import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:path/path.dart' as p;

import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/learning_progress_provider.dart';
import '../../providers/listening_practice/listening_practice_provider.dart';
import '../../utils/app_data_dir.dart';
import '../../utils/srt_generator.dart';
import '../../utils/word_timestamp_sync.dart';
import 'subtitle_edit_engine.dart';

enum SubtitleEditorPlaybackMode { idle, sentence, range }

final subtitleEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<SubtitleEditorController, SubtitleEditorState, AudioItem>((
      ref,
      audioItem,
    ) {
      return SubtitleEditorController(ref: ref, audioItem: audioItem);
    });

@immutable
class SubtitleEditorState {
  final bool isLoading;
  final bool isSaving;
  final bool isDirty;
  final String? errorMessage;
  final AudioItem audioItem;
  final List<Sentence> sentences;
  final int? selectedSentenceIndex;
  final int? playingSentenceIndex;
  final bool isPlaying;
  final SubtitleEditorPlaybackMode playbackMode;
  final Duration playbackPosition;
  final Duration? totalDuration;
  final Waveform? waveform;
  final double waveformProgress;
  final double playbackSpeed;
  final double waveformZoomScale;

  /// 用户「显式选中某句」的递增计数。
  ///
  /// 仅当用户主动点选句子（[selectSentence]）时自增，用来驱动波形把该句居中。
  /// 播放推进、播放结束、拖动边界等导致的选中句变化都不会改变它，从而避免
  /// 波形在播放停止后被错误地重新居中（跳变）。
  final int selectionEpoch;

  const SubtitleEditorState({
    required this.audioItem,
    this.isLoading = true,
    this.isSaving = false,
    this.isDirty = false,
    this.errorMessage,
    this.sentences = const [],
    this.selectedSentenceIndex,
    this.playingSentenceIndex,
    this.isPlaying = false,
    this.playbackMode = SubtitleEditorPlaybackMode.idle,
    this.playbackPosition = Duration.zero,
    this.totalDuration,
    this.waveform,
    this.waveformProgress = 0,
    this.playbackSpeed = 1.0,
    this.waveformZoomScale = 1.0,
    this.selectionEpoch = 0,
  });

  Sentence? get selectedSentence {
    final index = selectedSentenceIndex;
    if (index == null || index < 0 || index >= sentences.length) return null;
    return sentences[index];
  }

  /// 最大放大时屏幕内约可见的秒数；据此让长音频也能放大到看清一句话。
  static const double _minVisibleSeconds = 2.0;

  /// 波形最大放大倍数。
  ///
  /// `1.0` 表示不缩放（整段音频铺满屏宽）；放大到上限时屏幕内约可见
  /// [_minVisibleSeconds] 秒，足够精细调整句子边界。音频越长上限越大；
  /// 短于该秒数的音频无需放大，返回 `1.0`。
  double get maxWaveformZoomScale {
    final seconds = (totalDuration?.inMilliseconds ?? 0) / 1000;
    if (seconds <= _minVisibleSeconds) return 1.0;
    return (seconds / _minVisibleSeconds).clamp(1.0, 150.0);
  }

  SubtitleEditorState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isDirty,
    Object? errorMessage = _sentinel,
    AudioItem? audioItem,
    List<Sentence>? sentences,
    Object? selectedSentenceIndex = _sentinel,
    Object? playingSentenceIndex = _sentinel,
    bool? isPlaying,
    SubtitleEditorPlaybackMode? playbackMode,
    Duration? playbackPosition,
    Object? totalDuration = _sentinel,
    Waveform? waveform,
    double? waveformProgress,
    double? playbackSpeed,
    double? waveformZoomScale,
    int? selectionEpoch,
  }) {
    return SubtitleEditorState(
      audioItem: audioItem ?? this.audioItem,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      sentences: sentences ?? this.sentences,
      selectedSentenceIndex: selectedSentenceIndex == _sentinel
          ? this.selectedSentenceIndex
          : selectedSentenceIndex as int?,
      playingSentenceIndex: playingSentenceIndex == _sentinel
          ? this.playingSentenceIndex
          : playingSentenceIndex as int?,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackMode: playbackMode ?? this.playbackMode,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      totalDuration: totalDuration == _sentinel
          ? this.totalDuration
          : totalDuration as Duration?,
      waveform: waveform ?? this.waveform,
      waveformProgress: waveformProgress ?? this.waveformProgress,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      waveformZoomScale: waveformZoomScale ?? this.waveformZoomScale,
      selectionEpoch: selectionEpoch ?? this.selectionEpoch,
    );
  }
}

const _sentinel = Object();

class SubtitleEditorController extends StateNotifier<SubtitleEditorState> {
  SubtitleEditorController({required Ref ref, required AudioItem audioItem})
    : _ref = ref,
      _audioEngine = ref.read(audioEngineProvider.notifier),
      _engine = const SubtitleEditEngine(),
      super(SubtitleEditorState(audioItem: audioItem)) {
    _positionSub = _audioEngine.absolutePositionStream.listen(_handlePosition);
  }

  final Ref _ref;
  final AudioEngine _audioEngine;
  final SubtitleEditEngine _engine;
  StreamSubscription<Duration>? _positionSub;
  Timer? _playheadTimer;
  int? _activePlaybackSessionId;
  Duration _playbackStart = Duration.zero;
  Duration _playbackEnd = Duration.zero;
  Duration _playheadAnchor = Duration.zero;
  DateTime? _playheadAnchorAt;
  bool _hasLoaded = false;
  bool _didInitZoom = false;
  String _baselineSubtitleHash = '';

  /// 进入编辑页时的原始句子数量。
  ///
  /// 句子数量只会因合并/删除而减少（调整边界仅改时间戳）。保存时若数量未变，
  /// 说明仅调整了时间戳、句子与索引的对应关系不变，无需清空按句索引的学习进度
  /// 和收藏句子。
  int? _baselineSentenceCount;

  /// 相对进入编辑页时句子数量是否发生变化（合并/删除）。
  ///
  /// 仅调整边界时间戳不会改变数量。数量变化才会打乱按句索引的学习进度与收藏，
  /// 保存时需清空；据此 UI 也只在数量变化时提示「将清空进度」。
  bool get sentenceCountChanged =>
      _baselineSentenceCount != null &&
      state.sentences.length != _baselineSentenceCount;

  /// 每厘米屏幕对应的逻辑像素数（160 逻辑像素/英寸 ÷ 2.54 厘米/英寸）。
  static const double _logicalPixelsPerCm = 160 / 2.54;

  Future<void> load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    try {
      final duration = await _audioEngine.loadAudio(state.audioItem, 1.0);
      final sentences = await _audioEngine.loadTranscript(state.audioItem);
      _baselineSubtitleHash = _subtitleHash(sentences);
      _baselineSentenceCount = sentences.length;
      state = state.copyWith(
        isLoading: false,
        totalDuration: duration,
        sentences: sentences,
        selectedSentenceIndex: sentences.isEmpty ? null : 0,
        playbackPosition: sentences.isEmpty
            ? Duration.zero
            : sentences.first.startTime,
      );
      unawaited(_loadWaveform());
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> playSentence(int index) async {
    if (index < 0 || index >= state.sentences.length) return;
    await _stopActivePlayback(invalidateSession: true);
    final sentence = state.sentences[index];
    final sessionId = _audioEngine.newSession();
    _startPlayheadTicker(
      sessionId: sessionId,
      start: sentence.startTime,
      end: sentence.endTime,
    );
    state = state.copyWith(
      selectedSentenceIndex: index,
      playingSentenceIndex: index,
      isPlaying: true,
      playbackMode: SubtitleEditorPlaybackMode.sentence,
      playbackPosition: sentence.startTime,
    );
    try {
      await _audioEngine.setSpeed(state.playbackSpeed);
      await _audioEngine.playClipOnce(sentence, sessionId);
    } finally {
      if (mounted && _audioEngine.isActiveSession(sessionId)) {
        // ⚠️ 关键顺序：必须「先冻结状态（isPlaying=false + 锁定句尾位置）再停底层
        // 播放器」。否则 _audioPlayer.stop() 会吐出 position=0，经
        // absolutePositionStream 映射为 clipStart(=句首) 后被 _handlePosition 采纳
        // （此刻 isPlaying 仍为 true），把播放头拉回句首 —— 即「播放完跳回到前面」。
        // 与 stopPlayback() 同款处理。
        state = state.copyWith(
          playingSentenceIndex: null,
          isPlaying: false,
          playbackMode: SubtitleEditorPlaybackMode.idle,
          playbackPosition: sentence.endTime,
        );
        await _stopActivePlayback(invalidateSession: false);
      }
    }
  }

  /// 从当前播放头位置开始连续播放到音频末尾，不受句子边界限制。
  Future<void> togglePlaybackFromPlayhead() async {
    if (state.isPlaying) {
      await stopPlayback();
      return;
    }

    final start = _clampToDuration(state.playbackPosition);
    final end = _effectiveTotalDuration();
    if (end == null || start >= end) return;

    await _stopActivePlayback(invalidateSession: true);
    final sessionId = _audioEngine.newSession();
    _startPlayheadTicker(sessionId: sessionId, start: start, end: end);
    state = state.copyWith(
      selectedSentenceIndex: _sentenceIndexAt(start),
      playingSentenceIndex: null,
      isPlaying: true,
      playbackMode: SubtitleEditorPlaybackMode.range,
      playbackPosition: start,
    );

    try {
      await _audioEngine.setSpeed(state.playbackSpeed);
      await _audioEngine.playRangeOnce(start, end, sessionId);
    } finally {
      if (mounted && _audioEngine.isActiveSession(sessionId)) {
        // 同 playSentence：先冻结状态再停底层播放器，避免 stop() 的 position=0
        // 残留事件被 _handlePosition 采纳而把播放头拉回区间起点。
        state = state.copyWith(
          isPlaying: false,
          playbackMode: SubtitleEditorPlaybackMode.idle,
          playbackPosition: end,
        );
        await _stopActivePlayback(invalidateSession: false);
      }
    }
  }

  Future<void> stopPlayback() async {
    final pausedPosition = state.playbackPosition;
    // 先冻结状态（isPlaying=false + 锁定位置）再停底层播放：否则停止过程中
    // position 流残留事件会被 _handlePosition 处理，把播放头往前推，随后又被
    // pausedPosition 拉回，表现为红线「先往前跳一下再弹回」。
    state = state.copyWith(
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: pausedPosition,
    );
    await _stopActivePlayback(invalidateSession: true);
  }

  void selectSentence(int index) {
    if (index < 0 || index >= state.sentences.length) return;
    final sentence = state.sentences[index];
    state = state.copyWith(
      selectedSentenceIndex: index,
      playbackPosition: sentence.startTime,
      // 用户显式点选 —— 自增 epoch，驱动波形把该句居中。
      selectionEpoch: state.selectionEpoch + 1,
    );
  }

  void selectSentenceAt(Duration position) {
    final index = state.sentences.indexWhere(
      (sentence) =>
          position >= sentence.startTime && position < sentence.endTime,
    );
    if (index < 0) return;
    state = state.copyWith(
      selectedSentenceIndex: index,
      playbackPosition: position,
    );
  }

  void scrubTo(Duration position) {
    state = state.copyWith(
      selectedSentenceIndex: _sentenceIndexAt(position),
      playbackPosition: _clampToDuration(position),
    );
  }

  Future<void> finishScrub(Duration position) async {
    final clamped = _clampToDuration(position);
    if (state.isPlaying) {
      await stopPlayback();
    }
    scrubTo(clamped);
    await _audioEngine.clearClip();
    await _audioEngine.seekToAbsolute(clamped);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final next = speed.clamp(0.5, 2.0).toDouble();
    final currentPosition = state.playbackPosition;
    state = state.copyWith(playbackSpeed: next);
    if (state.isPlaying) {
      _calibratePlayhead(currentPosition);
      await _audioEngine.setSpeed(next);
    }
  }

  void setWaveformZoomScale(double scale) {
    state = state.copyWith(
      waveformZoomScale: scale
          .clamp(1.0, state.maxWaveformZoomScale)
          .toDouble(),
    );
  }

  /// 进入编辑页时按屏幕物理宽度自动计算初始缩放：每厘米屏幕约显示 1 秒音频。
  ///
  /// Flutter 逻辑像素以 160px/英寸 为基准，故 1 厘米 ≈ 63 逻辑像素。
  /// 缩放语义见 [SubtitleEditorState.maxWaveformZoomScale]：`zoom == 1` 时整段
  /// 音频铺满可视区，于是目标缩放 = (每厘米逻辑像素 × 音频秒数) / 可视区宽度。
  /// 仅在首次进入时执行一次，之后用户可通过滑块手动调整。
  void initZoomForViewport(double usableViewportWidth) {
    if (_didInitZoom) return;
    final seconds = (state.totalDuration?.inMilliseconds ?? 0) / 1000;
    if (usableViewportWidth <= 0 || seconds <= 0) return;
    _didInitZoom = true;
    final scale = _logicalPixelsPerCm * seconds / usableViewportWidth;
    setWaveformZoomScale(scale);
  }

  void mergeWithNext(int index) {
    final next = _engine.mergeWithNext(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterMerge(
      selectedIndex: state.selectedSentenceIndex,
      mergeIndex: index,
    );
    state = state.copyWith(
      sentences: next,
      selectedSentenceIndex: selectedIndex,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: _positionForSelected(next, selectedIndex),
      isDirty: _sentencesChanged(next),
    );
  }

  void deleteSentence(int index) {
    final next = _engine.deleteSentence(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterDelete(
      selectedIndex: state.selectedSentenceIndex,
      deletedIndex: index,
      nextLength: next.length,
    );
    state = state.copyWith(
      sentences: next,
      selectedSentenceIndex: selectedIndex,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      playbackPosition: _positionForSelected(next, selectedIndex),
      isDirty: _sentencesChanged(next),
    );
  }

  /// 调整当前选中句某一端边界到 [target]。
  void adjustSelectedSentenceBoundary(BoundaryEdge edge, Duration target) {
    final index = state.selectedSentenceIndex;
    if (index == null) return;
    adjustSentenceBoundary(index, edge, target);
  }

  /// 调整 [index] 句某一端边界到 [target]（波形拖动时实时调用）。
  ///
  /// 边界由 [SubtitleEditEngine.adjustBoundary] 按相邻句最近边界钳制，
  /// 保证不越界、不重叠。可用于拖动当前句或相邻句的边界（拖动相邻句时
  /// 保持当前选中句不变）。无实际变化时不更新 state。
  void adjustSentenceBoundary(int index, BoundaryEdge edge, Duration target) {
    if (index < 0 || index >= state.sentences.length) return;
    final total =
        state.totalDuration ??
        (state.sentences.isEmpty
            ? Duration.zero
            : state.sentences.last.endTime);
    final next = _engine.adjustBoundary(
      state.sentences,
      index,
      edge,
      target,
      totalDuration: total,
    );
    if (identical(next, state.sentences)) return;
    final wasPlaying = state.isPlaying;
    if (wasPlaying) _cancelPlaybackSession();
    state = state.copyWith(
      sentences: next,
      isDirty: _sentencesChanged(next),
      playingSentenceIndex: wasPlaying ? null : state.playingSentenceIndex,
      isPlaying: wasPlaying ? false : state.isPlaying,
      playbackMode: wasPlaying
          ? SubtitleEditorPlaybackMode.idle
          : state.playbackMode,
    );
  }

  /// 还原句子列表，用于删除后的撤销操作。
  ///
  /// 直接用调用方在删除前捕获的快照覆盖当前列表，并停止任何播放。
  /// 撤销后按当前字幕是否等于进入编辑页时的原始字幕重新计算 [isDirty]。
  void restoreSentences(List<Sentence> snapshot) {
    _cancelPlaybackSession();
    state = state.copyWith(
      sentences: snapshot,
      playingSentenceIndex: null,
      isPlaying: false,
      playbackMode: SubtitleEditorPlaybackMode.idle,
      isDirty: _sentencesChanged(snapshot),
    );
  }

  Future<bool> save() async {
    if (!state.isDirty || state.isSaving) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await stopPlayback();

      final item = state.audioItem;

      final srt = _generateSrt(state.sentences);

      // 词级时间戳同步（仅 AI 转录有词级数据）：按最终句子边界对齐边界词，
      // 丢弃被删除区间的词。无词级数据（本地字幕）则保留原词级列不动。
      final dao = _ref.read(audioItemDaoProvider);
      int? syncedWordCount;
      String? syncedWordsJson;
      bool updateWords = false;
      if (item.transcriptSource == TranscriptSource.ai) {
        final json = await dao.getWordTimestamps(item.id);
        final words = json == null ? null : decodeWordTimestamps(json);
        if (words != null && words.isNotEmpty) {
          final synced = syncWordTimestampsToSentenceBounds(
            state.sentences,
            words,
          );
          syncedWordsJson = encodeWordTimestamps(synced);
          syncedWordCount = synced.length;
          updateWords = true;
        }
      }

      // 字幕内容（+ 同步后的词级时间戳）原子写入 DB 列。
      if (updateWords) {
        await dao.saveTranscriptContent(
          item.id,
          srt: srt,
          wordTimestampsJson: syncedWordsJson,
        );
      } else {
        await dao.updateTranscriptSrt(item.id, srt);
      }

      final wordCount =
          syncedWordCount ??
          state.sentences.fold<int>(
            0,
            (sum, sentence) => sum + _countWords(sentence.text),
          );
      final updatedItem = item.copyWith(
        transcriptPath: null,
        sentenceCount: state.sentences.length,
        wordCount: wordCount,
      );

      await _ref
          .read(audioLibraryProvider.notifier)
          .updateAudioItem(updatedItem);

      // 句子数量变化（合并/删除）才会打乱按句索引的学习进度和收藏句子，需清空；
      // 仅调整时间戳时索引对应关系不变，保留进度与收藏。
      if (sentenceCountChanged) {
        await _ref.read(bookmarkDaoProvider).removeAllForAudio(item.id);
        await _ref
            .read(learningProgressNotifierProvider.notifier)
            .deleteProgress(item.id);
      }

      final practiceState = _ref.read(listeningPracticeProvider);
      if (practiceState.currentAudioItem?.id == item.id) {
        // 字幕保存只改 DB transcript_srt 列，id / transcriptPath 不变（都为 null）。
        // loadAudio 的去重守卫只比较 id + transcriptPath，不带 force 会命中守卫
        // 直接跳过重新解析，使 keepAlive 的 LP 保留旧句子（自由练习/盲听显示陈旧
        // 拆分版本）。必须强制重载以绕过守卫，从 DB 列读到最新内容。
        await _ref
            .read(listeningPracticeProvider.notifier)
            .loadAudio(updatedItem, forceTranscriptReload: true);
      }

      _baselineSentenceCount = state.sentences.length;
      _baselineSubtitleHash = _subtitleHash(state.sentences);
      if (!mounted) return true;
      state = state.copyWith(
        isSaving: false,
        isDirty: false,
        audioItem: updatedItem,
      );
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSaving: false, errorMessage: e.toString());
      }
      return false;
    }
  }

  void _handlePosition(Duration position) {
    if (!mounted || !state.isPlaying) return;
    if (position < _playbackStart ||
        position > _playbackEnd + const Duration(milliseconds: 250)) {
      return;
    }
    // 防御：播放期间播放头由本地时钟（_tickPlayhead）单调前进，position 流仅做校准。
    // 大幅「后退」几乎只可能是停止/换 clip 的残留事件（stop 把相对位置归 0 → 映射成
    // clip 起点），直接丢弃，避免把播放头拉回。允许 ≤400ms 的正常校准抖动。
    if (position < state.playbackPosition - const Duration(milliseconds: 400)) {
      return;
    }
    final clamped = _clampToPlaybackRange(position);
    _calibratePlayhead(clamped);
    state = state.copyWith(
      selectedSentenceIndex: _selectedIndexDuringPlayback(clamped),
      playbackPosition: clamped,
    );
  }

  /// 播放推进时的选中句索引。
  ///
  /// 仅连续播放（range 模式）跟随播放头切换选中句；单句播放（sentence 模式）
  /// 保持焦点在当前句，避免播到句尾因与下一句首尾相接而跳到下一句。
  int? _selectedIndexDuringPlayback(Duration position) {
    if (state.playbackMode == SubtitleEditorPlaybackMode.range) {
      return _sentenceIndexAt(position);
    }
    return state.selectedSentenceIndex;
  }

  int? _sentenceIndexAt(Duration position) {
    final index = state.sentences.indexWhere(
      (sentence) =>
          position >= sentence.startTime && position < sentence.endTime,
    );
    return index < 0 ? state.selectedSentenceIndex : index;
  }

  Duration _clampToDuration(Duration position) {
    final total = _effectiveTotalDuration();
    if (position < Duration.zero) return Duration.zero;
    if (total != null && position > total) return total;
    return position;
  }

  Duration? _effectiveTotalDuration() {
    return state.totalDuration ?? state.waveform?.duration;
  }

  void _cancelPlaybackSession() {
    if (!state.isPlaying && state.playingSentenceIndex == null) return;
    _audioEngine.newSession();
    _cancelPlayheadTicker();
    unawaited(_stopAndClearClip());
  }

  Future<void> _stopActivePlayback({required bool invalidateSession}) async {
    final shouldStop =
        state.isPlaying ||
        state.playingSentenceIndex != null ||
        _activePlaybackSessionId != null;
    if (invalidateSession) {
      _audioEngine.newSession();
    }
    _cancelPlayheadTicker();
    if (shouldStop) {
      await _stopAndClearClip();
      return;
    }
    await _audioEngine.clearClip();
  }

  Future<void> _stopAndClearClip() async {
    await _audioEngine.stopPlayback();
    await _audioEngine.clearClip();
  }

  /// 用本地时钟驱动播放头，底层 position stream 只负责校准。
  ///
  /// 这是音频编辑器常见做法：UI 以稳定帧率前进，避免播放器 position
  /// 事件稀疏时红线跳动；真正完成仍由播放 Future / session 兜底。
  void _startPlayheadTicker({
    required int sessionId,
    required Duration start,
    required Duration end,
  }) {
    _cancelPlayheadTicker();
    _activePlaybackSessionId = sessionId;
    _playbackStart = start;
    _playbackEnd = end;
    _calibratePlayhead(start);
    _playheadTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _tickPlayhead(),
    );
  }

  void _cancelPlayheadTicker() {
    _playheadTimer?.cancel();
    _playheadTimer = null;
    _activePlaybackSessionId = null;
    _playheadAnchorAt = null;
  }

  void _calibratePlayhead(Duration position) {
    _playheadAnchor = position;
    _playheadAnchorAt = DateTime.now();
  }

  void _tickPlayhead() {
    final sessionId = _activePlaybackSessionId;
    final anchorAt = _playheadAnchorAt;
    if (!mounted ||
        sessionId == null ||
        anchorAt == null ||
        !state.isPlaying ||
        !_audioEngine.isActiveSession(sessionId)) {
      _cancelPlayheadTicker();
      return;
    }

    final elapsed = DateTime.now().difference(anchorAt);
    final advancedUs = elapsed.inMicroseconds * state.playbackSpeed;
    final position = _clampToPlaybackRange(
      _playheadAnchor + Duration(microseconds: advancedUs.round()),
    );
    state = state.copyWith(
      selectedSentenceIndex: _selectedIndexDuringPlayback(position),
      playbackPosition: position,
    );
  }

  Duration _clampToPlaybackRange(Duration position) {
    if (position < _playbackStart) return _playbackStart;
    if (position > _playbackEnd) return _playbackEnd;
    return position;
  }

  Duration _positionForSelected(List<Sentence> sentences, int? selectedIndex) {
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= sentences.length) {
      return Duration.zero;
    }
    return sentences[selectedIndex].startTime;
  }

  /// 字幕是否相对进入编辑页或上次保存后的基线发生了实质变化。
  ///
  /// dirty 状态只看最终可保存的 SRT 内容，不看用户操作历史；删除后撤销、
  /// 边界拖回原位都会回到未修改状态，避免保存按钮误激活。
  bool _sentencesChanged(List<Sentence> current) {
    return _subtitleHash(current) != _baselineSubtitleHash;
  }

  String _subtitleHash(List<Sentence> sentences) {
    return sha256.convert(utf8.encode(_generateSrt(sentences))).toString();
  }

  String _generateSrt(List<Sentence> sentences) {
    return generateSrtContent([
      for (final sentence in sentences)
        TranscriptSentence(
          text: sentence.text,
          startTime: sentence.startTime,
          endTime: sentence.endTime,
        ),
    ]);
  }

  Future<void> _loadWaveform() async {
    try {
      final audioPath = await state.audioItem.getFullAudioPath();
      if (audioPath == null) return;
      final dataDir = await getAppDataDirectory();
      final waveDir = Directory(p.join(dataDir.path, 'waveforms'));
      if (!await waveDir.exists()) {
        await waveDir.create(recursive: true);
      }
      final waveFile = File(p.join(waveDir.path, '${state.audioItem.id}.wave'));
      if (await waveFile.exists()) {
        final waveform = await JustWaveform.parse(waveFile);
        if (!mounted) return;
        state = state.copyWith(waveform: waveform, waveformProgress: 1);
        return;
      }

      await for (final progress in JustWaveform.extract(
        audioInFile: File(audioPath),
        waveOutFile: waveFile,
        zoom: const WaveformZoom.pixelsPerSecond(80),
      )) {
        if (!mounted) return;
        state = state.copyWith(
          waveform: progress.waveform,
          waveformProgress: progress.progress,
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(waveformProgress: 0);
    }
  }

  int _countWords(String text) {
    return text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int? _indexAfterMerge({
    required int? selectedIndex,
    required int mergeIndex,
  }) {
    if (selectedIndex == null) return null;
    if (selectedIndex == mergeIndex + 1) return mergeIndex;
    if (selectedIndex > mergeIndex + 1) return selectedIndex - 1;
    return selectedIndex;
  }

  int? _indexAfterDelete({
    required int? selectedIndex,
    required int deletedIndex,
    required int nextLength,
  }) {
    if (selectedIndex == null || nextLength == 0) return null;
    if (selectedIndex == deletedIndex) {
      return deletedIndex.clamp(0, nextLength - 1).toInt();
    }
    if (selectedIndex > deletedIndex) return selectedIndex - 1;
    return selectedIndex.clamp(0, nextLength - 1).toInt();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cancelPlayheadTicker();
    _audioEngine.newSession();
    unawaited(_stopAndClearClip());
    super.dispose();
  }
}

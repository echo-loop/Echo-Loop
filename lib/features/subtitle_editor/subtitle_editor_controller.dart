import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateNotifier / StateProvider 已移入 legacy 库（Riverpod 3），此处保留旧写法
import 'package:flutter_riverpod/legacy.dart';

import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/listening_practice/listening_practice_provider.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/pause_other_playback_provider.dart';
import '../../providers/transcript_change_sync_provider.dart';
import '../../services/app_logger.dart';
import '../../services/subtitle_parser.dart';
import '../../services/transcript_sentences_loader.dart';
import '../../utils/srt_generator.dart';
import '../../utils/synthetic_word_timestamps.dart';
import '../../utils/waveform_peaks.dart';
import '../media_trim/media_trim_processor.dart';
import '../media_trim/media_trim_waveform_loader.dart';
import 'subtitle_edit_engine.dart';
import 'subtitle_editor_audio_player.dart';

/// 编辑器播放模式。
///
/// [word] 播放单词且播放头随之移动（字幕列表点词，帮助定位）；[wordAudition]
/// 只试听单词、播放头停在原处（波形上点词，避免播放头跳动干扰编辑）。
enum SubtitleEditorPlaybackMode { idle, sentence, range, word, wordAudition }

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
  final WaveformPeaks? waveform;
  final double waveformProgress;

  /// 波形提取是否失败（原生解码报错或长时间无进展）。
  ///
  /// 波形只是编辑辅助：失败时波形区显示失败态 + 重试，下方句子列表仍可正常编辑，
  /// 不阻断整个编辑流程。与「加载中（waveform == null 且未失败）」显式区分，
  /// 避免失败被误显示成永久「加载 0%」。
  final bool waveformFailed;

  /// 当前 item 没有本地音频文件，无法生成波形。
  ///
  /// 这不是波形提取失败：用户仍可编辑已有字幕，但没有可重试的本地音频输入。
  final bool waveformAudioMissing;
  final double playbackSpeed;
  final double waveformZoomScale;

  /// 用户「显式选中某句」的递增计数。
  ///
  /// 仅当用户主动点选句子（[selectSentence]）时自增，用来驱动波形把该句居中。
  /// 播放推进、播放结束、拖动边界等导致的选中句变化都不会改变它，从而避免
  /// 波形在播放停止后被错误地重新居中（跳变）。
  final int selectionEpoch;

  /// 当前音频的词级时间戳（全量）。
  ///
  /// AI 转录音频来自 DB `word_timestamps_json`；本地上传字幕没有真实词级数据时，
  /// 由 [generateSyntheticWordTimestamps] 按句内字符比例近似生成（编辑会话内存使用，
  /// 本任务不持久化）。词级编辑（拆成单词 label、点词播放、词边界显示）的数据源。
  final List<WordTimestamp> words;

  /// 当前点中词在「选中句词列表」内的序号；null 表示未点中任何词（纯文本态）。
  ///
  /// 用户点某句获焦后，点其中一个单词 label 时置位，用来播放该词并在波形上显示
  /// 该词及左右各两词的边界。切句 / 播放整句 / 结构变化时清空。
  final int? focusedWordIndex;

  /// 是否有可撤销 / 可重做的编辑（驱动标题栏按钮的可用态）。
  final bool canUndo;
  final bool canRedo;

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
    this.waveformFailed = false,
    this.waveformAudioMissing = false,
    this.playbackSpeed = 1.0,
    this.waveformZoomScale = 1.0,
    this.maxWaveformZoomScale = 1.0,
    this.selectionEpoch = 0,
    this.words = const [],
    this.focusedWordIndex,
    this.canUndo = false,
    this.canRedo = false,
  });

  Sentence? get selectedSentence {
    final index = selectedSentenceIndex;
    if (index == null || index < 0 || index >= sentences.length) return null;
    return sentences[index];
  }

  /// 波形最大放大倍数。
  ///
  /// `1.0` 表示不缩放（整段音频铺满屏宽）；进入编辑页拿到波形可用宽度后，
  /// [SubtitleEditorController.initZoomForViewport] 会按「最大放大时 1 秒音频约占
  /// 5cm 屏幕长度」计算上限。音频越长，上限越大。
  final double maxWaveformZoomScale;

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
    WaveformPeaks? waveform,
    double? waveformProgress,
    bool? waveformFailed,
    bool? waveformAudioMissing,
    double? playbackSpeed,
    double? waveformZoomScale,
    double? maxWaveformZoomScale,
    int? selectionEpoch,
    List<WordTimestamp>? words,
    Object? focusedWordIndex = _sentinel,
    bool? canUndo,
    bool? canRedo,
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
      waveformFailed: waveformFailed ?? this.waveformFailed,
      waveformAudioMissing: waveformAudioMissing ?? this.waveformAudioMissing,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      waveformZoomScale: waveformZoomScale ?? this.waveformZoomScale,
      maxWaveformZoomScale: maxWaveformZoomScale ?? this.maxWaveformZoomScale,
      selectionEpoch: selectionEpoch ?? this.selectionEpoch,
      words: words ?? this.words,
      focusedWordIndex: focusedWordIndex == _sentinel
          ? this.focusedWordIndex
          : focusedWordIndex as int?,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
    );
  }
}

/// 一步编辑前后的可还原内容：字幕、词级时间与当时的选中句。
typedef _EditSnapshot = ({
  List<Sentence> sentences,
  List<WordTimestamp> words,
  int? selectedSentenceIndex,
});

const _sentinel = Object();

class SubtitleEditorController extends StateNotifier<SubtitleEditorState> {
  SubtitleEditorController({required Ref ref, required AudioItem audioItem})
    : _ref = ref,
      _audioPlayer = SubtitleEditorAudioPlayer(
        ref.read(mediaBackendFactoryProvider)(),
      ),
      _engine = const SubtitleEditEngine(),
      super(SubtitleEditorState(audioItem: audioItem)) {
    _positionSub = _audioPlayer.positionStream.listen(_handlePosition);
  }

  final Ref _ref;

  /// 编辑器独占的声音播放器，随编辑页创建与释放。
  final SubtitleEditorAudioPlayer _audioPlayer;
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

  /// 进入编辑页或上次保存时的词级时间；与当前比较判定「仅改词边界」的改动，
  /// 撤销回原样时可恢复为未修改。
  List<WordTimestamp> _baselineWords = const [];

  /// 撤销 / 重做栈，只在本次编辑会话内有效。
  final List<_EditSnapshot> _undoStack = [];
  final List<_EditSnapshot> _redoStack = [];

  /// 撤销栈上限，防止长时间编辑无限占用内存。
  static const int _maxHistoryLength = 200;

  /// 一次边界 / 整词拖动是否已记录撤销点：拖动中每帧都会调用 [adjustWord] /
  /// [moveWord]，只在第一帧记录，整次拖动撤销一步。
  bool _hasRecordedAdjust = false;

  /// 进入编辑页或上次保存时的句子；保存时据此把学习断点换算到新字幕。
  List<Sentence> _baselineSentences = const [];

  /// 每厘米屏幕对应的逻辑像素数（160 逻辑像素/英寸 ÷ 2.54 厘米/英寸）。
  static const double _logicalPixelsPerCm = 160 / 2.54;

  /// 最大放大时 1 秒音频在屏幕上占用的物理长度。
  static const double _maxZoomCentimetersPerSecond = 5.0;

  Future<void> load() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    try {
      await _ref.read(pauseOtherPlaybackProvider)();
      if (!mounted) return;
      final duration = await _openAudio();
      if (!mounted) return;
      final sentences = await loadTranscriptSentences(
        _ref.read(audioItemDaoProvider),
        state.audioItem,
      );
      if (!mounted) return;
      _baselineSubtitleHash = _subtitleHash(sentences);
      _baselineSentences = sentences;
      // 物化为按句子文本 token 对齐的可编辑词列表（词边界拖动直接改它）。
      final words = _buildWords(sentences, await _loadWords(sentences));
      _baselineWords = words;
      state = state.copyWith(
        isLoading: false,
        totalDuration: duration,
        sentences: sentences,
        words: words,
        selectedSentenceIndex: sentences.isEmpty ? null : 0,
        playbackPosition: sentences.isEmpty
            ? Duration.zero
            : sentences.first.startTime,
      );
      AppLogger.log(
        'SubtitleEditor',
        '编辑页加载完成 audio=${state.audioItem.id} video=${state.audioItem.isVideo} '
            'duration=${duration?.inMilliseconds}ms sentences=${sentences.length}',
      );
      unawaited(_loadWaveform());
    } catch (e) {
      AppLogger.log(
        'SubtitleEditor',
        '编辑页加载失败 audio=${state.audioItem.id} error=$e',
      );
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 打开本地媒体并返回时长；没有本地文件时返回 null，字幕仍可编辑，只是不能试听。
  Future<Duration?> _openAudio() async {
    final path = await state.audioItem.getFullAudioPath();
    if (path == null) {
      AppLogger.log(
        'SubtitleEditor',
        '本地媒体文件缺失，跳过音频加载 audio=${state.audioItem.id}',
      );
      return null;
    }
    return _audioPlayer.open(path);
  }

  /// 加载当前音频的词级时间戳。
  ///
  /// 优先读 DB `word_timestamps_json`（AI 转录音频有真实词级数据）；为空或读取失败
  /// （本地上传字幕无词级数据）时按字幕句子近似生成，保证词级编辑入口对所有有字幕的
  /// 音频一致可用。本任务只在编辑会话内存使用，不写回 DB。
  Future<List<WordTimestamp>> _loadWords(List<Sentence> sentences) async {
    try {
      final json = await _ref
          .read(audioItemDaoProvider)
          .getWordTimestamps(state.audioItem.id);
      final decoded = json == null ? null : decodeWordTimestamps(json);
      if (decoded != null && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // DB 不可用时退化为合成词级时间戳，不阻塞编辑器加载。
    }
    return generateSyntheticWordTimestamps(sentences);
  }

  /// 词边界拖动时的最小词长，避免把词拖成零长或负长。
  static const Duration kMinWordDuration = Duration(milliseconds: 20);

  /// 选中句拆成的单词列表（按文本顺序），每个词带可编辑的时间区间。
  ///
  /// 取自 [SubtitleEditorState.words]（加载时按句子文本 token 物化、可被拖动编辑）对应
  /// 本句的切片，并把时间钳到当前句区间、首词贴句首 / 末词贴句尾（句子边界可能被单独
  /// 拖过）。词来自**句子文本按空格切分**，绝不丢词（含句首单字母词如 "I"）。
  /// 无选中句时返回空。
  List<WordTimestamp> get wordsOfSelectedSentence {
    final index = state.selectedSentenceIndex;
    if (index == null || index < 0 || index >= state.sentences.length) {
      return const [];
    }
    return _sentenceWords(index);
  }

  /// 选中句内与播放头对应的单词序号：句子列表高亮它、波形标出它的区间，与播放头
  /// 和视频画面始终是同一时刻。
  ///
  /// 用户点了某个词（[SubtitleEditorState.focusedWordIndex]）时以该词为准：播完
  /// 一个词后播放头停在词尾，按位置会落到下一个词上。其余情况（播放整句、拖动 /
  /// 点按定位播放头）按播放头位置取词，落在词与词的空隙或句外时为 null。
  int? get highlightedWordIndex {
    final words = wordsOfSelectedSentence;
    if (words.isEmpty) return null;
    final focused = state.focusedWordIndex;
    if (focused != null && focused < words.length) return focused;
    final position = state.playbackPosition;
    final index = words.indexWhere(
      (word) => position >= word.startTime && position < word.endTime,
    );
    return index < 0 ? null : index;
  }

  /// 波形要绘制 / 可拖动的全部单词边界：选中句 + 前后相邻句的所有词。
  ///
  /// 句子的起止边界即首词起点 / 末词终点，统一为单词边界（见 [adjustWord]），不再
  /// 单列句子边界。当前句为主样式，相邻句为次样式。无选中句返回空。
  List<WaveformWordBoundary> get wordBoundariesForWaveform {
    final selected = state.selectedSentenceIndex;
    if (selected == null) return const [];
    final result = <WaveformWordBoundary>[];
    for (final i in [selected - 1, selected, selected + 1]) {
      if (i < 0 || i >= state.sentences.length) continue;
      final view = _sentenceWords(i);
      if (view.isEmpty) continue;
      final range = _sentenceTokenRange(i);
      final last = view.length - 1;
      for (var local = 0; local < view.length; local++) {
        result.add((
          globalIndex: range == null ? -1 : range.offset + local,
          word: view[local],
          primary: i == selected,
          isSentenceStart: local == 0,
          isSentenceEnd: local == last,
        ));
      }
    }
    return result;
  }

  /// 拖动第 [globalIndex] 个词的某一端边界到 [target]（波形拖动时实时调用）。
  ///
  /// 统一入口：所有边界都是单词边界。句首词的起点 / 句末词的终点即句子的起止边界，
  /// 拖动它们会**同步**更新对应句的起止时间，保持「句起 = 首词起、句止 = 末词止」
  /// 不变量。钳制依据一律取自 [_sentenceWords]（已钳到句区间、首尾贴句界的显示视图）
  /// 与相邻句边界（[_prevSentenceEnd] / [_nextSentenceStart]），相邻词 / 句子边界绝
  /// 不被穿越。
  void adjustWord(int globalIndex, BoundaryEdge edge, Duration target) {
    if (globalIndex < 0 || globalIndex >= state.words.length) return;
    final sentenceIndex = _sentenceIndexOfWord(globalIndex);
    if (sentenceIndex == null) return;
    final range = _sentenceTokenRange(sentenceIndex);
    if (range == null) return;
    final local = globalIndex - range.offset;
    final view = _sentenceWords(sentenceIndex);
    if (local < 0 || local >= view.length) return;
    final word = view[local];

    final bounds = _wordEdgeBounds(sentenceIndex, view, local, edge);
    final current = edge == BoundaryEdge.start ? word.startTime : word.endTime;
    // 相邻词 / 句边界是硬约束，最小词长只阻止「再变短」：插词按字数分时间可能
    // 产生短于最小词长的词，此时若强行补足最小词长会越过相邻词、造成重叠。
    final clamped = _clampDuration(
      target,
      current < bounds.lower ? current : bounds.lower,
      current > bounds.upper ? current : bounds.upper,
    );
    if (clamped == current) return;
    if (!_hasRecordedAdjust) {
      _recordHistory();
      _hasRecordedAdjust = true;
    }

    // 写回原始词列表（采用句区间内显示值，避免原始词积累越界时间）。
    final words = List<WordTimestamp>.of(state.words);
    words[globalIndex] = edge == BoundaryEdge.start
        ? word.copyWith(startTime: clamped)
        : word.copyWith(endTime: clamped);

    // 句首词起点 / 句末词终点即句子边界：同步更新句子时间保持不变量。
    final isSentenceEdge =
        (edge == BoundaryEdge.start && local == 0) ||
        (edge == BoundaryEdge.end && local == view.length - 1);
    final nextSentences = isSentenceEdge
        ? _withSentenceEdge(sentenceIndex, edge, clamped)
        : state.sentences;
    _commitWordDrag(words, nextSentences);
  }

  /// 整体平移第 [globalIndex] 个词，使其起点到 [targetStart]，词长不变（波形上
  /// 按住词区间拖动时实时调用）。
  ///
  /// 与相邻词首尾相接（导入字幕按比例生成的词都是相接的）时，共享边界一起移动：
  /// 相邻词随之变长 / 变短，但不短于 [kMinWordDuration]；不相接的相邻词与相邻句
  /// 是硬边界。句首词 / 句末词同时带动句子起止，保持「句起 = 首词起、句止 = 末词
  /// 止」不变量（同 [adjustWord]）。
  void moveWord(int globalIndex, Duration targetStart) {
    if (globalIndex < 0 || globalIndex >= state.words.length) return;
    final sentenceIndex = _sentenceIndexOfWord(globalIndex);
    if (sentenceIndex == null) return;
    final range = _sentenceTokenRange(sentenceIndex);
    if (range == null) return;
    final local = globalIndex - range.offset;
    final view = _sentenceWords(sentenceIndex);
    if (local < 0 || local >= view.length) return;
    final word = view[local];
    final length = word.endTime - word.startTime;
    final last = view.length - 1;
    final prev = local > 0 ? view[local - 1] : null;
    final next = local < last ? view[local + 1] : null;
    final isPrevLinked = prev != null && prev.endTime == word.startTime;
    final isNextLinked = next != null && next.startTime == word.endTime;

    final lowerLimit = prev == null
        ? _prevSentenceEnd(sentenceIndex)
        : isPrevLinked
        ? prev.startTime + kMinWordDuration
        : prev.endTime;
    final upperLimit =
        (next == null
            ? _nextSentenceStart(sentenceIndex)
            : isNextLinked
            ? next.endTime - kMinWordDuration
            : next.startTime) -
        length;
    // 相邻词本已短于最小词长时只阻止它再变短，不强行把当前词推开。
    final start = _clampDuration(
      targetStart,
      lowerLimit < word.startTime ? lowerLimit : word.startTime,
      upperLimit > word.startTime ? upperLimit : word.startTime,
    );
    if (start == word.startTime) return;
    if (!_hasRecordedAdjust) {
      _recordHistory();
      _hasRecordedAdjust = true;
    }

    final end = start + length;
    final words = List<WordTimestamp>.of(state.words);
    words[globalIndex] = word.copyWith(startTime: start, endTime: end);
    if (isPrevLinked) words[globalIndex - 1] = prev.copyWith(endTime: start);
    if (isNextLinked) words[globalIndex + 1] = next.copyWith(startTime: end);
    var nextSentences = state.sentences;
    if (local == 0 || local == last) {
      nextSentences = [...nextSentences];
      final sentence = nextSentences[sentenceIndex];
      nextSentences[sentenceIndex] = sentence.copyWith(
        startTime: local == 0 ? start : sentence.startTime,
        endTime: local == last ? end : sentence.endTime,
      );
    }
    _commitWordDrag(words, nextSentences);
  }

  /// 写入一帧词拖动结果；拖动会打断正在进行的试听。
  void _commitWordDrag(List<WordTimestamp> words, List<Sentence> sentences) {
    final wasPlaying = state.isPlaying;
    if (wasPlaying) _cancelPlaybackSession();
    _commitEdit(
      state.copyWith(
        words: words,
        sentences: sentences,
        playingSentenceIndex: wasPlaying ? null : state.playingSentenceIndex,
        isPlaying: wasPlaying ? false : state.isPlaying,
        playbackMode: wasPlaying
            ? SubtitleEditorPlaybackMode.idle
            : state.playbackMode,
      ),
    );
  }

  /// 一次边界 / 整词拖动结束（松手）：下一次拖动重新记录撤销点。
  void endWordAdjust() {
    _hasRecordedAdjust = false;
  }

  /// 计算第 [local] 个词某端边界的允许范围 `[lower, upper]`。
  ///
  /// 句首词起点下限 = 前一句终点（无前句则 0）；句末词终点上限 = 后一句起点
  /// （无后句则音频总时长）。内部边界按相邻词 + [kMinWordDuration] 钳制。
  ({Duration lower, Duration upper}) _wordEdgeBounds(
    int sentenceIndex,
    List<WordTimestamp> view,
    int local,
    BoundaryEdge edge,
  ) {
    final word = view[local];
    if (edge == BoundaryEdge.start) {
      final lower = local > 0
          ? view[local - 1].endTime
          : _prevSentenceEnd(sentenceIndex);
      return (lower: lower, upper: word.endTime - kMinWordDuration);
    }
    final upper = local < view.length - 1
        ? view[local + 1].startTime
        : _nextSentenceStart(sentenceIndex);
    return (lower: word.startTime + kMinWordDuration, upper: upper);
  }

  /// 前一句终点（句首词起点的下限）；无前句返回 0。
  Duration _prevSentenceEnd(int sentenceIndex) {
    if (sentenceIndex <= 0) return Duration.zero;
    return state.sentences[sentenceIndex - 1].endTime;
  }

  /// 后一句起点（句末词终点的上限）；无后句返回音频总时长。
  Duration _nextSentenceStart(int sentenceIndex) {
    if (sentenceIndex < state.sentences.length - 1) {
      return state.sentences[sentenceIndex + 1].startTime;
    }
    return _effectiveTotalDuration() ??
        (state.sentences.isEmpty
            ? Duration.zero
            : state.sentences.last.endTime);
  }

  /// 返回把第 [index] 句某端时间改为 [clamped] 的新句子列表。
  List<Sentence> _withSentenceEdge(
    int index,
    BoundaryEdge edge,
    Duration clamped,
  ) {
    final next = [...state.sentences];
    final s = next[index];
    next[index] = edge == BoundaryEdge.start
        ? s.copyWith(startTime: clamped)
        : s.copyWith(endTime: clamped);
    return next;
  }

  Duration _clampDuration(Duration value, Duration lower, Duration upper) {
    if (upper < lower) return lower;
    if (value < lower) return lower;
    if (value > upper) return upper;
    return value;
  }

  /// 按空格把句子文本切成单词（去掉空 token）。labels 与词区间都以此为准，绝不丢词。
  static List<String> _splitTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed.split(RegExp(r'\s+'));
  }

  /// 第 [index] 句的 token 在全篇词列表中的 [offset, offset+count) 范围；
  /// 词列表与文本 token 数不同步（结构刚变、尚未重建）时返回 null。
  ({int offset, int count})? _sentenceTokenRange(int index) {
    final counts = [
      for (final s in state.sentences) _splitTokens(s.text).length,
    ];
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    if (state.words.length != total) return null;
    var offset = 0;
    for (var i = 0; i < index; i++) {
      offset += counts[i];
    }
    return (offset: offset, count: counts[index]);
  }

  /// 全局词下标 [globalIndex] 所属的句索引；找不到返回 null。
  int? _sentenceIndexOfWord(int globalIndex) {
    var offset = 0;
    for (var i = 0; i < state.sentences.length; i++) {
      final count = _splitTokens(state.sentences[i].text).length;
      if (globalIndex >= offset && globalIndex < offset + count) return i;
      offset += count;
    }
    return null;
  }

  /// 取第 [index] 句的可编辑词切片：钳到当前句区间 + 首尾贴合句子边界。
  List<WordTimestamp> _sentenceWords(int index) {
    final sentence = state.sentences[index];
    final range = _sentenceTokenRange(index);
    if (range == null) {
      // 词列表与文本 token 不同步（结构刚变），即时按比例重建本句。
      final tokens = _splitTokens(sentence.text);
      if (tokens.isEmpty) return const [];
      return _proportionalTokens(tokens, sentence);
    }
    if (range.count == 0) return const [];
    final slice = state.words
        .sublist(range.offset, range.offset + range.count)
        .toList();
    for (var i = 0; i < slice.length; i++) {
      slice[i] = _clampWordToSentence(
        slice[i],
        slice[i].word,
        sentence.startTime,
        sentence.endTime,
      );
    }
    slice[0] = slice.first.copyWith(startTime: sentence.startTime);
    slice[slice.length - 1] = slice.last.copyWith(endTime: sentence.endTime);
    return slice;
  }

  /// 整篇词列表（保存用）：逐句取 [_sentenceWords]（已钳到句区间、首尾贴合句子边界）。
  List<WordTimestamp> _wordsSnappedToSentences() {
    final result = <WordTimestamp>[];
    for (var i = 0; i < state.sentences.length; i++) {
      result.addAll(_sentenceWords(i));
    }
    return result;
  }

  /// 加载 / 结构变化后，按句子文本 token 物化整篇可编辑词列表。
  ///
  /// 每句：若全篇 token 数与 [rawWords] 数一致则按顺序索引取真实词级时间（钳到句区间），
  /// 否则按句内字符比例近似切分；并把首词贴句首、末词贴句尾。
  static List<WordTimestamp> _buildWords(
    List<Sentence> sentences,
    List<WordTimestamp> rawWords,
  ) {
    final counts = [for (final s in sentences) _splitTokens(s.text).length];
    final total = counts.fold<int>(0, (sum, c) => sum + c);
    final aligned = total > 0 && rawWords.length == total;
    final result = <WordTimestamp>[];
    var offset = 0;
    for (final sentence in sentences) {
      final tokens = _splitTokens(sentence.text);
      if (tokens.isEmpty) continue;
      final List<WordTimestamp> words;
      if (aligned) {
        words = [
          for (var k = 0; k < tokens.length; k++)
            _clampWordToSentence(
              rawWords[offset + k],
              tokens[k],
              sentence.startTime,
              sentence.endTime,
            ),
        ];
      } else {
        words = _proportionalTokens(tokens, sentence);
      }
      words[0] = words.first.copyWith(startTime: sentence.startTime);
      words[words.length - 1] = words.last.copyWith(endTime: sentence.endTime);
      result.addAll(words);
      offset += tokens.length;
    }
    return result;
  }

  /// 用给定词级时间构造词，并把时间钳到句区间（边界词不越过句起止线）。
  static WordTimestamp _clampWordToSentence(
    WordTimestamp word,
    String text,
    Duration start,
    Duration end,
  ) {
    var s = word.startTime;
    var e = word.endTime;
    if (s < start) s = start;
    if (s > end) s = end;
    if (e > end) e = end;
    if (e < s) e = s;
    return WordTimestamp(word: text, startTime: s, endTime: e);
  }

  /// 按各词字符数比例把句区间切成词级时间（无真实词级数据时使用）。
  static List<WordTimestamp> _proportionalTokens(
    List<String> tokens,
    Sentence s,
  ) => SubtitleEditEngine.distributeTokens(tokens, s.startTime, s.endTime);

  /// 就地编辑选中句第 [localWordIndex] 个词为 [input]（单词工具栏「编辑」提交时调用）。
  ///
  /// - [input] 为空 → 删除该词（其余词时间不变）；若是句中唯一词则删整句。
  /// - 单个词 → 仅改词文本，时间区间不变。
  /// - 多个词 → 把该词所在的时间按各词字符数比例切成多段。
  void editWord(int localWordIndex, String input) {
    final selected = state.selectedSentenceIndex;
    if (selected == null) return;
    final tokens = _sentenceTokens(selected);
    if (tokens == null ||
        localWordIndex < 0 ||
        localWordIndex >= tokens.length) {
      return;
    }
    final newTokens = _splitTokens(input);
    _replaceSentenceTokens(selected, [
      for (var i = 0; i < localWordIndex; i++) (tokens[i], i),
      for (final token in newTokens) (token, null),
      for (var i = localWordIndex + 1; i < tokens.length; i++) (tokens[i], i),
    ]);
  }

  /// 删除选中句第 [localWordIndex] 个词；句中唯一词时删整句。
  void deleteWord(int localWordIndex) => editWord(localWordIndex, '');

  /// 在选中句第 [localWordIndex] 个词之前（[after] 为 false）或之后插入 [input]。
  ///
  /// 新词分到与相邻词之间的空隙；紧挨着没有空隙时与该词一起按字符比例分时间，
  /// 之后用户可在波形上拖动微调。
  void insertWords(int localWordIndex, String input, {required bool after}) {
    final selected = state.selectedSentenceIndex;
    if (selected == null) return;
    final tokens = _sentenceTokens(selected);
    final newTokens = _splitTokens(input);
    if (tokens == null ||
        newTokens.isEmpty ||
        localWordIndex < 0 ||
        localWordIndex >= tokens.length) {
      return;
    }
    final at = after ? localWordIndex + 1 : localWordIndex;
    _replaceSentenceTokens(selected, [
      for (var i = 0; i < at; i++) (tokens[i], i),
      for (final token in newTokens) (token, null),
      for (var i = at; i < tokens.length; i++) (tokens[i], i),
    ]);
  }

  /// 把第 [index] 句的文字整体改为 [text]。
  ///
  /// 逐词对比新旧文字：没改的词保留原时间，新增 / 改写的词在前后两个保留词之间按
  /// 字数分时间，删掉的词直接去掉。清空文字等同删除该句。
  void editSentenceText(int index, String text) {
    final tokens = _sentenceTokens(index);
    if (tokens == null) return;
    final newTokens = _splitTokens(text);
    if (listEquals(tokens, newTokens)) return;
    final matches = _engine.matchTokens(tokens, newTokens);
    _replaceSentenceTokens(index, [
      for (var i = 0; i < newTokens.length; i++) (newTokens[i], matches[i]),
    ]);
  }

  /// 第 [index] 句的文本 token；越界返回 null。
  List<String>? _sentenceTokens(int index) {
    if (index < 0 || index >= state.sentences.length) return null;
    return _splitTokens(state.sentences[index].text);
  }

  /// 用 [tokens] 替换第 [index] 句的文字并重新计算词时间。
  ///
  /// 每个新 token 带上它对应的旧 token 序号（null 表示新增或改写），对应到旧词的
  /// 保留原时间；句子起止跟随新的首 / 末词，避免 [_buildWords] 把首尾 snap 回旧
  /// 句界而改动其余词。结果为空时删除整句（仅剩一句时不删）。
  void _replaceSentenceTokens(int index, List<(String, int?)> tokens) {
    if (tokens.isEmpty) {
      deleteSentence(index);
      return;
    }
    final range = _sentenceTokenRange(index);
    if (range == null) return;
    final sentence = state.sentences[index];
    final retimed = _engine.retimeTokens(
      oldWords: _sentenceWords(index),
      newTokens: [for (final (token, _) in tokens) token],
      matches: [for (final (_, match) in tokens) match],
      sentenceStart: sentence.startTime,
      sentenceEnd: sentence.endTime,
    );
    final words = List<WordTimestamp>.of(state.words)
      ..replaceRange(range.offset, range.offset + range.count, retimed);
    final sentences = [...state.sentences];
    sentences[index] = sentence.copyWith(
      text: retimed.map((word) => word.word).join(' '),
      startTime: retimed.first.startTime,
      endTime: retimed.last.endTime,
    );

    _recordHistory();
    _cancelPlaybackSession();
    _commitEdit(
      state.copyWith(
        sentences: sentences,
        words: _buildWords(sentences, words),
        focusedWordIndex: null,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
      ),
    );
  }

  /// 第 [index] 句之前 / 之后可插入新句的区间；空隙不足时为 null（入口置灰）。
  SentenceSlot? insertSlotNear(int index, {required bool after}) {
    return after
        ? _engine.slotAfter(state.sentences, index, _insertableDuration())
        : _engine.slotBefore(state.sentences, index);
  }

  /// 暂停时播放头所在空隙可插入新句的区间；播放中或播放头在某句之内时为 null。
  SentenceSlot? get insertSlotAtPlayhead {
    if (state.isPlaying || state.isLoading) return null;
    return _engine.slotAt(
      state.sentences,
      state.playbackPosition,
      _insertableDuration(),
    );
  }

  Duration _insertableDuration() =>
      _effectiveTotalDuration() ??
      (state.sentences.isEmpty ? Duration.zero : state.sentences.last.endTime);

  /// 在 [slot] 处插入文字为 [text] 的新句并选中它；文字为空时不插入。
  void insertSentence(SentenceSlot slot, String text) {
    final tokens = _splitTokens(text);
    if (tokens.isEmpty || slot.end <= slot.start) return;
    final inserted = _engine.insertSentence(state.sentences, slot, text);
    final index = inserted.index;
    // 新句的词插在它前面各句的词之后，其余词时间不变。
    final offset = index < state.sentences.length
        ? _sentenceTokenRange(index)?.offset
        : state.words.length;
    if (offset == null) return;
    final words = List<WordTimestamp>.of(state.words)
      ..insertAll(
        offset,
        SubtitleEditEngine.distributeTokens(tokens, slot.start, slot.end),
      );

    _recordHistory();
    _cancelPlaybackSession();
    _commitEdit(
      state.copyWith(
        sentences: inserted.sentences,
        words: _buildWords(inserted.sentences, words),
        selectedSentenceIndex: index,
        selectionEpoch: state.selectionEpoch + 1,
        playbackPosition: slot.start,
        focusedWordIndex: null,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
      ),
    );
    AppLogger.log(
      'SubtitleEditor',
      '插入新句 index=$index range=${slot.start.inMilliseconds}-'
          '${slot.end.inMilliseconds}ms',
    );
  }

  /// 把选中句从第 [localWordIndex] 个词处分成两句（剪刀分句时调用）。
  ///
  /// 该词成为新句（后半）的首词；前半保留原起点、终点贴前一词终点，后半起点贴该词
  /// 起点、保留原终点。首词（[localWordIndex] == 0）不允许分句（会产生空句）。
  /// 词数不变 → [_buildWords] 按序对齐保留已编辑时间。
  void splitSentenceAtWord(int localWordIndex) {
    final selected = state.selectedSentenceIndex;
    if (selected == null ||
        selected < 0 ||
        selected >= state.sentences.length) {
      return;
    }
    final sentence = state.sentences[selected];
    final tokens = _splitTokens(sentence.text);
    final view = _sentenceWords(selected);
    if (localWordIndex < 1 || localWordIndex >= tokens.length) return;
    if (localWordIndex >= view.length) return;

    final next = _engine.splitSentence(
      state.sentences,
      selected,
      firstText: tokens.sublist(0, localWordIndex).join(' '),
      firstEnd: view[localWordIndex - 1].endTime,
      secondText: tokens.sublist(localWordIndex).join(' '),
      secondStart: view[localWordIndex].startTime,
    );
    if (identical(next, state.sentences)) return;
    _recordHistory();
    _cancelPlaybackSession();
    _commitEdit(
      state.copyWith(
        sentences: next,
        selectedSentenceIndex: selected,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
        playbackPosition: next[selected].startTime,
        focusedWordIndex: null,
        words: _buildWords(next, state.words),
      ),
    );
  }

  /// 播放选中句内第 [wordIndex] 个词，并把它标记为「点中词」以显示词边界。
  ///
  /// 复用区间播放基元（[SubtitleEditorAudioPlayer.playRange]）、session 隔离与播放头计时器，
  /// 与 [playSentence] 同源。索引越界时钳到合法范围（label 与词数偶尔不一致时兜底）。
  /// 播放结束后保留 [SubtitleEditorState.focusedWordIndex]，便于用户继续查看边界。
  ///
  /// [movesPlayhead] 为 false 时只试听（[SubtitleEditorPlaybackMode.wordAudition]）：
  /// 不启动播放头计时器、不采纳位置流，播放头始终停在原处。
  Future<void> playWord(int wordIndex, {bool movesPlayhead = true}) async {
    final words = wordsOfSelectedSentence;
    if (words.isEmpty) return;
    final index = wordIndex.clamp(0, words.length - 1);
    final word = words[index];
    await _stopActivePlayback(invalidateSession: true);
    final sessionId = _audioPlayer.newSession();
    if (movesPlayhead) {
      _startPlayheadTicker(
        sessionId: sessionId,
        start: word.startTime,
        end: word.endTime,
      );
    }
    state = state.copyWith(
      focusedWordIndex: index,
      // 改为播放单个词，清空「正在播放的句子」，让句子行从停止按钮恢复为播放按钮。
      playingSentenceIndex: null,
      isPlaying: true,
      playbackMode: movesPlayhead
          ? SubtitleEditorPlaybackMode.word
          : SubtitleEditorPlaybackMode.wordAudition,
      playbackPosition: movesPlayhead ? word.startTime : null,
    );
    try {
      await _audioPlayer.setSpeed(state.playbackSpeed);
      await _audioPlayer.playRange(word.startTime, word.endTime, sessionId);
    } finally {
      if (mounted && _audioPlayer.isActiveSession(sessionId)) {
        // 同 playSentence：先冻结状态再停底层播放器，避免停止过程中的残留位置
        // 事件移动播放头。保留 focusedWordIndex 让词边界继续显示。
        state = state.copyWith(
          isPlaying: false,
          playbackMode: SubtitleEditorPlaybackMode.idle,
          playbackPosition: movesPlayhead ? word.endTime : null,
        );
        // 本会话自己播完，必须停掉底层播放器并撤销区间终点：只试听时没有播放头
        // 计时器，_stopActivePlayback 会误判为「无播放」而跳过停止。
        _cancelPlayheadTicker();
        await _audioPlayer.stop();
      }
    }
  }

  Future<void> playSentence(int index) async {
    if (index < 0 || index >= state.sentences.length) return;
    await _stopActivePlayback(invalidateSession: true);
    final sentence = state.sentences[index];
    final sessionId = _audioPlayer.newSession();
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
      // 播放整句而非某个词，退出词聚焦态。
      focusedWordIndex: null,
    );
    try {
      await _audioPlayer.setSpeed(state.playbackSpeed);
      await _audioPlayer.playRange(
        sentence.startTime,
        sentence.endTime,
        sessionId,
      );
    } finally {
      if (mounted && _audioPlayer.isActiveSession(sessionId)) {
        // ⚠️ 关键顺序：必须「先冻结状态（isPlaying=false + 锁定句尾位置）再停底层
        // 播放器」。否则停止过程中的残留位置事件会在 isPlaying 仍为 true 时被
        // _handlePosition 采纳，移动播放头 —— 即「播放完跳回到前面」。
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
      // 切换选中句，清空上一句的词聚焦态。
      focusedWordIndex: null,
    );
  }

  /// 定位播放头（点按波形或拖动播放头）。播放中定位先停止播放，画面与高亮的
  /// 单词停在新位置。
  void scrubTo(Duration position) {
    if (state.isPlaying) unawaited(stopPlayback());
    state = state.copyWith(
      selectedSentenceIndex: _sentenceIndexAt(position),
      playbackPosition: _clampToDuration(position),
      focusedWordIndex: null,
    );
  }

  Future<void> finishScrub(Duration position) async {
    final clamped = _clampToDuration(position);
    if (state.isPlaying) {
      await stopPlayback();
    }
    scrubTo(clamped);
    await _audioPlayer.seek(clamped);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final next = speed.clamp(0.5, 2.0).toDouble();
    final currentPosition = state.playbackPosition;
    state = state.copyWith(playbackSpeed: next);
    if (state.isPlaying) {
      _calibratePlayhead(currentPosition);
      await _audioPlayer.setSpeed(next);
    }
  }

  void setWaveformZoomScale(double scale) {
    state = state.copyWith(
      waveformZoomScale: scale
          .clamp(1.0, state.maxWaveformZoomScale)
          .toDouble(),
    );
  }

  /// 进入编辑页时按屏幕物理宽度自动计算缩放范围与初始缩放。
  ///
  /// Flutter 逻辑像素以 160px/英寸 为基准，故 1 厘米 ≈ 63 逻辑像素。缩放语义：
  /// `zoom == 1` 时整段音频铺满可视区；最大缩放时 1 秒音频约占 5cm 屏幕长度，
  /// 因此上限 = `音频秒数 × 5cm逻辑像素 / 可视区宽度`。
  ///
  /// 初始缩放仍保持每 1cm 屏幕约显示 1 秒音频，最大缩放提供 5 倍精调空间。
  /// 仅在首次进入时执行一次，之后用户可通过滑块手动调整。
  void initZoomForViewport(double usableViewportWidth) {
    if (_didInitZoom) return;
    final seconds = (state.totalDuration?.inMilliseconds ?? 0) / 1000;
    if (usableViewportWidth <= 0 || seconds <= 0) return;
    _didInitZoom = true;
    final initialScale = _logicalPixelsPerCm * seconds / usableViewportWidth;
    final maxScale = initialScale * _maxZoomCentimetersPerSecond;
    state = state.copyWith(
      maxWaveformZoomScale: maxScale.clamp(1.0, double.infinity).toDouble(),
      waveformZoomScale: initialScale
          .clamp(1.0, maxScale.clamp(1.0, double.infinity))
          .toDouble(),
    );
  }

  void mergeWithNext(int index) {
    final next = _engine.mergeWithNext(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _recordHistory();
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterMerge(
      selectedIndex: state.selectedSentenceIndex,
      mergeIndex: index,
    );
    _commitEdit(
      state.copyWith(
        sentences: next,
        selectedSentenceIndex: selectedIndex,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
        playbackPosition: _positionForSelected(next, selectedIndex),
        focusedWordIndex: null,
        // 合并不增减词，词数不变 → 顺序索引对齐，保留已编辑的词级时间。
        words: _buildWords(next, state.words),
      ),
    );
  }

  void deleteSentence(int index) {
    final next = _engine.deleteSentence(state.sentences, index);
    if (identical(next, state.sentences)) return;
    _recordHistory();
    _cancelPlaybackSession();
    final selectedIndex = _indexAfterDelete(
      selectedIndex: state.selectedSentenceIndex,
      deletedIndex: index,
      nextLength: next.length,
    );
    // 删除被删句对应的词切片，使剩余词与新文本 token 仍按序对齐、保留已编辑时间。
    final range = _sentenceTokenRange(index);
    final trimmedWords = range == null
        ? state.words
        : (List<WordTimestamp>.of(state.words)
            ..removeRange(range.offset, range.offset + range.count));
    _commitEdit(
      state.copyWith(
        sentences: next,
        selectedSentenceIndex: selectedIndex,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
        playbackPosition: _positionForSelected(next, selectedIndex),
        focusedWordIndex: null,
        words: _buildWords(next, trimmedWords),
      ),
    );
  }

  /// 撤销上一步编辑：还原字幕与词时间，并选中当时编辑的句子、让波形居中到它，
  /// 让用户看到撤销了什么。
  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restoreSnapshot(_undoStack.removeLast(), action: '撤销');
  }

  /// 重做最近一次撤销的编辑。
  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restoreSnapshot(_redoStack.removeLast(), action: '重做');
  }

  _EditSnapshot _snapshot() => (
    sentences: state.sentences,
    words: state.words,
    selectedSentenceIndex: state.selectedSentenceIndex,
  );

  /// 记录编辑前的状态作为撤销点；新的编辑会清空重做栈。
  void _recordHistory() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _maxHistoryLength) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restoreSnapshot(_EditSnapshot snapshot, {required String action}) {
    _cancelPlaybackSession();
    _hasRecordedAdjust = false;
    final sentences = snapshot.sentences;
    final selected = sentences.isEmpty
        ? null
        : (snapshot.selectedSentenceIndex ?? 0).clamp(0, sentences.length - 1);
    _commitEdit(
      state.copyWith(
        sentences: sentences,
        words: snapshot.words,
        selectedSentenceIndex: selected,
        selectionEpoch: state.selectionEpoch + 1,
        playbackPosition: _positionForSelected(sentences, selected),
        focusedWordIndex: null,
        playingSentenceIndex: null,
        isPlaying: false,
        playbackMode: SubtitleEditorPlaybackMode.idle,
      ),
    );
    AppLogger.log(
      'SubtitleEditor',
      '$action selected=$selected undo=${_undoStack.length} '
          'redo=${_redoStack.length}',
    );
  }

  /// 写入一次编辑结果：按与基线的比较重算 dirty，并同步撤销 / 重做可用态。
  void _commitEdit(SubtitleEditorState next) {
    state = next.copyWith(
      isDirty: _isDirty(next.sentences, next.words),
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  /// 字幕或词级时间是否相对基线（进入编辑页或上次保存）发生了实质变化。
  bool _isDirty(List<Sentence> sentences, List<WordTimestamp> words) {
    if (_sentencesChanged(sentences)) return true;
    if (words.length != _baselineWords.length) return true;
    for (var i = 0; i < words.length; i++) {
      final a = words[i];
      final b = _baselineWords[i];
      if (a.word != b.word ||
          a.startTime != b.startTime ||
          a.endTime != b.endTime) {
        return true;
      }
    }
    return false;
  }

  Future<bool> save() async {
    if (!state.isDirty || state.isSaving) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await stopPlayback();

      final item = state.audioItem;
      // 先取出依赖：保存期间页面可能被关闭（控制器随之释放），之后不能再读 ref。
      // 字幕一旦落库，必须完成学习数据同步。
      final dao = _ref.read(audioItemDaoProvider);
      final transcriptSync = _ref.read(transcriptChangeSyncProvider);
      final library = _ref.read(audioLibraryProvider.notifier);
      final practice = _ref.read(listeningPracticeProvider.notifier);
      final isPracticeHoldingItem =
          _ref.read(listeningPracticeProvider).currentAudioItem?.id == item.id;

      final srt = _generateSrt(state.sentences);

      // 词级字幕：直接落编辑后的词列表（加载时按句子文本 token 物化、可被拖动编辑），
      // 每句首尾词贴合句子边界，与句子 SRT 保持一致。句子与词级字幕同时更新。
      final words = _wordsSnappedToSentences();
      final syncedWordsJson = encodeWordTimestamps(words);
      final sentencesSnapshot = state.sentences;
      final wordsSnapshot = state.words;

      // 字幕内容（+ 词级时间戳）原子写入 DB 列。
      await dao.saveTranscriptContent(
        item.id,
        srt: srt,
        wordTimestampsJson: syncedWordsJson,
      );

      // 收藏改写为新字幕中对应的句子，学习断点按时间换算。
      // 以落库的 SRT 重新解析，保证与各读取路径看到的句子完全一致。
      final savedSentences = await SubtitleParser.parseSubtitleString(srt);
      await transcriptSync.apply(
        item.id,
        oldSentences: _baselineSentences,
        newSentences: savedSentences,
      );
      // 同步成功后立即推进基线：之后的步骤失败时重试保存，不会把已换算过的
      // 学习断点按旧基线再换算一次。
      _baselineSentences = savedSentences;
      _baselineSubtitleHash = _subtitleHash(sentencesSnapshot);
      _baselineWords = wordsSnapshot;

      final wordCount = words.isNotEmpty
          ? words.length
          : sentencesSnapshot.fold<int>(
              0,
              (sum, sentence) => sum + _countWords(sentence.text),
            );
      final updatedItem = item.copyWith(
        transcriptPath: null,
        sentenceCount: sentencesSnapshot.length,
        wordCount: wordCount,
      );
      await library.updateAudioItem(updatedItem);

      if (isPracticeHoldingItem) {
        // 字幕保存只改 DB transcript_srt 列，id / transcriptPath 不变（都为 null）。
        // loadAudio 的去重守卫只比较 id + transcriptPath，不带 force 会命中守卫
        // 直接跳过重新解析，使 keepAlive 的 LP 保留旧句子（自由练习/盲听显示陈旧
        // 拆分版本）。必须强制重载以绕过守卫，从 DB 列读到最新内容。
        await practice.loadAudio(updatedItem, forceTranscriptReload: true);
      }

      if (!mounted) return true;
      state = state.copyWith(
        isSaving: false,
        isDirty: _isDirty(state.sentences, state.words),
        audioItem: updatedItem,
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.log('SubtitleEditor', '保存失败 error=$e\n$stackTrace');
      if (mounted) {
        // 保持可保存：重试会重写字幕并补完未完成的步骤（学习数据同步可重复执行）。
        state = state.copyWith(
          isSaving: false,
          isDirty: true,
          errorMessage: e.toString(),
        );
      }
      return false;
    }
  }

  void _handlePosition(Duration position) {
    if (!mounted ||
        !state.isPlaying ||
        state.playbackMode == SubtitleEditorPlaybackMode.wordAudition) {
      return;
    }
    if (position < _playbackStart ||
        position > _playbackEnd + const Duration(milliseconds: 250)) {
      return;
    }
    // 防御：播放期间播放头由本地时钟（_tickPlayhead）单调前进，position 流仅做校准。
    // 大幅「后退」几乎只可能是停止 / 换区间前的残留事件，直接丢弃，避免把播放头
    // 拉回。允许 ≤400ms 的正常校准抖动。
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
    _audioPlayer.newSession();
    _cancelPlayheadTicker();
    unawaited(_audioPlayer.stop());
  }

  Future<void> _stopActivePlayback({required bool invalidateSession}) async {
    final shouldStop =
        state.isPlaying ||
        state.playingSentenceIndex != null ||
        _activePlaybackSessionId != null;
    if (invalidateSession) {
      _audioPlayer.newSession();
    }
    _cancelPlayheadTicker();
    if (shouldStop) await _audioPlayer.stop();
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
        !_audioPlayer.isActiveSession(sessionId)) {
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

  /// 进行中的波形提取；非 null 时不重复提取，离开页面时取消（同时终止抽音轨的 ffmpeg）。
  MediaTrimCancellation? _waveformCancellation;

  /// 重新尝试提取波形（失败态下用户点「重试」）。
  Future<void> retryWaveform() async {
    if (_waveformCancellation != null) return;
    state = state.copyWith(
      waveformFailed: false,
      waveformAudioMissing: false,
      waveformProgress: 0,
    );
    await _loadWaveform();
  }

  /// 提取波形，与剪辑页共用加载器和 `waveforms/{id}.wave` 缓存。
  ///
  /// 加载器用 FFmpeg 解码，不经系统解码器（iOS/macOS 的 ExtAudioFile 读不了
  /// mkv/avi 等容器）。解码失败置失败态，不阻断字幕编辑。
  Future<void> _loadWaveform() async {
    if (_waveformCancellation != null) return;
    final cancellation = MediaTrimCancellation();
    _waveformCancellation = cancellation;
    try {
      final audioPath = await state.audioItem.getFullAudioPath();
      if (audioPath == null) {
        if (mounted) state = state.copyWith(waveformAudioMissing: true);
        return;
      }
      final waveform = await _ref
          .read(mediaTrimWaveformLoaderProvider)
          .load(
            source: state.audioItem,
            mediaPath: audioPath,
            mediaDuration: state.totalDuration,
            cancellation: cancellation,
            onProgress: (progress) {
              if (mounted) state = state.copyWith(waveformProgress: progress);
            },
            onPartial: (partial) {
              if (mounted) state = state.copyWith(waveform: partial);
            },
          );
      if (!mounted) return;
      state = state.copyWith(
        waveform: waveform,
        waveformProgress: 1,
        waveformAudioMissing: false,
      );
    } on Object catch (error) {
      if (!mounted || cancellation.isCancelled) return;
      AppLogger.log(
        'SubtitleEditor',
        '波形提取失败 audio=${state.audioItem.id} video=${state.audioItem.isVideo} '
            'error=$error',
      );
      state = state.copyWith(waveformFailed: true);
    } finally {
      if (identical(_waveformCancellation, cancellation)) {
        _waveformCancellation = null;
      }
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
    unawaited(_waveformCancellation?.cancel());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_waveform/just_waveform.dart';

import '../../models/audio_item.dart';
import '../../models/word_timestamp.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/media_playback/media_playback_provider.dart';
import '../../services/app_logger.dart';
import '../../services/media_player_backend.dart';
import 'media_trim_clip.dart';
import 'media_trim_exporter.dart';
import 'media_trim_processor.dart';
import 'media_trim_repository.dart';
import 'media_trim_waveform_loader.dart';

/// 进入剪辑页时暂停其它正在出声的播放链路；测试替换为空实现。
final mediaTrimPauseOtherPlaybackProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    if (ref.read(mediaEngineProvider.notifier).isPlaying) {
      await ref.read(mediaPlaybackProvider.notifier).pause();
    }
    final audioEngine = ref.read(audioEngineProvider.notifier);
    if (audioEngine.isPlaying) await audioEngine.pause();
  },
);

final mediaTrimEditorProvider = NotifierProvider.autoDispose
    .family<MediaTrimEditorController, MediaTrimEditorState, AudioItem>(
      MediaTrimEditorController.new,
    );

enum MediaTrimLoadStatus { loading, ready, failed }

/// 最近一次试听目标；与 isPlaying 一起决定哪个按钮显示停止态。
sealed class MediaTrimPreview {
  const MediaTrimPreview();
}

class MediaTrimFreePreview extends MediaTrimPreview {
  const MediaTrimFreePreview();
}

class MediaTrimClipPreview extends MediaTrimPreview {
  const MediaTrimClipPreview(this.clipId);
  final int clipId;
}

class MediaTrimSentencePreview extends MediaTrimPreview {
  const MediaTrimSentencePreview(this.sentenceIndex);
  final int sentenceIndex;
}

class MediaTrimEditorState {
  const MediaTrimEditorState({
    required this.sourceName,
    this.status = MediaTrimLoadStatus.loading,
    this.loadFailure,
    this.boundaries,
    this.clips = const [],
    this.selectedClipId,
    this.revealSerial = 0,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.preview,
    this.videoAspectRatio,
    this.waveform,
    this.waveformProgress = 0,
    this.isWaveformFailed = false,
    this.isDirty = false,
    this.saveProgress,
    this.isCancellingSave = false,
    this.notice,
    this.noticeSerial = 0,
  });

  final String sourceName;
  final MediaTrimLoadStatus status;
  final MediaTrimFailure? loadFailure;

  /// 加载完成后才有值，包含媒体总时长与字幕。
  final MediaTrimBoundaries? boundaries;

  /// 按起点排序；序号与默认名称都由排序位置决定。
  final List<MediaTrimClip> clips;

  /// 选中片段后，播放头只能在片段内移动；取消选中后才能自由定位。
  final int? selectedClipId;

  /// 每次选中（含重复选中当前片段）递增，时间轴据此把当前片段滚入视口。
  final int revealSerial;
  final Duration position;
  final bool isPlaying;
  final MediaTrimPreview? preview;
  final double? videoAspectRatio;
  final Waveform? waveform;
  final double waveformProgress;
  final bool isWaveformFailed;
  final bool isDirty;

  /// 非 null 表示正在保存。
  final MediaTrimExportProgress? saveProgress;
  final bool isCancellingSave;

  /// 需要即时提示用户的失败（如播放失败）；[noticeSerial] 变化时界面提示一次。
  final MediaTrimFailure? notice;
  final int noticeSerial;

  bool get isSaving => saveProgress != null;

  MediaTrimClip? get selectedClip {
    for (final clip in clips) {
      if (clip.id == selectedClipId) return clip;
    }
    return null;
  }

  String clipName(MediaTrimClip clip) {
    final custom = clip.customName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final number = clips.indexWhere((c) => c.id == clip.id) + 1;
    return '$sourceName · ${number.toString().padLeft(2, '0')}';
  }

  MediaTrimEditorState copyWith({
    MediaTrimLoadStatus? status,
    MediaTrimFailure? loadFailure,
    MediaTrimBoundaries? boundaries,
    List<MediaTrimClip>? clips,
    int? selectedClipId,
    bool clearSelectedClip = false,
    int? revealSerial,
    Duration? position,
    bool? isPlaying,
    MediaTrimPreview? preview,
    double? videoAspectRatio,
    Waveform? waveform,
    double? waveformProgress,
    bool? isWaveformFailed,
    bool? isDirty,
    MediaTrimExportProgress? saveProgress,
    bool clearSaveProgress = false,
    bool? isCancellingSave,
    MediaTrimFailure? notice,
    int? noticeSerial,
  }) => MediaTrimEditorState(
    sourceName: sourceName,
    status: status ?? this.status,
    loadFailure: loadFailure ?? this.loadFailure,
    boundaries: boundaries ?? this.boundaries,
    clips: clips ?? this.clips,
    selectedClipId: clearSelectedClip
        ? null
        : (selectedClipId ?? this.selectedClipId),
    revealSerial: revealSerial ?? this.revealSerial,
    position: position ?? this.position,
    isPlaying: isPlaying ?? this.isPlaying,
    preview: preview ?? this.preview,
    videoAspectRatio: videoAspectRatio ?? this.videoAspectRatio,
    waveform: waveform ?? this.waveform,
    waveformProgress: waveformProgress ?? this.waveformProgress,
    isWaveformFailed: isWaveformFailed ?? this.isWaveformFailed,
    isDirty: isDirty ?? this.isDirty,
    saveProgress: clearSaveProgress
        ? null
        : (saveProgress ?? this.saveProgress),
    isCancellingSave: isCancellingSave ?? this.isCancellingSave,
    notice: notice ?? this.notice,
    noticeSerial: noticeSerial ?? this.noticeSerial,
  );
}

/// 剪辑编辑器：独占一个前台播放器，不接入学习计时和系统媒体会话。
class MediaTrimEditorController extends Notifier<MediaTrimEditorState> {
  MediaTrimEditorController(this.source);

  final AudioItem source;

  late final MediaPlayerBackend _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<WordTimestamp> _words = const [];
  String? _mediaPath;
  int _nextClipId = 1;
  bool _isDisposed = false;

  /// 每次试听请求递增；异步步骤之间比对，丢弃被新操作取代的旧请求。
  int _previewGeneration = 0;

  /// 拖动播放头期间界面直接跟手，播放器只追最新目标；期间忽略播放器回报的位置，
  /// 避免排队中的旧 seek 让播放头来回跳。
  bool _isScrubbing = false;
  bool _isScrubSeeking = false;
  Duration? _pendingScrubTarget;
  MediaTrimCancellation? _saveCancellation;
  MediaTrimCancellation? _waveformCancellation;

  @override
  MediaTrimEditorState build() {
    _player = ref.read(mediaBackendFactoryProvider)();
    ref.onDispose(_dispose);
    unawaited(Future.microtask(_load));
    return MediaTrimEditorState(sourceName: source.name);
  }

  Widget buildVideoView(Size viewportSize) =>
      _player.buildVideoView(viewportSize: viewportSize);

  Future<void> _load() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 每次 await 后都检查页面是否已关闭：已销毁的 ref 不能再读取 provider。
      await ref.read(mediaTrimPauseOtherPlaybackProvider)();
      if (_isDisposed) return;
      final repository = ref.read(mediaTrimRepositoryProvider);
      final processor = ref.read(mediaTrimProcessorProvider);
      final path = await source.getFullAudioPath();
      if (path == null || !await File(path).exists()) {
        throw const MediaTrimException(MediaTrimFailure.sourceMissing);
      }
      final (sentences, words) = await repository.loadTranscript(source);
      final info = await processor.probe(path);
      if (_isDisposed) return;
      for (final sentence in sentences) {
        if (sentence.startTime < Duration.zero ||
            sentence.endTime <= sentence.startTime ||
            sentence.endTime > info.duration) {
          throw const MediaTrimException(MediaTrimFailure.transcriptOutOfRange);
        }
      }
      _words = words;
      _mediaPath = path;
      await _player.open(path);
      if (_isDisposed) return;
      _subscriptions
        ..add(
          _player.positionStream.listen((position) {
            if (_isDisposed || _isScrubbing || _isScrubSeeking) return;
            state = state.copyWith(position: position);
          }),
        )
        ..add(
          // 不在暂停时清空 preview：试听开始前会先暂停，清空会丢失刚设置的试听目标。
          // 界面以 isPlaying && preview 判断试听状态。
          _player.playingStream.listen((isPlaying) {
            if (!_isDisposed) state = state.copyWith(isPlaying: isPlaying);
          }),
        )
        ..add(
          _player.videoAspectRatioStream.listen((ratio) {
            if (ratio != null && !_isDisposed) {
              state = state.copyWith(videoAspectRatio: ratio);
            }
          }),
        );
      final boundaries = MediaTrimBoundaries(
        total: info.duration,
        sentences: sentences,
      );
      state = state.copyWith(
        status: MediaTrimLoadStatus.ready,
        boundaries: boundaries,
        videoAspectRatio: _player.videoAspectRatio,
      );
      AppLogger.log(
        'MediaTrim',
        '剪辑页加载完成 source=${source.id} video=${source.isVideo} '
            'duration=${info.duration.inMilliseconds}ms '
            'sentences=${sentences.length} spans=${boundaries.spans.length} '
            'cost=${stopwatch.elapsedMilliseconds}ms',
      );
      unawaited(loadWaveform());
    } on MediaTrimException catch (error) {
      _failLoad(error.failure, error);
    } on Object catch (error, stackTrace) {
      _failLoad(MediaTrimFailure.unexpected, '$error\n$stackTrace');
    }
  }

  void _failLoad(MediaTrimFailure failure, Object detail) {
    AppLogger.log('MediaTrim', '剪辑页加载失败 source=${source.id} reason=$detail');
    if (_isDisposed) return;
    state = state.copyWith(
      status: MediaTrimLoadStatus.failed,
      loadFailure: failure,
    );
  }

  Future<void> loadWaveform() async {
    final path = _mediaPath;
    if (path == null || _waveformCancellation != null) return;
    final cancellation = MediaTrimCancellation();
    _waveformCancellation = cancellation;
    state = state.copyWith(isWaveformFailed: false, waveformProgress: 0);
    try {
      final waveform = await ref
          .read(mediaTrimWaveformLoaderProvider)
          .load(
            source: source,
            mediaPath: path,
            cancellation: cancellation,
            onProgress: (progress) {
              if (!_isDisposed) {
                state = state.copyWith(waveformProgress: progress);
              }
            },
          );
      if (_isDisposed) return;
      state = state.copyWith(waveform: waveform, waveformProgress: 1);
    } on Object catch (error) {
      if (_isDisposed || cancellation.isCancelled) return;
      AppLogger.log('MediaTrim', '波形加载失败 source=${source.id} reason=$error');
      state = state.copyWith(isWaveformFailed: true);
    } finally {
      if (identical(_waveformCancellation, cancellation)) {
        _waveformCancellation = null;
      }
    }
  }

  // ── 播放 ──

  /// 片段试听时，播放头距终点不足该值视为已播完，下次从片段起点开始。
  static const Duration _clipTailThreshold = Duration(milliseconds: 300);

  /// 播放 / 暂停。选中片段时只播放该片段；未选中时从播放头自由播放。
  Future<void> togglePlayback() async {
    if (state.isPlaying) return pause();
    final clip = state.selectedClip;
    if (clip != null) return _playClip(clip);
    final total = state.boundaries?.total;
    var from = state.position;
    if (total != null && total - from < const Duration(milliseconds: 100)) {
      from = Duration.zero;
    }
    await _startPlayback(
      from: from,
      end: null,
      preview: const MediaTrimFreePreview(),
    );
  }

  Future<void> toggleClipPreview(int clipId) async {
    final preview = state.preview;
    if (state.isPlaying &&
        preview is MediaTrimClipPreview &&
        preview.clipId == clipId) {
      return pause();
    }
    if (state.selectedClipId != clipId) selectClip(clipId);
    final clip = _clipById(clipId);
    if (clip == null) return;
    await _playClip(clip);
  }

  /// 试听片段：播放头在片段内且未到末尾时从播放头继续，否则从片段起点开始。
  /// 选中片段时播放头会回到起点，所以没有手动移动播放头时总是从头试听；
  /// 手动拖到后段后则从该处开始，便于快速确认结尾是否准确。
  Future<void> _playClip(MediaTrimClip clip) {
    final position = state.position;
    final canResume =
        position >= clip.start && clip.end - position > _clipTailThreshold;
    return _startPlayback(
      from: canResume ? position : clip.start,
      end: clip.end,
      preview: MediaTrimClipPreview(clip.id),
    );
  }

  /// 试听单句。句子可以在当前片段之外，这是播放头唯一可以离开选中片段的情况；
  /// 之后再播放片段会因播放头不在片段内而从片段起点开始。
  Future<void> toggleSentencePreview(int sentenceIndex) async {
    final preview = state.preview;
    if (state.isPlaying &&
        preview is MediaTrimSentencePreview &&
        preview.sentenceIndex == sentenceIndex) {
      return pause();
    }
    final sentence = state.boundaries?.sentences[sentenceIndex];
    if (sentence == null) return;
    await _startPlayback(
      from: sentence.startTime,
      end: sentence.endTime,
      preview: MediaTrimSentencePreview(sentenceIndex),
    );
  }

  Future<void> _startPlayback({
    required Duration from,
    required Duration? end,
    required MediaTrimPreview preview,
  }) async {
    if (state.isSaving) return;
    final generation = ++_previewGeneration;
    state = state.copyWith(preview: preview, position: from);
    try {
      await _player.pause();
      if (_isStale(generation)) return;
      await _player.setPlaybackEnd(end);
      if (_isStale(generation)) return;
      await _player.seek(from);
      if (_isStale(generation)) return;
      await _player.play();
    } on Object catch (error) {
      _reportPlaybackFailure(error);
    }
  }

  Future<void> pause() async {
    ++_previewGeneration;
    try {
      await _player.pause();
    } on Object catch (error) {
      _reportPlaybackFailure(error);
    }
  }

  /// 定位播放头（选中片段时钳在片段内）。正在播放时从新位置继续，
  /// 选中片段时仍以片段终点为界。
  Future<void> seek(Duration position) async {
    final target = _clampToSelection(position);
    final clip = state.selectedClip;
    final generation = ++_previewGeneration;
    state = state.copyWith(
      position: target,
      preview: state.isPlaying
          ? (clip == null
                ? const MediaTrimFreePreview()
                : MediaTrimClipPreview(clip.id))
          : null,
    );
    try {
      await _player.setPlaybackEnd(state.isPlaying ? clip?.end : null);
      if (_isStale(generation)) return;
      await _player.seek(target);
    } on Object catch (error) {
      _reportPlaybackFailure(error);
    }
  }

  Future<void> seekBy(Duration delta) => seek(state.position + delta);

  /// 拖动播放头：暂停播放，界面立即跟手，播放器只追最新目标。
  void scrub(Duration position) {
    if (state.isSaving) return;
    if (!_isScrubbing) {
      _isScrubbing = true;
      if (state.isPlaying) unawaited(pause());
    }
    final target = _clampToSelection(position);
    state = state.copyWith(position: target);
    _pendingScrubTarget = target;
    if (!_isScrubSeeking) unawaited(_drainScrubSeeks());
  }

  void endScrub() {
    _isScrubbing = false;
  }

  Future<void> _drainScrubSeeks() async {
    _isScrubSeeking = true;
    try {
      while (_pendingScrubTarget != null && !_isDisposed) {
        final target = _pendingScrubTarget!;
        _pendingScrubTarget = null;
        await _player.seek(target);
      }
    } on Object catch (error) {
      _reportPlaybackFailure(error);
    } finally {
      _isScrubSeeking = false;
    }
  }

  Duration _clampToSelection(Duration time) {
    final clip = state.selectedClip;
    final low = clip?.start ?? Duration.zero;
    final high = clip?.end ?? state.boundaries?.total ?? Duration.zero;
    if (time < low) return low;
    return time > high ? high : time;
  }

  bool _isStale(int generation) =>
      _isDisposed || generation != _previewGeneration;

  void _reportPlaybackFailure(Object error) {
    AppLogger.log('MediaTrim', '试听失败 source=${source.id} reason=$error');
    if (_isDisposed) return;
    state = state.copyWith(
      notice: MediaTrimFailure.playbackFailed,
      noticeSerial: state.noticeSerial + 1,
    );
  }

  /// 编辑范围、切换片段或保存时，让进行中的试听失效。
  void _invalidatePreview() {
    ++_previewGeneration;
    if (state.isPlaying && state.preview is! MediaTrimFreePreview) {
      unawaited(pause());
    }
  }

  // ── 片段编辑 ──

  /// 选中片段，播放头移到片段起点（从时间轴点选时移到点按处）。
  /// 重复选中当前片段时只让时间轴重新显示它，不改动播放头。
  void selectClip(int clipId, {Duration? at}) {
    if (state.isSaving) return;
    final clip = _clipById(clipId);
    if (clip == null) return;
    if (state.selectedClipId == clipId) {
      state = state.copyWith(revealSerial: state.revealSerial + 1);
      if (at != null) unawaited(seek(at));
      return;
    }
    _invalidatePreview();
    if (state.isPlaying) unawaited(pause());
    state = state.copyWith(
      selectedClipId: clipId,
      revealSerial: state.revealSerial + 1,
    );
    unawaited(seek(at ?? clip.start));
  }

  /// 取消选中，播放头恢复自由定位。
  void clearSelection() {
    if (state.isSaving || state.selectedClipId == null) return;
    _invalidatePreview();
    state = state.copyWith(clearSelectedClip: true);
  }

  /// 从播放头往后找空白处新建片段（规则见 [MediaTrimBoundaries.rangeInGap]）。
  /// 没有足够长的空白时返回 false，由界面提示。
  bool addClipInGap() {
    final boundaries = state.boundaries;
    if (boundaries == null || state.isSaving) return false;
    final range = boundaries.rangeInGap(state.clips, state.position);
    if (range == null) {
      AppLogger.log(
        'MediaTrim',
        '新建片段失败：没有足够长的空白 clips=${state.clips.length} '
            'position=${state.position.inMilliseconds}ms',
      );
      return false;
    }
    _addClip(range.$1, range.$2, reason: 'gap');
    return true;
  }

  /// 以播放头作为当前片段的一端；没有选中片段时新建一段。
  /// 选中片段时播放头只在片段内，因此这里只会收缩片段。
  void setEdgeAtPlayhead(MediaTrimEdge edge) {
    final boundaries = state.boundaries;
    if (boundaries == null) return;
    final clip = state.selectedClip;
    if (clip == null) {
      final position = state.position;
      if (edge == MediaTrimEdge.start) {
        final (start, end) = boundaries.defaultRangeAt(position);
        _addClip(start, end, reason: 'mark-in');
      } else if (boundaries.hasSentences) {
        final span = boundaries.lastSpanOf(
          MediaTrimClip(id: 0, start: Duration.zero, end: position),
        );
        final (start, end) = boundaries.rangeForSpans(span, span);
        _addClip(start, end, reason: 'mark-out');
      } else {
        final end = boundaries.snap(MediaTrimEdge.end, position);
        var start = end - MediaTrimBoundaries.newClipDuration;
        if (start < Duration.zero) start = Duration.zero;
        _addClip(start, end, reason: 'mark-out');
      }
      return;
    }
    _moveEdge(clip, edge, state.position, reason: 'playhead');
  }

  /// 拖动时间轴把手。拖动过程中不写日志、不移动播放头，结束时由 [endEdgeDrag] 处理。
  void dragEdge(MediaTrimEdge edge, Duration time) {
    final clip = state.selectedClip;
    if (clip == null) return;
    _moveEdge(clip, edge, time, reason: null);
  }

  /// 拖动结束：播放头停到刚调整的一端（起点或终点），与系统相册裁剪一致。
  void endEdgeDrag(MediaTrimEdge edge) => _finishContinuousAdjust(edge, '拖动结束');

  /// 微调一端。[isRepeating] 为 true 表示长按连续微调，结束时由 [endEdgeRepeat] 处理。
  void stepEdge(MediaTrimEdge edge, int direction, {bool isRepeating = false}) {
    final boundaries = state.boundaries;
    final clip = state.selectedClip;
    if (boundaries == null || clip == null) return;
    _moveEdge(
      clip,
      edge,
      boundaries.step(clip, edge, direction),
      reason: isRepeating ? null : 'step',
    );
  }

  void endEdgeRepeat(MediaTrimEdge edge) =>
      _finishContinuousAdjust(edge, '连续微调结束');

  void _finishContinuousAdjust(MediaTrimEdge edge, String action) {
    final clip = state.selectedClip;
    if (clip == null) return;
    _logClip(action, clip);
    _seekToEdge(edge);
  }

  /// 手动输入时间。返回失败原因，成功时返回 null。
  MediaTrimFailure? setEdgeTime(MediaTrimEdge edge, Duration time) {
    final boundaries = state.boundaries;
    final clip = state.selectedClip;
    if (boundaries == null || clip == null) return null;
    if (time < Duration.zero || time > boundaries.total) {
      return MediaTrimFailure.clipOutOfRange;
    }
    final snapped = boundaries.snap(edge, time);
    final candidate = edge == MediaTrimEdge.start
        ? clip.copyWith(start: snapped)
        : clip.copyWith(end: snapped);
    final failure = boundaries.validate(candidate);
    if (failure != null) return failure;
    _replaceClip(candidate);
    _logClip('输入时间', candidate);
    _seekToEdge(edge);
    return null;
  }

  void renameClip(int clipId, String name) {
    final clip = _clipById(clipId);
    if (clip == null || state.isSaving) return;
    final trimmed = name.trim();
    _replaceClip(
      trimmed.isEmpty ||
              trimmed == state.clipName(clip.copyWith(clearCustomName: true))
          ? clip.copyWith(clearCustomName: true)
          : clip.copyWith(customName: trimmed),
    );
  }

  void removeClip(int clipId) {
    if (state.isSaving) return;
    final index = state.clips.indexWhere((clip) => clip.id == clipId);
    if (index < 0) return;
    _invalidatePreview();
    final clips = [...state.clips]..removeAt(index);
    final wasSelected = state.selectedClipId == clipId;
    state = state.copyWith(
      clips: clips,
      clearSelectedClip: wasSelected,
      isDirty: true,
    );
    AppLogger.log('MediaTrim', '删除片段 id=$clipId remaining=${clips.length}');
    // 删除选中片段后选中相邻片段，便于连续删除或继续编辑。
    if (wasSelected && clips.isNotEmpty) {
      selectClip(clips[index.clamp(0, clips.length - 1)].id);
    }
  }

  /// 按目标时长自动分段，替换现有全部片段。返回生成的片段数。
  int autoSplit(Duration target) {
    final boundaries = state.boundaries;
    if (boundaries == null || state.isSaving) return 0;
    _invalidatePreview();
    final clips = [
      for (final (start, end) in boundaries.autoSplit(target))
        MediaTrimClip(id: _nextClipId++, start: start, end: end),
    ];
    state = state.copyWith(
      clips: clips,
      clearSelectedClip: true,
      isDirty: true,
    );
    selectClip(clips.first.id);
    AppLogger.log(
      'MediaTrim',
      '自动分段 target=${target.inSeconds}s count=${clips.length} '
          'bySentence=${boundaries.hasSentences}',
    );
    return clips.length;
  }

  void _addClip(Duration start, Duration end, {required String reason}) {
    if (state.isSaving) return;
    final boundaries = state.boundaries;
    if (boundaries == null) return;
    final candidate = MediaTrimClip(id: _nextClipId, start: start, end: end);
    for (final clip in state.clips) {
      if (clip.hasSameRange(candidate)) {
        selectClip(clip.id);
        return;
      }
    }
    if (boundaries.validate(candidate) != null) return;
    _nextClipId++;
    _invalidatePreview();
    state = state.copyWith(
      clips: _sorted([...state.clips, candidate]),
      isDirty: true,
    );
    _logClip('新建片段($reason)', candidate);
    selectClip(candidate.id);
  }

  void _moveEdge(
    MediaTrimClip clip,
    MediaTrimEdge edge,
    Duration time, {
    required String? reason,
  }) {
    final boundaries = state.boundaries;
    if (boundaries == null) return;
    final (start, end) = boundaries.moveEdge(clip, edge, time);
    _updateRange(clip, start, end, reason: reason);
    // 非连续调整后，播放头停到刚调整的一端，便于立即试听确认。
    if (reason != null) _seekToEdge(edge);
  }

  /// [reason] 为 null 表示连续调整（拖动、长按）的中间步骤，不写日志。
  void _updateRange(
    MediaTrimClip clip,
    Duration start,
    Duration end, {
    required String? reason,
  }) {
    final boundaries = state.boundaries;
    if (boundaries == null || state.isSaving) return;
    if (start == clip.start && end == clip.end) return;
    final updated = clip.copyWith(start: start, end: end);
    if (boundaries.validate(updated) != null) return;
    _replaceClip(updated);
    if (reason != null) _logClip('调整边界($reason)', updated);
  }

  void _seekToEdge(MediaTrimEdge edge) {
    final clip = state.selectedClip;
    if (clip == null) return;
    unawaited(seek(edge == MediaTrimEdge.start ? clip.start : clip.end));
  }

  void _replaceClip(MediaTrimClip updated) {
    final previous = _clipById(updated.id);
    if (previous != null && !previous.hasSameRange(updated)) {
      _invalidatePreview();
    }
    state = state.copyWith(
      clips: _sorted([
        for (final clip in state.clips) clip.id == updated.id ? updated : clip,
      ]),
      isDirty: true,
    );
  }

  MediaTrimClip? _clipById(int clipId) {
    for (final clip in state.clips) {
      if (clip.id == clipId) return clip;
    }
    return null;
  }

  static List<MediaTrimClip> _sorted(List<MediaTrimClip> clips) =>
      clips..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.end.compareTo(b.end);
      });

  void _logClip(String action, MediaTrimClip clip) {
    AppLogger.log(
      'MediaTrim',
      '$action id=${clip.id} range=${clip.start.inMilliseconds}-'
          '${clip.end.inMilliseconds}ms clips=${state.clips.length}',
    );
  }

  // ── 保存 ──

  Future<MediaTrimExportResult> save(MediaTrimDestination destination) async {
    final boundaries = state.boundaries;
    if (boundaries == null || state.isSaving) {
      throw StateError('剪辑页未就绪或正在保存');
    }
    final named = [
      for (final clip in state.clips) (clip: clip, name: state.clipName(clip)),
    ];
    final cancellation = MediaTrimCancellation();
    _saveCancellation = cancellation;
    ++_previewGeneration;
    state = state.copyWith(
      saveProgress: MediaTrimExportProgress(
        completedClips: 0,
        totalClips: named.length,
        fraction: 0,
      ),
      isCancellingSave: false,
    );
    try {
      await _player.pause();
      final result = await ref
          .read(mediaTrimExporterProvider)
          .export(
            source: source,
            boundaries: boundaries,
            words: _words,
            clips: named,
            destination: destination,
            cancellation: cancellation,
            onProgress: (progress) {
              if (!_isDisposed) state = state.copyWith(saveProgress: progress);
            },
          );
      if (!_isDisposed) state = state.copyWith(isDirty: false);
      return result;
    } on MediaTrimException {
      rethrow;
    } on Object catch (error) {
      throw MediaTrimException(MediaTrimFailure.unexpected, error);
    } finally {
      _saveCancellation = null;
      if (!_isDisposed) {
        state = state.copyWith(
          clearSaveProgress: true,
          isCancellingSave: false,
        );
      }
    }
  }

  Future<void> cancelSave() async {
    final cancellation = _saveCancellation;
    if (cancellation == null) return;
    AppLogger.log('MediaTrim', '用户取消保存 source=${source.id}');
    state = state.copyWith(isCancellingSave: true);
    await cancellation.cancel();
  }

  void _dispose() {
    _isDisposed = true;
    ++_previewGeneration;
    unawaited(_saveCancellation?.cancel());
    unawaited(_waveformCancellation?.cancel());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(
      _player.dispose().catchError((Object error) {
        AppLogger.log('MediaTrim', '剪辑播放器释放失败：$error');
      }),
    );
  }
}

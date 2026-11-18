import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/providers.dart';
import '../../database/app_database.dart' as db;
import '../../models/audio_engine_state.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_highlight_binding.dart';
import '../../services/app_logger.dart';
import '../../services/background_audio_handler.dart';
import '../../services/transcript_sentences_loader.dart';
import '../../services/word_highlight_playback_status_tracker.dart';

part 'audio_engine_provider.g.dart';

@Riverpod(keepAlive: true)
class AudioEngine extends _$AudioEngine {
  /// 同一材料并发请求只执行一次文件加载，避免重复 setFilePath 打断前一个请求。
  final Map<String, Future<void>> _loadingAudioById = <String, Future<void>>{};
  final WordHighlightPlaybackStatusTracker _wordHighlightPlaybackStatus =
      WordHighlightPlaybackStatusTracker();
  StreamSubscription<ja.PlayerState>? _wordHighlightPlaybackSubscription;
  int? _wordHighlightCompletionSessionId;
  int? _wordHighlightObservedPlayingSessionId;

  @override
  AudioEngineState build() {
    _wordHighlightPlaybackSubscription = _handler.player.playerStateStream
        .listen(
          (_) => _observeWordHighlightPlaybackState(),
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.log('AudioEngine', '逐词高亮播放状态流失败: $error\n$stackTrace');
          },
        );
    ref.onDispose(() {
      unawaited(_wordHighlightPlaybackSubscription?.cancel());
      unawaited(_wordHighlightPlaybackStatus.dispose());
    });
    return const AudioEngineState();
  }

  EchoLoopAudioHandler get _handler => echoLoopAudioHandler;
  ja.AudioPlayer get audioPlayer => _handler.player;

  // --- Streams ---
  Stream<Duration> get absolutePositionStream =>
      _handler.player.positionStream.map((rel) => state.clipStart + rel);

  Stream<ja.PlayerState> get playerStateStream =>
      _handler.player.playerStateStream;

  /// 当前逐词高亮播放生命周期状态。
  WordHighlightPlaybackStatus get wordHighlightPlaybackStatus =>
      _wordHighlightPlaybackStatus.status;

  /// 逐词高亮播放生命周期状态流。
  Stream<WordHighlightPlaybackStatus> get wordHighlightPlaybackStatusStream =>
      _wordHighlightPlaybackStatus.stream;

  void _observeWordHighlightPlaybackState() {
    final player = _handler.player;
    final sessionId = state.sessionId;
    final isCurrentSessionPlaying =
        player.playing && _wordHighlightCompletionSessionId == sessionId;
    if (isCurrentSessionPlaying) {
      _wordHighlightObservedPlayingSessionId = sessionId;
      _wordHighlightPlaybackStatus.observePlayerState(
        isPlaying: true,
        isCompleted: false,
      );
      return;
    }

    final isCurrentSessionCompleted =
        player.processingState == ja.ProcessingState.completed &&
        _wordHighlightCompletionSessionId == sessionId &&
        _wordHighlightObservedPlayingSessionId == sessionId;
    if (isCurrentSessionCompleted) {
      _wordHighlightCompletionSessionId = null;
      _wordHighlightObservedPlayingSessionId = null;
    }
    _wordHighlightPlaybackStatus.observePlayerState(
      isPlaying: false,
      isCompleted: isCurrentSessionCompleted,
    );
  }

  void _markWordHighlightPlaybackStarted(int sessionId) {
    _wordHighlightCompletionSessionId = sessionId;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.markPlaying();
  }

  Future<void> _playPlayerForWordHighlight(int sessionId) async {
    _markWordHighlightPlaybackStarted(sessionId);
    try {
      await _handler.playPlayer();
    } catch (_) {
      if (_wordHighlightCompletionSessionId == sessionId) {
        _wordHighlightCompletionSessionId = null;
        _wordHighlightObservedPlayingSessionId = null;
        _wordHighlightPlaybackStatus.reset();
      }
      rethrow;
    }
  }

  bool get isPlaying => _handler.player.playing;
  ja.ProcessingState get processingState => _handler.player.processingState;
  Duration get currentPosition => _handler.player.position;

  /// 已解析的音频总时长（loadAudio 时写入 [AudioEngineState.totalDuration]）。
  Duration? get totalDuration => state.totalDuration;
  Duration get absoluteCurrentPosition =>
      state.clipStart + _handler.player.position;

  /// 当前 session id。调用方据此判断「引擎是否仍停在自己上次驱动的 session」，
  /// 用于隔离讲解页等外来组件对共享引擎的旁路驱动。
  int get currentSessionId => state.sessionId;

  /// 注册/清空锁屏「上一句/下一句」回调，转发给底层 handler。
  ///
  /// 业务层只经 AudioEngine 触达 handler，不直接持有 handler。
  void setSkipHandlers({
    Future<void> Function()? onPrevious,
    Future<void> Function()? onNext,
  }) {
    _handler.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
  }

  /// 注册/清空锁屏播放、暂停回调，转发给底层 handler。
  void setTransportHandlers({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
  }) {
    _handler.setTransportHandlers(onPlay: onPlay, onPause: onPause);
  }

  /// 注册/清空锁屏「后退/前进 N 秒」回调，转发给底层 handler。
  ///
  /// 无字幕音频没有「上一句/下一句」语义，改用相对 seek；与 [setSkipHandlers]
  /// 互斥（注册其一时另一个传 null），由 controller 按是否有字幕分流注册。
  void setSeekHandlers({
    Future<void> Function()? onRewind,
    Future<void> Function()? onFastForward,
  }) {
    _handler.setSeekHandlers(onRewind: onRewind, onFastForward: onFastForward);
  }

  /// 设置/清除锁屏逻辑播放态覆盖（传 null 恢复读裸 player），转发给底层 handler。
  ///
  /// 学习/复习任务在停顿倒计时期间保持 true，使锁屏图标显示「播放中」。
  void setLogicalPlaying(bool? playing) {
    _handler.setLogicalPlaying(playing);
  }

  /// 设置进度冻结（停顿倒计时期间上报 speed=0，锁屏进度条不再外推前进），
  /// 转发给底层 handler。
  void setProgressFrozen(bool frozen) {
    _handler.setProgressFrozen(frozen);
  }

  /// 启动后台静音保活（仅 iOS 生效，见 handler），转发给底层 handler。
  Future<void> startKeepAlive() => _handler.startKeepAlive();

  /// 暂停后台静音保活，转发给底层 handler。
  Future<void> stopKeepAlive() => _handler.stopKeepAlive();

  // --- 音频加载 ---
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.reset();
    // AudioService 仅负责系统媒体会话；失败时后台能力降级，前台播放器继续工作。
    retryEchoLoopAudioServiceOnPlayback();
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final fullAudioPath = await item.getFullAudioPath();
      if (fullAudioPath == null) {
        state = state.copyWith(isLoading: false, errorMessage: '音频文件不可用（未下载）');
        return null;
      }
      final fileExists = File(fullAudioPath).existsSync();
      AppLogger.log(
        'AudioEngine',
        '🔊 loadAudio: id=${item.id}, path=$fullAudioPath, '
            'exists=$fileExists, sessionId=${state.sessionId}',
      );
      final duration = await _handler.loadFile(
        id: item.id,
        filePath: fullAudioPath,
        title: item.name,
        speed: speed,
        subtitle: subtitle,
      );
      var resolvedDuration = duration ?? _handler.player.duration;
      if (resolvedDuration == null) {
        await _handler.player.durationStream.first;
        resolvedDuration = _handler.player.duration;
      }

      state = state.copyWith(
        totalDuration: resolvedDuration,
        clipStart: Duration.zero,
        isClipActive: false,
        currentAudioId: item.id,
        isLoading: false,
      );

      return resolvedDuration;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// 确保 [audioItemId] 已装载到媒体播放器，再播放指定区间。
  Future<void> playRangeForAudio(
    String audioItemId,
    Duration start,
    Duration end, {
    required double speed,
  }) async {
    // 分段播放也要触发后台服务重试，避免复用已加载音频时错过重试机会。
    retryEchoLoopAudioServiceOnPlayback();
    if (state.currentAudioId != audioItemId) {
      await _ensureAudioLoaded(audioItemId, speed);
    }
    if (state.currentAudioId != audioItemId) {
      throw StateError('audio_not_loaded:$audioItemId');
    }
    await setSpeed(speed);
    final sessionId = newSession();
    await playRangeOnce(start, end, sessionId);
  }

  Future<void> _ensureAudioLoaded(String audioItemId, double speed) async {
    final existing = _loadingAudioById[audioItemId];
    if (existing != null) return existing;

    late final Future<void> loading;
    loading = () async {
      try {
        final row = await ref.read(audioItemDaoProvider).getById(audioItemId);
        if (row == null) throw StateError('audio_not_found:$audioItemId');
        await loadAudio(_toAudioItem(row), speed);
      } finally {
        _loadingAudioById.remove(audioItemId);
      }
    }();
    _loadingAudioById[audioItemId] = loading;
    return loading;
  }

  AudioItem _toAudioItem(db.AudioItem row) => AudioItem(
    id: row.id,
    name: row.name,
    audioPath: row.audioPath,
    transcriptPath: row.transcriptPath,
    addedDate: row.addedDate,
    totalDuration: row.totalDuration,
    sentenceCount: row.sentenceCount,
    wordCount: row.wordCount,
    isPinned: row.isPinned,
    transcriptSource: TranscriptSource.fromIndex(row.transcriptSource),
    audioSha256: row.audioSha256,
    originalAudioSha256: row.originalAudioSha256,
    transcriptLanguage: row.transcriptLanguage,
  );

  // --- 字幕加载 ---
  ///
  /// 字幕内容唯一真相源是 DB 的 transcript_srt 列。优先读列；列为空且存在遗留文件
  /// 路径时读文件作防御兜底（全量 backfill 后正常不会触发），并顺手回填列。
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async {
    try {
      return await loadTranscriptSentences(
        ref.read(audioItemDaoProvider),
        audioItem,
      );
    } catch (e) {
      AppLogger.log('Player', '✗ loadTranscript 失败: $e');
      return [];
    }
  }

  // --- 基础控制 ---
  // 引擎内部一律用 playPlayer/pausePlayer 直接驱动底层播放器；handler 的 play/pause
  // 留给系统命令（锁屏/耳机/中断）转交业务回调，避免「controller → engine → handler →
  // controller」回环。
  Future<void> play() async {
    retryEchoLoopAudioServiceOnPlayback();
    await _playPlayerForWordHighlight(state.sessionId);
  }

  Future<void> pause() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _handler.pausePlayer();
    _wordHighlightPlaybackStatus.markPaused();
  }

  /// 暂停但不递增 sessionId。
  ///
  /// 用于「暂停后仍要从同一 LP session 续播」的场景（边界监听回卷、进度条任意
  /// 拖动续播）。普通 [pause] 会 `sessionId++` 使调用方持有的 session 失效，
  /// 续播时会被误判为「被外来 session 顶掉」而走重新起播逻辑；本方法保留 session，
  /// 让调用方能从精确位置继续。
  Future<void> pauseKeepSession() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    await _handler.pausePlayer();
    _wordHighlightPlaybackStatus.markPaused();
  }

  Future<void> stop() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'AudioEngine',
      '⏹ stop(): sessionId $oldId → ${state.sessionId}',
    );
    await _handler.stop();
    _wordHighlightPlaybackStatus.reset();
  }

  /// 停止音频播放（不改变 sessionId）
  ///
  /// 用于 pause 场景：先通过 newSession() 使旧 session 失效，
  /// 再调用此方法真正停止底层播放器，避免额外递增 sessionId。
  Future<void> stopPlayback() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    await _handler.stop();
    _wordHighlightPlaybackStatus.markPaused();
  }

  Future<void> seek(Duration pos) async {
    final wasCompleted =
        _handler.player.processingState == ja.ProcessingState.completed;
    await _handler.seek(pos);
    if (_handler.player.playing) {
      _wordHighlightPlaybackStatus.markPlaying();
    } else {
      _wordHighlightCompletionSessionId = null;
      _wordHighlightObservedPlayingSessionId = null;
      _wordHighlightPlaybackStatus.markPositionSelected(
        ignoreCurrentCompletion: wasCompleted,
      );
    }
  }

  /// 按绝对音频时间跳转，自动转换为当前 clip 的相对位置。
  ///
  /// just_audio 的 `seek` 在 `setClip` 之后以 clip 起点为 0 计算，
  /// 直接传绝对时间会跳到 `clipStart + absolute`，常常越过 clip 末尾
  /// 触发误 `completed`。本方法消除了调用方关心 clip 边界的必要。
  Future<void> seekToAbsolute(Duration absolute) async {
    final wasCompleted =
        _handler.player.processingState == ja.ProcessingState.completed;
    final relative = absolute - state.clipStart;
    await _handler.seek(relative.isNegative ? Duration.zero : relative);
    if (_handler.player.playing) {
      _wordHighlightPlaybackStatus.markPlaying();
    } else {
      _wordHighlightCompletionSessionId = null;
      _wordHighlightObservedPlayingSessionId = null;
      _wordHighlightPlaybackStatus.markPositionSelected(
        ignoreCurrentCompletion: wasCompleted,
      );
    }
  }

  Future<void> setSpeed(double speed) async => await _handler.setSpeed(speed);

  // --- Clip 管理 ---
  Future<void> setClip(Duration start, Duration end) async {
    state = state.copyWith(clipStart: start, isClipActive: true);
    await _handler.setClip(start: start, end: end);
  }

  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    await _handler.setClip(start: null, end: null);
  }

  // --- 句子级播放基元（所有业务模式共享） ---
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();

    AppLogger.log(
      'AudioEngine',
      '▶ playClip: loadedAudio=${state.currentAudioId}, '
          'clip=${sentence.startTime.inMilliseconds}-${sentence.endTime.inMilliseconds}ms',
    );
    state = state.copyWith(clipStart: sentence.startTime, isClipActive: true);
    await _handler.setClip(start: sentence.startTime, end: sentence.endTime);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 标准 clip 播放流程：每次设置片段后显式回到 clip 相对起点。
    // just_audio 在连续切 clip 时可能保留旧相对 position；不 seek(0)
    // 会导致“点击句子却从句中间播放”的交互错误。
    await _handler.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    await _playPlayerForWordHighlight(sessionId);
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playClipOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _handler.pausePlayer();
      return;
    }

    await _handler.player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
  }

  /// 按句播放若干遍。
  ///
  /// Free Player 的单句循环/收藏跳播和学习模式共用这个低层基元：每一遍都重新
  /// setClip 并 seek 到 clip 相对起点，避免 just_audio 在连续切片时沿用旧位置。
  Future<void> playClipWithLoops(
    Sentence sentence,
    int sessionId, {
    required int loopCount,
    required Duration interval,
  }) async {
    for (int loop = 0; loop < loopCount; loop++) {
      if (!isActiveSession(sessionId)) return;

      await playClipOnce(sentence, sessionId);

      if (!isActiveSession(sessionId)) return;
      if (loop < loopCount - 1 && interval > Duration.zero) {
        await Future.delayed(interval);
      }
    }
  }

  /// 从当前播放位置播到音频自然结束（整篇连续播放用）。
  ///
  /// 不 setClip：清除任何残留 clip 后从引擎当前 position 播放，await 直到 just_audio
  /// 发出 `ProcessingState.completed` 或 session 失效。每个自然结束只解析一次 await，
  /// 因此对 just_audio 在部分平台发出的重复/滞后 `completed` 事件天然免疫——
  /// 调用方据此做确定性的整篇循环计数，不依赖反应式事件流。
  Future<void> playToEnd(int sessionId) async {
    if (!isActiveSession(sessionId)) return;

    await _playPlayerForWordHighlight(sessionId);
    // play() 是真正启动播放的点，并发场景下上游可能在此之前 bump session。
    if (!isActiveSession(sessionId)) {
      await _handler.pausePlayer();
      return;
    }

    await _handler.player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
  }

  // --- 区间播放（段落级） ---

  /// 播放指定时间区间一次（段落播放用）
  ///
  /// [start] 区间起始时间，[end] 区间结束时间。
  /// 设置 clip 后播放，等待完成。受 sessionId 保护。
  ///
  /// [onClipReady] 在 clip+seek(0) 落定、`play()` 之前回调一次（session 仍有效时）。
  /// 调用方应在此回调里才订阅 [absolutePositionStream]——此刻位置流发出的是
  /// seek 后的新位置（rel≈0 → 绝对位置≈[start]），可避免在 setClip/seek 过渡期
  /// 把陈旧 position 误映射成错误句子。
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    AppLogger.log(
      'AudioEngine',
      '▶ playRangeOnce: range=${start.inMilliseconds}-${end.inMilliseconds}ms, '
          'sessionId=$sessionId, currentSessionId=${state.sessionId}, '
          'isActive=${isActiveSession(sessionId)}, '
          'audioId=${state.currentAudioId}',
    );
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();

    state = state.copyWith(clipStart: start, isClipActive: true);
    await _handler.setClip(start: start, end: end);

    // setClip 是 await 点，microtask 可能在此期间改变 session
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 在播放中切到同段另一句时，旧 position 可能仍落在新 clip 范围内，
    // 导致 play() 沿用旧 position 而非跳到 clip 起点。
    // 显式 seek 到 clip 相对起点（Duration.zero）保证从目标句开始播放。
    await _handler.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // clip+seek(0) 已落定，位置流此刻起发出的是新位置——通知调用方安全订阅。
    onClipReady?.call();

    // play() 是真正启动音频的点，必须最后一次 check session：
    // 上游 pause / seek 在并发场景下可能在 setClip → seek(0) 期间 bump session，
    // 不在这里拦住会让旧 session 启动一段短暂的播放再被 stop。
    await _playPlayerForWordHighlight(sessionId);
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'AudioEngine',
        '⚠ playRangeOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _handler.pausePlayer();
      return;
    }

    AppLogger.log(
      'AudioEngine',
      '│ play() returned: processingState=${_handler.player.processingState.name}, '
          'playing=${_handler.player.playing}, '
          'sessionActive=${isActiveSession(sessionId)}',
    );

    await _handler.player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
    AppLogger.log(
      'AudioEngine',
      '✓ playRangeOnce done: sessionStillActive=${isActiveSession(sessionId)}, '
          'processingState=${_handler.player.processingState.name}',
    );
  }

  // --- Session 管理 ---
  int newSession() {
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();
    AppLogger.log(
      'AudioEngine',
      '🔄 newSession(): sessionId $oldId → ${state.sessionId}',
    );
    return state.sessionId;
  }

  bool isActiveSession(int id) => id == state.sessionId;
}

import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../database/providers.dart';
import '../../database/app_database.dart' as db;
import '../../models/audio_engine_state.dart';
import '../../models/audio_item.dart' as model;
import '../../models/sentence.dart';
import '../../models/word_highlight_binding.dart';
import '../../services/app_logger.dart';
import '../../services/subtitle_parser.dart';
import '../../services/word_highlight_playback_status_tracker.dart';

part 'foreground_audio_engine_provider.g.dart';

/// 前台音频引擎——录音/复习类任务专用，**不接入 `audio_service`**。
///
/// 与媒体引擎 [AudioEngine]（接 `audio_service`，带锁屏/后台/静音保活）相对：
/// 本引擎自持一个**裸 [ja.AudioPlayer]**，物理上碰不到系统媒体会话
/// （`MPNowPlayingInfoCenter` / 前台通知），故播放原句/原段时永不弹锁屏卡片。
///
/// 服务于：难句跟读 / 段落复述 / 难句补练 / 收藏句复习 / 收藏词复习(闪卡)。
/// 这些任务只在前台播放，不需要后台续播与锁屏控制（见 PLAN.md ADR-7）。
///
/// 播放子集逐方法照抄 [AudioEngine]，仅把 `_handler.xxx` 换成裸 `_player.xxx`，
/// 保证 session 守卫、clip 语义、await-完成等行为与 commit 578f8829 一致；
/// 不实现 `setMediaSessionSuppressed` / `setLogicalPlaying` / 保活 / 锁屏回调 /
/// `playToEnd`（媒体会话/整篇循环专属）。
@Riverpod(keepAlive: true)
class ForegroundAudioEngine extends _$ForegroundAudioEngine {
  /// 裸播放器——独立实例，从不注册到 `audio_service`。
  final ja.AudioPlayer _player = ja.AudioPlayer();

  /// 同一材料并发请求只执行一次文件加载，避免重复 setFilePath 打断前一个请求。
  final Map<String, Future<void>> _loadingAudioById = <String, Future<void>>{};
  final WordHighlightPlaybackStatusTracker _wordHighlightPlaybackStatus =
      WordHighlightPlaybackStatusTracker();
  StreamSubscription<ja.PlayerState>? _wordHighlightPlaybackSubscription;
  int? _wordHighlightCompletionSessionId;
  int? _wordHighlightObservedPlayingSessionId;

  @override
  AudioEngineState build() {
    _wordHighlightPlaybackSubscription = _player.playerStateStream.listen(
      (_) => _observeWordHighlightPlaybackState(),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.log(
          'ForegroundAudioEngine',
          '逐词高亮播放状态流失败: $error\n$stackTrace',
        );
      },
    );
    ref.onDispose(() {
      unawaited(_wordHighlightPlaybackSubscription?.cancel());
      unawaited(_wordHighlightPlaybackStatus.dispose());
      unawaited(_player.dispose());
    });
    return const AudioEngineState();
  }

  ja.AudioPlayer get audioPlayer => _player;

  // --- Streams ---
  Stream<Duration> get absolutePositionStream =>
      _player.positionStream.map((rel) => state.clipStart + rel);

  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;

  /// 当前逐词高亮播放生命周期状态。
  WordHighlightPlaybackStatus get wordHighlightPlaybackStatus =>
      _wordHighlightPlaybackStatus.status;

  /// 逐词高亮播放生命周期状态流。
  Stream<WordHighlightPlaybackStatus> get wordHighlightPlaybackStatusStream =>
      _wordHighlightPlaybackStatus.stream;

  void _observeWordHighlightPlaybackState() {
    final sessionId = state.sessionId;
    final isCurrentSessionPlaying =
        _player.playing && _wordHighlightCompletionSessionId == sessionId;
    if (isCurrentSessionPlaying) {
      _wordHighlightObservedPlayingSessionId = sessionId;
      _wordHighlightPlaybackStatus.observePlayerState(
        isPlaying: true,
        isCompleted: false,
      );
      return;
    }

    final isCurrentSessionCompleted =
        _player.processingState == ja.ProcessingState.completed &&
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
      await _player.play();
    } catch (_) {
      if (_wordHighlightCompletionSessionId == sessionId) {
        _wordHighlightCompletionSessionId = null;
        _wordHighlightObservedPlayingSessionId = null;
        _wordHighlightPlaybackStatus.reset();
      }
      rethrow;
    }
  }

  bool get isPlaying => _player.playing;
  ja.ProcessingState get processingState => _player.processingState;
  Duration get currentPosition => _player.position;

  /// 已解析的音频总时长（loadAudio 时写入）。
  Duration? get totalDuration => state.totalDuration;
  Duration get absoluteCurrentPosition => state.clipStart + _player.position;

  /// 当前 session id。
  int get currentSessionId => state.sessionId;

  // --- 音频加载 ---
  /// 加载音频文件到裸播放器。
  ///
  /// 与 [AudioEngine.loadAudio] 等价，但不经 handler、不设 MediaItem/封面
  /// （前台引擎不上锁屏）。[subtitle] 参数保留以对齐调用签名，本引擎忽略。
  Future<Duration?> loadAudio(
    model.AudioItem item,
    double speed, {
    String? subtitle,
  }) async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.reset();
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final fullAudioPath = await item.getFullAudioPath();
      if (fullAudioPath == null) {
        state = state.copyWith(isLoading: false, errorMessage: '音频文件不可用（未下载）');
        return null;
      }
      final fileExists = File(fullAudioPath).existsSync();
      AppLogger.log(
        'ForegroundAudioEngine',
        '🔊 loadAudio: id=${item.id}, path=$fullAudioPath, '
            'exists=$fileExists, sessionId=${state.sessionId}',
      );
      final duration = await _player.setFilePath(fullAudioPath);
      await _player.setSpeed(speed);
      var resolvedDuration = duration ?? _player.duration;
      if (resolvedDuration == null) {
        await _player.durationStream.first;
        resolvedDuration = _player.duration;
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

  /// 确保 [audioItemId] 已装载到此前台播放器，再播放指定区间。
  ///
  /// 播放入口不应依赖调用方预加载：正面自动播放、意群试听等都可安全直接调用。
  /// 同一材料的并发加载会合并；加载完成后新建 session，旧播放自然失效。
  /// [isRequestActive] 可在异步加载和调速后阻止已取消的旧请求起播；创建 session 后，
  /// [onSessionStarted] 会同步收到该 sessionId，供调用方只取消自己启动的播放。
  Future<void> playRangeForAudio(
    String audioItemId,
    Duration start,
    Duration end, {
    required double speed,
    bool Function()? isRequestActive,
    void Function(int sessionId)? onSessionStarted,
  }) async {
    if (state.currentAudioId != audioItemId) {
      await _ensureAudioLoaded(audioItemId, speed);
    }
    if (state.currentAudioId != audioItemId) {
      throw StateError('audio_not_loaded:$audioItemId');
    }
    if (isRequestActive != null && !isRequestActive()) {
      AppLogger.log(
        'ForegroundAudioEngine',
        'event=range-play-skipped reason=request-cancelled-before-speed '
            'audioId=$audioItemId',
      );
      return;
    }
    await setSpeed(speed);
    if (isRequestActive != null && !isRequestActive()) {
      AppLogger.log(
        'ForegroundAudioEngine',
        'event=range-play-skipped reason=request-cancelled-before-session '
            'audioId=$audioItemId',
      );
      return;
    }
    final sessionId = newSession();
    onSessionStarted?.call(sessionId);
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

  model.AudioItem _toAudioItem(db.AudioItem row) => model.AudioItem(
    id: row.id,
    name: row.name,
    audioPath: row.audioPath,
    transcriptPath: row.transcriptPath,
    addedDate: row.addedDate,
    totalDuration: row.totalDuration,
    sentenceCount: row.sentenceCount,
    wordCount: row.wordCount,
    isPinned: row.isPinned,
    transcriptSource: model.TranscriptSource.fromIndex(row.transcriptSource),
    audioSha256: row.audioSha256,
    originalAudioSha256: row.originalAudioSha256,
    transcriptLanguage: row.transcriptLanguage,
  );

  // --- 字幕加载 ---
  /// 字幕内容唯一真相源是 DB 的 transcript_srt 列；列空时读遗留文件并回填。
  /// 与 [AudioEngine.loadTranscript] 一致（纯 DB + 解析，与 player 无关）。
  Future<List<Sentence>> loadTranscript(model.AudioItem audioItem) async {
    if (!audioItem.hasTranscript) {
      return [];
    }

    try {
      final dao = ref.read(audioItemDaoProvider);
      final srt = await dao.getTranscriptSrt(audioItem.id);
      if (srt != null && srt.isNotEmpty) {
        return await SubtitleParser.parseSubtitleString(srt);
      }

      final fullTranscriptPath = await audioItem.getFullTranscriptPath();
      if (fullTranscriptPath != null) {
        final file = File(fullTranscriptPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            await dao.updateTranscriptSrt(audioItem.id, content);
            return await SubtitleParser.parseSubtitleString(content);
          }
        }
      }
      return [];
    } catch (e) {
      AppLogger.log('ForegroundAudioEngine', '✗ loadTranscript 失败: $e');
      return [];
    }
  }

  // --- 基础控制 ---
  Future<void> play() async {
    await _playPlayerForWordHighlight(state.sessionId);
  }

  Future<void> pause() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'ForegroundAudioEngine',
      'event=pause-session-invalidated previousSessionId=$oldId '
          'currentSessionId=${state.sessionId}',
    );
    await _player.pause();
    _wordHighlightPlaybackStatus.markPaused();
  }

  /// 暂停但不递增 sessionId（边界监听回卷、进度条拖动续播用）。
  Future<void> pauseKeepSession() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    await _player.pause();
    _wordHighlightPlaybackStatus.markPaused();
  }

  Future<void> stop() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    final oldId = state.sessionId;
    state = state.copyWith(sessionId: state.sessionId + 1);
    AppLogger.log(
      'ForegroundAudioEngine',
      '⏹ stop(): sessionId $oldId → ${state.sessionId}',
    );
    await _player.stop();
    _wordHighlightPlaybackStatus.reset();
  }

  /// 停止播放（不改变 sessionId）。
  Future<void> stopPlayback() async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    await _player.stop();
    _wordHighlightPlaybackStatus.markPaused();
  }

  Future<void> seek(Duration pos) async {
    final wasCompleted =
        _player.processingState == ja.ProcessingState.completed;
    await _player.seek(pos);
    if (_player.playing) {
      _wordHighlightPlaybackStatus.markPlaying();
    } else {
      _wordHighlightCompletionSessionId = null;
      _wordHighlightObservedPlayingSessionId = null;
      _wordHighlightPlaybackStatus.markPositionSelected(
        ignoreCurrentCompletion: wasCompleted,
      );
    }
  }

  /// 按绝对音频时间跳转，自动转换为当前 clip 的相对位置（同 [AudioEngine.seekToAbsolute]）。
  Future<void> seekToAbsolute(Duration absolute) async {
    final wasCompleted =
        _player.processingState == ja.ProcessingState.completed;
    final relative = absolute - state.clipStart;
    await _player.seek(relative.isNegative ? Duration.zero : relative);
    if (_player.playing) {
      _wordHighlightPlaybackStatus.markPlaying();
    } else {
      _wordHighlightCompletionSessionId = null;
      _wordHighlightObservedPlayingSessionId = null;
      _wordHighlightPlaybackStatus.markPositionSelected(
        ignoreCurrentCompletion: wasCompleted,
      );
    }
  }

  Future<void> setSpeed(double speed) async => await _player.setSpeed(speed);

  // --- Clip 管理 ---
  Future<void> setClip(Duration start, Duration end) async {
    state = state.copyWith(clipStart: start, isClipActive: true);
    await _player.setClip(start: start, end: end);
  }

  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    await _player.setClip(start: null, end: null);
  }

  // --- 句子级播放基元 ---
  Future<void> playClipOnce(Sentence sentence, int sessionId) =>
      _playClipFromPosition(sentence, sessionId, sentence.startTime);

  /// 从句子内部的位置播放，供暂停恢复使用。
  Future<void> playClipFromPosition(
    Sentence sentence,
    int sessionId,
    Duration startAt,
  ) => _playClipFromPosition(sentence, sessionId, startAt);

  Future<void> _playClipFromPosition(
    Sentence sentence,
    int sessionId,
    Duration requestedStart,
  ) async {
    if (!isActiveSession(sessionId)) return;

    final clipStart =
        requestedStart >= sentence.startTime &&
            requestedStart < sentence.endTime
        ? requestedStart
        : sentence.startTime;

    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();

    AppLogger.log(
      'ForegroundAudioEngine',
      '▶ playClip: loadedAudio=${state.currentAudioId}, '
          'clip=${clipStart.inMilliseconds}-${sentence.endTime.inMilliseconds}ms',
    );
    state = state.copyWith(clipStart: clipStart, isClipActive: true);
    await _player.setClip(start: clipStart, end: sentence.endTime);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 每次设置片段后显式回到 clip 相对起点，避免 just_audio 沿用旧 position。
    await _player.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    await _playPlayerForWordHighlight(sessionId);
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playClipOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _player.pause();
      return;
    }

    await _player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
  }

  /// 按句播放若干遍（同 [AudioEngine.playClipWithLoops]）。
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

  // --- 区间播放（段落级） ---
  /// 播放指定时间区间一次（段落播放用，同 [AudioEngine.playRangeOnce]）。
  ///
  /// [onClipReady] 在 clip+seek(0) 落定、`play()` 之前回调一次（session 仍有效时），
  /// 供调用方在此刻才订阅 [absolutePositionStream]，避免 setClip/seek 过渡期的
  /// 陈旧 position 被误映射成错误句子。
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    AppLogger.log(
      'ForegroundAudioEngine',
      '▶ playRangeOnce: range=${start.inMilliseconds}-${end.inMilliseconds}ms, '
          'sessionId=$sessionId, currentSessionId=${state.sessionId}, '
          'isActive=${isActiveSession(sessionId)}, audioId=${state.currentAudioId}',
    );
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED: session $sessionId 已过期 (current=${state.sessionId})',
      );
      return;
    }

    _wordHighlightCompletionSessionId = null;
    _wordHighlightObservedPlayingSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();

    state = state.copyWith(clipStart: start, isClipActive: true);
    await _player.setClip(start: start, end: end);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED after setClip: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // 显式 seek 到 clip 相对起点，保证从目标段开始播放。
    await _player.seek(Duration.zero);

    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce SKIPPED after seek: session $sessionId 已过期 '
            '(current=${state.sessionId})',
      );
      return;
    }

    // clip+seek(0) 已落定，位置流此刻起发出的是新位置——通知调用方安全订阅。
    onClipReady?.call();

    await _playPlayerForWordHighlight(sessionId);
    if (!isActiveSession(sessionId)) {
      AppLogger.log(
        'ForegroundAudioEngine',
        '⚠ playRangeOnce: session $sessionId 在 play() 后已过期，主动 pause',
      );
      await _player.pause();
      return;
    }

    await _player.playerStateStream.firstWhere(
      (s) =>
          !isActiveSession(sessionId) ||
          s.processingState == ja.ProcessingState.completed,
    );
    AppLogger.log(
      'ForegroundAudioEngine',
      '✓ playRangeOnce done: sessionStillActive=${isActiveSession(sessionId)}, '
          'processingState=${_player.processingState.name}',
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
      'ForegroundAudioEngine',
      '🔄 newSession(): sessionId $oldId → ${state.sessionId}',
    );
    return state.sessionId;
  }

  bool isActiveSession(int id) => id == state.sessionId;
}

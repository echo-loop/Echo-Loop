import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/audio_item.dart';
import '../../models/media_engine_state.dart';
import '../../models/sentence_playback_result.dart';
import '../../models/word_highlight_binding.dart';
import '../../services/background_audio_handler.dart';
import '../../services/echo_loop_media_handler.dart';
import '../../services/app_logger.dart';
import '../../services/media_kit_player_backend.dart';
import '../../services/media_kit_debug_initializer.dart';
import '../../services/media_player_backend.dart';
import '../../services/media_session_router.dart';
import '../../services/word_highlight_playback_status_tracker.dart';

part 'media_engine_provider.g.dart';

/// 测试缝：真实工厂造 MediaKitPlayerBackend，测试 override 注入 fake。
@Riverpod(keepAlive: true)
MediaPlayerBackend Function() mediaBackendFactory(Ref ref) {
  return () => MediaKitPlayerBackend();
}

/// 测试缝：默认读全局 router，测试 override 成纯 Dart router。
@Riverpod(keepAlive: true)
MediaSessionRouter mediaSessionRouter(Ref ref) => echoLoopMediaSessionRouter;

@Riverpod(keepAlive: true)
class MediaEngine extends _$MediaEngine {
  MediaPlayerBackend? _backend;
  Stream<Duration>? _wordHighlightPositionStream;
  EchoLoopMediaHandler? _handler;
  MediaSessionRouter? _router;
  bool _disposingChain = false;
  int _rangeRequestId = 0;
  bool _hasActiveRangeRequest = false;
  Duration? _activeRangeStart;
  int _activeRangeSessionId = 0;
  Future<void> _commandTail = Future<void>.value();
  int _resourceGeneration = 0;
  final WordHighlightPlaybackStatusTracker _wordHighlightPlaybackStatus =
      WordHighlightPlaybackStatusTracker();
  StreamSubscription<bool>? _wordHighlightPlayingSubscription;
  StreamSubscription<void>? _wordHighlightCompletedSubscription;
  int? _wordHighlightCompletionSessionId;

  @override
  MediaEngineState build() {
    ref.onDispose(() {
      unawaited(_wordHighlightPlaybackStatus.dispose());
      // Provider 销毁也必须进入同一生命周期队列，不能和页面 detach 并发操作
      // 同一个 native Player。
      unawaited(
        _enqueueLifecycle(
          'dispose-provider',
          () => _disposeChain(resetState: false, reason: 'provider-dispose'),
        ),
      );
    });
    return const MediaEngineState();
  }

  Future<void> ensureChain() async {
    if (_backend != null && _handler != null) {
      AppLogger.log(
        'MediaEngine',
        'ensureChain: reuse session=${state.sessionId} backend=${identityHashCode(_backend)}',
      );
      return;
    }
    final backend = ref.read(mediaBackendFactoryProvider)();
    // 测试可注入纯 Dart backend；只有真实 media_kit backend 才需要加载原生库。
    // 这样状态机单测不会因为 flutter_tester 不携带 Runner 的 Mpv.framework 失败。
    if (backend is MediaKitPlayerBackend) {
      ensureMediaKitInitialized();
    }
    final handler = EchoLoopMediaHandler(backend);
    final router = ref.read(mediaSessionRouterProvider);
    _backend = backend;
    _wordHighlightPositionStream = backend.positionStream.map(
      _positionForWordHighlight,
    );
    _handler = handler;
    _router = router;
    _listenToWordHighlightPlayback(backend);
    _resourceGeneration += 1;
    AppLogger.log(
      'MediaEngine',
      'ensureChain: create session=${state.sessionId} backend=${identityHashCode(backend)}',
    );
    unawaited(handler.prepareArtwork());
    unawaited(handler.configureInterruptions());
  }

  /// 只接受当前 backend、当前 session 的自然结束事件。
  void _listenToWordHighlightPlayback(MediaPlayerBackend backend) {
    _wordHighlightPlaybackStatus.reset();
    _wordHighlightCompletionSessionId = null;
    _wordHighlightPlayingSubscription = backend.playingStream.listen(
      (_) {
        if (!identical(_backend, backend)) return;
        final sessionId = _wordHighlightCompletionSessionId;
        _wordHighlightPlaybackStatus.observePlayerState(
          isPlaying:
              backend.playing &&
              sessionId != null &&
              isActiveSession(sessionId),
          isCompleted: false,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.log('MediaEngine', '逐词高亮播放状态流失败: $error\n$stackTrace');
      },
    );
    _wordHighlightCompletedSubscription = backend.completedStream.listen(
      (_) {
        final sessionId = _wordHighlightCompletionSessionId;
        if (!identical(_backend, backend) ||
            sessionId == null ||
            !isActiveSession(sessionId) ||
            backend.playing) {
          return;
        }
        _wordHighlightCompletionSessionId = null;
        _wordHighlightPlaybackStatus.markCompleted();
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.log('MediaEngine', '逐词高亮自然结束流失败: $error\n$stackTrace');
      },
    );
  }

  Future<void> disposeChain() async {
    await _enqueueLifecycle(
      'dispose-explicit',
      () => _disposeChain(resetState: true, reason: 'explicit'),
    );
  }

  /// 所有者销毁时解绑媒体会话，但保留全局复用的 native 链路。
  Future<void> releaseForOwnerDispose() async {
    await _enqueueLifecycle(
      'detach-owner',
      () => _detachFromScreen(reason: 'owner-dispose'),
    );
  }

  /// 当前媒体链路是否仍然加载着指定媒体。
  ///
  /// MediaEngine 会被多个学习入口共享，调用方自己的 ready 标记不能代表
  /// backend 仍然存在；所有需要复用媒体的判断都必须以这里的真实资源状态为准。
  bool isReadyFor(String mediaId) =>
      !_disposingChain &&
      _backend != null &&
      _handler != null &&
      !state.isLoading &&
      state.currentMediaId == mediaId;

  /// 当前 native 媒体链路的代际标识，与播放 session 分开管理。
  int get resourceGeneration => _resourceGeneration;

  /// 真正释放 media_kit 原生链路。
  ///
  /// 页面退出不能调用此方法。media_kit 的 native mpv 终止可能晚于 Dart
  /// [Player.dispose] 返回，因此全局复用期间只允许 Provider 销毁路径执行这里。
  Future<void> _disposeChain({
    required bool resetState,
    required String reason,
  }) async {
    if (_disposingChain) {
      AppLogger.log(
        'MediaEngine',
        'disposeChain: skip already disposing reason=$reason',
      );
      return;
    }
    AppLogger.log(
      'MediaEngine',
      'disposeChain: begin reason=$reason backend=${identityHashCode(_backend)} '
          'handler=${identityHashCode(_handler)}',
    );
    _invalidateRangeRequest('dispose-$reason');
    _wordHighlightCompletionSessionId = null;
    _wordHighlightPlaybackStatus.reset();
    _disposingChain = true;
    final handler = _handler;
    final backend = _backend;
    final router = _router;
    Object? firstError;
    try {
      if (handler != null) {
        router?.deactivate(handler);
        try {
          await handler.dispose();
        } catch (error) {
          firstError ??= error;
          AppLogger.log(
            'MediaEngine',
            'dispose handler failed ($reason): $error',
          );
        }
      }
      try {
        await backend?.stop();
      } catch (error) {
        firstError ??= error;
        AppLogger.log('MediaEngine', 'dispose stop failed ($reason): $error');
        // backend.dispose() 仍会尝试 stop；这里的 stop 只是提前卸载媒体的防护。
      }
      try {
        await backend?.dispose();
      } catch (error) {
        firstError ??= error;
        AppLogger.log(
          'MediaEngine',
          'dispose backend failed ($reason): $error',
        );
      }
      final error = firstError;
      if (error != null) {
        throw error;
      }
      await _wordHighlightPlayingSubscription?.cancel();
      _wordHighlightPlayingSubscription = null;
      await _wordHighlightCompletedSubscription?.cancel();
      _wordHighlightCompletedSubscription = null;
      // 只有整条释放链成功后才清空引用。失败时保留唯一 owner，允许后续
      // 显式重试，而不是把仍可能存活的 native 资源变成不可达泄漏。
      _handler = null;
      _backend = null;
      _wordHighlightPositionStream = null;
      _router = null;
      if (resetState) {
        state = const MediaEngineState().copyWith(
          sessionId: state.sessionId + 1,
          clearCurrentMediaId: true,
          clearTotalDuration: true,
        );
      }
      AppLogger.log('MediaEngine', 'disposeChain: complete reason=$reason');
    } catch (e) {
      // 释放路径不能沉默失败；日志保留 reason 方便区分页面退出与容器销毁。
      // 不向上抛，避免 dispose 阶段异常打断 Flutter 清理流程。
      AppLogger.log('MediaEngine', '✗ disposeChain failed ($reason): $e');
    } finally {
      _disposingChain = false;
    }
  }

  /// 加载媒体；[publishToSystemMediaSession] 控制是否发布系统媒体控制信息。
  Future<Duration?> loadMedia(
    AudioItem item,
    double speed, {
    Duration initialPosition = Duration.zero,
    bool publishToSystemMediaSession = true,
  }) => _enqueueLifecycle(
    'load-${item.id}',
    () => _loadMedia(
      item,
      speed,
      initialPosition: initialPosition,
      publishToSystemMediaSession: publishToSystemMediaSession,
    ),
  );

  Future<Duration?> _loadMedia(
    AudioItem item,
    double speed, {
    required Duration initialPosition,
    required bool publishToSystemMediaSession,
  }) async {
    _wordHighlightCompletionSessionId = null;
    _wordHighlightPlaybackStatus.reset();
    final currentBackend = _backend;
    AppLogger.log(
      'MediaEngine',
      'loadMedia: begin id=${item.id} session=${state.sessionId} '
          'backend=${currentBackend == null ? 'uninitialized' : identityHashCode(currentBackend)}',
    );
    await ensureChain();
    // media_kit 前台播放不依赖 AudioService；测试 fake backend 也不应触发
    // 真实平台媒体会话初始化，否则 flutter_tester 会访问不存在的平台插件。
    if (publishToSystemMediaSession && _backend is MediaKitPlayerBackend) {
      retryEchoLoopAudioServiceOnPlayback();
    }
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearTotalDuration: true,
    );
    final path = await item.getFullAudioPath();
    if (path == null) {
      AppLogger.log('MediaEngine', 'loadMedia: file unavailable id=${item.id}');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'file not available',
      );
      return null;
    }
    final handler = _handler;
    final backend = _backend;
    if (handler == null || backend == null) {
      AppLogger.log(
        'MediaEngine',
        'loadMedia: chain unavailable id=${item.id}',
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'media chain not available',
      );
      return null;
    }
    final router = _router;
    if (!publishToSystemMediaSession) router?.deactivate(handler);
    try {
      handler.setNowPlaying(id: item.id, title: item.name);
      await backend.open(path, initialPosition: initialPosition);
      await backend.setRate(speed);
      if (publishToSystemMediaSession) router?.activate(handler);
      if (publishToSystemMediaSession && router != null) {
        await _waitForSystemMediaState(router, item.id);
      }
      final duration =
          backend.duration ??
          await backend.durationStream
              .firstWhere((value) => value > Duration.zero)
              .timeout(const Duration(seconds: 10));
      state = state.copyWith(
        totalDuration: duration,
        currentMediaId: item.id,
        isLoading: false,
      );
      AppLogger.log(
        'MediaEngine',
        'loadMedia: complete id=${item.id} session=${state.sessionId} '
            'backend=${identityHashCode(backend)} duration=${duration.inMilliseconds}ms',
      );
      return duration;
    } catch (e) {
      AppLogger.log('MediaEngine', 'loadMedia: failed id=${item.id} error=$e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  /// 等待系统媒体路由转发当前曲目和就绪态，再向页面报告加载完成。
  ///
  /// SwitchAudioHandler 切换内部 handler 后会异步订阅新 handler 的状态流；如果
  /// 页面立刻起播并锁屏，iOS 可能先收到播放态、却还没有当前曲目。超时只记录诊断，
  /// 不阻止前台播放。
  Future<void> _waitForSystemMediaState(
    MediaSessionRouter router,
    String mediaId,
  ) async {
    final mediaItemReady = Completer<void>();
    final playbackStateReady = Completer<void>();

    void completeMediaItem(MediaItem? item) {
      if (item?.id == mediaId && !mediaItemReady.isCompleted) {
        mediaItemReady.complete();
      }
    }

    void completePlaybackState(PlaybackState playbackState) {
      if (playbackState.processingState == AudioProcessingState.ready &&
          !playbackStateReady.isCompleted) {
        playbackStateReady.complete();
      }
    }

    final mediaItemSub = router.mediaItem.listen(completeMediaItem);
    final playbackStateSub = router.playbackState.listen(completePlaybackState);
    completeMediaItem(router.mediaItem.value);
    completePlaybackState(router.playbackState.value);

    try {
      await Future.wait<void>([
        mediaItemReady.future,
        playbackStateReady.future,
      ]).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      AppLogger.log(
        'MediaEngine',
        'system media state handoff timed out id=$mediaId '
            'routed=${router.isRouted} '
            'mediaItem=${router.mediaItem.value?.id} '
            'processing=${router.playbackState.value.processingState.name}',
      );
    } finally {
      await mediaItemSub.cancel();
      await playbackStateSub.cancel();
    }
  }

  int newSession() {
    final next = state.sessionId + 1;
    state = state.copyWith(sessionId: next);
    _wordHighlightCompletionSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();
    return next;
  }

  bool isActiveSession(int id) => id == state.sessionId;

  int get currentSessionId => state.sessionId;

  /// 当前逐词高亮播放生命周期状态。
  WordHighlightPlaybackStatus get wordHighlightPlaybackStatus =>
      _wordHighlightPlaybackStatus.status;

  /// 逐词高亮播放生命周期状态流。
  Stream<WordHighlightPlaybackStatus> get wordHighlightPlaybackStatusStream =>
      _wordHighlightPlaybackStatus.stream;

  /// 已解码视频的显示方向，已由后端处理旋转元数据。
  bool? get isLandscapeVideo => _backend?.isLandscapeVideo;

  Stream<bool?> get isLandscapeVideoStream =>
      _backend?.isLandscapeVideoStream ?? const Stream<bool?>.empty();

  /// 已解码视频的实际宽高比，供 UI 按原比例布局。
  double? get videoAspectRatio => _backend?.videoAspectRatio;

  Stream<double?> get videoAspectRatioStream =>
      _backend?.videoAspectRatioStream ?? const Stream<double?>.empty();

  Future<void> play() => _enqueueLifecycle('play', () async {
    final handler = _handler;
    if (handler == null) return;
    final sessionId = state.sessionId;
    _wordHighlightCompletionSessionId = sessionId;
    _wordHighlightPlaybackStatus.markPlaying();
    try {
      await handler.playBackend();
    } catch (_) {
      if (_wordHighlightCompletionSessionId == sessionId) {
        _wordHighlightCompletionSessionId = null;
        _wordHighlightPlaybackStatus.reset();
      }
      rethrow;
    }
  });

  Future<void> pause() async {
    _wordHighlightCompletionSessionId = null;
    _invalidateRangeRequest('legacy-pause');
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _enqueueLifecycle('pause', () async {
      await _handler?.pauseBackend();
      _wordHighlightPlaybackStatus.markPaused();
    });
  }

  Future<void> pauseKeepSession() {
    _wordHighlightCompletionSessionId = null;
    return _enqueueLifecycle('pause-keep-session', () async {
      await _handler?.pauseBackend();
      _wordHighlightPlaybackStatus.markPaused();
    });
  }

  Future<void> stop() async {
    _wordHighlightCompletionSessionId = null;
    _invalidateRangeRequest('legacy-stop');
    state = state.copyWith(sessionId: state.sessionId + 1);
    await _enqueueLifecycle('stop', () async {
      await _handler?.stop();
      _wordHighlightPlaybackStatus.reset();
    });
  }

  /// 页面退出只解绑会话，保留 backend 供下一个页面复用。
  Future<void> releaseFromScreen() => _enqueueLifecycle(
    'detach-screen',
    () => _detachFromScreen(reason: 'screen-release'),
  );

  /// 释放页面所有权，但不销毁全局共享的 native Player。
  Future<void> _detachFromScreen({required String reason}) async {
    _wordHighlightCompletionSessionId = null;
    AppLogger.log(
      'MediaEngine',
      'detachFromScreen: begin reason=$reason session=${state.sessionId} '
          'activeRange=$_hasActiveRangeRequest rangeId=$_rangeRequestId '
          'backend=${identityHashCode(_backend)}',
    );
    _invalidateRangeRequest('screen-release');
    // 所有会改变 backend 的命令都共享同一条队列；当前 detach 排在已经发出的
    // range 命令之后，后续 load 则排在 detach 之后，不会跨越 native 生命周期边界。
    AppLogger.log('MediaEngine', 'detachFromScreen: command queue ordered');
    state = state.copyWith(sessionId: state.sessionId + 1);
    final handler = _handler;
    final router = _router;
    Object? pauseError;
    try {
      await handler?.pauseBackend();
      _wordHighlightPlaybackStatus.markPaused();
    } catch (error) {
      pauseError = error;
      AppLogger.log(
        'MediaEngine',
        'detach pause failed reason=$reason: $error',
      );
    }
    if (handler != null) router?.deactivate(handler);
    state = state.copyWith(clearCurrentMediaId: true, clearTotalDuration: true);
    final error = pauseError;
    if (error != null) throw error;
    AppLogger.log(
      'MediaEngine',
      'detachFromScreen: complete reason=$reason session=${state.sessionId} '
          'backendRetained=${_backend != null}',
    );
  }

  Future<void> seek(Duration pos) {
    final backend = _backend;
    AppLogger.log(
      'MediaEngine',
      'seek begin target=${pos.inMilliseconds}ms '
          'position=${backend?.position.inMilliseconds}ms '
          'playing=${backend?.playing}',
    );
    return _enqueueLifecycle('seek', () async {
      final wasPlaying = _backend?.playing ?? false;
      await _handler?.seek(pos);
      AppLogger.log(
        'MediaEngine',
        'seek complete target=${pos.inMilliseconds}ms '
            'position=${_backend?.position.inMilliseconds}ms '
            'playing=${_backend?.playing}',
      );
      if (wasPlaying) {
        _wordHighlightPlaybackStatus.markPlaying();
      } else {
        _wordHighlightCompletionSessionId = null;
        _wordHighlightPlaybackStatus.markPositionSelected();
      }
    });
  }

  Future<void> setSpeed(double speed) =>
      _enqueueLifecycle('set-speed', () async {
        await _handler?.setSpeed(speed);
      });

  Future<void> setVideoTrackEnabled(bool enabled) =>
      _enqueueLifecycle('set-video-track', () async {
        final backend = _backend;
        if (backend == null) return;
        await backend.setVideoTrackEnabled(enabled);
        state = state.copyWith(videoTrackEnabled: enabled);
      });

  Future<void> setSubtitleTrackData(String? srt) =>
      _enqueueLifecycle('set-subtitle-track', () async {
        final backend = _backend;
        if (backend == null) return;
        await backend.setSubtitleTrackData(srt);
        state = state.copyWith(
          subtitleTrackEnabled: srt != null && srt.isNotEmpty,
        );
      });

  bool get isPlaying => _backend?.playing ?? false;
  Duration get currentPosition => _backend?.position ?? Duration.zero;

  /// 当前高亮位置；活动区间内不会早于区间起点。
  Duration get wordHighlightPosition {
    final position = currentPosition;
    final rangeStart = _activeWordHighlightRangeStart;
    return rangeStart != null && position < rangeStart ? rangeStart : position;
  }

  Duration? get totalDuration => state.totalDuration;
  Stream<Duration> get positionStream =>
      _backend?.positionStream ?? const Stream<Duration>.empty();

  /// 逐词高亮使用的时间轴，屏蔽活动播放区间起点前的陈旧位置样本。
  Stream<Duration> get wordHighlightPositionStream =>
      _wordHighlightPositionStream ?? const Stream<Duration>.empty();

  /// 将活动区间起点之前的位置样本视作起点，避免逐词高亮向前闪回。
  Duration _positionForWordHighlight(Duration position) {
    final rangeStart = _activeWordHighlightRangeStart;
    return rangeStart != null && position < rangeStart ? rangeStart : position;
  }

  Duration? get _activeWordHighlightRangeStart =>
      _hasActiveRangeRequest && isActiveSession(_activeRangeSessionId)
      ? _activeRangeStart
      : null;

  Stream<bool> get playingStream =>
      _backend?.playingStream ?? const Stream<bool>.empty();

  Widget buildVideoView({required Size viewportSize}) {
    final backend = _backend;
    if (backend == null) return const SizedBox.shrink();
    return backend.buildVideoView(viewportSize: viewportSize);
  }

  void setTransportHandlers({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
  }) {
    _handler?.setTransportHandlers(onPlay: onPlay, onPause: onPause);
  }

  void setSkipHandlers({
    Future<void> Function()? onPrevious,
    Future<void> Function()? onNext,
  }) {
    _handler?.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
  }

  /// 注册/清空系统媒体面板的相对快进、回退命令回调。
  void setSeekHandlers({
    Future<void> Function()? onRewind,
    Future<void> Function()? onFastForward,
  }) {
    _handler?.setSeekHandlers(onRewind: onRewind, onFastForward: onFastForward);
  }

  void setLogicalPlaying(bool? playing) {
    _handler?.setLogicalPlaying(playing);
  }

  void setProgressFrozen(bool frozen) {
    _handler?.setProgressFrozen(frozen);
  }

  Future<void> startKeepAlive() => _enqueueLifecycle(
    'start-keep-alive',
    () async => _handler?.startKeepAlive(),
  );

  Future<void> stopKeepAlive() => _enqueueLifecycle(
    'stop-keep-alive',
    () async => _handler?.stopKeepAlive(),
  );

  /// 原子替换当前区间播放；可由长期存在的调用方传入所属媒体 session。
  ///
  /// 每个请求拥有私有 generation。新的 range、取消或页面释放都会使旧请求返回
  /// [SentencePlaybackResult.cancelled]，旧请求的迟到回调不会暂停后继请求。
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end, {
    required double speed,
    VoidCallback? onRangeReady,
    int? sessionId,
  }) async {
    if (start < Duration.zero || end <= start) {
      AppLogger.log(
        'MediaEngine Range',
        'failed: invalid-range=${start.inMilliseconds}-${end.inMilliseconds}ms',
      );
      return SentencePlaybackResult.failed;
    }
    final rangeSessionId = sessionId ?? currentSessionId;
    if (!isActiveSession(rangeSessionId)) {
      return SentencePlaybackResult.cancelled;
    }

    _wordHighlightCompletionSessionId = null;
    _wordHighlightPlaybackStatus.prepareForPlayback();
    final requestId = ++_rangeRequestId;
    _activeRangeStart = start;
    _hasActiveRangeRequest = true;
    _activeRangeSessionId = rangeSessionId;
    AppLogger.log(
      'MediaEngine Range',
      'request: id=$requestId range=${start.inMilliseconds}-'
          '${end.inMilliseconds}ms speed=$speed',
    );

    final setupResult = await _enqueueRangeControl(
      'range-setup-$requestId',
      () async {
        final handler = _handler;
        final backend = _backend;
        if (handler == null || backend == null) {
          return (
            result: SentencePlaybackResult.cancelled,
            backend: backend,
            startWaiter: null,
          );
        }
        if (!_isActiveRangeRequest(requestId)) {
          return (
            result: SentencePlaybackResult.cancelled,
            backend: backend,
            startWaiter: null,
          );
        }
        _RangeStartWaiter? startWaiter;
        try {
          await handler.pauseBackend();
          if (!_isActiveRangeRequest(requestId)) {
            return (
              result: SentencePlaybackResult.cancelled,
              backend: backend,
              startWaiter: null,
            );
          }
          await handler.setSpeed(speed);
          if (!_isActiveRangeRequest(requestId)) {
            return (
              result: SentencePlaybackResult.cancelled,
              backend: backend,
              startWaiter: null,
            );
          }
          // 先订阅位置流，再发 seek，确保不会漏掉 seek 后首个有效位置事件。
          startWaiter = _awaitRangeStartPosition(
            backend,
            start,
            end,
            requestId,
          );
          await handler.seek(start);
          if (!_isActiveRangeRequest(requestId)) {
            await startWaiter.cancel();
            return (
              result: SentencePlaybackResult.cancelled,
              backend: backend,
              startWaiter: null,
            );
          }
          AppLogger.log(
            'MediaEngine Range',
            'seek-ack: id=$requestId targetStartMs=${start.inMilliseconds} '
                'cachedPositionMs=${backend.position.inMilliseconds} '
                'deltaMs=${backend.position.inMilliseconds - start.inMilliseconds} '
                'sessionId=$rangeSessionId',
          );
          return (
            result: SentencePlaybackResult.completed,
            backend: backend,
            startWaiter: startWaiter,
          );
        } catch (error) {
          await startWaiter?.cancel();
          AppLogger.log(
            'MediaEngine Range',
            'failed: id=$requestId setup-error=$error',
          );
          _invalidateRangeRequest('setup-failed');
          return (
            result: SentencePlaybackResult.failed,
            backend: backend,
            startWaiter: null,
          );
        }
      },
    );

    final backend = setupResult.backend;
    final startWaiter = setupResult.startWaiter;
    if (setupResult.result != SentencePlaybackResult.completed ||
        backend == null ||
        startWaiter == null ||
        !_isActiveRangeRequest(requestId)) {
      await startWaiter?.cancel();
      return _rangeResultFor(requestId, setupResult.result);
    }

    final reached = _awaitRangeEndOrRequestInvalid(backend, end, requestId);
    final playResult = await _enqueueRangeControl(
      'range-play-$requestId',
      () async {
        final handler = _handler;
        if (handler == null || !_isActiveRangeRequest(requestId)) {
          return SentencePlaybackResult.cancelled;
        }
        try {
          // 先让调用方订阅位置流；高亮等 seek 对应的新时间轴事件到达后再开启。
          onRangeReady?.call();
          await handler.playBackend();
          return _isActiveRangeRequest(requestId)
              ? SentencePlaybackResult.completed
              : SentencePlaybackResult.cancelled;
        } catch (error) {
          AppLogger.log(
            'MediaEngine Range',
            'failed: id=$requestId play-error=$error',
          );
          if (_isActiveRangeRequest(requestId)) {
            _wordHighlightCompletionSessionId = null;
            _wordHighlightPlaybackStatus.reset();
          }
          _invalidateRangeRequest('play-failed');
          return SentencePlaybackResult.failed;
        }
      },
    );
    if (playResult != SentencePlaybackResult.completed) {
      await reached.cancel();
      await startWaiter.cancel();
      return playResult;
    }

    final startConfirmed = await Future.any<bool>([
      startWaiter.started,
      reached.future.then((_) => false),
    ]);
    if (startConfirmed && _isActiveRangeRequest(requestId)) {
      await _enqueueRangeControl('range-position-ready-$requestId', () async {
        if (_isActiveRangeRequest(requestId)) {
          _wordHighlightCompletionSessionId = rangeSessionId;
          _wordHighlightPlaybackStatus.markPlaying();
        }
      });
    }

    final result = await reached.future;
    await startWaiter.cancel();
    if (result == SentencePlaybackResult.completed) {
      await _enqueueRangeControl('range-finish-$requestId', () async {
        if (_isActiveRangeRequest(requestId)) {
          _wordHighlightCompletionSessionId = null;
          _wordHighlightPlaybackStatus.markCompleted();
          await _handler?.pauseBackend();
        }
      });
    }
    AppLogger.log(
      'MediaEngine Range',
      'return: id=$requestId position=${backend.position.inMilliseconds}ms '
          'result=$result',
    );
    _completeRangeRequest(requestId);
    return result;
  }

  /// 取消当前自管理区间播放，并等待底层暂停排在已发出的控制命令之后执行。
  Future<void> cancelActiveRange({String reason = 'caller-cancel'}) async {
    AppLogger.log(
      'MediaEngine Range',
      'cancel request: reason=$reason active=$_hasActiveRangeRequest '
          'rangeId=$_rangeRequestId',
    );
    _wordHighlightCompletionSessionId = null;
    _invalidateRangeRequest(reason);
    await _enqueueRangeControl('range-cancel-$reason', () async {
      await _handler?.pauseBackend();
      _wordHighlightPlaybackStatus.markPaused();
    });
  }

  bool _isActiveRangeRequest(int requestId) =>
      _hasActiveRangeRequest &&
      requestId == _rangeRequestId &&
      isActiveSession(_activeRangeSessionId);

  void _completeRangeRequest(int requestId) {
    if (_isActiveRangeRequest(requestId)) {
      _hasActiveRangeRequest = false;
      _activeRangeStart = null;
    }
  }

  SentencePlaybackResult _rangeResultFor(
    int requestId,
    SentencePlaybackResult fallback,
  ) => _isActiveRangeRequest(requestId)
      ? fallback
      : SentencePlaybackResult.cancelled;

  void _invalidateRangeRequest(String reason) {
    if (!_hasActiveRangeRequest) return;
    final previous = _rangeRequestId;
    _rangeRequestId += 1;
    _hasActiveRangeRequest = false;
    _activeRangeStart = null;
    AppLogger.log(
      'MediaEngine Range',
      'cancel: previous=$previous current=$_rangeRequestId reason=$reason',
    );
  }

  Future<T> _enqueueRangeControl<T>(
    String label,
    Future<T> Function() operation,
  ) {
    final queued = _commandTail.then((_) async {
      try {
        return await operation();
      } catch (error) {
        AppLogger.log(
          'MediaEngine Range',
          'control failed: label=$label error=$error',
        );
        rethrow;
      }
    });
    _commandTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }

  Future<T> _enqueueLifecycle<T>(String label, Future<T> Function() operation) {
    final queued = _commandTail.then((_) async {
      final diagnostic = _shouldLogLifecycle(label);
      if (diagnostic) AppLogger.log('MediaEngine', 'lifecycle begin: $label');
      try {
        final result = await operation();
        if (diagnostic) {
          AppLogger.log('MediaEngine', 'lifecycle complete: $label');
        }
        return result;
      } catch (error) {
        AppLogger.log('MediaEngine', 'lifecycle failed: $label error=$error');
        rethrow;
      }
    });
    _commandTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }

  bool _shouldLogLifecycle(String label) =>
      label.startsWith('load-') ||
      label.startsWith('dispose-') ||
      label.startsWith('detach-') ||
      label.startsWith('play-to-end-');

  _RangeWaiter _awaitRangeEndOrRequestInvalid(
    MediaPlayerBackend backend,
    Duration end,
    int requestId,
  ) {
    final completer = Completer<SentencePlaybackResult>();
    StreamSubscription<Duration>? posSub;
    StreamSubscription<void>? doneSub;
    Timer? guard;
    Future<void>? cleanupFuture;
    Future<void> cleanup() async {
      final existing = cleanupFuture;
      if (existing != null) {
        await existing;
        return;
      }
      final future = _cancelRangeSubscriptions(posSub, doneSub);
      cleanupFuture = future;
      guard?.cancel();
      await future;
    }

    Future<void> finish(SentencePlaybackResult result) async {
      if (completer.isCompleted) return;
      completer.complete(result);
      await cleanup();
    }

    posSub = backend.positionStream.listen((position) {
      if (!_isActiveRangeRequest(requestId)) {
        unawaited(finish(SentencePlaybackResult.cancelled));
      } else if (position >= end) {
        unawaited(finish(SentencePlaybackResult.completed));
      }
    });
    doneSub = backend.completedStream.listen((_) {
      if (!_isActiveRangeRequest(requestId)) {
        unawaited(finish(SentencePlaybackResult.cancelled));
      } else {
        unawaited(finish(_rangeResultOnMediaCompletion(backend, end)));
      }
    });
    guard = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_isActiveRangeRequest(requestId)) {
        unawaited(finish(SentencePlaybackResult.cancelled));
      } else if (backend.position >= end) {
        unawaited(finish(SentencePlaybackResult.completed));
      }
    });
    return _RangeWaiter(completer.future, () async {
      await finish(SentencePlaybackResult.cancelled);
    });
  }

  /// 根据媒体自然结束事件判定区间结果。
  ///
  /// media_kit 的 EOF 事件可能先于最后一条位置事件到达。若媒体时长已覆盖区间
  /// 终点，自然结束就能证明区间已播完；媒体时长不足时仍按失败处理。
  SentencePlaybackResult _rangeResultOnMediaCompletion(
    MediaPlayerBackend backend,
    Duration end,
  ) {
    if (backend.position >= end) return SentencePlaybackResult.completed;

    final mediaDuration = backend.duration ?? state.totalDuration;
    return mediaDuration != null && end <= mediaDuration
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.failed;
  }

  /// 以位置流确认 seek 起点已进入时间轴。
  ///
  /// media_kit 的 seek Future 只代表命令回执；其缓存位置可能仍是旧值。起点前的
  /// 位置事件不能开启高亮。此观察器不阻塞播放，也不负责区间结束判断。
  _RangeStartWaiter _awaitRangeStartPosition(
    MediaPlayerBackend backend,
    Duration start,
    Duration end,
    int requestId,
  ) {
    final started = Completer<bool>();
    StreamSubscription<Duration>? posSub;
    Timer? guard;
    Future<void>? cleanupFuture;
    var finished = false;
    Future<void> cleanup() async {
      final existing = cleanupFuture;
      if (existing != null) {
        await existing;
        return;
      }
      final future = posSub?.cancel() ?? Future<void>.value();
      cleanupFuture = future;
      guard?.cancel();
      await future;
    }

    void finish(bool result) {
      if (finished) return;
      finished = true;
      if (!started.isCompleted) started.complete(result);
      unawaited(cleanup());
    }

    posSub = backend.positionStream.listen((position) {
      if (!_isActiveRangeRequest(requestId)) {
        finish(false);
      } else {
        const startTolerance = Duration(milliseconds: 250);
        final offsetFromStart = position - start;
        if (position < end &&
            offsetFromStart >= Duration.zero &&
            offsetFromStart <= startTolerance) {
          AppLogger.log(
            'MediaEngine Range',
            'position-ready: id=$requestId targetStartMs=${start.inMilliseconds} '
                'positionMs=${position.inMilliseconds} '
                'deltaMs=${offsetFromStart.inMilliseconds}',
          );
          finish(true);
        }
      }
    });
    guard = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_isActiveRangeRequest(requestId)) {
        finish(false);
      }
    });
    return _RangeStartWaiter(started.future, () async {
      finish(false);
      await cleanup();
    });
  }

  Future<void> _cancelRangeSubscriptions(
    StreamSubscription<Duration>? positionSubscription,
    StreamSubscription<void>? completedSubscription,
  ) async {
    await positionSubscription?.cancel();
    await completedSubscription?.cancel();
  }

  Future<void> playToEnd(int sessionId) async {
    final handler = _handler;
    final backend = _backend;
    if (handler == null || backend == null || !isActiveSession(sessionId)) {
      AppLogger.log(
        'MediaEngine',
        'playToEnd ignored session=$sessionId active=${isActiveSession(sessionId)} '
            'hasHandler=${handler != null} hasBackend=${backend != null}',
      );
      return;
    }

    AppLogger.log(
      'MediaEngine',
      'playToEnd begin session=$sessionId backend=${identityHashCode(backend)} '
          'position=${backend.position.inMilliseconds}ms playing=${backend.playing} '
          'duration=${backend.duration?.inMilliseconds}ms',
    );

    // play 也必须经过生命周期队列。否则页面 detach 与新媒体 load 可能在
    // native play 尚未返回时并发执行，旧 play 返回后的补偿 pause 就会命中新媒体。
    final played = await _enqueueLifecycle('play-to-end-$sessionId', () async {
      if (!isActiveSession(sessionId) ||
          !identical(_handler, handler) ||
          !identical(_backend, backend)) {
        return false;
      }
      try {
        _wordHighlightCompletionSessionId = sessionId;
        _wordHighlightPlaybackStatus.markPlaying();
        await handler.playBackend();
        return true;
      } catch (error, stackTrace) {
        if (_wordHighlightCompletionSessionId == sessionId) {
          _wordHighlightCompletionSessionId = null;
          _wordHighlightPlaybackStatus.reset();
        }
        AppLogger.log(
          'MediaEngine',
          'playToEnd play failed session=$sessionId error=$error\n$stackTrace',
        );
        rethrow;
      }
    });
    if (!played) return;
    AppLogger.log(
      'MediaEngine',
      'playToEnd play returned session=$sessionId active=${isActiveSession(sessionId)} '
          'position=${backend.position.inMilliseconds}ms playing=${backend.playing}',
    );
    if (isActiveSession(sessionId)) {
      await _awaitCompletedOrInvalid(backend, sessionId);
    }
    AppLogger.log(
      'MediaEngine',
      'playToEnd done session=$sessionId active=${isActiveSession(sessionId)} '
          'position=${backend.position.inMilliseconds}ms playing=${backend.playing}',
    );
  }

  Future<void> _awaitCompletedOrInvalid(
    MediaPlayerBackend backend,
    int sessionId,
  ) {
    final completer = Completer<void>();
    StreamSubscription<void>? doneSub;
    Timer? guard;
    void finish() {
      if (completer.isCompleted) return;
      unawaited(doneSub?.cancel());
      guard?.cancel();
      AppLogger.log(
        'MediaEngine',
        'playToEnd wait finished session=$sessionId active=${isActiveSession(sessionId)} '
            'position=${backend.position.inMilliseconds}ms playing=${backend.playing}',
      );
      completer.complete();
    }

    doneSub = backend.completedStream.listen((_) {
      AppLogger.log(
        'MediaEngine',
        'backend completed event session=$sessionId '
            'position=${backend.position.inMilliseconds}ms playing=${backend.playing}',
      );
      if (isActiveSession(sessionId) &&
          identical(_backend, backend) &&
          _wordHighlightCompletionSessionId == sessionId &&
          !backend.playing) {
        _wordHighlightCompletionSessionId = null;
        _wordHighlightPlaybackStatus.markCompleted();
      }
      finish();
    });
    guard = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!isActiveSession(sessionId)) {
        finish();
        return;
      }
    });
    return completer.future;
  }
}

/// 区间结束监听器的可取消句柄，确保起播失败时不会遗留订阅和定时器。
class _RangeWaiter {
  const _RangeWaiter(this.future, this.cancel);

  final Future<SentencePlaybackResult> future;
  final Future<void> Function() cancel;
}

/// 区间 seek 起点确认监听器，播放区间结束由 [_RangeWaiter] 独立管理。
class _RangeStartWaiter {
  const _RangeStartWaiter(this.started, this.cancel);

  final Future<bool> started;
  final Future<void> Function() cancel;
}

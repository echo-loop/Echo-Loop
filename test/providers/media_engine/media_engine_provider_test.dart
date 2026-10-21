import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/word_highlight_binding.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_playback_driver.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_sense_group_range_playback.dart';
import 'package:echo_loop/services/media_session_router.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shared/fake_media_player_backend.dart';

class _FirstPauseGateBackend extends FakeMediaPlayerBackend {
  final pauseGate = Completer<void>();
  bool _blockFirstPause = true;

  @override
  Future<void> pause() async {
    if (_blockFirstPause) {
      _blockFirstPause = false;
      await pauseGate.future;
    }
    await super.pause();
  }
}

void main() {
  late FakeMediaPlayerBackend backend;
  late MediaSessionRouter router;
  late ProviderContainer container;
  late Directory appDir;
  late File mediaFile;
  var backendFactoryCalls = 0;

  setUp(() async {
    backendFactoryCalls = 0;
    appDir = await Directory.systemTemp.createTemp('echo-loop-media-engine-');
    appDataDirectoryOverride = appDir;
    backend = FakeMediaPlayerBackend();
    router = MediaSessionRouter(defaultHandler: BaseAudioHandler());
    container = ProviderContainer(
      overrides: [
        mediaBackendFactoryProvider.overrideWithValue(() {
          backendFactoryCalls += 1;
          return backend;
        }),
        mediaSessionRouterProvider.overrideWithValue(router),
      ],
    );
    mediaFile = File('${appDir.path}/echo-loop-video-test.mp4');
    await mediaFile.writeAsBytes(const [0, 1, 2]);
  });

  tearDown(() async {
    container.dispose();
    appDataDirectoryOverride = null;
    if (await appDir.exists()) await appDir.delete(recursive: true);
  });

  AudioItem item() => AudioItem(
    id: 'video-1',
    name: 'Video',
    audioPath: 'echo-loop-video-test.mp4',
    addedDate: DateTime(2026, 7, 24),
  );

  test('loadMedia 成功后打开 backend 并激活媒体会话', () async {
    final engine = container.read(mediaEngineProvider.notifier);

    final duration = await engine.loadMedia(
      item(),
      1.25,
      initialPosition: const Duration(seconds: 4),
    );

    expect(duration, const Duration(seconds: 10));
    expect(backend.openCalls, [mediaFile.path]);
    expect(backend.openInitialPositions, [const Duration(seconds: 4)]);
    expect(backend.rateCalls, [1.25]);
    expect(router.isRouted, isTrue);
    expect(router.mediaItem.value?.id, 'video-1');
    expect(router.mediaItem.value?.title, 'Video');
    expect(
      router.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    expect(container.read(mediaEngineProvider).currentMediaId, 'video-1');

    final playingState = router.playbackState.firstWhere(
      (state) => state.playing,
    );
    await engine.play().timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError('engine.play timed out'),
    );
    await playingState.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError(
        'backend=${backend.playing} '
        'handler=${router.inner.playbackState.value.playing} '
        'router=${router.playbackState.value.playing}',
      ),
    );
    expect(router.playbackState.value.playing, isTrue);

    final clearedMediaItem = router.mediaItem.firstWhere(
      (mediaItem) => mediaItem == null,
    );
    final idleState = router.playbackState.firstWhere(
      (state) => state.processingState == AudioProcessingState.idle,
    );
    await engine.releaseFromScreen();
    await Future.wait<void>([
      clearedMediaItem.then<void>((_) {}),
      idleState.then<void>((_) {}),
    ]);
    expect(router.isRouted, isFalse);
    expect(router.mediaItem.value, isNull);
    expect(
      router.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test('前台播放可加载媒体但不发布系统媒体控制信息', () async {
    final engine = container.read(mediaEngineProvider.notifier);

    final duration = await engine.loadMedia(
      item(),
      1.0,
      publishToSystemMediaSession: false,
    );

    expect(duration, const Duration(seconds: 10));
    expect(backend.openCalls, [mediaFile.path]);
    expect(router.isRouted, isFalse);
    expect(router.mediaItem.value, isNull);
  });

  test('自然播放结束关闭逐词高亮，定位后重新启用', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    await engine.play();
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.playing,
    );

    final completedStatus = engine.wordHighlightPlaybackStatusStream.firstWhere(
      (status) => status == WordHighlightPlaybackStatus.completed,
    );
    backend.emitPlaying(false);
    backend.emitCompleted();
    await completedStatus;
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.completed,
    );

    await engine.seek(const Duration(seconds: 6));
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.paused,
    );
  });

  test('手动暂停保留高亮，之后的旧完成事件不清除它', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    await engine.play();

    await engine.pause();
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.paused,
    );

    final completionEvent = backend.completedController.stream.first;
    backend.emitCompleted();
    await completionEvent;
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.paused,
    );
  });

  test('旧 session 的迟到完成事件不会清除定位后的高亮', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    await engine.play();

    engine.newSession();
    await engine.seek(const Duration(seconds: 6));
    final pausedStatus = engine.wordHighlightPlaybackStatusStream.firstWhere(
      (status) => status == WordHighlightPlaybackStatus.paused,
    );
    backend.emitPlaying(false);
    await pausedStatus;
    final completionEvent = backend.completedController.stream.first;
    backend.emitCompleted();
    await completionEvent;

    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.paused,
    );
  });

  test('playRange 到达区间终点后自动暂停，并在起播前通知就绪', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    var readyCalls = 0;
    WordHighlightPlaybackStatus? statusAtReady;

    final playing = engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
      onRangeReady: () {
        readyCalls++;
        statusAtReady = engine.wordHighlightPlaybackStatus;
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.seekCalls.last, const Duration(seconds: 1));
    expect(backend.playCalls, 1);
    expect(readyCalls, 1);
    expect(statusAtReady, WordHighlightPlaybackStatus.idle);
    backend.emitPosition(const Duration(seconds: 3));
    expect(await playing, SentencePlaybackResult.completed);

    expect(backend.pauseCalls, 2);
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.completed,
    );
  });

  test('playRange 等收到目标位置事件后才开启逐词高亮', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    backend.emitPosition(const Duration(milliseconds: 3999));
    backend.deferSeekPositionUpdate = true;
    backend.playStarted = Completer<void>();

    final playback = engine.playRange(
      const Duration(seconds: 4),
      const Duration(seconds: 6),
      speed: 1.0,
    );
    await backend.playStarted!.future;

    expect(backend.playCalls, 1);
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.idle,
    );

    backend.emitPosition(const Duration(milliseconds: 3999));
    await Future<void>.delayed(Duration.zero);
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.idle,
    );

    final started = engine.wordHighlightPlaybackStatusStream.firstWhere(
      (status) => status == WordHighlightPlaybackStatus.playing,
    );
    backend.emitPosition(const Duration(seconds: 4));
    await started;
    expect(
      engine.wordHighlightPlaybackStatus,
      WordHighlightPlaybackStatus.playing,
    );

    backend.emitPosition(const Duration(seconds: 6));
    expect(await playback, SentencePlaybackResult.completed);
  });

  test('逐词高亮位置流会屏蔽播放区间起点前的陈旧样本', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    const rangeStart = Duration(seconds: 4);
    final rollbackObserved = Completer<Duration>();
    final highlightPositionSubscription = engine.wordHighlightPositionStream
        .listen((position) {
          if (backend.position < rangeStart && !rollbackObserved.isCompleted) {
            rollbackObserved.complete(position);
          }
        });
    addTearDown(highlightPositionSubscription.cancel);
    backend.playStarted = Completer<void>();
    backend.deferSeekPositionUpdate = true;

    final playback = engine.playRange(
      rangeStart,
      const Duration(seconds: 6),
      speed: 1.0,
    );
    await backend.playStarted!.future;

    final started = engine.wordHighlightPlaybackStatusStream.firstWhere(
      (status) => status == WordHighlightPlaybackStatus.playing,
    );
    backend.emitPosition(rangeStart);
    await started;
    backend.emitPosition(rangeStart - const Duration(milliseconds: 40));

    expect(await rollbackObserved.future, rangeStart);
    expect(backend.position, rangeStart - const Duration(milliseconds: 40));
    expect(engine.wordHighlightPosition, rangeStart);

    backend.emitPosition(const Duration(seconds: 6));
    expect(await playback, SentencePlaybackResult.completed);

    final positionAfterRange = rangeStart - const Duration(milliseconds: 40);
    backend.emitPosition(positionAfterRange);
    expect(engine.wordHighlightPosition, positionAfterRange);
  });

  test('playRange 会替换旧请求，旧请求不能暂停新请求', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    final first = engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);
    final second = engine.playRange(
      const Duration(seconds: 4),
      const Duration(seconds: 6),
      speed: 1.25,
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.seekCalls.last, const Duration(seconds: 4));
    backend.emitPosition(const Duration(seconds: 6));

    expect(await first, SentencePlaybackResult.cancelled);
    expect(await second, SentencePlaybackResult.completed);
    expect(backend.pauseCalls, 3);
  });

  test('旧 playToEnd 返回后不能暂停页面退出后重新加载的媒体', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final sessionId = engine.newSession();
    backend.playStarted = Completer<void>();
    backend.playGate = Completer<void>();

    final oldPlayback = engine.playToEnd(sessionId);
    await backend.playStarted!.future;

    var releaseCompleted = false;
    final release = engine.releaseFromScreen().then((_) {
      releaseCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(releaseCompleted, isFalse);
    backend.playGate!.complete();
    await release;
    await engine.loadMedia(item(), 1.0);
    await oldPlayback;

    expect(backend.playing, isFalse);
  });

  test('cancelActiveRange 会取消当前请求且不等待句尾事件', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    final playing = engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);
    await engine.cancelActiveRange(reason: 'user-next');

    expect(await playing, SentencePlaybackResult.cancelled);
    expect(backend.pauseCalls, 2);
  });

  test('释放媒体前等待已排队的区间控制，避免迟到暂停污染下一次播放', () async {
    final gatedBackend = _FirstPauseGateBackend();
    final gatedContainer = ProviderContainer(
      overrides: [
        mediaBackendFactoryProvider.overrideWithValue(() => gatedBackend),
        mediaSessionRouterProvider.overrideWithValue(router),
      ],
    );
    addTearDown(gatedContainer.dispose);
    final engine = gatedContainer.read(mediaEngineProvider.notifier);

    await engine.loadMedia(item(), 1.0);
    final playing = engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);

    final cancel = engine.cancelActiveRange(reason: 'intensive-dispose');
    var releaseCompleted = false;
    final release = engine.releaseFromScreen().then((_) {
      releaseCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(releaseCompleted, isFalse);
    gatedBackend.pauseGate.complete();
    await release;
    await cancel;
    expect(await playing, SentencePlaybackResult.cancelled);
  });

  test('页面解绑与重新加载串行执行，并复用同一 native backend', () async {
    backend.closeStreamsOnDispose = false;
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    final release = engine.releaseFromScreen();
    final reload = engine.loadMedia(item(), 1.0);

    await release;
    expect(await reload, const Duration(seconds: 10));
    expect(backend.openCalls, hasLength(2));
    expect(backendFactoryCalls, 1);
    expect(backend.disposed, isFalse);
  });

  test('pause 会取消旧区间，旧终点不再二次暂停', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    final playing = engine.playRange(
      Duration.zero,
      const Duration(seconds: 4),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);
    await engine.pause();
    backend.emitPosition(const Duration(seconds: 5));
    expect(await playing, SentencePlaybackResult.cancelled);

    expect(backend.pauseCalls, 2);
  });

  test('媒体时长不足以覆盖区间时自然结束仍返回 failed', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    backend.setDuration(const Duration(seconds: 2));
    await engine.loadMedia(item(), 1.0);

    final playing = engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);
    backend.emitPosition(const Duration(seconds: 2));
    backend.emitCompleted();

    expect(await playing, SentencePlaybackResult.failed);
    expect(backend.pauseCalls, 1);
  });

  test('媒体自然结束且实际时长覆盖区间时忽略滞后的位置缓存', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    final playing = engine.playRange(
      const Duration(seconds: 8),
      const Duration(milliseconds: 9950),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);

    // media_kit 的 EOF 事件先于最后一个 time-pos 更新到达；实际时长 10s
    // 已覆盖区间终点，但缓存位置仍落后 213ms。
    backend.setPositionWithoutEvent(const Duration(milliseconds: 9737));
    backend.emitCompleted();

    expect(await playing, SentencePlaybackResult.completed);
    expect(backend.pauseCalls, 2);
  });

  test('区间起播失败时清理结束监听，避免共享 backend 保留订阅', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    backend.playError = StateError('play failed');

    final result = await engine.playRange(
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      speed: 1.0,
    );

    expect(result, SentencePlaybackResult.failed);
    await backend.positionStreamCancelled.future;
  });

  test('媒体意群播放按当前速度播放区间，取消后活动 range 不再生效', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final playback = MediaSenseGroupRangePlayback(
      engine: engine,
      playbackSpeed: () => 1.25,
    );

    final playing = playback.play(
      'media-test',
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    );
    await Future<void>.delayed(Duration.zero);
    expect(backend.rateCalls.last, 1.25);
    expect(backend.seekCalls.last, const Duration(seconds: 2));

    await playback.cancel();
    backend.emitPosition(const Duration(seconds: 4));
    await playing;

    expect(backend.pauseCalls, 2);
  });

  test('媒体意群未开始播放时取消不会暂停主句 range', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final playback = MediaSenseGroupRangePlayback(
      engine: engine,
      playbackSpeed: () => 1.25,
    );

    final mainPlaying = engine.playRange(
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      speed: 1.0,
    );
    await Future<void>.delayed(Duration.zero);
    final pausesBeforeCancel = backend.pauseCalls;

    await playback.cancel();

    expect(backend.pauseCalls, pausesBeforeCancel);
    backend.emitPosition(const Duration(seconds: 4));
    expect(await mainPlaying, SentencePlaybackResult.completed);
  });

  test('disposeChain 交还会话并释放 backend', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    await engine.disposeChain();

    expect(router.isRouted, isFalse);
    expect(backend.stopCalls, 1);
    expect(backend.disposed, isTrue);
  });

  test('backend 释放失败时保留 owner，并允许后续重试释放', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    backend.closeStreamsOnDispose = false;
    backend.disposeError = StateError('native dispose failed');

    await engine.disposeChain();

    expect(backend.disposed, isFalse);
    expect(backend.disposeCalls, 1);
    backend.disposeError = null;
    await engine.disposeChain();

    expect(backend.disposed, isTrue);
    expect(backend.disposeCalls, 2);
  });

  test('releaseFromScreen 使 session 失效但保留 backend 供全局复用', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final playbackSessionId = engine.newSession();

    await engine.releaseFromScreen();

    expect(engine.isActiveSession(playbackSessionId), isFalse);
    expect(backend.pauseCalls, 1);
    expect(backend.stopCalls, 0);
    expect(router.isRouted, isFalse);
    expect(backend.disposed, isFalse);
  });

  test('detach 暂停失败也会解绑会话并清理媒体状态', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    backend.pauseError = StateError('pause failed');

    await expectLater(engine.releaseFromScreen(), throwsStateError);

    expect(router.isRouted, isFalse);
    expect(container.read(mediaEngineProvider).currentMediaId, isNull);
    expect(backend.disposed, isFalse);
  });

  test('setSubtitleTrackData 加载或关闭视频字幕轨', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    await engine.setSubtitleTrackData('1\n00:00:00,000 --> 00:00:01,000\nHi\n');
    await engine.setSubtitleTrackData(null);

    expect(backend.subtitleTrackDataCalls, [
      '1\n00:00:00,000 --> 00:00:01,000\nHi\n',
      null,
    ]);
    expect(container.read(mediaEngineProvider).subtitleTrackEnabled, isFalse);
  });

  test('MediaSentencePlaybackDriver按绝对句子区间播放并接管锁屏切句', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final driver = MediaSentencePlaybackDriver(engine);
    final playbackSessionId = driver.newSession();
    var previousCalls = 0;
    var nextCalls = 0;
    driver.bindLockScreen(
      onPlay: () async {},
      onPause: () async {},
      onPrevious: () async => previousCalls++,
      onNext: () async => nextCalls++,
    );

    final playing = driver.playSentence(
      Sentence(
        index: 0,
        text: 'hello',
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 5),
      ),
      playbackSessionId,
    );
    await Future<void>.delayed(Duration.zero);
    expect(backend.seekCalls.last, const Duration(seconds: 2));
    backend.emitPosition(const Duration(seconds: 5));
    await playing;

    await router.skipToPrevious();
    await router.skipToNext();
    expect(previousCalls, 1);
    expect(nextCalls, 1);

    driver.setSessionActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(backend.startKeepAliveCalls, 1);
    expect(router.playbackState.value.playing, isTrue);
    driver.setProgressFrozen(true);
    await Future<void>.delayed(Duration.zero);
    expect(router.playbackState.value.speed, 0);
    driver.unbindLockScreen();
    await Future<void>.delayed(Duration.zero);
    expect(backend.stopKeepAliveCalls, 1);
  });

  test('MediaSentencePlaybackDriver在播放中即时更新并保留新速度', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);
    final driver = MediaSentencePlaybackDriver(engine);
    final playbackSessionId = driver.newSession();

    final firstPlayback = driver.playSentence(
      Sentence(
        index: 0,
        text: 'first sentence',
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 3),
      ),
      playbackSessionId,
    );
    await Future<void>.delayed(Duration.zero);
    expect(backend.playing, isTrue);
    expect(backend.rate, 1.0);

    await driver.setSpeed(1.5);
    expect(backend.rate, 1.5);

    backend.emitPosition(const Duration(seconds: 3));
    expect(await firstPlayback, SentencePlaybackResult.completed);

    final secondPlayback = driver.playSentence(
      Sentence(
        index: 1,
        text: 'second sentence',
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 5),
      ),
      playbackSessionId,
    );
    await Future<void>.delayed(Duration.zero);
    expect(backend.rateCalls.last, 1.5);

    backend.emitPosition(const Duration(seconds: 5));
    expect(await secondPlayback, SentencePlaybackResult.completed);
  });

  test('ProviderContainer dispose 时释放 backend，避免热重启残留 native 链路', () async {
    final engine = container.read(mediaEngineProvider.notifier);
    await engine.loadMedia(item(), 1.0);

    container.dispose();
    await Future<void>.delayed(Duration.zero);
    container = ProviderContainer();

    expect(router.isRouted, isFalse);
    expect(backend.stopCalls, 1);
    expect(backend.disposed, isTrue);
  });
}

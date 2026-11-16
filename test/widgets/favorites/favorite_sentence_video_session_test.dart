import 'dart:async';

import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/widgets/favorites/favorite_sentence_video_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// 记录加载请求并由测试决定何时完成，用于模拟慢速加载与连续点击。
class _ControlledMediaEngine extends MediaEngine {
  final loadRequests = <({AudioItem item, Duration initialPosition})>[];
  final loadCompleters = <Completer<Duration?>>[];
  int releaseCalls = 0;

  @override
  Future<Duration?> loadMedia(
    AudioItem item,
    double speed, {
    Duration initialPosition = Duration.zero,
    bool publishToSystemMediaSession = true,
  }) {
    loadRequests.add((item: item, initialPosition: initialPosition));
    final completer = Completer<Duration?>();
    loadCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> releaseFromScreen() async {
    releaseCalls += 1;
  }

  @override
  Future<void> setVideoTrackEnabled(bool enabled) async {}

  @override
  Future<void> setSubtitleTrackData(String? srt) async {}
}

void main() {
  late ProviderContainer container;
  late _ControlledMediaEngine engine;
  late FakeAudioEngine audioEngine;
  late FakeAudioItemDao audioItemDao;
  late AudioItem videoItem;
  final sessions = <FavoriteSentenceVideoSession>[];

  setUp(() {
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWith(_ControlledMediaEngine.new),
        audioEngineProvider.overrideWith(() => FakeAudioEngine()),
      ],
    );
    engine =
        container.read(mediaEngineProvider.notifier) as _ControlledMediaEngine;
    audioEngine =
        container.read(audioEngineProvider.notifier) as FakeAudioEngine;
    audioItemDao = FakeAudioItemDao();
    videoItem = AudioItem(
      id: 'video-1',
      name: 'Video',
      audioPath: 'videos/clip.mp4',
      addedDate: DateTime(2026, 1, 1),
    );
  });

  tearDown(() async {
    for (final session in sessions) {
      await session.close();
    }
    sessions.clear();
    container.dispose();
  });

  FavoriteSentenceVideoSession createSession() {
    final session = FavoriteSentenceVideoSession(
      engine: engine,
      audioEngine: audioEngine,
      audioItemDao: audioItemDao,
    );
    sessions.add(session);
    return session;
  }

  /// 等待 open 内部在暂停音频后发起的加载请求。
  Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

  test('打开视频时加载材料并定位到句首，同时停止正在播放的音频', () async {
    audioEngine.isPlaying = true;
    final session = createSession();

    final opening = session.open(
      item: videoItem,
      sentenceStart: const Duration(seconds: 51),
    );
    await flushMicrotasks();
    engine.loadCompleters.single.complete(const Duration(minutes: 10));

    expect(await opening, FavoriteVideoOpenResult.opened);
    expect(engine.loadRequests.single.item.id, 'video-1');
    expect(
      engine.loadRequests.single.initialPosition,
      const Duration(seconds: 51),
    );
    expect(audioEngine.isPlaying, isFalse);
    expect(session.mediaSession, isNotNull);
  });

  test('视频加载失败时返回 failed，关闭时释放本次引擎会话', () async {
    final session = createSession();

    final opening = session.open(item: videoItem, sentenceStart: Duration.zero);
    await flushMicrotasks();
    engine.loadCompleters.single.complete(null);

    expect(await opening, FavoriteVideoOpenResult.failed);
    await session.close();
    expect(engine.releaseCalls, 1);
  });

  test('连续打开时前一次返回 cancelled，关闭前一次不会释放后一次的会话', () async {
    final first = createSession();
    final second = createSession();

    final firstOpening = first.open(
      item: videoItem,
      sentenceStart: const Duration(seconds: 1),
    );
    await flushMicrotasks();
    final secondOpening = second.open(
      item: videoItem,
      sentenceStart: const Duration(seconds: 4),
    );
    await flushMicrotasks();
    engine.loadCompleters[0].complete(const Duration(minutes: 10));
    engine.loadCompleters[1].complete(const Duration(minutes: 10));

    expect(await firstOpening, FavoriteVideoOpenResult.cancelled);
    expect(await secondOpening, FavoriteVideoOpenResult.opened);

    await first.close();
    expect(engine.releaseCalls, 0);
    await second.close();
    expect(engine.releaseCalls, 1);
  });

  test('关闭会话只释放一次', () async {
    final session = createSession();
    final opening = session.open(item: videoItem, sentenceStart: Duration.zero);
    await flushMicrotasks();
    engine.loadCompleters.single.complete(const Duration(minutes: 10));
    await opening;

    await session.close();
    await session.close();

    expect(engine.releaseCalls, 1);
  });

  test('未成功打开前不能借用讲解画面', () {
    final session = createSession();

    expect(() => session.mediaSession, throwsStateError);
  });
}

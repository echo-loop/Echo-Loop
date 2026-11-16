import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/widgets/common/media_presentation_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// 只记录视频轨与字幕轨的调用，不触达真实 media_kit 后端。
class _RecordingMediaEngine extends MediaEngine {
  final videoTrackCalls = <bool>[];
  final subtitleCalls = <String?>[];

  @override
  Future<void> setVideoTrackEnabled(bool enabled) async {
    videoTrackCalls.add(enabled);
  }

  @override
  Future<void> setSubtitleTrackData(String? srt) async {
    subtitleCalls.add(srt);
  }
}

void main() {
  late ProviderContainer container;
  late _RecordingMediaEngine engine;
  late FakeAudioItemDao audioItemDao;

  setUp(() {
    container = ProviderContainer(
      overrides: [mediaEngineProvider.overrideWith(_RecordingMediaEngine.new)],
    );
    engine =
        container.read(mediaEngineProvider.notifier) as _RecordingMediaEngine;
    audioItemDao = FakeAudioItemDao();
  });

  tearDown(() {
    container.dispose();
  });

  MediaPresentationController createController({
    String audioItemId = 'video-1',
  }) {
    return MediaPresentationController(
      engine: engine,
      readTranscriptSrt: audioItemDao.getTranscriptSrt,
      audioItemId: audioItemId,
    );
  }

  test('隐藏视频轨时同步引擎并通知监听者', () async {
    final controller = createController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await controller.setVisualTrackVisible(false);

    expect(engine.videoTrackCalls, [false]);
    expect(controller.visualTrackVisible, isFalse);
    expect(notifications, 1);
  });

  test('开启字幕时读取当前材料字幕，关闭时清空字幕轨', () async {
    audioItemDao.transcriptSrtStore['video-1'] =
        '1\n00:00:01,000 --> 00:00:02,000\nHi\n';
    final controller = createController();

    await controller.setSubtitleVisible(true);
    expect(engine.subtitleCalls, [audioItemDao.transcriptSrtStore['video-1']]);
    expect(controller.subtitleVisible, isTrue);

    await controller.setSubtitleVisible(false);
    expect(engine.subtitleCalls.last, isNull);
    expect(controller.subtitleVisible, isFalse);
  });

  test('切换材料时清除字幕开关，之后开启读取新材料的字幕', () async {
    audioItemDao.transcriptSrtStore['video-1'] = 'old';
    audioItemDao.transcriptSrtStore['video-2'] = 'new';
    final controller = createController();
    await controller.setSubtitleVisible(true);

    controller.switchAudioItem('video-2');
    expect(controller.subtitleVisible, isFalse);

    await controller.setSubtitleVisible(true);
    expect(engine.subtitleCalls.last, 'new');
  });

  test('后台禁用视频轨，回到前台时仅在画面可见时恢复', () async {
    final controller = createController();

    controller.handleLifecycleState(AppLifecycleState.paused);
    expect(engine.videoTrackCalls, [false]);

    controller.handleLifecycleState(AppLifecycleState.resumed);
    expect(engine.videoTrackCalls, [false, true]);

    await controller.setVisualTrackVisible(false);
    controller.handleLifecycleState(AppLifecycleState.paused);
    controller.handleLifecycleState(AppLifecycleState.resumed);
    // 画面已隐藏：回到前台不应重新打开视频轨。
    expect(engine.videoTrackCalls, [false, true, false, false]);
  });
}

/// 随心听视频自适应分栏的 macOS 交互测试。
///
/// 与学习任务页共用 [PracticeMediaSplitLayout]，在真实桌面渲染（真实字体、
/// 鼠标手势）下验证：
/// - 按窗口尺寸在上下 / 左右布局间切换，视频、字幕与控制面板不重叠、不溢出；
/// - 鼠标拖动分隔条调整视频尺寸并记住比例，双击恢复默认；
/// - 视频加载期间占位就在视频槽内，ready 前后布局方向不变。
///
/// 运行：flutter test integration_test/media_playback_split_test.dart -d macos
library;

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:echo_loop/database/daos/playback_state_dao.dart';
import 'package:echo_loop/database/app_database.dart' hide AudioItem;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/practice_media_split_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/screens/media_playback_screen.dart';
import 'package:echo_loop/services/media_session_router.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:echo_loop/widgets/common/paragraph_sentence_list_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/helpers/shared/fake_media_player_backend.dart';
import 'helpers/test_main_setup.dart';
import 'helpers/test_notifiers.dart';

const _stackedKey = ValueKey('practice-media-split-stacked');
const _sideBySideKey = ValueKey('practice-media-split-side-by-side');
const _dividerKey = ValueKey('practice-media-split-divider');
const _videoKey = ValueKey('media-visual-surface');
const _controlPanelKey = ValueKey('media-control-panel');
const _startupCanvasKey = ValueKey('media-startup-canvas');

/// 覆盖手机竖屏、平板竖屏、近方形窗口、笔记本与宽屏桌面窗口。
const _windowSizes = <(String, Size, ValueKey<String>)>[
  ('手机竖屏', Size(390, 844), _stackedKey),
  ('平板竖屏', Size(820, 1180), _stackedKey),
  ('近方形窗口', Size(700, 700), _stackedKey),
  ('笔记本窗口', Size(1280, 800), _sideBySideKey),
  ('宽屏桌面', Size(1600, 900), _sideBySideKey),
];

class _MockPlaybackStateDao extends Mock implements PlaybackStateDao {}

class _FakePlaybackStatesCompanion extends Fake
    implements PlaybackStatesCompanion {}

/// 字幕读取可由 [gate] 挂起，用来让页面停在加载态。
class _TranscriptAudioEngine extends TestAudioEngine {
  _TranscriptAudioEngine(this.gate);

  final Future<void>? gate;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async {
    await gate;
    return createTestSentences(count: 12);
  }
}

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  late Directory appDir;
  late AudioItem videoItem;

  setUpAll(() => registerFallbackValue(_FakePlaybackStatesCompanion()));

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('echo-loop-media-split-');
    appDataDirectoryOverride = appDir;
    await File('${appDir.path}/media-split.mp4').writeAsBytes(const [0, 1, 2]);
    videoItem = createTestAudioItem(
      id: 'media-split-video',
      name: 'Split Video',
      audioPath: 'media-split.mp4',
    );
  });

  tearDown(() async {
    appDataDirectoryOverride = null;
    if (await appDir.exists()) await appDir.delete(recursive: true);
  });

  /// 打开随心听视频页，字幕在 [beforeReady] 完成后才返回；返回 App 的 ProviderContainer。
  Future<ProviderContainer> openMediaPlayback(
    WidgetTester tester, {
    Future<void>? beforeReady,
  }) async {
    addTearDown(tester.view.reset);
    final playbackStateDao = _MockPlaybackStateDao();
    when(
      () => playbackStateDao.getByAudioId(any()),
    ).thenAnswer((_) async => null);
    when(() => playbackStateDao.saveState(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      createTestAppWithAudio(
        extraOverrides: [
          mediaBackendFactoryProvider.overrideWithValue(
            FakeMediaPlayerBackend.new,
          ),
          mediaSessionRouterProvider.overrideWithValue(
            MediaSessionRouter(defaultHandler: BaseAudioHandler()),
          ),
          playbackStateDaoProvider.overrideWithValue(playbackStateDao),
          audioEngineProvider.overrideWith(
            () => _TranscriptAudioEngine(beforeReady),
          ),
        ],
      ),
    );
    await safeSettle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EchoLoopApp)),
    );
    // 视频尺寸偏好存于整个测试进程共享的 SharedPreferences，逐个用例清空以免互相影响。
    final split = container.read(practiceMediaSplitProvider.notifier);
    for (final axis in PracticeMediaSplitAxis.values) {
      await split.setVideoFraction(axis, null);
    }
    // 冷启动期间路由仍在等待地区等启动信息，过早 push 会被启动重定向覆盖；
    // 未进入页面时有界重试。
    final screen = find.byType(MediaPlaybackScreen);
    final route = '/audio/${videoItem.id}/${AppRoutes.mediaPlayerSegment}';
    for (var attempt = 0; attempt < 5 && screen.evaluate().isEmpty; attempt++) {
      unawaited(
        container.read(appRouterProvider).push(route, extra: videoItem),
      );
      await _settle(tester);
    }
    expect(screen, findsOneWidget, reason: '未能进入随心听页面');
    return container;
  }

  group('随心听视频自适应分栏', () {
    testWidgets('各窗口尺寸布局方向正确，视频、字幕与控制面板不重叠不溢出', (tester) async {
      await openMediaPlayback(tester);
      for (final (label, size, expectedKey) in _windowSizes) {
        await _resizeWindow(tester, size);
        _expectSplitLayout(
          tester,
          label: label,
          size: size,
          expectedKey: expectedKey,
        );
      }
    });

    testWidgets('左右布局拖动分隔条调宽视频，记住比例，双击恢复默认', (tester) async {
      final container = await openMediaPlayback(tester);
      await _resizeWindow(tester, const Size(1280, 800));
      await _expectDragAndReset(
        tester,
        container,
        axis: PracticeMediaSplitAxis.sideBySide,
        delta: const Offset(-160, 0),
      );
    });

    testWidgets('上下布局拖动分隔条调整视频高度，拉到最大字幕与控制面板仍完整', (tester) async {
      final container = await openMediaPlayback(tester);
      await _resizeWindow(tester, const Size(390, 844));
      // 横屏视频在竖屏窗口默认已按宽度铺满（自然高度即上限），只能向上拖小。
      await _expectDragAndReset(
        tester,
        container,
        axis: PracticeMediaSplitAxis.stacked,
        delta: const Offset(0, -80),
      );
      // 一直拖到底：视频被限制在上限，内容区保留最小高度且不溢出。
      await _dragDivider(tester, const Offset(0, 900));
      _expectSplitLayout(
        tester,
        label: '拉到最大',
        size: const Size(390, 844),
        expectedKey: _stackedKey,
      );
    });

    testWidgets('宽屏加载中占位位于左侧视频槽，ready 后保持左右布局', (tester) async {
      final load = Completer<void>();
      await openMediaPlayback(tester, beforeReady: load.future);
      await _resizeWindow(tester, const Size(1280, 800));

      expect(find.byKey(_sideBySideKey), findsOneWidget);
      final canvas = find.byKey(_startupCanvasKey);
      expect(canvas, findsOneWidget);
      expect(
        tester.getRect(canvas).right,
        lessThanOrEqualTo(tester.getRect(find.byKey(_controlPanelKey)).left),
      );

      load.complete();
      await _settle(tester);
      expect(find.byKey(_sideBySideKey), findsOneWidget);
      expect(canvas, findsNothing);
      expect(find.byKey(_videoKey), findsOneWidget);
    });
  });
}

Future<void> _resizeWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await _settle(tester);
}

/// 页面包含持续动画（加载指示、播放高亮），只做有界推进。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectSplitLayout(
  WidgetTester tester, {
  required String label,
  required Size size,
  required ValueKey<String> expectedKey,
}) {
  expect(tester.takeException(), isNull, reason: '$label 出现布局异常');
  expect(find.byKey(expectedKey), findsOneWidget, reason: '$label 布局方向');

  final video = tester.getRect(find.byKey(_videoKey));
  final transcript = tester.getRect(find.byType(ParagraphSentenceListCard));
  final controlPanel = tester.getRect(find.byKey(_controlPanelKey));
  if (expectedKey == _sideBySideKey) {
    expect(video.right, lessThanOrEqualTo(transcript.left), reason: label);
    expect(video.right, lessThanOrEqualTo(controlPanel.left), reason: label);
  } else {
    expect(video.bottom, lessThanOrEqualTo(transcript.top), reason: label);
  }
  expect(transcript.bottom, lessThanOrEqualTo(controlPanel.top), reason: label);
  expect(transcript.height, greaterThan(0), reason: label);
  // 控制面板完整可见：内容区没有被视频挤出窗口。
  expect(controlPanel.bottom, lessThanOrEqualTo(size.height), reason: label);
  expect(video.width, greaterThan(0), reason: label);
  expect(video.height, greaterThan(0), reason: label);
}

Future<void> _dragDivider(WidgetTester tester, Offset delta) async {
  final divider = find.byKey(_dividerKey);
  final gesture = await tester.startGesture(
    tester.getCenter(divider),
    kind: PointerDeviceKind.mouse,
  );
  // 分多步移动，贴近真实鼠标拖动，并越过拖动识别阈值。
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(delta / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _settle(tester);
}

Future<void> _doubleClickDivider(WidgetTester tester) async {
  final center = tester.getCenter(find.byKey(_dividerKey));
  for (var i = 0; i < 2; i++) {
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 60));
  }
  await _settle(tester);
}

Future<void> _expectDragAndReset(
  WidgetTester tester,
  ProviderContainer container, {
  required PracticeMediaSplitAxis axis,
  required Offset delta,
}) async {
  final isStacked = axis == PracticeMediaSplitAxis.stacked;
  double videoExtent() {
    final size = tester.getSize(find.byKey(_videoKey));
    return isStacked ? size.height : size.width;
  }

  final before = videoExtent();
  expect(container.read(practiceMediaSplitProvider).fractionFor(axis), isNull);

  await _dragDivider(tester, delta);
  final dragged = videoExtent();
  final expectedChange = isStacked ? delta.dy : delta.dx;
  expect(
    (dragged - before).sign,
    expectedChange.sign,
    reason: '拖动后视频尺寸应随拖动方向变化',
  );
  expect(
    container.read(practiceMediaSplitProvider).fractionFor(axis),
    isNotNull,
    reason: '松手后应记住比例',
  );
  expect(tester.takeException(), isNull);

  await _doubleClickDivider(tester);
  expect(
    container.read(practiceMediaSplitProvider).fractionFor(axis),
    isNull,
    reason: '双击后恢复默认',
  );
  expect(videoExtent(), closeTo(before, 1), reason: '双击后恢复默认尺寸');
}

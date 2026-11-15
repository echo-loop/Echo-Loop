/// 学习任务页视频自适应分栏的 macOS 交互测试。
///
/// 在真实桌面渲染（真实字体、鼠标手势）下，逐个任务页验证：
/// - 按窗口尺寸在上下 / 左右布局间切换，视频与学习内容不重叠、不溢出；
/// - 鼠标拖动分隔条调整视频尺寸并记住比例，双击恢复默认；
/// - 视频加载期间占位就在视频槽内，ready 前后布局方向不变。
///
/// 运行：flutter test integration_test/practice_media_split_test.dart -d macos
library;

import 'dart:async';

import 'package:echo_loop/main.dart';
import 'package:echo_loop/models/media_learning_startup.dart';
import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_phase.dart';
import 'package:echo_loop/providers/practice_media_split_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/screens/blind_listen_player_screen.dart';
import 'package:echo_loop/screens/intensive_listen_player_screen.dart';
import 'package:echo_loop/screens/listen_and_repeat_player_screen.dart';
import 'package:echo_loop/screens/retell_player_screen.dart';
import 'package:echo_loop/screens/review_difficult_practice_screen.dart';
import 'package:echo_loop/widgets/practice/practice_progress_section.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_main_setup.dart';
import 'helpers/test_notifiers.dart';

const _stackedKey = ValueKey('practice-media-split-stacked');
const _sideBySideKey = ValueKey('practice-media-split-side-by-side');
const _dividerKey = ValueKey('practice-media-split-divider');
const _videoKey = ValueKey('media-visual-surface');
const _startupCanvasKey = ValueKey('media-startup-canvas');

/// 覆盖手机竖屏、平板竖屏、近方形窗口、笔记本与宽屏桌面窗口。
const _windowSizes = <(String, Size, ValueKey<String>)>[
  ('手机竖屏', Size(390, 844), _stackedKey),
  ('平板竖屏', Size(820, 1180), _stackedKey),
  ('近方形窗口', Size(700, 700), _stackedKey),
  ('笔记本窗口', Size(1280, 800), _sideBySideKey),
  ('宽屏桌面', Size(1600, 900), _sideBySideKey),
];

/// 一个视频学习任务页的进入方式。
class _PracticeTask {
  const _PracticeTask({
    required this.name,
    required this.route,
    required this.screenType,
    required this.learningMode,
    required this.prepare,
    this.overrides = const [],
  });

  final String name;
  final Type screenType;
  final String route;
  final LearningMode learningMode;

  /// 在 load 中准备该任务的视频会话，对应真实入口里 controller 的初始化。
  final Future<void> Function(ProviderContainer container) prepare;

  /// 该任务额外需要的 Provider 替身。
  final List<Override> overrides;
}

const _taskRoot = '/collections/test-collection-1/test-audio-1';

final _tasks = <_PracticeTask>[
  _PracticeTask(
    name: '全文盲听',
    route: '$_taskRoot/blind-listen',
    screenType: BlindListenPlayerScreen,
    learningMode: LearningMode.blindListen,
    prepare: (container) async =>
        (container.read(
          blindListenPlayerProvider.notifier,
        ) as TestBlindListenPlayer).setState(
          const BlindListenPlayerState(
            currentParagraphIndex: 0,
            totalParagraphs: 3,
          ),
        ),
  ),
  _PracticeTask(
    name: '逐句精听',
    route: '$_taskRoot/intensive-listen',
    screenType: IntensiveListenPlayerScreen,
    learningMode: LearningMode.intensiveListen,
    prepare: (container) => container
        .read(intensiveListenPlayerProvider.notifier)
        .initialize(createTestSentences(), hasVideo: true),
  ),
  _PracticeTask(
    name: '难句跟读',
    route: '$_taskRoot/listen-and-repeat',
    screenType: ListenAndRepeatPlayerScreen,
    learningMode: LearningMode.listenAndRepeat,
    prepare: (container) async {},
    overrides: [
      listenAndRepeatControllerProvider.overrideWith(
        _VideoListenAndRepeatController.new,
      ),
    ],
  ),
  _PracticeTask(
    name: '段落复述',
    route: '$_taskRoot/retell',
    screenType: RetellPlayerScreen,
    learningMode: LearningMode.retell,
    prepare: (container) async {
      final player =
          container.read(retellPlayerProvider.notifier) as TestRetellPlayer;
      final sentences = createTestSentences(count: 6);
      player.setTestParagraphs([sentences.sublist(0, 3), sentences.sublist(3)]);
      player.setState(
        const RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: 2,
          phase: RetellPhase.listening,
        ),
      );
    },
  ),
  _PracticeTask(
    name: '难句复习',
    route: '$_taskRoot/review-difficult-practice',
    screenType: ReviewDifficultPracticeScreen,
    learningMode: LearningMode.reviewDifficultPractice,
    prepare: (container) =>
        container.read(reviewDifficultPracticeProvider.notifier).initialize([
          for (final sentence in createTestSentences())
            sentence.copyWith(isBookmarked: true),
        ], hasVideo: true),
  ),
];

/// 难句跟读的视频会话替身：只提供已准备好的句子与带视频的状态，不驱动真实播放。
class _VideoListenAndRepeatController extends ListenAndRepeatController {
  final List<Sentence> _sentences = createTestSentences();

  @override
  ListenAndRepeatSessionState build() => ListenAndRepeatSessionState(
    phase: const WaitingForUser(WaitingReason.userInteraction),
    sentenceIndex: 0,
    totalSentences: _sentences.length,
    repeatIndex: 0,
    totalRepeats: 3,
    flowToken: 1,
    currentSentenceBookmarked: true,
    hasVideo: true,
  );

  @override
  List<Sentence> get sentences => _sentences;

  @override
  bool get isSessionPrepared => true;

  @override
  Sentence? get currentSentence => _sentences[state.sentenceIndex];

  @override
  String get currentPromptId => 'lar:test-audio-1:${state.sentenceIndex}';

  @override
  Future<void> startPlaying() async {}

  @override
  void enterWaitingForUser() {}

  @override
  void enterWaitingForUserAfterCurrentPrompt() {}

  @override
  Future<void> exitLearningMode() async {}
}

void main() {
  setupIntegrationTestBinding();
  registerCommonSetUpAll();

  for (final task in _tasks) {
    group('视频自适应分栏：${task.name}', () {
      testWidgets('各窗口尺寸布局方向正确，视频与内容不重叠不溢出', (tester) async {
        await _openTask(tester, task);
        for (final (label, size, expectedKey) in _windowSizes) {
          await _resizeWindow(tester, size);
          _expectSplitLayout(
            tester,
            label: '${task.name}/$label',
            size: size,
            expectedKey: expectedKey,
          );
        }
      });

      testWidgets('左右布局拖动分隔条调宽视频，记住比例，双击恢复默认', (tester) async {
        final container = await _openTask(tester, task);
        await _resizeWindow(tester, const Size(1280, 800));
        await _expectDragAndReset(
          tester,
          container,
          axis: PracticeMediaSplitAxis.sideBySide,
          delta: const Offset(-160, 0),
          label: task.name,
        );
      });

      testWidgets('上下布局拖动分隔条调整视频高度，拉到最大学习区仍完整', (tester) async {
        final container = await _openTask(tester, task);
        await _resizeWindow(tester, const Size(390, 844));
        // 横屏视频在竖屏窗口默认已按宽度铺满（自然高度即上限），只能向上拖小。
        await _expectDragAndReset(
          tester,
          container,
          axis: PracticeMediaSplitAxis.stacked,
          delta: const Offset(0, -80),
          label: task.name,
        );
        // 一直拖到底：视频被限制在上限，学习区保留最小高度且不溢出。
        await _dragDivider(tester, const Offset(0, 900));
        _expectSplitLayout(
          tester,
          label: '${task.name}/拉到最大',
          size: const Size(390, 844),
          expectedKey: _stackedKey,
        );
      });

      testWidgets('宽屏加载中占位位于左侧视频槽，ready 后保持左右布局', (tester) async {
        final load = Completer<void>();
        await _openTask(tester, task, beforeReady: load.future);
        await _resizeWindow(tester, const Size(1280, 800));

        expect(find.byKey(_sideBySideKey), findsOneWidget);
        final canvas = find.byKey(_startupCanvasKey);
        expect(canvas, findsOneWidget);
        expect(
          tester.getRect(canvas).right,
          lessThanOrEqualTo(
            tester.getRect(find.byType(PracticeProgressBar)).left,
          ),
        );

        load.complete();
        await _settle(tester);
        expect(find.byKey(_sideBySideKey), findsOneWidget);
        expect(canvas, findsNothing);
        expect(find.byKey(_videoKey), findsOneWidget);
      });
    });
  }
}

/// 打开任务页，媒体在 [beforeReady] 完成后 ready；返回 App 的 ProviderContainer。
Future<ProviderContainer> _openTask(
  WidgetTester tester,
  _PracticeTask task, {
  Future<void>? beforeReady,
}) async {
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    createTestAppWithAudio(extraOverrides: task.overrides),
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
  (container.read(learningSessionProvider.notifier) as TestLearningSession)
      .setState(
        LearningSessionState(
          learningMode: task.learningMode,
          audioItemId: 'test-audio-1',
          playbackChain: LearningPlaybackChain.mediaEngine,
        ),
      );
  final startup = MediaLearningStartup(
    loadKey: '${task.name}-video',
    load: () async {
      await beforeReady;
      await task.prepare(container);
      return MediaLoadResult.ready;
    },
    cancel: () async {},
  );
  // 冷启动期间路由仍在等待地区等启动信息，过早 push 会被启动重定向覆盖；
  // 未进入任务页时有界重试。
  final screen = find.byType(task.screenType);
  for (var attempt = 0; attempt < 5 && screen.evaluate().isEmpty; attempt++) {
    unawaited(
      container.read(appRouterProvider).push(task.route, extra: startup),
    );
    await _settle(tester);
  }
  expect(screen, findsOneWidget, reason: '${task.name} 未能进入任务页');
  return container;
}

Future<void> _resizeWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await _settle(tester);
}

/// 学习页包含持续动画（倒计时、播放指示），只做有界推进。
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
  final progress = tester.getRect(find.byType(PracticeProgressBar));
  final nextButton = tester.getRect(find.byIcon(Icons.skip_next_rounded).last);
  if (expectedKey == _sideBySideKey) {
    expect(video.right, lessThanOrEqualTo(progress.left), reason: label);
  } else {
    expect(video.bottom, lessThanOrEqualTo(progress.top), reason: label);
  }
  // 底栏完整可见：内容区没有被视频挤出窗口。
  expect(nextButton.bottom, lessThanOrEqualTo(size.height), reason: label);
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
  required String label,
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
    reason: '$label 拖动后视频尺寸应随拖动方向变化',
  );
  expect(
    container.read(practiceMediaSplitProvider).fractionFor(axis),
    isNotNull,
    reason: '$label 松手后应记住比例',
  );
  expect(tester.takeException(), isNull);

  await _doubleClickDivider(tester);
  expect(
    container.read(practiceMediaSplitProvider).fractionFor(axis),
    isNull,
    reason: '$label 双击后恢复默认',
  );
  expect(videoExtent(), closeTo(before, 1), reason: '$label 双击后恢复默认尺寸');
}

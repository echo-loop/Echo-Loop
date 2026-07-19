// Widget 集成测试：验证 GuideFlowSequenceHost + GuideTarget 与 showcaseview
// 的集成能正确 启动 tour / 通过 onFinish 回到 controller / 已 seen 不重跑。
//
// 故意不使用 AppLocalizations——用 `Localizations.override` + 直接 MaterialApp，
// 避免引入整个 l10n 生成路径。但 GuideTarget 内部需要 AppLocalizations，
// 所以 import 并通过 MaterialApp.localizationsDelegates 注入。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:echo_loop/widgets/guide_flow.dart';

/// Helper：包一个完整的 MaterialApp + ProviderScope，支持注入覆盖。
Widget _wrap({required Widget child, required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// 为测试创建一个独立的 [ShowcaseView] 实例并自动注销。
/// 同一测试文件内所有测试 **必须顺序执行**，ShowcaseView 用单例注册表。
void _registerTestShowcaseView() {
  final view = ShowcaseView.register(
    onFinish: GuideShowcaseBus.fireEnd,
    onDismiss: (_) => GuideShowcaseBus.fireEnd(),
  );
  addTearDown(view.unregister);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuideShowcaseBus.setOnEnd(null);
  });

  testWidgets('启动 flow 时 ShowcaseView 收到全部 step 的 key', (tester) async {
    _registerTestShowcaseView();
    final key1 = GlobalKey();
    final key2 = GlobalKey();

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        guideRegistryProvider.overrideWithValue(GuideRegistry(prefs: prefs)),
      ],
    );
    addTearDown(container.dispose);

    final step1 = GuideStep(
      key: key1,
      title: 'Step 1',
      description: 'Description 1',
    );
    final step2 = GuideStep(
      key: key2,
      title: 'Step 2',
      description: 'Description 2',
    );

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: GuideFlowSequenceHost(
          flows: [
            GuideFlow(
              flowId: 'test_flow',
              shouldRun: true,
              steps: [step1, step2],
            ),
          ],
          child: Column(
            children: [
              GuideTarget(step: step1, child: const Text('T1')),
              GuideTarget(step: step2, child: const Text('T2')),
            ],
          ),
        ),
      ),
    );

    // 让 postFrame + state check 全部跑完
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Controller 应已标记 active
    expect(
      container.read(guideControllerProvider).activeFlowId,
      'test_flow',
      reason: 'flow should be active after postFrame',
    );

    // Showcaseview 应在跑，active key 应为 step1（列表首个）
    expect(ShowcaseView.get().isShowcaseRunning, isTrue);
    expect(ShowcaseView.get().getActiveShowcaseKey, same(key1));
  });

  testWidgets('showcase 结束（onFinish）时 controller markSeen 并清空 active', (
    tester,
  ) async {
    _registerTestShowcaseView();
    final key = GlobalKey();

    final prefs = await SharedPreferences.getInstance();
    final registry = GuideRegistry(prefs: prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        guideRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    final step = GuideStep(
      key: key,
      title: 'Only',
      description: 'Only description',
    );

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: GuideFlowSequenceHost(
          flows: [
            GuideFlow(flowId: 'only', shouldRun: true, steps: [step]),
          ],
          child: GuideTarget(step: step, child: const Text('T')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(guideControllerProvider).activeFlowId, 'only');
    expect(ShowcaseView.get().isShowcaseRunning, isTrue);

    // 模拟用户点 next 完成 tour——last step 的 next 会触发 onFinish。
    ShowcaseView.get().next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(guideControllerProvider).isActive, isFalse);
    expect(await registry.isSeen('only'), isTrue);
  });

  testWidgets('已 seen 的 flow 不再启动 showcase', (tester) async {
    _registerTestShowcaseView();
    final key = GlobalKey();

    SharedPreferences.setMockInitialValues({'guide_v1_seen_flow_seen': true});
    final prefs = await SharedPreferences.getInstance();
    final registry = GuideRegistry(prefs: prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        guideRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    final step = GuideStep(key: key, title: 'T', description: 'D');

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: GuideFlowSequenceHost(
          flows: [
            GuideFlow(flowId: 'seen_flow', shouldRun: true, steps: [step]),
          ],
          child: GuideTarget(step: step, child: const Text('T')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(guideControllerProvider).isActive, isFalse);
    expect(ShowcaseView.get().isShowcaseRunning, isFalse);
  });

  testWidgets('shouldRun=false 的 flow 会跳过，继续尝试下一个 flow', (tester) async {
    _registerTestShowcaseView();
    final keySkipped = GlobalKey();
    final keyActive = GlobalKey();

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        guideRegistryProvider.overrideWithValue(GuideRegistry(prefs: prefs)),
      ],
    );
    addTearDown(container.dispose);

    final stepSkipped = GuideStep(
      key: keySkipped,
      title: 'Skip',
      description: 'Skip',
    );
    final stepActive = GuideStep(
      key: keyActive,
      title: 'Active',
      description: 'Active',
    );

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: GuideFlowSequenceHost(
          flows: [
            GuideFlow(
              flowId: 'skipped',
              shouldRun: false,
              steps: [stepSkipped],
            ),
            GuideFlow(flowId: 'active', shouldRun: true, steps: [stepActive]),
          ],
          child: Column(
            children: [
              GuideTarget(step: stepSkipped, child: const Text('Skip')),
              GuideTarget(step: stepActive, child: const Text('Active')),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(container.read(guideControllerProvider).activeFlowId, 'active');
    expect(ShowcaseView.get().getActiveShowcaseKey, same(keyActive));
  });

  testWidgets('上一个 flow 完成后自动启动下一个 flow', (tester) async {
    _registerTestShowcaseView();
    final keyA = GlobalKey();
    final keyB = GlobalKey();

    final prefs = await SharedPreferences.getInstance();
    final registry = GuideRegistry(prefs: prefs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        guideRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    final stepA = GuideStep(key: keyA, title: 'A', description: 'A');
    final stepB = GuideStep(key: keyB, title: 'B', description: 'B');

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: GuideFlowSequenceHost(
          flows: [
            GuideFlow(flowId: 'flow_a', shouldRun: true, steps: [stepA]),
            GuideFlow(flowId: 'flow_b', shouldRun: true, steps: [stepB]),
          ],
          child: Column(
            children: [
              GuideTarget(step: stepA, child: const Text('A')),
              GuideTarget(step: stepB, child: const Text('B')),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // flow_a 先跑
    expect(container.read(guideControllerProvider).activeFlowId, 'flow_a');
    expect(ShowcaseView.get().getActiveShowcaseKey, same(keyA));

    // 完成 flow_a
    ShowcaseView.get().next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(await registry.isSeen('flow_a'), isTrue);

    // flow_b 自动接力
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(guideControllerProvider).activeFlowId, 'flow_b');
    expect(ShowcaseView.get().getActiveShowcaseKey, same(keyB));
  });
}

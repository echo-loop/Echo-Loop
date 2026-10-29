import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import 'package:echo_loop/providers/new_user_guide_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('引导开关与跳过', () {
    test('setEnabled 只写本机，不做云同步', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(guideEnabledProvider.notifier).setEnabled(false);

      expect(prefs.getBool(GuideRegistry.enabledKey), isFalse);
      expect(container.read(guideEnabledProvider), isFalse);
    });

    test('skipAll 关闭引导开关，并同步内存状态', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          guideRegistryProvider.overrideWithValue(GuideRegistry(prefs: prefs)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(guideControllerProvider.notifier).skipAll();

      expect(prefs.getBool(GuideRegistry.enabledKey), isFalse);
      expect(container.read(guideEnabledProvider), isFalse);
    });

    test('resetAll 重新开启引导并清空所有已看状态', () async {
      final firstFlow = GuideFlowIds.active.first;
      SharedPreferences.setMockInitialValues({
        GuideRegistry.enabledKey: false,
        'guide_v1_${firstFlow}_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          guideRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);

      await container.read(guideControllerProvider.notifier).resetAll();

      expect(prefs.getBool(GuideRegistry.enabledKey), isTrue);
      expect(container.read(guideEnabledProvider), isTrue);
      expect(await registry.isSeen(firstFlow), isFalse);
    });
  });

  group('GuideRegistry', () {
    test('每个 flow 独立保存 seen 状态', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);

      expect(await registry.isSeen('library'), isFalse);
      expect(await registry.isSeen('learning_plan_no_transcript'), isFalse);

      await registry.markSeen('library');

      expect(await registry.isSeen('library'), isTrue);
      expect(await registry.isSeen('learning_plan_no_transcript'), isFalse);
    });

    test('reset 只清除指定 flow', () async {
      SharedPreferences.setMockInitialValues({
        'guide_v1_library_seen': true,
        'guide_v1_collection_detail_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);

      await registry.reset('library');

      expect(await registry.isSeen('library'), isFalse);
      expect(await registry.isSeen('collection_detail'), isTrue);
    });
  });

  group('GuideController', () {
    test('startFlow 成功后 activeFlowId 置为目标 flow', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final controller = container.read(guideControllerProvider.notifier);
      final started = await controller.startFlow('learning_plan_no_transcript');

      expect(started, isTrue);
      expect(
        container.read(guideControllerProvider).activeFlowId,
        'learning_plan_no_transcript',
      );
    });

    test('completeActiveFlow 标记已看并清空 active', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final controller = container.read(guideControllerProvider.notifier);
      await controller.startFlow('stuck_flow');
      expect(container.read(guideControllerProvider).isActive, isTrue);

      await controller.completeActiveFlow();

      expect(container.read(guideControllerProvider).isActive, isFalse);
      expect(await registry.isSeen('stuck_flow'), isTrue);
    });

    test('已 seen 的 flow 不再启动', () async {
      SharedPreferences.setMockInitialValues({'guide_v1_library_seen': true});
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final started = await container
          .read(guideControllerProvider.notifier)
          .startFlow('library');

      expect(started, isFalse);
      expect(container.read(guideControllerProvider).isActive, isFalse);
    });

    test('resetFlows 清 seen 并递增 resetGeneration', () async {
      SharedPreferences.setMockInitialValues({
        'guide_v1_flow_a_seen': true,
        'guide_v1_flow_b_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final registry = GuideRegistry(prefs: prefs);
      final container = ProviderContainer(
        overrides: [guideRegistryProvider.overrideWithValue(registry)],
      );
      addTearDown(container.dispose);

      final controller = container.read(guideControllerProvider.notifier);
      final beforeGen = container.read(guideControllerProvider).resetGeneration;

      await controller.resetFlows(['flow_a', 'flow_b']);

      expect(await registry.isSeen('flow_a'), isFalse);
      expect(await registry.isSeen('flow_b'), isFalse);
      expect(
        container.read(guideControllerProvider).resetGeneration,
        beforeGen + 1,
      );
    });
  });

  group('GuideEnabledNotifier', () {
    ProviderContainer buildContainer(SharedPreferences prefs) {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('默认开启（SP 无值时为 true）', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);

      expect(container.read(guideEnabledProvider), isTrue);
    });

    test('SP 存 false 时读为关闭', () async {
      SharedPreferences.setMockInitialValues({GuideRegistry.enabledKey: false});
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);

      expect(container.read(guideEnabledProvider), isFalse);
    });

    test('setEnabled 翻转 state 并写入 SP', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);

      await container.read(guideEnabledProvider.notifier).setEnabled(false);

      expect(container.read(guideEnabledProvider), isFalse);
      expect(prefs.getBool(GuideRegistry.enabledKey), isFalse);
    });
  });

  group('GuideShowcaseBus', () {
    test('setOnEnd + fireEnd 触发一次后自动清空', () {
      var count = 0;
      GuideShowcaseBus.setOnEnd(() => count++);
      GuideShowcaseBus.fireEnd();
      expect(count, 1);

      // 第二次 fireEnd 不应再调——callback 已清
      GuideShowcaseBus.fireEnd();
      expect(count, 1);
    });
  });
}

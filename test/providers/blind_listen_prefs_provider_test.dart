/// BlindListenPrefs Provider 单元测试（按槽位）
///
/// 覆盖:启动期 fromPrefsSync 注入、细粒度 setter(带槽位) 更新 state + 写 SP、
/// 槽位独立(不同轮次互不影响)、未设字段保持 null(不冻结智能默认)、跨实例持久化。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show PauseMode, ShadowingControlMode;
import 'package:echo_loop/models/stage_settings_overrides.dart'
    show StageSettingsSlots, stageSlotKey;
import 'package:echo_loop/providers/blind_listen_prefs_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart'
    show sharedPreferencesProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/mock_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer(SharedPreferences prefs) {
    return ProviderContainer(
      overrides: dedupeOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialBlindListenPrefsProvider.overrideWithValue(
          blindListenPrefsFromPrefsSync(prefs),
        ),
      ]),
    );
  }

  final firstLearnSlot = stageSlotKey(
    StageSettingsSlots.blindListen,
    LearningStage.firstLearn,
  );
  final review2Slot = stageSlotKey(
    StageSettingsSlots.blindListen,
    LearningStage.review2,
  );

  group('fromPrefsSync 注入', () {
    test('SP 缺失时为空表', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      expect(notifier.prefsFor(firstLearnSlot).pauseMode, isNull);
    });

    test('SP 已写入时按槽位同步注入', () async {
      SharedPreferences.setMockInitialValues({
        'blind_listen_prefs_v1':
            '{"blindListen:firstLearn":{"pauseMode":"fixed","fixedPauseSeconds":15}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      expect(notifier.prefsFor(firstLearnSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(firstLearnSlot).fixedPauseSeconds, 15);
    });
  });

  group('细粒度 setter（按槽位）', () {
    test('更新 state + 写 SP,可被新实例读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      await notifier.setPauseMode(firstLearnSlot, PauseMode.fixed);
      await notifier.setFixedPauseSeconds(firstLearnSlot, 15);

      expect(notifier.prefsFor(firstLearnSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(firstLearnSlot).fixedPauseSeconds, 15);
      // 落盘可被新实例读回
      final reloaded = blindListenPrefsFromPrefsSync(prefs);
      expect(reloaded.maybe(firstLearnSlot)?.fixedPauseSeconds, 15);
    });

    test('槽位独立:firstLearn 写入不影响 review2', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      await notifier.setFixedPauseSeconds(firstLearnSlot, 15);
      await notifier.setPauseMode(firstLearnSlot, PauseMode.fixed);

      expect(notifier.prefsFor(firstLearnSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(review2Slot).pauseMode, isNull); // review2 未受影响
    });

    test('只改停顿时速度仍为 null(不冻结智能默认)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      await notifier.setPauseMode(firstLearnSlot, PauseMode.fixed);
      await notifier.setFixedPauseSeconds(firstLearnSlot, 15);

      expect(notifier.prefsFor(firstLearnSlot).playbackSpeed, isNull);
      expect(
        notifier.resolve(firstLearnSlot, smartSpeed: 0.8).playbackSpeed,
        0.8,
      );
      expect(
        notifier.resolve(firstLearnSlot, smartSpeed: 1.0).playbackSpeed,
        1.0,
      );
    });

    test('值未变化时不重复写 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      await notifier.setControlMode(
        firstLearnSlot,
        ShadowingControlMode.manual,
      );
      final before = container.read(blindListenPrefsProvider);
      await notifier.setControlMode(
        firstLearnSlot,
        ShadowingControlMode.manual,
      );
      expect(
        identical(container.read(blindListenPrefsProvider), before),
        isTrue,
      );
    });

    test('段落时长(targetSeconds) 持久化 + resolveTargetSeconds 回退', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(blindListenPrefsProvider.notifier);
      // 未设 → 回退智能默认(-1 不分段)
      expect(
        notifier.resolveTargetSeconds(firstLearnSlot, smartSeconds: -1),
        -1,
      );
      await notifier.setTargetSeconds(firstLearnSlot, 30);
      expect(
        notifier.resolveTargetSeconds(firstLearnSlot, smartSeconds: -1),
        30,
      );
      // 落盘可被新实例读回
      final reloaded = blindListenPrefsFromPrefsSync(prefs);
      expect(reloaded.maybe(firstLearnSlot)?.targetSeconds, 30);
    });
  });
}

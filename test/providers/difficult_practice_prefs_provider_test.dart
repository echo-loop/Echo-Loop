/// DifficultPracticePrefs Provider 单元测试（按槽位）
///
/// 覆盖:启动期 fromPrefsSync 注入、细粒度 setter(带槽位) 更新 state + 写 SP、
/// 槽位独立(难句补练/收藏句复习互不影响,收藏句固定槽位与复习轮次独立)、
/// 未设字段保持 null(不冻结智能默认)、跨实例持久化。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/stage_settings_overrides.dart'
    show StageSettingsSlots, stageSlotKey;
import 'package:echo_loop/providers/difficult_practice_prefs_provider.dart';
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
        initialDifficultPracticePrefsProvider.overrideWithValue(
          difficultPracticePrefsFromPrefsSync(prefs),
        ),
      ]),
    );
  }

  // 难句补练绑复习轮次(review2)。
  final difficultSlot = stageSlotKey(
    StageSettingsSlots.reviewDifficultPractice,
    LearningStage.review2,
  );
  // 收藏句复习固定槽位 bookmarkReview:none(不绑复习轮次)。
  final bookmarkSlot = stageSlotKey(StageSettingsSlots.bookmarkReview, null);

  group('fromPrefsSync 注入', () {
    test('SP 缺失时为空表', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      expect(notifier.prefsFor(difficultSlot).pauseMode, isNull);
    });

    test('SP 已写入时按槽位同步注入', () async {
      SharedPreferences.setMockInitialValues({
        'difficult_practice_prefs_v1':
            '{"reviewDifficultPractice:review2":{"pauseMode":"fixed","fixedPauseSeconds":5}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      expect(notifier.prefsFor(difficultSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(difficultSlot).fixedPauseSeconds, 5);
    });
  });

  group('细粒度 setter（按槽位）', () {
    test('更新 state + 写 SP,可被新实例读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      await notifier.setPauseMode(difficultSlot, PauseMode.fixed);
      await notifier.setShadowReadingRepeatCount(difficultSlot, 5);

      expect(notifier.prefsFor(difficultSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(difficultSlot).shadowReadingRepeatCount, 5);
      // 落盘可被新实例读回
      final reloaded = difficultPracticePrefsFromPrefsSync(prefs);
      expect(reloaded.maybe(difficultSlot)?.shadowReadingRepeatCount, 5);
    });

    test('槽位独立:难句补练写入不影响收藏句复习', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      await notifier.setPauseMode(difficultSlot, PauseMode.fixed);

      expect(notifier.prefsFor(difficultSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(bookmarkSlot).pauseMode, isNull); // 收藏句未受影响
    });

    test('收藏句固定槽位 bookmarkReview:none 独立工作且与复习轮次无关', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      await notifier.setBlindListenRepeatCount(bookmarkSlot, 2);
      await notifier.setControlMode(bookmarkSlot, ShadowingControlMode.manual);

      expect(notifier.prefsFor(bookmarkSlot).blindListenRepeatCount, 2);
      expect(
        notifier.prefsFor(bookmarkSlot).controlMode,
        ShadowingControlMode.manual,
      );
      // 不影响绑轮次的难句补练槽位
      expect(notifier.prefsFor(difficultSlot).blindListenRepeatCount, isNull);
      // 落盘可被新实例读回(收藏句固定槽位持久化)
      final reloaded = difficultPracticePrefsFromPrefsSync(prefs);
      expect(reloaded.maybe(bookmarkSlot)?.blindListenRepeatCount, 2);
    });

    test('只改停顿时速度仍为 null(不冻结智能默认)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      await notifier.setPauseMode(difficultSlot, PauseMode.fixed);
      await notifier.setFixedPauseSeconds(difficultSlot, 5);

      expect(notifier.prefsFor(difficultSlot).playbackSpeed, isNull);
      expect(
        notifier.resolve(difficultSlot, smartSpeed: 0.8).playbackSpeed,
        0.8,
      );
      expect(
        notifier.resolve(difficultSlot, smartSpeed: 1.0).playbackSpeed,
        1.0,
      );
    });

    test('值未变化时不重复写 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(difficultPracticePrefsProvider.notifier);
      await notifier.setControlMode(difficultSlot, ShadowingControlMode.manual);
      final before = container.read(difficultPracticePrefsProvider);
      await notifier.setControlMode(difficultSlot, ShadowingControlMode.manual);
      expect(
        identical(container.read(difficultPracticePrefsProvider), before),
        isTrue,
      );
    });
  });
}

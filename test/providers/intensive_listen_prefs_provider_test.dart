/// IntensiveListenPrefs Provider 单元测试（按槽位）
///
/// 覆盖:启动期 fromPrefsSync 注入、细粒度 setter(带槽位) 更新 state + 写 SP、
/// 槽位独立(精听/跟读互不影响)、未设字段保持 null(不冻结智能默认)、跨实例持久化。
library;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/stage_settings_overrides.dart'
    show StageSettingsSlots, stageSlotKey;
import 'package:echo_loop/providers/intensive_listen_prefs_provider.dart';
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
        initialIntensiveListenPrefsProvider.overrideWithValue(
          intensiveListenPrefsFromPrefsSync(prefs),
        ),
      ]),
    );
  }

  final intensiveSlot = stageSlotKey(
    StageSettingsSlots.intensiveListen,
    LearningStage.firstLearn,
  );
  final repeatSlot = stageSlotKey(
    StageSettingsSlots.listenAndRepeat,
    LearningStage.firstLearn,
  );

  group('fromPrefsSync 注入', () {
    test('SP 缺失时为空表', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      expect(notifier.prefsFor(intensiveSlot).pauseMode, isNull);
    });

    test('SP 已写入时按槽位同步注入', () async {
      SharedPreferences.setMockInitialValues({
        'intensive_listen_prefs_v2':
            '{"intensiveListen:firstLearn":{"pauseMode":"fixed","fixedPauseSeconds":5}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      expect(notifier.prefsFor(intensiveSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(intensiveSlot).fixedPauseSeconds, 5);
    });
  });

  group('细粒度 setter（按槽位）', () {
    test('跟读范围默认仅难句并只写入跟读槽位', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      expect(
        notifier.listenAndRepeatScopeFor(repeatSlot),
        ListenAndRepeatScope.difficultOnly,
      );
      await notifier.setListenAndRepeatScope(
        repeatSlot,
        ListenAndRepeatScope.fullText,
      );

      expect(
        notifier.listenAndRepeatScopeFor(repeatSlot),
        ListenAndRepeatScope.fullText,
      );
      expect(notifier.prefsFor(intensiveSlot).listenAndRepeatScope, isNull);
      expect(
        intensiveListenPrefsFromPrefsSync(
          prefs,
        ).maybe(repeatSlot)?.listenAndRepeatScope,
        ListenAndRepeatScope.fullText,
      );
    });
    test('更新 state + 写 SP,可被新实例读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      await notifier.setPauseMode(intensiveSlot, PauseMode.fixed);
      await notifier.setFixedPauseSeconds(intensiveSlot, 5);

      expect(notifier.prefsFor(intensiveSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(intensiveSlot).fixedPauseSeconds, 5);
      // 落盘可被新实例读回
      final reloaded = intensiveListenPrefsFromPrefsSync(prefs);
      expect(reloaded.maybe(intensiveSlot)?.fixedPauseSeconds, 5);
    });

    test('讲解页循环开关写入精听槽位并可读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      await notifier.setAnnotationReplayUsesRepeatCount(intensiveSlot, true);

      expect(
        notifier.prefsFor(intensiveSlot).annotationReplayUsesRepeatCount,
        true,
      );
      expect(
        intensiveListenPrefsFromPrefsSync(
          prefs,
        ).maybe(intensiveSlot)?.annotationReplayUsesRepeatCount,
        true,
      );
      expect(
        notifier.prefsFor(repeatSlot).annotationReplayUsesRepeatCount,
        isNull,
      );
    });

    test('槽位独立:精听写入不影响跟读', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      await notifier.setFixedPauseSeconds(intensiveSlot, 5);
      await notifier.setPauseMode(intensiveSlot, PauseMode.fixed);

      expect(notifier.prefsFor(intensiveSlot).pauseMode, PauseMode.fixed);
      expect(notifier.prefsFor(repeatSlot).pauseMode, isNull); // 跟读未受影响
    });

    test('只改停顿时速度仍为 null(不冻结智能默认)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      await notifier.setPauseMode(intensiveSlot, PauseMode.fixed);
      await notifier.setFixedPauseSeconds(intensiveSlot, 5);

      expect(notifier.prefsFor(intensiveSlot).playbackSpeed, isNull);
      expect(
        notifier.resolve(intensiveSlot, smartSpeed: 0.8).playbackSpeed,
        0.8,
      );
      expect(
        notifier.resolve(intensiveSlot, smartSpeed: 1.0).playbackSpeed,
        1.0,
      );
    });

    test('值未变化时不重复写 state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPrefsProvider.notifier);
      await notifier.setControlMode(intensiveSlot, ShadowingControlMode.manual);
      final before = container.read(intensiveListenPrefsProvider);
      await notifier.setControlMode(intensiveSlot, ShadowingControlMode.manual);
      expect(
        identical(container.read(intensiveListenPrefsProvider), before),
        isTrue,
      );
    });
  });
}

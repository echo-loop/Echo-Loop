import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluency/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettingsState', () {
    group('默认值', () {
      test('初始状态正确', () {
        const state = AppSettingsState();

        expect(state.themeMode, ThemeMode.system);
        expect(state.locale, const Locale('en'));
      });
    });

    group('copyWith', () {
      test('setThemeMode 更新状态', () {
        const state = AppSettingsState();
        final copied = state.copyWith(themeMode: ThemeMode.dark);

        expect(copied.themeMode, ThemeMode.dark);
        expect(copied.locale, const Locale('en')); // 未修改
      });

      test('setLocale 更新状态', () {
        const state = AppSettingsState();
        final copied = state.copyWith(locale: const Locale('zh'));

        expect(copied.locale, const Locale('zh'));
        expect(copied.themeMode, ThemeMode.system); // 未修改
      });

      test('同时更新多个字段', () {
        const state = AppSettingsState();
        final copied = state.copyWith(
          themeMode: ThemeMode.light,
          locale: const Locale('ja'),
          timeMachineDateTime: DateTime(2026, 3, 11, 21, 30),
        );

        expect(copied.themeMode, ThemeMode.light);
        expect(copied.locale, const Locale('ja'));
        expect(copied.timeMachineDateTime, DateTime(2026, 3, 11, 21, 30));
      });

      test('不传参数时保持原值', () {
        const state = AppSettingsState(
          themeMode: ThemeMode.dark,
          locale: Locale('zh'),
        );
        final copied = state.copyWith();

        expect(copied.themeMode, ThemeMode.dark);
        expect(copied.locale, const Locale('zh'));
      });

      test('可清除时光机时间', () {
        final state = AppSettingsState(
          timeMachineDateTime: DateTime(2026, 3, 11, 21, 30),
        );
        final copied = state.copyWith(clearTimeMachineDateTime: true);

        expect(copied.timeMachineDateTime, isNull);
      });
    });
  });

  group('AppSettings provider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('加载已保存的时光机时间', () async {
      final expected = DateTime(2026, 3, 11, 21, 30);
      SharedPreferences.setMockInitialValues({
        'developer_time_machine_at_ms': expected.millisecondsSinceEpoch,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appSettingsProvider).timeMachineDateTime, expected);
    });

    test('isDemoMode 默认为 false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appSettingsProvider);
      expect(state.isDemoMode, isFalse);
      expect(state.isDemoModeLoading, isFalse);
    });

    test('setDemoMode(true) 更新状态并持久化到 SP', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setDemoMode(true);

      expect(container.read(appSettingsProvider).isDemoMode, isTrue);
      expect(container.read(appSettingsProvider).isDemoModeLoading, isFalse);

      // 验证持久化
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('demo_mode'), isTrue);
    });

    test('setDemoMode(false) 更新状态并持久化到 SP', () async {
      SharedPreferences.setMockInitialValues({'demo_mode': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setDemoMode(false);

      expect(container.read(appSettingsProvider).isDemoMode, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('demo_mode'), isFalse);
    });

    test('isDemoModeLoading 在手动设置时为 true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      notifier.setDemoModeLoading(true);

      expect(container.read(appSettingsProvider).isDemoModeLoading, isTrue);

      notifier.setDemoModeLoading(false);
      expect(container.read(appSettingsProvider).isDemoModeLoading, isFalse);
    });

    test('加载已保存的 isDemoMode', () async {
      SharedPreferences.setMockInitialValues({'demo_mode': true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appSettingsProvider).isDemoMode, isTrue);
    });

    test('兼容旧版 unlock_all_reviews 配置', () async {
      SharedPreferences.setMockInitialValues({'unlock_all_reviews': true});
      final before = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final migrated = container.read(appSettingsProvider).timeMachineDateTime;
      expect(migrated, isNotNull);
      expect(migrated!.isAfter(before.add(const Duration(days: 364))), isTrue);
      expect(prefs.getInt('developer_time_machine_at_ms'), isNotNull);
      expect(prefs.getBool('unlock_all_reviews'), isNull);
    });
  });
}

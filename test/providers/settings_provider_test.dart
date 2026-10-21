import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppSettingsState', () {
    group('默认值', () {
      test('初始状态正确', () {
        const state = AppSettingsState();

        expect(state.themeMode, ThemeMode.system);
        expect(state.locale, isNull);
        expect(state.wordHighlightEnabled, isTrue);
      });
    });

    test('时光机最小时间为当前分钟的下一分钟', () {
      final now = DateTime(2026, 6, 9, 12, 28, 30);

      expect(minimumTimeMachineDateTime(now), DateTime(2026, 6, 9, 12, 29));
    });

    test('过去的时光机时间会被规整到最小未来时间', () {
      final now = DateTime(2026, 6, 9, 12, 28, 30);
      final past = DateTime(2026, 5, 29, 12);

      expect(
        normalizedFutureTimeMachineDateTime(past, now),
        DateTime(2026, 6, 9, 12, 29),
      );
    });

    group('copyWith', () {
      test('setThemeMode 更新状态', () {
        const state = AppSettingsState();
        final copied = state.copyWith(themeMode: ThemeMode.dark);

        expect(copied.themeMode, ThemeMode.dark);
        expect(copied.locale, isNull); // 未修改
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

      test('clearLocale 可将 locale 重置为 null（跟随系统）', () {
        const state = AppSettingsState(locale: Locale('zh'));
        final copied = state.copyWith(clearLocale: true);

        expect(copied.locale, isNull);
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

    test('加载设置时清理旧字幕校准偏好并保留正常设置', () async {
      SharedPreferences.setMockInitialValues({
        'developer_subtitle_auto_align_enabled': false,
        'theme_mode': 'dark',
        'word_highlight_enabled': false,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settingsReady = Completer<void>();
      container.listen(appSettingsProvider, (_, next) {
        if (next.themeMode == ThemeMode.dark && !settingsReady.isCompleted) {
          settingsReady.complete();
        }
      });
      await settingsReady.future;

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('developer_subtitle_auto_align_enabled'),
        isFalse,
      );
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(container.read(appSettingsProvider).wordHighlightEnabled, isFalse);
    });

    test('加载已保存的未来时光机时间', () async {
      final expected = DateTime(2027, 3, 11, 21, 30);
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

    test('加载已保存的过去时光机时间时自动清除', () async {
      final past = DateTime(2020, 1, 1);
      SharedPreferences.setMockInitialValues({
        'developer_time_machine_at_ms': past.millisecondsSinceEpoch,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appSettingsProvider).timeMachineDateTime, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('developer_time_machine_at_ms'), isNull);
    });

    test('保存过去时光机时间时自动提升到未来', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final before = minimumTimeMachineDateTime(DateTime.now());

      await container
          .read(appSettingsProvider.notifier)
          .setTimeMachineDateTime(DateTime(2020, 1, 1));

      final saved = container.read(appSettingsProvider).timeMachineDateTime;
      expect(saved, isNotNull);
      expect(saved!.isBefore(before), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('developer_time_machine_at_ms'), isNotNull);
    });

    test('isDemoMode 默认为 false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appSettingsProvider);
      expect(state.isDemoMode, isFalse);
      expect(state.isDemoModeLoading, isFalse);
    });

    test('逐词高亮默认为开启并可持久化关闭选择', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      expect(container.read(appSettingsProvider).wordHighlightEnabled, isTrue);

      await notifier.setWordHighlightEnabled(false);

      expect(container.read(appSettingsProvider).wordHighlightEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('word_highlight_enabled'), isFalse);
    });

    test('没有已保存值时，读取其他偏好后逐词高亮仍默认开启', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen(appSettingsProvider, (_, next) {
        if (next.themeMode == ThemeMode.dark && !loaded.isCompleted) {
          loaded.complete();
        }
      });
      addTearDown(subscription.close);

      await loaded.future.timeout(const Duration(seconds: 5));

      expect(container.read(appSettingsProvider).wordHighlightEnabled, isTrue);
    });

    test('保留用户已保存的逐词高亮关闭状态', () async {
      SharedPreferences.setMockInitialValues({'word_highlight_enabled': false});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      final subscription = container.listen(appSettingsProvider, (_, next) {
        if (!next.wordHighlightEnabled && !loaded.isCompleted) {
          loaded.complete();
        }
      });
      addTearDown(subscription.close);

      await loaded.future.timeout(const Duration(seconds: 5));

      expect(container.read(appSettingsProvider).wordHighlightEnabled, isFalse);
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

    test('无 locale 配置时默认为 null（跟随系统），不自动写 SP', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appSettingsProvider).locale, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), isNull);
    });

    test('initialUiLocaleProvider override 直接作为首帧 locale，无闪烁', () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh-CN'});

      final container = ProviderContainer(
        overrides: [
          initialUiLocaleProvider.overrideWithValue(const Locale('zh', 'CN')),
        ],
      );
      addTearDown(container.dispose);

      // 同步读取，无需 await：build() 已用 override 值作为初始 locale
      expect(
        container.read(appSettingsProvider).locale,
        equals(const Locale('zh', 'CN')),
      );

      // hydrate 完成后值不变（SP 与 override 同源）
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(appSettingsProvider).locale,
        equals(const Locale('zh', 'CN')),
      );
    });

    test('readInitialUiLocaleSync 解析 SP 值', () async {
      SharedPreferences.setMockInitialValues({'locale': 'en'});
      var prefs = await SharedPreferences.getInstance();
      expect(readInitialUiLocaleSync(prefs), equals(const Locale('en')));

      SharedPreferences.setMockInitialValues({'locale': 'zh-CN'});
      prefs = await SharedPreferences.getInstance();
      expect(readInitialUiLocaleSync(prefs), equals(const Locale('zh', 'CN')));

      SharedPreferences.setMockInitialValues({'locale': 'system'});
      prefs = await SharedPreferences.getInstance();
      expect(readInitialUiLocaleSync(prefs), isNull);

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      expect(readInitialUiLocaleSync(prefs), isNull);
    });

    test(
      'initialAiTranscriptionAutoMergeEnabledProvider override 直接作为首帧开关值',
      () async {
        SharedPreferences.setMockInitialValues({
          'ai_transcription_auto_merge_enabled': false,
        });

        final container = ProviderContainer(
          overrides: [
            initialAiTranscriptionAutoMergeEnabledProvider.overrideWithValue(
              false,
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(appSettingsProvider).aiTranscriptionAutoMergeEnabled,
          isFalse,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(appSettingsProvider).aiTranscriptionAutoMergeEnabled,
          isFalse,
        );
      },
    );

    test('readInitialAiTranscriptionAutoMergeEnabledSync 解析 SP 值', () async {
      SharedPreferences.setMockInitialValues({
        'ai_transcription_auto_merge_enabled': false,
      });
      var prefs = await SharedPreferences.getInstance();
      expect(readInitialAiTranscriptionAutoMergeEnabledSync(prefs), isFalse);

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      expect(readInitialAiTranscriptionAutoMergeEnabledSync(prefs), isTrue);
    });

    test('locale 配置为 system 时加载为 null（用户显式选择跟随系统）', () async {
      SharedPreferences.setMockInitialValues({'locale': 'system'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(appSettingsProvider).locale, isNull);
    });

    test('locale 配置为 zh 时回填为 zh-CN（兼容旧值）', () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(appSettingsProvider).locale,
        equals(const Locale('zh', 'CN')),
      );
    });

    test('setLocale(null) 持久化为 system', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setLocale(null);

      expect(container.read(appSettingsProvider).locale, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'system');
    });

    test('setLocale(Locale("zh")) 持久化为 zh', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setLocale(const Locale('zh'));

      expect(container.read(appSettingsProvider).locale, const Locale('zh'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale'), 'zh');
    });

    test('aiTranscriptionAutoMergeEnabled 默认开启', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appSettingsProvider).aiTranscriptionAutoMergeEnabled,
        isTrue,
      );
    });

    test('setAiTranscriptionAutoMergeEnabled(false) 更新状态并持久化', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setAiTranscriptionAutoMergeEnabled(false);

      expect(
        container.read(appSettingsProvider).aiTranscriptionAutoMergeEnabled,
        isFalse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ai_transcription_auto_merge_enabled'), isFalse);
    });

    test('加载已保存的 aiTranscriptionAutoMergeEnabled=false', () async {
      SharedPreferences.setMockInitialValues({
        'ai_transcription_auto_merge_enabled': false,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(appSettingsProvider).aiTranscriptionAutoMergeEnabled,
        isFalse,
      );
    });
  });

  group('matchUiLocale', () {
    test('zh 系列（不论国家）→ Locale("zh", "CN")', () {
      expect(
        matchUiLocale(const Locale('zh', 'CN')),
        equals(const Locale('zh', 'CN')),
      );
      expect(
        matchUiLocale(const Locale('zh', 'TW')),
        equals(const Locale('zh', 'CN')),
      );
      expect(
        matchUiLocale(const Locale('zh')),
        equals(const Locale('zh', 'CN')),
      );
    });

    test('英文 → Locale("en")', () {
      expect(matchUiLocale(const Locale('en')), equals(const Locale('en')));
      expect(
        matchUiLocale(const Locale('en', 'US')),
        equals(const Locale('en')),
      );
    });

    test('其它任何语言均回退到英文', () {
      expect(matchUiLocale(const Locale('ja')), equals(const Locale('en')));
      expect(matchUiLocale(const Locale('ko')), equals(const Locale('en')));
      expect(matchUiLocale(const Locale('fr')), equals(const Locale('en')));
      expect(
        matchUiLocale(const Locale('xx', 'YY')),
        equals(const Locale('en')),
      );
    });
  });
}

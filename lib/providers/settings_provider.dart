import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _timeMachineDateTimeKey = 'developer_time_machine_at_ms';
const _legacyUnlockAllReviewsKey = 'unlock_all_reviews';
const _demoModeKey = 'demo_mode';

class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;

  /// 开发者选项：时光机时间。
  ///
  /// 为 null 时表示使用系统真实时间。
  final DateTime? timeMachineDateTime;

  /// 开发者选项：演示模式。
  ///
  /// 开启后使用独立的演示数据库，展示精心设计的假数据。
  final bool isDemoMode;

  /// 演示模式切换中的加载状态。
  final bool isDemoModeLoading;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.timeMachineDateTime,
    this.isDemoMode = false,
    this.isDemoModeLoading = false,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    DateTime? timeMachineDateTime,
    bool clearTimeMachineDateTime = false,
    bool? isDemoMode,
    bool? isDemoModeLoading,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      timeMachineDateTime: clearTimeMachineDateTime
          ? null
          : timeMachineDateTime ?? this.timeMachineDateTime,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isDemoModeLoading: isDemoModeLoading ?? this.isDemoModeLoading,
    );
  }
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsState build() {
    _loadSettings();
    return const AppSettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_themeModeKey) ?? 'system';
    final themeMode = switch (themeModeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final localeString = prefs.getString(_localeKey) ?? 'en';
    final locale = Locale(localeString);

    final timeMachineDateTime = await _loadTimeMachineDateTime(prefs);
    final isDemoMode = prefs.getBool(_demoModeKey) ?? false;

    state = state.copyWith(
      themeMode: themeMode,
      locale: locale,
      timeMachineDateTime: timeMachineDateTime,
      isDemoMode: isDemoMode,
    );
  }

  /// 加载时光机时间，并兼容旧版“解锁所有复习”开关。
  Future<DateTime?> _loadTimeMachineDateTime(SharedPreferences prefs) async {
    final storedMillis = prefs.getInt(_timeMachineDateTimeKey);
    if (storedMillis != null) {
      return DateTime.fromMillisecondsSinceEpoch(storedMillis);
    }

    final legacyUnlockAllReviews =
        prefs.getBool(_legacyUnlockAllReviewsKey) ?? false;
    if (!legacyUnlockAllReviews) {
      return null;
    }

    final migratedDateTime = DateTime.now().add(const Duration(days: 365));
    await prefs.setInt(
      _timeMachineDateTimeKey,
      migratedDateTime.millisecondsSinceEpoch,
    );
    await prefs.remove(_legacyUnlockAllReviewsKey);
    return migratedDateTime;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, modeString);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  /// 设置开发者时光机时间。
  ///
  /// 传入 null 时恢复系统真实时间。
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    state = state.copyWith(
      timeMachineDateTime: value,
      clearTimeMachineDateTime: value == null,
    );

    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_timeMachineDateTimeKey);
    } else {
      await prefs.setInt(_timeMachineDateTimeKey, value.millisecondsSinceEpoch);
    }
    await prefs.remove(_legacyUnlockAllReviewsKey);
  }

  /// 设置演示模式加载状态（供 UI 显示 loading 指示器）。
  void setDemoModeLoading(bool loading) {
    state = state.copyWith(isDemoModeLoading: loading);
  }

  /// 持久化演示模式开关状态。
  ///
  /// 数据库切换由调用方（settings_screen）负责，
  /// 此方法只更新 UI 状态和 SharedPreferences。
  Future<void> setDemoMode(bool enabled) async {
    state = state.copyWith(isDemoMode: enabled, isDemoModeLoading: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, enabled);
  }
}

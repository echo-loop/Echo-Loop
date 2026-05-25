import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _nativeLanguageKey = 'native_language';
const _timeMachineDateTimeKey = 'developer_time_machine_at_ms';
const _legacyUnlockAllReviewsKey = 'unlock_all_reviews';
const _demoModeKey = 'demo_mode';
const _subtitleAutoAlignEnabledKey = 'developer_subtitle_auto_align_enabled';
const _skipSilenceEnabledKey = 'skip_silence_enabled';
const _silenceThresholdSecondsKey = 'silence_threshold_seconds';

/// 静音阈值合法范围（秒）
const silenceThresholdMinSeconds = 1;
const silenceThresholdMaxSeconds = 10;
const silenceThresholdDefaultSeconds = 2;

/// 支持的母语列表（BCP 47 代码 → 本地名称）
///
/// 后续扩展只需在此处添加条目。
const supportedNativeLanguages = <String, String>{
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
};

/// 根据系统 locale 匹配应用界面语言。
///
/// 当前界面只支持中文 / 英文：
/// - 中文系列（zh）→ `Locale('zh', 'CN')`
/// - 其它任何语言（含未识别）→ `Locale('en')`
Locale matchUiLocale(Locale systemLocale) {
  if (systemLocale.languageCode == 'zh') return const Locale('zh', 'CN');
  return const Locale('en');
}

/// 根据系统 locale 匹配母语。
///
/// 匹配规则：
/// 1. 精确匹配 languageCode + countryCode（如 zh-CN）
/// 2. languageCode 匹配第一个同语言条目（如系统 zh → zh-CN）
/// 3. 无匹配 → 列表第一个
String matchNativeLanguage(Locale systemLocale) {
  final codes = supportedNativeLanguages.keys.toList();

  // 精确匹配：languageCode + countryCode
  final systemTag = systemLocale.countryCode != null
      ? '${systemLocale.languageCode}-${systemLocale.countryCode}'
      : systemLocale.languageCode;
  if (supportedNativeLanguages.containsKey(systemTag)) return systemTag;

  // languageCode 模糊匹配
  for (final code in codes) {
    if (code.split('-').first == systemLocale.languageCode) return code;
  }

  // 回退到列表第一个
  return codes.first;
}

class AppSettingsState {
  final ThemeMode themeMode;

  /// 用户选择的界面语言（BCP 47）。
  ///
  /// 为 null 时表示跟随系统语言，不支持的系统语言回退到英语。
  final Locale? locale;

  /// 用户的母语（BCP 47 代码），用于 AI 翻译/解析的目标语言。
  ///
  /// 首次启动时根据系统语言自动匹配并持久化。
  final String nativeLanguage;

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

  /// 开发者选项：字幕自动校准开关。
  ///
  /// 默认开启。关闭后 AI 转录完成不再调用 `SubtitleAutoAlignService`，
  /// 直接使用后端返回的句边界。仅开发者选项可见，不暴露给普通用户。
  final bool subtitleAutoAlignEnabled;

  /// 自动跳过静音段开关（默认开启）。
  ///
  /// 开启后，盲听 / 复述等段落级播放会按字幕时间戳自动跳过较长的静音段，
  /// 避免考试音频中长时间留白破坏体验。
  final bool skipSilenceEnabled;

  /// 静音阈值（秒）。仅当 [skipSilenceEnabled] 为 true 时生效。
  ///
  /// 字幕间隔 ≥ 该阈值才会被识别为"静音段"并跳过。默认 2 秒。
  final int silenceThresholdSeconds;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.nativeLanguage = 'zh-CN',
    this.timeMachineDateTime,
    this.isDemoMode = false,
    this.isDemoModeLoading = false,
    this.subtitleAutoAlignEnabled = true,
    this.skipSilenceEnabled = true,
    this.silenceThresholdSeconds = silenceThresholdDefaultSeconds,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    String? nativeLanguage,
    DateTime? timeMachineDateTime,
    bool clearTimeMachineDateTime = false,
    bool? isDemoMode,
    bool? isDemoModeLoading,
    bool? subtitleAutoAlignEnabled,
    bool? skipSilenceEnabled,
    int? silenceThresholdSeconds,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : locale ?? this.locale,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      timeMachineDateTime: clearTimeMachineDateTime
          ? null
          : timeMachineDateTime ?? this.timeMachineDateTime,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      isDemoModeLoading: isDemoModeLoading ?? this.isDemoModeLoading,
      subtitleAutoAlignEnabled:
          subtitleAutoAlignEnabled ?? this.subtitleAutoAlignEnabled,
      skipSilenceEnabled: skipSilenceEnabled ?? this.skipSilenceEnabled,
      silenceThresholdSeconds:
          silenceThresholdSeconds ?? this.silenceThresholdSeconds,
    );
  }
}

/// 启动期同步预读的界面语言。在 `main()` 同步从 SP 读出后通过
/// `overrideWithValue` 注入；用作 `AppSettings.build()` 的初始值，避免
/// 首帧 locale 为 null 引起的"先按系统语言渲染、再切到用户设置"闪烁。
///
/// 解析规则：
/// - SP 'en' → Locale('en')
/// - SP 'zh' / 'zh-CN' → Locale('zh', 'CN')
/// - SP 'system' / 缺失 / 异常值 → null（跟随系统）
///
/// 未 override 时返回 null，单测里也安全。
final initialUiLocaleProvider = Provider<Locale?>((ref) => null);

/// 同步从 SP 读取并解析界面语言（main() 启动期使用）。
Locale? readInitialUiLocaleSync(SharedPreferences prefs) {
  final stored = prefs.getString(_localeKey);
  return switch (stored) {
    'en' => const Locale('en'),
    'zh' || 'zh-CN' => const Locale('zh', 'CN'),
    _ => null, // 'system' / null / 异常 → 跟随系统
  };
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsState build() {
    // 用 main() 同步预读的 initialUiLocale 作为首帧值，避免闪烁。
    final initialLocale = ref.read(initialUiLocaleProvider);
    _loadSettings();
    return AppSettingsState(locale: initialLocale);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_themeModeKey) ?? 'system';
    final themeMode = switch (themeModeString) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // 界面语言：未设置或设置为 'system' 时返回 null，让 MaterialApp 跟随系统
    // （`matchUiLocale` 的语义同样适用——zh 系列→中文，其它→英文）。
    // 不再首次启动时自动持久化具体语言，保证设置页默认显示"跟随系统"。
    final locale = readInitialUiLocaleSync(prefs);

    // 母语：首次启动时根据系统语言匹配并持久化
    final nativeLanguage = await _loadNativeLanguage(prefs);

    final timeMachineDateTime = await _loadTimeMachineDateTime(prefs);
    final isDemoMode = prefs.getBool(_demoModeKey) ?? false;
    final subtitleAutoAlignEnabled =
        prefs.getBool(_subtitleAutoAlignEnabledKey) ?? true;
    final skipSilenceEnabled = prefs.getBool(_skipSilenceEnabledKey) ?? true;
    final storedThreshold = prefs.getInt(_silenceThresholdSecondsKey);
    final silenceThresholdSeconds =
        (storedThreshold ?? silenceThresholdDefaultSeconds).clamp(
          silenceThresholdMinSeconds,
          silenceThresholdMaxSeconds,
        );

    state = state.copyWith(
      themeMode: themeMode,
      locale: locale,
      clearLocale: locale == null,
      nativeLanguage: nativeLanguage,
      timeMachineDateTime: timeMachineDateTime,
      isDemoMode: isDemoMode,
      subtitleAutoAlignEnabled: subtitleAutoAlignEnabled,
      skipSilenceEnabled: skipSilenceEnabled,
      silenceThresholdSeconds: silenceThresholdSeconds,
    );
  }

  /// 加载母语设置，首次启动时自动匹配系统语言并持久化。
  Future<String> _loadNativeLanguage(SharedPreferences prefs) async {
    final stored = prefs.getString(_nativeLanguageKey);
    if (stored != null) return stored;

    // 首次启动：根据系统 locale 匹配
    final systemLocale = PlatformDispatcher.instance.locale;
    final matched = matchNativeLanguage(systemLocale);
    await prefs.setString(_nativeLanguageKey, matched);
    return matched;
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

  /// 设置界面语言（BCP 47）。
  ///
  /// 传入 null 时跟随系统语言。
  Future<void> setLocale(Locale? locale) async {
    state = locale == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(locale: locale);

    final prefs = await SharedPreferences.getInstance();
    final tag = locale == null
        ? 'system'
        : locale.countryCode != null
        ? '${locale.languageCode}-${locale.countryCode}'
        : locale.languageCode;
    await prefs.setString(_localeKey, tag);
  }

  /// 设置母语（BCP 47 代码）。
  Future<void> setNativeLanguage(String lang) async {
    state = state.copyWith(nativeLanguage: lang);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nativeLanguageKey, lang);
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

  /// 设置字幕自动校准开关（开发者选项，默认开启）。
  Future<void> setSubtitleAutoAlignEnabled(bool enabled) async {
    state = state.copyWith(subtitleAutoAlignEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subtitleAutoAlignEnabledKey, enabled);
  }

  /// 设置静音跳过开关（默认开启）。
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    state = state.copyWith(skipSilenceEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skipSilenceEnabledKey, enabled);
  }

  /// 设置静音阈值（秒）。范围 [silenceThresholdMinSeconds, silenceThresholdMaxSeconds]。
  Future<void> setSilenceThresholdSeconds(int seconds) async {
    final clamped = seconds.clamp(
      silenceThresholdMinSeconds,
      silenceThresholdMaxSeconds,
    );
    state = state.copyWith(silenceThresholdSeconds: clamped);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_silenceThresholdSecondsKey, clamped);
  }
}

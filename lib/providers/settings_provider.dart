import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/user_preferences/domain/user_preferences_sync_events.dart';

part 'settings_provider.g.dart';

const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _nativeLanguageKey = 'native_language';
const _timeMachineDateTimeKey = 'developer_time_machine_at_ms';
const _legacyUnlockAllReviewsKey = 'unlock_all_reviews';
const _demoModeKey = 'demo_mode';
const _legacySubtitleAutoAlignEnabledKey =
    'developer_subtitle_auto_align_enabled';
const _skipSilenceEnabledKey = 'skip_silence_enabled';
const _silenceThresholdSecondsKey = 'silence_threshold_seconds';
const _aiTranscriptionAutoMergeEnabledKey =
    'ai_transcription_auto_merge_enabled';
const _wordHighlightEnabledKey = 'word_highlight_enabled';

/// 静音阈值合法范围（秒）
const silenceThresholdMinSeconds = 1;
const silenceThresholdMaxSeconds = 10;
const silenceThresholdDefaultSeconds = 2;

/// 时光机只允许跳到未来；picker 只有分钟精度，因此最小值取下一分钟。
DateTime minimumTimeMachineDateTime(DateTime now) {
  return DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 1));
}

/// 规整用户选择的时光机时间，避免调试时间早于真实系统时间。
DateTime normalizedFutureTimeMachineDateTime(DateTime value, DateTime now) {
  final minimum = minimumTimeMachineDateTime(now);
  if (value.isBefore(minimum)) return minimum;
  return value;
}

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

  /// 自动跳过静音段开关（默认开启）。
  ///
  /// 开启后，盲听 / 复述等段落级播放会按字幕时间戳自动跳过较长的静音段，
  /// 避免考试音频中长时间留白破坏体验。
  final bool skipSilenceEnabled;

  /// 静音阈值（秒）。仅当 [skipSilenceEnabled] 为 true 时生效。
  ///
  /// 字幕间隔 ≥ 该阈值才会被识别为"静音段"并跳过。默认 2 秒。
  final int silenceThresholdSeconds;

  /// AI 转录「自动合并短句」开关（默认开启）。
  ///
  /// 开启时后端把过短句子合并到 4-7 秒目标带（字幕更长）；关闭时返回 provider
  /// 原生未合并分句（句子更短）。作为转录弹窗开关的默认值，记住用户上次选择。
  final bool aiTranscriptionAutoMergeEnabled;

  /// 播放原音时高亮当前字幕词语（默认开启）。
  final bool wordHighlightEnabled;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.nativeLanguage = 'zh-CN',
    this.timeMachineDateTime,
    this.isDemoMode = false,
    this.isDemoModeLoading = false,
    this.skipSilenceEnabled = true,
    this.silenceThresholdSeconds = silenceThresholdDefaultSeconds,
    this.aiTranscriptionAutoMergeEnabled = true,
    this.wordHighlightEnabled = true,
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
    bool? skipSilenceEnabled,
    int? silenceThresholdSeconds,
    bool? aiTranscriptionAutoMergeEnabled,
    bool? wordHighlightEnabled,
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
      skipSilenceEnabled: skipSilenceEnabled ?? this.skipSilenceEnabled,
      silenceThresholdSeconds:
          silenceThresholdSeconds ?? this.silenceThresholdSeconds,
      aiTranscriptionAutoMergeEnabled:
          aiTranscriptionAutoMergeEnabled ??
          this.aiTranscriptionAutoMergeEnabled,
      wordHighlightEnabled: wordHighlightEnabled ?? this.wordHighlightEnabled,
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

/// 启动期同步预读的 AI 转录「自动合并短句」开关。
///
/// 在 `main()` 同步从 SP 读出后通过 `overrideWithValue` 注入；用作
/// [AppSettings.build] 的首帧值，避免转录弹窗在设置 hydrate 前先读到默认 `true`，
/// 把错误值锁进本地 state。
///
/// 未 override 时返回默认 `true`，单测里也安全。
final initialAiTranscriptionAutoMergeEnabledProvider = Provider<bool>(
  (ref) => true,
);

/// 同步从 SP 读取并解析界面语言（main() 启动期使用）。
Locale? readInitialUiLocaleSync(SharedPreferences prefs) {
  final stored = prefs.getString(_localeKey);
  return switch (stored) {
    'en' => const Locale('en'),
    'zh' || 'zh-CN' => const Locale('zh', 'CN'),
    _ => null, // 'system' / null / 异常 → 跟随系统
  };
}

/// 同步从 SP 读取 AI 转录「自动合并短句」开关（main() 启动期使用）。
bool readInitialAiTranscriptionAutoMergeEnabledSync(SharedPreferences prefs) {
  return prefs.getBool(_aiTranscriptionAutoMergeEnabledKey) ?? true;
}

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  bool _wordHighlightChangedByUser = false;
  int _settingsLoadGeneration = 0;

  @override
  AppSettingsState build() {
    // 用 main() 同步预读的首帧值，避免 locale 闪烁，以及转录弹窗在 hydrate 前
    // 读到错误的 auto-merge 默认值。
    final initialLocale = ref.read(initialUiLocaleProvider);
    final initialAiTranscriptionAutoMergeEnabled = ref.read(
      initialAiTranscriptionAutoMergeEnabledProvider,
    );
    _loadSettings();
    return AppSettingsState(
      locale: initialLocale,
      aiTranscriptionAutoMergeEnabled: initialAiTranscriptionAutoMergeEnabled,
    );
  }

  Future<void> _loadSettings() async {
    final generation = ++_settingsLoadGeneration;
    final prefs = await SharedPreferences.getInstance();

    // 字幕校准已统一开启，移除旧调试偏好，避免升级后保留失效的关闭状态。
    if (prefs.containsKey(_legacySubtitleAutoAlignEnabledKey)) {
      await prefs.remove(_legacySubtitleAutoAlignEnabledKey);
    }

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
    final nativeLanguage = await _loadNativeLanguage(prefs, generation);

    final timeMachineDateTime = await _loadTimeMachineDateTime(prefs);
    final isDemoMode = prefs.getBool(_demoModeKey) ?? false;
    final skipSilenceEnabled = prefs.getBool(_skipSilenceEnabledKey) ?? true;
    final storedThreshold = prefs.getInt(_silenceThresholdSecondsKey);
    final silenceThresholdSeconds =
        (storedThreshold ?? silenceThresholdDefaultSeconds).clamp(
          silenceThresholdMinSeconds,
          silenceThresholdMaxSeconds,
        );
    final aiTranscriptionAutoMergeEnabled =
        prefs.getBool(_aiTranscriptionAutoMergeEnabledKey) ?? true;
    final wordHighlightEnabled =
        prefs.getBool(_wordHighlightEnabledKey) ?? true;

    if (generation != _settingsLoadGeneration) return;
    state = state.copyWith(
      themeMode: themeMode,
      locale: locale,
      clearLocale: locale == null,
      nativeLanguage: nativeLanguage,
      timeMachineDateTime: timeMachineDateTime,
      isDemoMode: isDemoMode,
      skipSilenceEnabled: skipSilenceEnabled,
      silenceThresholdSeconds: silenceThresholdSeconds,
      aiTranscriptionAutoMergeEnabled: aiTranscriptionAutoMergeEnabled,
      // 用户在异步设置加载期间操作开关时，保留其即时选择。
      wordHighlightEnabled: _wordHighlightChangedByUser
          ? null
          : wordHighlightEnabled,
    );
  }

  /// 云端写回 SharedPreferences 后重新加载设置。较早启动的异步加载会因
  /// generation 变化而被丢弃，避免覆盖云端快照。
  Future<void> reloadFromPrefs() => _loadSettings();

  /// 加载母语设置，首次启动时自动匹配系统语言并持久化。
  Future<String> _loadNativeLanguage(
    SharedPreferences prefs,
    int generation,
  ) async {
    final stored = prefs.getString(_nativeLanguageKey);
    if (stored != null) return stored;

    // 首次启动：根据系统 locale 匹配
    final systemLocale = PlatformDispatcher.instance.locale;
    final matched = matchNativeLanguage(systemLocale);
    if (generation == _settingsLoadGeneration) {
      await prefs.setString(_nativeLanguageKey, matched);
    }
    return matched;
  }

  /// 加载时光机时间，并兼容旧版“解锁所有复习”开关。
  Future<DateTime?> _loadTimeMachineDateTime(SharedPreferences prefs) async {
    final storedMillis = prefs.getInt(_timeMachineDateTimeKey);
    if (storedMillis != null) {
      final storedDateTime = DateTime.fromMillisecondsSinceEpoch(storedMillis);
      if (storedDateTime.isBefore(minimumTimeMachineDateTime(DateTime.now()))) {
        await prefs.remove(_timeMachineDateTimeKey);
        return null;
      }
      return storedDateTime;
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
    _settingsLoadGeneration++;
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, modeString);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置界面语言（BCP 47）。
  ///
  /// 传入 null 时跟随系统语言。
  Future<void> setLocale(Locale? locale) async {
    _settingsLoadGeneration++;
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
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置母语（BCP 47 代码）。
  Future<void> setNativeLanguage(String lang) async {
    _settingsLoadGeneration++;
    state = state.copyWith(nativeLanguage: lang);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nativeLanguageKey, lang);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置开发者时光机时间。
  ///
  /// 传入 null 时恢复系统真实时间。
  Future<void> setTimeMachineDateTime(DateTime? value) async {
    _settingsLoadGeneration++;
    final normalizedValue = value == null
        ? null
        : normalizedFutureTimeMachineDateTime(value, DateTime.now());
    state = state.copyWith(
      timeMachineDateTime: normalizedValue,
      clearTimeMachineDateTime: normalizedValue == null,
    );

    final prefs = await SharedPreferences.getInstance();
    if (normalizedValue == null) {
      await prefs.remove(_timeMachineDateTimeKey);
    } else {
      await prefs.setInt(
        _timeMachineDateTimeKey,
        normalizedValue.millisecondsSinceEpoch,
      );
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
    _settingsLoadGeneration++;
    state = state.copyWith(isDemoMode: enabled, isDemoModeLoading: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, enabled);
  }

  /// 设置静音跳过开关（默认开启）。
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    _settingsLoadGeneration++;
    state = state.copyWith(skipSilenceEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skipSilenceEnabledKey, enabled);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置播放原音时的字幕逐词高亮（默认开启）。
  Future<void> setWordHighlightEnabled(bool enabled) async {
    _settingsLoadGeneration++;
    _wordHighlightChangedByUser = true;
    state = state.copyWith(wordHighlightEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wordHighlightEnabledKey, enabled);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置静音阈值（秒）。范围 [silenceThresholdMinSeconds, silenceThresholdMaxSeconds]。
  Future<void> setSilenceThresholdSeconds(int seconds) async {
    _settingsLoadGeneration++;
    final clamped = seconds.clamp(
      silenceThresholdMinSeconds,
      silenceThresholdMaxSeconds,
    );
    state = state.copyWith(silenceThresholdSeconds: clamped);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_silenceThresholdSecondsKey, clamped);
    userPreferencesSyncEvents.notifyLocalChange();
  }

  /// 设置 AI 转录「自动合并短句」开关（记住用户上次选择，默认开启）。
  Future<void> setAiTranscriptionAutoMergeEnabled(bool enabled) async {
    _settingsLoadGeneration++;
    state = state.copyWith(aiTranscriptionAutoMergeEnabled: enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiTranscriptionAutoMergeEnabledKey, enabled);
    userPreferencesSyncEvents.notifyLocalChange();
  }
}

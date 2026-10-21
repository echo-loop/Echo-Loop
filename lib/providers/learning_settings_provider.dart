/// 学习设置 Provider
///
/// 全局控制学习流程偏好，包括自动跳过复述、缓存讲解展开，以及复述完成
/// 后是否自动播放本次录音、是否计算复述评级。
///
/// 采用手动 Notifier 模式（不走 riverpod_generator），对齐
/// [lib/features/onboarding_survey/providers/onboarding_survey_provider.dart]。
/// `build()` 从 [initialLearningSettingsProvider] 同步读 SP 注入的快照，
/// 避免 router redirect / 学习计划页 initState 在异步加载完成前拿不到状态。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;
import '../services/app_logger.dart';
import '../features/user_preferences/domain/user_preferences_sync_events.dart';

export '../features/onboarding_survey/providers/onboarding_survey_provider.dart'
    show sharedPreferencesProvider;

/// 同步从 SP 预读的学习设置初值，由 main() 通过 override 注入。
///
/// 未 override 时抛出，强制启动期显式注入。
final initialLearningSettingsProvider = Provider<LearningSettings>((ref) {
  throw UnimplementedError(
    'initialLearningSettingsProvider must be overridden in main()',
  );
});

/// 学习设置 SP key 常量。
abstract final class LearningSettingsKeys {
  static const autoSkipRetell = 'learning_auto_skip_retell';
  static const autoExpandCachedAnnotation =
      'learning_auto_expand_cached_annotation';
  static const autoShowAiExplanation = 'learning_auto_show_ai_explanation';
  static const autoShowAiAnalysis = 'learning_auto_show_ai_analysis';
  static const autoShowAiTranslation = 'learning_auto_show_ai_translation';
  static const autoShowAiSenseGroups = 'learning_auto_show_ai_sense_groups';
  static const autoPlayRetellRecordingAfterCompletion =
      'learning_auto_play_retell_recording_after_completion';
  static const listenAndRepeatRatingEnabled =
      'learning_listen_and_repeat_rating_enabled';
  static const retellRatingEnabled = 'learning_retell_rating_enabled';
  static const retellAutoPlaybackPromptShown =
      'learning_retell_auto_playback_prompt_shown';
  static const pdfExportReminderShown = 'learning_pdf_export_reminder_shown';

  /// 历史 SP key，启动期会被清理。
  static const legacyOfflineAsrEnabled = 'offline_asr_enabled';
  static const legacyRetellEnabled = 'learning_retell_enabled';
  static const legacySetupChoiceMadeAtMs = 'retell_setup_choice_at_ms';
}

/// 学习设置不可变值对象。
///
/// 学习设置不可变值对象。
class LearningSettings {
  /// 是否自动跳过复述（默认 false）。
  final bool autoSkipRetell;

  /// 是否自动展开缓存的解析/翻译/意群（默认 true）。
  final bool autoExpandCachedAnnotation;

  /// 是否自动显示 AI 讲解（默认 true）。
  final bool autoShowAiExplanation;

  /// 是否自动显示句子解析（默认 true）。
  final bool autoShowAiAnalysis;

  /// 是否自动显示句子翻译（默认 true）。
  final bool autoShowAiTranslation;

  /// 是否自动显示意群分割（默认 false）。
  final bool autoShowAiSenseGroups;

  /// 复述完成后是否自动播放用户录音（默认 false）。
  final bool autoPlayRetellRecordingAfterCompletion;

  /// 是否计算并显示跟读评级（默认 true）。
  final bool listenAndRepeatRatingEnabled;

  /// 是否计算并显示复述评级（默认 true）。
  final bool retellRatingEnabled;

  /// 是否已经展示过复述录音自动回放的首次提示（默认 false）。
  final bool retellAutoPlaybackPromptShown;

  /// 是否已经展示过首次导出 PDF 的补充复习材料提醒（默认 false）。
  final bool pdfExportReminderShown;

  const LearningSettings({
    this.autoSkipRetell = false,
    this.autoExpandCachedAnnotation = true,
    this.autoShowAiExplanation = true,
    this.autoShowAiAnalysis = true,
    this.autoShowAiTranslation = true,
    this.autoShowAiSenseGroups = false,
    this.autoPlayRetellRecordingAfterCompletion = false,
    this.listenAndRepeatRatingEnabled = true,
    this.retellRatingEnabled = true,
    this.retellAutoPlaybackPromptShown = false,
    this.pdfExportReminderShown = false,
  });

  /// 同步从 [SharedPreferences] 派生当前状态，用于启动期 override 注入。
  factory LearningSettings.fromPrefsSync(SharedPreferences prefs) {
    return LearningSettings(
      autoSkipRetell:
          prefs.getBool(LearningSettingsKeys.autoSkipRetell) ?? false,
      autoExpandCachedAnnotation:
          prefs.getBool(LearningSettingsKeys.autoExpandCachedAnnotation) ??
          true,
      autoShowAiExplanation:
          prefs.getBool(LearningSettingsKeys.autoShowAiExplanation) ?? true,
      autoShowAiAnalysis:
          prefs.getBool(LearningSettingsKeys.autoShowAiAnalysis) ?? true,
      autoShowAiTranslation:
          prefs.getBool(LearningSettingsKeys.autoShowAiTranslation) ?? true,
      autoShowAiSenseGroups:
          prefs.getBool(LearningSettingsKeys.autoShowAiSenseGroups) ?? false,
      autoPlayRetellRecordingAfterCompletion:
          prefs.getBool(
            LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
          ) ??
          false,
      listenAndRepeatRatingEnabled:
          prefs.getBool(LearningSettingsKeys.listenAndRepeatRatingEnabled) ??
          true,
      retellRatingEnabled:
          prefs.getBool(LearningSettingsKeys.retellRatingEnabled) ?? true,
      retellAutoPlaybackPromptShown:
          prefs.getBool(LearningSettingsKeys.retellAutoPlaybackPromptShown) ??
          false,
      pdfExportReminderShown:
          prefs.getBool(LearningSettingsKeys.pdfExportReminderShown) ?? false,
    );
  }

  LearningSettings copyWith({
    bool? autoSkipRetell,
    bool? autoExpandCachedAnnotation,
    bool? autoShowAiExplanation,
    bool? autoShowAiAnalysis,
    bool? autoShowAiTranslation,
    bool? autoShowAiSenseGroups,
    bool? autoPlayRetellRecordingAfterCompletion,
    bool? listenAndRepeatRatingEnabled,
    bool? retellRatingEnabled,
    bool? retellAutoPlaybackPromptShown,
    bool? pdfExportReminderShown,
  }) {
    return LearningSettings(
      autoSkipRetell: autoSkipRetell ?? this.autoSkipRetell,
      autoExpandCachedAnnotation:
          autoExpandCachedAnnotation ?? this.autoExpandCachedAnnotation,
      autoShowAiExplanation:
          autoShowAiExplanation ?? this.autoShowAiExplanation,
      autoShowAiAnalysis: autoShowAiAnalysis ?? this.autoShowAiAnalysis,
      autoShowAiTranslation:
          autoShowAiTranslation ?? this.autoShowAiTranslation,
      autoShowAiSenseGroups:
          autoShowAiSenseGroups ?? this.autoShowAiSenseGroups,
      autoPlayRetellRecordingAfterCompletion:
          autoPlayRetellRecordingAfterCompletion ??
          this.autoPlayRetellRecordingAfterCompletion,
      listenAndRepeatRatingEnabled:
          listenAndRepeatRatingEnabled ?? this.listenAndRepeatRatingEnabled,
      retellRatingEnabled: retellRatingEnabled ?? this.retellRatingEnabled,
      retellAutoPlaybackPromptShown:
          retellAutoPlaybackPromptShown ?? this.retellAutoPlaybackPromptShown,
      pdfExportReminderShown:
          pdfExportReminderShown ?? this.pdfExportReminderShown,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningSettings &&
          runtimeType == other.runtimeType &&
          autoSkipRetell == other.autoSkipRetell &&
          autoExpandCachedAnnotation == other.autoExpandCachedAnnotation &&
          autoShowAiExplanation == other.autoShowAiExplanation &&
          autoShowAiAnalysis == other.autoShowAiAnalysis &&
          autoShowAiTranslation == other.autoShowAiTranslation &&
          autoShowAiSenseGroups == other.autoShowAiSenseGroups &&
          autoPlayRetellRecordingAfterCompletion ==
              other.autoPlayRetellRecordingAfterCompletion &&
          listenAndRepeatRatingEnabled == other.listenAndRepeatRatingEnabled &&
          retellRatingEnabled == other.retellRatingEnabled &&
          retellAutoPlaybackPromptShown ==
              other.retellAutoPlaybackPromptShown &&
          pdfExportReminderShown == other.pdfExportReminderShown;

  @override
  int get hashCode => Object.hash(
    autoSkipRetell,
    autoExpandCachedAnnotation,
    autoShowAiExplanation,
    autoShowAiAnalysis,
    autoShowAiTranslation,
    autoShowAiSenseGroups,
    autoPlayRetellRecordingAfterCompletion,
    listenAndRepeatRatingEnabled,
    retellRatingEnabled,
    retellAutoPlaybackPromptShown,
    pdfExportReminderShown,
  );
}

/// 学习设置 Notifier。
///
/// 单向数据流：[setAutoSkipRetell] 仅写自己的 state + SP；progress 端通过
/// `ref.listen(learningSettingsProvider)` 监听变化触发 reconcile（包括
/// false→true 时对所有 progress 跑一次自动跳过扫描）。**不**在此 Notifier 内
/// 反向 read progress notifier 避免双向耦合。
class LearningSettingsNotifier extends Notifier<LearningSettings> {
  @override
  LearningSettings build() {
    try {
      return LearningSettings.fromPrefsSync(
        ref.read(sharedPreferencesProvider),
      );
    } on UnimplementedError {
      return ref.read(initialLearningSettingsProvider);
    }
  }

  /// 从当前 [SharedPreferences] 重新读取全部学习设置并刷新 state。
  ///
  /// 启动后 [build] 仅读一次冻结快照（[initialLearningSettingsProvider]），
  /// 此后只靠各 setter 维护内存状态。当外部直接改动了 SP（如开发者偏好设置页
  /// 删除/修改某个 key）时，需调用此方法回灌内存，否则运行中的状态会与持久化层
  /// 不一致。SP 为全局单例，外部改动已即时生效，这里直接重读即可。
  void reloadFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = LearningSettings.fromPrefsSync(prefs);
  }

  /// 切换 autoExpandCachedAnnotation，写 SP + 更新 state。
  Future<void> setAutoExpandCachedAnnotation(bool enabled) async {
    if (state.autoExpandCachedAnnotation == enabled) return;
    state = state.copyWith(autoExpandCachedAnnotation: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(
        LearningSettingsKeys.autoExpandCachedAnnotation,
        enabled,
      );
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log(
        'LearningSettings',
        'setAutoExpandCachedAnnotation 写 SP 失败: $e',
      );
    }
  }

  /// 切换自动显示 AI 讲解总开关，写 SP + 更新 state。
  Future<void> setAutoShowAiExplanation(bool enabled) async {
    if (state.autoShowAiExplanation == enabled) return;
    state = state.copyWith(autoShowAiExplanation: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoShowAiExplanation, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoShowAiExplanation 写 SP 失败: $e');
    }
  }

  /// 切换自动显示解析，写 SP + 更新 state。
  Future<void> setAutoShowAiAnalysis(bool enabled) async {
    if (state.autoShowAiAnalysis == enabled) return;
    state = state.copyWith(autoShowAiAnalysis: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoShowAiAnalysis, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoShowAiAnalysis 写 SP 失败: $e');
    }
  }

  /// 切换自动显示翻译，写 SP + 更新 state。
  Future<void> setAutoShowAiTranslation(bool enabled) async {
    if (state.autoShowAiTranslation == enabled) return;
    state = state.copyWith(autoShowAiTranslation: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoShowAiTranslation, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoShowAiTranslation 写 SP 失败: $e');
    }
  }

  /// 切换自动显示意群分割，写 SP + 更新 state。
  Future<void> setAutoShowAiSenseGroups(bool enabled) async {
    if (state.autoShowAiSenseGroups == enabled) return;
    state = state.copyWith(autoShowAiSenseGroups: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoShowAiSenseGroups, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoShowAiSenseGroups 写 SP 失败: $e');
    }
  }

  /// 切换复述完成后自动播放录音，写 SP + 更新 state。
  Future<void> setAutoPlayRetellRecordingAfterCompletion(bool enabled) async {
    if (state.autoPlayRetellRecordingAfterCompletion == enabled) return;
    state = state.copyWith(autoPlayRetellRecordingAfterCompletion: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(
        LearningSettingsKeys.autoPlayRetellRecordingAfterCompletion,
        enabled,
      );
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log(
        'LearningSettings',
        'setAutoPlayRetellRecordingAfterCompletion 写 SP 失败: $e',
      );
    }
  }

  /// 切换跟读评级计算与显示，写 SP + 更新 state。
  Future<void> setListenAndRepeatRatingEnabled(bool enabled) async {
    if (state.listenAndRepeatRatingEnabled == enabled) return;
    state = state.copyWith(listenAndRepeatRatingEnabled: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(
        LearningSettingsKeys.listenAndRepeatRatingEnabled,
        enabled,
      );
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log(
        'LearningSettings',
        'setListenAndRepeatRatingEnabled 写 SP 失败: $e',
      );
    }
  }

  /// 切换复述评级计算与显示，写 SP + 更新 state。
  Future<void> setRetellRatingEnabled(bool enabled) async {
    if (state.retellRatingEnabled == enabled) return;
    state = state.copyWith(retellRatingEnabled: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.retellRatingEnabled, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setRetellRatingEnabled 写 SP 失败: $e');
    }
  }

  /// 标记复述自动回放首次提示已展示。
  Future<void> markRetellAutoPlaybackPromptShown() async {
    if (state.retellAutoPlaybackPromptShown) return;
    state = state.copyWith(retellAutoPlaybackPromptShown: true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(
        LearningSettingsKeys.retellAutoPlaybackPromptShown,
        true,
      );
    } catch (e) {
      AppLogger.log(
        'LearningSettings',
        'markRetellAutoPlaybackPromptShown 写 SP 失败: $e',
      );
    }
  }

  /// 标记首次导出 PDF 的补充复习材料提醒已展示。
  Future<void> markPdfExportReminderShown() async {
    if (state.pdfExportReminderShown) return;
    state = state.copyWith(pdfExportReminderShown: true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.pdfExportReminderShown, true);
    } catch (e) {
      AppLogger.log(
        'LearningSettings',
        'markPdfExportReminderShown 写 SP 失败: $e',
      );
    }
  }

  /// 切换 autoSkipRetell，写 SP + 更新 state。
  ///
  /// 调用方负责埋点（不同 source 需要不同的 source 参数）。
  Future<void> setAutoSkipRetell(bool enabled) async {
    if (state.autoSkipRetell == enabled) return;
    state = state.copyWith(autoSkipRetell: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoSkipRetell, enabled);
      userPreferencesSyncEvents.notifyLocalChange();
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoSkipRetell 写 SP 失败: $e');
    }
  }
}

/// 学习设置 Provider 入口。
final learningSettingsProvider =
    NotifierProvider<LearningSettingsNotifier, LearningSettings>(
      LearningSettingsNotifier.new,
    );

/// 一次性迁移旧“语音识别总开关”到两个练习评分开关。
///
/// 旧开关只有 false 表示用户不想使用语音练习评分；true 或缺失时，新评分开关
/// 保持默认 true。已存在的新 key 代表用户已有明确选择，不覆盖。
Future<void> migrateLegacyOfflineAsrEnabledToRatingSettings(
  SharedPreferences prefs,
) async {
  final legacyEnabled = prefs.getBool(
    LearningSettingsKeys.legacyOfflineAsrEnabled,
  );
  if (legacyEnabled == false) {
    if (!prefs.containsKey(LearningSettingsKeys.listenAndRepeatRatingEnabled)) {
      await prefs.setBool(
        LearningSettingsKeys.listenAndRepeatRatingEnabled,
        false,
      );
    }
    if (!prefs.containsKey(LearningSettingsKeys.retellRatingEnabled)) {
      await prefs.setBool(LearningSettingsKeys.retellRatingEnabled, false);
    }
  }
  if (prefs.containsKey(LearningSettingsKeys.legacyOfflineAsrEnabled)) {
    await prefs.remove(LearningSettingsKeys.legacyOfflineAsrEnabled);
  }
}

/// 启动期 best-effort 清理历史 SP key（开发期数据卫生）。
///
/// 老 key `learning_retell_enabled` / `retell_setup_choice_at_ms` 已不再读，
/// 但仍可能残留在用户手机上。这里幂等地移除以避免长期垃圾。
Future<void> cleanupLegacyLearningSettingsKeys(SharedPreferences prefs) async {
  for (final key in [
    LearningSettingsKeys.legacyRetellEnabled,
    LearningSettingsKeys.legacySetupChoiceMadeAtMs,
  ]) {
    if (prefs.containsKey(key)) {
      try {
        await prefs.remove(key);
      } catch (e) {
        AppLogger.log('LearningSettings', 'cleanupLegacy 删 $key 失败: $e');
      }
    }
  }
}

/// 学习设置 Provider
///
/// 全局控制「自动跳过复述」策略。默认关闭——复述子阶段照常参与计划；
/// 开启后，所有推进到复述子阶段的位置都会自动调 `skipCurrentSubStage`，
/// 与用户在简报弹窗里手动点「跳过」同效（统一通过
/// [LearningProgress.skippedSubStageKeys] 字段承载）。
///
/// 持久化 SP key：`learning_auto_skip_retell` (bool)。
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
  static const autoExpandCachedAnnotation = 'learning_auto_expand_cached_annotation';

  /// 历史 SP key，启动期会被清理。
  static const legacyRetellEnabled = 'learning_retell_enabled';
  static const legacySetupChoiceMadeAtMs = 'retell_setup_choice_at_ms';
}

/// 学习设置不可变值对象。
///
/// 当前仅一个用户偏好（[autoSkipRetell]）。未来扩展只需新增字段并在
/// [fromPrefsSync] / [copyWith] 中补对应处理。
class LearningSettings {
  /// 是否自动跳过复述（默认 false）。
  final bool autoSkipRetell;

  /// 是否自动展开缓存的解析/翻译/意群（默认 true）。
  final bool autoExpandCachedAnnotation;

  const LearningSettings({
    this.autoSkipRetell = false,
    this.autoExpandCachedAnnotation = true,
  });

  /// 同步从 [SharedPreferences] 派生当前状态，用于启动期 override 注入。
  factory LearningSettings.fromPrefsSync(SharedPreferences prefs) {
    return LearningSettings(
      autoSkipRetell:
          prefs.getBool(LearningSettingsKeys.autoSkipRetell) ?? false,
      autoExpandCachedAnnotation:
          prefs.getBool(LearningSettingsKeys.autoExpandCachedAnnotation) ?? true,
    );
  }

  LearningSettings copyWith({
    bool? autoSkipRetell,
    bool? autoExpandCachedAnnotation,
  }) {
    return LearningSettings(
      autoSkipRetell: autoSkipRetell ?? this.autoSkipRetell,
      autoExpandCachedAnnotation: autoExpandCachedAnnotation ?? this.autoExpandCachedAnnotation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningSettings &&
          runtimeType == other.runtimeType &&
          autoSkipRetell == other.autoSkipRetell &&
          autoExpandCachedAnnotation == other.autoExpandCachedAnnotation;

  @override
  int get hashCode => Object.hash(autoSkipRetell, autoExpandCachedAnnotation);
}

/// 学习设置 Notifier。
///
/// 单向数据流：[setAutoSkipRetell] 仅写自己的 state + SP；progress 端通过
/// `ref.listen(learningSettingsProvider)` 监听变化触发 reconcile（包括
/// false→true 时对所有 progress 跑一次自动跳过扫描）。**不**在此 Notifier 内
/// 反向 read progress notifier 避免双向耦合。
class LearningSettingsNotifier extends Notifier<LearningSettings> {
  @override
  LearningSettings build() => ref.read(initialLearningSettingsProvider);

  /// 切换 autoExpandCachedAnnotation，写 SP + 更新 state。
  Future<void> setAutoExpandCachedAnnotation(bool enabled) async {
    if (state.autoExpandCachedAnnotation == enabled) return;
    state = state.copyWith(autoExpandCachedAnnotation: enabled);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(LearningSettingsKeys.autoExpandCachedAnnotation, enabled);
    } catch (e) {
      AppLogger.log('LearningSettings', 'setAutoExpandCachedAnnotation 写 SP 失败: $e');
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

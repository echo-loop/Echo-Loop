/// 学习设置页面
///
/// 控制全局学习行为偏好，本期只支持「自动跳过复述」开关。
/// 默认关闭：复述类子阶段照常参与计划，用户在简报弹窗里可手动跳过。
/// 开启后：所有推进到复述子阶段的位置都自动调用 `skipCurrentSubStage`，
/// 效果与用户手动点跳过一致。设置切换瞬间会触发对所有 progress 的扫描，
/// 把当前停在复述位置的音频立刻推进。自由练习入口不受影响。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics_providers.dart';
import '../analytics/models/event_names.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../theme/app_theme.dart';

/// 学习设置页面
class LearningSettingsScreen extends ConsumerWidget {
  const LearningSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(learningSettingsProvider);
    final guideEnabled = ref.watch(guideEnabledProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.learningSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: Text(l10n.autoShowAiExplanationToggle),
                  subtitle: Text(
                    l10n.autoShowAiExplanationSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  value: settings.autoShowAiExplanation,
                  onChanged: (value) async {
                    await ref
                        .read(learningSettingsProvider.notifier)
                        .setAutoShowAiExplanation(value);
                  },
                ),
                if (settings.autoShowAiExplanation) ...[
                  const Divider(height: 1),
                  _AiExplanationSubSwitch(
                    title: l10n.autoShowAiAnalysisToggle,
                    icon: Icons.psychology_alt_outlined,
                    value: settings.autoShowAiAnalysis,
                    onChanged: (value) async {
                      await ref
                          .read(learningSettingsProvider.notifier)
                          .setAutoShowAiAnalysis(value);
                    },
                  ),
                  _AiExplanationSubSwitch(
                    title: l10n.autoShowAiTranslationToggle,
                    icon: Icons.translate,
                    value: settings.autoShowAiTranslation,
                    onChanged: (value) async {
                      await ref
                          .read(learningSettingsProvider.notifier)
                          .setAutoShowAiTranslation(value);
                    },
                  ),
                  _AiExplanationSubSwitch(
                    title: l10n.autoShowAiSenseGroupsToggle,
                    icon: Icons.account_tree_outlined,
                    value: settings.autoShowAiSenseGroups,
                    onChanged: (value) async {
                      await ref
                          .read(learningSettingsProvider.notifier)
                          .setAutoShowAiSenseGroups(value);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.chat, size: 20, color: colorScheme.primary),
              ),
              title: Text(l10n.autoSkipRetellToggle),
              subtitle: Text(
                l10n.autoSkipRetellSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoSkipRetell,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setAutoSkipRetell(value);
                if (value) {
                  await ref
                      .read(learningProgressNotifierProvider.notifier)
                      .triggerAutoSkipScan();
                }
                ref.read(analyticsServiceProvider).track(
                  Events.retellToggleChanged,
                  {
                    EventParams.enabled: value,
                    EventParams.source: 'settings_page',
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.listenAndRepeatRatingToggle),
              subtitle: Text(
                l10n.listenAndRepeatRatingSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.listenAndRepeatRatingEnabled,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setListenAndRepeatRatingEnabled(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.autoPlayRetellRecordingToggle),
              subtitle: Text(
                l10n.autoPlayRetellRecordingSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoPlayRetellRecordingAfterCompletion,
              onChanged: (value) async {
                final notifier = ref.read(learningSettingsProvider.notifier);
                await notifier.setAutoPlayRetellRecordingAfterCompletion(value);
                // 在设置页显式配置过（开或关）即视为已知晓该功能，
                // 不再弹复述完成后的首次提示。
                await notifier.markRetellAutoPlaybackPromptShown();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.retellRatingToggle),
              subtitle: Text(
                l10n.retellRatingSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.retellRatingEnabled,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setRetellRatingEnabled(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: SwitchListTile(
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bookmark_added_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.autoSaveOnUnclearToggle),
              subtitle: Text(
                l10n.autoSaveOnUnclearSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: settings.autoSaveOnUnclear,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setAutoSaveOnUnclear(value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // 新手引导：总开关（默认开启）；开启时在开关左侧内联「重置」入口，
          // 关闭时不显示「重置」（关闭后不再弹任何引导气泡）。
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                AppSpacing.s,
                AppSpacing.s,
                AppSpacing.s,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.newUserGuideToggle,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.newUserGuideSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 仅在开启时显示「重置」：清空所有 flow 的 seen，重新体验引导。
                  if (guideEnabled)
                    TextButton(
                      onPressed: () => _resetGuide(context, ref, l10n),
                      child: Text(l10n.newUserGuideResetAction),
                    ),
                  Switch(
                    value: guideEnabled,
                    onChanged: (value) async {
                      await ref
                          .read(guideEnabledProvider.notifier)
                          .setEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 重置新手引导：清空所有 flow 的 seen 状态，用户可重新体验引导气泡。
  Future<void> _resetGuide(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await ref
        .read(guideControllerProvider.notifier)
        .resetFlows(GuideFlowIds.all);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.resetNewUserGuideDone)));
  }
}

class _AiExplanationSubSwitch extends StatelessWidget {
  const _AiExplanationSubSwitch({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xl + AppSpacing.m,
          right: AppSpacing.l,
        ),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              Transform.scale(
                scale: 0.88,
                alignment: Alignment.centerRight,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

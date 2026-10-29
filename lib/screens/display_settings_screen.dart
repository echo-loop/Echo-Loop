/// 显示设置页面
///
/// 控制学习页的展示偏好，目前只包含「显示推荐卡片」开关。
/// 学习页的「为你推荐」卡片可被用户关闭，关闭后在此重新开启。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/learning_settings_provider.dart';
import '../theme/app_theme.dart';

/// 显示设置页面
class DisplaySettingsScreen extends ConsumerWidget {
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final showRecommendation = ref.watch(
      learningSettingsProvider.select((s) => s.showStudyRecommendation),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.displaySettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        children: [
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
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              title: Text(l10n.showRecommendationToggle),
              subtitle: Text(
                l10n.showRecommendationSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              value: showRecommendation,
              onChanged: (value) async {
                await ref
                    .read(learningSettingsProvider.notifier)
                    .setShowStudyRecommendation(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

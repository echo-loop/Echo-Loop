/// 日历页顶部的「今日目标」进度卡。
///
/// 纯展示组件：进度与打卡状态由调用方传入，不直接读取数据。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class DailyGoalProgressCard extends StatelessWidget {
  /// 今日已学习时长（秒）
  final int studiedSeconds;

  /// 每日学习目标（分钟）
  final int goalMinutes;

  /// 今天是否已打卡。已打卡后以打卡结果为准，即使之后调高目标也保持已完成状态。
  final bool isCheckedIn;

  const DailyGoalProgressCard({
    super.key,
    required this.studiedSeconds,
    required this.goalMinutes,
    required this.isCheckedIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final goalSeconds = goalMinutes * 60;
    final progress = goalSeconds <= 0
        ? 1.0
        : (studiedSeconds / goalSeconds).clamp(0.0, 1.0);
    final color = isCheckedIn
        ? AppTheme.successColor
        : theme.colorScheme.primary;

    final studiedMinutes = studiedSeconds ~/ 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCheckedIn ? Icons.check_circle : Icons.flag_outlined,
                  size: 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.dailyGoalTodayTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isCheckedIn)
                  Text(
                    l10n.dailyGoalTodayCheckedIn,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isCheckedIn ? 1 : progress,
                minHeight: 6,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 进度条下方同时展示已学习时长与目标时长
            Row(
              children: [
                Text(
                  l10n.dailyGoalStudiedLabel(studiedMinutes),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.dailyGoalTargetLabel(goalMinutes),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

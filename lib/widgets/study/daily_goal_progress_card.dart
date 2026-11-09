/// 日历页顶部的「今日目标」进度卡。
///
/// 纯展示组件：进度与打卡状态由调用方传入，不直接读取数据。
library;

import 'package:flutter/material.dart';

import '../../features/daily_goal_check_in/widgets/daily_check_in_share_icon.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/learning_progress_colors.dart';

class DailyGoalProgressCard extends StatelessWidget {
  /// 今日已学习时长（秒）
  final int studiedSeconds;

  /// 每日学习目标（分钟）
  final int goalMinutes;

  /// 今天是否已打卡。已打卡后以打卡结果为准，即使之后调高目标也保持已完成状态。
  final bool isCheckedIn;

  /// 点击「今日已打卡」后的操作；未提供时只展示状态。
  final VoidCallback? onShareTap;

  const DailyGoalProgressCard({
    super.key,
    required this.studiedSeconds,
    required this.goalMinutes,
    required this.isCheckedIn,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final goalSeconds = goalMinutes * 60;
    final progress = goalSeconds <= 0
        ? 1.0
        : (studiedSeconds / goalSeconds).clamp(0.0, 1.0);
    final palette = learningProgressPalette(theme.brightness);
    final color = isCheckedIn ? palette.completed : palette.active;

    final studiedMinutes = studiedSeconds ~/ 60;

    final canShare = isCheckedIn && onShareTap != null;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canShare ? onShareTap : null,
        borderRadius: BorderRadius.circular(16),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.dailyGoalTodayCheckedIn,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.completed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (canShare) ...[
                          const SizedBox(width: 4),
                          DailyCheckInShareIcon(
                            color: palette.completed,
                            size: 14,
                          ),
                        ],
                      ],
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
                  backgroundColor: palette.track,
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
      ),
    );

    if (!canShare) return card;
    return Tooltip(message: l10n.shareCardShare, child: card);
  }
}

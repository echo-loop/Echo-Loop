import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/study_stats_provider.dart';
import '../../theme/app_theme.dart';

/// 学习统计头部组件
///
/// 包含 3 个统计指标卡片（连续天数、今日时长、本周时长）和 7 天柱状图。
class StudyStatsHeader extends ConsumerWidget {
  const StudyStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studyStatsNotifierProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => Column(
        children: [
          _StatsChips(stats: stats),
          if (stats.dailySeconds.any((s) => s > 0)) ...[
            const SizedBox(height: AppSpacing.m),
            _WeeklyBarChart(dailySeconds: stats.dailySeconds),
          ],
        ],
      ),
    );
  }
}

/// 3 个统计指标：连续天数、今日时长、本周时长
///
/// 使用自定义样式容器替代默认 Chip，增加视觉层次。
class _StatsChips extends StatelessWidget {
  final StudyStats stats;

  const _StatsChips({required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.xs,
      children: [
        if (stats.streak > 0)
          _StatChip(
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.orange,
            label: l10n.streakDays(stats.streak),
          ),
        _StatChip(
          icon: Icons.timer_outlined,
          iconColor: theme.colorScheme.primary,
          label:
              '${l10n.todayStudyTimeShort}: ${_formatTime(l10n, stats.todaySeconds)}',
        ),
        _StatChip(
          icon: Icons.date_range_outlined,
          iconColor: theme.colorScheme.tertiary,
          label:
              '${l10n.weekStudyTimeShort}: ${_formatTime(l10n, stats.weekTotalSeconds)}',
        ),
      ],
    );
  }
}

/// 单个统计指标
///
/// 自定义样式：圆角容器 + 图标 + 文字，比默认 Chip 更精致。
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 7 天学习时长柱状图
///
/// 用 Row + Container 实现，不引入图表库。
/// 当天主题色高亮，其余淡色。柱顶圆角。
class _WeeklyBarChart extends StatelessWidget {
  final List<int> dailySeconds;

  const _WeeklyBarChart({required this.dailySeconds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds = dailySeconds.reduce((a, b) => a > b ? a : b);
    const maxBarHeight = 56.0;

    // 计算最近 7 天的星期标签
    final now = DateTime.now();
    final weekdayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _weekdayShort(date.weekday);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.m,
          AppSpacing.m,
          12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final isToday = i == 6;
            final seconds = dailySeconds[i];
            final ratio = maxSeconds > 0 ? seconds / maxSeconds : 0.0;
            final barHeight = (ratio * maxBarHeight).clamp(3.0, maxBarHeight);

            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 柱顶数值
                  if (seconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _formatMinutes(seconds),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight:
                              isToday ? FontWeight.w600 : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  // 柱体
                  Container(
                    height: barHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // 星期标签
                  Text(
                    weekdayLabels[i],
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 格式化秒数为分钟显示（柱状图上方的数字）
  String _formatMinutes(int seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h';
  }

  /// 星期几缩写
  String _weekdayShort(int weekday) {
    return switch (weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '',
    };
  }
}

/// 格式化学习时长显示
String _formatTime(AppLocalizations l10n, int seconds) {
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes <= 0) return l10n.studyTimeMinutes(0);
  if (totalMinutes < 60) return l10n.studyTimeMinutes(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return l10n.studyTimeHoursMinutes(hours, minutes);
}

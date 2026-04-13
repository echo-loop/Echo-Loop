import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/monthly_study_records_provider.dart';
import '../../theme/app_theme.dart';

/// 月度统计摘要卡片
///
/// 显示当月的汇总数据：总学习时长、活跃天数、日均时长、当月最长连续天数。
/// 数据从 [monthlyData] 直接计算，不需要额外查询。
class MonthlySummaryCard extends StatelessWidget {
  /// 当月每日学习数据，key 为日期（1~31）
  final Map<int, MonthDayRecord> monthlyData;

  /// 当月年份
  final int year;

  /// 当月月份
  final int month;

  const MonthlySummaryCard({
    super.key,
    required this.monthlyData,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final stats = _computeStats();

    // 月份标题：中文用 "4月统计"，英文用 "Apr Stats"
    final isZh = l10n.localeName == 'zh';
    final monthLabel = isZh
        ? l10n.monthlySummaryTitle('$month')
        : l10n.monthlySummaryTitle(
            DateFormat.MMM().format(DateTime(year, month)),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF1976D2),
                    label: l10n.monthlyTotal,
                    value: _formatDuration(stats.totalSeconds, l10n),
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF388E3C),
                    label: l10n.monthlyActiveDays,
                    value: l10n.activeDaysFraction(
                      stats.activeDays,
                      stats.totalDays,
                    ),
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    icon: Icons.trending_up,
                    iconColor: const Color(0xFF7B1FA2),
                    label: l10n.monthlyAvgPerDay,
                    value: _formatDuration(stats.avgSecondsPerDay, l10n),
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: Colors.orange,
                    label: l10n.monthlyBestStreak,
                    value: l10n.daysSuffix(stats.bestStreak),
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 计算月度统计数据
  _MonthlyStats _computeStats() {
    final now = DateTime.now();
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 如果是当前月，只计算到今天
    final totalDays = (year == now.year && month == now.month)
        ? now.day
        : daysInMonth;

    int totalSeconds = 0;
    int activeDays = 0;

    for (final record in monthlyData.values) {
      totalSeconds += record.studyTimeSeconds;
      if (record.hasActivity) activeDays++;
    }

    final avgSecondsPerDay = activeDays > 0
        ? (totalSeconds / activeDays).round()
        : 0;

    // 计算当月最长连续天数
    int bestStreak = 0;
    int currentStreak = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      if (monthlyData[day]?.hasActivity ?? false) {
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
    }

    return _MonthlyStats(
      totalSeconds: totalSeconds,
      activeDays: activeDays,
      totalDays: totalDays,
      avgSecondsPerDay: avgSecondsPerDay,
      bestStreak: bestStreak,
    );
  }

  /// 格式化时长
  String _formatDuration(int seconds, AppLocalizations l10n) {
    if (seconds <= 0) return '0m';
    final totalMin = (seconds / 60).ceil();
    if (totalMin < 60) {
      return '${totalMin}m';
    }
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

/// 月度统计内部数据
class _MonthlyStats {
  final int totalSeconds;
  final int activeDays;
  final int totalDays;
  final int avgSecondsPerDay;
  final int bestStreak;

  const _MonthlyStats({
    required this.totalSeconds,
    required this.activeDays,
    required this.totalDays,
    required this.avgSecondsPerDay,
    required this.bestStreak,
  });
}

/// 统计单元格
class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ThemeData theme;

  const _StatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

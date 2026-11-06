import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/monthly_study_records_provider.dart';
import '../../theme/app_theme.dart';
import '../stat_value_text.dart';

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
            // 自适应列数：窄屏两列，宽屏自动增加列数，避免固定两列在宽屏上留白。
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisExtent: 64,
                crossAxisSpacing: AppSpacing.m,
                mainAxisSpacing: AppSpacing.m,
              ),
              children: [
                _StatCell(
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF1976D2),
                  label: l10n.monthlyTotal,
                  value: _durationValue(stats.totalSeconds, l10n),
                  theme: theme,
                ),
                _StatCell(
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFF7B1FA2),
                  label: l10n.monthlyAvgPerDay,
                  value: _durationValue(stats.avgSecondsPerDay, l10n),
                  theme: theme,
                ),
                _StatCell(
                  icon: Icons.calendar_today_outlined,
                  iconColor: const Color(0xFF388E3C),
                  label: l10n.monthlyActiveDays,
                  value: _daysValue(stats.activeDays, l10n),
                  theme: theme,
                ),
                _StatCell(
                  icon: Icons.check_circle_outline,
                  iconColor: AppTheme.successColor,
                  label: l10n.monthlyCheckInDays,
                  value: _daysValue(stats.checkInDays, l10n),
                  theme: theme,
                ),
                _StatCell(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: Colors.orange,
                  label: l10n.monthlyBestStreak,
                  value: _daysValue(stats.bestStreak, l10n),
                  theme: theme,
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
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int totalSeconds = 0;
    int activeDays = 0;
    int checkInDays = 0;

    for (final record in monthlyData.values) {
      totalSeconds += record.studyTimeSeconds;
      if (record.hasActivity) activeDays++;
      if (record.isCheckedIn) checkInDays++;
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
      avgSecondsPerDay: avgSecondsPerDay,
      bestStreak: bestStreak,
      checkInDays: checkInDays,
    );
  }

  /// 时长：大数字 + 小字单位。不足一小时显示分钟；满一小时显示小时，剩余分钟放进单位。
  StatValue _durationValue(int seconds, AppLocalizations l10n) {
    if (seconds <= 0) return StatValue('0', l10n.unitMinute);
    final totalMin = (seconds / 60).ceil();
    if (totalMin < 60) return StatValue('$totalMin', l10n.unitMinute);
    final hours = totalMin ~/ 60;
    final minutes = totalMin % 60;
    return StatValue(
      '$hours',
      minutes == 0 ? l10n.unitHour : l10n.hourMinuteUnit(minutes),
    );
  }

  /// 天数：大数字 + 小字「天」。
  StatValue _daysValue(int days, AppLocalizations l10n) =>
      StatValue('$days', l10n.unitDay);
}

/// 月度统计内部数据
class _MonthlyStats {
  final int totalSeconds;
  final int activeDays;
  final int avgSecondsPerDay;
  final int bestStreak;
  final int checkInDays;

  const _MonthlyStats({
    required this.totalSeconds,
    required this.activeDays,
    required this.avgSecondsPerDay,
    required this.bestStreak,
    required this.checkInDays,
  });
}

/// 统计单元格
class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final StatValue value;
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
    // 图标与文字块在行内垂直居中：图标放进同色系的圆底里，与两行文字的整体高度对齐。
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.s),
        // 格子较窄时文字截断，避免整行溢出。
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              StatValueText(
                value: value,
                numberStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

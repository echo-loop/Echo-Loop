import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/monthly_study_records_provider.dart';
import '../providers/study_stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/study/activity_day_cell.dart';
import '../widgets/study/day_stage_breakdown_sheet.dart';
import '../widgets/study/monthly_summary_card.dart';

/// 活动日历页面
///
/// 以月视图展示每天的学习活动和时长，点击某天弹出阶段明细弹窗。
/// 页面头部显示当前 streak，支持左右滑动切换月份。
/// 有活动的日期用绿色圆形填充，颜色深浅表示学习强度。
class ActivityCalendarScreen extends ConsumerStatefulWidget {
  const ActivityCalendarScreen({super.key});

  @override
  ConsumerState<ActivityCalendarScreen> createState() =>
      _ActivityCalendarScreenState();
}

class _ActivityCalendarScreenState
    extends ConsumerState<ActivityCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// 中文星期简称（一 ~ 日）
  static const _zhWeekdays = ['一', '二', '三', '四', '五', '六', '日'];

  /// 英文星期简称
  static const _enWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final locale = l10n.localeName;
    final isZh = locale == 'zh';

    final recordsAsync = ref.watch(monthlyStudyRecordsProvider(year, month));
    final statsAsync = ref.watch(studyStatsNotifierProvider);
    final service = ref.read(studyTimeServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityCalendar),
        actions: [_buildStreakChip(context, statsAsync)],
      ),
      // 点击空白处清空日期选择
      body: GestureDetector(
        onTap: () {
          if (_selectedDay != null) {
            setState(() => _selectedDay = null);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              children: [
                // 月度摘要卡片（在日历上方）
                recordsAsync.when(
                  data: (records) => MonthlySummaryCard(
                    monthlyData: records,
                    year: year,
                    month: month,
                  ),
                  loading: () => MonthlySummaryCard(
                    monthlyData: const {},
                    year: year,
                    month: month,
                  ),
                  error: (_, __) => MonthlySummaryCard(
                    monthlyData: const {},
                    year: year,
                    month: month,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                // 日历卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: recordsAsync.when(
                      data: (records) =>
                          _buildCalendar(records, locale, service, isZh),
                      loading: () => _buildCalendar({}, locale, service, isZh),
                      error: (_, __) =>
                          _buildCalendar({}, locale, service, isZh),
                    ),
                  ),
                ),
                // 颜色深浅图例 / 空月份提示
                recordsAsync.whenOrNull(
                      data: (records) => records.isNotEmpty
                          ? _buildLegend(theme, isZh)
                          : _buildEmptyHint(theme, l10n),
                    ) ??
                    const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建日历组件
  Widget _buildCalendar(
    Map<int, MonthDayRecord> records,
    String locale,
    dynamic service,
    bool isZh,
  ) {
    final theme = Theme.of(context);

    return TableCalendar<void>(
      focusedDay: _focusedDay,
      firstDay: DateTime(2024, 1, 1),
      lastDay: DateTime.now(),
      locale: locale,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        headerPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      daysOfWeekHeight: 28,
      rowHeight: 48,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        // 点击任何本月日期都弹出阶段明细弹窗
        _showBreakdownSheet(selectedDay, service);
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _selectedDay = null;
        });
      },
      calendarBuilders: CalendarBuilders(
        // 星期标题：中文显示 一~日，英文显示 Mon~Sun
        dowBuilder: (context, day) {
          final labels = isZh ? _zhWeekdays : _enWeekdays;
          final label = labels[day.weekday - 1];
          return Center(
            child: Text(
              label,
              style: theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
        defaultBuilder: (context, day, focusedDay) {
          return ActivityDayCell(day: day, record: records[day.day]);
        },
        todayBuilder: (context, day, focusedDay) {
          return ActivityDayCell(
            day: day,
            record: records[day.day],
            isToday: true,
            isSelected: isSameDay(day, _selectedDay),
          );
        },
        selectedBuilder: (context, day, focusedDay) {
          final isToday = isSameDay(day, DateTime.now());
          return ActivityDayCell(
            day: day,
            record: records[day.day],
            isToday: isToday,
            isSelected: true,
          );
        },
        outsideBuilder: (context, day, focusedDay) {
          return ActivityDayCell(day: day, isOutside: true);
        },
      ),
    );
  }

  /// 弹出阶段明细弹窗
  void _showBreakdownSheet(DateTime date, dynamic service) {
    showDayStageBreakdownSheet(
      context: context,
      date: date,
      studyTimeService: service,
      showLegend: false,
    );
  }

  /// 颜色深浅图例（日历下方）
  Widget _buildLegend(ThemeData theme, bool isZh) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: AppSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isZh ? '学习时间短' : 'Less study time',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          // 示意 5 级颜色，从浅到深
          for (final mins in [3, 30, 80, 150, 300]) ...[
            _legendBlock(
              ActivityDayCell.intensityColor(mins * 60, theme.brightness),
            ),
            const SizedBox(width: 2),
          ],
          const SizedBox(width: 6),
          Text(
            isZh ? '学习时间长' : 'More study time',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendBlock(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  /// 构建 streak chip
  Widget _buildStreakChip(
    BuildContext context,
    AsyncValue<StudyStats> statsAsync,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final streak = statsAsync.valueOrNull?.streak ?? 0;
    final isActive = streak > 0;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.orange.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: isActive
                  ? Colors.orange
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.streakDays(streak),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.orange.shade800
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空月份提示
  Widget _buildEmptyHint(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
      child: Text(
        l10n.noActivityThisMonth,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

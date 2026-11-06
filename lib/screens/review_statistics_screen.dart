import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/review_statistics/review_statistics_provider.dart';
import '../features/review_statistics/review_statistics_repository.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common/app_segmented_button.dart';
import '../widgets/stat_value_text.dart';

/// 收藏复习统计页，将当天行动、近期表现与历史记录按时间口径分层展示。
class ReviewStatisticsScreen extends ConsumerWidget {
  const ReviewStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewStatisticsProvider);
    final notifier = ref.read(reviewStatisticsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewStatisticsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.reviewStatisticsLoadError)),
        data: (stats) => RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList.list(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          children: [
                            _ScopeSelector(
                              selected: notifier.scope,
                              onChanged: notifier.setScope,
                              l10n: l10n,
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(
                              title: l10n.reviewStatisticsTodayOverview,
                              icon: Icons.dashboard_rounded,
                              accent: _SectionAccent.primary,
                            ),
                            const SizedBox(height: 12),
                            _TodayOverview(stats: stats, l10n: l10n),
                            const SizedBox(height: 12),
                            _CurrentDueNotice(stats: stats, l10n: l10n),
                            const SizedBox(height: 28),
                            _SectionHeader(
                              title: l10n.reviewStatisticsLearningRhythm,
                              icon: Icons.insights_rounded,
                              accent: _SectionAccent.secondary,
                            ),
                            const SizedBox(height: 12),
                            _StreakCard(stats: stats, l10n: l10n),
                            const SizedBox(height: 14),
                            _JournalCard(
                              title: l10n.reviewStatisticsTrend,
                              subtitle: l10n.reviewStatisticsTrendExplanation,
                              child: _TrendChart(stats: stats, l10n: l10n),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(
                              title: l10n.reviewStatisticsReviewPlan,
                              icon: Icons.event_available_rounded,
                              accent: _SectionAccent.tertiary,
                            ),
                            const SizedBox(height: 12),
                            _JournalCard(
                              title: l10n.reviewStatisticsUpcoming,
                              subtitle:
                                  l10n.reviewStatisticsUpcomingExplanation,
                              child: _UpcomingChart(stats: stats, l10n: l10n),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(
                              title: l10n.reviewStatisticsRecentPerformance,
                              icon: Icons.trending_up_rounded,
                              accent: _SectionAccent.surface,
                            ),
                            const SizedBox(height: 12),
                            _JournalCard(
                              title: l10n.reviewStatisticsRatings,
                              subtitle:
                                  l10n.reviewStatisticsRetentionExplanation,
                              child: _RatingChart(stats: stats, l10n: l10n),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeader(
                              title: l10n.reviewStatisticsHistory,
                              icon: Icons.timeline_rounded,
                              accent: _SectionAccent.error,
                            ),
                            const SizedBox(height: 12),
                            _JournalCard(
                              title: l10n.reviewStatisticsContent,
                              subtitle: l10n.reviewStatisticsContentExplanation,
                              child: _ContentSummary(
                                stats: stats,
                                scope: notifier.scope,
                                l10n: l10n,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  final ReviewStatisticsScope selected;
  final ValueChanged<ReviewStatisticsScope> onChanged;
  final AppLocalizations l10n;

  const _ScopeSelector({
    required this.selected,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) =>
      AppSegmentedButton<ReviewStatisticsScope>(
        segments: [
          ButtonSegment(
            value: ReviewStatisticsScope.all,
            label: Text(l10n.reviewStatisticsAll),
          ),
          ButtonSegment(
            value: ReviewStatisticsScope.sentences,
            label: Text(l10n.reviewStatisticsSentences),
          ),
          ButtonSegment(
            value: ReviewStatisticsScope.vocabulary,
            label: Text(l10n.reviewStatisticsVocabulary),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
      );
}

enum _SectionAccent { primary, secondary, tertiary, surface, error }

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final _SectionAccent accent;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (backgroundColor, foregroundColor) = switch (accent) {
      _SectionAccent.primary => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      _SectionAccent.secondary => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      _SectionAccent.tertiary => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      _SectionAccent.surface => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
      _SectionAccent.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
    };
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: foregroundColor),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _TodayOverview extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _TodayOverview({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = [
        _MetricCard(
          value: _itemCountValue(stats.todayReviewedCards, l10n),
          label: l10n.reviewStatisticsTodayCompleted,
          accent: Theme.of(context).colorScheme.primary,
        ),
        _MetricCard(
          value: _durationValue(stats.todaySeconds, l10n),
          label: l10n.reviewStatisticsDuration,
          accent: const Color(0xFF4D9271),
        ),
      ];
      if (constraints.maxWidth < 360) {
        return Column(
          children: [metrics.first, const SizedBox(height: 10), metrics.last],
        );
      }
      return Row(
        children: [
          Expanded(child: metrics.first),
          const SizedBox(width: 12),
          Expanded(child: metrics.last),
        ],
      );
    },
  );
}

/// 指标块：浅色底 + 强调色大数字 + 标签，无图标与阴影。
///
/// 与学习统计的指标样式保持一致，颜色由 [accent] 派生。
class _MetricCard extends StatelessWidget {
  final StatValue value;
  final String label;
  final Color accent;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatValueText(
            value: value,
            numberStyle: theme.textTheme.headlineMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentDueNotice extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _CurrentDueNotice({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFFC56B45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.09,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: accent, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewStatisticsCurrentDue(
                    _formatItemCount(stats.dueNow, l10n),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.reviewStatisticsCurrentDueBreakdown(
                    stats.overdueNow,
                    stats.dueNow - stats.overdueNow,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _StreakCard({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFFD88A36);
    return _Surface(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: accent,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewStatisticsStreak,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.reviewStatisticsStreakExplanation(stats.streak),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${stats.streak}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _Surface({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: theme.brightness == Brightness.light ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: theme.brightness == Brightness.dark
            ? BorderSide(color: theme.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _JournalCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _TrendChart extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _TrendChart({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (!stats.dailyTrend.any((day) => day.reviewedCards > 0)) {
      return const _ChartEmptyState(icon: Icons.bar_chart_rounded);
    }
    final theme = Theme.of(context);
    final maxY = stats.dailyTrend
        .map((day) => day.reviewedCards)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final interval = (maxY / 3).clamp(1, double.infinity).toDouble();
    return SizedBox(
      height: 184,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.18,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 29,
                interval: interval,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= stats.dailyTrend.length ||
                      (index != 0 &&
                          index != 7 &&
                          index != 14 &&
                          index != 21 &&
                          index != stats.dailyTrend.length - 1)) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat('M/d').format(stats.dailyTrend[index].date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, _, rod, __) {
                final day = stats.dailyTrend[group.x];
                return BarTooltipItem(
                  '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(day.date)}\n${_formatItemCount(rod.toY.toInt(), l10n)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < stats.dailyTrend.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: stats.dailyTrend[i].reviewedCards.toDouble(),
                    width: 5,
                    color: i == stats.dailyTrend.length - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.62),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
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

class _UpcomingChart extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _UpcomingChart({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (!stats.upcomingDue.any((value) => value > 0)) {
      return const _ChartEmptyState(icon: Icons.event_available_outlined);
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    final maxY = stats.upcomingDue.reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 188,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY / 3).clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 31,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= stats.upcomingDue.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      index == 0
                          ? l10n.reviewStatisticsTodayShort
                          : DateFormat(
                              'M/d',
                            ).format(now.add(Duration(days: index))),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: index == 0
                            ? const Color(0xFFC56B45)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: index == 0 ? FontWeight.w800 : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(now.add(Duration(days: group.x)))}\n${rod.toY.toInt()}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < stats.upcomingDue.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: stats.upcomingDue[i].toDouble(),
                    width: 18,
                    color: i == 0
                        ? const Color(0xFFC56B45)
                        : const Color(0xFF597C65),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7),
                    ),
                    label: BarChartRodLabel(
                      show: stats.upcomingDue[i] > 0,
                      text: stats.upcomingDue[i].toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: i == 0
                            ? const Color(0xFFC56B45)
                            : const Color(0xFF597C65),
                        fontWeight: FontWeight.w800,
                      ),
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

class _RatingChart extends StatelessWidget {
  final ReviewStatistics stats;
  final AppLocalizations l10n;

  const _RatingChart({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (stats.ratings.total == 0) {
      return _ChartEmptyState(
        icon: Icons.donut_large_outlined,
        message: l10n.reviewStatisticsEmptyRatings,
      );
    }
    // 当前复习流程只提供三档评分；历史困难记录归入“再来一遍”，
    // 保持环图与近 30 天首次评分统计使用同一总量。
    final sections = [
      _RatingSlice(
        l10n.bookmarkReviewRatingAgain,
        stats.ratings.again + stats.ratings.hard,
        const Color(0xFFC56B45),
      ),
      _RatingSlice(
        l10n.bookmarkReviewRatingGood,
        stats.ratings.good,
        const Color(0xFF4D9271),
      ),
      _RatingSlice(
        l10n.bookmarkReviewRatingEasy,
        stats.ratings.easy,
        Theme.of(context).colorScheme.primary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = SizedBox(
          width: 156,
          height: 156,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 49,
                  sections: [
                    for (final slice in sections)
                      PieChartSectionData(
                        value: slice.value.toDouble(),
                        color: slice.color,
                        radius: 30,
                        title: '',
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.reviewStatisticsRetentionRate,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${(stats.retentionRate * 100).round()}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        final legend = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final slice in sections)
              _LegendRow(slice: slice, total: stats.ratings.total, l10n: l10n),
          ],
        );
        return constraints.maxWidth < 380
            ? Column(children: [chart, const SizedBox(height: 12), legend])
            : Row(
                children: [
                  chart,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
      },
    );
  }
}

class _RatingSlice {
  final String label;
  final int value;
  final Color color;

  const _RatingSlice(this.label, this.value, this.color);
}

class _LegendRow extends StatelessWidget {
  final _RatingSlice slice;
  final int total;
  final AppLocalizations l10n;

  const _LegendRow({
    required this.slice,
    required this.total,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(
            _formatItemCount(slice.value, l10n),
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(slice.value / total * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _ContentSummary extends StatelessWidget {
  final ReviewStatistics stats;
  final ReviewStatisticsScope scope;
  final AppLocalizations l10n;

  const _ContentSummary({
    required this.stats,
    required this.scope,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = switch (scope) {
      ReviewStatisticsScope.all => [
        _ContentTile(
          label: l10n.reviewStatisticsSentences,
          count: stats.totalSentences,
          color: Theme.of(context).colorScheme.primary,
        ),
        _ContentTile(
          label: l10n.reviewStatisticsVocabulary,
          count: stats.totalVocabulary,
          color: const Color(0xFF4D9271),
        ),
      ],
      ReviewStatisticsScope.sentences => [
        _ContentTile(
          label: l10n.reviewStatisticsSentences,
          count: stats.totalSentences,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
      ReviewStatisticsScope.vocabulary => [
        _ContentTile(
          label: l10n.reviewStatisticsVocabulary,
          count: stats.totalVocabulary,
          color: const Color(0xFF4D9271),
        ),
      ],
    };
    return Row(
      children: [
        for (var index = 0; index < tiles.length; index++) ...[
          Expanded(child: tiles[index]),
          if (index < tiles.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ContentTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ContentTile({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String? message;

  const _ChartEmptyState({required this.icon, this.message});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 30,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

String _formatItemCount(int count, AppLocalizations l10n) =>
    l10n.reviewStatisticsItemCount(count);

/// 今日条目数：大数字 + 小字「项」。
StatValue _itemCountValue(int count, AppLocalizations l10n) =>
    StatValue('$count', l10n.unitItem);

/// 复习时长：不足一分钟用秒，否则用分钟；大数字 + 小字单位。
StatValue _durationValue(int seconds, AppLocalizations l10n) {
  final minutes = seconds ~/ 60;
  if (minutes == 0) return StatValue('$seconds', l10n.unitSecond);
  return StatValue('$minutes', l10n.unitMinute);
}

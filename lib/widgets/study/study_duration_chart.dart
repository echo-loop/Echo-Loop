import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/study_duration_provider.dart';
import '../../database/providers.dart';
import '../../services/study_time_service.dart';
import '../../theme/app_theme.dart';
import '../common/app_segmented_button.dart';
import 'day_stage_breakdown_sheet.dart';
import 'study_stats_header.dart';

/// 学习日历下方的历史学习时长统计。
class StudyDurationChart extends ConsumerStatefulWidget {
  const StudyDurationChart({super.key});

  @override
  ConsumerState<StudyDurationChart> createState() => _StudyDurationChartState();
}

class _StudyDurationChartState extends ConsumerState<StudyDurationChart> {
  StudyDurationGranularity _granularity = StudyDurationGranularity.week;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studyDurationBucketsProvider(_granularity));
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isZh ? '学习时长' : 'Study duration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: AppSegmentedButton<StudyDurationGranularity>(
                minimumHeight: 30,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                segments: [
                  ButtonSegment(
                    value: StudyDurationGranularity.day,
                    label: Text(isZh ? '日' : 'Day'),
                  ),
                  ButtonSegment(
                    value: StudyDurationGranularity.week,
                    label: Text(isZh ? '周' : 'Week'),
                  ),
                  ButtonSegment(
                    value: StudyDurationGranularity.month,
                    label: Text(isZh ? '月' : 'Month'),
                  ),
                  ButtonSegment(
                    value: StudyDurationGranularity.year,
                    label: Text(isZh ? '年' : 'Year'),
                  ),
                ],
                selected: {_granularity},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() => _granularity = value.first);
                },
              ),
            ),
            const SizedBox(height: 12),
            async.when(
              loading: () => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorState(
                onRetry: () => ref.invalidate(studyDurationRecordsProvider),
              ),
              data: (buckets) =>
                  buckets.every((bucket) => bucket.totalSeconds == 0)
                  ? SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.studyDurationNoRecords,
                        ),
                      ),
                    )
                  : _BucketList(
                      key: ValueKey(_granularity),
                      buckets: buckets,
                      granularity: _granularity,
                    ),
            ),
            const SizedBox(height: 12),
            const _ChartLegend(),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 100,
    child: Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    ),
  );
}

/// 历史学习时长柱状图的听、说、其它颜色图例。
class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 8,
        spacing: 16,
        children: [
          _LegendItem(color: kInputColor, label: l10n.chartLegendListening),
          _LegendItem(color: kOutputColor, label: l10n.chartLegendSpeaking),
          _LegendItem(
            color: kOtherColor,
            label: '${l10n.chartLegendOther} (${l10n.chartLegendOtherHint})',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BucketList extends ConsumerStatefulWidget {
  final List<StudyDurationBucket> buckets;
  final StudyDurationGranularity granularity;
  const _BucketList({
    super.key,
    required this.buckets,
    required this.granularity,
  });

  @override
  ConsumerState<_BucketList> createState() => _BucketListState();
}

class _BucketListState extends ConsumerState<_BucketList> {
  /// 100% 字号下柱体的最大高度；字号变大时柱体会进一步被剩余高度压缩。
  static const double _maxBarHeight = 90;

  final ScrollController _scrollController = ScrollController();
  bool _sheetOpen = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var maxValue = 1;
    for (final bucket in widget.buckets) {
      if (bucket.totalSeconds > maxValue) maxValue = bucket.totalSeconds;
    }
    // 图表文字最多放大 1.3 倍：列宽与图表高度固定，字号过大会挤压布局。
    // 标题、分段按钮和图例不在此范围内，仍按系统字号缩放。
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.3);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          controller: _scrollController,
          // 从最新周期端开始布局，避免首帧先绘制最早周期再跳转到末端。
          reverse: true,
          scrollDirection: Axis.horizontal,
          itemExtent: 58,
          cacheExtent: 58 * 8,
          itemCount: widget.buckets.length,
          itemBuilder: (context, index) {
            final bucket = widget.buckets[widget.buckets.length - index - 1];
            final label = formatStudyDurationBucketLabel(
              bucket: bucket,
              granularity: widget.granularity,
              now: DateTime.now(),
              isZh: Localizations.localeOf(context).languageCode == 'zh',
            );
            return Semantics(
              label:
                  '${bucket.periodStart} - ${bucket.periodEnd}, ${bucket.totalSeconds} seconds${bucket.isCurrentPeriod ? ', current period' : ''}',
              button: true,
              child: GestureDetector(
                onLongPress: () => _showTooltip(context, bucket),
                onTap: () => _showTooltip(context, bucket),
                child: Column(
                  children: [
                    Text(
                      bucket.totalSeconds == 0
                          ? ''
                          : formatStudyDurationCompact(bucket.totalSeconds),
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    const SizedBox(height: 3),
                    // 柱体占用数值与日期标签之外的剩余高度：字号变大只会压缩柱体，不会撑破列高。
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final barHeight = bucket.totalSeconds == 0
                              ? 3.0
                              : math.min(_maxBarHeight, constraints.maxHeight) *
                                    bucket.totalSeconds /
                                    maxValue;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 30,
                              height: barHeight,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: _StackedBar(bucket: bucket),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 立即打开唯一面板；FutureBuilder 随面板销毁，迟到查询不会另开弹窗。
  Future<void> _showTooltip(
    BuildContext context,
    StudyDurationBucket bucket,
  ) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final service = ref.read(studyTimeServiceProvider);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final start = bucket.periodStart;
    final end = bucket.periodEnd;
    debugPrint('[StudyDurationChart] 加载阶段明细：$start — $end');
    final title = switch (widget.granularity) {
      StudyDurationGranularity.day => null,
      StudyDurationGranularity.week =>
        '${start.year}/${start.month}/${start.day} – ${end.year}/${end.month}/${end.day}',
      StudyDurationGranularity.month =>
        isZh ? '${start.year}年${start.month}月' : '${start.year}/${start.month}',
      StudyDurationGranularity.year =>
        isZh ? '${start.year}年' : '${start.year}',
    };
    var query = service.getStageBreakdownInRange(start, end);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (context, setSheetState) =>
              FutureBuilder<List<DailyStageStudyRecordData>>(
                future: query,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const SafeArea(
                      child: SizedBox(
                        height: 150,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    debugPrint(
                      '[StudyDurationChart] 阶段明细加载失败：${snapshot.error}',
                    );
                    return SafeArea(
                      child: _ErrorState(
                        onRetry: () {
                          setSheetState(() {
                            query = service.getStageBreakdownInRange(
                              start,
                              end,
                            );
                          });
                        },
                      ),
                    );
                  }
                  return DayStageBreakdownSheet(
                    date: start,
                    periodTitle: title,
                    stageRecords: snapshot.data ?? const [],
                    totalData: DailyTotalData(
                      studyTimeSeconds: bucket.totalSeconds,
                      inputTimeSeconds: bucket.inputSeconds,
                      outputTimeSeconds: bucket.outputSeconds,
                    ),
                  );
                },
              ),
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }
}

/// 使用紧凑的小时和分钟格式展示学习时长。
///
/// 分钟统一向上取整，确保柱状图标签与学习时长明细使用相同的显示口径。
String formatStudyDurationCompact(int seconds) {
  if (seconds > 0 && seconds < 60) return '<1m';
  final totalMinutes = seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) return minutes > 0 ? '${hours}h${minutes}m' : '${hours}h';
  return '${minutes}m';
}

/// 按粒度生成易读的时间轴标签，并优先标识当前和上一周期。
String formatStudyDurationBucketLabel({
  required StudyDurationBucket bucket,
  required StudyDurationGranularity granularity,
  required DateTime now,
  required bool isZh,
}) {
  final currentStart = _periodStart(now, granularity);
  final previousStart = _previousPeriodStart(currentStart, granularity);
  if (_sameDate(bucket.periodStart, currentStart)) {
    return isZh ? _currentLabel(granularity) : _currentLabelEn(granularity);
  }
  if (_sameDate(bucket.periodStart, previousStart)) {
    return isZh ? _previousLabel(granularity) : _previousLabelEn(granularity);
  }
  if (granularity == StudyDurationGranularity.year) {
    return '${bucket.periodStart.year}';
  }
  // 月标签只保留月份名，周标签只保留起始日，完整区间在点击后的明细标题中展示，避免大字号下换行。
  if (granularity == StudyDurationGranularity.month) {
    return isZh
        ? '${bucket.periodStart.month}月'
        : _monthAbbreviations[bucket.periodStart.month - 1];
  }
  return '${bucket.periodStart.month}/${bucket.periodStart.day}';
}

DateTime _periodStart(DateTime date, StudyDurationGranularity granularity) {
  final normalized = DateTime(date.year, date.month, date.day);
  return switch (granularity) {
    StudyDurationGranularity.day => normalized,
    StudyDurationGranularity.week => normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    ),
    StudyDurationGranularity.month => DateTime(date.year, date.month),
    StudyDurationGranularity.year => DateTime(date.year),
  };
}

DateTime _previousPeriodStart(
  DateTime currentStart,
  StudyDurationGranularity granularity,
) => switch (granularity) {
  StudyDurationGranularity.day => currentStart.subtract(
    const Duration(days: 1),
  ),
  StudyDurationGranularity.week => currentStart.subtract(
    const Duration(days: 7),
  ),
  StudyDurationGranularity.month => DateTime(
    currentStart.year,
    currentStart.month - 1,
  ),
  StudyDurationGranularity.year => DateTime(currentStart.year - 1),
};

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _currentLabel(StudyDurationGranularity granularity) =>
    switch (granularity) {
      StudyDurationGranularity.day => '今天',
      StudyDurationGranularity.week => '本周',
      StudyDurationGranularity.month => '本月',
      StudyDurationGranularity.year => '今年',
    };

String _previousLabel(StudyDurationGranularity granularity) =>
    switch (granularity) {
      StudyDurationGranularity.day => '昨天',
      StudyDurationGranularity.week => '上周',
      StudyDurationGranularity.month => '上月',
      StudyDurationGranularity.year => '去年',
    };

String _currentLabelEn(StudyDurationGranularity granularity) =>
    switch (granularity) {
      StudyDurationGranularity.day => 'Today',
      StudyDurationGranularity.week => 'This week',
      StudyDurationGranularity.month => 'This month',
      StudyDurationGranularity.year => 'This year',
    };

String _previousLabelEn(StudyDurationGranularity granularity) =>
    switch (granularity) {
      StudyDurationGranularity.day => 'Yesterday',
      StudyDurationGranularity.week => 'Last week',
      StudyDurationGranularity.month => 'Last month',
      StudyDurationGranularity.year => 'Last year',
    };

class _StackedBar extends StatelessWidget {
  final StudyDurationBucket bucket;
  const _StackedBar({required this.bucket});
  @override
  Widget build(BuildContext context) {
    final total = bucket.totalSeconds;
    if (total <= 0) {
      return Container(color: Theme.of(context).colorScheme.outlineVariant);
    }
    return Column(
      children: [
        if (bucket.otherSeconds > 0)
          Expanded(
            flex: bucket.otherSeconds,
            child: Container(color: kOtherColor),
          ),
        if (bucket.outputSeconds > 0)
          Expanded(
            flex: bucket.outputSeconds,
            child: Container(color: kOutputColor),
          ),
        if (bucket.inputSeconds > 0)
          Expanded(
            flex: bucket.inputSeconds,
            child: Container(color: kInputColor),
          ),
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/study_time_service.dart';
import '../../providers/study_stats_provider.dart';
import '../../theme/app_theme.dart';
import 'day_stage_breakdown_sheet.dart';
import 'learned_word_forms_sheet.dart';

/// 输入（听力）主题色 — 蓝色
const kInputColor = Color(0xFF3B82F6);

/// 输出（口语）主题色 — 绿色
const kOutputColor = Color(0xFF10B981);

/// 其它（思考、停顿等）主题色 — 灰色
const kOtherColor = Color(0xFFD1D5DB);

/// 学习统计头部组件
///
/// 分三层信息层次：
/// 1. 今日卡片：学习时长 + 听/说明细（同一时间维度）
/// 2. 本周柱状图：标题行含本周累计，柱体双色堆叠
/// 3. 词汇量 badge：累计量 + 今日增量，可点击展开
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
          _TodayCard(
            stats: stats,
            studyTimeService: ref.read(studyTimeServiceProvider),
            onStudyTimeTap: () => ref
                .read(analyticsServiceProvider)
                .track(Events.studyTimeViewed),
          ),
          if (stats.dailySeconds.any((s) => s > 0)) ...[
            const SizedBox(height: AppSpacing.s),
            _WeeklyBarChart(
              weekTotalSeconds: stats.weekTotalSeconds,
              dailyInputSeconds: stats.dailyInputSeconds,
              dailyOutputSeconds: stats.dailyOutputSeconds,
              dailyTotalSeconds: stats.dailySeconds,
              onBarTap: (date) {
                ref.read(analyticsServiceProvider).track(
                  Events.dayBreakdownViewed,
                  {
                    EventParams.dateParam:
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  },
                );
                final service = ref.read(studyTimeServiceProvider);
                showDayStageBreakdownSheet(
                  context: context,
                  date: date,
                  studyTimeService: service,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 今日学习卡片
///
/// 顶部大字显示今日总时长，下方两列显示听/说明细。
/// 所有数据均为"今日"维度，视觉上清晰统一。
/// 点击今日时长行弹出阶段总览，点击听/说弹出对应维度阶段明细。
class _TodayCard extends StatelessWidget {
  final StudyStats stats;
  final StudyTimeService studyTimeService;
  final VoidCallback? onStudyTimeTap;

  const _TodayCard({
    required this.stats,
    required this.studyTimeService,
    this.onStudyTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final today = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: 12,
        ),
        child: Column(
          children: [
            // 第一行：今日时长（点击弹出阶段总览）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onStudyTimeTap?.call();
                showDayStageBreakdownSheet(
                  context: context,
                  date: today,
                  studyTimeService: studyTimeService,
                );
              },
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.todayStudyTimeShort,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(l10n, stats.todaySeconds),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 第二行：听 / 说 / 词汇 三列（clamp 防御脏数据）
            Builder(
              builder: (context) {
                final clampedInput = math.min(
                  stats.todayInputSeconds,
                  stats.todaySeconds,
                );
                final clampedOutput = math.min(
                  stats.todayOutputSeconds,
                  stats.todaySeconds,
                );
                if (clampedInput != stats.todayInputSeconds ||
                    clampedOutput != stats.todayOutputSeconds) {
                  debugPrint(
                    '⚠️ 今日卡片 clamp: input ${stats.todayInputSeconds}→$clampedInput, '
                    'output ${stats.todayOutputSeconds}→$clampedOutput, '
                    'total ${stats.todaySeconds}',
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _ListenSpeakItem(
                        icon: Icons.headphones_outlined,
                        iconColor: kInputColor,
                        timeText: _formatTimeShort(
                          clampedInput,
                          isZh: l10n.localeName == 'zh',
                        ),
                        wordText:
                            '${_formatWordCount(stats.todayInputWords)}${l10n.localeName == 'zh' ? '词' : 'w'}',
                        onTap: () => showDayStageBreakdownSheet(
                          context: context,
                          date: today,
                          studyTimeService: studyTimeService,
                          mode: StageBreakdownMode.input,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _ListenSpeakItem(
                        icon: Icons.mic_outlined,
                        iconColor: kOutputColor,
                        timeText: _formatTimeShort(
                          clampedOutput,
                          isZh: l10n.localeName == 'zh',
                        ),
                        onTap: () => showDayStageBreakdownSheet(
                          context: context,
                          date: today,
                          studyTimeService: studyTimeService,
                          mode: StageBreakdownMode.output,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _VocabItem(
                        todayNew: stats.todayNewWordForms,
                        onTap: () =>
                            showLearnedWordFormsSheet(context: context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 听/说单项指标
///
/// 图标 + 时间 · 词数，水平居中排列。
class _ListenSpeakItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String timeText;
  final String? wordText;
  final VoidCallback? onTap;

  const _ListenSpeakItem({
    required this.icon,
    required this.iconColor,
    required this.timeText,
    this.wordText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.labelSmall!.copyWith(fontSize: 12);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              timeText,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (wordText != null) ...[
              Text(
                ' · ',
                style: baseStyle.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              Text(
                wordText!,
                style: baseStyle.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 词汇今日新增项（嵌入今日卡片第二行）
///
/// 只显示今日新增词数，点击可打开词汇列表弹窗查看全局数据。
class _VocabItem extends StatelessWidget {
  final int todayNew;
  final VoidCallback onTap;

  const _VocabItem({required this.todayNew, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final baseStyle = theme.textTheme.labelSmall!.copyWith(fontSize: 12);
    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.spellcheck_rounded, size: 14, color: Colors.indigo),
            const SizedBox(width: 4),
            Text(
              '+${_formatWordCount(todayNew)}',
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.localeName == 'zh' ? '词' : 'w',
              style: baseStyle.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 7 天学习时长柱状图（双色堆叠）
///
/// 标题行显示"本周"累计时长，柱体底部蓝色 = 输入，顶部绿色 = 输出。
/// 向前兼容：旧数据无 input/output 时，用 totalSeconds 当输入（蓝色单色）。
/// 点击有数据的柱子可查看该天各阶段详细时长。
class _WeeklyBarChart extends StatefulWidget {
  final int weekTotalSeconds;
  final List<int> dailyInputSeconds;
  final List<int> dailyOutputSeconds;
  final List<int> dailyTotalSeconds;
  final void Function(DateTime date)? onBarTap;

  const _WeeklyBarChart({
    required this.weekTotalSeconds,
    required this.dailyInputSeconds,
    required this.dailyOutputSeconds,
    required this.dailyTotalSeconds,
    this.onBarTap,
  });

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart> {
  /// 当前高亮的柱子索引（点击后短暂高亮）
  int? _highlightIndex;

  void _onBarTapped(int index) {
    final totalSec = widget.dailyTotalSeconds[index];
    if (totalSec <= 0 || widget.onBarTap == null) return;

    // 计算对应日期
    final now = DateTime.now();
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: 6 - index));

    // 短暂高亮 150ms
    setState(() => _highlightIndex = index);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlightIndex = null);
    });

    widget.onBarTap!(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 柱高基于 totalSeconds（而非 input+output），避免重叠计时导致柱高虚高
    final maxSeconds = widget.dailyTotalSeconds.reduce((a, b) => a > b ? a : b);
    const maxBarHeight = 56.0;

    // 计算最近 7 天的星期标签
    final now = DateTime.now();
    final weekdayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return _weekdayShort(date.weekday);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.m, 12, AppSpacing.m, 12),
        child: Column(
          children: [
            // 标题行：本周累计
            Row(
              children: [
                Icon(
                  Icons.date_range_outlined,
                  size: 15,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${l10n.weekStudyTimeShort}: ${_formatTime(l10n, widget.weekTotalSeconds)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 柱状图
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                final totalSec = widget.dailyTotalSeconds[i];
                final ratio = maxSeconds > 0 ? totalSec / maxSeconds : 0.0;
                final barHeight = (ratio * maxBarHeight).clamp(
                  3.0,
                  maxBarHeight,
                );

                // Clamp input/output 防御历史脏数据
                final hasBreakdown =
                    widget.dailyInputSeconds[i] > 0 ||
                    widget.dailyOutputSeconds[i] > 0;
                final rawInput = hasBreakdown
                    ? widget.dailyInputSeconds[i]
                    : widget.dailyTotalSeconds[i];
                final rawOutput = hasBreakdown
                    ? widget.dailyOutputSeconds[i]
                    : 0;
                var inputSec = math.min(rawInput, totalSec);
                var outputSec = math.min(rawOutput, totalSec);
                // input+output 超过 total 时按比例缩放
                final ioSum = inputSec + outputSec;
                if (ioSum > totalSec && ioSum > 0) {
                  final scale = totalSec / ioSum;
                  inputSec = (inputSec * scale).round();
                  outputSec = (outputSec * scale).round();
                }
                // 三段比例：听 / 说 / 其它
                final otherSec = math.max(0, totalSec - inputSec - outputSec);
                final inputRatio = totalSec > 0 ? inputSec / totalSec : 1.0;
                final outputRatio = totalSec > 0 ? outputSec / totalSec : 0.0;
                final otherRatio = totalSec > 0 ? otherSec / totalSec : 0.0;

                // 点击高亮效果
                final isHighlighted = _highlightIndex == i;
                final highlightAlpha = isHighlighted ? 0.5 : 1.0;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onBarTapped(i),
                    child: Opacity(
                      opacity: highlightAlpha,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 柱顶数值
                          if (totalSec > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                _formatMinutes(totalSec),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: isToday
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          // 柱体（三色堆叠：蓝=听，绿=说，灰=其它）
                          _buildStackedBar(
                            barHeight: barHeight,
                            inputRatio: inputRatio,
                            outputRatio: outputRatio,
                            otherRatio: otherRatio,
                            isToday: isToday,
                          ),
                          const SizedBox(height: 5),
                          // 星期标签
                          Text(
                            weekdayLabels[i],
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建三色堆叠柱体（蓝=听，绿=说，灰=其它）
  Widget _buildStackedBar({
    required double barHeight,
    required double inputRatio,
    required double outputRatio,
    required double otherRatio,
    required bool isToday,
  }) {
    final alpha = isToday ? 1.0 : 0.5;
    // 按比例分配高度，用 ClipRect 兜底防溢出
    final inputH = barHeight * inputRatio;
    final outputH = barHeight * outputRatio;
    final otherH = barHeight * otherRatio;

    return Container(
      height: barHeight,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          // 顶部：其它（灰色）
          if (otherH > 0)
            Container(
              height: otherH,
              decoration: BoxDecoration(
                color: kOtherColor.withValues(alpha: alpha),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(4),
                  bottom: outputH == 0 && inputH == 0
                      ? const Radius.circular(2)
                      : Radius.zero,
                ),
              ),
            ),
          // 中间：输出/说（绿色）
          if (outputH > 0)
            Container(
              height: outputH,
              decoration: BoxDecoration(
                color: kOutputColor.withValues(alpha: alpha),
                borderRadius: BorderRadius.vertical(
                  top: otherH == 0 ? const Radius.circular(4) : Radius.zero,
                  bottom: inputH == 0 ? const Radius.circular(2) : Radius.zero,
                ),
              ),
            ),
          // 底部：输入/听（蓝色）
          if (inputH > 0)
            Container(
              height: inputH,
              decoration: BoxDecoration(
                color: kInputColor.withValues(alpha: alpha),
                borderRadius: BorderRadius.vertical(
                  top: otherH == 0 && outputH == 0
                      ? const Radius.circular(4)
                      : Radius.zero,
                  bottom: const Radius.circular(2),
                ),
              ),
            ),
        ],
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

/// 格式化秒数为简短时间显示（用于听/说明细）
///
/// 中文: 0 → "0分", < 3600 → "N分", >= 3600 → "Nh Mm"
/// 英文: 0 → "0m", < 3600 → "Nm", >= 3600 → "Nh Mm"
String _formatTimeShort(int seconds, {bool isZh = true}) {
  final minUnit = isZh ? '分' : 'm';
  if (seconds <= 0) return '0$minUnit';
  final totalMinutes = (seconds / 60).ceil();
  if (totalMinutes < 60) return '$totalMinutes$minUnit';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h${minutes}m';
}

/// 格式化词数显示
///
/// < 1000 → "856", >= 1000 → "1,234", >= 10000 → "12.3k"
String _formatWordCount(int count) {
  if (count >= 10000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(1)}k';
  }
  if (count >= 1000) {
    final str = count.toString();
    return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
  }
  return count.toString();
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

/// 高亮列类型：听弹窗或说弹窗
enum HighlightColumn { listening, speaking }

/// CEFR 每日推荐最少练习量表格
///
/// 三行（初/中/高级）× 三列（阶段 | 听力 | 口语）的对齐表格。
/// 听力列显示听时长+输入词数，口语列显示说时长+输出词数。
/// [highlightColumn] 控制哪一列用强调色，另一列弱化显示。
/// 该组件被听/说两个弹窗共享，仅高亮列不同。
class CefrRecommendationTable extends StatelessWidget {
  final HighlightColumn highlightColumn;
  final bool isZh;

  const CefrRecommendationTable({
    required this.highlightColumn,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = highlightColumn == HighlightColumn.listening;

    // 基于 CEFR 各级别每日推荐练习时长：
    //   初级: 听力 12min, 口语 8min, 日总 20min
    //   中级: 听力 15min, 口语 10min, 日总 25min
    //   高级: 听力 18min, 口语 12min, 日总 30min
    final levels = [
      CefrLevel('A1–A2', isZh ? '初级' : 'Beginner', '12', '8', '5,000', '1,700'),
      CefrLevel(
        'B1–B2',
        isZh ? '中级' : 'Intermediate',
        '15',
        '10',
        '5,500',
        '3,500',
      ),
      CefrLevel(
        'C1–C2',
        isZh ? '高级' : 'Advanced',
        '18',
        '12',
        '6,000',
        '5,000',
      ),
    ];

    final listenHeader = isZh ? '听力（输入）' : 'Listening (input)';
    final speakHeader = isZh ? '口语（输出）' : 'Speaking (output)';
    final minLabel = isZh ? '分钟' : 'min';
    final wordSuffix = isZh ? '词' : 'w';
    final footnote = isZh
        ? '输入输出比随水平提升从 ~3:2 趋近 ~1:1'
        : 'Input/output ratio trends from ~3:2 to ~1:1 as level rises';
    final sectionTitle = isZh ? '每日推荐最少练习量' : 'Daily minimum recommendation';

    final inputBg = kInputColor.withValues(alpha: isListening ? 0.08 : 0.03);
    final outputBg = kOutputColor.withValues(alpha: isListening ? 0.03 : 0.08);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          // 小节标题
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              sectionTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 表格
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(1.0),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(1.3),
            },
            children: [
              // 表头
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  _buildHeaderCell(
                    context,
                    listenHeader,
                    kInputColor,
                    muted: !isListening,
                  ),
                  _buildHeaderCell(
                    context,
                    speakHeader,
                    kOutputColor,
                    muted: isListening,
                  ),
                ],
              ),
              // 数据行
              for (var i = 0; i < levels.length; i++)
                TableRow(
                  children: [
                    // 阶段列（结构与数据列一致：Container + Column）
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            levels[i].name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            levels[i].cefr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 听力列
                    _buildDataCell(
                      context,
                      time: '${levels[i].listenMin}$minLabel',
                      words: '~${levels[i].inputWords}$wordSuffix',
                      bgColor: inputBg,
                      accentColor: kInputColor,
                      muted: !isListening,
                    ),
                    // 口语列
                    _buildDataCell(
                      context,
                      time: '${levels[i].speakMin}$minLabel',
                      words: '~${levels[i].outputWords}$wordSuffix',
                      bgColor: outputBg,
                      accentColor: kOutputColor,
                      muted: isListening,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            footnote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建表头单元格
  Widget _buildHeaderCell(
    BuildContext context,
    String text,
    Color color, {
    required bool muted,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.03 : 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: muted
              ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
              : color,
        ),
      ),
    );
  }

  /// 构建数据单元格（时长 + 词数，上下两行）
  Widget _buildDataCell(
    BuildContext context, {
    required String time,
    required String words,
    required Color bgColor,
    required Color accentColor,
    required bool muted,
  }) {
    final theme = Theme.of(context);
    final textColor = muted
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75)
        : theme.colorScheme.onSurface;
    final subColor = muted
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : accentColor.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: bgColor,
      child: Column(
        children: [
          Text(
            time,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            words,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// CEFR 等级推荐数据
class CefrLevel {
  final String cefr;
  final String name;
  final String listenMin;
  final String speakMin;
  final String inputWords;
  final String outputWords;

  const CefrLevel(
    this.cefr,
    this.name,
    this.listenMin,
    this.speakMin,
    this.inputWords,
    this.outputWords,
  );
}

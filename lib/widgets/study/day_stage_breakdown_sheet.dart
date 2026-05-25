import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/study_stage.dart';
import '../../services/study_time_service.dart';
import 'study_stats_header.dart';

/// 阶段明细弹窗的显示模式
///
/// - [total] 总览模式，显示各阶段总学习时长（默认）
/// - [input] 听力模式，仅显示各阶段听力（输入）时长
/// - [output] 口语模式，仅显示各阶段口语（输出）时长
enum StageBreakdownMode { total, input, output }

/// 某日学习阶段明细底部弹窗
///
/// 显示该日各学习阶段的听说时长分布。
/// 支持三种模式：总览 / 听力 / 口语，由 [mode] 控制。
/// 无阶段数据的历史日期显示总时长 + 提示文案。
class DayStageBreakdownSheet extends StatelessWidget {
  /// 要查看的日期
  final DateTime date;

  /// 阶段明细数据（可能为空）
  final List<DailyStageStudyRecordData> stageRecords;

  /// 当日总量数据（用于回退显示）
  final DailyTotalData? totalData;

  /// 弹窗显示模式
  final StageBreakdownMode mode;

  /// 是否显示三色图例（听/说/其它）
  final bool showLegend;

  const DayStageBreakdownSheet({
    super.key,
    required this.date,
    required this.stageRecords,
    this.totalData,
    this.mode = StageBreakdownMode.total,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isZh = l10n.localeName == 'zh';

    // 按 mode 过滤掉对应维度时长为 0 的阶段
    final nonZero = stageRecords.where((r) {
      return switch (mode) {
        StageBreakdownMode.total => r.studyTimeSeconds > 0,
        StageBreakdownMode.input => r.inputTimeSeconds > 0,
        StageBreakdownMode.output => r.outputTimeSeconds > 0,
      };
    }).toList();

    // 标题
    final title = _buildTitle(isZh);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示条
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 标题行
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // 总览模式显示三色图例（可通过 showLegend 关闭）
            if (mode == StageBreakdownMode.total && showLegend) ...[
              const SizedBox(height: 8),
              _ChartLegend(l10n: l10n, theme: theme),
            ],
            const SizedBox(height: 16),
            // 内容
            if (nonZero.isEmpty)
              _buildNoStageDataFallback(context, l10n, theme)
            else ...[
              ...nonZero.map((r) => _StageRow(record: r, mode: mode)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildTotalRow(context),
            ],
            // 听/说模式下追加 CEFR 推荐表格
            if (mode != StageBreakdownMode.total) ...[
              const SizedBox(height: 20),
              CefrRecommendationTable(
                highlightColumn: mode == StageBreakdownMode.input
                    ? HighlightColumn.listening
                    : HighlightColumn.speaking,
                isZh: isZh,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建标题文本
  ///
  /// 总览模式显示日期 + 星期 +（今天），听/说模式显示维度名称。
  String _buildTitle(bool isZh) {
    final isToday = _isToday(date);

    if (mode == StageBreakdownMode.input) {
      return isZh ? '听力详情' : 'Listening Details';
    }
    if (mode == StageBreakdownMode.output) {
      return isZh ? '口语详情' : 'Speaking Details';
    }

    // 总览模式：日期 + 星期
    final weekday = isZh
        ? _weekdayChinese(date.weekday)
        : _weekdayEnglish(date.weekday);
    final dateStr = isZh
        ? '${date.month}月${date.day}日 $weekday'
        : '${_monthEnglish(date.month)} ${date.day} $weekday';
    return '$dateStr${isToday ? (isZh ? '（今天）' : ' (Today)') : ''}';
  }

  /// 无阶段数据时的回退显示
  Widget _buildNoStageDataFallback(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final total = totalData;
    if (total == null || total.studyTimeSeconds <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.stageBreakdownNoRecord,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final seconds = switch (mode) {
      StageBreakdownMode.total => total.studyTimeSeconds,
      StageBreakdownMode.input => total.inputTimeSeconds,
      StageBreakdownMode.output => total.outputTimeSeconds,
    };
    if (seconds <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          _formatDuration(seconds, l10n),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.stageBreakdownNoStageData,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 底部合计行
  ///
  /// 使用总量表（daily_study_records）数据，与今日卡片保持一致。
  /// 根据 mode 显示对应维度的合计时长。
  Widget _buildTotalRow(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final total = totalData;
    if (total == null) return const SizedBox.shrink();

    final totalStudy = total.studyTimeSeconds;
    // clamp 逻辑与今日卡片一致，防止脏数据导致不一致
    final clampedInput = total.inputTimeSeconds.clamp(0, totalStudy);
    final clampedOutput = total.outputTimeSeconds.clamp(0, totalStudy);

    // 根据 mode 决定合计行显示的主数值
    final mainSeconds = switch (mode) {
      StageBreakdownMode.total => totalStudy,
      StageBreakdownMode.input => clampedInput,
      StageBreakdownMode.output => clampedOutput,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.functions, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.stageBreakdownTotal,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(mainSeconds, l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 总览模式下显示听/说副行
              if (mode == StageBreakdownMode.total &&
                  (clampedInput > 0 || clampedOutput > 0))
                Text(
                  _buildInputOutputText(clampedInput, clampedOutput, l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _weekdayChinese(int wd) => switch (wd) {
    1 => '周一',
    2 => '周二',
    3 => '周三',
    4 => '周四',
    5 => '周五',
    6 => '周六',
    7 => '周日',
    _ => '',
  };

  String _weekdayEnglish(int wd) => switch (wd) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => '',
  };

  String _monthEnglish(int m) => switch (m) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => '',
  };
}

/// 阶段列表中单行
///
/// 根据 [mode] 显示不同维度的时长：
/// - total：主数值为总学习时长，副行显示听/说拆分
/// - input：主数值为听力时长，无副行
/// - output：主数值为口语时长，无副行
class _StageRow extends StatelessWidget {
  final DailyStageStudyRecordData record;
  final StageBreakdownMode mode;

  const _StageRow({required this.record, this.mode = StageBreakdownMode.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final icon = _stageIcon(record.stage);
    final name = _stageName(record.stage, l10n);

    // clamp 输入/输出，确保 听+说 ≤ 该阶段总时长
    final total = record.studyTimeSeconds;
    final clampedInput = record.inputTimeSeconds.clamp(0, total);
    final clampedOutput = record.outputTimeSeconds.clamp(0, total);

    // 根据 mode 决定主数值
    final mainSeconds = switch (mode) {
      StageBreakdownMode.total => total,
      StageBreakdownMode.input => clampedInput,
      StageBreakdownMode.output => clampedOutput,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyMedium),
                // 总览模式下显示听/说副行
                if (mode == StageBreakdownMode.total &&
                    (clampedInput > 0 || clampedOutput > 0))
                  Text(
                    _buildInputOutputText(clampedInput, clampedOutput, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatDuration(mainSeconds, l10n),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阶段对应的 Material 图标
IconData _stageIcon(StudyStage stage) => switch (stage) {
  StudyStage.blindListen => Icons.headphones,
  StudyStage.intensiveListen => Icons.hearing,
  StudyStage.listenAndRepeat => Icons.record_voice_over,
  StudyStage.retell => Icons.chat_bubble_outline,
  StudyStage.reviewDifficultPractice => Icons.fitness_center,
  StudyStage.bookmarkReview => Icons.bookmark,
  StudyStage.flashcard => Icons.style,
};

/// 阶段对应的 i18n 名称
String _stageName(StudyStage stage, AppLocalizations l10n) => switch (stage) {
  StudyStage.blindListen => l10n.stageBlindListen,
  StudyStage.intensiveListen => l10n.stageIntensiveListen,
  StudyStage.listenAndRepeat => l10n.stageListenAndRepeat,
  StudyStage.retell => l10n.stageRetell,
  StudyStage.reviewDifficultPractice => l10n.stageReviewDifficultPractice,
  StudyStage.bookmarkReview => l10n.stageBookmarkReview,
  StudyStage.flashcard => l10n.stageFlashcard,
};

/// 格式化时长显示
///
/// < 60s → "<1分" / "<1m"
/// ≥ 60s → "X分" / "Xm"
/// ≥ 3600s → "Xh Ym"
String _formatDuration(int seconds, AppLocalizations l10n) {
  if (seconds <= 0) return l10n.stageBreakdownLessThanOneMin;
  if (seconds < 60) return l10n.stageBreakdownLessThanOneMin;
  final totalMin = (seconds / 60).ceil();
  if (totalMin < 60) {
    return l10n.localeName == 'zh' ? '$totalMin分' : '${totalMin}m';
  }
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (m == 0) return '${h}h';
  return l10n.localeName == 'zh' ? '${h}h $m分' : '${h}h ${m}m';
}

/// 构建 "听 Xm · 说 Ym" 文本
String _buildInputOutputText(
  int inputSeconds,
  int outputSeconds,
  AppLocalizations l10n,
) {
  final parts = <String>[];
  final listenLabel = l10n.stageBreakdownListenShort;
  final speakLabel = l10n.stageBreakdownSpeakShort;
  if (inputSeconds > 0) {
    parts.add('$listenLabel ${_formatDuration(inputSeconds, l10n)}');
  }
  if (outputSeconds > 0) {
    parts.add('$speakLabel ${_formatDuration(outputSeconds, l10n)}');
  }
  return parts.join(' · ');
}

/// 显示某日学习阶段明细底部弹窗
///
/// [date] 要查看的日期。
/// [studyTimeService] 用于加载阶段明细和总量数据。
/// [mode] 弹窗显示模式（总览/听力/口语），默认总览。
Future<void> showDayStageBreakdownSheet({
  required BuildContext context,
  required DateTime date,
  required StudyTimeService studyTimeService,
  StageBreakdownMode mode = StageBreakdownMode.total,
  bool showLegend = true,
}) async {
  // 并行加载阶段明细和总量
  final results = await Future.wait([
    studyTimeService.getStageBreakdown(date),
    studyTimeService.getDayTotal(date),
  ]);
  final stageRecords = results[0] as List<DailyStageStudyRecordData>;
  final totalData = results[1] as DailyTotalData?;

  if (!context.mounted) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DayStageBreakdownSheet(
      date: date,
      stageRecords: stageRecords,
      totalData: totalData,
      mode: mode,
      showLegend: showLegend,
    ),
  );
}

/// 柱状图三色图例（听/说/其它）
class _ChartLegend extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _ChartLegend({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(kInputColor, l10n.chartLegendListening),
        const SizedBox(width: 16),
        _legendDot(kOutputColor, l10n.chartLegendSpeaking),
        const SizedBox(width: 16),
        _legendDot(
          kOtherColor,
          '${l10n.chartLegendOther} (${l10n.chartLegendOtherHint})',
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

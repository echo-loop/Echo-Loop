import 'package:flutter/material.dart';

import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../models/difficult_practice_settings.dart';
import '../../theme/app_theme.dart';

/// 复习步骤提示弹窗。
///
/// 交互与首次学习保持一致：先展示当前步骤说明，再点击“开始练习”进入页面。
/// [defaultPlaybackSpeed] 默认播放速度（按难度+轮次映射），用户可在弹窗里改。
/// [onStartPractice] 点击"开始练习"时回调，参数为用户最终选定的速度
///   以及句间停顿倍数（-1.0 = 自动/smart，>0 = multiplier 模式）。
///   句间停顿下拉仅在 [SubStageType.reviewDifficultPractice] 子步骤显示，
///   其余子步骤回调 pauseMultiplier 固定为 -1.0。
Future<void> showReviewBriefingSheet({
  required BuildContext context,
  required LearningStage stage,
  required SubStageType subStage,
  Duration? estimatedDuration,
  double defaultPlaybackSpeed = 1.0,
  required void Function(double playbackSpeed, double pauseMultiplier)
  onStartPractice,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ReviewBriefingSheet(
      stage: stage,
      subStage: subStage,
      estimatedDuration: estimatedDuration,
      defaultPlaybackSpeed: defaultPlaybackSpeed,
      onStartPractice: onStartPractice,
    ),
  );
}

/// 句间停顿下拉选项：-1.0 = 自动（smart 模式），其余为段长倍数。
const List<double> _kPauseMultiplierOptions = [-1.0, 1.0, 2.0, 3.0, 4.0, 5.0];

class _ReviewBriefingSheet extends StatefulWidget {
  final LearningStage stage;
  final SubStageType subStage;
  final Duration? estimatedDuration;
  final double defaultPlaybackSpeed;
  final void Function(double playbackSpeed, double pauseMultiplier)
  onStartPractice;

  const _ReviewBriefingSheet({
    required this.stage,
    required this.subStage,
    this.estimatedDuration,
    required this.defaultPlaybackSpeed,
    required this.onStartPractice,
  });

  @override
  State<_ReviewBriefingSheet> createState() => _ReviewBriefingSheetState();
}

class _ReviewBriefingSheetState extends State<_ReviewBriefingSheet> {
  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  double _pauseMultiplier = -1.0;

  /// 格式化预估时长
  String _formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
    return formatEstimatedDuration(l10n, duration);
  }

  /// 统一显示速度标签：整数速度显示为 1x，0.05 步进保留必要小数。
  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
    if ((speed * 10).roundToDouble() == speed * 10) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed.toStringAsFixed(2)}x';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Icon(
            _iconForSubStage(widget.subStage),
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            _titleForSubStage(l10n, isZh, widget.subStage),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reviewStageLabel(l10n, widget.stage),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    _tipForSubStage(isZh, widget.subStage),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          // 句间停顿（仅难句补练子步骤显示）
          if (widget.subStage == SubStageType.reviewDifficultPractice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.intensiveListenPauseLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: DropdownButton<double>(
                    value: _pauseMultiplier,
                    isExpanded: true,
                    isDense: true,
                    elevation: 0,
                    underline: const SizedBox.shrink(),
                    items: _kPauseMultiplierOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value < 0
                                  ? l10n.intensiveListenPauseSmart
                                  : '${value.toInt()}x',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _pauseMultiplier = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          // 播放速度（与盲听/复述对齐）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.playbackSpeed,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                width: 80,
                child: DropdownButton<double>(
                  value: _playbackSpeed,
                  isExpanded: true,
                  isDense: true,
                  elevation: 0,
                  underline: const SizedBox.shrink(),
                  items: DifficultPracticeSettings.briefingPlaybackSpeedOptions
                      .map(
                        (speed) => DropdownMenuItem(
                          value: speed,
                          child: Text(_formatSpeed(speed)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _playbackSpeed = v);
                  },
                ),
              ),
            ],
          ),
          if (widget.estimatedDuration != null) ...[
            const SizedBox(height: AppSpacing.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatEstimatedDuration(l10n, widget.estimatedDuration!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onStartPractice(_playbackSpeed, _pauseMultiplier);
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.startPractice),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForSubStage(SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen => Icons.headphones,
    SubStageType.reviewDifficultPractice => Icons.hearing,
    SubStageType.reviewRetellParagraph => Icons.notes,
    SubStageType.reviewRetellSummary => Icons.summarize,
    SubStageType.intensiveListen => Icons.hearing,
    SubStageType.listenAndRepeat => Icons.record_voice_over,
    SubStageType.retell => Icons.chat,
  };
}

String _titleForSubStage(
  AppLocalizations l10n,
  bool isZh,
  SubStageType subStage,
) {
  return switch (subStage) {
    SubStageType.blindListen => l10n.stepBlindListening,
    SubStageType.reviewDifficultPractice =>
      isZh ? '难句补练' : 'Difficult Sentence Practice',
    SubStageType.reviewRetellParagraph => isZh ? '段落复述' : 'Paragraph Retelling',
    SubStageType.reviewRetellSummary => isZh ? '全文复述' : 'Full Text Retelling',
    SubStageType.intensiveListen => l10n.stepIntensiveListening,
    SubStageType.listenAndRepeat => l10n.stepShadowing,
    SubStageType.retell => l10n.stepRetelling,
  };
}

String _tipForSubStage(bool isZh, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.blindListen =>
      isZh
          ? '全文盲听一遍，不看字幕先听大意。'
          : 'Listen once without subtitles and focus on the gist.',
    SubStageType.reviewDifficultPractice =>
      isZh
          ? '先盲听难句，听不懂再跟读加练。'
          : 'Blind listen difficult sentences first, then do remedial practice.',
    SubStageType.reviewRetellParagraph =>
      isZh ? '按段复述本轮复习内容。' : 'Retell this review round paragraph by paragraph.',
    SubStageType.reviewRetellSummary =>
      isZh ? '用 3-5 句话总结全文大意。' : 'Summarize the full audio in 3-5 sentences.',
    SubStageType.intensiveListen =>
      isZh
          ? '逐句精听并处理听不懂的内容。'
          : 'Work sentence by sentence and resolve difficult parts.',
    SubStageType.listenAndRepeat =>
      isZh ? '针对关键句进行跟读巩固。' : 'Shadow key sentences for reinforcement.',
    SubStageType.retell =>
      isZh ? '按段复述主要内容。' : 'Retell the main points by paragraph.',
  };
}

/// 格式化预估时长为本地化文本（如"预计 3 分钟"）
String formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
  final minutes = (duration.inSeconds / 60).ceil();
  if (minutes < 1) return l10n.estimatedLessThanOneMinute;
  return l10n.estimatedMinutes(minutes);
}

/// 返回学习阶段的本地化标签文本（如"第三轮复习"）
String reviewStageLabel(AppLocalizations l10n, LearningStage stage) {
  return switch (stage) {
    LearningStage.firstLearn => l10n.firstStudy,
    LearningStage.review0 => l10n.reviewRound0,
    LearningStage.review1 => l10n.reviewRound1,
    LearningStage.review2 => l10n.reviewRound2,
    LearningStage.review4 => l10n.reviewRound4,
    LearningStage.review7 => l10n.reviewRound7,
    LearningStage.review14 => l10n.reviewRound14,
    LearningStage.review28 => l10n.reviewRound28,
    LearningStage.completed => l10n.learningCompleted,
  };
}

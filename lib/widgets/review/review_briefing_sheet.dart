import 'package:flutter/material.dart';

import '../common/app_dropdown.dart';
import '../common/pause_choice_dropdown.dart';
import '../common/setting_labeled_row.dart';

import '../../database/enums.dart';
import '../../l10n/app_localizations.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/intensive_listen_settings.dart'
    show IntensiveListenSettings;
import '../../models/study_stage.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;
import '../../theme/app_theme.dart';
import '../../utils/playback_speed.dart';
import '../common/briefing_action_row.dart';
import '../common/learning_briefing_sheet_content.dart';
import '../study/study_stage_visuals.dart';

/// 复习步骤提示弹窗。
///
/// 交互与首次学习保持一致：先展示当前步骤说明，再点击“开始练习”进入页面。
/// [defaultPlaybackSpeed] 默认播放速度（按难度+轮次映射），用户可在弹窗里改。
/// [defaultPause] 默认句间停顿(自动/固定间隔/句长倍数)，用于回显已记忆值。
/// [onStartPractice] 点击"开始练习"时回调，参数为用户最终选定的速度 + 句间停顿。
///   句间停顿下拉仅在 [SubStageType.reviewDifficultPractice] 子步骤显示，
///   其余子步骤回调停顿固定为自动。
/// [onSkip] 可选，提供时在"开始练习"左侧显示「跳过」按钮，点击直接跳过当前任务。
Future<void> showReviewBriefingSheet({
  required BuildContext context,
  required LearningStage stage,
  required SubStageType subStage,
  Duration? estimatedDuration,
  double defaultPlaybackSpeed = 1.0,
  BriefingPauseChoice defaultPause = const BriefingPauseChoice.smart(),
  required void Function(double playbackSpeed, BriefingPauseChoice pause)
  onStartPractice,
  void Function(double playbackSpeed, BriefingPauseChoice pause)?
  onSelectionChanged,
  VoidCallback? onSkip,
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
      defaultPause: defaultPause,
      onStartPractice: onStartPractice,
      onSelectionChanged: onSelectionChanged,
      onSkip: onSkip,
    ),
  );
}

class _ReviewBriefingSheet extends StatefulWidget {
  final LearningStage stage;
  final SubStageType subStage;
  final Duration? estimatedDuration;
  final double defaultPlaybackSpeed;
  final BriefingPauseChoice defaultPause;
  final void Function(double playbackSpeed, BriefingPauseChoice pause)
  onStartPractice;
  final void Function(double playbackSpeed, BriefingPauseChoice pause)?
  onSelectionChanged;
  final VoidCallback? onSkip;

  const _ReviewBriefingSheet({
    required this.stage,
    required this.subStage,
    this.estimatedDuration,
    required this.defaultPlaybackSpeed,
    this.defaultPause = const BriefingPauseChoice.smart(),
    required this.onStartPractice,
    this.onSelectionChanged,
    this.onSkip,
  });

  @override
  State<_ReviewBriefingSheet> createState() => _ReviewBriefingSheetState();
}

class _ReviewBriefingSheetState extends State<_ReviewBriefingSheet> {
  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  late BriefingPauseChoice _pause = widget.defaultPause;

  /// 格式化预估时长
  String _formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
    return formatEstimatedDuration(l10n, duration);
  }

  /// 统一显示速度标签：始终保留一位小数。
  String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stageVisual = switch (widget.subStage) {
      SubStageType.reviewDifficultPractice => studyStageVisual(
        StudyStage.reviewDifficultPractice,
        l10n,
      ),
      SubStageType.reviewRetellSummary => studyRetellSummaryVisual(l10n),
      _ => _unsupportedSubStage(widget.subStage),
    };

    return LearningBriefingSheetContent(
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
            stageVisual.icon,
            size: 56,
            color: stageVisual.iconColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            _titleForSubStage(l10n, widget.subStage),
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
                    _tipForSubStage(l10n, widget.subStage),
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
            SettingLabeledRow(
              label: Text(
                l10n.intensiveListenPauseLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: PauseChoiceDropdown(
                value: _pause,
                fixedOptions: IntensiveListenSettings.fixedPauseOptions,
                multiplierOptions: IntensiveListenSettings.multiplierOptions,
                onChanged: (v) {
                  setState(() => _pause = v);
                  widget.onSelectionChanged?.call(_playbackSpeed, _pause);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.m),
          ],
          // 播放速度（与盲听/复述对齐）
          SettingLabeledRow(
            label: Text(
              l10n.playbackSpeed,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: AppDropdown<double>(
              value: _playbackSpeed,
              isDense: true,
              alignment: AlignmentDirectional.centerEnd,
              items: DifficultPracticeSettings.briefingPlaybackSpeedOptions
                  .map(
                    (speed) => DropdownMenuItem(
                      value: speed,
                      child: Text(_formatSpeed(speed)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _playbackSpeed = v);
                  widget.onSelectionChanged?.call(_playbackSpeed, _pause);
                }
              },
            ),
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
          BriefingActionRow(
            startLabel: l10n.startPractice,
            onStart: () {
              Navigator.of(context).pop();
              widget.onStartPractice(_playbackSpeed, _pause);
            },
            skipLabel: widget.onSkip != null ? l10n.retellSkip : null,
            onSkip: widget.onSkip == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onSkip!();
                  },
          ),
        ],
      ),
    );
  }
}

/// 本弹窗只会以 [SubStageType.reviewDifficultPractice] 或
/// [SubStageType.reviewRetellSummary] 展示——盲听、段落复述、以及首次学习的
/// 三个子步骤都各自走独立的简报弹窗（见 [showReviewBriefingSheet] 调用方
/// `learning_plan_screen.dart` 的 `_startReviewSubStage`），不会传入这里。
Never _unsupportedSubStage(SubStageType subStage) =>
    throw ArgumentError('复习简报弹窗不支持子步骤 $subStage');

String _titleForSubStage(AppLocalizations l10n, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
    SubStageType.reviewRetellSummary => l10n.stepFullTextRetelling,
    _ => _unsupportedSubStage(subStage),
  };
}

String _tipForSubStage(AppLocalizations l10n, SubStageType subStage) {
  return switch (subStage) {
    SubStageType.reviewDifficultPractice =>
      l10n.reviewBriefingTipDifficultPractice,
    SubStageType.reviewRetellSummary => l10n.reviewBriefingTipRetellSummary,
    _ => _unsupportedSubStage(subStage),
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

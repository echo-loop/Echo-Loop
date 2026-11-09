/// 精听简报底部弹窗
///
/// 进入精听前显示，告知用户句子总数和操作提示，
/// 同时让用户在弹窗里选择本次会话的初始播放速度（与盲听/复述/跟读对齐）。
library;

import 'package:flutter/material.dart';

import '../common/app_dropdown.dart';
import '../common/pause_choice_dropdown.dart';
import '../common/setting_labeled_row.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/study_stage.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;
import '../../theme/app_theme.dart';
import '../../utils/playback_speed.dart';
import '../common/briefing_action_row.dart';
import '../common/learning_briefing_sheet_content.dart';
import '../study/study_stage_visuals.dart';

/// 显示精听简报底部弹窗
///
/// [defaultPlaybackSpeed] 默认播放速度（默认 1.0），用户可在弹窗里改。
/// [defaultPause] 默认句间停顿(自动/固定间隔/句长倍数)，用于回显已记忆值。
/// [onStartPractice] 点击"开始练习"时回调，参数为用户最终选定的速度 + 句间停顿。
/// [onSkip] 可选，提供时在"开始练习"左侧显示「跳过」按钮，点击直接跳过当前任务。
Future<void> showIntensiveListenBriefingSheet({
  required BuildContext context,
  required int sentenceCount,
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
    builder: (context) => IntensiveListenBriefingSheet(
      sentenceCount: sentenceCount,
      estimatedDuration: estimatedDuration,
      defaultPlaybackSpeed: defaultPlaybackSpeed,
      defaultPause: defaultPause,
      onStartPractice: onStartPractice,
      onSelectionChanged: onSelectionChanged,
      onSkip: onSkip,
    ),
  );
}

class IntensiveListenBriefingSheet extends StatefulWidget {
  /// 句子总数
  final int sentenceCount;

  /// 预估练习时长
  final Duration? estimatedDuration;

  /// 默认播放速度
  final double defaultPlaybackSpeed;

  /// 默认句间停顿(自动/固定间隔/句长倍数)。用于回显已记忆值。
  final BriefingPauseChoice defaultPause;

  /// 开始练习回调（带回最终选定的速度 + 句间停顿）
  final void Function(double playbackSpeed, BriefingPauseChoice pause)
  onStartPractice;

  /// 用户改动速度/停顿时即时回调(带回当前完整选择),供调用方即时持久化——
  /// 与播放器内 🔧 面板一致:改完即记,不必等「开始练习」。
  final void Function(double playbackSpeed, BriefingPauseChoice pause)?
  onSelectionChanged;

  /// 跳过当前任务回调，提供时显示「跳过」按钮
  final VoidCallback? onSkip;

  const IntensiveListenBriefingSheet({
    super.key,
    required this.sentenceCount,
    this.estimatedDuration,
    this.defaultPlaybackSpeed = 1.0,
    this.defaultPause = const BriefingPauseChoice.smart(),
    required this.onStartPractice,
    this.onSelectionChanged,
    this.onSkip,
  });

  @override
  State<IntensiveListenBriefingSheet> createState() =>
      _IntensiveListenBriefingSheetState();
}

class _IntensiveListenBriefingSheetState
    extends State<IntensiveListenBriefingSheet> {
  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  late BriefingPauseChoice _pause = widget.defaultPause;

  /// 格式化预估时长
  String _formatEstimatedDuration(AppLocalizations l10n, Duration duration) {
    final minutes = (duration.inSeconds / 60).ceil();
    if (minutes < 1) return l10n.estimatedLessThanOneMinute;
    return l10n.estimatedMinutes(minutes);
  }

  /// 统一显示速度标签：始终保留一位小数。
  String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visual = studyStageVisual(StudyStage.intensiveListen, l10n);

    return LearningBriefingSheetContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示条
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 与学习任务列表共用阶段图标和颜色。
          Icon(
            visual.icon,
            size: 56,
            color: visual.iconColor ?? theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.m),

          // 标题
          Text(
            l10n.intensiveListenBriefingTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          // 练习提示
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
                    l10n.intensiveListenBriefingTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 句间停顿（分组:自动 / 固定间隔 / 句长倍数,与 🔧 面板一致）
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
                widget.onSelectionChanged?.call(_playbackSpeed, v);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 播放速度（与盲听/复述/跟读对齐）
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
              items: IntensiveListenSettings.briefingPlaybackSpeedOptions
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
                  widget.onSelectionChanged?.call(v, _pause);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 句子总数 + 预估时长
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.intensiveListenBriefingSentenceCount(widget.sentenceCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.estimatedDuration != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                  child: Text(
                    '·',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
            ],
          ),
          const SizedBox(height: AppSpacing.l),

          // 开始练习按钮（+ 可选跳过）
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

/// 跟读简报底部弹窗
///
/// 进入跟读前显示，告知用户难句数量、每句遍数和操作提示，
/// 同时让用户在弹窗里选择本次会话的初始播放速度（与盲听/复述对齐）。
library;

import 'package:flutter/material.dart';
import '../common/app_dropdown.dart';
import '../common/pause_choice_dropdown.dart';
import '../common/setting_labeled_row.dart';
import '../../l10n/app_localizations.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/intensive_listen_prefs.dart' show ListenAndRepeatScope;
import '../../models/study_stage.dart';
import '../../models/stage_settings_overrides.dart' show BriefingPauseChoice;
import '../../theme/app_theme.dart';
import '../../utils/playback_speed.dart';
import '../common/briefing_action_row.dart';
import '../common/learning_briefing_sheet_content.dart';
import '../study/study_stage_visuals.dart';

/// 显示跟读简报底部弹窗
///
/// [defaultPlaybackSpeed] 默认播放速度（按难度+轮次映射），用户可在弹窗里改。
/// [defaultPause] 默认句间停顿(自动/固定间隔/句长倍数)，用于回显已记忆值。
/// [onStartPractice] 点击"开始练习"时回调，参数为用户最终选定的速度 + 句间停顿。
/// [onSkip] 可选，提供时在"开始练习"左侧显示「跳过」按钮，点击直接跳过当前任务。
Future<void> showListenAndRepeatBriefingSheet({
  required BuildContext context,
  required int difficultCount,
  required int fullTextCount,
  required int playCount,
  required Duration? difficultEstimatedDuration,
  required Duration? fullTextEstimatedDuration,
  ListenAndRepeatScope defaultScope = ListenAndRepeatScope.difficultOnly,
  double defaultPlaybackSpeed = 1.0,
  BriefingPauseChoice defaultPause = const BriefingPauseChoice.smart(),
  required void Function(
    double playbackSpeed,
    BriefingPauseChoice pause,
    ListenAndRepeatScope scope,
  )
  onStartPractice,
  void Function(double playbackSpeed, BriefingPauseChoice pause)?
  onSelectionChanged,
  void Function(ListenAndRepeatScope scope)? onScopeChanged,
  VoidCallback? onSkip,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ListenAndRepeatBriefingSheet(
      difficultCount: difficultCount,
      fullTextCount: fullTextCount,
      playCount: playCount,
      difficultEstimatedDuration: difficultEstimatedDuration,
      fullTextEstimatedDuration: fullTextEstimatedDuration,
      defaultScope: defaultScope,
      defaultPlaybackSpeed: defaultPlaybackSpeed,
      defaultPause: defaultPause,
      onStartPractice: onStartPractice,
      onSelectionChanged: onSelectionChanged,
      onScopeChanged: onScopeChanged,
      onSkip: onSkip,
    ),
  );
}

class ListenAndRepeatBriefingSheet extends StatefulWidget {
  /// 难句总数
  final int difficultCount;

  /// 全文句子总数。
  final int fullTextCount;

  /// 每句播放遍数
  final int playCount;

  /// 预估练习时长
  final Duration? difficultEstimatedDuration;

  /// 全文范围下的预估练习时长。
  final Duration? fullTextEstimatedDuration;

  /// 已记忆的入口跟读范围。
  final ListenAndRepeatScope defaultScope;

  /// 默认播放速度
  final double defaultPlaybackSpeed;

  /// 默认句间停顿(自动/固定间隔/句长倍数)。用于回显已记忆值。
  final BriefingPauseChoice defaultPause;

  /// 开始练习回调（带回最终选定的速度 + 句间停顿）
  final void Function(
    double playbackSpeed,
    BriefingPauseChoice pause,
    ListenAndRepeatScope scope,
  )
  onStartPractice;

  /// 用户改动速度/停顿时即时回调(改完即记,与 🔧 面板一致,不必等「开始练习」)。
  final void Function(double playbackSpeed, BriefingPauseChoice pause)?
  onSelectionChanged;

  /// 用户切换范围时立即回调，用于持久化范围和清理当前入口断点。
  final void Function(ListenAndRepeatScope scope)? onScopeChanged;

  /// 跳过当前任务回调，提供时显示「跳过」按钮
  final VoidCallback? onSkip;

  const ListenAndRepeatBriefingSheet({
    super.key,
    required this.difficultCount,
    required this.fullTextCount,
    required this.playCount,
    this.difficultEstimatedDuration,
    this.fullTextEstimatedDuration,
    this.defaultScope = ListenAndRepeatScope.difficultOnly,
    this.defaultPlaybackSpeed = 1.0,
    this.defaultPause = const BriefingPauseChoice.smart(),
    required this.onStartPractice,
    this.onSelectionChanged,
    this.onScopeChanged,
    this.onSkip,
  });

  @override
  State<ListenAndRepeatBriefingSheet> createState() =>
      _ListenAndRepeatBriefingSheetState();
}

class _ListenAndRepeatBriefingSheetState
    extends State<ListenAndRepeatBriefingSheet> {
  late double _playbackSpeed = widget.defaultPlaybackSpeed;
  late BriefingPauseChoice _pause = widget.defaultPause;
  late ListenAndRepeatScope _scope = widget.defaultScope;

  int get _selectedSentenceCount => switch (_scope) {
    ListenAndRepeatScope.fullText => widget.fullTextCount,
    ListenAndRepeatScope.difficultOnly => widget.difficultCount,
  };

  Duration? get _selectedEstimatedDuration => switch (_scope) {
    ListenAndRepeatScope.fullText => widget.fullTextEstimatedDuration,
    ListenAndRepeatScope.difficultOnly => widget.difficultEstimatedDuration,
  };

  String _selectedSentenceCountLabel(AppLocalizations l10n) => switch (_scope) {
    ListenAndRepeatScope.fullText => l10n.listenAndRepeatBriefingSentenceCount(
      _selectedSentenceCount,
    ),
    ListenAndRepeatScope.difficultOnly =>
      l10n.listenAndRepeatBriefingDifficultCount(_selectedSentenceCount),
  };

  /// 仅收藏范围没有内容时，明确禁用开始操作；全文范围仍可正常练习。
  bool get _canStartPractice =>
      _scope == ListenAndRepeatScope.fullText || widget.difficultCount > 0;

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
    final visual = studyStageVisual(StudyStage.listenAndRepeat, l10n);

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
            l10n.listenAndRepeatBriefingTitle,
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
                    l10n.listenAndRepeatBriefingTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // 跟读范围只在入口选择，不进入任务内设置面板。
          // 与下方的句间停顿、播放速度复用相同的设置行和下拉框样式。
          SettingLabeledRow(
            trailingWidth: null,
            label: Text(
              l10n.listenAndRepeatScopeLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: AppDropdown<ListenAndRepeatScope>(
              value: _scope,
              isDense: true,
              alignment: AlignmentDirectional.center,
              items: [
                DropdownMenuItem(
                  value: ListenAndRepeatScope.fullText,
                  child: Center(child: Text(l10n.listenAndRepeatScopeFullText)),
                ),
                DropdownMenuItem(
                  value: ListenAndRepeatScope.difficultOnly,
                  child: Center(
                    child: Text(l10n.listenAndRepeatScopeDifficultOnly),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null || value == _scope) return;
                setState(() => _scope = value);
                widget.onScopeChanged?.call(value);
              },
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
              isExpanded: true,
              isDense: true,
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

          // 难句数量 + 遍数 + 预估时长
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _selectedSentenceCountLabel(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Text(
                  '·',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                widget.playCount == 0
                    ? l10n.infiniteRepeat
                    : l10n.listenAndRepeatBriefingPlayCount(widget.playCount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedEstimatedDuration != null) ...[
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
                  _formatEstimatedDuration(l10n, _selectedEstimatedDuration!),
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
            startLabel: _canStartPractice
                ? l10n.startPractice
                : l10n.listenAndRepeatNoSavedSentencesNoNeed,
            isStartEnabled: _canStartPractice,
            onStart: () {
              Navigator.of(context).pop();
              widget.onStartPractice(_playbackSpeed, _pause, _scope);
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

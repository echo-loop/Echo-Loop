// 学习进度条
//
// 合集详情页素材列表项的学习进度：左侧为进度条，右侧为「未学习 / 进度百分比 / 已完成」。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/learning_progress.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../theme/app_theme.dart';

/// 学习进度条
///
/// - 未学习：空进度条 + 「未学习」
/// - 学习中：蓝色进度条 + 百分比；暂停时进度条与百分比统一灰化
/// - 已完成：满条绿色 + 「已完成」
class LearningProgressBar extends ConsumerWidget {
  /// 学习进度数据，为 null 表示未学习
  final LearningProgress? progress;

  const LearningProgressBar({super.key, required this.progress});

  static const double _kLabelWidth = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final current = progress;
    // 有进度时按音频派生计划与已完成的步骤。
    final plan = current == null
        ? ref.watch(learningPlanProvider)
        : ref.watch(learningPlanForAudioProvider(current.audioItemId));
    final completedKeys = current == null
        ? const <String>{}
        : ref
              .watch(learningProgressProvider)
              .completionsFor(current.audioItemId);

    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final barColor = learningProgressColor(theme, current);

    if (current == null || !current.isStarted) {
      return _buildBar(
        theme,
        value: 0,
        barColor: barColor,
        label: l10n.learningNotStarted,
        labelColor: mutedColor,
      );
    }
    if (current.isCompleted) {
      return _buildBar(
        theme,
        value: 1,
        barColor: barColor,
        label: l10n.learningCompleted,
        labelColor: AppTheme.learningCompletedColor,
      );
    }
    final value = current.progressPercent(plan, completedKeys);
    return _buildBar(
      theme,
      value: value,
      barColor: barColor,
      label: '${(value * 100).round()}%',
      labelColor: mutedColor,
    );
  }

  Widget _buildBar(
    ThemeData theme, {
    required double value,
    required Color barColor,
    required String label,
    required Color labelColor,
  }) {
    return Row(
      key: const Key('learning_progress_bar'),
      children: [
        Expanded(
          child: LearningProgressTrack(value: value, color: barColor),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _kLabelWidth,
          child: Text(
            label,
            textAlign: TextAlign.end,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
          ),
        ),
      ],
    );
  }
}

/// 学习进度条轨道：高 3、圆角、轨道底色统一。合集列表项与学习页卡片共用，颜色由调用方决定。
class LearningProgressTrack extends StatelessWidget {
  /// 进度比例，取值 0 到 1。
  final double value;

  final Color color;

  const LearningProgressTrack({
    super.key,
    required this.value,
    required this.color,
  });

  static const double barHeight = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(barHeight / 2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: barHeight,
        color: color,
        backgroundColor: AppTheme.progressTrackColor(theme.brightness),
      ),
    );
  }
}

/// 学习进度条颜色：完成为绿色，学习中为蓝色，暂停时灰化。未开始的进度条不展示有效进度，取学习中色。
Color learningProgressColor(ThemeData theme, LearningProgress? progress) {
  if (progress == null || !progress.isStarted) {
    return AppTheme.learningInProgressColor(theme.brightness);
  }
  if (progress.isCompleted) return AppTheme.learningCompletedColor;
  if (progress.isPaused) return theme.colorScheme.onSurfaceVariant;
  return AppTheme.learningInProgressColor(theme.brightness);
}

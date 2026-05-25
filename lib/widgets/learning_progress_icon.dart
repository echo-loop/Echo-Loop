/// 环形学习进度图标
///
/// 根据学习进度显示不同状态：
/// - 未学习：音频图标 + 灰色背景
/// - 进行中：环形进度 + 蓝色音频图标
/// - 已完成：满环 + 绿色对勾
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_progress.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';

/// 环形学习进度图标组件
///
/// 用于 [AudioListTile] 和学习页面 [_TaskCard] 等位置，
/// 统一展示音频的学习进度状态。
class LearningProgressIcon extends ConsumerWidget {
  /// 学习进度数据，为 null 表示未学习
  final LearningProgress? progress;

  /// 图标整体尺寸
  final double size;

  /// 中央图标尺寸
  final double iconSize;

  /// 环形进度条宽度
  final double strokeWidth;

  const LearningProgressIcon({
    super.key,
    this.progress,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.strokeWidth = 3.0,
  });

  /// 已完成状态的绿色
  static const completedColor = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // progress 缺失时（音频未开始）按全局默认 plan；有 progress 则按 audio 派生。
    final plan = progress == null
        ? ref.watch(learningPlanProvider)
        : ref.watch(learningPlanForAudioProvider(progress!.audioItemId));
    final completedKeys = progress == null
        ? const <String>{}
        : ref
              .watch(learningProgressNotifierProvider)
              .completionsFor(progress!.audioItemId);

    // 未学习状态
    if (progress == null || !progress!.isStarted) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.graphic_eq,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // 已完成状态
    if (progress!.isCompleted) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: strokeWidth,
                color: completedColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Icon(Icons.check, size: iconSize, color: completedColor),
          ],
        ),
      );
    }

    // 暂停态：保留进度比例，但环和图标整体灰化，与「已暂停」chip 视觉一致。
    if (progress!.isPaused) {
      final mutedColor = theme.colorScheme.onSurfaceVariant;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress!.progressPercent(plan, completedKeys),
                strokeWidth: strokeWidth,
                color: mutedColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Icon(Icons.pause_rounded, size: iconSize, color: mutedColor),
          ],
        ),
      );
    }

    // 进行中状态
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress!.progressPercent(plan, completedKeys),
              strokeWidth: strokeWidth,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Icon(
            Icons.graphic_eq,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

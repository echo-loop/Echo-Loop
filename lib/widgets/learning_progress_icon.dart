/// 环形学习进度图标
///
/// 根据学习进度显示不同状态：
/// - 未学习：音频图标 + 灰色背景
/// - 进行中：环形进度 + 蓝色音频图标
/// - 已完成：绿色满环 + 对应的音频或视频图标
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_progress.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import 'media_type_icon.dart';

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

  /// 是否为视频条目：为 true 时中心媒体图标用视频图标（而非音频波形）。
  final bool isVideo;

  const LearningProgressIcon({
    super.key,
    this.progress,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.strokeWidth = 3.0,
    this.isVideo = false,
  });

  /// 已完成状态的绿色。
  static const completedColor = Color(0xFF4CAF50);

  /// 构建中心媒体图标：视频使用视频图标，音频使用波形图标。
  Widget _mediaGlyph(Color color) {
    return MediaTypeIcon(isVideo: isVideo, size: iconSize, color: color);
  }

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
              .watch(learningProgressProvider)
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
        alignment: Alignment.center,
        child: _mediaGlyph(theme.colorScheme.onSurfaceVariant),
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
            // 外圈表达完成状态；中心媒体图标沿用普通任务的主色，保持媒体类型清晰。
            _mediaGlyph(theme.colorScheme.primary),
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
          _mediaGlyph(theme.colorScheme.primary),
        ],
      ),
    );
  }
}

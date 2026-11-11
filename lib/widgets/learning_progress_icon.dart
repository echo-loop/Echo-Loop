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

/// 学习进度图标组件
///
/// 用于 [AudioListTile] 和学习页面 [_TaskCard] 等位置，
/// 统一展示音频的学习进度状态。默认外形为圆形；合集详情页使用圆角方形以与封面外形保持一致。
class LearningProgressIcon extends ConsumerWidget {
  /// 学习进度数据，为 null 表示未学习
  final LearningProgress? progress;

  /// 图标整体尺寸
  final double size;

  /// 中央图标尺寸
  final double iconSize;

  /// 进度条宽度
  final double strokeWidth;

  /// 是否为视频条目：为 true 时中心媒体图标用视频图标（而非音频波形）。
  final bool isVideo;

  /// 是否使用圆角方形外形；为 false 时保持圆形。
  final bool isRoundedSquare;

  const LearningProgressIcon({
    super.key,
    this.progress,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.strokeWidth = 3.0,
    this.isVideo = false,
    this.isRoundedSquare = false,
  });

  /// 已完成状态的绿色。
  static const completedColor = Color(0xFF4CAF50);

  /// 构建中心媒体图标：视频使用视频图标，音频使用波形图标。
  Widget _mediaGlyph(Color color) {
    return MediaTypeIcon(isVideo: isVideo, size: iconSize, color: color);
  }

  /// 底色容器：圆形或圆角方形，与进度环的外形保持一致。
  BoxDecoration _backgroundDecoration(Color color) {
    return BoxDecoration(
      color: color,
      shape: isRoundedSquare ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: isRoundedSquare
          ? BorderRadius.circular(_kRoundedSquareRadius)
          : null,
    );
  }

  /// 进度环与中心图标叠放，整体尺寸固定为 [size]。
  Widget _ringStack({required Widget ring, required Widget glyph}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [ring, glyph]),
    );
  }

  /// 圆形使用 [CircularProgressIndicator]；圆角方形改用自绘路径，让进度沿方形边框前进。
  Widget _progressRing({
    required double value,
    required Color color,
    required Color trackColor,
  }) {
    if (!isRoundedSquare) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: strokeWidth,
          color: color,
          backgroundColor: trackColor,
        ),
      );
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _RoundedSquareRingPainter(
        value: value,
        color: color,
        trackColor: trackColor,
        strokeWidth: strokeWidth,
      ),
    );
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
        decoration: _backgroundDecoration(
          theme.colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: _mediaGlyph(theme.colorScheme.onSurfaceVariant),
      );
    }

    final trackColor = theme.colorScheme.surfaceContainerHighest;

    // 已完成状态：外圈表达完成；中心媒体图标沿用普通任务的主色，保持媒体类型清晰。
    if (progress!.isCompleted) {
      return _ringStack(
        ring: _progressRing(
          value: 1.0,
          color: completedColor,
          trackColor: trackColor,
        ),
        glyph: _mediaGlyph(theme.colorScheme.primary),
      );
    }

    // 暂停态：保留进度比例，但环和图标整体灰化，与「已暂停」chip 视觉一致。
    if (progress!.isPaused) {
      final mutedColor = theme.colorScheme.onSurfaceVariant;
      return _ringStack(
        ring: _progressRing(
          value: progress!.progressPercent(plan, completedKeys),
          color: mutedColor,
          trackColor: trackColor,
        ),
        glyph: Icon(Icons.pause_rounded, size: iconSize, color: mutedColor),
      );
    }

    // 进行中状态
    return _ringStack(
      ring: _progressRing(
        value: progress!.progressPercent(plan, completedKeys),
        color: theme.colorScheme.primary,
        trackColor: trackColor,
      ),
      glyph: _mediaGlyph(theme.colorScheme.primary),
    );
  }
}

/// 圆角方形外形的圆角半径，与合集列表项的封面圆角一致。
const double _kRoundedSquareRadius = 8;

/// 圆角方形进度环：轨道是整圈圆角矩形，进度从左上角起沿顺时针方向绘制。
class _RoundedSquareRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _RoundedSquareRingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 描边居中于边界内侧，避免被裁切。
    final inset = strokeWidth / 2;
    final ring = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(_kRoundedSquareRadius - inset),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );
    final contour = (Path()..addRRect(ring)).computeMetrics().first;
    final progressPath = contour.extractPath(
      0,
      contour.length * value.clamp(0.0, 1.0),
    );
    canvas.drawPath(
      progressPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RoundedSquareRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

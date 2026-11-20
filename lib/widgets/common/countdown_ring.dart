/// 环形倒计时（共享组件）
///
/// 圆环随时间推进，剩余秒数交给调用方通过 [overlayBuilder] 绘制，
/// 因此同一个圆环既可以包住文字，也可以只配一个秒数标签（主播放按钮，
/// 见 [PlaybackCountdownRing]）。
///
/// **自驱动动画**：内部使用 [AnimationController] 驱动圆环，不依赖外部高频
/// 传入 remaining，避免 Provider 每 100ms rebuild。
///
/// **快进内置**：收到 [isFastForward] = true 时，剩余动画压缩到 ~1 秒内完成。
library;

import 'package:flutter/material.dart';

import 'playback_controls.dart';

/// 环形倒计时
///
/// [total] 变化视为新的倒计时，会重建动画；[isPaused] 切换时暂停或继续。
class CountdownRing extends StatefulWidget {
  /// 倒计时总时长
  final Duration total;

  /// 是否已暂停
  final bool isPaused;

  /// 是否快进中（剩余动画将在 ~1 秒内完成）
  final bool isFastForward;

  /// 圆环外径
  final double diameter;

  /// 圆环线宽
  final double strokeWidth;

  /// 按剩余秒数绘制的叠加内容。返回值是圆环 Stack 的直接子项，
  /// 因此可以直接返回 [Positioned]。
  final Widget Function(BuildContext context, int remainingSeconds)?
  overlayBuilder;

  const CountdownRing({
    super.key,
    required this.total,
    required this.isPaused,
    this.isFastForward = false,
    required this.diameter,
    this.strokeWidth = 3,
    this.overlayBuilder,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  /// 快进目标时长
  static const _fastForwardDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    if (!widget.isPaused) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 总时长变化 → 新的倒计时，重建 controller
    if (widget.total != oldWidget.total) {
      final wasAnimating = _controller.isAnimating;
      _controller.dispose();
      _controller = _createController();
      if (wasAnimating && !widget.isPaused) _controller.forward();
      return;
    }

    // 快进状态变化
    if (widget.isFastForward != oldWidget.isFastForward) {
      _applyFastForward();
      return;
    }

    // 暂停/恢复
    if (widget.isPaused && !oldWidget.isPaused) {
      _controller.stop();
    } else if (!widget.isPaused && oldWidget.isPaused) {
      _controller.forward();
    }
  }

  /// 创建 AnimationController，正常速度 = total 时长
  AnimationController _createController() {
    return AnimationController(vsync: this, duration: widget.total)
      ..addListener(_onTick);
  }

  /// 快进/恢复正常速度
  void _applyFastForward() {
    final currentValue = _controller.value;
    _controller.stop();

    if (widget.isFastForward) {
      // 快进：让剩余动画在 ~1 秒内走完
      final remainingFraction = 1.0 - currentValue;
      if (remainingFraction > 0) {
        // duration 是 0→1 的总时长，只跑 remainingFraction 这段
        // 实际耗时 = duration × remainingFraction = 1000ms
        final fullDurationMs =
            _fastForwardDuration.inMilliseconds / remainingFraction;
        _controller.duration = Duration(milliseconds: fullDurationMs.round());
      }
    } else {
      // 恢复正常速度
      _controller.duration = widget.total;
    }

    if (!widget.isPaused) {
      _controller.forward(from: currentValue);
    }
  }

  void _onTick() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _controller.value; // 0.0 → 1.0（已过时间占比）
    final remainingMs = ((1.0 - progress) * widget.total.inMilliseconds)
        .round();
    final seconds = (remainingMs / 1000).ceil();
    final overlayBuilder = widget.overlayBuilder;

    return SizedBox.square(
      dimension: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SizedBox.square(
            dimension: widget.diameter,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: widget.strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              valueColor: AlwaysStoppedAnimation(
                theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (overlayBuilder != null) overlayBuilder(context, seconds),
        ],
      ),
    );
  }
}

/// 主播放按钮外侧的环形倒计时：直径与主按钮一致，秒数标签压在圆环顶部。
///
/// 讲解页、跟读、盲听等页面的循环间隙共用，通过 [PlaybackControls.centerRing]
/// 与主按钮叠放，不改变控制栏布局。
class PlaybackCountdownRing extends StatelessWidget {
  /// 倒计时总时长
  final Duration total;

  /// 是否已暂停
  final bool isPaused;

  /// 是否快进中
  final bool isFastForward;

  const PlaybackCountdownRing({
    super.key,
    required this.total,
    required this.isPaused,
    this.isFastForward = false,
  });

  @override
  Widget build(BuildContext context) {
    return CountdownRing(
      total: total,
      isPaused: isPaused,
      isFastForward: isFastForward,
      diameter: PlaybackControls.controlButtonSize,
      overlayBuilder: (context, seconds) => Positioned(
        // 秒数标签压在圆环顶部边缘上，不占用按钮行的布局高度。
        top: -9,
        left: 0,
        right: 0,
        child: Center(
          child: IgnorePointer(child: CountdownSecondsBadge(seconds: seconds)),
        ),
      ),
    );
  }
}

/// 倒计时秒数标签：浮在圆环边缘上的小胶囊，便于在不改变布局的情况下看清剩余秒数。
///
/// 高度不固定，大字号时随文字撑开，不会被裁切。
class CountdownSecondsBadge extends StatelessWidget {
  /// 剩余秒数
  final int seconds;

  const CountdownSecondsBadge({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$seconds',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

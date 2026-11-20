/// 倒计时控制按钮（共享组件）
///
/// 56×56 圆形按钮，外围带进度环，内部显示倒计时秒数，
/// 默认右下角显示暂停/恢复小徽章。调用方可提供 [onTap]，将点击改为
/// 接管自动流程（例如进入等待用户操作）。
///
/// 圆环与动画由 [CountdownRing] 负责，本组件只负责秒数、徽章与点击语义。
///
/// **纯展示组件**：只负责倒计时圆环，快进按钮由调用方控制。
library;

import 'package:flutter/material.dart';

import 'countdown_ring.dart';
import 'tappable_wrapper.dart';

/// 倒计时控制按钮
///
/// 接收 [total]（总时长）、[isPaused]、[isFastForward]，内部由 [CountdownRing] 驱动动画。
/// 点击自动切换暂停/恢复。
class CountdownChip extends StatelessWidget {
  /// 倒计时总时长
  final Duration total;

  /// 是否已暂停
  final bool isPaused;

  /// 是否快进中（剩余动画将在 ~1 秒内完成）
  final bool isFastForward;

  /// 暂停回调
  final VoidCallback onPause;

  /// 恢复回调
  final VoidCallback onResume;

  /// 自定义点击动作。提供后优先于暂停/恢复。
  final VoidCallback? onTap;

  const CountdownChip({
    super.key,
    required this.total,
    required this.isPaused,
    this.isFastForward = false,
    required this.onPause,
    required this.onResume,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TappableWrapper(
      onTap: onTap ?? (isPaused ? onResume : onPause),
      feedbackType: TapFeedback.scale,
      scaleDown: 0.90,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CountdownRing(
              total: total,
              isPaused: isPaused,
              isFastForward: isFastForward,
              diameter: 48,
              overlayBuilder: (context, seconds) => Center(
                child: Text(
                  '$seconds',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // 自定义动作用停止脚标提示“点击后停止自动推进”。
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primaryContainer,
                  border: Border.all(color: theme.colorScheme.surface),
                ),
                child: Icon(
                  onTap != null
                      ? Icons.stop_rounded
                      : (isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded),
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

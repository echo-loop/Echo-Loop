/// 播放控制栏（所有学习页面共享）
///
/// 通用的 [上一个] [播放/暂停] [下一个/完成] 控制栏。
/// 回调驱动，不依赖任何具体 Provider。
/// 用于盲听、精听、跟读、复述、难句补练、收藏复习页面。
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import 'tappable_wrapper.dart';

/// 播放控制栏：[上一个] [播放/暂停] [下一个/完成]
class PlaybackControls extends StatelessWidget {
  static const double controlButtonSize = 56;

  /// 是否可以返回上一个
  final bool canGoPrev;

  /// 是否为最后一个（影响下一个按钮图标：skip_next → check_circle）
  final bool isLast;

  /// 中间按钮图标（播放/暂停）
  final IconData centerIcon;

  /// 中间按钮点击回调
  final VoidCallback? onCenter;

  /// 上一个回调
  final VoidCallback? onPrevious;

  /// 下一个回调
  final VoidCallback? onNext;

  /// 可选：中间按钮的新手引导步骤，提供时会用 [GuideTarget] 包裹中间按钮
  final GuideStep? centerGuideStep;

  const PlaybackControls({
    super.key,
    required this.canGoPrev,
    required this.isLast,
    required this.centerIcon,
    this.onCenter,
    this.onPrevious,
    this.onNext,
    this.centerGuideStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final centerButton = TappableWrapper(
      onTap: onCenter,
      feedbackType: TapFeedback.scale,
      scaleDown: 0.92,
      child: Container(
        width: controlButtonSize,
        height: controlButtonSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          centerIcon,
          size: 28,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );

    final centerStep = centerGuideStep;
    final centerWidget = centerStep != null
        ? GuideTarget(step: centerStep, child: centerButton)
        : centerButton;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlaybackNavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? onPrevious : null,
          ),
          const SizedBox(width: 48),

          centerWidget,
          const SizedBox(width: 48),

          PlaybackNavButton(
            icon: isLast ? Icons.check_circle_rounded : Icons.skip_next_rounded,
            enabled: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（上一个/下一个/完成）
class PlaybackNavButton extends StatelessWidget {
  /// 按钮图标
  final IconData icon;

  /// 是否可用
  final bool enabled;

  /// 点击回调
  final VoidCallback? onTap;

  const PlaybackNavButton({
    super.key,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return SizedBox(
        width: PlaybackControls.controlButtonSize,
        height: PlaybackControls.controlButtonSize,
        child: Center(
          child: AnimatedOpacity(
            opacity: 0.15,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }
    return TappableWrapper(
      onTap: onTap,
      feedbackType: TapFeedback.opacityAndScale,
      pressedOpacity: 0.4,
      scaleDown: 0.85,
      child: SizedBox(
        width: PlaybackControls.controlButtonSize,
        height: PlaybackControls.controlButtonSize,
        child: Center(
          child: Opacity(
            opacity: 0.6,
            child: Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

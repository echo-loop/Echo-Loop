/// 播放控制栏（所有学习页面共享）
///
/// 通用的 [上一个] [播放/暂停] [下一个/完成] 控制栏。
/// 回调驱动，不依赖任何具体 Provider。
/// 用于盲听、精听、跟读、复述、难句补练、收藏复习页面。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import '../../utils/playback_speed.dart';
import 'capsule_selector.dart';

/// 播放类按钮的 SVG 图标：播放 / 暂停。
enum PlaybackToggleIcon {
  play('assets/icon/play.svg', 1),
  // 暂停条的占满面积比三角形大，按 0.9 缩小后与播放三角形的视觉高度接近
  pause('assets/icon/pause.svg', 0.9);

  const PlaybackToggleIcon(this.assetPath, this.opticalScale);

  /// SVG 资源路径
  final String assetPath;

  /// 相对调用方给定尺寸的视觉缩放系数，用于抵消各 SVG 画面占比的差异
  final double opticalScale;
}

/// 中间主播放按钮图标的定位 Key，供测试按图标类型查找。
ValueKey<String> playbackCenterIconKey(PlaybackToggleIcon icon) =>
    ValueKey('playback-center-icon-${icon.name}');

/// 播放 / 暂停 SVG 图标，颜色与尺寸由调用方决定。
Widget playbackToggleGlyph(
  PlaybackToggleIcon icon, {
  required Color color,
  required double size,
}) {
  final renderedSize = size * icon.opticalScale;
  return SvgPicture.asset(
    icon.assetPath,
    key: playbackCenterIconKey(icon),
    width: renderedSize,
    height: renderedSize,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// 主播放按钮的统一样式：无底色，图标直接使用主题主色。
///
/// 所有播放 / 暂停主按钮都用它，避免各页面各自实现出不同的外观。
class PlaybackCenterButton extends StatelessWidget {
  const PlaybackCenterButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = PlaybackControls.controlButtonSize,
    this.tooltip,
  });

  /// 按钮图标，通常由 [playbackToggleGlyph] 生成
  final Widget icon;

  /// 点击回调，为 null 时按钮置灰
  final VoidCallback? onPressed;

  /// 按钮的点击区域与圆形水波纹尺寸
  final double size;

  /// 可选提示文案
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      // 去掉默认的 8 内边距，否则 56 的按钮里图标最多只有 40，放大的图标会被压缩
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        padding: EdgeInsets.zero,
        hoverColor: primary.withValues(alpha: 0.08),
        focusColor: primary.withValues(alpha: 0.12),
        highlightColor: primary.withValues(alpha: 0.12),
      ),
    );
  }
}

/// 播放控制栏：[上一个] [播放/暂停] [下一个/完成]
class PlaybackControls extends StatelessWidget {
  static const double controlButtonSize = 56;
  /// 播放按钮与上一句 / 下一句的间距，与随心听保持一致（中心距 104）。
  static const double standardControlGap = 48;
  /// 随心听 / 普通状态下相邻按钮的中心距。
  static const double standardControlPitch =
      controlButtonSize + standardControlGap;

  /// 开启速度按钮时相邻按钮中心距的下限：保证 360pt 宽的手机上四个按钮放得下。
  static const double speedControlPitch = 64;

  /// 显示速度按钮所需的最小宽度：两侧各容纳「速度 + 间距 + 上一句」，再加中间按钮。
  static const double speedControlMinWidth = 4 * speedControlPitch + controlButtonSize;

  /// 开启速度按钮时，按可用宽度计算相邻按钮的间距：在 [speedControlPitch] 与
  /// [standardControlPitch] 之间尽量拉开，播放按钮始终居中不受影响。
  ///
  /// 速度按钮与上一句之间占两个中心距，左侧需要两个按钮宽加一个间距才放得下，
  /// 据此反推中心距上限为 (宽度 - 按钮宽) / 4。
  static double speedControlSideGap(double availableWidth) {
    final maxPitch = (availableWidth - controlButtonSize) / 4;
    final pitch = maxPitch
        .clamp(speedControlPitch, standardControlPitch)
        .toDouble();
    return pitch - controlButtonSize;
  }

  /// 中间主播放 / 暂停图标的尺寸：去掉底色后需要比导航图标略大，才有视觉重心。
  ///
  /// play.svg 的三角形只占 viewBox 的约一半，36 时视觉偏小，故放大到 44；
  /// 按钮点击区域（[controlButtonSize]）保持不变。
  static const double centerIconSize = 44;

  /// 是否可以返回上一个
  final bool canGoPrev;

  /// 是否可以前进到下一个。默认 true；为 false 时下一个按钮置灰（如讲解页的末句）。
  final bool canGoNext;

  /// 是否为最后一个（影响下一个按钮图标：skip_next → check_circle）
  final bool isLast;

  /// 中间按钮图标（播放/暂停）
  final PlaybackToggleIcon centerIcon;

  /// 中间按钮点击回调
  final VoidCallback? onCenter;

  /// 上一个回调
  final VoidCallback? onPrevious;

  /// 下一个回调
  final VoidCallback? onNext;

  /// 可选：中间按钮的新手引导步骤，提供时会用 [GuideTarget] 包裹中间按钮
  final GuideStep? centerGuideStep;

  /// 可选：当前播放速度。与 [onPlaybackSpeedChanged] 同时提供时，在上一句左侧显示速度按钮。
  final double? playbackSpeed;

  /// 可选：选定新速度后的回调。
  final ValueChanged<double>? onPlaybackSpeedChanged;

  const PlaybackControls({
    super.key,
    required this.canGoPrev,
    this.canGoNext = true,
    required this.isLast,
    required this.centerIcon,
    this.onCenter,
    this.onPrevious,
    this.onNext,
    this.centerGuideStep,
    this.playbackSpeed,
    this.onPlaybackSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final centerButton = SizedBox.square(
      dimension: controlButtonSize,
      child: PlaybackCenterButton(
        onPressed: onCenter,
        icon: playbackToggleGlyph(
          centerIcon,
          color: onCenter != null
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withValues(alpha: 0.38),
          size: centerIconSize,
        ),
      ),
    );

    final centerStep = centerGuideStep;
    final centerWidget = centerStep != null
        ? GuideTarget(step: centerStep, child: centerButton)
        : centerButton;

    final previousWidget = PlaybackNavButton(
      icon: Icons.skip_previous_rounded,
      enabled: canGoPrev,
      onTap: canGoPrev ? onPrevious : null,
    );
    final nextRegionChild = PlaybackNavButton(
      icon: isLast ? Icons.check_circle_rounded : Icons.skip_next_rounded,
      enabled: canGoNext,
      onTap: canGoNext ? onNext : null,
    );

    final speed = playbackSpeed;
    final changeSpeed = onPlaybackSpeedChanged;
    final hasSpeedControl = speed != null && changeSpeed != null;

    // 播放按钮必须始终固定在正中间：左右两侧各用等 flex 的 Expanded 包住导航区域，
    // 两侧分配到的宽度永远相等，播放按钮的位置只取决于这个等分点。
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽度放不下速度按钮时隐藏它，而不是让导航区域溢出。
        final showSpeedSelector =
            hasSpeedControl && constraints.maxWidth >= speedControlMinWidth;
        // 播放按钮与上一句/下一句之间的间距：显示速度按钮时按可用宽度决定。
        final sideGap = showSpeedSelector
            ? speedControlSideGap(constraints.maxWidth)
            : standardControlGap;
        // 两侧 Expanded 等宽，每侧至少要容纳较宽的一侧内容。
        final leftContentWidth = showSpeedSelector
            ? controlButtonSize * 2 + sideGap
            : controlButtonSize;
        final sideRegionWidth = math.max(leftContentWidth, controlButtonSize);
        final requiredWidth =
            sideRegionWidth * 2 + controlButtonSize + sideGap * 2;
        final horizontalPadding = math
            .max(
              0,
              math.min(
                AppSpacing.l,
                (constraints.maxWidth - requiredWidth) / 2,
              ),
            )
            .toDouble();
        // 无速度按钮时直接使用上一句按钮，不额外包一层 Row。
        final Widget previousRegionChild = !showSpeedSelector
            ? previousWidget
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CapsuleSelector<double>(
                    value: speed,
                    options: kQuickPlaybackSpeeds,
                    labelOf: formatPlaybackSpeedLabel,
                    highlightIndexOf: nearestQuickPlaybackSpeedIndex,
                    onChanged: changeSpeed,
                    size: controlButtonSize,
                    title: AppLocalizations.of(context)!.playbackSpeed,
                    dragHint: AppLocalizations.of(
                      context,
                    )!.playbackSpeedDragHint,
                  ),
                  SizedBox(width: sideGap),
                  previousWidget,
                ],
              );
        final controls = Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: previousRegionChild,
              ),
            ),
            SizedBox(width: sideGap),
            centerWidget,
            SizedBox(width: sideGap),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: nextRegionChild,
              ),
            ),
          ],
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: controls,
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    final iconWidget = enabled
        ? Opacity(
            opacity: 0.6,
            child: Icon(icon, size: 32, color: colorScheme.onSurface),
          )
        : AnimatedOpacity(
            opacity: 0.15,
            duration: const Duration(milliseconds: 150),
            child: Icon(icon, size: 32, color: colorScheme.onSurface),
          );

    return SizedBox.square(
      dimension: PlaybackControls.controlButtonSize,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: iconWidget,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(PlaybackControls.controlButtonSize),
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
          focusColor: colorScheme.onSurface.withValues(alpha: 0.12),
          highlightColor: colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface,
        ),
      ),
    );
  }
}

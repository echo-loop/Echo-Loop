/// 应用统一 toast 接口：居中胶囊，可控位置、颜色、时长与图标。
///
/// 使用 toastification 而非 SnackBar：toast 需要覆盖全屏页面（如学习页）。
/// 所有应用内轻提示都应通过 [showAppToast]，不要直接调用 toastification。
library;

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// toast 在屏幕上的位置。
enum AppToastPosition {
  top(Alignment.topCenter),
  center(Alignment.center),
  bottom(Alignment.bottomCenter);

  const AppToastPosition(this.alignment);

  final Alignment alignment;
}

/// toast 最大宽度：宽度随内容收缩，超过该值才换行。与 toastification 默认槽位宽度一致，
/// 避免在平板/桌面上铺满屏幕。
const _maxToastWidth = 400.0;

/// toast 与屏幕左右边缘的最小距离，窄窗口或小屏手机上避免贴边。
const _screenHorizontalMargin = 24.0;

/// 在 [overlayState] 上弹出胶囊 toast。
///
/// [overlayState] 由调用方提供：在页面内用 `Overlay.of(context, rootOverlay: true)`；
/// 在 MaterialApp.builder 等位于 Navigator 之上的位置，用根 Navigator 的 overlay。
///
/// - [position]：位置，默认顶部居中。
/// - [duration]：自动消失时长，默认 3 秒。
/// - [icon]：可选前置图标，传 null 则不显示。
/// - [background] / [foreground]：胶囊底色与文字、图标颜色，缺省时取当前主题的
///   `inverseSurface` / `onInverseSurface`，亮暗主题下都能保证对比度。
/// - [dismissOnTap]：点击是否立即关闭。
void showAppToast({
  required OverlayState overlayState,
  required String message,
  AppToastPosition position = AppToastPosition.top,
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
  Color? background,
  Color? foreground,
  bool dismissOnTap = true,
}) {
  final scheme = Theme.of(overlayState.context).colorScheme;
  final backgroundColor = background ?? scheme.inverseSurface;
  final foregroundColor = foreground ?? scheme.onInverseSurface;

  toastification.showCustom(
    overlayState: overlayState,
    alignment: position.alignment,
    autoCloseDuration: duration,
    builder: (context, holder) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final maxWidth = screenWidth - 2 * _screenHorizontalMargin;
      // toastification 把每条 toast 放进固定宽度（默认 400）的槽位，内容默认靠左，
      // 因此这里显式居中；点击区域只覆盖胶囊本身。
      return Center(
        child: GestureDetector(
          onTap: dismissOnTap
              ? () => toastification.dismissById(holder.id)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < _maxToastWidth ? maxWidth : _maxToastWidth,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                // 单行时接近胶囊；换行后仍是圆角矩形，不会变成大圆角的团块。
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: foregroundColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      message,
                      // 左对齐：换行时图标与文字首行贴近，而不是文字居中后图标离得很远。
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// 每日学习目标打卡成功 toast。
///
/// 使用 toastification 而非 SnackBar：提示需要覆盖全屏学习页，且视觉为居中胶囊。
library;

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// 胶囊背景与文字颜色，按亮/暗主题分别取值。
// 亮色背景需要与白色页面拉开对比，因此比暗色取更饱和的绿；同时加轻阴影分层。
const _lightBackground = Color(0xFFD3EEDF);
const _lightForeground = Color(0xFF2E7D57);
const _darkBackground = Color(0xFF1E3A2C);
const _darkForeground = Color(0xFF9FD8B5);

/// toast 最大宽度：宽度随内容收缩，超过该值才换行。与 toastification 默认槽位宽度一致，
/// 避免在平板/桌面上铺满屏幕。
const _maxToastWidth = 400.0;

/// toast 与屏幕左右边缘的最小距离，窄窗口或小屏手机上避免贴边。
const _screenHorizontalMargin = 24.0;

/// 在根 [overlayState] 上弹出打卡成功提示，3 秒后自动消失，点击可提前关闭。
///
/// 根 overlay 位于根 Navigator 之上，因此即使学习页是全屏页也能看到。
void showDailyGoalCompletedToast({
  required OverlayState overlayState,
  required String message,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? _darkBackground : _lightBackground;
  final foreground = isDark ? _darkForeground : _lightForeground;

  toastification.showCustom(
    overlayState: overlayState,
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    builder: (context, holder) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final maxWidth = screenWidth - 2 * _screenHorizontalMargin;
      // toastification 把每条 toast 放进固定宽度（默认 400）的槽位，内容默认靠左，
      // 因此这里显式居中；点击区域只覆盖胶囊本身。
      return Center(
        child: GestureDetector(
          onTap: () => toastification.dismissById(holder.id),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < _maxToastWidth ? maxWidth : _maxToastWidth,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: background,
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
                  Icon(Icons.check_circle_outline, size: 20, color: foreground),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      // 左对齐：换行时图标与文字首行贴近，而不是文字居中后图标离得很远。
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: foreground,
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

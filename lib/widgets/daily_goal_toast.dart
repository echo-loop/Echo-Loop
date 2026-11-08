/// 每日学习目标打卡成功 toast。
library;

import 'package:flutter/material.dart';

import 'app_toast.dart';

/// 胶囊背景与文字颜色，按亮/暗主题分别取值。
// 亮色背景需要与白色页面拉开对比，因此比暗色取更饱和的绿；同时加轻阴影分层。
const _lightBackground = Color(0xFFD3EEDF);
const _lightForeground = Color(0xFF2E7D57);
const _darkBackground = Color(0xFF1E3A2C);
const _darkForeground = Color(0xFF9FD8B5);

/// 在根 [overlayState] 上弹出打卡成功提示，3 秒后自动消失，点击可提前关闭。
///
/// 根 overlay 位于根 Navigator 之上，因此即使学习页是全屏页也能看到。
void showDailyGoalCompletedToast({
  required OverlayState overlayState,
  required String message,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  showAppToast(
    overlayState: overlayState,
    message: message,
    icon: Icons.check_circle_outline,
    background: isDark ? _darkBackground : _lightBackground,
    foreground: isDark ? _darkForeground : _lightForeground,
  );
}

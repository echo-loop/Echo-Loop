// 二级菜单与原弹出菜单共用外观，避免不同入口发生样式漂移。
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

MenuStyle appMenuStyle(ThemeData theme) {
  final popupTheme = theme.popupMenuTheme;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(popupTheme.color),
    surfaceTintColor: WidgetStatePropertyAll(popupTheme.surfaceTintColor),
    shadowColor: WidgetStatePropertyAll(popupTheme.shadowColor),
    elevation: WidgetStatePropertyAll(popupTheme.elevation),
    shape: WidgetStatePropertyAll(switch (popupTheme.shape) {
      final OutlinedBorder shape => shape,
      _ => const RoundedRectangleBorder(),
    }),
    side: WidgetStatePropertyAll(switch (popupTheme.shape) {
      final OutlinedBorder shape => shape.side,
      _ => BorderSide.none,
    }),
    padding: WidgetStatePropertyAll(popupTheme.menuPadding),
  );
}

ButtonStyle appMenuButtonStyle(ThemeData theme, {bool destructive = false}) {
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(
      destructive
          ? theme.colorScheme.error
          : theme.colorScheme.onSurface.withValues(alpha: 0.84),
    ),
    iconColor: WidgetStatePropertyAll(
      destructive
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
    ),
    textStyle: WidgetStatePropertyAll(
      theme.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.m),
    ),
    visualDensity: VisualDensity.standard,
    overlayColor: WidgetStatePropertyAll(
      theme.colorScheme.onSurface.withValues(alpha: 0.06),
    ),
  );
}

import 'package:flutter/material.dart';

/// 普通表单输入文字样式，降低弹窗和底部 sheet 内输入框的视觉重量。
TextStyle? compactFormTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface,
    height: 1.25,
  );
}

/// 普通表单输入框装饰，统一弱化 label 和 placeholder。
InputDecoration compactFormInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool isDense = false,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final labelStyle = theme.textTheme.bodySmall?.copyWith(
    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: isDense,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    labelStyle: labelStyle,
    floatingLabelStyle: labelStyle?.copyWith(
      color: colorScheme.primary.withValues(alpha: 0.78),
    ),
    hintStyle: theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
  );
}

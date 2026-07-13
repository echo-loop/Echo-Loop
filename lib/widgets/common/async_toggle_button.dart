/// 异步 toggle 按钮
///
/// 内部管理 loading 状态，点击时执行异步回调，
/// 自动显示 loading 指示器并禁止重复点击。
/// 支持默认、选中、加载、禁用四种视觉状态。
library;

import 'package:flutter/material.dart';

/// 选中态填充色（纯黑深色主题专用）
///
/// M3 primaryContainer 是低饱和灰蓝，在纯黑上显朦胧；改用实色深蓝，
/// 与意群 badge 同色系，清爽不发雾。浅色仍用 primaryContainer。
const _activeFillDark = Color(0xFF1A3A5C);

/// 异步 toggle 按钮
///
/// 按钮高度 36dp，圆角 8dp，图标 16dp + labelMedium 文字。
/// [onPressed] 返回 Future，按钮在 Future 完成前自动显示 loading。
class AsyncToggleButton extends StatefulWidget {
  /// 按钮文字
  final String label;

  /// 按钮图标
  final IconData icon;

  /// 是否处于选中（激活）状态
  final bool isActive;

  /// 是否禁用
  final bool isDisabled;

  /// 外部驱动的加载状态。
  ///
  /// 自动触发请求时，按钮没有经过内部点击路径，但仍需要显示加载并禁止重复点击。
  final bool isLoading;

  /// 默认状态下的图标颜色（未激活、未禁用时使用）
  /// 为 null 时使用 foregroundColor（与文字同色）
  final Color? iconColor;

  /// 点击回调，返回 Future；按钮自动管理 loading 状态
  final Future<void> Function() onPressed;

  const AsyncToggleButton({
    super.key,
    required this.label,
    required this.icon,
    this.isActive = false,
    this.isDisabled = false,
    this.isLoading = false,
    this.iconColor,
    required this.onPressed,
  });

  @override
  State<AsyncToggleButton> createState() => _AsyncToggleButtonState();
}

class _AsyncToggleButtonState extends State<AsyncToggleButton> {
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_effectiveLoading || widget.isDisabled) return;
    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } catch (_) {
      // 错误由 onPressed 内部处理，按钮只负责停止 loading
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _effectiveLoading => _isLoading || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 纯黑深色主题下：底色压暗后几乎贴黑，需满底色 + 细描边才能看清芯片边界；
    // 选中态的亮 primary 描边在纯黑上过曝，需柔化。浅色主题保持原样。
    final isDark = theme.brightness == Brightness.dark;

    // 根据状态决定颜色
    final Color backgroundColor;
    final Color foregroundColor;
    final Border? border;

    if (widget.isDisabled) {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.6 : 0.3,
      );
      foregroundColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
      border = isDark
          ? Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            )
          : null;
    } else if (widget.isActive || _effectiveLoading) {
      backgroundColor = isDark ? _activeFillDark : colorScheme.primaryContainer;
      foregroundColor = colorScheme.primary;
      border = Border.all(
        color: isDark
            ? colorScheme.primary.withValues(alpha: 0.5)
            : colorScheme.primary,
        width: 1,
      );
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 1 : 0.5,
      );
      foregroundColor = colorScheme.onSurfaceVariant;
      border = isDark
          ? Border.all(color: colorScheme.outlineVariant, width: 1)
          : null;
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_effectiveLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(
                widget.icon,
                size: 16,
                color: widget.isDisabled
                    ? foregroundColor
                    : (widget.iconColor ?? foregroundColor),
              ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

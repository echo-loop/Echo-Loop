/// 文本右键/长按上下文菜单
///
/// 提供复制等文本操作，支持 iOS 长按和桌面端右键。
/// 复制成功后使用 Overlay 显示轻量提示，确保在 BottomSheet 等场景下也能正常显示。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// 文本右键/长按上下文菜单
class TextContextMenu {
  /// 显示上下文菜单
  ///
  /// [context] 当前 BuildContext
  /// [position] 菜单弹出位置（全局坐标）
  /// [text] 要复制的文本内容
  static Future<void> show(
    BuildContext context,
    Offset position,
    String text,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    final theme = Theme.of(context);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & (overlay?.size ?? const Size(0, 0)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      surfaceTintColor: Colors.transparent,
      color: theme.colorScheme.surface,
      constraints: const BoxConstraints(minWidth: 120),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.copy,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (result == 'copy' && context.mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        showFeedback(context, l10n.copied);
      }
    }
  }

  /// 使用 Overlay 显示轻量提示
  ///
  /// 不依赖 ScaffoldMessenger，在 BottomSheet 等场景中也能正常显示，
  /// 并避免整句菜单的结果覆盖播放器已有的列表回退提示。
  static void showFeedback(
    BuildContext context,
    String message, {
    IconData icon = Icons.check,
  }) {
    final overlayState = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        icon: icon,
        onDismiss: () => entry.remove(),
      ),
    );

    overlayState.insert(entry);
  }
}

/// Overlay 轻量提示组件
///
/// 底部居中显示，1 秒后自动淡出消失。
class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.message,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
    _dismissTimer = Timer(const Duration(seconds: 1), _fadeOut);
  }

  void _fadeOut() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 80,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xE0303030),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 15, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

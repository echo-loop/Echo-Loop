/// 意群快捷操作工具条
///
/// 浮动在 badge 上方，单个书签图标按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 意群快捷操作工具条
///
/// 圆角浅色背景，单个书签按钮。
class SenseGroupActionBar extends StatelessWidget {
  /// 是否已收藏
  final bool isSaved;

  /// 收藏/取消收藏回调
  final VoidCallback onToggleSave;

  const SenseGroupActionBar({
    super.key,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surfaceContainerHigh;
    final fgColor = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            HapticFeedback.lightImpact();
            onToggleSave();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              size: 18,
              color: isSaved ? Colors.amber.shade700 : fgColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// 词性蓝标签
///
/// 在线词典与 AI 词典共用，统一词性（n./v./adj.…）的视觉样式。
library;

import 'package:flutter/material.dart';

/// 词性标签
class PosTag extends StatelessWidget {
  /// 词性缩写文本
  final String pos;

  const PosTag({super.key, required this.pos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pos,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
          height: 1.3,
        ),
      ),
    );
  }
}

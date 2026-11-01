import 'package:flutter/material.dart';

/// 音频元信息小标签：图标 + 文字（如时长、句数、词数）。
///
/// 学习计划页进度卡片与音频详情页共用，颜色取当前主题的 outline 色。
class AudioInfoChip extends StatelessWidget {
  /// 标签前的图标。
  final IconData icon;

  /// 标签文字。
  final String label;

  const AudioInfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

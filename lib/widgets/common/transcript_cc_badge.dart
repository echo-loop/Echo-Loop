/// 字幕 CC 徽章
///
/// 项目统一的「有字幕」静态标记：列表与播客单集共用同一外观，保证视觉一致。
library;

import 'package:flutter/material.dart';

/// 中性灰 CC 徽章，表示条目有可用字幕。
///
/// [label] 作为无障碍语义（Tooltip 与朗读），视觉上只呈现「CC」。
/// [containerKey] 挂在徽章的 Container 上，供测试定位。
class TranscriptCcBadge extends StatelessWidget {
  const TranscriptCcBadge({super.key, required this.label, this.containerKey});

  final String label;
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // CC 是「有无字幕」的静态属性，用中性色，避免与彩色状态 chip 争夺注意力。
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Container(
        key: containerKey,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'CC',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

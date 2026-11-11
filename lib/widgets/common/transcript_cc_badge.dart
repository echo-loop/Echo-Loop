/// 字幕图标徽章
///
/// 项目统一的「有字幕」静态标记：列表与播客单集共用同一外观，保证视觉一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 中性色字幕图标，表示条目有可用字幕。
///
/// [label] 作为无障碍语义（Tooltip 与朗读）。
/// [containerKey] 挂在图标上，供测试定位。
class TranscriptCcBadge extends StatelessWidget {
  const TranscriptCcBadge({super.key, required this.label, this.containerKey});

  static const String _iconAsset = 'assets/icon/closed-captions.svg';
  // 图标在 20×20 画布内留有约 13% 的边距；取 22 让可见轮廓约 16，比难度 badge（约 20）略小，视觉上不抢眼。
  static const double _size = 22;

  final String label;
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 字幕是「有无字幕」的静态属性，用弱化的中性色，避免与彩色状态 chip 争夺注意力。
    final color = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return Tooltip(
      message: label,
      child: SvgPicture.asset(
        _iconAsset,
        key: containerKey,
        width: _size,
        height: _size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

/// 意群标注文本组件
///
/// 将句子按意群渲染为内联 badge 样式，保持自然文本排版。
/// 所有意群使用统一背景色，可点击播放对应音频片段。
/// 支持三种状态：空闲 / 播放中 / 已播放。
/// 意群内单词仍可点击查词典。
library;

import 'package:flutter/material.dart';
import '../../models/sense_group_result.dart';
import '../../utils/sense_group_timing.dart';

/// 意群 badge 背景色（亮色主题，统一颜色避免误导用户）
const _groupColorLight = Color(0xFFE3F2FD); // 浅蓝

/// 意群 badge 背景色（暗色主题）
const _groupColorDark = Color(0xFF1A3A5C); // 深蓝

/// 意群标注文本
///
/// 使用 Wrap + badge 实现，意群间留出间距，意群内单词保持正常间距。
class SenseGroupText extends StatefulWidget {
  /// 意群列表
  final List<SenseGroup> groups;

  /// 各意群时间范围
  final List<SenseGroupTiming> timings;

  /// 正在播放的意群索引（null 表示无播放）
  final int? playingGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedGroupIndices;

  /// 点击意群回调
  final void Function(int groupIndex) onTapGroup;

  const SenseGroupText({
    super.key,
    required this.groups,
    required this.timings,
    this.playingGroupIndex,
    this.playedGroupIndices = const {},
    required this.onTapGroup,
  });

  @override
  State<SenseGroupText> createState() => _SenseGroupTextState();
}

class _SenseGroupTextState extends State<SenseGroupText> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
      height: 1.4,
      color: colorScheme.onSurface,
    );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < widget.groups.length; i++)
          _buildGroupBadge(i, baseStyle, colorScheme),
      ],
    );
  }

  /// 构建单个意群 badge
  Widget _buildGroupBadge(
    int index,
    TextStyle? baseStyle,
    ColorScheme colorScheme,
  ) {
    final group = widget.groups[index];
    final isPlaying = widget.playingGroupIndex == index;
    final isPlayed = widget.playedGroupIndices.contains(index);

    // 背景色：播放中用主题色，否则统一颜色
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isPlaying
        ? colorScheme.primaryContainer
        : isDark ? _groupColorDark : _groupColorLight;

    // 边框：默认显示浅色边框，播放中/已播放加深
    final borderColor = isPlaying
        ? colorScheme.primary
        : isPlayed
        ? colorScheme.primary.withValues(alpha: 0.3)
        : colorScheme.outline.withValues(alpha: 0.3);
    final border = Border.all(color: borderColor, width: 1.5);

    return GestureDetector(
      onTap: () => widget.onTapGroup(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: Text(
          group.text.trim(),
          style: baseStyle?.copyWith(
            fontWeight: group.isCore ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

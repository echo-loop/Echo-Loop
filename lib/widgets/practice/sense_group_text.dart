/// 意群标注文本组件
///
/// 将句子按意群渲染为内联 badge 样式，保持自然文本排版。
/// 所有意群使用统一背景色，可点击播放对应音频片段。
/// 支持四种视觉状态：空闲 / 播放中 / 已播放 / 已收藏。
library;

import 'package:flutter/material.dart';
import '../../utils/sense_group_timing.dart';
import '../common/text_context_menu.dart';

/// 意群 badge 背景色（亮色主题，统一颜色避免误导用户）
const _groupColorLight = Color(0xFFE3F2FD); // 浅蓝

/// 意群 badge 背景色（暗色主题）
const _groupColorDark = Color(0xFF1A3A5C); // 深蓝

/// 已收藏意群背景色（亮色主题）
final _savedColorLight = Colors.orange.shade50;

/// 已收藏意群背景色（暗色主题）
final _savedColorDark = Colors.orange.shade900.withValues(alpha: 0.2);

/// 已收藏意群边框色
final _savedBorderColor = Colors.orange.shade300;

/// 归一化意群文本（小写 + trim + 去句末标点，保留撇号）
///
/// 与 DAO 层的归一化规则保持一致。
String normalizeSenseGroupPhrase(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'[.!?,;:]+$'), '');
}

/// 意群标注文本
///
/// 使用 Wrap + badge 实现，意群间留出间距，意群内单词保持正常间距。
class SenseGroupText extends StatefulWidget {
  /// 意群文本列表
  final List<String> chunks;

  /// 各意群时间范围
  final List<SenseGroupTiming> timings;

  /// 正在播放的意群索引（null 表示无播放）
  final int? playingGroupIndex;

  /// 已播放过的意群索引集合
  final Set<int> playedGroupIndices;

  /// 点击意群回调（播放）
  final void Function(int groupIndex) onTapGroup;

  /// 点击意群回调（附带 badge 全局位置，用于显示工具条）
  final void Function(int groupIndex, Rect globalRect)? onTapGroupWithRect;

  /// 已收藏的意群文本集合（归一化后）
  final Set<String> savedGroupTexts;

  const SenseGroupText({
    super.key,
    required this.chunks,
    required this.timings,
    this.playingGroupIndex,
    this.playedGroupIndices = const {},
    required this.onTapGroup,
    this.onTapGroupWithRect,
    this.savedGroupTexts = const {},
  });

  @override
  State<SenseGroupText> createState() => _SenseGroupTextState();
}

class _SenseGroupTextState extends State<SenseGroupText> {
  /// 每个 badge 的 GlobalKey，用于获取位置
  final List<GlobalKey> _badgeKeys = [];

  @override
  void didUpdateWidget(SenseGroupText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBadgeKeys();
  }

  @override
  void initState() {
    super.initState();
    _syncBadgeKeys();
  }

  void _syncBadgeKeys() {
    while (_badgeKeys.length < widget.chunks.length) {
      _badgeKeys.add(GlobalKey());
    }
  }

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
        for (var i = 0; i < widget.chunks.length; i++)
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
    final chunk = widget.chunks[index];
    final isPlaying = widget.playingGroupIndex == index;
    final isPlayed = widget.playedGroupIndices.contains(index);
    final isSaved = widget.savedGroupTexts.contains(
      normalizeSenseGroupPhrase(chunk),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 背景色优先级：播放中 > 已收藏 > 默认
    final Color bgColor;
    if (isPlaying) {
      bgColor = colorScheme.primaryContainer;
    } else if (isSaved) {
      bgColor = isDark ? _savedColorDark : _savedColorLight;
    } else {
      bgColor = isDark ? _groupColorDark : _groupColorLight;
    }

    // 边框优先级：播放中 > 已收藏 > 已播放 > 默认
    final Color borderColor;
    if (isPlaying) {
      borderColor = colorScheme.primary;
    } else if (isSaved) {
      borderColor = _savedBorderColor;
    } else if (isPlayed) {
      borderColor = colorScheme.primary.withValues(alpha: 0.3);
    } else {
      borderColor = colorScheme.outline.withValues(alpha: 0.3);
    }
    final border = Border.all(color: borderColor, width: 1.5);

    return GestureDetector(
      onTap: () {
        widget.onTapGroup(index);
        // 获取 badge 全局位置，通知父组件显示工具条
        if (widget.onTapGroupWithRect != null) {
          final renderBox =
              _badgeKeys[index].currentContext?.findRenderObject()
                  as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final rect = position & renderBox.size;
            widget.onTapGroupWithRect!(index, rect);
          }
        }
      },
      onLongPressStart: (details) =>
          TextContextMenu.show(context, details.globalPosition, chunk.trim()),
      onSecondaryTapDown: (details) =>
          TextContextMenu.show(context, details.globalPosition, chunk.trim()),
      child: Container(
        key: _badgeKeys[index],
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: border,
        ),
        child: Text(chunk.trim(), style: baseStyle),
      ),
    );
  }
}

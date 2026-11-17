import 'package:flutter/material.dart';

import '../../models/practice_media_split.dart';
import 'practice_media_split_geometry.dart';

/// 视频与内容之间的拖动分隔条：整条都是热区，中间的短条是视觉提示。
///
/// 学习任务页与字幕编辑页共用，拖动、双击恢复默认、悬停光标的手感保持一致；
/// 尺寸如何换算与保存由使用方决定。
class MediaSplitDivider extends StatefulWidget {
  const MediaSplitDivider({
    super.key,
    required this.axis,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onReset,
  });

  final PracticeMediaSplitAxis axis;
  final VoidCallback onDragStart;

  /// 主轴方向的位移，正值表示视频变大。
  final ValueChanged<double> onDragUpdate;

  /// 拖动结束；拖动中分隔条被移出树时会在帧结束后补发，使用方可能已销毁，需自行检查。
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  @override
  State<MediaSplitDivider> createState() => _MediaSplitDividerState();
}

class _MediaSplitDividerState extends State<MediaSplitDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  void dispose() {
    // 拖动中被移出树（窗口缩放切换布局、页面关闭）时手势不会再回调结束，
    // 使用方会残留拖动中的尺寸；帧结束后补发一次。不能在 dispose 中直接回调：
    // 此时元素树处于锁定状态，使用方 setState 会报错。
    if (_isDragging) {
      final onDragEnd = widget.onDragEnd;
      WidgetsBinding.instance.addPostFrameCallback((_) => onDragEnd());
    }
    super.dispose();
  }

  void _handleStart() {
    setState(() => _isDragging = true);
    widget.onDragStart();
  }

  void _handleEnd() {
    setState(() => _isDragging = false);
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isStacked = widget.axis == PracticeMediaSplitAxis.stacked;
    final isActive = _isHovered || _isDragging;
    const thickness = PracticeMediaSplitGeometry.dividerExtent;
    final grip = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: isStacked ? (isActive ? 48 : 36) : 4,
      height: isStacked ? 4 : (isActive ? 48 : 36),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return MouseRegion(
      cursor: isStacked
          ? SystemMouseCursors.resizeUpDown
          : SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        key: const ValueKey('practice-media-split-divider'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onVerticalDragStart: isStacked ? (_) => _handleStart() : null,
        onVerticalDragUpdate: isStacked
            ? (details) => widget.onDragUpdate(details.delta.dy)
            : null,
        onVerticalDragEnd: isStacked ? (_) => _handleEnd() : null,
        onVerticalDragCancel: isStacked ? _handleEnd : null,
        onHorizontalDragStart: isStacked ? null : (_) => _handleStart(),
        onHorizontalDragUpdate: isStacked
            ? null
            : (details) => widget.onDragUpdate(details.delta.dx),
        onHorizontalDragEnd: isStacked ? null : (_) => _handleEnd(),
        onHorizontalDragCancel: isStacked ? null : _handleEnd,
        child: SizedBox(
          width: isStacked ? double.infinity : thickness,
          height: isStacked ? thickness : double.infinity,
          child: Center(child: grip),
        ),
      ),
    );
  }
}

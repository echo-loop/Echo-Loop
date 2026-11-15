import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/practice_media_split_provider.dart';
import '../../services/app_logger.dart';
import 'practice_media_split_geometry.dart';

/// 学习任务页「视频 + 学习内容」的自适应分栏。
///
/// 根据实际可用空间在上下 / 左右布局间切换（规则见
/// [PracticeMediaSplitGeometry]），中间的分隔条可拖动调整视频高度或宽度，
/// 松手后按方向记住比例。双击分隔条恢复默认尺寸。
class PracticeMediaSplitLayout extends ConsumerStatefulWidget {
  const PracticeMediaSplitLayout({
    super.key,
    required this.media,
    required this.isMediaResizable,
    required this.videoAspectRatio,
    required this.content,
    this.panelHostBuilder,
  });

  /// 视频画面；null 表示纯音频任务，只显示学习内容。
  final Widget? media;

  /// 视频轨可见时才可分栏和拖动；隐藏后 [media] 是一条固定高度的恢复条。
  final bool isMediaResizable;

  /// 视频宽高比，用于限制视频最大尺寸以免出现多余黑边；未知时为 null。
  final double? videoAspectRatio;

  /// 学习内容（进度、句子、底栏）。
  final Widget content;

  /// 包裹浮层宿主（如词典面板）。上下布局包住整页，保持面板原有覆盖范围；
  /// 左右布局只包右侧学习内容，面板不会盖住视频。
  final Widget Function(Widget child)? panelHostBuilder;

  @override
  ConsumerState<PracticeMediaSplitLayout> createState() =>
      _PracticeMediaSplitLayoutState();
}

class _PracticeMediaSplitLayoutState
    extends ConsumerState<PracticeMediaSplitLayout> {
  // 跨越断点时视频与学习内容会在 Column / Row 间移动；GlobalKey 让它们
  // 保留状态（视频纹理、句子分页位置、词典面板）而不是销毁重建。
  final _mediaKey = GlobalKey(debugLabel: 'practice-media-split-media');
  final _contentKey = GlobalKey(debugLabel: 'practice-media-split-content');

  /// 拖动中的视频尺寸，只存在于拖动期间；松手后写入偏好并清空。
  double? _dragExtent;

  Widget _wrapPanelHost(Widget child) =>
      widget.panelHostBuilder?.call(child) ?? child;

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _contentKey, child: widget.content);
    final media = widget.media;
    if (media == null) return _wrapPanelHost(content);

    final keyedMedia = KeyedSubtree(key: _mediaKey, child: media);
    if (!widget.isMediaResizable) {
      return _wrapPanelHost(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            keyedMedia,
            Expanded(child: content),
          ],
        ),
      );
    }

    final split = ref.watch(practiceMediaSplitProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final axis = PracticeMediaSplitGeometry.resolveAxis(size);
        final range = PracticeMediaSplitGeometry.extentRange(
          axis: axis,
          size: size,
          videoAspectRatio: widget.videoAspectRatio,
        );
        final extent = _dragExtent != null
            ? range.clamp(_dragExtent!)
            : PracticeMediaSplitGeometry.resolveVideoExtent(
                axis: axis,
                range: range,
                fraction: split.fractionFor(axis),
              );
        final divider = _PracticeMediaSplitDivider(
          axis: axis,
          onDragStart: () => setState(() => _dragExtent = extent),
          onDragUpdate: (delta) => setState(
            () => _dragExtent = range.clamp((_dragExtent ?? extent) + delta),
          ),
          onDragEnd: () => _commitDrag(axis, range),
          onReset: () => _resetExtent(axis),
        );

        return switch (axis) {
          PracticeMediaSplitAxis.stacked => _wrapPanelHost(
            Column(
              key: const ValueKey('practice-media-split-stacked'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: extent,
                  child: _fitMedia(keyedMedia, Size(size.width, extent)),
                ),
                divider,
                Expanded(child: content),
              ],
            ),
          ),
          PracticeMediaSplitAxis.sideBySide => Row(
            key: const ValueKey('practice-media-split-side-by-side'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: extent,
                child: _fitMedia(keyedMedia, Size(extent, size.height)),
              ),
              divider,
              Expanded(child: _wrapPanelHost(content)),
            ],
          ),
        };
      },
    );
  }

  /// 画面容器按视频比例贴合，居中放在分给视频的区域里。
  Widget _fitMedia(Widget media, Size box) => Center(
    child: SizedBox.fromSize(
      size: PracticeMediaSplitGeometry.fittedVideoSize(
        box,
        widget.videoAspectRatio,
      ),
      child: media,
    ),
  );

  void _commitDrag(
    PracticeMediaSplitAxis axis,
    PracticeMediaExtentRange range,
  ) {
    final dragExtent = _dragExtent;
    setState(() => _dragExtent = null);
    if (dragExtent == null) return;
    final fraction = range.fractionOf(range.clamp(dragExtent));
    if (fraction == null) return;
    AppLogger.log(
      'PracticeMediaLayout',
      '保存视频尺寸: axis=${axis.name}, '
          'fraction=${fraction.toStringAsFixed(3)}',
    );
    ref
        .read(practiceMediaSplitProvider.notifier)
        .setVideoFraction(axis, fraction);
  }

  void _resetExtent(PracticeMediaSplitAxis axis) {
    AppLogger.log('PracticeMediaLayout', '恢复默认视频尺寸: axis=${axis.name}');
    ref.read(practiceMediaSplitProvider.notifier).setVideoFraction(axis, null);
  }
}

/// 视频与学习内容之间的拖动分隔条：整条都是热区，中间的短条是视觉提示。
class _PracticeMediaSplitDivider extends StatefulWidget {
  const _PracticeMediaSplitDivider({
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
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  @override
  State<_PracticeMediaSplitDivider> createState() =>
      _PracticeMediaSplitDividerState();
}

class _PracticeMediaSplitDividerState
    extends State<_PracticeMediaSplitDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

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

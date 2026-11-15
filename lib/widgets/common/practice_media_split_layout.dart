import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/practice_media_split_provider.dart';
import '../../services/app_logger.dart';
import 'media_startup_canvas.dart';
import 'media_startup_status.dart';
import 'practice_media_split_geometry.dart';

/// 学习任务页与随心听「视频 + 学习内容」的自适应分栏。
///
/// 根据实际可用空间在上下 / 左右布局间切换（规则见
/// [PracticeMediaSplitGeometry]），中间的分隔条可拖动调整视频高度或宽度，
/// 松手后按方向记住比例。双击分隔条恢复默认尺寸。
///
/// 视频任务加载期间传入 [startupStatus]：加载 / 失败占位画在视频槽内，
/// 学习内容保持真实布局但淡化且不可交互，ready 后布局不跳变。
class PracticeMediaSplitLayout extends ConsumerStatefulWidget {
  const PracticeMediaSplitLayout({
    super.key,
    required this.media,
    required this.isMediaResizable,
    required this.videoAspectRatio,
    required this.content,
    this.panelHostBuilder,
    this.startupStatus,
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

  /// 视频任务的启动状态；null 表示没有托管加载（音频任务或已直接可用）。
  ///
  /// 加载期间学习会话可能尚未初始化，[media] 往往为 null，因此视频槽由占位
  /// 自己撑起，并强制按可分栏处理，否则会退化为无视频的单栏（troubleshooting 7.50）。
  final MediaStartupStatus? startupStatus;

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
  final _mediaSurfaceKey = GlobalKey(
    debugLabel: 'practice-media-split-media-surface',
  );

  /// 拖动中的视频尺寸，只存在于拖动期间；松手后写入偏好并清空。
  double? _dragExtent;

  /// 上一次排版使用的分栏方向，仅用于在方向切换时记录一次日志。
  PracticeMediaSplitAxis? _loggedAxis;

  Widget _wrapPanelHost(Widget child) =>
      widget.panelHostBuilder?.call(child) ?? child;

  @override
  Widget build(BuildContext context) {
    final status = widget.startupStatus;
    final loadingStatus = status != null && !status.isReady ? status : null;
    final content = KeyedSubtree(
      key: _contentKey,
      child: _StartupContentGate(
        isReady: loadingStatus == null,
        child: widget.content,
      ),
    );
    // 加载期间视频外层多一个叠放占位的 Stack；单独的 GlobalKey 让视频画面在
    // ready 去掉 Stack 时原样保留，而不是销毁重建（纹理、遮罩重新挂载）。
    final rawMedia = widget.media;
    final stableMedia = rawMedia == null
        ? null
        : KeyedSubtree(key: _mediaSurfaceKey, child: rawMedia);
    final media = loadingStatus == null
        ? stableMedia
        : Stack(
            fit: StackFit.expand,
            children: [
              ?stableMedia,
              MediaStartupCanvas(status: loadingStatus),
            ],
          );
    if (media == null) return _wrapPanelHost(content);

    final keyedMedia = KeyedSubtree(key: _mediaKey, child: media);
    if (!widget.isMediaResizable && loadingStatus == null) {
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
        _logAxisChange(axis, size, split.fractionFor(axis));
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

  /// 窗口缩放或旋转跨越断点时记录方向切换，便于把视频重建等现象对应到布局变化；
  /// 同时记录该方向恢复的视频比例（default 表示未调整过）。
  void _logAxisChange(
    PracticeMediaSplitAxis axis,
    Size size,
    double? savedFraction,
  ) {
    if (_loggedAxis == axis) return;
    AppLogger.log(
      'PracticeMediaLayout',
      '分栏方向: ${_loggedAxis?.name ?? 'initial'} → ${axis.name}, '
          'size=${size.width.toStringAsFixed(0)}x'
          '${size.height.toStringAsFixed(0)}, '
          'fraction=${savedFraction?.toStringAsFixed(3) ?? 'default'}',
    );
    _loggedAxis = axis;
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
    // 拖到上下限后再次拖动时比例不变，跳过重复写入。
    final savedFraction = ref
        .read(practiceMediaSplitProvider)
        .fractionFor(axis);
    if (savedFraction != null && (savedFraction - fraction).abs() < 0.001) {
      return;
    }
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

/// 视频加载期间保留学习内容的真实布局，但淡化并禁止点击，避免媒体未就绪时切句或播放。
class _StartupContentGate extends StatelessWidget {
  const _StartupContentGate({required this.isReady, required this.child});

  final bool isReady;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return IgnorePointer(
      ignoring: !isReady,
      child: AnimatedOpacity(
        opacity: isReady ? 1 : 0.5,
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: child,
      ),
    );
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

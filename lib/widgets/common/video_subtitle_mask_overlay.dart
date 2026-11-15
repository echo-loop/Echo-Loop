import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/video_subtitle_mask.dart';

/// 计算视频按 [BoxFit.contain] 绘制后在视口中的实际画面区域（不含黑边）。
///
/// 宽高比未知时退回整个视口。
Rect videoContentRect(Size viewport, double? videoAspectRatio) {
  final viewportRect = Offset.zero & viewport;
  if (videoAspectRatio == null ||
      !videoAspectRatio.isFinite ||
      videoAspectRatio <= 0) {
    return viewportRect;
  }
  final fitted = applyBoxFit(
    BoxFit.contain,
    Size(videoAspectRatio, 1),
    viewport,
  ).destination;
  return Alignment.center.inscribe(fitted, viewportRect);
}

/// 遮罩四条边上的调整手柄。
enum VideoSubtitleMaskEdge { left, top, right, bottom }

/// 视频画面上的半透明磨砂遮罩，用于遮住烧录在画面里的原字幕。
///
/// 单指拖动移动、双指捏合等比缩放、拖动四边中点的手柄调整对应边。拖动过程
/// 只更新本地草稿，松手后通过 [onRectChanged] 提交一次，避免每帧写持久化。
/// 必须放在与 [contentRect] 同坐标系的全尺寸 Stack 中。
class VideoSubtitleMaskOverlay extends StatefulWidget {
  const VideoSubtitleMaskOverlay({
    super.key,
    required this.normalizedRect,
    required this.contentRect,
    required this.onRectChanged,
    required this.onInteractionStart,
  });

  /// 相对 [contentRect] 的归一化位置。
  final Rect normalizedRect;

  /// 视频实际画面区域（像素）。
  final Rect contentRect;

  final ValueChanged<Rect> onRectChanged;

  /// 用户开始点按或拖动遮罩；画面借此收起播放控件，避免与手柄重叠。
  final VoidCallback onInteractionStart;

  @override
  State<VideoSubtitleMaskOverlay> createState() =>
      _VideoSubtitleMaskOverlayState();
}

class _VideoSubtitleMaskOverlayState extends State<VideoSubtitleMaskOverlay> {
  static const _tintAlpha = 0.45;
  static const _borderRadius = BorderRadius.all(Radius.circular(8));

  /// 手柄触控区：沿边方向的长度与垂直于边方向的厚度（逻辑像素）。
  static const _gripTouchLength = 44.0;
  static const _gripTouchThickness = 32.0;

  /// 手柄触控区伸进遮罩内部的深度；其余部分在遮罩外，最小尺寸下上下 / 左右
  /// 两个手柄也不会重叠。
  static const _gripInset = 10.0;

  /// 遮罩最小像素尺寸，保证缩小后仍能拖动和调整。
  static const _minPixelWidth = 56.0;
  static const _minPixelHeight = 2 * _gripInset + 4;

  /// 松手后边框与手柄继续显示的时长，便于连续微调。
  static const _frameHoldDuration = Duration(seconds: 2);

  /// 遮罩内的触摸判定阈值（逻辑像素）。
  ///
  /// 默认 Scale 手势要移动 36px（2 × kTouchSlop）才开始响应，在小尺寸视频
  /// 画面里表现为“按住拖不动、突然才跟手”；遮罩只承载拖动 / 缩放，调低即可。
  static const _maskGestureSettings = DeviceGestureSettings(touchSlop: 4);

  /// 手势进行中的归一化位置；为 null 时显示已提交的位置。
  Rect? _draftRect;
  Rect _gestureStartRect = Rect.zero;
  Offset _gestureStartFocal = Offset.zero;
  bool _isFrameHeld = false;
  Timer? _frameHoldTimer;

  Rect get _currentRect => _draftRect ?? widget.normalizedRect;

  Size get _contentSize => widget.contentRect.size;

  /// 归一化最小宽高：取模型下限与像素下限中较大者，且不超过 [current]。
  ///
  /// 像素下限随画面大小变化：在全屏里缩小的遮罩回到小窗口后，可能已经小于
  /// 当前画面的像素下限。此时以当前尺寸为下限（只能放大、不能再缩小），保证
  /// clamp 的下限不超过上限，否则 clamp 会抛 ArgumentError。
  Size _minNormalizedSizeFor(Size current) {
    final size = _contentSize;
    return Size(
      math.min(
        current.width,
        math.max(
          VideoSubtitleMask.minNormalizedSize,
          _minPixelWidth / size.width,
        ),
      ),
      math.min(
        current.height,
        math.max(
          VideoSubtitleMask.minNormalizedSize,
          _minPixelHeight / size.height,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // 遮罩出现时短暂显示手柄，提示可以拖动和调整大小。
    _isFrameHeld = true;
    _frameHoldTimer = Timer(_frameHoldDuration, _releaseFrame);
  }

  @override
  void dispose() {
    _frameHoldTimer?.cancel();
    super.dispose();
  }

  void _releaseFrame() {
    if (mounted) setState(() => _isFrameHeld = false);
  }

  /// 点按或操作遮罩后短暂显示边框与手柄。
  void _holdFrame() {
    _frameHoldTimer?.cancel();
    setState(() => _isFrameHeld = true);
    _frameHoldTimer = Timer(_frameHoldDuration, _releaseFrame);
  }

  void _handleTap() {
    widget.onInteractionStart();
    _holdFrame();
  }

  void _startGesture(Offset focalPoint) {
    widget.onInteractionStart();
    _frameHoldTimer?.cancel();
    _gestureStartRect = _currentRect;
    _gestureStartFocal = focalPoint;
    setState(() {
      _isFrameHeld = true;
      _draftRect = _gestureStartRect;
    });
  }

  void _updateMoveOrPinch(ScaleUpdateDetails details) {
    final size = _contentSize;
    if (size.isEmpty) return;
    final start = _gestureStartRect;
    final minSize = _minNormalizedSizeFor(start.size);
    final delta = details.focalPoint - _gestureStartFocal;
    final scale = details.pointerCount > 1 ? details.scale : 1.0;
    final center =
        start.center + Offset(delta.dx / size.width, delta.dy / size.height);
    final width = (start.width * scale).clamp(minSize.width, 1.0);
    final height = (start.height * scale).clamp(minSize.height, 1.0);
    setState(() {
      _draftRect = VideoSubtitleMask.clampRect(
        Rect.fromCenter(center: center, width: width, height: height),
      );
    });
  }

  /// 拖动某条边：只移动该边，对边保持不动。
  void _updateEdge(VideoSubtitleMaskEdge edge, DragUpdateDetails details) {
    final size = _contentSize;
    if (size.isEmpty) return;
    final start = _gestureStartRect;
    final minSize = _minNormalizedSizeFor(start.size);
    final delta = details.globalPosition - _gestureStartFocal;
    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;
    final next = switch (edge) {
      VideoSubtitleMaskEdge.left => Rect.fromLTRB(
        (start.left + dx).clamp(0.0, start.right - minSize.width),
        start.top,
        start.right,
        start.bottom,
      ),
      VideoSubtitleMaskEdge.right => Rect.fromLTRB(
        start.left,
        start.top,
        (start.right + dx).clamp(start.left + minSize.width, 1.0),
        start.bottom,
      ),
      VideoSubtitleMaskEdge.top => Rect.fromLTRB(
        start.left,
        (start.top + dy).clamp(0.0, start.bottom - minSize.height),
        start.right,
        start.bottom,
      ),
      VideoSubtitleMaskEdge.bottom => Rect.fromLTRB(
        start.left,
        start.top,
        start.right,
        (start.bottom + dy).clamp(start.top + minSize.height, 1.0),
      ),
    };
    setState(() => _draftRect = next);
  }

  void _commit() {
    final draft = _draftRect;
    if (draft == null) return;
    widget.onRectChanged(draft);
    setState(() => _draftRect = null);
    _holdFrame();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _currentRect;
    final content = widget.contentRect;
    final maskRect = Rect.fromLTWH(
      content.left + normalized.left * content.width,
      content.top + normalized.top * content.height,
      normalized.width * content.width,
      normalized.height * content.height,
    );
    final showFrame = _isFrameHeld || _draftRect != null;
    // 全屏时字幕字号更大，模糊半径随遮罩高度放大，确保文字轮廓不可辨认。
    final blurSigma = (maskRect.height * 0.2).clamp(10.0, 24.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Offset.zero & constraints.biggest;
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(gestureSettings: _maskGestureSettings),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: maskRect,
                child: Semantics(
                  key: const ValueKey('video-subtitle-mask'),
                  label: AppLocalizations.of(context)!.mediaSubtitleMaskLabel,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleTap,
                      onScaleStart: (details) =>
                          _startGesture(details.focalPoint),
                      onScaleUpdate: _updateMoveOrPinch,
                      onScaleEnd: (_) => _commit(),
                      child: ClipRRect(
                        borderRadius: _borderRadius,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: blurSigma,
                            sigmaY: blurSigma,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: _tintAlpha),
                              borderRadius: _borderRadius,
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: showFrame ? 0.85 : 0.0,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showFrame)
                for (final edge in VideoSubtitleMaskEdge.values)
                  _buildGrip(edge, maskRect, bounds),
            ],
          ),
        );
      },
    );
  }

  /// 手柄触控区跨在边上（大部分在遮罩外），并收进画面范围，贴边时不被裁掉。
  Widget _buildGrip(VideoSubtitleMaskEdge edge, Rect maskRect, Rect bounds) {
    final isHorizontalEdge =
        edge == VideoSubtitleMaskEdge.top ||
        edge == VideoSubtitleMaskEdge.bottom;
    final touchSize = isHorizontalEdge
        ? const Size(_gripTouchLength, _gripTouchThickness)
        : const Size(_gripTouchThickness, _gripTouchLength);
    final outside = _gripTouchThickness - _gripInset;
    final touchRect = switch (edge) {
      VideoSubtitleMaskEdge.left => Rect.fromLTWH(
        maskRect.left - outside,
        maskRect.center.dy - touchSize.height / 2,
        touchSize.width,
        touchSize.height,
      ),
      VideoSubtitleMaskEdge.right => Rect.fromLTWH(
        maskRect.right - _gripInset,
        maskRect.center.dy - touchSize.height / 2,
        touchSize.width,
        touchSize.height,
      ),
      VideoSubtitleMaskEdge.top => Rect.fromLTWH(
        maskRect.center.dx - touchSize.width / 2,
        maskRect.top - outside,
        touchSize.width,
        touchSize.height,
      ),
      VideoSubtitleMaskEdge.bottom => Rect.fromLTWH(
        maskRect.center.dx - touchSize.width / 2,
        maskRect.bottom - _gripInset,
        touchSize.width,
        touchSize.height,
      ),
    };
    final clampedRect = touchRect.shift(
      Offset(
        _overflowCorrection(touchRect.left, touchRect.right, bounds.width),
        _overflowCorrection(touchRect.top, touchRect.bottom, bounds.height),
      ),
    );
    // 手柄小圆条始终画在边线上，触控区平移时反向补偿。
    final edgePoint = switch (edge) {
      VideoSubtitleMaskEdge.left => maskRect.centerLeft,
      VideoSubtitleMaskEdge.right => maskRect.centerRight,
      VideoSubtitleMaskEdge.top => maskRect.topCenter,
      VideoSubtitleMaskEdge.bottom => maskRect.bottomCenter,
    };
    final pillSize = isHorizontalEdge ? const Size(24, 5) : const Size(5, 24);
    final pillCenter = edgePoint - clampedRect.topLeft;
    return Positioned.fromRect(
      rect: clampedRect,
      child: MouseRegion(
        cursor: isHorizontalEdge
            ? SystemMouseCursors.resizeUpDown
            : SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: ValueKey('video-subtitle-mask-grip-${edge.name}'),
          behavior: HitTestBehavior.opaque,
          // 以按下点为起点，越过判定阈值的那段位移也计入，手柄始终贴着手指。
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) => _startGesture(details.globalPosition),
          onPanUpdate: (details) => _updateEdge(edge, details),
          onPanEnd: (_) => _commit(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: Rect.fromCenter(
                  center: pillCenter,
                  width: pillSize.width,
                  height: pillSize.height,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 区间 [start, end] 超出 [0, limit] 时需要平移的距离。
  static double _overflowCorrection(double start, double end, double limit) {
    if (start < 0) return -start;
    if (end > limit) return limit - end;
    return 0;
  }
}

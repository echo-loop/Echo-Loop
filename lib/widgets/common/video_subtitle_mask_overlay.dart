import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/video_subtitle_mask.dart';
import '../../services/app_logger.dart';

const _logTag = 'VideoSubtitleMask';

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
///
/// 边框与手柄只在“激发态”下显示，激发来源有三种：开关从关到开、点按或拖动
/// 之后保持 2 秒、鼠标悬浮。挂载本身（打开视频、窗口跨越布局断点导致重建）
/// 不是用户操作，不会激发。
class VideoSubtitleMaskOverlay extends StatefulWidget {
  const VideoSubtitleMaskOverlay({
    super.key,
    required this.normalizedRect,
    required this.contentRect,
    required this.isEnabled,
    required this.onRectChanged,
    required this.onInteractionStart,
  });

  /// 相对 [contentRect] 的归一化位置。
  final Rect normalizedRect;

  /// 视频实际画面区域（像素）。
  final Rect contentRect;

  /// 字幕遮罩开关；为 false 时不渲染任何内容。
  final bool isEnabled;

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

  /// 定时保持：开关打开、点按或拖动结束后显示 [_frameHoldDuration]。
  bool _isFrameHeld = false;
  Timer? _frameHoldTimer;

  /// 鼠标是否悬浮在遮罩及手柄区域内；触屏设备不会产生悬浮事件。
  bool _isPointerInside = false;

  Rect get _currentRect => _draftRect ?? widget.normalizedRect;

  /// 激发态：边框与手柄是否显示，由定时保持、悬浮与拖动三种来源共同决定。
  bool get _isFrameActive =>
      _isFrameHeld || _isPointerInside || _draftRect != null;

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
    // 挂载不是用户操作，不显示手柄。打开视频、窗口跨越布局断点都会重建本组件，
    // 日志里的挂载记录用于判断手柄异常出现是否由重建引起。
    AppLogger.log(_logTag, '遮罩组件挂载 enabled=${widget.isEnabled}');
  }

  @override
  void didUpdateWidget(VideoSubtitleMaskOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnabled == widget.isEnabled) return;
    // 开关变化是唯一由状态切换激发手柄的入口；关闭时清空全部激发来源。
    final wasActive = _isFrameActive;
    if (widget.isEnabled) {
      _holdFrame();
    } else {
      _frameHoldTimer?.cancel();
      _isFrameHeld = false;
      _isPointerInside = false;
      _draftRect = null;
    }
    _logFrameActiveChange(wasActive, widget.isEnabled ? '遮罩开启' : '遮罩关闭');
  }

  @override
  void dispose() {
    _frameHoldTimer?.cancel();
    super.dispose();
  }

  /// 修改激发态相关字段并刷新界面，激发态真正变化时记录原因。
  void _updateFrameState(String reason, VoidCallback change) {
    final wasActive = _isFrameActive;
    setState(change);
    _logFrameActiveChange(wasActive, reason);
  }

  void _logFrameActiveChange(bool wasActive, String reason) {
    final isActive = _isFrameActive;
    if (isActive == wasActive) return;
    AppLogger.log(_logTag, '遮罩激发态${isActive ? '开启' : '关闭'} 原因=$reason');
  }

  /// 保持显示并重新计时；须在 [_updateFrameState] 或 didUpdateWidget 中调用。
  void _holdFrame() {
    _isFrameHeld = true;
    _frameHoldTimer?.cancel();
    _frameHoldTimer = Timer(_frameHoldDuration, _releaseFrame);
  }

  void _releaseFrame() {
    if (!mounted) return;
    _updateFrameState('保持时间结束', () => _isFrameHeld = false);
  }

  void _handleTap() {
    widget.onInteractionStart();
    _updateFrameState('点按遮罩', _holdFrame);
  }

  void _setPointerInside(bool isInside) {
    if (isInside == _isPointerInside) return;
    _updateFrameState(
      isInside ? '鼠标悬浮' : '鼠标移出',
      () => _isPointerInside = isInside,
    );
  }

  /// 悬浮判定区域是遮罩外扩手柄触控区的部分，鼠标从遮罩移到手柄上不会丢失激发态。
  void _updatePointerPosition(Offset localPosition) {
    final hoverZone = _maskRectFor(_currentRect)
        .inflate(_gripTouchThickness - _gripInset);
    _setPointerInside(hoverZone.contains(localPosition));
  }

  void _startGesture(Offset focalPoint) {
    widget.onInteractionStart();
    _gestureStartRect = _currentRect;
    _gestureStartFocal = focalPoint;
    _updateFrameState('开始拖动', () {
      _frameHoldTimer?.cancel();
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
    _updateFrameState('拖动结束', () {
      _draftRect = null;
      _holdFrame();
    });
  }

  /// 归一化位置对应的遮罩像素区域（相对本组件左上角）。
  Rect _maskRectFor(Rect normalized) {
    final content = widget.contentRect;
    return Rect.fromLTWH(
      content.left + normalized.left * content.width,
      content.top + normalized.top * content.height,
      normalized.width * content.width,
      normalized.height * content.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();
    final maskRect = _maskRectFor(_currentRect);
    final showFrame = _isFrameActive;
    // 全屏时字幕字号更大，模糊半径随遮罩高度放大，确保文字轮廓不可辨认。
    final blurSigma = (maskRect.height * 0.2).clamp(10.0, 24.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Offset.zero & constraints.biggest;
        // opaque: false 让悬浮判定不吞掉画面上的其他悬浮事件（控件显示等）。
        return MouseRegion(
          opaque: false,
          onEnter: (event) => _updatePointerPosition(event.localPosition),
          onHover: (event) => _updatePointerPosition(event.localPosition),
          onExit: (_) => _setPointerInside(false),
          child: MediaQuery(
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
                                color: Colors.black.withValues(
                                  alpha: _tintAlpha,
                                ),
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

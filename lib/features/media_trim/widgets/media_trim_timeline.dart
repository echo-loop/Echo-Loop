import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:just_waveform/just_waveform.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/waveform_samples.dart';
import '../media_trim_clip.dart';
import 'media_trim_format.dart';

/// 时间轴的坐标换算：唯一的时间 ↔ 像素真相源，波形、片段、把手和播放头都经它计算。
class _TimelineMetrics {
  const _TimelineMetrics({
    required this.viewport,
    required this.zoom,
    required this.total,
  });

  /// 两侧留白，保证位于首尾的把手也能完整显示和抓取。
  static const double padding = 14;

  final double viewport;
  final double zoom;
  final Duration total;

  double get usable => math.max(0, viewport - padding * 2) * zoom;
  double get maxOffset => math.max(0, usable + padding * 2 - viewport);

  double contentX(Duration time) {
    final micros = total.inMicroseconds;
    if (micros <= 0) return padding;
    return padding + usable * (time.inMicroseconds / micros).clamp(0.0, 1.0);
  }

  double screenX(Duration time, double offset) => contentX(time) - offset;

  Duration timeAt(double screenX, double offset) {
    if (usable <= 0) return Duration.zero;
    final fraction = ((screenX + offset - padding) / usable).clamp(0.0, 1.0);
    return Duration(microseconds: (total.inMicroseconds * fraction).round());
  }

  double clampOffset(double offset) => offset.clamp(0.0, maxOffset);
}

/// 剪辑时间轴：显示整段波形、全部片段、当前片段把手与播放头。
///
/// 交互参照系统相册的视频裁剪：选中片段后播放头只在片段内移动；轻点当前片段外
/// 会选中所点的其它片段，落在空白处则取消选中并定位；播放头可以直接拖动；拖动把手
/// 时隐藏播放头，松手后播放头停在刚调整的一端。拖动空白处平移；双指捏合、触控板
/// 捏合或 Ctrl/⌘ + 滚轮缩放；放大后滚轮平移。
class MediaTrimTimeline extends StatefulWidget {
  const MediaTrimTimeline({
    super.key,
    required this.waveform,
    required this.waveformProgress,
    required this.isWaveformFailed,
    required this.onRetryWaveform,
    required this.total,
    required this.spans,
    required this.clips,
    required this.selectedClipId,
    required this.revealSerial,
    required this.position,
    required this.isPlaying,
    required this.onSeek,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onSelectClip,
    required this.onClearSelection,
    required this.onEdgeDrag,
    required this.onEdgeDragEnd,
    this.height = 128,
  });

  final Waveform? waveform;
  final double waveformProgress;
  final bool isWaveformFailed;
  final VoidCallback onRetryWaveform;
  final Duration total;
  final List<MediaTrimSentenceSpan> spans;
  final List<MediaTrimClip> clips;
  final int? selectedClipId;

  /// 变化时把当前片段滚入视口（包括重复选中同一片段）。
  final int revealSerial;
  final Duration position;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;

  /// 拖动播放头的过程与结束。
  final ValueChanged<Duration> onScrub;
  final VoidCallback onScrubEnd;

  /// 点选片段，并把播放头定位到点按处。
  final void Function(int clipId, Duration at) onSelectClip;
  final VoidCallback onClearSelection;
  final void Function(MediaTrimEdge edge, Duration time) onEdgeDrag;
  final ValueChanged<MediaTrimEdge> onEdgeDragEnd;
  final double height;

  @override
  State<MediaTrimTimeline> createState() => _MediaTrimTimelineState();
}

class _MediaTrimTimelineState extends State<MediaTrimTimeline> {
  /// 放大到最大时每秒占用的像素，足够精确到百毫秒。
  static const double _maxPixelsPerSecond = 120;
  static const double _zoomStep = 1.8;

  double _zoom = 1;
  double _offset = 0;
  double _viewport = 0;
  WaveformSamples? _samples;
  MouseCursor _cursor = SystemMouseCursors.click;

  MediaTrimEdge? _draggingEdge;
  bool _isScrubbing = false;
  bool _isPanning = false;
  double _scaleStartZoom = 1;
  int _activePointers = 0;

  /// 最近一次按下的位置。拖动识别要越过阈值才回调开始，届时指针已离开把手，
  /// 因此把手命中必须用按下位置判断。
  Offset? _downPosition;
  PointerDeviceKind _pointerKind = PointerDeviceKind.touch;

  /// 缩放时保持不动的锚点：屏幕 x 与其对应时间。
  ({double x, Duration time})? _zoomAnchor;

  _TimelineMetrics get _metrics =>
      _TimelineMetrics(viewport: _viewport, zoom: _zoom, total: widget.total);

  double get _maxZoom {
    final usable = _viewport - _TimelineMetrics.padding * 2;
    if (usable <= 0 || widget.total <= Duration.zero) return 1;
    final seconds = widget.total.inMicroseconds / 1000000;
    return math.max(1, seconds * _maxPixelsPerSecond / usable);
  }

  MediaTrimClip? get _selectedClip {
    for (final clip in widget.clips) {
      if (clip.id == widget.selectedClipId) return clip;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _samples = _samplesOf(widget.waveform);
  }

  @override
  void didUpdateWidget(MediaTrimTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.waveform, widget.waveform)) {
      _samples = _samplesOf(widget.waveform);
    }
    if (_viewport <= 0 || _draggingEdge != null || _isScrubbing) return;
    final metrics = _metrics;
    if (widget.revealSerial != oldWidget.revealSerial) {
      final clip = _selectedClip;
      if (clip != null) _reveal(clip.start, clip.end, metrics);
    } else if (widget.isPlaying && widget.position != oldWidget.position) {
      // 播放时播放头离开视口就翻页，翻页后播放头位于左侧 15% 处。
      final x = metrics.screenX(widget.position, _offset);
      if (x < 0 || x > _viewport - _TimelineMetrics.padding) {
        _offset = metrics.clampOffset(
          metrics.contentX(widget.position) - _viewport * 0.15,
        );
      }
    }
  }

  /// 让 [start, end] 尽量完整可见；放不下时让起点靠左显示。
  void _reveal(Duration start, Duration end, _TimelineMetrics metrics) {
    final left = metrics.screenX(start, _offset);
    final right = metrics.screenX(end, _offset);
    if (left >= 0 && right <= _viewport) return;
    final width = right - left;
    final target = width < _viewport * 0.8
        ? metrics.contentX(start) - (_viewport - width) / 2
        : metrics.contentX(start) - _viewport * 0.1;
    _offset = metrics.clampOffset(target);
  }

  static WaveformSamples? _samplesOf(Waveform? waveform) =>
      waveform == null ? null : WaveformSamples(waveform);

  void _setZoom(double zoom, {double? anchorX}) {
    final clamped = zoom.clamp(1.0, _maxZoom).toDouble();
    if (clamped == _zoom) return;
    final x = anchorX ?? _anchorXForButtons();
    final anchorTime = _metrics.timeAt(x, _offset);
    setState(() {
      _zoom = clamped;
      final metrics = _metrics;
      _offset = metrics.clampOffset(metrics.contentX(anchorTime) - x);
    });
  }

  /// 按钮缩放时，播放头可见则以它为锚点，否则以视口中心为锚点。
  double _anchorXForButtons() {
    final x = _metrics.screenX(widget.position, _offset);
    return x >= 0 && x <= _viewport ? x : _viewport / 2;
  }

  /// 放大到当前片段占视口约 80%，并居中显示。
  void _fitSelectedClip() {
    final clip = _selectedClip;
    final usable = _viewport - _TimelineMetrics.padding * 2;
    if (clip == null || usable <= 0 || clip.duration <= Duration.zero) return;
    final ratio = widget.total.inMicroseconds / clip.duration.inMicroseconds;
    setState(() {
      _zoom = (ratio * 0.8).clamp(1.0, _maxZoom).toDouble();
      final metrics = _metrics;
      final center =
          (metrics.contentX(clip.start) + metrics.contentX(clip.end)) / 2;
      _offset = metrics.clampOffset(center - _viewport / 2);
    });
  }

  void _panBy(double dx) {
    setState(() => _offset = _metrics.clampOffset(_offset - dx));
  }

  /// 鼠标精确，命中区小；触摸需要更大的命中区。
  static double _slopFor(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ? 8.0 : 18.0;

  bool _hitPlayhead(double x, PointerDeviceKind kind) =>
      (_metrics.screenX(widget.position, _offset) - x).abs() <= _slopFor(kind);

  /// 播放头与把手重叠时（例如刚拖完把手），按在顶部标签行抓播放头，其余位置抓把手。
  bool _prefersPlayhead(Offset position, PointerDeviceKind kind) =>
      _hitPlayhead(position.dx, kind) &&
      (position.dy <= _TimelinePainter.labelLane + 4 ||
          _hitEdge(position.dx, kind) == null);

  MediaTrimEdge? _hitEdge(double x, PointerDeviceKind kind) {
    final clip = _selectedClip;
    if (clip == null) return null;
    final metrics = _metrics;
    final slop = _slopFor(kind);
    final startDistance = (metrics.screenX(clip.start, _offset) - x).abs();
    final endDistance = (metrics.screenX(clip.end, _offset) - x).abs();
    if (startDistance > slop && endDistance > slop) return null;
    return startDistance <= endDistance
        ? MediaTrimEdge.start
        : MediaTrimEdge.end;
  }

  void _handleTap(TapUpDetails details) {
    final time = _metrics.timeAt(details.localPosition.dx, _offset);
    final selected = _selectedClip;
    if (selected != null && time >= selected.start && time <= selected.end) {
      widget.onSeek(time);
      return;
    }
    MediaTrimClip? candidate;
    for (final clip in widget.clips) {
      if (clip.containsTime(time) &&
          (candidate == null || clip.duration < candidate.duration)) {
        candidate = clip;
      }
    }
    if (candidate != null) {
      widget.onSelectClip(candidate.id, time);
      return;
    }
    // 落在所有片段之外：取消选中，播放头恢复自由定位。
    if (selected != null) widget.onClearSelection();
    widget.onSeek(time);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _scaleStartZoom = _zoom;
    _zoomAnchor = null;
    _draggingEdge = null;
    _isScrubbing = false;
    _isPanning = false;
    if (details.pointerCount != 1 || _activePointers > 1) return;
    final down = _downPosition ?? details.localFocalPoint;
    if (_prefersPlayhead(down, _pointerKind)) {
      setState(() => _isScrubbing = true);
      return;
    }
    final edge = _hitEdge(down.dx, _pointerKind);
    if (edge != null) {
      // 拖动把手时隐藏播放头，需要重绘。
      setState(() => _draggingEdge = edge);
      return;
    }
    if (_metrics.maxOffset > 0) {
      _isPanning = true;
      return;
    }
    // 未放大时无处可平移：在空白处拖动直接从按下处开始拖动播放头。
    setState(() => _isScrubbing = true);
    widget.onScrub(_metrics.timeAt(down.dx, _offset));
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final edge = _draggingEdge;
    if (edge != null || _isScrubbing) {
      final x = details.localFocalPoint.dx;
      _autoScrollNearEdges(x);
      final time = _metrics.timeAt(x, _offset);
      if (edge != null) {
        widget.onEdgeDrag(edge, time);
      } else {
        widget.onScrub(time);
      }
      return;
    }
    if (details.scale != 1) {
      final anchor = _zoomAnchor ??= (
        x: details.localFocalPoint.dx,
        time: _metrics.timeAt(details.localFocalPoint.dx, _offset),
      );
      final zoom = (_scaleStartZoom * details.scale).clamp(1.0, _maxZoom);
      setState(() {
        _zoom = zoom.toDouble();
        final metrics = _metrics;
        _offset = metrics.clampOffset(
          metrics.contentX(anchor.time) - details.localFocalPoint.dx,
        );
      });
      return;
    }
    if (_isPanning || details.pointerCount > 1) {
      _panBy(details.focalPointDelta.dx);
    }
  }

  /// 拖动把手靠近视口边缘时自动平移，便于把边界拖到视口外的位置。
  void _autoScrollNearEdges(double x) {
    const zone = 24.0;
    if (x < zone) {
      _panBy((zone - x) * 0.5);
    } else if (x > _viewport - zone) {
      _panBy(-(x - (_viewport - zone)) * 0.5);
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final edge = _draggingEdge;
    if (edge != null) widget.onEdgeDragEnd(edge);
    if (_isScrubbing) widget.onScrubEnd();
    setState(() {
      _draggingEdge = null;
      _isScrubbing = false;
      _isPanning = false;
      _zoomAnchor = null;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    final wantsZoom = keyboard.isControlPressed || keyboard.isMetaPressed;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    // 未放大且不是缩放手势时不接管，让外层页面继续滚动。
    if (!wantsZoom && (_zoom <= 1 || (dx == 0 && dy == 0))) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      if (wantsZoom) {
        _setZoom(_zoom * math.exp(-dy / 240), anchorX: event.localPosition.dx);
      } else {
        _panBy(-(dx.abs() > dy.abs() ? dx : dy));
      }
    });
  }

  MouseCursor _cursorFor(Offset position) {
    if (_isScrubbing || _prefersPlayhead(position, PointerDeviceKind.mouse)) {
      return SystemMouseCursors.resizeColumn;
    }
    return _draggingEdge != null ||
            _hitEdge(position.dx, PointerDeviceKind.mouse) != null
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.click;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.maxWidth;
              if (viewport != _viewport) {
                final anchor = _viewport > 0
                    ? _metrics.timeAt(0, _offset)
                    : Duration.zero;
                _viewport = viewport;
                _zoom = _zoom.clamp(1.0, _maxZoom).toDouble();
                _offset = _metrics.clampOffset(
                  _metrics.contentX(anchor) - _TimelineMetrics.padding,
                );
              }
              final metrics = _metrics;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: Listener(
                    onPointerDown: (event) {
                      _activePointers++;
                      _pointerKind = event.kind;
                      _downPosition = event.localPosition;
                    },
                    onPointerUp: (_) => _activePointers--,
                    onPointerCancel: (_) => _activePointers--,
                    onPointerSignal: _handlePointerSignal,
                    child: MouseRegion(
                      cursor: _cursor,
                      onHover: (event) {
                        final cursor = _cursorFor(event.localPosition);
                        if (cursor != _cursor) setState(() => _cursor = cursor);
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _handleTap,
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onScaleEnd: _handleScaleEnd,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _TimelinePainter(
                                  metrics: metrics,
                                  offset: _offset,
                                  waveform: widget.waveform,
                                  samples: _samples,
                                  spans: widget.spans,
                                  clips: widget.clips,
                                  selectedClipId: widget.selectedClipId,
                                  activeEdge: _draggingEdge,
                                  scheme: scheme,
                                  textScaler: MediaQuery.textScalerOf(context),
                                ),
                              ),
                            ),
                            // 拖动把手时隐藏播放头，避免和把手混在一起。
                            if (_draggingEdge == null)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: _PlayheadPainter(
                                    x: metrics.screenX(
                                      widget.position,
                                      _offset,
                                    ),
                                    color: scheme.onSurface,
                                    ringColor: scheme.surfaceContainerHigh,
                                    isActive: _isScrubbing,
                                  ),
                                ),
                              ),
                            if (widget.waveform == null)
                              Center(
                                child: _WaveformStatus(
                                  progress: widget.waveformProgress,
                                  isFailed: widget.isWaveformFailed,
                                  onRetry: widget.onRetryWaveform,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (_selectedClip case final clip?)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('trim-zoom-clip'),
                    onPressed: _fitSelectedClip,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: SvgPicture.asset(
                      'assets/icon/arrow-range.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        scheme.onSurfaceVariant,
                        BlendMode.srcIn,
                      ),
                    ),
                    // 点按放大到当前片段；标签说明当前是哪个片段及其范围。
                    label: Text(
                      '${l10n.mediaTrimClipLabel(widget.clips.indexOf(clip) + 1)}'
                      ' · ${formatTrimClock(clip.start)} – '
                      '${formatTrimClock(clip.end)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            _ZoomButton(
              key: const ValueKey('trim-zoom-out'),
              icon: Icons.zoom_out_rounded,
              tooltip: l10n.mediaTrimZoomOut,
              onPressed: _zoom > 1 ? () => _setZoom(_zoom / _zoomStep) : null,
            ),
            _ZoomButton(
              key: const ValueKey('trim-zoom-in'),
              icon: Icons.zoom_in_rounded,
              tooltip: l10n.mediaTrimZoomIn,
              onPressed: _zoom < _maxZoom
                  ? () => _setZoom(_zoom * _zoomStep)
                  : null,
            ),
            _ZoomButton(
              icon: Icons.fit_screen_outlined,
              tooltip: l10n.mediaTrimZoomFit,
              onPressed: _zoom > 1 ? () => _setZoom(1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 20),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
}

class _WaveformStatus extends StatelessWidget {
  const _WaveformStatus({
    required this.progress,
    required this.isFailed,
    required this.onRetry,
  });

  final double progress;
  final bool isFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    if (isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.mediaTrimWaveformFailed, style: style),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      );
    }
    return Text(
      l10n.mediaTrimWaveformLoading((progress * 100).round()),
      style: style,
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.metrics,
    required this.offset,
    required this.waveform,
    required this.samples,
    required this.spans,
    required this.clips,
    required this.selectedClipId,
    required this.activeEdge,
    required this.scheme,
    required this.textScaler,
  });

  static const double labelLane = 20;
  static const double axisLane = 18;

  final _TimelineMetrics metrics;
  final double offset;
  final Waveform? waveform;
  final WaveformSamples? samples;
  final List<MediaTrimSentenceSpan> spans;
  final List<MediaTrimClip> clips;
  final int? selectedClipId;
  final MediaTrimEdge? activeEdge;
  final ColorScheme scheme;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final waveTop = labelLane;
    final waveBottom = size.height - axisLane;
    MediaTrimClip? selected;
    for (final clip in clips) {
      if (clip.id == selectedClipId) selected = clip;
    }
    _paintClipRegions(canvas, waveTop, waveBottom, selected);
    _paintWaveform(canvas, size, waveTop, waveBottom, selected);
    _paintSpans(canvas, waveBottom);
    _paintAxis(canvas, size, waveBottom);
    _paintClipLabels(canvas, selected);
    if (selected != null) _paintHandles(canvas, waveTop, waveBottom, selected);
  }

  /// 非选中片段画成浅色圆角块；选中片段的框和把手在 [_paintHandles] 中最后绘制。
  void _paintClipRegions(
    Canvas canvas,
    double top,
    double bottom,
    MediaTrimClip? selected,
  ) {
    final others = Paint()..color = scheme.primary.withValues(alpha: 0.08);
    for (final clip in clips) {
      if (clip.id == selectedClipId) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _clipRect(clip, top, bottom),
          const Radius.circular(6),
        ),
        others,
      );
    }
    if (selected != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _clipRect(selected, top, bottom),
          const Radius.circular(8),
        ),
        Paint()..color = scheme.primary.withValues(alpha: 0.08),
      );
    }
  }

  Rect _clipRect(MediaTrimClip clip, double top, double bottom) =>
      Rect.fromLTRB(
        metrics.screenX(clip.start, offset),
        top,
        metrics.screenX(clip.end, offset),
        bottom,
      );

  void _paintWaveform(
    Canvas canvas,
    Size size,
    double top,
    double bottom,
    MediaTrimClip? selected,
  ) {
    final data = waveform;
    final values = samples;
    final centerY = (top + bottom) / 2;
    final halfHeight = (bottom - top) / 2 - 4;
    final idle = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.32)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (data == null || values == null) {
      canvas.drawLine(
        Offset(_TimelineMetrics.padding, centerY),
        Offset(size.width - _TimelineMetrics.padding, centerY),
        idle,
      );
      return;
    }
    final active = Paint()
      ..color = scheme.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // 3px 一根圆头竖条：比连续填充更轻、更易分辨音量起伏。
    const step = 3.0;
    final startX = math.max(0.0, metrics.screenX(Duration.zero, offset));
    final endX = math.min(size.width, metrics.screenX(metrics.total, offset));
    for (var x = startX; x < endX; x += step) {
      final from = data.positionToPixel(metrics.timeAt(x, offset)).floor();
      final to = math.max(
        from + 1,
        data.positionToPixel(metrics.timeAt(x + step, offset)).ceil(),
      );
      var low = 0;
      var high = 0;
      for (var i = math.max(0, from); i < to && i < values.length; i++) {
        final min = values.minAt(i);
        final max = values.maxAt(i);
        if (min < low) low = min;
        if (max > high) high = max;
      }
      final time = metrics.timeAt(x, offset);
      final isActive = selected != null && selected.containsTime(time);
      final y1 = centerY - math.max(1.0, high / values.peak * halfHeight);
      final y2 = centerY - math.min(-1.0, low / values.peak * halfHeight);
      canvas.drawLine(Offset(x, y1), Offset(x, y2), isActive ? active : idle);
    }
  }

  /// 句子位置条：提示有字幕时边界只会吸附到句间空隙。
  void _paintSpans(Canvas canvas, double waveBottom) {
    if (spans.isEmpty) return;
    final paint = Paint()..color = scheme.outline.withValues(alpha: 0.55);
    for (final span in spans) {
      final left = metrics.screenX(span.start, offset);
      final right = metrics.screenX(span.end, offset);
      if (right < 0 || left > metrics.viewport) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            left,
            waveBottom - 4,
            math.max(left + 1.5, right),
            waveBottom - 1,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  void _paintAxis(Canvas canvas, Size size, double waveBottom) {
    final totalSeconds = metrics.total.inMicroseconds / 1000000;
    if (totalSeconds <= 0 || metrics.usable <= 0) return;
    const candidates = [
      1,
      2,
      5,
      10,
      15,
      30,
      60,
      120,
      300,
      600,
      900,
      1800,
      3600,
    ];
    final pixelsPerSecond = metrics.usable / totalSeconds;
    final interval = candidates.firstWhere(
      (seconds) => seconds * pixelsPerSecond >= 72,
      orElse: () => candidates.last,
    );
    final tick = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 1;
    final style = TextStyle(
      fontSize: 10,
      color: scheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final first = (offset / pixelsPerSecond / interval).floor() * interval;
    for (var second = first; second <= totalSeconds; second += interval) {
      final x = metrics.screenX(Duration(seconds: second), offset);
      if (x > size.width) break;
      if (x < -40) continue;
      canvas.drawLine(Offset(x, waveBottom), Offset(x, waveBottom + 4), tick);
      final painter = TextPainter(
        text: TextSpan(
          text: formatTrimClock(Duration(seconds: second)),
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler.clamp(maxScaleFactor: 1.3),
      )..layout();
      final labelX = x + 3 + painter.width > size.width
          ? x - 3 - painter.width
          : x + 3;
      painter.paint(canvas, Offset(labelX, waveBottom + 3));
    }
  }

  void _paintClipLabels(Canvas canvas, MediaTrimClip? selected) {
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final isSelected = clip.id == selectedClipId;
      final left = metrics.screenX(clip.start, offset);
      final right = metrics.screenX(clip.end, offset);
      if (right < 0 || left > metrics.viewport) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? scheme.onPrimary : scheme.onPrimaryContainer,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler.clamp(maxScaleFactor: 1.2),
      )..layout();
      final badgeWidth = math.max(16.0, painter.width + 8);
      // 片段太窄放不下序号时，只在选中时显示，避免标签挤在一起。
      if (right - left < badgeWidth + 2 && !isSelected) continue;
      // 序号放在片段可见部分的中间：播放头常停在片段两端，放中间不会被抓手盖住。
      final visibleLeft = math.max(left, 0.0);
      final visibleRight = math.min(right, metrics.viewport);
      final badgeLeft = ((visibleLeft + visibleRight - badgeWidth) / 2)
          .clamp(left, math.max(left, right - badgeWidth))
          .toDouble();
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(badgeLeft, 2, badgeWidth, labelLane - 5),
        Radius.circular((labelLane - 5) / 2),
      );
      canvas.drawRRect(
        badge,
        Paint()..color = isSelected ? scheme.primary : scheme.primaryContainer,
      );
      painter.paint(
        canvas,
        Offset(
          badge.left + (badgeWidth - painter.width) / 2,
          badge.top + (badge.height - painter.height) / 2,
        ),
      );
    }
  }

  /// 选中片段：圆角描边框 + 两端实心把手（参照系统相册裁剪框）。
  void _paintHandles(
    Canvas canvas,
    double top,
    double bottom,
    MediaTrimClip clip,
  ) {
    final startX = metrics.screenX(clip.start, offset);
    final endX = metrics.screenX(clip.end, offset);
    final color = scheme.primary;
    canvas.drawRRect(
      RRect.fromLTRBR(startX, top, endX, bottom, const Radius.circular(8)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final edge in MediaTrimEdge.values) {
      final isStart = edge == MediaTrimEdge.start;
      final x = isStart ? startX : endX;
      final width = activeEdge == edge ? 16.0 : 12.0;
      // 把手向片段内侧展开，外侧与描边对齐，避免遮住片段外的波形。
      final rect = isStart
          ? Rect.fromLTRB(x - 1.25, top, x - 1.25 + width, bottom)
          : Rect.fromLTRB(x + 1.25 - width, top, x + 1.25, bottom);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(isStart ? 8 : 3),
          bottomLeft: Radius.circular(isStart ? 8 : 3),
          topRight: Radius.circular(isStart ? 3 : 8),
          bottomRight: Radius.circular(isStart ? 3 : 8),
        ),
        Paint()..color = color,
      );
      // 把手上的小箭头指向可拖动方向。
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final dir = isStart ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(cx - dir * 1.5, cy - 5)
          ..lineTo(cx + dir * 2, cy)
          ..lineTo(cx - dir * 1.5, cy + 5),
        Paint()
          ..color = scheme.onPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.metrics.viewport != metrics.viewport ||
      old.metrics.zoom != metrics.zoom ||
      old.metrics.total != metrics.total ||
      old.offset != offset ||
      !identical(old.waveform, waveform) ||
      !identical(old.samples, samples) ||
      !identical(old.spans, spans) ||
      !identical(old.clips, clips) ||
      old.selectedClipId != selectedClipId ||
      old.activeEdge != activeEdge ||
      old.scheme != scheme ||
      old.textScaler != textScaler;
}

/// 播放头：细竖线 + 顶部圆形抓手，用中性前景色，不和错误红色混淆。
class _PlayheadPainter extends CustomPainter {
  const _PlayheadPainter({
    required this.x,
    required this.color,
    required this.ringColor,
    required this.isActive,
  });

  final double x;
  final Color color;

  /// 抓手外圈，与背景分开。
  final Color ringColor;

  /// 正在拖动时放大抓手，提示已抓住。
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    if (x < -8 || x > size.width + 8) return;
    canvas.drawLine(
      Offset(x, 8),
      Offset(x, size.height - 16),
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final radius = isActive ? 7.0 : 5.5;
    final center = Offset(x, 8);
    canvas
      ..drawCircle(center, radius + 2, Paint()..color = ringColor)
      ..drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) =>
      old.x != x ||
      old.color != color ||
      old.ringColor != ringColor ||
      old.isActive != isActive;
}

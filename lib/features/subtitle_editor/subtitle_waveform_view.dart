import 'package:flutter/material.dart';
import 'package:just_waveform/just_waveform.dart';

import '../../l10n/app_localizations.dart';

import '../../models/sentence.dart';
import 'subtitle_edit_engine.dart';

/// 一条可拖动边界的引用：全篇词列表下标 + 起 / 止端。
///
/// 所有边界都是单词边界——句子起止即首词起点 / 末词终点，由 controller 同步。
typedef _BoundaryRef = ({int globalIndex, BoundaryEdge edge});

/// 波形视图的「单一坐标真相源」。
///
/// 所有元素（波形、句子边界、播放头红线、命中测试、时间轴）都只经由这里的
/// [timeToContentX] / [screenX] / [timeAt] 互转，杜绝「波形与播放头各算各的、
/// 不同周期更新」导致的跳变/闪烁。
///
/// 坐标系：
/// - content-x：内容空间，`[0, contentWidth]`，与缩放/视口无关地表示「整段音频铺开」。
/// - screen-x：视口空间，`[0, viewport]`，= content-x − [viewOffset]。
///
/// 缩放语义：`zoom == 1` 时整段音频恰好铺满视口（不可滚动）；`zoom == z` 时
/// 内容被拉长到 z 倍，超出部分靠 [viewOffset] 平移查看。
class WaveformMetrics {
  final double viewport;
  final double zoom;
  final Duration duration;
  final double padding;

  const WaveformMetrics({
    required this.viewport,
    required this.zoom,
    required this.duration,
    required this.padding,
  });

  double get _z => zoom < 1.0 ? 1.0 : zoom;

  /// 视口去掉左右 padding 后的可用宽度。
  double get usableViewport {
    final u = viewport - padding * 2;
    return u < 0 ? 0 : u;
  }

  /// 内容可用宽度（= 整段音频在 content 空间占用的像素）。
  double get contentUsable => usableViewport * _z;

  /// 内容总宽度（含两侧 padding 留白）。
  double get contentWidth => contentUsable + padding * 2;

  /// 最大可平移偏移；`0` 表示内容不超过视口（不可滚动）。
  double get maxOffset {
    final m = contentWidth - viewport;
    return m < 0 ? 0 : m;
  }

  /// 把偏移钳到合法范围。
  double clampOffset(double offset) => offset.clamp(0.0, maxOffset);

  /// 时间 → content-x。
  double timeToContentX(Duration t) {
    final us = duration.inMicroseconds;
    if (us <= 0 || contentUsable <= 0) return padding;
    final frac = (t.inMicroseconds / us).clamp(0.0, 1.0);
    return padding + contentUsable * frac;
  }

  /// 时间 → screen-x（给定当前 [viewOffset]）。所有元素绘制都用它，故永不 desync。
  double screenX(Duration t, double viewOffset) =>
      timeToContentX(t) - viewOffset;

  /// screen-x → 时间（命中测试 / 点按定位用），结果钳在 `[0, duration]`。
  Duration timeAt(double localX, double viewOffset) {
    final us = duration.inMicroseconds;
    if (us <= 0 || contentUsable <= 0) return Duration.zero;
    final rel = (localX + viewOffset - padding).clamp(0.0, contentUsable);
    final frac = rel / contentUsable;
    return Duration(microseconds: (us * frac).round());
  }

  /// 让 [t] 落在视口中线所需的偏移（近首尾被 clamp，自动退化为「红线扫过」）。
  double offsetToCenter(Duration t) =>
      clampOffset(timeToContentX(t) - viewport / 2);
}

/// 简版字幕编辑波形视图。
///
/// 展示整段波形、当前句起止区间、当前句与前后相邻句的全部单词边界和播放进度。
/// 所有边界都是单词边界（句子起止即首词起点 / 末词终点）带可抓取把手，拖动经
/// [onAdjustWord] 上报，越界钳制（含句子时间同步）由 controller 负责。
///
/// 架构：单 [CustomPaint] 填满视口（非内容宽），波形/边界/红线都由同一帧算出的
/// [WaveformMetrics] + viewOffset 派生绘制——无 ScrollView、无独立 overlay、无
/// post-frame 跟随，故播放停止等状态切换不产生跳变/闪烁。
///
/// 手势（确定性、跨平台一致，不用各平台不一致的惯性滚动）：
/// - 在空白处「拖动」= 平移波形（浏览）；「轻点」= 定位播放头到该处。
/// - 在边界把手上拖动 = 调整该边界。
/// - 双指捏合 / 触控板 pan-zoom = 缩放。
/// - 播放中：波形自动滚动让播放头钉在视口中线（近首尾退化为扫过）。
class SubtitleWaveformView extends StatefulWidget {
  static const double horizontalPadding = 16;

  /// 边界命中区相对把手宽度的横向外扩（逻辑像素）。
  ///
  /// 设为 0：命中区横向就是把手宽本身、不额外吸附，两条相近边界不易误选；
  /// 纵向覆盖整条竖线（见 [_SubtitleWaveformViewState._hitTestBoundaries]），
  /// 故线身任意处都能抓取。
  static const double boundaryHitRadius = 0;

  /// 边界把手底部贴住时间轴上沿，避免边界细线在把手下方露头。
  static const double boundaryHandleAxisGap = 0;

  /// 区分「轻点定位」与「拖动平移」的位移阈值（逻辑像素）。
  static const double tapSlop = 8;

  /// 底部时间轴占用高度（逻辑像素）。播放头红线只画到此高度之上。
  static const double axisHeight = 26;

  /// 起始边界配色（绿），结束边界配色（红），方便用户区分两端。
  static const Color startBoundaryColor = Color(0xFF43A047);
  static const Color endBoundaryColor = Color(0xFFE53935);

  /// 当前播放位置线配色（蓝），与起止的绿/红区分开。
  static const Color playheadColor = Color(0xFF1E88E5);

  /// [onAdjustWord] 默认空实现（未接入词级拖动时）。
  static void _ignoreWordAdjust(
    int index,
    BoundaryEdge edge,
    Duration target,
  ) {}

  /// [onAdjustEnd] 默认空实现。
  static void _ignoreAdjustEnd() {}

  /// [onRetryExtraction] 默认空实现。
  static void _ignoreRetry() {}

  final Waveform? waveform;
  final double extractionProgress;

  /// 波形提取是否失败：为 true 时波形区显示失败态 + 重试，而非「加载中」。
  final bool extractionFailed;

  /// 点击「重试」重新提取波形。
  final VoidCallback onRetryExtraction;

  final Duration? duration;
  final List<Sentence> sentences;
  final Sentence? activeSentence;

  /// 用户显式点选句子的递增计数（见 SubtitleEditorState.selectionEpoch）。
  /// 仅当它变化时才把当前句居中；播放推进/结束不会改变它，故播放停止后波形不跳变。
  final int selectionEpoch;

  final Duration playbackPosition;
  final bool isPlaying;
  final double zoomScale;

  /// 当前选中句 + 前后相邻句的全部单词边界（统一为可拖动的边界，含句子起止）。
  ///
  /// 句子起止边界即首词起点 / 末词终点，统一去重绘制（见 `_drawBoundaries`）。
  /// 当前句为主样式（大把手），相邻句为次样式（小把手）。空表示当前无选中句。
  final List<WaveformWordBoundary> wordBoundaries;

  /// 拖动单词边界时回调（全局词下标 + 起 / 止端 + 目标时间）。
  /// 句首词起点 / 句末词终点的拖动由 controller 同步到句子起止时间。
  final void Function(int wordIndex, BoundaryEdge edge, Duration target)
  onAdjustWord;

  /// 双指捏合缩放时回调，传入新的缩放倍数（越界由上层钳制）。
  final ValueChanged<double> onZoomChanged;

  /// 定位播放头（轻点空白处）时实时上报与结束上报。
  final ValueChanged<Duration> onScrub;
  final ValueChanged<Duration> onScrubEnd;

  /// 边界拖动结束时回调。
  final VoidCallback onAdjustEnd;

  const SubtitleWaveformView({
    super.key,
    required this.waveform,
    required this.extractionProgress,
    this.extractionFailed = false,
    this.onRetryExtraction = _ignoreRetry,
    required this.duration,
    required this.sentences,
    required this.activeSentence,
    required this.selectionEpoch,
    required this.playbackPosition,
    required this.isPlaying,
    required this.zoomScale,
    this.wordBoundaries = const [],
    this.onAdjustWord = _ignoreWordAdjust,
    required this.onZoomChanged,
    required this.onScrub,
    required this.onScrubEnd,
    this.onAdjustEnd = _ignoreAdjustEnd,
  });

  @override
  State<SubtitleWaveformView> createState() => _SubtitleWaveformViewState();
}

class _SubtitleWaveformViewState extends State<SubtitleWaveformView> {
  /// 持久视图偏移（唯一真相源）。每帧在 build 内由 缩放焦点 / 播放跟随 / 选句居中 /
  /// 保持（含手动平移结果）四种规则派生并回写，供下一帧使用。
  double _viewOffset = 0;

  /// 上次据以做缩放焦点保持的 zoom / viewport，用于检测变化。
  double? _lastZoom;
  double? _lastViewport;

  /// 待生效的「选句居中」目标时间（一次性）；null 表示无。
  Duration? _pendingCenterTime;

  /// 上次执行居中所对应的 [SubtitleWaveformView.selectionEpoch]。
  int? _lastCenteredEpoch;

  /// 播放头是否做 80ms 线性补间（仅连续播放推进时），用于平滑 50ms tick 与
  /// position 流的微小校准抖动 —— 否则波形滚动会「一格一格」抖/闪。
  bool _animatePlayhead = false;

  /// 供指针回调使用的「当前帧」度量与偏移（在 build 内回写）。
  WaveformMetrics? _metrics;
  double _renderOffset = 0;

  /// 鼠标光标：悬停在某条边界（竖线/把手）上时显示「可左右移动」（↔），
  /// 其余波形区域为默认箭头，让用户一眼区分「能抓边界」与「普通区域」。
  MouseCursor _hoverCursor = SystemMouseCursors.basic;

  // ── 手势状态 ──
  /// 当前正在拖动的边界（句子或词）；null 表示未在拖动边界。
  _BoundaryRef? _draggingBoundary;

  /// 按下时命中多条重合/相邻边界，待首次移动按方向定夺的候选。
  List<_BoundaryRef>? _pendingBoundaries;

  /// 多边界方向定夺的起始视口 localX。
  double? _pendingLocalX;

  /// 单指平移/轻点：是否进行中、上一次 localX、起按 localX、累计位移绝对值。
  bool _panActive = false;
  double _panLastX = 0;
  double _panDownX = 0;
  double _panTotalAbs = 0;

  bool get _isAdjustingBoundary =>
      _draggingBoundary != null || _pendingBoundaries != null;

  /// 当前按下的所有指针（id → 全局坐标），用于识别双指捏合缩放。
  final Map<int, Offset> _activePointers = {};
  bool _isPinching = false;
  double _pinchInitialDistance = 0;
  double _pinchBaseZoom = 1;

  /// 触控板 pan-zoom（双指捏合）开始时的基准缩放。
  double _trackpadBaseZoom = 1;

  @override
  void initState() {
    super.initState();
    // 以挂载时的 epoch 为基准：仅此后用户主动点选（epoch 自增）才触发居中。
    _lastCenteredEpoch = widget.selectionEpoch;
  }

  @override
  void didUpdateWidget(covariant SubtitleWaveformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animatePlayhead = _shouldAnimatePlayhead(oldWidget);
    // 仅在「用户显式点选句子」（selectionEpoch 自增）且暂停时标记一次居中。
    // 播放推进/结束、拖边界等不改 epoch，故不会误触发居中（停止后波形不回跳）。
    final active = widget.activeSentence;
    if (active != null && widget.selectionEpoch != _lastCenteredEpoch) {
      _lastCenteredEpoch = widget.selectionEpoch;
      if (!widget.isPlaying && !oldWidget.isPlaying) {
        _pendingCenterTime = Duration(
          microseconds:
              (active.startTime.inMicroseconds +
                  active.endTime.inMicroseconds) ~/
              2,
        );
      }
    }
  }

  /// 是否对播放头做补间：仅在「连续播放、同一句、相邻小步」时平滑。
  /// 起播/停止/换句/定位/大跳等都不补间（直接到位），避免补间滞后造成停止时的偏差。
  ///
  /// 平滑双向小步（含 position 流相对本地时钟的微小后退校准），否则 50ms tick 的
  /// 台阶 + 校准回退会让波形滚动一格一格地抖/闪。
  bool _shouldAnimatePlayhead(SubtitleWaveformView oldWidget) {
    if (!widget.isPlaying || !oldWidget.isPlaying) return false;
    if (widget.activeSentence?.index != oldWidget.activeSentence?.index) {
      return false;
    }
    final delta =
        (widget.playbackPosition.inMicroseconds -
                oldWidget.playbackPosition.inMicroseconds)
            .abs();
    return delta > 0 &&
        delta <= const Duration(milliseconds: 250).inMicroseconds;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveform = widget.waveform;
    final duration = widget.duration ?? waveform?.duration;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SizedBox(
        height: 112,
        width: double.infinity,
        child: widget.extractionFailed
            ? _WaveformFailed(onRetry: widget.onRetryExtraction)
            : (waveform == null ||
                  duration == null ||
                  duration <= Duration.zero)
            ? _WaveformLoading(progress: widget.extractionProgress)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = WaveformMetrics(
                    viewport: constraints.maxWidth,
                    zoom: widget.zoomScale,
                    duration: duration,
                    padding: SubtitleWaveformView.horizontalPadding,
                  );
                  _metrics = metrics; // 供指针回调使用

                  return MouseRegion(
                    cursor: _hoverCursor,
                    onHover: (event) =>
                        _updateHoverCursor(event.localPosition, metrics),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerUp,
                      // 触控板双指捏合（macOS / 触控板设备）。
                      onPointerPanZoomStart: (_) =>
                          _trackpadBaseZoom = widget.zoomScale,
                      onPointerPanZoomUpdate: (event) =>
                          widget.onZoomChanged(_trackpadBaseZoom * event.scale),
                      // 播放头位置补间：仅平滑「播放推进」，其余瞬时到位。
                      // 用同一个 painted 同时驱动红线与跟随偏移，二者永不 desync。
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          end: widget.playbackPosition.inMicroseconds
                              .toDouble(),
                        ),
                        duration: _animatePlayhead
                            ? const Duration(milliseconds: 80)
                            : Duration.zero,
                        curve: Curves.linear,
                        builder: (context, animatedUs, _) {
                          final painted = Duration(
                            microseconds: animatedUs.round(),
                          );
                          final offset = _resolveOffset(metrics, painted);
                          _renderOffset = offset; // 供指针回调使用
                          final playheadX = widget.isPlaying
                              ? metrics
                                    .screenX(painted, offset)
                                    .clamp(0.0, metrics.viewport)
                              : null;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: _WaveformLayerPainter(
                                    waveform: waveform,
                                    metrics: metrics,
                                    viewOffset: offset,
                                    sentences: widget.sentences,
                                    activeSentence: widget.activeSentence,
                                    wordBoundaries: widget.wordBoundaries,
                                    color: theme.colorScheme.outline,
                                    activeColor: theme.colorScheme.primary,
                                    startColor:
                                        SubtitleWaveformView.startBoundaryColor,
                                    endColor:
                                        SubtitleWaveformView.endBoundaryColor,
                                    axisColor:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (playheadX != null)
                                RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _PlayheadLayerPainter(
                                      x: playheadX.toDouble(),
                                      color: SubtitleWaveformView.playheadColor,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ── 视图偏移：每帧由「缩放焦点 → 播放跟随 → 选句居中 → 保持」依次决定 ──

  /// 每帧解析当前视图偏移，并把结果回写 [_viewOffset]（供下一帧与指针回调用）。
  ///
  /// 同步计算（无 post-frame）：播放跟随期间 [_viewOffset] 始终等于「让播放头居中」
  /// 的偏移，因此播放停止那一帧「保持」分支取到的偏移与播放中完全相同 ——
  /// 红线 screenX、波形偏移都不变，**结构性地零跳变**。手动平移直接改写
  /// [_viewOffset]，经「保持」分支生效。
  double _resolveOffset(WaveformMetrics metrics, Duration painted) {
    // 1) 缩放 / 视口变化 → 保持焦点（同步调整持久偏移）。
    if (_lastZoom != null &&
        _lastViewport != null &&
        (metrics.zoom != _lastZoom || metrics.viewport != _lastViewport)) {
      final oldMetrics = WaveformMetrics(
        viewport: _lastViewport!,
        zoom: _lastZoom!,
        duration: metrics.duration,
        padding: metrics.padding,
      );
      _viewOffset = _focalPreservedOffset(oldMetrics, metrics, painted);
    }
    _lastZoom = metrics.zoom;
    _lastViewport = metrics.viewport;

    // 2) 播放中 → 钉中线跟随（边沿 clamp 退化为扫过）。
    if (widget.isPlaying) {
      final o = metrics.offsetToCenter(painted);
      _viewOffset = o;
      return o;
    }
    // 3) 暂停态下用户点选某句 → 一次性居中。
    final pending = _pendingCenterTime;
    if (pending != null) {
      _pendingCenterTime = null;
      final o = metrics.offsetToCenter(pending);
      _viewOffset = o;
      return o;
    }
    // 4) 保持（含手动平移结果、停止后）。
    final o = metrics.clampOffset(_viewOffset);
    _viewOffset = o;
    return o;
  }

  /// 缩放时让「焦点内容点」在屏幕上的位置不变，避免画面横向漂移。
  ///
  /// 焦点：播放头若在视口内则锚定播放头，否则锚定视口中心。
  double _focalPreservedOffset(
    WaveformMetrics oldM,
    WaveformMetrics newM,
    Duration painted,
  ) {
    final oldOffset = oldM.clampOffset(_viewOffset);
    final playheadScreenX = oldM.screenX(painted, oldOffset);
    final double focalScreenX;
    final Duration focalTime;
    if (playheadScreenX >= 0 && playheadScreenX <= oldM.viewport) {
      focalScreenX = playheadScreenX;
      focalTime = painted;
    } else {
      focalScreenX = oldM.viewport / 2;
      focalTime = oldM.timeAt(focalScreenX, oldOffset);
    }
    return newM.clampOffset(newM.timeToContentX(focalTime) - focalScreenX);
  }

  // ── 指针多路分发：单指走平移/轻点/拖边界，双指走捏合缩放 ──

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length >= 2) {
      _beginPinch();
      return;
    }
    final metrics = _metrics;
    if (metrics == null) return;
    final localPosition = event.localPosition;
    final localX = localPosition.dx;
    final hits = _hitTestBoundaries(localPosition, metrics, _renderOffset);
    if (hits.isNotEmpty) {
      if (hits.length == 1) {
        // 唯一命中：标记为拖动目标，但按下时不移动边界，
        // 等首次 move 时再跟手调整（避免「按下即跳」）。
        setState(() => _draggingBoundary = hits.first);
      } else {
        // 多条重合/相邻边界：待首次移动按方向定夺。
        setState(() {
          _pendingBoundaries = hits;
          _pendingLocalX = localX;
        });
      }
      return;
    }
    // 空白处：进入「平移/轻点」待定（移动超过阈值=平移，否则=轻点定位）。
    _panActive = true;
    _panDownX = localX;
    _panLastX = localX;
    _panTotalAbs = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointers.containsKey(event.pointer)) {
      _activePointers[event.pointer] = event.position;
    }
    if (_isPinching) {
      _updatePinch();
      return;
    }
    final metrics = _metrics;
    if (metrics == null) return;
    final localX = event.localPosition.dx;

    if (_draggingBoundary != null) {
      _updateBoundaryDrag(localX, metrics, _renderOffset);
      return;
    }
    final pending = _pendingBoundaries;
    if (pending != null) {
      final dir = localX - (_pendingLocalX ?? 0);
      if (dir == 0) return; // 还没有方向，继续等待。
      final chosen = _chooseByDirection(pending, dir);
      setState(() {
        _draggingBoundary = chosen;
        _pendingBoundaries = null;
        _pendingLocalX = null;
      });
      _updateBoundaryDrag(localX, metrics, _renderOffset);
      return;
    }
    if (_panActive) {
      // 平移波形：手指向右拖 → 看见更早内容 → 偏移减小（1:1 跟手）。
      final dx = localX - _panLastX;
      _panLastX = localX;
      _panTotalAbs += dx.abs();
      // 播放中跟随接管偏移，手动平移无效（需先暂停）；暂停态下直接改写偏移。
      if (!widget.isPlaying) {
        setState(() => _viewOffset = metrics.clampOffset(_viewOffset - dx));
      }
    }
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_isPinching) {
      if (_activePointers.length < 2) {
        setState(() => _isPinching = false);
        _pinchInitialDistance = 0;
      }
      return;
    }
    if (_isAdjustingBoundary) {
      final wasDragging = _draggingBoundary != null;
      setState(() {
        _draggingBoundary = null;
        _pendingBoundaries = null;
        _pendingLocalX = null;
      });
      if (wasDragging) widget.onAdjustEnd();
      return;
    }
    if (_panActive) {
      _panActive = false;
      // 位移小于阈值视为「轻点」→ 定位播放头到点按处。
      final metrics = _metrics;
      if (metrics != null && _panTotalAbs <= SubtitleWaveformView.tapSlop) {
        final t = metrics.timeAt(_panDownX, _renderOffset);
        widget.onScrub(t);
        widget.onScrubEnd(t);
      }
    }
  }

  /// 进入双指捏合：取消进行中的单指操作，记录初始指距与基准缩放。
  void _beginPinch() {
    _cancelSinglePointerActions();
    _pinchInitialDistance = _currentPointerDistance();
    _pinchBaseZoom = widget.zoomScale;
    setState(() => _isPinching = true);
  }

  /// 捏合更新：按指距变化比例缩放（越界由 [onZoomChanged] 上层钳制）。
  void _updatePinch() {
    if (_activePointers.length < 2 || _pinchInitialDistance <= 0) return;
    final distance = _currentPointerDistance();
    if (distance <= 0) return;
    widget.onZoomChanged(_pinchBaseZoom * distance / _pinchInitialDistance);
  }

  /// 取前两个指针之间的距离（全局坐标，平移不变）。
  double _currentPointerDistance() {
    final points = _activePointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  /// 第二指落下时，作废尚未提交的单指平移/拖边界操作。
  void _cancelSinglePointerActions() {
    _panActive = false;
    if (_isAdjustingBoundary) {
      setState(() {
        _draggingBoundary = null;
        _pendingBoundaries = null;
        _pendingLocalX = null;
      });
    }
  }

  /// 当前可拖动的边界候选：所有单词边界的起 / 止两端。
  ///
  /// 句子起止边界即首词起点 / 末词终点，已统一在 [SubtitleWaveformView.wordBoundaries]
  /// 中。`globalIndex < 0`（与 token 暂不同步）的词只绘制、不可拖动。
  List<_BoundaryRef> _boundaryCandidates() {
    final result = <_BoundaryRef>[];
    for (final b in widget.wordBoundaries) {
      if (b.globalIndex < 0) continue;
      result.add((globalIndex: b.globalIndex, edge: BoundaryEdge.start));
      result.add((globalIndex: b.globalIndex, edge: BoundaryEdge.end));
    }
    return result;
  }

  /// 按全局词下标查找对应的边界数据。
  WaveformWordBoundary? _boundaryByIndex(int globalIndex) {
    for (final b in widget.wordBoundaries) {
      if (b.globalIndex == globalIndex) return b;
    }
    return null;
  }

  /// 边界对应的时间；引用失效返回 null。
  Duration? _boundaryTime(_BoundaryRef ref) {
    final b = _boundaryByIndex(ref.globalIndex);
    if (b == null) return null;
    return ref.edge == BoundaryEdge.start ? b.word.startTime : b.word.endTime;
  }

  /// 该边界是否次样式（小把手）：相邻句的单词边界为次样式。
  bool _boundaryIsSecondary(_BoundaryRef ref) {
    final b = _boundaryByIndex(ref.globalIndex);
    return b == null || !b.primary;
  }

  /// 鼠标悬停时更新光标：在边界命中区内显示「可左右移动」（↔），否则默认箭头。
  void _updateHoverCursor(Offset localPosition, WaveformMetrics metrics) {
    final overBoundary = _hitTestBoundaries(
      localPosition,
      metrics,
      _renderOffset,
    ).isNotEmpty;
    final next = overBoundary
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.basic;
    if (next != _hoverCursor) {
      setState(() => _hoverCursor = next);
    }
  }

  /// 命中测试：返回竖线（含把手）命中区域内的所有边界，按横向距离升序。
  ///
  /// 命中区 = 整条竖线：横向仅把手宽（外扩 [SubtitleWaveformView.boundaryHitRadius]
  /// = 0，相近边界不易误选），纵向覆盖竖线全高（顶到时间轴上沿），故线身任意处都可抓取。
  List<_BoundaryRef> _hitTestBoundaries(
    Offset localPosition,
    WaveformMetrics metrics,
    double offset,
  ) {
    final bottom = context.size?.height;
    if (bottom == null) return const [];
    final lineBottom =
        bottom -
        SubtitleWaveformView.axisHeight -
        SubtitleWaveformView.boundaryHandleAxisGap;
    if (localPosition.dy < 0 || localPosition.dy > lineBottom) return const [];
    final hits = <({_BoundaryRef c, double d})>[];
    for (final candidate in _boundaryCandidates()) {
      final time = _boundaryTime(candidate);
      if (time == null) continue;
      final x = metrics.screenX(time, offset);
      final isSecondary = _boundaryIsSecondary(candidate);
      final halfWidth =
          (isSecondary ? 7.0 : 10.0) / 2 +
          SubtitleWaveformView.boundaryHitRadius;
      final dx = (localPosition.dx - x).abs();
      if (dx > halfWidth) continue;
      hits.add((c: candidate, d: dx));
    }
    hits.sort((a, b) => a.d.compareTo(b.d));
    return [for (final hit in hits) hit.c];
  }

  /// 多条重合边界按拖动方向定夺：向左选「结束」边界，向右选「开始」边界，
  /// 从而总能朝指针方向移动。
  _BoundaryRef _chooseByDirection(
    List<_BoundaryRef> candidates,
    double direction,
  ) {
    final preferEnd = direction < 0;
    for (final candidate in candidates) {
      if (preferEnd && candidate.edge == BoundaryEdge.end) return candidate;
      if (!preferEnd && candidate.edge == BoundaryEdge.start) return candidate;
    }
    return candidates.first;
  }

  void _updateBoundaryDrag(
    double localX,
    WaveformMetrics metrics,
    double offset,
  ) {
    final boundary = _draggingBoundary;
    if (boundary == null) return;
    final target = metrics.timeAt(localX, offset);
    widget.onAdjustWord(boundary.globalIndex, boundary.edge, target);
  }
}

/// 播放头红线层。仅画一条位于视口坐标 [x] 处的竖线（顶到时间轴上沿）。
///
/// 与波形层分层 + 各自 RepaintBoundary：播放推进只重绘这条线，不触发波形层重绘。
class _PlayheadLayerPainter extends CustomPainter {
  final double x;
  final Color color;

  const _PlayheadLayerPainter({required this.x, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - SubtitleWaveformView.axisHeight;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4;
    canvas.drawLine(Offset(x, 0), Offset(x, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant _PlayheadLayerPainter oldDelegate) {
    return x != oldDelegate.x || color != oldDelegate.color;
  }
}

class _WaveformLoading extends StatelessWidget {
  final double progress;

  const _WaveformLoading({required this.progress});

  @override
  Widget build(BuildContext context) {
    final l10nProgress = (progress * 100).clamp(0, 100).round();
    return Center(
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress <= 0 ? null : progress),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.waveformLoading(l10nProgress),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 波形提取失败态：提示失败 + 重试按钮。
///
/// 波形只是编辑辅助，失败不阻断编辑——下方句子列表仍可正常增删改。
class _WaveformFailed extends StatelessWidget {
  final VoidCallback onRetry;

  const _WaveformFailed({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.waveformLoadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: Text(l10n.waveformRetry)),
          ],
        ),
      ),
    );
  }
}

/// 波形层：只绘制**当前可见时间窗**（约 viewport/2 条竖线，与缩放无关），
/// 经 [metrics] + [viewOffset] 单一映射定位，故与播放头同一坐标空间、不可能错位。
class _WaveformLayerPainter extends CustomPainter {
  final Waveform waveform;
  final WaveformMetrics metrics;
  final double viewOffset;
  final List<Sentence> sentences;
  final Sentence? activeSentence;

  /// 选中句 + 前后相邻句的全部单词边界（含句子起止）。当前句为主样式，邻句为次样式。
  final List<WaveformWordBoundary> wordBoundaries;
  final Color color;
  final Color activeColor;

  /// 起始边界配色（绿），结束边界配色（红）。
  final Color startColor;
  final Color endColor;
  final Color axisColor;

  const _WaveformLayerPainter({
    required this.waveform,
    required this.metrics,
    required this.viewOffset,
    required this.sentences,
    required this.activeSentence,
    required this.wordBoundaries,
    required this.color,
    required this.activeColor,
    required this.startColor,
    required this.endColor,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPadding = 0.0;
    final viewport = size.width;
    final waveformBottom = size.height - SubtitleWaveformView.axisHeight;
    final centerY = topPadding + (waveformBottom - topPadding) / 2;
    final usableHeight = waveformBottom - topPadding;
    final totalUs = metrics.duration.inMicroseconds;
    if (usableHeight <= 0 || viewport <= 0 || totalUs <= 0) return;

    // 中线（横跨整个视口）。
    final midlinePaint = Paint()
      ..color = axisColor.withValues(alpha: .12)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(viewport, centerY),
      midlinePaint,
    );

    final basePaint = Paint()
      ..color = color.withValues(alpha: .50)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final sentencePaint = Paint()
      ..color = activeColor.withValues(alpha: .42)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final active = activeSentence;

    // 当前句填充高亮（先于竖线，作背景）。
    if (active != null) {
      final sx = metrics.screenX(active.startTime, viewOffset);
      final ex = metrics.screenX(active.endTime, viewOffset);
      final fillPaint = Paint()
        ..color = activeColor.withValues(alpha: .08)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(sx, topPadding, ex, waveformBottom),
          const Radius.circular(4),
        ),
        fillPaint,
      );
    }

    // 波形竖线：采样网格钉在**内容坐标**（content-x = k*step），而非屏幕坐标。
    // 这样每根柱子恒定代表同一采样点，滚动时随内容平移、高度不变——若钉屏幕坐标，
    // 同一屏幕位置每帧映射到不同采样点，柱高就会一帧一变地闪烁。
    const step = 2.0;
    // 当前视口左缘对应的 content-x，向下取整对齐到 step 网格，保证网格不随偏移漂移。
    final startK = ((viewOffset) / step).floor();
    for (var k = startK; ; k++) {
      final cx = k * step; // 内容坐标（稳定网格）
      final sx = cx - viewOffset; // 屏幕坐标
      if (sx > viewport) break;
      if (sx < 0) continue;
      final rel = cx - metrics.padding;
      if (rel < 0 || rel > metrics.contentUsable) continue; // 落在留白/越界处
      final frac = metrics.contentUsable <= 0
          ? 0.0
          : rel / metrics.contentUsable;
      final sampleIndex = (frac * waveform.length).round().clamp(
        0,
        waveform.length - 1,
      );
      final min = waveform.getPixelMin(sampleIndex);
      final max = waveform.getPixelMax(sampleIndex);
      final minY = centerY + _normalize(min, usableHeight);
      final maxY = centerY + _normalize(max, usableHeight);
      final positionUs = (totalUs * frac);
      final isActive =
          active != null &&
          positionUs >= active.startTime.inMicroseconds &&
          positionUs <= active.endTime.inMicroseconds;
      final isSentence = !isActive && _hasSentenceAt(positionUs);
      canvas.drawLine(
        Offset(sx, minY),
        Offset(sx, maxY),
        isActive
            ? activePaint
            : isSentence
            ? sentencePaint
            : basePaint,
      );
    }

    // 句子文本（弱化小字，钉在每句起点、随内容平移、按句区间裁剪）。
    _drawSentenceTexts(canvas, viewport, topPadding);

    // 句子边界 + 词边界统一去重绘制（见 _drawBoundaries）。
    _drawBoundaries(canvas, viewport, topPadding, waveformBottom);

    // 播放头红线由独立的 _PlayheadLayerPainter 绘制，不在此层。
    _drawTimeAxis(canvas: canvas, size: size, waveformBottom: waveformBottom);
  }

  /// 在波形顶部绘制每句文本：弱化小字，左对齐到句起点（随内容平移），
  /// 并裁剪到该句的屏幕区间内，避免文字溢出到相邻句。仅画可见句以省开销。
  void _drawSentenceTexts(Canvas canvas, double viewport, double top) {
    const leftPad = 5.0; // 让文字让开起始把手
    const textTop = 2.0;
    final style = TextStyle(
      color: axisColor.withValues(alpha: .5),
      fontSize: 10,
      height: 1.1,
    );
    for (final s in sentences) {
      if (s.text.trim().isEmpty) continue;
      final sx = metrics.screenX(s.startTime, viewOffset);
      final ex = metrics.screenX(s.endTime, viewOffset);
      if (ex < 0 || sx > viewport) continue; // 不可见
      final clipLeft = sx < 0 ? 0.0 : sx;
      final clipRight = ex > viewport ? viewport : ex;
      if (clipRight - clipLeft < 8) continue; // 太窄，放不下字
      final painter = TextPainter(
        text: TextSpan(text: s.text.trim(), style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (ex - sx - leftPad).clamp(0.0, double.infinity));
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(clipLeft, top, clipRight, top + 16));
      painter.paint(canvas, Offset(sx + leftPad, top + textTop));
      canvas.restore();
    }
  }

  bool _hasSentenceAt(double positionUs) {
    for (final s in sentences) {
      if (positionUs >= s.startTime.inMicroseconds &&
          positionUs < s.endTime.inMicroseconds) {
        return true;
      }
    }
    return false;
  }

  /// 统一绘制所有单词边界（都带把手），按屏幕位置聚合后绘制。
  ///
  /// 规则（句子起止边界即首词起点 / 末词终点，已并入单词边界）：
  /// - 当前句（主样式：粗、大把手）优先于相邻句（次样式：细、小把手）。
  /// - 同一位置若**同时**有「结束(红)」与「起始(绿)」边界（相邻词首尾相接），
  ///   不再让绿色覆盖红色，而是分段双色显示（见 [_drawBoundaryIfVisible]），
  ///   让用户看出这里既是上一段的结束、又是下一段的开始。
  void _drawBoundaries(
    Canvas canvas,
    double viewport,
    double top,
    double bottom,
  ) {
    // 按屏幕 x 聚合：记录该位置是否有起始(绿)/结束(红)边界、是否属于当前句(主样式)。
    final byX = <int, ({double x, bool hasStart, bool hasEnd, bool primary})>{};
    void add(Duration t, {required bool isStart, required bool primary}) {
      final x = metrics.screenX(t, viewOffset);
      final key = x.round();
      final e = byX[key];
      byX[key] = (
        x: e?.x ?? x,
        hasStart: (e?.hasStart ?? false) || isStart,
        hasEnd: (e?.hasEnd ?? false) || !isStart,
        primary: (e?.primary ?? false) || primary,
      );
    }

    for (final b in wordBoundaries) {
      add(b.word.startTime, isStart: true, primary: b.primary);
      add(b.word.endTime, isStart: false, primary: b.primary);
    }

    // 次样式先画、主样式后画，主把手叠在最上层。
    final markers = byX.values.toList()
      ..sort((a, b) => (a.primary ? 1 : 0).compareTo(b.primary ? 1 : 0));
    for (final m in markers) {
      _drawBoundaryIfVisible(
        canvas,
        m.x,
        viewport,
        top,
        bottom,
        hasStart: m.hasStart,
        hasEnd: m.hasEnd,
        secondary: !m.primary,
      );
    }
  }

  /// 仅当边界落在视口内（含少量外扩，容纳把手）时绘制竖线 + 底部把手。
  ///
  /// 当同一位置同时有「结束(红)」和「起始(绿)」边界（相邻词首尾相接）时，竖线与把手
  /// 都分成**左红右绿**：左 = 上一段的结束、右 = 下一段的开始。接缝落在真实时间点 [x]，
  /// 既不让绿色覆盖红色，又对应拖动方向（向左抓结束 / 向右抓开始）——业界 NLE 双修剪
  /// 手柄约定。
  void _drawBoundaryIfVisible(
    Canvas canvas,
    double x,
    double viewport,
    double top,
    double bottom, {
    required bool hasStart,
    required bool hasEnd,
    required bool secondary,
  }) {
    if (x < -12 || x > viewport + 12) return;
    final lineAlpha = secondary ? .35 : .9;
    final handleAlpha = secondary ? .55 : 1.0;
    final lineHalf = secondary ? 0.5 : 0.8; // 竖线半宽（单色时即标准 1 / 1.6px）
    final width = secondary ? 7.0 : 10.0;
    final height = secondary ? 10.0 : 14.0;
    final handleBottom = bottom - SubtitleWaveformView.boundaryHandleAxisGap;
    final rect = Rect.fromCenter(
      center: Offset(x, handleBottom - height / 2),
      width: width,
      height: height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

    if (hasStart && hasEnd) {
      // 左红(结束) / 右绿(开始)：竖线合成一条略宽双色柱，把手左右两半双色。
      canvas.drawRect(
        Rect.fromLTRB(x - lineHalf, top, x, bottom),
        Paint()..color = endColor.withValues(alpha: lineAlpha),
      );
      canvas.drawRect(
        Rect.fromLTRB(x, top, x + lineHalf, bottom),
        Paint()..color = startColor.withValues(alpha: lineAlpha),
      );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, x, rect.bottom),
        Paint()..color = endColor.withValues(alpha: handleAlpha),
      );
      canvas.drawRect(
        Rect.fromLTRB(x, rect.top, rect.right, rect.bottom),
        Paint()..color = startColor.withValues(alpha: handleAlpha),
      );
      canvas.restore();
      return;
    }

    // 仅起始或仅结束：单色竖线 + 单色把手。
    final color = hasStart ? startColor : endColor;
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = color.withValues(alpha: lineAlpha)
        ..strokeWidth = lineHalf * 2,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: handleAlpha)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawTimeAxis({
    required Canvas canvas,
    required Size size,
    required double waveformBottom,
  }) {
    final viewport = size.width;
    final axisTop = waveformBottom;
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: .14)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = axisColor.withValues(alpha: .26)
      ..strokeWidth = 1;
    // 轴底线横跨视口。
    canvas.drawLine(Offset(0, axisTop), Offset(viewport, axisTop), axisPaint);

    final totalSeconds =
        metrics.duration.inMilliseconds / Duration.millisecondsPerSecond;
    if (totalSeconds <= 0) return;

    final pixelsPerSecond = metrics.contentUsable / totalSeconds;
    final majorStepSeconds = _majorStepSeconds(pixelsPerSecond);
    final minorStepSeconds = majorStepSeconds / 2;
    final textStyle = TextStyle(
      color: axisColor.withValues(alpha: .38),
      fontSize: 9,
      height: 1,
    );

    for (
      var second = 0.0;
      second <= totalSeconds + 0.001;
      second += minorStepSeconds
    ) {
      final x = metrics.screenX(
        Duration(milliseconds: (second * 1000).round()),
        viewOffset,
      );
      if (x < 0 || x > viewport) continue; // 仅画可见刻度
      final isMajor =
          (second / majorStepSeconds - (second / majorStepSeconds).round())
              .abs() <
          0.001;
      canvas.drawLine(
        Offset(x, axisTop),
        Offset(x, axisTop + (isMajor ? 8 : 4)),
        isMajor ? majorPaint : axisPaint,
      );
      if (isMajor) {
        final label = _formatAxisTime(
          Duration(milliseconds: (second * 1000).round()),
        );
        final paragraph = _axisLabel(label, textStyle);
        if (x + 3 + paragraph.width <= viewport) {
          paragraph.paint(canvas, Offset(x + 3, axisTop + 8));
        }
      }
    }
  }

  double _majorStepSeconds(double pixelsPerSecond) {
    if (pixelsPerSecond >= 30) return 5;
    if (pixelsPerSecond >= 16) return 10;
    if (pixelsPerSecond >= 8) return 30;
    return 60;
  }

  TextPainter _axisLabel(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  String _formatAxisTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double _normalize(int value, double height) {
    final max = waveform.flags == 0 ? 32768.0 : 128.0;
    return (value / max) * height / 2;
  }

  @override
  bool shouldRepaint(covariant _WaveformLayerPainter oldDelegate) {
    return viewOffset != oldDelegate.viewOffset ||
        metrics.contentUsable != oldDelegate.metrics.contentUsable ||
        metrics.viewport != oldDelegate.metrics.viewport ||
        metrics.duration != oldDelegate.metrics.duration ||
        waveform != oldDelegate.waveform ||
        !identical(sentences, oldDelegate.sentences) ||
        activeSentence != oldDelegate.activeSentence ||
        // 按值比较词边界：词边界列表每帧重建，仅当时间 / 主次样式真正变化才重绘，
        // 避免播放时（实例每帧不同但内容相同）触发整层波形重绘。
        !_wordBoundariesEqual(wordBoundaries, oldDelegate.wordBoundaries) ||
        color != oldDelegate.color ||
        activeColor != oldDelegate.activeColor ||
        startColor != oldDelegate.startColor ||
        endColor != oldDelegate.endColor ||
        axisColor != oldDelegate.axisColor;
  }

  /// 词边界按时间值 + 主次样式比较（词文本不影响绘制）。
  static bool _wordBoundariesEqual(
    List<WaveformWordBoundary> a,
    List<WaveformWordBoundary> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].word.startTime != b[i].word.startTime ||
          a[i].word.endTime != b[i].word.endTime ||
          a[i].primary != b[i].primary) {
        return false;
      }
    }
    return true;
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:echo_loop/widgets/common/svg_action_icon.dart';

import '../../l10n/app_localizations.dart';

import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../utils/waveform_peaks.dart';
import 'subtitle_edit_engine.dart';
import 'subtitle_sentence_colors.dart';

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
/// - 选中句顶部的单词块「轻点」= 试听该词。
/// - 播放头顶部手柄拖动 = 连续定位。
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

  /// 波形区固定高度（含底部时间轴）；宽窗口左右分栏时也不加高，多余空间留在底部。
  static const double height = 120;

  /// [onAdjustWord] 默认空实现（未接入词级拖动时）。
  static void _ignoreWordAdjust(
    int index,
    BoundaryEdge edge,
    Duration target,
  ) {}

  /// [onMoveWord] 默认空实现（未接入整词拖动时）。
  static void _ignoreWordMove(int index, Duration targetStart) {}

  /// [onAdjustEnd] 默认空实现。
  static void _ignoreAdjustEnd() {}

  /// [onRetryExtraction] 默认空实现。
  static void _ignoreRetry() {}

  final WaveformPeaks? waveform;
  final double extractionProgress;

  /// 波形提取是否失败：为 true 时波形区显示失败态 + 重试，而非「加载中」。
  final bool extractionFailed;

  /// 当前字幕 item 没有本地音频：显示不可重试的无音频提示。
  final bool audioMissing;

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

  /// 播放中是否让波形跟随播放头（钉在视口中线）。
  ///
  /// 整句试听时跟随；试听单个词时不跟随，否则在波形上点词会让整个视图滚走、
  /// 单词跑出手指下方。不跟随时只在播放头离开视口时才居中。
  final bool followsPlayhead;
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

  /// 整体拖动单词时回调（全局词下标 + 目标起点），词长不变。
  ///
  /// 鼠标按住词区间（非边界）拖动、触摸长按词区间后拖动触发；松手走 [onAdjustEnd]。
  final void Function(int wordIndex, Duration targetStart) onMoveWord;

  /// 双指捏合缩放时回调，传入新的缩放倍数（越界由上层钳制）。
  final ValueChanged<double> onZoomChanged;

  /// 定位播放头（轻点空白处）时实时上报与结束上报。
  final ValueChanged<Duration> onScrub;
  final ValueChanged<Duration> onScrubEnd;

  /// 边界 / 整词拖动结束时回调。
  final VoidCallback onAdjustEnd;

  /// 与播放头对应的单词（选中句内）；非 null 时在波形上淡色标出它的区间，
  /// 与句子列表里高亮的单词、视频画面保持同一时刻。
  final WordTimestamp? highlightedWord;

  /// 暂停时播放头所在空隙可放新句的区间；非 null 时在波形上标出该区间，并在其中
  /// 显示「添加句子」按钮，用于补上识别漏掉的话。
  final SentenceSlot? insertSlot;

  /// 点「添加句子」时回调。
  final VoidCallback? onInsertSentence;

  /// 轻点选中句顶部的单词块时回调，参数为该词在选中句内的下标（与
  /// [wordBoundaries] 中主样式边界的顺序一致）。
  final ValueChanged<int>? onWordTap;

  const SubtitleWaveformView({
    super.key,
    required this.waveform,
    required this.extractionProgress,
    this.extractionFailed = false,
    this.audioMissing = false,
    this.onRetryExtraction = _ignoreRetry,
    required this.duration,
    required this.sentences,
    required this.activeSentence,
    required this.selectionEpoch,
    required this.playbackPosition,
    required this.isPlaying,
    this.followsPlayhead = true,
    required this.zoomScale,
    this.wordBoundaries = const [],
    this.onAdjustWord = _ignoreWordAdjust,
    this.onMoveWord = _ignoreWordMove,
    required this.onZoomChanged,
    required this.onScrub,
    required this.onScrubEnd,
    this.onAdjustEnd = _ignoreAdjustEnd,
    this.insertSlot,
    this.onInsertSentence,
    this.highlightedWord,
    this.onWordTap,
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
  /// 词区间内显示「可抓取」（手形），其余波形区域为默认箭头。
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

  /// 本次是鼠标右键拖动：只平移波形，松开时不当作轻点（不试听、不定位）。
  bool _isPanOnly = false;

  /// 正在整体拖动的词：全局词下标 + 按下点相对词起点的时间偏移（拖动中保持
  /// 指针相对词的位置不变）。null 表示未在拖词。
  _WordGrab? _movingWord;

  /// 按在词区间上、尚未开始拖动的词：鼠标移动超过 [_mouseGrabSlop] 或触摸长按
  /// 后开始整体拖动；鼠标未移动即松手仍按轻点定位播放头处理。
  _WordGrab? _pendingWordGrab;

  /// 触摸长按抓词的计时器；移动超过 [SubtitleWaveformView.tapSlop] 视为平移并取消。
  Timer? _wordLongPressTimer;

  /// 鼠标按住词区间后开始拖词的位移阈值，过滤点击时的手抖。
  static const double _mouseGrabSlop = 3;

  bool get _isAdjustingBoundary =>
      _draggingBoundary != null || _pendingBoundaries != null;

  /// 当前按下的所有指针（id → 全局坐标），用于识别双指捏合缩放。
  final Map<int, Offset> _activePointers = {};
  bool _isPinching = false;
  double _pinchInitialDistance = 0;
  double _pinchBaseZoom = 1;

  /// 双指捏合时两指中点的上一次横坐标（全局），两指同向移动时据此平移。
  double _pinchLastFocalX = 0;

  /// 触控板 pan-zoom（双指捏合）开始时的基准缩放。
  double _trackpadBaseZoom = 1;

  /// 是否正在拖动播放头（拖动中按指针位置实时定位）。
  bool _isScrubbingPlayhead = false;

  /// 按下处在选中句顶部的哪个单词块上（选中句内下标）；null 表示不在单词块上。
  /// 抬起时若是轻点，就试听该词而不是定位播放头。
  int? _downWordIndex;

  /// 在单词块上按住了播放头手柄：位移超过 [SubtitleWaveformView.tapSlop] 才开始
  /// 拖动播放头，否则视为点词，避免手柄压住的单词点不到。记录按下时的 localX。
  double? _pendingPlayheadGrabX;

  /// 本次按下是否落在波形上方的按钮（「添加句子」）上：按钮自己处理点击，
  /// 波形不再把它当成定位或平移。
  bool _isPointerOnOverlay = false;

  @override
  void dispose() {
    _wordLongPressTimer?.cancel();
    super.dispose();
  }

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
    final palette = WaveformPalette.of(theme.colorScheme);
    // 背景与圆角由外层卡片负责，这里只画内容，便于在不同布局中复用。
    return SizedBox(
      height: SubtitleWaveformView.height,
      width: double.infinity,
      child: widget.audioMissing
          ? const _WaveformAudioMissing()
          : widget.extractionFailed
          ? _WaveformFailed(onRetry: widget.onRetryExtraction)
          : (waveform == null || duration == null || duration <= Duration.zero)
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
                    // 触控板双指手势（macOS / 触控板设备）：滑动平移，捏合缩放。
                    onPointerPanZoomStart: (_) =>
                        _trackpadBaseZoom = widget.zoomScale,
                    onPointerPanZoomUpdate: _onTrackpadPanZoomUpdate,
                    // 鼠标滚轮：滚动平移，Ctrl / ⌘ + 滚轮缩放。
                    onPointerSignal: _onPointerSignal,
                    // 播放头位置补间：仅平滑「播放推进」，其余瞬时到位。
                    // 用同一个 painted 同时驱动红线与跟随偏移，二者永不 desync。
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        end: widget.playbackPosition.inMicroseconds.toDouble(),
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
                        // 播放头常驻：暂停时停在当前位置，播放中随播放推进。
                        final playheadX = metrics.screenX(painted, offset);
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _WaveformLayerPainter(
                                  peaks: waveform,
                                  metrics: metrics,
                                  viewOffset: offset,
                                  sentences: widget.sentences,
                                  activeSentence: widget.activeSentence,
                                  wordBoundaries: widget.wordBoundaries,
                                  highlightedWord: widget.highlightedWord,
                                  palette: palette,
                                  textScaler: MediaQuery.textScalerOf(context),
                                ),
                              ),
                            ),
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: _PlayheadLayerPainter(
                                  x: playheadX,
                                  palette: palette,
                                  isActive: _isScrubbingPlayhead,
                                ),
                              ),
                            ),
                            ..._buildInsertSlotOverlay(
                              metrics,
                              offset,
                              theme.colorScheme,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// 可插入新句的空隙：淡色区间标出新句将占的时间，中间放「添加句子」按钮。
  List<Widget> _buildInsertSlotOverlay(
    WaveformMetrics metrics,
    double offset,
    ColorScheme scheme,
  ) {
    final slot = widget.insertSlot;
    final onInsert = widget.onInsertSentence;
    if (slot == null || onInsert == null || widget.isPlaying) return const [];
    final left = metrics.screenX(slot.start, offset);
    final right = metrics.screenX(slot.end, offset);
    if (right <= 0 || left >= metrics.viewport) return const [];
    const top = _WaveformLayerPainter.labelLaneHeight;
    const bottomInset = SubtitleWaveformView.axisHeight;
    // 按钮放在区间可见部分的中央，并按半个按钮的估计宽度留边，避免贴边被裁掉。
    const halfButtonWidth = 70.0;
    final visibleCenter =
        (math.max(left, 0) + math.min(right, metrics.viewport)) / 2;
    final buttonCenter = metrics.viewport <= halfButtonWidth * 2
        ? metrics.viewport / 2
        : visibleCenter.clamp(
            halfButtonWidth,
            metrics.viewport - halfButtonWidth,
          );
    return [
      Positioned(
        left: left,
        width: right - left,
        top: top,
        bottom: bottomInset,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.primary.withValues(alpha: .45)),
            ),
          ),
        ),
      ),
      // 只定左缘、宽度随文案，再平移半个自身宽度居中，不同语言文案都不会被截断。
      Positioned(
        left: buttonCenter,
        top: top,
        bottom: bottomInset,
        child: FractionalTranslation(
          translation: const Offset(-.5, 0),
          child: Center(
            child: Listener(
              onPointerDown: (_) => _isPointerOnOverlay = true,
              child: _InsertSentenceButton(onPressed: onInsert),
            ),
          ),
        ),
      ),
    ];
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
    if (widget.isPlaying && widget.followsPlayhead) {
      final o = metrics.offsetToCenter(painted);
      _viewOffset = o;
      return o;
    }
    // 2b) 不跟随的播放（试听单词）：保持当前视图，播放头出视口时才居中。
    if (widget.isPlaying) {
      final kept = metrics.clampOffset(_viewOffset);
      final x = metrics.screenX(painted, kept);
      final o = x < 0 || x > metrics.viewport
          ? metrics.offsetToCenter(painted)
          : kept;
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
    if (_isPointerOnOverlay) {
      _isPointerOnOverlay = false;
      return;
    }
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length >= 2) {
      _beginPinch();
      return;
    }
    final metrics = _metrics;
    if (metrics == null) return;
    final localPosition = event.localPosition;
    final localX = localPosition.dx;
    // 鼠标右键：任意位置拖动都只平移，不抓词、边界或播放头。
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons & kSecondaryMouseButton != 0) {
      _isPanOnly = true;
      _panActive = true;
      _panDownX = localX;
      _panLastX = localX;
      _panTotalAbs = 0;
      return;
    }
    final hits = _hitTestBoundaries(localPosition, metrics, _renderOffset);
    _downWordIndex = _wordIndexAt(localPosition, metrics, _renderOffset);
    if (_prefersPlayhead(localPosition, event.kind, metrics, hits)) {
      if (_downWordIndex != null) {
        _pendingPlayheadGrabX = localX;
      } else {
        setState(() => _isScrubbingPlayhead = true);
      }
      return;
    }
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
    // 单词（单词块或词区间，非边界）：鼠标按住拖动即拖词，触摸需长按；在开始
    // 拖词之前仍按平移 / 轻点处理，轻点试听该词。
    final grab = _wordGrabAt(localPosition, metrics, _renderOffset);
    if (grab != null) {
      _pendingWordGrab = grab;
      if (event.kind != PointerDeviceKind.mouse) {
        _wordLongPressTimer = Timer(kLongPressTimeout, () {
          HapticFeedback.selectionClick();
          _beginWordMove();
        });
      }
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

    final grabX = _pendingPlayheadGrabX;
    if (grabX != null) {
      if ((localX - grabX).abs() <= SubtitleWaveformView.tapSlop) return;
      _pendingPlayheadGrabX = null;
      _downWordIndex = null;
      setState(() => _isScrubbingPlayhead = true);
    }
    if (_isScrubbingPlayhead) {
      widget.onScrub(_scrubTimeAt(localX, metrics));
      return;
    }
    if (_draggingBoundary != null) {
      _updateBoundaryDrag(localX, metrics, _renderOffset);
      return;
    }
    if (_movingWord != null) {
      _updateWordMove(localX, metrics);
      return;
    }
    if (_pendingWordGrab != null) {
      final moved = (localX - _panDownX).abs();
      if (event.kind == PointerDeviceKind.mouse) {
        if (moved <= _mouseGrabSlop) return;
        _beginWordMove();
        _updateWordMove(localX, metrics);
        return;
      }
      // 触摸：长按前移动超过阈值视为平移波形。
      if (moved > SubtitleWaveformView.tapSlop) _cancelWordGrab();
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
      _panBy(dx);
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
    final tappedWord = _downWordIndex;
    _downWordIndex = null;
    _cancelWordGrab();
    if (_movingWord != null) {
      setState(() {
        _movingWord = null;
        _hoverCursor = SystemMouseCursors.grab;
      });
      widget.onAdjustEnd();
      return;
    }
    if (_pendingPlayheadGrabX != null) {
      // 按在手柄上但没拖动：手柄下面是单词块，按点词处理。
      _pendingPlayheadGrabX = null;
      if (tappedWord != null) widget.onWordTap?.call(tappedWord);
      return;
    }
    if (_isScrubbingPlayhead) {
      setState(() => _isScrubbingPlayhead = false);
      final metrics = _metrics;
      if (metrics != null) {
        widget.onScrubEnd(_scrubTimeAt(event.localPosition.dx, metrics));
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
      if (_isPanOnly) {
        _isPanOnly = false;
        return;
      }
      // 位移小于阈值视为「轻点」：落在当前句的词上试听该词（播放头不动），
      // 否则定位播放头到点按处。
      final metrics = _metrics;
      final onWordTap = widget.onWordTap;
      if (_panTotalAbs <= SubtitleWaveformView.tapSlop &&
          tappedWord != null &&
          onWordTap != null) {
        onWordTap(tappedWord);
      } else if (metrics != null &&
          _panTotalAbs <= SubtitleWaveformView.tapSlop) {
        final t = metrics.timeAt(_panDownX, _renderOffset);
        widget.onScrub(t);
        widget.onScrubEnd(t);
      }
    }
  }

  /// 进入双指捏合：取消进行中的单指操作，记录初始指距、两指中点与基准缩放。
  void _beginPinch() {
    _cancelSinglePointerActions();
    _pinchInitialDistance = _currentPointerDistance();
    _pinchLastFocalX = _currentFocalX();
    _pinchBaseZoom = widget.zoomScale;
    setState(() => _isPinching = true);
  }

  /// 捏合更新：两指同向移动平移波形，指距变化缩放（越界由 [onZoomChanged] 上层钳制）。
  void _updatePinch() {
    if (_activePointers.length < 2 || _pinchInitialDistance <= 0) return;
    final focalX = _currentFocalX();
    _panBy(focalX - _pinchLastFocalX);
    _pinchLastFocalX = focalX;
    final distance = _currentPointerDistance();
    if (distance <= 0) return;
    widget.onZoomChanged(_pinchBaseZoom * distance / _pinchInitialDistance);
  }

  /// 前两个指针中点的横坐标（全局）。
  double _currentFocalX() {
    final points = _activePointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0].dx + points[1].dx) / 2;
  }

  /// 触控板双指：滑动按主方向平移（竖向滑动也映射为横向，便于只习惯上下滑的
  /// 用户浏览时间轴），捏合按比例缩放。
  void _onTrackpadPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final delta = event.panDelta;
    _panBy(delta.dx.abs() >= delta.dy.abs() ? delta.dx : delta.dy);
    if (event.scale != 1.0) {
      widget.onZoomChanged(_trackpadBaseZoom * event.scale);
    }
  }

  /// 鼠标滚轮：Ctrl / ⌘ + 滚轮缩放（与剪辑页一致），否则按主方向平移。
  ///
  /// 未放大（整段铺满、无处可平移）且不是缩放手势时不接管，让外层照常处理。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    final wantsZoom = keyboard.isControlPressed || keyboard.isMetaPressed;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final canPan = (_metrics?.maxOffset ?? 0) > 0;
    if (!wantsZoom && (!canPan || (dx == 0 && dy == 0))) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      if (wantsZoom) {
        widget.onZoomChanged(widget.zoomScale * math.exp(-dy / 240));
      } else {
        // 滚轮向下 / 向右 = 看更晚的内容，与单指拖动方向相反。
        _panBy(-(dx.abs() > dy.abs() ? dx : dy));
      }
    });
  }

  /// 按手指方向平移波形：向右移动 [dx] 看见更早的内容（1:1 跟手）。
  ///
  /// 播放中由跟随播放头接管偏移，手动平移不生效（与单指拖动一致）。
  void _panBy(double dx) {
    final metrics = _metrics;
    if (dx == 0 || metrics == null || widget.isPlaying) return;
    setState(() => _viewOffset = metrics.clampOffset(_viewOffset - dx));
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
    _isPanOnly = false;
    _downWordIndex = null;
    _cancelWordGrab();
    if (_movingWord != null) {
      setState(() => _movingWord = null);
      widget.onAdjustEnd();
    }
    _pendingPlayheadGrabX = null;
    if (_isScrubbingPlayhead) setState(() => _isScrubbingPlayhead = false);
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

  /// 鼠标悬停时更新光标：在边界命中区内显示「可左右移动」（↔），可拖动的词
  /// （单词块或词区间）上显示「可抓取」，只能试听的词上显示「可点击」，否则默认箭头。
  void _updateHoverCursor(Offset localPosition, WaveformMetrics metrics) {
    final hits = _hitTestBoundaries(localPosition, metrics, _renderOffset);
    final next =
        hits.isNotEmpty ||
            _prefersPlayhead(
              localPosition,
              PointerDeviceKind.mouse,
              metrics,
              hits,
            )
        ? SystemMouseCursors.resizeLeftRight
        : _wordGrabAt(localPosition, metrics, _renderOffset) != null
        ? SystemMouseCursors.grab
        : widget.onWordTap != null &&
              _wordIndexAt(localPosition, metrics, _renderOffset) != null
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic;
    if (next != _hoverCursor) {
      setState(() => _hoverCursor = next);
    }
  }

  /// 播放头线身命中半径：鼠标精确取小值，触摸取大值（与剪辑页一致）。
  static double _playheadSlop(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ? 6.0 : 16.0;

  /// 播放头手柄命中区在手柄半宽之外的外扩：触摸手指粗，外扩更多。
  static double _playheadHandleSlop(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.mouse ? 2.0 : 10.0;

  /// 按下处是否抓播放头。纵向分区，每个区只有一个明确目标：
  /// - 顶部文字行：手柄是播放头的专属抓取区（边界线不延伸到这里）；
  /// - 线身：选句后播放头常与句首边界重合，编辑边界是主要操作，与边界重叠时
  ///   让给边界，附近没有边界才抓播放头；
  /// - 线身以下（边界把手区）：只抓边界。
  bool _prefersPlayhead(
    Offset position,
    PointerDeviceKind kind,
    WaveformMetrics metrics,
    List<_BoundaryRef> boundaryHits,
  ) {
    final height = context.size?.height;
    if (height == null) return false;
    final dx =
        (metrics.screenX(widget.playbackPosition, _renderOffset) - position.dx)
            .abs();
    if (position.dy <= _WaveformLayerPainter.labelLaneHeight) {
      return dx <=
          _PlayheadLayerPainter.handleWidth / 2 + _playheadHandleSlop(kind);
    }
    if (position.dy > _PlayheadLayerPainter.lineBottom(height)) return false;
    return boundaryHits.isEmpty && dx <= _playheadSlop(kind);
  }

  /// 单词的点击 / 长按区：顶部单词块与它下方的词区间是同一个目标，下沿止于边界把手区。
  bool _isInWordZone(Offset position) {
    final height = context.size?.height;
    return height != null &&
        position.dy >= 0 &&
        position.dy <=
            height -
                SubtitleWaveformView.axisHeight -
                SubtitleWaveformView.boundaryHandleAxisGap;
  }

  /// 按下处落在选中句哪个词上（单词块或词区间），返回该词在选中句内的下标。
  int? _wordIndexAt(Offset position, WaveformMetrics metrics, double offset) {
    if (widget.onWordTap == null || !_isInWordZone(position)) return null;
    var local = 0;
    for (final b in widget.wordBoundaries) {
      if (!b.primary) continue;
      final startX = metrics.screenX(b.word.startTime, offset);
      final endX = metrics.screenX(b.word.endTime, offset);
      if (position.dx >= startX && position.dx <= endX) return local;
      local++;
    }
    return null;
  }

  /// 按下处落在哪个可拖动的词上（边界命中优先、已在调用前排除）。
  ///
  /// 词区间内当前句与相邻句的词都可整体拖动；顶部文字行只有当前句显示单词块，
  /// 只命中当前句的词。`globalIndex < 0` 的词只绘制、不可拖。
  _WordGrab? _wordGrabAt(
    Offset position,
    WaveformMetrics metrics,
    double offset,
  ) {
    if (!_isInWordZone(position)) return null;
    final isInLabelLane = position.dy < _WaveformLayerPainter.labelLaneHeight;
    for (final b in widget.wordBoundaries) {
      if (b.globalIndex < 0 || (isInLabelLane && !b.primary)) continue;
      final startX = metrics.screenX(b.word.startTime, offset);
      final endX = metrics.screenX(b.word.endTime, offset);
      if (position.dx < startX || position.dx > endX) continue;
      return (
        globalIndex: b.globalIndex,
        grabOffset: metrics.timeAt(position.dx, offset) - b.word.startTime,
      );
    }
    return null;
  }

  /// 开始整体拖词：停止平移 / 轻点判定，光标切为「抓取中」。
  void _beginWordMove() {
    _wordLongPressTimer?.cancel();
    _wordLongPressTimer = null;
    final grab = _pendingWordGrab;
    if (grab == null) return;
    _pendingWordGrab = null;
    _panActive = false;
    _downWordIndex = null;
    setState(() {
      _movingWord = grab;
      _hoverCursor = SystemMouseCursors.grabbing;
    });
  }

  void _cancelWordGrab() {
    _wordLongPressTimer?.cancel();
    _wordLongPressTimer = null;
    _pendingWordGrab = null;
  }

  void _updateWordMove(double localX, WaveformMetrics metrics) {
    final grab = _movingWord;
    if (grab == null) return;
    final target = metrics.timeAt(localX, _renderOffset) - grab.grabOffset;
    widget.onMoveWord(grab.globalIndex, target);
  }

  Duration _scrubTimeAt(double localX, WaveformMetrics metrics) =>
      metrics.timeAt(localX.clamp(0.0, metrics.viewport), _renderOffset);

  /// 命中测试：返回竖线（含把手）命中区域内的所有边界，按横向距离升序。
  ///
  /// 命中区 = 整条竖线：横向仅把手宽（外扩 [SubtitleWaveformView.boundaryHitRadius]
  /// = 0，相近边界不易误选），纵向覆盖竖线全高（从顶部文字行下沿到时间轴上沿），
  /// 故线身任意处都可抓取；文字行留给单词块和播放头手柄。
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
    if (localPosition.dy < _WaveformLayerPainter.labelLaneHeight ||
        localPosition.dy > lineBottom) {
      return const [];
    }
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

/// 被抓住的词：全局词下标 + 按下点相对词起点的时间偏移。
typedef _WordGrab = ({int globalIndex, Duration grabOffset});

/// 聚合后待绘制的边界标记。
typedef _BoundaryMarker = ({
  double x,
  bool hasStart,
  bool hasEnd,
  bool primary,
  bool isSentenceEdge,
});

/// 边界的视觉层级。
enum _BoundaryStyle {
  /// 当前句的起止：最醒目。
  sentenceEdge,

  /// 当前句内部的词边界。
  word,

  /// 相邻句的词边界：最淡，只作参照。
  neighbor,
}

/// 字幕编辑波形的配色，全部随明暗主题变化。
///
/// 起止边界保留「起点绿 / 终点红」的语义（用户已习惯），但用与主题协调的柔和色值，
/// 暗色下提高明度保证在近黑背景上可辨。句子按序号轮换主题色（见
/// [SubtitleSentenceColors]），同一句的波形、底色、单词都用同一色相，只用透明度区分
/// 选中与否。播放头用橙色细线，与绿 / 红边界和冷色句子都不撞色。
@immutable
class WaveformPalette {
  const WaveformPalette({
    required this.brightness,
    required this.bar,
    required this.start,
    required this.end,
    required this.playhead,
    required this.playheadOutline,
    required this.playheadShadow,
    required this.axis,
    required this.axisLabel,
  });

  factory WaveformPalette.of(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return WaveformPalette(
      brightness: scheme.brightness,
      bar: scheme.onSurfaceVariant.withValues(alpha: .3),
      start: isDark ? const Color(0xFF5FD08E) : const Color(0xFF1E9E5A),
      end: isDark ? const Color(0xFFFF7A70) : const Color(0xFFE04B3F),
      playhead: isDark ? const Color(0xFFFFA24A) : const Color(0xFFF07A12),
      // 手柄描一圈波形底色，压在彩色单词块上时轮廓仍清楚。
      playheadOutline: scheme.surfaceContainerHigh,
      playheadShadow: scheme.shadow.withValues(alpha: isDark ? .6 : .35),
      axis: scheme.onSurfaceVariant.withValues(alpha: .18),
      axisLabel: scheme.onSurfaceVariant.withValues(alpha: .7),
    );
  }

  final Brightness brightness;

  /// 不属于任何句子的波形（停顿、无字幕片段）。
  final Color bar;
  final Color start;
  final Color end;
  final Color playhead;
  final Color playheadOutline;
  final Color playheadShadow;
  final Color axis;
  final Color axisLabel;

  bool get _isDark => brightness == Brightness.dark;

  /// 第 [index] 句的主题色：选中句的波形、区间顶条、单词文字。
  Color sentenceColor(int index) =>
      SubtitleSentenceColors.of(index, brightness);

  /// 未选中句的波形：同色相、降低不透明度。
  Color sentenceBar(int index) =>
      sentenceColor(index).withValues(alpha: _isDark ? .55 : .5);

  /// 未选中句的区间底色：极淡铺底，一眼看出句与句的间隔。
  Color sentenceFill(int index) =>
      sentenceColor(index).withValues(alpha: _isDark ? .07 : .05);

  /// 选中句的区间底色。
  Color activeFill(int index) =>
      sentenceColor(index).withValues(alpha: _isDark ? .16 : .1);

  /// 未选中句顶部的整句文字。
  Color sentenceLabel(int index) => sentenceColor(index).withValues(alpha: .8);

  /// 选中句顶部单词块的底色；[isHighlighted] 为播放头所在词。
  Color wordChipFill(int index, {required bool isHighlighted}) =>
      sentenceColor(index).withValues(
        alpha: isHighlighted ? (_isDark ? .34 : .22) : (_isDark ? .16 : .1),
      );

  /// 播放头所在单词在波形上的区间底色（比选中句底色更深）。
  Color wordFill(int index) =>
      sentenceColor(index).withValues(alpha: _isDark ? .26 : .16);

  @override
  bool operator ==(Object other) =>
      other is WaveformPalette &&
      other.brightness == brightness &&
      other.bar == bar &&
      other.start == start &&
      other.end == end &&
      other.playhead == playhead &&
      other.playheadOutline == playheadOutline &&
      other.playheadShadow == playheadShadow &&
      other.axis == axis &&
      other.axisLabel == axisLabel;

  @override
  int get hashCode => Object.hash(
    brightness,
    bar,
    start,
    end,
    playhead,
    playheadOutline,
    playheadShadow,
    axis,
    axisLabel,
  );
}

/// 播放头层：顶部倒五边形手柄 + 橙色细线。
///
/// 字幕编辑要精确到词，所以线只有 1.5px（拖动时 2px），比 2.5px 的句子边界还细，
/// 两者重合时边界颜色从两侧露出。手柄放在顶部单词行里，平顶、尖端正好落在线的
/// 起点，指明精确时刻；线身与句子起止边界的线身等长（从波形顶到句子边界把手上沿），
/// 不挡底部把手。手柄是播放头的专属抓取区，线身与边界重叠时让给边界（见
/// [_SubtitleWaveformViewState._prefersPlayhead]）。
///
/// 与波形层分层 + 各自 RepaintBoundary：播放推进只重绘这条线，不触发波形层重绘。
class _PlayheadLayerPainter extends CustomPainter {
  final double x;
  final WaveformPalette palette;

  /// 正在拖动时手柄放大、线加粗，提示已抓住。
  final bool isActive;

  const _PlayheadLayerPainter({
    required this.x,
    required this.palette,
    required this.isActive,
  });

  /// 手柄宽度与顶部留白；尖端落在单词行下沿（即波形顶）。
  static const double handleWidth = 11;
  static const double _activeHandleWidth = 13;
  static const double _handleTop = 2;

  /// 线身下端：与句子起止边界线身的下端（把手上沿）对齐。
  static double lineBottom(double height) =>
      height -
      SubtitleWaveformView.axisHeight -
      SubtitleWaveformView.boundaryHandleAxisGap -
      _WaveformLayerPainter.sentenceEdgeHandleHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (x < -8 || x > size.width + 8) return;
    const tipY = _WaveformLayerPainter.labelLaneHeight;
    final lineWidth = isActive ? 2.0 : 1.5;
    canvas.drawRect(
      Rect.fromLTRB(
        x - lineWidth / 2,
        tipY - 1,
        x + lineWidth / 2,
        lineBottom(size.height),
      ),
      Paint()..color = palette.playhead,
    );

    final half = (isActive ? _activeHandleWidth : handleWidth) / 2;
    final top = isActive ? _handleTop - 1 : _handleTop;
    // 平顶占 55% 高度，其余收成尖；上方两角做小圆角。
    final shoulder = top + (tipY - top) * .55;
    const radius = 2.0;
    final handle = Path()
      ..moveTo(x - half + radius, top)
      ..lineTo(x + half - radius, top)
      ..quadraticBezierTo(x + half, top, x + half, top + radius)
      ..lineTo(x + half, shoulder)
      ..lineTo(x, tipY)
      ..lineTo(x - half, shoulder)
      ..lineTo(x - half, top + radius)
      ..quadraticBezierTo(x - half, top, x - half + radius, top)
      ..close();
    canvas
      ..drawShadow(handle, palette.playheadShadow, 1.5, false)
      ..drawPath(
        handle,
        Paint()
          ..color = palette.playheadOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(handle, Paint()..color = palette.playhead);
  }

  @override
  bool shouldRepaint(covariant _PlayheadLayerPainter oldDelegate) {
    return x != oldDelegate.x ||
        palette != oldDelegate.palette ||
        isActive != oldDelegate.isActive;
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

/// 无本地音频态：字幕仍可编辑，但没有音频输入可用于生成波形。
class _WaveformAudioMissing extends StatelessWidget {
  const _WaveformAudioMissing();

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
              Icons.music_off,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.waveformAudioMissing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
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

/// 波形层：只绘制**当前可见时间窗**（约 viewport/3 根竖条，与缩放无关），
/// 经 [metrics] + [viewOffset] 单一映射定位，故与播放头同一坐标空间、不可能错位。
class _WaveformLayerPainter extends CustomPainter {
  final WaveformPeaks peaks;
  final WaveformMetrics metrics;
  final double viewOffset;
  final List<Sentence> sentences;
  final Sentence? activeSentence;

  /// 选中句 + 前后相邻句的全部单词边界（含句子起止）。当前句为主样式，邻句为次样式。
  final List<WaveformWordBoundary> wordBoundaries;

  /// 播放头所在单词，淡色标出它的区间。
  final WordTimestamp? highlightedWord;
  final WaveformPalette palette;

  /// 句子文字与轴标签的系统文字缩放，与普通 Text 保持一致。
  final TextScaler textScaler;

  /// 波形竖条在内容坐标中的间距与粗细。
  static const double _barStep = 3;
  static const double _barWidth = 1.5;

  /// 顶部文字行的高度：未选中句显示整句，选中句显示逐词单词块；波形与边界线在其
  /// 下方绘制，文字不被压住。播放头手柄也在这一行。
  static const double labelLaneHeight = 18;

  /// 当前句起止边界把手的高度；播放头线身下端与它的上沿对齐。
  static const double sentenceEdgeHandleHeight = 18;

  /// 单词块在文字行内的上下留白（上方让出选中句顶部色条）。
  static const double _wordChipTop = 3.5;
  static const double _wordChipBottom = 1.5;

  /// 单词放不下时，块宽至少这么宽才显示省略后的文字；更窄时「w…」这类残字
  /// 没有辨识度，只画色块（仍可点击播放）。
  static const double _minEllipsisWordWidth = 30;

  /// 屏幕上相距不足该距离的边界合并为一个把手。
  static const double _mergeDistance = 4;

  const _WaveformLayerPainter({
    required this.peaks,
    required this.metrics,
    required this.viewOffset,
    required this.sentences,
    required this.activeSentence,
    required this.wordBoundaries,
    required this.highlightedWord,
    required this.palette,
    required this.textScaler,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 0.0;
    final viewport = size.width;
    final waveformBottom = size.height - SubtitleWaveformView.axisHeight;
    const waveTop = top + labelLaneHeight;
    final centerY = waveTop + (waveformBottom - waveTop) / 2;
    final usableHeight = waveformBottom - waveTop - 6;
    final totalUs = metrics.duration.inMicroseconds;
    if (usableHeight <= 0 || viewport <= 0 || totalUs <= 0) return;

    final active = activeSentence;
    final activeIndex = sentences.indexWhere((s) => identical(s, active));

    // 句子区间底色：有字幕处按句子主题色极淡铺底，停顿留白，一眼看出句与句的间隔。
    for (var i = 0; i < sentences.length; i++) {
      if (i == activeIndex) continue;
      final sentence = sentences[i];
      final sx = metrics.screenX(sentence.startTime, viewOffset);
      final ex = metrics.screenX(sentence.endTime, viewOffset);
      if (ex < 0 || sx > viewport) continue;
      canvas.drawRect(
        Rect.fromLTRB(sx, top, ex, waveformBottom),
        Paint()..color = palette.sentenceFill(i),
      );
    }
    // 当前句：主题色淡底 + 顶部主题色细条，标出正在编辑的区间。
    if (active != null && activeIndex >= 0) {
      final sx = metrics.screenX(active.startTime, viewOffset);
      final ex = metrics.screenX(active.endTime, viewOffset);
      canvas.drawRect(
        Rect.fromLTRB(sx, top, ex, waveformBottom),
        Paint()..color = palette.activeFill(activeIndex),
      );
      canvas.drawRect(
        Rect.fromLTRB(sx, top, ex, top + 2.5),
        Paint()..color = palette.sentenceColor(activeIndex),
      );
    }
    // 播放头所在单词：与句子列表里高亮的单词对应。
    final word = highlightedWord;
    if (word != null && activeIndex >= 0) {
      canvas.drawRect(
        Rect.fromLTRB(
          metrics.screenX(word.startTime, viewOffset),
          waveTop,
          metrics.screenX(word.endTime, viewOffset),
          waveformBottom,
        ),
        Paint()..color = palette.wordFill(activeIndex),
      );
    }

    final barPaint = Paint()
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;

    // 波形竖条：采样网格钉在**内容坐标**（content-x = k*step），而非屏幕坐标。
    // 这样每根柱子恒定代表同一采样点，滚动时随内容平移、高度不变——若钉屏幕坐标，
    // 同一屏幕位置每帧映射到不同采样点，柱高就会一帧一变地闪烁。
    // 竖条按时间递增，句子按时间排序，用游标查所在句，避免每根竖条遍历全部句子。
    var sentenceCursor = 0;
    final startK = (viewOffset / _barStep).floor();
    for (var k = startK; ; k++) {
      final cx = k * _barStep; // 内容坐标（稳定网格）
      final sx = cx - viewOffset; // 屏幕坐标
      if (sx > viewport) break;
      if (sx < 0) continue;
      final rel = cx - metrics.padding;
      if (rel < 0 || rel > metrics.contentUsable) continue; // 落在留白/越界处
      final frac = metrics.contentUsable <= 0
          ? 0.0
          : rel / metrics.contentUsable;
      if (peaks.length == 0) break;
      final sampleIndex = (frac * peaks.length).round().clamp(
        0,
        peaks.length - 1,
      );
      // 流式生成中尚未解码到的位置不画，留白等待后续像素。
      if (sampleIndex >= peaks.readyLength) continue;
      final min = peaks.minAt(sampleIndex);
      final max = peaks.maxAt(sampleIndex);
      // 至少保留 1px 高度，静音处也连成一条细线，时间轴不显得断裂。
      final minY = math.min(
        centerY + _normalize(min, usableHeight),
        centerY - .5,
      );
      final maxY = math.max(
        centerY + _normalize(max, usableHeight),
        centerY + .5,
      );
      final positionUs = totalUs * frac;
      while (sentenceCursor < sentences.length &&
          sentences[sentenceCursor].endTime.inMicroseconds < positionUs) {
        sentenceCursor++;
      }
      final inSentence =
          sentenceCursor < sentences.length &&
          positionUs >= sentences[sentenceCursor].startTime.inMicroseconds;
      barPaint.color = !inSentence
          ? palette.bar
          : sentenceCursor == activeIndex
          ? palette.sentenceColor(sentenceCursor)
          : palette.sentenceBar(sentenceCursor);
      canvas.drawLine(Offset(sx, minY), Offset(sx, maxY), barPaint);
    }

    // 顶部文字行：未选中句画整句，选中句画逐词单词块（有词时）。
    final activeWords = [
      for (final b in wordBoundaries)
        if (b.primary) b.word,
    ];
    _drawSentenceTexts(
      canvas,
      viewport,
      top,
      skipIndex: activeWords.isEmpty ? null : activeIndex,
    );
    if (activeWords.isNotEmpty && activeIndex >= 0) {
      _drawActiveWords(canvas, viewport, top, activeWords, activeIndex);
    }

    // 句子边界 + 词边界统一去重绘制（见 _drawBoundaries）。
    _drawBoundaries(canvas, viewport, waveTop, waveformBottom);

    // 播放头由独立的 _PlayheadLayerPainter 绘制，不在此层。
    _drawTimeAxis(canvas: canvas, size: size, waveformBottom: waveformBottom);
  }

  /// 在波形顶部绘制每句文本：左对齐到句起点（随内容平移），并裁剪到该句的屏幕
  /// 区间内，避免文字溢出到相邻句。仅画可见句以省开销。[skipIndex] 为改画逐词
  /// 单词块的选中句。
  void _drawSentenceTexts(
    Canvas canvas,
    double viewport,
    double top, {
    required int? skipIndex,
  }) {
    const leftPad = 6.0; // 让文字让开起始把手
    const textTop = 4.0;
    for (var i = 0; i < sentences.length; i++) {
      if (i == skipIndex) continue;
      final s = sentences[i];
      if (s.text.trim().isEmpty) continue;
      final sx = metrics.screenX(s.startTime, viewOffset);
      final ex = metrics.screenX(s.endTime, viewOffset);
      if (ex < 0 || sx > viewport) continue; // 不可见
      final clipLeft = sx < 0 ? 0.0 : sx;
      final clipRight = ex > viewport ? viewport : ex;
      if (clipRight - clipLeft < 8) continue; // 太窄，放不下字
      final isActive = identical(s, activeSentence);
      final style = TextStyle(
        color: isActive ? palette.sentenceColor(i) : palette.sentenceLabel(i),
        fontSize: 10,
        height: 1.1,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      );
      final painter = TextPainter(
        text: TextSpan(text: s.text.trim(), style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (ex - sx - leftPad * 2).clamp(0.0, double.infinity));
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(clipLeft, top, clipRight, top + labelLaneHeight),
      );
      painter.paint(canvas, Offset(sx + leftPad, top + textTop));
      canvas.restore();
    }
  }

  /// 选中句的逐词单词块：每个词一个圆角色块，文字居中在该词的时间区间内，用户
  /// 不必回到句子列表就能定位单词、点按试听。播放头所在词加深并加粗。
  void _drawActiveWords(
    Canvas canvas,
    double viewport,
    double top,
    List<WordTimestamp> words,
    int sentenceIndex,
  ) {
    final color = palette.sentenceColor(sentenceIndex);
    final highlighted = highlightedWord;
    for (final word in words) {
      final rect = wordChipRect(
        metrics.screenX(word.startTime, viewOffset),
        metrics.screenX(word.endTime, viewOffset),
        top,
      );
      if (rect.right < 0 || rect.left > viewport || rect.width <= 0) continue;
      final isHighlighted =
          highlighted != null &&
          highlighted.startTime == word.startTime &&
          highlighted.endTime == word.endTime;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = palette.wordChipFill(
            sentenceIndex,
            isHighlighted: isHighlighted,
          ),
      );
      final text = word.word.trim();
      if (text.isEmpty || rect.width <= 4) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            height: 1.1,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 4);
      if (painter.didExceedMaxLines && rect.width < _minEllipsisWordWidth) {
        continue;
      }
      canvas.save();
      canvas.clipRect(rect);
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.center.dy - painter.height / 2,
        ),
      );
      canvas.restore();
    }
  }

  /// 单词块在文字行内的矩形：左右各缩进半像素，相邻词首尾相接时仍有细缝。
  static Rect wordChipRect(double startX, double endX, double top) =>
      Rect.fromLTRB(
        startX + .5,
        top + _wordChipTop,
        endX - .5,
        top + labelLaneHeight - _wordChipBottom,
      );

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
    // 按屏幕位置聚合：相距不足 [_mergeDistance] 的边界（相邻词首尾相接）画成一个
    // 双色把手，避免一排挤在一起的小把手；拖动命中仍按各自边界判定。
    final markers = <_BoundaryMarker>[];
    void add(
      Duration t, {
      required bool isStart,
      required bool primary,
      required bool isSentenceEdge,
    }) {
      final x = metrics.screenX(t, viewOffset);
      for (var i = 0; i < markers.length; i++) {
        final m = markers[i];
        if ((m.x - x).abs() < _mergeDistance) {
          markers[i] = (
            x: m.x,
            hasStart: m.hasStart || isStart,
            hasEnd: m.hasEnd || !isStart,
            primary: m.primary || primary,
            isSentenceEdge: m.isSentenceEdge || isSentenceEdge,
          );
          return;
        }
      }
      markers.add((
        x: x,
        hasStart: isStart,
        hasEnd: !isStart,
        primary: primary,
        isSentenceEdge: isSentenceEdge,
      ));
    }

    for (final b in wordBoundaries) {
      add(
        b.word.startTime,
        isStart: true,
        primary: b.primary,
        isSentenceEdge: b.isSentenceStart,
      );
      add(
        b.word.endTime,
        isStart: false,
        primary: b.primary,
        isSentenceEdge: b.isSentenceEnd,
      );
    }

    // 次样式先画、主样式后画，句子起止最后画，最重要的把手叠在最上层。
    int rank(_BoundaryMarker m) =>
        (m.primary ? 1 : 0) + (m.primary && m.isSentenceEdge ? 1 : 0);
    markers.sort((a, b) => rank(a).compareTo(rank(b)));
    for (final m in markers) {
      _drawBoundaryIfVisible(
        canvas,
        m.x,
        viewport,
        top,
        bottom,
        hasStart: m.hasStart,
        hasEnd: m.hasEnd,
        style: !m.primary
            ? _BoundaryStyle.neighbor
            : m.isSentenceEdge
            ? _BoundaryStyle.sentenceEdge
            : _BoundaryStyle.word,
      );
    }
  }

  /// 仅当边界落在视口内（含少量外扩，容纳把手）时绘制竖线 + 底部把手。
  ///
  /// 三级样式（见 [_BoundaryStyle]）：当前句起止最醒目，句内词边界次之，相邻句
  /// 最淡，让用户先看到「这句从哪到哪」，再看到可微调的词边界。把手为圆角胶囊。
  /// 当同一位置同时有「结束(红)」和「起始(绿)」边界（相邻词首尾相接）时，竖线与
  /// 把手都分成**左红右绿**：左 = 上一段的结束、右 = 下一段的开始，对应拖动方向
  /// （向左抓结束 / 向右抓开始）——业界 NLE 双修剪手柄约定。
  ///
  /// 把手只是视觉提示，命中区按 `_hitTestBoundaries` 的固定宽度判定，不随样式缩小。
  void _drawBoundaryIfVisible(
    Canvas canvas,
    double x,
    double viewport,
    double top,
    double bottom, {
    required bool hasStart,
    required bool hasEnd,
    required _BoundaryStyle style,
  }) {
    if (x < -12 || x > viewport + 12) return;
    final (lineAlpha, handleAlpha, lineWidth, width, height) = switch (style) {
      _BoundaryStyle.sentenceEdge => (
        .95,
        1.0,
        2.5,
        11.0,
        sentenceEdgeHandleHeight,
      ),
      _BoundaryStyle.word => (.8, .95, 2.0, 9.0, 14.0),
      _BoundaryStyle.neighbor => (.4, .55, 1.5, 7.0, 10.0),
    };
    final lineHalf = lineWidth / 2;
    // 相邻词首尾相接时一条线分成左红右绿两半，每半也要和单色线一样粗，否则两色
    // 细到看不清。
    final dualHalf = lineWidth * .75;
    final handleBottom = bottom - SubtitleWaveformView.boundaryHandleAxisGap;
    final rect = Rect.fromCenter(
      center: Offset(x, handleBottom - height / 2),
      width: width,
      height: height,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(width / 2));

    if (hasStart && hasEnd) {
      canvas.drawRect(
        Rect.fromLTRB(x - dualHalf, top, x, rect.top),
        Paint()..color = palette.end.withValues(alpha: lineAlpha),
      );
      canvas.drawRect(
        Rect.fromLTRB(x, top, x + dualHalf, rect.top),
        Paint()..color = palette.start.withValues(alpha: lineAlpha),
      );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, x, rect.bottom),
        Paint()..color = palette.end.withValues(alpha: handleAlpha),
      );
      canvas.drawRect(
        Rect.fromLTRB(x, rect.top, rect.right, rect.bottom),
        Paint()..color = palette.start.withValues(alpha: handleAlpha),
      );
      canvas.restore();
      return;
    }
    final color = hasStart ? palette.start : palette.end;
    canvas.drawRect(
      Rect.fromLTRB(x - lineHalf, top, x + lineHalf, rect.top),
      Paint()..color = color.withValues(alpha: lineAlpha),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: handleAlpha),
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
      ..color = palette.axis
      ..strokeWidth = 1;
    // 轴底线横跨视口。
    canvas.drawLine(Offset(0, axisTop), Offset(viewport, axisTop), axisPaint);

    final totalSeconds =
        metrics.duration.inMilliseconds / Duration.millisecondsPerSecond;
    if (totalSeconds <= 0) return;

    final pixelsPerSecond = metrics.contentUsable / totalSeconds;
    final majorStepSeconds = _majorStepSeconds(pixelsPerSecond);
    final minorStepSeconds = majorStepSeconds / 5;
    final textStyle = TextStyle(
      color: palette.axisLabel,
      fontSize: 10,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
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
        Offset(x, axisTop + (isMajor ? 6 : 3)),
        axisPaint,
      );
      if (isMajor) {
        final label = _formatAxisTime(
          Duration(milliseconds: (second * 1000).round()),
        );
        final paragraph = _axisLabel(label, textStyle);
        final labelX = x - paragraph.width / 2;
        if (labelX >= 2 && labelX + paragraph.width <= viewport - 2) {
          paragraph.paint(canvas, Offset(labelX, axisTop + 9));
        }
      }
    }
  }

  double _majorStepSeconds(double pixelsPerSecond) {
    if (pixelsPerSecond >= 60) return 2;
    if (pixelsPerSecond >= 30) return 5;
    if (pixelsPerSecond >= 16) return 10;
    if (pixelsPerSecond >= 8) return 30;
    return 60;
  }

  TextPainter _axisLabel(String text, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
  }

  String _formatAxisTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 按全段峰值归一化，低音量录音也能铺满波形区高度。
  double _normalize(int value, double height) {
    return (value / peaks.peak) * height / 2;
  }

  @override
  bool shouldRepaint(covariant _WaveformLayerPainter oldDelegate) {
    return viewOffset != oldDelegate.viewOffset ||
        metrics.contentUsable != oldDelegate.metrics.contentUsable ||
        metrics.viewport != oldDelegate.metrics.viewport ||
        metrics.duration != oldDelegate.metrics.duration ||
        !identical(peaks, oldDelegate.peaks) ||
        !identical(sentences, oldDelegate.sentences) ||
        activeSentence != oldDelegate.activeSentence ||
        highlightedWord?.startTime != oldDelegate.highlightedWord?.startTime ||
        highlightedWord?.endTime != oldDelegate.highlightedWord?.endTime ||
        // 按值比较词边界：词边界列表每帧重建，仅当时间 / 主次样式真正变化才重绘，
        // 避免播放时（实例每帧不同但内容相同）触发整层波形重绘。
        !_wordBoundariesEqual(wordBoundaries, oldDelegate.wordBoundaries) ||
        palette != oldDelegate.palette ||
        textScaler != oldDelegate.textScaler;
  }

  /// 词边界按时间值、主次样式与词文本比较（选中句的词文本画在顶部单词块里）。
  static bool _wordBoundariesEqual(
    List<WaveformWordBoundary> a,
    List<WaveformWordBoundary> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].word.startTime != b[i].word.startTime ||
          a[i].word.endTime != b[i].word.endTime ||
          a[i].word.word != b[i].word.word ||
          a[i].primary != b[i].primary) {
        return false;
      }
    }
    return true;
  }
}

/// 波形空隙里的「添加句子」胶囊按钮。
class _InsertSentenceButton extends StatelessWidget {
  const _InsertSentenceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const ValueKey('subtitle-waveform-insert-sentence'),
      color: scheme.primary,
      shape: const StadiumBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgActionIcon(
                assetName: 'assets/icon/plus.svg',
                size: 16,
                color: scheme.onPrimary,
              ),
              const SizedBox(width: 3),
              Text(
                AppLocalizations.of(context)!.subtitleAddSentenceHere,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

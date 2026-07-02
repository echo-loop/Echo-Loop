/// 可点词 + 词组选区的句子文本组件（统一标注卡与盲听偷看两套点词实现）
///
/// 交互模型（业界标准「点词查词 + 选区手柄扩选」）：
/// - 点单词：立即查该词（词典面板 [DictionaryPanelHost.show]），同时该词
///   成为选区并在两侧显示词级吸附的边界手柄；
/// - 拖动手柄：跨词扩展/收缩选区（吸附到词边界，支持跨行），松手后以
///   选区文本（词组）重新查询；
/// - 长按不占用：宿主外层的「长按复制整句」GestureDetector 原样生效
///   （手柄用 [ImmediateMultiDragGestureRecognizer] 按下即抢占，不与长按冲突）。
///
/// 几何实现：RichText（保排版）+ [RenderParagraph] 的
/// `getPositionForOffset` / `getBoxesForSelection` 做命中测试与手柄定位；
/// 手柄矩形在 post-frame 计算（首帧无手柄，下一帧出现，肉眼无感）。
///
/// 选区是组件局部 state：面板关闭或别的组件发起查词
/// （[DictionaryPanelHost.activeOwnerOf] 变化）时自动清除。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../models/speech_practice_models.dart';
import '../dictionary/dictionary_panel_host.dart';
import 'sentence_word_selection.dart';

/// 查词来源上下文（收藏溯源用），聚合原先散落的 5 个参数
class DictionaryLookupOrigin {
  /// 来源音频 ID（可选）
  final String? audioItemId;

  /// 来源句子索引（可选）
  final int? sentenceIndex;

  /// 来源句子文本
  final String? sentenceText;

  /// 来源句子起始时间（毫秒，可选）
  final int? sentenceStartMs;

  /// 来源句子结束时间（毫秒，可选）
  final int? sentenceEndMs;

  const DictionaryLookupOrigin({
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceText,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  /// 组装词典面板查询
  DictionaryPanelQuery queryFor(String word) => DictionaryPanelQuery(
    word: word,
    audioItemId: audioItemId,
    sentenceIndex: sentenceIndex,
    sentenceText: sentenceText,
    sentenceStartMs: sentenceStartMs,
    sentenceEndMs: sentenceEndMs,
  );
}

/// 可点词句子文本
class SelectableSentenceText extends StatefulWidget {
  /// 句子文本（无 [highlightedSegments] 时的渲染与分词来源）
  final String text;

  /// 文本样式
  final TextStyle? style;

  /// 高亮片段（跟读评分染色）；非空时渲染文本 = 片段拼接
  final List<SpeechTranscriptSegment>? highlightedSegments;

  /// 查词来源上下文（收藏溯源）
  final DictionaryLookupOrigin origin;

  /// 查词前副作用钩子（盲听进入等待用户态、标注卡切手动模式等）。
  /// 点词与词组松手时、面板 show 之前触发。
  final VoidCallback? onBeforeLookup;

  const SelectableSentenceText({
    super.key,
    required this.text,
    this.style,
    this.highlightedSegments,
    this.origin = const DictionaryLookupOrigin(),
    this.onBeforeLookup,
  });

  @override
  State<SelectableSentenceText> createState() => _SelectableSentenceTextState();
}

class _SelectableSentenceTextState extends State<SelectableSentenceText> {
  /// RichText 的 key，用于获取 RenderParagraph 做几何查询
  final GlobalKey _textKey = GlobalKey();

  /// 分词结果（text/segments 变化时重建）
  late List<WordToken> _tokens = tokenizeSentence(_fullText);

  /// 当前选区（null = 无选区）
  WordSelection? _selection;

  /// 手柄锚点矩形（post-frame 由 RenderParagraph 计算；选区首/末词的行内 box）
  Rect? _startAnchor;
  Rect? _endAnchor;

  /// 手柄命中区边长
  static const double _kHandleHitSize = 36;

  /// 手柄圆点直径（iOS 系统选择手柄同款圆点，略放大便于点按）
  static const double _kHandleDotSize = 12;

  /// 选区边界竖线宽度
  static const double _kCaretWidth = 2;

  /// 已注册豁免区域的宿主（组件卸载时按同一实例注销）
  DictionaryPanelHostState? _host;

  /// 渲染文本：有高亮片段时为片段拼接，否则为原句
  String get _fullText {
    final segs = widget.highlightedSegments;
    if (segs == null || segs.isEmpty) return widget.text;
    return segs.map((s) => s.text).join();
  }

  RenderParagraph? get _paragraph {
    final obj = _textKey.currentContext?.findRenderObject();
    return obj is RenderParagraph ? obj : null;
  }

  @override
  void didUpdateWidget(SelectableSentenceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 文本重排（换句/评分片段更新）即清选区并重新分词，避免陈旧几何
    final oldFull = oldWidget.highlightedSegments?.map((s) => s.text).join();
    final oldText = (oldFull == null || oldFull.isEmpty)
        ? oldWidget.text
        : oldFull;
    if (oldText != _fullText) {
      _tokens = tokenizeSentence(_fullText);
      _clearSelection();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 向宿主注册屏障豁免区域：面板开着时点本组件（词/手柄）仍放行，
    // 点区域外则由宿主屏障关面板并吸收点击。
    final host = DictionaryPanelHost.maybeOf(context);
    if (!identical(host, _host)) {
      _host?.unregisterTapThroughRegion(_tapThroughRect);
      _host = host;
      _host?.registerTapThroughRegion(_tapThroughRect);
    }
    // 面板关闭或别的组件发起了查词：清掉本组件的选区高亮/手柄。
    // （didChangeDependencies 本就处于重建流程，直接改字段即可）
    final owner = DictionaryPanelHost.activeOwnerOf(context);
    if (_selection != null && !identical(owner, this)) {
      _selection = null;
      _startAnchor = null;
      _endAnchor = null;
    }
  }

  @override
  void dispose() {
    _host?.unregisterTapThroughRegion(_tapThroughRect);
    super.dispose();
  }

  /// 屏障豁免区域（全局坐标）：组件自身 + 手柄外扩
  /// （左右各半个命中区、上下各一个命中区，覆盖越界的手柄——
  /// 起始圆点悬在首行上方、结束圆点悬在末行下方）
  Rect _tapThroughRect() {
    final obj = context.findRenderObject();
    if (obj is! RenderBox || !obj.attached || !obj.hasSize) return Rect.zero;
    final topLeft = obj.localToGlobal(Offset.zero);
    return Rect.fromLTRB(
      topLeft.dx - _kHandleHitSize / 2,
      topLeft.dy - _kHandleHitSize,
      topLeft.dx + obj.size.width + _kHandleHitSize / 2,
      topLeft.dy + obj.size.height + _kHandleHitSize,
    );
  }

  void _clearSelection() {
    _selection = null;
    _startAnchor = null;
    _endAnchor = null;
  }

  // -- 查词触发 --

  /// 设置选区并查询其文本
  void _selectAndLookup(WordSelection sel) {
    setState(() => _selection = sel);
    _scheduleAnchorUpdate();
    widget.onBeforeLookup?.call();
    DictionaryPanelHost.of(
      context,
    ).show(widget.origin.queryFor(sel.textOf(_fullText, _tokens)), owner: this);
  }

  /// 点词：命中词内才触发（点空白/标点不查询）
  void _handleTapUp(TapUpDetails details) {
    final para = _paragraph;
    if (para == null || _tokens.isEmpty) return;
    final pos = para.getPositionForOffset(details.localPosition);
    // 光标位可能落在词右边界（== end），前移一位再判定
    var idx = wordTokenAtChar(_tokens, pos.offset);
    if (idx < 0 && pos.offset > 0) {
      idx = wordTokenAtChar(_tokens, pos.offset - 1);
    }
    if (idx < 0) return;
    // box 包含判定：防止行尾空白区域反查到最近词而误触发
    final t = _tokens[idx];
    final boxes = para.getBoxesForSelection(
      TextSelection(baseOffset: t.start, extentOffset: t.end),
    );
    final hit = boxes.any(
      (b) => b.toRect().inflate(2).contains(details.localPosition),
    );
    if (!hit) return;
    _selectAndLookup(WordSelection(idx, idx));
  }

  // -- 手柄拖拽 --

  /// 手柄拖拽中把手指位置换算为文本内字符偏移并做词级吸附
  void _updateSelectionFromDrag(bool isStartHandle, Offset globalPosition) {
    final para = _paragraph;
    final sel = _selection;
    if (para == null || sel == null) return;
    final local = para.globalToLocal(globalPosition);
    final pos = para.getPositionForOffset(local);
    final snapped = snapToWordToken(_tokens, pos.offset);
    if (snapped < 0) return;
    // 手柄不越过对侧（交叉时 clamp 成单词选区，系统文本选择同款行为）
    final next = isStartHandle
        ? WordSelection(
            snapped <= sel.endToken ? snapped : sel.endToken,
            sel.endToken,
          )
        : WordSelection(
            sel.startToken,
            snapped >= sel.startToken ? snapped : sel.startToken,
          );
    if (next != sel) {
      setState(() => _selection = next);
      _scheduleAnchorUpdate();
    }
  }

  /// 手柄松手：以当前选区文本查询（与上次查询相同则不重复触发）
  void _handleDragEnd() {
    final sel = _selection;
    if (sel == null) return;
    widget.onBeforeLookup?.call();
    DictionaryPanelHost.of(
      context,
    ).show(widget.origin.queryFor(sel.textOf(_fullText, _tokens)), owner: this);
  }

  // -- 手柄几何 --

  /// post-frame 重算手柄锚点（选区变化/布局完成后 RenderParagraph 才有最新 box）
  void _scheduleAnchorUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateAnchors();
    });
  }

  void _updateAnchors() {
    final para = _paragraph;
    final sel = _selection;
    if (para == null || sel == null) {
      if (_startAnchor != null || _endAnchor != null) {
        setState(() {
          _startAnchor = null;
          _endAnchor = null;
        });
      }
      return;
    }
    final startTok = _tokens[sel.startToken];
    final endTok = _tokens[sel.endToken];
    final startBoxes = para.getBoxesForSelection(
      TextSelection(baseOffset: startTok.start, extentOffset: startTok.end),
    );
    final endBoxes = para.getBoxesForSelection(
      TextSelection(baseOffset: endTok.start, extentOffset: endTok.end),
    );
    if (startBoxes.isEmpty || endBoxes.isEmpty) return;
    final newStart = startBoxes.first.toRect();
    final newEnd = endBoxes.last.toRect();
    if (newStart != _startAnchor || newEnd != _endAnchor) {
      setState(() {
        _startAnchor = newStart;
        _endAnchor = newEnd;
      });
    }
  }

  // -- 构建 --

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        widget.style ??
        theme.textTheme.titleMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface,
        );
    final rich = RichText(
      key: _textKey,
      text: TextSpan(style: style, children: _buildSpans(theme)),
    );
    // 选区存在时布局可能变化（旋屏/字号），每帧后校正手柄位置
    if (_selection != null) _scheduleAnchorUpdate();
    // 手柄悬在文本 bounds 之外（首行上方/末行下方/行首左侧），普通 Stack 的命中测试
    // 会在 size.contains 处提前剪裁——用越界命中 Stack 保证手柄全域可拖。
    return _UnboundedHitStack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTapUp,
          child: rich,
        ),
        if (_selection != null && _startAnchor != null) ...[
          _buildCaretLine(theme, isStartHandle: true, anchor: _startAnchor!),
          _buildHandle(theme, isStartHandle: true, anchor: _startAnchor!),
        ],
        if (_selection != null && _endAnchor != null) ...[
          _buildCaretLine(theme, isStartHandle: false, anchor: _endAnchor!),
          _buildHandle(theme, isStartHandle: false, anchor: _endAnchor!),
        ],
      ],
    );
  }

  /// 逐 token 构建 span：选区染背景色，评分片段染文字色
  List<InlineSpan> _buildSpans(ThemeData theme) {
    final selectionColor = theme.colorScheme.primary.withValues(alpha: 0.15);
    final (selStart, selEnd) = _selection?.charRangeOf(_tokens) ?? (-1, -1);
    final colorAt = _segmentColorLookup();
    return [
      for (final t in _tokens)
        TextSpan(
          text: t.text,
          style: TextStyle(
            color: colorAt(t.start),
            backgroundColor: (t.start >= selStart && t.end <= selEnd)
                ? selectionColor
                : null,
          ),
        ),
    ];
  }

  /// 评分片段颜色查询：字符偏移 → 文字色（无片段时恒 null）
  Color? Function(int) _segmentColorLookup() {
    final segs = widget.highlightedSegments;
    if (segs == null || segs.isEmpty) return (_) => null;
    // 预计算各片段的字符区间（拼接顺序即偏移顺序）
    final ranges = <(int, int, bool)>[];
    var offset = 0;
    for (final s in segs) {
      ranges.add((offset, offset + s.text.length, s.isMatched));
      offset += s.text.length;
    }
    return (charOffset) {
      for (final (start, end, matched) in ranges) {
        if (charOffset >= start && charOffset < end) {
          // 命中片段沿用既有跟读评分绿色
          return matched ? const Color(0xFF2E9B51) : null;
        }
      }
      return null;
    };
  }

  /// 选区边界竖线（caret，纯视觉）：贴选区首/末词行盒的边界，高度=行高
  Widget _buildCaretLine(
    ThemeData theme, {
    required bool isStartHandle,
    required Rect anchor,
  }) {
    final x = isStartHandle ? anchor.left : anchor.right;
    return Positioned(
      left: x - _kCaretWidth / 2,
      top: anchor.top,
      child: IgnorePointer(
        child: Container(
          width: _kCaretWidth,
          height: anchor.height,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  /// 选区边界手柄：iOS 系统选择手柄同款圆点（起始手柄圆点悬在竖线上端，
  /// 结束手柄悬在竖线下端，圆点与竖线端点相切），直径较系统略大便于点按。
  /// 命中区 36dp、以圆点为中心；用 [ImmediateMultiDragGestureRecognizer]
  /// 按下即赢得手势竞技场，压制外层滚动/横滑/长按（系统选择手柄同款思路）。
  Widget _buildHandle(
    ThemeData theme, {
    required bool isStartHandle,
    required Rect anchor,
  }) {
    final x = isStartHandle ? anchor.left : anchor.right;
    // 圆点中心：起始 = 竖线上端再上移半径，结束 = 竖线下端再下移半径
    final dotCenterY = isStartHandle
        ? anchor.top - _kHandleDotSize / 2
        : anchor.bottom + _kHandleDotSize / 2;
    return Positioned(
      left: x - _kHandleHitSize / 2,
      top: dotCenterY - _kHandleHitSize / 2,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer
              >(ImmediateMultiDragGestureRecognizer.new, (recognizer) {
                recognizer.onStart = (offset) => _HandleDrag(
                  onUpdate: (d) =>
                      _updateSelectionFromDrag(isStartHandle, d.globalPosition),
                  onEnd: _handleDragEnd,
                );
              }),
        },
        child: SizedBox(
          key: Key(isStartHandle ? 'word_handle_start' : 'word_handle_end'),
          width: _kHandleHitSize,
          height: _kHandleHitSize,
          child: Center(
            child: Container(
              width: _kHandleDotSize,
              height: _kHandleDotSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 越界命中 Stack：不做自身 size 的提前剪裁，允许命中悬在文本 bounds
/// 之外的选区手柄（首行上方、末行下方、行首左侧）。仅用于本组件内部。
class _UnboundedHitStack extends Stack {
  const _UnboundedHitStack({super.children}) : super(clipBehavior: Clip.none);

  @override
  RenderStack createRenderObject(BuildContext context) =>
      _RenderUnboundedHitStack(
        textDirection: textDirection ?? Directionality.maybeOf(context),
        alignment: alignment,
        fit: fit,
        clipBehavior: clipBehavior,
      );
}

/// [_UnboundedHitStack] 的 render object
class _RenderUnboundedHitStack extends RenderStack {
  _RenderUnboundedHitStack({
    super.textDirection,
    super.alignment,
    super.fit,
    super.clipBehavior,
  });

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 跳过 RenderBox 默认的 size.contains 剪裁，直接测试子节点
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// 手柄拖拽会话（ImmediateMultiDrag 的 Drag 回调载体）
class _HandleDrag extends Drag {
  final void Function(DragUpdateDetails) onUpdate;
  final VoidCallback onEnd;

  _HandleDrag({required this.onUpdate, required this.onEnd});

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() {}
}

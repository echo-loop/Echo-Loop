/// 单段可选文本（自有选区的组装件）
///
/// 把交互内核 [SelectableContent] 与单段后端 [ParagraphSelectionBackend] 装在
/// 一起：内容是一个 `RichText`，字符空间与分词偏移由调用方给定的 [text] 决定
/// （渲染 span 也从同一份文本切出，两者严格同源）。
///
/// 跨块内容（markdown / AI 回答）用同一个内核换 [MultiParagraphSelectionBackend]，
/// 见 `features/chatbot/widgets/selectable_assistant_markdown.dart`。
///
/// 本组件不知道「查词」「词典面板」的存在：选区确认后只回调
/// [onSelectionCommitted]，操作条内容由 [actionsBuilder] 提供。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'paragraph_selection_backend.dart';
import 'selectable_content.dart';
import 'selection_backend.dart';
import 'selection_toolbar.dart';
import 'selection_toolbar_layer.dart';
import 'text_selection_session.dart';

/// 自有选区的单段可选文本。
class AppSelectableText extends StatefulWidget {
  const AppSelectableText({
    super.key,
    required this.text,
    required this.spanBuilder,
    required this.wordRange,
    required this.actionsBuilder,
    this.style,
    this.onSelectionCommitted,
    this.onBeforeSelectionCommitted,
    this.onSessionEnded,
    this.onShowToolbar,
    this.onHideToolbar,
  });

  /// 渲染纯文本：分词、字符偏移与取文本的唯一依据。
  final String text;

  /// 构建正文 span（收藏下划线、评分染色等由调用方决定）。
  final List<InlineSpan> Function(BuildContext context) spanBuilder;

  /// 词边界策略（点词用）。查词场景必须注入词典自己的分词规则。
  final WordRangeResolver wordRange;

  /// 操作条动作；入参为当前选中文本。返回空列表则不显示操作条。
  final List<SelectionToolbarAction> Function(String selectedText)
  actionsBuilder;

  /// 文本样式。
  final TextStyle? style;

  /// 选区确认（点词或松手）时回调选中文本。
  final ValueChanged<String>? onSelectionCommitted;

  /// 选区确认**之前**的副作用钩子（如暂停自动推进）。
  final VoidCallback? onBeforeSelectionCommitted;

  /// 会话结束（点空白、内容变化、外部显式结束）时回调。
  final VoidCallback? onSessionEnded;

  /// 挂载/更新选区操作条（必须由页面级宿主渲染，见 [SelectionToolbarRequest]）。
  final ValueChanged<SelectionToolbarRequest>? onShowToolbar;

  /// 收起选区操作条；入参为 owner 身份（卸载后仍可调用，见 [SelectableContent]）。
  final ValueChanged<Object>? onHideToolbar;

  @override
  State<AppSelectableText> createState() => AppSelectableTextState();
}

/// [AppSelectableText] 的 state：转发内核能力，并额外暴露段落渲染节点。
class AppSelectableTextState extends State<AppSelectableText> {
  final GlobalKey _textKey = GlobalKey();
  final GlobalKey<SelectableContentState> _contentKey =
      GlobalKey<SelectableContentState>();

  /// L3：单段后端。渲染节点惰性取值（重建会换实例，不能缓存）。
  late final SelectionBackend _backend = ParagraphSelectionBackend(
    paragraph: () => contentParagraph,
    text: () => widget.text,
    wordRange: (offset) => widget.wordRange(offset),
  );

  SelectableContentState? get _content => _contentKey.currentState;

  /// 正文段落渲染节点。
  ///
  /// 公开给宿主与测试做几何断言（取某个词的屏幕位置、校验高亮矩形）；组件内部
  /// 的几何一律走 [SelectionBackend]，不直接依赖这里。
  RenderParagraph? get contentParagraph {
    final object = _textKey.currentContext?.findRenderObject();
    return object is RenderParagraph ? object : null;
  }

  /// 是否有已确认的选区。
  bool get hasActiveSelection => _content?.hasActiveSelection ?? false;

  /// 当前选区字符区间（无选区为 null）。
  TextRange? get selectionRange => _content?.selectionRange;

  /// 当前会话阶段。
  TextSelectionPhase get selectionPhase =>
      _content?.selectionPhase ?? TextSelectionPhase.idle;

  /// 当前选中文本（无选区时为空串）。
  String get selectedText => _content?.selectedText ?? '';

  /// 显式结束会话（面板关闭、别处发起查词、复制/问 AI 之后）。
  void endSession({bool notify = true}) => _content?.endSession(notify: notify);

  /// 全局坐标是否命中本组件的交互区域（正文 bounds ∪ 手柄命中区）。
  bool hitTest(Offset globalPosition) =>
      _content?.hitTest(globalPosition) ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        widget.style ??
        theme.textTheme.titleMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface,
        );
    return SelectableContent(
      key: _contentKey,
      backend: _backend,
      contentIdentity: widget.text,
      actionsBuilder: widget.actionsBuilder,
      // 业务层用 AppSelectableTextState 调宿主收起操作条，owner 必须是同一对象。
      toolbarOwner: this,
      onSelectionCommitted: widget.onSelectionCommitted,
      onBeforeSelectionCommitted: widget.onBeforeSelectionCommitted,
      onSessionEnded: widget.onSessionEnded,
      onShowToolbar: widget.onShowToolbar,
      onHideToolbar: widget.onHideToolbar,
      child: RichText(
        key: _textKey,
        text: TextSpan(style: style, children: widget.spanBuilder(context)),
        // RichText 默认不跟随系统文字缩放，需与 Text 保持一致
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }
}

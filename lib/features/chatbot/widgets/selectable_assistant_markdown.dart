/// 可选中的 AI 回答 markdown：官方 SelectionArea + 自定义选区操作条（复制 / 问 AI）。
///
/// 采用 Flutter 标准文本选择方案（[SelectionArea] + `contextMenuBuilder`），三端一致、
/// 贴官方惯用法，避免自定义手柄/放大镜/桌面分支带来的踩坑：
/// - 长按/拖拽手柄自由选中任意连续文本（跨 markdown 块、含行内代码 `` `code` ``）；
/// - 选区完成后在选区上方中间弹出操作条（复制 / 问 AI）；
/// - 「点已选中文本切换操作条显隐、点选区外清除选区」均由框架原生处理，本组件不干预。
///
/// 内部复用 [MarkdownMessage]（`selectable: false`，选区统一由本组件的 [SelectionArea]
/// 接管），保持 markdown 渲染逻辑单一来源。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import 'markdown_message.dart';
import 'selection_toolbar.dart';

/// 选中背景色（标准浅蓝，对齐发送按钮蓝，低透明度不遮挡文字）。
const Color _kSelectionColor = Color(0x470A84FF);

/// AI 回答 markdown（可选中）。
///
/// - [data]：markdown 源文本；
/// - [style]：文字样式（随气泡主题传入）；
/// - [onFollowUp]：点「问 AI」时回调，携带当前选区纯文本；为空则不显示该按钮。
class SelectableAssistantMarkdown extends StatefulWidget {
  const SelectableAssistantMarkdown({
    super.key,
    required this.data,
    this.style,
    this.onFollowUp,
  });

  final String data;
  final TextStyle? style;
  final void Function(String selectedText)? onFollowUp;

  @override
  State<SelectableAssistantMarkdown> createState() =>
      _SelectableAssistantMarkdownState();
}

class _SelectableAssistantMarkdownState
    extends State<SelectableAssistantMarkdown> {
  /// 当前选区纯文本（由 `onSelectionChanged` 跟踪，供复制/问 AI 读取）。
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    // 覆盖框架默认灰色选中背景为标准浅蓝。
    return DefaultSelectionStyle(
      selectionColor: _kSelectionColor,
      child: SelectionArea(
        contextMenuBuilder: _buildToolbar,
        onSelectionChanged: (content) =>
            _selectedText = content?.plainText ?? '',
        child: MarkdownMessage(
          data: widget.data,
          selectable: false,
          style: widget.style,
        ),
      ),
    );
  }

  /// 选区操作条：选区完成后在选区上方中间自动弹出「复制 / 问 AI」（选择/改选过程中
  /// 由框架自动隐藏，settle 后才弹）。
  ///
  /// 气泡样式与按钮交互由可复用组件 [SelectionToolbar] 承载；本组件只提供锚点与动作。
  Widget _buildToolbar(BuildContext context, SelectableRegionState state) {
    final l10n = AppLocalizations.of(context)!;
    return SelectionToolbar(
      anchors: SelectionToolbar.anchorsForSelection(state),
      actions: [
        SelectionToolbarAction(
          label: l10n.chatCopy,
          onPressed: () => _handleCopy(state),
        ),
        if (widget.onFollowUp != null)
          SelectionToolbarAction(
            label: l10n.chatFollowUp,
            onPressed: () => _handleFollowUp(state),
          ),
      ],
    );
  }

  /// 复制：写入剪贴板，收起操作条并清空选区。
  void _handleCopy(SelectableRegionState state) {
    final text = _selectedText;
    if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
    state.hideToolbar();
    state.clearSelection();
  }

  /// 问 AI：先取选区文本再清空（[SelectableRegionState.clearSelection] 会同步触发
  /// `onSelectionChanged` 把 [_selectedText] 置空），收起操作条后回调。
  void _handleFollowUp(SelectableRegionState state) {
    final text = _selectedText;
    state.hideToolbar();
    state.clearSelection();
    if (text.trim().isNotEmpty) widget.onFollowUp?.call(text);
  }
}

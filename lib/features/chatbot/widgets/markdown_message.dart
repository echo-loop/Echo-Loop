/// gpt_markdown 薄封装：隔离第三方渲染库。
///
/// 链接经 url_launcher 外开。未来换渲染库只改此文件。
/// 相对库默认做了三处样式修正：
/// - 行内代码 `code`：默认是「加粗 + 无圆角紧贴灰底」。用 [_InlineCodeMd] 换成
///   等宽、常规字重、浅底的 **TextSpan**（而非 WidgetSpan）——TextSpan 按基线对齐，
///   避免标题等大字号行里「数字与代码块不在同一水平线」的错位（WidgetSpan 会被库
///   强制按行居中）。
/// - quote 竖条：默认取 onSurfaceVariant（偏深，观感发黑）→ 用 Theme 局部把该色
///   调淡（库内该色仅用于 quote 竖条）。
/// - 表格：默认横向滚动（手机需左右滑）→ 改为按屏宽等分列、单元格内换行。
library;

import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/markdown_config.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// 行内代码组件：在库默认 inline 组件基础上替换 [HighlightedText]。
final List<MarkdownComponent> _inlineComponents = [
  for (final c in MarkdownComponent.inlineComponents)
    if (c is HighlightedText) _InlineCodeMd() else c,
];

/// Markdown 消息渲染（流式期间 data 可能是半截 markdown，gpt_markdown 容忍）。
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({
    super.key,
    required this.data,
    this.selectable = true,
    this.style,
  });

  /// markdown 源文本。
  final String data;

  /// 是否可选中复制。
  final bool selectable;

  /// 文本样式（颜色随气泡主题传入）。
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    Widget markdown = GptMarkdown(
      data,
      style: style,
      onLinkTap: _openLink,
      inlineComponents: _inlineComponents,
      tableBuilder: _table,
    );
    // 调淡 quote 竖条：库内 onSurfaceVariant 仅用于该竖条，局部覆盖不影响其它。
    markdown = Theme(data: _softQuoteTheme(context), child: markdown);
    if (!selectable) return markdown;
    return SelectionArea(child: markdown);
  }

  /// 外开链接；无法启动时静默忽略（不阻断阅读）。
  Future<void> _openLink(String url, String title) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 把 quote 竖条所用的 onSurfaceVariant 调淡（向 surface 混合一半）。
ThemeData _softQuoteTheme(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final softened =
      Color.lerp(scheme.onSurfaceVariant, scheme.surface, 0.5) ??
      scheme.onSurfaceVariant;
  return theme.copyWith(
    colorScheme: scheme.copyWith(onSurfaceVariant: softened),
  );
}

/// 行内代码：等宽、常规字重、浅底的 TextSpan（基线对齐，标题内不错位）。
class _InlineCodeMd extends InlineMd {
  @override
  RegExp get exp => RegExp(r'`(?!`)(.+?)(?<!`)`(?!`)');

  @override
  InlineSpan span(BuildContext context, String text, GptMarkdownConfig config) {
    final code = exp.firstMatch(text.trim())?[1] ?? '';
    final scheme = Theme.of(context).colorScheme;
    final base = config.style ?? const TextStyle();
    return TextSpan(
      text: code,
      style: base.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
        // 半透明底色：TextSpan.background 绘制在选中高亮之上，不透明会遮挡
        // SelectionArea 的蓝色高亮（表现为「代码块选不中」）。用半透明让选中色透出。
        background: Paint()
          ..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      ),
    );
  }
}

/// 自适应宽度表格：列按屏宽等分，单元格内换行，不再横向滚动。
Widget _table(
  BuildContext context,
  List<CustomTableRow> rows,
  TextStyle style,
  GptMarkdownConfig config,
) {
  if (rows.isEmpty) return const SizedBox.shrink();
  final scheme = Theme.of(context).colorScheme;
  final colCount = rows.fold<int>(
    0,
    (max, r) => r.fields.length > max ? r.fields.length : max,
  );
  if (colCount == 0) return const SizedBox.shrink();

  return Table(
    columnWidths: {
      for (var i = 0; i < colCount; i++) i: const FlexColumnWidth(),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    border: TableBorder.all(width: 1, color: scheme.outlineVariant),
    children: [
      for (final row in rows)
        TableRow(
          decoration: row.isHeader
              ? BoxDecoration(color: scheme.surfaceContainerHighest)
              : null,
          children: [
            for (var i = 0; i < colCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: _cell(
                  context,
                  i < row.fields.length ? row.fields[i] : null,
                  style,
                ),
              ),
          ],
        ),
    ],
  );
}

/// 表格单元格：渲染内嵌 markdown，行内代码复用同一 TextSpan 样式。
Widget _cell(BuildContext context, CustomTableField? field, TextStyle style) {
  final text = field?.data.trim() ?? '';
  if (text.isEmpty) return const SizedBox.shrink();
  return GptMarkdown(
    text,
    style: style,
    textAlign: field?.alignment ?? TextAlign.left,
    inlineComponents: _inlineComponents,
  );
}

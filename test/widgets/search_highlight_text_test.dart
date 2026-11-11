import 'package:echo_loop/widgets/search_highlight_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取出 [SearchHighlightText] 渲染出的叶子 TextSpan（按文本顺序）。
List<TextSpan> _spansOf(WidgetTester tester) {
  final richText = tester.widget<RichText>(
    find.descendant(
      of: find.byType(SearchHighlightText),
      matching: find.byType(RichText),
    ),
  );
  final leaves = <TextSpan>[];
  void collect(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text != null) leaves.add(span);
    span.children?.forEach(collect);
  }

  collect(richText.text);
  return leaves;
}

void main() {
  Future<void> pump(WidgetTester tester, String text, String query) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchHighlightText(text: text, searchQuery: query),
        ),
      ),
    );
  }

  testWidgets('高亮所有匹配项并保留原始大小写', (tester) async {
    await pump(tester, 'Coffee and coffee', 'COFFEE');

    final spans = _spansOf(tester);
    expect(spans.map((s) => s.text), ['Coffee', ' and ', 'coffee']);
    expect(spans[0].style?.backgroundColor, isNotNull);
    expect(spans[1].style?.backgroundColor, isNull);
    expect(spans[2].style?.backgroundColor, isNotNull);
  });

  testWidgets('无关键词时不做高亮', (tester) async {
    await pump(tester, 'Coffee', '  ');

    // 无匹配时退化为普通 Text，不产生高亮背景。
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });
}

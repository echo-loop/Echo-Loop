/// [SettingsSectionCard] 分组卡片测试
///
/// 验证 children 正常渲染，以及 title 传/不传两种情况下的标题显隐。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/common/settings_section_card.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('渲染传入的 children', (tester) async {
    await tester.pumpWidget(
      wrap(const SettingsSectionCard(children: [Text('row-a'), Text('row-b')])),
    );

    expect(find.text('row-a'), findsOneWidget);
    expect(find.text('row-b'), findsOneWidget);
  });

  testWidgets('传入 title 时渲染分组标题', (tester) async {
    await tester.pumpWidget(
      wrap(const SettingsSectionCard(title: '分组标题', children: [Text('row-a')])),
    );

    expect(find.text('分组标题'), findsOneWidget);
  });

  testWidgets('不传 title 时不渲染标题文本', (tester) async {
    await tester.pumpWidget(
      wrap(const SettingsSectionCard(children: [Text('row-a')])),
    );

    expect(find.text('分组标题'), findsNothing);
  });

  testWidgets('浅色主题下分组卡片不绘制外框', (tester) async {
    final card = const SettingsSectionCard(children: [Text('row-a')]);
    await tester.pumpWidget(wrap(card));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byWidget(card),
        matching: find.byType(Container),
      ),
    );
    expect(
      container.decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.border,
        'border',
        isNull,
      ),
    );
  });

  testWidgets('暗色主题下分组卡片不绘制外框', (tester) async {
    final card = const SettingsSectionCard(children: [Text('row-a')]);
    await tester.pumpWidget(wrap(card, theme: AppTheme.dark()));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byWidget(card),
        matching: find.byType(Container),
      ),
    );
    expect(
      container.decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.border,
        'border',
        isNull,
      ),
    );
    expect(
      container.decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        Colors.transparent,
      ),
    );
  });
}

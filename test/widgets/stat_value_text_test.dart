/// StatValueText 组件测试
///
/// 覆盖：数字与单位拼接为完整文本，单位使用小字样式。
library;

import 'package:echo_loop/widgets/stat_value_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('数字使用指定样式，单位为小字', (tester) async {
    const numberStyle = TextStyle(fontSize: 40);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatValueText(
            value: StatValue('36', 'min'),
            numberStyle: numberStyle,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.textSpan?.toPlainText(), '36 min');
    final spans = (text.textSpan as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.style?.fontSize, 40);
    // 单位样式来自 labelMedium，字号明显小于大数字
    expect(spans.last.style?.fontSize, lessThan(40));
  });
}

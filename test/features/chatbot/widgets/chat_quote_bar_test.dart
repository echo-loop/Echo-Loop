/// ChatQuoteBar 测试：引用文本 / 快捷指令 / 关闭 / 流式禁用。
library;

import 'package:echo_loop/features/chatbot/widgets/chat_quote_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatbot_widget_harness.dart';

void main() {
  testWidgets('渲染引用文本 + 3 个快捷指令 chips', (tester) async {
    await pumpChatWidget(
      tester,
      ChatQuoteBar(
        quote: 'pretty busy tomorrow',
        isStreaming: false,
        onClose: () {},
        onCommand: (_) {},
      ),
    );
    expect(find.text('pretty busy tomorrow'), findsOneWidget);
    // en locale：Explain / Translate / Example
    expect(find.text('Explain'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
  });

  testWidgets('点快捷指令回调该指令文案', (tester) async {
    String? command;
    await pumpChatWidget(
      tester,
      ChatQuoteBar(
        quote: 'q',
        isStreaming: false,
        onClose: () {},
        onCommand: (c) => command = c,
      ),
    );
    await tester.tap(find.text('Translate'));
    expect(command, 'Translate');
  });

  testWidgets('点关闭触发 onClose', (tester) async {
    var closed = false;
    await pumpChatWidget(
      tester,
      ChatQuoteBar(
        quote: 'q',
        isStreaming: false,
        onClose: () => closed = true,
        onCommand: (_) {},
      ),
    );
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets('流式中快捷指令禁用（点击无回调）', (tester) async {
    var tapped = false;
    await pumpChatWidget(
      tester,
      ChatQuoteBar(
        quote: 'q',
        isStreaming: true,
        onClose: () {},
        onCommand: (_) => tapped = true,
      ),
    );
    await tester.tap(find.text('Explain'));
    expect(tapped, isFalse);
  });
}

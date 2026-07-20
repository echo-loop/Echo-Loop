/// ChatComposer 测试：发送清空 / 空文本禁用 / 停止切换 / 桌面 Enter。
library;

import 'package:echo_loop/features/chatbot/widgets/chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatbot_widget_harness.dart';

void main() {
  testWidgets('输入非空后发送 → 回调收到文本并清空输入框', (tester) async {
    String? sent;
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: false,
        onSend: (t) async => sent = t,
        onStop: () {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(sent, 'hello');
    expect(find.text('hello'), findsNothing); // 已清空
  });

  testWidgets('输入框接线 onTapOutside（点外收键盘）', (tester) async {
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: false,
        onSend: (_) async {},
        onStop: () {},
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.onTapOutside, isNotNull);
  });

  testWidgets('空文本时发送按钮禁用', (tester) async {
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: false,
        onSend: (_) async {},
        onStop: () {},
      ),
    );
    final btn = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(IconButton),
      ),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('流式中显示停止键，点击回调 onStop', (tester) async {
    var stopped = false;
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: true,
        onSend: (_) async {},
        onStop: () => stopped = true,
      ),
    );
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);
    await tester.tap(find.byIcon(Icons.stop));
    expect(stopped, isTrue);
  });

  testWidgets('桌面 Enter 发送、Shift+Enter 换行', (tester) async {
    final sent = <String>[];
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: false,
        onSend: (t) async => sent.add(t),
        onStop: () {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'line1');
    await tester.pump();

    // Shift+Enter → 不发送
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(sent, isEmpty);

    // Enter → 发送
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['line1']);
  });

  testWidgets('输入超 4000 字符被截断', (tester) async {
    await pumpChatWidget(
      tester,
      ChatComposer(
        placeholder: 'ask',
        isStreaming: false,
        onSend: (_) async {},
        onStop: () {},
      ),
    );
    await tester.enterText(find.byType(TextField), 'a' * 5000);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 4000);
  });
}

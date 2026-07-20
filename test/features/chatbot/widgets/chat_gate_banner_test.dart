/// ChatGateBanner + ChatContextChip 测试。
library;

import 'package:echo_loop/features/chatbot/state/chat_session_state.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_gate_banner.dart';
import 'package:echo_loop/features/chatbot/widgets/context_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatbot_widget_harness.dart';

void main() {
  ChatGateBanner banner(
    ChatGate gate, {
    VoidCallback? onUpgrade,
    VoidCallback? onSignIn,
  }) => ChatGateBanner(
    gate: gate,
    onUpgrade: onUpgrade ?? () {},
    onSignIn: onSignIn ?? () {},
  );

  testWidgets('gate=none → 不渲染内容', (tester) async {
    await pumpChatWidget(tester, banner(ChatGate.none));
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('gate=authRequired → 登录入口并回调', (tester) async {
    var signIn = false;
    await pumpChatWidget(
      tester,
      banner(ChatGate.authRequired, onSignIn: () => signIn = true),
    );
    expect(find.text('Sign in required'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    expect(signIn, isTrue);
  });

  testWidgets('gate=quotaExceeded → 升级入口并回调', (tester) async {
    var upgrade = false;
    await pumpChatWidget(
      tester,
      banner(ChatGate.quotaExceeded, onUpgrade: () => upgrade = true),
    );
    expect(find.text('Upgrade'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    expect(upgrade, isTrue);
  });

  testWidgets('ChatContextChip 显示摘要且单行省略', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatContextChip(summary: 'The quick brown fox'),
    );
    expect(find.textContaining('The quick brown fox'), findsOneWidget);
    final text = tester.widget<Text>(
      find.textContaining('The quick brown fox'),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}

/// ChatHeaderActions 测试：溢出菜单渲染清空 / 重新生成项。
///
/// clear()/retry() 的状态流转逻辑由 chat_session_controller_test.dart 覆盖；
/// 本测试只验证 header 菜单的 UI 存在与文案（避免驱动 send 引入实时定时器/动画）。
library;

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatbot_widget_harness.dart';

const _config = ChatbotConfig(
  sessionId: 's1',
  endpoint: '/chat',
  title: 'T',
  inputPlaceholder: 'P',
);

void main() {
  testWidgets('溢出菜单展示「重新生成」「清空对话」两项', (tester) async {
    await pumpChatWidget(
      tester,
      Scaffold(
        appBar: AppBar(
          title: const Text('T'),
          actions: const [ChatHeaderActions(config: _config)],
        ),
      ),
      overrides: [isAuthenticatedProvider.overrideWithValue(true)],
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Clear chat'), findsOneWidget);
  });
}

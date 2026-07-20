/// ChatMessageBubble 测试：角色 / 思考中 / inline 重试 / 升级 / 复制。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chat_role.dart';
import 'package:echo_loop/features/chatbot/widgets/markdown_message.dart';
import 'package:echo_loop/features/chatbot/widgets/message_bubble.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'chatbot_widget_harness.dart';

void main() {
  final now = DateTime(2026, 7, 18);

  ChatMessage msg({
    ChatRole role = ChatRole.assistant,
    String content = '',
    ChatMessageStatus status = ChatMessageStatus.done,
  }) => ChatMessage(
    id: 'm1',
    role: role,
    content: content,
    status: status,
    createdAt: now,
  );

  testWidgets('user 消息渲染纯文本', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(role: ChatRole.user, content: 'Hello'),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(MarkdownMessage), findsNothing);
  });

  testWidgets('assistant 消息用 markdown 渲染', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(message: msg(content: '**bold**')),
    );
    expect(find.byType(GptMarkdown), findsOneWidget);
  });

  testWidgets('streaming 且空 content → 思考中指示（无 markdown）', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(content: '', status: ChatMessageStatus.streaming),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GptMarkdown), findsNothing);
    // 思考中语义标签存在
    expect(find.bySemanticsLabel('Thinking…'), findsOneWidget);
  });

  testWidgets('error 态显示 inline 重试并回调', (tester) async {
    var retried = false;
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(content: '半截', status: ChatMessageStatus.error),
        onRetry: () => retried = true,
      ),
    );
    final retry = find.text('Generation failed. Tap to retry.');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    expect(retried, isTrue);
  });

  testWidgets('quotaBlocked 态显示 inline 升级并回调', (tester) async {
    var upgraded = false;
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(content: '额度', status: ChatMessageStatus.quotaBlocked),
        onUpgrade: () => upgraded = true,
      ),
    );
    final upgrade = find.text('Upgrade');
    expect(upgrade, findsOneWidget);
    await tester.tap(upgrade);
    expect(upgraded, isTrue);
  });

  testWidgets(
    'assistant 内容渲染为可选中 markdown（SelectionArea → SelectableRegion）',
    (tester) async {
      await pumpChatWidget(
        tester,
        ChatMessageBubble(
          message: msg(content: '**note**'),
          onFollowUp: (_) {},
        ),
      );
      // AI 回答用 SelectionArea 包裹，支持长按/拖拽自由选中连续文本。
      expect(find.byType(MarkdownMessage), findsOneWidget);
      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(find.byType(SelectableRegion), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('user 带 quote：气泡上方显示引用行，气泡只显示问题', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: ChatMessage.user(
          id: 'u1',
          content: '啥意思',
          createdAt: now,
          quote: '只保留 backticks 和 blockquote',
        ),
      ),
    );
    expect(find.text('啥意思'), findsOneWidget);
    expect(find.text('只保留 backticks 和 blockquote'), findsOneWidget);
    // 引用行图标已改为 SVG（arrow-right-turn），不再是 Material Icon。
    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('user 消息无常驻操作栏（复制/编辑仅长按菜单）', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(role: ChatRole.user, content: 'Hello'),
        onCopy: (_) {},
        onEdit: () {},
      ),
    );
    // 常驻操作栏图标不出现（tooltip 只在常驻栏用）。
    expect(find.byTooltip('Copy'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testWidgets('长按 user 弹菜单：复制 + 编辑 回调', (tester) async {
    String? copied;
    var edited = false;
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(role: ChatRole.user, content: 'Hello'),
        onCopy: (c) => copied = c,
        onEdit: () => edited = true,
      ),
    );
    // 复制
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'Hello');
    // 编辑
    await tester.longPress(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });

  testWidgets('桌面右键 user 弹菜单：复制 + 编辑', (tester) async {
    var edited = false;
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(role: ChatRole.user, content: 'Hello'),
        onCopy: (_) {},
        onEdit: () => edited = true,
      ),
    );
    await tester.tap(find.text('Hello'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(edited, isTrue);
  });

  testWidgets('assistant done 态操作栏：复制 + 重新生成 回调', (tester) async {
    var regenerated = false;
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(content: '**note**'),
        onRegenerate: () => regenerated = true,
      ),
    );
    expect(find.byTooltip('Copy'), findsOneWidget);
    await tester.tap(find.byTooltip('Regenerate'));
    expect(regenerated, isTrue);
  });

  testWidgets('streaming 态无操作栏', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(content: '生成中', status: ChatMessageStatus.streaming),
        onRegenerate: () {},
      ),
    );
    expect(find.byTooltip('Copy'), findsNothing);
    expect(find.byTooltip('Regenerate'), findsNothing);
  });

  testWidgets('半截 markdown 不抛异常', (tester) async {
    await pumpChatWidget(
      tester,
      ChatMessageBubble(
        message: msg(
          content: '**未闭合 加粗 和 [链接](',
          status: ChatMessageStatus.streaming,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

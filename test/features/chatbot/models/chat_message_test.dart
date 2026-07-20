/// ChatMessage 模型测试：factory / copyWith / toWire / includeInHistory。
library;

import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chat_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 18, 10, 0, 0);

  group('ChatMessage.user', () {
    test('构造 done 态用户消息、默认入历史', () {
      final m = ChatMessage.user(id: 'u1', content: '你好', createdAt: now);
      expect(m.role, ChatRole.user);
      expect(m.status, ChatMessageStatus.done);
      expect(m.content, '你好');
      expect(m.includeInHistory, isTrue);
    });
  });

  group('ChatMessage.assistantPlaceholder', () {
    test('构造 streaming 空占位', () {
      final m = ChatMessage.assistantPlaceholder(id: 'a1', createdAt: now);
      expect(m.role, ChatRole.assistant);
      expect(m.status, ChatMessageStatus.streaming);
      expect(m.content, isEmpty);
      expect(m.includeInHistory, isTrue);
    });
  });

  group('ChatMessage.greeting', () {
    test('done 态且不入历史', () {
      final m = ChatMessage.greeting(
        id: 'g1',
        content: '有问题问我',
        createdAt: now,
      );
      expect(m.role, ChatRole.assistant);
      expect(m.status, ChatMessageStatus.done);
      expect(m.includeInHistory, isFalse);
    });
  });

  group('copyWith', () {
    test('仅覆盖 content/status，其余不变', () {
      final m = ChatMessage.assistantPlaceholder(id: 'a1', createdAt: now);
      final m2 = m.copyWith(content: '它', status: ChatMessageStatus.streaming);
      expect(m2.id, 'a1');
      expect(m2.role, ChatRole.assistant);
      expect(m2.createdAt, now);
      expect(m2.content, '它');
      final m3 = m2.copyWith(status: ChatMessageStatus.done);
      expect(m3.content, '它'); // content 未传保持不变
      expect(m3.status, ChatMessageStatus.done);
    });
  });

  group('toWire', () {
    test('仅序列化 role/content（无 quote 时忽略指令）', () {
      final m = ChatMessage.user(id: 'u1', content: '再举个例子', createdAt: now);
      expect(m.toWire(instruction: 'INSTR'), {
        'role': 'user',
        'content': '再举个例子',
      });
    });

    test('带 quote 时 content 拼成 指令 + <quote> 标签 + 问题', () {
      final m = ChatMessage.user(
        id: 'u1',
        content: '详细解释',
        createdAt: now,
        quote: 'pretty busy',
      );
      expect(m.toWire(instruction: 'INSTR'), {
        'role': 'user',
        'content': 'INSTR\n\n<quote>\npretty busy\n</quote>\n\n详细解释',
      });
    });
  });

  group('quote 字段', () {
    test('user 工厂保存 quote，默认 null', () {
      final withQuote = ChatMessage.user(
        id: 'u1',
        content: '啥意思',
        createdAt: now,
        quote: '被引用文本',
      );
      expect(withQuote.quote, '被引用文本');
      final without = ChatMessage.user(id: 'u2', content: '你好', createdAt: now);
      expect(without.quote, isNull);
    });

    test('copyWith 保留 quote', () {
      final m = ChatMessage.user(
        id: 'u1',
        content: '啥意思',
        createdAt: now,
        quote: '被引用文本',
      );
      final m2 = m.copyWith(content: '换个问法');
      expect(m2.quote, '被引用文本');
    });
  });
}

/// ChatSessionState 测试：initial 含 greeting、gate 语义、canSend/isStreaming。
library;

import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/state/chat_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatbotConfig config({String? greeting}) => ChatbotConfig(
    sessionId: 's1',
    endpoint: '/chat',
    title: 'T',
    inputPlaceholder: 'P',
    greeting: greeting,
  );

  group('initial', () {
    test('无 greeting → 空消息、idle、gate=none', () {
      final s = ChatSessionState.initial(config());
      expect(s.messages, isEmpty);
      expect(s.status, ChatSessionStatus.idle);
      expect(s.gate, ChatGate.none);
    });

    test('有 greeting → 插入一条不入历史的 done 开场白', () {
      final s = ChatSessionState.initial(config(greeting: '你好'));
      expect(s.messages, hasLength(1));
      expect(s.messages.first.status, ChatMessageStatus.done);
      expect(s.messages.first.includeInHistory, isFalse);
      expect(s.messages.first.content, '你好');
    });

    test('空串 greeting 不插入', () {
      final s = ChatSessionState.initial(config(greeting: ''));
      expect(s.messages, isEmpty);
    });
  });

  group('canSend / isStreaming', () {
    test('idle 可发送', () {
      final s = ChatSessionState.initial(config());
      expect(s.canSend, isTrue);
      expect(s.isStreaming, isFalse);
    });

    test('streaming 禁止发送', () {
      final s = ChatSessionState.initial(
        config(),
      ).copyWith(status: ChatSessionStatus.streaming);
      expect(s.canSend, isFalse);
      expect(s.isStreaming, isTrue);
    });
  });

  group('copyWith', () {
    test('可单独更新 gate', () {
      final s = ChatSessionState.initial(config());
      final s2 = s.copyWith(gate: ChatGate.authRequired);
      expect(s2.gate, ChatGate.authRequired);
      expect(s2.status, ChatSessionStatus.idle);
    });
  });
}

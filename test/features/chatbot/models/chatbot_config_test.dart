/// ChatbotConfig 相等性测试：比 sessionId + endpoint，context 排除。
library;

import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatbotConfig make({
    String sessionId = 's1',
    String endpoint = '/chat',
    Map<String, Object?> context = const {},
  }) => ChatbotConfig(
    sessionId: sessionId,
    endpoint: endpoint,
    context: context,
    title: 'T',
    inputPlaceholder: 'P',
  );

  test('sessionId + endpoint 相同即相等（context 不同也相等）', () {
    final a = make(context: {'sentence': 'A'});
    final b = make(context: {'sentence': 'B'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('sessionId 不同 → 不相等', () {
    expect(make(sessionId: 's1'), isNot(make(sessionId: 's2')));
  });

  test('endpoint 不同 → 不相等（防串会话）', () {
    expect(make(endpoint: '/a'), isNot(make(endpoint: '/b')));
  });
}

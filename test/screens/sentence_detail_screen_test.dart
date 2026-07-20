import 'package:echo_loop/screens/sentence_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowAiChatAssistantEntry', () {
    test('编译期开关和远程开关都开启时显示入口', () {
      expect(
        shouldShowAiChatAssistantEntry(
          chatbotEnabled: true,
          remoteEnabled: true,
        ),
        isTrue,
      );
    });

    test('远程关闭时隐藏入口', () {
      expect(
        shouldShowAiChatAssistantEntry(
          chatbotEnabled: true,
          remoteEnabled: false,
        ),
        isFalse,
      );
    });

    test('编译期开关关闭时始终隐藏入口', () {
      expect(
        shouldShowAiChatAssistantEntry(
          chatbotEnabled: false,
          remoteEnabled: true,
        ),
        isFalse,
      );
    });
  });
}

/// SentenceChatButton 测试：开关显隐规则 + 组件渲染 + onBeforeOpen 回调。
library;

import 'package:echo_loop/features/chatbot/widgets/sentence_chat_button.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/sentence_passage.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chatbot_widget_harness.dart';

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

  group('SentenceChatButton', () {
    /// 覆盖远程开关为指定值。
    List<Override> remoteOverride({required bool enabled}) => [
      remoteFeatureEnabledProvider(
        RemoteFeature.aiChatAssistant,
      ).overrideWithValue(enabled),
    ];

    testWidgets('来源与上下文共同确定会话，空上下文保持单句请求', (tester) async {
      ChatbotConfig? withPassage;
      ChatbotConfig? withoutPassage;
      ChatbotConfig? sameTarget;
      ChatbotConfig? otherSource;
      ChatbotConfig? emptyPassage;
      await pumpChatWidget(
        tester,
        Builder(
          builder: (context) {
            withPassage = sentenceChatbotConfig(
              context,
              const SentenceChatTarget(
                text: 'Current.',
                audioItemId: 'audio-1',
                sentenceIndex: 4,
              ),
              passage: 'Before.\nCurrent.\nAfter.',
            );
            withoutPassage = sentenceChatbotConfig(
              context,
              const SentenceChatTarget(
                text: 'Current.',
                audioItemId: 'audio-1',
                sentenceIndex: 4,
              ),
              passage: '  ',
            );
            emptyPassage = sentenceChatbotConfig(
              context,
              const SentenceChatTarget(
                text: 'Current.',
                audioItemId: 'audio-1',
                sentenceIndex: 4,
              ),
            );
            sameTarget = sentenceChatbotConfig(
              context,
              const SentenceChatTarget(
                text: 'Current.',
                audioItemId: 'audio-1',
                sentenceIndex: 4,
              ),
              passage: 'Before.\nCurrent.\nAfter.',
            );
            otherSource = sentenceChatbotConfig(
              context,
              const SentenceChatTarget(
                text: 'Current.',
                audioItemId: 'audio-2',
                sentenceIndex: 4,
              ),
              passage: 'Before.\nCurrent.\nAfter.',
            );
            return const SizedBox.shrink();
          },
        ),
      );

      expect(withPassage?.context, {
        'sentence': 'Current.',
        'passage': 'Before.\nCurrent.\nAfter.',
      });
      expect(withoutPassage?.context, {'sentence': 'Current.'});
      expect(withPassage?.sessionId, isNot(withoutPassage?.sessionId));
      expect(emptyPassage?.sessionId, withoutPassage?.sessionId);
      expect(sameTarget?.sessionId, withPassage?.sessionId);
      expect(otherSource?.sessionId, isNot(withPassage?.sessionId));
    });

    testWidgets('远程开关开启且句子非空时渲染按钮', (tester) async {
      await pumpChatWidget(
        tester,
        const SentenceChatButton(
          target: SentenceChatTarget(text: 'Hello world.'),
        ),
        overrides: remoteOverride(enabled: true),
      );
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('远程开关关闭时不渲染按钮', (tester) async {
      await pumpChatWidget(
        tester,
        const SentenceChatButton(
          target: SentenceChatTarget(text: 'Hello world.'),
        ),
        overrides: remoteOverride(enabled: false),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('句子为空（未就绪）时不渲染按钮', (tester) async {
      await pumpChatWidget(
        tester,
        const SentenceChatButton(target: SentenceChatTarget(text: '')),
        overrides: remoteOverride(enabled: true),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('点击时先触发 onBeforeOpen（任务页借此暂停自动推进）', (tester) async {
      var beforeOpenCalled = false;
      await pumpChatWidget(
        tester,
        SentenceChatButton(
          target: const SentenceChatTarget(text: 'Hello world.'),
          onBeforeOpen: () => beforeOpenCalled = true,
        ),
        overrides: remoteOverride(enabled: true),
      );
      // 只验证回调时序，不 pump sheet 内容（ChatView 依赖网络/订阅一整套 provider）。
      await tester.tap(find.byType(IconButton));
      expect(beforeOpenCalled, isTrue);
    });
  });
}

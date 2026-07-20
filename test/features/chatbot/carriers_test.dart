/// 两载体测试：showChatbotSheet（sheet）+ ChatScreen（全屏页壳）。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/chatbot/chatbot_flags.dart';
import 'package:echo_loop/features/chatbot/chatbot_sheet.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/providers/chat_api_client_provider.dart';
import 'package:echo_loop/features/chatbot/screens/chat_screen.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_composer.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_view.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/ai_trial_usage_provider.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import 'widgets/chatbot_widget_harness.dart';

class _EmptyApi implements ChatApi {
  bool disposed = false;
  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) => const Stream.empty();
  @override
  void dispose() => disposed = true;
}

class _Trial extends AiTrialUsageNotifier {
  @override
  Map<PremiumFeature, int> build() => const {};
  @override
  void consume(PremiumFeature feature) {}
}

Session _session() => Session(
  accessToken: 't',
  tokenType: 'bearer',
  user: const User(
    id: 'u',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-07-13T00:00:00.000Z',
  ),
);

const _config = ChatbotConfig(
  sessionId: 's1',
  endpoint: '/chat',
  title: 'AI Tutor',
  inputPlaceholder: 'Ask…',
);

void main() {
  List<Override> overrides() => [
    chatApiClientProvider.overrideWithValue(_EmptyApi()),
    isAuthenticatedProvider.overrideWithValue(true),
    supabaseSessionProvider.overrideWith(
      (ref) => Stream<Session?>.value(_session()),
    ),
    freeAllowancePolicyProvider.overrideWithValue(const AlwaysAllowPolicy()),
    aiTrialUsageProvider.overrideWith(() => _Trial()),
    appSettingsProvider.overrideWith(() => TestAppSettings()),
  ];

  testWidgets('showChatbotSheet 打开显示 ChatView，关闭后消失', (tester) async {
    await pumpChatWidget(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () =>
                showChatbotSheet(context: context, config: _config),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: overrides(),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text('AI Tutor'), findsOneWidget); // sheet 标题

    // 关闭 sheet：点顶部遮罩区（header 无关闭按钮，默认高度屏高×0.8，顶部为遮罩）。
    await tester.tapAt(const Offset(400, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ChatView), findsNothing);
  });

  // 屏高（逻辑像素）：从测试视图算，避免硬编码默认 800x600。
  double screenHeight(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  Future<void> openSheet(WidgetTester tester) async {
    await pumpChatWidget(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () =>
                showChatbotSheet(context: context, config: _config),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: overrides(),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet 默认高度约 0.8 屏高', (tester) async {
    await openSheet(tester);
    final h = tester.getSize(find.byKey(const Key('chat_sheet_sizer'))).height;
    expect(h, moreOrLessEquals(screenHeight(tester) * 0.8, epsilon: 1));
  });

  testWidgets('拖 header 向上放大（≤95%）、向下缩小（≥40%）', (tester) async {
    await openSheet(tester);
    final sizer = find.byKey(const Key('chat_sheet_sizer'));
    final base = tester.getSize(sizer).height;

    // 上拉 120：高度增大。
    await tester.drag(find.text('AI Tutor'), const Offset(0, -120));
    await tester.pump();
    final taller = tester.getSize(sizer).height;
    expect(taller, greaterThan(base));
    expect(taller, lessThanOrEqualTo(screenHeight(tester) * 0.95 + 1));

    // 下拉 80：高度减小（仍在下限内，不触发关闭）。
    await tester.drag(find.text('AI Tutor'), const Offset(0, 80));
    await tester.pump();
    final shorter = tester.getSize(sizer).height;
    expect(shorter, lessThan(taller));
    expect(shorter, greaterThanOrEqualTo(screenHeight(tester) * 0.4 - 1));
  });

  testWidgets('下拉到底再继续拉（过 overdrag 阈值）→ 关闭 sheet', (tester) async {
    await openSheet(tester);
    expect(find.byType(ChatView), findsOneWidget);
    // 一次性大幅下拉：从默认 0.6 拉到远低于下限 0.4 + 80px overdrag。
    await tester.drag(find.text('AI Tutor'), Offset(0, screenHeight(tester)));
    await tester.pumpAndSettle();
    expect(find.byType(ChatView), findsNothing);
  });

  test('本地联调开关已开启（入口可见 + fake 流式数据）', () {
    // 本地手动验收 chatbot 时入口保持可见，并用 fake 流式实现避免依赖后端状态。
    expect(kChatbotEnabled, isTrue);
    expect(kChatbotUseFakeApi, isTrue);
  });

  testWidgets('ChatScreen 全屏页壳渲染标题与 ChatView', (tester) async {
    await pumpChatWidget(
      tester,
      const ChatScreen(config: _config),
      overrides: overrides(),
    );
    await tester.pump();
    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text('AI Tutor'), findsOneWidget); // AppBar 标题
  });
}

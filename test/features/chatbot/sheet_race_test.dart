/// sheet 保活 / 关-开语义回归。
///
/// controller 保活（keepAlive）：流式中关闭 sheet 不销毁 controller，由
/// showChatbotSheet 关闭后显式 stop() 中断在途流并保留已生成部分为 done；
/// 重开同一 config 复用同一会话（内容还在）。竞态守卫（_disposed || seq != _seq）
/// 保证过程不崩、不写脏状态。
library;

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/chatbot/chatbot_sheet.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/providers/chat_api_client_provider.dart';
import 'package:echo_loop/features/chatbot/providers/chat_session_controller.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:echo_loop/features/chatbot/state/chat_session_state.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_view.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/ai_trial_usage_provider.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';
import 'widgets/chatbot_widget_harness.dart';

/// 长流 fake：yield 一帧后持续等待取消（模拟流式中被关 sheet）。
class _SlowApi implements ChatApi {
  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) async* {
    yield const ChatTextFrame(text: '正在回答', isFinal: false);
    while (!(cancelToken?.isCancelled ?? false)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  void dispose() {}
}

class _Trial extends AiTrialUsageNotifier {
  @override
  Map<PremiumFeature, int> build() => const {};
  @override
  void consume(PremiumFeature feature) {}
}

class _FreeSub extends SubscriptionController {
  @override
  EntitlementState build() => const EntitlementState.free();
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
  title: 'AI',
  inputPlaceholder: 'Ask…',
);

void main() {
  testWidgets('流式中关-开 sheet：保活续上会话，在途被 stop 成 done 且不崩', (tester) async {
    await pumpChatWidget(
      tester,
      Builder(
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            ref.watch(supabaseSessionProvider); // 订阅 session 让其落定
            return Center(
              child: ElevatedButton(
                onPressed: () =>
                    showChatbotSheet(context: context, config: _config),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
      overrides: [
        chatApiClientProvider.overrideWithValue(_SlowApi()),
        isAuthenticatedProvider.overrideWithValue(true),
        supabaseSessionProvider.overrideWith(
          (ref) => Stream<Session?>.value(_session()),
        ),
        freeAllowancePolicyProvider.overrideWithValue(
          const AlwaysAllowPolicy(),
        ),
        subscriptionControllerProvider.overrideWith(() => _FreeSub()),
        aiTrialUsageProvider.overrideWith(() => _Trial()),
        appSettingsProvider.overrideWith(() => TestAppSettings()),
      ],
    );
    await tester.pump();

    // 'open' 按钮所在 element 始终存活，用它拿 container 读会话 state。
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
      listen: false,
    );
    ChatSessionState state() =>
        container.read(chatSessionControllerProvider(_config));

    // 开 sheet
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChatView), findsOneWidget);

    // 发送 → 进入流式（首帧 '正在回答' 到达）
    await tester.enterText(find.byType(TextField), '问题');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(state().status, ChatSessionStatus.streaming);
    expect(state().messages.last.content, '正在回答');

    // 关闭 sheet：点顶部遮罩区（无关闭按钮，sheet 高度屏高×0.9，顶部为遮罩）。
    await tester.tapAt(const Offset(400, 10));
    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // 关闭动画 + showChatbotSheet future 完成触发 stop
    expect(find.byType(ChatView), findsNothing);
    expect(tester.takeException(), isNull);

    // 关面板即停：在途那条被 stop 收尾为 done，已生成部分保留，会话回 idle。
    expect(state().status, ChatSessionStatus.idle);
    expect(state().messages.last.status, ChatMessageStatus.done);
    expect(state().messages.last.content, '正在回答');

    // 重开同一 config：保活复用，历史内容还在。
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChatView), findsOneWidget);
    expect(state().messages.last.content, '正在回答');
    expect(tester.takeException(), isNull);

    // 收尾关闭
    await tester.tapAt(const Offset(400, 10));
    await tester.pump(const Duration(milliseconds: 400));
  });
}

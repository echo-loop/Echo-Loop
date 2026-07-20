/// ChatView 集成测试（真实 controller + 可控 fake api）。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/providers/chat_api_client_provider.dart';
import 'package:echo_loop/features/chatbot/providers/chat_session_controller.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_composer.dart';
import 'package:echo_loop/features/chatbot/widgets/chat_view.dart';
import 'package:echo_loop/features/chatbot/widgets/message_list.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/ai_trial_usage_provider.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mock_providers.dart';
import 'chatbot_widget_harness.dart';

class _ScriptApi implements ChatApi {
  _ScriptApi(this.script);
  final Stream<ChatTextFrame> Function() script;
  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) => script();
  @override
  void dispose() {}
}

/// 能拿到 cancelToken 的 fake api（用于停止/取消路径）。
class _CancelAwareApi implements ChatApi {
  _CancelAwareApi(this.script);
  final Stream<ChatTextFrame> Function(CancelToken? cancelToken) script;
  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) => script(cancelToken);
  @override
  void dispose() {}
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

void main() {
  List<Override> overrides(
    ChatApi api, {
    FreeAllowancePolicy policy = const AlwaysAllowPolicy(),
  }) => [
    chatApiClientProvider.overrideWithValue(api),
    isAuthenticatedProvider.overrideWithValue(true),
    supabaseSessionProvider.overrideWith(
      (ref) => Stream<Session?>.value(_session()),
    ),
    freeAllowancePolicyProvider.overrideWithValue(policy),
    aiTrialUsageProvider.overrideWith(() => _Trial()),
    appSettingsProvider.overrideWith(() => TestAppSettings()),
  ];

  // supabaseSessionProvider 是 StreamProvider（异步 emit）。controller 同步读
  // valueOrNull，需先 subscribe 并 pump 让其落定，否则误判 authRequired。包一层
  // Consumer 订阅 session。
  Widget wrap(ChatView view) => Consumer(
    builder: (context, ref, _) {
      ref.watch(supabaseSessionProvider);
      return view;
    },
  );

  ChatbotConfig config({String? greeting, String? summary}) => ChatbotConfig(
    sessionId: 's1',
    endpoint: '/chat',
    context: const {'sentence': 'The fox'},
    title: 'T',
    inputPlaceholder: 'Ask…',
    greeting: greeting,
    contextSummary: summary,
  );

  testWidgets('空态显示 greeting + context chip', (tester) async {
    await pumpChatWidget(
      tester,
      wrap(
        ChatView(
          config: config(greeting: '有问题问我', summary: 'The fox'),
        ),
      ),
      overrides: overrides(_ScriptApi(() => const Stream.empty())),
    );
    await tester.pump();
    expect(find.text('有问题问我'), findsOneWidget);
    expect(find.textContaining('The fox'), findsWidgets); // context chip
  });

  testWidgets('整块统一底色：外层 ColoredBox == scheme.surface（Issue 4）', (
    tester,
  ) async {
    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config(greeting: 'hi'))),
      overrides: overrides(_ScriptApi(() => const Stream.empty())),
    );
    await tester.pump();

    // ChatComposer 的最近 ColoredBox 祖先即 ChatView 统一底色层。
    final coloredBox = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: find.byType(ChatComposer),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    // 消息区与底栏同色（harness 默认亮色主题）。
    expect(coloredBox.color, AppTheme.light().colorScheme.surface);
  });

  testWidgets('发送 → 流式渲染 markdown + 完成后回 idle', (tester) async {
    Stream<ChatTextFrame> ok() async* {
      yield const ChatTextFrame(text: '**它**', isFinal: false);
      yield const ChatTextFrame(text: '**它表示**', isFinal: true);
    }

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config())),
      overrides: overrides(_ScriptApi(ok)),
    );
    await tester.pump(); // 让 session 落定

    await tester.enterText(find.byType(TextField), '什么意思');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(); // 追加消息 + 启动流
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('什么意思'), findsWidgets); // 用户气泡
    expect(find.byType(GptMarkdown), findsWidgets); // assistant markdown
    // 完成后 composer 恢复发送键
    expect(find.byIcon(Icons.stop), findsNothing);
  });

  testWidgets('发送后把新消息顶到可视区顶部；流式增量不再改变位置', (tester) async {
    final firstFrame = Completer<void>();
    final keepStreaming = Completer<void>();
    Stream<ChatTextFrame> ok() async* {
      yield const ChatTextFrame(text: '第一段回答', isFinal: false);
      firstFrame.complete();
      await keepStreaming.future;
      yield const ChatTextFrame(text: '第一段回答\n\n第二段回答', isFinal: true);
    }

    final longGreeting = List.generate(
      60,
      (i) => '历史内容第 $i 行，用来撑出可滚动区域。',
    ).join('\n\n');

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config(greeting: longGreeting))),
      overrides: overrides(_ScriptApi(ok)),
    );
    await tester.pump(); // 让 session 落定并完成首帧布局。

    // 列表初始停在顶部（长 greeting，新消息原本远在下方视口外）。
    await tester.enterText(find.byType(TextField), '继续解释');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(); // 追加用户消息 + assistant 占位。
    await tester.pump(const Duration(milliseconds: 10)); // 触发置顶动画。
    await tester.pumpAndSettle(); // 置顶动画落定。
    await firstFrame.future;
    await tester.pump();

    // 新消息气泡顶部贴近列表视口顶部（容许 padding 与气泡外边距）。
    final listTop = tester.getTopLeft(find.byType(ChatMessageList)).dy;
    // 新消息气泡顶部贴近列表视口顶部（SPL 过渡期可能存在离屏副本，取任一在屏副本）。
    bool pinnedNearTop() => find
        .text('继续解释')
        .evaluate()
        .map(
          (e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy -
              listTop,
        )
        .any((d) => d >= -1 && d <= 80);
    expect(pinnedNearTop(), isTrue);

    // 流式增量到达 / 完成后，提问仍钉在顶部（不被下方回答顶下去）。
    keepStreaming.complete();
    await tester.pumpAndSettle();
    expect(pinnedNearTop(), isTrue);
  });

  testWidgets('开启新会话后隐藏回到底部按钮', (tester) async {
    late WidgetRef capturedRef;
    Widget capture(ChatView view) => Consumer(
      builder: (context, ref, _) {
        capturedRef = ref;
        ref.watch(supabaseSessionProvider);
        return view;
      },
    );

    Stream<ChatTextFrame> ok() async* {
      yield const ChatTextFrame(text: 'answer', isFinal: true);
    }

    final longGreeting = List.generate(
      60,
      (i) => '历史内容第 $i 行，用来撑出可滚动区域。',
    ).join('\n\n');
    final chatConfig = config(greeting: 'hi');

    await pumpChatWidget(
      tester,
      capture(ChatView(config: chatConfig)),
      overrides: overrides(_ScriptApi(ok)),
    );
    await tester.pump();

    // 发送一条超长用户消息：置顶后其自身溢出底部 → 回底浮标出现。
    await tester.enterText(find.byType(TextField), longGreeting);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Scroll to bottom'), findsOneWidget);

    // 清空会话回到短 greeting → 内容不溢出 → 浮标隐藏。
    capturedRef
        .read(chatSessionControllerProvider(chatConfig).notifier)
        .clear();
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Scroll to bottom'), findsNothing);
  });

  testWidgets('只有长 greeting 但底部仍有内容时显示回到底部按钮', (tester) async {
    final longGreeting = List.generate(
      60,
      (i) => '开场内容第 $i 行，用来撑出可滚动区域。',
    ).join('\n\n');

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config(greeting: longGreeting))),
      overrides: overrides(_ScriptApi(() => const Stream.empty())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Scroll to bottom'), findsOneWidget);
  });

  testWidgets('流式内容撑出底部时立即显示回到底部按钮', (tester) async {
    final firstFrame = Completer<void>();
    final keepStreaming = Completer<void>();
    Stream<ChatTextFrame> streaming() async* {
      final longAnswer = List.generate(
        80,
        (i) => '生成中的第 $i 行，用来撑出底部。',
      ).join('\n\n');
      yield ChatTextFrame(text: longAnswer, isFinal: false);
      firstFrame.complete();
      await keepStreaming.future;
      yield ChatTextFrame(text: longAnswer, isFinal: true);
    }

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config())),
      overrides: overrides(_ScriptApi(streaming)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '解释一下');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await firstFrame.future;
    await tester.pumpAndSettle(); // 等新消息置顶动画落定后再断言几何。

    expect(find.byIcon(Icons.stop), findsOneWidget);
    // 置顶后长回答仍溢出底部 → 回底浮标出现。
    expect(find.bySemanticsLabel('Scroll to bottom'), findsOneWidget);

    keepStreaming.complete();
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('流式中显示停止键；历史消息不被后续帧破坏', (tester) async {
    Stream<ChatTextFrame> slow() async* {
      yield const ChatTextFrame(text: 'part', isFinal: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      yield const ChatTextFrame(text: 'part done', isFinal: true);
    }

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config())),
      overrides: overrides(_ScriptApi(slow)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Q1');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump(); // 追加消息 + 启动流
    await tester.pump(const Duration(milliseconds: 10)); // 第一帧到达

    // 流式中：停止键出现，用户气泡 Q1 仍在
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.text('Q1'), findsWidgets);

    // 推进到末帧完成
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Q1'), findsWidgets); // 历史用户气泡完好
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget); // 回到发送态
  });

  testWidgets('发送 → 停止 → 保留已生成部分并回到发送态', (tester) async {
    Stream<ChatTextFrame> slow(CancelToken? ct) async* {
      yield const ChatTextFrame(text: '正在回答', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.cancel,
      );
    }

    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config())),
      overrides: overrides(_CancelAwareApi(slow)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Q');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20)); // 首帧、流式中

    expect(find.byIcon(Icons.stop), findsOneWidget);
    // 点停止
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.textContaining('正在回答'), findsWidgets); // 已生成部分保留
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget); // 回到发送态
  });

  testWidgets('已登录未解锁 → 发送触发 quotaExceeded 升级 banner', (tester) async {
    await pumpChatWidget(
      tester,
      wrap(ChatView(config: config())),
      overrides: overrides(
        _ScriptApi(() => const Stream.empty()),
        policy: _DenyPolicy(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();

    // gate banner 升级入口出现
    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
  });
}

class _DenyPolicy implements FreeAllowancePolicy {
  @override
  bool allows(PremiumFeature feature) => false;
}

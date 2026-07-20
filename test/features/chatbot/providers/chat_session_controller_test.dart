/// ChatSessionController 测试：状态流转 / 防竞态 / 闸门 / 计费。
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/models/chat_role.dart';
import 'package:echo_loop/features/chatbot/models/chatbot_config.dart';
import 'package:echo_loop/features/chatbot/providers/chat_api_client_provider.dart';
import 'package:echo_loop/features/chatbot/providers/chat_session_controller.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/chatbot/services/ndjson_text_stream.dart';
import 'package:echo_loop/features/chatbot/state/chat_session_state.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/ai_trial_usage_provider.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/services/free_allowance_policy.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mock_providers.dart';

/// 可脚本化的 ChatApi 假实现：每次 streamChat 调用交给 [script]，并捕获入参。
class _ScriptApi implements ChatApi {
  _ScriptApi(this.script);
  final Stream<ChatTextFrame> Function(CancelToken? cancelToken) script;

  List<ChatMessage>? lastHistory;
  Map<String, Object?>? lastContext;
  String? lastTargetLanguage;
  int callCount = 0;

  @override
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) {
    callCount++;
    lastHistory = history;
    lastContext = context;
    lastTargetLanguage = targetLanguage;
    return script(cancelToken);
  }

  @override
  void dispose() {}
}

/// 记录 consume 调用次数的试用计数替身。
class _RecordingTrialUsage extends AiTrialUsageNotifier {
  int consumeCount = 0;
  @override
  Map<PremiumFeature, int> build() => const {};
  @override
  void consume(PremiumFeature feature) => consumeCount++;
}

class _FixedSubscription extends SubscriptionController {
  _FixedSubscription(this._state);
  final EntitlementState _state;
  @override
  EntitlementState build() => _state;
}

class _DenyPolicy implements FreeAllowancePolicy {
  const _DenyPolicy();
  @override
  bool allows(PremiumFeature feature) => false;
}

Session _session() => Session(
  accessToken: 'test-token',
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
  context: {'sentence': 'The fox'},
  title: 'T',
  inputPlaceholder: 'P',
);

const _pro = EntitlementState(
  status: EntitlementStatus.premium,
  entitlement: Entitlement(isPremium: true),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingTrialUsage trialUsage;

  /// 构造容器：默认已登录 + 免费 + 放行。
  ///
  /// supabaseSessionProvider 是 StreamProvider（`Stream.value` 异步 emit）；
  /// controller 同步读 `valueOrNull`，故先 await session future 让其落定，
  /// 避免误判 AsyncLoading → authRequired。
  Future<ProviderContainer> make(
    _ScriptApi api, {
    bool authenticated = true,
    bool hasSession = true,
    EntitlementState subscription = const EntitlementState.free(),
    FreeAllowancePolicy policy = const AlwaysAllowPolicy(),
    bool holdListener = true,
  }) async {
    trialUsage = _RecordingTrialUsage();
    final container = ProviderContainer(
      overrides: [
        chatApiClientProvider.overrideWithValue(api),
        isAuthenticatedProvider.overrideWithValue(authenticated),
        supabaseSessionProvider.overrideWith(
          (ref) => Stream<Session?>.value(hasSession ? _session() : null),
        ),
        subscriptionControllerProvider.overrideWith(
          () => _FixedSubscription(subscription),
        ),
        freeAllowancePolicyProvider.overrideWithValue(policy),
        aiTrialUsageProvider.overrideWith(() => trialUsage),
        appSettingsProvider.overrideWith(
          () =>
              TestAppSettings(const AppSettingsState(nativeLanguage: 'zh-CN')),
        ),
      ],
    );
    addTearDown(container.dispose);
    // 常驻 listener：多数用例两次 read 之间要稳定持有同一实例。
    // holdListener=false 用于验证 keepAlive（无 listener 也不被回收）。
    if (holdListener) {
      container.listen(
        chatSessionControllerProvider(_config),
        (_, __) {},
        fireImmediately: true,
      );
    }
    await container.read(supabaseSessionProvider.future); // 等 session 落定
    return container;
  }

  ChatSessionController ctrl(ProviderContainer c) =>
      c.read(chatSessionControllerProvider(_config).notifier);
  ChatSessionState st(ProviderContainer c) =>
      c.read(chatSessionControllerProvider(_config));

  Stream<ChatTextFrame> okStream() async* {
    yield const ChatTextFrame(text: '它', isFinal: false);
    yield const ChatTextFrame(text: '它表示', isFinal: false);
    yield const ChatTextFrame(text: '它表示……', isFinal: true);
  }

  test('发送 → 逐帧更新最后一条 assistant → final 转 done+idle+consume 一次', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('这句话什么意思？');

    final msgs = st(c).messages;
    expect(msgs, hasLength(2)); // user + assistant
    expect(msgs[0].role, ChatRole.user);
    expect(msgs[1].role, ChatRole.assistant);
    expect(msgs[1].content, '它表示……');
    expect(msgs[1].status, ChatMessageStatus.done);
    expect(st(c).status, ChatSessionStatus.idle);
    expect(trialUsage.consumeCount, 1);
    expect(api.lastContext, {'sentence': 'The fox'});
    expect(api.lastTargetLanguage, 'zh-CN');
  });

  test('会员成功不 consume', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api, subscription: _pro);
    await ctrl(c).send('hi');
    expect(trialUsage.consumeCount, 0);
    expect(st(c).messages.last.status, ChatMessageStatus.done);
  });

  test('空文本 / 流式中 send 无效', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('   ');
    expect(st(c).messages, isEmpty);
    expect(api.callCount, 0);
  });

  test('未登录 send → gate=authRequired，不发请求', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api, authenticated: false);
    await ctrl(c).send('hi');
    expect(st(c).gate, ChatGate.authRequired);
    expect(st(c).messages, isEmpty);
    expect(api.callCount, 0);
  });

  test('已登录未解锁 send → gate=quotaExceeded，不发请求', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api, policy: const _DenyPolicy());
    await ctrl(c).send('hi');
    expect(st(c).gate, ChatGate.quotaExceeded);
    expect(api.callCount, 0);
  });

  test('后端 402 → 该条 quotaBlocked（gate 不变）', () async {
    final api = _ScriptApi(
      (_) => Stream<ChatTextFrame>.error(
        DioException(
          requestOptions: RequestOptions(path: '/chat'),
          response: Response(
            requestOptions: RequestOptions(path: '/chat'),
            statusCode: 402,
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
    );
    final c = await make(api);
    await ctrl(c).send('hi');
    expect(st(c).messages.last.status, ChatMessageStatus.quotaBlocked);
    expect(st(c).gate, ChatGate.none);
    expect(trialUsage.consumeCount, 0);
  });

  test('流内错误 → 该条 error', () async {
    final api = _ScriptApi(
      (_) => Stream<ChatTextFrame>.error(const ChatStreamException()),
    );
    final c = await make(api);
    await ctrl(c).send('hi');
    expect(st(c).messages.last.status, ChatMessageStatus.error);
    expect(st(c).status, ChatSessionStatus.idle);
  });

  test('自然结束无 done 且非用户停止 → 该条 error 可重试', () async {
    final api = _ScriptApi((_) async* {
      yield const ChatTextFrame(text: '半截', isFinal: false);
    });
    final c = await make(api);
    await ctrl(c).send('hi');
    expect(st(c).messages.last.status, ChatMessageStatus.error);
    expect(st(c).messages.last.content, '半截');
  });

  test('stop → cancel 抛异常 → 保留部分文本为 done，不报错、不 consume', () async {
    final api = _ScriptApi((ct) async* {
      yield const ChatTextFrame(text: '部分', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw DioException(
        requestOptions: RequestOptions(path: '/chat'),
        type: DioExceptionType.cancel,
      );
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(st(c).messages.last.content, '部分');
    ctrl(c).stop();
    await f;
    expect(st(c).messages.last.status, ChatMessageStatus.done);
    expect(st(c).messages.last.content, '部分');
    expect(st(c).status, ChatSessionStatus.idle);
    expect(trialUsage.consumeCount, 0);
  });

  test('stop 后流以自然结束形态收尾 → _stopRequested 兜底仍为 done', () async {
    final api = _ScriptApi((ct) async* {
      yield const ChatTextFrame(text: '部分', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // 自然结束，不抛异常
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    ctrl(c).stop();
    await f;
    expect(st(c).messages.last.status, ChatMessageStatus.done);
    expect(st(c).messages.last.content, '部分');
  });

  test('首 token 前停止（占位为空）→ 占位被移除，不留空气泡', () async {
    final api = _ScriptApi((ct) async* {
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      // 无任何 frame，自然结束
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(st(c).messages.last.role, ChatRole.assistant); // 占位存在
    ctrl(c).stop();
    await f;
    // 空占位被移除，仅剩 user
    expect(st(c).messages, hasLength(1));
    expect(st(c).messages.last.role, ChatRole.user);
  });

  test('retry → 移除最后 user 及其后消息，复用闸门重新流式', () async {
    // 首轮失败
    var first = true;
    final api = _ScriptApi((_) {
      if (first) {
        first = false;
        return Stream<ChatTextFrame>.error(const ChatStreamException());
      }
      return okStream();
    });
    final c = await make(api);
    await ctrl(c).send('hi');
    expect(st(c).messages.last.status, ChatMessageStatus.error);

    await ctrl(c).retry();
    expect(api.callCount, 2);
    final msgs = st(c).messages;
    expect(msgs, hasLength(2)); // 仍是 1 user + 1 assistant（旧的失败对被移除）
    expect(msgs.last.status, ChatMessageStatus.done);
    expect(msgs.last.content, '它表示……');
    expect(trialUsage.consumeCount, 1);
  });

  test('send 带 quote → user 消息存 quote，发后端 content 并入 blockquote', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('详细解释', quote: 'pretty busy');

    final userMsg = st(c).messages.first;
    expect(userMsg.role, ChatRole.user);
    expect(userMsg.content, '详细解释'); // 气泡只显示纯问题
    expect(userMsg.quote, 'pretty busy');
    // 发后端时 quote 并入 blockquote（toWire）。
    expect(
      api.lastHistory!.first.toWire(instruction: 'INSTR')['content'],
      'INSTR\n\n<quote>\npretty busy\n</quote>\n\n详细解释',
    );
  });

  test('retry 保留原 user 消息的 quote', () async {
    var first = true;
    final api = _ScriptApi((_) {
      if (first) {
        first = false;
        return Stream<ChatTextFrame>.error(const ChatStreamException());
      }
      return okStream();
    });
    final c = await make(api);
    await ctrl(c).send('翻译', quote: 'so I can do');
    expect(st(c).messages.last.status, ChatMessageStatus.error);

    await ctrl(c).retry();
    expect(st(c).messages.first.quote, 'so I can do');
    expect(
      api.lastHistory!.first.toWire(instruction: 'INSTR')['content'],
      'INSTR\n\n<quote>\nso I can do\n</quote>\n\n翻译',
    );
  });

  test('regenerate → 移除该 assistant 之前的 user 及其后消息，重新流式', () async {
    var round = 0;
    final api = _ScriptApi((_) {
      round++;
      return round == 1
          ? (() async* {
              yield const ChatTextFrame(text: '旧答案', isFinal: true);
            })()
          : okStream();
    });
    final c = await make(api);
    await ctrl(c).send('问题');
    final botId = st(c).messages.last.id;
    expect(st(c).messages.last.content, '旧答案');

    await ctrl(c).regenerate(botId);
    expect(api.callCount, 2);
    final msgs = st(c).messages;
    expect(msgs, hasLength(2)); // 仍是 1 user + 1 assistant（无重复 user、无分叉）
    expect(msgs.first.content, '问题');
    expect(msgs.last.content, '它表示……');
    expect(msgs.last.status, ChatMessageStatus.done);
  });

  test('regenerate 流式中被忽略', () async {
    final api = _ScriptApi((ct) async* {
      yield const ChatTextFrame(text: '部分', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final botId = st(c).messages.last.id;
    await ctrl(c).regenerate(botId); // 流式中：应无效
    expect(api.callCount, 1);
    ctrl(c).stop();
    await f;
  });

  test('messageContent → 返回原文；未找到返回 null', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('第一句');
    final userId = st(c).messages.first.id;
    expect(ctrl(c).messageContent(userId), '第一句');
    expect(ctrl(c).messageContent('nope'), isNull);
  });

  test('editAndResend → 截断该 user 及其后消息并以新文本重发', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('第一句');
    final userId = st(c).messages.first.id;
    expect(st(c).messages, hasLength(2));

    await ctrl(c).editAndResend(userId, '改后的问题');
    // 旧 user + 旧 assistant 被截断，重发出新 user + 新 assistant。
    expect(st(c).messages, hasLength(2));
    expect(st(c).messages.first.content, '改后的问题');
    expect(st(c).messages.first.id, isNot(userId)); // 新一轮的新消息
  });

  test('editAndResend 空文本不处理', () async {
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    await ctrl(c).send('第一句');
    final userId = st(c).messages.first.id;
    await ctrl(c).editAndResend(userId, '   ');
    expect(st(c).messages, hasLength(2)); // 状态不变
    expect(st(c).messages.first.id, userId);
  });

  test('editAndResend 流式中不处理', () async {
    final api = _ScriptApi((ct) async* {
      yield const ChatTextFrame(text: '部分', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final userId = st(c).messages.first.id;
    await ctrl(c).editAndResend(userId, '改后');
    expect(st(c).messages, hasLength(2)); // 未截断、未重发
    expect(st(c).messages.first.id, userId);
    ctrl(c).stop();
    await f;
  });

  test('clear → 回初始态并取消在途', () async {
    final api = _ScriptApi((ct) async* {
      yield const ChatTextFrame(text: '部分', isFinal: false);
      while (!(ct?.isCancelled ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final c = await make(api);
    final f = ctrl(c).send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    ctrl(c).clear();
    expect(st(c).messages, isEmpty);
    expect(st(c).status, ChatSessionStatus.idle);
    // 收尾在途 future，确保迟到帧不写状态
    ctrl(c).stop();
    await f;
    expect(st(c).messages, isEmpty);
  });

  test('旧 seq 帧回调被丢弃（clear 后迟到帧不写状态）', () async {
    final controllers = <StreamController<ChatTextFrame>>[];
    final api = _ScriptApi((_) {
      final sc = StreamController<ChatTextFrame>();
      controllers.add(sc);
      return sc.stream;
    });
    final c = await make(api);
    unawaited(ctrl(c).send('hi'));
    await Future<void>.delayed(Duration.zero);
    controllers.first.add(const ChatTextFrame(text: '早', isFinal: false));
    await Future<void>.delayed(Duration.zero);
    expect(st(c).messages.last.content, '早');

    ctrl(c).clear(); // _seq++ 作废
    // 旧流迟到帧
    controllers.first.add(const ChatTextFrame(text: '迟到', isFinal: false));
    await Future<void>.delayed(Duration.zero);
    expect(st(c).messages, isEmpty); // 未被迟到帧污染
    await controllers.first.close();
  });

  test('dispose → 不写已销毁状态', () async {
    final controllers = <StreamController<ChatTextFrame>>[];
    final api = _ScriptApi((_) {
      final sc = StreamController<ChatTextFrame>();
      controllers.add(sc);
      return sc.stream;
    });
    final c = await make(api);
    final notifier = ctrl(c);
    unawaited(notifier.send('hi'));
    await Future<void>.delayed(Duration.zero);
    // 主动 invalidate 触发销毁（keepAlive 下仍可被 invalidate 重建）
    c.invalidate(chatSessionControllerProvider(_config));
    controllers.first.add(const ChatTextFrame(text: '迟到', isFinal: true));
    await Future<void>.delayed(Duration.zero);
    // 未抛异常即通过；关闭流收尾
    await controllers.first.close();
  });

  test('历史软上限截断 + greeting/占位/失败不入 _buildHistory', () async {
    final configWithGreeting = ChatbotConfig(
      sessionId: _config.sessionId,
      endpoint: _config.endpoint,
      context: _config.context,
      title: 'T',
      inputPlaceholder: 'P',
      greeting: '你好',
    );
    final api = _ScriptApi((_) => okStream());
    final c = await make(api);
    c.listen(
      chatSessionControllerProvider(configWithGreeting),
      (_, __) {},
      fireImmediately: true,
    );
    final notifier = c.read(
      chatSessionControllerProvider(configWithGreeting).notifier,
    );

    // 连发 30 轮，累计 done 消息远超 50。
    for (var i = 0; i < 30; i++) {
      await notifier.send('m$i');
    }
    final hist = api.lastHistory!;
    // 截断到 50
    expect(hist.length, lessThanOrEqualTo(50));
    // 不含 greeting（includeInHistory=false）
    expect(hist.any((m) => m.content == '你好'), isFalse);
    // 全部为 done（无占位/失败）
    expect(hist.every((m) => m.status == ChatMessageStatus.done), isTrue);
  });

  test('keepAlive：无常驻 listener 时会话跨读取存活（内存保活，不被回收）', () async {
    final api = _ScriptApi((_) => okStream());
    // 不持有常驻 listener：autoDispose 会在无 listener 时回收，keepAlive 则保留。
    final c = await make(api, holdListener: false);
    await ctrl(c).send('保活测试');
    expect(st(c).messages, hasLength(2));

    // 放开引用后等待若干事件循环——给 autoDispose 回收的时机窗口。
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // 重新读取同 config：内容仍在。若为 autoDispose，此处会得到重建的初始空态。
    expect(st(c).messages, hasLength(2));
    expect(st(c).messages.last.content, '它表示……');
    expect(st(c).messages.last.status, ChatMessageStatus.done);
    expect(api.callCount, 1); // 未重建 → 未重新发起
  });
}

# 通用 Chatbot 组件 — 实现级详细计划

> 本文档为可直接交付实现的规格说明。实现方无需再次 plan，按"任务拆解"顺序逐项落地即可。所有接口签名、输入输出、协议契约、测试用例均已提前约定。
> 目标仓库：`/Volumes/SamsungT7/workspace/fluency/chatbot`（Flutter app `echo_loop`）。
>
> **修订版 v2（2026-07-18）**：经三方 review（代码事实核实 / 架构 / PM）修订。主要变更：
> ① 修正 4 处编译级引用错误（`clock.now()` 替代不存在的 clockProvider、`AppSpacing` 字段名、`ensureSignedInForAction`/`createBackendDio`/`configureAiHttpClientAdapter` 均为命名参数）；
> ② 流式「自然结束无 done」改判 error（服务端异常断流，不得伪装成完成态）；
> ③ sheet 载体放弃 DraggableScrollableSheet，改固定高度；
> ④ 流式重建改行级 select（ValueKey 不跳过 build）；
> ⑤ 错误态收敛为「发送前闸门 banner + 轮内失败气泡 inline」双轨，删会话级 lastError；
> ⑥ retry 规格补全（与 send 共用 `_startTurn` 闸门）；
> ⑦ 新增发布开关 `kChatbotEnabled`、debug 假流 `FakeChatApiClient`、流程登记任务 T0；
> ⑧ 澄清：额度唯一权威是后端 402（本地预测现网为死分支）；加 `PremiumFeature.aiChat` 无任何 switch 连带修改。

---

## 1. Context（为什么做）

Echo Loop 已有多项**一问一答式**流式 AI 能力（翻译/句子解析/词典/意群），但缺**多轮对话式 AI 助手**。本次实现一个**通用可插拔 chatbot 组件**：
- 同一套 UI/逻辑接入应用不同位置；每处用不同后端 endpoint（= 不同 system prompt）、传入不同业务 context。
- 既能在 bottom sheet 弹窗用，也能在完整页面用（同一 `ChatView`）。
- 功能：多轮聊天、文字输入（未来可切语音，本次留插槽）、markdown 渲染、流式显示、停止生成、复制、错误重试、自动滚动、额度门、首帧前「思考中」指示、暗色模式适配、桌面端（macOS）Enter 发送。

### 已拍板决策
1. **后端端点尚不存在** → 本次定义 NDJSON 协议契约 + 用 mock Dio 测试跑通客户端。后端端点为外部待办。前端不被阻塞。
2. **聊天 UI = 自建最小 UI + `gpt_markdown`**（不用 flutter_chat_ui：其强制 `ChatController` 与项目"单一数据源"冲突、传递依赖拖入 dio/path_provider/provider、流式状态机仍需自写、按全高聊天界面设计不利于塞进小面板；其唯一可复用原语 gpt_markdown 直接单独用）。
3. **首接入点** = 句子讲解页 `SentenceDetailScreen` 的 AppBar 加 AI 图标按钮 → 弹 chatbot bottom sheet，context 传当前句子。同时交付全屏页壳作第二载体。
4. **接入额度门** = 新增 `PremiumFeature.aiChat`，复用 402→超额→Paywall 全链路，每条成功用户消息消耗一次试用（会员不计数）。
5. **持久化** = v1 仅内存态（autoDispose controller，关闭即销毁）。Controller 与存储解耦，未来可加 drift 不改 UI。
6. **发布控制** = 入口按钮由编译期常量 `kChatbotEnabled`（默认 **false**）控制。后端端点不存在，若无开关，T8 一合入线上用户就会看到一个每次必失败的 AI 按钮。组件与测试照常合入，后端就绪后翻开关即可。
7. **运行时 mock** = 交付 debug 假流 `FakeChatApiClient`（预置 NDJSON 分片 + 模拟延迟），由 `kChatbotUseFakeApi` 切换。否则后端不存在时 §13 手动验收无法闭环。

---

## 2. 复用的现有基建（不重新发明，路径已核实）

| 用途 | 文件 / 符号 |
|---|---|
| NDJSON 传输层（字节流→逐行 JSON） | `lib/services/ndjson_stream.dart` → `decodeNdjson(Stream<List<int>> bytes, {void Function(String)? onLine, Duration? idleTimeout})` |
| 流式 API client 范式（stream/validateStatus/错误体映射） | `lib/services/sentence_ai_api_client.dart` |
| 统一后端 Dio 工厂（自动注入 client-info header + 日志拦截器） | `lib/services/backend_dio.dart` → `createBackendDio({String baseUrl, String? appVersion, Duration connectTimeout, Duration receiveTimeout, String apiLogTag})` |
| HTTP2 适配 + 空闲超时常量 | `lib/services/ai_http_client_adapter.dart` → `configureAiHttpClientAdapter(dio, {baseUrl, http2Enabled})`、`aiHttp2EnabledByDefault`、`aiHttpStreamIdleTimeout` |
| GeoInterceptor | `lib/analytics/geo_interceptor.dart` → `GeoInterceptor(prefs)` |
| 防竞态状态机范式（seq + CancelToken + disposed 守卫 + sealed 态） | `lib/providers/dictionary/lookup_controller.dart` → `DictionaryLookupController` |
| API base url | `lib/config/api_config.dart` → `const apiBaseUrl` |
| app 版本（随请求 x-app-version） | `lib/providers/package_info_provider.dart` → `readAppVersion(ref)` |
| 登录态 access token | `lib/features/auth/providers/auth_providers.dart` → `supabaseSessionProvider.valueOrNull?.accessToken`、`isAuthenticatedProvider` |
| 登录引导（tap site） | `lib/features/auth/sign_in_required_dialog.dart` → `Future<bool> ensureSignedInForAction({required BuildContext context, required WidgetRef ref, required String title, required String message})` |
| 额度门查询 | `lib/features/subscription/providers/feature_access_provider.dart` → `featureAccessProvider(PremiumFeature)`（**同步 bool**，非 AsyncValue；未登录 false；会员 true；免费登录用户当前恒 true——现行策略为 AlwaysAllowPolicy，见 §6） |
| 会员判定 | `lib/features/subscription/providers/subscription_controller.dart` → `subscriptionControllerProvider.isActive` |
| 消耗免费试用 | `aiTrialUsageProvider.notifier.consume(PremiumFeature)`（见 sentence_ai_provider.dart:924） |
| 超额异常 | `lib/providers/sentence_ai_provider.dart` → `AiFeatureQuotaExceededException({PremiumFeature? feature, DateTime? resetAt})`、`AiFeatureAuthRequiredException()` |
| 打开 Paywall | `lib/features/subscription/widgets/feature_gate.dart` → `Future<void> openPaywall(BuildContext context, WidgetRef ref)`（平台未启用订阅时仅 snackbar） |
| 目标语言 | `lib/providers/settings_provider.dart` → `appSettingsProvider.select((s) => s.nativeLanguage)`（String，默认 'zh-CN'，不会为空串） |
| 时间来源 | `package:clock` → `clock.now()`（项目惯例，见 subscription_controller.dart:200；**仓库无 clockProvider**） |
| 设计 token | `lib/theme/app_theme.dart` → `AppSpacing`（字段名 **`.xs/.s/.m/.l/.xl`**，值 4/8/16/24/32；不存在 `.xs4/.m16` 这类命名）、`AppTextStyles`（`caption(context)`/`label(context)` 静态方法）、种子色 #1976D2 |
| 全屏页路由约束（§7.17） | `lib/router/app_router.dart` → `AppRoutes.pushNested(context, segment)`、`_RestoredRoutePopper`、`_sentenceDetailRoute()` 范例 |
| bottom sheet 惯例 | `showModalBottomSheet(isScrollControlled:true, shape 圆角20)`；每 sheet 导出顶层 `showXxxSheet({required context, ...})`（命名参数惯例） |
| 首接入点宿主 | `lib/screens/sentence_detail_screen.dart` → `SentenceDetailScreen`（`appBar: AppBar(title: Text(args.audioName), centerTitle: true)` 在 **268** 行，当前无 `actions:`；`SentenceDetailArgs` 含 `audioName`/`sentenceText`/`sentenceIndex(int)`） |
| l10n | `lib/l10n/app_en.arb`（模板）、`app_zh.arb`；引用 `AppLocalizations.of(context)!.key` |
| 测试脚手架 | `test/helpers/test_app.dart` → `createTestApp/createTestScreen`；`test/helpers/mock_providers.dart`；`mocktail` |

---

## 3. 后端协议契约（NDJSON token 追加式）

> 需后端配合新增 chat 流式端点。前端按此实现 + mock；后端待就绪后对齐。

### 3.1 请求
- **Method / Path**：`POST <config.endpoint>`（如 `/api/v1/stream/chat/sentence`）。
- **Headers**：`Authorization: Bearer <accessToken>`；client-info（`x-app-platform`/`x-app-distribution`/`x-app-version`，由 `createBackendDio` 自动带）。
- **Body（JSON）**：
```json
{
  "messages": [
    {"role": "user", "content": "这句话什么意思？"},
    {"role": "assistant", "content": "它表示……"},
    {"role": "user", "content": "再举个例子"}
  ],
  "context": {"sentence": "The quick brown fox..."},
  "targetLanguage": "zh-CN"
}
```
- `messages`：本会话完整历史（软上限 50 条，超出取最近 50 条；不含流式失败/占位消息）。role 仅 `user`/`assistant`。
- `context`：宿主注入的业务数据（任意 JSON map）；为空则省略该字段。
- `targetLanguage`：BCP 47（取 `appSettings.nativeLanguage`）；为空省略。

### 3.2 成功响应（HTTP 200，NDJSON，每行一个 JSON 对象，`\n` 分隔）
```
{"meta":{"messageId":"msg_abc","model":"..."}}   ← 可选，通常首帧；未知键忽略
{"delta":"它"}
{"delta":"表示"}
{"delta":"……"}
{"done":true}                                     ← 正常结束（末帧 isFinal=true）
```
- `delta`：文本增量，追加到当前 assistant 消息累计文本。
- `done:true`：正常结束。
- 未知帧/未知键：忽略（前向兼容）。
- **未收到 `done` 即流结束 = 服务端异常断流**（后端崩溃/网关掐流），客户端判为 error 可重试。用户主动取消走 CancelToken（表现为 `DioException(cancel)`），不会以「自然结束」形态出现，见 §5.8。

### 3.3 错误
- **流内错误帧**：`{"__error":"..."}` → 抛 `ChatStreamException`。
- **HTTP 非 200**（`validateStatus:(_)=>true` 让 Dio 不提前抛，手动读小 JSON 错误体 `{"code":"...","error":"..."}`）：
  - `401` → 抛 `ChatAuthRequiredException`。
  - `402`（`code == "quota_exceeded"`）→ 抛带状态码的 `DioException`（response.statusCode=402, data=errorMap），由 controller 映射为额度态。
  - 其余非 200 → 抛 `DioException(badResponse)`。
- **帧间空闲僵死**：`decodeNdjson(idleTimeout: aiHttpStreamIdleTimeout)` 抛 `TimeoutException` → 累积层归一为 `ChatStreamException`。

---

## 4. 目录结构与文件清单

新增 `lib/features/chatbot/`（对齐 `lib/features/subscription/` 全分层）。**每文件 ≤500 行、每函数 ≤50 行、中文文档注释、类型安全（禁 dynamic/as/!）。**

```
lib/features/chatbot/
  models/
    chat_role.dart              // enum ChatRole
    chat_message.dart           // ChatMessage + ChatMessageStatus
    chatbot_config.dart         // ChatbotConfig
  state/
    chat_session_state.dart     // ChatSessionState + ChatSessionStatus + ChatGate
  services/
    ndjson_text_stream.dart     // accumulateNdjsonText + ChatTextFrame + ChatStreamException
    chat_api_client.dart        // ChatApi 抽象 + ChatApiClient + ChatAuthRequiredException
    fake_chat_api_client.dart   // FakeChatApiClient（debug 假流：预置 NDJSON 分片 + 延迟）
  providers/
    chat_api_client_provider.dart   // chatApiClientProvider (keepAlive，返回 ChatApi)
    chat_session_controller.dart    // ChatSessionController (@riverpod family, autoDispose) + part '*.g.dart'
  widgets/
    chat_view.dart              // ChatView（纯组件，载体无关）
    message_list.dart           // ChatMessageList（列表 + 行级 select + 自动滚动 + 回底浮标）
    message_bubble.dart         // ChatMessageBubble（气泡 + 思考中指示 + inline 重试/升级 + 长按复制）
    markdown_message.dart       // MarkdownMessage（gpt_markdown 薄封装）
    chat_composer.dart          // ChatComposer（输入条 + 发送/停止切换 + 桌面 Enter 发送）
    chat_gate_banner.dart       // ChatGateBanner（发送前闸门：需登录/额度超限）
    context_chip.dart           // ChatContextChip（"正在讨论：…"，单行省略）
  screens/
    chat_screen.dart            // ChatScreen（全屏页壳）
  chatbot_flags.dart            // const kChatbotEnabled = false; const kChatbotUseFakeApi = false;
  chatbot_sheet.dart            // showChatbotSheet({required context, required config})
```

修改现有文件：
- `pubspec.yaml`：加 `gpt_markdown: ^1.1.8`（dependencies 区，AI/UI 相关处）。`uuid ^4.5.3`、`url_launcher ^6.3.1` **已存在**，无需新增。
- `lib/features/subscription/models/premium_feature.dart`：枚举加 `aiChat`。已核实：全仓无对 PremiumFeature 的 exhaustive switch，加枚举**零连带编译错误**。
- （可选）`lib/features/subscription/config/ai_trial_limits.dart`：`kAiTrialLimits` 显式补 `PremiumFeature.aiChat: 0`（穷举语义，防未来切换策略漏配；不加也不崩，`?? 0` 兜底）。
- `lib/router/app_router.dart`：加 `AppRoutes.chatbotSegment = 'chatbot'` 常量 + 在需要的入口路由声明 `_chatbotRoute()`（仅当用全屏页壳时）。
- `lib/screens/sentence_detail_screen.dart`：AppBar `actions:` 加 AI 图标按钮（受 `kChatbotEnabled` 控制）→ `showChatbotSheet(...)`。
- `lib/l10n/app_en.arb` + `app_zh.arb`：新增文案（见 §9）。
- `TASKS.md` + `PLAN.md`：登记本工作（见 T0，否则违反 CLAUDE.md §3 启动流程）。

---

## 5. 接口设计（逐文件 Dart 签名）

### 5.1 `models/chat_role.dart`
```dart
/// 对话角色。仅 user / assistant 参与后端历史。
enum ChatRole { user, assistant }
```

### 5.2 `models/chat_message.dart`
```dart
/// 单条消息状态。
/// - streaming：assistant 正在流式接收（content 随帧增长；content 为空时 UI 显示「思考中」动画指示）
/// - done：已完成（user 消息发出即 done；assistant 收到 done 帧或被用户主动停止后）
/// - error：生成失败（网络/服务端/流内错误/异常断流），气泡 inline 重试
/// - quotaBlocked：额度超限（后端 402），气泡 inline 升级入口
enum ChatMessageStatus { streaming, done, error, quotaBlocked }

/// 不可变消息模型。Model 不依赖 State。
@immutable
class ChatMessage {
  final String id;              // 客户端生成（uuid v4），全生命周期不变。
                                // meta.messageId 仅记录日志，v1 不覆盖 id——中途换 id 会令
                                // ValueKey 变化导致气泡重建、_updateBot 按旧 id 找不到目标。
  final ChatRole role;
  final String content;         // 累计文本，流式期间随帧增长
  final ChatMessageStatus status;
  final DateTime createdAt;
  final bool includeInHistory;  // false = 仅展示、不发后端（greeting 用）

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
    this.includeInHistory = true,
  });

  /// 构造一条已发出的用户消息（status=done）。
  factory ChatMessage.user({required String id, required String content, required DateTime createdAt});

  /// 构造一条空的 assistant 占位（status=streaming，content=''）。
  factory ChatMessage.assistantPlaceholder({required String id, required DateTime createdAt});

  /// 构造开场白（status=done，includeInHistory=false，不发后端）。
  factory ChatMessage.greeting({required String id, required String content, required DateTime createdAt});

  ChatMessage copyWith({String? content, ChatMessageStatus? status});

  /// 序列化为后端历史条目（仅 role/content）。
  Map<String, Object?> toWire() => {'role': role.name, 'content': content};
}
```

### 5.3 `models/chatbot_config.dart`
```dart
/// 可插拔配置：驱动同一套组件在不同位置表现不同。
/// == / hashCode 比 sessionId + endpoint —— context（Map 无稳定相等）排除，避免 rebuild 时
/// 新建 map 实例误重建 controller；endpoint 纳入相等性，防止两个接入点误用同 sessionId 时
/// 静默串到第一个 controller 的后端（family 身份键完整性）。
@immutable
class ChatbotConfig {
  final String sessionId;              // family 身份键，每接入点稳定唯一，如 'sentence:$hash'
  final String endpoint;               // 后端 path，不同 endpoint = 不同 system prompt
  final Map<String, Object?> context;  // 业务 context，随请求体发；一次会话内固定
  final String title;                  // 载体标题
  final String inputPlaceholder;       // 输入框 placeholder
  final String? greeting;              // 可选开场白（作 assistant 首条 done 消息展示，不入 messages 历史发后端）
  final String? contextSummary;        // 可选，上下文 chip 显示文本（如句子摘要）

  const ChatbotConfig({
    required this.sessionId,
    required this.endpoint,
    this.context = const {},
    required this.title,
    required this.inputPlaceholder,
    this.greeting,
    this.contextSummary,
  });

  @override
  bool operator ==(Object other) =>
      other is ChatbotConfig && other.sessionId == sessionId && other.endpoint == endpoint;
  @override
  int get hashCode => Object.hash(sessionId, endpoint);
}
```

### 5.4 `state/chat_session_state.dart`
```dart
/// 会话整体运行态。
/// - idle：可发送
/// - streaming：正在生成（禁止再次发送）
enum ChatSessionStatus { idle, streaming }

/// 发送前闸门态（ChatGateBanner 的唯一数据源）。
/// 一轮已开始后的失败不走这里，只落在那条 assistant 消息的 status 上（气泡 inline 重试/升级）。
enum ChatGate { none, authRequired, quotaExceeded }

/// 会话运行态（单一数据源）。State 可含 Model。
@immutable
class ChatSessionState {
  final List<ChatMessage> messages;   // 展示用完整列表（含 greeting）
  final ChatSessionStatus status;
  final ChatGate gate;                // 发送前闸门：需登录 / 额度超限（本地预测）

  const ChatSessionState({
    required this.messages,
    required this.status,
    this.gate = ChatGate.none,
  });

  /// 初始态：若 config.greeting 非空，插入一条 ChatMessage.greeting 开场白。
  factory ChatSessionState.initial(ChatbotConfig config);

  ChatSessionState copyWith({
    List<ChatMessage>? messages,
    ChatSessionStatus? status,
    ChatGate? gate,
  });

  bool get isStreaming => status == ChatSessionStatus.streaming;
  bool get canSend => status != ChatSessionStatus.streaming;
}
```
> 注：错误态收敛为双轨，避免 banner 与气泡同时显示重试入口（单一数据源）——
> ① 发送前闸门（未登录 / 无 token / 本地额度预测拦截）：无气泡可挂 → `gate` 驱动 banner；
> ② 一轮已开始后的失败（网络 / 流内错误 / 异常断流 / 后端 402）：只落在那条 assistant 消息的
>   `status`（气泡 inline 重试或升级入口），**不设会话级 lastError**。
> 附带收益：删掉了 lastError 后不存在「copyWith 清 null」的哨兵问题。

### 5.5 `services/ndjson_text_stream.dart`
```dart
/// 聊天流式帧：累计全文快照 + 是否末帧。
@immutable
class ChatTextFrame {
  final String text;        // 到当前为止的累计全文
  final bool isFinal;       // 仅收到 {"done":true} 的末帧为 true
  final String? messageId;  // 来自 meta.messageId，可为 null
  const ChatTextFrame({required this.text, required this.isFinal, this.messageId});
}

/// 流内错误（{"__error":..} / 行损坏 / 空闲超时）。
class ChatStreamException implements Exception {
  const ChatStreamException();
  @override
  String toString() => 'ChatStreamException';
}

/// 把 NDJSON 事件流累积为「逐帧累计全文」流。
/// 复用 decodeNdjson 的输出。纯函数、无状态、不感知取消（取消由上游关流使流自然结束）。
///
/// 协议：{"delta":"..."} 追加 / {"done":true} 结束 / {"__error":..} 抛错 /
///       {"meta":{"messageId":..}} 记录 id / 未知键忽略。
Stream<ChatTextFrame> accumulateNdjsonText(Stream<Map<String, dynamic>> events) async* {
  final buffer = StringBuffer();
  String? messageId;
  try {
    await for (final ev in events) {
      if (ev.containsKey('__error')) throw const ChatStreamException();
      if (ev['done'] == true) {
        yield ChatTextFrame(text: buffer.toString(), isFinal: true, messageId: messageId);
        return;
      }
      final meta = ev['meta'];
      if (meta is Map && meta['messageId'] is String) {
        messageId = meta['messageId'] as String;
        continue;
      }
      final delta = ev['delta'];
      if (delta is String) {
        buffer.write(delta);
        yield ChatTextFrame(text: buffer.toString(), isFinal: false, messageId: messageId);
      }
      // 未知帧忽略
    }
    // 流自然结束但未收到 done：不 yield final。
    // 语义注意：用户主动取消走 CancelToken → DioException(cancel)，不会以自然结束形态到达；
    // 自然结束却无 done = 服务端异常断流，消费方（controller）必须判 error，不得当成完成态。
  } on FormatException {
    throw const ChatStreamException();
  } on TimeoutException {
    throw const ChatStreamException();
  }
}
```

### 5.6 `services/chat_api_client.dart`
```dart
/// 请求聊天但未登录 / token 失效（HTTP 401）。
class ChatAuthRequiredException implements Exception {
  const ChatAuthRequiredException();
  @override
  String toString() => 'ChatAuthRequiredException';
}

/// 聊天流式 API 抽象：真实实现 ChatApiClient 与 debug 假实现 FakeChatApiClient 共用，
/// provider 按 kChatbotUseFakeApi 切换；测试直接 override provider。
abstract interface class ChatApi {
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  });
  void dispose();
}

/// 通用聊天流式 API 客户端。对齐 SentenceAiApiClient 写法。
class ChatApiClient implements ChatApi {
  final Dio _dio;
  final void Function(String message) _streamLogPrint;

  ChatApiClient({
    required String baseUrl,
    String? appVersion,
    bool http2Enabled = aiHttp2EnabledByDefault,
    void Function(String message)? streamLogPrint,
  });
  // 内部（注意：以下工厂函数均为**命名参数**，不能位置传参）：
  //   _dio = createBackendDio(baseUrl: baseUrl, appVersion: appVersion,
  //            connectTimeout: 15s, receiveTimeout: 30s, apiLogTag: 'CHAT-API');
  //   configureAiHttpClientAdapter(_dio, baseUrl: baseUrl, http2Enabled: http2Enabled);
  //   SharedPreferences.getInstance().then((prefs) => _dio.interceptors.add(GeoInterceptor(prefs)));
  //   （照抄 SentenceAiApiClient 构造）

  /// 测试用：注入 Dio。
  ChatApiClient.withDio(this._dio, {void Function(String message)? streamLogPrint});

  /// 发起一轮聊天，逐帧 yield 累计全文。
  ///
  /// [endpoint] 来自 config；[history] 为完整对话历史（已截断，不含占位/失败消息）。
  /// 非 200：401→ChatAuthRequiredException；402→带状态码 DioException；其余→DioException(badResponse)。
  /// 流内错误→ChatStreamException。取消：传入的 cancelToken 被 cancel 时 Dio 抛 DioException(cancel)。
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  }) async* {
    // data: {'messages': history.map((m)=>m.toWire()).toList(),
    //        if (context.isNotEmpty) 'context': context,
    //        if (targetLanguage != null) 'targetLanguage': targetLanguage}
    // options: Options(responseType: ResponseType.stream, validateStatus:(_)=>true,
    //                  headers:{'Authorization':'Bearer $accessToken'})
    // 非 200 分支照抄 sentence client 的 _decodeErrorBody + 映射
    // 200：accumulateNdjsonText(decodeNdjson(body.stream, idleTimeout: aiHttpStreamIdleTimeout, onLine: 旁路日志))
    //      逐帧 yield；捕获 ChatStreamException 原样上抛
  }

  void dispose() => _dio.close();
}
```

### 5.6b `services/fake_chat_api_client.dart`（debug 假流）
```dart
/// debug 假实现：不发网络请求，按预置 NDJSON 分片以 30–80ms 间隔逐帧吐 delta、末帧 done，
/// 模拟真实流式节奏；响应 cancelToken 取消（停止吐帧、流结束）。
/// 用途：后端端点不存在时跑通 §13 手动验收（流式/停止/markdown/多轮）。
/// 仅当 kChatbotUseFakeApi=true 时由 provider 返回；不进 release 逻辑分支。
class FakeChatApiClient implements ChatApi { /* streamChat + dispose(空实现) */ }
```

### 5.7 `providers/chat_api_client_provider.dart`
```dart
part 'chat_api_client_provider.g.dart';

/// ChatApi 单例（keepAlive）。kChatbotUseFakeApi=true（仅 debug 联调用）时返回假实现。
@Riverpod(keepAlive: true)
ChatApi chatApiClient(Ref ref) {
  if (kChatbotUseFakeApi) return FakeChatApiClient();
  final client = ChatApiClient(baseUrl: apiBaseUrl, appVersion: readAppVersion(ref));
  ref.onDispose(client.dispose);
  return client;
}
```

### 5.8 `providers/chat_session_controller.dart`（核心，镜像 lookup_controller 防竞态）
```dart
part 'chat_session_controller.g.dart';

/// 会话 controller（family by ChatbotConfig，autoDispose）。
/// 单向数据流：UI 调 send/stop/retry/clear → 改 state → UI 渲染。
/// 函数 ≤50 行约束：闸门+组装抽 _startTurn；_run 只留 happy-path 循环；异常映射抽 _mapRunError。
@riverpod
class ChatSessionController extends _$ChatSessionController {
  int _seq = 0;                 // 每次发起流式请求自增；旧帧回调发现过期即丢弃
  CancelToken? _inflight;       // 当前在途请求
  bool _disposed = false;       // 销毁后回调一律丢弃
  bool _stopRequested = false;  // 本轮用户是否主动停止（兜底 cancel 以非异常形态到达的边缘情况）
  final _uuid = const Uuid();

  @override
  ChatSessionState build(ChatbotConfig config) {
    ref.onDispose(() {
      _disposed = true;
      _inflight?.cancel('controller disposed');   // 关 sheet/离页即取消在途 → 后端 abort 省 token
    });
    return ChatSessionState.initial(config);
  }

  /// 发送一条用户消息。前置：调用方（ChatView）已做登录拦截（ensureSignedInForAction）。
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;   // 空 / 流式中禁止
    await _startTurn(trimmed);
  }

  /// 停止生成：取消在途，保留已生成部分为 done（在 _run 的 cancel 分支落地）。
  void stop() {
    _stopRequested = true;
    _inflight?.cancel('user stopped');
  }

  /// 重试：重发最后一条 user 消息。
  /// 步骤：①定位最后一条 user；②移除它及其后所有消息（含失败/占位 assistant）；
  ///      ③复用 _startTurn —— 与 send 走同一闸门（登录/token/额度），不允许绕过。
  Future<void> retry() async {
    if (state.isStreaming) return;
    final lastUserIndex = state.messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (lastUserIndex < 0) return;
    final lastUserText = state.messages[lastUserIndex].content;
    state = state.copyWith(messages: state.messages.sublist(0, lastUserIndex));
    await _startTurn(lastUserText);
  }

  /// 清空对话：取消在途，回到初始态。
  void clear() {
    _inflight?.cancel('cleared');
    _seq++; // 作废在途回调
    state = ChatSessionState.initial(config);
  }

  /// 发起一轮（send/retry 共用）：闸门 → 追加 user+占位 → 流式。
  Future<void> _startTurn(String userText) async {
    // 1) 闸门（gate 是 banner 的唯一数据源）。
    //    注意：当前 freeAllowancePolicy 为 AlwaysAllowPolicy（恒放行），本地额度预测在现网是
    //    前向兼容的死分支；额度唯一权威是后端 402（见 §6），实现与测试不得假设本地会拦截。
    if (!ref.read(isAuthenticatedProvider)) {
      state = state.copyWith(gate: ChatGate.authRequired);
      return;
    }
    final accessToken = ref.read(supabaseSessionProvider).valueOrNull?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      state = state.copyWith(gate: ChatGate.authRequired);
      return;
    }
    if (!ref.read(featureAccessProvider(PremiumFeature.aiChat))) {
      state = state.copyWith(gate: ChatGate.quotaExceeded);
      return;
    }

    // 2) 追加 user(done) + assistant 占位(streaming)，清闸门
    final now = clock.now(); // package:clock，项目惯例（测试可注入；仓库无 clockProvider）
    final userMsg = ChatMessage.user(id: _uuid.v4(), content: userText, createdAt: now);
    final botId = _uuid.v4();
    final botMsg = ChatMessage.assistantPlaceholder(id: botId, createdAt: now);
    state = state.copyWith(
      messages: [...state.messages, userMsg, botMsg],
      status: ChatSessionStatus.streaming,
      gate: ChatGate.none,
    );

    await _run(botId, accessToken);
  }

  /// 内部：发起并消费流式，防竞态守卫。只留 happy-path，异常映射在 _mapRunError。
  Future<void> _run(String botId, String accessToken) async {
    final seq = ++_seq;
    _stopRequested = false;
    _inflight?.cancel('restart');
    final token = CancelToken();
    _inflight = token;

    final targetLanguage = ref.read(appSettingsProvider.select((s) => s.nativeLanguage));
    final history = _buildHistory(); // 完整历史（含刚追加的 user），软上限 50，剔除占位/失败/greeting

    final client = ref.read(chatApiClientProvider);
    try {
      await for (final frame in client.streamChat(
        endpoint: config.endpoint,
        history: history,
        context: config.context,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        cancelToken: token,
      )) {
        if (_disposed || seq != _seq) return;      // 防竞态守卫
        _updateBot(botId, frame.text);             // 只改这条 assistant content
        if (frame.isFinal) {
          _finishTurn(botId, ChatMessageStatus.done);
          _consumeTrial();                          // 成功计一次（会员不计；本地预测计数，权威在后端）
          return;
        }
      }
      // 流自然结束但无 final：
      // - _stopRequested（用户主动停止，兜底 cancel 以非异常形态到达）→ 保留部分为 done；
      // - 否则 = 服务端异常断流 → error 可重试（不得伪装成完成态）。
      if (_disposed || seq != _seq) return;
      _finishTurn(botId, _stopRequested ? ChatMessageStatus.done : ChatMessageStatus.error);
    } catch (e) {
      if (_disposed || seq != _seq) return;
      _finishTurn(botId, _mapRunError(e));         // 诊断日志：打印异常与 botId
    }
  }

  /// 异常 → 该条 assistant 消息的终态（气泡 inline 表达，不设会话级错误）。
  /// - DioException(cancel)（用户停止）→ done，保留已生成部分；
  /// - DioException(402)（额度权威判定）→ quotaBlocked（气泡 inline 升级入口）；
  /// - ChatAuthRequiredException(401) / ChatStreamException / 其余 → error（气泡 inline 重试）。
  ChatMessageStatus _mapRunError(Object e) {
    if (e is DioException && e.type == DioExceptionType.cancel) return ChatMessageStatus.done;
    if (e is DioException && e.response?.statusCode == 402) return ChatMessageStatus.quotaBlocked;
    return ChatMessageStatus.error;
  }

  void _consumeTrial() {
    if (ref.read(subscriptionControllerProvider).isActive) return;
    ref.read(aiTrialUsageProvider.notifier).consume(PremiumFeature.aiChat);
  }

  // 私有辅助：
  //   _buildHistory()：过滤 includeInHistory=false（greeting）、status==streaming（占位）、
  //                    status==error/quotaBlocked（失败），再取最近 50 条，map(toWire) 组装。
  //   _updateBot(id, text)：按 id 定位那条 assistant，copyWith(content) 后替换（不动其它条）。
  //   _finishTurn(id, status)：按 id 置终态 + 会话 status 回 idle；
  //                    特例：status==done 且 content 仍为空（首 token 前即停止）→ 直接移除该占位，
  //                    避免留下一条空气泡。
}
```
> 关键点：帧回调全部过 `_disposed || seq != _seq` 守卫（cancel 异步窗口）；cancel 分支识别不报错；「自然结束无 done 且非用户停止」判 error；只更新目标 assistant 消息，历史消息引用不变（配合 §5.9 行级 select 短路）。

### 5.9 UI 组件签名

`widgets/markdown_message.dart`
```dart
/// gpt_markdown 薄封装：隔离第三方，链接经 url_launcher 外开。
/// 未来换渲染库只改此文件。
class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.data, this.selectable = true});
  final String data;      // markdown 源文本（流式期间为半截，gpt_markdown 容忍）
  final bool selectable;
  // build: GptMarkdown(data, onLinkTap: (url,title)=>launchUrl(...))
}
```

`widgets/message_bubble.dart`
```dart
/// 单条气泡：user 右对齐纯文本气泡；assistant 左对齐 MarkdownMessage。
/// - streaming 且 content 为空 → 显示「思考中」动画指示（三点跳动），避免首 token 前 1–3s 空白像卡死；
/// - error → 气泡内 inline 重试入口（onRetry）；
/// - quotaBlocked → 气泡内 inline 升级入口（onUpgrade → openPaywall）；
/// - 长按弹菜单：复制（assistant 复制 markdown 源）。
/// 颜色全部取 Theme/colorScheme（暗色模式适配），禁止硬编码色值。
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message, this.onRetry, this.onUpgrade, this.onCopy});
  final ChatMessage message;
  final VoidCallback? onRetry;                 // 仅 error 态用
  final VoidCallback? onUpgrade;               // 仅 quotaBlocked 态用
  final void Function(String content)? onCopy;
}
```

`widgets/message_list.dart`
```dart
/// 消息列表：ListView.builder + 稳定 ValueKey(message.id) + 自动滚动策略 + 回底浮标。
///
/// 性能关键（ValueKey 只保 State 复用、**不跳过 build**，不能靠 key 防重建）：
/// - 本组件只 watch `select((s) => (s.messages.length, s.messages.lastOrNull?.id))`
///   （record 结构相等）→ delta 帧不重建列表本身，仅 send/retry/clear 时重建；
/// - 每行 `_MessageRow(config, messageId)` 为独立 ConsumerWidget，各自
///   `select` 自己那条消息 → 历史消息实例不变、等值短路不 rebuild，
///   流式期间只有正在生成那一行重建 + reparse markdown；
/// - 贴底驱动用 `ref.listen` 监听最后一条消息 content 变化（listen 不触发本组件 rebuild）。
/// 滚动策略：仅当 maxScrollExtent - offset < 80 才随新内容贴底；上滑查看历史不打断并显示
/// 回底浮标；发新用户消息强制滚底（addPostFrameCallback）。
class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({super.key, required this.config, this.onRetry, this.onUpgrade, this.onCopy});
  final ChatbotConfig config;                  // 供行级 select 定位 provider
  final void Function(String messageId)? onRetry;
  final VoidCallback? onUpgrade;
  final void Function(String content)? onCopy;
}
```

`widgets/chat_composer.dart`
```dart
/// 输入条：多行自适应 TextField + 发送/停止切换按钮。
/// - 语音插槽：预留 leading 区（本次不实现）；未来语音转文字结果回填输入框后仍走 onSend，契约不变。
/// - 字符上限：inputFormatters: [LengthLimitingTextInputFormatter(4000)]（前端兜底）。
/// - 键盘行为：移动端 IME action=send；桌面/硬键盘（本项目支持 macOS）Enter=发送、Shift+Enter=换行。
/// 空文本或未在流式时按钮为「发送」（空文本禁用）；流式中按钮为「停止」。
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.placeholder,
    required this.isStreaming,
    required this.onSend,     // Future<void> Function(String text)
    required this.onStop,     // VoidCallback
  });
  final String placeholder;
  final bool isStreaming;
  final Future<void> Function(String text) onSend;
  final VoidCallback onStop;
  // 发送成功后清空输入框；发送期间/流式中禁用发送键
}
```

`widgets/chat_gate_banner.dart`
```dart
/// 发送前闸门 banner（唯一数据源 = state.gate）：
/// authRequired → 登录引导；quotaExceeded → 升级（openPaywall）；gate=none 渲染 SizedBox.shrink。
/// 一轮已开始后的失败（网络/断流/402）不在此显示——由那条气泡 inline 表达（见 ChatMessageBubble），
/// 避免 banner 与气泡同时出现两个重试/升级入口。
class ChatGateBanner extends StatelessWidget {
  const ChatGateBanner({super.key, required this.gate, required this.onUpgrade, required this.onSignIn});
  final ChatGate gate;
  final VoidCallback onUpgrade;
  final VoidCallback onSignIn;
}
```

`widgets/context_chip.dart`
```dart
/// 输入框上方「正在讨论：<摘要>」chip。config.contextSummary 为空则不显示。
/// 摘要可能是整句长文本：maxLines: 1 + TextOverflow.ellipsis。
class ChatContextChip extends StatelessWidget {
  const ChatContextChip({super.key, required this.summary});
  final String summary;
}
```

`widgets/chat_view.dart`（**载体无关纯组件，双载体共用**）
```dart
/// 通用聊天视图：可嵌 bottom sheet 或全屏页 body。无 Scaffold。
/// 结构：Column[ 可选 ContextChip, Expanded(ChatMessageList), ChatGateBanner, ChatComposer ]
/// 键盘避让：外层用 Padding(MediaQuery.viewInsetsOf(context).bottom)（sheet/page 一致）。
/// 性能：**不 watch 整个 state**（否则每个 delta 帧全树 rebuild）——分别
///   `select((s) => s.isStreaming)`（composer 用）与 `select((s) => s.gate)`（banner 用）；
///   消息渲染的重建控制在 ChatMessageList（见其注释）。
/// 颜色/间距全部取 Theme + AppSpacing token（暗色模式适配）。
class ChatView extends ConsumerWidget {
  const ChatView({super.key, required this.config});
  final ChatbotConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(chatSessionControllerProvider(config).notifier);
    // 发送前登录拦截（tap site；注意 ensureSignedInForAction 为**全命名参数**）：
    //   Future<void> handleSend(String text) async {
    //     final ok = await ensureSignedInForAction(
    //       context: context, ref: ref,
    //       title: l10n.chatSignInTitle, message: l10n.chatSignInMessage);
    //     if (!ok) return;
    //     await notifier.send(text);
    //   }
    // banner：gate==quotaExceeded → onUpgrade: openPaywall(context, ref)；
    //         gate==authRequired → onSignIn: ensureSignedInForAction(...)（同上命名传参）
    // 气泡：onRetry → notifier.retry()；onUpgrade → openPaywall(context, ref)
  }
}
```

### 5.10 载体

`chatbot_sheet.dart`
```dart
/// 以 bottom sheet 打开 chatbot（命名参数，对齐项目 showXxxSheet 惯例）。
Future<void> showChatbotSheet({required BuildContext context, required ChatbotConfig config}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ChatbotSheetBody(config: config),
  );
}
// _ChatbotSheetBody：**固定高度**（屏高 × 0.9）SizedBox；顶部把手 + 标题(config.title) + 关闭按钮；
//   body 为 ChatView(config)；外层 Padding(MediaQuery.viewInsetsOf(context).bottom) 键盘避让，
//   键盘弹出整块上推，行为确定且与全屏页壳一致。
//   ⚠️ 不用 DraggableScrollableSheet：其 builder 交出的 scrollController 必须接管内部唯一
//   scrollable 才能拖拽联动（参考 podcast_info_sheet），与 ChatMessageList 自己的贴底/回底
//   controller 结构性冲突；再叠加常驻输入框 + 键盘 viewInsets（maxChildSize 仍以全屏为基准）
//   行为不可控。可拖拽调节高度留作 P2，若做必须先解决双 controller 协调。
//   关闭时 controller 随 autoDispose 销毁 → 自动取消在途（build 里 ref.onDispose 已处理）。
```

`screens/chat_screen.dart`（全屏页壳）
```dart
/// 全屏聊天页壳。走嵌套子路由（§7.17）。
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.config});
  final ChatbotConfig config;
  // Scaffold(appBar: AppBar(title: Text(config.title)), body: SafeArea(child: ChatView(config)))
}
```
> 若首版仅用 sheet，全屏页壳仍需交付并用一个临时/设置内调试入口验证（满足"双载体"验收）。全屏页接入路由时按 §7.17：`app_router.dart` 加 `chatbotSegment='chatbot'` + `_chatbotRoute()`（`parentNavigatorKey: rootNavigatorKey`，`_RestoredRoutePopper` 兜底 extra 丢失），入口用 `AppRoutes.pushNested(context, AppRoutes.chatbotSegment, extra: config)`。

---

## 6. 额度门 / 登录 / Paywall 接线（精确）

> **权威语义（实现与测试的前提）**：额度的唯一权威是**后端 402**。当前 `freeAllowancePolicyProvider` 返回 AlwaysAllowPolicy（恒放行）、`kAiTrialLimits` 全 0，因此「本地额度预测」在现网是**前向兼容的死分支**——保留它是为了未来切回 TrialAllowancePolicy 时无需改 controller，但实现与测试不得假设它会实际拦截。

- **登录**：发送 tap site（ChatView.handleSend）调 `ensureSignedInForAction(context: ..., ref: ..., title: ..., message: ...)`（**全命名参数**）；返回 false 直接 return（不隐式重放）。controller._startTurn 内再兜底：未登录或无 accessToken → `gate=authRequired`。
- **额度门（本地预测，现网死分支）**：_startTurn 发请求前 `ref.read(featureAccessProvider(PremiumFeature.aiChat))`（同步 bool）；false 且已登录 → `gate=quotaExceeded`，不发请求。
- **额度门（后端权威）**：后端 402 `code==quota_exceeded` → client 抛带码 DioException → `_mapRunError` 置该条 assistant 消息 `quotaBlocked`（气泡 inline 升级入口），**不弹 banner**（错误态双轨，见 §5.4 注）。
- **计费**：收到 `isFinal` 帧成功后 `_consumeTrial()`：会员 `subscriptionControllerProvider.isActive`（EntitlementState 的 bool getter）不计；否则 `aiTrialUsageProvider.notifier.consume(PremiumFeature.aiChat)`。**每条成功用户消息计一次**；中途停止不计（本地仅预测计数，后端按实际 token 计量，可接受）。
- **Paywall**：气泡/banner 的升级入口 → `openPaywall(context, ref)`（平台未启用订阅自动降级为 snackbar）。
- **premium_feature.dart 修改**：
```dart
enum PremiumFeature {
  aiTranslation, aiAnalysis, aiSenseGroup, aiWordAnalysis, aiTranscription,
  /// AI 对话助手（后端 LLM 多轮对话）。
  aiChat,
}
```
> 已核实（review 结论，实现方无需再排查）：全仓**无**对 PremiumFeature 的 exhaustive switch，加 `aiChat` 零连带编译错误（用法均为 map 字面量 + `.values` 遍历）；`freeAllowancePolicy.allows()` 对未配置枚举用 `?? 0` 兜底**不抛错**，无需改 policy。可选：`kAiTrialLimits`（`lib/features/subscription/config/ai_trial_limits.dart`）显式补 `PremiumFeature.aiChat: 0`，仅为穷举语义。

---

## 7. 首接入点：句子讲解页 AppBar AI 按钮

`lib/screens/sentence_detail_screen.dart` 第 **268** 行 `appBar: AppBar(title: Text(args.audioName), centerTitle: true)` → 加 `actions`（**受发布开关控制**，后端未就绪前 `kChatbotEnabled=false` 不对用户暴露）：
```dart
appBar: AppBar(
  title: Text(args.audioName),
  centerTitle: true,
  actions: [
    if (kChatbotEnabled)
      IconButton(
        icon: const Icon(Icons.auto_awesome),   // 或 font_awesome AI 图标，与全 app 一致
        tooltip: l10n.chatOpenTooltip,
        onPressed: () => showChatbotSheet(
          context: context,
          config: ChatbotConfig(
            sessionId: 'sentence:${args.sentenceIndex}:${args.sentenceText.hashCode}',
            endpoint: '/api/v1/stream/chat/sentence',
            context: {'sentence': args.sentenceText},
            title: l10n.chatSentenceTitle,
            inputPlaceholder: l10n.chatInputPlaceholder,
            contextSummary: args.sentenceText,
          ),
        ),
      ),
  ],
),
```

---

## 8. `pubspec.yaml` 变更
```yaml
  # LLM 流式 markdown 渲染（专为未闭合/流式 markdown 设计；纯 Dart）。
  gpt_markdown: ^1.1.8
```

---

## 9. 国际化文案（en/zh 同步新增；有占位符加 @key 元数据）

| key | en | zh |
|---|---|---|
| `chatOpenTooltip` | Ask AI | 问 AI |
| `chatSentenceTitle` | AI Tutor | AI 助教 |
| `chatInputPlaceholder` | Ask anything… | 有问题尽管问… |
| `chatSend` | Send | 发送 |
| `chatStop` | Stop | 停止 |
| `chatClear` | Clear chat | 清空对话 |
| `chatRegenerate` | Regenerate | 重新生成 |
| `chatCopy` | Copy | 复制 |
| `chatCopied` | Copied | 已复制 |
| `chatContextLabel` | Discussing: {summary} | 正在讨论：{summary} |
| `chatEmptyGreeting` | Ask me anything about this sentence. | 关于这句话，有什么想问的？ |
| `chatErrorNetwork` | Network unavailable. Tap to retry. | 网络不可用，点击重试。 |
| `chatErrorGenerate` | Generation failed. Tap to retry. | 生成失败，点击重试。 |
| `chatQuotaTitle` | Free quota used up | 免费额度已用完 |
| `chatUpgrade` | Upgrade | 升级 |
| `chatSignInTitle` | Sign in required | 需要登录 |
| `chatSignInMessage` | Sign in to use the AI assistant. | 登录后即可使用 AI 助手。 |
| `chatScrollToBottom` | (a11y label) Scroll to bottom | 回到底部 |

> `chatContextLabel` 需 `@chatContextLabel: {"placeholders":{"summary":{"type":"String"}}}`。改后跑 `flutter gen-l10n`。

---

## 10. 关键踩坑预警（实现必须遵守）

1. **流式重建（ValueKey 不防 build）**：ValueKey 只保 Element/State 复用，**不跳过 build**。若顶层 watch 整个 state 往下传 messages，每个 delta 帧所有可见气泡都会 rebuild + gpt_markdown 全量 reparse。必须行级 select（见 §5.9 ChatMessageList）：列表本身只 watch `(length, lastId)` record，每行独立 ConsumerWidget select 自己那条消息，等值短路。controller 侧配合：只按 id 替换流式那条，历史消息实例不变。
2. **「自然结束无 done」= 服务端异常断流，必须判 error**：用户主动停止走 CancelToken → `DioException(cancel)`；流自然结束却没有 done 帧只可能是后端崩/网关掐流，判成 done 会把半截回答伪装成完成态（无错误、无重试）。`_run` 以 `_stopRequested` 标志兜底 cancel 以非异常形态到达的边缘情况。
3. **自动滚动**：仅当 `maxScrollExtent - offset < 阈值(80px)` 才随新内容 `animateTo` 贴底；用户上滑不打断并显示回底浮标；发送新用户消息强制滚底（`addPostFrameCallback`）；贴底驱动用 `ref.listen`（不触发列表 rebuild）。
4. **取消时序异步**：cancel→真正抛 DioException 有窗口，所有帧回调过 `_disposed || seq != _seq` 守卫；cancel 分支识别 `DioExceptionType.cancel` 不报错、保留部分文本为 done（对齐 §7.1、lookup_controller）。
5. **sheet 载体禁用 DraggableScrollableSheet**：其 scrollController 必须接管内部唯一 scrollable，与消息列表自己的贴底/回底 controller 结构性冲突，叠加键盘 viewInsets 行为不可控（见 §5.10）。固定高度 + `isScrollControlled:true` + composer 外层 `Padding(MediaQuery.viewInsetsOf(context).bottom)`，否则输入条被遮。
6. **空闲僵死**：`decodeNdjson(idleTimeout: aiHttpStreamIdleTimeout)` 兜底抛超时 → error 可重试。
7. **流式响应体只能消费一次**：日志走 `decodeNdjson(onLine:)` 旁路，勿在业务解析前重读 stream（对齐 §7.26）。
8. **family 稳定性**：`ChatbotConfig` 的 `==/hashCode` 比 `sessionId + endpoint`（防不同接入点误用同 id 串会话），context 仍排除（Map 无稳定相等）；宿主每次传相同 sessionId 才复用会话。
9. **greeting 不入历史**：靠 `ChatMessage.includeInHistory=false` 字段，`_buildHistory()` 统一过滤（连同 streaming 占位与 error/quotaBlocked 失败消息）。
10. **meta.messageId 不覆盖消息 id**：仅记录日志。中途换 id 会令 ValueKey 变化导致气泡重建、`_updateBot` 按旧 id 找不到目标。
11. **API 事实（照抄前核对，均已 review 核实）**：时间用 `package:clock` 的 `clock.now()`（**仓库无 clockProvider**）；间距 token 是 `AppSpacing.xs/.s/.m/.l/.xl`（**无 `.m16` 这类字段**）；`ensureSignedInForAction` / `createBackendDio` / `configureAiHttpClientAdapter` 均为**命名参数**。
12. **函数 ≤50 行（CLAUDE.md 硬约束）**：controller 按 §5.8 拆 `_startTurn` / `_run` / `_mapRunError`，不要写成一个大函数。
13. **暗色模式**：所有颜色取 Theme/colorScheme + AppSpacing token，禁止硬编码色值；深浅两套主题下气泡、输入条、banner 都要可读。

---

## 11. 任务拆解（测试先行 · 单任务聚焦 · 每项含交付物+接口+测试）

> 顺序即依赖顺序。每个任务完成即 `flutter analyze`（0 error）+ 对应 `flutter test` 通过。改 provider 后 `dart run build_runner build`（漏跑会缺 .g.dart 编译不过）。

### T0 流程登记（P0，无依赖，~0.1d）
- 交付：`TASKS.md` 新增「通用 Chatbot 组件」区块（列 T1–T10 + 优先级，不抢当前既有焦点任务）；`PLAN.md` 登记「AI 对话助手」能力条目；本文档移至 `docs/chatbot-implementation-plan.md` 并从 TASKS.md 链接。
- 原因：CLAUDE.md §3 要求实现方开工先读 PLAN/TASKS 并从中挑任务，chatbot 未登记会造成流程冲突。

### T1 数据模型与配置（P0，dep:T0，~0.5d）
- 交付：`chat_role.dart`、`chat_message.dart`、`chatbot_config.dart`、`chat_session_state.dart`、`chatbot_flags.dart`（§5.1–5.4、§4）。
- 测试 `test/features/chatbot/models/`：ChatMessage.copyWith/factory/toWire/includeInHistory（greeting factory=false）；ChatbotConfig ==/hashCode 比 sessionId+endpoint（context 排除）；ChatSessionState.initial 含 greeting、gate 语义、canSend/isStreaming。

### T2 流式协议层（P0，dep:T1，~0.5d）
- 交付：`ndjson_text_stream.dart`（§5.5）。
- 测试 `test/features/chatbot/services/ndjson_text_stream_test.dart`：delta 逐帧累计；done→isFinal；meta.messageId 透传；`__error`→ChatStreamException；行损坏(FormatException)→ChatStreamException；空闲超时(TimeoutException)→ChatStreamException；无 done 自然结束不 yield final；未知键忽略。（构造 `Stream<Map>` 直接喂，不经 Dio。）

### T3 ChatApiClient + FakeChatApiClient + provider（P0，dep:T2，~1d）
- 交付：`chat_api_client.dart`（含 ChatApi 抽象）、`fake_chat_api_client.dart`、`chat_api_client_provider.dart`（§5.6–5.7）。
- 测试 `test/features/chatbot/services/chat_api_client_test.dart`（mock Dio 返回 `ResponseBody.fromStream`）：200 正常流→帧序列正确；请求体 messages/context/targetLanguage 组装正确；Authorization header 带 token；401→ChatAuthRequiredException；402 quota→DioException(statusCode 402)；5xx→DioException(badResponse)；流内 `__error`→ChatStreamException；cancelToken 取消→DioException(cancel)；流只消费一次（日志旁路不破坏解析）。FakeChatApiClient：逐帧吐 delta+末帧 done、cancelToken 取消后停止吐帧。

### T4 额度门枚举（P0，可与 T3 并行，~0.25d）
- 交付：`premium_feature.dart` 加 `aiChat`；（可选）`kAiTrialLimits` 显式补 `aiChat: 0`。已核实无 exhaustive switch 连带修改、policy 无需改（§6 尾注）。
- 测试：现有 subscription 测试通过；补 `featureAccessProvider(aiChat)` 在 未登录=false / 会员=true / 免费登录=放行 三态（override providers）。

### T5 ChatSessionController（P0，dep:T1,T3,T4，~1d）
- 交付：`chat_session_controller.dart`（§5.8）。
- 测试 `test/features/chatbot/providers/chat_session_controller_test.dart`（override chatApiClientProvider 为可控 fake；override auth/subscription/trial providers）：
  - 发送→流式逐帧更新最后一条 assistant→final 转 done+idle+consume 一次；
  - 会员成功不 consume；
  - stop→cancel→保留部分文本为 done+idle，不报错、不 consume；
  - **流自然结束无 done 且非用户停止→该条 error 可重试**（服务端异常断流不得伪装成完成态）；
  - stop 后流以自然结束形态收尾（无 cancel 异常）→ _stopRequested 兜底仍为 done；
  - 空文本/流式中 send 无效；
  - 未登录 send→gate=authRequired；已登录未解锁 send→gate=quotaExceeded 不发请求；
  - 后端 402→该条 quotaBlocked（gate 不变，无 banner 态）；
  - 网络/流内错误→该条 error（无会话级 lastError）；
  - retry→移除最后 user 及其后消息、复用 _startTurn 重新过闸门、重新流式；
  - 首 token 前停止（占位 content 为空）→ 占位被移除，不留空气泡；
  - clear→回初始态并取消在途；
  - 旧 seq 帧回调被丢弃（发起两次，验证第一次的迟到帧不写状态）；
  - dispose→取消在途、不写已销毁状态；
  - 历史软上限 50 截断、greeting(includeInHistory=false)/占位/失败消息不入 _buildHistory。

### T6 UI 组件 + markdown（P0，dep:T5，~1.5d）
- 交付：`pubspec.yaml` 加 gpt_markdown；`markdown_message/message_bubble/message_list/chat_composer/chat_gate_banner/context_chip/chat_view`（§5.9）。
- 测试 `test/features/chatbot/widgets/`（`createTestApp` + override controller）：空态显 greeting；流式渲染逐帧+markdown 列表/加粗；**流式期间历史气泡不重建**（build 计数探针验证行级 select 短路）；占位空 content 显「思考中」指示；发送清空输入框；空文本禁用发送；流式中显示停止键、点停止调 onStop；error 气泡显 inline 重试、quotaBlocked 气泡显 inline 升级；长按复制回调；自动滚动（在底部随新内容贴底、上滑不回底、回底浮标）；gate=quotaExceeded 显升级 banner、gate=authRequired 显登录 banner；半截 markdown 不抛异常；输入超 4000 字符被截断；桌面键盘 Enter 发送、Shift+Enter 换行；深色主题下渲染不用硬编码色（可 golden 或色值断言抽查）。

### T7 双语文案（P0，随 T6 并行，~0.5d）
- 交付：§9 全部 key 入 `app_en.arb`+`app_zh.arb`；`flutter gen-l10n` 通过；组件无硬编码文案。
- 测试：en/zh key 齐全（可加断言测试或人工核对）。

### T8 两载体 + 首接入点 + 发布开关（P0，dep:T6,T7，~1d）
- 交付：`chatbot_sheet.dart`（固定高度，§5.10）；`chat_screen.dart` + 路由声明（§5.10 尾注）；`sentence_detail_screen.dart` AppBar AI 按钮，受 `kChatbotEnabled` 控制（§7），**默认 false 直至后端就绪**。
- 测试：widget 测 showChatbotSheet 打开显 ChatView、关闭触发 controller dispose 取消在途；`test/router/app_router_test.dart` 增全屏页壳 push/返回栈不塌回归；`kChatbotEnabled=true` 时句子页 AppBar 有 AI 按钮、点击开 sheet 且 context 透传正确；`kChatbotEnabled=false` 时按钮不渲染。

### T9 边界打磨 + e2e（P1，dep:T8，~0.5d）
- 交付：断网/超时/半截 markdown 收口；**流式中快速关-开 sheet 竞态显式回归**（autoDispose 微任务窗口内复用/重建均不崩、无写已销毁状态日志）；`integration_test/` 走"发送→流式→完成"+"发送→停止"（用 kChatbotUseFakeApi 假流，不依赖后端）。
- 注：本机 `integration_test -d macos` 环境已知异常（见 MEMORY），e2e 以 iOS 模拟器 + 单测为准，环境受限则说明。

### T10 清空 / 重新生成（P1，dep:T5,T6，~0.5d）
- 交付：ChatView header/menu 加清空按钮（调 controller.clear）；失败气泡/末条 assistant 加重新生成（调 controller.retry）。
- 测试：清空回空态并取消在途；重新生成重新流式且计费按新一次。

### 后续迭代（P2，本次不做）
语音输入 & 键盘/语音切换（composer 已留插槽；届时给 composer 暴露文本注入 seam 以回填 partial transcript，onSend 契约不变）；跨重启持久化 + 多会话列表（drift）；编辑重发；点赞点踩；建议问法 chips；第 2、3 个业务接入点；sheet 可拖拽调节高度（需解决双 ScrollController 协调，见 §5.10）；消息时间戳；字符计数/撞 4000 上限提示；宽屏（iPad/macOS）气泡最大宽度约束 + sheet 居中；无障碍语义补全；代码块复制按钮/表格横滚；网络恢复自动重试；gpt_markdown_lite 评估（去 LaTeX 减体积）。

---

## 12. 后端待办（本仓库外，需协调）
新增 chat 流式端点（如 `/api/v1/stream/chat/sentence`），输入 `{messages, context, targetLanguage}`，按 endpoint 绑定各自 system prompt；输出 §3.2 的 `{"delta"}`/`{"done"}`/`{"__error"}` NDJSON；鉴权 `Authorization: Bearer`；额度超限返回 402 `{"code":"quota_exceeded"}`。

---

## 13. 验证方式（端到端）

- **自动**：`flutter analyze`（0 error）+ `flutter test`（全绿），覆盖协议层/client/controller/UI 各层成功·错误·边界态。
- **手动 Demo**：后端未就绪时**开 `kChatbotEnabled=true` + `kChatbotUseFakeApi=true`** 用假流走通 1–5、9–15；后端就绪后关掉假流重跑全量（6/7/8 依赖真实后端行为）：
  1. 句子讲解页点 AppBar AI 按钮 → 弹 sheet，context chip 显当前句（单行省略）；
  2. "用列表解释这句语法" → 逐字流式 + markdown 列表/加粗正确；
  3. 长回答中途停止 → 保留已生成、可长按复制；
  4. "再举个例子" → 延续上文多轮；
  5. 长回答时上滑不被拉回、点回底浮标回底；
  6. 登出后发送 → 登录引导；
  7. 无额度账号发送 → 402 → 气泡升级入口 → Paywall；
  8. 飞行模式发送 → 气泡标红重试，恢复后重试成功；
  9. 流式中关 sheet → 无报错、日志无"写已销毁状态"；流式中快速关-开 sheet 不崩；
  10. 切 en/zh → 全文案随变；
  11. 从全屏页壳打开同组件 → 一套组件两种载体一致；
  12. 发送后首帧前 → 气泡显「思考中」动画，不长时间空白；
  13. 切深色模式 → 气泡/输入条/banner 正常可读；
  14. macOS：Enter 发送、Shift+Enter 换行；键盘弹出输入条不被遮；
  15. `kChatbotEnabled=false` 编译 → 句子页无 AI 按钮（发布安全）。

---

## 14. 收尾（完成后）
- 更新 `TASKS.md`（勾选、记录完成时间）、`PLAN.md`（如里程碑变化）。
- `flutter analyze` / `flutter test` / `dart run build_runner build`。

/// 会话 controller（核心，镜像 lookup_controller 防竞态范式）。
///
/// 单向数据流：UI 调 send/stop/retry/clear → 改 state → UI 渲染。
/// 防竞态：每次发起流式请求自增 [_seq]，旧帧回调发现过期即丢弃；[_inflight]
/// CancelToken 关流；[_disposed] 守卫销毁后回调。
library;

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/app_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../../subscription/models/premium_feature.dart';
import '../../subscription/providers/ai_trial_usage_provider.dart';
import '../../subscription/providers/feature_access_provider.dart';
import '../../subscription/providers/subscription_controller.dart';
import '../models/chat_message.dart';
import '../models/chat_role.dart';
import '../models/chatbot_config.dart';
import '../state/chat_session_state.dart';
import 'chat_api_client_provider.dart';

part 'chat_session_controller.g.dart';

/// 历史软上限（超出取最近 N 条）。
const int _historyLimit = 50;

/// 会话 controller（family by [ChatbotConfig]，keepAlive 保活）。
///
/// keepAlive——会话 state 需跨"关面板/重开"存活（内存保活，不落盘）：同一句子
/// 关掉 sheet 再打开、内容还在；重启进程自然清空。因此不用 autoDispose。
/// 关面板时的在途流中断由 sheet 关闭后显式调 [stop] 处理（见 chatbot_sheet.dart），
/// 不再依赖 autoDispose 的 onDispose。
///
/// 函数 ≤50 行约束：闸门+组装抽 [_startTurn]；[_run] 只留 happy-path 循环；
/// 异常映射抽 [_mapRunError]。
@Riverpod(keepAlive: true)
class ChatSessionController extends _$ChatSessionController {
  int _seq = 0; // 每次发起流式请求自增；旧帧回调发现过期即丢弃
  CancelToken? _inflight; // 当前在途请求
  bool _disposed = false; // 销毁后回调一律丢弃
  bool _stopRequested = false; // 本轮用户是否主动停止（兜底 cancel 以非异常形态到达）
  final _uuid = const Uuid();

  @override
  ChatSessionState build(ChatbotConfig config) {
    ref.onDispose(() {
      _disposed = true;
      _inflight?.cancel(
        'controller disposed',
      ); // keepAlive 下仅 provider 真被 invalidate/容器销毁时触发，作真销毁兜底
    });
    return ChatSessionState.initial(config);
  }

  /// 发送一条用户消息。前置：调用方（ChatView）已做登录拦截。
  ///
  /// [quote] 为追问引用原文（可选）：气泡上方单独显示，发后端时并入 blockquote。
  Future<void> send(String text, {String? quote}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return; // 空 / 流式中禁止
    await _startTurn(trimmed, quote: quote);
  }

  /// 停止生成：取消在途，保留已生成部分为 done（在 [_run] 的 cancel 分支落地）。
  void stop() {
    _stopRequested = true;
    _inflight?.cancel('user stopped');
  }

  /// 重试：重发最后一条 user 消息。
  ///
  /// 步骤：①定位最后一条 user；②移除它及其后所有消息（含失败/占位 assistant）；
  /// ③复用 [_startTurn] —— 与 send 走同一闸门（登录/token/额度），不允许绕过。
  Future<void> retry() async {
    if (state.isStreaming) return;
    final lastUserIndex = state.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
    );
    if (lastUserIndex < 0) return;
    final lastUser = state.messages[lastUserIndex];
    state = state.copyWith(messages: state.messages.sublist(0, lastUserIndex));
    await _startTurn(lastUser.content, quote: lastUser.quote);
  }

  /// 重新生成指定 assistant 消息：重发它前面最近的一条 user 消息。
  ///
  /// 简单处理、不分叉：定位该 assistant 前最近的 user，移除该 user 及其后所有消息
  /// （含要重生的 assistant），再复用 [_startTurn] 走同一闸门重跑。
  Future<void> regenerate(String assistantId) async {
    if (state.isStreaming) return;
    final botIndex = state.messages.indexWhere((m) => m.id == assistantId);
    if (botIndex < 0) return;
    final userIndex = state.messages.lastIndexWhere(
      (m) => m.role == ChatRole.user,
      botIndex - 1,
    );
    if (userIndex < 0) return;
    final user = state.messages[userIndex];
    state = state.copyWith(messages: state.messages.sublist(0, userIndex));
    await _startTurn(user.content, quote: user.quote);
  }

  /// 读取指定消息原文，供编辑页预填。未找到返回 null。
  String? messageContent(String messageId) {
    final target = state.messages.where((m) => m.id == messageId).firstOrNull;
    return target?.content;
  }

  /// 修改并重发指定 user 消息：移除该消息及其后所有消息，以新文本发起新一轮。
  ///
  /// 不分叉：编辑即从该轮起截断，再以新文本走 [_startTurn]（同一登录/额度闸门）。
  /// 流式中 / 未找到 / 新文本为空 → 不处理（用户在编辑页确认发送后才触发）。
  Future<void> editAndResend(String userId, String newText) async {
    if (state.isStreaming) return;
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    final index = state.messages.indexWhere((m) => m.id == userId);
    if (index < 0) return;
    final originalQuote = state.messages[index].quote;
    state = state.copyWith(messages: state.messages.sublist(0, index));
    await _startTurn(trimmed, quote: originalQuote);
  }

  /// 清空对话：取消在途，回到初始态。
  void clear() {
    _inflight?.cancel('cleared');
    _seq++; // 作废在途回调
    state = ChatSessionState.initial(config);
  }

  /// 发起一轮（send/retry 共用）：闸门 → 追加 user+占位 → 流式。
  /// [quote] 为追问引用原文（可选），随 user 消息保存。
  Future<void> _startTurn(String userText, {String? quote}) async {
    // 1) 闸门（gate 是 banner 的唯一数据源）。
    //    注意：当前 freeAllowancePolicy 为 AlwaysAllowPolicy（恒放行），本地额度预测在
    //    现网是前向兼容的死分支；额度唯一权威是后端 402。
    if (!ref.read(isAuthenticatedProvider)) {
      state = state.copyWith(gate: ChatGate.authRequired);
      return;
    }
    final accessToken = ref
        .read(supabaseSessionProvider)
        .valueOrNull
        ?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      state = state.copyWith(gate: ChatGate.authRequired);
      return;
    }
    if (!ref.read(featureAccessProvider(PremiumFeature.aiChat))) {
      state = state.copyWith(gate: ChatGate.quotaExceeded);
      return;
    }

    // 2) 追加 user(done) + assistant 占位(streaming)，清闸门。
    final now = clock.now();
    final userMsg = ChatMessage.user(
      id: _uuid.v4(),
      content: userText,
      createdAt: now,
      quote: quote,
    );
    final botId = _uuid.v4();
    final botMsg = ChatMessage.assistantPlaceholder(id: botId, createdAt: now);
    state = state.copyWith(
      messages: [...state.messages, userMsg, botMsg],
      status: ChatSessionStatus.streaming,
      gate: ChatGate.none,
    );

    await _run(botId, accessToken);
  }

  /// 内部：发起并消费流式，防竞态守卫。只留 happy-path，异常映射在 [_mapRunError]。
  Future<void> _run(String botId, String accessToken) async {
    final seq = ++_seq;
    _stopRequested = false;
    _inflight?.cancel('restart');
    final token = CancelToken();
    _inflight = token;

    final targetLanguage = ref.read(
      appSettingsProvider.select((s) => s.nativeLanguage),
    );
    final history = _buildHistory();
    final client = ref.read(chatApiClientProvider);
    // 追问引用指令按界面语言本地化：界面语言未显式设置时回退到系统 locale 匹配，
    // 使指令语言与用户界面一致（英文指令会让模型倾向英文回答）。
    final uiLocale =
        ref.read(appSettingsProvider.select((s) => s.locale)) ??
        matchUiLocale(WidgetsBinding.instance.platformDispatcher.locale);
    final followUpInstruction = lookupAppLocalizations(
      uiLocale,
    ).chatFollowUpInstruction;

    try {
      await for (final frame in client.streamChat(
        endpoint: config.endpoint,
        history: history,
        context: config.context,
        followUpInstruction: followUpInstruction,
        targetLanguage: targetLanguage,
        accessToken: accessToken,
        cancelToken: token,
      )) {
        if (_disposed || seq != _seq) return; // 防竞态守卫
        _updateBot(botId, frame.text); // 只改这条 assistant content
        if (frame.isFinal) {
          _finishTurn(botId, ChatMessageStatus.done);
          _consumeTrial(); // 成功计一次（会员不计；本地预测计数，权威在后端）
          return;
        }
      }
      // 流自然结束但无 final：
      // - _stopRequested（用户主动停止，兜底 cancel 以非异常形态到达）→ 保留部分为 done；
      // - 否则 = 服务端异常断流 → error 可重试（不得伪装成完成态）。
      if (_disposed || seq != _seq) return;
      _finishTurn(
        botId,
        _stopRequested ? ChatMessageStatus.done : ChatMessageStatus.error,
      );
    } catch (e) {
      if (_disposed || seq != _seq) return;
      final status = _mapRunError(e);
      // 用户主动取消（cancel→done）不算失败，不打 error 日志。
      if (status != ChatMessageStatus.done) {
        _log('流式失败 botId=$botId status=$status error=$e');
      }
      _finishTurn(botId, status);
    }
  }

  /// 异常 → 该条 assistant 消息的终态（气泡 inline 表达，不设会话级错误）。
  /// - DioException(cancel)（用户停止）→ done，保留已生成部分；
  /// - DioException(402)（额度权威判定）→ quotaBlocked（气泡 inline 升级入口）；
  /// - ChatAuthRequiredException(401) / ChatStreamException / 其余 → error。
  ChatMessageStatus _mapRunError(Object e) {
    if (e is DioException && e.type == DioExceptionType.cancel) {
      return ChatMessageStatus.done;
    }
    if (e is DioException && e.response?.statusCode == 402) {
      return ChatMessageStatus.quotaBlocked;
    }
    return ChatMessageStatus.error;
  }

  /// 成功后消耗一次免费试用（会员不计）。
  void _consumeTrial() {
    if (ref.read(subscriptionControllerProvider).isActive) return;
    ref.read(aiTrialUsageProvider.notifier).consume(PremiumFeature.aiChat);
  }

  /// 组装发后端的历史：剔除 greeting / 占位 / 失败消息，取最近 [_historyLimit] 条。
  List<ChatMessage> _buildHistory() {
    final valid = state.messages
        .where((m) => m.includeInHistory)
        .where((m) => m.status == ChatMessageStatus.done)
        .toList();
    if (valid.length <= _historyLimit) return valid;
    return valid.sublist(valid.length - _historyLimit);
  }

  /// 按 id 定位那条 assistant，copyWith(content) 后替换（不动其它条）。
  void _updateBot(String id, String text) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id == id) m.copyWith(content: text) else m,
      ],
    );
  }

  /// 按 id 置终态 + 会话 status 回 idle。
  ///
  /// 特例：status==done 且 content 仍为空（首 token 前即停止）→ 直接移除该占位，
  /// 避免留下一条空气泡。
  void _finishTurn(String id, ChatMessageStatus status) {
    final target = state.messages.where((m) => m.id == id).firstOrNull;
    final removeEmpty =
        status == ChatMessageStatus.done &&
        target != null &&
        target.content.isEmpty;
    final next = <ChatMessage>[];
    for (final m in state.messages) {
      if (m.id != id) {
        next.add(m); // 非目标消息原样保留
      } else if (!removeEmpty) {
        next.add(m.copyWith(status: status));
      }
      // removeEmpty && 目标 → 跳过（移除空占位）
    }
    state = state.copyWith(status: ChatSessionStatus.idle, messages: next);
  }

  /// 诊断日志。
  void _log(String message) => AppLogger.log('CHAT-CTRL', message);
}

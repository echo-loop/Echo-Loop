/// 会话运行态（单一数据源）。
library;

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/chatbot_config.dart';

/// 会话整体运行态。
/// - [idle]：可发送。
/// - [streaming]：正在生成（禁止再次发送）。
enum ChatSessionStatus { idle, streaming }

/// 发送前闸门态（ChatGateBanner 的唯一数据源）。
///
/// 一轮已开始后的失败不走这里，只落在那条 assistant 消息的 status 上
/// （气泡 inline 重试 / 升级）。
enum ChatGate { none, authRequired, quotaExceeded }

/// 会话运行态（单一数据源）。State 可含 Model。
@immutable
class ChatSessionState {
  /// 展示用完整列表（含 greeting）。
  final List<ChatMessage> messages;

  /// 会话状态。
  final ChatSessionStatus status;

  /// 发送前闸门：需登录 / 额度超限（本地预测）。
  final ChatGate gate;

  const ChatSessionState({
    required this.messages,
    required this.status,
    this.gate = ChatGate.none,
  });

  /// 初始态：若 config.greeting 非空，插入一条 [ChatMessage.greeting] 开场白。
  factory ChatSessionState.initial(ChatbotConfig config) {
    final greeting = config.greeting;
    final messages = <ChatMessage>[
      if (greeting != null && greeting.isNotEmpty)
        ChatMessage.greeting(
          // 固定 id：初始态无副作用、不依赖时间/随机源，便于测试稳定断言。
          id: 'greeting',
          content: greeting,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
    return ChatSessionState(messages: messages, status: ChatSessionStatus.idle);
  }

  ChatSessionState copyWith({
    List<ChatMessage>? messages,
    ChatSessionStatus? status,
    ChatGate? gate,
  }) => ChatSessionState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    gate: gate ?? this.gate,
  );

  bool get isStreaming => status == ChatSessionStatus.streaming;

  bool get canSend => status != ChatSessionStatus.streaming;
}

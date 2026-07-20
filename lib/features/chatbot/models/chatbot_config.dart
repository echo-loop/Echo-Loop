/// Chatbot 可插拔配置。
library;

import 'package:flutter/foundation.dart';

/// 可插拔配置：驱动同一套组件在不同位置表现不同。
///
/// == / hashCode 比 sessionId + endpoint —— context（Map 无稳定相等）排除，避免
/// rebuild 时新建 map 实例误重建 controller；endpoint 纳入相等性，防止两个接入点
/// 误用同 sessionId 时静默串到第一个 controller 的后端（family 身份键完整性）。
@immutable
class ChatbotConfig {
  /// family 身份键，每接入点稳定唯一，如 `'sentence:$hash'`。
  final String sessionId;

  /// 后端 path，不同 endpoint = 不同 system prompt。
  final String endpoint;

  /// 业务 context，随请求体发；一次会话内固定。
  final Map<String, Object?> context;

  /// 载体标题。
  final String title;

  /// 输入框 placeholder。
  final String inputPlaceholder;

  /// 可选开场白（作 assistant 首条 done 消息展示，不入 messages 历史发后端）。
  final String? greeting;

  /// 可选，上下文 chip 显示文本（如句子摘要）。
  final String? contextSummary;

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
      other is ChatbotConfig &&
      other.sessionId == sessionId &&
      other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(sessionId, endpoint);
}

/// 单条聊天消息模型。
library;

import 'package:flutter/foundation.dart';

import '../follow_up.dart';
import 'chat_role.dart';

/// 单条消息状态。
/// - [streaming]：assistant 正在流式接收（content 随帧增长；content 为空时
///   UI 显示「思考中」动画指示）。
/// - [done]：已完成（user 消息发出即 done；assistant 收到 done 帧或被用户主动停止后）。
/// - [error]：生成失败（网络 / 服务端 / 流内错误 / 异常断流），气泡 inline 重试。
/// - [quotaBlocked]：额度超限（后端 402），气泡 inline 升级入口。
enum ChatMessageStatus { streaming, done, error, quotaBlocked }

/// 不可变消息模型。Model 不依赖 State。
@immutable
class ChatMessage {
  /// 客户端生成（uuid v4），全生命周期不变。
  ///
  /// meta.messageId 仅记录日志，v1 不覆盖 id——中途换 id 会令 ValueKey 变化导致
  /// 气泡重建、`_updateBot` 按旧 id 找不到目标。
  final String id;

  /// 消息角色。
  final ChatRole role;

  /// 累计文本，流式期间随帧增长。
  final String content;

  /// 消息状态。
  final ChatMessageStatus status;

  /// 创建时间。
  final DateTime createdAt;

  /// false = 仅展示、不发后端（greeting 用）。
  final bool includeInHistory;

  /// 追问引用的被引用原文（仅 user 消息可能有；null = 无引用）。
  ///
  /// 显示层在气泡上方单独渲染为「↳ + 灰字」引用行；发后端时经 [toWire] 并入
  /// content（blockquote），因此气泡可见文本（[content]）保持为纯问题。
  final String? quote;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
    this.includeInHistory = true,
    this.quote,
  });

  /// 构造一条已发出的用户消息（status=done）。[quote] 为追问引用原文（可选）。
  factory ChatMessage.user({
    required String id,
    required String content,
    required DateTime createdAt,
    String? quote,
  }) => ChatMessage(
    id: id,
    role: ChatRole.user,
    content: content,
    status: ChatMessageStatus.done,
    createdAt: createdAt,
    quote: quote,
  );

  /// 构造一条空的 assistant 占位（status=streaming，content=''）。
  factory ChatMessage.assistantPlaceholder({
    required String id,
    required DateTime createdAt,
  }) => ChatMessage(
    id: id,
    role: ChatRole.assistant,
    content: '',
    status: ChatMessageStatus.streaming,
    createdAt: createdAt,
  );

  /// 构造开场白（status=done，includeInHistory=false，不发后端）。
  factory ChatMessage.greeting({
    required String id,
    required String content,
    required DateTime createdAt,
  }) => ChatMessage(
    id: id,
    role: ChatRole.assistant,
    content: content,
    status: ChatMessageStatus.done,
    createdAt: createdAt,
    includeInHistory: false,
  );

  /// 复制并覆盖 content / status（其余字段不可变，quote 原样保留）。
  ChatMessage copyWith({String? content, ChatMessageStatus? status}) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        status: status ?? this.status,
        createdAt: createdAt,
        includeInHistory: includeInHistory,
        quote: quote,
      );

  /// 序列化为后端历史条目（仅 role/content）。
  ///
  /// 有 [quote] 时把引用并入 content（指令 + `<quote>` 标签 + 问题），让模型看到被
  /// 追问的原文并基于它作答；显示层不受影响（气泡仍只用纯 [content]）。
  ///
  /// [instruction]：追问引用的显式指令（本地化文案，按界面语言传入）。
  Map<String, Object?> toWire({required String instruction}) => {
    'role': role.name,
    'content': quote == null
        ? content
        : composeFollowUp(content, quote!, instruction: instruction),
  };
}

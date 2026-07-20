/// 聊天 NDJSON 文本累积层。
///
/// 把 [decodeNdjson] 输出的逐行 JSON 事件流累积为「逐帧累计全文」流：
/// {"delta":"..."} 追加 / {"done":true} 结束 / {"__error":..} 抛错 /
/// {"meta":{"messageId":..}} 记录 id / 未知键忽略。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// 聊天流式帧：累计全文快照 + 是否末帧。
@immutable
class ChatTextFrame {
  /// 到当前为止的累计全文。
  final String text;

  /// 仅收到 {"done":true} 的末帧为 true。
  final bool isFinal;

  /// 来自 meta.messageId，可为 null。
  final String? messageId;

  const ChatTextFrame({
    required this.text,
    required this.isFinal,
    this.messageId,
  });
}

/// 流内错误（{"__error":..} / 行损坏 / 空闲超时）。
class ChatStreamException implements Exception {
  const ChatStreamException();

  @override
  String toString() => 'ChatStreamException';
}

/// 把 NDJSON 事件流累积为「逐帧累计全文」流。
///
/// 复用 [decodeNdjson] 的输出。纯函数、无状态、不感知取消（取消由上游关流使流
/// 自然结束）。
///
/// 协议：{"delta":"..."} 追加 / {"done":true} 结束 / {"__error":..} 抛错 /
///       {"meta":{"messageId":..}} 记录 id / 未知键忽略。
Stream<ChatTextFrame> accumulateNdjsonText(
  Stream<Map<String, dynamic>> events,
) async* {
  final buffer = StringBuffer();
  String? messageId;
  try {
    await for (final ev in events) {
      if (ev.containsKey('__error')) throw const ChatStreamException();
      if (ev['done'] == true) {
        yield ChatTextFrame(
          text: buffer.toString(),
          isFinal: true,
          messageId: messageId,
        );
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
        yield ChatTextFrame(
          text: buffer.toString(),
          isFinal: false,
          messageId: messageId,
        );
      }
      // 未知帧忽略（前向兼容）。
    }
    // 流自然结束但未收到 done：不 yield final。
    // 语义注意：用户主动取消走 CancelToken → DioException(cancel)，不会以自然结束
    // 形态到达；自然结束却无 done = 服务端异常断流，消费方（controller）必须判
    // error，不得当成完成态。
  } on FormatException {
    throw const ChatStreamException();
  } on TimeoutException {
    throw const ChatStreamException();
  }
}

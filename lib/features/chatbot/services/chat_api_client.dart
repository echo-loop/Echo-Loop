/// 通用聊天流式 API 客户端。
///
/// 对齐 [SentenceAiApiClient] 写法：`ResponseType.stream` + `validateStatus:(_)=>true`
/// 手动读错误体 + NDJSON 逐帧累积。真实实现 [ChatApiClient] 与 debug 假实现
/// [FakeChatApiClient] 共用 [ChatApi] 抽象，provider 按 kChatbotUseFakeApi 切换。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../analytics/geo_interceptor.dart';
import '../../../services/ai_http_client_adapter.dart';
import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../../../services/ndjson_stream.dart';
import '../models/chat_message.dart';
import 'ndjson_text_stream.dart';

/// 请求聊天但未登录 / token 失效（HTTP 401）。
class ChatAuthRequiredException implements Exception {
  const ChatAuthRequiredException();

  @override
  String toString() => 'ChatAuthRequiredException';
}

/// 聊天流式 API 抽象。
///
/// 真实实现 [ChatApiClient] 与 debug 假实现 FakeChatApiClient 共用，
/// provider 按 kChatbotUseFakeApi 切换；测试直接 override provider。
abstract interface class ChatApi {
  /// 发起一轮聊天，逐帧 yield 累计全文。
  ///
  /// [followUpInstruction]：追问引用的显式指令（本地化文案，按界面语言传入），
  /// 用于把带引用的消息拼成 `指令 + <quote>…</quote> + 问题`。
  Stream<ChatTextFrame> streamChat({
    required String endpoint,
    required List<ChatMessage> history,
    required Map<String, Object?> context,
    required String followUpInstruction,
    String? targetLanguage,
    required String accessToken,
    CancelToken? cancelToken,
  });

  /// 释放资源。
  void dispose();
}

/// 通用聊天流式 API 客户端。
class ChatApiClient implements ChatApi {
  final Dio _dio;
  final void Function(String message) _streamLogPrint;

  /// [appVersion] 随请求以 `x-app-version` 上报（版本灰度预留），可为 null。
  ChatApiClient({
    required String baseUrl,
    String? appVersion,
    bool http2Enabled = aiHttp2EnabledByDefault,
    void Function(String message)? streamLogPrint,
  }) : _dio = createBackendDio(
         baseUrl: baseUrl,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'CHAT-API',
       ),
       _streamLogPrint =
           streamLogPrint ?? ((message) => AppLogger.log('CHAT-API', message)) {
    configureAiHttpClientAdapter(
      _dio,
      baseUrl: baseUrl,
      http2Enabled: http2Enabled,
    );
    // 异步添加 GeoInterceptor（SharedPreferences 在 main() 中已初始化）。
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
  }

  /// 测试用：注入 Dio。
  ChatApiClient.withDio(
    this._dio, {
    void Function(String message)? streamLogPrint,
  }) : _streamLogPrint =
           streamLogPrint ?? ((message) => AppLogger.log('CHAT-API', message));

  /// 请求公共 headers（仅测试用）。
  @visibleForTesting
  Map<String, dynamic> get defaultHeaders => _dio.options.headers;

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
    final response = await _dio.post<ResponseBody>(
      endpoint,
      data: {
        'messages': history
            .map((m) => m.toWire(instruction: followUpInstruction))
            .toList(),
        if (context.isNotEmpty) 'context': context,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      },
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    if (status != 200) {
      yield* _handleNon200(body, status, response);
      return;
    }

    // 200：NDJSON 逐帧累积；日志走 decodeNdjson(onLine:) 旁路，不重复消费流。
    final frames = accumulateNdjsonText(
      decodeNdjson(
        body.stream,
        idleTimeout: aiHttpStreamIdleTimeout,
        onLine: (line) => _streamLogPrint(
          '  流式响应帧 ${response.requestOptions.uri}: ${_truncate(line)}',
        ),
      ),
    );
    yield* frames;
  }

  /// 非 200：手动读小 JSON 错误体并映射为对应异常。
  ///
  /// 401 → [ChatAuthRequiredException]；其余（含 402 quota）→ 带状态码的
  /// [DioException]，由 controller 映射（402 → 额度态）。
  Stream<ChatTextFrame> _handleNon200(
    ResponseBody body,
    int status,
    Response<ResponseBody> response,
  ) async* {
    final errorMap = await _decodeErrorBody(body);
    _streamLogPrint(
      '流式请求失败 ${response.requestOptions.uri} status=$status '
      'code=${errorMap?['code'] ?? '(空)'} error=${errorMap?['error'] ?? '(空)'}',
    );
    if (status == 401) {
      throw const ChatAuthRequiredException();
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: Response(
        requestOptions: response.requestOptions,
        statusCode: status,
        data: errorMap,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  /// 读取非 200 响应的错误体（小 JSON），解析为 Map；失败返回 null。
  Future<Map<String, dynamic>?> _decodeErrorBody(ResponseBody body) async {
    try {
      final text = await utf8.decodeStream(body.stream);
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// 单帧过长时截断，避免一条日志挤爆控制台。
  String _truncate(String text) {
    const maxLength = 2000;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…（已截断，共 ${text.length} 字符）';
  }

  @override
  void dispose() => _dio.close();
}

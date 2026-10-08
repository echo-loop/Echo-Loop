import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'ai_http2_retry_interceptor.dart';
import 'ai_http_client_adapter_stub.dart'
    if (dart.library.io) 'ai_http_client_adapter_io.dart'
    as platform_adapter;

/// AI API HTTP/2 开关。
///
/// 默认开启；如线上网关或平台兼容性异常，可通过
/// `--dart-define=AI_HTTP2_ENABLED=false` 回退到 Dio 默认 adapter。
const aiHttp2EnabledByDefault = bool.fromEnvironment(
  'AI_HTTP2_ENABLED',
  defaultValue: true,
);

/// AI HTTP/2 空闲连接保留时间。
///
/// 覆盖同一句内翻译、解析、意群和查词的连续操作窗口，同时避免空闲连接长期占用。
const aiHttp2IdleTimeout = Duration(seconds: 30);

/// AI 流式响应「帧间空闲超时」。
///
/// HTTP/2 adapter 下 `receiveTimeout` 只约束「到首个响应头」的时间，不再约束帧间空闲。
/// 此超时用于流开到一半服务端僵死时的止损：帧间超过该时长无新字节即中断报错。
const aiHttpStreamIdleTimeout = Duration(seconds: 30);

/// 为 AI API 的 Dio 实例配置 HTTP/2 adapter。
///
/// 仅 HTTPS API 启用 HTTP/2；本地开发常用的 `http://localhost` 保持默认
/// HTTP/1.1，避免 h2c/TLS 协商差异带来的开发环境问题。
void configureAiHttpClientAdapter(
  Dio dio, {
  required String baseUrl,
  bool http2Enabled = aiHttp2EnabledByDefault,
}) {
  if (!shouldUseAiHttp2Adapter(baseUrl, http2Enabled: http2Enabled)) {
    return;
  }
  platform_adapter.configureAiHttp2Adapter(
    dio,
    idleTimeout: aiHttp2IdleTimeout,
  );
  // 仅 h2 路径挂载连接层重试：兜底 GOAWAY/空闲连接失效导致的瞬断（见拦截器说明）。
  // 添加到拦截器列表末尾，使其先于已有拦截器处理 onError。
  dio.interceptors.add(AiHttp2RetryInterceptor(dio));
}

@visibleForTesting
bool shouldUseAiHttp2Adapter(
  String baseUrl, {
  bool http2Enabled = aiHttp2EnabledByDefault,
}) {
  if (!http2Enabled || !platform_adapter.isAiHttp2Supported) {
    return false;
  }
  final uri = Uri.tryParse(baseUrl);
  return uri?.scheme == 'https';
}

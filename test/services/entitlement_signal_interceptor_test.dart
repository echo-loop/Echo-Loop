import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/services/entitlement_signal_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定返回 402 + 权益信号头的假 HTTP 适配器（验证 onError 信号路径）。
class _Fixed402Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":"Monthly free quota exceeded","code":"quota_exceeded"}',
      402,
      headers: {
        entitlementActiveHeader: ['0'],
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [EntitlementSignalInterceptor] 单测：从响应头提取权益信号并转发。
void main() {
  final interceptor = EntitlementSignalInterceptor();
  late List<({bool serverActive, String path})> signals;

  Response<dynamic> response(String path, {String? headerValue}) {
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      headers: Headers.fromMap({
        if (headerValue != null) entitlementActiveHeader: [headerValue],
      }),
    );
  }

  setUp(() {
    signals = [];
    EntitlementSignalInterceptor.onSignal =
        ({required bool serverActive, required String path}) {
          signals.add((serverActive: serverActive, path: path));
        };
  });

  tearDown(() {
    EntitlementSignalInterceptor.onSignal = null;
  });

  test('响应头为 1/0 → 转发信号（带请求路径）', () {
    interceptor.onResponse(
      response('/api/v1/stream/translate', headerValue: '1'),
      ResponseInterceptorHandler(),
    );
    interceptor.onResponse(
      response('/api/v1/stream/analyze', headerValue: '0'),
      ResponseInterceptorHandler(),
    );

    expect(signals, [
      (serverActive: true, path: '/api/v1/stream/translate'),
      (serverActive: false, path: '/api/v1/stream/analyze'),
    ]);
  });

  test('无信号头或值非法 → 不转发', () {
    interceptor.onResponse(
      response('/api/v1/stream/translate'),
      ResponseInterceptorHandler(),
    );
    interceptor.onResponse(
      response('/api/v1/stream/translate', headerValue: 'yes'),
      ResponseInterceptorHandler(),
    );

    expect(signals, isEmpty);
  });

  test('错误响应（如 402）同样携带信号头 → 转发', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.test'))
      ..httpClientAdapter = _Fixed402Adapter();
    dio.interceptors.add(interceptor);

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/v1/stream/translate'),
      throwsA(isA<DioException>()),
    );

    expect(signals, [(serverActive: false, path: '/api/v1/stream/translate')]);
  });

  test('未注册处理器时安全忽略', () {
    EntitlementSignalInterceptor.onSignal = null;
    interceptor.onResponse(
      response('/api/v1/stream/translate', headerValue: '1'),
      ResponseInterceptorHandler(),
    );
    // 不抛异常即通过。
  });
}

/// 后端 Dio 工厂 [createBackendDio] 测试。
///
/// 覆盖：工厂产出的 Dio 已在 BaseOptions 注入 client-info 公共 header（平台/渠道/版本），
/// 与 [clientInfoHeaders] 一致；appVersion 缺省时省略版本 header；baseUrl / 超时按参数设置。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/services/backend_dio.dart';
import 'package:echo_loop/services/api_log_interceptor.dart';
import 'package:echo_loop/services/client_info.dart';
import 'package:echo_loop/services/supabase_token_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';

class _AuthSource implements AuthSessionSource {
  _AuthSource(this.snapshot);

  AuthSessionSnapshot? snapshot;
  final events = StreamController<AuthSessionEvent>.broadcast();
  int refreshCalls = 0;
  Object? refreshError;
  Future<void> Function()? onRefresh;

  @override
  AuthSessionSnapshot? get currentSession => snapshot;

  @override
  Stream<AuthSessionEvent> get onAuthStateChange => events.stream;

  @override
  Future<void> refreshSession() async {
    refreshCalls++;
    final callback = onRefresh;
    if (callback != null) return callback();
    final error = refreshError;
    if (error != null) throw error;
    snapshot = AuthSessionSnapshot(
      userId: 'u1',
      accessToken: 'fresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCodes);

  final List<int> statusCodes;
  final headers = <Map<String, Object?>>[];
  final requestUris = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers.add(Map<String, Object?>.from(options.headers));
    requestUris.add(options.uri);
    final status = statusCodes.removeAt(0);
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('createBackendDio', () {
    test('API 区域跟随 UserRegion 更新', () async {
      final router = RuntimeEndpointRouter(
        endpoints: const RegionalServiceEndpoints(
          globalApiBaseUrl: 'https://global-api.example',
          chinaApiBaseUrl: 'https://china-api.example',
          globalModelCdnBaseUrl: 'https://global-cdn.example',
          chinaModelCdnBaseUrl: 'https://china-cdn.example',
        ),
      );
      final adapter = _RecordingAdapter([200, 200, 200]);
      final dio = createBackendDio(
        baseUrl: 'https://global-api.example',
        endpointRouter: router,
      )..httpClientAdapter = adapter;

      await dio.get<Object?>('/before-routing-change');
      await dio.get<Object?>('/after-routing-change');
      router.updateFromUserRegion(isChinaUser: true);
      router.markApiRegionAvailable(ServiceEndpointRegion.china);
      await dio.get<Object?>('/after-user-region-update');

      expect(adapter.requestUris[0].host, 'global-api.example');
      expect(adapter.requestUris[1].host, 'global-api.example');
      expect(adapter.requestUris[2].host, 'china-api.example');
      dio.close();
    });

    test('BaseOptions.headers 与 clientInfoHeaders 一致（携带平台/渠道/版本）', () {
      final dio = createBackendDio(
        baseUrl: 'https://example.com',
        appVersion: '1.2.3',
      );
      expect(dio.options.headers, clientInfoHeaders(appVersion: '1.2.3'));
      // 平台标识随请求上送（测试宿主平台合法则携带）。
      final platform = clientPlatformName();
      if (platform.isEmpty) {
        expect(dio.options.headers.containsKey(kAppPlatformHeader), isFalse);
      } else {
        expect(dio.options.headers[kAppPlatformHeader], platform);
      }
      expect(dio.options.headers[kAppVersionHeader], '1.2.3');
      dio.close();
    });

    test('appVersion 缺省时省略版本 header', () {
      final dio = createBackendDio(baseUrl: 'https://example.com');
      expect(dio.options.headers.containsKey(kAppVersionHeader), isFalse);
      dio.close();
    });

    test('baseUrl 与超时按参数设置', () {
      final dio = createBackendDio(
        baseUrl: 'https://api.example.com',
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 7),
      );
      expect(dio.options.baseUrl, 'https://api.example.com');
      expect(dio.options.connectTimeout, const Duration(seconds: 3));
      expect(dio.options.receiveTimeout, const Duration(seconds: 7));
      dio.close();
    });

    test('默认超时为连接 15 秒、接收 30 秒', () {
      final dio = createBackendDio(baseUrl: 'https://api.example.com');

      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 30));
      dio.close();
    });

    test('默认安装一个后端 API 日志拦截器并支持自定义 tag', () {
      final logs = <String>[];
      final dio = createBackendDio(
        baseUrl: 'https://api.example.com',
        apiLogTag: 'CATALOG',
        apiLogPrint: logs.add,
      );

      final interceptors = dio.interceptors.whereType<ApiLogInterceptor>();
      expect(interceptors, hasLength(1));
      expect(interceptors.single.tag, 'CATALOG');
      dio.close();
    });
  });

  group('createAuthenticatedBackendDio', () {
    test('Token Gate notSignedIn 映射为本地 401，且请求不出站', () async {
      final source = _AuthSource(null);
      final coordinator = SupabaseTokenCoordinator(source);
      final adapter = _RecordingAdapter([200]);
      final dio = createAuthenticatedBackendDio(
        tokenCoordinator: coordinator,
        baseUrl: 'https://api.example.com',
      )..httpClientAdapter = adapter;

      await expectLater(
        dio.post<void>('/stream'),
        throwsA(
          isA<DioException>()
              .having(
                (error) => error.type,
                'type',
                DioExceptionType.badResponse,
              )
              .having((error) => error.response?.statusCode, 'statusCode', 401),
        ),
      );
      expect(adapter.headers, isEmpty);
      coordinator.dispose();
      await source.events.close();
    });

    test('Token Gate 临时刷新失败映射为 connectionError', () async {
      final source = _AuthSource(
        AuthSessionSnapshot(
          userId: 'u1',
          accessToken: 'expired',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      )..refreshError = StateError('offline');
      final coordinator = SupabaseTokenCoordinator(source);
      final adapter = _RecordingAdapter([200]);
      final dio = createAuthenticatedBackendDio(
        tokenCoordinator: coordinator,
        baseUrl: 'https://api.example.com',
      )..httpClientAdapter = adapter;

      await expectLater(
        dio.get<void>('/entitlements'),
        throwsA(
          isA<DioException>()
              .having(
                (error) => error.type,
                'type',
                DioExceptionType.connectionError,
              )
              .having((error) => error.response, 'response', isNull),
        ),
      );
      expect(adapter.headers, isEmpty);
      coordinator.dispose();
      await source.events.close();
    });

    test('Token Gate identityChanged 按取消处理，不误报 401', () async {
      late _AuthSource source;
      source =
          _AuthSource(
              AuthSessionSnapshot(
                userId: 'u1',
                accessToken: 'expired',
                expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
              ),
            )
            ..onRefresh = () async {
              source.snapshot = AuthSessionSnapshot(
                userId: 'u2',
                accessToken: 'fresh-u2',
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
              );
              source.events.add(AuthSessionEvent.identityReplaced);
              await Future<void>.delayed(Duration.zero);
            };
      final coordinator = SupabaseTokenCoordinator(source);
      final adapter = _RecordingAdapter([200]);
      final dio = createAuthenticatedBackendDio(
        tokenCoordinator: coordinator,
        baseUrl: 'https://api.example.com',
      )..httpClientAdapter = adapter;

      await expectLater(
        dio.get<void>('/profile'),
        throwsA(
          isA<DioException>()
              .having((error) => error.type, 'type', DioExceptionType.cancel)
              .having((error) => error.response, 'response', isNull),
        ),
      );
      expect(adapter.headers, isEmpty);
      coordinator.dispose();
      await source.events.close();
    });

    test('请求前覆盖旧 Authorization，401 opt-in 只重试一次并保留幂等键', () async {
      final source = _AuthSource(
        AuthSessionSnapshot(
          userId: 'u1',
          accessToken: 'old',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final coordinator = SupabaseTokenCoordinator(source);
      final adapter = _RecordingAdapter([401, 200]);
      final dio = createAuthenticatedBackendDio(
        tokenCoordinator: coordinator,
        baseUrl: 'https://api.example.com',
      )..httpClientAdapter = adapter;

      await dio.post<Map<String, dynamic>>(
        '/checkout',
        options: authRetryOnceOptions(
          headers: {
            'Authorization': 'Bearer stale-parameter',
            'Idempotency-Key': 'same-key',
          },
        ),
      );

      expect(source.refreshCalls, 1);
      expect(adapter.headers, hasLength(2));
      expect(adapter.headers.first['Authorization'], 'Bearer old');
      expect(adapter.headers.last['Authorization'], 'Bearer fresh');
      expect(adapter.headers.map((value) => value['Idempotency-Key']).toSet(), {
        'same-key',
      });
      coordinator.dispose();
      await source.events.close();
    });

    test('未 opt-in 的 401 不刷新、不重放', () async {
      final source = _AuthSource(
        AuthSessionSnapshot(
          userId: 'u1',
          accessToken: 'valid',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final coordinator = SupabaseTokenCoordinator(source);
      final adapter = _RecordingAdapter([401]);
      final dio = createAuthenticatedBackendDio(
        tokenCoordinator: coordinator,
        baseUrl: 'https://api.example.com',
      )..httpClientAdapter = adapter;

      await expectLater(
        dio.post<void>('/stream'),
        throwsA(isA<DioException>()),
      );
      expect(source.refreshCalls, 0);
      expect(adapter.headers, hasLength(1));
      coordinator.dispose();
      await source.events.close();
    });
  });
}

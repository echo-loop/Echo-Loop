/// 自家后端请求的统一 Dio 工厂。
///
/// **凡是请求自家后端（[apiBaseUrl]）的 Dio 都应经此工厂创建**，工厂自动把
/// client-info 公共 header（`x-app-platform` / `x-app-distribution` / `x-app-version`）
/// 写入 [BaseOptions.headers]，使平台/渠道标识随该 Dio 的每个请求上送——后端据此按
/// 「平台+渠道」组合决定 AI 免费额度等策略（见 docs/subscription-setup.md）。
///
/// 好处：header 注入集中一处，新增后端 client 无需再手写，杜绝「漏带渠道 header」。
///
/// **不得**用于外部主机请求（R2 presigned 上传、CDN 模型/资源下载、播客 RSS、
/// App Store Lookup 等）——那些请求不应携带自家标识 header。此类请求继续裸构造 `Dio`，
/// 或（如 [AppUpdateChecker] 那种同一 Dio 混打后端与外部主机的场景）改用 per-request
/// [Options.headers] 只在打后端的那个请求上带 [clientInfoHeaders]。
library;

import 'package:dio/dio.dart';

import 'api_log_interceptor.dart';
import 'app_logger.dart';
import 'client_info.dart';
import 'entitlement_signal_interceptor.dart';
import 'supabase_token_coordinator.dart';
import 'runtime_endpoint_router.dart';

/// 响应 401 后的端点级重试策略；默认禁止重放业务请求。
enum AuthRetryPolicy { none, once }

const _authRetryPolicyKey = 'authRetryPolicy';
const _authRetryAttemptKey = 'authRetryAttempt';

/// 为明确允许重放的端点标记一次鉴权重试。
Options authRetryOnceOptions({Map<String, Object?>? headers}) => Options(
  headers: headers,
  extra: const {_authRetryPolicyKey: AuthRetryPolicy.once},
);

/// 构造一个已注入 client-info 公共 header 的后端 Dio。
///
/// 工厂统一安装 client-info 与请求日志；HTTP/2 等差异化能力由各 client 追加。
/// 传入 [endpointRouter] 后，每次请求发送前会读取最新的区域 API 地址。
///
/// [baseUrl] 为空时表示各请求用完整 URL（header 仍随每个请求上送，故仅用于纯后端 Dio）。
/// [appVersion] 为空/null 时省略版本 header（降级不阻断，见 [clientInfoHeaders]）。
Dio createBackendDio({
  String baseUrl = '',
  RuntimeEndpointRouter? endpointRouter,
  String? appVersion,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 30),
  String apiLogTag = 'BACKEND',
  void Function(String message)? apiLogPrint,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: clientInfoHeaders(appVersion: appVersion),
    ),
  );
  if (endpointRouter != null) {
    dio.interceptors.add(RuntimeApiEndpointInterceptor(endpointRouter));
  }
  dio.interceptors.add(
    ApiLogInterceptor(tag: apiLogTag, logPrint: apiLogPrint),
  );
  // E6：读取权益信号响应头，服务端权益变化（退款/到期）时提示订阅层回源对账。
  dio.interceptors.add(EntitlementSignalInterceptor());
  return dio;
}

/// 构造需要 Supabase 登录的自建后端 Dio。
///
/// Token Gate 只保证请求发送前 token 有效；响应 401 仅在请求通过
/// [authRetryOnceOptions] 显式 opt-in 时刷新并重放一次。
Dio createAuthenticatedBackendDio({
  required SupabaseTokenCoordinator? tokenCoordinator,
  String baseUrl = '',
  RuntimeEndpointRouter? endpointRouter,
  String? appVersion,
  Duration connectTimeout = const Duration(seconds: 15),
  Duration receiveTimeout = const Duration(seconds: 30),
  String apiLogTag = 'BACKEND',
  void Function(String message)? apiLogPrint,
}) {
  final dio = createBackendDio(
    baseUrl: baseUrl,
    endpointRouter: endpointRouter,
    appVersion: appVersion,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    apiLogTag: apiLogTag,
    apiLogPrint: apiLogPrint,
  );
  if (tokenCoordinator != null) {
    dio.interceptors.insert(
      0,
      _AuthenticatedBackendInterceptor(dio, tokenCoordinator),
    );
  }
  return dio;
}

/// 在每次请求发送前读取 UserRegion 统一结论当前选中的 API 地址。
class RuntimeApiEndpointInterceptor extends Interceptor {
  RuntimeApiEndpointInterceptor(this._router);

  final RuntimeEndpointRouter _router;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestUri = Uri.tryParse(options.path);
    if (requestUri?.hasScheme ?? false) {
      handler.next(options);
      return;
    }
    try {
      options.baseUrl = _router.apiBaseUrl;
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}

class _AuthenticatedBackendInterceptor extends Interceptor {
  _AuthenticatedBackendInterceptor(this._dio, this._coordinator);

  final Dio _dio;
  final SupabaseTokenCoordinator _coordinator;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requestLabel = '${options.method} ${options.path}';
    try {
      if (options.cancelToken?.isCancelled ?? false) {
        AppLogger.log(
          'AuthHttp',
          '鉴权请求取消: phase=beforeGate request=$requestLabel',
        );
        handler.reject(
          DioException.requestCancelled(
            requestOptions: options,
            reason: options.cancelToken?.cancelError?.error,
          ),
        );
        return;
      }
      AppLogger.log('AuthHttp', '鉴权请求等待 Token Gate: request=$requestLabel');
      final token = await _coordinator.requireValidAccessToken();
      if (options.cancelToken?.isCancelled ?? false) {
        AppLogger.log(
          'AuthHttp',
          '鉴权请求取消: phase=afterGate request=$requestLabel',
        );
        handler.reject(
          DioException.requestCancelled(
            requestOptions: options,
            reason: options.cancelToken?.cancelError?.error,
          ),
        );
        return;
      }
      options.headers['Authorization'] = 'Bearer $token';
      AppLogger.log('AuthHttp', '鉴权请求放行: request=$requestLabel');
      handler.next(options);
    } catch (error, stackTrace) {
      final gateFailure = error is TokenGateException ? error.reason : null;
      AppLogger.log(
        'AuthHttp',
        '鉴权请求拒绝: request=$requestLabel type=${error.runtimeType} '
            'reason=${error is TokenGateException ? error.reason.name : "unknown"}',
      );
      if (gateFailure == TokenGateFailure.identityChanged) {
        handler.reject(
          DioException.requestCancelled(requestOptions: options, reason: error),
        );
        return;
      }
      final unauthorized = gateFailure == TokenGateFailure.notSignedIn;
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: unauthorized
              ? DioExceptionType.badResponse
              : DioExceptionType.connectionError,
          response: unauthorized
              ? Response<Object?>(requestOptions: options, statusCode: 401)
              : null,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final policy = request.extra[_authRetryPolicyKey];
    final attempt = request.extra[_authRetryAttemptKey];
    if (error.response?.statusCode != 401) {
      handler.next(error);
      return;
    }
    final requestLabel = '${request.method} ${request.path}';
    final cancelled = request.cancelToken?.isCancelled ?? false;
    if (policy != AuthRetryPolicy.once || attempt == 1 || cancelled) {
      AppLogger.log(
        'AuthHttp',
        '401 不重放: request=$requestLabel policy=${policy?.toString() ?? "none"} '
            'attempt=${attempt ?? 0} cancelled=$cancelled',
      );
      handler.next(error);
      return;
    }
    AppLogger.log('AuthHttp', '401 开始单次鉴权重试: request=$requestLabel attempt=1');
    try {
      final token = await _coordinator.requireValidAccessToken(
        forceRefresh: true,
      );
      if (request.cancelToken?.isCancelled ?? false) {
        AppLogger.log(
          'AuthHttp',
          '401 重试取消: phase=afterRefresh request=$requestLabel',
        );
        handler.next(error);
        return;
      }
      request.headers['Authorization'] = 'Bearer $token';
      request.extra[_authRetryAttemptKey] = 1;
      final response = await _dio.fetch<Object?>(request);
      AppLogger.log(
        'AuthHttp',
        '401 重试成功: request=$requestLabel status=${response.statusCode}',
      );
      handler.resolve(response);
    } catch (retryError) {
      AppLogger.log(
        'AuthHttp',
        '401 重试失败: request=$requestLabel type=${retryError.runtimeType}',
      );
      handler.next(error);
    }
  }
}

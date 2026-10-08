/// 远程配置拉取服务。
///
/// 先读未过期缓存，过期后请求后端；请求失败时使用过期缓存，最后才回退本地默认。
library;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/app_logger.dart';
import '../../services/backend_dio.dart';
import '../../services/client_info.dart';
import '../../services/runtime_endpoint_router.dart';
import 'remote_config.dart';
import 'remote_config_store.dart';

const _logTag = 'RemoteConfig';

class RemoteConfigService {
  RemoteConfigService({
    required Dio dio,
    required RemoteConfigStore store,
    DateTime Function()? now,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = dio,
       _store = store,
       _now = now ?? DateTime.now,
       _endpointRouter = endpointRouter;

  RemoteConfigService.create({
    required SharedPreferences prefs,
    String baseUrl = apiBaseUrl,
    String? appVersion,
    RuntimeEndpointRouter? endpointRouter,
  }) : this(
         dio: createBackendDio(
           baseUrl: baseUrl,
           endpointRouter: endpointRouter,
           appVersion: appVersion,
           apiLogTag: 'REMOTE-CONFIG',
         ),
         store: RemoteConfigStore(prefs),
         endpointRouter: endpointRouter,
       );

  final Dio _dio;
  final RemoteConfigStore _store;
  final DateTime Function() _now;
  final RuntimeEndpointRouter? _endpointRouter;

  /// 最近一次成功获取远程配置的时间，用于统一刷新节流。
  DateTime? get lastFetchedAt => _store.readFetchedAt();

  /// 启动期同步读取本地初始配置，不触发网络请求。
  ///
  /// 远程配置失败时允许沿用过期缓存，避免配置服务短暂不可用导致入口抖动；
  /// 真正的远端刷新由 App 首帧后的 [fetchRemote] 后台任务完成。
  RemoteConfig loadInitialFromCache() {
    try {
      final cached = _store.readCached(now: _now(), allowExpired: true);
      if (cached != null) {
        AppLogger.log(
          _logTag,
          'initial cache country=${cached.context.countryCode}',
        );
        return cached;
      }
    } catch (e) {
      AppLogger.log(_logTag, 'initial cache parse failed: $e');
    }

    AppLogger.log(_logTag, 'initial fallback to local defaults');
    return RemoteConfig.defaults;
  }

  /// 加载启动配置；任何异常都降级为缓存或本地默认，不能中断 App 启动。
  Future<RemoteConfig> load() async {
    try {
      final cached = _store.readCached(now: _now());
      if (cached != null) {
        AppLogger.log(
          _logTag,
          'cache hit country=${cached.context.countryCode}',
        );
        return cached;
      }
    } catch (e) {
      AppLogger.log(_logTag, 'cache parse failed: $e');
    }

    try {
      return await fetchRemote();
    } catch (e) {
      AppLogger.log(_logTag, 'fetch failed: $e');
    }

    try {
      final expired = _store.readCached(now: _now(), allowExpired: true);
      if (expired != null) {
        AppLogger.log(
          _logTag,
          'use expired cache country=${expired.context.countryCode}',
        );
        return expired;
      }
    } catch (e) {
      AppLogger.log(_logTag, 'expired cache parse failed: $e');
    }

    AppLogger.log(_logTag, 'fallback to local defaults');
    return RemoteConfig.defaults;
  }

  /// 直接请求后端并写入缓存。
  ///
  /// 运行期刷新使用本方法，避免 [load] 的缓存优先逻辑让过期检查后的刷新
  /// 再次命中本地缓存。调用方负责决定失败时是否保留旧内存配置。
  Future<RemoteConfig> fetchRemote() async {
    final response = await _fetchRemoteConfigResponse();
    final config = RemoteConfig.fromRemoteJson(response.data);
    await _store.write(config, now: _now());
    AppLogger.log(
      _logTag,
      'fetch ok country=${config.context.countryCode} '
      'cloudDriveImport=${config.features.cloudDriveImport.enabled} '
      'aiChatAssistant=${config.features.aiChatAssistant.enabled}',
    );
    return config;
  }

  /// 请求当前首选区域的 Client Config；网络错误或 5xx 时最多尝试备用区域一次。
  ///
  /// 4xx、取消请求或没有备用端点时保留原错误，成功响应会更新当前 API 区域。
  Future<Response<Object?>> _fetchRemoteConfigResponse() async {
    const path = '/api/v1/client/config';
    final router = _endpointRouter;
    if (router == null) return _getConfig(path);

    final preferredRegion = router.preferredApiRegion;
    final preferredUri = router.apiUriForRegion(preferredRegion, path);
    if (preferredUri == null) {
      AppLogger.log(
        _logTag,
        'preferred config API is not configured; using Dio base URL',
      );
      return _getConfig(path);
    }

    AppLogger.log(
      _logTag,
      'request client config preferred=${preferredRegion.name} '
      'endpoint=${_endpointLabel(preferredUri)}',
    );

    try {
      final response = await _getConfig(preferredUri.toString());
      router.markApiRegionAvailable(preferredRegion);
      return response;
    } on DioException catch (preferredError) {
      if (!_shouldTryAlternate(preferredError)) {
        AppLogger.log(
          _logTag,
          'preferred config API fallback skipped '
          'type=${preferredError.type.name} '
          'status=${preferredError.response?.statusCode ?? "none"}',
        );
        rethrow;
      }

      final alternateRegion = router.alternateApiRegion;
      if (alternateRegion == null) {
        AppLogger.log(
          _logTag,
          'config API fallback unavailable: no alternate endpoint configured',
        );
        rethrow;
      }
      final alternateUri = router.apiUriForRegion(alternateRegion, path);
      if (alternateUri == null) {
        AppLogger.log(
          _logTag,
          'config API fallback unavailable: '
          'alternate=${alternateRegion.name} endpoint is not configured',
        );
        rethrow;
      }

      AppLogger.log(
        _logTag,
        'preferred config endpoint failed; trying alternate '
        'preferred=${preferredRegion.name}('
        '${_endpointLabel(preferredUri)}) '
        'alternate=${alternateRegion.name}('
        '${_endpointLabel(alternateUri)}) '
        'type=${preferredError.type.name} '
        'status=${preferredError.response?.statusCode ?? "none"}',
      );
      try {
        final response = await _getConfig(alternateUri.toString());
        router.markApiRegionAvailable(alternateRegion);
        return response;
      } catch (alternateError, stackTrace) {
        final errorType = alternateError is DioException
            ? alternateError.type.name
            : alternateError.runtimeType.toString();
        final statusCode = alternateError is DioException
            ? alternateError.response?.statusCode
            : null;
        AppLogger.log(
          _logTag,
          'alternate config endpoint failed '
          'region=${alternateRegion.name} '
          'endpoint=${_endpointLabel(alternateUri)} '
          'type=$errorType status=${statusCode ?? "none"}',
        );
        Error.throwWithStackTrace(alternateError, stackTrace);
      }
    }
  }

  Future<Response<Object?>> _getConfig(String pathOrUri) => _dio.get<Object?>(
    pathOrUri,
    queryParameters: {'platform': clientPlatformName()},
  );

  bool _shouldTryAlternate(DioException error) {
    if (error.type == DioExceptionType.cancel) return false;
    final statusCode = error.response?.statusCode;
    return statusCode == null || statusCode >= 500;
  }

  String _endpointLabel(Uri uri) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }
}

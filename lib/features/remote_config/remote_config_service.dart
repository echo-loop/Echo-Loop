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
import 'remote_config.dart';
import 'remote_config_store.dart';

const _logTag = 'RemoteConfig';

class RemoteConfigService {
  RemoteConfigService({
    required Dio dio,
    required RemoteConfigStore store,
    DateTime Function()? now,
  }) : _dio = dio,
       _store = store,
       _now = now ?? DateTime.now;

  RemoteConfigService.create({
    required SharedPreferences prefs,
    String baseUrl = apiBaseUrl,
    String? appVersion,
  }) : this(
         dio: createBackendDio(
           baseUrl: baseUrl,
           appVersion: appVersion,
           connectTimeout: const Duration(seconds: 3),
           receiveTimeout: const Duration(seconds: 5),
           apiLogTag: 'REMOTE-CONFIG',
         ),
         store: RemoteConfigStore(prefs),
       );

  final Dio _dio;
  final RemoteConfigStore _store;
  final DateTime Function() _now;

  /// 最近一次成功获取远程配置的时间，用于统一刷新节流。
  DateTime? get lastFetchedAt => _store.readFetchedAt();

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
    final response = await _dio.get<Object?>(
      '/api/v1/client/config',
      queryParameters: {'platform': clientPlatformName()},
    );
    final config = RemoteConfig.fromJson(response.data);
    await _store.write(config, now: _now());
    AppLogger.log(
      _logTag,
      'fetch ok country=${config.context.countryCode} '
      'cloudDriveImport=${config.features.cloudDriveImport.enabled}',
    );
    return config;
  }
}

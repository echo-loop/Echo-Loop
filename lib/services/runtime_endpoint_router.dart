import 'package:flutter/foundation.dart' show kReleaseMode;

import '../config/api_config.dart' show apiBaseUrl;
import '../config/regional_service_endpoints.dart';
import 'app_logger.dart';

/// 以 UserRegion 的统一结论选择 API 与 CDN 首选区域，并记录 API 可用性回退。
class RuntimeEndpointRouter {
  RuntimeEndpointRouter({required this.endpoints});

  final RegionalServiceEndpoints endpoints;

  ServiceEndpointRegion _preferredApiRegion = ServiceEndpointRegion.global;
  ServiceEndpointRegion _activeApiRegion = ServiceEndpointRegion.global;
  ServiceEndpointRegion _cdnRegion = ServiceEndpointRegion.global;
  bool _apiFallbackActive = false;

  /// 当前实际承载后端 API 请求的区域，可能因故障回退而不同于用户首选区域。
  ServiceEndpointRegion get apiRegion => _activeApiRegion;
  ServiceEndpointRegion get preferredApiRegion => _preferredApiRegion;
  ServiceEndpointRegion get modelCdnRegion => _cdnRegion;

  String get apiBaseUrl =>
      endpoints.apiBaseUrlFor(_activeApiRegion) ??
      endpoints.apiBaseUrlFor(ServiceEndpointRegion.global) ??
      '';

  String get modelCdnBaseUrl =>
      endpoints.modelCdnBaseUrlFor(_cdnRegion) ??
      endpoints.modelCdnBaseUrlFor(ServiceEndpointRegion.global) ??
      '';

  Uri apiUri(String path) => _resolvePath(apiBaseUrl, path);

  /// 根据 UserRegion 唯一结论更新 API/CDN 首选区域。
  ///
  /// 地区结论变化后先保留当前 API，直到配置请求验证新的首选区域；用户地区
  /// 状态本身不受可用性回退影响。
  void updateFromUserRegion({required bool isChinaUser}) {
    final requestedRegion = isChinaUser
        ? ServiceEndpointRegion.china
        : ServiceEndpointRegion.global;
    final requestedApiBaseUrl = endpoints.apiBaseUrlFor(requestedRegion);
    final requestedCdnBaseUrl = endpoints.modelCdnBaseUrlFor(requestedRegion);
    _preferredApiRegion = _configuredRegion(
      requestedRegion,
      endpoints.apiBaseUrlFor,
    );
    _cdnRegion = _configuredRegion(
      requestedRegion,
      endpoints.modelCdnBaseUrlFor,
    );

    _apiFallbackActive = _activeApiRegion != _preferredApiRegion;

    if (requestedRegion == ServiceEndpointRegion.china &&
        requestedApiBaseUrl == null) {
      AppLogger.log(
        'EndpointRouter',
        'China API is not configured; using global API',
      );
    }
    if (requestedRegion == ServiceEndpointRegion.china &&
        requestedCdnBaseUrl == null) {
      AppLogger.log(
        'EndpointRouter',
        'China model CDN is not configured; using global CDN',
      );
    }

    AppLogger.log(
      'EndpointRouter',
      'userRegion china=$isChinaUser requested=${requestedRegion.name} '
          'preferredApi=${_preferredApiRegion.name}('
          '${_endpointLabel(endpoints.apiBaseUrlFor(_preferredApiRegion))}) '
          'activeApi=${_activeApiRegion.name}(${_endpointLabel(apiBaseUrl)}) '
          'cdn=${_cdnRegion.name}('
          '${_endpointLabel(modelCdnBaseUrl)}) '
          'fallback=$_apiFallbackActive',
    );
  }

  /// 返回指定区域的 API 地址；未配置时返回 null。
  Uri? apiUriForRegion(ServiceEndpointRegion region, String path) {
    final baseUrl = endpoints.apiBaseUrlFor(region);
    if (baseUrl == null) return null;
    return _resolvePath(baseUrl, path);
  }

  /// 返回与首选 API 区域相反且已配置的区域，用于配置请求故障回退。
  ServiceEndpointRegion? get alternateApiRegion {
    final alternate = _preferredApiRegion == ServiceEndpointRegion.china
        ? ServiceEndpointRegion.global
        : ServiceEndpointRegion.china;
    return endpoints.apiBaseUrlFor(alternate) == null ? null : alternate;
  }

  /// 记录配置请求验证成功的 API 区域，并清除或启用会话级回退。
  bool markApiRegionAvailable(ServiceEndpointRegion region) {
    if (endpoints.apiBaseUrlFor(region) == null) return false;
    _activeApiRegion = region;
    _apiFallbackActive = region != _preferredApiRegion;
    AppLogger.log(
      'EndpointRouter',
      'api endpoint available region=${region.name} '
          'url=${_endpointLabel(endpoints.apiBaseUrlFor(region))} '
          'preferred=${_preferredApiRegion.name} fallback=$_apiFallbackActive',
    );
    return true;
  }

  /// 将 CDN 资源相对路径解析到当前选中的 CDN 域名。
  Uri modelCdnUri(String resourcePath) {
    final baseUrl = modelCdnBaseUrl;
    if (baseUrl.isEmpty) {
      throw StateError('No model CDN endpoint is configured');
    }
    return _resolvePath(baseUrl, resourcePath);
  }

  ServiceEndpointRegion _configuredRegion(
    ServiceEndpointRegion preferred,
    String? Function(ServiceEndpointRegion) readBaseUrl,
  ) =>
      readBaseUrl(preferred) == null ? ServiceEndpointRegion.global : preferred;

  String _endpointLabel(String? baseUrl) {
    if (baseUrl == null) return 'unconfigured';
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return 'invalid';
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  Uri _resolvePath(String baseUrl, String path) {
    if (baseUrl.isEmpty) {
      throw StateError('No service endpoint is configured');
    }
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/').resolve(relativePath);
  }
}

/// 发布包启用中国与全球地址；开发和 profile 构建保留 API_BASE_URL 覆盖。
final _runtimeEndpoints = kReleaseMode
    ? regionalServiceEndpoints
    : const RegionalServiceEndpoints(
        globalApiBaseUrl: apiBaseUrl,
        chinaApiBaseUrl: '',
        globalModelCdnBaseUrl: globalModelCdnBaseUrl,
        chinaModelCdnBaseUrl: '',
      );

final runtimeEndpointRouter = RuntimeEndpointRouter(
  endpoints: _runtimeEndpoints,
);

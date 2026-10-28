/// 启动时按候选 API 顺序解析服务地区。
library;

import '../../config/regional_service_endpoints.dart';
import '../../services/app_logger.dart';
import '../remote_config/remote_config.dart';

/// 地区解析的来源，供启动诊断与 UI 状态共享。
enum UserRegionDecisionSource {
  remoteConfig,
  systemFallback,
  developerOverride,
}

/// 本进程启动时采用的地区及对应远程配置。
class UserRegionBootstrapResult {
  const UserRegionBootstrapResult({
    required this.isChinaUser,
    required this.source,
    required this.remoteConfig,
    bool? configFetched,
  }) : _configFetched = configFetched;

  final bool isChinaUser;
  final UserRegionDecisionSource source;
  final RemoteConfig remoteConfig;
  final bool? _configFetched;

  /// 启动期是否已拿到本次网络返回的 Config；为 true 时首轮定时刷新可跳过请求。
  ///
  /// 未显式指定时，仅 [UserRegionDecisionSource.remoteConfig] 视为已拿到。
  bool get configFetched =>
      _configFetched ?? source == UserRegionDecisionSource.remoteConfig;
}

/// 远程配置候选地址读取接口，便于用确定性结果测试启动编排。
typedef RemoteConfigCandidateFetcher =
    Future<RemoteConfig> Function(String baseUrl, Duration timeout);

/// 通过 Config API 地区结果决定当前进程的 API/CDN 路由。
class UserRegionBootstrapper {
  UserRegionBootstrapper({
    required RegionalServiceEndpoints endpoints,
    required RemoteConfigCandidateFetcher fetchRemoteConfig,
    this.requestTimeout = const Duration(seconds: 5),
  }) : _endpoints = endpoints,
       _fetchRemoteConfig = fetchRemoteConfig;

  static final RegExp _alpha2CountryCode = RegExp(r'^[A-Z]{2}$');

  final RegionalServiceEndpoints _endpoints;
  final RemoteConfigCandidateFetcher _fetchRemoteConfig;
  final Duration requestTimeout;

  /// 先访问系统 Region 对应地址，再访问另一区域；无有效结果时保留系统判断。
  ///
  /// [forcedRegion] 非空时（开发者选项手动指定）只访问该区域并固定使用它，
  /// 忽略系统 Region 与 Config 返回的国家码。
  Future<UserRegionBootstrapResult> resolve({
    required bool systemIsChinaUser,
    required RemoteConfig cachedConfig,
    ServiceEndpointRegion? forcedRegion,
  }) async {
    if (forcedRegion != null) {
      return _resolveForced(forcedRegion, cachedConfig);
    }
    final preferredRegion = systemIsChinaUser
        ? ServiceEndpointRegion.china
        : ServiceEndpointRegion.global;
    final alternateRegion = systemIsChinaUser
        ? ServiceEndpointRegion.global
        : ServiceEndpointRegion.china;
    final preferredUrl = _endpoints.apiBaseUrlFor(preferredRegion);
    final alternateUrl = _endpoints.apiBaseUrlFor(alternateRegion);
    final candidates = <String?>[
      preferredUrl,
      if (alternateUrl != preferredUrl) alternateUrl,
    ];

    RemoteConfig? latestValidConfig;
    for (var index = 0; index < candidates.length; index++) {
      final baseUrl = candidates[index];
      if (baseUrl == null) {
        AppLogger.log(
          'UserRegion',
          'config candidate ${index + 1} skipped: endpoint unconfigured',
        );
        continue;
      }

      final stopwatch = Stopwatch()..start();
      try {
        AppLogger.log(
          'UserRegion',
          'config candidate ${index + 1} start '
              'region=${preferredUrl == baseUrl ? preferredRegion.name : alternateRegion.name}',
        );
        final config = await _fetchRemoteConfig(baseUrl, requestTimeout);
        latestValidConfig = config;
        final countryCode = _validCountryCode(config.context.countryCode);
        if (countryCode == null) {
          AppLogger.log(
            'UserRegion',
            'config candidate ${index + 1} has no valid country code '
                'elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
          continue;
        }

        final isChinaUser = countryCode == 'CN';
        AppLogger.log(
          'UserRegion',
          'config decision country=$countryCode china=$isChinaUser '
              'candidate=${index + 1} elapsedMs=${stopwatch.elapsedMilliseconds}',
        );
        return UserRegionBootstrapResult(
          isChinaUser: isChinaUser,
          source: UserRegionDecisionSource.remoteConfig,
          remoteConfig: config,
        );
      } catch (error) {
        AppLogger.log(
          'UserRegion',
          'config candidate ${index + 1} failed '
              'elapsedMs=${stopwatch.elapsedMilliseconds} '
              'errorType=${error.runtimeType}',
        );
      }
    }

    AppLogger.log(
      'UserRegion',
      'system fallback china=$systemIsChinaUser '
          'configAvailable=${latestValidConfig != null}',
    );
    return UserRegionBootstrapResult(
      isChinaUser: systemIsChinaUser,
      source: UserRegionDecisionSource.systemFallback,
      remoteConfig: latestValidConfig ?? cachedConfig,
    );
  }

  /// 开发者强制地区：只拉该区域的 Config，失败时用缓存，地区保持不变。
  Future<UserRegionBootstrapResult> _resolveForced(
    ServiceEndpointRegion region,
    RemoteConfig cachedConfig,
  ) async {
    final isChinaUser = region == ServiceEndpointRegion.china;
    var config = cachedConfig;
    var fetched = false;
    final baseUrl = _endpoints.apiBaseUrlFor(region);
    if (baseUrl == null) {
      AppLogger.log(
        'UserRegion',
        'developer override region=${region.name} endpoint unconfigured',
      );
    } else {
      try {
        config = await _fetchRemoteConfig(baseUrl, requestTimeout);
        fetched = true;
      } catch (error) {
        AppLogger.log(
          'UserRegion',
          'developer override config failed errorType=${error.runtimeType}',
        );
      }
    }
    AppLogger.log(
      'UserRegion',
      'developer override decision region=${region.name} '
          'china=$isChinaUser configFetched=$fetched',
    );
    return UserRegionBootstrapResult(
      isChinaUser: isChinaUser,
      source: UserRegionDecisionSource.developerOverride,
      remoteConfig: config,
      configFetched: fetched,
    );
  }

  String? _validCountryCode(String? countryCode) {
    final normalized = countryCode?.trim().toUpperCase();
    if (normalized == null ||
        normalized == 'XX' ||
        !_alpha2CountryCode.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}

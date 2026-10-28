import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/user_region/user_region_bootstrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const endpoints = RegionalServiceEndpoints(
    globalApiBaseUrl: 'https://global.example',
    chinaApiBaseUrl: 'https://china.example',
    globalModelCdnBaseUrl: 'https://global-cdn.example',
    chinaModelCdnBaseUrl: 'https://china-cdn.example',
  );

  test('系统为中国区时先访问中国地址，Config 可将用户判为全球区', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, timeout) async {
        calls.add(baseUrl);
        expect(timeout, const Duration(seconds: 5));
        return _config('US');
      },
    );

    final result = await bootstrapper.resolve(
      systemIsChinaUser: true,
      cachedConfig: _config('CN'),
    );

    expect(calls, ['https://china.example']);
    expect(result.isChinaUser, isFalse);
    expect(result.source, UserRegionDecisionSource.remoteConfig);
    expect(result.configFetched, isTrue);
    expect(result.remoteConfig.context.countryCode, 'US');
  });

  test('首选地址失败后尝试另一区域，并采用其 Config 国家码', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async {
        calls.add(baseUrl);
        if (baseUrl == 'https://global.example') {
          throw StateError('global unavailable');
        }
        return _config('CN');
      },
    );

    final result = await bootstrapper.resolve(
      systemIsChinaUser: false,
      cachedConfig: _config('US'),
    );

    expect(calls, ['https://global.example', 'https://china.example']);
    expect(result.isChinaUser, isTrue);
    expect(result.source, UserRegionDecisionSource.remoteConfig);
  });

  test('成功响应为 XX 无效地区码时继续尝试另一区域', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async {
        calls.add(baseUrl);
        return _config(baseUrl == 'https://global.example' ? 'XX' : 'CN');
      },
    );

    final result = await bootstrapper.resolve(
      systemIsChinaUser: false,
      cachedConfig: RemoteConfig.defaults,
    );

    expect(calls, ['https://global.example', 'https://china.example']);
    expect(result.isChinaUser, isTrue);
    expect(result.source, UserRegionDecisionSource.remoteConfig);
  });

  test('两个地址都不能提供有效地区时保留系统 Region', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async {
        calls.add(baseUrl);
        throw StateError('unavailable');
      },
    );

    final cachedConfig = _config('US');
    final result = await bootstrapper.resolve(
      systemIsChinaUser: true,
      cachedConfig: cachedConfig,
    );

    expect(calls, ['https://china.example', 'https://global.example']);
    expect(result.isChinaUser, isTrue);
    expect(result.source, UserRegionDecisionSource.systemFallback);
    expect(result.configFetched, isFalse);
    expect(result.remoteConfig, cachedConfig);
  });

  test('两个地址均返回无效国家码时使用系统 Region 和最近的有效配置', () async {
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async =>
          _config(baseUrl == 'https://global.example' ? 'XX' : 'unknown'),
    );

    final result = await bootstrapper.resolve(
      systemIsChinaUser: false,
      cachedConfig: RemoteConfig.defaults,
    );

    expect(result.isChinaUser, isFalse);
    expect(result.source, UserRegionDecisionSource.systemFallback);
    expect(result.remoteConfig.context.countryCode, 'unknown');
  });

  test('开发者强制中国区时只访问中国地址，并忽略 Config 国家码', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async {
        calls.add(baseUrl);
        return _config('US');
      },
    );

    final result = await bootstrapper.resolve(
      systemIsChinaUser: false,
      cachedConfig: RemoteConfig.defaults,
      forcedRegion: ServiceEndpointRegion.china,
    );

    expect(calls, ['https://china.example']);
    expect(result.isChinaUser, isTrue);
    expect(result.source, UserRegionDecisionSource.developerOverride);
    expect(result.configFetched, isTrue);
    expect(result.remoteConfig.context.countryCode, 'US');
  });

  test('开发者强制全球区时 Config 拉取失败仍保持全球区并使用缓存', () async {
    final calls = <String>[];
    final bootstrapper = UserRegionBootstrapper(
      endpoints: endpoints,
      fetchRemoteConfig: (baseUrl, _) async {
        calls.add(baseUrl);
        throw StateError('unavailable');
      },
    );

    final cachedConfig = _config('CN');
    final result = await bootstrapper.resolve(
      systemIsChinaUser: true,
      cachedConfig: cachedConfig,
      forcedRegion: ServiceEndpointRegion.global,
    );

    expect(calls, ['https://global.example']);
    expect(result.isChinaUser, isFalse);
    expect(result.source, UserRegionDecisionSource.developerOverride);
    expect(result.configFetched, isFalse);
    expect(result.remoteConfig, cachedConfig);
  });
}

RemoteConfig _config(String? countryCode) => RemoteConfig(
  version: RemoteConfig.currentVersion,
  ttlSeconds: 120,
  context: RemoteConfigContext(countryCode: countryCode),
  features: RemoteConfigFeatures.defaults,
);

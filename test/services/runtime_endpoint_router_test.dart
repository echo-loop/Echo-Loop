import 'package:echo_loop/config/api_config.dart'
    show apiBaseUrl, globalApiBaseUrl;
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_test/flutter_test.dart';

const _expectedChinaApiBaseUrl = String.fromEnvironment(
  'API_CHINA_BASE_URL',
  defaultValue: 'https://www.echo-loop.cn',
);
const _expectedGlobalApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://www.echo-loop.top',
);

const _testEndpoints = RegionalServiceEndpoints(
  globalApiBaseUrl: 'https://global-api.example',
  chinaApiBaseUrl: 'https://china-api.example',
  globalModelCdnBaseUrl: 'https://global-cdn.example',
  chinaModelCdnBaseUrl: 'https://china-cdn.example',
);

void main() {
  test(
    'endpoint registry contains configured global and China URLs',
    () {
      expect(globalApiBaseUrl, _expectedGlobalApiBaseUrl);
      expect(chinaApiBaseUrl, _expectedChinaApiBaseUrl);
      expect(
        regionalServiceEndpoints.apiBaseUrlFor(ServiceEndpointRegion.global),
        apiBaseUrl,
      );
      expect(
        regionalServiceEndpoints.apiBaseUrlFor(ServiceEndpointRegion.china),
        _expectedChinaApiBaseUrl,
      );
      expect(
        regionalServiceEndpoints.modelCdnBaseUrlFor(
          ServiceEndpointRegion.global,
        ),
        'https://cdn.echo-loop.top',
      );
      expect(
        regionalServiceEndpoints.modelCdnBaseUrlFor(
          ServiceEndpointRegion.china,
        ),
        'https://cdn.echo-loop.cn',
      );
    },
  );

  test('non-release routing preserves development API and global CDN', () {
    if (kReleaseMode) return;

    expect(runtimeEndpointRouter.apiBaseUrl, apiBaseUrl);
    expect(
      runtimeEndpointRouter.endpoints.apiBaseUrlFor(
        ServiceEndpointRegion.china,
      ),
      isNull,
    );
    expect(
      runtimeEndpointRouter.endpoints.modelCdnBaseUrlFor(
        ServiceEndpointRegion.china,
      ),
      isNull,
    );
  });

  test('isChinaUser selects China API and CDN', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: true);
    expect(router.preferredApiRegion, ServiceEndpointRegion.china);
    expect(router.apiRegion, ServiceEndpointRegion.global);

    router.markApiRegionAvailable(ServiceEndpointRegion.china);

    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.modelCdnRegion, ServiceEndpointRegion.china);
    expect(router.apiUri('/api/v1/client/config').host, 'china-api.example');
    expect(
      router.modelCdnUri('model/asr/silero-vad-v1.zip').host,
      'china-cdn.example',
    );
  });

  test('non-China users select the global endpoints', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: false);

    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);
    expect(router.apiUri('/health').host, 'global-api.example');
    expect(
      router.modelCdnUri('/dictionary/resource.zip').host,
      'global-cdn.example',
    );

    router.updateFromUserRegion(isChinaUser: false);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);
  });

  test('missing China endpoints fall back to global', () {
    const endpointsWithoutChina = RegionalServiceEndpoints(
      globalApiBaseUrl: 'https://global-api.example',
      chinaApiBaseUrl: '',
      globalModelCdnBaseUrl: 'https://global-cdn.example',
      chinaModelCdnBaseUrl: '',
    );
    final router = RuntimeEndpointRouter(endpoints: endpointsWithoutChina)
      ..updateFromUserRegion(isChinaUser: true);

    expect(router.preferredApiRegion, ServiceEndpointRegion.global);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);
    expect(router.alternateApiRegion, isNull);
  });

  test('API fallback changes active route but keeps UserRegion preference', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: true);

    expect(router.preferredApiRegion, ServiceEndpointRegion.china);
    expect(router.apiRegion, ServiceEndpointRegion.global);

    expect(router.markApiRegionAvailable(ServiceEndpointRegion.china), isTrue);
    expect(router.apiRegion, ServiceEndpointRegion.china);

    expect(router.markApiRegionAvailable(ServiceEndpointRegion.global), isTrue);
    expect(router.preferredApiRegion, ServiceEndpointRegion.china);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.apiBaseUrl, 'https://global-api.example');
    expect(router.modelCdnBaseUrl, 'https://china-cdn.example');

    // 同一 UserRegion 状态刷新时保留已验证可用的备用 API。
    router.updateFromUserRegion(isChinaUser: true);
    expect(router.apiRegion, ServiceEndpointRegion.global);

    // 首选 API 后续探测成功时，清除回退并恢复地区首选路由。
    router.markApiRegionAvailable(ServiceEndpointRegion.china);
    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.apiBaseUrl, 'https://china-api.example');
  });

  test('UserRegion 改变时保留当前 API，直到配置验证新首选区域', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: true);
    router.markApiRegionAvailable(ServiceEndpointRegion.china);

    router.updateFromUserRegion(isChinaUser: false);

    expect(router.preferredApiRegion, ServiceEndpointRegion.global);
    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);

    router.markApiRegionAvailable(ServiceEndpointRegion.global);
    expect(router.apiRegion, ServiceEndpointRegion.global);
  });
}

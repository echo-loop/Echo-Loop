import 'package:echo_loop/config/api_config.dart'
    show apiBaseUrl, globalApiBaseUrl;
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
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
  test('endpoint registry contains configured global and China URLs', () {
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
      regionalServiceEndpoints.modelCdnBaseUrlFor(ServiceEndpointRegion.global),
      'https://cdn.echo-loop.top',
    );
    expect(
      regionalServiceEndpoints.modelCdnBaseUrlFor(ServiceEndpointRegion.china),
      'https://cdn.echo-loop.cn',
    );
  });

  test('runtime router retains configured China API and CDN endpoints', () {
    expect(runtimeEndpointRouter.apiBaseUrl, apiBaseUrl);
    expect(
      runtimeEndpointRouter.endpoints.apiBaseUrlFor(
        ServiceEndpointRegion.china,
      ),
      _expectedChinaApiBaseUrl,
    );
    expect(
      runtimeEndpointRouter.endpoints.modelCdnBaseUrlFor(
        ServiceEndpointRegion.china,
      ),
      'https://cdn.echo-loop.cn',
    );
  });

  test('China system region immediately selects China API and CDN', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: true);

    expect(router.isChinaUser, isTrue);
    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.modelCdnRegion, ServiceEndpointRegion.china);
    expect(router.apiBaseUrl, 'https://china-api.example');
    expect(router.apiUri('/api/v1/client/config').host, 'china-api.example');
    expect(router.modelCdnBaseUrl, 'https://china-cdn.example');
    expect(
      router.modelCdnUri('model/asr/silero-vad-v1.zip').host,
      'china-cdn.example',
    );
  });

  test('non-China users select the global endpoints', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: false);

    expect(router.isChinaUser, isFalse);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);
    expect(router.apiUri('/health').host, 'global-api.example');
    expect(
      router.modelCdnUri('/dictionary/resource.zip').host,
      'global-cdn.example',
    );
  });

  test('a region change immediately switches both API and CDN', () {
    final router = RuntimeEndpointRouter(endpoints: _testEndpoints)
      ..updateFromUserRegion(isChinaUser: true);
    expect(router.apiRegion, ServiceEndpointRegion.china);

    router.updateFromUserRegion(isChinaUser: false);

    expect(router.isChinaUser, isFalse);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);
    expect(router.apiBaseUrl, 'https://global-api.example');
    expect(router.modelCdnBaseUrl, 'https://global-cdn.example');
  });

  test('missing selected China endpoints report configuration errors', () {
    const endpointsWithoutChina = RegionalServiceEndpoints(
      globalApiBaseUrl: 'https://global-api.example',
      chinaApiBaseUrl: '',
      globalModelCdnBaseUrl: 'https://global-cdn.example',
      chinaModelCdnBaseUrl: '',
    );
    final router = RuntimeEndpointRouter(endpoints: endpointsWithoutChina)
      ..updateFromUserRegion(isChinaUser: true);

    expect(() => router.apiBaseUrl, throwsA(isA<StateError>()));
    expect(() => router.apiUri('/health'), throwsA(isA<StateError>()));
    expect(() => router.modelCdnBaseUrl, throwsA(isA<StateError>()));
    expect(() => router.modelCdnUri('/model.zip'), throwsA(isA<StateError>()));
  });
}

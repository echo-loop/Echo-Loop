import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import './helpers/mock_providers.dart';

const _endpoints = RegionalServiceEndpoints(
  globalApiBaseUrl: 'https://global-api.example',
  chinaApiBaseUrl: 'https://china-api.example',
  globalStaticCdnBaseUrl: 'https://global-cdn.example',
  chinaStaticCdnBaseUrl: 'https://china-cdn.example',
);

class _NoRefreshRemoteConfigController extends RemoteConfigController {
  _NoRefreshRemoteConfigController()
    : super(
        readService: () => throw StateError('Remote Config is disabled here'),
        initialConfig: RemoteConfig.defaults,
      );

  @override
  void startPeriodicRefresh({
    bool forceFirst = false,
    bool skipInitialRequest = false,
  }) {}

  @override
  Future<void> refreshIfStale({bool force = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('resume does not change the process region snapshot', (
    tester,
  ) async {
    var systemCountryCode = 'CN';
    final router = RuntimeEndpointRouter(endpoints: _endpoints);

    await pumpFullApp(
      tester,
      overrides: dedupeOverrides([
        remoteConfigProvider.overrideWith(
          (ref) => _NoRefreshRemoteConfigController(),
        ),
        userRegionDeviceCountryCodeProvider.overrideWithValue(
          () => systemCountryCode,
        ),
        userRegionEndpointRouterProvider.overrideWithValue(router),
      ]),
    );

    expect(router.apiRegion, ServiceEndpointRegion.china);

    systemCountryCode = 'US';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.apiBaseUrl, _endpoints.chinaApiBaseUrl);

    // 清理测试应用首帧后安排的延迟任务。
    await tester.pump(const Duration(seconds: 6));
  });
}

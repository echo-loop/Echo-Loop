import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/config/client_distribution.dart'
    show ClientPaymentChannel;
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config_service.dart';
import 'package:echo_loop/features/remote_config/remote_config_store.dart';
import 'package:echo_loop/features/subscription/services/purchase_service.dart';
import 'package:echo_loop/features/subscription/services/revenuecat_purchase_service.dart'
    show purchaseServiceProvider;
import 'package:echo_loop/features/user_region/user_region.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

class _FakePurchaseService extends StubPurchaseService {
  _FakePurchaseService(this._readStorefront);

  final Future<String?> Function() _readStorefront;
  int storefrontReads = 0;

  @override
  Future<String?> storefrontCountryCode() {
    storefrontReads += 1;
    return _readStorefront();
  }
}

RemoteConfig _config(String countryCode) => RemoteConfig(
  version: 1,
  ttlSeconds: 60,
  context: RemoteConfigContext(countryCode: countryCode),
  features: RemoteConfigFeatures.defaults,
);

void main() {
  group('UserRegionController', () {
    test('任一中国证据都会判定为中国用户', () async {
      final service = _FakePurchaseService(() async => 'CHN');
      final controller = UserRegionController(
        readPurchaseService: () => service,
        readDeviceCountryCode: () => 'US',
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      await controller.refresh(UserRegionRefreshTrigger.startup);

      expect(controller.state.isChinaUser, isTrue);
      expect(controller.state.matchedSources, [UserRegionEvidence.storefront]);
      expect(controller.state.storefront.countryCode, 'CHN');
    });

    test('系统地区为 CN 时不需要等待 Storefront 也立即命中', () {
      final controller = UserRegionController(
        readPurchaseService: () => _FakePurchaseService(() async => 'US'),
        readDeviceCountryCode: () => 'CN',
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      expect(controller.state.isChinaUser, isTrue);
      expect(controller.state.matchedSources, [
        UserRegionEvidence.deviceRegion,
      ]);
    });

    test('只设置中文语言但没有国家码不视为中国', () {
      final controller = UserRegionController(
        readPurchaseService: () => _FakePurchaseService(() async => null),
        readDeviceCountryCode: () => null,
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      expect(controller.state.isChinaUser, isFalse);
    });

    test('Client Config 国家码未知时不伪造国家或命中中国', () {
      final unknownConfig = RemoteConfig.fromJson({
        'context': {'countryCode': null},
      });
      final controller = UserRegionController(
        readPurchaseService: () => _FakePurchaseService(() async => null),
        readDeviceCountryCode: () => null,
        isAppleStoreChannel: false,
        initialRemoteConfig: unknownConfig,
      );
      addTearDown(controller.dispose);

      expect(controller.state.clientConfig.countryCode, isNull);
      expect(controller.state.isChinaUser, isFalse);
    });

    test('单项失败不阻断其他策略，全部未命中默认国际', () async {
      final controller = UserRegionController(
        readPurchaseService: () => _FakePurchaseService(
          () => throw StateError('storefront unavailable'),
        ),
        readDeviceCountryCode: () => throw StateError('locale unavailable'),
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      await controller.refresh(UserRegionRefreshTrigger.startup);

      expect(controller.state.isChinaUser, isFalse);
      expect(controller.state.storefront.status, UserRegionSourceStatus.failed);
      expect(
        controller.state.deviceRegion.status,
        UserRegionSourceStatus.failed,
      );
      expect(
        controller.state.clientConfig.status,
        UserRegionSourceStatus.available,
      );
    });

    test('非 Apple StoreKit 渠道跳过 Storefront', () async {
      final service = _FakePurchaseService(() async => 'CHN');
      final controller = UserRegionController(
        readPurchaseService: () => service,
        readDeviceCountryCode: () => 'US',
        isAppleStoreChannel: false,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      await controller.refresh(UserRegionRefreshTrigger.resume);

      expect(service.storefrontReads, 0);
      expect(
        controller.state.storefront.status,
        UserRegionSourceStatus.skipped,
      );
      expect(controller.state.isChinaUser, isFalse);
    });

    test('并发 refresh 复用同一次 Storefront 查询', () async {
      final completer = Completer<String?>();
      final service = _FakePurchaseService(() => completer.future);
      final controller = UserRegionController(
        readPurchaseService: () => service,
        readDeviceCountryCode: () => 'US',
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      final first = controller.refresh(UserRegionRefreshTrigger.startup);
      final second = controller.refresh(UserRegionRefreshTrigger.resume);
      completer.complete('US');
      await Future.wait([first, second]);

      expect(service.storefrontReads, 1);
    });

    test('Client Config 更新只重算缓存结论，不重复读取 Storefront', () async {
      final service = _FakePurchaseService(() async => 'US');
      final controller = UserRegionController(
        readPurchaseService: () => service,
        readDeviceCountryCode: () => 'US',
        isAppleStoreChannel: true,
        initialRemoteConfig: _config('US'),
      );
      addTearDown(controller.dispose);

      await controller.refresh(UserRegionRefreshTrigger.startup);
      controller.updateClientConfig(_config('CN'));

      expect(controller.state.isChinaUser, isTrue);
      expect(controller.state.matchedSources, [
        UserRegionEvidence.clientConfig,
      ]);
      expect(service.storefrontReads, 1);
    });
  });

  test('冷启动缓存的中国配置设为首选且 CDN 立即切换', () {
    final router = RuntimeEndpointRouter(
      endpoints: const RegionalServiceEndpoints(
        globalApiBaseUrl: 'https://global-api.example',
        chinaApiBaseUrl: 'https://china-api.example',
        globalModelCdnBaseUrl: 'https://global-cdn.example',
        chinaModelCdnBaseUrl: 'https://china-cdn.example',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        initialRemoteConfigProvider.overrideWithValue(_config('CN')),
        userRegionPaymentChannelProvider.overrideWithValue(
          ClientPaymentChannel.web,
        ),
        userRegionDeviceCountryCodeProvider.overrideWithValue(() => 'US'),
        userRegionEndpointRouterProvider.overrideWithValue(router),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isChinaUserProvider), isTrue);
    expect(router.preferredApiRegion, ServiceEndpointRegion.china);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.china);
  });

  test('Apple Storefront 国家更新通过 isChinaUser 切换 API 和 CDN', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final purchaseService = _FakePurchaseService(() async => 'CHN');
    final router = RuntimeEndpointRouter(
      endpoints: const RegionalServiceEndpoints(
        globalApiBaseUrl: 'https://global-api.example',
        chinaApiBaseUrl: 'https://china-api.example',
        globalModelCdnBaseUrl: 'https://global-cdn.example',
        chinaModelCdnBaseUrl: 'https://china-cdn.example',
      ),
    );
    const configUrl = 'https://china-api.example/api/v1/client/config';
    final dio = _MockDio();
    when(
      () => dio.get<Object?>(
        configUrl,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response<Object?>(
        requestOptions: RequestOptions(path: configUrl),
        statusCode: 200,
        data: {
          'version': 1,
          'ttlSeconds': 120,
          'context': {'countryCode': 'CN'},
        },
      ),
    );
    final service = RemoteConfigService(
      dio: dio,
      store: RemoteConfigStore(prefs),
      endpointRouter: router,
    );
    final container = ProviderContainer(
      overrides: [
        initialRemoteConfigProvider.overrideWithValue(_config('US')),
        remoteConfigServiceProvider.overrideWithValue(service),
        userRegionPaymentChannelProvider.overrideWithValue(
          ClientPaymentChannel.appleStore,
        ),
        userRegionDeviceCountryCodeProvider.overrideWithValue(() => 'US'),
        userRegionEndpointRouterProvider.overrideWithValue(router),
        purchaseServiceProvider.overrideWithValue(purchaseService),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(isChinaUserProvider), isFalse);
    expect(router.apiRegion, ServiceEndpointRegion.global);
    expect(router.modelCdnRegion, ServiceEndpointRegion.global);

    await container
        .read(userRegionProvider.notifier)
        .refresh(UserRegionRefreshTrigger.startup);
    await pumpEventQueue();

    expect(container.read(isChinaUserProvider), isTrue);
    expect(router.apiRegion, ServiceEndpointRegion.china);
    expect(router.modelCdnRegion, ServiceEndpointRegion.china);
    verify(
      () => dio.get<Object?>(
        configUrl,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).called(1);
  });
}

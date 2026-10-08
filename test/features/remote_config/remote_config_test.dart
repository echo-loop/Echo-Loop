import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/config/client_distribution.dart'
    show ClientPaymentChannel;
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config_service.dart';
import 'package:echo_loop/features/remote_config/remote_config_store.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

class _QueuedResponse {
  const _QueuedResponse({this.statusCode = 200, this.body, this.errorType});

  final int statusCode;
  final Object? body;
  final DioExceptionType? errorType;
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<_QueuedResponse> _responses;
  final requestUris = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestUris.add(options.uri);
    final response = _responses.removeAt(0);
    final errorType = response.errorType;
    if (errorType != null) {
      throw DioException(
        requestOptions: options,
        type: errorType,
        error: StateError('simulated transport failure'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _remoteConfigBody(String countryCode) => {
  'version': RemoteConfig.currentVersion,
  'ttlSeconds': 120,
  'context': {'countryCode': countryCode},
  'features': RemoteConfigFeatures.defaults.toJson(),
};

RemoteConfig _config(String countryCode) => RemoteConfig(
  version: RemoteConfig.currentVersion,
  ttlSeconds: 120,
  context: RemoteConfigContext(countryCode: countryCode),
  features: RemoteConfigFeatures.defaults,
);

void main() {
  Response<Object?> response(Object? data) => Response<Object?>(
    requestOptions: RequestOptions(path: '/api/v1/client/config'),
    statusCode: 200,
    data: data,
  );

  group('RemoteConfig', () {
    test('解析 V1 schema 并读取从网盘导入开关', () {
      final config = RemoteConfig.fromJson({
        'version': 1,
        'ttlSeconds': 600,
        'context': {
          'countryCode': 'CN',
          'platform': 'ios',
          'channel': 'app_store',
        },
        'features': {
          'cloudDriveImport': {'enabled': true, 'ignored': 'x'},
          'showStoreWebCheckoutFallback': {'enabled': true},
          'aiChatAssistant': {'enabled': false},
        },
        'limits': {
          'transcription': {
            'maxDurationSeconds': 3600,
            'maxUploadBytes': 104857600,
          },
        },
        'ignoredRoot': true,
      });

      expect(config.version, 1);
      expect(config.ttlSeconds, 600);
      expect(config.context.countryCode, 'CN');
      expect(config.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      expect(
        config.isEnabled(RemoteFeature.showStoreWebCheckoutFallback),
        isTrue,
      );
      expect(config.isEnabled(RemoteFeature.aiChatAssistant), isFalse);
      expect(config.transcriptionLimits.maxDurationSeconds, 3600);
      expect(config.transcriptionLimits.maxUploadBytes, 104857600);
    });

    test('countryCode 缺失、无效或 unknown 时保留为未知', () {
      expect(RemoteConfig.fromJson({}).context.countryCode, isNull);

      final contexts = <Map<String, Object?>>[
        {},
        {'countryCode': null},
        {'countryCode': 123},
        {'countryCode': ''},
        {'countryCode': '  '},
        {'countryCode': 'unknown'},
        {'countryCode': 'UNKNOWN'},
      ];

      for (final context in contexts) {
        final config = RemoteConfig.fromJson({'context': context});
        expect(config.context.countryCode, isNull, reason: '$context');
      }

      final validCountry = RemoteConfig.fromJson({
        'context': {'countryCode': ' CN '},
      });
      expect(validCountry.context.countryCode, 'CN');
    });

    test('缺字段和未知版本回退本地默认，网盘导入和 AI 聊天入口默认开启', () {
      final missing = RemoteConfig.fromJson({'version': 1});
      expect(missing.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      expect(
        missing.isEnabled(RemoteFeature.showStoreWebCheckoutFallback),
        isFalse,
      );
      expect(missing.isEnabled(RemoteFeature.aiChatAssistant), isTrue);
      expect(missing.ttlSeconds, RemoteConfig.defaultTtlSeconds);
      expect(RemoteConfig.defaultTtlSeconds, 86400);
      expect(
        missing.transcriptionLimits.maxDurationSeconds,
        RemoteTranscriptionLimits.defaultMaxDurationSeconds,
      );
      expect(
        missing.transcriptionLimits.maxUploadBytes,
        RemoteTranscriptionLimits.defaultMaxUploadBytes,
      );

      final unknownVersion = RemoteConfig.fromJson({
        'version': 99,
        'features': {
          'cloudDriveImport': {'enabled': true},
        },
      });
      expect(unknownVersion.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      expect(unknownVersion.isEnabled(RemoteFeature.aiChatAssistant), isTrue);
    });

    test('转录限制字段非法时逐项回退本地默认', () {
      final config = RemoteConfig.fromJson({
        'version': 1,
        'limits': {
          'transcription': {'maxDurationSeconds': 0, 'maxUploadBytes': 1024},
        },
      });

      expect(
        config.transcriptionLimits.maxDurationSeconds,
        RemoteTranscriptionLimits.defaultMaxDurationSeconds,
      );
      expect(config.transcriptionLimits.maxUploadBytes, 1024);
    });
  });

  group('RemoteConfigStore', () {
    test('TTL 内命中缓存，过期后不返回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      final now = DateTime(2026, 7, 19, 14);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'CN'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: true),
          ),
        ),
        now: now,
      );

      expect(
        store
            .readCached(now: now.add(const Duration(seconds: 59)))
            ?.isEnabled(RemoteFeature.cloudDriveImport),
        isTrue,
      );
      expect(
        store.readCached(now: now.add(const Duration(seconds: 61))),
        isNull,
      );
      expect(
        store
            .readCached(
              now: now.add(const Duration(seconds: 61)),
              allowExpired: true,
            )
            ?.isEnabled(RemoteFeature.cloudDriveImport),
        isTrue,
      );
    });
  });

  group('RemoteConfigService', () {
    test('启动初始加载使用过期缓存且不触发后端请求', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 1,
          context: RemoteConfigContext(countryCode: 'CN'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: true),
          ),
        ),
        now: DateTime(2026, 7, 19, 14),
      );

      final dio = _MockDio();
      final service = RemoteConfigService(
        dio: dio,
        store: store,
        now: () => DateTime(2026, 7, 19, 14, 1),
      );

      final config = service.loadInitialFromCache();

      expect(config.context.countryCode, 'CN');
      expect(config.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      verifyNever(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    });

    test('启动初始加载在缓存缺失或损坏时回退默认值', () async {
      SharedPreferences.setMockInitialValues({});
      final emptyPrefs = await SharedPreferences.getInstance();
      final emptyService = RemoteConfigService(
        dio: _MockDio(),
        store: RemoteConfigStore(emptyPrefs),
      );

      expect(emptyService.loadInitialFromCache(), RemoteConfig.defaults);

      SharedPreferences.setMockInitialValues({
        'remote_config_payload_v1': '{broken json',
        'remote_config_fetched_at_ms_v1': DateTime(
          2026,
          7,
          19,
          14,
        ).millisecondsSinceEpoch,
      });
      final brokenPrefs = await SharedPreferences.getInstance();
      final brokenService = RemoteConfigService(
        dio: _MockDio(),
        store: RemoteConfigStore(brokenPrefs),
      );

      expect(brokenService.loadInitialFromCache(), RemoteConfig.defaults);
    });

    test('缓存过期后请求后端并写入新配置', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => response({
          'version': 1,
          'ttlSeconds': 3600,
          'context': {'countryCode': 'CN'},
          'features': {
            'cloudDriveImport': {'enabled': true},
          },
        }),
      );

      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        now: () => DateTime(2026, 7, 19, 14),
      );

      final config = await service.load();

      expect(config.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      expect(
        RemoteConfigStore(prefs).readCached(now: DateTime(2026, 7, 19, 14, 30)),
        isNotNull,
      );
    });

    test('网络失败时使用过期缓存，无缓存时回退默认', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 1,
          context: RemoteConfigContext(countryCode: 'CN'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: true),
          ),
        ),
        now: DateTime(2026, 7, 19, 14),
      );

      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '/')));

      final service = RemoteConfigService(
        dio: dio,
        store: store,
        now: () => DateTime(2026, 7, 19, 14, 1),
      );

      final expired = await service.load();
      expect(expired.isEnabled(RemoteFeature.cloudDriveImport), isTrue);

      SharedPreferences.setMockInitialValues({});
      final emptyPrefs = await SharedPreferences.getInstance();
      final fallback = await RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(emptyPrefs),
        now: () => DateTime(2026, 7, 19, 14, 1),
      ).load();
      expect(fallback.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
    });

    test('fetchRemote 直接触网并覆盖未过期缓存', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 3600,
          context: RemoteConfigContext(countryCode: 'US'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: false),
          ),
        ),
        now: DateTime(2026, 7, 19, 14),
      );

      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => response({
          'version': 1,
          'ttlSeconds': 120,
          'context': {'countryCode': 'CN'},
          'features': {
            'cloudDriveImport': {'enabled': true},
          },
        }),
      );
      final service = RemoteConfigService(
        dio: dio,
        store: store,
        now: () => DateTime(2026, 7, 19, 14, 1),
      );

      final config = await service.fetchRemote();

      expect(config.context.countryCode, 'CN');
      expect(config.isEnabled(RemoteFeature.cloudDriveImport), isTrue);
      verify(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
    });

    test(
      'preferred API failure falls back, then a later refresh probes preference',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final router = RuntimeEndpointRouter(
          endpoints: const RegionalServiceEndpoints(
            globalApiBaseUrl: 'https://global-api.example',
            chinaApiBaseUrl: 'https://china-api.example',
            globalModelCdnBaseUrl: 'https://global-cdn.example',
            chinaModelCdnBaseUrl: 'https://china-cdn.example',
          ),
        )..updateFromUserRegion(isChinaUser: true);
        final adapter = _QueueAdapter([
          _QueuedResponse(statusCode: 503, body: {'error': 'unavailable'}),
          _QueuedResponse(statusCode: 200, body: _remoteConfigBody('CN')),
          _QueuedResponse(statusCode: 200, body: _remoteConfigBody('CN')),
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final service = RemoteConfigService(
          dio: dio,
          store: RemoteConfigStore(prefs),
          endpointRouter: router,
        );

        await service.fetchRemote();
        expect(adapter.requestUris.map((uri) => uri.host), [
          'china-api.example',
          'global-api.example',
        ]);
        expect(router.preferredApiRegion, ServiceEndpointRegion.china);
        expect(router.apiRegion, ServiceEndpointRegion.global);

        await service.fetchRemote();
        expect(adapter.requestUris.last.host, 'china-api.example');
        expect(router.apiRegion, ServiceEndpointRegion.china);
      },
    );

    test('client errors do not fall back to the alternate API', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = RuntimeEndpointRouter(
        endpoints: const RegionalServiceEndpoints(
          globalApiBaseUrl: 'https://global-api.example',
          chinaApiBaseUrl: 'https://china-api.example',
          globalModelCdnBaseUrl: 'https://global-cdn.example',
          chinaModelCdnBaseUrl: 'https://china-cdn.example',
        ),
      )..updateFromUserRegion(isChinaUser: true);
      final adapter = _QueueAdapter([
        _QueuedResponse(statusCode: 401, body: {'error': 'unauthorized'}),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        endpointRouter: router,
      );

      await expectLater(service.fetchRemote(), throwsA(isA<DioException>()));

      expect(adapter.requestUris, hasLength(1));
      expect(adapter.requestUris.single.host, 'china-api.example');
      expect(router.preferredApiRegion, ServiceEndpointRegion.china);
      expect(router.apiRegion, ServiceEndpointRegion.global);
    });

    test('transport failure falls back to the alternate API', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = RuntimeEndpointRouter(
        endpoints: const RegionalServiceEndpoints(
          globalApiBaseUrl: 'https://global-api.example',
          chinaApiBaseUrl: 'https://china-api.example',
          globalModelCdnBaseUrl: 'https://global-cdn.example',
          chinaModelCdnBaseUrl: 'https://china-cdn.example',
        ),
      )..updateFromUserRegion(isChinaUser: true);
      final adapter = _QueueAdapter([
        _QueuedResponse(errorType: DioExceptionType.connectionError),
        _QueuedResponse(body: _remoteConfigBody('CN')),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        endpointRouter: router,
      );

      await service.fetchRemote();

      expect(adapter.requestUris.map((uri) => uri.host), [
        'china-api.example',
        'global-api.example',
      ]);
      expect(router.preferredApiRegion, ServiceEndpointRegion.china);
      expect(router.apiRegion, ServiceEndpointRegion.global);
    });

    test(
      'both API regions failing preserves the active route and cached config',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = RemoteConfigStore(prefs);
        await store.write(_config('US'));
        final router = RuntimeEndpointRouter(
          endpoints: const RegionalServiceEndpoints(
            globalApiBaseUrl: 'https://global-api.example',
            chinaApiBaseUrl: 'https://china-api.example',
            globalModelCdnBaseUrl: 'https://global-cdn.example',
            chinaModelCdnBaseUrl: 'https://china-cdn.example',
          ),
        )..updateFromUserRegion(isChinaUser: true);
        router.markApiRegionAvailable(ServiceEndpointRegion.global);
        final adapter = _QueueAdapter([
          _QueuedResponse(statusCode: 503, body: {'error': 'unavailable'}),
          _QueuedResponse(statusCode: 503, body: {'error': 'unavailable'}),
        ]);
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(dio.close);
        final service = RemoteConfigService(
          dio: dio,
          store: store,
          endpointRouter: router,
        );

        await expectLater(service.fetchRemote(), throwsA(isA<DioException>()));

        expect(adapter.requestUris, hasLength(2));
        expect(router.apiRegion, ServiceEndpointRegion.global);
        expect(store.readCached(allowExpired: true)?.context.countryCode, 'US');
      },
    );
  });

  group('RemoteConfigController', () {
    test('TTL 内 refreshIfStale 不触发后端请求', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'US'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: false),
          ),
        ),
        now: DateTime(2026, 7, 19, 14),
      );

      final dio = _MockDio();
      final service = RemoteConfigService(
        dio: dio,
        store: store,
        now: () => DateTime(2026, 7, 19, 14, 0, 30),
      );
      final controller = RemoteConfigController(
        readService: () => service,
        initialConfig: const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'US'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: false),
          ),
        ),
        now: () => DateTime(2026, 7, 19, 14, 0, 30),
      );

      await controller.refreshIfStale();

      expect(controller.state.isEnabled(RemoteFeature.cloudDriveImport), false);
      verifyNever(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      );
      controller.dispose();
    });

    test('startPeriodicRefresh forceFirst 会忽略未过期 TTL 刷新一次', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = RemoteConfigStore(prefs);
      await store.write(
        const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'US'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: false),
          ),
        ),
        now: DateTime(2026, 7, 19, 14),
      );

      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => response({
          'version': 1,
          'ttlSeconds': 120,
          'context': {'countryCode': 'CN'},
          'features': {
            'cloudDriveImport': {'enabled': true},
          },
        }),
      );
      final service = RemoteConfigService(
        dio: dio,
        store: store,
        now: () => DateTime(2026, 7, 19, 14, 0, 30),
      );
      final controller = RemoteConfigController(
        readService: () => service,
        initialConfig: const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'US'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: false),
          ),
        ),
        now: () => DateTime(2026, 7, 19, 14, 0, 30),
      );

      controller.startPeriodicRefresh(forceFirst: true);
      await pumpEventQueue();

      expect(controller.state.context.countryCode, 'CN');
      expect(controller.state.isEnabled(RemoteFeature.cloudDriveImport), true);
      verify(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
      controller.dispose();
    });

    test('TTL 过期后刷新成功会更新 feature provider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => response({
          'version': 1,
          'ttlSeconds': 120,
          'context': {'countryCode': 'CN'},
          'features': {
            'cloudDriveImport': {'enabled': true},
          },
        }),
      );
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        now: () => DateTime(2026, 7, 19, 14, 2),
      );
      final container = ProviderContainer(
        overrides: [
          initialRemoteConfigProvider.overrideWithValue(
            const RemoteConfig(
              version: 1,
              ttlSeconds: 120,
              context: RemoteConfigContext(countryCode: 'US'),
              features: RemoteConfigFeatures(
                cloudDriveImport: RemoteFeatureConfig(enabled: false),
              ),
            ),
          ),
          remoteConfigServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(
          remoteFeatureEnabledProvider(RemoteFeature.cloudDriveImport),
        ),
        isFalse,
      );

      await container.read(remoteConfigProvider.notifier).refreshIfStale();

      expect(
        container.read(
          remoteFeatureEnabledProvider(RemoteFeature.cloudDriveImport),
        ),
        isTrue,
      );
    });

    test('Client Config 刷新通过 isChinaUser 更新 API 和 CDN 区域', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = RuntimeEndpointRouter(
        endpoints: const RegionalServiceEndpoints(
          globalApiBaseUrl: 'https://global-api.example',
          chinaApiBaseUrl: 'https://china-api.example',
          globalModelCdnBaseUrl: 'https://global-cdn.example',
          chinaModelCdnBaseUrl: 'https://china-cdn.example',
        ),
      );
      final adapter = _QueueAdapter([
        _QueuedResponse(body: _remoteConfigBody('CN')),
        _QueuedResponse(statusCode: 503, body: {'error': 'unavailable'}),
        _QueuedResponse(body: _remoteConfigBody('CN')),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        endpointRouter: router,
      );
      final container = ProviderContainer(
        overrides: [
          initialRemoteConfigProvider.overrideWithValue(_config('US')),
          remoteConfigServiceProvider.overrideWithValue(service),
          userRegionDeviceCountryCodeProvider.overrideWithValue(() => 'US'),
          userRegionPaymentChannelProvider.overrideWithValue(
            ClientPaymentChannel.web,
          ),
          userRegionEndpointRouterProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(isChinaUserProvider), isFalse);
      expect(router.apiRegion, ServiceEndpointRegion.global);
      expect(router.modelCdnRegion, ServiceEndpointRegion.global);

      await container
          .read(remoteConfigProvider.notifier)
          .refreshIfStale(force: true);

      expect(container.read(isChinaUserProvider), isTrue);
      expect(adapter.requestUris.map((uri) => uri.host), [
        'global-api.example',
        'china-api.example',
        'global-api.example',
      ]);
      expect(router.preferredApiRegion, ServiceEndpointRegion.china);
      expect(router.apiRegion, ServiceEndpointRegion.global);
      expect(router.modelCdnRegion, ServiceEndpointRegion.china);
    });

    test('transcription limits provider 暴露远程限制值', () {
      final container = ProviderContainer(
        overrides: [
          initialRemoteConfigProvider.overrideWithValue(
            const RemoteConfig(
              version: 1,
              ttlSeconds: 60,
              context: RemoteConfigContext(countryCode: 'US'),
              features: RemoteConfigFeatures.defaults,
              transcriptionLimits: RemoteTranscriptionLimits(
                maxDurationSeconds: 300,
                maxUploadBytes: 1048576,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final limits = container.read(remoteTranscriptionLimitsProvider);

      expect(limits.maxDurationSeconds, 300);
      expect(limits.maxUploadBytes, 1048576);
    });

    test('feature provider 暴露 AI 聊天助手开关', () {
      final container = ProviderContainer(
        overrides: [
          initialRemoteConfigProvider.overrideWithValue(
            const RemoteConfig(
              version: 1,
              ttlSeconds: 60,
              context: RemoteConfigContext(countryCode: 'US'),
              features: RemoteConfigFeatures(
                aiChatAssistant: RemoteFeatureConfig(enabled: false),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(
          remoteFeatureEnabledProvider(RemoteFeature.aiChatAssistant),
        ),
        isFalse,
      );
    });

    test('并发刷新只发起一次后端请求', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = _MockDio();
      final completer = Completer<Response<Object?>>();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) => completer.future);
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        now: () => DateTime(2026, 7, 19, 14, 2),
      );
      final controller = RemoteConfigController(
        readService: () => service,
        initialConfig: RemoteConfig.defaults,
        now: () => DateTime(2026, 7, 19, 14, 2),
      );

      final first = controller.refreshIfStale();
      final second = controller.refreshIfStale();
      completer.complete(
        response({
          'version': 1,
          'ttlSeconds': 120,
          'context': {'countryCode': 'CN'},
          'features': {
            'cloudDriveImport': {'enabled': true},
          },
        }),
      );
      await Future.wait([first, second]);

      verify(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).called(1);
      expect(controller.state.isEnabled(RemoteFeature.cloudDriveImport), true);
      controller.dispose();
    });

    test('网络失败时保留旧内存配置', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = _MockDio();
      when(
        () => dio.get<Object?>(
          '/api/v1/client/config',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions(path: '/')));
      final service = RemoteConfigService(
        dio: dio,
        store: RemoteConfigStore(prefs),
        now: () => DateTime(2026, 7, 19, 14, 2),
      );
      final controller = RemoteConfigController(
        readService: () => service,
        initialConfig: const RemoteConfig(
          version: 1,
          ttlSeconds: 60,
          context: RemoteConfigContext(countryCode: 'CN'),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(enabled: true),
          ),
        ),
        now: () => DateTime(2026, 7, 19, 14, 2),
      );

      await controller.refreshIfStale();

      expect(controller.state.isEnabled(RemoteFeature.cloudDriveImport), true);
      controller.dispose();
    });
  });
}

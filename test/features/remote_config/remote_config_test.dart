import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config_service.dart';
import 'package:echo_loop/features/remote_config/remote_config_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDio extends Mock implements Dio {}

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

    test('缺字段和未知版本回退本地默认，AI 聊天入口默认开启', () {
      final missing = RemoteConfig.fromJson({'version': 1});
      expect(missing.isEnabled(RemoteFeature.cloudDriveImport), isFalse);
      expect(
        missing.isEnabled(RemoteFeature.showStoreWebCheckoutFallback),
        isFalse,
      );
      expect(missing.isEnabled(RemoteFeature.aiChatAssistant), isTrue);
      expect(missing.ttlSeconds, RemoteConfig.defaultTtlSeconds);
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
      expect(unknownVersion.isEnabled(RemoteFeature.cloudDriveImport), isFalse);
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
      expect(fallback.isEnabled(RemoteFeature.cloudDriveImport), isFalse);
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
          initialRemoteConfigProvider.overrideWithValue(RemoteConfig.defaults),
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

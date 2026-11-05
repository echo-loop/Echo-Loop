import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/services/android_update_bridge.dart';
import 'package:echo_loop/services/app_update_checker.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class FakeAndroidUpdateBridge implements AndroidUpdateBridge {
  String? installer;

  @override
  Future<String?> installerPackageName() async => installer;
}

void main() {
  late MockDio mockDio;
  late AppUpdateChecker checker;

  setUp(() {
    mockDio = MockDio();
    checker = AppUpdateChecker.withDio(mockDio);
  });

  group('AppUpdateChecker.check', () {
    test('成功解析有效 JSON', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '1.1.0',
            'minimumVersion': '1.0.0',
            'releaseNotes': {'en': 'Bug fixes'},
            'downloadUrl': {'fallback': 'https://example.com'},
          },
        ),
      );

      final result = await checker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.1.0');
      expect(result.minimumVersion, '1.0.0');
    });

    test('网络错误返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('响应数据为 null 返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: null,
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('JSON 格式错误返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: <String, dynamic>{'invalid': true},
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });

    test('DNS 解析失败返回 null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.unknown,
          error: 'Failed host lookup',
        ),
      );

      final result = await checker.check();
      expect(result, isNull);
    });
  });

  group('AppUpdateChecker.check iOS Lookup API', () {
    late AppUpdateChecker iosChecker;

    setUp(() {
      iosChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: 'top.echo-loop',
        useIosLookup: true,
      );
    });

    /// 桩 iTunes Lookup 响应：iOS 路径强制 ResponseType.plain，data 为字符串
    void stubLookup(Object data) {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data: jsonEncode(data),
        ),
      );
    }

    test('成功解析 Lookup API 响应', () async {
      stubLookup({
        'resultCount': 1,
        'results': [
          {
            'version': '1.0.12',
            'trackViewUrl': 'https://apps.apple.com/app/id6760324074',
            'releaseNotes': 'Bug fixes and improvements',
          },
        ],
      });
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '1.0.12',
            'minimumVersion': '1.0.0',
            'platforms': {
              'ios': {'minimumVersion': '1.0.0'},
            },
          },
        ),
      );

      final result = await iosChecker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
      // 只认 platforms.ios.minimumVersion
      expect(result.minimumVersion, '1.0.0');
      expect(result.channel, AppUpdateChannel.iosAppStore);
      // trackViewUrl 同时作为 ios 和 fallback
      expect(
        result.downloadUrl['ios'],
        'https://apps.apple.com/app/id6760324074',
      );
      expect(
        result.downloadUrl['fallback'],
        'https://apps.apple.com/app/id6760324074',
      );
      // releaseNotes 单语字符串同时映射给 en 和 zh
      expect(result.releaseNotes['en'], 'Bug fixes and improvements');
      expect(result.releaseNotes['zh'], 'Bug fixes and improvements');
    });

    test('results 为空数组返回 null', () async {
      stubLookup({'resultCount': 0, 'results': []});

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('缺少 version 字段返回 null', () async {
      stubLookup({
        'results': [
          {'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('网络错误返回 null', () async {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('bundleId 为空返回 null', () async {
      final emptyChecker = AppUpdateChecker.withDio(
        mockDio,
        bundleId: '',
        useIosLookup: true,
      );

      final result = await emptyChecker.check();
      expect(result, isNull);
      verifyNever(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      );
    });

    test('releaseNotes 缺失时降级为空 Map', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions()));

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.releaseNotes, isEmpty);
    });

    test('trackViewUrl 缺失时使用默认 App Store 链接', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12'},
        ],
      });
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(DioException(requestOptions: RequestOptions()));

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.downloadUrl['ios'], contains('apps.apple.com'));
    });

    test('Content-Type 为 text/javascript 时也能解析（回归测试）', () async {
      // 真实环境 iTunes Lookup 返回 text/javascript，Dio 不会自动 JSON 解码
      // 这里模拟该场景：data 是裸 JSON 字符串而非 Map
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data:
              '{"resultCount":1,"results":[{"version":"1.0.12","trackViewUrl":"https://apps.apple.com/app/id6760324074"}]}',
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
    });

    test('响应不是合法 JSON 返回 null', () async {
      when(
        () => mockDio.get<String>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<String>(
          requestOptions: RequestOptions(),
          data: 'not json at all',
        ),
      );

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('version 不是 String 类型返回 null', () async {
      // 防御 Apple 改 schema：例如 version 变成数字
      stubLookup({
        'results': [
          {'version': 1.2, 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('传入 country 时作为查询参数发出', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      await iosChecker.check(country: 'cn');

      final captured =
          verify(
                () => mockDio.get<String>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map;
      expect(captured['country'], 'cn');
      expect(captured['bundleId'], 'top.echo-loop');
    });

    test('country 为 null 时不带 country 参数', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });

      await iosChecker.check();

      final captured =
          verify(
                () => mockDio.get<String>(
                  any(),
                  queryParameters: captureAny(named: 'queryParameters'),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as Map;
      expect(captured.containsKey('country'), isFalse);
    });

    test('results[0] 不是 Map 返回 null', () async {
      // 防御上游数据脏：results 元素是字符串/数字而非对象
      stubLookup({
        'results': ['unexpected-string-entry'],
      });

      final result = await iosChecker.check();
      expect(result, isNull);
    });

    test('minimumVersion 高于 App Store 可下载版本时不触发强制更新', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '1.0.99',
            'minimumVersion': '1.0.99',
            'platforms': {
              'ios': {'minimumVersion': '1.0.99'},
            },
          },
        ),
      );

      final result = await iosChecker.check();

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.12');
      expect(result.minimumVersion, '0.0.0');
    });

    test('仅顶层 minimumVersion 不波及 iOS（新版本忽略顶层）', () async {
      stubLookup({
        'results': [
          {'version': '1.0.12', 'trackViewUrl': 'https://apps.apple.com/x'},
        ],
      });
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          // 只有顶层 minimumVersion，无 platforms.ios
          data: {'latestVersion': '1.0.12', 'minimumVersion': '1.0.10'},
        ),
      );

      final result = await iosChecker.check();

      expect(result, isNotNull);
      expect(result!.minimumVersion, '0.0.0');
    });
  });

  group('AppUpdateChecker.check Android channels', () {
    late FakeAndroidUpdateBridge bridge;
    late AppUpdateChecker androidChecker;

    RuntimeEndpointRouter buildRouter({required bool isChinaUser}) {
      return RuntimeEndpointRouter(
        endpoints: const RegionalServiceEndpoints(
          globalApiBaseUrl: 'https://global-api.example',
          chinaApiBaseUrl: 'https://china-api.example',
          globalStaticCdnBaseUrl: 'https://global-cdn.example',
          chinaStaticCdnBaseUrl: 'https://china-cdn.example',
        ),
      )..updateFromUserRegion(isChinaUser: isChinaUser);
    }

    AppUpdateChecker buildAndroidChecker({required bool isChinaUser}) {
      return AppUpdateChecker.withDio(
        mockDio,
        platform: AppUpdateRuntimePlatform.android,
        endpointRouter: buildRouter(isChinaUser: isChinaUser),
        androidBridge: bridge,
      );
    }

    setUp(() {
      bridge = FakeAndroidUpdateBridge();
      androidChecker = buildAndroidChecker(isChinaUser: false);
    });

    void stubManifest({bool includeChinaUrl = false}) {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '2.0.0',
            'minimumVersion': '1.5.0',
            'releaseNotes': {'en': 'Bug fixes'},
            'downloadUrl': {
              'android': 'https://cdn.example.com/legacy.apk',
              'androidApk': 'https://cdn.example.com/app.apk',
              'fallback': 'https://example.com',
            },
            'platforms': {
              'android': {
                'googlePlay': {
                  'minimumVersion': '1.6.0',
                  'storeUrl': 'market://details?id=app.echoloop',
                  'fallbackUrl':
                      'https://play.google.com/store/apps/details?id=app.echoloop',
                },
                'apk': {
                  'latestVersion': '2.0.1',
                  'minimumVersion': '1.7.0',
                  'downloadUrl': 'https://cdn.example.com/app-2.0.1.apk',
                  if (includeChinaUrl)
                    'downloadUrlChina':
                        'https://cdn-cn.example.com/app-2.0.1.apk',
                },
              },
            },
          },
        ),
      );
    }

    void stubChinaApkHead({required int statusCode}) {
      when(
        () => mockDio.head<void>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<void>(
          requestOptions: RequestOptions(
            path: 'https://cdn-cn.example.com/app-2.0.1.apk',
          ),
          statusCode: statusCode,
        ),
      );
    }

    test('Google Play 安装来源使用商店渠道配置', () async {
      stubManifest(includeChinaUrl: true);
      bridge.installer = 'com.android.vending';

      final result = await androidChecker.check();

      expect(result, isNotNull);
      expect(result!.channel, AppUpdateChannel.androidGooglePlay);
      expect(result.latestVersion, '2.0.0');
      expect(result.minimumVersion, '1.6.0');
      expect(result.downloadUrl['android'], 'market://details?id=app.echoloop');
      verifyNever(
        () => mockDio.head<void>(any(), options: any(named: 'options')),
      );
    });

    test('非 Google Play 安装来源使用 APK 渠道配置', () async {
      stubManifest(includeChinaUrl: true);
      bridge.installer = null;

      final result = await androidChecker.check();

      expect(result, isNotNull);
      expect(result!.channel, AppUpdateChannel.androidApk);
      expect(result.latestVersion, '2.0.1');
      expect(result.minimumVersion, '1.7.0');
      expect(
        result.downloadUrl['android'],
        'https://cdn.example.com/app-2.0.1.apk',
      );
      verifyNever(
        () => mockDio.head<void>(any(), options: any(named: 'options')),
      );
    });

    test('中国用户链接可用时优先使用中国 APK 地址', () async {
      stubManifest(includeChinaUrl: true);
      stubChinaApkHead(statusCode: 200);
      bridge.installer = null;
      final chinaChecker = buildAndroidChecker(isChinaUser: true);

      final result = await chinaChecker.check();

      expect(result, isNotNull);
      expect(
        result?.downloadUrl['android'],
        'https://cdn-cn.example.com/app-2.0.1.apk',
      );
      expect(
        result?.downloadUrl['androidApk'],
        'https://cdn-cn.example.com/app-2.0.1.apk',
      );
      verify(
        () => mockDio.head<void>(
          'https://cdn-cn.example.com/app-2.0.1.apk',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    for (final statusCode in [404, 410]) {
      test('中国 APK 返回 $statusCode 时回退到默认地址', () async {
        stubManifest(includeChinaUrl: true);
        stubChinaApkHead(statusCode: statusCode);
        bridge.installer = null;
        final chinaChecker = buildAndroidChecker(isChinaUser: true);

        final result = await chinaChecker.check();

        expect(result, isNotNull);
        expect(
          result?.downloadUrl['android'],
          'https://cdn.example.com/app-2.0.1.apk',
        );
      });
    }

    test('中国 APK 地址缺失时使用默认地址且不探测', () async {
      stubManifest();
      bridge.installer = null;
      final chinaChecker = buildAndroidChecker(isChinaUser: true);

      final result = await chinaChecker.check();

      expect(result, isNotNull);
      expect(
        result?.downloadUrl['android'],
        'https://cdn.example.com/app-2.0.1.apk',
      );
      verifyNever(
        () => mockDio.head<void>(any(), options: any(named: 'options')),
      );
    });

    test('中国 APK 探测遇到非 404 状态时保留中国地址', () async {
      stubManifest(includeChinaUrl: true);
      stubChinaApkHead(statusCode: 500);
      bridge.installer = null;
      final chinaChecker = buildAndroidChecker(isChinaUser: true);

      final result = await chinaChecker.check();

      expect(result, isNotNull);
      expect(
        result?.downloadUrl['android'],
        'https://cdn-cn.example.com/app-2.0.1.apk',
      );
    });

    test('中国 APK 探测网络异常时保留中国地址', () async {
      stubManifest(includeChinaUrl: true);
      when(
        () => mockDio.head<void>(any(), options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: 'https://cdn-cn.example.com/app-2.0.1.apk',
          ),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      bridge.installer = null;
      final chinaChecker = buildAndroidChecker(isChinaUser: true);

      final result = await chinaChecker.check();

      expect(result, isNotNull);
      expect(
        result?.downloadUrl['android'],
        'https://cdn-cn.example.com/app-2.0.1.apk',
      );
    });

    test('仅顶层 minimumVersion 不波及 Android 各渠道（新版本忽略顶层）', () async {
      // 只有顶层 minimumVersion，无 platforms.android.*.minimumVersion
      when(
        () => mockDio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          data: {
            'latestVersion': '2.0.0',
            'minimumVersion': '1.9.0',
            'downloadUrl': {'androidApk': 'https://cdn.example.com/app.apk'},
          },
        ),
      );

      bridge.installer = 'com.android.vending';
      final playResult = await androidChecker.check();
      expect(playResult!.channel, AppUpdateChannel.androidGooglePlay);
      expect(playResult.minimumVersion, '0.0.0');

      bridge.installer = null;
      final apkResult = await androidChecker.check();
      expect(apkResult!.channel, AppUpdateChannel.androidApk);
      expect(apkResult.minimumVersion, '0.0.0');
    });
  });
}

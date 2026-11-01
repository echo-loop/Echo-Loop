import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:echo_loop/models/app_update_info.dart';
import 'package:echo_loop/services/app_update_launcher.dart';

/// 记录 launchUrl 的假 url_launcher 平台实现。
class FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = [];
  bool launchReturns = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return launchReturns;
  }

  @override
  // ignore: deprecated_member_use
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return launchReturns;
  }
}

void main() {
  late FakeUrlLauncher urlLauncher;

  setUp(() {
    urlLauncher = FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  AppUpdateLauncher makeLauncher() => const AppUpdateLauncher();

  group('AppUpdateLauncher', () {
    const playInfo = AppUpdateInfo(
      latestVersion: '2.0.0',
      minimumVersion: '1.5.0',
      channel: AppUpdateChannel.androidGooglePlay,
    );

    test('Google Play 渠道直接打开应用商店链接', () async {
      await makeLauncher().launch(
        info: playInfo,
        primaryUrl: 'market://details?id=app.echoloop',
      );

      expect(urlLauncher.launched, ['market://details?id=app.echoloop']);
    });

    test('Google Play 商店链接打不开时回退到 fallbackUrl', () async {
      urlLauncher.launchReturns = false;
      const info = AppUpdateInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.5.0',
        channel: AppUpdateChannel.androidGooglePlay,
        platforms: AppUpdatePlatforms(
          android: AndroidUpdateConfig(
            googlePlay: AndroidGooglePlayUpdateConfig(
              fallbackUrl:
                  'https://play.google.com/store/apps/details?id=app.echoloop',
            ),
          ),
        ),
      );

      await makeLauncher().launch(info: info, primaryUrl: 'market://x');

      expect(urlLauncher.launched, [
        'market://x',
        'https://play.google.com/store/apps/details?id=app.echoloop',
      ]);
    });

    test(
      'Google Play 商店链接打不开且渠道无 fallback 时回退到 downloadUrl.fallback',
      () async {
        urlLauncher.launchReturns = false;
        const info = AppUpdateInfo(
          latestVersion: '2.0.0',
          minimumVersion: '1.5.0',
          channel: AppUpdateChannel.androidGooglePlay,
          downloadUrl: {
            'fallback':
                'https://play.google.com/store/apps/details?id=app.echoloop',
          },
        );

        await makeLauncher().launch(info: info, primaryUrl: 'market://x');

        expect(urlLauncher.launched, [
          'market://x',
          'https://play.google.com/store/apps/details?id=app.echoloop',
        ]);
      },
    );

    test('非 Play 渠道直接打开下载链接，不触碰 Play 专属逻辑', () async {
      const info = AppUpdateInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.5.0',
        channel: AppUpdateChannel.androidApk,
      );

      await makeLauncher().launch(
        info: info,
        primaryUrl: 'https://cdn.echo-loop.top/app.apk',
      );

      expect(urlLauncher.launched, ['https://cdn.echo-loop.top/app.apk']);
    });
  });
}

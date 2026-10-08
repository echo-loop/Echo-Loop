/// SettingsScreen 测试
///
/// 测试设置页面的渲染和交互。
library;

import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:echo_loop/providers/app_update_provider.dart';
import 'package:echo_loop/providers/developer_options_provider.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/screens/settings_screen.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/providers/subscription_availability.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/package_info_provider.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<LaunchOptions> options = [];
  final List<String> urls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions launchOptions) async {
    urls.add(url);
    options.add(launchOptions);
    return true;
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
  }) async => true;
}

void main() {
  final testPackageInfo = PackageInfo(
    appName: 'Echo Loop',
    packageName: 'top.echo-loop',
    version: '1.0.0',
    buildNumber: '1',
  );

  // 词典设置等同步读取 SharedPreferences 的 provider 需注入实例
  late SharedPreferences prefs;
  late _FakeUrlLauncher urlLauncher;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    urlLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = urlLauncher;
  });

  List<Override> buildOverrides({
    AppSettingsState settings = const AppSettingsState(),
    bool showDeveloperOptions = true,
    bool showOfflineAsrSection = false,
    OfflineAsrSettingsState? offlineAsrState,
    TtsSettings ttsSettings = const TtsSettings(),
    PackageInfo? packageInfo,
    bool isChinaUser = false,
    StateProvider<bool>? simulatedChinaUserProvider,
    // 测试宿主（macOS/无 key）默认不支持订阅，这里默认置 true 以覆盖订阅入口 UI。
    bool subscriptionAvailable = true,
  }) {
    const recommendedModel = AsrModelInfo(
      id: 'whisper-base-en-int8',
      displayName: 'Whisper Base.en',
      type: AsrModelType.whisper,
    );
    return [
      ...learningSettingsOverrides(prefs: prefs),
      appSettingsProvider.overrideWith(() => TestAppSettings(settings)),
      initialTtsSettingsProvider.overrideWithValue(ttsSettings),
      showDeveloperOptionsProvider.overrideWith(
        () => _TestDeveloperOptions(showDeveloperOptions),
      ),
      showOfflineAsrSectionProvider.overrideWithValue(showOfflineAsrSection),
      recommendedAsrModelProvider.overrideWithValue(recommendedModel),
      initialOfflineAsrSettingsStateProvider.overrideWithValue(
        offlineAsrState ??
            OfflineAsrSettingsState(recommendedModel: recommendedModel),
      ),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
      audioEngineProvider.overrideWith(() => TestAudioEngine()),
      packageInfoProvider.overrideWithValue(packageInfo ?? testPackageInfo),
      appUpdateProvider.overrideWith(() => TestAppUpdate()),
      subscriptionAvailabilityProvider.overrideWithValue(subscriptionAvailable),
      isChinaUserProvider.overrideWith((ref) {
        final simulatedProvider = simulatedChinaUserProvider;
        return simulatedProvider == null
            ? isChinaUser
            : ref.watch(simulatedProvider);
      }),
      analyticsOverride(),
    ];
  }

  group('SettingsScreen', () {
    const settingsSvgAssets = [
      'assets/icon/account-1.svg',
      'assets/icon/diamond.svg',
      'assets/icon/artist-palette.svg',
      'assets/icon/locale.svg',
      'assets/icon/speak.svg',
      'assets/icon/bell.svg',
      'assets/icon/book-shelf.svg',
      'assets/icon/microphone.svg',
      'assets/icon/speaker.svg',
      'assets/icon/play-pause.svg',
      'assets/icon/locale-1.svg',
      'assets/icon/diskette.svg',
      'assets/icon/trash-bin.svg',
      'assets/icon/refresh.svg',
      'assets/icon/documents.svg',
      'assets/icon/lock.svg',
      'assets/icon/feedback.svg',
      'assets/icon/help.svg',
      'assets/icon/group.svg',
    ];

    Finder findSvgAsset(String assetName) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName == assetName,
      );
    }

    group('渲染', () {
      testWidgets('仅中国区路由显示账号行国旗角标', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(isChinaUser: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(findSvgAsset('assets/icon/china_flag.svg'), findsOneWidget);
        expect(
          find.byTooltip('Using China region service routing'),
          findsOneWidget,
        );
      });

      testWidgets('地区状态改变时更新账号行国旗角标', (tester) async {
        final simulatedChinaUserProvider = StateProvider<bool>((ref) => false);
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              simulatedChinaUserProvider: simulatedChinaUserProvider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(findSvgAsset('assets/icon/china_flag.svg'), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        container.read(simulatedChinaUserProvider.notifier).state = true;
        await tester.pumpAndSettle();

        expect(findSvgAsset('assets/icon/china_flag.svg'), findsOneWidget);

        container.read(simulatedChinaUserProvider.notifier).state = false;
        await tester.pumpAndSettle();

        expect(findSvgAsset('assets/icon/china_flag.svg'), findsNothing);
      });

      test('设置页 SVG 图标统一使用 24x24 viewBox', () {
        for (final asset in settingsSvgAssets) {
          final content = File(asset).readAsStringSync();
          final svgTag = RegExp(
            r'<svg\b[^>]*>',
            dotAll: true,
          ).firstMatch(content)?.group(0);

          expect(svgTag, isNotNull, reason: asset);
          expect(svgTag, contains('viewBox="0 0 24 24"'), reason: asset);
          expect(svgTag, contains('width="24"'), reason: asset);
          expect(svgTag, contains('height="24"'), reason: asset);
          expect(
            RegExp(r'\sviewBox=').allMatches(svgTag!).length,
            1,
            reason: asset,
          );
          expect(
            RegExp(r'\swidth=').allMatches(svgTag).length,
            1,
            reason: asset,
          );
          expect(
            RegExp(r'\sheight=').allMatches(svgTag).length,
            1,
            reason: asset,
          );
          expect(content, isNot(contains('<style')), reason: asset);
        }
      });

      test('设置页满框 SVG 图标声明资源级视觉缩放', () {
        const visuallyScaledAssets = {
          'assets/icon/diskette.svg',
          'assets/icon/trash-bin.svg',
          'assets/icon/refresh.svg',
          'assets/icon/lock.svg',
          'assets/icon/group.svg',
          'assets/icon/play-pause.svg',
        };

        for (final asset in visuallyScaledAssets) {
          final content = File(asset).readAsStringSync();
          expect(
            content,
            contains('data-settings-visual-scale='),
            reason: asset,
          );
          expect(content, contains('translate(12 12) scale('), reason: asset);
        }
      });

      testWidgets('显示主题设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Theme'), findsOneWidget);
        // 默认 system 模式（主题和语言都显示"Follow System"）
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('显示语言设置项', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('App Language'), findsOneWidget);
        // 默认跟随系统
        expect(find.text('Follow System'), findsAtLeast(1));
      });

      testWidgets('普通设置项使用 SVG 图标替代 emoji', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              showDeveloperOptions: false,
              showOfflineAsrSection: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(findSvgAsset('assets/icon/account-1.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/diamond.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/artist-palette.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/locale.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/speak.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/bell.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/book-shelf.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/microphone.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/speaker.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/play-pause.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/locale-1.svg'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('About'), 200);
        await tester.pumpAndSettle();
        expect(findSvgAsset('assets/icon/refresh.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/documents.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/lock.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/feedback.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/help.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/group.svg'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('Backup & Restore'), 200);
        await tester.pumpAndSettle();
        expect(findSvgAsset('assets/icon/diskette.svg'), findsOneWidget);
        expect(findSvgAsset('assets/icon/trash-bin.svg'), findsOneWidget);

        for (final emoji in [
          '👤',
          '💎',
          '🎨',
          '🌐',
          '🗣️',
          '🔔',
          '📚',
          '🎙️',
          '🔊',
          '▶️',
          '📖',
          '💾',
          '🗑️',
          '🔄',
          '📜',
          '🔒',
          '✉️',
          '👥',
        ]) {
          expect(find.text(emoji), findsNothing);
        }
      });

      testWidgets('设置页普通图标保留 leading 占位并收紧内部绘制尺寸', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showDeveloperOptions: false),
          ),
        );
        await tester.pumpAndSettle();

        final accountIcon = tester.widget<SvgPicture>(
          findSvgAsset('assets/icon/account-1.svg'),
        );
        expect(accountIcon.width, 26);
        expect(accountIcon.height, 26);
        expect(
          tester.getSize(
            find
                .ancestor(
                  of: findSvgAsset('assets/icon/account-1.svg'),
                  matching: find.byType(SizedBox),
                )
                .first,
          ),
          const Size(32, 32),
        );

        await tester.scrollUntilVisible(find.text('Open Source Project'), 200);
        await tester.pumpAndSettle();

        final refreshIcon = tester.widget<SvgPicture>(
          findSvgAsset('assets/icon/refresh.svg'),
        );
        expect(refreshIcon.width, 26);
        expect(refreshIcon.height, 26);

        final githubIcons = tester.widgetList<FaIcon>(find.byType(FaIcon));
        expect(githubIcons, hasLength(1));
        expect(githubIcons.single.size, 20);
      });

      testWidgets('深色主题下单色 SVG 使用高对比主题前景色', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            Theme(data: AppTheme.dark(), child: const SettingsScreen()),
            overrides: buildOverrides(
              showDeveloperOptions: false,
              showOfflineAsrSection: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedColor = AppTheme.dark().colorScheme.onSurfaceVariant;
        final paletteIcon = tester.widget<SvgPicture>(
          findSvgAsset('assets/icon/artist-palette.svg'),
        );
        expect(paletteIcon.colorFilter, isNull);

        const visibleAssets = [
          'assets/icon/account-1.svg',
          'assets/icon/speak.svg',
          'assets/icon/microphone.svg',
          'assets/icon/play-pause.svg',
          'assets/icon/refresh.svg',
          'assets/icon/lock.svg',
          'assets/icon/feedback.svg',
          'assets/icon/group.svg',
          'assets/icon/help.svg',
          'assets/icon/trash-bin.svg',
        ];

        for (final asset in visibleAssets) {
          await tester.scrollUntilVisible(findSvgAsset(asset), 200);
          await tester.pumpAndSettle();
          final icon = tester.widget<SvgPicture>(findSvgAsset(asset));
          expect(
            icon.colorFilter,
            ColorFilter.mode(expectedColor, BlendMode.srcIn),
            reason: asset,
          );
        }
      });

      testWidgets('显示关于信息区域', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('About'), findsOneWidget);
        expect(find.text('Terms of Service'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('FAQ'), findsOneWidget);
        expect(find.text('Write Feedback'), findsOneWidget);
        expect(find.text('Join Community'), findsOneWidget);
        expect(find.text('Open Source Project'), findsOneWidget);
        expect(find.text('github.com/echo-loop/Echo-Loop'), findsNothing);
        // 版本标签在页面底部，需要滚动到可见
        await tester.scrollUntilVisible(find.textContaining('Version'), 200);
        await tester.pumpAndSettle();
        expect(find.text('Version 1.0.0 (Debug)'), findsOneWidget);
      });

      testWidgets('iOS 显示评价我们入口', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.pumpWidget(
            createTestScreen(
              const SettingsScreen(),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Rate Us'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('非 iOS 不显示评价我们入口', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(
            createTestScreen(
              const SettingsScreen(),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Rate Us'), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('已登录时账号区显示登录邮箱', (tester) async {
        final user = User(
          id: 'user-1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          email: 'user@example.com',
          createdAt: '2026-06-03T00:00:00.000Z',
        );
        final session = Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: user,
          refreshToken: 'refresh',
        );

        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              supabaseSessionProvider.overrideWith(
                (ref) => Stream<Session?>.value(session),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
      });

      testWidgets('Apple 登录在账号入口显示 Apple 登录方式', (tester) async {
        final user = User(
          id: 'user-1',
          appMetadata: const {
            'provider': 'apple',
            'providers': ['apple'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'mbfpw8sdy7@privaterelay.appleid.com',
          createdAt: '2026-06-04T00:00:00.000Z',
        );
        final session = Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: user,
          refreshToken: 'refresh',
        );

        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              supabaseSessionProvider.overrideWith(
                (ref) => Stream<Session?>.value(session),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('mbfpw8sdy7@privaterelay.appleid.com'), findsNothing);
        expect(find.text('Signed in with Apple'), findsOneWidget);
      });

      testWidgets('Google 登录在账号入口显示 Google 登录方式', (tester) async {
        final user = User(
          id: 'user-1',
          appMetadata: const {
            'provider': 'google',
            'providers': ['google'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'long.google.account@example.com',
          createdAt: '2026-06-04T00:00:00.000Z',
        );
        final session = Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: user,
          refreshToken: 'refresh',
        );

        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              supabaseSessionProvider.overrideWith(
                (ref) => Stream<Session?>.value(session),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('long.google.account@example.com'), findsNothing);
        expect(find.text('Signed in with Google'), findsOneWidget);
      });

      testWidgets('关联 Google 后使用邮箱 OTP 登录在账号入口显示邮箱', (tester) async {
        final user = User(
          id: 'user-1',
          appMetadata: const {
            'provider': 'google',
            'providers': ['email', 'google'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'user@example.com',
          createdAt: '2026-06-07T00:00:00.000Z',
        );
        final session = Session(
          accessToken: _jwtWithAuthenticationMethod('otp'),
          tokenType: 'bearer',
          user: user,
          refreshToken: 'refresh',
        );

        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              supabaseSessionProvider.overrideWith(
                (ref) => Stream<Session?>.value(session),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('Signed in with Google'), findsNothing);
      });

      testWidgets('邮箱登录不通过 Apple relay 域名误判登录方式', (tester) async {
        final user = User(
          id: 'user-1',
          appMetadata: const {
            'provider': 'email',
            'providers': ['email'],
          },
          userMetadata: const {},
          aud: 'authenticated',
          email: 'mbfpw8sdy7@privaterelay.appleid.com',
          createdAt: '2026-06-04T00:00:00.000Z',
        );
        final session = Session(
          accessToken: 'token',
          tokenType: 'bearer',
          user: user,
          refreshToken: 'refresh',
        );

        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              supabaseSessionProvider.overrideWith(
                (ref) => Stream<Session?>.value(session),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Signed in with Apple'), findsNothing);
        expect(find.text('mbfpw8sd...@ay.appleid.com'), findsOneWidget);
      });

      testWidgets('未订阅：账户分组内显示订阅入口与「升级」徽章，无顶部金卡', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 订阅行标题（沿用 premiumEntryTitle）+ 未订阅高亮「升级」徽章
        expect(find.text('Subscription'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
        final upgradeBadge = tester.widget<Text>(find.text('Upgrade'));
        expect(upgradeBadge.style?.color, const Color(0xFF111111));
        // 顶部不再有大金卡的「会员」状态徽章
        expect(find.text('Premium'), findsNothing);
      });

      testWidgets('已订阅：显示「会员」徽章与套餐摘要', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () => _TestSubscriptionController(
                  const EntitlementState(
                    status: EntitlementStatus.premium,
                    entitlement: Entitlement(
                      isPremium: true,
                      productId: 'pro_yearly',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // 保持简洁：只有标题 + 「会员」徽章，无副标题详情
        expect(find.text('Subscription'), findsOneWidget);
        expect(find.text('Premium'), findsOneWidget);
        expect(find.text('Upgrade'), findsNothing);
      });

      testWidgets('点击订阅入口跳转 Paywall', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Subscription'));
        await tester.pumpAndSettle();

        expect(find.text('Paywall'), findsOneWidget);
      });

      testWidgets('平台未启用订阅：不显示订阅入口', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: [
              ...buildOverrides(subscriptionAvailable: false),
              subscriptionControllerProvider.overrideWith(
                () =>
                    _TestSubscriptionController(const EntitlementState.free()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Subscription'), findsNothing);
        expect(find.text('Upgrade'), findsNothing);
      });

      testWidgets('显示外观标题', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Appearance'), findsOneWidget);
      });

      testWidgets('Speech Recognition 入口仅在开关启用时显示', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showOfflineAsrSection: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Learning'), findsOneWidget);
        expect(find.text('Speech Recognition'), findsOneWidget);
      });

      testWidgets('语音合成入口显示当前 Echo Loop 引擎，不显示口音', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Text-to-Speech'), findsOneWidget);
        expect(find.text('Echo Loop AI'), findsOneWidget);
        expect(find.text('American'), findsNothing);
      });

      testWidgets('语音合成入口显示 Echo Loop 引擎', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              ttsSettings: const TtsSettings(engine: TtsEngineKind.kokoro),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Text-to-Speech'), findsOneWidget);
        expect(find.text('Echo Loop AI'), findsOneWidget);
      });

      testWidgets('开发者选项关闭时不显示开发者分组', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(showDeveloperOptions: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsNothing);
        expect(find.text('Time Machine'), findsNothing);
      });

      testWidgets('开发者选项开启且未设置时时显示系统时间文案', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        expect(find.text('Developer'), findsOneWidget);
        expect(find.text('Time Machine'), findsOneWidget);
        expect(find.text('Use system time'), findsOneWidget);
      });

      testWidgets('开发者选项开启且已设置时时显示当前调试时间', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 滚动到开发者区域
        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();

        // 调试时间显示在 Time Machine 对话框中，先点击打开
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Debug time:'), findsOneWidget);
      });
    });

    group('交互', () {
      testWidgets('点击 FAQ 后使用系统外部浏览器打开帮助文档', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('FAQ'));
        await tester.pump();

        expect(urlLauncher.urls, [
          'https://my.feishu.cn/docx/OPZRdXkRvoAW5Bx78LocBUdqn80',
        ]);
        expect(
          urlLauncher.options.single.mode,
          PreferredLaunchMode.externalApplication,
        );
      });

      testWidgets('点击主题设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击主题设置项
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示三个选项
        expect(find.text('Light Mode'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        // 对话框标题 + 列表中的 Follow System
        expect(find.text('Follow System'), findsAtLeast(1));
        expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget);
        expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
        expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
        expect(find.text('⚙️'), findsNothing);
        expect(find.text('☀️'), findsNothing);
        expect(find.text('🌛'), findsNothing);
      });

      testWidgets('选择 Dark 主题后状态更新', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 打开主题选择对话框
        await tester.tap(find.text('Theme'));
        await tester.pumpAndSettle();

        // 选择 Dark Mode
        await tester.tap(find.text('Dark Mode'));
        await tester.pumpAndSettle();

        // 对话框关闭后，应显示 Dark Mode
        expect(find.text('Dark Mode'), findsOneWidget);
      });

      testWidgets('点击语言设置弹出选择对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        // 点击语言设置项
        await tester.tap(find.text('App Language'));
        await tester.pumpAndSettle();

        // 应弹出对话框，显示三个选项
        expect(find.text('Follow System'), findsAtLeast(1));
        expect(find.text('English'), findsAtLeast(1));
        expect(find.text('简体中文'), findsAtLeast(1));
      });

      testWidgets('点击时光机弹出设置对话框', (tester) async {
        await tester.pumpWidget(
          createTestScreen(const SettingsScreen(), overrides: buildOverrides()),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        expect(find.text('Select date'), findsOneWidget);
        expect(find.text('Select time'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('点击恢复系统时间并保存后清除时光机', (tester) async {
        await tester.pumpWidget(
          createTestScreen(
            const SettingsScreen(),
            overrides: buildOverrides(
              settings: AppSettingsState(
                timeMachineDateTime: DateTime(2026, 3, 11, 22, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(find.text('Time Machine'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Time Machine'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Use system time'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Use system time'), findsOneWidget);
        expect(find.text('Debug time: 2026-03-11 22:15'), findsNothing);
      });
    });
  });
}

String _jwtWithAuthenticationMethod(String method) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode('{"amr":[{"method":"$method","timestamp":0}]}'),
  );
  return '$header.$payload.';
}

/// 测试用 SubscriptionController，固定返回指定权益状态，
/// 跳过真实对账（避免依赖 RevenueCat / 缓存 / 后端）。
class _TestSubscriptionController extends SubscriptionController {
  _TestSubscriptionController(this._state);
  final EntitlementState _state;

  @override
  EntitlementState build() => _state;
}

/// 测试用 DeveloperOptions Notifier，固定返回指定值。
class _TestDeveloperOptions extends DeveloperOptions {
  final bool _value;
  _TestDeveloperOptions(this._value);

  @override
  bool build() => _value;

  @override
  Future<void> setEnabled(bool value) async {
    state = value;
  }
}

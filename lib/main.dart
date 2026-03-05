import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'database/app_database.dart';
import 'database/providers.dart';
import 'database/migration/sp_to_drift_migration.dart';
import 'providers/package_info_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/review_reminder_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';
import 'services/notification_tap_router_bridge.dart';

/// 通过原生网络栈连接后端服务器。
///
/// Flutter 的 dart:io HttpClient 绕过了 iOS 原生网络栈，
/// 不会触发系统网络权限弹窗。此方法通过 Method Channel
/// 调用 iOS 原生 URLSession 发起请求，确保触发权限弹窗。
Future<void> _triggerNetworkPermission() async {
  try {
    const channel = MethodChannel('top.valuespot.fluency/network');
    await channel.invokeMethod('triggerNetworkPermission', {'url': apiBaseUrl});
  } catch (_) {
    // 忽略错误——目的只是触发权限弹窗
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();

  // 初始化数据库
  final database = AppDatabase(openConnection());

  // 执行 SP → Drift 迁移
  final prefs = await SharedPreferences.getInstance();
  final migration = SpToDriftMigration(
    database,
    prefs,
    subtitleLoader: defaultSubtitleLoader,
  );
  try {
    await migration.migrate();
  } catch (e) {
    print('SP → Drift 迁移失败，下次启动重试: $e');
  }

  if (!kIsWeb) {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      print('Audio session configured for background playback');
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  } else {
    print('Web platform: skipping audio session configuration');
  }

  // iOS: 通过原生网络栈触发系统网络权限弹窗
  if (!kIsWeb && Platform.isIOS) {
    unawaited(_triggerNetworkPermission());
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        packageInfoProvider.overrideWithValue(packageInfo),
      ],
      child: const FluencyApp(),
    ),
  );
}

class FluencyApp extends ConsumerStatefulWidget {
  const FluencyApp({super.key});

  @override
  ConsumerState<FluencyApp> createState() => _FluencyAppState();
}

class _FluencyAppState extends ConsumerState<FluencyApp> {
  StreamSubscription<NotificationIntent>? _intentSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bridge = ref.read(notificationTapRouterBridgeProvider);
      _intentSubscription = bridge.intents.listen(_handleNotificationIntent);

      final pendingIntent = bridge.takePendingIntent();
      if (pendingIntent != null) {
        _handleNotificationIntent(pendingIntent);
      }

      await ref.read(reviewReminderServiceProvider).init();
      final latestPendingIntent = bridge.takePendingIntent();
      if (latestPendingIntent != null) {
        _handleNotificationIntent(latestPendingIntent);
      }
    });
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  void _handleNotificationIntent(NotificationIntent intent) {
    if (!mounted) return;
    switch (intent) {
      case NotificationIntent.openStudyTasks:
        ref.read(appRouterProvider).go(AppRoutes.study);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Fluency',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

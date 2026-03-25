import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
import 'services/dictionary_service.dart';
import 'services/bundled_example_installer.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';
import 'services/notification_tap_router_bridge.dart';
import 'package:firebase_core/firebase_core.dart';
import 'analytics/analytics_providers.dart';
import 'analytics/models/event_names.dart';
import 'firebase_options.dart';

/// 通过原生网络栈连接后端服务器。
///
/// Flutter 的 dart:io HttpClient 绕过了 iOS 原生网络栈，
/// 不会触发系统网络权限弹窗。此方法通过 Method Channel
/// 调用 iOS 原生 URLSession 发起请求，确保触发权限弹窗。
Future<void> _triggerNetworkPermission() async {
  try {
    const channel = MethodChannel('top.echo-loop/network');
    await channel.invokeMethod('triggerNetworkPermission', {'url': apiBaseUrl});
  } catch (_) {
    // 忽略错误——目的只是触发权限弹窗
  }
}

/// 数据库文件重命名迁移：fluency.db → echo_loop.db
///
/// 旧版本使用 `fluency.db` / `fluency_demo.db`，新版本统一为
/// `echo_loop.db` / `echo_loop_demo.db`。仅在新文件不存在时重命名。
Future<void> _migrateDbFileNames() async {
  final docsDir = await getApplicationDocumentsDirectory();
  const renames = {
    'fluency.db': 'echo_loop.db',
    'fluency_demo.db': 'echo_loop_demo.db',
  };
  for (final entry in renames.entries) {
    final oldFile = File(p.join(docsDir.path, entry.key));
    final newFile = File(p.join(docsDir.path, entry.value));
    if (await oldFile.exists() && !await newFile.exists()) {
      await oldFile.rename(newFile.path);
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();

  // 数据库文件名迁移（fluency → echo_loop）
  await _migrateDbFileNames();

  // 检查是否处于演示模式
  final prefs = await SharedPreferences.getInstance();
  final isDemoMode = prefs.getBool('demo_mode') ?? false;

  // 初始化数据库（演示模式使用独立数据库文件）
  final dbFileName = isDemoMode ? 'echo_loop_demo.db' : 'echo_loop.db';
  final database = AppDatabase(openConnectionWithName(dbFileName));
  initAppDatabase(database);

  // 执行 SP → Drift 迁移（仅对生产数据库）
  if (!isDemoMode) {
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

    // 首次启动时安装内置示例内容
    try {
      await BundledExampleInstaller(database, prefs).installOnFirstLaunch();
    } catch (e) {
      print('内置示例安装失败: $e');
    }
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

  // 初始化 Firebase（所有平台都初始化，采集开关由通道选择逻辑控制）
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 初始化分析服务（根据 geo 选择 Firebase/友盟/Log 通道）
  final analyticsService = await initAnalyticsService(prefs);
  initAnalytics(analyticsService);

  // 预热本地词典数据库，避免首次查询时冷启动延迟（异步，不阻塞启动）
  unawaited(
    DictionaryService.instance.warmUp().catchError(
      (e) => debugPrint('Dictionary warm-up skipped: $e'),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [packageInfoProvider.overrideWithValue(packageInfo)],
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
  late final AppLifecycleListener _lifecycleListener;

  /// App 进入前台的时间戳，用于计算 foreground_duration_ms
  DateTime? _foregroundSince;

  /// 启动保护标记，防止 macOS 启动过程中的 resume 事件误触发 warm open
  bool _coldStartDone = false;

  @override
  void initState() {
    super.initState();

    // App 生命周期事件追踪
    _foregroundSince = DateTime.now();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onAppResumed,
      onHide: _onAppBackground,
    );

    // 冷启动 app_open 事件 + 设置保护期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).track(Events.appOpen, {
        EventParams.launchType: 'cold',
      });
      // 延迟 5 秒解除保护，避免启动过程中的 resume 误报 warm
      Future.delayed(const Duration(seconds: 5), () {
        _coldStartDone = true;
      });
    });

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
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// App 从后台恢复
  void _onAppResumed() {
    if (!_coldStartDone) return; // 启动保护期内忽略
    _foregroundSince = DateTime.now();
    ref.read(analyticsServiceProvider).track(Events.appOpen, {
      EventParams.launchType: 'warm',
    });
  }

  /// App 进入后台
  void _onAppBackground() {
    if (!_coldStartDone) return; // 启动保护期内忽略
    final durationMs = _foregroundSince != null
        ? DateTime.now().difference(_foregroundSince!).inMilliseconds
        : 0;
    ref.read(analyticsServiceProvider).track(Events.appBackground, {
      EventParams.foregroundDurationMs: durationMs,
    });
  }

  void _handleNotificationIntent(NotificationIntent intent) {
    if (!mounted) return;
    switch (intent) {
      case OpenStudyTasks():
        ref.read(appRouterProvider).go(AppRoutes.study);
      case OpenFavorites():
        ref.read(appRouterProvider).go(AppRoutes.favorites);
      case OpenAudioLearningPlan(:final audioId):
        final router = ref.read(appRouterProvider);
        router.go(AppRoutes.study);
        router.push(AppRoutes.audioLearningPlan(audioId));
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

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
import 'utils/time_format.dart';
import 'database/app_database.dart';
import 'database/providers.dart';
import 'database/migration/sp_to_drift_migration.dart';
import 'providers/package_info_provider.dart';
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/review_reminder_provider.dart';
import 'router/app_router.dart';
import 'services/bundled_example_installer.dart';
import 'services/temp_cleanup_service.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';
import 'services/notification_tap_router_bridge.dart';
import 'package:firebase_core/firebase_core.dart';
import 'analytics/analytics_providers.dart';
import 'services/user_id_service.dart';
import 'analytics/models/event_names.dart';
import 'firebase_options.dart';
import 'providers/offline_asr_settings_provider.dart';
import 'services/asr/asr_model_manager.dart';
import 'services/asr/offline_asr_engine.dart';
import 'services/app_logger.dart';
import 'services/speech_practice_platform.dart';
import 'services/storage_migration_service.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initTimeago();

  final packageInfo = await PackageInfo.fromPlatform();

  // 数据目录迁移（Documents → Application Support）
  try {
    await migrateToAppSupportDirectory();
  } catch (e) {
    AppLogger.log('App', '数据目录迁移失败，下次启动重试: $e');
  }

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

  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 初始化用户 ID（SecureStorage 持久化，卸载重装可恢复）
  final userId = await initUserIdService(prefs);

  // 初始化分析服务（根据 geo 选择 Firebase/友盟/Log 通道）
  final analyticsService = await initAnalyticsService(prefs, userId: userId);
  initAnalytics(analyticsService);

  // 清理上次残留的录音临时文件（沙盒/tmp/ 中超过 60 秒的文件），不阻塞启动
  unawaited(cleanupRecordingTempFiles());

  // 词典由 dictionaryProvider 管理下载和打开，
  // 在 FluencyApp.initState 中 eagerly read 触发初始化。

  // 离线 ASR 初始化（全平台）。
  // Android 固定 offline 后端，iOS/macOS 默认 platform 后端（可切换）。
  AsrModelInfo? recommendedAsrModel;
  OfflineAsrSettingsState? initialOfflineAsrSettingsState;
  if (!kIsWeb) {
    final defaultBackend =
        Platform.isAndroid ? AsrBackend.offline : AsrBackend.platform;
    AppLogger.log('App', 'ASR: platform=${Platform.operatingSystem}, defaultBackend=${defaultBackend.name}');
    final platform = SpeechPracticePlatform.instance;
    final ramBytes = platform.isSupported
        ? await platform.getDeviceRamBytes()
        : 0;
    final modelManager = AsrModelManager();
    recommendedAsrModel = modelManager.recommendModel(ramBytes: ramBytes);
    initialOfflineAsrSettingsState = await loadInitialOfflineAsrSettingsState(
      prefs: prefs,
      modelManager: modelManager,
      recommendedModel: recommendedAsrModel,
      defaultBackend: defaultBackend,
    );
    // 清理推荐模型变更后残留的旧模型文件（异步，不阻塞启动）
    unawaited(modelManager.cleanupUnusedModels(recommendedAsrModel.id));
  }

  runApp(
    ProviderScope(
      overrides: [
        packageInfoProvider.overrideWithValue(packageInfo),
        if (recommendedAsrModel != null)
          recommendedAsrModelProvider.overrideWithValue(recommendedAsrModel),
        if (initialOfflineAsrSettingsState != null)
          initialOfflineAsrSettingsStateProvider.overrideWithValue(
            initialOfflineAsrSettingsState,
          ),
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

    // 预加载词典（触发下载或打开本地词典）
    ref.read(dictionaryProvider);

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
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
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

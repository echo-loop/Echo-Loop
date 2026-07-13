import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'utils/time_format.dart';
import 'database/app_database.dart';
import 'database/providers.dart';
import 'database/migration/sp_to_drift_migration.dart';
import 'providers/package_info_provider.dart';
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'router/app_router.dart';
import 'services/bundled_example_installer.dart';
import 'services/temp_cleanup_service.dart';
import 'theme/app_theme.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'config/api_config.dart';
import 'config/auth_config.dart' as auth_config;
import 'config/revenuecat_config.dart' as revenuecat_config;
import 'config/web_purchase_config.dart' as web_purchase_config;
import 'providers/review_reminder_provider.dart';
import 'services/notification_tap_router_bridge.dart';
import 'package:firebase_core/firebase_core.dart';
import 'analytics/analytics_providers.dart';
import 'analytics/permission_snapshot.dart';
import 'services/network_permission_trigger.dart';
import 'services/user_id_service.dart';
import 'firebase_options.dart';
import 'providers/learning_settings_provider.dart';
import 'providers/tts/kokoro_model_provider.dart';
import 'providers/tts/piper_model_provider.dart';
import 'providers/tts/tts_settings_provider.dart';
import 'providers/intensive_listen_prefs_provider.dart';
import 'providers/blind_listen_prefs_provider.dart';
import 'providers/retell_prefs_provider.dart';
import 'providers/difficult_practice_prefs_provider.dart';
import 'providers/new_user_guide_provider.dart';
import 'providers/offline_asr_settings_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'services/asr/asr_model_manager.dart';
import 'services/asr/offline_asr_engine.dart';
import 'services/app_logger.dart';
import 'services/tts/kokoro_model_manager.dart';
import 'services/tts/piper_model_manager.dart';
import 'services/tts/piper_voices.dart';
import 'services/tts/tts_cache_store.dart';
import 'utils/app_data_dir.dart';
import 'services/speech_practice_platform.dart';
import 'services/storage_migration_service.dart';
import 'services/background_audio_handler.dart';
import 'features/official_collections/data/official_catalog_service.dart';
import 'features/official_collections/data/trigger_official_sync.dart';
import 'features/official_collections/download/official_download_notifier.dart';
import 'features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/subscription/providers/subscription_controller.dart';
import 'features/subscription/providers/subscription_plans_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initTimeago();

  // 开启日志落盘：每条日志同步写入文件并 flush，崩溃（含 native SIGABRT）前的
  // 日志仍保留在磁盘，供日志页导出排查。失败静默忽略，不影响启动。
  try {
    await AppLogger.initFileSink(await appLogFilePath());
  } catch (_) {}

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

  // 首次启动检测：哨兵 key `first_launch_done` 不存在即视为首次启动，
  // 立即写入 true。后续所有启动都会读到该 key = true，即非首启。
  // 注意：该机制从此版本引入，老用户升级时哨兵同样缺失，会被当作首启。
  // 需要业务层额外用数据是否为空等 gate 兜底区分升级用户。
  final isFirstLaunch = !(prefs.getBool('first_launch_done') ?? false);
  if (isFirstLaunch) {
    await prefs.setBool('first_launch_done', true);
  }

  // Onboarding 问卷"是否已完成"同步预读：GoRouter redirect 是同步函数，
  // 必须在 main() 阶段拿到值，否则启动闪屏期间 redirect 失效。
  // 用 `onboarding_completed_at_ms` 存在性判定，不引入冗余 bool key。
  final onboardingCompleted = OnboardingSurveyStorage.readIsCompletedSync(
    prefs,
  );

  // 旧“语音识别总开关”迁移到两个练习评分开关，须在学习设置预读前完成。
  await migrateLegacyOfflineAsrEnabledToRatingSettings(prefs);

  // 学习设置（自动跳过复述）同步预读：plan / progress 启动期就需要拿到值。
  final initialLearningSettings = LearningSettings.fromPrefsSync(prefs);
  // 清理历史 SP key（开发期数据卫生，幂等无副作用）。
  await cleanupLegacyLearningSettingsKeys(prefs);

  // 语音合成设置（引擎/口音）同步预读：闪卡翻面等同步发音路径需立即拿到口音，
  // 避免异步 hydrate 前先用默认美音发声。
  final initialTtsSettings = TtsSettings.fromPrefsSync(prefs);

  // 各学习子阶段用户偏好(按槽位)同步预读:入口弹窗 / 播放器进入时需立即拿到记忆值。
  final initialIntensiveListenPrefs = intensiveListenPrefsFromPrefsSync(prefs);
  final initialBlindListenPrefs = blindListenPrefsFromPrefsSync(prefs);
  final initialRetellPrefs = retellPrefsFromPrefsSync(prefs);
  final initialDifficultPracticePrefs = difficultPracticePrefsFromPrefsSync(
    prefs,
  );

  // 界面语言同步预读：让首帧 MaterialApp.locale 直接拿到用户已选语言，
  // 避免"先按系统语言渲染、再 hydrate 切到用户设置"的闪烁。
  final initialUiLocale = readInitialUiLocaleSync(prefs);
  // AI 转录「自动合并短句」同步预读：让转录弹窗首帧直接拿到上次选择，
  // 避免在 AppSettings 异步 hydrate 前先读到默认 true。
  final initialAiTranscriptionAutoMergeEnabled =
      readInitialAiTranscriptionAutoMergeEnabledSync(prefs);

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

  await initEchoLoopAudioHandler();

  // iOS: 通过原生网络栈触发系统网络权限弹窗。
  // 启动时立即触发（包括 Onboarding 期间的新用户），原因：埋点上报
  // （app_permission_snapshot / onboarding_survey_shown 等）依赖网络通畅，
  // 推迟会丢失事件。系统弹窗由 OS 决定具体呈现时机，可能延后。
  if (!kIsWeb && Platform.isIOS) {
    unawaited(NetworkPermissionTrigger.trigger(prefs, apiBaseUrl));
  }

  // 初始化 Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 初始化 Supabase（认证 + 未来云同步用）
  //
  // 仅在 --dart-define 注入了 SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY 时才初始化；
  // 未配置时跳过，登录功能不可用但 app 仍可匿名运行（渐进式登录策略）。
  // Session 默认走 SharedPreferences 持久化，重启自动恢复。
  // 已恢复的登录用户 ID（若有）。用于给 RevenueCat configure 直接带上 appUserID，
  // 让已登录老用户冷启动跳过匿名态；未登录 / 未配置认证时为 null。
  String? restoredUserId;
  if (auth_config.isAuthConfigured) {
    try {
      await Supabase.initialize(
        url: auth_config.supabaseUrl,
        anonKey: auth_config.supabasePublishableKey,
      );
      // Supabase 启动时自动从 SharedPreferences 恢复上次 session；此处读回恢复的用户 ID。
      restoredUserId = Supabase.instance.client.auth.currentSession?.user.id;
    } catch (e) {
      AppLogger.log('App', 'Supabase 初始化失败，认证功能不可用: $e');
    }
  } else {
    AppLogger.log(
      'App',
      'Supabase 未配置（缺 SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY），跳过初始化',
    );
  }

  // 初始化 RevenueCat（IAP 订阅）
  //
  // 仅在 --dart-define 注入了当前平台的 REVENUECAT_API_KEY_* 时才初始化；
  // 未配置时跳过，订阅功能不可用但 app 仍可匿名运行。
  // 用户身份绑定（Purchases.logIn）由 SubscriptionController 监听登录态后处理，
  // 这里只做 SDK 配置。
  if (revenuecat_config.useLocalStoreKit) {
    // 本地 StoreKit 测试模式：**不初始化 RevenueCat**，购买走 in_app_purchase
    // 直连 .storekit，避免本地交易被 RC SDK 捕获上报（不污染 RC Sandbox）。
    AppLogger.log('App', '本地 StoreKit 测试模式：跳过 RevenueCat 初始化');
  } else if (web_purchase_config.isWebCheckoutConfigured) {
    // 网页支付渠道（侧载 APK / 桌面）：无可用 RC 原生 SDK，购买走浏览器结账、
    // 权益经后端 /api/entitlements 读回，**不初始化 RevenueCat SDK**。
    AppLogger.log('App', '网页支付渠道：跳过 RevenueCat 初始化（权益经后端读回）');
  } else if (revenuecat_config.isRevenueCatConfigured) {
    try {
      // Debug 构建打开 RevenueCat 详细日志，便于定位 Offerings 为空等问题。
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      // 若已有恢复的登录 session，直接以真实用户 ID 配置，跳过匿名态；
      // 否则匿名 configure（行为同旧版），后续由 SubscriptionController.logIn 绑定。
      final configuration = PurchasesConfiguration(
        revenuecat_config.revenueCatApiKey,
      );
      if (restoredUserId != null) {
        configuration.appUserID = restoredUserId;
      }
      await Purchases.configure(configuration);
      AppLogger.log(
        'App',
        restoredUserId != null
            ? 'RevenueCat 以已登录身份 configure（appUserID=$restoredUserId）'
            : 'RevenueCat 匿名 configure',
      );
    } catch (e) {
      AppLogger.log('App', 'RevenueCat 初始化失败，订阅功能不可用: $e');
    }
  } else {
    AppLogger.log('App', 'RevenueCat 未配置（缺平台 API Key），跳过初始化');
  }

  // 初始化用户 ID（SecureStorage 持久化，卸载重装可恢复）
  final userId = await initUserIdService(prefs);

  // 初始化分析服务（根据 geo 选择 Firebase/友盟/Log 通道）
  final analyticsService = await initAnalyticsService(prefs, userId: userId);
  initAnalytics(analyticsService);

  // 上报 4 类系统授权状态（mic / speech / notification / network）：
  // super properties + person properties + app_permission_snapshot 三路写入。
  // 失败不影响启动；底层方法已各自做 consent gate + try/catch。
  try {
    final snapshot = await PermissionSnapshot.capture(prefs);
    await analyticsService.reportPermissionSnapshot(snapshot);
  } catch (e) {
    AppLogger.log('App', '权限状态埋点失败: $e');
  }

  // 清理上次残留的录音临时文件（沙盒/tmp/ 中超过 60 秒的文件），不阻塞启动
  unawaited(cleanupRecordingTempFiles());

  // 清理超过 1 天的 PDF 分享临时目录（分享后不能立即删，见 temp_cleanup_service）
  unawaited(cleanupStalePdfExportTemp());

  // 启动后延迟清理 TTS 合成缓存（过期 + 超量 LRU），不拖首屏。
  Future.delayed(const Duration(seconds: 8), () {
    TtsCacheStore(
      resolveDao: () => database.ttsCacheDao,
      resolveCacheDir: getApplicationCacheDirectory,
    ).cleanup();
  });

  // 词典由 dictionaryProvider 管理下载和打开，
  // 在 EchoLoopApp.initState 中 eagerly read 触发初始化。

  // 离线 ASR 初始化（全平台）。
  // Android 固定 offline 后端，iOS/macOS 默认 platform 后端（可切换）。
  AsrModelInfo? recommendedAsrModel;
  OfflineAsrSettingsState? initialOfflineAsrSettingsState;
  if (!kIsWeb) {
    final defaultBackend = Platform.isAndroid
        ? AsrBackend.offline
        : AsrBackend.platform;
    AppLogger.log(
      'App',
      'ASR: platform=${Platform.operatingSystem}, defaultBackend=${defaultBackend.name}',
    );
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
    // 清理历史废弃 ASR 模型目录；保留当前版本所有可选模型。
    unawaited(modelManager.cleanupUnknownModels());
  }

  // Echo Loop TTS（Kokoro）模型初始状态：用持久化标记 + 文件系统校验恢复，
  // 使启动后若已选 Echo Loop 且模型就绪能立即生效（全平台，Web 除外）。
  KokoroModelsState? initialKokoroModelState;
  if (!kIsWeb) {
    final managers = <KokoroModelVariant, KokoroModelManager>{
      for (final v in KokoroModelVariant.values)
        v: KokoroModelManager(spec: kokoroSpecOf(v)),
    };
    initialKokoroModelState = await loadInitialKokoroModelState(
      prefs: prefs,
      managerOf: (v) => managers[v]!,
    );
    for (final m in managers.values) {
      m.dispose();
    }
  }

  // Piper（Echo Loop TTS 平衡档）模型初始状态：每音色一个独立模型，用持久化标记 +
  // 文件系统校验恢复各音色就绪态（全平台，Web 除外）。
  PiperModelsState? initialPiperModelState;
  if (!kIsWeb) {
    final managers = <String, PiperModelManager>{
      for (final v in piperVoices) v.id: PiperModelManager(voice: v),
    };
    initialPiperModelState = await loadInitialPiperModelState(
      prefs: prefs,
      managerOf: (id) => managers[id]!,
    );
    for (final m in managers.values) {
      m.dispose();
    }
  }

  // 清理上次运行残留的官方合集音频下载 tmp 文件（异步）
  unawaited(cleanupOfficialDownloadTmp());

  runApp(
    // PostHogWidget：posthog_flutter 5.x Session Replay 必需的根包装。
    // 负责 Flutter 端变更检测 + 截图并桥接原生 SDK 上报 $snapshot 事件；
    // 不包的话即便 PostHogConfig.sessionReplay=true 也不会生成录像。
    // 当前通道非 PostHog 时 Posthog().config 为 null，此组件会直接跳过，不影响其他通道。
    PostHogWidget(
      child: ProviderScope(
        overrides: [
          packageInfoProvider.overrideWithValue(packageInfo),
          isFirstLaunchProvider.overrideWithValue(isFirstLaunch),
          sharedPreferencesProvider.overrideWithValue(prefs),
          initialOnboardingCompletedProvider.overrideWithValue(
            onboardingCompleted,
          ),
          initialLearningSettingsProvider.overrideWithValue(
            initialLearningSettings,
          ),
          initialTtsSettingsProvider.overrideWithValue(initialTtsSettings),
          initialIntensiveListenPrefsProvider.overrideWithValue(
            initialIntensiveListenPrefs,
          ),
          initialBlindListenPrefsProvider.overrideWithValue(
            initialBlindListenPrefs,
          ),
          initialRetellPrefsProvider.overrideWithValue(initialRetellPrefs),
          initialDifficultPracticePrefsProvider.overrideWithValue(
            initialDifficultPracticePrefs,
          ),
          initialUiLocaleProvider.overrideWithValue(initialUiLocale),
          initialAiTranscriptionAutoMergeEnabledProvider.overrideWithValue(
            initialAiTranscriptionAutoMergeEnabled,
          ),
          if (recommendedAsrModel != null)
            recommendedAsrModelProvider.overrideWithValue(recommendedAsrModel),
          if (initialOfflineAsrSettingsState != null)
            initialOfflineAsrSettingsStateProvider.overrideWithValue(
              initialOfflineAsrSettingsState,
            ),
          if (initialKokoroModelState != null)
            initialKokoroModelStateProvider.overrideWithValue(
              initialKokoroModelState,
            ),
          if (initialPiperModelState != null)
            initialPiperModelStateProvider.overrideWithValue(
              initialPiperModelState,
            ),
        ],
        child: const EchoLoopApp(),
      ),
    ),
  );
}

class EchoLoopApp extends ConsumerStatefulWidget {
  const EchoLoopApp({super.key});

  @override
  ConsumerState<EchoLoopApp> createState() => _EchoLoopAppState();
}

class _EchoLoopAppState extends ConsumerState<EchoLoopApp>
    with WidgetsBindingObserver {
  StreamSubscription<NotificationIntent>? _intentSubscription;
  ProviderSubscription<AsyncValue<Session?>>? _authSessionSubscription;
  late final ShowcaseView _showcase;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // 新手引导 showcase 控制器全局注册（替代旧的 ShowCaseWidget InheritedWidget）。
    // 整段 tour 走完或被 dismiss 时，通过 GuideShowcaseBus 触发 controller 的
    // completeActiveFlow 标记已看并清空 active。
    _showcase = ShowcaseView.register(
      enableAutoScroll: true,
      onFinish: GuideShowcaseBus.fireEnd,
      onDismiss: (_) => GuideShowcaseBus.fireEnd(),
    );

    // 预加载词典（触发下载或打开本地词典）
    ref.read(dictionaryProvider);

    // 启动即建订阅控制器：配合其 fireImmediately 监听，在启动阶段就把 RevenueCat
    // 身份绑定到当前登录用户（执行 logIn），不必等用户打开付费墙才触发；
    // 也修复已受影响用户——下次启动即重绑 / 把匿名购买 Transfer 到其 Supabase UUID。
    ref.read(subscriptionControllerProvider);

    // RevenueCat configure 后尽早预热套餐；Provider 保留本次会话的最后成功价格，
    // 用户首次打开订阅页时可直接渲染，无需等待临时网络请求。
    ref.read(subscriptionPlansProvider);

    _authSessionSubscription = ref.listenManual<AsyncValue<Session?>>(
      supabaseSessionProvider,
      (previous, next) {
        unawaited(
          ref
              .read(authAnalyticsSyncProvider)
              .syncSessionChange(
                previous: previous?.valueOrNull,
                current: next.valueOrNull,
              ),
        );
      },
      fireImmediately: true,
    );

    // 启动时先尝试从磁盘加载已缓存的 catalog（让 Discover 页一进来就有数据）。
    // 失败静默，下面的 syncAll 会按需重新拉网络。
    unawaited(
      ref.read(officialCatalogServiceProvider).loadCachedCatalog().then((_) {
        if (mounted) {
          ref.invalidate(cachedCatalogProvider);
        }
      }),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bridge = ref.read(notificationTapRouterBridgeProvider);
      _intentSubscription = bridge.intents.listen(_handleNotificationIntent);

      final pendingIntent = bridge.takePendingIntent();
      if (pendingIntent != null) {
        _handleNotificationIntent(pendingIntent);
      }
    });

    // 冷启动后异步触发 catalog 同步。force=true 绕过本地 10min 节流，
    // 避免运营刚调整精选合集后启动仍停留在旧磁盘缓存。
    Future.delayed(
      const Duration(seconds: 3),
      () => _triggerCatalogSync(force: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSubscription?.cancel();
    _authSessionSubscription?.close();
    _showcase.unregister();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _triggerCatalogSync();
        // 回前台时重对账订阅权益：用户可能刚在系统订阅页退订 / 换 plan / 续费，
        // 或退款生效。RevenueCat 有约 5 分钟缓存，频繁切前台基本命中缓存、近零成本。
        unawaited(ref.read(subscriptionControllerProvider.notifier).refresh());
        // 同时检查商店 storefront。跨区时立即撤下旧币种价格并重新读取商品；
        // 同区则遵循五分钟 TTL，避免每次短暂切后台都重复查询。
        unawaited(
          ref.read(subscriptionPlansProvider.notifier).refreshIfStale(),
        );
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 立即刷新 PostHog 埋点队列，避免 Application Backgrounded 等事件
        // 卡在内存队列里，App 被 OS 挂起 / 杀进程时丢失。
        // PostHog 默认 flushAt=20 / flushInterval=30s，单纯依赖默认策略
        // 在快速切后台场景容易丢。
        unawaited(Posthog().flush());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      // no-op
    }
  }

  /// 全局唯一同步入口；inflight + 10min 节流防止重复请求。
  /// updated 时由 helper 自动 loadLibrary + loadCollections + invalidate catalog。
  void _triggerCatalogSync({bool force = false}) {
    if (!mounted) return;
    unawaited(
      triggerOfficialSync(ref, force: force).then((outcome) {
        AppLogger.log('main', 'OfficialSync outcome=$outcome');
      }),
    );
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
      title: 'Echo Loop',
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
      scaffoldMessengerKey: officialDownloadScaffoldMessengerKey,
    );
  }
}

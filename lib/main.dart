import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'utils/time_format.dart';
import 'utils/echo_loop_scroll_behavior.dart';
import 'database/app_database.dart';
import 'database/providers.dart';
import 'config/client_distribution.dart';
import 'providers/package_info_provider.dart';
import 'providers/dictionary_provider.dart';
import 'providers/download_provider.dart';
import 'providers/pronunciation/pronunciation_providers.dart';
import 'providers/settings_provider.dart';
import 'providers/startup_bootstrap_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/review_reminder_provider.dart';
import 'services/notification_tap_router_bridge.dart';
import 'analytics/analytics_providers.dart';
import 'analytics/analytics_service.dart';
import 'analytics/models/event_names.dart';
import 'providers/learning_settings_provider.dart';
import 'providers/tts/tts_settings_provider.dart';
import 'providers/intensive_listen_prefs_provider.dart';
import 'providers/blind_listen_prefs_provider.dart';
import 'providers/retell_prefs_provider.dart';
import 'providers/difficult_practice_prefs_provider.dart';
import 'providers/new_user_guide_provider.dart';
import 'services/app_logger.dart';
import 'services/app_deep_link_router.dart';
import 'services/app_window_service.dart';
import 'services/startup_trace.dart';
import 'services/app_update_migration.dart';
import 'services/media_kit_debug_initializer.dart';
import 'services/user_id_service.dart';
import 'widgets/app_notice_presenter.dart';
import 'features/community_collections/data/trigger_community_sync.dart';
import 'features/community_collections/download/community_download_notifier.dart';
import 'features/podcast/data/podcast_catalog_service.dart';
import 'features/podcast/data/trigger_podcast_catalog_refresh.dart';
import 'features/onboarding_survey/data/onboarding_survey_storage.dart';
import 'features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/remote_config/remote_config_providers.dart';
import 'features/remote_config/remote_config_service.dart';
import 'features/user_region/user_region_providers.dart';
import 'features/subscription/providers/subscription_controller.dart';
import 'features/subscription/providers/subscription_plans_provider.dart';
import 'features/subscription/services/paddle_deep_link_handler.dart';

void main() async {
  final startupTrace = StartupTrace();
  registerStartupTrace(startupTrace);
  startupTrace.mark('dart_main_enter');
  WidgetsFlutterBinding.ensureInitialized();
  startupTrace.mark('flutter_binding_ready');
  final appWindowActivator = WindowManagerAppWindowActivator();
  await appWindowActivator.initialize();
  startupTrace.runSync('timeago_initialize', initTimeago);

  final packageInfo = await startupTrace.run(
    'package_info',
    PackageInfo.fromPlatform,
  );

  // 检查是否处于演示模式
  final prefs = await startupTrace.run(
    'shared_preferences',
    SharedPreferences.getInstance,
  );
  // SecureStorage 在新装设备上可能较慢。立即并行启动匿名 ID 初始化，但不能让它
  // 阻塞 PostHog channel ready 或首帧；完成后再注册为事件 super property。
  final anonymousIdReady = startUserIdService(prefs);
  final analyticsService = await startupTrace.run(
    'analytics_initialize',
    () => initializeAnalyticsWithFallback(prefs),
  );
  final distribution = clientDistribution;
  if (distribution != null) {
    try {
      // 安装来源是用户属性，不创建额外事件；启动时设置可覆盖匿名用户和已有用户。
      await analyticsService.setUserProperty(
        UserProperties.installSource,
        distribution.headerValue,
      );
    } catch (error, stackTrace) {
      AppLogger.log('Analytics', 'install source registration failed: $error');
      AppLogger.log('Analytics', stackTrace.toString());
    }
  }
  unawaited(_registerAnonymousIdWhenReady(anonymousIdReady, analyticsService));
  // 应用升级迁移由自身记录结构化日志，不包装成普通 StartupTrace 步骤，
  // 避免日志看起来像启动阶段重复执行了一次迁移。
  await runAppUpdateMigrations(prefs);
  final isDemoMode = prefs.getBool('demo_mode') ?? false;

  // 远程配置：启动期只同步读取本地缓存/默认值，不触发网络请求，避免网络慢阻塞首帧。
  // 下游 UI 只读取 provider 暴露的 resolved config；远端刷新由 MainShell 首帧后后台执行。
  final initialRemoteConfig = RemoteConfigService.create(
    prefs: prefs,
    appVersion: packageInfo.version,
  ).loadInitialFromCache();

  // 首次启动检测：哨兵 key `first_launch_done` 不存在即视为首次启动，
  // 立即写入 true。后续所有启动都会读到该 key = true，即非首启。
  // 注意：该机制从此版本引入，老用户升级时哨兵同样缺失，会被当作首启。
  // 需要业务层额外用数据是否为空等 gate 兜底区分升级用户。
  final isFirstLaunch = !(prefs.getBool('first_launch_done') ?? false);
  if (isFirstLaunch) {
    await startupTrace.run(
      'first_launch_marker_write',
      () => prefs.setBool('first_launch_done', true),
    );
  }

  // Onboarding 问卷"是否已完成"同步预读：GoRouter redirect 是同步函数，
  // 必须在 main() 阶段拿到值，否则启动闪屏期间 redirect 失效。
  // 用 `onboarding_completed_at_ms` 存在性判定，不引入冗余 bool key。
  final onboardingCompleted = OnboardingSurveyStorage.readIsCompletedSync(
    prefs,
  );

  // 学习设置（自动跳过复述）同步预读：plan / progress 启动期就需要拿到值。
  final initialLearningSettings = LearningSettings.fromPrefsSync(prefs);

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
  startupTrace.mark(
    'database_instance_registered',
    fields: {'demoMode': isDemoMode},
  );

  // 至此仅完成了绑定、同步 UI 偏好和数据库对象注册。首帧后的本地与第三方
  // 任务由 ProviderScope 内的标准 Riverpod 启动 provider 编排。
  startupTrace.mark('run_app_invoked');
  runApp(
    PostHogWidget(
      child: ProviderScope(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analyticsService),
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
          initialRemoteConfigProvider.overrideWithValue(initialRemoteConfig),
          startupDemoModeProvider.overrideWithValue(isDemoMode),
        ],
        child: EchoLoopApp(windowActivator: appWindowActivator),
      ),
    ),
  );
}

/// 匿名 ID 是附加事件属性，不是 PostHog distinct ID；其迟到不得丢弃已入 SDK 队列
/// 的早期事件，也不得阻塞首帧。
Future<void> _registerAnonymousIdWhenReady(
  Future<String> anonymousIdReady,
  AnalyticsService analyticsService,
) async {
  try {
    final anonymousId = await anonymousIdReady;
    await analyticsService.registerSuperProperties({
      'app_anonymous_id': anonymousId,
    });
  } catch (error, stackTrace) {
    AppLogger.log('Analytics', 'anonymous ID initialization failed: $error');
    AppLogger.log('Analytics', stackTrace.toString());
  }
}

class EchoLoopApp extends ConsumerStatefulWidget {
  const EchoLoopApp({super.key, this.windowActivator});

  final AppWindowActivator? windowActivator;

  @override
  ConsumerState<EchoLoopApp> createState() => _EchoLoopAppState();
}

class _EchoLoopAppState extends ConsumerState<EchoLoopApp>
    with WidgetsBindingObserver {
  StreamSubscription<NotificationIntent>? _intentSubscription;
  ProviderSubscription<AsyncValue<Session?>>? _authSessionSubscription;
  ProviderSubscription<AsyncValue<StartupReport>>? _localStartupSubscription;
  ProviderSubscription<AsyncValue<ThirdPartyStartupReport>>?
  _thirdPartyStartupSubscription;
  AppDeepLinkRouter? _appDeepLinkRouter;
  late final ShowcaseView _showcase;
  bool _hasLoggedRouterCreated = false;
  bool _didStartLocalEffects = false;
  Future<void>? _thirdPartyEffectsFuture;

  @override
  void initState() {
    super.initState();
    activeStartupTrace?.mark('app_widget_init_state');
    // 在本地启动任务可能发起后端请求前，初始化统一地区判定及其端点路由监听。
    ref.read(userRegionProvider);
    _localStartupSubscription = ref.listenManual<AsyncValue<StartupReport>>(
      localStartupProvider,
      (_, next) {
        if (next.hasValue) unawaited(_startAfterLocalDataReady());
      },
      fireImmediately: true,
    );
    _thirdPartyStartupSubscription = ref
        .listenManual<AsyncValue<ThirdPartyStartupReport>>(
          thirdPartyStartupProvider,
          (_, next) {
            if (next.hasValue) unawaited(_ensureThirdPartyDependentTasks());
          },
          fireImmediately: true,
        );

    WidgetsBinding.instance.addObserver(this);
    final windowActivator =
        widget.windowActivator ?? WindowManagerAppWindowActivator();

    final paddleDeepLinkHandler = PaddleDeepLinkHandler(
      refreshEntitlements: () async {
        await _ensureThirdPartyDependentTasks();
        if (!mounted || !ref.read(thirdPartyStartupProvider).hasValue) return;
        await ref
            .read(subscriptionControllerProvider.notifier)
            .refreshAfterExternalCheckout();
      },
    );
    final appDeepLinkRouter = AppDeepLinkRouter.forCurrentPlatform(
      routes: [paddleDeepLinkHandler.route],
      beforeDispatch: windowActivator.activate,
    );
    _appDeepLinkRouter = appDeepLinkRouter;
    unawaited(appDeepLinkRouter.start());

    // 新手引导 showcase 控制器全局注册（替代旧的 ShowCaseWidget InheritedWidget）。
    // 整段 tour 走完或被 dismiss 时，通过 GuideShowcaseBus 触发 controller 的
    // completeActiveFlow 标记已看并清空 active。
    _showcase = ShowcaseView.register(
      enableAutoScroll: true,
      onFinish: GuideShowcaseBus.fireEnd,
      onDismiss: (_) => GuideShowcaseBus.fireEnd(),
    );
  }

  /// 依次启动所有不属于首帧关键路径的本地预热任务。
  Future<void> _startAfterLocalDataReady() async {
    if (!mounted || _didStartLocalEffects) return;
    _didStartLocalEffects = true;
    activeStartupTrace?.mark('main_navigation_released');

    // 下载注册表和词典预热都可能访问文件系统，统一放到首帧后。
    unawaited(startRegisteredDownloads(ref));
    _scheduleMediaKitPrewarm();
    ref.read(dictionaryProvider);
    ref.read(pronunciationLibraryProvider);

    // Podcast catalog 与社区合集同步相互独立；先恢复本地精选缓存，再后台刷新，
    // 避免社区合集 v2 的同步结果改变原有 Podcast 发现页行为。
    unawaited(
      ref.read(podcastCatalogServiceProvider).loadCachedCatalog().then((_) {
        if (mounted) ref.invalidate(cachedPodcastCatalogProvider);
      }),
    );

    final bridge = ref.read(notificationTapRouterBridgeProvider);
    _intentSubscription = bridge.intents.listen(_handleNotificationIntent);
    final pendingIntent = bridge.takePendingIntent();
    if (pendingIntent != null) _handleNotificationIntent(pendingIntent);

    Future.delayed(const Duration(seconds: 3), _triggerBackgroundSync);
  }

  /// 业务内容提交后再预热，不让原生播放器依赖阻塞进入学习页。
  void _scheduleMediaKitPrewarm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        Future<void>(() {
          activeStartupTrace?.runSync(
            'media_kit_initialize',
            ensureMediaKitInitialized,
          );
        }).catchError((Object _) {}),
      );
    });
  }

  /// 等待后台 SDK 初始化完成后再创建其依赖的订阅与认证控制器。
  Future<void> _ensureThirdPartyDependentTasks() {
    final existing = _thirdPartyEffectsFuture;
    if (existing != null) return existing;

    final operation = _startThirdPartyDependentTasks();
    _thirdPartyEffectsFuture = operation;
    return operation;
  }

  Future<void> _startThirdPartyDependentTasks() async {
    try {
      await ref.read(thirdPartyStartupProvider.future);
    } catch (error, stackTrace) {
      AppLogger.log(
        'ThirdPartyStartup',
        '等待第三方启动失败，跳过依赖任务 error=$error stack=$stackTrace',
      );
      return;
    }
    if (!mounted) return;

    // RevenueCat 与 Supabase 已完成后台串行初始化；先让 session provider
    // 重新读取 SDK 当前快照，再创建订阅 controller，避免 controller 首次构造时
    // 先按匿名身份发起一次无效权益对账。
    ref.invalidate(supabaseSessionProvider);
    try {
      // Supabase.initialize() 返回不代表 auth.currentSession 已完成恢复；
      // 等待 provider 收到 initialSession，避免启动预热仍抢跑到匿名态。
      await ref.read(supabaseSessionProvider.future);
    } catch (error, stackTrace) {
      AppLogger.log(
        'AuthSession',
        '等待 initialSession 失败，保留 pending 语义 error=$error stack=$stackTrace',
      );
    }
    if (!mounted) return;
    ref.read(subscriptionControllerProvider);
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSubscription?.cancel();
    final appDeepLinkRouter = _appDeepLinkRouter;
    _appDeepLinkRouter = null;
    if (appDeepLinkRouter != null) {
      unawaited(appDeepLinkRouter.dispose());
    }
    _authSessionSubscription?.close();
    _localStartupSubscription?.close();
    _thirdPartyStartupSubscription?.close();
    _showcase.unregister();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    activeStartupTrace?.mark(
      'app_lifecycle_changed',
      fields: {'state': state.name},
    );
    AppLogger.log('Lifecycle', 'state=${state.name}');
    switch (state) {
      case AppLifecycleState.resumed:
        if (ref.read(localStartupProvider).hasValue) {
          _triggerBackgroundSync();
        }
        // 回前台时条件重对账订阅权益（E8）。单一来源下每次刷新都是真实后端请求
        // （不再有 RC SDK 客户端缓存兜着），且退款/退订分歧主要靠 E6/E7 在后端
        // 交互时被动收敛，故仅在状态陈旧 / 越过到期点 / 超过 24h 新鲜窗（兜住
        // 长期无后端流量的用户）时才回源，频繁切前台不盲查。
        if (ref.read(thirdPartyStartupProvider).hasValue) {
          unawaited(
            ref.read(subscriptionControllerProvider.notifier).refreshIfStale(),
          );
          // 同时检查商店 storefront。跨区时立即撤下旧币种价格并重新读取商品；
          // 同区则遵循五分钟 TTL，避免每次短暂切后台都重复查询。
          unawaited(
            ref.read(subscriptionPlansProvider.notifier).refreshIfStale(),
          );
        }
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

  /// 全局唯一社区合集同步入口；后台调用由 service 统一执行 2h 节流。
  void _triggerCommunitySync({bool force = false}) {
    if (!mounted) return;
    unawaited(
      triggerCommunitySync(ref, force: force).then((outcome) {
        AppLogger.log('main', 'CommunitySync outcome=${outcome.runtimeType}');
      }),
    );
  }

  /// 前台/启动后台刷新两个互不依赖的公共内容源；任一失败都不能阻塞另一方。
  void _triggerBackgroundSync({bool force = false}) {
    _triggerCommunitySync(force: force);
    unawaited(
      triggerPodcastCatalogRefresh(ref, force: force).then((outcome) {
        AppLogger.log('main', 'PodcastCatalog outcome=${outcome?.runtimeType}');
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
    if (!_hasLoggedRouterCreated) {
      _hasLoggedRouterCreated = true;
      activeStartupTrace?.mark('router_created');
    }

    return MaterialApp.router(
      title: 'Echo Loop',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const EchoLoopScrollBehavior(),
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
      builder: (context, child) =>
          AppNoticePresenter(child: child ?? const SizedBox.shrink()),
      scaffoldMessengerKey: communityDownloadScaffoldMessengerKey,
    );
  }
}

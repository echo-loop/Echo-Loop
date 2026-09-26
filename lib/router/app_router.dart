/// GoRouter 路由配置
///
/// 定义应用的路由结构和类型安全的路径常量。
/// 使用 StatefulShellRoute.indexedStack 保持 Tab 状态。
/// 详情页使用 parentNavigatorKey 确保全屏展示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics_observer.dart';
import '../analytics/analytics_providers.dart';
import '../features/auth/screens/account_screen.dart';
import '../features/subscription/screens/paywall_screen.dart';
import '../features/auth/screens/check_email_screen.dart';
import '../features/auth/screens/email_sign_in_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/password_sign_in_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/community_collections/screens/discover_collections_screen.dart';
import '../features/community_collections/screens/community_collection_detail_screen.dart';
import '../features/community_collections/community_collection_routes.dart';
import '../features/podcast/podcast_models.dart';
import '../features/podcast/screens/podcast_discovery_screen.dart';
import '../features/podcast/screens/podcast_preview_screen.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart';
import '../features/onboarding_survey/screens/onboarding_survey_screen.dart';
import '../features/subtitle_editor/subtitle_simple_editor_screen.dart';
import '../models/audio_item.dart';
import '../services/app_logger.dart';
import '../screens/library_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/study_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/learning_plan_screen.dart';
import '../screens/player_screen.dart';
import '../screens/media_playback_screen.dart';
import '../screens/blind_listen_player_screen.dart';
import '../screens/intensive_listen_player_screen.dart';
import '../models/media_learning_startup.dart';
import '../screens/listen_and_repeat_player_screen.dart';
import '../screens/retell_player_screen.dart';
import '../screens/review_difficult_practice_screen.dart';
import '../screens/bookmark_review_screen.dart';
import '../screens/sentence_detail_screen.dart';
import '../screens/pdf_preview_screen.dart';
import '../screens/backup_restore_screen.dart';
import '../screens/favorite_vocabulary_review_screen.dart';
import '../screens/activity_calendar_screen.dart';
import '../screens/review_statistics_screen.dart';
import 'main_shell.dart';

/// 全局根导航器 key
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 监听 MainShell 所在 root route 被全屏页面覆盖与恢复。
final rootRouteObserver = RouteObserver<ModalRoute<void>>();

/// 路由路径常量 + 类型安全的路径构建方法
abstract class AppRoutes {
  static const collections = '/collections';

  /// 发现资源列表和合集详情留在资源库主导航壳中的路径。
  static const discoverResources = CommunityCollectionRoutes.discoverResources;
  static const study = '/study';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const login = '/login';
  static const emailSignIn = '/login/email';
  static const checkEmail = '/login/check-email';

  /// 隐藏的邮箱密码登录入口（App Store / Google Play 审核员专用）。
  static const passwordSignIn = '/login/password';
  static const account = '/account';

  /// Podcast 搜索与订阅统一页，位于资源库主导航壳中。
  static const podcastSubscribeSegment = 'podcast-subscribe';
  static const podcastSubscribe = '$collections/$podcastSubscribeSegment';

  /// 旧版全屏 Podcast 搜索页路径，用于兼容已发出的链接。
  static const legacyPodcastSubscribe = '/podcast-subscribe';

  /// Podcast 单集预览页路径段（挂在 [podcastSubscribe] 之下的相对子路由）。
  static const podcastPreviewSegment = 'preview';

  /// 合集详情页路径
  static String collectionDetail(String collectionId) =>
      '/collections/$collectionId';

  /// 发现资源中的公开合集详情页路径。
  static String discoverCollection(String remoteId) =>
      CommunityCollectionRoutes.discoverCollection(remoteId);

  /// 学习计划页路径
  /// [autoStart] 为 true 时进入后自动弹出学习任务
  static String learningPlan(
    String collectionId,
    String audioId, {
    bool autoStart = false,
  }) => autoStart
      ? '/collections/$collectionId/$audioId/plan?autoStart=true'
      : '/collections/$collectionId/$audioId/plan';

  /// 播放器页路径
  static String player(String collectionId, String audioId) =>
      '/collections/$collectionId/$audioId/player';

  /// 盲听播放器页路径
  static String blindListenPlayer(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/blind-listen'
      : '/audio/$audioId/blind-listen';

  /// 精听播放器页路径
  static String intensiveListenPlayer(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/intensive-listen'
      : '/audio/$audioId/intensive-listen';

  /// 跟读播放器页路径
  static String listenAndRepeatPlayer(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/listen-and-repeat'
      : '/audio/$audioId/listen-and-repeat';

  /// 复述播放器页路径
  static String retellPlayer(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/retell'
      : '/audio/$audioId/retell';

  /// 媒体随心听页路径段。
  static const mediaPlayerSegment = 'media-player';

  /// 媒体随心听页。collectionId 为 null 时为独立音频变体。
  static String mediaPlayer(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/$mediaPlayerSegment'
      : '/audio/$audioId/$mediaPlayerSegment';

  /// 独立音频学习计划页路径（不依赖合集）
  /// [autoStart] 为 true 时进入后自动弹出学习任务
  static String audioLearningPlan(String audioId, {bool autoStart = false}) =>
      autoStart
      ? '/audio/$audioId/plan?autoStart=true'
      : '/audio/$audioId/plan';

  /// 独立音频播放器页路径（不依赖合集）
  static String audioPlayer(String audioId) => '/audio/$audioId/player';

  /// 简版字幕编辑页路径
  static String subtitleEditor(String audioId) =>
      '/audio/$audioId/subtitles/edit';

  /// 收藏句子复习页路径
  static const bookmarkReview = '/bookmark-review';

  /// 句子详情页路径段（挂在各播放页 / 收藏页之下的相对子路由）
  static const sentenceDetailSegment = 'sentence-detail';

  /// 学习材料 PDF 导出预览页路径段（挂在计划页 / 合集页之下的相对子路由）
  static const pdfPreviewSegment = 'pdf-preview';
  static const backupRestore = '/backup-restore';

  /// 收藏词汇（单词+意群）调度式复习页路径
  static const favoriteVocabularyReview = '/favorite-vocabulary-review';

  /// 活动日历页路径
  static const activityCalendar = '/activity-calendar';
  static const reviewStatistics = '/review-statistics';

  /// 难句补练页路径
  static String reviewDifficultPractice(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/review-difficult-practice'
      : '/audio/$audioId/review-difficult-practice';

  /// Onboarding 问卷页路径（仅首启新用户访问）
  static const onboardingSurvey = '/onboarding/survey';

  /// 订阅计划介绍 / 购买页（Paywall）
  static const paywall = '/paywall';

  /// 在「当前路由位置之下」push 一个嵌套路由子页。
  ///
  /// 使子页 URL 携带完整入口栈（如 `/collections/c/a/player/sentence-detail`），
  /// 避免框架以 null state 按 URI 重解析时把 shell 分支塌回资源库根、返回时多退
  /// （§7.17）。子页必须已声明为当前路由的子路由，否则 go_router 抛「no route」，
  /// 把静默偶发 bug 变成即时可见错误。
  ///
  /// [segment] 传相对路径段（如 [sentenceDetailSegment]），[extra] 透传给子页。
  static Future<T?> pushNested<T extends Object?>(
    BuildContext context,
    String segment, {
    Object? extra,
  }) {
    // matchedLocation 为已解析、不含 query 的当前路由路径。
    final base = GoRouterState.of(context).matchedLocation;
    final sep = base.endsWith('/') ? '' : '/';
    return context.push<T>('$base$sep$segment', extra: extra);
  }

  /// 挂载路由 path 调试日志，记录 GoRouter 每次完成导航后的最终 URI。
  ///
  /// 直接监听 [GoRouter.routeInformationProvider]，能覆盖 `go` / `push` / `pop`
  /// 以及 StatefulShellRoute 重解析后的最终地址；返回值用于 Provider dispose 时解绑。
  static VoidCallback attachNavigationPathLogger(GoRouter router) {
    String? lastUri;

    void logCurrentRoute() {
      final uri = router.routeInformationProvider.value.uri;
      final uriText = uri.toString();
      if (uriText == lastUri) return;
      lastUri = uriText;
      AppLogger.log('Navigation', 'path=${uri.path} uri=$uriText');
    }

    router.routeInformationProvider.addListener(logCurrentRoute);
    logCurrentRoute();
    return () =>
        router.routeInformationProvider.removeListener(logCurrentRoute);
  }
}

/// 句子讲解页子路由工厂。
///
/// 挂在各播放页（随心听 / 盲听 / 复述）与收藏页之下，路径为相对段
/// [AppRoutes.sentenceDetailSegment]，仍带 rootNavigatorKey 全屏无 tab bar。
/// 嵌套使其 URL 携带完整入口栈，避免 §7.17 重解析塌栈。
///
/// extra 在 Android Activity 重建等场景恢复时不可序列化 → 可能为 null；此时
/// 无法重建自身内容，交由 [_RestoredRoutePopper] 首帧退回已重建的入口页。
GoRoute _sentenceDetailRoute() => GoRoute(
  path: AppRoutes.sentenceDetailSegment,
  parentNavigatorKey: rootNavigatorKey,
  builder: (context, state) {
    final args = state.extra;
    if (args is! SentenceDetailArgs) return const _RestoredRoutePopper();
    return SentenceDetailScreen(args: args);
  },
);

/// 音频随心听播放器路由工厂。合集内变体挂在 `/collections/:collectionId` 之下
/// （[path] 传相对段），独立音频变体挂在顶层（[path] 传绝对路径）。
///
/// 同 §7.17：嵌套让 URL 自表达完整栈；extra 重解析丢失时首帧退回入口页。
GoRoute _audioPlayerRoute(String path) => GoRoute(
  path: path,
  parentNavigatorKey: rootNavigatorKey,
  builder: (context, state) => const PlayerScreen(),
  routes: [_sentenceDetailRoute()],
);

/// 媒体随心听播放器路由工厂，路径形式与 [_audioPlayerRoute] 相同。
GoRoute _mediaPlayerRoute(String path) => GoRoute(
  path: path,
  parentNavigatorKey: rootNavigatorKey,
  builder: (context, state) {
    final item = state.extra;
    if (item is! AudioItem) return const _RestoredRoutePopper();
    return MediaPlaybackScreen(audioItem: item);
  },
  routes: [_sentenceDetailRoute()],
);

/// PDF 导出预览页子路由工厂。挂在计划页 / 合集页 / 资源库之下，同上说明。
GoRoute _pdfPreviewRoute() => GoRoute(
  path: AppRoutes.pdfPreviewSegment,
  parentNavigatorKey: rootNavigatorKey,
  builder: (context, state) {
    final item = state.extra;
    if (item is! AudioItem) return const _RestoredRoutePopper();
    return PdfPreviewScreen(audioItem: item);
  },
);

/// GoRouter Provider（keepAlive，不可 invalidate）
final appRouterProvider = Provider<GoRouter>((ref) {
  final analyticsService = ref.read(analyticsServiceProvider);
  AppLogger.log(
    'Navigation',
    'router_create initialLocation=${AppRoutes.study}',
  );
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.study,
    observers: [rootRouteObserver, AnalyticsObserver(analyticsService)],
    redirect: (context, state) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      final isAuthRoute =
          state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.emailSignIn ||
          state.uri.path == AppRoutes.checkEmail ||
          state.uri.path == AppRoutes.passwordSignIn;
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.settings;
      }
      if (!isAuthenticated && state.uri.path == AppRoutes.account) {
        return AppRoutes.settings;
      }
      // /onboarding/survey 自身路径必须早返，否则在拦截路径上产生死循环
      if (state.uri.path == AppRoutes.onboardingSurvey) return null;
      // 首启新用户、未完成且未学习过 → 强制进入问卷
      if (ref.read(shouldShowSurveyProvider)) {
        return AppRoutes.onboardingSurvey;
      }
      if (state.uri.path == '/') return AppRoutes.study;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collections',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  _pdfPreviewRoute(),
                  // 发现页属于资源库入口流程，留在 branch-0 内以持续显示主导航。
                  GoRoute(
                    path: CommunityCollectionRoutes.discoverSegment,
                    builder: (context, state) =>
                        const DiscoverCommunityCollectionsScreen(),
                    routes: [
                      GoRoute(
                        path: ':remoteId',
                        builder: (context, state) {
                          final remoteId = state.pathParameters['remoteId'];
                          if (remoteId == null) {
                            return const _RestoredRoutePopper();
                          }
                          return CommunityCollectionDetailScreen(
                            remoteId: remoteId,
                          );
                        },
                      ),
                    ],
                  ),
                  // Podcast 搜索和单集预览共用资源库 branch，保持主导航可见。
                  GoRoute(
                    path: AppRoutes.podcastSubscribeSegment,
                    builder: (context, state) => const PodcastDiscoveryScreen(),
                    routes: [
                      GoRoute(
                        path: AppRoutes.podcastPreviewSegment,
                        // Android Activity 重建可能丢失 extra；无法还原预览时
                        // 由首帧 popper 回到搜索页。
                        builder: (context, state) {
                          final arg = state.extra;
                          if (arg is! PodcastPreviewArg) {
                            return const _RestoredRoutePopper();
                          }
                          return PodcastPreviewScreen(arg: arg);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':collectionId',
                    builder: (context, state) {
                      final collectionId =
                          state.pathParameters['collectionId']!;
                      return CollectionDetailScreen(collectionId: collectionId);
                    },
                    // 合集内的音频子页面（学习计划 / 各播放器）作为「合集详情」的
                    // 子路由嵌套，但仍带 rootNavigatorKey 全屏展示（无 tab bar）。
                    //
                    // 必须嵌套而非声明成顶层路由：这些路径与 branch-0 的 /collections
                    // 前缀重叠，若拍平在顶层，框架以 null state 回灌当前 URI 触发
                    // findMatch 重解析时，URI 里不携带「合集详情」这层 imperative push
                    // 的记录，shell 分支会被重置回初始 location（资源库根），返回时
                    // 自动多退一层。嵌套后该层级由 URI 自身表达，重解析不再丢失。
                    // 详见 CLAUDE.md §7.17。
                    routes: [
                      _pdfPreviewRoute(),
                      GoRoute(
                        path: ':audioId/plan',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final autoStart =
                              state.uri.queryParameters['autoStart'] == 'true';
                          return LearningPlanScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            autoStart: autoStart,
                          );
                        },
                        routes: [_pdfPreviewRoute()],
                      ),
                      _audioPlayerRoute(':audioId/player'),
                      _mediaPlayerRoute(
                        ':audioId/${AppRoutes.mediaPlayerSegment}',
                      ),
                      GoRoute(
                        path: ':audioId/blind-listen',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final startup = state.extra;
                          return BlindListenPlayerScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            mediaStartup: startup is MediaLearningStartup
                                ? startup
                                : null,
                          );
                        },
                        routes: [_sentenceDetailRoute()],
                      ),
                      GoRoute(
                        path: ':audioId/intensive-listen',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final startup = state.extra;
                          return IntensiveListenPlayerScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            mediaStartup: startup is MediaLearningStartup
                                ? startup
                                : null,
                          );
                        },
                      ),
                      GoRoute(
                        path: ':audioId/listen-and-repeat',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final startup = state.extra;
                          return ListenAndRepeatPlayerScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            mediaStartup: startup is MediaLearningStartup
                                ? startup
                                : null,
                          );
                        },
                      ),
                      GoRoute(
                        path: ':audioId/retell',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final startup = state.extra;
                          return RetellPlayerScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            mediaStartup: startup is MediaLearningStartup
                                ? startup
                                : null,
                          );
                        },
                        routes: [_sentenceDetailRoute()],
                      ),
                      GoRoute(
                        path: ':audioId/review-difficult-practice',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final collectionId =
                              state.pathParameters['collectionId']!;
                          final audioId = state.pathParameters['audioId']!;
                          final startup = state.extra;
                          return ReviewDifficultPracticeScreen(
                            collectionId: collectionId,
                            audioItemId: audioId,
                            mediaStartup: startup is MediaLearningStartup
                                ? startup
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const StudyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
                routes: [_sentenceDetailRoute()],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Onboarding 问卷（首启新用户全屏，无 tab bar / 不可返回）
      GoRoute(
        path: AppRoutes.backupRestore,
        builder: (context, state) => const BackupRestoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingSurvey,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OnboardingSurveyScreen(),
      ),
      // 账号与登录流程（全屏）
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailSignIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String ? extra : '';
          return EmailSignInScreen(initialEmail: email);
        },
      ),
      GoRoute(
        path: AppRoutes.checkEmail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String ? extra : '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: AppRoutes.passwordSignIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PasswordSignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.account,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PaywallScreen(),
      ),
      // 收藏句子复习（全屏）
      GoRoute(
        path: '/bookmark-review',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BookmarkReviewScreen(),
      ),
      // 句子详情 / PDF 预览已下沉为各入口页的嵌套子路由（§7.17），
      // 见 _sentenceDetailRoute() / _pdfPreviewRoute() 的挂载点。
      // 收藏词汇（单词+意群）调度式复习（全屏）
      GoRoute(
        path: AppRoutes.favoriteVocabularyReview,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoriteVocabularyReviewScreen(),
      ),
      // 活动日历（全屏）
      GoRoute(
        path: '/activity-calendar',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActivityCalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.reviewStatistics,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReviewStatisticsScreen(),
      ),
      // 兼容已发出的旧发现页链接，统一导向资源库主导航壳内的新路径。
      GoRoute(
        path: CommunityCollectionRoutes.legacyDiscover,
        redirect: (context, state) =>
            state.uri.path == CommunityCollectionRoutes.legacyDiscover
            ? AppRoutes.discoverResources
            : null,
        routes: [
          GoRoute(
            path: ':remoteId',
            redirect: (context, state) {
              final remoteId = state.pathParameters['remoteId'];
              if (remoteId == null) return AppRoutes.discoverResources;
              return AppRoutes.discoverCollection(remoteId);
            },
          ),
        ],
      ),
      // 兼容旧版全屏 Podcast 搜索和预览链接，统一导向主导航壳内的新路径。
      GoRoute(
        path: AppRoutes.legacyPodcastSubscribe,
        redirect: (context, state) =>
            state.uri.path == AppRoutes.legacyPodcastSubscribe
            ? AppRoutes.podcastSubscribe
            : null,
        routes: [
          GoRoute(
            path: AppRoutes.podcastPreviewSegment,
            redirect: (context, state) =>
                '${AppRoutes.podcastSubscribe}/'
                '${AppRoutes.podcastPreviewSegment}',
          ),
        ],
      ),
      // 独立音频路由（不依赖合集）
      GoRoute(
        path: '/audio/:audioId/plan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final autoStart = state.uri.queryParameters['autoStart'] == 'true';
          return LearningPlanScreen(
            collectionId: null,
            audioItemId: audioId,
            autoStart: autoStart,
          );
        },
        routes: [_pdfPreviewRoute()],
      ),
      _audioPlayerRoute('/audio/:audioId/player'),
      _mediaPlayerRoute('/audio/:audioId/${AppRoutes.mediaPlayerSegment}'),
      GoRoute(
        path: '/audio/:audioId/subtitles/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! AudioItem) {
            throw StateError('Subtitle editor requires AudioItem extra');
          }
          return SubtitleSimpleEditorScreen(audioItem: extra);
        },
      ),
      GoRoute(
        path: '/audio/:audioId/blind-listen',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final startup = state.extra;
          return BlindListenPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
            mediaStartup: startup is MediaLearningStartup ? startup : null,
          );
        },
        routes: [_sentenceDetailRoute()],
      ),
      GoRoute(
        path: '/audio/:audioId/intensive-listen',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final startup = state.extra;
          return IntensiveListenPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
            mediaStartup: startup is MediaLearningStartup ? startup : null,
          );
        },
      ),
      GoRoute(
        path: '/audio/:audioId/listen-and-repeat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final startup = state.extra;
          return ListenAndRepeatPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
            mediaStartup: startup is MediaLearningStartup ? startup : null,
          );
        },
      ),
      GoRoute(
        path: '/audio/:audioId/retell',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final startup = state.extra;
          return RetellPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
            mediaStartup: startup is MediaLearningStartup ? startup : null,
          );
        },
        routes: [_sentenceDetailRoute()],
      ),
      GoRoute(
        path: '/audio/:audioId/review-difficult-practice',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final startup = state.extra;
          return ReviewDifficultPracticeScreen(
            collectionId: null,
            audioItemId: audioId,
            mediaStartup: startup is MediaLearningStartup ? startup : null,
          );
        },
      ),
    ],
  );
  final detachNavigationLogger = AppRoutes.attachNavigationPathLogger(router);
  AppLogger.log(
    'Navigation',
    'router_created currentUri=${router.routeInformationProvider.value.uri}',
  );
  ref.onDispose(detachNavigationLogger);
  return router;
});

/// 全屏子页在 extra 丢失（如 Android Activity 重建后按 URI 重解析、extra 不可序列化）
/// 时的兜底占位：首帧退回栈中已重建的入口页，避免因缺参数崩溃或白屏卡死。
class _RestoredRoutePopper extends StatefulWidget {
  const _RestoredRoutePopper();

  @override
  State<_RestoredRoutePopper> createState() => _RestoredRoutePopperState();
}

class _RestoredRoutePopperState extends State<_RestoredRoutePopper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uri = GoRouter.of(context).routeInformationProvider.value.uri;
      final canPop = context.canPop();
      AppLogger.log(
        'Navigation',
        'restored-route-popper reason=missing-extra '
            'path=${uri.path} uri=$uri canPop=$canPop',
      );
      if (canPop) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

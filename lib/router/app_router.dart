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
import '../features/auth/screens/check_email_screen.dart';
import '../features/auth/screens/email_sign_in_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/password_sign_in_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/official_collections/screens/discover_collections_screen.dart';
import '../features/official_collections/screens/official_collection_detail_screen.dart';
import '../features/onboarding_survey/providers/onboarding_survey_provider.dart';
import '../features/onboarding_survey/screens/onboarding_survey_screen.dart';
import '../features/subtitle_editor/subtitle_simple_editor_screen.dart';
import '../models/audio_item.dart';
import '../screens/library_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/study_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/learning_plan_screen.dart';
import '../screens/player_screen.dart';
import '../screens/blind_listen_player_screen.dart';
import '../screens/intensive_listen_player_screen.dart';
import '../screens/listen_and_repeat_player_screen.dart';
import '../screens/retell_player_screen.dart';
import '../screens/review_difficult_practice_screen.dart';
import '../screens/bookmark_review_screen.dart';
import '../screens/sentence_detail_screen.dart';
import '../screens/flashcard_screen.dart';
import '../screens/activity_calendar_screen.dart';
import 'main_shell.dart';

/// 全局根导航器 key
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 路由路径常量 + 类型安全的路径构建方法
abstract class AppRoutes {
  static const collections = '/collections';
  static const study = '/study';
  static const favorites = '/favorites';
  static const settings = '/settings';
  static const login = '/login';
  static const emailSignIn = '/login/email';
  static const checkEmail = '/login/check-email';

  /// 隐藏的邮箱密码登录入口（App Store / Google Play 审核员专用）。
  static const passwordSignIn = '/login/password';
  static const account = '/account';

  /// 合集详情页路径
  static String collectionDetail(String collectionId) =>
      '/collections/$collectionId';

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

  /// 句子详情页路径（通用）
  static const sentenceDetail = '/sentence-detail';

  /// Flashcard 单词卡片复习页路径
  static const flashcard = '/flashcard';

  /// 活动日历页路径
  static const activityCalendar = '/activity-calendar';

  /// 难句补练页路径
  static String reviewDifficultPractice(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/review-difficult-practice'
      : '/audio/$audioId/review-difficult-practice';

  /// Onboarding 问卷页路径（仅首启新用户访问）
  static const onboardingSurvey = '/onboarding/survey';
}

/// GoRouter Provider（keepAlive，不可 invalidate）
final appRouterProvider = Provider<GoRouter>((ref) {
  final analyticsService = ref.read(analyticsServiceProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.study,
    observers: [AnalyticsObserver(analyticsService)],
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
                  GoRoute(
                    path: ':collectionId',
                    builder: (context, state) {
                      final collectionId =
                          state.pathParameters['collectionId']!;
                      return CollectionDetailScreen(collectionId: collectionId);
                    },
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
      // 收藏句子复习（全屏）
      GoRoute(
        path: '/bookmark-review',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BookmarkReviewScreen(),
      ),
      // 句子详情（通用，全屏）
      GoRoute(
        path: '/sentence-detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra! as SentenceDetailArgs;
          return SentenceDetailScreen(args: args);
        },
      ),
      // Flashcard 单词卡片复习（全屏）
      GoRoute(
        path: '/flashcard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FlashcardScreen(),
      ),
      // 活动日历（全屏）
      GoRoute(
        path: '/activity-calendar',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActivityCalendarScreen(),
      ),
      // 发现官方合集（全屏）
      GoRoute(
        path: '/discover',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DiscoverCollectionsScreen(),
        routes: [
          GoRoute(
            path: ':remoteId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final remoteId = state.pathParameters['remoteId']!;
              return OfficialCollectionDetailScreen(remoteId: remoteId);
            },
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
      ),
      GoRoute(
        path: '/audio/:audioId/player',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PlayerScreen(),
      ),
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
          return BlindListenPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/audio/:audioId/intensive-listen',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          return IntensiveListenPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/audio/:audioId/listen-and-repeat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          return ListenAndRepeatPlayerScreen(
            collectionId: null,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/audio/:audioId/retell',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          return RetellPlayerScreen(collectionId: null, audioItemId: audioId);
        },
      ),
      GoRoute(
        path: '/audio/:audioId/review-difficult-practice',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          return ReviewDifficultPracticeScreen(
            collectionId: null,
            audioItemId: audioId,
          );
        },
      ),
      // 合集内的子页面（全屏，无 tab bar）
      GoRoute(
        path: '/collections/:collectionId/:audioId/plan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          final autoStart = state.uri.queryParameters['autoStart'] == 'true';
          return LearningPlanScreen(
            collectionId: collectionId,
            audioItemId: audioId,
            autoStart: autoStart,
          );
        },
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/player',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PlayerScreen(),
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/blind-listen',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          return BlindListenPlayerScreen(
            collectionId: collectionId,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/intensive-listen',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          return IntensiveListenPlayerScreen(
            collectionId: collectionId,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/listen-and-repeat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          return ListenAndRepeatPlayerScreen(
            collectionId: collectionId,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/retell',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          return RetellPlayerScreen(
            collectionId: collectionId,
            audioItemId: audioId,
          );
        },
      ),
      GoRoute(
        path: '/collections/:collectionId/:audioId/review-difficult-practice',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final collectionId = state.pathParameters['collectionId']!;
          final audioId = state.pathParameters['audioId']!;
          return ReviewDifficultPracticeScreen(
            collectionId: collectionId,
            audioItemId: audioId,
          );
        },
      ),
    ],
  );
});

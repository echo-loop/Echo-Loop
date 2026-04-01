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
import '../screens/library_screen.dart';
import '../screens/collection_detail_screen.dart';
import '../screens/study_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/learning_plan_screen.dart';
import '../screens/player_screen.dart';
import '../screens/blind_listen_player_screen.dart';
import '../screens/intensive_listen_player_screen.dart';
import '../screens/shadowing_player_screen.dart';
import '../screens/retell_player_screen.dart';
import '../screens/review_difficult_practice_screen.dart';
import '../screens/bookmark_review_screen.dart';
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

  /// 合集详情页路径
  static String collectionDetail(String collectionId) =>
      '/collections/$collectionId';

  /// 学习计划页路径
  /// [autoStart] 为 true 时进入后自动弹出学习任务
  static String learningPlan(
    String collectionId,
    String audioId, {
    bool autoStart = false,
  }) =>
      autoStart
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
  static String shadowingPlayer(String? collectionId, String audioId) =>
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
  static String audioLearningPlan(
    String audioId, {
    bool autoStart = false,
  }) =>
      autoStart
          ? '/audio/$audioId/plan?autoStart=true'
          : '/audio/$audioId/plan';

  /// 独立音频播放器页路径（不依赖合集）
  static String audioPlayer(String audioId) => '/audio/$audioId/player';

  /// 收藏句子复习页路径
  static const bookmarkReview = '/bookmark-review';

  /// Flashcard 单词卡片复习页路径
  static const flashcard = '/flashcard';

  /// 活动日历页路径
  static const activityCalendar = '/activity-calendar';

  /// 难句补练页路径
  static String reviewDifficultPractice(String? collectionId, String audioId) =>
      collectionId != null
      ? '/collections/$collectionId/$audioId/review-difficult-practice'
      : '/audio/$audioId/review-difficult-practice';
}

/// GoRouter Provider（keepAlive，不可 invalidate）
final appRouterProvider = Provider<GoRouter>((ref) {
  final analyticsService = ref.read(analyticsServiceProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.study,
    observers: [AnalyticsObserver(analyticsService)],
    redirect: (context, state) {
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
                      return CollectionDetailScreen(
                        collectionId: collectionId,
                      );
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
      // 收藏句子复习（全屏）
      GoRoute(
        path: '/bookmark-review',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BookmarkReviewScreen(),
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
      // 独立音频路由（不依赖合集）
      GoRoute(
        path: '/audio/:audioId/plan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final audioId = state.pathParameters['audioId']!;
          final autoStart =
              state.uri.queryParameters['autoStart'] == 'true';
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
          return ShadowingPlayerScreen(
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
          final autoStart =
              state.uri.queryParameters['autoStart'] == 'true';
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
          return ShadowingPlayerScreen(
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

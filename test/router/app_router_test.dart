/// GoRouter 路由配置测试
///
/// 验证路由结构、重定向、路径参数传递等。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/features/community_collections/community_collection_routes.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/package_info_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/mock_providers.dart';

void main() {
  final testPackageInfo = PackageInfo(
    appName: 'Echo Loop',
    packageName: 'top.echo-loop',
    version: '1.0.0',
    buildNumber: '1',
  );

  Widget createRouterTestApp(GoRouter router) {
    return ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => TestAppSettings()),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
        listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
        audioEngineProvider.overrideWith(() => TestAudioEngine()),
        packageInfoProvider.overrideWithValue(testPackageInfo),
      ],
      child: MaterialApp.router(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  group('AppRoutes', () {
    test('路径常量正确', () {
      expect(AppRoutes.collections, '/collections');
      expect(AppRoutes.discoverResources, '/collections/discover');
      expect(AppRoutes.study, '/study');
      expect(AppRoutes.favorites, '/favorites');
      expect(AppRoutes.settings, '/settings');
      expect(AppRoutes.backupRestore, '/backup-restore');
    });

    test('collectionDetail 构建正确路径', () {
      expect(AppRoutes.collectionDetail('abc-123'), '/collections/abc-123');
    });

    test('发现资源详情构建正确路径', () {
      expect(
        AppRoutes.discoverCollection('remote-123'),
        '/collections/discover/remote-123',
      );
    });

    test('learningPlan 构建正确路径', () {
      expect(
        AppRoutes.learningPlan('col-1', 'audio-2'),
        '/collections/col-1/audio-2/plan',
      );
    });

    test('player 构建正确路径', () {
      expect(
        AppRoutes.player('col-1', 'audio-2'),
        '/collections/col-1/audio-2/player',
      );
    });

    test('独立音频学习路径可用于 Universal Links', () {
      expect(AppRoutes.audioLearningPlan('audio-2'), '/audio/audio-2/plan');
      expect(AppRoutes.audioPlayer('audio-2'), '/audio/audio-2/player');
      expect(
        AppRoutes.blindListenPlayer(null, 'audio-2'),
        '/audio/audio-2/blind-listen',
      );
      expect(
        AppRoutes.intensiveListenPlayer(null, 'audio-2'),
        '/audio/audio-2/intensive-listen',
      );
      expect(
        AppRoutes.listenAndRepeatPlayer(null, 'audio-2'),
        '/audio/audio-2/listen-and-repeat',
      );
      expect(AppRoutes.retellPlayer(null, 'audio-2'), '/audio/audio-2/retell');
      expect(
        AppRoutes.reviewDifficultPractice(null, 'audio-2'),
        '/audio/audio-2/review-difficult-practice',
      );
    });

    test('全屏功能页路径可用于 Universal Links', () {
      expect(AppRoutes.bookmarkReview, '/bookmark-review');
    });

    test('讲解页 / PDF 预览为相对路径段（嵌套子路由，防塌栈 §7.17）', () {
      expect(AppRoutes.sentenceDetailSegment, 'sentence-detail');
      expect(AppRoutes.pdfPreviewSegment, 'pdf-preview');
    });

    test('Podcast 搜索订阅页与预览子路由段正确', () {
      expect(AppRoutes.podcastSubscribeSegment, 'podcast-subscribe');
      expect(AppRoutes.podcastSubscribe, '/collections/podcast-subscribe');
      expect(AppRoutes.legacyPodcastSubscribe, '/podcast-subscribe');
      expect(AppRoutes.podcastPreviewSegment, 'preview');
    });

    test('媒体随心听页两种变体路径正确', () {
      expect(AppRoutes.mediaPlayerSegment, 'media-player');
      expect(
        AppRoutes.mediaPlayer('c1', 'a1'),
        '/collections/c1/a1/media-player',
      );
      expect(AppRoutes.mediaPlayer(null, 'a1'), '/audio/a1/media-player');
    });
  });

  group('GoRouter 配置', () {
    testWidgets('发现和 Podcast 页面留在主导航壳内，旧链接重定向后也保留导航', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.collections,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                key: const ValueKey('main-navigation'),
                selectedIndex: navigationShell.currentIndex,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.school),
                    label: 'Study',
                  ),
                ],
              ),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.collections,
                    builder: (context, state) =>
                        const Scaffold(body: Text('library')),
                    routes: [
                      GoRoute(
                        path: CommunityCollectionRoutes.discoverSegment,
                        builder: (context, state) =>
                            const Scaffold(body: Text('discover')),
                        routes: [
                          GoRoute(
                            path: ':remoteId',
                            builder: (context, state) =>
                                const Scaffold(body: Text('discover-detail')),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: AppRoutes.podcastSubscribeSegment,
                        builder: (context, state) =>
                            const Scaffold(body: Text('podcast-search')),
                        routes: [
                          GoRoute(
                            path: AppRoutes.podcastPreviewSegment,
                            builder: (context, state) =>
                                const Scaffold(body: Text('podcast-preview')),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: ':collectionId',
                        builder: (context, state) =>
                            const Scaffold(body: Text('collection-detail')),
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.study,
                    builder: (context, state) =>
                        const Scaffold(body: Text('study')),
                  ),
                ],
              ),
            ],
          ),
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
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();
      expect(find.text('library'), findsOneWidget);

      router.push<void>(CommunityCollectionRoutes.legacyDiscover);
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.push<void>(AppRoutes.discoverCollection('remote-123'));
      await tester.pumpAndSettle();
      expect(find.text('discover-detail'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('discover'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.go('${CommunityCollectionRoutes.legacyDiscover}/remote-123');
      await tester.pumpAndSettle();
      expect(find.text('discover-detail'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.push<void>(AppRoutes.podcastSubscribe);
      await tester.pumpAndSettle();
      expect(find.text('podcast-search'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.push<void>(
        '${AppRoutes.podcastSubscribe}/${AppRoutes.podcastPreviewSegment}',
      );
      await tester.pumpAndSettle();
      expect(find.text('podcast-preview'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('podcast-search'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.go(AppRoutes.legacyPodcastSubscribe);
      await tester.pumpAndSettle();
      expect(find.text('podcast-search'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);

      router.go(
        '${AppRoutes.legacyPodcastSubscribe}/'
        '${AppRoutes.podcastPreviewSegment}',
      );
      await tester.pumpAndSettle();
      expect(find.text('podcast-preview'), findsOneWidget);
      expect(find.byKey(const ValueKey('main-navigation')), findsOneWidget);
    });

    testWidgets('导航完成后打印当前 path 与 uri，并对重复 URI 去重', (tester) async {
      AppLogger.instance.clear();
      final router = GoRouter(
        initialLocation: AppRoutes.study,
        routes: [
          GoRoute(
            path: AppRoutes.study,
            builder: (context, state) => const Scaffold(body: Text('study')),
          ),
          GoRoute(
            path: AppRoutes.collections,
            builder: (context, state) =>
                const Scaffold(body: Text('collections')),
            routes: [
              GoRoute(
                path: ':collectionId/:audioId/player',
                builder: (context, state) =>
                    const Scaffold(body: Text('player')),
                routes: [
                  GoRoute(
                    path: AppRoutes.sentenceDetailSegment,
                    builder: (context, state) =>
                        const Scaffold(body: Text('sentence-detail')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final detachLogger = AppRoutes.attachNavigationPathLogger(router);
      addTearDown(detachLogger);

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();
      expect(
        AppLogger.instance.entries.map((e) => e.toString()),
        contains(contains('[Navigation] path=/study uri=/study')),
      );

      router.go('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      expect(
        AppLogger.instance.entries.map((e) => e.toString()),
        contains(
          contains(
            '[Navigation] path=/collections/c1/a1/player '
            'uri=/collections/c1/a1/player',
          ),
        ),
      );

      final countBeforeDuplicate = AppLogger.instance.entries.length;
      router.go('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      expect(AppLogger.instance.entries.length, countBeforeDuplicate);

      router.push('/collections/c1/a1/player/sentence-detail');
      await tester.pumpAndSettle();
      expect(
        AppLogger.instance.entries.map((e) => e.toString()),
        contains(
          contains(
            '[Navigation] path=/collections/c1/a1/player/sentence-detail '
            'uri=/collections/c1/a1/player/sentence-detail',
          ),
        ),
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(
        AppLogger.instance.entries.last.toString(),
        contains(
          '[Navigation] path=/collections/c1/a1/player '
          'uri=/collections/c1/a1/player',
        ),
      );
    });

    testWidgets('初始路由为 /study', (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.study,
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) =>
                const Scaffold(body: Text('Study Page')),
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Study Page'), findsOneWidget);
    });

    testWidgets('/ 重定向到 /study', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        redirect: (context, state) {
          if (state.uri.path == '/') return AppRoutes.study;
          return null;
        },
        routes: [
          GoRoute(
            path: '/study',
            builder: (context, state) =>
                const Scaffold(body: Text('Study Page')),
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Study Page'), findsOneWidget);
    });

    testWidgets('路径参数正确传递到合集详情页', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/test-col-id',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) {
              final id = state.pathParameters['collectionId']!;
              return Scaffold(body: Text('Detail: $id'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Detail: test-col-id'), findsOneWidget);
    });

    testWidgets('学习计划页路径参数正确传递', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/audio-2/plan',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) => const Scaffold(body: Text('Detail')),
            routes: [
              GoRoute(
                path: ':audioId/plan',
                builder: (context, state) {
                  final colId = state.pathParameters['collectionId']!;
                  final audioId = state.pathParameters['audioId']!;
                  return Scaffold(body: Text('Plan: $colId/$audioId'));
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Plan: col-1/audio-2'), findsOneWidget);
    });

    testWidgets('播放器路径参数正确传递', (tester) async {
      final router = GoRouter(
        initialLocation: '/collections/col-1/audio-2/player',
        routes: [
          GoRoute(
            path: '/collections/:collectionId',
            builder: (context, state) => const Scaffold(body: Text('Detail')),
            routes: [
              GoRoute(
                path: ':audioId/player',
                builder: (context, state) {
                  final colId = state.pathParameters['collectionId']!;
                  final audioId = state.pathParameters['audioId']!;
                  return Scaffold(body: Text('Player: $colId/$audioId'));
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      expect(find.text('Player: col-1/audio-2'), findsOneWidget);
    });
  });

  // 回归：合集内音频子页面（plan/player）必须嵌套在「合集详情」之下，
  // 不能拍平成 StatefulShellRoute 的顶层兄弟路由。
  //
  // 根因（见 CLAUDE.md §7.16）：详情页路径 /collections/:c/:a/plan 与 branch-0
  // 的 /collections 前缀重叠。框架以 null state 回灌当前 URI 时，go_router 走
  // 「合成 go → findMatch(uri)」从零重建栈。若 plan 是顶层路由，URI 里不携带
  // 「合集详情」这层 imperative push 的记录，shell 分支会被重置回初始 location
  // （资源库根），返回时自动多退一层。下面用 router.go(深层URI) 模拟这次重解析。
  group('合集内子页面路由结构（防分支重置回归）', () {
    /// 构造一个 StatefulShellRoute：branch-0 = 合集（资源库根 → 合集详情 → 子页），
    /// branch-1 = 学习占位。[nestDetailRoutes] 决定 plan/player 是嵌套子路由（修复）
    /// 还是顶层平级路由（旧的有 bug 结构）。
    GoRouter buildShellRouter({required bool nestDetailRoutes}) {
      final rootKey = GlobalKey<NavigatorState>();
      final detailChildren = <GoRoute>[
        GoRoute(
          path: ':audioId/plan',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const Scaffold(body: Text('plan')),
        ),
        GoRoute(
          path: ':audioId/player',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const Scaffold(body: Text('player')),
        ),
      ];

      return GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/collections',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/collections',
                    builder: (context, state) =>
                        const Scaffold(body: Text('library-root')),
                    routes: [
                      GoRoute(
                        path: ':collectionId',
                        builder: (context, state) =>
                            const Scaffold(body: Text('collection-detail')),
                        // 修复结构：plan/player 作为合集详情的子路由
                        routes: nestDetailRoutes ? detailChildren : const [],
                      ),
                    ],
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/study',
                    builder: (context, state) =>
                        const Scaffold(body: Text('study')),
                  ),
                ],
              ),
            ],
          ),
          // 旧的有 bug 结构：plan/player 拍平成顶层兄弟路由
          if (!nestDetailRoutes) ...[
            GoRoute(
              path: '/collections/:collectionId/:audioId/plan',
              parentNavigatorKey: rootKey,
              builder: (context, state) => const Scaffold(body: Text('plan')),
            ),
            GoRoute(
              path: '/collections/:collectionId/:audioId/player',
              parentNavigatorKey: rootKey,
              builder: (context, state) => const Scaffold(body: Text('player')),
            ),
          ],
        ],
      );
    }

    testWidgets('嵌套结构：深层 URI 重解析后 pop 回到合集详情而非资源库根', (tester) async {
      final router = buildShellRouter(nestDetailRoutes: true);
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      expect(find.text('collection-detail'), findsOneWidget);

      router.push('/collections/c1/a1/plan');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      expect(find.text('player'), findsOneWidget);

      // 模拟框架 null-state 回灌当前 URI（合成 go → findMatch 从零重建栈）。
      router.go('/collections/c1/a1/plan');
      await tester.pumpAndSettle();
      expect(find.text('plan'), findsOneWidget);

      // 关键：重解析后 plan 之下仍保留合集分支（合集详情可被返回到），
      // 而不是塌成只剩 plan 的孤栈。
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('collection-detail'), findsOneWidget);
      expect(find.text('library-root'), findsNothing);
    });

    testWidgets('顶层平级结构：深层 URI 重解析把 shell 分支重置到资源库根（根因复现）', (tester) async {
      final router = buildShellRouter(nestDetailRoutes: false);
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      expect(find.text('collection-detail'), findsOneWidget);

      router.push('/collections/c1/a1/plan');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      expect(find.text('player'), findsOneWidget);

      // 同样的重解析：顶层平级结构下，深层 URI 只匹配到顶层 plan 路由，shell 整个
      // 不在匹配链里 —— 栈塌成只剩 plan 的孤页，合集详情/资源库分支全部丢失。
      router.go('/collections/c1/a1/plan');
      await tester.pumpAndSettle();
      expect(find.text('plan'), findsOneWidget);

      // 根因复现：plan 之下已无任何可返回的页面（合集详情上下文丢失）。
      // 真机上由此衍生出「返回后自动多退一层」。
      expect(router.canPop(), isFalse);
      expect(find.text('collection-detail'), findsNothing);
    });
  });

  // 回归：句子讲解页必须嵌套在入口（随心听 player）之下，不能拍平成顶层路由。
  //
  // 与 §7.17 同类。用 router.go(当前URI) 模拟框架 null-state 回灌重解析：
  //   - 顶层扁平结构 → 讲解页 URI 不携带 player 层，栈塌回资源库根，返回回不到 player（bug）。
  //   - 嵌套于 player → URI 携带 player 层，重解析不丢栈，返回正常回到 player（修复）。
  group('句子讲解页路由结构（防塌栈回归）', () {
    /// [nestUnderPlayer] 决定讲解页是 player 的嵌套子路由（修复）还是顶层扁平（现状）。
    GoRouter buildDetailRouter({required bool nestUnderPlayer}) {
      final rootKey = GlobalKey<NavigatorState>();
      return GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/collections',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/collections',
                    builder: (context, state) =>
                        const Scaffold(body: Text('library-root')),
                    routes: [
                      GoRoute(
                        path: ':collectionId',
                        builder: (context, state) =>
                            const Scaffold(body: Text('collection-detail')),
                        routes: [
                          GoRoute(
                            path: ':audioId/player',
                            parentNavigatorKey: rootKey,
                            builder: (context, state) =>
                                const Scaffold(body: Text('player')),
                            // 修复结构：讲解页作为 player 的子路由
                            routes: nestUnderPlayer
                                ? [
                                    GoRoute(
                                      path: 'sentence-detail',
                                      parentNavigatorKey: rootKey,
                                      builder: (context, state) =>
                                          const Scaffold(
                                            body: Text('sentence-detail'),
                                          ),
                                    ),
                                  ]
                                : const [],
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
                    builder: (context, state) =>
                        const Scaffold(body: Text('study')),
                  ),
                ],
              ),
            ],
          ),
          // 现状结构：讲解页拍平成顶层兄弟路由
          if (!nestUnderPlayer)
            GoRoute(
              path: '/sentence-detail',
              parentNavigatorKey: rootKey,
              builder: (context, state) =>
                  const Scaffold(body: Text('sentence-detail')),
            ),
        ],
      );
    }

    testWidgets('顶层扁平结构：重解析把栈塌回资源库根（根因复现）', (tester) async {
      final router = buildDetailRouter(nestUnderPlayer: false);
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      expect(find.text('player'), findsOneWidget);

      router.push('/sentence-detail');
      await tester.pumpAndSettle();
      expect(find.text('sentence-detail'), findsOneWidget);

      // 模拟框架 null-state 回灌当前 URI（合成 go → findMatch 从零重建栈）。
      router.go('/sentence-detail');
      await tester.pumpAndSettle();

      // 根因复现：扁平 URI 只匹配到顶层讲解页，player 层丢失 → 讲解页之下已无可返回页。
      // 真机上由此衍生出「返回后自动多退回合集首页」。
      expect(router.canPop(), isFalse);
      expect(find.text('player'), findsNothing);
    });

    testWidgets('修复（嵌套于 player）：重解析后返回回到随心听', (tester) async {
      final router = buildDetailRouter(nestUnderPlayer: true);
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/player');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/player/sentence-detail');
      await tester.pumpAndSettle();
      expect(find.text('sentence-detail'), findsOneWidget);

      router.go('/collections/c1/a1/player/sentence-detail');
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('player'), findsOneWidget);
    });
  });

  // 回归：PDF 预览页同样必须嵌套在入口（学习计划页）之下（§7.17 同类）。
  group('PDF 预览页路由结构（防塌栈回归）', () {
    testWidgets('嵌套于 plan：重解析后返回回到学习计划页', (tester) async {
      final rootKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/collections',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/collections',
                    builder: (context, state) =>
                        const Scaffold(body: Text('library-root')),
                    routes: [
                      GoRoute(
                        path: ':collectionId',
                        builder: (context, state) =>
                            const Scaffold(body: Text('collection-detail')),
                        routes: [
                          GoRoute(
                            path: ':audioId/plan',
                            parentNavigatorKey: rootKey,
                            builder: (context, state) =>
                                const Scaffold(body: Text('plan')),
                            routes: [
                              GoRoute(
                                path: 'pdf-preview',
                                parentNavigatorKey: rootKey,
                                builder: (context, state) =>
                                    const Scaffold(body: Text('pdf-preview')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/plan');
      await tester.pumpAndSettle();
      router.push('/collections/c1/a1/plan/pdf-preview');
      await tester.pumpAndSettle();
      expect(find.text('pdf-preview'), findsOneWidget);

      router.go('/collections/c1/a1/plan/pdf-preview');
      await tester.pumpAndSettle();

      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('plan'), findsOneWidget);
    });
  });

  group('媒体随心听页路由结构（防塌栈回归）', () {
    /// 复刻真实媒体页路由的构造语义：extra 非 AudioItem 时首帧 pop 回入口页
    /// （对齐 _RestoredRoutePopper 行为，后者为 private 无法直接引用）。
    Widget mediaPlayerBuilder(GoRouterState state) {
      final item = state.extra;
      if (item is! AudioItem) return const _FakeRestoredPopper();
      return Scaffold(body: Text('media-player:${item.name}'));
    }

    GoRouter buildMediaRouter() {
      final rootKey = GlobalKey<NavigatorState>();
      return GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/collections',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/collections',
                    builder: (context, state) =>
                        const Scaffold(body: Text('library-root')),
                    routes: [
                      GoRoute(
                        path: ':collectionId',
                        builder: (context, state) =>
                            const Scaffold(body: Text('collection-detail')),
                        routes: [
                          GoRoute(
                            path: ':audioId/${AppRoutes.mediaPlayerSegment}',
                            parentNavigatorKey: rootKey,
                            builder: (context, state) =>
                                mediaPlayerBuilder(state),
                            routes: [
                              GoRoute(
                                path: AppRoutes.sentenceDetailSegment,
                                parentNavigatorKey: rootKey,
                                builder: (context, state) => const Scaffold(
                                  body: Text('media-sentence-detail'),
                                ),
                              ),
                            ],
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
                    builder: (context, state) =>
                        const Scaffold(body: Text('study')),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/audio/:audioId/${AppRoutes.mediaPlayerSegment}',
            parentNavigatorKey: rootKey,
            builder: (context, state) => mediaPlayerBuilder(state),
            routes: [
              GoRoute(
                path: AppRoutes.sentenceDetailSegment,
                parentNavigatorKey: rootKey,
                builder: (context, state) =>
                    const Scaffold(body: Text('media-sentence-detail')),
              ),
            ],
          ),
        ],
      );
    }

    final videoItem = createTestAudioItem(
      id: 'v1',
      name: '视频',
      audioPath: 'videos/v1.mp4',
    );

    testWidgets('嵌套结构：深层 URI 重解析后返回回到合集详情而非资源库根', (tester) async {
      final router = buildMediaRouter();
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();
      expect(find.text('collection-detail'), findsOneWidget);

      router.push(
        '/collections/c1/v1/${AppRoutes.mediaPlayerSegment}',
        extra: videoItem,
      );
      await tester.pumpAndSettle();
      expect(find.text('media-player:视频'), findsOneWidget);

      // 模拟框架 null-state 回灌当前 URI：extra 丢失 → 命中 popper 首帧退回入口页。
      router.go('/collections/c1/v1/${AppRoutes.mediaPlayerSegment}');
      await tester.pumpAndSettle();

      // 重解析后栈仍保留合集详情，可被返回到（不塌回资源库根）。
      expect(find.text('collection-detail'), findsOneWidget);
      expect(find.text('library-root'), findsNothing);
    });

    testWidgets('extra 丢失命中 popper：不显示视频页内容', (tester) async {
      final router = buildMediaRouter();
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.go('/collections/c1');
      await tester.pumpAndSettle();

      // 不带 extra 直接进入（模拟重解析后 extra 丢失）。
      router.push('/collections/c1/v1/${AppRoutes.mediaPlayerSegment}');
      await tester.pumpAndSettle();

      // popper 首帧 pop，最终停在合集详情，媒体页内容不出现。
      expect(find.textContaining('media-player'), findsNothing);
      expect(find.text('collection-detail'), findsOneWidget);
    });

    testWidgets('合集与独立媒体入口都可嵌套进入句子讲解页', (tester) async {
      final router = buildMediaRouter();
      await tester.pumpWidget(createRouterTestApp(router));
      await tester.pumpAndSettle();

      router.push(
        '/collections/c1/v1/${AppRoutes.mediaPlayerSegment}',
        extra: videoItem,
      );
      await tester.pumpAndSettle();
      router.push(
        '/collections/c1/v1/${AppRoutes.mediaPlayerSegment}/'
        '${AppRoutes.sentenceDetailSegment}',
      );
      await tester.pumpAndSettle();
      expect(find.text('media-sentence-detail'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('media-player:视频'), findsOneWidget);

      router.go('/study');
      await tester.pumpAndSettle();
      router.push(
        '/audio/v1/${AppRoutes.mediaPlayerSegment}',
        extra: videoItem,
      );
      await tester.pumpAndSettle();
      router.push(
        '/audio/v1/${AppRoutes.mediaPlayerSegment}/'
        '${AppRoutes.sentenceDetailSegment}',
      );
      await tester.pumpAndSettle();
      expect(find.text('media-sentence-detail'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('media-player:视频'), findsOneWidget);
    });
  });
}

/// 测试用的入口页恢复占位组件：首帧 pop 回上一页，模拟 _RestoredRoutePopper。
class _FakeRestoredPopper extends StatefulWidget {
  const _FakeRestoredPopper();

  @override
  State<_FakeRestoredPopper> createState() => _FakeRestoredPopperState();
}

class _FakeRestoredPopperState extends State<_FakeRestoredPopper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

import 'dart:async';

import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/daily_goal_check_in/providers/daily_check_in_share_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_attempt_store.dart';
import 'package:echo_loop/features/rating_prompt/data/rating_prompt_task_completion_store.dart';
import 'package:echo_loop/features/rating_prompt/rating_prompt_providers.dart';
import 'package:echo_loop/features/rating_prompt/services/in_app_review_gateway.dart';
import 'package:echo_loop/features/rating_prompt/services/rating_prompt_coordinator.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/startup_bootstrap_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/providers/notification_permission_provider.dart';
import 'package:echo_loop/router/main_shell.dart';
import 'package:echo_loop/services/notification_permission_service.dart';

import '../helpers/mock_providers.dart';

class _NoopReviewGateway implements InAppReviewGateway {
  @override
  Future<void> requestReview() async {}
}

/// 记录每次触发评分检查时“页面是否可以展示”的结果，不做真实资格判断。
class _RecordingCoordinator extends RatingPromptCoordinator {
  _RecordingCoordinator({
    required AppDatabase database,
    required SharedPreferences preferences,
  }) : super(
         packageInfo: PackageInfo(
           appName: 'Echo Loop',
           packageName: 'test.echo.loop',
           version: '1.0.0',
           buildNumber: '1',
           installerStore: 'com.apple',
         ),
         studyRecordDao: database.dailyStudyRecordDao,
         attemptStore: RatingPromptAttemptStore(preferences),
         taskCompletionStore: RatingPromptTaskCompletionStore(preferences),
         reviewGateway: _NoopReviewGateway(),
         isEnabled: () => true,
       );

  /// 每次 [maybeRequest] 被调用时，记录调用时的 canPresent 结果。
  final List<bool> presentableAtCall = [];

  @override
  Future<void> maybeRequest({required bool Function() canPresent}) async {
    presentableAtCall.add(canPresent());
  }
}

class _FakeNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

class _PendingStartupController extends LocalStartupController {
  @override
  Future<StartupReport> build() => Completer<StartupReport>().future;
}

NotificationPermissionService _notificationPermissionService() {
  final fake = _FakeNotificationPermissionService();
  when(() => fake.syncSystemAuthorizationStatus()).thenAnswer((_) async {});
  when(() => fake.maybeTriggerPrompt()).thenAnswer((_) async {});
  return fake;
}

/// 按 Flutter 允许的顺序切到前台（inactive → resumed），避免非法状态转换断言。
void _resumeApp() {
  TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.inactive,
  );
  TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
}

/// 主导航壳会启动周期性后台任务，不能用 pumpAndSettle 等待其结束。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 释放整棵树并推进时间，让壳里的定时器结束，避免测试结束时仍有待处理的 Timer。
Future<void> _disposeShell(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences preferences;
  late GoRouter router;
  late _RecordingCoordinator coordinator;

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    coordinator = _RecordingCoordinator(
      database: database,
      preferences: preferences,
    );
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      observers: [rootRouteObserver],
      initialLocation: '/study',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/collections',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Collections')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/study',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Study')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Favorites')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings')),
                ),
              ],
            ),
          ],
        ),
        // 模拟学习任务页：推入根导航器，覆盖在主导航壳之上。
        GoRoute(
          path: '/practice',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const Scaffold(body: Text('Practice')),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await database.close();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          dailyShareUserIdProvider.overrideWithValue(null),
          appDatabaseProvider.overrideWithValue(database),
          localStartupProvider.overrideWith(_PendingStartupController.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          ratingPromptCoordinatorProvider.overrideWithValue(coordinator),
          analyticsOverride(),
          notificationPermissionServiceProvider.overrideWithValue(
            _notificationPermissionService(),
          ),
        ]),
        child: MaterialApp.router(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('zh')],
          routerConfig: router,
        ),
      ),
    );
    // 测试环境默认不是前台状态，评分检查要求 App 处于 resumed。
    _resumeApp();
    await _settle(tester);
  }

  testWidgets('冷启动落在学习首页时检查一次，且此时可以展示', (tester) async {
    await pumpShell(tester);

    expect(coordinator.presentableAtCall, [true]);
    await _disposeShell(tester);
  });

  testWidgets('切换到收藏 Tab 时检查一次', (tester) async {
    await pumpShell(tester);

    router.go('/favorites');
    await _settle(tester);

    expect(coordinator.presentableAtCall, [true, true]);
    await _disposeShell(tester);
  });

  testWidgets('切换到资源库或我的 Tab 时不检查', (tester) async {
    await pumpShell(tester);

    router.go('/collections');
    await _settle(tester);
    router.go('/settings');
    await _settle(tester);

    expect(coordinator.presentableAtCall, [true]);
    await _disposeShell(tester);
  });

  testWidgets('学习任务页覆盖在学习首页之上时不检查，返回首页后检查一次', (tester) async {
    await pumpShell(tester);
    expect(coordinator.presentableAtCall, hasLength(1));

    final practiceRoute = router.push<void>('/practice');
    await _settle(tester);
    expect(find.text('Practice'), findsOneWidget);
    expect(coordinator.presentableAtCall, hasLength(1));

    router.pop();
    await practiceRoute;
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/study');
    expect(find.text('Practice'), findsNothing);
    expect(coordinator.presentableAtCall, [true, true]);
    await _disposeShell(tester);
  });

  testWidgets('App 从后台回到前台且停留在学习首页时检查一次', (tester) async {
    await pumpShell(tester);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
    }
    await _settle(tester);

    expect(coordinator.presentableAtCall, hasLength(2));
    expect(coordinator.presentableAtCall.last, isTrue);
    await _disposeShell(tester);
  });
}

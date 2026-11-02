import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/l10n/app_localizations.dart';
import 'package:echo_loop/providers/startup_bootstrap_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/media_playback/media_playback_provider.dart';
import 'package:echo_loop/models/media_playback_state.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/router/main_shell.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:echo_loop/models/study_stage.dart';

import '../helpers/mock_providers.dart';

class _RecordingListeningPractice extends FakeListeningPractice {
  int finishCalls = 0;

  @override
  int beginStudyPage() => 1;

  @override
  Future<void> finishStudyPage({int? generation}) {
    finishCalls++;
    return Future<void>.value();
  }
}

class _IdleMediaPlayback extends MediaPlayback {
  @override
  MediaPlaybackState build() => const MediaPlaybackState();

  @override
  Future<void> finishStudyPage({int? generation}) => Future<void>.value();
}

class _PendingStartupController extends LocalStartupController {
  @override
  Future<StartupReport> build() => Completer<StartupReport>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late GoRouter router;
  late _RecordingListeningPractice recordingListeningPractice;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    recordingListeningPractice = _RecordingListeningPractice();
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
        GoRoute(
          path: '/free-player',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              const Scaffold(body: Text('Free Player')),
          onExit: (context, state) async {
            await StudyTimeService(
              database.dailyStudyRecordDao,
              database.dailyStageStudyRecordDao,
            ).recordActiveDuration(
              const Duration(seconds: 2),
              stage: StudyStage.freePlayer,
            );
            return true;
          },
        ),
        GoRoute(
          path: '/free-player-immediate',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              const Scaffold(body: Text('Free Player Immediate')),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await database.close();
  });

  testWidgets('根路由退出收尾完成后返回 Study 时刷新统计', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appDatabaseProvider.overrideWithValue(database),
          localStartupProvider.overrideWith(_PendingStartupController.new),
        ]),
        child: Consumer(
          builder: (context, ref, child) {
            final stats = ref.watch(studyStatsProvider).value;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  MaterialApp.router(
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [Locale('en'), Locale('zh')],
                    routerConfig: router,
                  ),
                  Positioned(
                    key: const ValueKey('study-stats-observer'),
                    left: 0,
                    top: 0,
                    child: Text('${stats?.todaySeconds ?? -1}'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0'), findsOneWidget);

    final playerRoute = router.push<void>('/free-player');
    await tester.pumpAndSettle();
    router.pop();
    await playerRoute;
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('返回 Study 时触发随心听收尾', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: dedupeOverrides([
          appDatabaseProvider.overrideWithValue(database),
          localStartupProvider.overrideWith(_PendingStartupController.new),
          listeningPracticeProvider.overrideWith(
            () => recordingListeningPractice,
          ),
          mediaPlaybackProvider.overrideWith(_IdleMediaPlayback.new),
        ]),
        child: Consumer(
          builder: (context, ref, child) {
            final stats = ref.watch(studyStatsProvider).value;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  MaterialApp.router(
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: const [Locale('en'), Locale('zh')],
                    routerConfig: router,
                  ),
                  Positioned(
                    key: const ValueKey('study-stats-observer'),
                    left: 0,
                    top: 0,
                    child: Text('${stats?.todaySeconds ?? -1}'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('0'), findsOneWidget);

    final playerRoute = router.push<void>('/free-player-immediate');
    await tester.pumpAndSettle();
    router.pop();
    await playerRoute;
    await tester.pump();

    expect(recordingListeningPractice.finishCalls, 1);
    expect(find.text('0'), findsOneWidget);
    await tester.pump();
  });
}

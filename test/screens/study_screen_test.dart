import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/audio_item.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/audio_library_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/screens/study_screen.dart';
import 'package:fluency/providers/time_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required List<AudioItem> audioItems,
    required LearningProgressState progressState,
    DateTime? fixedNow,
  }) {
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => Scaffold(
            body: navigationShell,
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/collections',
                builder: (context, state) =>
                    const Scaffold(body: Text('Library')),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/study',
                builder: (context, state) => const StudyScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/favorites',
                builder: (context, state) =>
                    const Scaffold(body: Text('Favorites')),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const Scaffold(body: Text('Settings')),
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/audio/:audioId/plan',
          builder: (context, state) =>
              const Scaffold(body: Text('Learning Plan')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        audioLibraryProvider.overrideWith(
          () => TestAudioLibrary(AudioLibraryState(audioItems: audioItems)),
        ),
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(progressState),
        ),
        if (fixedNow != null) nowProvider.overrideWithValue(() => fixedNow),
      ],
      child: MaterialApp.router(
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }

  testWidgets('无任务时显示空状态', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioItems: const [],
        progressState: const LearningProgressState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No study tasks yet'), findsOneWidget);
    expect(find.text('Go to Library'), findsOneWidget);
  });

  testWidgets('未到时间复习任务的开始按钮禁用', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Upcoming Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // upcoming reviews 默认折叠，先展开
    final expansionTile = find.byType(ExpansionTile);
    expect(expansionTile, findsWidgets);
    await tester.tap(expansionTile.first);
    await tester.pumpAndSettle();

    // 找到 FilledButton（任务卡片中的按钮），应该是禁用的
    final disabledButtons = find.byWidgetPredicate(
      (w) => w is FilledButton && w.onPressed == null,
    );
    expect(disabledButtons, findsAtLeast(1));
  });

  testWidgets('复习任务点击开始后导航到学习计划页', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 音频名称出现在 Hero Card 和任务卡片中
    expect(find.text('Review Audio'), findsAtLeast(1));

    // 点击 Hero Card 中的 Review 按钮
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();

    expect(find.text('Learning Plan'), findsOneWidget);
  });

  testWidgets('逾期复习任务显示逾期文案', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Overdue Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          // review1 窗口结束 = completed + 48h，这里逾期 3h
          lastStageCompletedAt: now.subtract(const Duration(hours: 51)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 新格式："Overdue 3h"
    expect(find.textContaining('Overdue 3h'), findsOneWidget);
    // Hero Card 和任务卡片都有 Review 按钮
    final reviewButtons = find.widgetWithText(FilledButton, 'Review');
    expect(reviewButtons, findsAtLeast(1));
  });

  testWidgets('首学任务显示子阶段标签', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'First Study Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.intensiveListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // 子阶段标签
    expect(find.textContaining('Intensive Listening'), findsAtLeast(1));
    // 按钮文案为 Continue（已开始首学）
    expect(find.text('Continue'), findsAtLeast(1));
  });

  testWidgets('已完成音频显示在折叠区', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Completed Audio',
        audioPath: 'audios/test.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.completed,
          currentSubStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // "All done" 状态
    expect(find.text('All done for now!'), findsOneWidget);

    // 展开已完成区
    expect(find.textContaining('Completed (1)'), findsOneWidget);
    await tester.tap(find.textContaining('Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Audio'), findsOneWidget);
  });

  testWidgets('Hero Card 显示最优先任务', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final audioItems = [
      AudioItem(
        id: 'audio-1',
        name: 'Review Audio',
        audioPath: 'audios/review.mp3',
        addedDate: now,
      ),
      AudioItem(
        id: 'audio-2',
        name: 'First Study Audio',
        audioPath: 'audios/first.mp3',
        addedDate: now,
      ),
    ];
    final progressState = LearningProgressState(
      progressMap: {
        'audio-1': LearningProgress(
          audioItemId: 'audio-1',
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.blindListen,
          lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
          updatedAt: now,
        ),
      },
    );

    await tester.pumpWidget(
      createTestWidget(
        audioItems: audioItems,
        progressState: progressState,
        fixedNow: now,
      ),
    );
    await tester.pumpAndSettle();

    // Hero Card 应该显示复习任务（优先级更高）
    expect(find.text('Continue Learning'), findsOneWidget);
    // Hero Card 中显示复习音频名称
    expect(find.text('Review Audio'), findsAtLeast(1));
  });

  testWidgets('无任务时点击"去导入音频"导航到 Library', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        audioItems: const [],
        progressState: const LearningProgressState(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to Library'));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
  });
}

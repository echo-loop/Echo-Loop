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

import '../helpers/mock_providers.dart';

void main() {
  Widget createTestWidget({
    required List<AudioItem> audioItems,
    required LearningProgressState progressState,
    DateTime? fixedNow,
  }) {
    final router = GoRouter(
      initialLocation: '/study',
      routes: [
        GoRoute(
          path: '/study',
          builder: (context, state) => const StudyScreen(),
        ),
        GoRoute(
          path: '/audio/:audioId/review/:subStage',
          builder: (context, state) =>
              const Scaffold(body: Text('Review Placeholder')),
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

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('复习任务点击开始后先弹窗再进入当前子步骤', (tester) async {
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

    expect(find.text('Review Audio'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Start Practice'), findsOneWidget);

    await tester.tap(find.text('Start Practice'));
    await tester.pumpAndSettle();
    expect(find.text('Review Placeholder'), findsOneWidget);
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

    expect(find.textContaining('Overdue by 3 hour(s)'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNotNull);
  });
}

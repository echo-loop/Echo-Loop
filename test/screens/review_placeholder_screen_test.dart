import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/l10n/app_localizations.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/time_provider.dart';
import 'package:fluency/screens/review_placeholder_screen.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

void main() {
  Widget createTestWidget({
    required LearningProgress progress,
    required DateTime fixedNow,
  }) {
    final router = GoRouter(
      initialLocation: '/audio/audio-1/review/blindListen',
      routes: [
        GoRoute(
          path: '/audio/:audioId/review/:subStage',
          builder: (context, state) {
            final audioId = state.pathParameters['audioId']!;
            final subStageKey = state.pathParameters['subStage']!;
            return ReviewPlaceholderScreen(
              audioItemId: audioId,
              subStageKey: subStageKey,
            );
          },
        ),
        GoRoute(
          path: '/audio/:audioId/plan',
          builder: (context, state) => const Scaffold(body: Text('Plan')),
        ),
        GoRoute(
          path: '/study',
          builder: (context, state) => const Scaffold(body: Text('Study')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        learningProgressNotifierProvider.overrideWith(
          () => TestLearningProgressNotifier(
            LearningProgressState(progressMap: {'audio-1': progress}),
          ),
        ),
        nowProvider.overrideWithValue(() => fixedNow),
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

  testWidgets('复习未到时间时完成按钮禁用并显示倒计时', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final progress = LearningProgress(
      audioItemId: 'audio-1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.blindListen,
      lastStageCompletedAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      createTestWidget(progress: progress, fixedNow: now),
    );
    await tester.pumpAndSettle();

    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark complete & continue'),
    );
    expect(finishButton.onPressed, isNull);
    expect(find.textContaining('Available in'), findsOneWidget);
  });

  testWidgets('复习已到时间时完成按钮可用', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final progress = LearningProgress(
      audioItemId: 'audio-1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.blindListen,
      lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      createTestWidget(progress: progress, fixedNow: now),
    );
    await tester.pumpAndSettle();

    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark complete & continue'),
    );
    expect(finishButton.onPressed, isNotNull);
  });

  testWidgets('复习逾期时显示逾期提示且完成按钮可用', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final progress = LearningProgress(
      audioItemId: 'audio-1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.blindListen,
      // review1 窗口结束 = completed + 48h，这里逾期 2h
      lastStageCompletedAt: now.subtract(const Duration(hours: 50)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      createTestWidget(progress: progress, fixedNow: now),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Overdue by 2 hour(s)'), findsOneWidget);
    final finishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mark complete & continue'),
    );
    expect(finishButton.onPressed, isNotNull);
  });

  testWidgets('返回操作统一回学习计划页', (tester) async {
    final now = DateTime(2026, 2, 25, 12, 0);
    final progress = LearningProgress(
      audioItemId: 'audio-1',
      currentStage: LearningStage.review1,
      currentSubStage: SubStageType.blindListen,
      lastStageCompletedAt: now.subtract(const Duration(hours: 24)),
      updatedAt: now,
    );

    await tester.pumpWidget(
      createTestWidget(progress: progress, fixedNow: now),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsOneWidget);
  });
}

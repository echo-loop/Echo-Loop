// 学习进度条测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/learning_plan.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/theme/app_theme.dart';
import 'package:echo_loop/widgets/learning_progress_bar.dart';

import '../helpers/test_app.dart';

void main() {
  Widget buildBar(LearningProgress? progress) {
    return createTestApp(
      Center(
        child: SizedBox(
          width: 300,
          child: LearningProgressBar(progress: progress),
        ),
      ),
    );
  }

  LearningProgress startedProgress() => LearningProgress(
    audioItemId: 'test-1',
    currentStage: LearningStage.firstLearn,
    currentSubStage: SubStageType.listenAndRepeat,
    updatedAt: DateTime(2026, 1, 1),
  );

  group('LearningProgressBar', () {
    testWidgets('未学习 → 进度为 0 并显示未学习文案', (tester) async {
      await tester.pumpWidget(buildBar(null));
      await tester.pumpAndSettle();

      expect(find.text('Not started'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0);
    });

    testWidgets('学习中 → 进度为计划百分比并显示百分比文案', (tester) async {
      final progress = startedProgress();
      await tester.pumpWidget(buildBar(progress));
      await tester.pumpAndSettle();

      final expected = progress.progressPercent(
        LearningPlan.standard(),
        const <String>{},
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, expected);
      expect(find.text('${(expected * 100).round()}%'), findsOneWidget);
    });

    testWidgets('已完成 → 满条并显示已完成文案', (tester) async {
      final progress = LearningProgress(
        audioItemId: 'test-1',
        currentStage: LearningStage.completed,
        currentSubStage: SubStageType.blindListen,
        updatedAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(buildBar(progress));
      await tester.pumpAndSettle();

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1.0);
      expect(find.text('Completed'), findsOneWidget);
    });
  });

  group('learningProgressColor', () {
    final theme = ThemeData.light();

    test('完成为绿色，学习中与未开始为蓝色，暂停时灰化', () {
      final completed = startedProgress().copyWith(
        currentStage: LearningStage.completed,
      );
      final paused = startedProgress().copyWith(isPaused: true);

      expect(
        learningProgressColor(theme, completed),
        AppTheme.learningCompletedColor,
      );
      expect(
        learningProgressColor(theme, startedProgress()),
        AppTheme.learningInProgressColor(theme.brightness),
      );
      expect(
        learningProgressColor(theme, null),
        AppTheme.learningInProgressColor(theme.brightness),
      );
      expect(
        learningProgressColor(theme, paused),
        theme.colorScheme.onSurfaceVariant,
      );
    });
  });
}

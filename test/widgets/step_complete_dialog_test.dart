import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/widgets/dialogs/step_complete_dialog.dart';

import '../helpers/test_app.dart';

void main() {
  group('StepCompleteDialog', () {
    /// 非末步骤（有下一步可继续）
    testWidgets('非末步骤 — 显示步骤进度、难度选择、双按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  contentBody: const Text('Listened 2 time(s)'),
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证标题和步骤进度
      expect(find.text('Blind Listen Complete'), findsOneWidget);
      expect(find.text('Step 1/4 (First Study)'), findsOneWidget);
      expect(find.text('Listened 2 time(s)'), findsOneWidget);
      expect(find.text('How did it feel?'), findsOneWidget);

      // 验证 5 个难度选项
      expect(find.text('Very Easy'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Very Hard'), findsOneWidget);

      // 验证两个按钮（无再来一遍）
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Continue: Intensive Listening'), findsOneWidget);

      // 右上角关闭按钮
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('非末步骤 — 未选择难度时按钮置灰', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 继续按钮始终为 FilledButton
      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue: Intensive Listening'),
      );
      expect(continueButton.onPressed, isNull);

      final doneButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Done'),
      );
      expect(doneButton.onPressed, isNull);
    });

    testWidgets('非末步骤 — 选择难度后点击"继续"返回 continueNext', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 选择难度
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();

      // 点击"继续"
      await tester.tap(find.text('Continue: Intensive Listening'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.hard);
      expect(result!.action, StepCompleteAction.continueNext);
    });

    testWidgets('非末步骤 — 选择难度后点击"完成"返回 back', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Study',
                  nextStepName: 'Intensive Listening',
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 选择难度
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      // 点击"完成"
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.easy);
      expect(result!.action, StepCompleteAction.back);
    });

    testWidgets('右上角关闭按钮返回 null', (tester) async {
      StepCompleteResult? result = const (
        action: StepCompleteAction.back,
        difficulty: null,
      );

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Test',
                  stepIndex: 0,
                  totalSteps: 2,
                  stageName: 'First Study',
                  nextStepName: 'Next',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 点击关闭按钮
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    /// 末步骤（没有下一步）
    testWidgets('末步骤 — 显示"完成首次学习"按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'First Study',
                  isLastStep: true,
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 验证步骤进度
      expect(find.text('Step 4/4 (First Study)'), findsOneWidget);

      // 末步骤显示"完成首次学习"按钮
      expect(find.text('Complete First Study'), findsOneWidget);

      // 不应显示"Done"和"继续"
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('末步骤 — 选择难度后点击"完成首次学习"返回 back', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'First Study',
                  isLastStep: true,
                  showDifficultySelector: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Complete First Study'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, DifficultyLevel.medium);
      expect(result!.action, StepCompleteAction.back);
    });

    /// 复习模式（隐藏难度选择器）
    testWidgets('showDifficultySelector=false — 隐藏难度选择器，按钮直接可用',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 0,
                  totalSteps: 3,
                  stageName: 'Review Round 1',
                  nextStepName: 'Difficult Sentence Practice',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 难度选择器不可见
      expect(find.text('How did it feel?'), findsNothing);
      expect(find.text('Very Easy'), findsNothing);
      expect(find.text('Hard'), findsNothing);

      // 按钮直接可用
      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Continue: Difficult Sentence Practice',
        ),
      );
      expect(continueButton.onPressed, isNotNull);

      final doneButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Done'),
      );
      expect(doneButton.onPressed, isNotNull);
    });

    testWidgets('showDifficultySelector=false — 点击继续返回 null difficulty',
        (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Blind Listen Complete',
                  stepIndex: 0,
                  totalSteps: 3,
                  stageName: 'Review Round 1',
                  nextStepName: 'Difficult Sentence Practice',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 直接点击"继续"
      await tester.tap(
        find.text('Continue: Difficult Sentence Practice'),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.difficulty, isNull);
      expect(result!.action, StepCompleteAction.continueNext);
    });
  });
}

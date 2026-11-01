import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:echo_loop/widgets/dialogs/step_complete_dialog.dart';

import '../helpers/test_app.dart';

void main() {
  group('StepCompleteDialog', () {
    /// 非末步骤（有下一步可继续）
    testWidgets('非末步骤 — 显示步骤进度、内容、双按钮（无难度选择器）', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Listening sentence by sentence Complete',
                  contentBody: const Text('All 10 sentences'),
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Round',
                  nextStepName: 'Listen & Repeat',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      // 验证标题和步骤进度
      expect(
        find.text('Listening sentence by sentence Complete'),
        findsOneWidget,
      );
      expect(find.text('Stage 1/4 (First Round)'), findsOneWidget);
      expect(find.text('All 10 sentences'), findsOneWidget);

      // 难度选择器已移除
      expect(find.text('How difficult was this?'), findsNothing);
      expect(find.text('Very Easy'), findsNothing);
      expect(find.text('Hard'), findsNothing);

      // 验证两个按钮
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // 右上角关闭按钮
      expect(find.byIcon(Icons.close), findsOneWidget);
      final animation = tester.widget<LottieBuilder>(
        find.byKey(const Key('completion-dialog-done-check')),
      );
      expect(animation.repeat, isTrue);
      expect(animation.animate, isTrue);
      expect(
        tester.getSize(find.byKey(const Key('completion-dialog-done-check'))),
        const Size(160, 160),
      );
    });

    testWidgets('非末步骤 — 按钮直接可用', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Listening sentence by sentence Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Round',
                  nextStepName: 'Listen & Repeat',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      final continueButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNotNull);

      final doneButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Done'),
      );
      expect(doneButton.onPressed, isNotNull);
    });

    testWidgets('中文非末步骤使用简短的继续文案', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => StepCompleteDialog(
              onResult: (_) {},
              title: '完成',
              nextStepName: '听写练习',
            ),
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('继续'), findsOneWidget);
      expect(find.text('继续：听写练习'), findsNothing);
    });

    testWidgets('非末步骤 — 点击"继续"返回 continueNext', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Listening sentence by sentence Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Round',
                  nextStepName: 'Listen & Repeat',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.action, StepCompleteAction.continueNext);
    });

    testWidgets('非末步骤 — 点击"完成"返回 back', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Listening sentence by sentence Complete',
                  stepIndex: 0,
                  totalSteps: 4,
                  stageName: 'First Round',
                  nextStepName: 'Listen & Repeat',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Done'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.action, StepCompleteAction.back);
    });

    testWidgets('右上角关闭按钮返回 null', (tester) async {
      StepCompleteResult? result = const (action: StepCompleteAction.back);

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
                  stageName: 'First Round',
                  nextStepName: 'Next',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNull);
    });

    /// 末步骤（没有下一步）
    testWidgets('末步骤 — 显示"完成复习"按钮', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showStepCompleteDialog(
                  context: context,
                  title: 'Retell Complete',
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'Intensive Listening',
                  isLastStep: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Stage 4/4 (Intensive Listening)'), findsOneWidget);
      expect(find.text('Review Complete'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('末步骤 — 点击"完成复习"返回 back', (tester) async {
      StepCompleteResult? result;

      await tester.pumpWidget(
        createTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showStepCompleteDialog(
                  context: context,
                  title: 'Retell Complete',
                  stepIndex: 3,
                  totalSteps: 4,
                  stageName: 'Intensive Listening',
                  isLastStep: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Review Complete'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(result, isNotNull);
      expect(result!.action, StepCompleteAction.back);
    });
  });
}

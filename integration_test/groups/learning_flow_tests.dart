/// 跨页面学习流程端到端测试
///
/// 验证集成测试最核心的价值：页面间状态传递和流程连贯性。
/// 包含 2 个测试场景：盲听完成闭环、精听断点续学。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/main.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/blind_listen_player_screen.dart';
import 'package:fluency/widgets/blind_listen_briefing_sheet.dart';
import 'package:fluency/widgets/dialogs/step_complete_dialog.dart';

import '../helpers/test_notifiers.dart';

Future<void> _pumpUi(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
  int stepMilliseconds = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(Duration(milliseconds: stepMilliseconds));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

/// 跨页面学习流程端到端测试
void learningFlowTests() {
  group('流程 7：跨页面学习闭环', () {
    testWidgets('盲听完成 → 返回学习计划页 → 进度更新', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await _pumpUi(tester, 1000);

      // === 1. 导航到学习计划页 ===
      final appContext = tester.element(find.byType(FluencyApp));
      final appContainer = ProviderScope.containerOf(appContext);
      appContainer
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      final startLearningButton = find.text('Start Learning');
      await _pumpUntilFound(tester, startLearningButton);

      // 验证盲听步骤为当前（底部按钮显示"Start Learning"）
      expect(startLearningButton, findsOneWidget);

      // === 2. 点击"开始学习" → 弹出盲听简报 ===
      await tester.tap(startLearningButton);
      await _pumpUi(tester, 1000);

      expect(find.byType(BlindListenBriefingSheet), findsOneWidget);

      // === 3. 点击"开始练习" → 进入盲听播放器 ===
      await tester.tap(find.text('Start Practice'));
      await _pumpUi(tester, 1000);

      expect(find.byType(BlindListenPlayerScreen), findsOneWidget);

      // === 4. 模拟盲听完成（达到目标遍数）===
      final blindContext = tester.element(find.byType(BlindListenPlayerScreen));
      final container = ProviderScope.containerOf(blindContext);
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;

      // 设置已达目标遍数
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.blindListen,
          audioItemId: 'test-audio-1',
          blindListenPassCount: 2,
          targetBlindListenPasses: 2,
          blindListenCompleted: false,
        ),
      );
      await _pumpUi(tester, 800);

      // 触发完成
      session.setState(session.state.copyWith(blindListenCompleted: true));
      await _pumpUi(tester, 1000);

      // === 5. 完成对话框 → 选择难度 → 点击"返回计划" ===
      expect(find.byType(StepCompleteDialog), findsOneWidget);

      // 选择 "Okay" 难度
      await tester.tap(find.text('Okay'));
      await _pumpUi(tester, 800);

      // 点击 "Back to Plan"（返回计划页查看进度更新）
      await tester.tap(find.text('Back to Plan'));
      await _pumpUi(tester, 1200);

      // === 6. 返回学习计划页 → 验证进度更新 ===
      // 盲听页面已退出
      expect(find.byType(BlindListenPlayerScreen), findsNothing);

      // 验证进度更新：盲听完成 → 当前步骤应推进到精听
      // 底部按钮应变为"Continue Learning"（因为 isStarted = true）
      expect(find.text('Continue Learning'), findsOneWidget);

      // 验证完成标记（绿色勾）出现在盲听步骤
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('精听断点续学验证', (tester) async {
      // === 1. 设置初始进度：精听阶段 + 断点在第 3 句（索引 2）===
      final progress = createTestLearningProgress(
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        blindListenPassCount: 2,
        intensiveListenSentenceIndex: 2,
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      // === 2. 导航到学习计划页 ===
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      await tester.pumpAndSettle();

      // 验证底部按钮显示"Continue Learning"
      expect(find.text('Continue Learning'), findsOneWidget);

      // === 3. 验证断点进度数据正确保存 ===
      // 通过读取 Provider state 验证断点值（复用上方 container）
      final progressState = container.read(learningProgressNotifierProvider);
      final savedProgress = progressState.progressMap['test-audio-1'];
      expect(savedProgress, isNotNull);
      expect(savedProgress!.intensiveListenSentenceIndex, equals(2));
      expect(
        savedProgress.currentSubStage,
        equals(SubStageType.intensiveListen),
      );
    });
  });
}

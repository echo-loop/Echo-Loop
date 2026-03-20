/// 学习统计显示集成测试
///
/// 验证修复的 6 个 Bug：
/// 1. 遍数语义纠正（PassCount 替代 RepeatCount）
/// 2. 难句数实时更新（从 bookmarks 表查询）
/// 3. 所有退出路径保存统计
/// 4. 跟读/精听 settings 变更时 clamp playCount
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/intensive_listen_player_screen.dart';
import 'package:fluency/screens/listen_and_repeat_player_screen.dart';

import '../helpers/test_notifiers.dart';

/// 学习统计显示集成测试
void statsDisplayTests() {
  group('流程 9：学习统计显示修复', () {
    // ========== 精听完成保存统计 ==========

    testWidgets('精听正常完成 → 保存难句数 + 递增精听遍数', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            blindListenPassCount: 2,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到精听播放器
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.intensiveListen,
          audioItemId: 'test-audio-1',
        ),
      );

      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(
        IntensiveListenState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
          difficultSentences: {0, 2, 4}, // 标记 3 个难句
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await tester.pumpAndSettle();

      // 触发完成
      final screenContext = tester.element(
        find.byType(IntensiveListenPlayerScreen),
      );
      final screenContainer = ProviderScope.containerOf(screenContext);
      final p =
          screenContainer.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      p.setState(p.state.copyWith(
        currentSentenceIndex: p.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 完成对话框弹出 → 点击"Back to Plan"
      expect(find.text('Intensive Listening Complete'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // 验证进度已更新
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];

      expect(progress, isNotNull);
      // 难句数快照已保存
      expect(progress!.intensiveListenDifficultCount, equals(3));
      // 精听总遍数递增到 1
      expect(progress.intensiveListenPassCount, equals(1));
    });

    testWidgets('精听中途退出 → 保存难句数快照', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            blindListenPassCount: 2,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到精听播放器
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.intensiveListen,
          audioItemId: 'test-audio-1',
        ),
      );

      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(
        IntensiveListenState(
          currentSentenceIndex: 2,
          totalSentences: sentences.length,
          difficultSentences: {1, 3}, // 标记 2 个难句
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await tester.pumpAndSettle();

      // 点击返回按钮触发退出
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 确认对话框 → 点击 Exit
      expect(find.text('Exit Intensive Listening?'), findsOneWidget);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      // 验证精听页面已退出
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);

      // 验证难句数快照已保存
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];

      expect(progress, isNotNull);
      expect(progress!.intensiveListenDifficultCount, equals(2));
      // 中途退出不递增遍数
      expect(progress.intensiveListenPassCount, isNull);
    });

    testWidgets('精听自由练习完成 → 保存难句数 + 递增遍数', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            blindListenPassCount: 2,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到精听播放器（自由练习模式）
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.intensiveListen,
          audioItemId: 'test-audio-1',
          isFreePlay: true,
        ),
      );

      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(
        IntensiveListenState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
          difficultSentences: {0, 1}, // 标记 2 个难句
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await tester.pumpAndSettle();

      // 触发完成（自由练习模式弹出完成对话框）
      final screenContext = tester.element(
        find.byType(IntensiveListenPlayerScreen),
      );
      final screenContainer = ProviderScope.containerOf(screenContext);
      final p =
          screenContainer.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      p.setState(p.state.copyWith(
        currentSentenceIndex: p.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 自由练习完成后弹窗，点击"完成"退出
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 验证进度
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];

      expect(progress, isNotNull);
      // 自由练习也保存难句数
      expect(progress!.intensiveListenDifficultCount, equals(2));
      // 自由练习也递增遍数
      expect(progress.intensiveListenPassCount, equals(1));
    });

    // ========== 跟读完成保存统计 ==========

    testWidgets('跟读正常完成 → 递增跟读遍数', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            blindListenPassCount: 2,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到跟读播放器
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.listenAndRepeat,
          audioItemId: 'test-audio-1',
        ),
      );

      final player =
          container.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      final sentences = createTestSentences(count: 3);
      player.setTestSentences(sentences);
      player.setState(
        ListenAndRepeatPlayerState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
          targetPlayCount: 3,
        ),
      );

      container
          .read(appRouterProvider)
          .push(
            '/collections/test-collection-1/test-audio-1/listen-and-repeat',
          );
      await tester.pumpAndSettle();

      // 触发完成
      final screenContext = tester.element(
        find.byType(ListenAndRepeatPlayerScreen),
      );
      final screenContainer = ProviderScope.containerOf(screenContext);
      final p =
          screenContainer.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      p.setState(p.state.copyWith(
        currentSentenceIndex: p.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 完成对话框弹出 → 点击"Back to Plan"
      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // 验证跟读遍数递增
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];

      expect(progress, isNotNull);
      expect(progress!.shadowingPassCount, equals(1));
    });

    testWidgets('跟读自由练习完成 → 递增跟读遍数', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            blindListenPassCount: 2,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 导航到跟读播放器（自由练习模式）
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.listenAndRepeat,
          audioItemId: 'test-audio-1',
          isFreePlay: true,
        ),
      );

      final player =
          container.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      final sentences = createTestSentences(count: 3);
      player.setTestSentences(sentences);
      player.setState(
        ListenAndRepeatPlayerState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
          targetPlayCount: 3,
        ),
      );

      container
          .read(appRouterProvider)
          .push(
            '/collections/test-collection-1/test-audio-1/listen-and-repeat',
          );
      await tester.pumpAndSettle();

      // 触发完成（自由练习模式弹出完成对话框）
      final screenContext = tester.element(
        find.byType(ListenAndRepeatPlayerScreen),
      );
      final screenContainer = ProviderScope.containerOf(screenContext);
      final p =
          screenContainer.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      p.setState(p.state.copyWith(
        currentSentenceIndex: p.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 完成对话框弹出 → 点击"Done"完成退出
      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 验证跟读遍数递增
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];

      expect(progress, isNotNull);
      expect(progress!.shadowingPassCount, equals(1));
    });

    // ========== 学习计划页统计显示 ==========

    testWidgets('学习计划页显示精听遍数和跟读遍数', (tester) async {
      // 预设进度：精听已完成 2 遍，跟读已完成 1 遍，当前在跟读阶段
      final progress = createTestLearningProgress(
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        blindListenPassCount: 2,
        intensiveListenPassCount: 2,
        shadowingPassCount: 1,
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      // 导航到学习计划页
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      await tester.pumpAndSettle();

      // 验证精听遍数显示（"Intensive listen 2x"）
      expect(find.textContaining('2x'), findsWidgets);
      // 验证跟读遍数显示（"Shadowing 1x"）
      expect(find.textContaining('1x'), findsWidgets);
    });

    testWidgets('精听完成闭环 → 返回计划页 → 遍数更新', (tester) async {
      // 预设：精听阶段，已有 1 遍精听
      final progress = createTestLearningProgress(
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        blindListenPassCount: 2,
        intensiveListenPassCount: 1,
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      // 导航到精听播放器
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.intensiveListen,
          audioItemId: 'test-audio-1',
        ),
      );

      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(
        IntensiveListenState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
          difficultSentences: {0, 1, 2},
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await tester.pumpAndSettle();

      // 触发完成
      final screenContext = tester.element(
        find.byType(IntensiveListenPlayerScreen),
      );
      final screenContainer = ProviderScope.containerOf(screenContext);
      final p =
          screenContainer.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      p.setState(p.state.copyWith(
        currentSentenceIndex: p.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 点击"Back to Plan"
      expect(find.text('Intensive Listening Complete'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // 验证 Provider 中遍数递增（1 → 2）
      final appContext2 = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(appContext2);
      final progressState = container2.read(learningProgressNotifierProvider);
      final updatedProgress = progressState.progressMap['test-audio-1'];

      expect(updatedProgress, isNotNull);
      expect(updatedProgress!.intensiveListenPassCount, equals(2));
      expect(updatedProgress.intensiveListenDifficultCount, equals(3));
    });
  });
}

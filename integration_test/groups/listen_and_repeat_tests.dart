/// 跟读播放器集成测试
///
/// 验证跟读播放器的 UI 展示、导航、完成对话框和退出保存断点。
/// 包含 5 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/speech_practice_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/listen_and_repeat_player_screen.dart';
import 'package:fluency/widgets/intensive_listen/sentence_annotation_card.dart';

import '../helpers/test_notifiers.dart';

/// 跟读播放器集成测试
void listenAndRepeatTests() {
  group('流程 8：跟读播放器', () {
    /// 导航到跟读播放器的辅助方法
    ///
    /// 设置 LearningSession 为跟读模式，
    /// 初始化 ListenAndRepeatPlayer 难句数据。
    Future<void> navigateToListenAndRepeat(WidgetTester tester) async {
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 设置学习会话为跟读模式
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.listenAndRepeat,
          audioItemId: 'test-audio-1',
        ),
      );

      // 初始化跟读播放器的句子数据（模拟 3 个难句）
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
    }

    /// 获取 ProviderContainer 辅助方法
    ProviderContainer getContainer(WidgetTester tester) {
      final context = tester.element(find.byType(ListenAndRepeatPlayerScreen));
      return ProviderScope.containerOf(context);
    }

    testWidgets('跟读页面基本 UI', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      // 验证 AppBar 标题
      expect(find.text('Listen & Repeat'), findsOneWidget);

      // 验证进度条
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 验证播放控制按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // 验证句子标注卡片（跟读模式始终显示文本）
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);

      // 验证遍数信息
      expect(find.textContaining('1/3'), findsWidgets);
    });

    testWidgets('上一句/下一句导航', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      // 初始在第 1 句，进度显示 "Repeat 1/3"
      expect(find.textContaining('1/3'), findsWidgets);

      // 点击下一句
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证进度变为 2/3
      expect(find.textContaining('2/3'), findsWidgets);

      // 点击上一句
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.pumpAndSettle();

      // 验证进度回到 1/3
      expect(find.textContaining('1/3'), findsWidgets);
    });

    testWidgets('跟读完成对话框', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      final container = getContainer(tester);

      // 定位到最后一句，点击"下一句"触发完成
      final player =
          container.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      player.setState(player.state.copyWith(
        currentSentenceIndex: player.state.totalSentences - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证完成对话框弹出
      expect(find.text('Listen & Repeat Complete'), findsOneWidget);
      // 验证步骤进度信息
      expect(find.textContaining('3/4'), findsOneWidget);
      // 验证"返回计划"按钮
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('跟读中退出保存断点', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      // 导航到第 2 句（索引 1）
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证当前在第 2 句
      expect(find.textContaining('2/3'), findsWidgets);

      // 点击返回按钮触发退出
      final backButton = find.byIcon(Icons.close);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 验证确认对话框弹出
      expect(find.text('Exit Listen & Repeat?'), findsOneWidget);

      // 点击"Exit"确认退出
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      // 验证跟读页面已退出
      expect(find.byType(ListenAndRepeatPlayerScreen), findsNothing);

      // 验证断点已保存
      final context = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(context);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];
      expect(progress?.shadowingSentenceIndex, equals(1));
    });

    testWidgets('设置按钮弹出设置面板', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      // 验证设置按钮存在
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // 点击设置按钮
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // 验证设置面板弹出（包含循环次数配置）
      expect(find.text('Repeat per sentence'), findsOneWidget);
      expect(find.text('Smart'), findsOneWidget);
    });

    testWidgets('轮到用户说时可录音并显示识别结果', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.listenAndRepeat,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToListenAndRepeat(tester);

      final container = getContainer(tester);
      final player =
          container.read(listenAndRepeatPlayerProvider.notifier)
              as TestListenAndRepeatPlayer;
      final platform =
          container.read(speechPracticeBackendProvider)
              as TestSpeechPracticePlatform;
      platform.transcriptsByPath['/tmp/test-recording-1.caf'] =
          'test sentence number 1';

      player.setState(
        player.state.copyWith(
          isPlaying: false,
          isPauseBetweenPlays: true,
          pauseRemaining: const Duration(seconds: 3),
          pauseDuration: const Duration(seconds: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Record'), findsOneWidget);

      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Matched'), findsOneWidget);
      expect(find.text('Play My Recording'), findsOneWidget);
    });
  });
}

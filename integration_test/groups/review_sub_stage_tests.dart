/// 复习子步骤集成测试
///
/// 验证复习阶段的学习计划展示和子步骤入口交互，
/// 包括难句补练页面 UI、复习段落复述入口（无双弹窗）、
/// 以及复习总结复述简报。
/// 包含 6 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/database/app_database.dart' show BookmarksCompanion;
import 'package:fluency/database/providers.dart';
import 'package:fluency/main.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/review_difficult_practice_screen.dart';

import '../helpers/test_notifiers.dart';

/// 复习子步骤集成测试
void reviewSubStageTests() {
  group('流程 11：复习子步骤', () {
    /// 导航到学习计划页的辅助方法
    Future<void> navigateToLearningPlan(WidgetTester tester) async {
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/plan');
      await tester.pumpAndSettle();
    }

    testWidgets('review0 阶段展示 2 个复习子步骤', (tester) async {
      // review0 子步骤：reviewDifficultPractice, reviewRetellParagraph
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 滚动到 Review 1 区域
      await tester.scrollUntilVisible(
        find.text('Review 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 验证 review0 标题显示
      expect(find.text('Review 1'), findsOneWidget);

      // 点击展开 Review 1 区域查看子步骤
      await tester.tap(find.text('Review 1'));
      await tester.pumpAndSettle();

      // 验证 2 个复习子步骤名称
      expect(find.text('Difficult sentence practice'), findsOneWidget);
      expect(find.text('Paragraph retelling'), findsOneWidget);

      // 验证底部按钮显示"Continue Learning"
      expect(find.text('Continue Learning'), findsOneWidget);
    });

    testWidgets('复习难句补练入口弹出复习简报后导航到难句补练页面', (tester) async {
      // review0 当前子步骤为 reviewDifficultPractice
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 预置书签数据（难句补练需要 bookmarked 句子）
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      final bookmarkDao =
          container.read(bookmarkDaoProvider) as TestBookmarkDao;
      // 添加一些书签
      final now = DateTime.now();
      await bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'test-audio-1',
          sentenceIndex: 0,
          sentenceText: 'Test sentence number 1.',
          startTime: 0.0,
          endTime: 5.0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'test-audio-1',
          sentenceIndex: 2,
          sentenceText: 'Test sentence number 3.',
          startTime: 10.0,
          endTime: 15.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 点击"Continue Learning"（用 last 避免匹配学习页 Hero Card 的同名文本）
      await tester.tap(find.text('Continue Learning').last);
      await tester.pumpAndSettle();

      // 验证弹出复习简报 → 含"Start Practice"按钮
      expect(find.text('Start Practice'), findsOneWidget);

      // 点击"Start Practice"
      await tester.tap(find.text('Start Practice'));
      await tester.pumpAndSettle();

      // 验证导航到了难句补练页面
      expect(find.byType(ReviewDifficultPracticeScreen), findsOneWidget);
      expect(find.text('Difficult Sentence Practice'), findsOneWidget);
    });

    testWidgets('复习段落复述入口只弹出一个弹窗（时长选择）', (tester) async {
      // review0 当前子步骤为 reviewRetellParagraph
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewRetellParagraph,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 点击"Continue Learning"（用 last 避免匹配学习页 Hero Card 的同名文本）
      await tester.tap(find.text('Continue Learning').last);
      await tester.pumpAndSettle();

      // 应该直接弹出复述简报（含时长选择），而非先弹复习简报
      // 验证显示的是复述时长选择弹窗
      expect(find.text('Paragraph Retelling'), findsOneWidget);
      expect(find.text('Target paragraph duration'), findsOneWidget);

      // 验证只有一个"Start Practice"按钮（不是两个弹窗叠加）
      expect(find.text('Start Practice'), findsOneWidget);
    });

    testWidgets('review1 阶段展示 3 个复习子步骤（含盲听）', (tester) async {
      // review1 子步骤：blindListen, reviewDifficultPractice, reviewRetellParagraph
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.blindListen,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await navigateToLearningPlan(tester);

      // 滚动到 Review 2 区域（可能在视口外）
      await tester.scrollUntilVisible(
        find.text('Review 2'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 验证 review1 标题显示
      expect(find.text('Review 2'), findsOneWidget);

      // 点击展开 Review 2 区域查看子步骤
      await tester.tap(find.text('Review 2'));
      await tester.pumpAndSettle();

      // 验证 3 个子步骤名称（review0 已完成也自动展开，故可能出现多个同名步骤）
      expect(find.text('Blind Listening'), findsWidgets);
      expect(find.text('Difficult sentence practice'), findsWidgets);
      expect(find.text('Paragraph retelling'), findsWidgets);
    });

    testWidgets('难句补练页面基本 UI', (tester) async {
      // review0 难句补练阶段
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      // 预置难句播放器状态
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 设置 learningSession 为 reviewDifficultPractice 模式
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      await session.enterReviewDifficultPracticeMode(
        'test-audio-1',
        createTestSentences(),
      );

      // 初始化难句播放器
      final player =
          container.read(reviewDifficultPracticeProvider.notifier)
              as TestReviewDifficultPractice;
      player.initialize(createTestSentences(count: 3));
      player.setState(
        const ReviewDifficultPracticeState(
          currentSentenceIndex: 0,
          totalSentences: 3,
          isPlaying: true,
        ),
      );

      // 直接导航到难句补练页面
      container
          .read(appRouterProvider)
          .push(
            AppRoutes.reviewDifficultPractice(
              'test-collection-1',
              'test-audio-1',
            ),
          );
      await tester.pumpAndSettle();

      // 验证 AppBar 标题
      expect(find.text('Difficult Sentence Practice'), findsOneWidget);

      // 验证进度条存在
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 验证进度文本
      expect(find.text('1/3 sentences'), findsOneWidget);

      // 验证操作按钮：偷看 + 听不懂
      expect(find.text('Peek'), findsOneWidget);
      expect(find.text("Can't understand"), findsOneWidget);

      // 验证底部播放控制按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('难句补练完成弹出完成对话框', (tester) async {
      // review0 难句补练阶段
      final progress = createTestLearningProgress(
        currentStage: LearningStage.review0,
        currentSubStage: SubStageType.reviewDifficultPractice,
        blindListenPassCount: 2,
        firstLearnCompletedAt: DateTime(2026, 1, 1),
        lastStageCompletedAt: DateTime(2026, 1, 1),
        currentStageStartedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestAppWithAudio(progressOverride: progress),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 设置 learningSession 为 reviewDifficultPractice 模式
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      await session.enterReviewDifficultPracticeMode(
        'test-audio-1',
        createTestSentences(),
      );

      // 初始化难句播放器（先设置为未完成状态）
      final player =
          container.read(reviewDifficultPracticeProvider.notifier)
              as TestReviewDifficultPractice;
      player.initialize(createTestSentences(count: 3));
      player.setState(
        const ReviewDifficultPracticeState(
          currentSentenceIndex: 2,
          totalSentences: 3,
          isPlaying: false,
        ),
      );

      // 导航到难句补练页面
      container
          .read(appRouterProvider)
          .push(
            AppRoutes.reviewDifficultPractice(
              'test-collection-1',
              'test-audio-1',
            ),
          );
      await tester.pumpAndSettle();

      // 定位到最后一句，点击"下一句"触发完成
      player.setState(
        const ReviewDifficultPracticeState(
          currentSentenceIndex: 2,
          totalSentences: 3,
          isPlaying: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证完成对话框出现
      expect(find.text('Difficult Practice Complete'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // 验证有"Continue"和"Back to Plan"按钮
      // review0 当前是第 1 步（共 2 步），还有下一步（reviewRetellParagraph）
      expect(find.text('Back'), findsOneWidget);
      // 下一步名称包含 "Continue:"
      expect(find.textContaining('Continue:'), findsOneWidget);
    });
  });
}

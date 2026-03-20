/// 复述播放器集成测试
///
/// 验证复述播放器的 UI 展示、段落导航、显示模式切换、
/// 完成对话框、退出保存断点和设置面板。
/// 包含 8 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/database/enums.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/retell_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/retell_player_screen.dart';
import 'package:fluency/models/retell_settings.dart';
import 'package:fluency/models/sentence.dart';

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

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 20,
  int stepMilliseconds = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(Duration(milliseconds: stepMilliseconds));
    if (condition()) {
      return;
    }
  }
}

/// 创建测试用段落列表（3 段，每段 2-3 句）
List<List<Sentence>> _createTestParagraphs() {
  return [
    // 段落 1：2 句
    [
      Sentence(
        index: 0,
        text: 'The quick brown fox jumps over the lazy dog.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 5),
      ),
      Sentence(
        index: 1,
        text: 'A wonderful serenity has taken possession of my soul.',
        startTime: const Duration(seconds: 5),
        endTime: const Duration(seconds: 10),
      ),
    ],
    // 段落 2：3 句
    [
      Sentence(
        index: 2,
        text: 'I should be incapable of drawing a single stroke.',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 15),
      ),
      Sentence(
        index: 3,
        text: 'The beautiful morning light fills the entire room.',
        startTime: const Duration(seconds: 15),
        endTime: const Duration(seconds: 20),
      ),
      Sentence(
        index: 4,
        text: 'Everything seems perfectly arranged and harmonious.',
        startTime: const Duration(seconds: 20),
        endTime: const Duration(seconds: 25),
      ),
    ],
    // 段落 3：2 句
    [
      Sentence(
        index: 5,
        text: 'The magnificent castle overlooked the peaceful valley below.',
        startTime: const Duration(seconds: 25),
        endTime: const Duration(seconds: 30),
      ),
      Sentence(
        index: 6,
        text: 'Ancient traditions continue throughout generations.',
        startTime: const Duration(seconds: 30),
        endTime: const Duration(seconds: 35),
      ),
    ],
  ];
}

/// 创建测试用关键词映射
Map<int, Set<int>> _createTestKeywords() {
  return {
    0: {2, 3}, // "brown", "fox"
    1: {1, 3}, // "wonderful", "serenity"
    3: {1, 3}, // "beautiful", "morning"
    5: {1, 5}, // "magnificent", "peaceful"
  };
}

/// 复述播放器集成测试
void retellTests() {
  group('流程 10：复述播放器', () {
    /// 导航到复述播放器的辅助方法
    ///
    /// 设置 LearningSession 为复述模式，
    /// 初始化 RetellPlayer 段落数据。
    Future<void> navigateToRetell(WidgetTester tester) async {
      await _pumpUi(tester, 1000);
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);

      // 设置学习会话为复述模式
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.retell,
          audioItemId: 'test-audio-1',
        ),
      );

      // 初始化复述播放器
      final player =
          container.read(retellPlayerProvider.notifier) as TestRetellPlayer;
      final paragraphs = _createTestParagraphs();
      final keywords = _createTestKeywords();
      player.setTestParagraphs(paragraphs);
      player.setTestKeywords(keywords);
      player.setState(
        RetellPlayerState(
          currentParagraphIndex: 0,
          totalParagraphs: paragraphs.length,
          phase: RetellPhase.listening,
          isPlaying: true,
          playingSentenceIndex: 0,
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/retell');
      await _pumpUntilFound(tester, find.byType(RetellPlayerScreen));
    }

    /// 获取 ProviderContainer 辅助方法
    ProviderContainer getContainer(WidgetTester tester) {
      final context = tester.element(find.byType(RetellPlayerScreen));
      return ProviderScope.containerOf(context);
    }

    Finder appBarTuneButton() => find.widgetWithIcon(IconButton, Icons.tune);

    Future<void> openSettingsSheet(WidgetTester tester) async {
      final button = tester.widget<IconButton>(appBarTuneButton());
      button.onPressed?.call();
      await tester.pumpAndSettle();
    }

    testWidgets('复述页面基本 UI', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      // 验证 AppBar 标题
      expect(find.text('Paragraph Retelling'), findsOneWidget);

      // 验证进度条
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      // 验证段落进度信息
      expect(find.textContaining('1/3'), findsWidgets);

      // 验证播放控制按钮（listening phase）
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // 验证 AppBar 操作按钮（显示模式 + 设置）
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });

    testWidgets('段落导航 — 上一段/下一段', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      final container = getContainer(tester);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 0);

      // 点击下一段
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await _pumpUntil(
        tester,
        () => container.read(retellPlayerProvider).currentParagraphIndex == 1,
      );

      // 验证推进到第 2 段（索引 1）
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);

      // 点击上一段
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await _pumpUntil(
        tester,
        () => container.read(retellPlayerProvider).currentParagraphIndex == 0,
      );

      // 验证回到第 1 段（索引 0）
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 0);
    });

    testWidgets('显示模式 SegmentedButton 切换', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      // 验证三个显示模式按钮存在
      expect(find.text('Visible Only'), findsOneWidget);
      expect(find.text('Show All'), findsOneWidget);
      expect(find.text('Hide All'), findsOneWidget);

      // listening 阶段默认模式 hideAll
      final container = getContainer(tester);
      expect(
        container.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.hideAll,
      );

      // listening 阶段即可切换显示模式（无需等到 retelling）
      // 点击"全部显示"
      await tester.tap(find.text('Show All'));
      await tester.pumpAndSettle();
      expect(
        container.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.showAll,
      );

      // 点击"全部隐藏"
      await tester.tap(find.text('Hide All'));
      await tester.pumpAndSettle();
      expect(
        container.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.hideAll,
      );
    });

    testWidgets('复述完成对话框 — 完成退出', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      final container = getContainer(tester);

      // 定位到最后一段，然后点击"下一段"触发完成
      final player =
          container.read(retellPlayerProvider.notifier) as TestRetellPlayer;
      player.setState(player.state.copyWith(
        currentParagraphIndex: player.state.totalParagraphs - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();

      // 点击"下一段"按钮触发完成
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证完成对话框弹出
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Retelling Complete'), findsOneWidget);

      // 验证统计信息
      expect(find.text('3 paragraphs retold'), findsOneWidget);

      // 验证"再来一遍"和"完成首次学习"按钮都存在
      expect(find.text('Practice Again'), findsOneWidget);
      expect(find.text('Complete First Study'), findsOneWidget);
    });

    testWidgets('复述完成对话框 — 再来一遍', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      final container = getContainer(tester);

      // 定位到最后一段，点击"下一段"触发完成
      final player =
          container.read(retellPlayerProvider.notifier) as TestRetellPlayer;
      player.setState(player.state.copyWith(
        currentParagraphIndex: player.state.totalParagraphs - 1,
        isPlaying: false,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 点击"再来一遍"
      await tester.tap(find.text('Practice Again'));
      await tester.pumpAndSettle();

      // 对话框关闭，页面仍在
      expect(find.byType(RetellPlayerScreen), findsOneWidget);

      // 验证重置到第 1 段
      expect(find.textContaining('1/3'), findsWidgets);
    });

    testWidgets('复述中退出保存断点', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      // 导航到第 2 段
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.pumpAndSettle();

      // 验证当前在第 2 段
      expect(find.textContaining('2/3'), findsWidgets);

      // 点击关闭按钮触发退出
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 验证确认对话框弹出
      expect(find.text('Exit Retelling?'), findsOneWidget);

      // 点击确认退出
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // 验证复述页面已退出
      expect(find.byType(RetellPlayerScreen), findsNothing);

      // 验证断点已保存（第 2 段第一句的全局句子索引 = 2）
      final context = tester.element(find.byType(FluencyApp));
      final container2 = ProviderScope.containerOf(context);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];
      expect(progress?.retellParagraphIndex, equals(2));
    });

    testWidgets('设置按钮弹出设置面板', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      // 验证设置按钮存在
      final settingsButton = appBarTuneButton();
      expect(settingsButton, findsOneWidget);

      // 点击设置按钮
      await openSettingsSheet(tester);

      // 验证设置面板弹出（包含重复次数和停顿模式）
      expect(find.text('Retell Settings'), findsOneWidget);
      expect(find.text('Repeat per paragraph'), findsOneWidget);
      expect(find.text('Smart'), findsOneWidget);
    });

    testWidgets('设置面板 — 可见词生成方式和比例', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.retell,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToRetell(tester);

      // 打开设置面板
      await openSettingsSheet(tester);

      // 验证可见词生成方式区域存在（3 个选项）
      expect(find.text('Visible words'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);

      // 默认 random → 比例区域可见
      expect(find.text('Visible ratio'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      // 点击 1/2 比例
      await tester.tap(find.text('1/2'));
      await tester.pumpAndSettle();

      final container = getContainer(tester);
      final settings = container.read(retellPlayerProvider).settings;
      expect(settings.keywordRatio, equals(KeywordRatio.half));

      // 切换到"关闭" → 比例区域消失
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();

      expect(
        container.read(retellPlayerProvider).settings.keywordMethod,
        equals(KeywordMethod.off),
      );
      expect(find.text('Visible ratio'), findsNothing);
    });
  });
}

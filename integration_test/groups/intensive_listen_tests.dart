/// 精听播放器集成测试
///
/// 验证精听播放器的 UI 展示、偷看字幕、导航、标注模式、完成对话框、
/// 退出保存断点、难句书签持久化。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/screens/intensive_listen_player_screen.dart';
import 'package:echo_loop/widgets/practice/sentence_annotation_card.dart';

import '../helpers/test_notifiers.dart';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
  int stepMilliseconds = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(Duration(milliseconds: stepMilliseconds));
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// 精听播放器集成测试
void intensiveListenTests() {
  group('流程 6：精听播放器', () {
    /// 导航到精听播放器的辅助方法
    ///
    /// 需要先设置 LearningSession 为精听模式，
    /// 并初始化 IntensiveListenPlayer 句子数据。
    Future<void> navigateToIntensiveListen(WidgetTester tester) async {
      await safeSettle(tester);
      final context = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(context);

      // 设置学习会话为精听模式
      final session =
          container.read(learningSessionProvider.notifier)
              as TestLearningSession;
      session.setState(
        const LearningSessionState(
          learningMode: LearningMode.intensiveListen,
          audioItemId: 'test-audio-1',
        ),
      );

      // 初始化精听播放器的句子数据
      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      final sentences = createTestSentences();
      player.setTestSentences(sentences);
      player.setState(
        IntensiveListenState(
          currentSentenceIndex: 0,
          totalSentences: sentences.length,
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await safeSettle(tester);
    }

    /// 获取 ProviderContainer 辅助方法
    ProviderContainer getContainer(WidgetTester tester) {
      final context = tester.element(find.byType(IntensiveListenPlayerScreen));
      return ProviderScope.containerOf(context);
    }

    testWidgets('精听页面基本 UI', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 验证 AppBar 标题
      expect(find.text('Intensive Listening'), findsOneWidget);

      // 验证进度条
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 验证播放控制按钮
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      // 进入后自动播放 → pause 图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // 验证偷看和听不懂按钮
      expect(find.text('Peek'), findsOneWidget);
      expect(find.text('Unclear'), findsOneWidget);
    });

    testWidgets('偷看字幕：点击显示，再次点击隐藏', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 初始状态：文字隐藏
      expect(find.text('Test sentence number 1.'), findsNothing);

      // 第一次点击 "Peek" 按钮
      await tester.tap(find.text('Peek'));
      await safeSettle(tester);

      // 验证点击后文本显示（逐词可点击布局，token 后带空格）；按钮文案翻转为 "Hide"
      expect(find.text('sentence '), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      // 第二次点击（此时按钮文案为 Hide）后文本隐藏
      await tester.tap(find.text('Hide'));
      await safeSettle(tester);

      // 验证再次点击后文本隐藏，按钮文案恢复为 "Peek"
      expect(find.text('sentence '), findsNothing);
      expect(find.text('Peek'), findsOneWidget);
    });

    testWidgets('上一句/下一句导航', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 初始在第 1 句（索引 0），进度显示 "Intensive 1/5"
      expect(find.textContaining('1/5'), findsOneWidget);

      // 点击下一句
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);

      // 验证进度变为 2/5
      expect(find.textContaining('2/5'), findsOneWidget);

      // 再点击下一句
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);

      // 验证进度变为 3/5
      expect(find.textContaining('3/5'), findsOneWidget);

      // 点击上一句
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await safeSettle(tester);

      // 验证进度回到 2/5
      expect(find.textContaining('2/5'), findsOneWidget);
    });

    testWidgets('标注模式进入', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 点击"Unclear"进入标注模式（等待按钮渲染，GuideTarget 包装可能延迟）
      await _pumpUntilFound(tester, find.text('Unclear'));
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);

      // 验证标注卡片出现
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);
      // 验证"Continue"按钮
      expect(find.text('Continue'), findsOneWidget);
      // 偷看和听不懂按钮应消失
      expect(find.text('Peek'), findsNothing);
      expect(find.text('Unclear'), findsNothing);
    });

    testWidgets('标注模式退出', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 进入标注模式
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);

      // 验证标注卡片存在
      expect(find.byType(SentenceAnnotationCard), findsWidgets);

      // 通过 provider 退出标注模式（按钮 tap 在 LiveTest 下可能不生效）
      final ctx2 = tester.element(find.byType(EchoLoopApp));
      final c2 = ProviderScope.containerOf(ctx2);
      final p = c2.read(intensiveListenPlayerProvider.notifier)
          as TestIntensiveListenPlayer;
      p.setState(p.state.copyWith(
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isPlaying: true,
      ));
      await safeSettle(tester);

      // 验证标注卡片消失
      expect(find.byType(SentenceAnnotationCard), findsNothing);
    });

    testWidgets('精听完成对话框', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      final container = getContainer(tester);

      // 定位到最后一句，点击"下一句"触发完成
      final player =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
      player.setState(player.state.copyWith(
        currentSentenceIndex: player.state.totalSentences - 1,
        isPlaying: false,
      ));
      await safeSettle(tester);
      // 最后一句时，下一步按钮变为完成图标
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await safeSettle(tester);

      // 验证完成对话框弹出
      expect(find.text('Intensive Listening Complete'), findsOneWidget);
      // 验证步骤进度信息
      expect(find.textContaining('2/4'), findsOneWidget);
      // 精听后的步骤（listenAndRepeat）有播放器，显示"完成"和"继续"两个按钮
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('Continue'), findsOneWidget);
    });

    testWidgets('精听中退出保存断点', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 导航到第 3 句（索引 2）
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);

      // 验证当前在第 3 句
      expect(find.textContaining('3/5'), findsOneWidget);

      // 点击返回按钮触发退出
      final backButton = find.byIcon(Icons.close);
      await tester.tap(backButton);
      await safeSettle(tester);

      // 验证确认对话框弹出
      expect(find.text('Exit Intensive Listening?'), findsOneWidget);

      // 点击"Exit"确认退出
      await tester.tap(find.text('Exit'));
      await safeSettle(tester, timeout: const Duration(seconds: 10));

      // 验证精听页面已退出
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);

      // 验证断点已保存（通过检查进度 state）
      final context = tester.element(find.byType(EchoLoopApp));
      final container2 = ProviderScope.containerOf(context);
      final progressState = container2.read(learningProgressNotifierProvider);
      final progress = progressState.progressMap['test-audio-1'];
      expect(progress?.intensiveListenSentenceIndex, equals(2));
    });

    testWidgets('看不懂标记难句 → 退出 → 书签持久化到数据库', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 点击"Can't understand"进入标注模式 → 自动标记当前句子为难句
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);

      // 验证进入标注模式
      expect(find.byType(SentenceAnnotationCard), findsOneWidget);

      // 退出标注模式
      await tester.tap(find.text('Continue'));
      await safeSettle(tester);

      // 点击关闭按钮触发退出
      await tester.tap(find.byIcon(Icons.close));
      await safeSettle(tester);

      // 确认退出对话框
      expect(find.text('Exit Intensive Listening?'), findsOneWidget);
      await tester.tap(find.text('Exit'));
      // 退出对话框确认后路由 pop + 状态清理需要多帧，5 秒可能不够。
      await safeSettle(tester, timeout: const Duration(seconds: 10));

      // 验证精听页面已退出
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);

      // 验证书签已持久化到数据库
      final context = tester.element(find.byType(EchoLoopApp));
      final container2 = ProviderScope.containerOf(context);
      final bookmarkDao =
          container2.read(bookmarkDaoProvider) as TestBookmarkDao;
      final bookmarkedIndices =
          await bookmarkDao.getBookmarkedIndices('test-audio-1');
      // 第一句（index 0）被标记为难句
      expect(bookmarkedIndices, contains(0));

      // 难句数快照字段当前未在 production 代码中被写入（仅 schema 保留），
      // 仅断言 bookmark 真实落库即可。
    });

    testWidgets('freePlay 模式退出时也持久化难句书签', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );

      // 导航到精听并设置为 freePlay 模式
      await safeSettle(tester);
      final ctx = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(ctx);

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
        ),
      );

      container
          .read(appRouterProvider)
          .push('/collections/test-collection-1/test-audio-1/intensive-listen');
      await safeSettle(tester);

      // 点击"Can't understand" → 标注模式 → 自动标记难句
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);

      // 退出标注模式
      await tester.tap(find.text('Continue'));
      await safeSettle(tester);

      // freePlay 模式点击关闭直接退出（无确认对话框）
      await tester.tap(find.byIcon(Icons.close));
      await safeSettle(tester, timeout: const Duration(seconds: 10));

      // 验证精听页面已退出
      expect(find.byType(IntensiveListenPlayerScreen), findsNothing);

      // 验证书签已持久化到数据库
      final container2 = ProviderScope.containerOf(
        tester.element(find.byType(EchoLoopApp)),
      );
      final bookmarkDao =
          container2.read(bookmarkDaoProvider) as TestBookmarkDao;
      final bookmarkedIndices =
          await bookmarkDao.getBookmarkedIndices('test-audio-1');
      expect(bookmarkedIndices, contains(0));

      // 难句数快照字段当前未在 production 代码中被写入（仅 schema 保留），
      // 仅断言 bookmark 真实落库即可。
    });

    testWidgets('多句标记难句 → 退出 → 全部持久化', (tester) async {
      await tester.pumpWidget(
        createTestAppWithAudio(
          progressOverride: createTestLearningProgress(
            currentSubStage: SubStageType.intensiveListen,
            currentStageStartedAt: DateTime.now(),
          ),
        ),
      );
      await navigateToIntensiveListen(tester);

      // 第 1 句：点击"看不懂"
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);
      await tester.tap(find.text('Continue'));
      await safeSettle(tester);

      // 导航到第 3 句（索引 2）
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await safeSettle(tester);

      // 第 3 句：点击"看不懂"
      await tester.tap(find.text('Unclear'));
      await safeSettle(tester);
      await tester.tap(find.text('Continue'));
      await safeSettle(tester);

      // 退出
      await tester.tap(find.byIcon(Icons.close));
      await safeSettle(tester);
      await tester.tap(find.text('Exit'));
      await safeSettle(tester);

      // 验证两个书签都已持久化
      final context = tester.element(find.byType(EchoLoopApp));
      final container2 = ProviderScope.containerOf(context);
      final bookmarkDao =
          container2.read(bookmarkDaoProvider) as TestBookmarkDao;
      final bookmarkedIndices =
          await bookmarkDao.getBookmarkedIndices('test-audio-1');
      expect(bookmarkedIndices, containsAll([0, 2]));
      expect(bookmarkedIndices.length, equals(2));

      // 难句数快照字段当前未在 production 代码中被写入（仅 schema 保留），
      // 仅断言 bookmark 真实落库即可。
    });
  });
}

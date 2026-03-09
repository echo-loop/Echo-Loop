/// 盲听播放器集成测试
///
/// 验证盲听播放器的 UI 展示、播放控制、倒计时、完成对话框和退出确认。
/// 包含 6 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/main.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/router/app_router.dart';
import 'package:fluency/screens/blind_listen_player_screen.dart';
import 'package:fluency/widgets/dialogs/step_complete_dialog.dart';

import '../helpers/test_notifiers.dart';

Future<void> _pumpUi(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump(Duration(milliseconds: milliseconds));
}

/// 盲听播放器集成测试
void blindListenTests() {
  group('流程 5：盲听播放器', () {
    /// 导航到盲听播放器的辅助方法
    Future<void> navigateToBlindListen(WidgetTester tester) async {
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FluencyApp));
      final container = ProviderScope.containerOf(context);
      container.read(appRouterProvider).push(
        '/collections/test-collection-1/test-audio-1/blind-listen',
      );
      await tester.pumpAndSettle();
    }

    /// 获取 ProviderContainer 辅助方法
    ProviderContainer getContainer(WidgetTester tester) {
      final context = tester.element(find.byType(BlindListenPlayerScreen));
      return ProviderScope.containerOf(context);
    }

    testWidgets('盲听页面基本 UI', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      // 验证 AppBar 标题
      expect(find.text('Full Listening'), findsOneWidget);

      // 验证耳机图标
      expect(find.byIcon(Icons.headphones), findsOneWidget);

      // 验证播放按钮区域存在（进入后自动播放，所以显示 pause）
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 验证进度条
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('播放/暂停切换', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      // 进入后自动播放，显示 pause 图标
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // 点击暂停
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pumpAndSettle();

      // 验证变为 play_arrow
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);

      // 再点击恢复播放
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      // 验证变回 pause
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('第一遍完成显示倒计时覆盖层', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      final container = getContainer(tester);

      // 设置会话状态：第 1 遍，目标 2 遍（hasRemainingPasses = true）
      final session =
          container.read(learningSessionProvider.notifier) as TestLearningSession;
      session.setState(const LearningSessionState(
        learningMode: LearningMode.blindListen,
        audioItemId: 'test-audio-1',
        blindListenPassCount: 1,
        targetBlindListenPasses: 2,
        blindListenCompleted: false,
      ));
      await tester.pumpAndSettle();

      // 触发 blindListenCompleted = true（模拟播放完成）
      session.setState(session.state.copyWith(blindListenCompleted: true));
      await tester.pumpAndSettle();

      // 验证内联倒计时指示器出现（文案格式: "Next play in Xs"）
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // 验证跳过按钮
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('达到目标遍数弹出完成对话框', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      final container = getContainer(tester);

      // 设置会话状态：第 2 遍，目标 2 遍（hasRemainingPasses = false）
      final session =
          container.read(learningSessionProvider.notifier) as TestLearningSession;
      session.setState(const LearningSessionState(
        learningMode: LearningMode.blindListen,
        audioItemId: 'test-audio-1',
        blindListenPassCount: 2,
        targetBlindListenPasses: 2,
        blindListenCompleted: false,
      ));
      await tester.pumpAndSettle();

      // 触发完成
      session.setState(session.state.copyWith(blindListenCompleted: true));
      await tester.pumpAndSettle();

      // 验证完成对话框弹出
      expect(find.byType(StepCompleteDialog), findsOneWidget);
      expect(find.text('Listening Complete'), findsOneWidget);
      // 验证难度选择存在
      expect(find.text('How did it feel?'), findsOneWidget);
      // 验证双按钮："返回计划"和"继续：逐句精听"，以及"再听一遍"
      expect(find.text('Listen Again'), findsOneWidget);
      expect(find.text('Back to Plan'), findsOneWidget);
      expect(find.text('Continue: Intensive Listening'), findsOneWidget);
      // 验证步骤进度
      expect(find.textContaining('1/4'), findsOneWidget);
    });

    testWidgets('选择难度并退出', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      final container = getContainer(tester);

      // 设置会话状态：达到目标遍数
      final session =
          container.read(learningSessionProvider.notifier) as TestLearningSession;
      session.setState(const LearningSessionState(
        learningMode: LearningMode.blindListen,
        audioItemId: 'test-audio-1',
        blindListenPassCount: 2,
        targetBlindListenPasses: 2,
        blindListenCompleted: false,
      ));
      await _pumpUi(tester, 600);

      // 触发完成
      session.setState(session.state.copyWith(blindListenCompleted: true));
      await _pumpUi(tester, 800);

      // 选择 "Okay"（medium）难度
      await tester.tap(find.text('Okay'));
      await _pumpUi(tester, 600);

      // 点击"返回计划"
      await tester.tap(find.text('Back to Plan'));
      await _pumpUi(tester, 1000);

      // 验证盲听页面已退出（不再显示盲听播放器）
      expect(find.byType(BlindListenPlayerScreen), findsNothing);
    });

    testWidgets('播放中退出弹出确认对话框', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      final container = getContainer(tester);

      // 确保处于正常学习模式（非自由练习）且播放中
      final session =
          container.read(learningSessionProvider.notifier) as TestLearningSession;
      session.setState(const LearningSessionState(
        learningMode: LearningMode.blindListen,
        audioItemId: 'test-audio-1',
        isFreePlay: false,
      ));

      // BlindListenPlayer 进入后自动播放（isPlaying=true）
      final player =
          container.read(blindListenPlayerProvider.notifier) as TestBlindListenPlayer;
      player.setState(player.state.copyWith(isPlaying: true));
      await tester.pumpAndSettle();

      // 点击返回按钮
      final backButton = find.byIcon(Icons.close);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 验证确认对话框弹出
      expect(find.text('Exit Listening?'), findsOneWidget);

      // 点击"Cancel"不退出
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 验证仍在盲听页面
      expect(find.byType(BlindListenPlayerScreen), findsOneWidget);

      // 再次点击返回
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 点击"Exit"确认退出
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      // 验证盲听页面已退出
      expect(find.byType(BlindListenPlayerScreen), findsNothing);
    });
  });
}

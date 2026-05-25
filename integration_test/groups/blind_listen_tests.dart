/// 盲听播放器集成测试
///
/// 验证盲听播放器的 UI 展示、播放控制、倒计时、完成对话框和退出确认。
/// 包含 6 个测试场景。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/main.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/router/app_router.dart';
import 'package:echo_loop/screens/blind_listen_player_screen.dart';
import 'package:echo_loop/widgets/common/countdown_chip.dart';
import 'package:echo_loop/widgets/common/playback_controls.dart';
import 'package:echo_loop/widgets/dialogs/step_complete_dialog.dart';

import '../helpers/test_notifiers.dart';

Future<void> _pumpUi(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump(Duration(milliseconds: milliseconds));
}

/// 盲听播放器集成测试
void blindListenTests() {
  group('流程 5：盲听播放器', () {
    /// 导航到盲听播放器的辅助方法
    Future<void> navigateToBlindListen(WidgetTester tester) async {
      await safeSettle(tester);
      final context = tester.element(find.byType(EchoLoopApp));
      final container = ProviderScope.containerOf(context);
      container.read(appRouterProvider).push(
        '/collections/test-collection-1/test-audio-1/blind-listen',
      );
      await safeSettle(tester);
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
      expect(find.text('Blind Listening'), findsOneWidget);

      // 验证耳机图标（播放中时出现在状态提示区域）
      expect(find.byIcon(Icons.headphones), findsOneWidget);

      // 验证播放按钮区域存在（进入后自动播放，所以显示 pause_rounded）
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // 验证段落底部控制栏和进度条
      expect(find.byType(PlaybackControls), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('播放/暂停切换', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      // 进入后自动播放，显示 pause_rounded 图标
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // 点击暂停（通过 GestureDetector 包裹的圆形按钮）
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await safeSettle(tester);

      // 验证变为 play_arrow_rounded
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      // 再点击恢复播放
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await safeSettle(tester);

      // 验证变回 pause_rounded
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('第一遍完成显示倒计时覆盖层', (tester) async {
      await tester.pumpWidget(createTestAppWithAudio());
      await navigateToBlindListen(tester);

      final container = getContainer(tester);

      // 直接设置 blindListenPlayer 状态为段间停顿倒计时
      // 这模拟段落播放完成后进入倒计时的状态
      final player =
          container.read(blindListenPlayerProvider.notifier) as TestBlindListenPlayer;
      player.setState(player.state.copyWith(
        isPlaying: false,
        isPauseCountdown: true,
        pauseRemaining: const Duration(seconds: 3),
        pauseDuration: const Duration(seconds: 5),
      ));
      await safeSettle(tester);

      // 验证倒计时芯片出现（CountdownChip 在 isPauseCountdown=true 时渲染）
      expect(find.byType(CountdownChip), findsOneWidget);
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
      ));
      await safeSettle(tester);

      // 通过 blindListenPlayer 状态变化触发完成回调：
      // ref.listen 检查：最后一段 + 之前活跃 + 现在空闲
      final player =
          container.read(blindListenPlayerProvider.notifier) as TestBlindListenPlayer;
      // 先设为"正在播放最后一段"
      player.setState(player.state.copyWith(
        isPlaying: true,
        currentParagraphIndex: 0,
        totalParagraphs: 1,
      ));
      await _pumpUi(tester, 100);

      // 再设为"播放结束"（stepFinished=true 表示自然完成）
      player.setState(player.state.copyWith(
        isPlaying: false,
        stepFinished: true,
      ));
      await safeSettle(tester);

      // 验证完成对话框弹出
      expect(find.byType(StepCompleteDialog), findsOneWidget);
      expect(find.text('Blind Listen Complete'), findsOneWidget);
      // 验证难度选择存在
      expect(find.text('How did it feel?'), findsOneWidget);
      // 验证按钮："Done"和"Continue: Intensive Listening"
      expect(find.text('Done'), findsOneWidget);
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
      ));
      await _pumpUi(tester, 100);

      // 通过 blindListenPlayer 状态变化触发完成
      final player =
          container.read(blindListenPlayerProvider.notifier) as TestBlindListenPlayer;
      player.setState(player.state.copyWith(
        isPlaying: true,
        currentParagraphIndex: 0,
        totalParagraphs: 1,
      ));
      await _pumpUi(tester, 100);

      player.setState(player.state.copyWith(
        isPlaying: false,
        stepFinished: true,
      ));
      await _pumpUi(tester, 800);

      // 选择 "Medium" 难度（原 "Okay" 已重命名为 5 档，取中间档）
      await tester.tap(find.text('Medium'));
      await _pumpUi(tester, 600);

      // 点击"Done"返回计划
      await tester.tap(find.text('Done'));
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
      await safeSettle(tester);

      // 点击返回按钮
      final backButton = find.byIcon(Icons.close);
      await tester.tap(backButton);
      await safeSettle(tester);

      // 验证确认对话框弹出
      expect(find.text('Exit Listening?'), findsOneWidget);

      // 点击"Cancel"不退出
      await tester.tap(find.text('Cancel'));
      await safeSettle(tester);

      // 验证仍在盲听页面
      expect(find.byType(BlindListenPlayerScreen), findsOneWidget);

      // 再次点击返回
      await tester.tap(backButton);
      await safeSettle(tester);

      // 点击"Exit"确认退出
      await tester.tap(find.text('Exit'));
      await safeSettle(tester, timeout: const Duration(seconds: 10));

      // 验证盲听页面已退出
      expect(find.byType(BlindListenPlayerScreen), findsNothing);
    });
  });
}

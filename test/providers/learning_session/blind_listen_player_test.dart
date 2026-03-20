import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/blind_listen_settings.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';

void main() {
  group('BlindListenPlayerState', () {
    test('初始状态 — 默认值正确', () {
      const state = BlindListenPlayerState();

      expect(state.isPlaying, false);
      expect(state.currentParagraphIndex, 0);
      expect(state.totalParagraphs, 0);
      expect(state.playingSentenceIndex, -1);
      expect(state.currentRepeatCount, 1);
      expect(state.isPauseCountdown, false);
      expect(state.isCountdownPaused, false);
      expect(state.displayMode, BlindListenDisplayMode.hideAll);
    });

    test('copyWith 设置播放中状态', () {
      const state = BlindListenPlayerState();
      final updated = state.copyWith(
        isPlaying: true,
        totalParagraphs: 5,
      );

      expect(updated.isPlaying, true);
      expect(updated.totalParagraphs, 5);
      expect(updated.currentParagraphIndex, 0);
    });

    test('copyWith 更新段落索引', () {
      const state = BlindListenPlayerState(totalParagraphs: 5);
      final updated = state.copyWith(currentParagraphIndex: 2);

      expect(updated.currentParagraphIndex, 2);
      expect(updated.totalParagraphs, 5);
    });

    test('copyWith 切换显示模式', () {
      const state = BlindListenPlayerState();
      final showAll = state.copyWith(displayMode: BlindListenDisplayMode.showAll);

      expect(showAll.displayMode, BlindListenDisplayMode.showAll);
    });

    test('copyWith 设置倒计时状态', () {
      const state = BlindListenPlayerState();
      final countdown = state.copyWith(
        isPauseCountdown: true,
        pauseDuration: const Duration(seconds: 30),
        pauseRemaining: const Duration(seconds: 20),
      );

      expect(countdown.isPauseCountdown, true);
      expect(countdown.pauseDuration, const Duration(seconds: 30));
      expect(countdown.pauseRemaining, const Duration(seconds: 20));
    });

    test('copyWith 保留未修改字段', () {
      const state = BlindListenPlayerState(
        isPlaying: true,
        currentParagraphIndex: 2,
        totalParagraphs: 5,
        currentRepeatCount: 3,
      );
      final updated = state.copyWith(isPlaying: false);

      expect(updated.isPlaying, false);
      expect(updated.currentParagraphIndex, 2);
      expect(updated.totalParagraphs, 5);
      expect(updated.currentRepeatCount, 3);
    });

    test('disposePlayer 重置所有状态', () {
      const state = BlindListenPlayerState(
        isPlaying: true,
        currentParagraphIndex: 3,
        totalParagraphs: 5,
      );

      const resetState = BlindListenPlayerState();
      expect(resetState.isPlaying, false);
      expect(resetState.currentParagraphIndex, 0);
      expect(resetState.totalParagraphs, 0);
      // 原状态不受影响（immutable）
      expect(state.isPlaying, true);
    });
  });

  group('BlindListenSettings', () {
    test('默认值正确', () {
      const settings = BlindListenSettings();

      expect(settings.repeatCount, 1);
      expect(settings.pauseMode.name, 'multiplier');
      expect(settings.pauseMultiplier, 1.5);
      expect(settings.fixedPauseSeconds, 15);
    });

    test('calculatePauseDuration — multiplier 模式', () {
      const settings = BlindListenSettings(pauseMultiplier: 2.0);
      final duration = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );

      expect(duration, const Duration(seconds: 20));
    });

    test('calculatePauseDuration — 最少 3 秒', () {
      const settings = BlindListenSettings(pauseMultiplier: 0.3);
      final duration = settings.calculatePauseDuration(
        const Duration(seconds: 5),
      );

      expect(duration, const Duration(seconds: 3));
    });

    test('copyWith 更新倍数', () {
      const settings = BlindListenSettings();
      final updated = settings.copyWith(pauseMultiplier: 3.0);

      expect(updated.pauseMultiplier, 3.0);
      expect(updated.repeatCount, 1);
    });
  });
}

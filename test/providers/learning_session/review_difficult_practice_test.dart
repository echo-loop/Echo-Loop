// ReviewDifficultPracticeState 单元测试
//
// 测试状态类的 copyWith 和初始值行为。
// Provider 的播放逻辑依赖 SentencePlaybackEngine，
// 集成测试在 integration_test 中覆盖。
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/difficult_practice_settings.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';

void main() {
  group('ReviewDifficultPracticeState', () {
    test('初始状态 — 默认值正确', () {
      const state = ReviewDifficultPracticeState();

      expect(state.currentSentenceIndex, 0);
      expect(state.totalSentences, 0);
      expect(state.currentPlayCount, 1);
      expect(state.isPlaying, false);
      expect(state.isPauseBetweenPlays, false);
      expect(state.isPauseBetweenSentences, false);
      expect(state.pauseRemaining, Duration.zero);
      expect(state.pauseDuration, Duration.zero);
      expect(state.isAnnotationMode, false);
      expect(state.isTextRevealed, false);
      expect(state.targetRepeatCount, 3);
    });

    test('copyWith — 更新单个字段', () {
      const state = ReviewDifficultPracticeState();
      final updated = state.copyWith(
        currentSentenceIndex: 2,
        totalSentences: 5,
      );

      expect(updated.currentSentenceIndex, 2);
      expect(updated.totalSentences, 5);
      // 未修改字段保持不变
      expect(updated.isPlaying, false);
      expect(updated.isAnnotationMode, false);
    });

    test('copyWith — 进入标注模式', () {
      const state = ReviewDifficultPracticeState(
        totalSentences: 3,
        isPlaying: true,
      );
      final annotation = state.copyWith(
        isAnnotationMode: true,
        isPlaying: false,
        isPauseBetweenPlays: false,
      );

      expect(annotation.isAnnotationMode, true);
      expect(annotation.isPlaying, false);
      expect(annotation.totalSentences, 3);
    });

    test('copyWith — settings (targetRepeatCount via settings)', () {
      const state = ReviewDifficultPracticeState();
      expect(state.targetRepeatCount, 3);

      final updated = state.copyWith(
        settings: const DifficultPracticeSettings(shadowReadingRepeatCount: 5),
      );
      expect(updated.targetRepeatCount, 5);
    });

    test('copyWith — 偷看字幕', () {
      const state = ReviewDifficultPracticeState();
      final peeked = state.copyWith(isTextRevealed: true);

      expect(peeked.isTextRevealed, true);
      // 偷看不影响播放状态
      expect(peeked.isPlaying, false);
      expect(peeked.isAnnotationMode, false);
    });

    test('copyWith — 句间停顿状态', () {
      const state = ReviewDifficultPracticeState(totalSentences: 3);
      final pausing = state.copyWith(
        isPauseBetweenPlays: true,
        isPauseBetweenSentences: true,
        isPlaying: false,
        pauseDuration: const Duration(seconds: 2),
        pauseRemaining: const Duration(seconds: 2),
      );

      expect(pausing.isPauseBetweenPlays, true);
      expect(pausing.isPauseBetweenSentences, true);
      expect(pausing.pauseDuration, const Duration(seconds: 2));
      expect(pausing.pauseRemaining, const Duration(seconds: 2));

      // 模拟停顿 tick
      final ticked = pausing.copyWith(
        pauseRemaining: const Duration(seconds: 1),
      );
      expect(ticked.pauseRemaining, const Duration(seconds: 1));
      expect(ticked.pauseDuration, const Duration(seconds: 2));
    });

    test('copyWith — 切句时重置标注/偷看状态', () {
      const state = ReviewDifficultPracticeState(
        currentSentenceIndex: 1,
        totalSentences: 5,
        isAnnotationMode: true,
        isTextRevealed: true,
      );
      final nextSentence = state.copyWith(
        currentSentenceIndex: 2,
        isAnnotationMode: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        currentPlayCount: 1,
      );

      expect(nextSentence.currentSentenceIndex, 2);
      expect(nextSentence.isAnnotationMode, false);
      expect(nextSentence.isTextRevealed, false);
    });

    test('copyWith — 进入跟读模式的状态转换', () {
      const state = ReviewDifficultPracticeState(
        totalSentences: 5,
        isPlaying: false,
      );

      // 模拟 _startShadowReading 设置的状态
      final shadowReading = state.copyWith(
        isAnnotationMode: true,
        isPlaying: true,
        currentPlayCount: 1,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isTextRevealed: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );

      expect(shadowReading.isAnnotationMode, true);
      expect(shadowReading.isPlaying, true);
      expect(shadowReading.currentPlayCount, 1);
      expect(shadowReading.targetRepeatCount, 3);
    });

    test('copyWith — 跟读循环遍数递增', () {
      const state = ReviewDifficultPracticeState(
        isAnnotationMode: true,
        isPlaying: true,
        currentPlayCount: 1,
      );

      final secondPlay = state.copyWith(currentPlayCount: 2);
      expect(secondPlay.currentPlayCount, 2);
      expect(secondPlay.isAnnotationMode, true);

      final thirdPlay = secondPlay.copyWith(currentPlayCount: 3);
      expect(thirdPlay.currentPlayCount, 3);
    });

    test('copyWith — 跟读完成后状态重置', () {
      const state = ReviewDifficultPracticeState(
        isAnnotationMode: true,
        isPlaying: true,
        currentPlayCount: 3,
      );

      // 模拟 onAllPlaysCompleted 回调
      final completed = state.copyWith(
        isAnnotationMode: false,
        isPlaying: false,
        isPauseBetweenPlays: false,
      );

      expect(completed.isAnnotationMode, false);
      expect(completed.isPlaying, false);
      expect(completed.isPauseBetweenPlays, false);
    });

    test('copyWith — 跟读留白状态', () {
      const state = ReviewDifficultPracticeState(
        isAnnotationMode: true,
        isPlaying: true,
        currentPlayCount: 1,
      );

      // 模拟 onPauseStarted 回调
      final pausing = state.copyWith(
        isPauseBetweenPlays: true,
        isPlaying: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        pauseDuration: const Duration(seconds: 8),
        pauseRemaining: const Duration(seconds: 8),
      );

      expect(pausing.isPauseBetweenPlays, true);
      expect(pausing.isPlaying, false);
      expect(pausing.isAnnotationMode, true);
      expect(pausing.pauseDuration, const Duration(seconds: 8));
    });

    test('copyWith — 倒计时控制字段', () {
      const state = ReviewDifficultPracticeState();

      expect(state.isCountdownPaused, false);
      expect(state.isCountdownFastForward, false);

      final paused = state.copyWith(isCountdownPaused: true);
      expect(paused.isCountdownPaused, true);

      final ff = state.copyWith(isCountdownFastForward: true);
      expect(ff.isCountdownFastForward, true);

      // 同时设置
      final both = state.copyWith(
        isCountdownPaused: true,
        isCountdownFastForward: true,
      );
      expect(both.isCountdownPaused, true);
      expect(both.isCountdownFastForward, true);
    });
  });
}

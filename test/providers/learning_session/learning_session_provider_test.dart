import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/models/playback_settings.dart';

void main() {
  group('LearningSessionState', () {
    test('初始状态 — 非学习模式', () {
      const state = LearningSessionState();

      expect(state.learningMode, isNull);
      expect(state.isInLearningMode, false);
      expect(state.blindListenCompleted, false);
      expect(state.blindListenPassCount, 0);
      expect(state.audioItemId, isNull);
      expect(state.savedSettings, isNull);
    });

    test('copyWith 设置盲听模式', () {
      const state = LearningSessionState();
      final updated = state.copyWith(
        learningMode: LearningMode.blindListen,
        audioItemId: 'audio-1',
        savedSettings: const PlaybackSettings(),
      );

      expect(updated.learningMode, LearningMode.blindListen);
      expect(updated.isInLearningMode, true);
      expect(updated.audioItemId, 'audio-1');
      expect(updated.savedSettings, isNotNull);
    });

    test('copyWith 标记完成 + 增加遍数', () {
      final state = const LearningSessionState().copyWith(
        learningMode: LearningMode.blindListen,
      );
      final completed = state.copyWith(
        blindListenCompleted: true,
        blindListenPassCount: 1,
      );

      expect(completed.blindListenCompleted, true);
      expect(completed.blindListenPassCount, 1);
    });

    test('copyWith clearLearningMode 清除模式', () {
      final state = const LearningSessionState().copyWith(
        learningMode: LearningMode.blindListen,
        audioItemId: 'audio-1',
      );
      final cleared = state.copyWith(clearLearningMode: true);

      expect(cleared.learningMode, isNull);
      expect(cleared.isInLearningMode, false);
      // audioItemId 保留
      expect(cleared.audioItemId, 'audio-1');
    });

    test('copyWith clearSavedSettings 清除保存的设置', () {
      final state = const LearningSessionState().copyWith(
        savedSettings: const PlaybackSettings(playbackSpeed: 1.5),
      );
      final cleared = state.copyWith(clearSavedSettings: true);

      expect(cleared.savedSettings, isNull);
    });

    test('copyWith clearAudioItemId 清除音频ID', () {
      final state = const LearningSessionState().copyWith(
        audioItemId: 'audio-1',
      );
      final cleared = state.copyWith(clearAudioItemId: true);

      expect(cleared.audioItemId, isNull);
    });

    test('isFreePlay 默认为 false', () {
      const state = LearningSessionState();
      expect(state.isFreePlay, false);
    });

    test('copyWith 设置 isFreePlay', () {
      const state = LearningSessionState();
      final updated = state.copyWith(
        learningMode: LearningMode.blindListen,
        isFreePlay: true,
      );

      expect(updated.isFreePlay, true);
      expect(updated.learningMode, LearningMode.blindListen);
    });

    test('copyWith 保持 isFreePlay 不变', () {
      final state = const LearningSessionState().copyWith(isFreePlay: true);
      final updated = state.copyWith(blindListenCompleted: true);

      expect(updated.isFreePlay, true);
    });

    test('targetBlindListenPasses 默认为 1', () {
      const state = LearningSessionState();
      expect(state.targetBlindListenPasses, 1);
    });

    test('copyWith 设置 targetBlindListenPasses', () {
      const state = LearningSessionState();
      final updated = state.copyWith(targetBlindListenPasses: 3);
      expect(updated.targetBlindListenPasses, 3);
    });

    test('hasRemainingPasses — 遍数未达目标时返回 true', () {
      // blindListenPassCount=1, target=2 → 正在听第 1 遍，还没达目标
      final state = const LearningSessionState().copyWith(
        blindListenPassCount: 1,
        targetBlindListenPasses: 2,
      );
      expect(state.hasRemainingPasses, true);
    });

    test('hasRemainingPasses — 遍数达到目标时返回 false', () {
      // blindListenPassCount=2, target=2 → 正在听第 2 遍，达到目标
      final state = const LearningSessionState().copyWith(
        blindListenPassCount: 2,
        targetBlindListenPasses: 2,
      );
      expect(state.hasRemainingPasses, false);
    });

    test('hasRemainingPasses — 遍数超过目标时返回 false', () {
      // blindListenPassCount=3, target=2 → 用户选了"再听一遍"
      final state = const LearningSessionState().copyWith(
        blindListenPassCount: 3,
        targetBlindListenPasses: 2,
      );
      expect(state.hasRemainingPasses, false);
    });

    test('重置为初始状态', () {
      final state = const LearningSessionState().copyWith(
        learningMode: LearningMode.blindListen,
        blindListenCompleted: true,
        blindListenPassCount: 3,
        audioItemId: 'audio-1',
        savedSettings: const PlaybackSettings(),
      );

      // 创建全新的初始状态
      const resetState = LearningSessionState();
      expect(resetState.isInLearningMode, false);
      expect(resetState.blindListenCompleted, false);
      expect(resetState.blindListenPassCount, 0);

      // 原始 state 不变
      expect(state.isInLearningMode, true);
      expect(state.blindListenPassCount, 3);
    });
  });

  group('LearningMode', () {
    test('blindListen、intensiveListen、listenAndRepeat 和 retell 枚举存在', () {
      expect(LearningMode.blindListen, isNotNull);
      expect(LearningMode.intensiveListen, isNotNull);
      expect(LearningMode.listenAndRepeat, isNotNull);
      expect(LearningMode.retell, isNotNull);
      expect(LearningMode.values.length, 4);
    });
  });
}

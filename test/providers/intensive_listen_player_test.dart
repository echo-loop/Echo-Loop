// 精听播放器状态测试
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/intensive_listen_settings.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import '../helpers/mock_providers.dart';

class _ReplayTestAudioEngine extends TestAudioEngine {
  int _sessionId = 0;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex,
  ) async {
    savedIndices.add(sentenceIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.intensiveListen,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      intensiveListenSentenceIndex: sentenceIndex,
      clearIntensiveListenSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('IntensiveListenState', () {
    test('默认初始状态', () {
      const state = IntensiveListenState();

      expect(state.currentSentenceIndex, 0);
      expect(state.totalSentences, 0);
      expect(state.currentPlayCount, 1);
      expect(state.settings.repeatCount, 1);
      expect(state.settings.pauseMode, PauseMode.smart);
      expect(state.settings.pauseMultiplier, 2.0);
      expect(state.isPlaying, false);
      expect(state.isPauseBetweenPlays, false);
      expect(state.isPauseBetweenSentences, false);
      expect(state.pauseRemaining, Duration.zero);
      expect(state.pauseDuration, Duration.zero);
      expect(state.isAnnotationMode, false);
      expect(state.isAnnotationReplay, false);
      expect(state.isTextRevealed, false);
      expect(state.difficultSentences, isEmpty);
      expect(state.isCurrentSentenceAutoMarked, false);
    });

    test('copyWith 更新播放状态', () {
      const state = IntensiveListenState();
      final updated = state.copyWith(
        currentSentenceIndex: 3,
        totalSentences: 10,
        currentPlayCount: 2,
        isPlaying: true,
      );

      expect(updated.currentSentenceIndex, 3);
      expect(updated.totalSentences, 10);
      expect(updated.currentPlayCount, 2);
      expect(updated.isPlaying, true);
      // 未修改的字段保持不变
      expect(updated.settings.repeatCount, 1);
      expect(updated.isAnnotationMode, false);
      expect(updated.isCurrentSentenceAutoMarked, false);
    });

    test('copyWith 更新 settings', () {
      const state = IntensiveListenState();
      final updated = state.copyWith(
        settings: const IntensiveListenSettings(
          repeatCount: 3,
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 10,
        ),
      );

      expect(updated.settings.repeatCount, 3);
      expect(updated.settings.pauseMode, PauseMode.fixed);
      expect(updated.settings.fixedPauseSeconds, 10);
    });

    test('copyWith 进入标注模式', () {
      const state = IntensiveListenState();
      final annotated = state.copyWith(
        isAnnotationMode: true,
        isPlaying: false,
        difficultSentences: {0, 3, 5},
      );

      expect(annotated.isAnnotationMode, true);
      expect(annotated.isPlaying, false);
      expect(annotated.difficultSentences, {0, 3, 5});
    });

    test('copyWith 标注重播模式', () {
      const state = IntensiveListenState();
      final replaying = state.copyWith(
        isAnnotationMode: false,
        isAnnotationReplay: true,
        isPlaying: true,
      );

      expect(replaying.isAnnotationMode, false);
      expect(replaying.isAnnotationReplay, true);
      expect(replaying.isPlaying, true);
    });

    test('copyWith 偷看字幕', () {
      const state = IntensiveListenState();
      final revealed = state.copyWith(isTextRevealed: true);
      expect(revealed.isTextRevealed, true);

      final hidden = revealed.copyWith(isTextRevealed: false);
      expect(hidden.isTextRevealed, false);
    });

    test('copyWith 遍间停顿状态', () {
      const state = IntensiveListenState();
      final paused = state.copyWith(
        isPauseBetweenPlays: true,
        isPlaying: false,
        pauseDuration: const Duration(seconds: 3),
        pauseRemaining: const Duration(seconds: 2),
      );

      expect(paused.isPauseBetweenPlays, true);
      expect(paused.isPlaying, false);
      expect(paused.pauseDuration, const Duration(seconds: 3));
      expect(paused.pauseRemaining, const Duration(seconds: 2));
    });

    test('copyWith 句间停顿状态', () {
      const state = IntensiveListenState();
      final paused = state.copyWith(
        isPauseBetweenPlays: true,
        isPauseBetweenSentences: true,
        isPlaying: false,
        pauseDuration: const Duration(seconds: 3),
        pauseRemaining: const Duration(seconds: 2),
      );

      expect(paused.isPauseBetweenPlays, true);
      expect(paused.isPauseBetweenSentences, true);
      expect(paused.isPlaying, false);
      expect(paused.pauseDuration, const Duration(seconds: 3));
      expect(paused.pauseRemaining, const Duration(seconds: 2));
    });

    test('copyWith 难句集合累积', () {
      const state = IntensiveListenState();
      final s1 = state.copyWith(difficultSentences: {0});
      final s2 = s1.copyWith(difficultSentences: {...s1.difficultSentences, 3});
      final s3 = s2.copyWith(difficultSentences: {...s2.difficultSentences, 7});

      expect(s3.difficultSentences, {0, 3, 7});
    });

    test('copyWith 自定义 settings', () {
      const state = IntensiveListenState();
      final custom = state.copyWith(
        settings: const IntensiveListenSettings(
          repeatCount: 3,
          pauseMultiplier: 1.5,
        ),
      );

      expect(custom.settings.repeatCount, 3);
      expect(custom.settings.pauseMultiplier, 1.5);
    });

    test('copyWith 不传参数时保持原值', () {
      final original = const IntensiveListenState().copyWith(
        currentSentenceIndex: 5,
        totalSentences: 20,
        isPlaying: true,
        isAnnotationMode: true,
        difficultSentences: {1, 2, 3},
        isCurrentSentenceAutoMarked: true,
      );

      final sameState = original.copyWith();

      expect(sameState.currentSentenceIndex, 5);
      expect(sameState.totalSentences, 20);
      expect(sameState.isPlaying, true);
      expect(sameState.isAnnotationMode, true);
      expect(sameState.difficultSentences, {1, 2, 3});
      expect(sameState.isCurrentSentenceAutoMarked, true);
    });

    test('切换到下一句时重置临时状态', () {
      final state = const IntensiveListenState().copyWith(
        currentSentenceIndex: 3,
        totalSentences: 10,
        isAnnotationMode: true,
        isTextRevealed: true,
        isPauseBetweenPlays: true,
        currentPlayCount: 2,
        difficultSentences: {3},
        isCurrentSentenceAutoMarked: true,
      );

      // 模拟切句时的状态更新
      final nextSentence = state.copyWith(
        currentSentenceIndex: 4,
        currentPlayCount: 1,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
        isCurrentSentenceAutoMarked: false,
      );

      expect(nextSentence.currentSentenceIndex, 4);
      expect(nextSentence.currentPlayCount, 1);
      expect(nextSentence.isAnnotationMode, false);
      expect(nextSentence.isTextRevealed, false);
      expect(nextSentence.isPauseBetweenPlays, false);
      expect(nextSentence.isPauseBetweenSentences, false);
      expect(nextSentence.isCurrentSentenceAutoMarked, false);
      // 难句集合保持
      expect(nextSentence.difficultSentences, {3});
    });
  });

  group('initialize 预填历史书签', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [audioEngineProvider.overrideWith(() => TestAudioEngine())],
      );
    });

    tearDown(() => container.dispose());

    test('句子 isBookmarked 为 true 时加入 difficultSentences', () async {
      final sentences = createTestSentences(count: 5);
      // 标记第 1 和第 3 句为书签
      sentences[1].isBookmarked = true;
      sentences[3].isBookmarked = true;

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, {1, 3});
    });

    test('无书签时 difficultSentences 为空', () async {
      final sentences = createTestSentences(count: 3);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, isEmpty);
    });

    test('所有句子都有书签时全部预填', () async {
      final sentences = createTestSentences(count: 3);
      for (final s in sentences) {
        s.isBookmarked = true;
      }

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, {0, 1, 2});
    });
  });

  group('看不懂详情页继续后的当前页重播', () {
    late ProviderContainer container;
    late IntensiveListenPlayer notifier;

    final sentences = [
      Sentence(
        index: 0,
        text: 'First short sentence.',
        startTime: Duration.zero,
        endTime: const Duration(milliseconds: 120),
      ),
      Sentence(
        index: 1,
        text: 'Second short sentence.',
        startTime: const Duration(milliseconds: 200),
        endTime: const Duration(milliseconds: 320),
      ),
    ];

    setUp(() async {
      container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
        ],
      );
      notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(sentences);
    });

    tearDown(() => container.dispose());

    test('点击继续后先重播，再进入句间倒计时，最后推进到下一句', () async {
      notifier.enterAnnotationMode();

      final future = notifier.exitAnnotationMode();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final replaying = container.read(intensiveListenPlayerProvider);
      expect(replaying.isAnnotationReplay, true);
      expect(replaying.isPlaying, true);
      expect(
        replaying.annotationReplayDuration,
        const Duration(milliseconds: 120),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      final pausing = container.read(intensiveListenPlayerProvider);
      expect(pausing.isAnnotationReplay, false);
      expect(pausing.isAnnotationMode, true);
      expect(pausing.isPauseBetweenSentences, true);

      await future;
      final advanced = container.read(intensiveListenPlayerProvider);
      expect(advanced.currentSentenceIndex, 1);
      expect(advanced.isAnnotationReplay, false);
      expect(advanced.isAnnotationMode, false);
      expect(advanced.isPauseBetweenSentences, false);
    });

    test('最后一句点击继续后，重播和倒计时结束后标记完成', () async {
      await notifier.goToNext();
      notifier.enterAnnotationMode();

      await notifier.exitAnnotationMode();

      final completed = container.read(intensiveListenPlayerProvider);
      expect(completed.isAnnotationReplay, false);
      expect(completed.isPauseBetweenSentences, false);
    });
  });

  group('开始播放一句时异步保存断点', () {
    test('startPlaying 会立即写入当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.intensiveListen,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.intensiveListen,
                audioItemId: 'audio-1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(createTestSentences(count: 3), startIndex: 1);
      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(1));
      expect(progressNotifier.savedIndices.first, 1);
      expect(
        container
            .read(learningProgressNotifierProvider)
            .progressMap['audio-1']
            ?.intensiveListenSentenceIndex,
        isNotNull,
      );
    });

    test('freePlay 模式也会写入当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.intensiveListen,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.intensiveListen,
                audioItemId: 'audio-1',
                isFreePlay: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await notifier.initialize(createTestSentences(count: 3), startIndex: 2);
      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(2));
    });
  });

  group('toggleDifficultSentence（通过 TestIntensiveListenPlayer）', () {
    late ProviderContainer container;
    late TestIntensiveListenPlayer notifier;

    setUp(() {
      final sentences = createTestSentences(count: 5);
      container = ProviderContainer(
        overrides: [
          intensiveListenPlayerProvider.overrideWith(
            () => TestIntensiveListenPlayer(
              IntensiveListenState(
                currentSentenceIndex: 2,
                totalSentences: 5,
                isAnnotationMode: false,
                isPlaying: false,
              ),
              sentences,
            ),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
        ],
      );
      notifier =
          container.read(intensiveListenPlayerProvider.notifier)
              as TestIntensiveListenPlayer;
    });

    tearDown(() => container.dispose());

    test('toggle 添加难句标记', () {
      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        isEmpty,
      );

      notifier.toggleDifficultSentence();

      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        contains(2),
      );
    });

    test('toggle 移除已有难句标记', () {
      // 先添加
      notifier.toggleDifficultSentence();
      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        contains(2),
      );

      // 再 toggle → 移除
      notifier.toggleDifficultSentence();
      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        isNot(contains(2)),
      );
    });

    test('toggle 不影响其他句子的标记', () {
      // 通过 enterAnnotationMode 标记当前句子
      notifier.enterAnnotationMode();
      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        contains(2),
      );

      // toggle 移除句子 2 的标记
      notifier.toggleDifficultSentence();

      // 难句集合应为空（enterAnnotationMode 只添加了句子 2）
      expect(
        container.read(intensiveListenPlayerProvider).difficultSentences,
        isEmpty,
      );
    });

    test('enterAnnotationMode 自动标记难句 + toggle 取消', () {
      // enterAnnotationMode 自动添加当前句子为难句
      notifier.enterAnnotationMode();
      final state1 = container.read(intensiveListenPlayerProvider);
      expect(state1.difficultSentences, contains(2));
      expect(state1.isAnnotationMode, true);
      expect(state1.isCurrentSentenceAutoMarked, true);

      // 用户点击取消标记
      notifier.toggleDifficultSentence();
      final state2 = container.read(intensiveListenPlayerProvider);
      expect(state2.difficultSentences, isNot(contains(2)));
      expect(state2.isCurrentSentenceAutoMarked, false);

      // 再次点击可重新标记
      notifier.toggleDifficultSentence();
      final state3 = container.read(intensiveListenPlayerProvider);
      expect(state3.difficultSentences, contains(2));
      expect(state3.isCurrentSentenceAutoMarked, false);
    });

    test('enterAnnotationMode 时句子已是难句 -> 不标记为自动来源', () {
      notifier.toggleDifficultSentence();
      final marked = container.read(intensiveListenPlayerProvider);
      expect(marked.difficultSentences, contains(2));
      expect(marked.isCurrentSentenceAutoMarked, false);

      notifier.enterAnnotationMode();
      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, contains(2));
      expect(state.isCurrentSentenceAutoMarked, false);
    });
  });

  group('calculatePauseDuration', () {
    test('smart 模式：1 倍句子时长', () {
      final result = calculatePauseDuration(
        const Duration(seconds: 3),
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(seconds: 3));
    });

    test('smart 模式：最短 1 秒', () {
      final result = calculatePauseDuration(
        const Duration(milliseconds: 500),
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(milliseconds: 1000));
    });

    test('smart 模式：零时长句子返回 1 秒', () {
      final result = calculatePauseDuration(
        Duration.zero,
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(milliseconds: 1000));
    });

    test('fixed 模式：返回固定秒数', () {
      final result = calculatePauseDuration(
        const Duration(seconds: 3),
        const IntensiveListenSettings(
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 10,
        ),
      );
      expect(result, const Duration(seconds: 10));
    });

    test('fixed 模式：不受句子时长影响', () {
      final result1 = calculatePauseDuration(
        const Duration(seconds: 1),
        const IntensiveListenSettings(
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 5,
        ),
      );
      final result2 = calculatePauseDuration(
        const Duration(seconds: 10),
        const IntensiveListenSettings(
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 5,
        ),
      );
      expect(result1, result2);
      expect(result1, const Duration(seconds: 5));
    });

    test('multiplier 模式：句子时长 × 倍数', () {
      final result = calculatePauseDuration(
        const Duration(seconds: 3),
        const IntensiveListenSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 2.5,
        ),
      );
      expect(result, const Duration(milliseconds: 7500));
    });

    test('multiplier 模式：1.0 倍等于句子时长', () {
      final result = calculatePauseDuration(
        const Duration(seconds: 4),
        const IntensiveListenSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 1.0,
        ),
      );
      expect(result, const Duration(seconds: 4));
    });
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/blind_flow/blind_practice_flow_phase.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_phase.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';

import '../helpers/mock_providers.dart';

class _ReplayTestAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;

  _ReplayTestAudioEngine()
    : super(initialState: const AudioEngineState(sessionId: 0));

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
    _sessionId += 1;
  }
}

class _SlowBlindAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;

  _SlowBlindAudioEngine()
    : super(initialState: const AudioEngineState(sessionId: 0));

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
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveDifficultPracticeSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
    savedIndices.add(sentenceIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.review1,
          currentSubStage: SubStageType.reviewDifficultPractice,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      difficultPracticeSentenceIndex: sentenceIndex,
      clearDifficultPracticeSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession(super.initialState);

  @override
  void addOutputWords(int count) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReviewDifficultPractice 开始播放时保存断点', () {
    test('startPlaying 会异步保存当前句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.review1,
              currentSubStage: SubStageType.reviewDifficultPractice,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
        Sentence(
          index: 1,
          text: 'Second sentence',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 3),
        ),
      ], startIndex: 1);

      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(1));
      expect(progressNotifier.savedIndices.first, 1);
    });

    test('跟读模式 WaitingForUser 态修改设置后保持等待', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ]);

      notifier.enterAnnotationMode();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.repeatEngine?.enterWaitingForUser();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(
        container.read(reviewDifficultPracticeProvider).repeatFlowState?.phase,
        isA<WaitingForUser>(),
      );

      await notifier.updateSettings(
        container
            .read(reviewDifficultPracticeProvider)
            .settings
            .copyWith(shadowReadingRepeatCount: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.repeatFlowState?.phase, isA<WaitingForUser>());
      expect(state.isPlaying, isFalse);
    });

    test('盲听模式进入 WaitingForUser 后修改设置保持等待', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ]);

      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      notifier.enterWaitingForUserInBlindMode();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(
        container.read(reviewDifficultPracticeProvider).blindFlowState?.phase,
        isA<BlindWaitingForUser>(),
      );

      await notifier.updateSettings(
        container
            .read(reviewDifficultPracticeProvider)
            .settings
            .copyWith(blindListenRepeatCount: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.blindFlowState?.phase, isA<BlindWaitingForUser>());
      expect(state.isPlaying, isFalse);
    });

    test('盲听播放中进入 WaitingForUser 时，允许当前句自然播完', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _SlowBlindAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ]);

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.enterWaitingForUserInBlindMode();

      final duringPlayback = container.read(reviewDifficultPracticeProvider);
      expect(duringPlayback.isPlaying, isTrue);
      expect(duringPlayback.blindFlowState?.phase, isA<BlindPlayingPrompt>());

      await Future<void>.delayed(const Duration(milliseconds: 120));

      final afterPrompt = container.read(reviewDifficultPracticeProvider);
      expect(afterPrompt.blindFlowState?.phase, isA<BlindWaitingForUser>());
      expect(afterPrompt.isPlaying, isFalse);
      expect(afterPrompt.isPauseBetweenPlays, isFalse);
    });

    test('dispose 后重新 initialize，盲听仍可再次播放', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _SlowBlindAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      final sentences = [
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ];

      notifier.initialize(sentences);
      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(reviewDifficultPracticeProvider).blindFlowState?.phase,
        isA<BlindPlayingPrompt>(),
      );

      notifier.disposePlayer();

      notifier.initialize(sentences);
      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.totalSentences, 1);
      expect(state.blindFlowState?.phase, isA<BlindPlayingPrompt>());
      expect(state.isPlaying, isTrue);
    });

    test('跟读完成后直接进入下一句，不回到当前句倒计时', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.review1,
              currentSubStage: SubStageType.reviewDifficultPractice,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
        Sentence(
          index: 1,
          text: 'Second sentence',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 3),
        ),
      ]);

      await notifier.updateSettings(
        container
            .read(reviewDifficultPracticeProvider)
            .settings
            .copyWith(blindListenRepeatCount: 1, shadowReadingRepeatCount: 1),
      );
      notifier.enterAnnotationMode();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      notifier.repeatEngine?.onRecordingFinished('recording.m4a', 92);
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.currentSentenceIndex, 1);
      expect(state.isAnnotationMode, isFalse);
      expect(state.stepFinished, isFalse);
    });

    test('跟读播放中修改设置不打断也不重播，播完后进入等待', () async {
      final audioEngine = _SlowBlindAudioEngine();
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => audioEngine),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize([
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ]);

      notifier.enterAnnotationMode();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.repeatEngine?.onUserInteraction();
      await notifier.updateSettings(
        container
            .read(reviewDifficultPracticeProvider)
            .settings
            .copyWith(
              shadowReadingRepeatCount: 5,
              controlMode: ShadowingControlMode.manual,
            ),
      );

      expect(
        container.read(reviewDifficultPracticeProvider).repeatFlowState?.phase,
        isA<PlayingPrompt>(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.repeatFlowState?.phase, isA<WaitingForUser>());
      expect(state.currentPlayCount, 1);
    });
  });

  group('goToSentence 任意跳转（进度条拖动）', () {
    List<Sentence> buildSentences(int count) => List.generate(
      count,
      (i) => Sentence(
        index: i,
        text: 'Sentence $i',
        startTime: Duration(seconds: i * 2),
        endTime: Duration(seconds: i * 2 + 1),
      ),
    );

    ProviderContainer buildContainer() => ProviderContainer(
      overrides: [
        foregroundAudioEngineProvider.overrideWith(
          () => _ReplayTestAudioEngine(),
        ),
        learningProgressNotifierProvider.overrideWith(
          () => _RecordingLearningProgressNotifier(
            const LearningProgressState(progressMap: {}),
          ),
        ),
        learningSessionProvider.overrideWith(
          () => _PassiveLearningSession(
            const LearningSessionState(
              learningMode: LearningMode.reviewDifficultPractice,
              audioItemId: 'audio-1',
            ),
          ),
        ),
        analyticsOverride(),
        ...studyTimeOverrides(),
      ],
    );

    test('跳转到合法句子更新 currentSentenceIndex', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize(buildSentences(8));

      await notifier.goToSentence(5);

      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        5,
      );
    });

    test('越界索引被 clamp 到合法范围', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize(buildSentences(5));

      await notifier.goToSentence(99);
      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        4,
      );

      await notifier.goToSentence(-3);
      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        0,
      );
    });

    test('跳到当前句保持不变（no-op）', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      notifier.initialize(buildSentences(5));
      await notifier.goToSentence(2);

      await notifier.goToSentence(2);

      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        2,
      );
    });
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/difficult_practice_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/blind_flow/blind_practice_flow_phase.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_playback_driver.dart';
import 'package:echo_loop/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_phase.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';

import '../helpers/mock_providers.dart';

void _listenToReviewDifficultPractice(ProviderContainer container) {
  container.listen<ReviewDifficultPracticeState>(
    reviewDifficultPracticeProvider,
    (_, __) {},
    fireImmediately: true,
  );
}

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
}

class _RecordingPlaybackDriver implements SentencePlaybackDriver {
  _RecordingPlaybackDriver({this.playbackDelay = Duration.zero});

  final Duration playbackDelay;
  int _sessionId = 0;
  int pauseCalls = 0;
  SentencePlaybackResult playResult = SentencePlaybackResult.completed;
  final List<double> speeds = [];
  final List<Sentence> playedSentences = [];
  final List<bool> activeStates = [];
  final List<bool> frozenStates = [];
  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Future<void> invalidateSession() async {
    _sessionId += 1;
    pauseCalls += 1;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int sessionId,
  ) async {
    if (playbackDelay > Duration.zero) {
      await Future<void>.delayed(playbackDelay);
    }
    if (isActiveSession(sessionId)) playedSentences.add(sentence);
    return isActiveSession(sessionId)
        ? playResult
        : SentencePlaybackResult.cancelled;
  }

  @override
  Future<SentencePlaybackResult> playSentenceWithSpeed(
    Sentence sentence,
    double speed,
  ) async {
    await setSpeed(speed);
    return playSentence(sentence, newSession());
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    this.onPlay = onPlay;
    this.onPause = onPause;
    this.onNext = onNext;
    this.onPrevious = onPrevious;
  }

  @override
  void setProgressFrozen(bool frozen) => frozenStates.add(frozen);

  @override
  void setSessionActive(bool active) => activeStates.add(active);

  @override
  void unbindLockScreen() {
    onPlay = null;
    onPause = null;
    onNext = null;
    onPrevious = null;
  }
}

class _GatedInvalidationPlaybackDriver extends _RecordingPlaybackDriver {
  final invalidationStarted = Completer<void>();
  final finishInvalidation = Completer<void>();

  @override
  Future<void> invalidateSession() async {
    await super.invalidateSession();
    if (!invalidationStarted.isCompleted) invalidationStarted.complete();
    await finishInvalidation.future;
  }
}

class _ControlledPlaybackDriver implements SentencePlaybackDriver {
  int _sessionId = 0;
  final List<Sentence> playedSentences = [];
  final List<Completer<SentencePlaybackResult>> _results = [];
  final StreamController<int> _playCountController =
      StreamController<int>.broadcast();

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Future<void> invalidateSession() async {
    _sessionId += 1;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int sessionId,
  ) {
    playedSentences.add(sentence);
    final result = Completer<SentencePlaybackResult>();
    _results.add(result);
    _playCountController.add(_results.length);
    return result.future;
  }

  @override
  Future<SentencePlaybackResult> playSentenceWithSpeed(
    Sentence sentence,
    double speed,
  ) => playSentence(sentence, newSession());

  Future<void> waitForPlayCount(int count) async {
    if (_results.length >= count) return;
    await _playCountController.stream.firstWhere((value) => value >= count);
  }

  void complete(int index, SentencePlaybackResult result) {
    _results[index].complete(result);
  }

  void dispose() => _playCountController.close();

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void unbindLockScreen() {}
}

class _RecordingStudyTimeService extends FakeStudyTimeService {
  final List<({Duration duration, String text, StudyStage stage})>
  sentencePlaybacks = [];
  final List<({Duration duration, StudyStage stage})> speechRecognitions = [];
  final List<
    ({Duration studyDuration, Duration inputDuration, StudyStage stage})
  >
  sessionDurations = [];
  int flushCalls = 0;

  @override
  void submitSentencePlayback({
    required Duration duration,
    required String text,
    required StudyStage stage,
    bool recordInputDuration = true,
    DateTime? date,
  }) {
    sentencePlaybacks.add((duration: duration, text: text, stage: stage));
  }

  @override
  void submitSpeechRecognition({
    required Duration duration,
    int producedWordCount = 0,
    required StudyStage stage,
    DateTime? date,
  }) {
    speechRecognitions.add((duration: duration, stage: stage));
  }

  @override
  Future<void> recordSessionDurations({
    required Duration studyDuration,
    Duration inputDuration = Duration.zero,
    required StudyStage stage,
    DateTime? date,
  }) async {
    sessionDurations.add((
      studyDuration: studyDuration,
      inputDuration: inputDuration,
      stage: stage,
    ));
  }

  @override
  Future<void> flush() async {
    flushCalls += 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReviewDifficultPractice 新学习统计', () {
    test('完整播放写入输入统计，退出刷写页面学习时长', () async {
      final playback = _RecordingPlaybackDriver();
      final statistics = _RecordingStudyTimeService();
      final speechController = TestSpeechRecordingController();
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-stats',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(
            studyTimeService: statistics,
            speechControllerFactory: () => speechController,
          ),
        ],
      );
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'A complete sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ],
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      await notifier.startPlaying();
      await notifier.disposePlayer();

      expect(statistics.sentencePlaybacks, hasLength(1));
      expect(statistics.sentencePlaybacks.single.text, 'A complete sentence');
      expect(
        statistics.sentencePlaybacks.single.stage,
        StudyStage.reviewDifficultPractice,
      );
      expect(statistics.sessionDurations, isNotEmpty);
      expect(
        statistics.sessionDurations.single.stage,
        StudyStage.reviewDifficultPractice,
      );
      expect(statistics.flushCalls, greaterThan(0));
    });

    test('取消播放和退出后的迟到回调不会写入统计', () async {
      final playback = _ControlledPlaybackDriver();
      final statistics = _RecordingStudyTimeService();
      final speechController = TestSpeechRecordingController();
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _ReplayTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.reviewDifficultPractice,
                audioItemId: 'audio-stats',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            () => _RecordingLearningProgressNotifier(
              const LearningProgressState(),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(
            studyTimeService: statistics,
            speechControllerFactory: () => speechController,
          ),
        ],
      );
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'Cancelled sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ],
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      final playing = notifier.startPlaying();
      await playback.waitForPlayCount(1);
      notifier.pause();
      playback.complete(0, SentencePlaybackResult.cancelled);
      await playing;
      expect(statistics.sentencePlaybacks, isEmpty);

      speechController.emitRecordingCompleted(const Duration(seconds: 2));
      expect(statistics.speechRecognitions, hasLength(1));

      await notifier.disposePlayer();
      speechController.emitRecordingCompleted(const Duration(seconds: 3));
      expect(statistics.speechRecognitions, hasLength(1));
    });
  });

  group('ReviewDifficultPractice 开始播放时保存断点', () {
    test('盲听手动模式播放完当前句后等待用户，不自动推进', () async {
      final playback = _ControlledPlaybackDriver();
      addTearDown(playback.dispose);
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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
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
        ],
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      final playing = notifier.startPlaying();
      await playback.waitForPlayCount(1);
      playback.complete(0, SentencePlaybackResult.completed);
      await playing;

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.currentSentenceIndex, 0);
      expect(state.blindFlowState?.phase, isA<BlindWaitingForUser>());
      expect(playback.playedSentences.map((sentence) => sentence.index), [0]);
    });

    test('媒体会话复用注入驱动播放原句且发布媒体标记', () async {
      final playback = _RecordingPlaybackDriver();
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
                audioItemId: 'video-1',
                playbackChain: LearningPlaybackChain.mediaEngine,
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'Video sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ],
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
          playbackSpeed: 1.25,
        ),
        playbackDriver: playback,
        hasVideo: true,
      );

      await notifier.startPlaying();

      expect(container.read(reviewDifficultPracticeProvider).hasVideo, isTrue);
      expect(playback.playedSentences.single.text, 'Video sentence');
      expect(playback.speeds, contains(1.25));
    });

    test('媒体练习绑定系统控制并随流程更新后台播放状态', () async {
      final playback = _RecordingPlaybackDriver(
        playbackDelay: const Duration(milliseconds: 1),
      );
      final container = ProviderContainer(
        overrides: [
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
                playbackChain: LearningPlaybackChain.mediaEngine,
              ),
            ),
          ),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
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
        ],
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      final onPlay = playback.onPlay;
      final onPause = playback.onPause;
      final onNext = playback.onNext;
      expect(onPlay, isNotNull);
      expect(onPause, isNotNull);
      expect(onNext, isNotNull);
      if (onPlay == null || onPause == null || onNext == null) return;

      await onPlay();
      expect(playback.activeStates, contains(true));
      expect(playback.activeStates.last, isFalse);

      await onNext();
      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        1,
      );
      await onPause();
      expect(
        container.read(reviewDifficultPracticeProvider).blindFlowState?.phase,
        isA<BlindWaitingForUser>(),
      );
      expect(playback.activeStates.last, isFalse);
    });

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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize([
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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize([
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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize([
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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'First sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ],
        playbackDriver: _RecordingPlaybackDriver(
          playbackDelay: const Duration(milliseconds: 80),
        ),
      );

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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      final sentences = [
        Sentence(
          index: 0,
          text: 'First sentence',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ];

      final playback = _RecordingPlaybackDriver(
        playbackDelay: const Duration(milliseconds: 80),
      );
      await notifier.initialize(sentences, playbackDriver: playback);
      unawaited(notifier.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(reviewDifficultPracticeProvider).blindFlowState?.phase,
        isA<BlindPlayingPrompt>(),
      );

      await notifier.disposePlayer();

      await notifier.initialize(sentences, playbackDriver: playback);
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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize([
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
      ], playbackDriver: _RecordingPlaybackDriver());

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
      _listenToReviewDifficultPractice(container);

      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        [
          Sentence(
            index: 0,
            text: 'First sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 1),
          ),
        ],
        playbackDriver: _RecordingPlaybackDriver(
          playbackDelay: const Duration(milliseconds: 80),
        ),
      );

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
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(buildSentences(8));

      await notifier.goToSentence(5);

      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        5,
      );
    });

    test('越界索引被 clamp 到合法范围', () async {
      final container = buildContainer();
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(buildSentences(5));

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
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(buildSentences(5));
      await notifier.goToSentence(2);

      await notifier.goToSentence(2);

      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        2,
      );
    });

    test('当前音频播放被取消时停留在目标句，不自动跳过', () async {
      final playback = _RecordingPlaybackDriver()
        ..playResult = SentencePlaybackResult.cancelled;
      final container = buildContainer();
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        buildSentences(2),
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      await notifier.startPlaying();

      final state = container.read(reviewDifficultPracticeProvider);
      expect(state.currentSentenceIndex, 0);
      expect(state.blindFlowState?.phase, isA<BlindWaitingForUser>());
      expect(playback.playedSentences.map((sentence) => sentence.index), [0]);
    });

    test('跳转等待旧音频失效完成后才播放目标句', () async {
      final playback = _GatedInvalidationPlaybackDriver();
      final container = buildContainer();
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        buildSentences(2),
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      final navigation = notifier.goToSentence(1);
      await playback.invalidationStarted.future;
      try {
        expect(playback.playedSentences, isEmpty);
      } finally {
        playback.finishInvalidation.complete();
      }
      await navigation;

      expect(playback.playedSentences.map((sentence) => sentence.index), [1]);
      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        1,
      );
    });

    test('定位时旧播放取消不会跳过目标句', () async {
      final playback = _ControlledPlaybackDriver();
      addTearDown(playback.dispose);
      final container = buildContainer();
      addTearDown(container.dispose);
      _listenToReviewDifficultPractice(container);
      final notifier = container.read(reviewDifficultPracticeProvider.notifier);
      await notifier.initialize(
        buildSentences(3),
        settings: const DifficultPracticeSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: playback,
      );

      final firstPlayback = notifier.startPlaying();
      await playback.waitForPlayCount(1);

      final locate = notifier.goToSentence(1);
      await playback.waitForPlayCount(2);
      playback.complete(0, SentencePlaybackResult.cancelled);
      await firstPlayback;

      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        1,
      );
      expect(playback.playedSentences.map((s) => s.index), [0, 1]);

      playback.complete(1, SentencePlaybackResult.completed);
      await locate;
    });
  });
}

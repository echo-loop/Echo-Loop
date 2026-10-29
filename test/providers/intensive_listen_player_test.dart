// 精听播放器状态测试
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/intensive_annotation/intensive_annotation_phase.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/intensive_listen_playback_driver.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_settings_provider.dart';
import '../helpers/mock_providers.dart';

class _ReplayTestAudioEngine extends TestAudioEngine {
  int _playbackSessionId = 0;
  final List<int> playedSentenceIndices = [];
  final List<Duration> playedStartPositions = [];

  @override
  int newSession() {
    _playbackSessionId += 1;
    return _playbackSessionId;
  }

  @override
  bool isActiveSession(int playbackSessionId) =>
      playbackSessionId == _playbackSessionId;

  @override
  Future<void> playClipOnce(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) async {
    if (!isActiveSession(playbackSessionId)) return;
    playedSentenceIndices.add(sentence.index);
    playedStartPositions.add(startAt ?? sentence.startTime);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _PositionedReplayTestAudioEngine extends _ReplayTestAudioEngine {
  Duration position = Duration.zero;

  @override
  Duration get currentPosition => position;
}

class _OverlappingReplayAudioEngine extends TestAudioEngine {
  int _playbackSessionId = 0;
  final Map<int, Completer<void>> _playbackCompletions = {};

  @override
  int newSession() => ++_playbackSessionId;

  @override
  bool isActiveSession(int playbackSessionId) =>
      playbackSessionId == _playbackSessionId;

  @override
  Future<void> playClipOnce(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) {
    final completion = Completer<void>();
    _playbackCompletions[playbackSessionId] = completion;
    return completion.future;
  }

  void completePlayback(int playbackSessionId) {
    final completion = _playbackCompletions[playbackSessionId];
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }
}

class _DeferredBlindAudioEngine extends TestAudioEngine {
  int _playbackSessionId = 0;
  final Map<int, Completer<void>> _sentenceCompletions = {};
  final List<int> playedSentenceIndices = [];

  @override
  int newSession() {
    _playbackSessionId += 1;
    return _playbackSessionId;
  }

  @override
  bool isActiveSession(int playbackSessionId) =>
      playbackSessionId == _playbackSessionId;

  @override
  Future<void> playClipOnce(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) {
    playedSentenceIndices.add(sentence.index);
    final completer = Completer<void>();
    _sentenceCompletions[sentence.index] = completer;
    return completer.future;
  }

  void completeSentence(int index) {
    final completer = _sentenceCompletions[index];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

/// 精听状态机测试使用可控的 just_audio 播放替身。
class _TestAudioIntensiveListenPlaybackDriver
    implements IntensiveListenPlaybackDriver {
  _TestAudioIntensiveListenPlaybackDriver(this._audioEngine);

  final AudioEngine _audioEngine;

  @override
  Duration get currentPosition => _audioEngine.currentPosition;

  @override
  int newSession() => _audioEngine.newSession();

  @override
  bool isActiveSession(int playbackSessionId) =>
      _audioEngine.isActiveSession(playbackSessionId);

  @override
  Future<void> invalidateSession() async {
    _audioEngine.newSession();
    await _audioEngine.pause();
  }

  @override
  Future<void> pause() => _audioEngine.pause();

  @override
  Future<void> setSpeed(double speed) => _audioEngine.setSpeed(speed);

  @override
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) async {
    if (_audioEngine case _ReplayTestAudioEngine recordingEngine) {
      recordingEngine.playedStartPositions.add(startAt ?? sentence.startTime);
    }
    await _audioEngine.playClipOnce(sentence, playbackSessionId);
    return _audioEngine.isActiveSession(playbackSessionId)
        ? SentencePlaybackResult.completed
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
  Future<SentencePlaybackResult> playRangeOnce(
    Duration start,
    Duration end,
    int playbackSessionId,
  ) async {
    await _audioEngine.playRangeOnce(start, end, playbackSessionId);
    return _audioEngine.isActiveSession(playbackSessionId)
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.cancelled;
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    _audioEngine.setTransportHandlers(onPlay: onPlay, onPause: onPause);
    _audioEngine.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
    _audioEngine.setSeekHandlers(onRewind: null, onFastForward: null);
  }

  @override
  void setSessionActive(bool active) {
    _audioEngine.setLogicalPlaying(active);
    if (active) {
      _audioEngine.startKeepAlive();
    } else {
      _audioEngine.stopKeepAlive();
    }
  }

  @override
  void setProgressFrozen(bool frozen) => _audioEngine.setProgressFrozen(frozen);

  @override
  void unbindLockScreen() {
    _audioEngine.setTransportHandlers(onPlay: null, onPause: null);
    _audioEngine.setSkipHandlers(onPrevious: null, onNext: null);
    _audioEngine.setSeekHandlers(onRewind: null, onFastForward: null);
    _audioEngine.setLogicalPlaying(null);
    _audioEngine.setProgressFrozen(false);
    _audioEngine.stopKeepAlive();
  }
}

/// 精听状态机测试显式注入可控播放替身，不走生产默认 MediaEngine 驱动。
Future<void> _initializeWithTestAudio(
  ProviderContainer container,
  IntensiveListenPlayer notifier,
  List<Sentence> sentences, {
  int startIndex = 0,
  IntensiveListenSettings settings = const IntensiveListenSettings(),
  String? settingsSlot,
}) => notifier.initialize(
  sentences,
  startIndex: startIndex,
  settings: settings,
  settingsSlot: settingsSlot,
  playbackDriver: _TestAudioIntensiveListenPlaybackDriver(
    container.read(audioEngineProvider.notifier),
  ),
);

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveIntensiveListenSentenceIndex(
    String audioItemId,
    int? sentenceIndex, {
    required bool isFreePlay,
  }) async {
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

/// 记录逐句精听统计调用的测试服务，避免测试依赖真实数据库。
class _RecordingStudyTimeService extends FakeStudyTimeService {
  final List<_SentencePlaybackRecord> sentencePlaybacks = [];
  final List<_SessionDurationRecord> sessionDurations = [];

  @override
  void submitSentencePlayback({
    required Duration duration,
    required String text,
    required StudyStage stage,
    bool recordInputDuration = true,
    DateTime? date,
  }) {
    sentencePlaybacks.add(
      _SentencePlaybackRecord(
        duration: duration,
        text: text,
        stage: stage,
        recordInputDuration: recordInputDuration,
      ),
    );
  }

  @override
  Future<void> recordSessionDurations({
    required Duration studyDuration,
    Duration inputDuration = Duration.zero,
    required StudyStage stage,
    DateTime? date,
  }) async {
    sessionDurations.add(
      _SessionDurationRecord(
        studyDuration: studyDuration,
        inputDuration: inputDuration,
        stage: stage,
      ),
    );
  }
}

class _SentencePlaybackRecord {
  const _SentencePlaybackRecord({
    required this.duration,
    required this.text,
    required this.stage,
    required this.recordInputDuration,
  });

  final Duration duration;
  final String text;
  final StudyStage stage;
  final bool recordInputDuration;
}

class _SessionDurationRecord {
  const _SessionDurationRecord({
    required this.studyDuration,
    required this.inputDuration,
    required this.stage,
  });

  final Duration studyDuration;
  final Duration inputDuration;
  final StudyStage stage;
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
      expect(state.stepFinished, false);
    });

    test('stepFinished — copyWith 设置和保留', () {
      const state = IntensiveListenState();
      final finished = state.copyWith(stepFinished: true);
      expect(finished.stepFinished, true);

      // copyWith 不传值时保留原值
      final updated = finished.copyWith(isPlaying: true);
      expect(updated.stepFinished, true);

      // 重置
      final reset = finished.copyWith(stepFinished: false);
      expect(reset.stepFinished, false);
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

  group('逐句精听新学习统计', () {
    late ProviderContainer container;
    late _RecordingStudyTimeService studyTimeService;

    ProviderContainer createContainer({
      TestAudioEngine? audioEngine,
      LearningSettings? learningSettings,
    }) {
      studyTimeService = _RecordingStudyTimeService();
      return ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(
            () => audioEngine ?? TestAudioEngine(),
          ),
          initialLearningSettingsProvider.overrideWithValue(
            learningSettings ?? const LearningSettings(),
          ),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
          studyTimeServiceProvider.overrideWithValue(studyTimeService),
        ],
      );
    }

    tearDown(() => container.dispose());

    test('完整句播放写入逐句精听输入统计', () async {
      container = createContainer();
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      final sentence = Sentence(
        index: 0,
        text: 'The quick brown fox.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 2),
      );

      await _initializeWithTestAudio(container, notifier, [sentence]);
      await notifier.startPlaying();

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      final record = studyTimeService.sentencePlaybacks.single;
      expect(record.duration, const Duration(seconds: 2));
      expect(record.text, sentence.text);
      expect(record.stage, StudyStage.intensiveListen);
      expect(record.recordInputDuration, isTrue);
    });

    test('取消播放不写入输入统计', () async {
      final audioEngine = _DeferredBlindAudioEngine();
      container = createContainer(audioEngine: audioEngine);
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(Duration.zero);
      await notifier.pause();

      expect(studyTimeService.sentencePlaybacks, isEmpty);
      await notifier.disposePlayer();
    });

    test('听不懂自动收藏开启时，进入讲解页把当前句加入难句并标记为自动收藏', () async {
      container = createContainer(
        learningSettings: const LearningSettings(
          autoFavoriteOnCantUnderstand: true,
        ),
      );
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      notifier.enterAnnotationMode();

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, {0});
      expect(state.isCurrentSentenceAutoMarked, isTrue);
    });

    test('听不懂自动收藏关闭时，进入讲解页不收藏当前句', () async {
      container = createContainer(
        learningSettings: const LearningSettings(
          autoFavoriteOnCantUnderstand: false,
        ),
      );
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      notifier.enterAnnotationMode();

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.annotationState, isNotNull);
      expect(state.difficultSentences, isEmpty);
      expect(state.isCurrentSentenceAutoMarked, isFalse);
    });

    test('进入讲解页后不沿用盲听暂停位置，播放按钮可开始讲解重播', () async {
      final audioEngine = _PositionedReplayTestAudioEngine();
      container = createContainer(audioEngine: audioEngine);
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      final playback = notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(intensiveListenPlayerProvider).isPlaying, isTrue);
      audioEngine.position = const Duration(milliseconds: 500);
      await notifier.pause();
      await playback;
      expect(notifier.hasPausedPlaybackPosition, isTrue);

      notifier.enterAnnotationMode();

      expect(notifier.hasPausedPlaybackPosition, isFalse);
      await notifier.replayInAnnotationMode();

      expect(audioEngine.playedSentenceIndices, [0, 0]);
      expect(
        container.read(intensiveListenPlayerProvider).annotationState?.phase,
        isA<InspectingAnnotation>(),
      );
    });

    test('讲解页整句重播暂停后，从保存的精确位置继续', () async {
      final audioEngine = _PositionedReplayTestAudioEngine();
      container = createContainer(audioEngine: audioEngine);
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      final sentence = createTestSentences(count: 1).single;
      await _initializeWithTestAudio(container, notifier, [sentence]);
      notifier.enterAnnotationMode();

      final firstReplay = notifier.replayInAnnotationMode();
      await Future<void>.delayed(Duration.zero);
      audioEngine.position = const Duration(milliseconds: 500);
      await notifier.pause();
      await firstReplay;

      audioEngine.playedStartPositions.clear();
      await notifier.resume();

      expect(
        audioEngine.playedStartPositions.first,
        const Duration(milliseconds: 500),
      );
    });

    test('讲解页句子自然播放完后再次播放仍从句首开始', () async {
      final audioEngine = _PositionedReplayTestAudioEngine();
      container = createContainer(audioEngine: audioEngine);
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      final sentence = createTestSentences(count: 1).single;
      await _initializeWithTestAudio(container, notifier, [sentence]);
      notifier.enterAnnotationMode();

      await notifier.replayInAnnotationMode();
      audioEngine.playedStartPositions.clear();
      await notifier.replayInAnnotationMode();

      expect(audioEngine.playedStartPositions.first, sentence.startTime);
    });

    test('重置到第一句时清除先前的盲听暂停位置', () async {
      final audioEngine = _PositionedReplayTestAudioEngine();
      container = createContainer(audioEngine: audioEngine);
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      final playback = notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);
      audioEngine.position = const Duration(milliseconds: 500);
      await notifier.pause();
      await playback;
      expect(notifier.hasPausedPlaybackPosition, isTrue);

      await notifier.resetToStart();

      expect(notifier.hasPausedPlaybackPosition, isFalse);
    });

    test('讲解页完整重播写入输入统计', () async {
      container = createContainer();
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 1),
      );

      notifier.enterAnnotationMode();
      await notifier.replayInAnnotationMode();

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      expect(
        studyTimeService.sentencePlaybacks.single.stage,
        StudyStage.intensiveListen,
      );
    });

    test('页面退出刷写逐句精听总学习时长且不写入输入时长', () async {
      var now = DateTime(2026, 9, 11, 12);
      await withClock(Clock(() => now), () async {
        container = createContainer();
        final notifier = container.read(intensiveListenPlayerProvider.notifier);
        await _initializeWithTestAudio(
          container,
          notifier,
          createTestSentences(count: 1),
        );
        now = now.add(const Duration(seconds: 3));

        await notifier.disposePlayer();

        expect(studyTimeService.sessionDurations, hasLength(1));
        final record = studyTimeService.sessionDurations.single;
        expect(record.studyDuration, const Duration(seconds: 3));
        expect(record.inputDuration, Duration.zero);
        expect(record.stage, StudyStage.intensiveListen);
      });
    });
  });

  group('goToSentence 任意跳转（进度条拖动）', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('跳转到合法句子更新 currentSentenceIndex', () async {
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 10),
      );

      await notifier.goToSentence(6);

      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        6,
      );
    });

    test('越界索引被 clamp 到合法范围', () async {
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 5),
      );

      await notifier.goToSentence(99);
      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        4,
      );

      await notifier.goToSentence(-3);
      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        0,
      );
    });

    test('跳到当前句不变化（no-op）', () async {
      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 5),
      );
      await notifier.goToSentence(2);

      // 制造一个可观察的临时状态，再跳到同一句应保持不变
      await notifier.goToSentence(2);

      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        2,
      );
    });
  });

  group('initialize 预填历史书签', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('句子 isBookmarked 为 true 时加入 difficultSentences', () async {
      final sentences = createTestSentences(count: 5);
      // 标记第 1 和第 3 句为书签
      sentences[1].isBookmarked = true;
      sentences[3].isBookmarked = true;

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(container, notifier, sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, {1, 3});
    });

    test('无书签时 difficultSentences 为空', () async {
      final sentences = createTestSentences(count: 3);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(container, notifier, sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, isEmpty);
    });

    test('所有句子都有书签时全部预填', () async {
      final sentences = createTestSentences(count: 3);
      for (final s in sentences) {
        s.isBookmarked = true;
      }

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(container, notifier, sentences);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.difficultSentences, {0, 1, 2});
    });
  });

  group('快速切句时旧盲听回调不会污染新句状态', () {
    test('上一句播放完成回调不会让新句一开始就进入倒计时', () async {
      final audioEngine = _DeferredBlindAudioEngine();
      final container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
      );

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(Duration.zero);

      unawaited(notifier.goToNext());
      await Future<void>.delayed(Duration.zero);

      audioEngine.completeSentence(0);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final stateAfterOldCallback = container.read(
        intensiveListenPlayerProvider,
      );
      expect(stateAfterOldCallback.currentSentenceIndex, 1);
      expect(stateAfterOldCallback.isPlaying, true);
      expect(stateAfterOldCallback.isPauseBetweenPlays, false);
      expect(stateAfterOldCallback.isPauseBetweenSentences, false);

      audioEngine.completeSentence(1);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final stateAfterCurrentCallback = container.read(
        intensiveListenPlayerProvider,
      );
      expect(stateAfterCurrentCallback.currentSentenceIndex, 1);
      expect(stateAfterCurrentCallback.isPauseBetweenSentences, true);
    });
  });

  group('句间停顿期上一句切到上一句', () {
    test('第一句停顿期 goToPrevious 保持在第一句', () async {
      final audioEngine = _DeferredBlindAudioEngine();
      final container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
      );

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(Duration.zero);
      expect(audioEngine.playedSentenceIndices, [0]);

      audioEngine.completeSentence(0);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(
        container.read(intensiveListenPlayerProvider).isPauseBetweenPlays,
        true,
      );

      unawaited(notifier.goToPrevious());
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        0,
      );
      expect(audioEngine.playedSentenceIndices, [0]);
      expect(
        container.read(intensiveListenPlayerProvider).isPauseBetweenSentences,
        true,
      );
    });

    test('第二句停顿期 goToPrevious 切到第一句并播放', () async {
      final audioEngine = _DeferredBlindAudioEngine();
      final container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
        startIndex: 1,
      );

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(Duration.zero);
      expect(audioEngine.playedSentenceIndices, [1]);

      audioEngine.completeSentence(1);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(
        container.read(intensiveListenPlayerProvider).isPauseBetweenPlays,
        true,
      );

      unawaited(notifier.goToPrevious());
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(intensiveListenPlayerProvider).currentSentenceIndex,
        0,
      );
      expect(audioEngine.playedSentenceIndices, [1, 0]);
      expect(container.read(intensiveListenPlayerProvider).isPlaying, true);
    });
  });

  group('句间倒计时冻结锁屏进度（见 §7.16）', () {
    test('播放中不冻结，进入句间停顿倒计时冻结，下一句起播解冻', () async {
      final audioEngine = _DeferredBlindAudioEngine();
      final container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
      );

      unawaited(notifier.startPlaying());
      await Future<void>.delayed(Duration.zero);

      // 播放中（BlindPlayingPrompt）：进度不冻结
      expect(container.read(intensiveListenPlayerProvider).isPlaying, true);
      expect(audioEngine.progressFrozen, false);

      // 本句播完 → 进入停顿倒计时（BlindWaitingInterval）：进度冻结
      audioEngine.completeSentence(0);
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(
        container.read(intensiveListenPlayerProvider).isPauseBetweenPlays,
        true,
      );
      expect(audioEngine.progressFrozen, true);
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
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(container, notifier, sentences);
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
      final pending = container.read(intensiveListenPlayerProvider);
      expect(pending.currentSentenceIndex, 0);
      expect(pending.isAnnotationReplay, false);
      expect(pending.isAnnotationMode, true);
      expect(pending.isPauseBetweenSentences, false);
      final phase = pending.annotationState?.phase;
      expect(phase, isA<WaitingAnnotationPageTransition>());
      expect(
        (phase! as WaitingAnnotationPageTransition).targetSentenceIndex,
        1,
      );

      await notifier.commitPendingAnnotationAdvance(1);

      final advanced = container.read(intensiveListenPlayerProvider);
      expect(advanced.currentSentenceIndex, 1);
      expect(advanced.isAnnotationReplay, false);
      expect(advanced.isAnnotationMode, false);
      expect(advanced.annotationState, isNull);
    });

    test('待翻页提交目标过期时不会推进句子', () async {
      notifier.enterAnnotationMode();

      final future = notifier.exitAnnotationMode();
      await future;

      await notifier.commitPendingAnnotationAdvance(2);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.currentSentenceIndex, 0);
      expect(
        state.annotationState?.phase,
        isA<WaitingAnnotationPageTransition>(),
      );
    });

    test('开启讲解页循环后，播放按钮按设置次数播放且不自动切句', () async {
      final audioEngine = _ReplayTestAudioEngine();
      final replayContainer = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(replayContainer.dispose);
      final replayNotifier = replayContainer.read(
        intensiveListenPlayerProvider.notifier,
      );
      await _initializeWithTestAudio(
        replayContainer,
        replayNotifier,
        sentences,
        settings: const IntensiveListenSettings(
          repeatCount: 3,
          annotationReplayUsesRepeatCount: true,
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 1.0,
        ),
      );
      replayNotifier.enterAnnotationMode();

      await replayNotifier.replayInAnnotationMode();

      expect(audioEngine.playedSentenceIndices, [0, 0, 0]);
      expect(
        replayContainer
            .read(intensiveListenPlayerProvider)
            .currentSentenceIndex,
        0,
      );
      expect(
        replayContainer
            .read(intensiveListenPlayerProvider)
            .annotationState
            ?.phase,
        isA<InspectingAnnotation>(),
      );
    });

    test('开启讲解页循环后，点击继续仍只重播一次', () async {
      final audioEngine = _ReplayTestAudioEngine();
      final replayContainer = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(replayContainer.dispose);
      final replayNotifier = replayContainer.read(
        intensiveListenPlayerProvider.notifier,
      );
      await _initializeWithTestAudio(
        replayContainer,
        replayNotifier,
        sentences,
        settings: const IntensiveListenSettings(
          repeatCount: 3,
          annotationReplayUsesRepeatCount: true,
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 1.0,
        ),
      );
      replayNotifier.enterAnnotationMode();

      await replayNotifier.exitAnnotationMode();

      expect(audioEngine.playedSentenceIndices, [0]);
      expect(
        replayContainer
            .read(intensiveListenPlayerProvider)
            .annotationState
            ?.phase,
        isA<WaitingAnnotationPageTransition>(),
      );
      await replayNotifier.commitPendingAnnotationAdvance(1);
      expect(
        replayContainer
            .read(intensiveListenPlayerProvider)
            .currentSentenceIndex,
        1,
      );
    });

    test('点击详情倒计时后取消自动推进并等待用户', () async {
      notifier.enterAnnotationMode();

      final future = notifier.exitAnnotationMode();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final pausing = container.read(intensiveListenPlayerProvider);
      expect(pausing.isPauseBetweenSentences, true);

      notifier.onAnnotationUserInteraction();
      await future;

      final waiting = container.read(intensiveListenPlayerProvider);
      expect(waiting.currentSentenceIndex, 0);
      expect(waiting.isAnnotationMode, true);
      expect(waiting.isPauseBetweenSentences, false);
      expect(waiting.annotationState?.phase, isA<WaitingAnnotationUser>());
    });

    test('最后一句点击继续后，重播和倒计时结束后标记完成', () async {
      await notifier.goToNext();
      notifier.enterAnnotationMode();

      await notifier.exitAnnotationMode();

      final completed = container.read(intensiveListenPlayerProvider);
      expect(completed.isAnnotationReplay, false);
      expect(completed.isPauseBetweenSentences, false);
    });

    test('旧详情重播结束不会覆盖新重播的播放态', () async {
      final audioEngine = _OverlappingReplayAudioEngine();
      final overlappingContainer = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(overlappingContainer.dispose);
      final overlappingNotifier = overlappingContainer.read(
        intensiveListenPlayerProvider.notifier,
      );
      await _initializeWithTestAudio(
        overlappingContainer,
        overlappingNotifier,
        sentences,
      );
      overlappingNotifier.enterAnnotationMode();

      final firstReplay = overlappingNotifier.exitAnnotationMode();
      await Future<void>.delayed(Duration.zero);
      overlappingNotifier.pause();
      final secondReplay = overlappingNotifier.exitAnnotationMode();
      await Future<void>.delayed(Duration.zero);

      expect(
        overlappingContainer.read(intensiveListenPlayerProvider).isPlaying,
        true,
      );

      audioEngine.completePlayback(1);
      await Future<void>.delayed(Duration.zero);

      final replaying = overlappingContainer.read(
        intensiveListenPlayerProvider,
      );
      expect(replaying.isAnnotationReplay, true);
      expect(replaying.isPlaying, true);

      audioEngine.completePlayback(2);
      await Future.wait([firstReplay, secondReplay]);
    });

    test('暂停详情重播后，旧回调不会启动倒计时', () async {
      final audioEngine = _OverlappingReplayAudioEngine();
      final pausedContainer = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => audioEngine),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(pausedContainer.dispose);
      final pausedNotifier = pausedContainer.read(
        intensiveListenPlayerProvider.notifier,
      );
      await _initializeWithTestAudio(
        pausedContainer,
        pausedNotifier,
        sentences,
      );
      pausedNotifier.enterAnnotationMode();

      final replay = pausedNotifier.exitAnnotationMode();
      await Future<void>.delayed(Duration.zero);
      await pausedNotifier.pause();
      audioEngine.completePlayback(1);
      await Future<void>.delayed(Duration.zero);

      final paused = pausedContainer.read(intensiveListenPlayerProvider);
      expect(paused.annotationState?.phase, isA<WaitingAnnotationUser>());
      expect(paused.isAnnotationReplay, isFalse);
      expect(paused.isPauseBetweenSentences, isFalse);
      await replay;
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
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
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
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
        startIndex: 1,
      );
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
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
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
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        createTestSentences(count: 3),
        startIndex: 2,
      );
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
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
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
          ...studyTimeOverrides(),
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

  group('手动模式行为', () {
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
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(
        container,
        notifier,
        sentences,
        settings: const IntensiveListenSettings(
          controlMode: ShadowingControlMode.manual,
        ),
      );
    });

    tearDown(() => container.dispose());

    test('手动模式下播放一遍后停止，不自动推进', () async {
      await notifier.startPlaying();

      final state = container.read(intensiveListenPlayerProvider);
      // 播放完一遍后应该停止
      expect(state.isPlaying, false);
      // 仍在第一句
      expect(state.currentSentenceIndex, 0);
      // 没有进入倒计时
      expect(state.isPauseBetweenPlays, false);
      expect(state.isPauseBetweenSentences, false);
    });

    test('手动模式从讲解页手动切句后进入下一句并退出讲解', () async {
      // 先正常播放一遍
      await notifier.startPlaying();
      // 进入标注模式
      notifier.enterAnnotationMode();
      // 手动下一句直接离开当前讲解并沿用手动播放流程
      await notifier.goToSentence(1);

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.currentSentenceIndex, 1);
      expect(state.isAnnotationMode, false);
      expect(state.annotationState, isNull);
      expect(state.isPlaying, false);
      expect(state.isAnnotationReplay, false);
    });

    test('手动模式使用循环次数和句间停顿，循环中停留当前句', () async {
      final repeatPause = Completer<IntensiveListenState>();
      final subscription = container.listen(intensiveListenPlayerProvider, (
        previous,
        next,
      ) {
        if (!repeatPause.isCompleted && next.isPauseBetweenPlays) {
          repeatPause.complete(next);
        }
      });
      notifier.updateSettings(
        const IntensiveListenSettings(
          controlMode: ShadowingControlMode.manual,
          repeatCount: 3,
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 5,
        ),
      );
      final state = await repeatPause.future;
      subscription.close();

      expect(state.isPlaying, false);
      expect(state.currentPlayCount, 2);
      expect(state.blindFlowState?.totalRepeats, 3);
      expect(state.isPauseBetweenPlays, true);
      expect(state.pauseDuration, const Duration(seconds: 5));
      expect(state.isPauseBetweenSentences, false);
      expect(state.currentSentenceIndex, 0);
    });
  });

  group('calculatePauseDuration', () {
    test('smart 模式：1秒 + 0.6 × 句子时长', () {
      // 3秒句子 → 1000 + 1800 = 2800ms
      final result = calculatePauseDuration(
        const Duration(seconds: 3),
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(milliseconds: 2800));
    });

    test('smart 模式：短句子 clamp 到最小 2 秒', () {
      // 500ms 句子 → 1000 + 300 = 1300ms → clamp 到 2000ms
      final result = calculatePauseDuration(
        const Duration(milliseconds: 500),
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('smart 模式：零时长句子返回最小 2 秒', () {
      final result = calculatePauseDuration(
        Duration.zero,
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(milliseconds: 2000));
    });

    test('smart 模式：超长句子封顶 20 秒', () {
      // 60秒句子 → 1000 + 36000 = 37000ms → clamp 到 20000ms
      final result = calculatePauseDuration(
        const Duration(seconds: 60),
        const IntensiveListenSettings(pauseMode: PauseMode.smart),
      );
      expect(result, const Duration(seconds: 20));
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

  group('盲听自动切句时重置偷看字幕', () {
    test('自动推进到下一句时 isTextRevealed 重置为 false', () async {
      final container = ProviderContainer(
        overrides: [
          initialLearningSettingsProvider.overrideWithValue(
            const LearningSettings(),
          ),
          audioEngineProvider.overrideWith(() => _ReplayTestAudioEngine()),
          learningSessionProvider.overrideWith(() => TestLearningSession()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

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

      final notifier = container.read(intensiveListenPlayerProvider.notifier);
      await _initializeWithTestAudio(container, notifier, sentences);
      // 使用极短倒计时以加速测试
      notifier.updateSettings(
        const IntensiveListenSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: 0.5,
        ),
      );

      // 偷看字幕
      notifier.setTextRevealed(true);
      expect(
        container.read(intensiveListenPlayerProvider).isTextRevealed,
        true,
      );

      // 播放 → 句间倒计时 → 自动切到下一句
      await notifier.startPlaying();
      // 等待倒计时 tick（100ms 间隔）+ 第二句播放
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final state = container.read(intensiveListenPlayerProvider);
      expect(state.currentSentenceIndex, 1);
      expect(state.isTextRevealed, false);
    });
  });
}

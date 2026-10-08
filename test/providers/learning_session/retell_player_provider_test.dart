import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/paragraph_playback_driver.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';
import 'package:echo_loop/providers/retell_recording_controller_provider.dart';
import 'package:echo_loop/services/study_activity_gate.dart';

import '../../helpers/mock_providers.dart';

/// 可控测试引擎：用于验证 stopPlayback 与下一次 playRangeOnce 的时序。
class SequencedTestAudioEngine extends ForegroundAudioEngine {
  final Completer<void> _stopCompleter = Completer<void>();
  final Completer<void> _playRangeOnceCompleter = Completer<void>();
  int _sessionId = 0;

  int stopPlaybackCallCount = 0;
  int playRangeOnceCallCount = 0;
  bool playCalledBeforeStopCompleted = false;

  Future<void> get playRangeOnceCalled => _playRangeOnceCompleter.future;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCallCount += 1;
    await _stopCompleter.future;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    playRangeOnceCallCount += 1;
    if (!_playRangeOnceCompleter.isCompleted) {
      _playRangeOnceCompleter.complete();
    }
    if (!_stopCompleter.isCompleted) {
      playCalledBeforeStopCompleted = true;
    }

    // 只用于时序测试：触发调用后立刻使当前 session 失效，
    // 避免 RetellPlayer 进入后续倒计时逻辑，保持测试稳定。
    _sessionId += 1;
  }

  void completeStopPlayback() {
    if (!_stopCompleter.isCompleted) {
      _stopCompleter.complete();
    }
  }
}

class _RecordingLearningProgressNotifier extends TestLearningProgressNotifier {
  _RecordingLearningProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveRetellSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    savedIndices.add(paragraphIndex);
    final progress =
        state.progressMap[audioItemId] ??
        LearningProgress(
          audioItemId: audioItemId,
          currentStage: LearningStage.firstLearn,
          currentSubStage: SubStageType.retell,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellSentenceIndex: paragraphIndex,
      clearRetellSentenceIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _InMemoryLearningProgressNotifier extends TestLearningProgressNotifier {
  _InMemoryLearningProgressNotifier([super.initialState]);

  @override
  Future<void> saveRetellSentenceIndex(
    String audioItemId,
    int? paragraphIndex, {
    required bool isFreePlay,
  }) async {
    final progress = await ensureProgress(audioItemId);
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      retellSentenceIndex: paragraphIndex,
      clearRetellSentenceIndex: paragraphIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

class _PassiveLearningSession extends TestLearningSession {
  _PassiveLearningSession([super.initialState]);
}

/// 记录段落复述写入新统计链路的内容，避免测试依赖真实数据库。
class _RecordingRetellStudyTimeService extends FakeStudyTimeService {
  final List<({Duration duration, String text, StudyStage stage})>
  sentencePlaybacks = [];
  final List<({Duration duration, StudyStage stage})> speechRecognitions = [];
  final List<({int count, StudyStage stage})> outputWords = [];
  final List<
    ({Duration studyDuration, Duration inputDuration, StudyStage stage})
  >
  sessionDurations = [];
  int flushCount = 0;

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
  void submitOutputWords(
    int count, {
    required StudyStage stage,
    DateTime? date,
  }) {
    outputWords.add((count: count, stage: stage));
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
  Future<void> flush() async => flushCount += 1;
}

/// 立即完成段落播放，供统计测试精确验证完整播放和断点后缀。
class _CompletingParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  int _sessionId = 0;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> pause() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    onRangeReady();
    return SentencePlaybackResult.completed;
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void unbindLockScreen() {}
}

ProviderContainer _createRetellStatsContainer(
  _RecordingRetellStudyTimeService studyTimeService, {
  TestRetellRecordingController? recordingController,
  StudyActivityGate? activityGate,
}) {
  return ProviderContainer(
    overrides: [
      foregroundAudioEngineProvider.overrideWith(TestForegroundAudioEngine.new),
      learningSessionProvider.overrideWith(TestLearningSession.new),
      analyticsOverride(),
      ...learningSettingsOverrides(),
      ...studyTimeOverrides(),
      studyTimeServiceProvider.overrideWithValue(studyTimeService),
      if (recordingController != null)
        retellRecordingControllerProvider.overrideWith(
          () => recordingController,
        ),
      if (activityGate != null)
        studyActivityGateProvider.overrideWithValue(activityGate),
    ],
  );
}

/// 记录复述状态机对底层播放契约的调用，不依赖音频或视频实现。
class _RecordingParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  int _sessionId = 0;
  final List<({Duration start, Duration end})> ranges = [];
  final List<double> speeds = [];
  final List<Duration> seeks = [];
  int pauseCalls = 0;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> pause() async => pauseCalls += 1;

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    ranges.add((start: start, end: end));
    speeds.add(speed);
    onRangeReady();
    // 模拟切换页面或任务导致本次播放过期，避免进入复述倒计时。
    _sessionId += 1;
    return SentencePlaybackResult.cancelled;
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void unbindLockScreen() {}
}

/// 控制每次段落播放完成时机，验证导航不会等待音频自然结束。
class _ControlledParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  int _sessionId = 0;
  final List<Completer<SentencePlaybackResult>> _playbacks = [];
  final List<({int count, Completer<void> completer})> _playCountWaiters = [];

  int get playCount => _playbacks.length;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> pause() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) {
    final playback = Completer<SentencePlaybackResult>();
    _playbacks.add(playback);
    onRangeReady();
    for (final waiter in _playCountWaiters.toList()) {
      if (_playbacks.length >= waiter.count) {
        waiter.completer.complete();
        _playCountWaiters.remove(waiter);
      }
    }
    return playback.future;
  }

  Future<void> waitForPlayCount(int count) {
    if (_playbacks.length >= count) return Future<void>.value();
    final completer = Completer<void>();
    _playCountWaiters.add((count: count, completer: completer));
    return completer.future;
  }

  void completePlayback(int index) {
    final playback = _playbacks[index];
    if (!playback.isCompleted) {
      playback.complete(SentencePlaybackResult.completed);
    }
  }

  void completeAll() {
    for (var index = 0; index < _playbacks.length; index++) {
      completePlayback(index);
    }
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void unbindLockScreen() {}
}

/// 用于复现“倒计时中切段”问题：
/// - 段落播放立即完成，进入复述倒计时
/// - stopPlayback 延迟完成，给已取消倒计时的过期回调制造竞态窗口
class CountdownNavigationTestAudioEngine extends ForegroundAudioEngine {
  final Completer<void> _stopCompleter = Completer<void>();
  int _sessionId = 0;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stopPlayback() async {
    await _stopCompleter.future;
  }

  void completeStopPlayback() {
    if (!_stopCompleter.isCompleted) {
      _stopCompleter.complete();
    }
  }
}

/// playRange 立刻返回并失效 session，避免 RetellPlayer 自动进入 retelling phase。
class _SeekTestAudioEngine extends ForegroundAudioEngine {
  int _sessionId = 0;
  Duration? lastPlayStart;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    lastPlayStart = start;
    // 立刻失效 session：RetellPlayer 进入 sessionStillActive=false 的 return 分支，
    // 不会自动推进到 retelling phase，state 停在 listening。
    _sessionId += 1;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stopPlayback() async {}
}

class DelayedRetellTestAudioEngine extends ForegroundAudioEngine {
  int _sessionId = 0;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => const Stream.empty();

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    if (!isActiveSession(sessionId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stopPlayback() async {}
}

/// 位置流驱动测试引擎：`playRangeOnce` 在 `onClipReady` 时通知调用方订阅位置流，
/// 随后挂起（保持 session 活跃 / listening 阶段），由测试用 [emitPosition] 手动推位置。
/// 用于验证「clip 落定前后的陈旧/越界 position 被丢弃」。
class PositionDrivenTestAudioEngine extends ForegroundAudioEngine {
  int _sessionId = 0;
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final Completer<void> _playGate = Completer<void>();
  final Completer<void> rangeReady = Completer<void>();
  Duration? lastPlayStart;

  @override
  AudioEngineState build() => const AudioEngineState();

  @override
  Stream<Duration> get absolutePositionStream => _posController.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => true;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    lastPlayStart = start;
    onClipReady?.call(); // 模拟 clip+seek(0) 落定后通知调用方订阅
    if (!rangeReady.isCompleted) rangeReady.complete();
    await _playGate.future; // 挂住，保持 session 活跃 / listening 阶段
  }

  /// 推一个位置事件并让监听器有机会处理。
  Future<void> emitPosition(Duration position) async {
    _posController.add(position);
    await Future<void>.delayed(Duration.zero);
  }

  /// 使当前 session 失效——放行 gate 后 `_playCurrentParagraph` 走
  /// `sessionStillActive == false` 的 early return，不再触发后续阶段逻辑。
  void invalidateSession() {
    _sessionId += 1;
  }

  void release() {
    if (!_playGate.isCompleted) _playGate.complete();
    if (!_posController.isClosed) _posController.close();
  }
}

void main() {
  group('RetellPlayer 新学习统计', () {
    test('页面退出记录有效学习时长，手动暂停期间不累计且重复退出只收尾一次', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final activityGate = StudyActivityGate();
      final container = _createRetellStatsContainer(
        studyTimeService,
        activityGate: activityGate,
      );
      addTearDown(() {
        activityGate.dispose();
        container.dispose();
      });

      var now = DateTime(2026, 9, 14, 12);
      await withClock(Clock(() => now), () async {
        final notifier = container.read(retellPlayerProvider.notifier);
        await notifier.initialize([
          [
            Sentence(
              index: 0,
              text: 'A paragraph',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 2),
            ),
          ],
        ], playbackDriver: _CompletingParagraphPlaybackDriver());

        now = now.add(const Duration(seconds: 3));
        notifier.pauseStudySession();
        now = now.add(const Duration(seconds: 10));
        notifier.resumeStudySession();
        now = now.add(const Duration(seconds: 2));

        await Future.wait([notifier.disposePlayer(), notifier.disposePlayer()]);

        expect(studyTimeService.sessionDurations, hasLength(2));
        expect(
          studyTimeService.sessionDurations
              .map((record) => record.studyDuration)
              .reduce((a, b) => a + b),
          const Duration(seconds: 5),
        );
        expect(
          studyTimeService.sessionDurations.every(
            (record) =>
                record.inputDuration == Duration.zero &&
                record.stage == StudyStage.retell,
          ),
          isTrue,
        );
      });
    });

    test('完整段落播放写入复述输入，断点续播只统计实际播放后缀', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final container = _createRetellStatsContainer(studyTimeService);
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      await notifier.initialize(
        [
          [
            Sentence(
              index: 0,
              text: 'First',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 5),
            ),
            Sentence(
              index: 1,
              text: 'Second words',
              startTime: const Duration(seconds: 5),
              endTime: const Duration(seconds: 15),
            ),
          ],
        ],
        startSentenceIndex: 1,
        settings: const RetellSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: _CompletingParagraphPlaybackDriver(),
      );

      await notifier.startPlaying();

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      expect(
        studyTimeService.sentencePlaybacks.single.duration,
        const Duration(seconds: 10),
      );
      expect(studyTimeService.sentencePlaybacks.single.text, 'Second words');
      expect(
        studyTimeService.sentencePlaybacks.single.stage,
        StudyStage.retell,
      );

      await notifier.completeRetellingTurn();

      expect(studyTimeService.outputWords, hasLength(1));
      expect(studyTimeService.outputWords.single.count, 3);
      expect(studyTimeService.outputWords.single.stage, StudyStage.retell);
      await notifier.disposePlayer();
    });

    test('取消段落播放不写入输入统计', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final container = _createRetellStatsContainer(studyTimeService);
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      await notifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Cancelled',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 2),
          ),
        ],
      ], playbackDriver: _RecordingParagraphPlaybackDriver());

      await notifier.startPlaying();

      expect(studyTimeService.sentencePlaybacks, isEmpty);
      await notifier.disposePlayer();
    });

    test('录音完成写入语音识别时长，旧会话迟到回调不会污染新会话', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final recordingController = TestRetellRecordingController();
      final container = _createRetellStatsContainer(
        studyTimeService,
        recordingController: recordingController,
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = [
        [
          Sentence(
            index: 0,
            text: 'Recorded',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 2),
          ),
        ],
      ];
      await notifier.initialize(paragraphs);
      final oldHandler = recordingController.recordingCompletionHandler;
      recordingController.emitRecordingCompleted(
        const Duration(milliseconds: 1200),
      );
      expect(studyTimeService.speechRecognitions, hasLength(1));

      await notifier.initialize(paragraphs);
      oldHandler?.call(const Duration(seconds: 3));

      expect(studyTimeService.speechRecognitions, hasLength(1));
      expect(
        studyTimeService.speechRecognitions.single.stage,
        StudyStage.retell,
      );
      await notifier.disposePlayer();
    });
  });

  group('RetellPlayer', () {
    late ProviderContainer container;
    late SequencedTestAudioEngine engine;
    late RetellPlayer notifier;

    setUp(() {
      engine = SequencedTestAudioEngine();
      container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => engine),
          learningSessionProvider.overrideWith(TestLearningSession.new),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      notifier = container.read(retellPlayerProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('注入的段落播放驱动承接播放、暂停、变速和跳转且丢弃过期 session', () async {
      final driver = _RecordingParagraphPlaybackDriver();
      final paragraphs = [
        [
          Sentence(
            index: 0,
            text: 'First',
            startTime: const Duration(seconds: 1),
            endTime: const Duration(seconds: 2),
          ),
          Sentence(
            index: 1,
            text: 'Second',
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 4),
          ),
        ],
      ];

      await notifier.initialize(paragraphs, playbackDriver: driver);
      await notifier.startPlaying();

      expect(driver.ranges.single.start, const Duration(seconds: 1));
      expect(driver.ranges.single.end, const Duration(seconds: 4));
      expect(driver.speeds, [1.0]);
      expect(container.read(retellPlayerProvider).phase, RetellPhase.listening);

      notifier.updateSettings(
        container
            .read(retellPlayerProvider)
            .settings
            .copyWith(playbackSpeed: 1.25),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier.pause();
      await notifier.seekToSentence(1);
      await Future<void>.delayed(Duration.zero);

      expect(driver.speeds, contains(1.25));
      expect(driver.pauseCalls, greaterThanOrEqualTo(2));
      expect(driver.ranges.last.start, const Duration(seconds: 2));
    });

    test('goToNextParagraph 等待 stopPlayback 完成后才开始下一段播放', () async {
      final sentences = [
        Sentence(
          index: 0,
          text: 'Paragraph one',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 3),
        ),
        Sentence(
          index: 1,
          text: 'Paragraph two',
          startTime: const Duration(seconds: 3),
          endTime: const Duration(seconds: 6),
        ),
      ];

      await notifier.initialize([
        [sentences[0]],
        [sentences[1]],
      ]);

      final pending = notifier.goToNextParagraph();
      await Future<void>.delayed(Duration.zero);

      expect(engine.stopPlaybackCallCount, 1);
      expect(engine.playRangeOnceCallCount, 0);

      engine.completeStopPlayback();
      await pending;
      await engine.playRangeOnceCalled;

      expect(engine.playRangeOnceCallCount, 1);
      expect(engine.playCalledBeforeStopCompleted, false);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);
    });

    test('段落播放未结束时仍可连续切换上一段和下一段', () async {
      final driver = _ControlledParagraphPlaybackDriver();
      await notifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        [
          Sentence(
            index: 1,
            text: 'Paragraph two',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        ],
      ], playbackDriver: driver);

      final pendingPlaybacks = <Future<void>>[];
      addTearDown(() async {
        driver.completeAll();
        await Future.wait(pendingPlaybacks);
        await notifier.disposePlayer();
      });

      pendingPlaybacks.add(notifier.startPlaying());
      await driver.waitForPlayCount(1);

      var nextReturned = false;
      final next = notifier.goToNextParagraph().then<void>((_) {
        nextReturned = true;
      });
      pendingPlaybacks.add(next);
      await driver.waitForPlayCount(2);
      await Future<void>.value();

      expect(nextReturned, isTrue);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);

      var previousReturned = false;
      final previous = notifier.goToPreviousParagraph().then<void>((_) {
        previousReturned = true;
      });
      pendingPlaybacks.add(previous);
      await driver.waitForPlayCount(3);
      await Future<void>.value();

      expect(previousReturned, isTrue);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 0);

      driver.completePlayback(0);
      await pendingPlaybacks.first;
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 0);
      expect(container.read(retellPlayerProvider).isPlaying, isTrue);
    });

    test('最后一段重复播放时不提前结束，达到遍数后才完成', () async {
      final driver = _ControlledParagraphPlaybackDriver();
      await notifier.initialize(
        [
          [
            Sentence(
              index: 0,
              text: 'Last paragraph',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
            ),
          ],
        ],
        settings: const RetellSettings(repeatCount: 2),
        playbackDriver: driver,
      );

      final pendingTurns = <Future<void>>[];
      addTearDown(() async {
        driver.completeAll();
        await Future.wait(pendingTurns);
        await notifier.disposePlayer();
      });

      var repeatReturned = false;
      final repeat = notifier.completeRetellingTurn().then<void>((_) {
        repeatReturned = true;
      });
      pendingTurns.add(repeat);
      await driver.waitForPlayCount(1);
      await Future<void>.value();

      final repeatedState = container.read(retellPlayerProvider);
      expect(repeatReturned, isTrue);
      expect(repeatedState.currentParagraphIndex, 0);
      expect(repeatedState.currentRepeatCount, 2);
      expect(repeatedState.stepFinished, isFalse);

      await notifier.completeRetellingTurn();
      expect(container.read(retellPlayerProvider).stepFinished, isTrue);

      driver.completePlayback(0);
      await Future<void>.value();
      expect(container.read(retellPlayerProvider).stepFinished, isTrue);
    });

    test('等待态挂起时，当前段播完后进入 waiting for user', () async {
      final delayedContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => DelayedRetellTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(TestLearningSession.new),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(delayedContainer.dispose);

      final delayedNotifier = delayedContainer.read(
        retellPlayerProvider.notifier,
      );
      await delayedNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      final pending = delayedNotifier.startPlaying();
      delayedNotifier.enterWaitingForUser(afterCurrentParagraph: true);
      delayedNotifier.updateSettings(
        const RetellSettings(controlMode: ShadowingControlMode.manual),
      );
      await pending;

      final state = delayedContainer.read(retellPlayerProvider);
      expect(state.phase, RetellPhase.retelling);
      expect(state.isWaitingForUser, true);
      expect(state.isPlaying, false);
      expect(state.isRetellCountdown, false);
    });

    test('无限重复时完成一遍后继续当前段', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => SequencedTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(_PassiveLearningSession.new),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      await notifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);
      notifier.updateSettings(const RetellSettings(repeatCount: 0));
      await notifier.completeRetellingTurn();

      final state = container.read(retellPlayerProvider);
      expect(state.currentParagraphIndex, 0);
      expect(state.currentRepeatCount, 2);
    });

    test('startPlaying 会异步保存当前段首句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.retell,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final saveContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => SequencedTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(saveContainer.dispose);

      final saveNotifier = saveContainer.read(retellPlayerProvider.notifier);
      await saveNotifier.initialize([
        [
          Sentence(
            index: 3,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      await saveNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(3));
      expect(progressNotifier.savedIndices.first, 3);
    });

    test('freePlay 模式也会异步保存当前段首句索引', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.retell,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final saveContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => SequencedTestAudioEngine(),
          ),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
                isFreePlay: true,
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(saveContainer.dispose);

      final saveNotifier = saveContainer.read(retellPlayerProvider.notifier);
      await saveNotifier.initialize([
        [
          Sentence(
            index: 5,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      await saveNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(5));
    });

    test('打开段落：clip 落定后吐出的越界陈旧 position 被丢弃，不改高亮、不污染断点', () async {
      final progressNotifier = _RecordingLearningProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.retell,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final posEngine = PositionDrivenTestAudioEngine();
      final studyTimeService = _RecordingRetellStudyTimeService();
      final posContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => posEngine),
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          // 静音跳过会读 appSettingsProvider；用测试实现避免触发 SharedPreferences 加载
          appSettingsProvider.overrideWith(() => TestAppSettings()),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
          studyTimeServiceProvider.overrideWithValue(studyTimeService),
        ],
      );
      addTearDown(() {
        posEngine.release();
        posContainer.dispose();
      });

      final posNotifier = posContainer.read(retellPlayerProvider.notifier);
      // 单段、起点在音频中部（30s 起）、时长 12s（>10s 触发断点偏移）
      final para = [
        Sentence(
          index: 0,
          text: 's0',
          startTime: const Duration(seconds: 30),
          endTime: const Duration(seconds: 33),
        ),
        Sentence(
          index: 1,
          text: 's1',
          startTime: const Duration(seconds: 33),
          endTime: const Duration(seconds: 36),
        ),
        Sentence(
          index: 2,
          text: 's2',
          startTime: const Duration(seconds: 36),
          endTime: const Duration(seconds: 39),
        ),
        Sentence(
          index: 3,
          text: 's3',
          startTime: const Duration(seconds: 39),
          endTime: const Duration(seconds: 42),
        ),
      ];
      // 断点恢复到第 3 句（全局 index 2）
      await posNotifier.initialize([para], startSentenceIndex: 2);

      final playing = posNotifier.startPlaying(); // 挂在 playGate，session 保持活跃
      await posEngine.rangeReady.future;

      // 起播即从断点句（local 2）开始，并持久化 index 2
      expect(posContainer.read(retellPlayerProvider).playingSentenceIndex, 2);
      expect(posEngine.lastPlayStart, const Duration(seconds: 36));
      expect(progressNotifier.savedIndices, [2]);

      // 模拟「player 在 0」吐出的陈旧越界 position（< 本段首句 30s）
      await posEngine.emitPosition(Duration.zero);
      // 高亮不变、未追加持久化（断点没被覆盖成首句）
      expect(posContainer.read(retellPlayerProvider).playingSentenceIndex, 2);
      expect(progressNotifier.savedIndices, [2]);

      // 段内 position（落在第 4 句 39-42s）正常推进高亮 + 持久化
      await posEngine.emitPosition(const Duration(seconds: 40));
      expect(posContainer.read(retellPlayerProvider).playingSentenceIndex, 3);
      expect(progressNotifier.savedIndices, [2, 3]);
      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      expect(studyTimeService.sentencePlaybacks.single.text, 's2');
      expect(
        studyTimeService.sentencePlaybacks.single.duration,
        const Duration(seconds: 3),
      );

      // 收尾：失效 session 后放行，让 startPlaying 干净返回
      posEngine.invalidateSession();
      posEngine.release();
      await playing;
    });

    test('自然完成时逐句写入复述输入统计', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final container = _createRetellStatsContainer(studyTimeService);
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      await notifier.initialize(
        [
          [
            Sentence(
              index: 0,
              text: 'First words',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 2),
            ),
            Sentence(
              index: 1,
              text: 'Second words',
              startTime: const Duration(seconds: 2),
              endTime: const Duration(seconds: 5),
            ),
            Sentence(
              index: 2,
              text: 'Third words',
              startTime: const Duration(seconds: 5),
              endTime: const Duration(seconds: 9),
            ),
          ],
        ],
        settings: const RetellSettings(
          controlMode: ShadowingControlMode.manual,
        ),
        playbackDriver: _CompletingParagraphPlaybackDriver(),
      );

      await notifier.startPlaying();

      expect(
        studyTimeService.sentencePlaybacks
            .map((record) => record.text)
            .toList(),
        ['First words', 'Second words', 'Third words'],
      );
      expect(
        studyTimeService.sentencePlaybacks
            .map((record) => record.duration)
            .toList(),
        [
          const Duration(seconds: 2),
          const Duration(seconds: 3),
          const Duration(seconds: 4),
        ],
      );
    });

    test('播放取消时保留已完成句子，不统计未完成句子', () async {
      final studyTimeService = _RecordingRetellStudyTimeService();
      final posEngine = PositionDrivenTestAudioEngine();
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => posEngine),
          learningSessionProvider.overrideWith(TestLearningSession.new),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
          studyTimeServiceProvider.overrideWithValue(studyTimeService),
        ],
      );
      addTearDown(() {
        posEngine.release();
        container.dispose();
      });

      final notifier = container.read(retellPlayerProvider.notifier);
      await notifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Completed sentence',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 2),
          ),
          Sentence(
            index: 1,
            text: 'Incomplete sentence',
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 5),
          ),
          Sentence(
            index: 2,
            text: 'Still incomplete sentence',
            startTime: const Duration(seconds: 5),
            endTime: const Duration(seconds: 8),
          ),
        ],
      ]);

      final playing = notifier.startPlaying();
      await posEngine.rangeReady.future;
      // 一次 position 可能跨过多个句尾，必须逐句补记而不是只记当前句。
      await posEngine.emitPosition(const Duration(seconds: 5));
      expect(studyTimeService.sentencePlaybacks, hasLength(2));
      expect(
        studyTimeService.sentencePlaybacks
            .map((record) => record.text)
            .toList(),
        ['Completed sentence', 'Incomplete sentence'],
      );

      posEngine.invalidateSession();
      posEngine.release();
      await playing;

      expect(studyTimeService.sentencePlaybacks, hasLength(2));
    });

    test('复述倒计时中点击上一段会正确进入上一段，不会停留在当前段', () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final countdownContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => countdownEngine),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(countdownContainer.dispose);

      final countdownNotifier = countdownContainer.read(
        retellPlayerProvider.notifier,
      );
      await countdownNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        [
          Sentence(
            index: 1,
            text: 'Paragraph two',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        ],
        [
          Sentence(
            index: 2,
            text: 'Paragraph three',
            startTime: const Duration(seconds: 6),
            endTime: const Duration(seconds: 9),
          ),
        ],
      ], startSentenceIndex: 1);
      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 模拟评估完成后 screen 层触发段间停顿
      countdownNotifier.startPostEvaluationPause();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        countdownContainer.read(retellPlayerProvider).isRetellCountdown,
        true,
      );
      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        1,
      );

      final pending = countdownNotifier.goToPreviousParagraph();
      await Future<void>.delayed(Duration.zero);
      countdownEngine.completeStopPlayback();
      await pending;

      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        0,
      );
    });

    test(
      '用户在 listening phase 手动切换 displayMode 后，进入 retelling phase 时保持不变',
      () async {
        final countdownEngine = CountdownNavigationTestAudioEngine();
        final testContainer = ProviderContainer(
          overrides: [
            foregroundAudioEngineProvider.overrideWith(() => countdownEngine),
            learningSessionProvider.overrideWith(
              () => _PassiveLearningSession(
                const LearningSessionState(
                  learningMode: LearningMode.retell,
                  audioItemId: 'audio-1',
                ),
              ),
            ),
            learningProgressNotifierProvider.overrideWith(
              _InMemoryLearningProgressNotifier.new,
            ),
            analyticsOverride(),
            ...learningSettingsOverrides(),
            ...studyTimeOverrides(),
          ],
        );
        addTearDown(testContainer.dispose);

        final testNotifier = testContainer.read(retellPlayerProvider.notifier);
        await testNotifier.initialize([
          [
            Sentence(
              index: 0,
              text: 'Paragraph one',
              startTime: Duration.zero,
              endTime: const Duration(seconds: 3),
            ),
          ],
        ]);

        // 开始播放（playRangeOnce 立即完成 → 自动进入 retelling phase）
        await testNotifier.startPlaying();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 验证默认进入 retelling 时 displayMode 为 keywordsOnly
        expect(
          testContainer.read(retellPlayerProvider).phase,
          RetellPhase.retelling,
        );
        expect(
          testContainer.read(retellPlayerProvider).displayMode,
          RetellDisplayMode.keywordsOnly,
        );

        // 重播回到 listening phase
        countdownEngine.completeStopPlayback();
        await testNotifier.replayDuringCountdown();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // 在播放完成前（或播放完成后）用户手动切换到 showAll
        testNotifier.setDisplayMode(RetellDisplayMode.showAll);
        expect(
          testContainer.read(retellPlayerProvider).displayMode,
          RetellDisplayMode.showAll,
        );
        expect(
          testContainer.read(retellPlayerProvider).userOverrodeDisplayMode,
          true,
        );

        // playRangeOnce 已完成，此时已进入 retelling phase
        // 验证 displayMode 仍为 showAll（未被重置为 keywordsOnly）
        expect(
          testContainer.read(retellPlayerProvider).phase,
          RetellPhase.retelling,
        );
        expect(
          testContainer.read(retellPlayerProvider).displayMode,
          RetellDisplayMode.showAll,
        );
      },
    );

    test('未手动切换 displayMode 时，进入 retelling phase 正常重置为 keywordsOnly', () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final testContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => countdownEngine),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(testContainer.dispose);

      final testNotifier = testContainer.read(retellPlayerProvider.notifier);
      await testNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
      ]);

      // 开始播放 → 自动进入 retelling phase
      await testNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 验证未手动操作时，displayMode 被重置为 keywordsOnly
      expect(
        testContainer.read(retellPlayerProvider).phase,
        RetellPhase.retelling,
      );
      expect(
        testContainer.read(retellPlayerProvider).displayMode,
        RetellDisplayMode.keywordsOnly,
      );
      expect(
        testContainer.read(retellPlayerProvider).userOverrodeDisplayMode,
        false,
      );
    });

    test('复述倒计时中点击下一段只推进一段，不会跳过一段', () async {
      final countdownEngine = CountdownNavigationTestAudioEngine();
      final countdownContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => countdownEngine),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(countdownContainer.dispose);

      final countdownNotifier = countdownContainer.read(
        retellPlayerProvider.notifier,
      );
      await countdownNotifier.initialize([
        [
          Sentence(
            index: 0,
            text: 'Paragraph one',
            startTime: Duration.zero,
            endTime: const Duration(seconds: 3),
          ),
        ],
        [
          Sentence(
            index: 1,
            text: 'Paragraph two',
            startTime: const Duration(seconds: 3),
            endTime: const Duration(seconds: 6),
          ),
        ],
        [
          Sentence(
            index: 2,
            text: 'Paragraph three',
            startTime: const Duration(seconds: 6),
            endTime: const Duration(seconds: 9),
          ),
        ],
      ]);

      await countdownNotifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 模拟评估完成后 screen 层触发段间停顿
      countdownNotifier.startPostEvaluationPause();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        countdownContainer.read(retellPlayerProvider).isRetellCountdown,
        true,
      );
      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        0,
      );

      final pending = countdownNotifier.goToNextParagraph();
      await Future<void>.delayed(Duration.zero);
      countdownEngine.completeStopPlayback();
      await pending;

      expect(
        countdownContainer.read(retellPlayerProvider).currentParagraphIndex,
        1,
      );
    });
  });

  group('RetellPlayer seekToSentence', () {
    /// 构造 N 段 × M 句 的等长段落
    List<List<Sentence>> buildParagraphs({
      required int paragraphCount,
      required int sentencesPerParagraph,
      int sentenceDurationMs = 2000,
    }) {
      final paragraphs = <List<Sentence>>[];
      var globalIdx = 0;
      var cursorMs = 0;
      for (var p = 0; p < paragraphCount; p++) {
        final paragraph = <Sentence>[];
        for (var s = 0; s < sentencesPerParagraph; s++) {
          paragraph.add(
            Sentence(
              index: globalIdx,
              text: 'p${p}_s$s',
              startTime: Duration(milliseconds: cursorMs),
              endTime: Duration(milliseconds: cursorMs + sentenceDurationMs),
            ),
          );
          globalIdx += 1;
          cursorMs += sentenceDurationMs;
        }
        paragraphs.add(paragraph);
      }
      return paragraphs;
    }

    test('同段 seek 保留 displayMode（如用户已切 showAll）', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(_SeekTestAudioEngine.new),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 5,
      );
      await notifier.initialize(paragraphs);
      notifier.setDisplayMode(RetellDisplayMode.showAll);

      await notifier.seekToSentence(2);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(retellPlayerProvider);
      // 同段 seek 不重置 displayMode（保留 showAll + userOverrodeDisplayMode）
      expect(state.displayMode, RetellDisplayMode.showAll);
      expect(state.userOverrodeDisplayMode, true);
      expect(state.phase, RetellPhase.listening);
    });

    test('跨段 seek 重置 displayMode 和 userOverrodeDisplayMode', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(_SeekTestAudioEngine.new),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 4,
      );
      await notifier.initialize(paragraphs);
      notifier.setDisplayMode(RetellDisplayMode.showAll);

      // 跨段 seek 到段 1 第 2 句（globalIdx = 6）
      await notifier.seekToSentence(6);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(retellPlayerProvider);
      expect(state.currentParagraphIndex, 1);
      expect(state.currentRepeatCount, 1);
      expect(state.displayMode, RetellDisplayMode.hideAll);
      expect(state.userOverrodeDisplayMode, false);
    });

    test('seekToParagraph 跳到目标段首句，越界则不动', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(_SeekTestAudioEngine.new),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = buildParagraphs(
        paragraphCount: 3,
        sentencesPerParagraph: 4,
      );
      await notifier.initialize(paragraphs);

      // 跳到第 3 段（index=2）→ 落在该段，listening phase
      await notifier.seekToParagraph(2);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 2);
      expect(container.read(retellPlayerProvider).phase, RetellPhase.listening);

      // 越界（>= 段数）不改变当前段
      await notifier.seekToParagraph(5);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 2);

      // 负索引不改变当前段
      await notifier.seekToParagraph(-1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 2);
    });

    test('retelling phase 中 seek 强制切回 listening + 清等待态', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(_SeekTestAudioEngine.new),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 5,
      );
      await notifier.initialize(paragraphs);

      // 模拟用户在播放中进入"等待用户操作"，phase 切到 retelling
      notifier.enterWaitingForUser(stopImmediately: true);
      expect(container.read(retellPlayerProvider).phase, RetellPhase.retelling);
      expect(container.read(retellPlayerProvider).isWaitingForUser, true);

      await notifier.seekToSentence(3);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(retellPlayerProvider);
      expect(state.phase, RetellPhase.listening);
      expect(state.isWaitingForUser, false);
      expect(state.isRetellCountdown, false);
      expect(state.isCountdownPaused, false);
      expect(state.isCountdownFastForward, false);
    });
  });

  group('RetellPlayer pause 快照', () {
    /// 构造 N 段 × M 句 的等长段落
    List<List<Sentence>> buildParagraphs({
      required int paragraphCount,
      required int sentencesPerParagraph,
      int sentenceDurationMs = 2000,
    }) {
      final paragraphs = <List<Sentence>>[];
      var globalIdx = 0;
      var cursorMs = 0;
      for (var p = 0; p < paragraphCount; p++) {
        final paragraph = <Sentence>[];
        for (var s = 0; s < sentencesPerParagraph; s++) {
          paragraph.add(
            Sentence(
              index: globalIdx,
              text: 'p${p}_s$s',
              startTime: Duration(milliseconds: cursorMs),
              endTime: Duration(milliseconds: cursorMs + sentenceDurationMs),
            ),
          );
          globalIdx += 1;
          cursorMs += sentenceDurationMs;
        }
        paragraphs.add(paragraph);
      }
      return paragraphs;
    }

    test('pause → goToNextParagraph 下一段从段首开播（不污染）', () async {
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(_SeekTestAudioEngine.new),
          learningSessionProvider.overrideWith(
            () => _PassiveLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.retell,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(
            _InMemoryLearningProgressNotifier.new,
          ),
          analyticsOverride(),
          ...learningSettingsOverrides(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(retellPlayerProvider.notifier);
      final paragraphs = buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 5,
      );
      await notifier.initialize(paragraphs);

      // 进入段 0 第 3 句，然后 pause
      await notifier.seekToSentence(3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await notifier.pause();

      // 跳到下一段：段 1 应从段首句开播，不带入段 0 idx=3 偏移
      await notifier.goToNextParagraph();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(retellPlayerProvider);
      expect(state.currentParagraphIndex, 1);
      expect(state.playingSentenceIndex, 0);
    });
  });
}

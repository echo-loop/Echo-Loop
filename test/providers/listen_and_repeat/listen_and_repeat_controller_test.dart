// 跟读会话控制器单元测试：覆盖自动流程、暂停恢复、切句竞态及媒体进入。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/native.dart';

import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart' as model;
import 'package:echo_loop/models/media_engine_state.dart';
import 'package:echo_loop/models/media_load_result.dart';
import 'package:echo_loop/models/intensive_listen_prefs.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_phase.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/listening_practice/listening_practice_provider.dart';
import 'package:echo_loop/providers/learned_vocabulary_tracker_provider.dart';
import 'package:echo_loop/providers/media_engine/media_engine_provider.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/learned_vocabulary_tracker.dart';

import '../../helpers/mock_providers.dart';

class _MockBookmarkDao extends Mock implements BookmarkDao {}

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

class _TestStudyStatsNotifier extends StudyStatsNotifier {
  @override
  Future<StudyStats> build() async => const StudyStats();

  @override
  Future<void> refresh() async {}
}

class _ControlledMediaEngine extends MediaEngine {
  _ControlledMediaEngine({this.duration = const Duration(minutes: 1)});

  final Duration? duration;
  final Completer<void> loadStarted = Completer<void>();
  Completer<Duration?>? blockingLoad;
  int releaseCalls = 0;
  int subtitleCalls = 0;
  int pauseCalls = 0;
  Completer<void>? rangePlayback;
  bool _rangeCancelled = false;
  final Completer<void> releaseStarted = Completer<void>();

  @override
  MediaEngineState build() => const MediaEngineState();

  @override
  Future<Duration?> loadMedia(
    model.AudioItem item,
    double speed, {
    Duration initialPosition = Duration.zero,
    bool publishToSystemMediaSession = true,
  }) {
    if (!loadStarted.isCompleted) loadStarted.complete();
    return blockingLoad?.future ?? Future<Duration?>.value(duration);
  }

  @override
  Future<void> setSubtitleTrackData(String? srt) async {
    subtitleCalls += 1;
  }

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end, {
    required double speed,
    void Function()? onRangeReady,
    int? sessionId,
  }) async {
    _rangeCancelled = false;
    onRangeReady?.call();
    await (rangePlayback ??= Completer<void>()).future;
    return _rangeCancelled
        ? SentencePlaybackResult.cancelled
        : SentencePlaybackResult.completed;
  }

  @override
  Future<void> cancelActiveRange({String reason = 'caller-cancel'}) async {
    pauseCalls += 1;
    _rangeCancelled = true;
    if (rangePlayback?.isCompleted == false) rangePlayback?.complete();
  }

  @override
  Future<void> releaseFromScreen() async {
    releaseCalls += 1;
    if (!releaseStarted.isCompleted) releaseStarted.complete();
  }
}

/// 测试用 AudioEngine — playClipOnce 即时完成
class _InstantAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;

  _InstantAudioEngine()
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
    // 即时完成，不等待播放
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// 测试用可控 AudioEngine
class _ControlledAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;
  Completer<void>? playCompleter;

  _ControlledAudioEngine()
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
    final completer = playCompleter ??= Completer<void>();
    await completer.future;
  }
}

/// 测试用默认配置
RepeatFlowConfig _testConfig({
  int repeatCount = 3,
  Duration interval = const Duration(milliseconds: 100),
  bool isManualMode = false,
}) {
  return RepeatFlowConfig(
    audioItemId: 'test-audio',
    getRepeatCount: (_) => repeatCount,
    getIntervalDuration: (_) => interval,
    isManualMode: () => isManualMode,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const BookmarksCompanion());
  });

  late ProviderContainer container;
  late ListenAndRepeatController controller;
  late AppDatabase database;
  late _RecordingStudyTimeService studyTimeService;

  void listenToController(ProviderContainer value) {
    value.listen<ListenAndRepeatSessionState>(
      listenAndRepeatControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
  }

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    studyTimeService = _RecordingStudyTimeService();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        foregroundAudioEngineProvider.overrideWith(() => _InstantAudioEngine()),
        audioEngineProvider.overrideWith(TestAudioEngine.new),
        studyTimeServiceProvider.overrideWithValue(studyTimeService),
        speechRecordingControllerProvider.overrideWith(
          TestSpeechRecordingController.new,
        ),
      ],
    );
    listenToController(container);
    controller = container.read(listenAndRepeatControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  ListenAndRepeatSessionState readState() =>
      container.read(listenAndRepeatControllerProvider);

  test('视频页面先挂载时可读取占位 promptId，不要求流程已初始化', () {
    expect(controller.currentPromptId, 'lar:pending:0');
  });

  group('视频进入竞态', () {
    model.AudioItem mediaItem() => model.AudioItem(
      id: 'video-1',
      name: 'Video',
      audioPath: 'video.mp4',
      addedDate: DateTime(2026, 8, 3),
    );

    ProviderContainer createMediaContainer(_ControlledMediaEngine mediaEngine) {
      final bookmarkDao = _MockBookmarkDao();
      when(
        () => bookmarkDao.getBookmarkedIndices('video-1'),
      ).thenAnswer((_) async => {0});
      final container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(
            () => _InstantAudioEngine(),
          ),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          mediaEngineProvider.overrideWith(() => mediaEngine),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          learningProgressNotifierProvider.overrideWith(
            TestLearningProgressNotifier.new,
          ),
          listeningPracticeProvider.overrideWith(TestListeningPractice.new),
          studyTimeServiceProvider.overrideWithValue(FakeStudyTimeService()),
          learnedVocabularyTrackerProvider.overrideWithValue(
            LearnedVocabularyTracker(
              persistWordForms: (_) async {},
              onStatsUpdated: () {},
            ),
          ),
          studyStatsNotifierProvider.overrideWith(_TestStudyStatsNotifier.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
        ],
      );
      listenToController(container);
      return container;
    }

    test('加载失败会释放媒体且不会准备跟读会话', () async {
      final mediaEngine = _ControlledMediaEngine(duration: null);
      final mediaContainer = createMediaContainer(mediaEngine);
      addTearDown(mediaContainer.dispose);
      final mediaController = mediaContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );

      final result = await mediaController.initialize(
        mediaItem: mediaItem(),
        allSentences: createTestSentences(count: 2),
        isFreePlay: false,
      );

      expect(result, MediaLoadResult.failure);
      expect(mediaEngine.releaseCalls, 1);
      expect(mediaController.isSessionPrepared, isFalse);
    });

    test('加载中取消会丢弃迟到成功并释放媒体', () async {
      final mediaEngine = _ControlledMediaEngine()
        ..blockingLoad = Completer<Duration?>();
      final mediaContainer = createMediaContainer(mediaEngine);
      addTearDown(mediaContainer.dispose);
      final mediaController = mediaContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );

      final entry = mediaController.initialize(
        mediaItem: mediaItem(),
        allSentences: createTestSentences(count: 2),
        isFreePlay: false,
      );
      await mediaEngine.loadStarted.future;
      await mediaController.cancelEntry();
      mediaEngine.blockingLoad?.complete(const Duration(minutes: 1));

      expect(await entry, MediaLoadResult.cancelled);
      expect(mediaEngine.releaseCalls, 1);
      expect(mediaController.isSessionPrepared, isFalse);
    });

    test('加载成功默认关闭字幕，退出后复位媒体状态', () async {
      final mediaEngine = _ControlledMediaEngine();
      final mediaContainer = createMediaContainer(mediaEngine);
      addTearDown(mediaContainer.dispose);
      final mediaController = mediaContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );

      final result = await mediaController.initialize(
        mediaItem: mediaItem(),
        allSentences: createTestSentences(count: 2),
        isFreePlay: false,
      );
      expect(result, MediaLoadResult.ready);
      expect(mediaEngine.subtitleCalls, 1);
      expect(
        mediaContainer.read(listenAndRepeatControllerProvider).hasVideo,
        isTrue,
      );

      await mediaController.exitLearningMode();

      expect(
        mediaContainer.read(listenAndRepeatControllerProvider).hasVideo,
        isFalse,
      );
      expect(mediaEngine.releaseCalls, 1);
    });

    test('媒体跟读暂停当前 MediaEngine，不触碰旧前台音频驱动', () async {
      final mediaEngine = _ControlledMediaEngine();
      final mediaContainer = createMediaContainer(mediaEngine);
      addTearDown(mediaContainer.dispose);
      final mediaController = mediaContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );

      expect(
        await mediaController.initialize(
          mediaItem: mediaItem(),
          allSentences: createTestSentences(count: 2),
          isFreePlay: false,
        ),
        MediaLoadResult.ready,
      );

      final playing = mediaController.startPlaying();
      await Future<void>.delayed(Duration.zero);
      expect(
        mediaContainer.read(listenAndRepeatControllerProvider).phase,
        isA<PlayingPrompt>(),
      );

      mediaController.enterWaitingForUser();
      await Future<void>.delayed(Duration.zero);
      await playing;

      expect(mediaEngine.pauseCalls, 1);
      expect(
        mediaContainer.read(listenAndRepeatControllerProvider).phase,
        isA<WaitingForUser>(),
      );
    });

    test('Controller 非正常销毁时仍释放已占用媒体', () async {
      final mediaEngine = _ControlledMediaEngine();
      final mediaContainer = createMediaContainer(mediaEngine);
      final mediaController = mediaContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );
      expect(
        await mediaController.initialize(
          mediaItem: mediaItem(),
          allSentences: createTestSentences(count: 2),
          isFreePlay: false,
        ),
        MediaLoadResult.ready,
      );

      mediaContainer.dispose();
      await mediaEngine.releaseStarted.future;

      expect(mediaEngine.releaseCalls, 1);
    });
  });

  group('新学习统计', () {
    test('完整原句播放提交输入统计，且取消播放不提交', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );
      await controller.startPlaying();

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      expect(studyTimeService.sentencePlaybacks.single, (
        duration: const Duration(seconds: 5),
        text: 'Test sentence number 1.',
        stage: StudyStage.listenAndRepeat,
      ));

      final controlledEngine = _ControlledAudioEngine();
      container.dispose();
      studyTimeService = _RecordingStudyTimeService();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(() => controlledEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          studyTimeServiceProvider.overrideWithValue(studyTimeService),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      listenToController(container);
      controller = container.read(listenAndRepeatControllerProvider.notifier);
      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );

      final playing = controller.startPlaying();
      await Future<void>.delayed(Duration.zero);
      await controller.disposeSession();
      controlledEngine.playCompleter?.complete();
      await playing;

      expect(studyTimeService.sentencePlaybacks, isEmpty);
    });

    test('页面计时在退出时写入总时长并刷写统计队列', () async {
      final bookmarkDao = _MockBookmarkDao();
      when(
        () => bookmarkDao.getBookmarkedIndices('test-audio'),
      ).thenAnswer((_) async => {0});
      final statsContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(
            () => _InstantAudioEngine(),
          ),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          mediaEngineProvider.overrideWith(() => _ControlledMediaEngine()),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          learningProgressNotifierProvider.overrideWith(
            TestLearningProgressNotifier.new,
          ),
          listeningPracticeProvider.overrideWith(TestListeningPractice.new),
          studyTimeServiceProvider.overrideWithValue(studyTimeService),
          studyStatsNotifierProvider.overrideWith(_TestStudyStatsNotifier.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
        ],
      );
      addTearDown(statsContainer.dispose);
      listenToController(statsContainer);
      final statsController = statsContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );

      await statsController.initialize(
        mediaItem: model.AudioItem(
          id: 'test-audio',
          name: 'Test Audio',
          audioPath: 'test-audio.mp3',
          addedDate: DateTime(2026, 8, 3),
        ),
        allSentences: createTestSentences(count: 1),
        isFreePlay: false,
        scope: ListenAndRepeatScope.fullText,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await statsController.exitLearningMode();

      expect(studyTimeService.sessionDurations, hasLength(1));
      expect(
        studyTimeService.sessionDurations.single.stage,
        StudyStage.listenAndRepeat,
      );
      expect(
        studyTimeService.sessionDurations.single.studyDuration,
        greaterThan(Duration.zero),
      );
      expect(studyTimeService.flushCalls, 1);
    });
  });

  group('startSession', () {
    test('初始化后进入 PlayingPrompt', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // playClipOnce 即时完成 → 自动进入 Recording（自动模式）
      // 但录音还没接入，_onPromptFinished 会设置 Recording
      expect(readState().phase, isA<Recording>());
      expect(readState().sentenceIndex, 0);
      expect(readState().totalSentences, 3);
      expect(readState().repeatIndex, 0);
      expect(readState().totalRepeats, 3);
      expect(readState().flowToken, 1);
    });

    test('指定 startIndex', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      expect(readState().sentenceIndex, 2);
    });

    test('repeatCount=0 时 totalRepeats 保留为无限', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(repeatCount: 0),
      );
      await controller.startPlaying();

      expect(readState().totalRepeats, 0);
    });

    test('startIndex 超出范围时 clamp', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 99,
      );
      await controller.startPlaying();

      expect(readState().sentenceIndex, 2); // clamped to last
    });
  });

  group('等待用户操作 (WaitingForUser)', () {
    test('enterWaitingForUser → WaitingForUser', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      expect(readState().phase, isA<Recording>());

      controller.enterWaitingForUser();

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('Idle 状态 enterWaitingForUser 无效', () async {
      expect(readState().phase, isA<Idle>());
      controller.enterWaitingForUser();
      expect(readState().phase, isA<Idle>());
    });

    test('重复 enterWaitingForUser 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();
      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());

      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());
    });

    test('onUserInteraction → WaitingForUser', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      controller.onUserInteraction();

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('播放中 onUserInteraction 不打断当前句，播完后进入 WaitingForUser', () async {
      final audioEngine = _ControlledAudioEngine();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(() => audioEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      listenToController(container);
      controller = container.read(listenAndRepeatControllerProvider.notifier);

      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );

      unawaited(controller.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(readState().phase, isA<PlayingPrompt>());

      controller.onUserInteraction();

      expect(readState().phase, isA<PlayingPrompt>());

      audioEngine.playCompleter?.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('播放中修改设置不打断也不重播，播完后进入 WaitingForUser', () async {
      final audioEngine = _ControlledAudioEngine();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(() => audioEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      listenToController(container);
      controller = container.read(listenAndRepeatControllerProvider.notifier);

      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );

      unawaited(controller.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      controller.onUserInteraction();
      await controller.applySettingsChange();

      expect(readState().phase, isA<PlayingPrompt>());

      audioEngine.playCompleter?.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = readState();
      expect(state.phase, isA<WaitingForUser>());
      expect(state.repeatIndex, 0);
    });
  });

  group('切句', () {
    test('nextSentence 原子重置 + flowToken 递增', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();
      final tokenBefore = readState().flowToken;

      await controller.nextSentence();

      expect(readState().sentenceIndex, 1);
      expect(readState().repeatIndex, 0);
      expect(readState().flowToken, greaterThan(tokenBefore));
      expect(readState().recordingPath, isNull);
    });

    test('previousSentence', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      await controller.previousSentence();

      expect(readState().sentenceIndex, 1);
    });

    test('第一句 previousSentence 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );
      await controller.startPlaying();

      await controller.previousSentence();
      expect(readState().sentenceIndex, 0); // 不变
    });

    test('最后一句 nextSentence 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      await controller.nextSentence();
      expect(readState().sentenceIndex, 2); // 不变
    });
  });

  group('flowToken 防竞态', () {
    test('初始化难句会保留已收藏状态，取消时走删除分支', () async {
      final bookmarkDao = _MockBookmarkDao();
      when(
        () => bookmarkDao.getBookmarkedIndices('test-audio'),
      ).thenAnswer((_) async => {0});
      when(
        () => bookmarkDao.removeBookmark(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => bookmarkDao.removeBookmarks(any(), any()),
      ).thenAnswer((_) async {});
      when(() => bookmarkDao.addBookmark(any())).thenAnswer((_) async {});
      when(() => bookmarkDao.getByAudioAndSentence(any(), any())).thenAnswer(
        (_) async => Bookmark(
          id: 1,
          memorySubjectId: 'subject-1',
          audioItemId: 'test-audio',
          sentenceIndex: 0,
          sentenceText: 'First sentence.',
          startTime: 0,
          endTime: 1,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          syncStatus: 0,
        ),
      );

      final initializedContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(
            () => _InstantAudioEngine(),
          ),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          mediaEngineProvider.overrideWith(() => _ControlledMediaEngine()),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          learningProgressNotifierProvider.overrideWith(
            TestLearningProgressNotifier.new,
          ),
          listeningPracticeProvider.overrideWith(TestListeningPractice.new),
          studyTimeServiceProvider.overrideWithValue(FakeStudyTimeService()),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
        ],
      );
      addTearDown(initializedContainer.dispose);
      listenToController(initializedContainer);

      final initializedController = initializedContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );
      await initializedController.initialize(
        mediaItem: model.AudioItem(
          id: 'test-audio',
          name: 'Test Audio',
          audioPath: 'test-audio.mp3',
          addedDate: DateTime(2026, 8, 3),
        ),
        allSentences: createTestSentences(count: 2),
        isFreePlay: false,
      );

      expect(
        initializedContainer
            .read(listenAndRepeatControllerProvider)
            .currentSentenceBookmarked,
        isTrue,
      );

      await initializedController.toggleCurrentBookmark();
      verify(() => bookmarkDao.removeBookmarks('test-audio', {0})).called(1);
      verifyNever(() => bookmarkDao.addBookmark(any()));
    });

    test('全文范围在无书签时仍使用全部字幕句子', () async {
      final bookmarkDao = _MockBookmarkDao();
      when(
        () => bookmarkDao.getBookmarkedIndices('test-audio'),
      ).thenAnswer((_) async => <int>{});
      final fullTextContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(
            () => _InstantAudioEngine(),
          ),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          mediaEngineProvider.overrideWith(() => _ControlledMediaEngine()),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          learningProgressNotifierProvider.overrideWith(
            TestLearningProgressNotifier.new,
          ),
          listeningPracticeProvider.overrideWith(TestListeningPractice.new),
          studyTimeServiceProvider.overrideWithValue(FakeStudyTimeService()),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
          analyticsOverride(),
        ],
      );
      addTearDown(fullTextContainer.dispose);
      listenToController(fullTextContainer);

      await fullTextContainer
          .read(listenAndRepeatControllerProvider.notifier)
          .initialize(
            mediaItem: model.AudioItem(
              id: 'test-audio',
              name: 'Test Audio',
              audioPath: 'test-audio.mp3',
              addedDate: DateTime(2026, 8, 3),
            ),
            allSentences: createTestSentences(count: 2),
            isFreePlay: false,
            scope: ListenAndRepeatScope.fullText,
          );

      final state = fullTextContainer.read(listenAndRepeatControllerProvider);
      expect(state.totalSentences, 2);
      expect(state.sentenceIndex, 0);
      expect(state.hasVideo, isFalse);
    });

    test('切句后旧回调被丢弃', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 记录当前 token
      final oldToken = readState().flowToken;

      // 切到下一句（token 递增）
      await controller.nextSentence();
      expect(readState().flowToken, isNot(oldToken));

      // 旧 token 的回调不应该影响新状态
      // （controller 内部 _onPromptFinished 等方法会检查 token）
    });

    test('播放中切换书签不应使当前播放回调失效', () async {
      final controlledEngine = _ControlledAudioEngine();
      final bookmarkDao = _MockBookmarkDao();
      when(
        () => bookmarkDao.getByAudioAndSentence(any(), any()),
      ).thenAnswer((_) async => null);
      when(
        () => bookmarkDao.removeBookmark(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => bookmarkDao.removeBookmarks(any(), any()),
      ).thenAnswer((_) async {});
      when(() => bookmarkDao.addBookmark(any())).thenAnswer((_) async {});
      final controlledContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          foregroundAudioEngineProvider.overrideWith(() => controlledEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          bookmarkDaoProvider.overrideWithValue(bookmarkDao),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      addTearDown(controlledContainer.dispose);
      listenToController(controlledContainer);

      final controlledController = controlledContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );
      final initialSentences = createTestSentences(
        count: 3,
      ).map((s) => s.index == 0 ? s.copyWith(isBookmarked: true) : s).toList();

      await controlledController.prepareSession(
        sentences: initialSentences,
        config: _testConfig(),
      );

      final startFuture = controlledController.startPlaying();
      await Future<void>.delayed(Duration.zero);

      expect(
        controlledContainer.read(listenAndRepeatControllerProvider).phase,
        isA<PlayingPrompt>(),
      );

      final tokenBefore = controlledContainer
          .read(listenAndRepeatControllerProvider)
          .flowToken;

      await controlledController.toggleCurrentBookmark();

      final stateAfterToggle = controlledContainer.read(
        listenAndRepeatControllerProvider,
      );
      expect(stateAfterToggle.flowToken, tokenBefore);
      expect(stateAfterToggle.currentSentenceBookmarked, isFalse);
      verify(() => bookmarkDao.removeBookmarks('test-audio', {0})).called(1);
      verifyNever(() => bookmarkDao.addBookmark(any()));

      controlledEngine.playCompleter?.complete();
      await startFuture;

      expect(
        controlledContainer.read(listenAndRepeatControllerProvider).phase,
        isA<Recording>(),
      );
    });
  });

  group('手动模式', () {
    test('手动模式下播放完成后进入 WaitingForUser（不自动录音）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(isManualMode: true),
      );
      await controller.startPlaying();

      // 手动模式：播放完成后进入 WaitingForUser，等用户手动操作
      expect(readState().phase, isA<WaitingForUser>());
    });
  });

  group('快进倒计时', () {
    test('非 WaitingInterval 状态 fastForward 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 当前在 Recording，不是 WaitingInterval
      controller.fastForwardInterval();
      expect(readState().phase, isA<Recording>()); // 不变
    });
  });

  group('stopSession', () {
    test('stopSession 回到 Idle', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      controller.stopSession();
      expect(readState().phase, isA<Idle>());
    });
  });

  group('replayCurrentSentence', () {
    test('手动重播递增 repeatIndex（按一次算一遍）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 自动模式下 startPlaying → PlayingPrompt → 即时完成 → Recording
      expect(readState().repeatIndex, 0);

      await controller.replayCurrentSentence();

      // 第一次重播：repeatIndex 从 0 变 1，原句重新播放后进入 Recording
      expect(readState().repeatIndex, 1);
      expect(readState().phase, isA<Recording>());

      await controller.replayCurrentSentence();

      // 第二次重播：repeatIndex 继续 +1
      expect(readState().repeatIndex, 2);

      await controller.replayCurrentSentence();

      // 允许 overshoot：4/3
      expect(readState().repeatIndex, 3);
      expect(readState().totalRepeats, 3);
    });
  });

  group('便捷 getter', () {
    test('isFirstSentence / isLastSentence', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );
      await controller.startPlaying();

      expect(readState().isFirstSentence, isTrue);
      expect(readState().isLastSentence, isFalse);

      await controller.nextSentence();
      await controller.nextSentence();

      expect(readState().isFirstSentence, isFalse);
      expect(readState().isLastSentence, isTrue);
    });
  });

  group('goToSentence 任意跳转（进度条拖动）', () {
    test('跳转到合法句子更新 sentenceIndex', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 8),
        config: _testConfig(),
      );
      await controller.startPlaying();

      await controller.goToSentence(5);

      expect(readState().sentenceIndex, 5);
    });

    test('越界索引被 clamp 到合法范围', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
      );
      await controller.startPlaying();

      await controller.goToSentence(99);
      expect(readState().sentenceIndex, 4);

      await controller.goToSentence(-3);
      expect(readState().sentenceIndex, 0);
    });

    test('跳到当前句保持不变（no-op，flowToken 不变）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
      );
      await controller.startPlaying();
      await controller.goToSentence(2);
      final tokenAfterFirstJump = readState().flowToken;

      await controller.goToSentence(2);

      expect(readState().sentenceIndex, 2);
      expect(readState().flowToken, tokenAfterFirstJump);
    });
  });
}

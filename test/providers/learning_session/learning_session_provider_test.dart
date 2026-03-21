import 'dart:ui';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluency/database/enums.dart';
import 'package:fluency/models/learning_progress.dart';
import 'package:fluency/providers/learning_session/learning_session_provider.dart';
import 'package:fluency/providers/learning_session/blind_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/intensive_listen_player_provider.dart';
import 'package:fluency/providers/learning_session/listen_and_repeat_player_provider.dart';
import 'package:fluency/providers/learning_session/review_difficult_practice_provider.dart';
import 'package:fluency/providers/learning_session/retell_player_provider.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/listening_practice/listening_practice_provider.dart';
import 'package:fluency/providers/learning_progress_provider.dart';
import 'package:fluency/providers/daily_study_time_provider.dart';
import 'package:fluency/models/playback_settings.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/database/providers.dart';
import 'package:fluency/database/daos/bookmark_dao.dart';
import 'package:fluency/database/app_database.dart';

import '../../helpers/mock_providers.dart';

/// 创建内存数据库（用于测试 StudyTimeService 依赖注入）
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

class _DaoFallbackLearningProgressNotifier
    extends TestLearningProgressNotifier {
  final LearningProgress? _dbProgress;

  _DaoFallbackLearningProgressNotifier(
    this._dbProgress, [
    LearningProgressState initialState = const LearningProgressState(),
  ]) : super(initialState);

  @override
  Future<LearningProgress?> getLatestByAudioId(String audioItemId) async {
    final persisted = _dbProgress;
    if (persisted != null) {
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = persisted;
      state = state.copyWith(progressMap: newMap);
      return persisted;
    }
    return super.getLatestByAudioId(audioItemId);
  }

  @override
  Future<LearningProgress> ensureProgress(String audioItemId) async {
    final persisted = _dbProgress;
    if (persisted != null) {
      final newMap = Map<String, LearningProgress>.from(state.progressMap);
      newMap[audioItemId] = persisted;
      state = state.copyWith(progressMap: newMap);
      return persisted;
    }
    return super.ensureProgress(audioItemId);
  }
}

class _TestBookmarkDao implements BookmarkDao {
  final Set<int> bookmarkedIndices;

  _TestBookmarkDao(this.bookmarkedIndices);

  @override
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async {
    return bookmarkedIndices;
  }

  @override
  Future<List<Bookmark>> getByAudioId(String audioItemId) async => [];

  @override
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) =>
      Stream<List<Bookmark>>.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    test('所有学习模式枚举存在', () {
      expect(LearningMode.blindListen, isNotNull);
      expect(LearningMode.intensiveListen, isNotNull);
      expect(LearningMode.listenAndRepeat, isNotNull);
      expect(LearningMode.retell, isNotNull);
      expect(LearningMode.reviewDifficultPractice, isNotNull);
      expect(LearningMode.values.length, 5);
    });
  });

  group('enterIntensiveListenMode 断点恢复', () {
    ProviderContainer createContainer(
      LearningProgressNotifier progressNotifier,
    ) {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_createTestDb()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          intensiveListenPlayerProvider.overrideWith(
            () => TestIntensiveListenPlayer(),
          ),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
          dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
        ],
      );
    }

    final sentences = [
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
      Sentence(
        index: 2,
        text: 'Third sentence',
        startTime: const Duration(seconds: 4),
        endTime: const Duration(seconds: 5),
      ),
    ];

    test('正常学习精听从头开始，忽略遗留断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        intensiveListenSentenceIndex: 2,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode('audio-1', sentences);

      final playerState = container.read(intensiveListenPlayerProvider);
      expect(playerState.currentSentenceIndex, 0);
    });

    test('自由练习精听恢复已保存断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        intensiveListenSentenceIndex: 2,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode('audio-1', sentences, isFreePlay: true);

      final playerState = container.read(intensiveListenPlayerProvider);
      expect(playerState.currentSentenceIndex, 2);
    });

    test('自由练习内存缺失时也能通过 DB 断点恢复', () async {
      final dbProgress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        intensiveListenSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        _DaoFallbackLearningProgressNotifier(dbProgress),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode('audio-1', sentences, isFreePlay: true);

      final playerState = container.read(intensiveListenPlayerProvider);
      expect(playerState.currentSentenceIndex, 1);
    });

    test('自由练习内存旧于数据库时优先使用数据库最新精听断点', () async {
      final stale = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        intensiveListenSentenceIndex: 0,
        updatedAt: DateTime(2026, 3, 11, 9),
      );
      final latest = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.intensiveListen,
        intensiveListenSentenceIndex: 2,
        updatedAt: DateTime(2026, 3, 11, 10),
      );
      final container = createContainer(
        _DaoFallbackLearningProgressNotifier(
          latest,
          LearningProgressState(progressMap: {'audio-1': stale}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode('audio-1', sentences, isFreePlay: true);

      final playerState = container.read(intensiveListenPlayerProvider);
      expect(playerState.currentSentenceIndex, 2);
    });
  });

  group('LearningSession App 生命周期计时', () {
    late ProviderContainer container;
    late TestAudioEngine testAudioEngine;

    /// 创建带有所有依赖 override 的 ProviderContainer
    ProviderContainer createContainer({bool isPlaying = false}) {
      testAudioEngine = TestAudioEngine(isPlaying: isPlaying);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_createTestDb()),
          audioEngineProvider.overrideWith(() => testAudioEngine),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          learningProgressNotifierProvider.overrideWith(
            () => TestLearningProgressNotifier(),
          ),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
          dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
        ],
      );
      return c;
    }

    /// 获取 LearningSession notifier
    LearningSession session(ProviderContainer c) =>
        c.read(learningSessionProvider.notifier);

    /// 模拟 App 进入后台（按 iOS 正确的状态转换顺序）
    ///
    /// resumed → inactive → hidden → paused
    void simulateEnterBackground() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }

    /// 模拟 App 回到前台（按 iOS 正确的状态转换顺序）
    ///
    /// paused → hidden → inactive → resumed
    void simulateEnterForeground() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    /// 模拟 App 进入 hidden 状态（多任务切换画面）
    ///
    /// resumed → inactive → hidden
    void simulateEnterHidden() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }

    tearDown(() {
      container.dispose();
      // 恢复到 resumed 状态，避免跨测试的生命周期状态残留
      final binding = TestWidgetsFlutterBinding.instance;
      try {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      } catch (_) {}
      try {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      } catch (_) {}
      try {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } catch (_) {}
    });

    test('进入学习模式后计时器启动', () async {
      container = createContainer();
      final s = session(container);

      await s.enterBlindListenMode('audio-1', paragraphs: const []);

      expect(s.isStudyTimerRunning, true);
    });

    test('进入后台且音频未播放 → 暂停计时', () async {
      container = createContainer(isPlaying: false);
      final s = session(container);

      await s.enterBlindListenMode('audio-1', paragraphs: const []);
      expect(s.isStudyTimerRunning, true);

      // 模拟：音频未播放时切到后台
      testAudioEngine.isPlaying = false;
      simulateEnterBackground();

      expect(s.isStudyTimerRunning, false);
    });

    test('进入后台且音频正在播放（盲听息屏）→ 暂停计时', () async {
      container = createContainer(isPlaying: true);
      final s = session(container);

      await s.enterBlindListenMode('audio-1', paragraphs: const []);
      expect(s.isStudyTimerRunning, true);

      // 模拟：音频播放中息屏 → 统一暂停计时（不再区分是否有音频播放）
      testAudioEngine.isPlaying = true;
      simulateEnterBackground();

      expect(s.isStudyTimerRunning, false);
    });

    test('回到前台且在学习模式 → 恢复计时', () async {
      container = createContainer(isPlaying: false);
      final s = session(container);

      await s.enterBlindListenMode('audio-1', paragraphs: const []);

      // 模拟：切到后台（音频未播放），计时暂停
      testAudioEngine.isPlaying = false;
      simulateEnterBackground();
      expect(s.isStudyTimerRunning, false);

      // 模拟：回到前台，计时恢复
      simulateEnterForeground();
      expect(s.isStudyTimerRunning, true);
    });

    test('回到前台但不在学习模式 → 不启动计时', () async {
      container = createContainer();

      // 读取 provider 以初始化（注册 AppLifecycleListener）
      container.read(learningSessionProvider);
      final s = session(container);

      // 没有进入学习模式，直接模拟生命周期变化
      simulateEnterBackground();
      simulateEnterForeground();

      expect(s.isStudyTimerRunning, false);
    });

    test('hidden 状态且音频未播放 → 暂停计时', () async {
      container = createContainer(isPlaying: false);
      final s = session(container);

      await s.enterBlindListenMode('audio-1', paragraphs: const []);
      expect(s.isStudyTimerRunning, true);

      // hidden 状态（多任务切换画面）也应暂停
      testAudioEngine.isPlaying = false;
      simulateEnterHidden();

      expect(s.isStudyTimerRunning, false);
    });
  });

  group('其他学习模式断点恢复', () {
    final sentences = [
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
      Sentence(
        index: 2,
        text: 'Third sentence',
        startTime: const Duration(seconds: 4),
        endTime: const Duration(seconds: 5),
      ),
      Sentence(
        index: 3,
        text: 'Fourth sentence',
        startTime: const Duration(seconds: 6),
        endTime: const Duration(seconds: 7),
      ),
    ];

    ProviderContainer createContainer(
      LearningProgressNotifier progressNotifier,
    ) {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(_createTestDb()),
          audioEngineProvider.overrideWith(() => TestAudioEngine()),
          listeningPracticeProvider.overrideWith(() => TestListeningPractice()),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          listenAndRepeatPlayerProvider.overrideWith(
            () => TestListenAndRepeatPlayer(),
          ),
          reviewDifficultPracticeProvider.overrideWith(
            () => TestReviewDifficultPractice(),
          ),
          retellPlayerProvider.overrideWith(() => TestRetellPlayer()),
          blindListenPlayerProvider.overrideWith(() => TestBlindListenPlayer()),
          dailyStudyTimeProvider.overrideWith(() => TestDailyStudyTime()),
          bookmarkDaoProvider.overrideWithValue(_TestBookmarkDao({1, 3})),
        ],
      );
    }

    test('跟读正常学习从头开始，忽略遗留断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        shadowingSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterListenAndRepeatMode('audio-1', sentences);

      final playerState = container.read(listenAndRepeatPlayerProvider);
      expect(playerState.currentSentenceIndex, 0);
    });

    test('跟读自由练习恢复已保存句子断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        shadowingSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterListenAndRepeatMode('audio-1', sentences, isFreePlay: true);

      final playerState = container.read(listenAndRepeatPlayerProvider);
      expect(playerState.currentSentenceIndex, 1);
    });

    test('难句补练正常学习从头开始，忽略遗留断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        difficultPracticeSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterReviewDifficultPracticeMode('audio-1', sentences);

      final playerState = container.read(reviewDifficultPracticeProvider);
      expect(playerState.currentSentenceIndex, 0);
    });

    test('难句补练自由练习恢复已保存句子断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.review1,
        currentSubStage: SubStageType.reviewDifficultPractice,
        difficultPracticeSentenceIndex: 1,
        updatedAt: DateTime(2026, 3, 11),
      );
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterReviewDifficultPracticeMode(
            'audio-1',
            sentences,
            isFreePlay: true,
          );

      final playerState = container.read(reviewDifficultPracticeProvider);
      expect(playerState.currentSentenceIndex, 1);
    });

    test('复述正常学习从头开始，忽略遗留断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        retellParagraphIndex: 2,
        updatedAt: DateTime(2026, 3, 11),
      );
      final paragraphs = [
        [sentences[0], sentences[1]],
        [sentences[2], sentences[3]],
      ];
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterRetellMode('audio-1', paragraphs, const {});

      final playerState = container.read(retellPlayerProvider);
      expect(playerState.currentParagraphIndex, 0);
    });

    test('复述自由练习恢复段首句断点', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        retellParagraphIndex: 2,
        updatedAt: DateTime(2026, 3, 11),
      );
      final paragraphs = [
        [sentences[0], sentences[1]],
        [sentences[2], sentences[3]],
      ];
      final container = createContainer(
        TestLearningProgressNotifier(
          LearningProgressState(progressMap: {'audio-1': progress}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterRetellMode('audio-1', paragraphs, const {}, isFreePlay: true);

      final playerState = container.read(retellPlayerProvider);
      expect(playerState.currentParagraphIndex, 1);
    });

    test('冷启动自由练习时也能从 DB 断点恢复跟读/补练/复述', () async {
      final progress = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        shadowingSentenceIndex: 1,
        difficultPracticeSentenceIndex: 1,
        retellParagraphIndex: 2,
        updatedAt: DateTime(2026, 3, 11),
      );
      final paragraphs = [
        [sentences[0], sentences[1]],
        [sentences[2], sentences[3]],
      ];
      final container = createContainer(
        _DaoFallbackLearningProgressNotifier(progress),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterListenAndRepeatMode('audio-1', sentences, isFreePlay: true);
      expect(
        container.read(listenAndRepeatPlayerProvider).currentSentenceIndex,
        1,
      );

      await container
          .read(learningSessionProvider.notifier)
          .enterReviewDifficultPracticeMode(
            'audio-1',
            sentences,
            isFreePlay: true,
          );
      expect(
        container.read(reviewDifficultPracticeProvider).currentSentenceIndex,
        1,
      );

      await container
          .read(learningSessionProvider.notifier)
          .enterRetellMode('audio-1', paragraphs, const {}, isFreePlay: true);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);
    });

    test('自由练习进入时优先使用数据库最新断点覆盖旧内存', () async {
      final stale = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.listenAndRepeat,
        shadowingSentenceIndex: 0,
        retellParagraphIndex: 0,
        updatedAt: DateTime(2026, 3, 11, 9),
      );
      final latest = LearningProgress(
        audioItemId: 'audio-1',
        currentStage: LearningStage.firstLearn,
        currentSubStage: SubStageType.retell,
        shadowingSentenceIndex: 1,
        retellParagraphIndex: 2,
        updatedAt: DateTime(2026, 3, 11, 10),
      );
      final paragraphs = [
        [sentences[0], sentences[1]],
        [sentences[2], sentences[3]],
      ];
      final container = createContainer(
        _DaoFallbackLearningProgressNotifier(
          latest,
          LearningProgressState(progressMap: {'audio-1': stale}),
        ),
      );
      addTearDown(container.dispose);

      await container
          .read(learningSessionProvider.notifier)
          .enterListenAndRepeatMode('audio-1', sentences, isFreePlay: true);
      expect(
        container.read(listenAndRepeatPlayerProvider).currentSentenceIndex,
        1,
      );

      await container
          .read(learningSessionProvider.notifier)
          .enterRetellMode('audio-1', paragraphs, const {}, isFreePlay: true);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);
    });
  });
}

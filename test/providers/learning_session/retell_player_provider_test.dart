import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart'
    show ShadowingControlMode;
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/retell_settings.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/retell_player_provider.dart';

import '../../helpers/mock_providers.dart';

/// 可控测试引擎：用于验证 stopPlayback 与下一次 playRangeOnce 的时序。
class SequencedTestAudioEngine extends ForegroundAudioEngine {
  final Completer<void> _stopCompleter = Completer<void>();
  int _sessionId = 0;

  int stopPlaybackCallCount = 0;
  int playRangeOnceCallCount = 0;
  bool playCalledBeforeStopCompleted = false;

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

  @override
  void addOutputWords(int count) {}
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
  group('RetellPlayerState', () {
    test('stepFinished — 默认为 false，copyWith 可设置和保留', () {
      const state = RetellPlayerState();
      expect(state.stepFinished, false);

      final finished = state.copyWith(stepFinished: true);
      expect(finished.stepFinished, true);

      // 不传值时保留
      final updated = finished.copyWith(isPlaying: true);
      expect(updated.stepFinished, true);

      // 重置
      final reset = finished.copyWith(stepFinished: false);
      expect(reset.stepFinished, false);
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

      notifier.initialize([
        [sentences[0]],
        [sentences[1]],
      ]);

      final pending = notifier.goToNextParagraph();
      await Future<void>.delayed(Duration.zero);

      expect(engine.stopPlaybackCallCount, 1);
      expect(engine.playRangeOnceCallCount, 0);

      engine.completeStopPlayback();
      await pending;

      expect(engine.playRangeOnceCallCount, 1);
      expect(engine.playCalledBeforeStopCompleted, false);
      expect(container.read(retellPlayerProvider).currentParagraphIndex, 1);
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
      delayedNotifier.initialize([
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
      notifier.initialize([
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
      saveNotifier.initialize([
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
      saveNotifier.initialize([
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
      posNotifier.initialize([para], startSentenceIndex: 2);

      final playing = posNotifier.startPlaying(); // 挂在 playGate，session 保持活跃
      await Future<void>.delayed(Duration.zero);

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

      // 收尾：失效 session 后放行，让 startPlaying 干净返回
      posEngine.invalidateSession();
      posEngine.release();
      await playing;
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
      countdownNotifier.initialize([
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
        testNotifier.initialize([
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
      testNotifier.initialize([
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
      countdownNotifier.initialize([
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
      notifier.initialize(paragraphs);
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
      notifier.initialize(paragraphs);
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
      notifier.initialize(paragraphs);

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
      notifier.initialize(paragraphs);

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
      notifier.initialize(paragraphs);

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

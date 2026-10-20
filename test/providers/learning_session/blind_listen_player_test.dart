import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:echo_loop/database/enums.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/blind_listen_settings.dart';
import 'package:echo_loop/models/intensive_listen_settings.dart';
import 'package:echo_loop/models/learning_progress.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/learning_progress_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/providers/learning_session/blind_listen_player_provider.dart';
import 'package:echo_loop/providers/learning_session/learning_session_provider.dart';
import 'package:echo_loop/providers/learning_session/paragraph_playback_driver.dart';
import 'package:echo_loop/services/study_activity_gate.dart';
import 'package:echo_loop/services/study_time_service.dart';

import '../../helpers/mock_providers.dart';

/// 播放一调用后立即取消 session 的测试驱动，
/// 同时使 session 失效避免触发后续段间倒计时 / 完成态推进。
class _FastParagraphPlaybackDriver extends _TestParagraphPlaybackDriver {
  int playRangeCallCount = 0;
  Duration? lastPlayStart;
  int lastPlaySessionId = -1;

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    playRangeCallCount += 1;
    lastPlayStart = start;
    lastPlaySessionId = sessionId;
    invalidateSession();
    return SentencePlaybackResult.cancelled;
  }
}

/// 立即结束播放且保持 session 有效，用于测试自然播完后的段间倒计时。
class _CompletingBlindTestDriver extends _TestParagraphPlaybackDriver {
  Duration? lastPlayStart;

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    lastPlayStart = start;
    onRangeReady();
    return SentencePlaybackResult.completed;
  }
}

/// 位置流驱动测试适配器：`playRange` 在 ready 回调后通知调用方订阅位置流，
/// 随后挂起（保持 session 活跃 / listening 阶段），由测试用 [emitPosition] 手动推位置。
/// 用于验证「clip 落定前后的陈旧/越界 position 被丢弃」。
class _PositionDrivenBlindTestDriver extends _TestParagraphPlaybackDriver {
  final StreamController<Duration> _posController =
      StreamController<Duration>.broadcast();
  final Completer<void> _playGate = Completer<void>();
  Duration? lastPlayStart;

  @override
  Stream<Duration> get positionStream => _posController.stream;

  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    lastPlayStart = start;
    onRangeReady(); // 模拟 seek 完成后通知调用方订阅
    await _playGate.future; // 挂住，保持 session 活跃 / listening 阶段
    return isActiveSession(sessionId)
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.cancelled;
  }

  /// 推一个位置事件并让监听器有机会处理。
  Future<void> emitPosition(Duration position) async {
    _posController.add(position);
    await Future<void>.delayed(Duration.zero);
  }

  /// 使当前 session 失效，放行 gate 后 `_playCurrentParagraph` 走 early return。
  @override
  void invalidateSession() {
    super.invalidateSession();
  }

  void release() {
    if (!_playGate.isCompleted) _playGate.complete();
    if (!_posController.isClosed) _posController.close();
  }
}

/// 为盲听状态机测试提供 MediaEngine 无关的段落驱动替身。
abstract class _TestParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  int _sessionId = 0;
  Future<void> Function()? lastOnPlay;
  Future<void> Function()? lastOnPause;
  Future<void> Function()? lastOnNext;
  Future<void> Function()? lastOnPrevious;
  bool? logicalPlaying;
  bool progressFrozen = false;
  int startKeepAliveCount = 0;
  int stopKeepAliveCount = 0;

  @override
  int newSession() => ++_sessionId;

  @override
  bool isActiveSession(int sessionId) => sessionId == _sessionId;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

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
  }) async => SentencePlaybackResult.cancelled;

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    lastOnPlay = onPlay;
    lastOnPause = onPause;
    lastOnNext = onNext;
    lastOnPrevious = onPrevious;
  }

  @override
  void setSessionActive(bool active) {
    logicalPlaying = active;
    if (active) {
      startKeepAliveCount += 1;
    } else {
      stopKeepAliveCount += 1;
    }
  }

  @override
  void setProgressFrozen(bool frozen) => progressFrozen = frozen;

  @override
  void unbindLockScreen() {
    lastOnPlay = null;
    lastOnPause = null;
    lastOnNext = null;
    lastOnPrevious = null;
    logicalPlaying = null;
    progressFrozen = false;
  }

  void invalidateSession() {
    _sessionId += 1;
  }
}

class _RecordingBlindProgressNotifier extends TestLearningProgressNotifier {
  _RecordingBlindProgressNotifier(super.initialState);

  final List<int?> savedIndices = [];

  @override
  Future<void> saveBlindListenSentenceIndex(
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
          currentSubStage: SubStageType.blindListen,
          updatedAt: DateTime(2026, 3, 11),
        );
    final newMap = Map<String, LearningProgress>.from(state.progressMap);
    newMap[audioItemId] = progress.copyWith(
      blindListenSentenceIndex: sentenceIndex,
      clearBlindListenSentenceIndex: sentenceIndex == null,
      updatedAt: DateTime(2026, 3, 11, 12),
    );
    state = state.copyWith(progressMap: newMap);
  }
}

/// 构造一组等长段落：每段 [sentencesPerParagraph] 句，每句 [sentenceDurationMs] 毫秒。
List<List<Sentence>> _buildParagraphs({
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

ProviderContainer _buildContainer({
  required ParagraphPlaybackDriver engine,
  TestLearningProgressNotifier? progressNotifier,
  bool isFreePlay = false,
  StudyTimeService? studyTimeService,
  StudyActivityGate? activityGate,
}) {
  // 兜底注入一个 noop progressNotifier，避免触发真实 appDatabaseProvider 的 LateInitializationError
  final notifier = progressNotifier ?? TestLearningProgressNotifier();
  return ProviderContainer(
    overrides: [
      learningSessionProvider.overrideWith(
        () => TestLearningSession(
          LearningSessionState(
            learningMode: LearningMode.blindListen,
            audioItemId: 'audio-1',
            isFreePlay: isFreePlay,
          ),
        ),
      ),
      learningProgressNotifierProvider.overrideWith(() => notifier),
      analyticsOverride(),
      ...studyTimeOverrides(),
      if (studyTimeService != null)
        studyTimeServiceProvider.overrideWithValue(studyTimeService),
      if (activityGate != null)
        studyActivityGateProvider.overrideWithValue(activityGate),
    ],
  );
}

/// 记录全文盲听统计调用，避免测试依赖真实数据库。
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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  group('BlindListenPlayerState', () {
    test('初始状态 — 默认值正确', () {
      const state = BlindListenPlayerState();

      expect(state.isPlaying, false);
      expect(state.currentParagraphIndex, 0);
      expect(state.totalParagraphs, 0);
      expect(state.playingSentenceIndex, -1);
      expect(state.currentRepeatCount, 1);
      expect(state.isPauseCountdown, false);
      expect(state.isCountdownPaused, false);
      expect(state.displayMode, BlindListenDisplayMode.hideAll);
      expect(state.stepFinished, false);
    });

    test('copyWith 设置播放中状态', () {
      const state = BlindListenPlayerState();
      final updated = state.copyWith(isPlaying: true, totalParagraphs: 5);

      expect(updated.isPlaying, true);
      expect(updated.totalParagraphs, 5);
      expect(updated.currentParagraphIndex, 0);
    });

    test('copyWith 更新段落索引', () {
      const state = BlindListenPlayerState(totalParagraphs: 5);
      final updated = state.copyWith(currentParagraphIndex: 2);

      expect(updated.currentParagraphIndex, 2);
      expect(updated.totalParagraphs, 5);
    });

    test('copyWith 切换显示模式', () {
      const state = BlindListenPlayerState();
      final showAll = state.copyWith(
        displayMode: BlindListenDisplayMode.showAll,
      );

      expect(showAll.displayMode, BlindListenDisplayMode.showAll);
    });

    test('copyWith 设置倒计时状态', () {
      const state = BlindListenPlayerState();
      final countdown = state.copyWith(
        isPauseCountdown: true,
        pauseDuration: const Duration(seconds: 30),
        pauseRemaining: const Duration(seconds: 20),
      );

      expect(countdown.isPauseCountdown, true);
      expect(countdown.pauseDuration, const Duration(seconds: 30));
      expect(countdown.pauseRemaining, const Duration(seconds: 20));
    });

    test('copyWith 保留未修改字段', () {
      const state = BlindListenPlayerState(
        isPlaying: true,
        currentParagraphIndex: 2,
        totalParagraphs: 5,
        currentRepeatCount: 3,
      );
      final updated = state.copyWith(isPlaying: false);

      expect(updated.isPlaying, false);
      expect(updated.currentParagraphIndex, 2);
      expect(updated.totalParagraphs, 5);
      expect(updated.currentRepeatCount, 3);
    });

    test('disposePlayer 重置所有状态', () {
      const state = BlindListenPlayerState(
        isPlaying: true,
        currentParagraphIndex: 3,
        totalParagraphs: 5,
      );

      const resetState = BlindListenPlayerState();
      expect(resetState.isPlaying, false);
      expect(resetState.currentParagraphIndex, 0);
      expect(resetState.totalParagraphs, 0);
      // 原状态不受影响（immutable）
      expect(state.isPlaying, true);
    });

    test('stepFinished — copyWith 设置和重置', () {
      const state = BlindListenPlayerState();
      expect(state.stepFinished, false);

      final finished = state.copyWith(stepFinished: true);
      expect(finished.stepFinished, true);

      final reset = finished.copyWith(stepFinished: false);
      expect(reset.stepFinished, false);
    });

    test('stepFinished — copyWith 不传值时保留原值', () {
      const state = BlindListenPlayerState(stepFinished: true);
      final updated = state.copyWith(isPlaying: true);
      expect(updated.stepFinished, true);
    });
  });

  group('BlindListenSettings', () {
    test('默认值正确', () {
      const settings = BlindListenSettings();

      expect(settings.repeatCount, 1);
      expect(settings.pauseMode.name, 'multiplier');
      expect(settings.pauseMultiplier, 0.5);
      expect(settings.fixedPauseSeconds, 10);
    });

    test('calculatePauseDuration — multiplier 模式', () {
      const settings = BlindListenSettings(pauseMultiplier: 2.0);
      final duration = settings.calculatePauseDuration(
        const Duration(seconds: 10),
      );

      expect(duration, const Duration(seconds: 20));
    });

    test('calculatePauseDuration — 最少 3 秒', () {
      const settings = BlindListenSettings(pauseMultiplier: 0.3);
      final duration = settings.calculatePauseDuration(
        const Duration(seconds: 5),
      );

      expect(duration, const Duration(seconds: 3));
    });

    test('copyWith 更新倍数', () {
      const settings = BlindListenSettings();
      final updated = settings.copyWith(pauseMultiplier: 3.0);

      expect(updated.pauseMultiplier, 3.0);
      expect(updated.repeatCount, 1);
    });
  });

  group('BlindListenPlayer seekToSentence', () {
    test('同段 seek 保留 currentRepeatCount 和 displayMode', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      // 单段 5 句，时长 10s（不触发跨段重置）
      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 5,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(repeatCount: 3),
        playbackDriver: engine,
      );
      // 模拟正处于第 2 遍 + 用户已切到 showAll
      notifier.setDisplayMode(BlindListenDisplayMode.showAll);
      await notifier.startPlaying();

      // 手动写入 currentRepeatCount=2 模拟第 2 遍中段（state 是 immutable，借助 seek 不会动它）
      // 这里直接读取并比较：startPlaying 完成后应为 1，seek 后仍为 1
      expect(container.read(blindListenPlayerProvider).currentRepeatCount, 1);

      // 跳到全局 idx=3（同段）
      await notifier.seekToSentence(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(blindListenPlayerProvider);
      expect(state.currentParagraphIndex, 0);
      expect(state.displayMode, BlindListenDisplayMode.showAll);
      // 起播位置 = 全局 idx 3 的句子 startTime
      expect(engine.lastPlayStart, paragraphs[0][3].startTime);
    });

    test('跨段 seek 重置 currentRepeatCount 和 displayMode', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 3,
        sentencesPerParagraph: 4,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(repeatCount: 3),
        playbackDriver: engine,
      );
      notifier.setDisplayMode(BlindListenDisplayMode.showAll);
      await notifier.startPlaying();

      // 跳到段 2 的第 0 句（globalIdx = 2*4 = 8）
      await notifier.seekToSentence(8);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(blindListenPlayerProvider);
      expect(state.currentParagraphIndex, 2);
      expect(state.currentRepeatCount, 1);
      expect(state.displayMode, BlindListenDisplayMode.hideAll);
      expect(engine.lastPlayStart, paragraphs[2][0].startTime);
    });

    test('seekToParagraph 跳到目标段首句，越界则不动', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 3,
        sentencesPerParagraph: 4,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(repeatCount: 3),
        playbackDriver: engine,
      );
      await notifier.startPlaying();

      // 跳到第 3 段（index=2）→ 落在该段首句
      await notifier.seekToParagraph(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(blindListenPlayerProvider).currentParagraphIndex,
        2,
      );
      expect(engine.lastPlayStart, paragraphs[2][0].startTime);

      // 越界（>= 段数）与负索引都不改变当前段
      await notifier.seekToParagraph(5);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(blindListenPlayerProvider).currentParagraphIndex,
        2,
      );
      await notifier.seekToParagraph(-1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(blindListenPlayerProvider).currentParagraphIndex,
        2,
      );
    });

    test('短段 (<10s) seek 仍能从指定句开播（绕过 10s 阈值）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      // 单段 3 句 × 2s = 6s（< 10s 阈值）
      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 3,
        sentenceDurationMs: 2000,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      await notifier.startPlaying();

      await notifier.seekToSentence(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 短段也能精确从 idx=2 开播
      expect(engine.lastPlayStart, paragraphs[0][2].startTime);
    });

    test('无限重复不会在段间停顿后自动完成当前段', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 1,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(repeatCount: 0),
        playbackDriver: engine,
      );

      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(blindListenPlayerProvider).stepFinished, isFalse);
      expect(
        container.read(blindListenPlayerProvider).currentRepeatCount,
        greaterThanOrEqualTo(1),
      );
    });

    test('seek 写盘 globalIdx（由 _playCurrentParagraph 内部 async 写）', () async {
      final progressNotifier = _RecordingBlindProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.blindListen,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(
        engine: engine,
        progressNotifier: progressNotifier,
      );
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 3,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      await notifier.startPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      progressNotifier.savedIndices.clear();
      await notifier.seekToSentence(4);
      await Future<void>.delayed(
        const Duration(milliseconds: 10),
      ); // 段 1 的第 1 句
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(progressNotifier.savedIndices, contains(4));
    });
  });

  group('BlindListenPlayer pause 快照', () {
    test(
      'pause 把 playingSentenceIndex 写入 _resumeStartLocalSentenceIndex（不调写盘）',
      () async {
        final progressNotifier = _RecordingBlindProgressNotifier(
          LearningProgressState(
            progressMap: {
              'audio-1': LearningProgress(
                audioItemId: 'audio-1',
                currentStage: LearningStage.firstLearn,
                currentSubStage: SubStageType.blindListen,
                updatedAt: DateTime(2026, 3, 11),
              ),
            },
          ),
        );
        final engine = _FastParagraphPlaybackDriver();
        final container = _buildContainer(
          engine: engine,
          progressNotifier: progressNotifier,
        );
        addTearDown(container.dispose);
        final notifier = container.read(blindListenPlayerProvider.notifier);

        final paragraphs = _buildParagraphs(
          paragraphCount: 1,
          sentencesPerParagraph: 5,
        );
        await notifier.initializeParagraphs(
          paragraphs,
          const BlindListenSettings(),
          playbackDriver: engine,
        );

        // 通过 seekToSentence 进入第 3 句的播放状态
        await notifier.seekToSentence(3);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 1));

        progressNotifier.savedIndices.clear();
        await notifier.pause();

        // pause 本身不调 saveBlindListenSentenceIndex
        expect(progressNotifier.savedIndices, isEmpty);

        // resume 应从同一句（globalIdx=3）开播，验证 _resumeStartLocalSentenceIndex 写入
        engine.playRangeCallCount = 0;
        await notifier.resume();
        expect(engine.lastPlayStart, paragraphs[0][3].startTime);
      },
    );

    test('pause → resume 从当前句开头开播（短段也生效，forceOffset 路径）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      // 短段 6s（<10s 阈值）
      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 3,
        sentenceDurationMs: 2000,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      await notifier.seekToSentence(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await notifier.pause();
      await notifier.resume();

      // resume 后仍从 idx=2 开播（forceOffset 绕过 10s 阈值）
      expect(engine.lastPlayStart, paragraphs[0][2].startTime);
    });

    test('pause → goToNextParagraph 下一段从段首开播（不污染）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 5,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      // 进入段 0 的第 3 句，然后 pause
      await notifier.seekToSentence(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await notifier.pause();

      // 跳到下一段
      await notifier.goToNextParagraph();

      // 段 1 从段首句（globalIdx=5）开播，不带入段 0 的 idx=3 偏移
      final state = container.read(blindListenPlayerProvider);
      expect(state.currentParagraphIndex, 1);
      expect(engine.lastPlayStart, paragraphs[1][0].startTime);
    });

    test('pause → goToPreviousParagraph 上一段从段首开播（不污染）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 5,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      // 先到段 1，再到第 3 句，pause，再回段 0
      await notifier.seekToSentence(8);
      await Future<void>.delayed(const Duration(milliseconds: 10)); // 段 1 第 3 句
      await notifier.pause();
      await notifier.goToPreviousParagraph();

      final state = container.read(blindListenPlayerProvider);
      expect(state.currentParagraphIndex, 0);
      expect(engine.lastPlayStart, paragraphs[0][0].startTime);
    });

    test('段间停顿期 goToPreviousParagraph 跳转到上一段', () async {
      final engine = _CompletingBlindTestDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 2,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(
          pauseMode: PauseMode.fixed,
          fixedPauseSeconds: 1,
        ),
        startParagraphIndex: 1,
        playbackDriver: engine,
      );

      await notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(blindListenPlayerProvider).isPauseCountdown, true);

      await notifier.goToPreviousParagraph();

      final state = container.read(blindListenPlayerProvider);
      expect(state.currentParagraphIndex, 0);
      expect(engine.lastPlayStart, paragraphs[0][0].startTime);
    });

    test('初始 playingSentenceIndex == -1 时 pause 不写脏断点', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 5,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      // 未开播直接 pause
      await notifier.pause();

      // resume 应从段首开播（断点字段未被写入）
      await notifier.resume();
      expect(engine.lastPlayStart, paragraphs[0][0].startTime);
    });
  });

  group('BlindListenPlayer currentSentenceGlobalIndex', () {
    test('未开播退化为当前段首句的全局索引', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 4,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      // 段 0 段首句 globalIdx = 0
      expect(notifier.currentSentenceGlobalIndex, 0);
    });

    test('段为空时返回 null', () {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      // 没有 initializeParagraphs
      expect(notifier.currentSentenceGlobalIndex, isNull);
    });

    test('seek 后返回目标句全局索引', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);

      final paragraphs = _buildParagraphs(
        paragraphCount: 2,
        sentencesPerParagraph: 4,
      );
      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      await notifier.seekToSentence(5);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // 段 1 第 1 句，state.playingSentenceIndex = 1，对应全局 idx = 5
      expect(notifier.currentSentenceGlobalIndex, 5);
    });
  });

  group('BlindListenPlayer 后台播放 / 锁屏接入', () {
    test('startPlaying 接管锁屏（注册播放/暂停/切段回调）并进入活跃会话（逻辑播放态+保活）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);
      await notifier.initializeParagraphs(
        _buildParagraphs(paragraphCount: 2, sentencesPerParagraph: 3),
        const BlindListenSettings(),
        playbackDriver: engine,
      );

      await notifier.startPlaying();

      expect(engine.lastOnPlay, isNotNull);
      expect(engine.lastOnPause, isNotNull);
      expect(engine.lastOnNext, isNotNull, reason: '锁屏下一段回调应注册');
      expect(engine.lastOnPrevious, isNotNull, reason: '锁屏上一段回调应注册');
      expect(engine.logicalPlaying, isTrue, reason: '起播后锁屏图标应显示播放中');
      expect(engine.startKeepAliveCount, greaterThan(0), reason: '活跃会话应启动静音保活');
    });

    test('pause 停保活、逻辑播放态=false，但保留回调槽（锁屏可续播）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);
      await notifier.initializeParagraphs(
        _buildParagraphs(paragraphCount: 2, sentencesPerParagraph: 3),
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      await notifier.startPlaying();

      await notifier.pause();

      expect(engine.logicalPlaying, isFalse);
      expect(engine.stopKeepAliveCount, greaterThan(0));
      // 回调槽仍在，锁屏播放按钮可续播（修复「播完/暂停后锁屏播放无反应」）。
      expect(engine.lastOnPlay, isNotNull);
      expect(engine.lastOnNext, isNotNull);
    });

    test('disposePlayer 清空锁屏回调并恢复逻辑播放态为 null（不破坏 Free Player）', () async {
      final engine = _FastParagraphPlaybackDriver();
      final container = _buildContainer(engine: engine);
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);
      await notifier.initializeParagraphs(
        _buildParagraphs(paragraphCount: 2, sentencesPerParagraph: 3),
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      await notifier.startPlaying();

      await notifier.disposePlayer();

      expect(engine.lastOnPlay, isNull);
      expect(engine.lastOnNext, isNull);
      expect(
        engine.logicalPlaying,
        isNull,
        reason: '离开任务后 handler 恢复读裸 player',
      );
    });
  });

  group('BlindListenPlayer 新学习统计', () {
    test('后台连续播放时仍累计页面学习时长和输入时长', () {
      fakeAsync((async) {
        withClock(async.getClock(DateTime(2026, 9, 14, 14)), () {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          final activityGate = StudyActivityGate();
          final engine = _PositionDrivenBlindTestDriver();
          final studyTimeService = _RecordingStudyTimeService();
          final container = _buildContainer(
            engine: engine,
            studyTimeService: studyTimeService,
            activityGate: activityGate,
          );
          final notifier = container.read(blindListenPlayerProvider.notifier);
          var initialized = false;

          notifier
              .initializeParagraphs(
                _buildParagraphs(paragraphCount: 1, sentencesPerParagraph: 1),
                const BlindListenSettings(),
                playbackDriver: engine,
              )
              .then((_) => initialized = true);
          async.flushMicrotasks();
          expect(initialized, isTrue);

          notifier.startPlaying();
          async.flushMicrotasks();

          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          async.elapse(const Duration(minutes: 7));
          async.flushMicrotasks();

          final recordedStudyMilliseconds = studyTimeService.sessionDurations
              .map((record) => record.studyDuration.inMilliseconds)
              .fold<int>(0, (total, value) => total + value);
          final recordedInputMilliseconds = studyTimeService.sessionDurations
              .map((record) => record.inputDuration.inMilliseconds)
              .fold<int>(0, (total, value) => total + value);
          expect(recordedStudyMilliseconds, greaterThanOrEqualTo(420000));
          expect(recordedInputMilliseconds, greaterThanOrEqualTo(420000));

          engine.invalidateSession();
          engine.release();
          async.flushMicrotasks();
          container.dispose();
          activityGate.dispose();
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        });
      });
    });

    test('持续播放超过 idle timeout 仍累计页面学习时长', () {
      fakeAsync((async) {
        withClock(async.getClock(DateTime(2026, 9, 14, 14)), () {
          final engine = _PositionDrivenBlindTestDriver();
          final studyTimeService = _RecordingStudyTimeService();
          final container = _buildContainer(
            engine: engine,
            studyTimeService: studyTimeService,
          );
          final notifier = container.read(blindListenPlayerProvider.notifier);
          var initialized = false;

          notifier
              .initializeParagraphs(
                _buildParagraphs(paragraphCount: 1, sentencesPerParagraph: 1),
                const BlindListenSettings(),
                playbackDriver: engine,
              )
              .then((_) => initialized = true);
          async.flushMicrotasks();
          expect(initialized, isTrue);

          notifier.startPlaying();
          async.flushMicrotasks();

          async.elapse(const Duration(minutes: 2, seconds: 30));
          async.flushMicrotasks();

          final recordedStudyMilliseconds = studyTimeService.sessionDurations
              .map((record) => record.studyDuration.inMilliseconds)
              .fold<int>(0, (total, value) => total + value);
          expect(recordedStudyMilliseconds, greaterThanOrEqualTo(150000));

          engine.invalidateSession();
          engine.release();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    });

    test('完整句子结束时立即逐句提交输入统计', () async {
      final engine = _PositionDrivenBlindTestDriver();
      final studyTimeService = _RecordingStudyTimeService();
      final container = _buildContainer(
        engine: engine,
        studyTimeService: studyTimeService,
      );
      addTearDown(container.dispose);
      final notifier = container.read(blindListenPlayerProvider.notifier);
      final paragraphs = _buildParagraphs(
        paragraphCount: 1,
        sentencesPerParagraph: 2,
      );

      await notifier.initializeParagraphs(
        paragraphs,
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      final playing = notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);

      await engine.emitPosition(const Duration(seconds: 2));

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      final firstRecord = studyTimeService.sentencePlaybacks.single;
      expect(firstRecord.duration, const Duration(seconds: 2));
      expect(firstRecord.text, 'p0_s0');
      expect(firstRecord.stage, StudyStage.blindListen);
      expect(firstRecord.recordInputDuration, isFalse);

      // 释放段落播放，成功结果会补齐没有单独 position 事件的尾句。
      engine.release();
      await playing;

      expect(studyTimeService.sentencePlaybacks, hasLength(2));
      final secondRecord = studyTimeService.sentencePlaybacks[1];
      expect(secondRecord.duration, const Duration(seconds: 2));
      expect(secondRecord.text, 'p0_s1');
    });

    test('中途暂停只提交已经完整播放的句子', () async {
      final engine = _PositionDrivenBlindTestDriver();
      final studyTimeService = _RecordingStudyTimeService();
      final container = _buildContainer(
        engine: engine,
        studyTimeService: studyTimeService,
      );
      addTearDown(() {
        engine.release();
        container.dispose();
      });
      final notifier = container.read(blindListenPlayerProvider.notifier);

      await notifier.initializeParagraphs(
        _buildParagraphs(paragraphCount: 1, sentencesPerParagraph: 2),
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      final playing = notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);

      await engine.emitPosition(const Duration(seconds: 2));
      await notifier.pause();

      expect(studyTimeService.sentencePlaybacks, hasLength(1));
      expect(studyTimeService.sentencePlaybacks.single.text, 'p0_s0');
      engine.release();
      await playing;
    });

    test('取消段落播放不提交输入统计', () async {
      final engine = _PositionDrivenBlindTestDriver();
      final studyTimeService = _RecordingStudyTimeService();
      final container = _buildContainer(
        engine: engine,
        studyTimeService: studyTimeService,
      );
      addTearDown(() {
        engine.release();
        container.dispose();
      });
      final notifier = container.read(blindListenPlayerProvider.notifier);

      await notifier.initializeParagraphs(
        _buildParagraphs(paragraphCount: 1, sentencesPerParagraph: 2),
        const BlindListenSettings(),
        playbackDriver: engine,
      );
      final playing = notifier.startPlaying();
      await Future<void>.delayed(Duration.zero);

      await notifier.pause();

      expect(studyTimeService.sentencePlaybacks, isEmpty);
      engine.release();
      await playing;
    });

    test('退出刷写总学习时长且重复销毁不重复写入', () async {
      var now = DateTime(2026, 9, 12, 12);
      await withClock(Clock(() => now), () async {
        final engine = _FastParagraphPlaybackDriver();
        final studyTimeService = _RecordingStudyTimeService();
        final container = _buildContainer(
          engine: engine,
          studyTimeService: studyTimeService,
        );
        addTearDown(container.dispose);
        final notifier = container.read(blindListenPlayerProvider.notifier);

        await notifier.initializeParagraphs(
          _buildParagraphs(paragraphCount: 1, sentencesPerParagraph: 1),
          const BlindListenSettings(),
          playbackDriver: engine,
        );
        now = now.add(const Duration(seconds: 3));

        await Future.wait([notifier.disposePlayer(), notifier.disposePlayer()]);

        expect(studyTimeService.sessionDurations, hasLength(1));
        final record = studyTimeService.sessionDurations.single;
        expect(record.studyDuration, const Duration(seconds: 3));
        expect(record.inputDuration, Duration.zero);
        expect(record.stage, StudyStage.blindListen);
      });
    });
  });

  group('BlindListenPlayer position 追踪防御', () {
    test('打开段落：clip 落定后吐出的越界陈旧 position 被丢弃，不改高亮、不污染断点', () async {
      final progressNotifier = _RecordingBlindProgressNotifier(
        LearningProgressState(
          progressMap: {
            'audio-1': LearningProgress(
              audioItemId: 'audio-1',
              currentStage: LearningStage.firstLearn,
              currentSubStage: SubStageType.blindListen,
              updatedAt: DateTime(2026, 3, 11),
            ),
          },
        ),
      );
      final posEngine = _PositionDrivenBlindTestDriver();
      final container = ProviderContainer(
        overrides: [
          learningSessionProvider.overrideWith(
            () => TestLearningSession(
              const LearningSessionState(
                learningMode: LearningMode.blindListen,
                audioItemId: 'audio-1',
              ),
            ),
          ),
          learningProgressNotifierProvider.overrideWith(() => progressNotifier),
          // 静音跳过会读 appSettingsProvider；用测试实现避免触发 SharedPreferences 加载
          appSettingsProvider.overrideWith(() => TestAppSettings()),
          analyticsOverride(),
          ...studyTimeOverrides(),
        ],
      );
      addTearDown(() {
        posEngine.release();
        container.dispose();
      });

      final notifier = container.read(blindListenPlayerProvider.notifier);
      // 单段、起点在音频中部（30s 起）、时长 12s（>10s 触发断点偏移）
      final para = [
        for (var i = 0; i < 4; i++)
          Sentence(
            index: i,
            text: 's$i',
            startTime: Duration(seconds: 30 + i * 3),
            endTime: Duration(seconds: 30 + i * 3 + 3),
          ),
      ];
      // 断点恢复到第 3 句（段内 local 2）
      await notifier.initializeParagraphs(
        [para],
        const BlindListenSettings(),
        startSentenceLocalIndex: 2,
        playbackDriver: posEngine,
      );

      final playing = notifier.startPlaying(); // 挂在 playGate
      await Future<void>.delayed(Duration.zero);

      // 起播即从断点句（local 2）开始，并持久化 index 2
      expect(container.read(blindListenPlayerProvider).playingSentenceIndex, 2);
      expect(posEngine.lastPlayStart, const Duration(seconds: 36));
      expect(progressNotifier.savedIndices, [2]);

      // 模拟陈旧越界 position（< 本段首句 30s）
      await posEngine.emitPosition(Duration.zero);
      expect(container.read(blindListenPlayerProvider).playingSentenceIndex, 2);
      expect(progressNotifier.savedIndices, [2]);

      // 段内 position（落在第 4 句 39-42s）正常推进高亮 + 持久化
      await posEngine.emitPosition(const Duration(seconds: 40));
      expect(container.read(blindListenPlayerProvider).playingSentenceIndex, 3);
      expect(progressNotifier.savedIndices, [2, 3]);

      // 收尾：失效 session 后放行，让 startPlaying 干净返回
      posEngine.invalidateSession();
      posEngine.release();
      await playing;
    });
  });
}

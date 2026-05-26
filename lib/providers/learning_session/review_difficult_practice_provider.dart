/// 复习难句补练 Provider
///
/// 两种模式：
/// 1. **盲听模式**：使用 [SentencePlaybackEngine] 播放 N 遍，句间停顿后自动推进。
/// 2. **跟读模式**：使用 [RepeatFlowEngine] 驱动 play→record→interval 流程。
///
/// 用户可随时「偷看」字幕或按「听不懂」进入跟读模式。
/// R1+ 支持取消难句标记（听懂的句子可 unbookmark）。
library;

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/intensive_listen_settings.dart' show PauseMode;
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/study_event_recorder.dart';
import '../../services/app_logger.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../blind_flow/blind_practice_flow_engine.dart';
import '../blind_flow/blind_practice_flow_phase.dart';
import '../blind_flow/blind_practice_flow_state.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../learning_progress_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../repeat_flow/repeat_flow_engine.dart';
import '../repeat_flow/repeat_flow_phase.dart';
import '../repeat_flow/repeat_flow_state.dart';
import '../speech/speech_recording_controller.dart';
import 'learning_session_provider.dart';
import 'sentence_playback_engine.dart';

part 'review_difficult_practice_provider.g.dart';

/// 难句补练状态
///
/// 盲听模式使用 [BlindPracticeFlowState]，跟读模式使用 [RepeatFlowState]。
class ReviewDifficultPracticeState {
  /// 当前句子索引
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based）
  final int currentPlayCount;

  /// 练习设置
  final DifficultPracticeSettings settings;

  /// 跟读模式目标遍数（手动模式下强制为 1）
  int get targetRepeatCount =>
      isManualMode ? 1 : settings.shadowReadingRepeatCount;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 是否处于跟读模式
  final bool isAnnotationMode;

  /// 是否偷看字幕
  final bool isTextRevealed;

  /// 倒计时是否暂停中（盲听模式用）
  final bool isCountdownPaused;

  /// 倒计时是否快进中（盲听模式用）
  final bool isCountdownFastForward;

  /// 是否处于评估后倒计时中（跟读模式已由 RepeatFlowEngine 处理，保留供收藏复习兼容）
  final bool isPostEvalCountdown;

  /// 当前步骤是否自然完成
  final bool stepFinished;

  /// 收藏标记版本号
  final int bookmarkVersion;

  /// 当前句是否被强制进入手动模式
  final bool isManualForSentence;

  /// 跟读模式下的流程状态（annotation mode 时有值）
  final RepeatFlowState? repeatFlowState;

  /// 盲听模式下的流程状态（blind mode 时有值）
  final BlindPracticeFlowState? blindFlowState;

  /// 是否处于手动模式
  bool get isManualMode => settings.isManualMode || isManualForSentence;

  const ReviewDifficultPracticeState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.settings = const DifficultPracticeSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isAnnotationMode = false,
    this.isTextRevealed = false,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
    this.isPostEvalCountdown = false,
    this.stepFinished = false,
    this.bookmarkVersion = 0,
    this.isManualForSentence = false,
    this.repeatFlowState,
    this.blindFlowState,
  });

  ReviewDifficultPracticeState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    DifficultPracticeSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isAnnotationMode,
    bool? isTextRevealed,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
    bool? isPostEvalCountdown,
    bool? stepFinished,
    int? bookmarkVersion,
    bool? isManualForSentence,
    RepeatFlowState? repeatFlowState,
    BlindPracticeFlowState? blindFlowState,
    bool clearRepeatFlowState = false,
    bool clearBlindFlowState = false,
  }) {
    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      settings: settings ?? this.settings,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays ?? this.isPauseBetweenPlays,
      isPauseBetweenSentences:
          isPauseBetweenSentences ?? this.isPauseBetweenSentences,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
      isPostEvalCountdown: isPostEvalCountdown ?? this.isPostEvalCountdown,
      stepFinished: stepFinished ?? this.stepFinished,
      bookmarkVersion: bookmarkVersion ?? this.bookmarkVersion,
      isManualForSentence: isManualForSentence ?? this.isManualForSentence,
      repeatFlowState: clearRepeatFlowState
          ? null
          : (repeatFlowState ?? this.repeatFlowState),
      blindFlowState: clearBlindFlowState
          ? null
          : (blindFlowState ?? this.blindFlowState),
    );
  }
}

/// 难句补练 Provider
@Riverpod(keepAlive: true)
class ReviewDifficultPractice extends _$ReviewDifficultPractice {
  /// 难句列表
  List<Sentence> _sentences = [];

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// 盲听播放引擎
  late SentencePlaybackEngine _engine;

  /// 跟读流程引擎（跟读模式时创建，退出时销毁）
  RepeatFlowEngine? _repeatEngine;

  /// 盲听流程引擎
  late BlindPracticeFlowEngine _blindEngine;

  BlindPracticeFlowEngine _createBlindEngine() {
    return BlindPracticeFlowEngine(
      onStateChanged: _onBlindFlowStateChanged,
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () => ref.read(audioEngineProvider.notifier).pause(),
        playSentence: _playSentenceForBlind,
      ),
      logTag: 'RDP-Blind',
    );
  }

  @override
  ReviewDifficultPracticeState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.reviewDifficultPractice,
    );

    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
      recorder: _recorder,
    );
    _blindEngine = _createBlindEngine();

    // 监听录音状态变化 → 桥接到跟读引擎
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);

    ref.onDispose(() {
      _engine.cleanup();
      _blindEngine.dispose();
      _repeatEngine?.dispose();
    });
    return const ReviewDifficultPracticeState();
  }

  /// 初始化
  ///
  /// [playbackSpeed] 入口 briefing 中用户选择的初始播放速度，默认 1.0x。
  /// [pauseMultiplier] 入口 briefing 中选择的句间停顿；-1.0 = 自动（smart 模式），
  ///   其余正数走 multiplier 模式。
  void initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) {
    _engine.cleanup();
    _blindEngine.dispose();
    _blindEngine = _createBlindEngine();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final validIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    // pauseMultiplier < 0 → 走 smart 模式（model 默认）；否则切到 multiplier 模式。
    final initialSettings = pauseMultiplier < 0
        ? DifficultPracticeSettings(playbackSpeed: playbackSpeed)
        : DifficultPracticeSettings(
            playbackSpeed: playbackSpeed,
            pauseMode: PauseMode.multiplier,
            pauseMultiplier: pauseMultiplier,
          );

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _sentences.length,
      settings: initialSettings,
    );
    _prepareBlindFlow(startIndex: validIndex);
    ref.read(analyticsServiceProvider).track(Events.difficultPracticeStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalDifficultSentences: _sentences.length,
    });

    // 注入 recorder
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(_recorder);
    // 也注入到 AudioEngine（跟读模式通过 engine 直接播放时需要）
    ref.read(audioEngineProvider.notifier).setRecorder(_recorder);
  }

  /// 更新设置并重新开始当前句
  Future<void> updateSettings(DifficultPracticeSettings newSettings) async {
    // 速度变化无需重启会话：直接推给 AudioEngine 即可。
    // 其它字段变化沿用现有重启逻辑。
    final old = state.settings;
    final speedOnly =
        newSettings.playbackSpeed != old.playbackSpeed &&
        newSettings.controlMode == old.controlMode &&
        newSettings.blindListenRepeatCount == old.blindListenRepeatCount &&
        newSettings.shadowReadingRepeatCount == old.shadowReadingRepeatCount &&
        newSettings.pauseMode == old.pauseMode &&
        newSettings.fixedPauseSeconds == old.fixedPauseSeconds &&
        newSettings.pauseMultiplier == old.pauseMultiplier;
    if (speedOnly) {
      state = state.copyWith(settings: newSettings);
      unawaited(
        ref
            .read(audioEngineProvider.notifier)
            .setSpeed(newSettings.playbackSpeed),
      );
      return;
    }

    final wasAnnotation = state.isAnnotationMode;
    final annotationWaitingForUser =
        state.repeatFlowState?.phase is WaitingForUser ||
        (_repeatEngine?.willEnterWaitingAfterCurrentPrompt ?? false);
    final blindWaitingForUser =
        state.blindFlowState?.phase is BlindWaitingForUser ||
        _blindEngine.willEnterWaitingAfterCurrentPrompt;
    if (wasAnnotation &&
        _repeatEngine?.willEnterWaitingAfterCurrentPrompt == true) {
      state = state.copyWith(settings: newSettings);
      return;
    }
    if (!wasAnnotation && _blindEngine.willEnterWaitingAfterCurrentPrompt) {
      state = state.copyWith(settings: newSettings);
      return;
    }
    _engine.invalidateSession();
    _blindEngine.stopSession();
    _exitAnnotationMode();
    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: 1,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );
    // 重新开始当前句（跟读模式→重新进入跟读，盲听模式→重新盲听）
    if (wasAnnotation) {
      _startRepeatFlow(autoplay: !annotationWaitingForUser);
    } else {
      await _startBlindFlow(autoplay: !blindWaitingForUser);
    }
  }

  /// 当前句进入手动模式
  void enterManualForSentence() {
    if (state.isManualForSentence) return;
    state = state.copyWith(isManualForSentence: true);
    if (state.isAnnotationMode) {
      _repeatEngine?.enterWaitingForUser();
    } else {
      unawaited(_blindEngine.restartCurrentSentence(autoplay: false));
    }
  }

  /// 获取当前句子索引
  int get currentIndex => state.currentSentenceIndex;

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 跟读流程引擎（跟读模式时有值，供 Screen 读取 engine API）
  RepeatFlowEngine? get repeatEngine => _repeatEngine;

  /// 开始播放
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startBlindFlow();
  }

  /// 外部中断通知
  void notifyExternalStop() {
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 暂停
  void pause() {
    _engine.invalidateSession();
    if (state.isAnnotationMode) {
      _repeatEngine?.enterWaitingForUser();
    } else {
      _blindEngine.enterWaitingForUser();
    }
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      _repeatEngine?.replayCurrentSentence();
      return;
    }
    await _blindEngine.replayCurrentSentence();
  }

  /// 进入跟读模式（听不懂）
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;

    _engine.invalidateSession();
    _blindEngine.stopSession();
    _startRepeatFlow();
  }

  /// 跳过跟读
  Future<void> skipShadowReading() async {
    _exitAnnotationMode();
    state = state.copyWith(
      isAnnotationMode: false,
      isPlaying: false,
      isPauseBetweenPlays: false,
    );
    await _advanceAfterAnnotationCompleted();
  }

  /// 偷看字幕
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 盲听模式下，用户显式接管流程（设置/偷看/查词）。
  void enterWaitingForUserInBlindMode() {
    if (state.isAnnotationMode) return;
    _blindEngine.enterWaitingForUser(afterCurrentPrompt: true);
  }

  /// 取消难句标记
  Sentence? removeDifficultMark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();
    _blindEngine.stopSession();
    _exitAnnotationMode();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(isPlaying: false, totalSentences: 0);
      return removed;
    }

    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      currentPlayCount: 1,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );

    return removed;
  }

  /// 切换收藏标记
  Future<void> toggleCurrentBookmark(String audioItemId) async {
    if (_sentences.isEmpty) return;
    final idx = state.currentSentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.isBookmarked;
    _sentences[idx] = s.copyWith(isBookmarked: !s.isBookmarked);
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (wasBookmarked) {
      await bookmarkDao.removeBookmark(audioItemId, s.index);
      return;
    }

    await BookmarkManager.addBookmarkToDb(audioItemId, s, dao: bookmarkDao);
  }

  /// 同步录音控制器模式，并在切到手动模式时取消活跃录音。
  void syncRecordingMode() {
    final controller = ref.read(speechRecordingControllerProvider.notifier);
    controller.setManualMode(state.isManualMode);

    if (!state.isManualMode) return;

    final recState = ref.read(speechRecordingControllerProvider);
    if (recState.phase == SpeechRecordingPhase.awaitingSpeech ||
        recState.phase == SpeechRecordingPhase.speaking) {
      unawaited(controller.cancelActiveRecording());
    }
  }

  /// 下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;
    _engine.invalidateSession();
    _exitAnnotationMode();
    _blindEngine.stopSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isManualForSentence: false,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );
    await _startBlindFlow();
  }

  /// 上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;
    _engine.invalidateSession();
    _exitAnnotationMode();
    _blindEngine.stopSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isManualForSentence: false,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );
    await _startBlindFlow();
  }

  /// 暂停盲听倒计时
  void pauseCountdown() {
    _blindEngine.pauseInterval();
  }

  /// 恢复盲听倒计时
  void resumeCountdown() {
    _blindEngine.resumeInterval();
  }

  /// 盲听倒计时快进（动态速度，~1.5 秒内结束）
  void toggleCountdownFastForward() {
    final isFF = !state.isCountdownFastForward;
    if (isFF) {
      _blindEngine.fastForwardInterval();
    } else {
      _blindEngine.setIntervalSpeed(1.0);
    }
    if (state.isCountdownPaused) _blindEngine.resumeInterval();
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 倒计时期间重播
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    if (state.isAnnotationMode) {
      _repeatEngine?.replayCurrentSentence();
    } else {
      await _blindEngine.replayCurrentSentence();
    }
  }

  /// 停止播放
  void stopPlayback() {
    _engine.invalidateSession();
    _blindEngine.stopSession();
    _exitAnnotationMode();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      clearBlindFlowState: true,
    );
  }

  /// 释放资源
  void disposePlayer() {
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(null);
    ref.read(audioEngineProvider.notifier).setRecorder(null);
    _engine.cleanup();
    _blindEngine.stopSession();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  /// 重置到第一句
  Future<void> resetToStart() async {
    _engine.cleanup();
    _blindEngine.stopSession();
    _exitAnnotationMode();
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );
    _prepareBlindFlow();
    await startPlaying();
  }

  // ========== 跟读模式（RepeatFlowEngine） ==========

  /// 启动跟读流程引擎
  void _startRepeatFlow({bool autoplay = true}) {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    // 创建或复用引擎
    _repeatEngine ??= RepeatFlowEngine(
      onStateChanged: _onRepeatFlowStateChanged,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () => ref.read(audioEngineProvider.notifier).pause(),
        playSentence: _playSentenceForRepeat,
        startRecording: _startRecordingForRepeat,
        cancelRecording: _cancelRecordingForRepeat,
        stopAndEvaluate: _stopAndEvaluateForRepeat,
        clearRecording: _clearRecordingForRepeat,
        setMaxRecordingDuration: _setMaxRecordingDuration,
        hasDetectedSpeech: _hasDetectedSpeech,
      ),
      logTag: 'RDP-Repeat',
    );

    final session = ref.read(learningSessionProvider);

    _repeatEngine!.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: session.audioItemId ?? '',
        promptIdPrefix: 'rdp',
        getRepeatCount: (_) => state.targetRepeatCount,
        getIntervalDuration: (s) => listenAndRepeatPauseCalculator(s.duration),
        isManualMode: () => state.isManualMode,
      ),
    );

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: autoplay,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      stepFinished: false,
    );

    if (autoplay) {
      unawaited(_repeatEngine!.startPlaying());
    } else {
      unawaited(_repeatEngine!.restartCurrentSentence(autoplay: false));
    }
  }

  /// 跟读引擎状态变化回调
  void _onRepeatFlowStateChanged(RepeatFlowState flowState) {
    state = state.copyWith(
      repeatFlowState: flowState,
      currentPlayCount: flowState.repeatIndex + 1,
      isPlaying: flowState.phase is PlayingPrompt,
      isPauseBetweenPlays: flowState.isInPause,
    );

    // 会话完成 → 退出跟读模式 → 直接进入下一句
    if (flowState.phase is SessionCompleted) {
      _exitAnnotationMode();
      state = state.copyWith(
        isAnnotationMode: false,
        isPlaying: false,
        isPauseBetweenPlays: false,
        clearRepeatFlowState: true,
      );
      AppLogger.log('RDP', '跟读完成 → 直接进入下一句');
      unawaited(_advanceAfterAnnotationCompleted());
    }
  }

  /// 退出跟读模式（停止引擎）
  void _exitAnnotationMode() {
    _repeatEngine?.stopSession();
  }

  /// 录音状态变化 → 桥接到跟读引擎
  void _onRecordingStateChanged(
    SpeechRecordingState? prev,
    SpeechRecordingState next,
  ) {
    if (prev == null || !state.isAnnotationMode || _repeatEngine == null) {
      return;
    }

    // 评估完成（有 ASR: processing→idle，无 ASR: speaking→idle）
    if (prev.phase != SpeechRecordingPhase.idle &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt != null) {
      final attempt = next.currentAttempt!;
      _repeatEngine!.onRecordingFinished(attempt.filePath, attempt.score);
      ref.read(analyticsServiceProvider).track(Events.recordingComplete, {
        ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
        EventParams.mode: 'difficult_practice',
        if (attempt.score != null) EventParams.score: attempt.score!,
      });
    }

    // 录音取消/超时
    if (_repeatEngine!.state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null) {
      _repeatEngine!.onRecordingCancelled();
    }
  }

  // ========== 跟读引擎回调实现 ==========

  Future<void> _playSentenceForRepeat(Sentence sentence, int flowToken) async {
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
  }

  void _startRecordingForRepeat({
    required String promptId,
    required String referenceText,
    required Duration maxDuration,
    Duration? referenceDuration,
  }) {
    final controller = ref.read(speechRecordingControllerProvider.notifier);
    controller.setMaxRecordingDuration(maxDuration);
    unawaited(
      controller.startRecording(
        promptId: promptId,
        referenceText: referenceText,
        referenceDuration: referenceDuration,
      ),
    );
  }

  Future<void> _cancelRecordingForRepeat() async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .cancelActiveRecording();
  }

  Future<void> _stopAndEvaluateForRepeat({
    required String referenceText,
  }) async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .stopAndEvaluate(referenceText: referenceText);
  }

  void _clearRecordingForRepeat() {
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
  }

  void _setMaxRecordingDuration(Duration duration) {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setMaxRecordingDuration(duration);
  }

  bool _hasDetectedSpeech() {
    return ref.read(speechRecordingControllerProvider).hasDetectedSpeech;
  }

  // ========== 盲听模式（BlindPracticeFlowEngine） ==========

  /// 准备盲听引擎当前句数据。
  void _prepareBlindFlow({int? startIndex}) {
    _blindEngine.prepare(
      sentences: _sentences,
      startIndex: startIndex ?? state.currentSentenceIndex,
      config: BlindPracticeFlowConfig(
        getRepeatCount: (_) =>
            state.isManualMode ? 1 : state.settings.blindListenRepeatCount,
        getRepeatIntervalDuration: (sentence) =>
            listenAndRepeatPauseCalculator(sentence.duration),
        getSentenceIntervalDuration: (sentence) =>
            state.settings.calculateInterSentencePause(sentence.duration),
        onSentencePlayed: _recorder.onSentencePlayed,
      ),
    );
  }

  /// 启动盲听流程。
  Future<void> _startBlindFlow({bool autoplay = true}) async {
    if (_sentences.isEmpty) return;
    _prepareBlindFlow();
    _persistCurrentSentenceIndexAsync();
    if (autoplay) {
      await _blindEngine.startPlaying();
      return;
    }
    await _blindEngine.restartCurrentSentence(autoplay: false);
  }

  /// 盲听引擎状态变化回调。
  void _onBlindFlowStateChanged(BlindPracticeFlowState flowState) {
    final previousIndex = state.currentSentenceIndex;
    final phase = flowState.phase;
    final interval = phase is BlindWaitingInterval ? phase : null;
    final sentenceChanged = previousIndex != flowState.sentenceIndex;

    state = state.copyWith(
      blindFlowState: flowState,
      currentSentenceIndex: flowState.sentenceIndex,
      currentPlayCount: flowState.repeatIndex + 1,
      isPlaying: phase is BlindPlayingPrompt,
      isPauseBetweenPlays: interval != null,
      isPauseBetweenSentences: interval?.isBetweenSentences ?? false,
      pauseDuration: interval?.total ?? Duration.zero,
      pauseRemaining: interval?.remaining ?? Duration.zero,
      isCountdownPaused: interval?.isPaused ?? false,
      isCountdownFastForward: interval == null
          ? false
          : state.isCountdownFastForward,
      isAnnotationMode: false,
      stepFinished: phase is BlindSessionCompleted,
      isTextRevealed: sentenceChanged ? false : state.isTextRevealed,
      isManualForSentence: sentenceChanged ? false : state.isManualForSentence,
    );

    if (phase is BlindSessionCompleted) {
      _trackDifficultPracticeComplete();
    }

    if (sentenceChanged) {
      _persistCurrentSentenceIndexAsync();
    }
  }

  /// 播放一遍盲听原句。
  Future<bool> _playSentenceForBlind(Sentence sentence, int flowToken) async {
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    return true;
  }

  /// 异步保存断点
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            audioItemId,
            state.currentSentenceIndex,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  /// 跟读完成后直接进入下一句，不回到当前句的盲听倒计时。
  Future<void> _advanceAfterAnnotationCompleted() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;
    if (isLastSentence) {
      state = state.copyWith(
        isPlaying: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        stepFinished: true,
      );
      _trackDifficultPracticeComplete();
      return;
    }

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isAnnotationMode: false,
      isManualForSentence: false,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );
    await _startBlindFlow();
  }

  /// 上报完成事件
  void _trackDifficultPracticeComplete() {
    ref.read(analyticsServiceProvider).track(Events.difficultPracticeComplete, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalDifficultSentences: state.totalSentences,
    });
  }
}

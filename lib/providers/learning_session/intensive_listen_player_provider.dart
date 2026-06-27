/// 精听专用播放器 Provider
///
/// 盲听部分复用 [BlindPracticeFlowEngine]，
/// “看不懂后”的详情部分使用精听专用 annotation phase 状态机。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/study_event_recorder.dart';
import '../../utils/sense_group_timing.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../blind_flow/blind_practice_flow_engine.dart';
import '../blind_flow/blind_practice_flow_phase.dart';
import '../blind_flow/blind_practice_flow_state.dart';
import '../intensive_annotation/intensive_annotation_phase.dart';
import '../intensive_annotation/intensive_annotation_state.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../intensive_listen_prefs_provider.dart';
import '../learning_progress_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';
import 'study_background_playback_mixin.dart';

part 'intensive_listen_player_provider.g.dart';

/// 计算停顿时长（纯函数）
Duration calculatePauseDuration(
  Duration sentenceDuration,
  IntensiveListenSettings settings,
) {
  switch (settings.pauseMode) {
    case PauseMode.smart:
      final ms = 1000 + (sentenceDuration.inMilliseconds * 0.6).round();
      return Duration(milliseconds: ms.clamp(2000, 20000));
    case PauseMode.fixed:
      return Duration(seconds: settings.fixedPauseSeconds);
    case PauseMode.multiplier:
      final ms = (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
          .round();
      return Duration(milliseconds: ms);
  }
}

/// 精听播放器状态
class IntensiveListenState {
  final int currentSentenceIndex;
  final int totalSentences;
  final int currentPlayCount;
  final IntensiveListenSettings settings;
  final bool isPlaying;
  final bool isPauseBetweenPlays;
  final bool isPauseBetweenSentences;
  final Duration pauseRemaining;
  final Duration pauseDuration;
  final Duration annotationReplayRemaining;
  final Duration annotationReplayDuration;
  final bool isAnnotationMode;
  final bool isAnnotationReplay;
  final bool isTextRevealed;
  final Set<int> difficultSentences;
  final bool isCurrentSentenceAutoMarked;
  final bool isCountdownPaused;
  final bool isCountdownFastForward;
  final bool stepFinished;
  final int? playingSenseGroupIndex;
  final Set<int> playedSenseGroupIndices;
  final BlindPracticeFlowState? blindFlowState;
  final IntensiveAnnotationState? annotationState;

  const IntensiveListenState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.settings = const IntensiveListenSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.annotationReplayRemaining = Duration.zero,
    this.annotationReplayDuration = Duration.zero,
    this.isAnnotationMode = false,
    this.isAnnotationReplay = false,
    this.isTextRevealed = false,
    this.difficultSentences = const {},
    this.isCurrentSentenceAutoMarked = false,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
    this.stepFinished = false,
    this.playingSenseGroupIndex,
    this.playedSenseGroupIndices = const {},
    this.blindFlowState,
    this.annotationState,
  });

  static const _sentinel = Object();

  bool get isManualMode => settings.isManualMode;

  IntensiveListenState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    IntensiveListenSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    Duration? annotationReplayRemaining,
    Duration? annotationReplayDuration,
    bool? isAnnotationMode,
    bool? isAnnotationReplay,
    bool? isTextRevealed,
    Set<int>? difficultSentences,
    bool? isCurrentSentenceAutoMarked,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
    bool? stepFinished,
    Object? playingSenseGroupIndex = _sentinel,
    Set<int>? playedSenseGroupIndices,
    Object? blindFlowState = _sentinel,
    Object? annotationState = _sentinel,
  }) {
    return IntensiveListenState(
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
      annotationReplayRemaining:
          annotationReplayRemaining ?? this.annotationReplayRemaining,
      annotationReplayDuration:
          annotationReplayDuration ?? this.annotationReplayDuration,
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay ?? this.isAnnotationReplay,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      difficultSentences: difficultSentences ?? this.difficultSentences,
      isCurrentSentenceAutoMarked:
          isCurrentSentenceAutoMarked ?? this.isCurrentSentenceAutoMarked,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
      stepFinished: stepFinished ?? this.stepFinished,
      playingSenseGroupIndex: playingSenseGroupIndex == _sentinel
          ? this.playingSenseGroupIndex
          : playingSenseGroupIndex as int?,
      playedSenseGroupIndices:
          playedSenseGroupIndices ?? this.playedSenseGroupIndices,
      blindFlowState: blindFlowState == _sentinel
          ? this.blindFlowState
          : blindFlowState as BlindPracticeFlowState?,
      annotationState: annotationState == _sentinel
          ? this.annotationState
          : annotationState as IntensiveAnnotationState?,
    );
  }
}

@Riverpod(keepAlive: true)
class IntensiveListenPlayer extends _$IntensiveListenPlayer
    with StudyBackgroundPlaybackMixin {
  @override
  Ref get bgRef => ref;

  List<Sentence> _sentences = [];
  late StudyEventRecorder _recorder;
  late BlindPracticeFlowEngine _blindEngine;
  final CountdownController _annotationCountdown = CountdownController();

  int _currentSessionId = -1;
  bool _refreshBlindConfigWhenWaiting = false;
  bool _annotationWaitAfterCurrentPlayback = false;

  /// 当前会话的偏好槽位(子阶段×轮次);🔧 面板改动按此槽位持久化。
  /// 逐句精听=`intensiveListen:firstLearn`、难句跟读=`listenAndRepeat:firstLearn`。
  String? _settingsSlot;

  BlindPracticeFlowEngine _createBlindEngine() {
    return BlindPracticeFlowEngine(
      onStateChanged: _onBlindFlowStateChanged,
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () => ref.read(audioEngineProvider.notifier).pause(),
        playSentence: _playSentenceForBlind,
      ),
      logTag: 'IntensiveBlind',
    );
  }

  @override
  IntensiveListenState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.intensiveListen,
    );
    _blindEngine = _createBlindEngine();

    ref.onDispose(() {
      _blindEngine.dispose();
      _annotationCountdown.cancel();
      _currentSessionId = -1;
    });
    return const IntensiveListenState();
  }

  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    IntensiveListenSettings settings = const IntensiveListenSettings(),
    String? settingsSlot,
  }) async {
    _settingsSlot = settingsSlot;
    _blindEngine.dispose();
    _blindEngine = _createBlindEngine();
    _cleanupAnnotationSession();

    _sentences = sentences.map((s) => s.copyWith()).toList();
    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);
    final preBookmarked = <int>{
      for (final (i, s) in _sentences.indexed)
        if (s.isBookmarked) i,
    };

    // [settings] 已由调用方从 intensiveListenPrefs.resolve(smartSpeed) 得出
    // (默认 + 用户记忆覆盖),这里直接 seed,不再有第二份覆盖通道。
    state = IntensiveListenState(
      currentSentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      difficultSentences: preBookmarked,
      settings: settings,
    );
    _prepareBlindFlow(startIndex: safeIndex);

    // 锁屏控制：每任务绑定一次（回调为稳定的 notifier 方法），整段任务期间锁屏
    // 上一句/下一句始终可用；避免「按活跃 phase 条件 bind」在等待/切换瞬间留下
    // 空窗导致切句失灵。会话活跃度（保活 + 图标）由 setSessionActive 单独维护。
    bindLockScreen(
      onPlay: resume,
      onPause: pause,
      onNext: goToNext,
      onPrevious: goToPrevious,
    );

    ref.read(analyticsServiceProvider).track(Events.intensiveListenStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalSentences: _sentences.length,
    });
  }

  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  List<Sentence> get sentences => List.unmodifiable(_sentences);

  int get currentIndex => state.currentSentenceIndex;

  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startBlindFlow();
  }

  Future<void> pause() async {
    if (state.annotationState != null) {
      _cleanupAnnotationSession();
      _setAnnotationPhase(const WaitingAnnotationUser());
      return;
    }

    _blindEngine.enterWaitingForUser();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  Future<void> resume() async {
    if (state.annotationState != null) {
      if (state.annotationState?.phase is ReplayingWithSubtitle) {
        await _startInlineAnnotationReplay();
      }
      return;
    }
    await _blindEngine.replayCurrentSentence();
  }

  Future<void> goToNext() async => goToSentence(state.currentSentenceIndex + 1);

  Future<void> goToPrevious() async =>
      goToSentence(state.currentSentenceIndex - 1);

  /// 跳转到指定句子（0-based）。
  ///
  /// 供进度条拖动跳转使用：越界自动 clamp，目标与当前相同时直接返回，
  /// 避免冗余的 flow 重启。
  Future<void> goToSentence(int index) async {
    if (state.totalSentences <= 0) return;
    final target = index.clamp(0, state.totalSentences - 1);
    if (target == state.currentSentenceIndex) return;
    await _goToSentence(target);
  }

  void enterAnnotationMode() {
    if (state.annotationState != null) return;

    _blindEngine.stopSession();
    _cleanupAnnotationSession();
    ref.read(audioEngineProvider.notifier).pause();

    final newDifficult = Set<int>.from(state.difficultSentences);
    final wasAlreadyDifficult = newDifficult.contains(
      state.currentSentenceIndex,
    );
    newDifficult.add(state.currentSentenceIndex);

    state = state.copyWith(
      difficultSentences: newDifficult,
      isCurrentSentenceAutoMarked: !wasAlreadyDifficult,
      isTextRevealed: false,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );
    _setAnnotationPhase(const InspectingAnnotation());
  }

  Future<void> exitAnnotationMode() async {
    if (state.annotationState == null) return;
    stopSenseGroupPlayback();
    await _startInlineAnnotationReplay();
  }

  /// 盲听模式下用户接管流程。
  void enterWaitingForUserInBlindMode() {
    if (state.annotationState != null) return;
    _blindEngine.enterWaitingForUser(afterCurrentPrompt: true);
  }

  /// 详情模式下用户接管流程。
  void onAnnotationUserInteraction() {
    if (state.annotationState == null) return;

    if (state.playingSenseGroupIndex != null) {
      stopSenseGroupPlayback();
      _setAnnotationPhase(const WaitingAnnotationUser());
      return;
    }

    final phase = state.annotationState!.phase;
    if (phase is ReplayingWithSubtitle) {
      _annotationWaitAfterCurrentPlayback = true;
      AppLogger.log('IntensiveAnnotation', '-> WaitingForUser (after replay)');
      return;
    }
    if (phase is WaitingAnnotationInterval) {
      _annotationCountdown.cancel();
      _setAnnotationPhase(const WaitingAnnotationUser());
      return;
    }
    _setAnnotationPhase(const WaitingAnnotationUser());
  }

  Future<void> replayInAnnotationMode() async {
    if (state.annotationState == null) return;
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    stopSenseGroupPlayback();
    _cleanupAnnotationSession();

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    state = state.copyWith(isPlaying: true);

    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    if (!engine.isActiveSession(sessionId)) {
      state = state.copyWith(isPlaying: false);
      return;
    }

    _recorder.onSentencePlayed(sentence);
    state = state.copyWith(isPlaying: false);
    _setAnnotationPhase(const InspectingAnnotation());
  }

  void toggleDifficultSentence() {
    final idx = state.currentSentenceIndex;
    final newSet = Set<int>.from(state.difficultSentences);
    if (newSet.contains(idx)) {
      newSet.remove(idx);
    } else {
      newSet.add(idx);
    }
    state = state.copyWith(
      difficultSentences: newSet,
      isCurrentSentenceAutoMarked: false,
    );
  }

  Future<void> playSenseGroup(
    Duration start,
    Duration end,
    int groupIndex,
  ) async {
    if (state.annotationState == null) return;
    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    _annotationCountdown.cancel();

    final played = Set<int>.from(state.playedSenseGroupIndices)
      ..add(groupIndex);
    state = state.copyWith(
      playingSenseGroupIndex: groupIndex,
      playedSenseGroupIndices: played,
      isPlaying: true,
    );

    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playRangeOnce(start, end, sessionId);
    if (!engine.isActiveSession(sessionId)) return;

    state = state.copyWith(playingSenseGroupIndex: null, isPlaying: false);
  }

  void stopSenseGroupPlayback() {
    if (state.playingSenseGroupIndex == null) return;
    _cleanupAnnotationSession();
    state = state.copyWith(playingSenseGroupIndex: null, isPlaying: false);
  }

  Future<void> playAllSenseGroups(List<SenseGroupTiming> timings) async {
    if (state.annotationState == null || timings.isEmpty) return;
    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    _annotationCountdown.cancel();

    state = state.copyWith(isPlaying: true);
    await engine.setSpeed(state.settings.playbackSpeed);
    for (var i = 0; i < timings.length; i++) {
      if (!engine.isActiveSession(sessionId)) return;

      final timing = timings[i];
      final played = Set<int>.from(state.playedSenseGroupIndices)..add(i);
      state = state.copyWith(
        playingSenseGroupIndex: i,
        playedSenseGroupIndices: played,
      );

      await engine.playRangeOnce(timing.start, timing.end, sessionId);
      if (!engine.isActiveSession(sessionId)) return;

      if (i < timings.length - 1) {
        state = state.copyWith(playingSenseGroupIndex: null);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    if (!engine.isActiveSession(sessionId)) return;
    state = state.copyWith(playingSenseGroupIndex: null, isPlaying: false);
  }

  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  void pauseCountdown() {
    if (state.annotationState != null) {
      final phase = state.annotationState?.phase;
      if (phase is WaitingAnnotationInterval) {
        _annotationCountdown.pause();
        _setAnnotationPhase(phase.copyWith(isPaused: true));
      }
      return;
    }
    _blindEngine.pauseInterval();
  }

  void resumeCountdown() {
    if (state.annotationState != null) {
      final phase = state.annotationState?.phase;
      if (phase is WaitingAnnotationInterval) {
        _annotationCountdown.resume();
        _setAnnotationPhase(phase.copyWith(isPaused: false));
      }
      return;
    }
    _blindEngine.resumeInterval();
  }

  void toggleCountdownFastForward() {
    if (state.annotationState != null) {
      final phase = state.annotationState?.phase;
      if (phase is! WaitingAnnotationInterval) return;
      final isFF = !state.isCountdownFastForward;
      if (isFF) {
        _annotationCountdown.fastForward();
      } else {
        _annotationCountdown.setSpeed(1.0);
      }
      if (phase.isPaused) {
        _annotationCountdown.resume();
      }
      state = state.copyWith(
        isCountdownFastForward: isFF,
        isCountdownPaused: false,
      );
      return;
    }

    final isFF = !state.isCountdownFastForward;
    if (isFF) {
      _blindEngine.fastForwardInterval();
    } else {
      _blindEngine.setIntervalSpeed(1.0);
    }
    if (state.isCountdownPaused) {
      _blindEngine.resumeInterval();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  Future<void> replayDuringCountdown() async {
    if (state.annotationState != null) {
      _cleanupAnnotationSession();
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        annotationReplayRemaining: Duration.zero,
        annotationReplayDuration: Duration.zero,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
      await _startInlineAnnotationReplay();
      return;
    }

    await _blindEngine.replayCurrentSentence();
  }

  /// 把 🔧 面板的改动持久化到用户偏好(与入口弹窗同一份 store)。
  ///
  /// 只把相对旧设置**真正变化**的字段写进偏好:每个面板交互只改一个字段,
  /// 故只会把该字段从「未设(用默认)」变成具体值,不冻结未碰过的智能默认。
  void _persistChangedPrefs(
    IntensiveListenSettings oldSettings,
    IntensiveListenSettings newSettings,
  ) {
    final slot = _settingsSlot;
    if (slot == null) return;
    persistIntensiveSettingsDiff(
      ref.read(intensiveListenPrefsProvider.notifier),
      slot,
      oldSettings,
      newSettings,
    );
  }

  void updateSettings(IntensiveListenSettings newSettings) {
    _persistChangedPrefs(state.settings, newSettings);
    var clampedPlayCount = state.currentPlayCount;
    if (clampedPlayCount > newSettings.repeatCount) {
      clampedPlayCount = newSettings.repeatCount;
    }

    final oldSettings = state.settings;
    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: clampedPlayCount,
    );

    if (state.annotationState != null) {
      return;
    }

    if (_blindEngine.willEnterWaitingAfterCurrentPrompt) {
      _refreshBlindConfigWhenWaiting = true;
      return;
    }

    if (state.blindFlowState?.phase is BlindWaitingForUser) {
      unawaited(_refreshBlindFlowWaitingState());
      return;
    }

    final modeChanged = newSettings.isManualMode != oldSettings.isManualMode;
    final repeatChanged = newSettings.repeatCount != oldSettings.repeatCount;
    if (modeChanged || repeatChanged) {
      _blindEngine.stopSession();
      unawaited(_startBlindFlow());
    }
  }

  void stopPlayback() {
    _blindEngine.stopSession();
    _cleanupAnnotationSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      stepFinished: false,
      blindFlowState: null,
      annotationState: null,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );
  }

  Future<void> resetToStart() async {
    _blindEngine.stopSession();
    _cleanupAnnotationSession();
    state = state.copyWith(
      currentSentenceIndex: 0,
      currentPlayCount: 1,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      stepFinished: false,
      blindFlowState: null,
      annotationState: null,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );
    await _startBlindFlow();
  }

  void disposePlayer() {
    unbindLockScreen();
    _blindEngine.stopSession();
    _cleanupAnnotationSession();
    _sentences = [];
    state = const IntensiveListenState();
  }

  void _prepareBlindFlow({int? startIndex}) {
    _blindEngine.prepare(
      sentences: _sentences,
      startIndex: startIndex ?? state.currentSentenceIndex,
      config: BlindPracticeFlowConfig(
        getRepeatCount: (_) =>
            state.settings.isManualMode ? 1 : state.settings.repeatCount,
        getRepeatIntervalDuration: (sentence) =>
            calculatePauseDuration(sentence.duration, state.settings),
        getSentenceIntervalDuration: (sentence) =>
            calculatePauseDuration(sentence.duration, state.settings),
        onSentencePlayed: _recorder.onSentencePlayed,
        isManualMode: () => state.settings.isManualMode,
      ),
    );
  }

  Future<void> _startBlindFlow({bool autoplay = true}) async {
    if (_sentences.isEmpty) return;
    _prepareBlindFlow();
    if (autoplay) {
      await _blindEngine.startPlaying();
      return;
    }
    await _blindEngine.restartCurrentSentence(autoplay: false);
  }

  Future<void> _refreshBlindFlowWaitingState() async {
    if (_sentences.isEmpty) return;
    _prepareBlindFlow(startIndex: state.currentSentenceIndex);
    await _blindEngine.restartCurrentSentence(autoplay: false);
  }

  void _onBlindFlowStateChanged(BlindPracticeFlowState flowState) {
    final phase = flowState.phase;
    final interval = phase is BlindWaitingInterval ? phase : null;
    final sentenceChanged =
        flowState.sentenceIndex != state.currentSentenceIndex;

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
      isAnnotationReplay: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      annotationState: null,
      isTextRevealed: sentenceChanged ? false : state.isTextRevealed,
      stepFinished: phase is BlindSessionCompleted,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );

    // 会话活跃度：播放中或停顿倒计时即活跃 → 保活（iOS 静音轨）+ 锁屏图标显示「播放中」；
    // 等待用户/完成时不活跃 → 停保活、图标转暂停。回调槽已在 initialize 绑定一次，此处不再动。
    final active = phase is BlindPlayingPrompt || phase is BlindWaitingInterval;
    setSessionActive(active);

    if (phase is BlindWaitingForUser && _refreshBlindConfigWhenWaiting) {
      _refreshBlindConfigWhenWaiting = false;
      unawaited(_refreshBlindFlowWaitingState());
      return;
    }

    if (phase is BlindSessionCompleted) {
      ref.read(analyticsServiceProvider).track(Events.intensiveListenComplete, {
        ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
        EventParams.totalSentences: state.totalSentences,
        EventParams.difficultCount: state.difficultSentences.length,
      });
    }
  }

  Future<bool> _playSentenceForBlind(Sentence sentence, int flowToken) async {
    if (sentence.duration <= Duration.zero) return false;
    _persistCurrentSentenceIndexAsync();
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    return true;
  }

  Future<void> _goToSentence(int sentenceIndex) async {
    _blindEngine.stopSession();
    _cleanupAnnotationSession();

    state = state.copyWith(
      currentSentenceIndex: sentenceIndex,
      currentPlayCount: 1,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      blindFlowState: null,
      annotationState: null,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
      stepFinished: false,
    );

    await _startBlindFlow();
  }

  Future<void> _startInlineAnnotationReplay() async {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) {
      await _finishAnnotationReplay();
      return;
    }

    stopSenseGroupPlayback();
    _cleanupAnnotationSession();
    _annotationWaitAfterCurrentPlayback = false;
    _setAnnotationPhase(
      ReplayingWithSubtitle(
        remaining: sentence.duration,
        total: sentence.duration,
      ),
    );

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    if (!engine.isActiveSession(sessionId)) {
      state = state.copyWith(isPlaying: false);
      return;
    }

    _recorder.onSentencePlayed(sentence);
    await _finishAnnotationReplay();
  }

  Future<void> _finishAnnotationReplay() async {
    if (_annotationWaitAfterCurrentPlayback) {
      _annotationWaitAfterCurrentPlayback = false;
      _setAnnotationPhase(const WaitingAnnotationUser());
      return;
    }

    if (state.settings.isManualMode) {
      state = state.copyWith(
        isAnnotationMode: false,
        isAnnotationReplay: false,
        isPlaying: false,
        annotationReplayRemaining: Duration.zero,
        annotationReplayDuration: Duration.zero,
        annotationState: null,
      );
      return;
    }

    final sentence = currentSentence;
    final pauseDur = sentence != null
        ? calculatePauseDuration(sentence.duration, state.settings)
        : const Duration(seconds: 1);
    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    _setAnnotationPhase(
      WaitingAnnotationInterval(remaining: pauseDur, total: pauseDur),
    );

    await _annotationCountdown.start(pauseDur);

    if (!engine.isActiveSession(sessionId)) return;

    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;
    if (isLastSentence) {
      state = state.copyWith(
        isPlaying: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        annotationReplayRemaining: Duration.zero,
        annotationReplayDuration: Duration.zero,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        stepFinished: true,
        annotationState: null,
        playingSenseGroupIndex: null,
        playedSenseGroupIndices: const {},
      );
      ref.read(analyticsServiceProvider).track(Events.intensiveListenComplete, {
        ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
        EventParams.totalSentences: state.totalSentences,
        EventParams.difficultCount: state.difficultSentences.length,
      });
      return;
    }

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      pauseRemaining: Duration.zero,
      pauseDuration: Duration.zero,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      annotationState: null,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      stepFinished: false,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );
    unawaited(_startBlindFlow());
  }

  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            audioItemId,
            state.currentSentenceIndex,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  void _cleanupAnnotationSession() {
    _annotationCountdown.cancel();
    _currentSessionId = -1;
    _annotationWaitAfterCurrentPlayback = false;
    ref.read(audioEngineProvider.notifier).pause();
  }

  void _setAnnotationPhase(IntensiveAnnotationPhase phase) {
    final waitingInterval = phase is WaitingAnnotationInterval ? phase : null;
    final replaying = phase is ReplayingWithSubtitle ? phase : null;
    final isSenseGroupPlaying = state.playingSenseGroupIndex != null;

    state = state.copyWith(
      annotationState: IntensiveAnnotationState(phase: phase),
      isAnnotationMode: true,
      isAnnotationReplay: replaying != null,
      isPlaying: replaying != null || isSenseGroupPlaying,
      isPauseBetweenPlays: waitingInterval != null,
      isPauseBetweenSentences: waitingInterval != null,
      pauseDuration: waitingInterval?.total ?? Duration.zero,
      pauseRemaining: waitingInterval?.remaining ?? Duration.zero,
      annotationReplayRemaining: replaying?.remaining ?? Duration.zero,
      annotationReplayDuration: replaying?.total ?? Duration.zero,
      isCountdownPaused: waitingInterval?.isPaused ?? false,
      isCountdownFastForward: waitingInterval == null
          ? false
          : state.isCountdownFastForward,
      blindFlowState: null,
      stepFinished: false,
    );
  }
}

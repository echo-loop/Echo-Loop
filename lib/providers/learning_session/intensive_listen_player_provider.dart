/// 精听专用播放器 Provider
///
/// 盲听部分复用 [BlindPracticeFlowEngine]，
/// “看不懂后”的详情部分使用精听专用 annotation phase 状态机。
library;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/study_stage.dart';
import '../../models/sentence_playback_result.dart';
import '../../services/app_logger.dart';
import '../../services/study_session_timer.dart';
import '../../services/study_time_service.dart';
import '../../utils/sense_group_timing.dart';
import '../media_engine/media_engine_provider.dart';
import '../blind_flow/blind_practice_flow_engine.dart';
import '../blind_flow/blind_practice_flow_phase.dart';
import '../blind_flow/blind_practice_flow_state.dart';
import '../intensive_annotation/intensive_annotation_phase.dart';
import '../intensive_annotation/intensive_annotation_state.dart';
import '../intensive_listen_prefs_provider.dart';
import '../learning_progress_provider.dart';
import '../learning_settings_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';
import 'intensive_listen_playback_driver.dart';

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

  /// 当前材料是否有视频画面；音频和视频都通过 MediaEngine 播放。
  final bool hasVideo;
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
    this.hasVideo = false,
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
    bool? hasVideo,
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
      hasVideo: hasVideo ?? this.hasVideo,
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
class IntensiveListenPlayer extends _$IntensiveListenPlayer {
  List<Sentence> _sentences = [];
  late BlindPracticeFlowEngine _blindEngine;
  final CountdownController _annotationCountdown = CountdownController();
  late IntensiveListenPlaybackDriver _playbackDriver;
  late StudyTimeService _studyTimeService;
  SenseGroupRangePlayback? _senseGroupRangePlayback;
  StudySessionTimer? _studySessionTimer;
  Future<void>? _disposePlayerInFlight;

  int _annotationSessionId = -1;
  bool _refreshBlindConfigWhenWaiting = false;
  bool _annotationWaitAfterCurrentPlayback = false;
  Duration? _blindResumePosition;
  Duration? _annotationResumePosition;
  int? _annotationResumePlayCount;

  /// 标识当前讲解页整句重播会话，避免把区间试听误认为整句播放。
  int? _annotationSentencePlaybackSessionId;

  /// 当前会话的偏好槽位(子阶段×轮次);🔧 面板改动按此槽位持久化。
  /// 逐句精听=`intensiveListen:firstLearn`、难句跟读=`listenAndRepeat:firstLearn`。
  String? _settingsSlot;

  BlindPracticeFlowEngine _createBlindEngine() {
    return BlindPracticeFlowEngine(
      onStateChanged: _onBlindFlowStateChanged,
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: _playbackDriver.pause,
        playSentence: _playSentenceForBlind,
        resumeSentence: _resumeSentenceForBlind,
      ),
      logTag: 'IntensiveBlind',
    );
  }

  @override
  IntensiveListenState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    _playbackDriver = MediaSentencePlaybackDriver(
      ref.read(mediaEngineProvider.notifier),
    );
    _blindEngine = _createBlindEngine();

    ref.onDispose(() {
      _blindEngine.dispose();
      _annotationCountdown.cancel();
      _annotationSessionId = -1;
      unawaited(_disposeStudySessionTimer());
    });
    return const IntensiveListenState();
  }

  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    IntensiveListenSettings settings = const IntensiveListenSettings(),
    String? settingsSlot,
    IntensiveListenPlaybackDriver? playbackDriver,
    SenseGroupRangePlayback? senseGroupRangePlayback,
    bool hasVideo = false,
  }) async {
    await _disposeStudySessionTimer();
    _playbackDriver =
        playbackDriver ??
        MediaSentencePlaybackDriver(ref.read(mediaEngineProvider.notifier));
    _senseGroupRangePlayback = senseGroupRangePlayback;
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
      hasVideo: hasVideo,
    );
    final timer = StudySessionTimer(
      studyTimeService: _studyTimeService,
      stage: StudyStage.intensiveListen,
      activityGate: ref.read(studyActivityGateProvider),
      idleTimeout: const Duration(minutes: 2),
      logScope: 'IntensiveListenTimer',
    );
    _studySessionTimer = timer;
    timer.start();
    _prepareBlindFlow(startIndex: safeIndex);

    // 锁屏控制：每任务绑定一次（回调为稳定的 notifier 方法），整段任务期间锁屏
    // 上一句/下一句始终可用；避免「按活跃 phase 条件 bind」在等待/切换瞬间留下
    // 空窗导致切句失灵。会话活跃度（保活 + 图标）由 setSessionActive 单独维护。
    _playbackDriver.bindLockScreen(
      onPlay: resume,
      onPause: pause,
      onNext: goToNext,
      onPrevious: goToPrevious,
    );

    AppLogger.log(
      'IntensivePlayer',
      'event=initialized itemId=${ref.read(learningSessionProvider).audioItemId} '
          'mediaType=${hasVideo ? 'video' : 'audio'} totalSentences=${_sentences.length} '
          'startIndex=$safeIndex speed=${settings.playbackSpeed} '
          'repeatCount=${settings.repeatCount} manual=${settings.isManualMode}',
    );

    ref.read(analyticsServiceProvider).track(Events.intensiveListenStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalSentences: _sentences.length,
    });
  }

  /// 将设置中的速度同步到当前会话实际使用的播放链路。
  Future<void> applyPlaybackSpeed(double speed) {
    AppLogger.log(
      'IntensivePlayer',
      'event=speed-update speed=$speed sentenceIndex=${state.currentSentenceIndex}',
    );
    return _playbackDriver.setSpeed(speed);
  }

  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  List<Sentence> get sentences => List.unmodifiable(_sentences);

  int get currentIndex => state.currentSentenceIndex;

  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      AppLogger.log(
        'IntensivePlayer',
        'event=start-ignored reason=no-sentences',
      );
      return;
    }
    AppLogger.log(
      'IntensivePlayer',
      'event=start-request sentenceIndex=${state.currentSentenceIndex} '
          'totalSentences=${state.totalSentences}',
    );
    await _startBlindFlow();
  }

  Future<void> pause() async {
    AppLogger.log(
      'IntensivePlayer',
      'event=pause-request sentenceIndex=${state.currentSentenceIndex} '
          'isPlaying=${state.isPlaying} annotation=${state.annotationState != null}',
    );
    if (state.annotationState != null) {
      _annotationResumePosition = null;
      _annotationResumePlayCount = null;
      final sentence = currentSentence;
      final position = _playbackDriver.currentPosition;
      if (state.isPlaying &&
          _annotationSentencePlaybackSessionId == _annotationSessionId &&
          sentence != null &&
          position >= sentence.startTime &&
          position < sentence.endTime) {
        _annotationResumePosition = position;
        _annotationResumePlayCount = state.currentPlayCount;
      }
      _cleanupAnnotationSession();
      _setAnnotationPhase(const WaitingAnnotationUser());
      return;
    }

    _blindResumePosition = null;
    final sentence = currentSentence;
    final position = _playbackDriver.currentPosition;
    if (sentence != null &&
        position >= sentence.startTime &&
        position < sentence.endTime) {
      _blindResumePosition = position;
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
    AppLogger.log(
      'IntensivePlayer',
      'event=resume-request sentenceIndex=${state.currentSentenceIndex} '
          'annotation=${state.annotationState != null}',
    );
    if (state.annotationState != null) {
      final resumePosition = _annotationResumePosition;
      if (resumePosition == null) return;
      final resumePlayCount = _annotationResumePlayCount;
      _annotationResumePosition = null;
      _annotationResumePlayCount = null;
      await _startInlineAnnotationReplay(
        repeatCount: _annotationReplayRepeatCount,
        advanceAfterReplay: false,
        showReplayStatus: true,
        startAt: resumePosition,
        startingPlayCount: resumePlayCount,
      );
      return;
    }
    final resumePosition = _blindResumePosition;
    _blindResumePosition = null;
    if (resumePosition != null) {
      await _blindEngine.resumeCurrentSentence(resumePosition);
    } else {
      await _blindEngine.replayCurrentSentence();
    }
  }

  /// 当前播放模式自己的暂停位置，避免跨模式的旧检查点误导播放按钮分支。
  bool get hasPausedPlaybackPosition => state.annotationState != null
      ? _annotationResumePosition != null
      : _blindResumePosition != null;

  Future<void> goToNext() async => goToSentence(state.currentSentenceIndex + 1);

  /// 切换到上一句；停顿期间也按当前句索引导航，不重播当前句。
  Future<void> goToPrevious() async {
    await goToSentence(state.currentSentenceIndex - 1);
  }

  /// 跳转到指定句子（0-based）。
  ///
  /// 供进度条拖动跳转使用：越界自动 clamp，目标与当前相同时直接返回，
  /// 避免冗余的 flow 重启。
  Future<void> goToSentence(int index) async {
    if (state.totalSentences <= 0) {
      AppLogger.log(
        'IntensivePlayer',
        'event=navigate-ignored targetIndex=$index reason=no-sentences',
      );
      return;
    }
    final target = index.clamp(0, state.totalSentences - 1);
    if (target == state.currentSentenceIndex) {
      AppLogger.log(
        'IntensivePlayer',
        'event=navigate-ignored targetIndex=$target reason=already-current',
      );
      return;
    }
    AppLogger.log(
      'IntensivePlayer',
      'event=navigate-request fromIndex=${state.currentSentenceIndex} '
          'toIndex=$target totalSentences=${state.totalSentences}',
    );
    await _goToSentence(target);
  }

  /// 提交讲解页自动翻页。
  ///
  /// 讲解页倒计时结束后，页面先完成分页动画，再调用此方法切换业务状态，
  /// 避免旧页面在动画期间因状态变化闪回盲听内容。
  Future<void> commitPendingAnnotationAdvance(int targetSentenceIndex) async {
    final phase = state.annotationState?.phase;
    if (phase is! WaitingAnnotationPageTransition ||
        phase.targetSentenceIndex != targetSentenceIndex ||
        targetSentenceIndex < 0 ||
        targetSentenceIndex >= state.totalSentences) {
      return;
    }
    await _goToSentence(targetSentenceIndex);
  }

  void enterAnnotationMode() {
    if (state.annotationState != null) return;

    // 进入讲解页后，盲听断点不再代表讲解回放的暂停位置。
    _clearPlaybackResumePositions();
    _blindEngine.stopSession();
    _cleanupAnnotationSession();
    _playbackDriver.pause();

    // 「听不太懂」自动收藏受学习设置控制；关闭时只进入讲解，不改收藏状态。
    // 持久化靠对比 difficultSentences 完成，因此不加入即不写库。
    final autoFavoriteEnabled = ref
        .read(learningSettingsProvider)
        .autoFavoriteOnCantUnderstand;
    final newDifficult = Set<int>.from(state.difficultSentences);
    final wasAlreadyDifficult = newDifficult.contains(
      state.currentSentenceIndex,
    );
    final shouldAutoFavorite = autoFavoriteEnabled && !wasAlreadyDifficult;
    if (shouldAutoFavorite) {
      newDifficult.add(state.currentSentenceIndex);
    }

    state = state.copyWith(
      difficultSentences: newDifficult,
      isCurrentSentenceAutoMarked: shouldAutoFavorite,
      isTextRevealed: false,
      playingSenseGroupIndex: null,
      playedSenseGroupIndices: const {},
    );
    _setAnnotationPhase(const InspectingAnnotation());
  }

  Future<void> exitAnnotationMode() async {
    if (state.annotationState == null ||
        state.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }
    stopSenseGroupPlayback();
    // “继续”始终只重播一次，再沿用原有自动推进流程。
    await _startInlineAnnotationReplay(
      repeatCount: 1,
      advanceAfterReplay: true,
      showReplayStatus: true,
    );
  }

  /// 盲听模式下用户接管流程。
  void enterWaitingForUserInBlindMode() {
    if (state.annotationState != null) return;
    _blindEngine.enterWaitingForUser(afterCurrentPrompt: true);
  }

  /// 详情模式下用户接管流程。
  void onAnnotationUserInteraction() {
    if (state.annotationState == null) return;

    if (state.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }

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
    _annotationResumePosition = null;
    _annotationResumePlayCount = null;
    if (state.annotationState == null ||
        state.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }
    await _startInlineAnnotationReplay(
      repeatCount: _annotationReplayRepeatCount,
      advanceAfterReplay: false,
      showReplayStatus: false,
    );
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
    _annotationResumePosition = null;
    _annotationResumePlayCount = null;
    _annotationSentencePlaybackSessionId = null;
    final playbackDriver = _playbackDriver;
    _annotationSessionId = playbackDriver.newSession();
    final annotationSessionId = _annotationSessionId;
    _annotationCountdown.cancel();

    final played = Set<int>.from(state.playedSenseGroupIndices)
      ..add(groupIndex);
    state = state.copyWith(
      playingSenseGroupIndex: groupIndex,
      playedSenseGroupIndices: played,
      isPlaying: true,
    );

    await playbackDriver.setSpeed(state.settings.playbackSpeed);
    await playbackDriver.playRangeOnce(start, end, annotationSessionId);
    if (!playbackDriver.isActiveSession(annotationSessionId)) return;

    state = state.copyWith(playingSenseGroupIndex: null, isPlaying: false);
  }

  /// 讲解页意群试听使用的区间播放器，由精听入口按当前媒体引擎注入。
  SenseGroupRangePlayback? get senseGroupRangePlayback =>
      _senseGroupRangePlayback;

  void stopSenseGroupPlayback() {
    if (state.playingSenseGroupIndex == null) return;
    _cleanupAnnotationSession();
    state = state.copyWith(playingSenseGroupIndex: null, isPlaying: false);
  }

  Future<void> playAllSenseGroups(List<SenseGroupTiming> timings) async {
    if (state.annotationState == null || timings.isEmpty) return;
    _annotationResumePosition = null;
    _annotationResumePlayCount = null;
    _annotationSentencePlaybackSessionId = null;
    final playbackDriver = _playbackDriver;
    _annotationSessionId = playbackDriver.newSession();
    final annotationSessionId = _annotationSessionId;
    _annotationCountdown.cancel();

    state = state.copyWith(isPlaying: true);
    await playbackDriver.setSpeed(state.settings.playbackSpeed);
    for (var i = 0; i < timings.length; i++) {
      if (!playbackDriver.isActiveSession(annotationSessionId)) return;

      final timing = timings[i];
      final played = Set<int>.from(state.playedSenseGroupIndices)..add(i);
      state = state.copyWith(
        playingSenseGroupIndex: i,
        playedSenseGroupIndices: played,
      );

      await playbackDriver.playRangeOnce(
        timing.start,
        timing.end,
        annotationSessionId,
      );
      if (!playbackDriver.isActiveSession(annotationSessionId)) return;

      if (i < timings.length - 1) {
        state = state.copyWith(playingSenseGroupIndex: null);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    if (!playbackDriver.isActiveSession(annotationSessionId)) return;
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
      if (state.annotationState?.phase is WaitingAnnotationPageTransition) {
        return;
      }
      _cleanupAnnotationSession();
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        annotationReplayRemaining: Duration.zero,
        annotationReplayDuration: Duration.zero,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
      await _startInlineAnnotationReplay(
        repeatCount: _annotationReplayRepeatCount,
        advanceAfterReplay: true,
        showReplayStatus: true,
      );
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
    AppLogger.log(
      'IntensivePlayer',
      'event=stop sentenceIndex=${state.currentSentenceIndex} '
          'isStepFinished=${state.stepFinished}',
    );
    _clearPlaybackResumePositions();
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
    _clearPlaybackResumePositions();
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

  /// 标记逐句精听页面仍有用户活动，使页面级学习计时器恢复计时。
  void markStudyActivity() => _studySessionTimer?.markActivity();

  /// 逐句精听页面累计的有效学习时长，供退出埋点复用。
  Duration get elapsed => _studySessionTimer?.elapsed ?? Duration.zero;

  /// 结束逐句精听页面会话并刷写最终统计；重复调用共享同一次收尾操作。
  Future<void> disposePlayer() {
    final inFlight = _disposePlayerInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> tracked;
    tracked = _disposePlayerInternal().whenComplete(() {
      if (identical(_disposePlayerInFlight, tracked)) {
        _disposePlayerInFlight = null;
      }
    });
    _disposePlayerInFlight = tracked;
    return tracked;
  }

  Future<void> _disposePlayerInternal() async {
    AppLogger.log(
      'IntensivePlayer',
      'disposePlayer: begin sentences=${_sentences.length} '
          'annotationSessionId=$_annotationSessionId',
    );
    try {
      await _playbackDriver.invalidateSession();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'intensive playback invalidation failed error=$error\n$stackTrace',
      );
    }
    _playbackDriver.unbindLockScreen();
    _blindEngine.stopSession();
    _cleanupAnnotationSession();

    final timer = _studySessionTimer;
    _studySessionTimer = null;
    try {
      await timer?.dispose();
    } catch (error, stackTrace) {
      // 统计刷写失败不能阻断播放器、媒体链路和页面状态的清理。
      AppLogger.log(
        'StudyExit',
        'intensive timer flush failed error=$error\n$stackTrace',
      );
    }

    _sentences = [];
    state = const IntensiveListenState();
    AppLogger.log('IntensivePlayer', 'disposePlayer: complete');
  }

  Future<void> _disposeStudySessionTimer() async {
    final timer = _studySessionTimer;
    _studySessionTimer = null;
    if (timer == null) return;
    try {
      await timer.dispose();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'intensive timer reset flush failed error=$error\n$stackTrace',
      );
    }
  }

  /// 仅在句子真实播放完成后记录输入时长、词数和词形。
  void _recordCompletedSentencePlayback(Sentence sentence) {
    _studyTimeService.submitSentencePlayback(
      duration: sentence.duration,
      text: sentence.text,
      stage: StudyStage.intensiveListen,
    );
  }

  void _prepareBlindFlow({int? startIndex}) {
    _blindEngine.prepare(
      sentences: _sentences,
      startIndex: startIndex ?? state.currentSentenceIndex,
      config: BlindPracticeFlowConfig(
        getRepeatCount: (_) => state.settings.repeatCount,
        getRepeatIntervalDuration: (sentence) =>
            calculatePauseDuration(sentence.duration, state.settings),
        getSentenceIntervalDuration: (sentence) =>
            calculatePauseDuration(sentence.duration, state.settings),
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
    final previousFlow = state.blindFlowState;
    final previousPhase = previousFlow?.phase;
    final sentenceChanged =
        flowState.sentenceIndex != state.currentSentenceIndex;

    if (phase is BlindWaitingInterval &&
        (previousPhase is! BlindWaitingInterval ||
            previousFlow?.sentenceIndex != flowState.sentenceIndex ||
            previousFlow?.repeatIndex != flowState.repeatIndex ||
            previousPhase.isPaused != phase.isPaused ||
            previousPhase.isBetweenSentences != phase.isBetweenSentences)) {
      AppLogger.log(
        'IntensivePlayer',
        'event=wait-start sentenceIndex=${flowState.sentenceIndex} '
            'repeatIndex=${flowState.repeatIndex} '
            'kind=${phase.isBetweenSentences ? 'sentence' : 'repeat'} '
            'durationMs=${phase.total.inMilliseconds} paused=${phase.isPaused}',
      );
    } else if (phase is BlindWaitingForUser &&
        previousPhase is! BlindWaitingForUser) {
      AppLogger.log(
        'IntensivePlayer',
        'event=wait-user sentenceIndex=${flowState.sentenceIndex} '
            'reason=${phase.reason}',
      );
    } else if (phase is BlindSessionCompleted &&
        previousPhase is! BlindSessionCompleted) {
      AppLogger.log(
        'IntensivePlayer',
        'event=completed totalSentences=${state.totalSentences} '
            'difficultCount=${state.difficultSentences.length}',
      );
    }

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
    _playbackDriver.setSessionActive(active);

    // 句间停顿倒计时期间冻结锁屏进度条：保活会话仍活跃（图标显示播放中），但音频不
    // 前进，进度条应停在句尾而非按 playbackRate 继续外推（见 §7.16，与全文盲听同源）。
    // 实际播放（BlindPlayingPrompt）时解冻，进度随播放前进。
    _playbackDriver.setProgressFrozen(interval != null);

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

  Future<SentencePlaybackResult> _playSentenceForBlind(
    Sentence sentence,
    int flowToken,
  ) async {
    if (sentence.duration <= Duration.zero) {
      AppLogger.log(
        'IntensivePlayer',
        'event=sentence-rejected flowToken=$flowToken '
            'sentenceIndex=${sentence.index} reason=invalid-duration',
      );
      return SentencePlaybackResult.failed;
    }
    _persistCurrentSentenceIndexAsync();
    final playbackDriver = _playbackDriver;
    final playbackSessionId = playbackDriver.newSession();
    await playbackDriver.setSpeed(state.settings.playbackSpeed);
    AppLogger.log(
      'IntensivePlayer',
      'event=sentence-flow-binding '
          'itemId=${ref.read(learningSessionProvider).audioItemId} '
          'flowToken=$flowToken playbackSessionId=$playbackSessionId '
          'sentenceIndex=${sentence.index}',
    );
    final result = await playbackDriver.playSentence(
      sentence,
      playbackSessionId,
    );
    if (result == SentencePlaybackResult.completed) {
      _recordCompletedSentencePlayback(sentence);
    }
    return result;
  }

  Future<SentencePlaybackResult> _resumeSentenceForBlind(
    Sentence sentence,
    int flowToken,
    Duration startAt,
  ) async {
    if (sentence.duration <= Duration.zero) {
      return SentencePlaybackResult.failed;
    }
    final playbackDriver = _playbackDriver;
    final sessionId = playbackDriver.newSession();
    await playbackDriver.setSpeed(state.settings.playbackSpeed);
    final result = await playbackDriver.playSentence(
      sentence,
      sessionId,
      startAt: startAt,
    );
    if (result == SentencePlaybackResult.completed) {
      _recordCompletedSentencePlayback(sentence);
    }
    return result;
  }

  Future<void> _goToSentence(int sentenceIndex) async {
    _clearPlaybackResumePositions();
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

  /// 讲解页按指定次数播放当前句。
  ///
  /// [advanceAfterReplay] 仅供“继续”流程使用；播放按钮完成后仍停留在讲解页。
  Future<void> _startInlineAnnotationReplay({
    required int repeatCount,
    required bool advanceAfterReplay,
    required bool showReplayStatus,
    Duration? startAt,
    int? startingPlayCount,
  }) async {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) {
      if (advanceAfterReplay) await _finishAnnotationReplay();
      return;
    }

    stopSenseGroupPlayback();
    _cleanupAnnotationSession();
    _annotationWaitAfterCurrentPlayback = false;
    final playbackDriver = _playbackDriver;
    _annotationSessionId = playbackDriver.newSession();
    final annotationSessionId = _annotationSessionId;
    _annotationSentencePlaybackSessionId = annotationSessionId;

    try {
      await playbackDriver.setSpeed(state.settings.playbackSpeed);
      var playCount = startingPlayCount ?? 1;
      var firstPlayback = true;
      while (repeatCount == 0 || playCount <= repeatCount) {
        if (_annotationSessionId != annotationSessionId ||
            !playbackDriver.isActiveSession(annotationSessionId)) {
          _clearPlayingIfCurrentAnnotationSession(annotationSessionId);
          return;
        }

        state = state.copyWith(currentPlayCount: playCount);
        if (showReplayStatus) {
          _setAnnotationPhase(
            ReplayingWithSubtitle(
              remaining: sentence.duration,
              total: sentence.duration,
            ),
          );
        } else {
          // 播放按钮只是讲解页内重听：保留讲解态和“继续”按钮，不显示重听提示。
          _setAnnotationPhase(const InspectingAnnotation());
          state = state.copyWith(isPlaying: true);
        }
        final result = await playbackDriver.playSentence(
          sentence,
          annotationSessionId,
          startAt: firstPlayback ? startAt : null,
        );
        firstPlayback = false;

        // 暂停会立即放弃当前讲解会话。即使底层播放器的取消回调晚到，
        // 旧重播也不能进入倒计时或覆盖图中的“继续”等待态。
        if (result != SentencePlaybackResult.completed ||
            _annotationSessionId != annotationSessionId ||
            !playbackDriver.isActiveSession(annotationSessionId)) {
          _clearPlayingIfCurrentAnnotationSession(annotationSessionId);
          return;
        }

        _recordCompletedSentencePlayback(sentence);
        if (_annotationWaitAfterCurrentPlayback) {
          _annotationWaitAfterCurrentPlayback = false;
          _setAnnotationPhase(const WaitingAnnotationUser());
          return;
        }
        if (repeatCount == 0 || playCount < repeatCount) {
          final pauseDuration = calculatePauseDuration(
            sentence.duration,
            state.settings,
          );
          _setAnnotationPhase(
            WaitingAnnotationInterval(
              remaining: pauseDuration,
              total: pauseDuration,
            ),
          );
          if (!showReplayStatus) {
            // 循环间停顿不属于“继续”流程，继续按钮仍保持可用。
            state = state.copyWith(isPauseBetweenSentences: false);
          }
          await _annotationCountdown.start(pauseDuration);
          if (_annotationSessionId != annotationSessionId ||
              !playbackDriver.isActiveSession(annotationSessionId) ||
              state.annotationState?.phase is! WaitingAnnotationInterval) {
            return;
          }
        }
        playCount += 1;
      }

      if (_annotationSessionId != annotationSessionId ||
          !playbackDriver.isActiveSession(annotationSessionId)) {
        return;
      }
      if (advanceAfterReplay) {
        await _finishAnnotationReplay();
      } else {
        _setAnnotationPhase(const InspectingAnnotation());
      }
    } finally {
      if (_annotationSentencePlaybackSessionId == annotationSessionId) {
        _annotationSentencePlaybackSessionId = null;
      }
    }
  }

  /// 返回讲解页播放按钮应使用的循环次数；关闭时固定为一遍。
  int get _annotationReplayRepeatCount =>
      state.settings.annotationReplayUsesRepeatCount
      ? state.settings.repeatCount
      : 1;

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
    final playbackDriver = _playbackDriver;
    _annotationSessionId = playbackDriver.newSession();
    final annotationSessionId = _annotationSessionId;

    _setAnnotationPhase(
      WaitingAnnotationInterval(remaining: pauseDur, total: pauseDur),
    );

    await _annotationCountdown.start(pauseDur);

    // 取消倒计时也会正常完成 Future；只有仍停留在倒计时阶段时，
    // 才允许继续执行自动切句，避免用户接管后被旧流程推进到下一句。
    if (!playbackDriver.isActiveSession(annotationSessionId) ||
        state.annotationState?.phase is! WaitingAnnotationInterval) {
      return;
    }

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

    // 保留当前句讲解内容，交由页面层先完成横向分页动画，再提交切句。
    _setAnnotationPhase(
      WaitingAnnotationPageTransition(
        targetSentenceIndex: state.currentSentenceIndex + 1,
      ),
    );
  }

  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final itemId = session.audioItemId;
    if (itemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            itemId,
            state.currentSentenceIndex,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  void _cleanupAnnotationSession() {
    _annotationCountdown.cancel();
    _annotationSessionId = -1;
    _annotationSentencePlaybackSessionId = null;
    _annotationWaitAfterCurrentPlayback = false;
    _playbackDriver.pause();
  }

  void _clearPlaybackResumePositions() {
    _blindResumePosition = null;
    _annotationResumePosition = null;
    _annotationResumePlayCount = null;
  }

  /// 仅允许当前讲解播放会话清除播放态。
  ///
  /// 用户在详情重播期间再次点击继续或播放时，旧 session 会异步返回。
  /// 旧 session 已失效并不代表新 session 已停止，因此不能覆盖新会话的
  /// [IntensiveListenState.isPlaying]。
  void _clearPlayingIfCurrentAnnotationSession(int annotationSessionId) {
    if (_annotationSessionId != annotationSessionId) return;
    state = state.copyWith(isPlaying: false);
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

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
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/sentence.dart';
import '../../models/sentence_playback_result.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/study_session_timer.dart';
import '../../services/study_time_service.dart';
import '../blind_flow/blind_practice_flow_engine.dart';
import '../blind_flow/blind_practice_flow_phase.dart';
import '../blind_flow/blind_practice_flow_state.dart';
import '../learning_progress_provider.dart';
import '../difficult_practice_prefs_provider.dart';
import '../favorite_sentence_lifecycle_provider.dart';
import '../media_engine/media_engine_provider.dart';
import '../media_engine/media_sense_group_range_playback.dart';
import '../repeat_flow/repeat_flow_engine.dart';
import '../repeat_flow/repeat_flow_phase.dart';
import '../repeat_flow/repeat_flow_state.dart';
import '../speech/speech_recording_controller.dart';
import 'intensive_listen_playback_driver.dart';
import 'learning_session_provider.dart';
import 'sentence_playback_engine.dart' show listenAndRepeatPauseCalculator;

part 'review_difficult_practice_provider.g.dart';

/// 记录用户对 [DifficultPracticeSettings] 的手动改动到 [slot] 偏好(按槽位)。
///
/// 难句补练 / 收藏句复习共用 [DifficultPracticeSettings] 与同一份偏好 store。
/// 仅写变化字段;[slot] 为 null 时跳过。
void recordDifficultPracticeChange(
  Ref ref,
  String? slot,
  DifficultPracticeSettings oldSettings,
  DifficultPracticeSettings newSettings,
) {
  if (slot == null) return;
  persistDifficultSettingsDiff(
    ref.read(difficultPracticePrefsProvider.notifier),
    slot,
    oldSettings,
    newSettings,
  );
}

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

  /// 当前材料是否为视频；所有原句均由共享 MediaEngine 播放。
  final bool hasVideo;

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
    this.hasVideo = false,
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
    bool? hasVideo,
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
      hasVideo: hasVideo ?? this.hasVideo,
    );
  }
}

/// 难句补练 Provider
@riverpod
class ReviewDifficultPractice extends _$ReviewDifficultPractice {
  /// 难句列表
  List<Sentence> _sentences = [];

  /// 设置记忆 slot(子阶段×轮次);null 表示本次不记忆。
  String? _settingsSlot;

  /// 当前难句补练页面的学习统计服务。
  late StudyTimeService _studyTimeService;

  /// 当前页面级学习计时器。
  StudySessionTimer? _studySessionTimer;

  /// 幂等退出收尾，避免路由退出和 Provider 销毁重复刷写统计。
  Future<void>? _disposePlayerInFlight;

  /// 统计会话代际，防止旧播放或录音回调污染新会话。
  int _studySessionGeneration = 0;

  /// 难句切换请求编号，串联一次导航的状态提交和播放器收尾日志。
  int _navigationRequestSequence = 0;

  /// 录音控制器实例；保存后可在 Provider 销毁阶段完成异步收尾，避免再次读取 ref。
  late final SpeechRecordingController _speechController;

  /// 当前会话句子播放驱动；音频与视频共用同一练习状态机。
  late SentencePlaybackDriver _playback;

  /// 当前会话意群区间播放器，与正文逐词高亮共用播放时间源。
  SenseGroupRangePlayback? _senseGroupRangePlayback;

  /// 跟读流程引擎（跟读模式时创建，退出时销毁）
  RepeatFlowEngine? _repeatEngine;

  /// 盲听流程引擎
  late BlindPracticeFlowEngine _blindEngine;

  BlindPracticeFlowEngine _createBlindEngine() {
    return BlindPracticeFlowEngine(
      onStateChanged: _onBlindFlowStateChanged,
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () => unawaited(_playback.pause()),
        playSentence: _playSentenceForBlind,
      ),
      logTag: 'RDP-Blind',
    );
  }

  @override
  ReviewDifficultPracticeState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    _speechController = ref.read(speechRecordingControllerProvider.notifier);

    _playback = MediaSentencePlaybackDriver(
      ref.read(mediaEngineProvider.notifier),
    );
    _blindEngine = _createBlindEngine();

    // 监听录音状态变化 → 桥接到跟读引擎
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);

    ref.onDispose(() {
      unawaited(_disposePlayerOnProviderDispose());
    });
    return const ReviewDifficultPracticeState();
  }

  /// 初始化
  ///
  /// [playbackSpeed] 入口 briefing 中用户选择的初始播放速度，默认 1.0x。
  /// [pauseMultiplier] 入口 briefing 中选择的句间停顿；-1.0 = 自动（smart 模式），
  ///   其余正数走 multiplier 模式。
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    DifficultPracticeSettings settings = const DifficultPracticeSettings(),
    String? settingsSlot,
    SentencePlaybackDriver? playbackDriver,
    SenseGroupRangePlayback? senseGroupRangePlayback,
    bool hasVideo = false,
  }) async {
    _studySessionGeneration += 1;
    await _disposeStudySessionTimer();
    _settingsSlot = settingsSlot;
    await _playback.invalidateSession();
    _playback.unbindLockScreen();
    _playback =
        playbackDriver ??
        MediaSentencePlaybackDriver(ref.read(mediaEngineProvider.notifier));
    _senseGroupRangePlayback =
        senseGroupRangePlayback ??
        MediaSenseGroupRangePlayback(
          engine: ref.read(mediaEngineProvider.notifier),
          playbackSpeed: () => state.settings.playbackSpeed,
        );
    _blindEngine.dispose();
    _blindEngine = _createBlindEngine();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final validIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _sentences.length,
      // [settings] 已由调用方从按槽位偏好 resolve 出(默认+记忆),直接 seed。
      settings: settings,
      hasVideo: hasVideo,
    );
    _prepareBlindFlow(startIndex: validIndex);
    ref.read(analyticsServiceProvider).track(Events.difficultPracticeStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalDifficultSentences: _sentences.length,
    });

    final sessionGeneration = _studySessionGeneration;
    _speechController.setRecordingCompletionHandler(
      (duration) => _recordSpeechRecognition(duration, sessionGeneration),
    );
    _playback.bindLockScreen(
      onPlay: resume,
      onPause: () async => pause(),
      onNext: goToNext,
      onPrevious: goToPrevious,
    );

    final timer = StudySessionTimer(
      studyTimeService: _studyTimeService,
      stage: StudyStage.reviewDifficultPractice,
      activityGate: ref.read(studyActivityGateProvider),
      idleTimeout: const Duration(minutes: 2),
      logScope: 'ReviewDifficultPracticeTimer',
    );
    _studySessionTimer = timer;
    timer.start();
    AppLogger.log(
      'ReviewDifficultPracticeStats',
      'session.ready sentenceCount=${_sentences.length} '
          'hasVideo=$hasVideo',
    );
  }

  /// 标记页面上的用户活动，供 [StudyActivityDetector] 调用。
  void markStudyActivity() => _studySessionTimer?.markActivity();

  /// 暂停完成弹窗期间的页面学习计时。
  void pauseStudySession() => _studySessionTimer?.pause();

  /// 恢复完成弹窗关闭或重新练习后的页面学习计时。
  void resumeStudySession() => _studySessionTimer?.resume();

  /// 当前页面累计的有效学习时长，供学习会话埋点使用。
  Duration get elapsed => _studySessionTimer?.elapsed ?? Duration.zero;

  /// 当前会话注入的意群区间播放器。
  SenseGroupRangePlayback? get senseGroupRangePlayback =>
      _senseGroupRangePlayback;

  /// 更新设置并重新开始当前句
  Future<void> updateSettings(DifficultPracticeSettings newSettings) async {
    recordDifficultPracticeChange(
      ref,
      _settingsSlot,
      state.settings,
      newSettings,
    );
    // 速度变化无需重启会话：直接推给 MediaEngine 即可。
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
      unawaited(_playback.setSpeed(newSettings.playbackSpeed));
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
    unawaited(_playback.invalidateSession());
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
    unawaited(_playback.invalidateSession());
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

    AppLogger.log(
      'RDP-Navigation',
      'event=annotation-enter sentenceIndex=${state.currentSentenceIndex} '
          'fromMode=blind media=true',
    );
    unawaited(_playback.invalidateSession());
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

    unawaited(_playback.invalidateSession());
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

    if (wasBookmarked) {
      await ref.read(favoriteSentenceLifecycleProvider).remove(audioItemId, {
        s.index,
      });
      return;
    }

    await ref.read(favoriteSentenceLifecycleProvider).save(audioItemId, s);
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
  Future<void> goToNext() async => goToSentence(state.currentSentenceIndex + 1);

  /// 上一句
  Future<void> goToPrevious() async =>
      goToSentence(state.currentSentenceIndex - 1);

  /// 跳转到指定句子（0-based）。
  ///
  /// 供进度条拖动跳转使用：越界自动 clamp，目标与当前相同时直接返回。
  Future<void> goToSentence(int index) async {
    final requestId = ++_navigationRequestSequence;
    final fromIndex = state.currentSentenceIndex;
    if (state.totalSentences <= 0) {
      AppLogger.log(
        'RDP-Navigation',
        'event=request-ignored id=$requestId reason=no-sentences '
            'requestedIndex=$index',
      );
      return;
    }
    final target = index.clamp(0, state.totalSentences - 1);
    final mode = state.isAnnotationMode ? 'annotation' : 'blind';
    AppLogger.log(
      'RDP-Navigation',
      'event=request id=$requestId source=goToSentence mode=$mode '
          'fromIndex=$fromIndex requestedIndex=$index targetIndex=$target '
          'totalSentences=${state.totalSentences} '
          'media=true',
    );
    if (target == fromIndex) {
      AppLogger.log(
        'RDP-Navigation',
        'event=request-ignored id=$requestId reason=already-at-target '
            'currentIndex=$fromIndex',
      );
      return;
    }
    await _goToSentenceIndex(
      target,
      requestId: requestId,
      fromIndex: fromIndex,
      fromMode: mode,
    );
    AppLogger.log(
      'RDP-Navigation',
      'event=complete id=$requestId currentIndex=${state.currentSentenceIndex} '
          'phase=${state.blindFlowState?.phase.runtimeType}',
    );
  }

  /// 切换到指定句子并重启盲听 flow（goToNext/goToPrevious/goToSentence 共用）
  Future<void> _goToSentenceIndex(
    int target, {
    required int requestId,
    required int fromIndex,
    required String fromMode,
  }) async {
    AppLogger.log(
      'RDP-Navigation',
      'event=commit-start id=$requestId fromIndex=$fromIndex '
          'targetIndex=$target fromMode=$fromMode '
          'media=true',
    );
    _exitAnnotationMode();
    _blindEngine.stopSession();
    state = state.copyWith(
      currentSentenceIndex: target,
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
    await _startBlindFlow(navigationId: requestId);
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
    unawaited(_playback.invalidateSession());
    if (state.isAnnotationMode) {
      _repeatEngine?.replayCurrentSentence();
    } else {
      await _blindEngine.replayCurrentSentence();
    }
  }

  /// 停止播放
  void stopPlayback() {
    unawaited(_playback.invalidateSession());
    _blindEngine.stopSession();
    _exitAnnotationMode();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      clearBlindFlowState: true,
    );
  }

  /// 释放播放器、页面计时器并等待统计队列刷写完成。
  Future<void> disposePlayer() {
    final inFlight = _disposePlayerInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> operation;
    operation = _disposePlayerInternal().whenComplete(() {
      if (identical(_disposePlayerInFlight, operation)) {
        _disposePlayerInFlight = null;
      }
    });
    _disposePlayerInFlight = operation;
    return operation;
  }

  Future<void> _disposePlayerInternal() async {
    _studySessionGeneration += 1;
    _speechController.setRecordingCompletionHandler(null);

    try {
      await _playback.invalidateSession();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'review difficult practice playback cleanup failed '
            'error=$error\n$stackTrace',
      );
    }
    _playback.unbindLockScreen();
    _blindEngine.stopSession();
    _repeatEngine?.dispose();
    _repeatEngine = null;

    await _disposeStudySessionTimer();
    try {
      await _studyTimeService.flush();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'review difficult practice statistics flush failed '
            'error=$error\n$stackTrace',
      );
    }

    _sentences = [];
    state = const ReviewDifficultPracticeState();
    AppLogger.log('ReviewDifficultPractice', 'disposePlayer: complete');
  }

  /// 释放当前页面计时器；初始化新会话时复用此方法，避免计时器泄漏。
  Future<void> _disposeStudySessionTimer() async {
    final timer = _studySessionTimer;
    _studySessionTimer = null;
    if (timer == null) return;
    try {
      await timer.dispose();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'review difficult practice timer cleanup failed '
            'error=$error\n$stackTrace',
      );
    }
  }

  /// Provider 被动销毁时兜底释放播放资源并刷写统计，不再访问已销毁的 ref。
  Future<void> _disposePlayerOnProviderDispose() async {
    _studySessionGeneration += 1;
    _speechController.setRecordingCompletionHandler(null);
    _blindEngine.dispose();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _playback.unbindLockScreen();
    try {
      await _playback.invalidateSession();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'review difficult practice provider playback cleanup failed '
            'error=$error\n$stackTrace',
      );
    }
    await _disposeStudySessionTimer();
    try {
      await _studyTimeService.flush();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'review difficult practice provider statistics flush failed '
            'error=$error\n$stackTrace',
      );
    }
  }

  /// 记录一次完整句子播放的输入统计。
  void _recordSentencePlayback(Sentence sentence) {
    AppLogger.log(
      'ReviewDifficultPracticeStats',
      'sentencePlayback.submit stage=${StudyStage.reviewDifficultPractice.name} '
          'sentenceIndex=${sentence.index} '
          'durationMs=${sentence.duration.inMilliseconds}',
    );
    _studyTimeService.submitSentencePlayback(
      duration: sentence.duration,
      text: sentence.text,
      stage: StudyStage.reviewDifficultPractice,
    );
  }

  /// 记录一次有效跟读录音，并丢弃退出后的迟到回调。
  ///
  /// 难句补练的学习统计只累计有效跟读时长，不累计跟读词数或总次数；
  /// 录音完成次数由 UsageTracker 单独计数，不走此统计入口。
  void _recordSpeechRecognition(Duration duration, int sessionGeneration) {
    if (sessionGeneration != _studySessionGeneration ||
        _studySessionTimer == null) {
      AppLogger.log(
        'ReviewDifficultPracticeStats',
        'speechRecognition.discarded durationMs=${duration.inMilliseconds} '
            'callbackGeneration=$sessionGeneration '
            'currentGeneration=$_studySessionGeneration '
            'hasTimer=${_studySessionTimer != null}',
      );
      return;
    }
    AppLogger.log(
      'ReviewDifficultPracticeStats',
      'speechRecognition.submit '
          'stage=${StudyStage.reviewDifficultPractice.name} '
          'durationMs=${duration.inMilliseconds} generation=$sessionGeneration',
    );
    _studyTimeService.submitSpeechRecognition(
      duration: duration,
      stage: StudyStage.reviewDifficultPractice,
    );
  }

  /// 重置到第一句
  Future<void> resetToStart() async {
    await _playback.invalidateSession();
    _blindEngine.stopSession();
    _exitAnnotationMode();
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
      settings: state.settings,
      hasVideo: state.hasVideo,
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
        pauseAudio: () => unawaited(_playback.pause()),
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
    final interval = flowState.isInPause;
    _playback.setSessionActive(flowState.phase is PlayingPrompt || interval);
    _playback.setProgressFrozen(interval);
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
      final accepted = _repeatEngine!.onRecordingFinished(
        attempt.filePath,
        attempt.score,
        promptId: attempt.promptId,
      );
      if (!accepted) {
        AppLogger.log(
          'RDP-Repeat',
          'event=recording_completed ignored promptId=${attempt.promptId} '
              'sessionId=${_repeatEngine!.state.sessionId} '
              'flowToken=${_repeatEngine!.state.flowToken}',
        );
        return;
      }
      ref
          .read(usageTrackerProvider)
          .record(
            UsageEvent.recordingCompleted,
            analyticsParams: {
              ...ref.audioEventParams(
                ref.read(learningSessionProvider).audioItemId,
              ),
              EventParams.mode: 'difficult_practice',
              if (attempt.score != null) EventParams.score: attempt.score!,
            },
          );
    }

    // 录音取消/超时
    if (_repeatEngine!.state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null &&
        next.promptId != null) {
      _repeatEngine!.onRecordingCancelled(promptId: next.promptId);
    }
  }

  // ========== 跟读引擎回调实现 ==========

  Future<SentencePlaybackResult> _playSentenceForRepeat(
    Sentence sentence,
    int flowToken,
  ) async {
    final playback = _playback;
    final sessionId = playback.newSession();
    AppLogger.log(
      'RDP-Repeat',
      'event=driver-play-start sentenceIndex=${sentence.index} '
          'flowToken=$flowToken playbackSessionId=$sessionId',
    );
    late final SentencePlaybackResult result;
    try {
      await playback.setSpeed(state.settings.playbackSpeed);
      result = await playback.playSentence(sentence, sessionId);
    } catch (error) {
      AppLogger.log(
        'RDP-Repeat',
        'event=driver-play-failed sentenceIndex=${sentence.index} '
            'flowToken=$flowToken playbackSessionId=$sessionId '
            'errorType=${error.runtimeType}',
      );
      rethrow;
    }
    AppLogger.log(
      'RDP-Repeat',
      'event=driver-play-result sentenceIndex=${sentence.index} '
          'flowToken=$flowToken '
          'currentFlowToken=${_repeatEngine?.state.flowToken} '
          'playbackSessionId=$sessionId '
          'sessionActive=${playback.isActiveSession(sessionId)} result=$result',
    );
    if (result == SentencePlaybackResult.completed &&
        playback.isActiveSession(sessionId)) {
      _recordSentencePlayback(sentence);
    }
    return result;
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

  Future<void> _clearRecordingForRepeat() {
    return ref
        .read(speechRecordingControllerProvider.notifier)
        .clearRecording();
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
        onSentencePlayed: _recordSentencePlayback,
        isManualMode: () => state.isManualMode,
      ),
    );
  }

  /// 启动盲听流程。
  Future<void> _startBlindFlow({
    bool autoplay = true,
    int? navigationId,
  }) async {
    if (_sentences.isEmpty) return;
    _prepareBlindFlow();
    // 准备阶段会异步暂停旧流程的音频。等播放器收尾完成后再启动新句，
    // 避免旧会话的 pause 抢停刚启动的目标句。
    final invalidation = Stopwatch()..start();
    AppLogger.log(
      'RDP-Navigation',
      'event=playback-invalidation-start navigationId=$navigationId '
          'sentenceIndex=${state.currentSentenceIndex} '
          'driver=media',
    );
    try {
      await _playback.invalidateSession();
    } catch (error) {
      AppLogger.log(
        'RDP-Navigation',
        'event=playback-invalidation-failed navigationId=$navigationId '
            'sentenceIndex=${state.currentSentenceIndex} '
            'errorType=${error.runtimeType}',
      );
      rethrow;
    }
    AppLogger.log(
      'RDP-Navigation',
      'event=playback-invalidation-complete navigationId=$navigationId '
          'sentenceIndex=${state.currentSentenceIndex} '
          'elapsedMs=${invalidation.elapsedMilliseconds}',
    );
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

    if (sentenceChanged) {
      AppLogger.log(
        'RDP-Navigation',
        'event=flow-index-change fromIndex=$previousIndex '
            'toIndex=${flowState.sentenceIndex} '
            'phase=${phase.runtimeType} flowToken=${flowState.flowToken}',
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
      stepFinished: phase is BlindSessionCompleted,
      isTextRevealed: sentenceChanged ? false : state.isTextRevealed,
      isManualForSentence: sentenceChanged ? false : state.isManualForSentence,
    );

    final inInterval = interval != null;
    _playback.setSessionActive(phase is BlindPlayingPrompt || inInterval);
    _playback.setProgressFrozen(inInterval);

    if (phase is BlindSessionCompleted) {
      _trackDifficultPracticeComplete();
    }

    if (sentenceChanged) {
      _persistCurrentSentenceIndexAsync();
    }
  }

  /// 播放一遍盲听原句。
  Future<SentencePlaybackResult> _playSentenceForBlind(
    Sentence sentence,
    int flowToken,
  ) async {
    final playback = _playback;
    final sessionId = playback.newSession();
    AppLogger.log(
      'RDP-Blind',
      'event=play-request-start sentenceIndex=${sentence.index} '
          'flowToken=$flowToken playbackSessionId=$sessionId '
          'driver=media',
    );
    late final SentencePlaybackResult result;
    try {
      await playback.setSpeed(state.settings.playbackSpeed);
      result = await playback.playSentence(sentence, sessionId);
    } catch (error) {
      AppLogger.log(
        'RDP-Blind',
        'event=play-request-failed sentenceIndex=${sentence.index} '
            'flowToken=$flowToken playbackSessionId=$sessionId '
            'errorType=${error.runtimeType}',
      );
      rethrow;
    }
    final currentFlowToken = _blindEngine.state.flowToken;
    final sessionActive = playback.isActiveSession(sessionId);
    AppLogger.log(
      'RDP-Blind',
      'event=play-request-result sentenceIndex=${sentence.index} '
          'flowToken=$flowToken currentFlowToken=$currentFlowToken '
          'playbackSessionId=$sessionId sessionActive=$sessionActive '
          'result=$result',
    );
    if (flowToken != currentFlowToken) return SentencePlaybackResult.cancelled;
    return result;
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
    final fromIndex = state.currentSentenceIndex;
    final requestId = ++_navigationRequestSequence;
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;
    AppLogger.log(
      'RDP-Navigation',
      'event=request id=$requestId source=annotation-completed '
          'fromIndex=$fromIndex '
          'targetIndex=${isLastSentence ? 'complete' : fromIndex + 1} '
          'totalSentences=${state.totalSentences}',
    );
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
    await _startBlindFlow(navigationId: requestId);
  }

  /// 上报完成事件
  void _trackDifficultPracticeComplete() {
    ref.read(analyticsServiceProvider).track(Events.difficultPracticeComplete, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalDifficultSentences: state.totalSentences,
    });
  }
}

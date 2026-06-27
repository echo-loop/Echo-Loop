/// 收藏句子复习 Provider
///
/// 加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练（ReviewDifficultPractice）一致：
/// 盲听 N 遍 → 句间停顿 → 自动推进；支持偷看字幕、听不懂进入跟读模式。
/// 支持手动模式（盲听强制 1 遍、跟读强制 1 遍）和自动录音（跟读停顿触发）。
///
/// 与难句补练的关键差异：
/// - 数据来源：全局 bookmarks（跨音频）
/// - 播放句子时需检测是否需要切换音频（loadAudio）
/// - 默认按音频分组乱序
/// - 不关联 LearningProgress / LearningSession
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/app_database.dart' as db;
import '../../services/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/daos/bookmark_dao.dart';
import '../../models/audio_item.dart' as model;
import '../../models/bookmark_sentence.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/sentence.dart';
import '../../database/providers.dart';
import '../../models/study_stage.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/study_event_recorder.dart';
import '../../services/study_time_service.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../blind_flow/blind_practice_flow_engine.dart';
import '../blind_flow/blind_practice_flow_phase.dart';
import '../blind_flow/blind_practice_flow_state.dart';
import '../daily_study_time_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../repeat_flow/repeat_flow_engine.dart';
import '../repeat_flow/repeat_flow_phase.dart';
import '../repeat_flow/repeat_flow_state.dart';
import '../difficult_practice_prefs_provider.dart';
import '../../models/stage_settings_overrides.dart';
import '../study_stats_provider.dart';
import 'review_difficult_practice_provider.dart';
import 'sentence_playback_engine.dart';
import '../speech/speech_recording_controller.dart';

part 'bookmark_review_provider.g.dart';

typedef BookmarkReviewAudioLoader = Future<db.AudioItem?> Function(String);

/// 收藏复习 Provider
///
/// 复用 [ReviewDifficultPracticeState] 作为状态类。
/// 内部维护 [List<BookmarkSentence>] 用于跨音频播放。
@Riverpod(keepAlive: true)
class BookmarkReview extends _$BookmarkReview {
  /// 收藏句子列表（乱序后）
  List<BookmarkSentence> _sentences = [];

  /// 设置记忆 slot:收藏句复习不绑学习流程、无轮次,固定 `bookmarkReview:none`。
  final String _settingsSlot = stageSlotKey(
    StageSettingsSlots.bookmarkReview,
    null,
  );

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// 获取 AudioItemDao 的回调（通过 ref 注入）
  late BookmarkReviewAudioLoader _getAudioItemById;

  /// 学习时长存储服务
  late StudyTimeService _studyTimeService;

  /// 学习计时器
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 周期保存定时器（每 _maxSessionSeconds 自动保存并重置计时器）
  Timer? _periodicSaveTimer;

  /// 是否正在执行保存（防止 timer 回调与 dispose 竞态）
  bool _isSaving = false;

  /// 单次会话最大计入时长（防止用户睡着等异常场景）
  static const _maxSessionSeconds = 5 * 60; // 5 分钟

  /// App 生命周期监听器，用于在后台暂停计时
  late AppLifecycleListener _lifecycleListener;

  /// 跟读流程引擎（跟读模式时创建，退出时销毁）
  RepeatFlowEngine? _repeatEngine;

  /// 盲听流程引擎
  late BlindPracticeFlowEngine _blindEngine;

  BlindPracticeFlowEngine _createBlindEngine() {
    return BlindPracticeFlowEngine(
      onStateChanged: _onBlindFlowStateChanged,
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () =>
            ref.read(foregroundAudioEngineProvider.notifier).pause(),
        playSentence: _playSentenceForBlind,
      ),
      logTag: 'BookmarkBlind',
    );
  }

  @override
  ReviewDifficultPracticeState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);

    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } on UnimplementedError {
      // 测试环境可能未注入数据库，忽略词形统计即可。
    }
    _recorder = StudyEventRecorder(
      studyTimeService: _studyTimeService,
      vocabTracker: vocabTracker,
      stage: StudyStage.bookmarkReview,
    );

    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(foregroundAudioEngineProvider.notifier),
      recorder: _recorder,
    );
    _blindEngine = _createBlindEngine();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChanged,
    );
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);
    ref.onDispose(() {
      _engine.cleanup();
      _blindEngine.dispose();
      _repeatEngine?.dispose();
      _periodicSaveTimer?.cancel();
      if (_sentences.isNotEmpty) {
        ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceReviewCompleted,
              analyticsParams: {
                EventParams.totalSentencesCount: _sentences.length,
                EventParams.durationMs: _studyStopwatch.elapsedMilliseconds,
              },
            );
      }
      _saveAndRefreshStudyTime();
      _lifecycleListener.dispose();
    });
    return const ReviewDifficultPracticeState();
  }

  /// App 生命周期变化时暂停/恢复计时
  ///
  /// - 进入后台：暂停所有计时器 + 取消周期保存
  /// - 回到前台：恢复计时 + 重新调度周期保存
  void _onAppLifecycleStateChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      _studyStopwatch.stop();
      _stopPeriodicSaveTimer();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (_sentences.isNotEmpty &&
          !state.stepFinished &&
          !_studyStopwatch.isRunning) {
        _studyStopwatch.start();
        _schedulePeriodicSave();
      }
    }
  }

  /// 调度下一次周期保存（one-shot Timer，避免 periodic 的 async 竞态）
  void _schedulePeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer(
      const Duration(seconds: _maxSessionSeconds),
      () async {
        if (_isSaving || _sentences.isEmpty) return;
        await _saveAndRefreshStudyTime();
        // 保存后如果仍在学习中，重新启动计时并调度下一次
        if (_sentences.isNotEmpty && !state.stepFinished) {
          _studyStopwatch.start();
          _schedulePeriodicSave();
        }
      },
    );
  }

  /// 停止周期保存定时器
  void _stopPeriodicSaveTimer() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  /// 初始化收藏复习
  ///
  /// [bookmarks] 来自 BookmarkDao.watchAllWithAudioName() 的快照
  /// [getAudioItemById] 根据 audioItemId 获取 AudioItem 行数据
  void initialize(
    List<BookmarkWithAudio> bookmarks, {
    required BookmarkReviewAudioLoader getAudioItemById,
  }) {
    // 收藏句复习用前台引擎、不上锁屏：进任务停掉媒体引擎，清除 Free Player 等残留的
    // 锁屏/通知栏卡片（非idle→idle → stopService）。见 ADR-7。
    unawaited(ref.read(audioEngineProvider.notifier).stop());
    _engine.cleanup();
    _blindEngine.dispose();
    _blindEngine = _createBlindEngine();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _getAudioItemById = getAudioItemById;

    // 过滤掉无效书签（迁移遗留的 startTime==endTime==0 条目）
    final validBookmarks = bookmarks.where((b) {
      final duration = b.bookmark.endTime - b.bookmark.startTime;
      return duration > 0 && b.bookmark.sentenceText.isNotEmpty;
    }).toList();

    // 按音频 ID 分组
    final grouped = <String, List<BookmarkWithAudio>>{};
    for (final b in validBookmarks) {
      (grouped[b.bookmark.audioItemId] ??= []).add(b);
    }

    // 方案 A：音频组间乱序，组内保持 sentenceIndex 顺序
    final audioIds = grouped.keys.toList()..shuffle();

    _sentences = [];
    for (final audioId in audioIds) {
      final items = grouped[audioId]!;
      // 组内已按 sentenceIndex 排序（DAO 查询保证）
      for (final item in items) {
        _sentences.add(
          BookmarkSentence(
            sentence: Sentence(
              index: item.bookmark.sentenceIndex,
              text: item.bookmark.sentenceText,
              startTime: Duration(
                milliseconds: (item.bookmark.startTime * 1000).round(),
              ),
              endTime: Duration(
                milliseconds: (item.bookmark.endTime * 1000).round(),
              ),
              isBookmarked: true,
            ),
            audioItemId: item.bookmark.audioItemId,
            audioName: item.audioName,
            originalSentenceIndex: item.bookmark.sentenceIndex,
          ),
        );
      }
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
      // 收藏句复习不绑学习流程,无难度速度,智能默认速度取 1.0;偏好按固定槽位记忆。
      settings: ref
          .read(difficultPracticePrefsProvider.notifier)
          .resolve(_settingsSlot, smartSpeed: 1.0),
    );
    _prepareBlindFlow();

    // 启动学习计时 + 周期保存
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave();
    ref.read(analyticsServiceProvider).track(Events.bookmarkReviewStart, {
      EventParams.totalSentencesCount: _sentences.length,
    });

    // 注入 recorder 到录音控制器
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(_recorder);
  }

  /// 更新练习设置（仅会话内生效）
  ///
  /// 设置更新后立即应用到当前句。速度变化只推给 AudioEngine，不重启会话。
  Future<void> updateSettings(DifficultPracticeSettings newSettings) async {
    recordDifficultPracticeChange(
      ref,
      _settingsSlot,
      state.settings,
      newSettings,
    );
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
            .read(foregroundAudioEngineProvider.notifier)
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

    if (wasAnnotation) {
      _startRepeatFlow(autoplay: !annotationWaitingForUser);
      return;
    }

    await _startBlindFlow(autoplay: !blindWaitingForUser);
  }

  /// 当前句进入手动模式（工具栏点击、手动停止播放等触发）
  ///
  /// 同时暂停盲听倒计时 + 取消评估后倒计时，防止自动推进。
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
      ? _sentences[state.currentSentenceIndex].sentence
      : null;

  /// 获取当前收藏句子（含音频信息）
  BookmarkSentence? get currentBookmarkSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 跟读流程引擎（跟读模式时有值，供 Screen 读取 engine API）
  RepeatFlowEngine? get repeatEngine => _repeatEngine;

  /// 开始播放
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startBlindFlow();
  }

  /// 外部中断播放通知（如意群播放）
  void notifyExternalStop() {
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 暂停播放
  void pause() {
    _engine.invalidateSession();
    if (state.isAnnotationMode) {
      _repeatEngine?.enterWaitingForUser();
    } else {
      _blindEngine.enterWaitingForUser();
    }
    _studyStopwatch.stop();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放
  ///
  /// 跟读模式下从当前遍数恢复跟读循环。
  /// 盲听模式下从当前句重新开始。
  Future<void> resume() async {
    _studyStopwatch.start();
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

  /// 设置偷看字幕状态
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 盲听模式下，用户显式接管流程（设置/偷看/查词）。
  void enterWaitingForUserInBlindMode() {
    if (state.isAnnotationMode) return;
    _blindEngine.enterWaitingForUser(afterCurrentPrompt: true);
  }

  /// 取消当前句子的收藏
  ///
  /// 返回被移除的 [BookmarkSentence]（供外部调用 BookmarkDao 删除）。
  BookmarkSentence? removeBookmark() {
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
      isCountdownPaused: false,
      isCountdownFastForward: false,
      currentPlayCount: 1,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );

    return removed;
  }

  /// 切换当前句子的收藏标记（不从列表移除）
  Future<void> toggleCurrentBookmark() async {
    if (_sentences.isEmpty) return;
    final idx = state.currentSentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.sentence.isBookmarked;
    _sentences[idx] = s.copyWithBookmark(!s.sentence.isBookmarked);
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (wasBookmarked) {
      await bookmarkDao.removeBookmark(s.audioItemId, s.originalSentenceIndex);
      return;
    }

    await BookmarkManager.addBookmarkToDb(
      s.audioItemId,
      s.sentence,
      dao: bookmarkDao,
    );
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

  /// 跳到下一句
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

  /// 跳到上一句
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

  /// 暂停倒计时
  void pauseCountdown() {
    if (state.isAnnotationMode) {
      _repeatEngine?.pauseInterval();
      return;
    }
    _blindEngine.pauseInterval();
  }

  /// 恢复倒计时
  void resumeCountdown() {
    if (state.isAnnotationMode) {
      _repeatEngine?.resumeInterval();
      return;
    }
    _blindEngine.resumeInterval();
  }

  /// 盲听倒计时快进（动态速度，~1.5 秒内结束）。
  void toggleCountdownFastForward() {
    if (state.isAnnotationMode) return;
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

  /// 倒计时期间重播当前句子
  Future<void> replayDuringCountdown() async {
    if (state.isAnnotationMode) {
      await _repeatEngine?.replayCurrentSentence();
      return;
    }
    _engine.invalidateSession();
    await _blindEngine.replayCurrentSentence();
  }

  /// 强制完成（用户在最后一句主动点击完成按钮）
  void forceComplete() {
    _engine.invalidateSession();
    _blindEngine.stopSession();
    _exitAnnotationMode();
    _studyStopwatch.stop();
    _stopPeriodicSaveTimer();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      clearRepeatFlowState: true,
      clearBlindFlowState: true,
    );
  }

  /// 重置到第一句并重新乱序播放（"再来一遍"）
  Future<void> resetToStart() async {
    _exitAnnotationMode();
    // 先保存已累计时间
    _saveAndRefreshStudyTime();
    _engine.cleanup();
    _blindEngine.stopSession();

    // 重新按音频分组乱序
    final grouped = <String, List<BookmarkSentence>>{};
    for (final s in _sentences) {
      (grouped[s.audioItemId] ??= []).add(s);
    }
    final audioIds = grouped.keys.toList()..shuffle();
    _sentences = [];
    for (final audioId in audioIds) {
      _sentences.addAll(grouped[audioId]!);
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
      // 收藏句复习不绑学习流程,无难度速度,智能默认速度取 1.0;偏好按固定槽位记忆。
      settings: ref
          .read(difficultPracticePrefsProvider.notifier)
          .resolve(_settingsSlot, smartSpeed: 1.0),
    );
    _prepareBlindFlow();

    // 重新启动计时 + 周期保存
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave();

    await startPlaying();
  }

  /// 释放资源
  void disposePlayer() {
    ref.read(speechRecordingControllerProvider.notifier).setRecorder(null);
    _stopPeriodicSaveTimer();
    _saveAndRefreshStudyTime();
    _engine.cleanup();
    _blindEngine.stopSession();
    _repeatEngine?.dispose();
    _repeatEngine = null;
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  // ========== 跟读模式（RepeatFlowEngine） ==========

  /// 启动跟读流程引擎
  void _startRepeatFlow({bool autoplay = true}) {
    final sentence = currentSentence;
    final bookmarkSentence = currentBookmarkSentence;
    if (sentence == null ||
        bookmarkSentence == null ||
        sentence.duration <= Duration.zero) {
      return;
    }

    _repeatEngine ??= RepeatFlowEngine(
      onStateChanged: _onRepeatFlowStateChanged,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () =>
            ref.read(foregroundAudioEngineProvider.notifier).pause(),
        playSentence: _playSentenceForRepeat,
        startRecording: _startRecordingForRepeat,
        cancelRecording: _cancelRecordingForRepeat,
        stopAndEvaluate: _stopAndEvaluateForRepeat,
        clearRecording: _clearRecordingForRepeat,
        setMaxRecordingDuration: _setMaxRecordingDuration,
        hasDetectedSpeech: _hasDetectedSpeech,
      ),
      logTag: 'BookmarkRepeat',
    );

    _repeatEngine!.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: bookmarkSentence.audioItemId,
        promptIdPrefix: 'bookmark',
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

    if (flowState.phase is SessionCompleted) {
      _exitAnnotationMode();
      state = state.copyWith(
        isAnnotationMode: false,
        isPlaying: false,
        isPauseBetweenPlays: false,
        clearRepeatFlowState: true,
      );
      unawaited(_advanceAfterAnnotationCompleted());
    }
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
    }

    if (_repeatEngine!.state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null) {
      _repeatEngine!.onRecordingCancelled();
    }
  }

  // ========== 内部方法 ==========

  /// 确保当前句子的音频已加载
  ///
  /// 如果当前 AudioEngine 加载的不是同一音频，则切换。
  /// 返回 false 表示加载失败（应跳过该句）。
  Future<bool> _ensureAudioLoaded(BookmarkSentence bookmarkSentence) async {
    final engineState = ref.read(foregroundAudioEngineProvider);
    if (engineState.currentAudioId == bookmarkSentence.audioItemId) {
      return true;
    }

    try {
      final row = await _getAudioItemById(bookmarkSentence.audioItemId);
      if (row == null) return false;

      final audioItem = model.AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isPinned: row.isPinned,
        transcriptSource: model.TranscriptSource.fromIndex(
          row.transcriptSource,
        ),
        audioSha256: row.audioSha256,
        originalAudioSha256: row.originalAudioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      final engine = ref.read(foregroundAudioEngineProvider.notifier);
      await engine.loadAudio(audioItem, 1.0);
      return true;
    } catch (e) {
      AppLogger.log('Player', '✗ 收藏复习加载音频失败: $e');
      return false;
    }
  }

  /// 准备盲听引擎。
  void _prepareBlindFlow({int? startIndex}) {
    _blindEngine.prepare(
      sentences: _sentences.map((item) => item.sentence).toList(),
      startIndex: startIndex ?? state.currentSentenceIndex,
      config: BlindPracticeFlowConfig(
        getRepeatCount: (_) =>
            state.isManualMode ? 1 : state.settings.blindListenRepeatCount,
        getRepeatIntervalDuration: (sentence) =>
            listenAndRepeatPauseCalculator(sentence.duration),
        getSentenceIntervalDuration: (sentence) =>
            state.settings.calculateInterSentencePause(sentence.duration),
        onBeforeSentenceStart: _ensureBlindSentenceReady,
        onSentencePlayed: _recorder.onSentencePlayed,
      ),
    );
  }

  /// 启动盲听流程。
  Future<void> _startBlindFlow({bool autoplay = true}) async {
    if (_sentences.isEmpty) return;
    _prepareBlindFlow();
    if (autoplay) {
      await _blindEngine.startPlaying();
      return;
    }
    await _blindEngine.restartCurrentSentence(autoplay: false);
  }

  /// 盲听模式确保当前句可播。
  Future<bool> _ensureBlindSentenceReady(int sentenceIndex) async {
    if (sentenceIndex < 0 || sentenceIndex >= _sentences.length) return false;
    return _ensureAudioLoaded(_sentences[sentenceIndex]);
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

    // 收藏句复习改用前台引擎、不进后台、不上锁屏（用户 2026-06-27 确认，见 ADR-7）。
    if (phase is BlindSessionCompleted) {
      _studyStopwatch.stop();
      _stopPeriodicSaveTimer();
    }
  }

  /// 盲听播放一遍当前句。
  Future<bool> _playSentenceForBlind(Sentence sentence, int flowToken) async {
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    return true;
  }

  /// 停止计时并保存已记录的学习时长，刷新统计 UI
  ///
  /// 输入/输出时间已由 [StudyEventRecorder] 事件驱动写入，无需周期保存。
  /// 所有时长 clamp 到 [_maxSessionSeconds]，防止用户睡着等异常场景。
  /// 使用 [_isSaving] 标志位防止周期保存定时器与 dispose 竞态 double-save。
  Future<void> _saveAndRefreshStudyTime() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      if (!_studyStopwatch.isRunning &&
          _studyStopwatch.elapsed == Duration.zero) {
        return;
      }
      _studyStopwatch.stop();
      final seconds = _studyStopwatch.elapsed.inSeconds.clamp(
        0,
        _maxSessionSeconds,
      );
      _studyStopwatch.reset();
      if (seconds > 0) {
        await _studyTimeService.addStudyTime(
          seconds,
          stage: StudyStage.bookmarkReview,
        );
      }
      ref.read(dailyStudyTimeProvider.notifier).refresh();
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    } finally {
      _isSaving = false;
    }
  }

  /// 累加输出词数并刷新统计 UI
  Future<void> _addOutputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addOutputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _playSentenceForRepeat(Sentence sentence, int flowToken) async {
    final bookmarkSentence = currentBookmarkSentence;
    if (bookmarkSentence == null) return;

    final loaded = await _ensureAudioLoaded(bookmarkSentence);
    if (!loaded) {
      AppLogger.log('BookmarkRepeat', '✗ 跟读模式加载音频失败，跳过当前句');
      if (state.currentSentenceIndex >= state.totalSentences - 1) {
        _exitAnnotationMode();
        state = state.copyWith(
          isAnnotationMode: false,
          isPlaying: false,
          stepFinished: true,
          clearRepeatFlowState: true,
        );
        _studyStopwatch.stop();
        _stopPeriodicSaveTimer();
      } else {
        await goToNext();
      }
      return;
    }

    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(state.settings.playbackSpeed);
    await engine.playClipOnce(sentence, sessionId);
    unawaited(_addOutputWords(countWords(sentence.text)));
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
}

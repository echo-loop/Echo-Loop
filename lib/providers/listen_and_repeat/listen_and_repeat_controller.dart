/// 跟读会话控制器
///
/// 组合 [RepeatFlowEngine] 驱动跟读流程，添加跟读页面专属逻辑：
/// - 初始化（读书签/断点/设置）
/// - 页面级学习统计计时与录音输出统计
/// - 书签管理、断点保存、进度统计
///
/// Screen 只读 state、只调公开方法，不直接操作资源服务。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/enums.dart' show LearningStage;
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/audio_item.dart';
import '../../models/media_load_result.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/sentence.dart';
import '../../models/sentence_playback_result.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/pronunciation/local_audio_clip_player.dart';
import '../../services/study_session_timer.dart';
import '../../services/study_time_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../daily_study_time_provider.dart';
import '../study_duration_provider.dart';
import '../study_stats_provider.dart';
import '../listening_practice/listening_practice_provider.dart';
import '../learning_progress_provider.dart';
import '../learning_session/sentence_playback_engine.dart';
import '../learning_session/intensive_listen_playback_driver.dart';
import '../media_engine/media_engine_provider.dart';
import '../media_engine/media_sense_group_range_playback.dart';
import '../repeat_flow/repeat_flow_engine.dart';
import '../repeat_flow/repeat_flow_phase.dart';
import '../repeat_flow/repeat_flow_state.dart';
import '../speech/speech_recording_controller.dart';
import '../listening_practice/bookmark_manager.dart';
import '../pronunciation/pronunciation_providers.dart';
import '../favorite_sentence_lifecycle_provider.dart';
import '../intensive_listen_prefs_provider.dart';
import '../../models/stage_settings_overrides.dart';
import 'listen_and_repeat_session_state.dart';
import 'listen_and_repeat_settings_provider.dart';

part 'listen_and_repeat_controller.g.dart';

/// 跟读会话控制器
@riverpod
class ListenAndRepeatController extends _$ListenAndRepeatController {
  /// 跟读流程引擎
  late final RepeatFlowEngine _engine;

  /// 当前会话的句子播放驱动；音频与视频共用同一流程状态机。
  late SentencePlaybackDriver _playback;

  /// 是否为自由练习模式
  bool _isFreePlay = false;

  /// 当前会话句子列表（包含页面级业务字段，如 bookmark 状态）
  List<Sentence> _sentences = [];
  bool _usesMediaEngine = false;
  int _mediaEntryGeneration = 0;
  bool _mediaSessionReady = false;
  bool _sessionPrepared = false;
  MediaEngine? _ownedMediaEngine;
  int? _ownedMediaGeneration;
  SenseGroupRangePlayback? _senseGroupRangePlayback;
  late StudyTimeService _studyTimeService;
  StudySessionTimer? _studySessionTimer;
  Future<void>? _exitInFlight;
  String? _studyAudioItemId;
  bool _manageForegroundAudioEngine = true;
  int _studySessionGeneration = 0;
  int _entryGeneration = 0;

  @override
  ListenAndRepeatSessionState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    final speechController = ref.read(
      speechRecordingControllerProvider.notifier,
    );
    _playback = ForegroundSentencePlaybackDriver(
      ref.read(foregroundAudioEngineProvider.notifier),
    );
    // 创建引擎
    _engine = RepeatFlowEngine(
      onStateChanged: _onEngineStateChanged,
      callbacks: RepeatFlowCallbacks(
        // 运行时读取当前驱动：媒体初始化会替换 [_playback]，不能捕获旧音频实例。
        pauseAudio: _pauseAudio,
        playSentence: _playSentence,
        startRecording: _startRecording,
        cancelRecording: _cancelRecording,
        stopAndEvaluate: _stopAndEvaluate,
        clearRecording: _clearRecording,
        setMaxRecordingDuration: _setMaxRecordingDuration,
        hasDetectedSpeech: _hasDetectedSpeech,
      ),
      logTag: 'L&R',
    );

    // 监听录音控制器状态变化 → 桥接到 engine
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);

    // 打印状态变化日志
    listenSelf((prev, next) {
      if (prev?.phase.runtimeType != next.phase.runtimeType ||
          prev?.sentenceIndex != next.sentenceIndex ||
          prev?.repeatIndex != next.repeatIndex) {
        final recPhase = ref.read(speechRecordingControllerProvider).phase;
        AppLogger.log(
          'L&R State',
          '${next.phase.runtimeType} | '
              '句${next.sentenceIndex + 1}/${next.totalSentences} '
              '遍${next.repeatIndex + 1}/${next.totalRepeats} | '
              '录音=$recPhase | '
              'sessionId=${next.sessionId} token=${next.flowToken} '
              'controlMode=${next.controlMode.name} '
              'postRecordingAction=${next.postRecordingAction.name} '
              'transitioning=${next.isTransitioning}',
        );
      }
    });

    ref.onDispose(() {
      _playback.unbindLockScreen();
      _engine.dispose();
      speechController.setRecordingCompletionHandler(null);
      final mediaEngine = _ownedMediaEngine;
      if (mediaEngine != null) unawaited(mediaEngine.releaseFromScreen());
      unawaited(_disposeStudySessionOnProviderDispose());
    });
    return const ListenAndRepeatSessionState();
  }

  // ========== 初始化 ==========

  /// 初始化跟读任务（从 DB 读数据 + 启动学习计时 + 准备会话）
  ///
  /// [smartSpeed] 按当前难度/阶段算出的动态默认速度;用户未在偏好里设过速度时用它。
  /// 句间停顿/遍数等其余设置由按槽位偏好 [intensiveListenPrefsProvider] resolve 出。
  Future<void> initialize({
    required String audioItemId,
    required List<Sentence> allSentences,
    required bool isFreePlay,
    ListenAndRepeatScope scope = ListenAndRepeatScope.difficultOnly,
    double smartSpeed = 1.0,
    LearningStage? stage,
    SentencePlaybackDriver? playbackDriver,
    bool usesMediaEngine = false,
  }) async {
    AppLogger.log(
      'L&R Session',
      'event=open_begin audioItemId=$audioItemId isFreePlay=$isFreePlay '
          'usesMediaEngine=$usesMediaEngine',
    );
    try {
      await _initialize(
        audioItemId: audioItemId,
        allSentences: allSentences,
        isFreePlay: isFreePlay,
        scope: scope,
        smartSpeed: smartSpeed,
        stage: stage,
        playbackDriver: playbackDriver,
        usesMediaEngine: usesMediaEngine,
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'L&R Session',
        'event=open_failed audioItemId=$audioItemId '
            'usesMediaEngine=$usesMediaEngine error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> _initialize({
    required String audioItemId,
    required List<Sentence> allSentences,
    required bool isFreePlay,
    ListenAndRepeatScope scope = ListenAndRepeatScope.difficultOnly,
    double smartSpeed = 1.0,
    LearningStage? stage,
    SentencePlaybackDriver? playbackDriver,
    bool usesMediaEngine = false,
  }) async {
    final entryGeneration = ++_entryGeneration;
    bool isCurrentEntry() => entryGeneration == _entryGeneration;
    await _disposeStudySessionTimer();
    if (!isCurrentEntry()) return;
    _studySessionGeneration += 1;
    _studyAudioItemId = audioItemId;
    _manageForegroundAudioEngine = !usesMediaEngine;
    _sessionPrepared = false;
    _isFreePlay = isFreePlay;
    _usesMediaEngine = usesMediaEngine;
    if (!usesMediaEngine) _senseGroupRangePlayback = null;
    _playback =
        playbackDriver ??
        ForegroundSentencePlaybackDriver(
          ref.read(foregroundAudioEngineProvider.notifier),
        );

    // 录音类任务用前台引擎播放原句、不上锁屏。进任务停掉媒体引擎，清除上一个媒体任务
    // （精听/盲听/Free Player）残留的锁屏/通知栏卡片（非idle→idle → stopService）。
    await ref.read(audioEngineProvider.notifier).stop();
    if (!isCurrentEntry()) return;

    // 从 DB 读难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );
    if (!isCurrentEntry()) return;
    // 难句列表来自数据库索引，而 [allSentences] 只承载字幕正文；进入跟读会话前
    // 必须同步收藏态，否则首句会被误判为“未收藏”，点击后还会走新增分支。
    final sessionSentences = BookmarkManager.createSentenceBookmarkSnapshot(
      allSentences,
      bookmarkedIndices,
    );
    final practiceSentences = switch (scope) {
      ListenAndRepeatScope.fullText => sessionSentences,
      ListenAndRepeatScope.difficultOnly =>
        sessionSentences
            .where((s) => bookmarkedIndices.contains(s.index))
            .toList(),
    };

    // 从 DB 读断点
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    if (!isCurrentEntry()) return;
    int startIndex = 0;
    if (isFreePlay) {
      startIndex = progress.freePlayShadowingSentenceIndex ?? 0;
    } else {
      startIndex = progress.shadowingSentenceIndex ?? 0;
    }

    // 根据难度计算目标遍数(动态默认遍数)
    final targetPlayCount = targetPlayCountForDifficulty(
      progress.difficulty.value,
    );

    // 难句跟读仅在首学,槽位固定;自由练习与按计划共用同一份偏好记忆。
    final slot = stageSlotKey(
      StageSettingsSlots.listenAndRepeat,
      stage ?? LearningStage.firstLearn,
    );
    final settings = ref
        .read(intensiveListenPrefsProvider.notifier)
        .resolve(
          slot,
          smartSpeed: smartSpeed,
          smartRepeatCount: targetPlayCount,
        );

    // 初始化设置(完整设置 = 偏好叠加智能默认/动态遍数)
    ref
        .read(listenAndRepeatSettingsProvider.notifier)
        .initialize(settings, slot);

    // 跟读页面独占前台学习资源，避免自由播放器在页面内继续响应播放事件。
    ref.read(listeningPracticeProvider.notifier).suspendListeners();
    if (_manageForegroundAudioEngine) {
      await _ensureForegroundAudioLoaded(audioItemId);
      if (!isCurrentEntry()) return;
    }

    final studySessionGeneration = _studySessionGeneration;
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setRecordingCompletionHandler(
          (duration) =>
              _recordSpeechRecognition(duration, studySessionGeneration),
        );

    // 构造 config 并准备会话
    final config = RepeatFlowConfig(
      audioItemId: audioItemId,
      promptIdPrefix: 'lar',
      getRepeatCount: (_) =>
          ref.read(listenAndRepeatSettingsProvider).repeatCount,
      getIntervalDuration: (s) {
        final st = ref.read(listenAndRepeatSettingsProvider);
        return switch (st.pauseMode) {
          PauseMode.smart => Duration(
            milliseconds: (1000 + (s.duration.inMilliseconds * 0.6).round())
                .clamp(kSmartPauseMinMs, kSmartPauseMaxMs),
          ),
          PauseMode.fixed => Duration(seconds: st.fixedPauseSeconds),
          PauseMode.multiplier => Duration(
            milliseconds: math.max(
              (s.duration.inMilliseconds * st.pauseMultiplier).round(),
              kMultiplierPauseMinMs,
            ),
          ),
        };
      },
      isManualMode: () =>
          ref.read(listenAndRepeatSettingsProvider).isManualMode,
    );

    await prepareSession(
      sentences: practiceSentences,
      config: config,
      startIndex: startIndex,
      isFreePlay: isFreePlay,
    );
    final timer = StudySessionTimer(
      studyTimeService: _studyTimeService,
      stage: StudyStage.listenAndRepeat,
      activityGate: ref.read(studyActivityGateProvider),
      idleTimeout: const Duration(minutes: 2),
      logScope: 'ListenAndRepeatTimer',
    );
    _studySessionTimer = timer;
    timer.start();
    AppLogger.log(
      'L&R Session',
      'event=timer_started sessionId=${state.sessionId} '
          'audioItemId=$audioItemId',
    );
    AppLogger.log(
      'L&R Session',
      'event=ready sessionId=${state.sessionId} audioItemId=$audioItemId '
          'sentenceCount=${practiceSentences.length} '
          'isFreePlay=$isFreePlay usesMediaEngine=$usesMediaEngine',
    );
    ref.read(analyticsServiceProvider).track(Events.learningStart, {
      ...ref.audioEventParams(audioItemId),
      EventParams.stage: StudyStage.listenAndRepeat.name,
      EventParams.isFreePractice: isFreePlay ? 1 : 0,
    });
    _playback.bindLockScreen(
      onPlay: replayCurrentSentence,
      onPause: () async => enterWaitingForUser(),
      onNext: nextSentence,
      onPrevious: previousSentence,
    );
    ref.read(analyticsServiceProvider).track(Events.listenRepeatStart, {
      ...ref.audioEventParams(audioItemId),
      EventParams.totalSentences: practiceSentences.length,
    });
  }

  /// 使用逐句精听同一 MediaEngine 初始化视频难句跟读。
  Future<MediaLoadResult> initializeMedia({
    required AudioItem mediaItem,
    required List<Sentence> allSentences,
    required bool isFreePlay,
    ListenAndRepeatScope scope = ListenAndRepeatScope.difficultOnly,
    double smartSpeed = 1.0,
    LearningStage? stage,
  }) async {
    final generation = ++_mediaEntryGeneration;
    bool isCurrent() => generation == _mediaEntryGeneration;
    AppLogger.log(
      'L&R MediaEntry',
      '开始加载: mediaId=${mediaItem.id}, generation=$generation',
    );

    await ref.read(audioEngineProvider.notifier).stop();
    if (!isCurrent()) return MediaLoadResult.cancelled;

    final settingsSlot = stageSlotKey(
      StageSettingsSlots.listenAndRepeat,
      stage ?? LearningStage.firstLearn,
    );
    final settings = ref
        .read(intensiveListenPrefsProvider.notifier)
        .resolve(settingsSlot, smartSpeed: smartSpeed);
    final mediaEngine = ref.read(mediaEngineProvider.notifier);
    _ownedMediaEngine = mediaEngine;
    _ownedMediaGeneration = generation;
    final duration = await mediaEngine.loadMedia(
      mediaItem,
      settings.playbackSpeed,
    );
    if (!isCurrent()) {
      AppLogger.log(
        'L&R MediaEntry',
        '加载结果已过期，释放媒体: mediaId=${mediaItem.id}, generation=$generation',
      );
      await _releaseOwnedMediaEngine(mediaEngine, generation);
      return MediaLoadResult.cancelled;
    }
    if (duration == null) {
      AppLogger.log(
        'L&R MediaEntry',
        '加载失败，释放媒体: mediaId=${mediaItem.id}, generation=$generation',
      );
      await _releaseOwnedMediaEngine(mediaEngine, generation);
      return MediaLoadResult.failure;
    }

    // 与逐句精听的呈现规则一致：视频字幕轨默认关闭，用户点 CC 后再按需加载。
    await mediaEngine.setSubtitleTrackData(null);
    if (!isCurrent()) {
      AppLogger.log(
        'L&R MediaEntry',
        '字幕初始化后任务已取消: mediaId=${mediaItem.id}, generation=$generation',
      );
      await _releaseOwnedMediaEngine(mediaEngine, generation);
      return MediaLoadResult.cancelled;
    }

    _senseGroupRangePlayback = MediaSenseGroupRangePlayback(
      engine: mediaEngine,
      playbackSpeed: () =>
          ref.read(listenAndRepeatSettingsProvider).playbackSpeed,
    );
    await initialize(
      audioItemId: mediaItem.id,
      allSentences: allSentences,
      isFreePlay: isFreePlay,
      scope: scope,
      smartSpeed: smartSpeed,
      stage: stage,
      playbackDriver: MediaSentencePlaybackDriver(mediaEngine),
      usesMediaEngine: true,
    );
    if (!isCurrent()) {
      AppLogger.log(
        'L&R MediaEntry',
        '业务初始化后任务已取消: mediaId=${mediaItem.id}, generation=$generation',
      );
      await exitLearningMode();
      return MediaLoadResult.cancelled;
    }
    _mediaSessionReady = true;
    AppLogger.log(
      'L&R MediaEntry',
      '加载完成: mediaId=${mediaItem.id}, generation=$generation',
    );
    return MediaLoadResult.ready;
  }

  /// 取消正在进入的视频跟读；迟到结果由 generation guard 丢弃。
  Future<void> cancelMediaEntry() async {
    ++_entryGeneration;
    final generation = ++_mediaEntryGeneration;
    AppLogger.log(
      'L&R MediaEntry',
      '取消进入: generation=$generation, ready=$_mediaSessionReady',
    );
    if (_mediaSessionReady) {
      await exitLearningMode();
    } else {
      final mediaEngine = _ownedMediaEngine;
      final mediaGeneration = _ownedMediaGeneration;
      if (mediaEngine != null && mediaGeneration != null) {
        await _releaseOwnedMediaEngine(mediaEngine, mediaGeneration);
      }
    }
  }

  /// 取消音频或视频跟读进入流程；迟到的初始化结果不得重新建立会话。
  Future<void> cancelEntry() async {
    ++_entryGeneration;
    ++_mediaEntryGeneration;
    AppLogger.log('L&R Session', 'event=startup_cancelled');
    if (_sessionPrepared || _studyAudioItemId != null) {
      await exitLearningMode();
    }
  }

  // ========== 公开方法（Screen 调用） ==========

  /// 准备会话数据
  Future<void> prepareSession({
    required List<Sentence> sentences,
    required RepeatFlowConfig config,
    int startIndex = 0,
    bool isFreePlay = false,
  }) async {
    _isFreePlay = isFreePlay;
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _engine.prepare(
      sentences: _sentences,
      config: config,
      startIndex: startIndex,
    );
    _sessionPrepared = true;

    // 同步录音控制器模式
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(config.isManualMode());
  }

  /// 开始播放
  Future<void> startPlaying() async => _engine.startPlaying();

  /// 将速度应用到当前实际播放驱动，音频仍委托原前台引擎。
  Future<void> applyPlaybackSpeed(double speed) => _playback.setSpeed(speed);

  /// 进入等待用户操作状态
  void enterWaitingForUser() => _engine.enterWaitingForUser();

  /// 当前原句播完后进入等待用户操作状态。
  void enterWaitingForUserAfterCurrentPrompt() =>
      _engine.enterWaitingForUser(afterCurrentPrompt: true);

  /// 用户交互（查词/翻译等）
  void onUserInteraction() => _engine.onUserInteraction();

  /// 下一句
  Future<void> nextSentence({
    RepeatNavigationSource source = RepeatNavigationSource.nextArrow,
  }) async => _engine.nextSentence(source: source);

  /// 上一句
  Future<void> previousSentence({
    RepeatNavigationSource source = RepeatNavigationSource.previousArrow,
  }) async => _engine.previousSentence(source: source);

  /// 跳转到指定句子（0-based，供进度条拖动跳转使用）
  Future<void> goToSentence(
    int index, {
    RepeatNavigationSource source = RepeatNavigationSource.explicit,
  }) async => _engine.goToSentence(index, source: source);

  /// 录音按钮点击
  Future<void> onRecordButtonTapped() async => _engine.onRecordButtonTapped();

  /// 录音回放按钮点击
  Future<void> togglePlayback() async => _engine.togglePlayback();

  /// 为播放录音回放做准备。
  void prepareForPlayback() => _engine.prepareForPlayback();

  /// 手动开始录音
  void startManualRecording() => _engine.startManualRecording();

  /// 手动停止录音
  Future<void> stopRecording() async => _engine.stopRecording();

  /// 播放录音回放
  Future<void> playRecording() async => _engine.playRecording();

  /// 停止录音回放
  Future<void> stopPlayback() async => _engine.stopPlayback();

  /// 当前媒体会话的意群区间播放；音频会话保持既有播放路径，因此不暴露实现。
  SenseGroupRangePlayback? get senseGroupRangePlayback =>
      _senseGroupRangePlayback;

  /// 快进倒计时
  void fastForwardInterval() => _engine.fastForwardInterval();

  /// 暂停倒计时
  void pauseInterval() => _engine.pauseInterval();

  /// 恢复倒计时
  void resumeInterval() => _engine.resumeInterval();

  /// 重播当前句子
  Future<void> replayCurrentSentence() async => _engine.replayCurrentSentence();

  /// 停止会话
  void stopSession() => _engine.stopSession();

  /// 释放流程和录音资源。
  Future<void> disposeSession() async {
    await _playback.invalidateSession();
    _playback.unbindLockScreen();
    _engine.stopSession();
    await ref.read(speechRecordingControllerProvider.notifier).fullReset();
  }

  /// 应用会话内设置变更，并立即按新配置重建当前句流程。
  ///
  /// 设置面板是即时写回 Provider 的，因此这里不能等弹窗关闭后再处理。
  Future<void> applySettingsChange() async {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(_engine.config.isManualMode());
    if (_engine.willEnterWaitingAfterCurrentPrompt) {
      return;
    }
    // 等待态只刷新当前句配置，不应立刻自动重播。
    await _engine.restartCurrentSentence(
      autoplay: state.phase is! WaitingForUser,
    );
  }

  /// 标记跟读页面仍有用户活动，使页面级学习计时器恢复计时。
  void markStudyActivity() => _studySessionTimer?.markActivity();

  /// 暂停完成弹窗期间的页面计时，不影响跟读流程状态。
  void pauseStudySession() => _studySessionTimer?.pause();

  /// 恢复完成弹窗取消后的页面计时。
  void resumeStudySession() => _studySessionTimer?.resume();

  /// 当前跟读页面累计的有效学习时长，供结束埋点复用。
  Duration get elapsed => _studySessionTimer?.elapsed ?? Duration.zero;

  // ========== 书签 & 进度 ==========

  /// 切换当前句子的收藏标记
  Future<void> toggleCurrentBookmark() async {
    if (_sentences.isEmpty) return;
    final idx = state.sentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.isBookmarked;
    _sentences[idx] = s.copyWith(isBookmarked: !wasBookmarked);
    state = state.copyWith(currentSentenceBookmarked: !wasBookmarked);

    if (wasBookmarked) {
      await ref.read(favoriteSentenceLifecycleProvider).remove(
        _engine.config.audioItemId,
        {s.index},
      );
    } else {
      await ref
          .read(favoriteSentenceLifecycleProvider)
          .save(_engine.config.audioItemId, s);
    }
  }

  /// 保存断点
  Future<void> saveBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _engine.config.audioItemId,
          state.sentenceIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 清除断点
  Future<void> clearBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _engine.config.audioItemId,
          null,
          isFreePlay: isFreePlay,
        );
  }

  /// 递增遍数统计
  Future<void> incrementPassCount() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementShadowingPassCount(_engine.config.audioItemId);
  }

  /// 标记当前子步骤完成
  Future<void> completeSubStage() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage(_engine.config.audioItemId);
  }

  /// 幂等退出跟读页面，并刷写页面计时器和统计队列。
  Future<void> exitLearningMode() {
    final inFlight = _exitInFlight;
    if (inFlight != null) return inFlight;

    late final Future<void> tracked;
    tracked = _exitLearningModeInternal().whenComplete(() {
      if (identical(_exitInFlight, tracked)) _exitInFlight = null;
    });
    _exitInFlight = tracked;
    return tracked;
  }

  // ========== 数据访问 ==========

  /// 当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.sentenceIndex < _sentences.length
      ? _sentences[state.sentenceIndex]
      : null;

  /// 当前 promptId
  String get currentPromptId => _sessionPrepared
      ? _engine.currentPromptId
      : 'lar:pending:${state.sentenceIndex}';

  /// 当前跟读流程是否已经完成配置，可安全接收播放与设置操作。
  bool get isSessionPrepared => _sessionPrepared;

  /// 当前配置
  RepeatFlowConfig get config => _engine.config;

  /// 当前句子索引
  int get currentIndex => state.sentenceIndex;

  /// 句子列表
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 确保前台音频引擎已经加载当前学习材料。
  Future<void> _ensureForegroundAudioLoaded(String audioItemId) async {
    final engineState = ref.read(foregroundAudioEngineProvider);
    if (engineState.currentAudioId == audioItemId && !engineState.isLoading) {
      return;
    }
    final practice = ref.read(listeningPracticeProvider);
    final audioItem = practice.currentAudioItem;
    if (audioItem != null && audioItem.id == audioItemId) {
      await ref
          .read(foregroundAudioEngineProvider.notifier)
          .loadAudio(audioItem, practice.settings.playbackSpeed);
    }
  }

  /// 仅释放仍由指定 generation 持有的媒体，避免旧异步回调释放新会话。
  Future<void> _releaseOwnedMediaEngine(
    MediaEngine mediaEngine,
    int generation,
  ) async {
    if (!identical(_ownedMediaEngine, mediaEngine) ||
        _ownedMediaGeneration != generation) {
      return;
    }
    _ownedMediaEngine = null;
    _ownedMediaGeneration = null;
    await mediaEngine.releaseFromScreen();
  }

  /// 记录一次跟读录音的有效输出时长，并丢弃退出后的迟到回调。
  void _recordSpeechRecognition(Duration duration, int sessionGeneration) {
    if (sessionGeneration != _studySessionGeneration ||
        _studySessionTimer == null) {
      AppLogger.log(
        'ListenAndRepeatStats',
        'speechRecognition.discarded durationMs=${duration.inMilliseconds} '
            'callbackGeneration=$sessionGeneration '
            'currentGeneration=$_studySessionGeneration '
            'hasTimer=${_studySessionTimer != null}',
      );
      return;
    }
    AppLogger.log(
      'ListenAndRepeatStats',
      'speechRecognition.submit stage=${StudyStage.listenAndRepeat.name} '
          'durationMs=${duration.inMilliseconds} generation=$sessionGeneration',
    );
    _studyTimeService.submitSpeechRecognition(
      duration: duration,
      stage: StudyStage.listenAndRepeat,
    );
  }

  /// 释放当前页面计时器；初始化新会话时也复用此方法，避免计时器泄漏。
  Future<void> _disposeStudySessionTimer() async {
    final timer = _studySessionTimer;
    _studySessionTimer = null;
    if (timer == null) return;
    try {
      await timer.dispose();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat timer cleanup failed '
            'error=$error\n$stackTrace',
      );
    }
  }

  /// Provider 被动销毁时兜底刷写统计队列，避免非路由退出丢失异步事件。
  Future<void> _disposeStudySessionOnProviderDispose() async {
    await _disposeStudySessionTimer();
    try {
      await _studyTimeService.flush();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat provider statistics flush failed '
            'error=$error\n$stackTrace',
      );
    }
  }

  Future<void> _exitLearningModeInternal() async {
    final audioItemId = _studyAudioItemId;
    final wasPrepared = _sessionPrepared;
    final studyDuration = elapsed;
    final timer = _studySessionTimer;
    final sessionId = state.sessionId;
    final usesMediaEngine = _usesMediaEngine;
    final manageForegroundAudioEngine = _manageForegroundAudioEngine;
    AppLogger.log(
      'L&R Session',
      'event=close_begin sessionId=$sessionId '
          'audioItemId=$audioItemId elapsedMs=${studyDuration.inMilliseconds} '
          'timerReady=${timer != null}',
    );

    _entryGeneration += 1;
    _studySessionGeneration += 1;
    _mediaEntryGeneration += 1;

    if (wasPrepared && audioItemId != null) {
      ref.read(analyticsServiceProvider).track(Events.listenRepeatComplete, {
        ...ref.audioEventParams(audioItemId),
        EventParams.totalSentences: _sentences.length,
      });
    }
    if (audioItemId != null) {
      ref.read(analyticsServiceProvider).track(Events.learningEnd, {
        ...ref.audioEventParams(audioItemId),
        EventParams.stage: StudyStage.listenAndRepeat.name,
        EventParams.durationMs: studyDuration.inMilliseconds,
        EventParams.isFreePractice: _isFreePlay ? 1 : 0,
      });
    }

    try {
      await disposeSession();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat session cleanup failed '
            'error=$error\n$stackTrace',
      );
    }
    try {
      await _senseGroupRangePlayback?.cancel();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat range playback cleanup failed '
            'error=$error\n$stackTrace',
      );
    }

    if (timer != null) {
      AppLogger.log(
        'L&R Session',
        'event=timer_flush_begin sessionId=$sessionId',
      );
    }
    try {
      await timer?.dispose();
      if (timer != null) {
        AppLogger.log(
          'L&R Session',
          'event=timer_flush_complete sessionId=$sessionId',
        );
      }
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat timer flush failed error=$error\n$stackTrace',
      );
    } finally {
      if (identical(_studySessionTimer, timer)) _studySessionTimer = null;
    }
    try {
      AppLogger.log(
        'L&R Session',
        'event=stats_flush_begin sessionId=$sessionId',
      );
      await _studyTimeService.flush();
      AppLogger.log(
        'L&R Session',
        'event=stats_flush_complete sessionId=$sessionId',
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat statistics flush failed '
            'error=$error\n$stackTrace',
      );
    }

    ref
        .read(speechRecordingControllerProvider.notifier)
        .setRecordingCompletionHandler(null);
    if (manageForegroundAudioEngine) {
      final foreground = ref.read(foregroundAudioEngineProvider.notifier);
      try {
        await foreground.clearClip();
      } catch (error, stackTrace) {
        AppLogger.log(
          'StudyExit',
          'listen and repeat foreground clip cleanup failed '
              'error=$error\n$stackTrace',
        );
      }
      try {
        await foreground.stop();
      } catch (error, stackTrace) {
        AppLogger.log(
          'StudyExit',
          'listen and repeat foreground playback cleanup failed '
              'error=$error\n$stackTrace',
        );
      }
    }

    final practice = ref.read(listeningPracticeProvider.notifier);
    practice.resumeListeners();
    try {
      await practice.syncBookmarks();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat bookmark sync failed error=$error\n$stackTrace',
      );
    }

    ref.invalidate(dailyStudyTimeProvider);
    ref.invalidate(studyDurationRecordsProvider);
    try {
      await ref.read(studyStatsNotifierProvider.notifier).refresh();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'listen and repeat study stats refresh failed '
            'error=$error\n$stackTrace',
      );
    }

    if (usesMediaEngine) {
      final mediaEngine = _ownedMediaEngine;
      final mediaGeneration = _ownedMediaGeneration;
      if (mediaEngine != null && mediaGeneration != null) {
        try {
          await _releaseOwnedMediaEngine(mediaEngine, mediaGeneration);
        } catch (error, stackTrace) {
          AppLogger.log(
            'StudyExit',
            'listen and repeat media cleanup failed '
                'error=$error\n$stackTrace',
          );
        }
      }
    }

    _mediaSessionReady = false;
    _usesMediaEngine = false;
    _ownedMediaEngine = null;
    _ownedMediaGeneration = null;
    _senseGroupRangePlayback = null;
    _sessionPrepared = false;
    _studyAudioItemId = null;
    _sentences = [];
    state = const ListenAndRepeatSessionState();
    AppLogger.log(
      'L&R Session',
      'event=close_complete sessionId=$sessionId '
          'audioItemId=$audioItemId',
    );
    AppLogger.log('StudyExit', 'listen and repeat cleanup complete');
  }

  // ========== Engine 回调实现 ==========

  /// Engine 状态变化 → 更新 Riverpod state
  void _onEngineStateChanged(RepeatFlowState flowState) {
    final isBookmarked =
        _sentences.isNotEmpty && flowState.sentenceIndex < _sentences.length
        ? _sentences[flowState.sentenceIndex].isBookmarked
        : false;
    state = ListenAndRepeatSessionState.fromFlowState(
      flowState,
      isFreePlay: _isFreePlay,
      currentSentenceBookmarked: isBookmarked,
      usesMediaEngine: _usesMediaEngine,
    );
    final interval = flowState.phase is WaitingInterval;
    final active = flowState.phase is PlayingPrompt || interval;
    _playback.setSessionActive(active);
    _playback.setProgressFrozen(interval);
  }

  /// 播放句子
  Future<SentencePlaybackResult> _playSentence(
    Sentence sentence,
    int flowToken,
  ) async {
    final driver = _playback;
    final settings = ref.read(listenAndRepeatSettingsProvider);
    final SentencePlaybackResult result;
    if (settings.referenceSource == ShadowingReferenceSource.localTts) {
      await driver.pause();
      final playback = await ref
          .read(textPlaybackProvider.notifier)
          .speakWithResult(
            sentence.text,
            key: 'listen-repeat-tts:${sentence.index}',
          );
      result = switch (playback) {
        AudioPlaybackResult.completed => SentencePlaybackResult.completed,
        AudioPlaybackResult.cancelled => SentencePlaybackResult.cancelled,
        AudioPlaybackResult.failed => SentencePlaybackResult.failed,
      };
    } else {
      await ref.read(textPlaybackProvider.notifier).stop();
      result = await driver.playSentenceWithSpeed(
        sentence,
        settings.playbackSpeed,
      );
    }
    if (result == SentencePlaybackResult.completed &&
        flowToken == state.flowToken) {
      AppLogger.log(
        'ListenAndRepeatStats',
        'sentencePlayback.submit stage=${StudyStage.listenAndRepeat.name} '
            'sentenceIndex=${state.sentenceIndex} '
            'durationMs=${sentence.duration.inMilliseconds} flowToken=$flowToken',
      );
      _studyTimeService.submitSentencePlayback(
        duration: sentence.duration,
        text: sentence.text,
        stage: StudyStage.listenAndRepeat,
      );
    } else {
      AppLogger.log(
        'ListenAndRepeatStats',
        'sentencePlayback.discarded result=${result.name} '
            'sentenceIndex=${state.sentenceIndex} '
            'flowToken=$flowToken currentFlowToken=${state.flowToken}',
      );
    }
    return result;
  }

  Future<void> _pauseAudio() async {
    await _playback.pause();
    await ref.read(textPlaybackProvider.notifier).stop();
  }

  /// 开始录音
  void _startRecording({
    required String promptId,
    required String referenceText,
    required Duration maxDuration,
    Duration? referenceDuration,
  }) {
    AppLogger.log(
      'L&R Rec',
      'request-start: flowToken=${state.flowToken} promptId=$promptId '
          'referenceDuration=${referenceDuration?.inMilliseconds}ms',
    );
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

  /// 取消录音
  Future<void> _cancelRecording() async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .cancelActiveRecording();
  }

  /// 停止录音并评估
  Future<void> _stopAndEvaluate({required String referenceText}) async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .stopAndEvaluate(referenceText: referenceText);
  }

  /// 清除录音数据
  Future<void> _clearRecording() {
    return ref
        .read(speechRecordingControllerProvider.notifier)
        .clearRecording();
  }

  /// 设置录音最大时长
  void _setMaxRecordingDuration(Duration duration) {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setMaxRecordingDuration(duration);
  }

  /// 是否检测到语音
  bool _hasDetectedSpeech() {
    return ref.read(speechRecordingControllerProvider).hasDetectedSpeech;
  }

  /// 录音状态变化 → 桥接到 engine
  void _onRecordingStateChanged(
    SpeechRecordingState? prev,
    SpeechRecordingState next,
  ) {
    if (prev == null) return;

    if (prev.phase != next.phase) {
      AppLogger.log(
        'L&R Rec',
        '${prev.phase.name} → ${next.phase.name} | '
            'attempt=${next.currentAttempt != null} | '
            'score=${next.currentAttempt?.score} | '
            'promptId=${next.promptId} | '
            'sessionId=${_engine.state.sessionId} '
            'flowToken=${_engine.state.flowToken}',
      );
    }

    // 评估完成 → 通知 engine（有 ASR: processing→idle，无 ASR: speaking→idle）
    if (prev.phase != SpeechRecordingPhase.idle &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt != null) {
      final attempt = next.currentAttempt!;
      final accepted = _engine.onRecordingFinished(
        attempt.filePath,
        attempt.score,
        promptId: attempt.promptId,
      );
      if (!accepted) {
        AppLogger.log(
          'L&R Rec',
          'event=recording_completed ignored promptId=${attempt.promptId} '
              'sessionId=${_engine.state.sessionId} '
              'flowToken=${_engine.state.flowToken}',
        );
        return;
      }
      ref
          .read(usageTrackerProvider)
          .record(
            UsageEvent.recordingCompleted,
            analyticsParams: {
              ...ref.audioEventParams(_engine.config.audioItemId),
              EventParams.mode: 'listen_repeat',
              if (attempt.score != null) EventParams.score: attempt.score!,
            },
          );
    }

    // 录音取消/超时 → 通知 engine
    if (state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null &&
        next.promptId != null) {
      _engine.onRecordingCancelled(promptId: next.promptId);
    }
  }
}

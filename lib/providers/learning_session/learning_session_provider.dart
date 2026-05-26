/// 学习会话层 Provider
///
/// 管理学习模式状态（盲听等），进入盲听时暂停 ListeningPractice
/// 的 stream 监听，通过 BlindListenPlayer 直接操作 AudioEngine。
/// 负责：进入/退出学习模式、保存/恢复用户播放设置、监听播放完成。
library;

import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/enums.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/playback_settings.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../database/providers.dart';
import '../../models/study_stage.dart';
import '../../services/study_time_service.dart';
import '../daily_study_time_provider.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../study_stats_provider.dart';
import '../../services/app_logger.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../speech/speech_recording_controller.dart';
import '../retell_recording_controller_provider.dart';
import '../listening_practice/listening_practice_provider.dart';
import 'blind_listen_player_provider.dart';
import 'intensive_listen_player_provider.dart';
import 'retell_player_provider.dart';
import 'review_difficult_practice_provider.dart';
import 'sentence_playback_engine.dart';

part 'learning_session_provider.g.dart';

/// 学习模式类型
enum LearningMode {
  /// 全文盲听
  blindListen,

  /// 逐句精听
  intensiveListen,

  /// 难句跟读
  listenAndRepeat,

  /// 段落复述
  retell,

  /// 复习难句补练
  reviewDifficultPractice,
}

/// 学习会话状态
class LearningSessionState {
  /// 当前学习模式（null = 自由收听）
  final LearningMode? learningMode;

  /// 本遍盲听是否已播放完成
  final bool blindListenCompleted;

  /// 当前盲听遍数（从 1 开始，表示正在听第几遍）
  final int blindListenPassCount;

  /// 当前学习的音频 ID
  final String? audioItemId;

  /// 进入学习模式前的用户播放设置（退出时恢复）
  final PlaybackSettings? savedSettings;

  /// 是否为自由练习模式（已完成步骤的单独练习，不计入遍数、不弹完成对话框）
  final bool isFreePlay;

  /// 目标盲听遍数（暂时硬编码，后续由 AI 决定）
  final int targetBlindListenPasses;

  /// 跟读难句列表（enterListenAndRepeatMode 准备，Screen 读取初始化 ListenAndRepeatController）
  final List<Sentence>? shadowingSentences;

  /// 跟读起始句子索引
  final int shadowingStartIndex;

  /// 跟读目标遍数
  final int shadowingTargetPlayCount;

  /// 自由练习时用户点击的目标大阶段（用于"补做跳过的复述"语义）。
  ///
  /// 仅 [isFreePlay] == true 且从过去阶段的复述卡片进入时设置。
  /// 自由练习完成时若该 (stage, subStage) 还未在 completedKeys 内，则写入
  /// stage_completions（[LearningProgressNotifier.recordCompletionIfNew]）
  /// 让 UI 把"跳过"卡切到 ✅。
  final LearningStage? retellCatchUpStage;

  /// 自由练习时用户点击的目标子步骤（与 [retellCatchUpStage] 配套）。
  final SubStageType? retellCatchUpSubStage;

  const LearningSessionState({
    this.learningMode,
    this.blindListenCompleted = false,
    this.blindListenPassCount = 0,
    this.audioItemId,
    this.savedSettings,
    this.isFreePlay = false,
    this.targetBlindListenPasses = 1,
    this.shadowingSentences,
    this.shadowingStartIndex = 0,
    this.shadowingTargetPlayCount = 3,
    this.retellCatchUpStage,
    this.retellCatchUpSubStage,
  });

  /// 是否处于学习模式中
  bool get isInLearningMode => learningMode != null;

  /// 是否还有剩余遍数未完成
  ///
  /// `blindListenPassCount` 表示"正在听第几遍"，完成后才 +1，
  /// 所以用 `<` 比较：正在听的这一遍还没达到目标时返回 true。
  bool get hasRemainingPasses => blindListenPassCount < targetBlindListenPasses;

  LearningSessionState copyWith({
    LearningMode? learningMode,
    bool? blindListenCompleted,
    int? blindListenPassCount,
    String? audioItemId,
    PlaybackSettings? savedSettings,
    bool? isFreePlay,
    int? targetBlindListenPasses,
    List<Sentence>? shadowingSentences,
    int? shadowingStartIndex,
    int? shadowingTargetPlayCount,
    LearningStage? retellCatchUpStage,
    SubStageType? retellCatchUpSubStage,
    bool clearLearningMode = false,
    bool clearSavedSettings = false,
    bool clearAudioItemId = false,
    bool clearShadowingSentences = false,
    bool clearRetellCatchUp = false,
  }) {
    return LearningSessionState(
      learningMode: clearLearningMode
          ? null
          : (learningMode ?? this.learningMode),
      blindListenCompleted: blindListenCompleted ?? this.blindListenCompleted,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      audioItemId: clearAudioItemId ? null : (audioItemId ?? this.audioItemId),
      savedSettings: clearSavedSettings
          ? null
          : (savedSettings ?? this.savedSettings),
      isFreePlay: isFreePlay ?? this.isFreePlay,
      targetBlindListenPasses:
          targetBlindListenPasses ?? this.targetBlindListenPasses,
      shadowingSentences: clearShadowingSentences
          ? null
          : (shadowingSentences ?? this.shadowingSentences),
      shadowingStartIndex: shadowingStartIndex ?? this.shadowingStartIndex,
      shadowingTargetPlayCount:
          shadowingTargetPlayCount ?? this.shadowingTargetPlayCount,
      retellCatchUpStage: clearRetellCatchUp
          ? null
          : (retellCatchUpStage ?? this.retellCatchUpStage),
      retellCatchUpSubStage: clearRetellCatchUp
          ? null
          : (retellCatchUpSubStage ?? this.retellCatchUpSubStage),
    );
  }
}

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。
@Riverpod(keepAlive: true)
class LearningSession extends _$LearningSession {
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  /// 学习计时器，进入学习模式时启动，退出时停止
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 周期保存定时器（每 _maxSessionSeconds 自动保存并重置计时器）
  Timer? _periodicSaveTimer;

  /// 学习计时器是否正在运行（仅用于测试验证）
  @visibleForTesting
  bool get isStudyTimerRunning => _studyStopwatch.isRunning;

  /// App 生命周期监听器，用于在后台暂停计时
  late AppLifecycleListener _lifecycleListener;

  /// 学习时长存储服务
  late StudyTimeService _studyTimeService;

  @override
  LearningSessionState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChanged,
    );
    ref.onDispose(() {
      _playerStateSub?.cancel();
      _periodicSaveTimer?.cancel();
      _saveStudyTime();
      _lifecycleListener.dispose();
    });
    return const LearningSessionState();
  }

  /// App 生命周期变化时暂停/恢复计时
  ///
  /// - 进入后台：暂停所有计时器 + 取消周期保存（用户不在看，不计入学习时长）
  /// - 回到前台：恢复计时 + 重新调度周期保存
  void _onAppLifecycleStateChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      _studyStopwatch.stop();
      _stopPeriodicSaveTimer();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (state.isInLearningMode && !_studyStopwatch.isRunning) {
        _studyStopwatch.start();
        _schedulePeriodicSave();
      }
    }
  }

  /// 单次会话最大计入时长（防止用户睡着等异常场景）
  static const _maxSessionSeconds = 5 * 60; // 5 分钟

  /// 当前学习模式对应的 StudyStage（用于阶段明细双写）
  StudyStage? get _currentStage => switch (state.learningMode) {
    LearningMode.blindListen => StudyStage.blindListen,
    LearningMode.intensiveListen => StudyStage.intensiveListen,
    LearningMode.listenAndRepeat => StudyStage.listenAndRepeat,
    LearningMode.retell => StudyStage.retell,
    LearningMode.reviewDifficultPractice => StudyStage.reviewDifficultPractice,
    null => null,
  };

  /// 停止计时并保存已记录的学习时长
  ///
  /// input/output 已由 StudyEventRecorder 事件驱动写入，无需周期保存。
  Future<void> _saveStudyTime() async {
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
        await _studyTimeService.addStudyTime(seconds, stage: _currentStage);
      }
    } finally {
      _isSaving = false;
    }
  }

  /// 是否正在执行保存（防止 timer 回调与 exit 竞态）
  bool _isSaving = false;

  /// 启动学习计时（含周期保存定时器）
  void _startStudyTimer() {
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave();
  }

  /// 调度下一次周期保存（one-shot Timer，避免 periodic 的 async 竞态）
  void _schedulePeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer(
      const Duration(seconds: _maxSessionSeconds),
      () async {
        if (_isSaving || !state.isInLearningMode) return;
        await _saveStudyTime();
        // 保存后如果仍在学习模式，重新启动计时并调度下一次
        if (state.isInLearningMode) {
          _studyStopwatch.start();
          _schedulePeriodicSave();
        }
      },
    );
  }

  /// 上报 session_start 事件
  void _trackSessionStart() {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(Events.learningStart, {
      ...ref.audioEventParams(state.audioItemId),
      if (state.learningMode != null)
        EventParams.stage: state.learningMode!.name,
      EventParams.isFreePractice: state.isFreePlay ? 1 : 0,
    });
  }

  /// 上报 session_end 事件
  void _trackSessionEnd() {
    final analytics = ref.read(analyticsServiceProvider);
    final durationMs = _studyStopwatch.elapsedMilliseconds;
    analytics.track(Events.learningEnd, {
      ...ref.audioEventParams(state.audioItemId),
      if (state.learningMode != null)
        EventParams.stage: state.learningMode!.name,
      EventParams.durationMs: durationMs,
      EventParams.isFreePractice: state.isFreePlay ? 1 : 0,
    });
  }

  /// 停止周期保存定时器
  void _stopPeriodicSaveTimer() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  /// 暂停学习计时（步骤完成后调用，防止完成弹窗期间白跑时长）
  void pauseStudyTimer() {
    _studyStopwatch.stop();
    _stopPeriodicSaveTimer();
  }

  /// 立即持久化输出词数（每完成一次跟读/复述调用，不丢数据）
  ///
  /// 学习期间 study tab 不可见，无需实时刷新统计 UI。
  /// 退出学习模式时 `exitLearningMode()` 会统一刷新。
  void addOutputWords(int count) {
    if (count > 0) {
      _studyTimeService.addOutputWords(count);
    }
  }

  /// 测试环境可能未注入数据库，此时跳过词形统计即可。
  LearnedVocabularyTracker? _readLearnedVocabularyTracker() {
    try {
      return ref.read(learnedVocabularyTrackerProvider);
    } on Exception catch (e) {
      AppLogger.log('Session', '⚠ vocabTracker 不可用（测试环境？）: $e');
      return null;
    }
  }

  /// 尽量在退出时落掉待写入的词形统计。
  Future<void> _flushLearnedVocabulary() async {
    final tracker = _readLearnedVocabularyTracker();
    if (tracker == null) return;
    await tracker.flush();
  }

  /// 进入全文盲听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听（避免 LP 干扰盲听播放）
  /// 3. 初始化 BlindListenPlayer
  /// 4. 有段落时使用段落分段模式，无段落时使用极简全文播放模式
  ///
  /// [paragraphs] 段落列表
  /// [settings] 盲听设置（段间停顿、重复次数等）
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
    required List<List<Sentence>> paragraphs,
    BlindListenSettings? settings,
  }) async {
    _startStudyTimer();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取已完成遍数 + 断点段落索引
    final progressNotifier = ref.read(
      learningProgressNotifierProvider.notifier,
    );
    final progress = await progressNotifier.getLatestOrEnsureProgress(
      audioItemId,
    );
    final dbPassCount = progress.blindListenPassCount;

    // 读取断点续学的全局句子 index + 校验过期时间
    int? startSentenceIndex;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startSentenceIndex = progress.freePlayBlindListenSentenceIndex;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startSentenceIndex = progress.blindListenSentenceIndex;
    }

    // 全局句子 index → (段索引, 段内本地句索引)
    var startParagraphIndex = 0;
    var startSentenceLocalIndex = 0;
    if (startSentenceIndex != null) {
      for (var i = 0; i < paragraphs.length; i++) {
        final local = paragraphs[i].indexWhere(
          (s) => s.index == startSentenceIndex,
        );
        if (local >= 0) {
          startParagraphIndex = i;
          startSentenceLocalIndex = local;
          break;
        }
      }
    }

    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      blindListenCompleted: false,
      blindListenPassCount: dbPassCount + 1,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    practice.suspendListeners();
    await _ensureAudioLoaded(audioItemId);

    final allSentences = paragraphs.expand((p) => p).toList();
    _logEnterMode(
      'enterBlindListenMode',
      audioItemId,
      sentenceCount: allSentences.length,
      firstSentenceText: allSentences.isNotEmpty
          ? allSentences.first.text
          : null,
    );

    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    blindPlayer.initializeParagraphs(
      paragraphs,
      settings ?? const BlindListenSettings(),
      startParagraphIndex: startParagraphIndex,
      startSentenceLocalIndex: startSentenceLocalIndex,
    );
    _trackSessionStart();
  }

  /// 再听一遍：重置到第一段，递增遍数
  Future<void> replayBlindListen() async {
    state = state.copyWith(
      blindListenCompleted: false,
      blindListenPassCount: state.blindListenPassCount + 1,
    );

    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    await blindPlayer.restart();
  }

  /// 进入逐句精听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 IntensiveListenPlayer，从数据库读取断点句子索引
  Future<void> enterIntensiveListenMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) async {
    _startStudyTimer();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;
    final progressNotifier = ref.read(
      learningProgressNotifierProvider.notifier,
    );

    // 读取断点续学索引：各自读取独立字段 + 校验过期时间
    final progress = await progressNotifier.getLatestOrEnsureProgress(
      audioItemId,
    );
    int startIndex = 0;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startIndex = progress.freePlayIntensiveListenSentenceIndex ?? 0;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startIndex = progress.intensiveListenSentenceIndex ?? 0;
    }

    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();
    await _ensureAudioLoaded(audioItemId);

    _logEnterMode(
      'enterIntensiveListenMode',
      audioItemId,
      sentenceCount: sentences.length,
      firstSentenceText: sentences.isNotEmpty ? sentences.first.text : null,
    );

    // 初始化精听播放器
    final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
    await intensivePlayer.initialize(
      sentences,
      startIndex: startIndex,
      playbackSpeed: playbackSpeed,
      pauseMultiplier: pauseMultiplier,
    );
    _trackSessionStart();
  }

  // TODO: 跟读页已迁移到 ListenAndRepeatController.initialize()，此方法不再被调用。
  // 等所有 enterXxxMode 都迁移到各自 Controller 后，删除整个 LearningSessionProvider。
  /// 进入难句跟读模式（已废弃，保留供参考）
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 从 BookmarkDao 读取难句索引集 → 过滤句子
  /// 4. 从 LearningProgress 读取断点 shadowingSentenceIndex
  /// 5. 根据 difficulty 计算 targetPlayCount
  /// 6. 初始化 ListenAndRepeatPlayer
  Future<void> enterListenAndRepeatMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
    double playbackSpeed = 1.0,
  }) async {
    _startStudyTimer();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );

    // 过滤出难句列表
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 跟读断点与难度都需要优先使用持久化的最新值，避免只吃到陈旧内存态。
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    int startIndex = 0;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startIndex = progress.freePlayShadowingSentenceIndex ?? 0;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startIndex = progress.shadowingSentenceIndex ?? 0;
    }
    final difficultyValue = progress.difficulty.value;
    final targetPlayCount = targetPlayCountForDifficulty(difficultyValue);

    state = state.copyWith(
      learningMode: LearningMode.listenAndRepeat,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();
    await _ensureAudioLoaded(audioItemId);

    _logEnterMode(
      'enterListenAndRepeatMode',
      audioItemId,
      sentenceCount: difficultSentences.length,
      firstSentenceText: difficultSentences.isNotEmpty
          ? difficultSentences.first.text
          : null,
    );

    // 存储难句数据供 Screen 初始化 ListenAndRepeatController
    state = state.copyWith(
      shadowingSentences: difficultSentences,
      shadowingStartIndex: startIndex,
      shadowingTargetPlayCount: targetPlayCount,
    );
    _trackSessionStart();
  }

  /// 进入段落复述模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 RetellPlayer（段落分组 + 按音频难度自动算可见词比例 + 断点索引）
  ///
  /// 可见词比例：
  /// - [overrideKeywordRatio] 非空时使用（用户在 briefing 弹窗中手动选了某档）
  /// - 否则按 `progress.difficulty` + 阶段映射自动算
  Future<void> enterRetellMode(
    String audioItemId,
    List<List<Sentence>> paragraphs, {
    bool isFreePlay = false,
    LearningStage? catchUpStage,
    SubStageType? catchUpSubStage,
    KeywordRatio? overrideKeywordRatio,
    double playbackSpeed = 1.0,
  }) async {
    _startStudyTimer();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 各自读取独立字段 + 校验过期时间
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    int? startSentenceIndex;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startSentenceIndex = progress.freePlayRetellSentenceIndex;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startSentenceIndex = progress.retellSentenceIndex;
    }

    state = state.copyWith(
      learningMode: LearningMode.retell,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
      retellCatchUpStage: catchUpStage,
      retellCatchUpSubStage: catchUpSubStage,
      clearRetellCatchUp: catchUpStage == null,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();
    await _ensureAudioLoaded(audioItemId);

    final retellSentences = paragraphs.expand((p) => p).toList();
    _logEnterMode(
      'enterRetellMode',
      audioItemId,
      sentenceCount: retellSentences.length,
      firstSentenceText: retellSentences.isNotEmpty
          ? retellSentences.first.text
          : null,
    );

    // 初始化复述播放器：优先用调用方覆盖值（briefing 弹窗里用户手动选的档位），
    // 否则按音频难度 + 学习阶段联合算可见词比例。
    // 补练场景按 catchUpStage 算（补练 firstLearn 就走 firstLearn 的曲线）。
    final effectiveStage = catchUpStage ?? progress.currentStage;
    final autoRatio =
        overrideKeywordRatio ??
        KeywordRatio.forDifficultyAndStage(progress.difficulty, effectiveStage);
    final player = ref.read(retellPlayerProvider.notifier);
    player.initialize(
      paragraphs,
      startSentenceIndex: startSentenceIndex,
      autoRatio: autoRatio,
      playbackSpeed: playbackSpeed,
    );
    _trackSessionStart();
  }

  /// 进入复习难句补练模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 从 BookmarkDao 读取难句 → 过滤句子
  /// 4. 初始化 ReviewDifficultPractice
  Future<void> enterReviewDifficultPracticeMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) async {
    _startStudyTimer();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );

    // 过滤出难句列表
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 各自读取独立字段 + 校验过期时间
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    int startIndex = 0;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startIndex = progress.freePlayDifficultPracticeSentenceIndex ?? 0;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startIndex = progress.difficultPracticeSentenceIndex ?? 0;
    }

    state = state.copyWith(
      learningMode: LearningMode.reviewDifficultPractice,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();
    await _ensureAudioLoaded(audioItemId);

    _logEnterMode(
      'enterReviewDifficultPracticeMode',
      audioItemId,
      sentenceCount: difficultSentences.length,
      firstSentenceText: difficultSentences.isNotEmpty
          ? difficultSentences.first.text
          : null,
    );

    // 初始化难句补练播放器（传入断点索引 + 入口选择的播放速度 + 句间停顿）
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.initialize(
      difficultSentences,
      startIndex: startIndex,
      playbackSpeed: playbackSpeed,
      pauseMultiplier: pauseMultiplier,
    );
    _trackSessionStart();
  }

  /// 退出学习模式
  ///
  /// 根据当前学习模式分支处理：停止播放、释放资源、恢复 LP 监听。
  Future<void> exitLearningMode() async {
    _trackSessionEnd();
    _stopPeriodicSaveTimer();
    await _saveStudyTime();
    final mode = state.learningMode;

    _playerStateSub?.cancel();
    _playerStateSub = null;
    if (mode == LearningMode.blindListen) {
      final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
      await blindPlayer.pause();
      blindPlayer.disposePlayer();
    } else if (mode == LearningMode.intensiveListen) {
      // 释放精听播放器资源
      final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
      intensivePlayer.disposePlayer();
    } else if (mode == LearningMode.listenAndRepeat) {
      // 跟读资源由 ListenAndRepeatController 在 Screen 层释放
    } else if (mode == LearningMode.retell) {
      // 释放复述播放器资源
      final retellPlayer = ref.read(retellPlayerProvider.notifier);
      retellPlayer.disposePlayer();
    } else if (mode == LearningMode.reviewDifficultPractice) {
      // 释放难句补练播放器资源
      final player = ref.read(reviewDifficultPracticeProvider.notifier);
      player.disposePlayer();
    }

    // 通用：清除 clip 防止残留影响 LP 的 absolutePositionStream
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();
    final savedSettings = state.savedSettings;
    if (savedSettings != null) {
      await engine.setSpeed(savedSettings.playbackSpeed);
    }
    // 按模式调用对应录音控制器的 fullReset
    if (mode == LearningMode.retell) {
      await ref.read(retellRecordingControllerProvider.notifier).fullReset();
    } else if (mode == LearningMode.listenAndRepeat ||
        mode == LearningMode.reviewDifficultPractice) {
      await ref.read(speechRecordingControllerProvider.notifier).fullReset();
    }

    // 恢复 LP 的 stream 监听
    final practice = ref.read(listeningPracticeProvider.notifier);
    practice.resumeListeners();

    // 同步精听期间新增的书签到 LP 内存状态
    await practice.syncBookmarks();

    // 停止引擎播放（确保干净退出）
    await practice.stop();

    await _flushLearnedVocabulary();

    // 通知 UI 刷新今日学习时长
    ref.read(dailyStudyTimeProvider.notifier).refresh();
    ref.read(studyStatsNotifierProvider.notifier).refresh();

    state = const LearningSessionState();
  }

  /// 记录进入学习模式时的音频/字幕诊断信息
  void _logEnterMode(
    String mode,
    String audioItemId, {
    int? sentenceCount,
    String? firstSentenceText,
  }) {
    final engineId = ref.read(audioEngineProvider).currentAudioId;
    final lp = ref.read(listeningPracticeProvider);
    final lpItem = lp.currentAudioItem;
    final preview = firstSentenceText != null
        ? firstSentenceText.substring(0, min(40, firstSentenceText.length))
        : (lp.sentences.isNotEmpty
              ? lp.sentences.first.text.substring(
                  0,
                  min(40, lp.sentences.first.text.length),
                )
              : 'empty');
    AppLogger.log(
      'Session',
      '🎬 $mode: '
          'targetId=$audioItemId, '
          'engineId=$engineId, '
          'lpId=${lpItem?.id}, '
          'lpName=${lpItem?.name}, '
          'transcript=${lpItem?.transcriptPath}, '
          'sentences=${sentenceCount ?? lp.sentences.length}, '
          'first="$preview"',
    );
  }

  /// 断点是否有效（距今 ≤3 天）
  bool _isBreakpointValid(DateTime? savedAt) {
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt).inDays <= 3;
  }

  /// 确保音频引擎已加载目标音频
  ///
  /// 收藏页、单词卡等页面可能将不同音频加载到全局引擎，
  /// 导致引擎持有的音频与当前学习目标不一致。
  /// 进入任何学习模式前调用此方法，检测不匹配时主动重新加载。
  Future<void> _ensureAudioLoaded(String audioItemId) async {
    final engine = ref.read(audioEngineProvider);
    if (engine.currentAudioId == audioItemId && !engine.isLoading) return;

    // 引擎音频不匹配 → 通过 LP 获取 audioItem，直接重新加载到引擎
    final lp = ref.read(listeningPracticeProvider);
    final audioItem = lp.currentAudioItem;
    if (audioItem != null && audioItem.id == audioItemId) {
      final engineNotifier = ref.read(audioEngineProvider.notifier);
      await engineNotifier.loadAudio(audioItem, lp.settings.playbackSpeed);
    }
  }
}

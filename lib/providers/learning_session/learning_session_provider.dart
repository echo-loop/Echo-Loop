/// 学习会话层 Provider
///
/// 管理学习模式状态（盲听等），进入盲听时暂停 ListeningPractice
/// 的 stream 监听，通过 BlindListenPlayer 和 MediaEngine 播放媒体。
/// 负责：进入/退出学习模式、保存/恢复用户播放设置、监听播放完成。
library;

import 'dart:async';
import 'dart:math' show min;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/enums.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/learning_progress.dart';
import '../../models/audio_item.dart';
import '../../models/media_load_result.dart';
import '../../models/playback_settings.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../database/providers.dart';
import '../daily_study_time_provider.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../study_stats_provider.dart';
import '../study_duration_provider.dart';
import '../../services/app_logger.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../retell_prefs_provider.dart';
import '../../models/stage_settings_overrides.dart';
import '../../utils/playback_speed_default.dart';
import '../speech/speech_recording_controller.dart';
import '../retell_recording_controller_provider.dart';
import '../listening_practice/listening_practice_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../media_engine/media_engine_provider.dart';
import '../media_engine/media_sense_group_range_playback.dart';
import 'blind_listen_player_provider.dart';
import 'paragraph_playback_driver.dart';
import 'intensive_listen_player_provider.dart';
import 'intensive_listen_playback_driver.dart';
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

/// 当前学习会话使用的播放器引擎链路。
enum LearningPlaybackChain { audioEngine, mediaEngine }

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
  final LearningStage? catchUpStage;

  /// 自由练习时用户点击的目标子步骤（与 [catchUpStage] 配套）。
  final SubStageType? catchUpSubStage;
  final LearningPlaybackChain playbackChain;

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
    this.catchUpStage,
    this.catchUpSubStage,
    this.playbackChain = LearningPlaybackChain.audioEngine,
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
    LearningStage? catchUpStage,
    SubStageType? catchUpSubStage,
    LearningPlaybackChain? playbackChain,
    bool clearLearningMode = false,
    bool clearSavedSettings = false,
    bool clearAudioItemId = false,
    bool clearShadowingSentences = false,
    bool clearCatchUp = false,
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
      catchUpStage: clearCatchUp ? null : (catchUpStage ?? this.catchUpStage),
      catchUpSubStage: clearCatchUp
          ? null
          : (catchUpSubStage ?? this.catchUpSubStage),
      playbackChain: playbackChain ?? this.playbackChain,
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
  /// 盲听进入流程 generation；取消、重试或退出会使旧结果失效。
  int _blindListenEntryGeneration = 0;

  /// 视频精听进入流程 generation；退出或重试会使旧异步结果失效。
  int _intensiveListenEntryGeneration = 0;

  /// 复述媒体进入流程 generation；取消、重试或退出会使旧异步结果失效。
  int _retellEntryGeneration = 0;
  int? _suspendedRetellEntryGeneration;

  /// 难句补练进入流程 generation；音视频共用同一媒体会话入口。
  int _reviewDifficultEntryGeneration = 0;
  int? _suspendedReviewDifficultEntryGeneration;

  @override
  LearningSessionState build() {
    return const LearningSessionState();
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
  void _trackSessionEnd({int? durationMs}) {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(Events.learningEnd, {
      ...ref.audioEventParams(state.audioItemId),
      if (state.learningMode != null)
        EventParams.stage: state.learningMode!.name,
      EventParams.durationMs: durationMs ?? 0,
      EventParams.isFreePractice: state.isFreePlay ? 1 : 0,
    });
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

  /// 设置自由练习"补做"目标 (stage, subStage)。
  ///
  /// 自由练习完成时，若该 (stage, subStage) 之前被跳过，则写入 stage_completions
  /// 并回收跳过状态（见 [LearningProgressNotifier.recordCompletionIfNew]）。
  /// 复述走 [enterRetellMode] 的 catchUp 参数；其余任务（盲听/精听/跟读/难句补练）
  /// 由各自由练习入口在进入后调用本方法显式设置，传 null 清除。
  void setCatchUp(LearningStage? stage, SubStageType? subStage) {
    state = state.copyWith(
      catchUpStage: stage,
      catchUpSubStage: subStage,
      clearCatchUp: stage == null,
    );
  }

  /// 若当前会话设置了自由练习"补做"目标，则将其记为完成。
  ///
  /// 幂等：已完成则 no-op；之前被跳过则回收为完成（清除跳过标记）。
  /// 由各自由练习播放器在完成退出时调用。
  Future<void> recordCatchUpCompletionIfAny(String audioItemId) async {
    final stage = state.catchUpStage;
    final subStage = state.catchUpSubStage;
    if (stage == null || subStage == null) return;
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .recordCompletionIfNew(audioItemId, stage, subStage);
  }

  /// 进入音频或视频盲听，共用 MediaEngine 媒体加载与段落播放链路。
  ///
  /// 页面通过 [MediaLearningStartup] 管理加载状态；此处负责媒体会话所有权、
  /// 断点与收藏快照、ListeningPractice 监听移交，以及盲听播放器初始化。
  Future<MediaLoadResult> enterBlindListenMode(
    AudioItem mediaItem, {
    required List<List<Sentence>> paragraphs,
    BlindListenSettings settings = const BlindListenSettings(),
    LearningStage? stage,
    bool isFreePlay = false,
  }) async {
    final generation = ++_blindListenEntryGeneration;
    bool isCurrentGeneration() => generation == _blindListenEntryGeneration;
    final practice = ref.read(listeningPracticeProvider.notifier);
    final mediaEngine = ref.read(mediaEngineProvider.notifier);
    final mediaType = mediaItem.isVideo ? 'video' : 'audio';
    AppLogger.log(
      'BlindListen',
      'event=entry-start generation=$generation itemId=${mediaItem.id} '
          'mediaType=$mediaType source=${isFreePlay ? 'free-practice' : 'planned'} '
          'paragraphCount=${paragraphs.length} speed=${settings.playbackSpeed}',
    );

    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(mediaItem.id);
    if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      mediaItem.id,
      dao: ref.read(bookmarkDaoProvider),
    );
    if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
    final sessionParagraphs = BookmarkManager.createParagraphBookmarkSnapshot(
      paragraphs,
      bookmarkedIndices,
    );

    // 先暂停并移交 Free Player，避免旧音频在媒体加载期间继续播放或更新锁屏状态。
    await practice.pause();
    if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
    practice.suspendListeners();

    // MediaEngine 是跨学习入口共享的。每次进入先取得独立会话所有权，旧请求
    // 迟到时只能释放仍归自己所有的链路，不能关闭后一次进入已加载的媒体。
    final mediaSessionId = mediaEngine.newSession();
    bool ownsMediaSession() => mediaEngine.isActiveSession(mediaSessionId);
    Duration? duration;
    try {
      duration = await mediaEngine.loadMedia(mediaItem, settings.playbackSpeed);
    } catch (error, stackTrace) {
      AppLogger.log(
        'BlindListen',
        'event=entry-failed generation=$generation stage=media-load '
            'itemId=${mediaItem.id} error=$error\n$stackTrace',
      );
      await _cleanupBlindListenEntry(
        mediaEngine: mediaEngine,
        generation: generation,
        itemId: mediaItem.id,
        stage: 'media-load',
        releaseMediaSession: ownsMediaSession(),
      );
      return MediaLoadResult.failure;
    }
    if (!isCurrentGeneration() || !ownsMediaSession()) {
      if (ownsMediaSession()) {
        await _releaseMediaSessionSafely(
          mediaEngine,
          scope: 'BlindListen',
          reason: 'stale-entry-after-media-load',
          itemId: mediaItem.id,
          generation: generation,
        );
      }
      return MediaLoadResult.cancelled;
    }
    if (duration == null) {
      AppLogger.log(
        'BlindListen',
        'event=entry-failed generation=$generation stage=media-load '
            'itemId=${mediaItem.id} error='
            '${mediaEngine.state.errorMessage ?? 'duration-unavailable'}',
      );
      await _cleanupBlindListenEntry(
        mediaEngine: mediaEngine,
        generation: generation,
        itemId: mediaItem.id,
        stage: 'media-load',
        releaseMediaSession: ownsMediaSession(),
      );
      return MediaLoadResult.failure;
    }
    try {
      await mediaEngine.setSubtitleTrackData(null);
    } catch (error, stackTrace) {
      AppLogger.log(
        'BlindListen',
        'event=entry-failed generation=$generation stage=subtitle-setup '
            'itemId=${mediaItem.id} error=$error\n$stackTrace',
      );
      await _cleanupBlindListenEntry(
        mediaEngine: mediaEngine,
        generation: generation,
        itemId: mediaItem.id,
        stage: 'subtitle-setup',
        releaseMediaSession: ownsMediaSession(),
      );
      return MediaLoadResult.failure;
    }
    if (!isCurrentGeneration() || !ownsMediaSession()) {
      if (ownsMediaSession()) {
        await _releaseMediaSessionSafely(
          mediaEngine,
          scope: 'BlindListen',
          reason: 'stale-entry-after-subtitle-setup',
          itemId: mediaItem.id,
          generation: generation,
        );
      }
      return MediaLoadResult.cancelled;
    }

    int? startSentenceIndex;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startSentenceIndex = progress.freePlayBlindListenSentenceIndex;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startSentenceIndex = progress.blindListenSentenceIndex;
    }
    var startParagraphIndex = 0;
    var startSentenceLocalIndex = 0;
    if (startSentenceIndex != null) {
      for (
        var paragraphIndex = 0;
        paragraphIndex < sessionParagraphs.length;
        paragraphIndex++
      ) {
        final localIndex = sessionParagraphs[paragraphIndex].indexWhere(
          (sentence) => sentence.index == startSentenceIndex,
        );
        if (localIndex >= 0) {
          startParagraphIndex = paragraphIndex;
          startSentenceLocalIndex = localIndex;
          break;
        }
      }
    }

    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      blindListenCompleted: false,
      blindListenPassCount: progress.blindListenPassCount + 1,
      audioItemId: mediaItem.id,
      isFreePlay: isFreePlay,
      playbackChain: LearningPlaybackChain.mediaEngine,
      clearSavedSettings: true,
    );

    try {
      await ref
          .read(blindListenPlayerProvider.notifier)
          .initializeParagraphs(
            sessionParagraphs,
            settings,
            startParagraphIndex: startParagraphIndex,
            startSentenceLocalIndex: startSentenceLocalIndex,
            settingsSlot: stageSlotKey(StageSettingsSlots.blindListen, stage),
            playbackDriver: MediaParagraphPlaybackDriver(mediaEngine),
          );
    } catch (error, stackTrace) {
      AppLogger.log(
        'BlindListen',
        'event=entry-failed generation=$generation stage=player-initialize '
            'itemId=${mediaItem.id} error=$error\n$stackTrace',
      );
      if (isCurrentGeneration() &&
          ownsMediaSession() &&
          state.learningMode == LearningMode.blindListen &&
          state.audioItemId == mediaItem.id) {
        await exitLearningMode();
      } else {
        await _cleanupBlindListenEntry(
          mediaEngine: mediaEngine,
          generation: generation,
          itemId: mediaItem.id,
          stage: 'player-initialize',
          releaseMediaSession: ownsMediaSession(),
        );
      }
      return MediaLoadResult.failure;
    }

    if (!isCurrentGeneration() || !ownsMediaSession()) {
      if (ownsMediaSession() &&
          state.learningMode == LearningMode.blindListen &&
          state.audioItemId == mediaItem.id) {
        await exitLearningMode();
      } else if (ownsMediaSession()) {
        await _releaseMediaSessionSafely(
          mediaEngine,
          scope: 'BlindListen',
          reason: 'stale-entry-after-player-initialize',
          itemId: mediaItem.id,
          generation: generation,
        );
      }
      return MediaLoadResult.cancelled;
    }
    _trackSessionStart();
    AppLogger.log(
      'BlindListen',
      'event=entry-ready generation=$generation itemId=${mediaItem.id} '
          'mediaType=$mediaType source=${isFreePlay ? 'free-practice' : 'planned'} '
          'mediaSessionId=$mediaSessionId paragraphCount=${sessionParagraphs.length} '
          'sentenceCount=${sessionParagraphs.fold<int>(0, (count, p) => count + p.length)} '
          'startParagraph=$startParagraphIndex startSentence=$startSentenceLocalIndex',
    );
    return MediaLoadResult.ready;
  }

  /// 盲听准备失败时统一释放本次媒体会话，并在仍由本次流程负责时恢复 Free Player 监听。
  Future<void> _cleanupBlindListenEntry({
    required MediaEngine mediaEngine,
    required int generation,
    required String itemId,
    required String stage,
    required bool releaseMediaSession,
  }) async {
    try {
      if (releaseMediaSession) {
        await _releaseMediaSessionSafely(
          mediaEngine,
          scope: 'BlindListen',
          reason: 'entry-failed-$stage',
          itemId: itemId,
          generation: generation,
        );
      }
    } finally {
      if (generation == _blindListenEntryGeneration) {
        ref.read(listeningPracticeProvider.notifier).resumeListeners();
      }
    }
  }

  /// 媒体释放失败时记录错误并继续执行所属学习会话的其他清理步骤。
  Future<void> _releaseMediaSessionSafely(
    MediaEngine mediaEngine, {
    required String scope,
    required String reason,
    required String itemId,
    required int? generation,
  }) async {
    try {
      await mediaEngine.releaseFromScreen();
    } catch (error, stackTrace) {
      AppLogger.log(
        scope,
        'event=media-release-failed generation=$generation itemId=$itemId '
        'reason=$reason error=$error\n$stackTrace',
      );
    }
  }

  /// 取消盲听媒体加载，或退出已建立的盲听媒体会话。
  Future<void> cancelBlindListenEntry() async {
    _blindListenEntryGeneration += 1;
    if (state.learningMode == LearningMode.blindListen &&
        state.playbackChain == LearningPlaybackChain.mediaEngine) {
      await exitLearningMode();
    } else {
      ref.read(listeningPracticeProvider.notifier).resumeListeners();
    }
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

  /// 进入音频或视频逐句精听模式。
  ///
  /// 两种材料共用 MediaEngine；页面管理加载反馈，代际与媒体 session 同时
  /// 校验，避免取消或较早的加载结果影响后续精听会话。
  Future<MediaLoadResult> enterIntensiveListenMode(
    AudioItem mediaItem,
    List<Sentence> sentences, {
    bool isFreePlay = false,
    IntensiveListenSettings settings = const IntensiveListenSettings(),
    String? settingsSlot,
  }) async {
    final generation = ++_intensiveListenEntryGeneration;
    bool isCurrentGeneration() => generation == _intensiveListenEntryGeneration;
    final mediaType = mediaItem.isVideo ? 'video' : 'audio';
    AppLogger.log(
      'IntensiveListen',
      'event=entry-start generation=$generation itemId=${mediaItem.id} '
          'mediaType=$mediaType source=${isFreePlay ? 'free-practice' : 'planned'} '
          'sentenceCount=${sentences.length} speed=${settings.playbackSpeed}',
    );

    final progressNotifier = ref.read(
      learningProgressNotifierProvider.notifier,
    );
    final progress = await progressNotifier.getLatestOrEnsureProgress(
      mediaItem.id,
    );
    if (!isCurrentGeneration()) {
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=progress '
            'currentGeneration=$_intensiveListenEntryGeneration',
      );
      return MediaLoadResult.cancelled;
    }
    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      mediaItem.id,
      dao: ref.read(bookmarkDaoProvider),
    );
    if (!isCurrentGeneration()) {
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=bookmarks '
            'currentGeneration=$_intensiveListenEntryGeneration',
      );
      return MediaLoadResult.cancelled;
    }
    final sessionSentences = BookmarkManager.createSentenceBookmarkSnapshot(
      sentences,
      bookmarkedIndices,
    );

    var startIndex = 0;
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      startIndex = progress.freePlayIntensiveListenSentenceIndex ?? 0;
    } else if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      startIndex = progress.intensiveListenSentenceIndex ?? 0;
    }
    AppLogger.log(
      'IntensiveListen',
      'event=breakpoint-selected itemId=${mediaItem.id} source='
          '${isFreePlay ? 'free-practice' : 'planned'} startIndex=$startIndex '
          'bookmarkCount=${bookmarkedIndices.length}',
    );

    // 先暂停并移交 Free Player，避免媒体加载期间旧音频继续播放或更新锁屏状态。
    final freePlayer = ref.read(listeningPracticeProvider.notifier);
    await freePlayer.pause();
    if (!isCurrentGeneration()) {
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=pause-player '
            'currentGeneration=$_intensiveListenEntryGeneration',
      );
      return MediaLoadResult.cancelled;
    }
    freePlayer.suspendListeners();
    AppLogger.log(
      'IntensiveListen',
      'event=free-player-listeners-suspended generation=$generation '
          'itemId=${mediaItem.id} listenersSuspended=true',
    );

    final mediaEngine = ref.read(mediaEngineProvider.notifier);
    final mediaSessionId = mediaEngine.newSession();
    bool ownsMediaSession() => mediaEngine.isActiveSession(mediaSessionId);
    final mediaLoadTimer = Stopwatch()..start();
    AppLogger.log(
      'IntensiveListen',
      'event=media-load-start generation=$generation itemId=${mediaItem.id} '
          'mediaType=$mediaType mediaSessionId=$mediaSessionId',
    );
    final duration = await mediaEngine.loadMedia(
      mediaItem,
      settings.playbackSpeed,
    );
    if (!isCurrentGeneration() || !ownsMediaSession()) {
      final ownsSession = ownsMediaSession();
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=media-load '
            'reason=${isCurrentGeneration() ? 'media-session-replaced' : 'superseded'} '
            'mediaSessionId=$mediaSessionId ownsSession=$ownsSession '
            'elapsedMs=${mediaLoadTimer.elapsedMilliseconds}',
      );
      if (ownsSession) await mediaEngine.releaseFromScreen();
      return MediaLoadResult.cancelled;
    }
    if (duration == null) {
      final error = mediaEngine.state.errorMessage ?? 'duration-unavailable';
      AppLogger.log(
        'IntensiveListen',
        'event=entry-failed generation=$generation stage=media-load '
            'itemId=${mediaItem.id} mediaType=$mediaType '
            'mediaSessionId=$mediaSessionId elapsedMs='
            '${mediaLoadTimer.elapsedMilliseconds} error=$error',
      );
      await mediaEngine.releaseFromScreen();
      freePlayer.resumeListeners();
      return MediaLoadResult.failure;
    }

    // 学习页视频字幕默认关闭；视频画面宿主在用户点 CC 后再按需读取 SRT。
    await mediaEngine.setSubtitleTrackData(null);
    if (!isCurrentGeneration() || !ownsMediaSession()) {
      final ownsSession = ownsMediaSession();
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=subtitle-setup '
            'reason=${isCurrentGeneration() ? 'media-session-replaced' : 'superseded'} '
            'mediaSessionId=$mediaSessionId ownsSession=$ownsSession',
      );
      if (ownsSession) await mediaEngine.releaseFromScreen();
      return MediaLoadResult.cancelled;
    }

    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      audioItemId: mediaItem.id,
      isFreePlay: isFreePlay,
      playbackChain: LearningPlaybackChain.mediaEngine,
      clearSavedSettings: true,
    );

    final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
    await intensivePlayer.initialize(
      sessionSentences,
      startIndex: startIndex,
      settings: settings,
      settingsSlot: settingsSlot,
      playbackDriver: MediaSentencePlaybackDriver(mediaEngine),
      senseGroupRangePlayback: MediaSenseGroupRangePlayback(
        engine: mediaEngine,
        playbackSpeed: () =>
            ref.read(intensiveListenPlayerProvider).settings.playbackSpeed,
      ),
      hasVideo: mediaItem.isVideo,
    );
    if (!isCurrentGeneration()) {
      AppLogger.log(
        'IntensiveListen',
        'event=entry-cancelled generation=$generation stage=player-initialize '
            'itemId=${mediaItem.id} currentGeneration=$_intensiveListenEntryGeneration '
            'ownsMediaSession=${ownsMediaSession()}',
      );
      if (ownsMediaSession() &&
          state.learningMode == LearningMode.intensiveListen &&
          state.playbackChain == LearningPlaybackChain.mediaEngine &&
          state.audioItemId == mediaItem.id) {
        await exitLearningMode();
      }
      return MediaLoadResult.cancelled;
    }

    _trackSessionStart();
    AppLogger.log(
      'IntensiveListen',
      'event=entry-ready generation=$generation itemId=${mediaItem.id} '
          'mediaType=$mediaType source=${isFreePlay ? 'free-practice' : 'planned'} '
          'mediaSessionId=$mediaSessionId requestedStartIndex=$startIndex '
          'resolvedStartIndex=${intensivePlayer.currentIndex} '
          'sentenceCount=${sentences.length} durationMs=${duration.inMilliseconds} '
          'loadElapsedMs=${mediaLoadTimer.elapsedMilliseconds}',
    );
    AppLogger.log(
      'Session',
      '🎧 enterIntensiveListenMode: targetId=${mediaItem.id}, '
          'video=${mediaItem.isVideo} sentences=${sentences.length}',
    );
    return MediaLoadResult.ready;
  }

  /// 取消当前精听进入流程。
  ///
  /// 加载尚未完成时只使 generation 失效，由原协程在下一异步边界释放媒体；若
  /// 会话已完成写入，则复用正常退出路径立即释放播放器和学习状态。
  Future<void> cancelIntensiveListenEntry() async {
    _intensiveListenEntryGeneration += 1;
    AppLogger.log(
      'IntensiveListen',
      'event=cancel-request generation=$_intensiveListenEntryGeneration '
          'mode=${state.learningMode} chain=${state.playbackChain} '
          'itemId=${state.audioItemId}',
    );
    if (state.learningMode == LearningMode.intensiveListen &&
        state.playbackChain == LearningPlaybackChain.mediaEngine) {
      await exitLearningMode();
    } else {
      ref.read(listeningPracticeProvider.notifier).resumeListeners();
    }
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
    // 跟读为录音类任务，用前台引擎（此 enter 方法已废弃，跟读改走
    // ListenAndRepeatController.initialize；保留以对齐前台引擎语义）。
    await _ensureForegroundAudioLoaded(audioItemId);

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

  /// 进入音频或视频段落复述，共用 MediaEngine 媒体会话与段落播放器。
  ///
  /// 媒体加载完成后才提交学习状态；取消、重试或其他媒体会话接管时，
  /// 旧请求只释放自己仍持有的媒体会话。
  Future<MediaLoadResult> enterRetellMode(
    AudioItem mediaItem,
    List<List<Sentence>> paragraphs, {
    bool isFreePlay = false,
    LearningStage? catchUpStage,
    SubStageType? catchUpSubStage,
  }) async {
    final generation = ++_retellEntryGeneration;
    // 新入口接管尚未恢复的自由播放器监听；旧请求随后完成时不能抢先恢复它。
    if (_suspendedRetellEntryGeneration != null) {
      _suspendedRetellEntryGeneration = generation;
    }
    bool isCurrentGeneration() => generation == _retellEntryGeneration;
    final practice = ref.read(listeningPracticeProvider.notifier);
    final mediaEngine = ref.read(mediaEngineProvider.notifier);
    var mediaSessionId = 0;
    var hasMediaSession = false;
    bool ownsMediaSession() =>
        hasMediaSession && mediaEngine.isActiveSession(mediaSessionId);

    Future<void> releaseOwnedMediaSession(String reason) async {
      if (!ownsMediaSession()) return;
      await _releaseMediaSessionSafely(
        mediaEngine,
        scope: 'Retell',
        reason: reason,
        itemId: mediaItem.id,
        generation: generation,
      );
    }

    AppLogger.log(
      'Retell',
      'event=entry-start generation=$generation itemId=${mediaItem.id} '
          'mediaType=${mediaItem.isVideo ? 'video' : 'audio'} '
          'source=${isFreePlay ? 'free-practice' : 'planned'} '
          'paragraphCount=${paragraphs.length}',
    );

    try {
      final progress = await ref
          .read(learningProgressNotifierProvider.notifier)
          .getLatestOrEnsureProgress(mediaItem.id);
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      final bookmarkedIndices = await BookmarkManager.loadBookmarks(
        mediaItem.id,
        dao: ref.read(bookmarkDaoProvider),
      );
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      final sessionParagraphs = BookmarkManager.createParagraphBookmarkSnapshot(
        paragraphs,
        bookmarkedIndices,
      );
      final effectiveStage = catchUpStage ?? progress.currentStage;
      final resolvedSettings = _resolveRetellSettings(progress, effectiveStage);

      // 移交自由播放器会话，避免旧播放与媒体加载并行。
      await practice.pause();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      practice.suspendListeners();
      _suspendedRetellEntryGeneration = generation;

      // 音频复述不注册系统媒体会话，因此需先停止默认 AudioService handler，
      // 清掉自由播放器留下的 Now Playing 卡片。视频复述保留默认音频会话暂停态。
      if (!mediaItem.isVideo) {
        await ref.read(audioEngineProvider.notifier).stop();
        if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      }

      mediaSessionId = mediaEngine.newSession();
      hasMediaSession = true;
      final duration = await mediaEngine.loadMedia(
        mediaItem,
        resolvedSettings.settings.playbackSpeed,
        // 音频复述保留无系统媒体控制的现状；视频复述沿用既有媒体会话行为。
        publishToSystemMediaSession: mediaItem.isVideo,
      );
      if (!isCurrentGeneration() || !ownsMediaSession()) {
        await releaseOwnedMediaSession('stale-entry-after-media-load');
        return MediaLoadResult.cancelled;
      }
      if (duration == null) {
        AppLogger.log(
          'Retell',
          'event=entry-failed generation=$generation stage=media-load '
              'itemId=${mediaItem.id} '
              'error=${mediaEngine.state.errorMessage ?? 'duration-unavailable'}',
        );
        await releaseOwnedMediaSession('entry-failed-media-load');
        await _restoreRetellListeners(generation);
        return MediaLoadResult.failure;
      }

      await mediaEngine.setSubtitleTrackData(null);
      if (!isCurrentGeneration() || !ownsMediaSession()) {
        await releaseOwnedMediaSession('stale-entry-after-subtitle-setup');
        return MediaLoadResult.cancelled;
      }

      state = state.copyWith(
        learningMode: LearningMode.retell,
        blindListenCompleted: false,
        audioItemId: mediaItem.id,
        isFreePlay: isFreePlay,
        catchUpStage: catchUpStage,
        catchUpSubStage: catchUpSubStage,
        clearCatchUp: catchUpStage == null,
        playbackChain: LearningPlaybackChain.mediaEngine,
        clearSavedSettings: true,
      );

      final retellSentences = sessionParagraphs
          .expand((paragraph) => paragraph)
          .toList();
      _logEnterMode(
        'enterRetellMode',
        mediaItem.id,
        sentenceCount: retellSentences.length,
        firstSentenceText: retellSentences.isNotEmpty
            ? retellSentences.first.text
            : null,
      );
      await ref
          .read(retellPlayerProvider.notifier)
          .initialize(
            sessionParagraphs,
            startSentenceIndex: _retellStartSentenceIndex(progress, isFreePlay),
            settings: resolvedSettings.settings,
            settingsSlot: resolvedSettings.slot,
            playbackDriver: MediaParagraphPlaybackDriver(mediaEngine),
          );
      if (!isCurrentGeneration() || !ownsMediaSession()) {
        if (ownsMediaSession() &&
            state.learningMode == LearningMode.retell &&
            state.audioItemId == mediaItem.id &&
            state.playbackChain == LearningPlaybackChain.mediaEngine) {
          await exitLearningMode();
        } else {
          await releaseOwnedMediaSession('stale-entry-after-player-initialize');
        }
        return MediaLoadResult.cancelled;
      }

      _trackSessionStart();
      AppLogger.log(
        'Retell',
        'event=entry-ready generation=$generation itemId=${mediaItem.id} '
            'mediaType=${mediaItem.isVideo ? 'video' : 'audio'} '
            'source=${isFreePlay ? 'free-practice' : 'planned'} '
            'mediaSessionId=$mediaSessionId '
            'paragraphCount=${sessionParagraphs.length} '
            'sentenceCount=${retellSentences.length}',
      );
      return MediaLoadResult.ready;
    } catch (error, stackTrace) {
      AppLogger.log(
        'Retell',
        'event=entry-failed generation=$generation itemId=${mediaItem.id} '
            'error=$error\n$stackTrace',
      );
      final ownsSession = ownsMediaSession();
      final isActiveRetellSession =
          state.learningMode == LearningMode.retell &&
          state.audioItemId == mediaItem.id &&
          state.playbackChain == LearningPlaybackChain.mediaEngine;
      if (isCurrentGeneration() && ownsSession && isActiveRetellSession) {
        await exitLearningMode();
      } else {
        await releaseOwnedMediaSession('entry-failed');
        await _restoreRetellListeners(generation);
      }
      return MediaLoadResult.failure;
    }
  }

  /// 取消尚未完成的复述媒体加载，或退出已建立的复述会话。
  Future<void> cancelRetellEntry() async {
    final suspendedGeneration = _suspendedRetellEntryGeneration;
    _retellEntryGeneration += 1;
    if (state.learningMode == LearningMode.retell &&
        state.playbackChain == LearningPlaybackChain.mediaEngine) {
      await exitLearningMode();
    } else {
      if (suspendedGeneration != null) {
        await _restoreRetellListeners(suspendedGeneration);
      }
    }
  }

  Future<void> _restoreRetellListeners(
    int generation, {
    bool allowActiveRetell = false,
  }) async {
    if (_suspendedRetellEntryGeneration != generation) return;
    if (state.learningMode != null &&
        !(allowActiveRetell && state.learningMode == LearningMode.retell)) {
      return;
    }
    _suspendedRetellEntryGeneration = null;
    final practice = ref.read(listeningPracticeProvider.notifier);
    try {
      practice.resumeListeners();
    } catch (error, stackTrace) {
      AppLogger.log(
        'Retell',
        'event=free-player-listener-restore-failed generation=$generation '
            'error=$error\n$stackTrace',
      );
    }
    try {
      await practice.syncBookmarks();
    } catch (error, stackTrace) {
      AppLogger.log(
        'Retell',
        'event=free-player-bookmark-sync-failed generation=$generation '
            'error=$error\n$stackTrace',
      );
    }
  }

  int? _retellStartSentenceIndex(LearningProgress progress, bool isFreePlay) {
    if (isFreePlay && _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
      return progress.freePlayRetellSentenceIndex;
    }
    if (!isFreePlay &&
        _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
      return progress.retellSentenceIndex;
    }
    return null;
  }

  ({String slot, RetellSettings settings}) _resolveRetellSettings(
    LearningProgress progress,
    LearningStage effectiveStage,
  ) {
    final slot = stageSlotKey(StageSettingsSlots.retell, effectiveStage);
    final settings = ref
        .read(retellPrefsProvider.notifier)
        .resolve(
          slot,
          smartSpeed: defaultPlaybackSpeedFor(
            progress.difficulty,
            effectiveStage,
          ),
          smartRatio: KeywordRatio.forDifficultyAndStage(
            progress.difficulty,
            effectiveStage,
          ),
        );
    return (slot: slot, settings: settings);
  }

  /// 通过共享 MediaEngine 进入音频或视频难句补练。
  Future<MediaLoadResult> enterReviewDifficultPracticeMode(
    AudioItem mediaItem,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
    DifficultPracticeSettings settings = const DifficultPracticeSettings(),
    LearningStage? stage,
  }) async {
    final generation = ++_reviewDifficultEntryGeneration;
    bool isCurrentGeneration() => generation == _reviewDifficultEntryGeneration;
    final audioItemId = mediaItem.id;
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;
    MediaEngine? mediaEngine;
    var mediaLoadStarted = false;
    try {
      await practice.pause();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      practice.suspendListeners();
      _suspendedReviewDifficultEntryGeneration = generation;

      final bookmarkDao = ref.read(bookmarkDaoProvider);
      final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
        audioItemId,
      );
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      final difficultSentences = allSentences
          .where((sentence) => bookmarkedIndices.contains(sentence.index))
          .map((sentence) => sentence.copyWith(isBookmarked: true))
          .toList();
      final progress = await ref
          .read(learningProgressNotifierProvider.notifier)
          .getLatestOrEnsureProgress(audioItemId);
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;

      var startIndex = 0;
      if (isFreePlay &&
          _isBreakpointValid(progress.freePlayBreakpointSavedAt)) {
        startIndex = progress.freePlayDifficultPracticeSentenceIndex ?? 0;
      } else if (!isFreePlay &&
          _isBreakpointValid(progress.newLearningBreakpointSavedAt)) {
        startIndex = progress.difficultPracticeSentenceIndex ?? 0;
      }

      // 清除旧自由播放器媒体卡片，再由 MediaEngine 接管当前材料。
      await ref.read(audioEngineProvider.notifier).stop();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      final activeMediaEngine = ref.read(mediaEngineProvider.notifier);
      mediaEngine = activeMediaEngine;
      mediaLoadStarted = true;
      final duration = await activeMediaEngine.loadMedia(
        mediaItem,
        settings.playbackSpeed,
      );
      if (!isCurrentGeneration()) {
        await _releaseMediaSessionSafely(
          activeMediaEngine,
          scope: 'Session',
          reason: 'stale-review-difficult-entry',
          itemId: audioItemId,
          generation: generation,
        );
        return MediaLoadResult.cancelled;
      }
      if (duration == null) {
        AppLogger.log(
          'Session',
          'event=review-difficult-load-failed itemId=$audioItemId',
        );
        await _releaseMediaSessionSafely(
          activeMediaEngine,
          scope: 'Session',
          reason: 'review-difficult-load-failure',
          itemId: audioItemId,
          generation: generation,
        );
        await _restoreReviewDifficultListeners(generation);
        return MediaLoadResult.failure;
      }

      await activeMediaEngine.setSubtitleTrackData(null);
      if (!isCurrentGeneration()) {
        await _releaseMediaSessionSafely(
          activeMediaEngine,
          scope: 'Session',
          reason: 'cancelled-review-difficult-entry',
          itemId: audioItemId,
          generation: generation,
        );
        return MediaLoadResult.cancelled;
      }

      state = state.copyWith(
        learningMode: LearningMode.reviewDifficultPractice,
        blindListenCompleted: false,
        audioItemId: audioItemId,
        savedSettings: currentSettings,
        isFreePlay: isFreePlay,
        playbackChain: LearningPlaybackChain.mediaEngine,
      );
      final player = ref.read(reviewDifficultPracticeProvider.notifier);
      await player.initialize(
        difficultSentences,
        startIndex: startIndex,
        settings: settings,
        settingsSlot: stageSlotKey(
          StageSettingsSlots.reviewDifficultPractice,
          stage,
        ),
        playbackDriver: MediaSentencePlaybackDriver(activeMediaEngine),
        senseGroupRangePlayback: MediaSenseGroupRangePlayback(
          engine: activeMediaEngine,
          playbackSpeed: () =>
              ref.read(reviewDifficultPracticeProvider).settings.playbackSpeed,
        ),
        hasVideo: mediaItem.isVideo,
      );
      if (!isCurrentGeneration()) {
        if (state.learningMode == LearningMode.reviewDifficultPractice &&
            state.audioItemId == audioItemId) {
          await exitLearningMode();
        }
        return MediaLoadResult.cancelled;
      }

      _logEnterMode(
        'enterReviewDifficultPracticeMode',
        audioItemId,
        sentenceCount: difficultSentences.length,
        firstSentenceText: difficultSentences.isNotEmpty
            ? difficultSentences.first.text
            : null,
      );
      _trackSessionStart();
      AppLogger.log(
        'Session',
        'review difficult media ready itemId=$audioItemId '
            'sentences=${difficultSentences.length} '
            'hasVideo=${mediaItem.isVideo}',
      );
      return MediaLoadResult.ready;
    } catch (error, stackTrace) {
      AppLogger.log(
        'Session',
        'review difficult media entry failed itemId=$audioItemId '
            'generation=$generation error=$error\n$stackTrace',
      );
      if (isCurrentGeneration()) {
        if (state.learningMode == LearningMode.reviewDifficultPractice &&
            state.audioItemId == audioItemId) {
          await exitLearningMode();
        } else {
          if (mediaLoadStarted && mediaEngine != null) {
            await _releaseMediaSessionSafely(
              mediaEngine,
              scope: 'Session',
              reason: 'review-difficult-entry-error',
              itemId: audioItemId,
              generation: generation,
            );
          }
          await _restoreReviewDifficultListeners(generation);
        }
      }
      rethrow;
    }
  }

  /// 取消难句补练进入；迟到的媒体结果由 generation guard 丢弃。
  Future<void> cancelReviewDifficultPracticeEntry() async {
    final generation = _reviewDifficultEntryGeneration;
    _reviewDifficultEntryGeneration += 1;
    AppLogger.log('Session', 'event=review_difficult_startup_cancelled');
    if (state.learningMode == LearningMode.reviewDifficultPractice) {
      await exitLearningMode();
      return;
    }
    await _restoreReviewDifficultListeners(generation);
  }

  /// 恢复进入补练前挂起的自由播放器监听，并同步书签。
  Future<void> _restoreReviewDifficultListeners(int generation) async {
    if (_suspendedReviewDifficultEntryGeneration != generation) return;
    _suspendedReviewDifficultEntryGeneration = null;
    final practice = ref.read(listeningPracticeProvider.notifier);
    try {
      practice.resumeListeners();
    } catch (error, stackTrace) {
      AppLogger.log(
        'Session',
        'review difficult listener restore failed generation=$generation '
            'error=$error\n$stackTrace',
      );
    }
    try {
      await practice.syncBookmarks();
    } catch (error, stackTrace) {
      AppLogger.log(
        'Session',
        'review difficult bookmark sync failed generation=$generation '
            'error=$error\n$stackTrace',
      );
    }
  }

  /// 退出学习模式
  ///
  /// 根据当前学习模式分支处理：停止播放、释放资源、恢复 LP 监听。
  Future<void> exitLearningMode() async {
    final mode = state.learningMode;
    final itemId = state.audioItemId;
    final intensivePlayer = mode == LearningMode.intensiveListen
        ? ref.read(intensiveListenPlayerProvider.notifier)
        : null;
    final blindPlayer = mode == LearningMode.blindListen
        ? ref.read(blindListenPlayerProvider.notifier)
        : null;
    final retellPlayer = mode == LearningMode.retell
        ? ref.read(retellPlayerProvider.notifier)
        : null;
    final difficultPracticePlayer = mode == LearningMode.reviewDifficultPractice
        ? ref.read(reviewDifficultPracticeProvider.notifier)
        : null;
    final suspendedRetellGeneration = mode == LearningMode.retell
        ? _suspendedRetellEntryGeneration
        : null;
    _trackSessionEnd(
      durationMs:
          intensivePlayer?.elapsed.inMilliseconds ??
          blindPlayer?.elapsed.inMilliseconds ??
          retellPlayer?.elapsed.inMilliseconds ??
          difficultPracticePlayer?.elapsed.inMilliseconds,
    );
    AppLogger.log(
      'Session',
      'exitLearningMode: begin mode=$mode chain=${state.playbackChain} '
          'itemId=${state.audioItemId}',
    );
    if (mode == LearningMode.intensiveListen) {
      AppLogger.log(
        'IntensiveListen',
        'event=exit-start itemId=$itemId '
            'mediaType=${intensivePlayer?.state.hasVideo == true ? 'video' : 'audio'} '
            'chain=${state.playbackChain} '
            'elapsedMs=${intensivePlayer?.elapsed.inMilliseconds ?? 0}',
      );
    }

    final usesMediaEngine =
        state.playbackChain == LearningPlaybackChain.mediaEngine;
    if (mode == LearningMode.retell && usesMediaEngine) {
      _retellEntryGeneration += 1;
    }
    if (mode == LearningMode.blindListen && usesMediaEngine) {
      _blindListenEntryGeneration += 1;
    }
    if (mode == LearningMode.reviewDifficultPractice) {
      _reviewDifficultEntryGeneration += 1;
    }
    if (mode == LearningMode.blindListen) {
      await blindPlayer?.disposePlayer();
    } else if (mode == LearningMode.intensiveListen) {
      // 释放精听播放器资源
      await intensivePlayer?.disposePlayer();
    } else if (mode == LearningMode.listenAndRepeat) {
      // 跟读资源由 ListenAndRepeatController 在 Screen 层释放
    } else if (mode == LearningMode.retell) {
      // 释放复述播放器资源
      await retellPlayer?.disposePlayer();
    } else if (mode == LearningMode.reviewDifficultPractice) {
      // 释放难句补练播放器资源
      await difficultPracticePlayer?.disposePlayer();
    }

    // 录音控制器属于录音任务本身，音频和视频退出都必须先完整复位。
    if (mode == LearningMode.retell) {
      await ref.read(retellRecordingControllerProvider.notifier).fullReset();
    }
    if (mode == LearningMode.reviewDifficultPractice) {
      await ref.read(speechRecordingControllerProvider.notifier).fullReset();
    }

    if (usesMediaEngine) {
      AppLogger.log(
        'Session',
        'exitLearningMode: releasing media chain mode=$mode',
      );
      try {
        await _releaseMediaSessionSafely(
          ref.read(mediaEngineProvider.notifier),
          scope: 'Session',
          reason: 'exit-$mode',
          itemId: itemId ?? 'unknown',
          generation: null,
        );
        if (mode == LearningMode.retell && suspendedRetellGeneration != null) {
          await _restoreRetellListeners(
            suspendedRetellGeneration,
            allowActiveRetell: true,
          );
        } else if (mode == LearningMode.intensiveListen ||
            mode == LearningMode.blindListen) {
          final freePlayer = ref.read(listeningPracticeProvider.notifier);
          try {
            freePlayer.resumeListeners();
          } catch (error, stackTrace) {
            AppLogger.log(
              'Session',
              'event=free-player-listener-restore-failed mode=$mode '
                  'itemId=${itemId ?? 'unknown'} error=$error\n$stackTrace',
            );
          }
          try {
            await freePlayer.syncBookmarks();
          } catch (error, stackTrace) {
            AppLogger.log(
              'Session',
              'event=free-player-bookmark-sync-failed mode=$mode '
                  'itemId=${itemId ?? 'unknown'} error=$error\n$stackTrace',
            );
          }
        } else if (mode == LearningMode.reviewDifficultPractice) {
          final generation = _suspendedReviewDifficultEntryGeneration;
          if (generation != null) {
            await _restoreReviewDifficultListeners(generation);
          }
        }
        try {
          await _flushLearnedVocabulary();
        } catch (error, stackTrace) {
          AppLogger.log(
            'Session',
            'event=learned-vocabulary-flush-failed mode=$mode '
                'itemId=${itemId ?? 'unknown'} error=$error\n$stackTrace',
          );
        }
        ref.read(dailyStudyTimeProvider.notifier).refresh();
        ref.invalidate(studyDurationRecordsProvider);
        ref.read(studyStatsNotifierProvider.notifier).refresh();
      } finally {
        state = const LearningSessionState();
      }
      if (mode == LearningMode.intensiveListen) {
        AppLogger.log(
          'IntensiveListen',
          'event=exit-complete itemId=${itemId ?? 'unknown'} '
              'mediaChainReleased=true',
        );
      }
      AppLogger.log(
        'Session',
        'exitLearningMode: complete mode=$mode media chain',
      );
      return;
    }

    // 通用：清除 clip 防止残留影响 LP 的 absolutePositionStream
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();
    final savedSettings = state.savedSettings;
    if (savedSettings != null) {
      await engine.setSpeed(savedSettings.playbackSpeed);
    }
    // 按模式调用对应录音控制器的 fullReset
    if (mode == LearningMode.listenAndRepeat) {
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
    ref.invalidate(studyDurationRecordsProvider);
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

  /// 确保前台音频引擎已加载目标材料。
  ///
  /// 收藏页、单词卡等页面可能切换全局引擎中的材料，因此进入复述或难句补练前
  /// 需要确认前台引擎加载的是当前目标。盲听与精听由 MediaEngine 负责加载。
  Future<void> _ensureForegroundAudioLoaded(String audioItemId) async {
    final lp = ref.read(listeningPracticeProvider);
    final audioItem = lp.currentAudioItem;
    final engine = ref.read(foregroundAudioEngineProvider);
    if (engine.currentAudioId == audioItemId && !engine.isLoading) return;
    if (audioItem != null && audioItem.id == audioItemId) {
      await ref
          .read(foregroundAudioEngineProvider.notifier)
          .loadAudio(audioItem, lp.settings.playbackSpeed);
    }
  }
}

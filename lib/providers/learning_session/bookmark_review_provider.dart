/// 收藏句闪卡复习状态与控制器。
///
/// 会话状态机复用通用调度引擎 `ScheduledFlashcardController<BookmarkSentence>`
/// （`lib/features/scheduled_flashcard/`）；本文件只负责 Riverpod 装配、
/// 前台播放编排（重播/打断）和取消收藏这类句子专属业务动作。对外暴露的
/// [BookmarkReviewState] 形状与迁移前完全一致，UI 与既有测试无需感知内部实现变化。
/// 所有媒体操作都用 generation 隔离，切卡、翻面和退出后，旧异步回调不能恢复播放
/// 或污染状态。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../features/memory_scheduler/domain/memory_rating.dart';
import '../../features/memory_scheduler/domain/memory_scheduler_results.dart';
import '../../features/memory_scheduler/providers/memory_scheduler_providers.dart';
import '../../config/ai_prewarm_config.dart';
import '../../features/scheduled_flashcard/application/scheduled_flashcard_controller.dart';
import '../../features/scheduled_flashcard/domain/scheduled_flashcard.dart';
import '../../features/scheduled_flashcard/domain/review_session_summary.dart';
import '../bookmark_review_settings_provider.dart';
import '../favorite_review_settings_provider.dart';
import '../favorite_sentence_lifecycle_provider.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../models/bookmark_sentence.dart';
import '../../models/favorite_review_settings.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/study_session_timer.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../media_engine/media_engine_provider.dart';
import '../../models/audio_item.dart';
import '../../models/sentence_playback_result.dart';
import '../../widgets/favorites/favorite_sentence_video_session.dart';
import 'favorite_sentence_deck_source.dart';
import '../short_audio_player_provider.dart';
import '../../services/pronunciation/local_audio_clip_player.dart';
import '../../services/pronunciation/local_audio_range_player.dart';

part 'bookmark_review_provider.g.dart';

enum BookmarkReviewFace { front, back }

enum BookmarkReviewPlaybackState { idle, loading, playing, failed }

/// 当前卡片的视频画面阶段。
enum BookmarkReviewVideoPhase {
  /// 不显示画面：音频材料、设置关闭或视频加载失败（退回音频播放）。
  none,

  /// 正在加载来源视频，页面在视频槽内显示加载占位。
  loading,

  /// 视频已就绪并停在当前句起点，播放走媒体引擎。
  ready,
}

@immutable
class BookmarkReviewState {
  const BookmarkReviewState({
    this.currentCard,
    this.initialTotal = 0,
    this.remainingCount = 0,
    this.face = BookmarkReviewFace.front,
    this.playbackState = BookmarkReviewPlaybackState.idle,
    this.isRemoving = false,
    this.mediaError,
    this.removeError,
    this.preview,
    this.isSubmittingRating = false,
    this.reviewedCount = 0,
    this.completionSummary,
    this.upcomingCards = const [],
    this.videoPhase = BookmarkReviewVideoPhase.none,
    this.isVideoVisualVisible = true,
    this.videoAspectRatio,
  });

  final BookmarkSentence? currentCard;

  /// 当前卡片的视频画面阶段；[BookmarkReviewVideoPhase.none] 时页面与改动前一致。
  final BookmarkReviewVideoPhase videoPhase;

  /// 用户是否在本次复习中保持画面显示；隐藏后只收起画面，声音照常。
  final bool isVideoVisualVisible;

  /// 已解码视频的宽高比，用于分栏贴合画面；未知时为 null。
  final double? videoAspectRatio;

  /// 当前卡之后即将展示的卡片，供页面提前预热 AI 内容。
  final List<BookmarkSentence> upcomingCards;
  final int initialTotal;
  final int remainingCount;
  final BookmarkReviewFace face;
  final BookmarkReviewPlaybackState playbackState;
  final bool isRemoving;
  final String? mediaError;
  final String? removeError;
  final MemoryRatingPreviewSet? preview;
  final bool isSubmittingRating;
  final int reviewedCount;
  final ReviewSessionSummary? completionSummary;

  double get progress =>
      initialTotal == 0 ? 0 : (initialTotal - remainingCount) / initialTotal;

  BookmarkReviewState copyWith({
    BookmarkSentence? currentCard,
    bool clearCurrentCard = false,
    int? initialTotal,
    int? remainingCount,
    BookmarkReviewFace? face,
    BookmarkReviewPlaybackState? playbackState,
    bool? isRemoving,
    String? mediaError,
    bool clearMediaError = false,
    String? removeError,
    bool clearRemoveError = false,
    MemoryRatingPreviewSet? preview,
    bool clearPreview = false,
    bool? isSubmittingRating,
    int? reviewedCount,
    ReviewSessionSummary? completionSummary,
    bool clearCompletionSummary = false,
    List<BookmarkSentence>? upcomingCards,
    BookmarkReviewVideoPhase? videoPhase,
    bool? isVideoVisualVisible,
    double? videoAspectRatio,
  }) => BookmarkReviewState(
    currentCard: clearCurrentCard ? null : currentCard ?? this.currentCard,
    initialTotal: initialTotal ?? this.initialTotal,
    remainingCount: remainingCount ?? this.remainingCount,
    face: face ?? this.face,
    playbackState: playbackState ?? this.playbackState,
    isRemoving: isRemoving ?? this.isRemoving,
    mediaError: clearMediaError ? null : mediaError ?? this.mediaError,
    removeError: clearRemoveError ? null : removeError ?? this.removeError,
    preview: clearPreview ? null : preview ?? this.preview,
    isSubmittingRating: isSubmittingRating ?? this.isSubmittingRating,
    reviewedCount: reviewedCount ?? this.reviewedCount,
    completionSummary: clearCompletionSummary
        ? null
        : completionSummary ?? this.completionSummary,
    upcomingCards: upcomingCards ?? this.upcomingCards,
    videoPhase: videoPhase ?? this.videoPhase,
    isVideoVisualVisible: isVideoVisualVisible ?? this.isVideoVisualVisible,
    videoAspectRatio: videoAspectRatio ?? this.videoAspectRatio,
  );
}

@Riverpod(keepAlive: true)
class BookmarkReview extends _$BookmarkReview {
  int _generation = 0;
  late final AppLifecycleListener _lifecycleListener;
  StudySessionTimer? _studySessionTimer;
  ScheduledFlashcardController<BookmarkSentence>? _controller;
  bool _hasSession = false;
  int _orderGeneration = 0;
  ReviewSessionSummary _summary = const ReviewSessionSummary();
  Future<void>? _disposeSessionInFlight;

  /// 一次复习内复用的视频会话；只在需要显示画面的视频卡片出现时创建。
  FavoriteSentenceVideoSession? _videoSession;

  /// 视频同步的 generation：切卡、改设置或退出后，旧的加载结果不得改写状态。
  int _videoGeneration = 0;
  StreamSubscription<double?>? _videoAspectRatioSubscription;

  /// 页面借用的视频会话；仅当前卡片的画面就绪时可用，其余情况走音频路径。
  ///
  /// 切卡后到同步完成前 phase 仍为 ready，因此还要校验会话当前加载的正是本卡材料，
  /// 否则页面会拿到上一份材料的画面，replay 也会按新卡的时间戳播放旧视频。
  FavoriteSentenceVideoSession? get videoSession {
    final session = _videoSession;
    final card = state.currentCard;
    if (state.videoPhase != BookmarkReviewVideoPhase.ready ||
        session == null ||
        card == null) {
      return null;
    }
    return session.isLoaded(card.audioItemId) ? session : null;
  }

  /// 当前收藏句复习会话的前台有效时长。
  Duration get elapsed => _studySessionTimer?.elapsed ?? Duration.zero;

  /// 标记用户仍在收藏句复习页面活动，让页面级计时器恢复前台计时。
  void markStudyActivity() => _studySessionTimer?.markActivity();

  @override
  BookmarkReviewState build() {
    ref.listen(favoriteReviewSettingsProvider, (previous, next) {
      if (previous != null && previous.order != next.order) {
        unawaited(_applyReviewOrder(next));
      }
    });
    ref.listen(bookmarkReviewSettingsProvider, (previous, next) {
      if (previous == null ||
          previous.showVideo == next.showVideo ||
          !_hasSession) {
        return;
      }
      AppLogger.log(
        'FavoriteSentenceReview',
        'video.setting showVideo=${next.showVideo} '
            'card=${state.currentCard?.memorySubjectId}',
      );
      unawaited(_applyShowVideoChange());
    });
    final audioEngine = ref.read(audioEngineProvider.notifier);
    final foregroundEngine = ref.read(foregroundAudioEngineProvider.notifier);
    final shortAudioPlayer = ref.read(shortAudioPlayerProvider);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (value) {
        if (value == AppLifecycleState.paused ||
            value == AppLifecycleState.hidden ||
            value == AppLifecycleState.detached) {
          unawaited(interruptPlayback());
        }
      },
    );
    ref.onDispose(() {
      _generation++;
      _lifecycleListener.dispose();
      _controller?.dispose();
      unawaited(audioEngine.stop());
      if (foregroundEngine.isPlaying) {
        unawaited(foregroundEngine.stop());
      }
      unawaited(shortAudioPlayer.stop());
      unawaited(_studySessionTimer?.dispose());
      _videoGeneration++;
      unawaited(_releaseVideoSession(reason: 'provider-dispose'));
    });
    return const BookmarkReviewState();
  }

  /// 建立只含 FSRS 到期收藏句的本次复习快照。
  Future<void> initialize() async {
    await _studySessionTimer?.dispose();
    _studySessionTimer = null;
    _summary = const ReviewSessionSummary();
    _generation++;
    unawaited(ref.read(audioEngineProvider.notifier).stop());
    unawaited(_stopForegroundPlaybackIfActive());
    unawaited(ref.read(shortAudioPlayerProvider).stop());

    _controller?.dispose();
    _hasSession = true;
    _orderGeneration++;
    final scheduler = ref.read(memorySchedulerProvider);
    final controller = ScheduledFlashcardController<BookmarkSentence>(
      deckSource: FavoriteSentenceDeckSource(
        favoriteReviewDao: ref.read(favoriteReviewDaoProvider),
        scheduler: scheduler,
        settings: ref.read(favoriteReviewSettingsProvider),
      ),
      ratingPort: MemorySchedulerFlashcardRatingPort(scheduler),
      operationIdGenerator: ref.read(memoryIdGeneratorProvider),
      logger: (message) => AppLogger.log('FavoriteSentenceReview', message),
    );
    _controller = controller;
    AppLogger.log(
      'FavoriteSentenceReview',
      'load.start source=memory_schedules providerGeneration=$_generation',
    );
    await controller.load();
    if (!identical(_controller, controller)) return;
    final completionSummary =
        controller.state.phase == ScheduledFlashcardPhase.completed
        ? _summary.complete(elapsed: Duration.zero, reviewedCount: 0)
        : null;
    state = _stateFromController(
      controller,
      completionSummary: completionSummary,
    );
    if (completionSummary != null) return;
    // 每次新建复习快照都创建新的计时会话，避免复用已停止的 timer。
    final timer = StudySessionTimer(
      studyTimeService: ref.read(studyTimeServiceProvider),
      stage: StudyStage.savedSentencesReview,
      activityGate: ref.read(studyActivityGateProvider),
      idleTimeout: const Duration(minutes: 2),
      logScope: 'SavedSentenceReviewTimer',
    );
    _studySessionTimer = timer;
    timer.start();
    ref.read(analyticsServiceProvider).track(Events.bookmarkReviewStart, {
      EventParams.totalSentencesCount: state.initialTotal,
    });
  }

  /// 设置面板切换顺序后，只重新排列当前会话尚未处理的句子。
  Future<void> _applyReviewOrder(FavoriteReviewSettings settings) async {
    final controller = _controller;
    if (!_hasSession || controller == null) return;
    final generation = ++_orderGeneration;
    AppLogger.log(
      'FavoriteSentenceReview',
      'reorder.load.start order=${settings.order} '
          'source=memory_schedules generation=$generation',
    );
    try {
      final scheduler = ref.read(memorySchedulerProvider);
      final loadStopwatch = Stopwatch()..start();
      final orderedDeck = await FavoriteSentenceDeckSource(
        favoriteReviewDao: ref.read(favoriteReviewDaoProvider),
        scheduler: scheduler,
        settings: settings,
      ).loadForReordering();
      if (generation != _orderGeneration ||
          !identical(_controller, controller)) {
        AppLogger.log(
          'FavoriteSentenceReview',
          'reorder.load.discarded generation=$generation '
              'activeGeneration=$_orderGeneration',
        );
        return;
      }
      AppLogger.log(
        'FavoriteSentenceReview',
        'reorder.load.success order=${settings.order} '
            'deckCount=${orderedDeck.length} '
            'elapsedMs=${loadStopwatch.elapsedMilliseconds} '
            'first=${orderedDeck.isEmpty ? 'none' : orderedDeck.first.subject.subjectId}',
      );
      if (controller.reorderPending(orderedDeck)) {
        state = _stateFromController(controller);
        unawaited(_syncVideoForCurrentCard());
      } else {
        // 首卡未变时保留当前翻面等状态，只同步重排后的后续卡片。
        state = state.copyWith(upcomingCards: _upcomingCards(controller));
      }
    } catch (error) {
      AppLogger.log(
        'FavoriteSentenceReview',
        'reorder.load.error order=${settings.order} '
            'generation=$generation error=$error',
      );
    }
  }

  /// 仅在共享偏好开启时自动播放正面；手动重播不受该偏好影响。
  ///
  /// 视频卡片先准备画面（加载或定位到句首），就绪后再自动播放，保证声音与
  /// 画面来自同一个播放器。
  Future<void> startCurrentCard() async {
    final card = state.currentCard;
    await _syncVideoForCurrentCard();
    if (!identical(state.currentCard, card)) return;
    if (ref.read(favoriteReviewSettingsProvider).autoPlayFront) {
      await replayCurrent();
    }
  }

  /// 立即废弃旧播放，再从当前句起点播放。
  Future<void> replayCurrent() async {
    final card = state.currentCard;
    if (card == null) return;
    final generation = ++_generation;
    final player = ref.read(shortAudioPlayerProvider);
    await _stopForegroundPlaybackIfActive();
    await player.stop();
    if (!_isCurrent(generation, card)) return;
    markStudyActivity();
    state = state.copyWith(
      playbackState: BookmarkReviewPlaybackState.loading,
      clearMediaError: true,
    );
    try {
      if (!_isCurrent(generation, card)) return;
      state = state.copyWith(
        playbackState: BookmarkReviewPlaybackState.playing,
      );
      final result = await _playCurrentSentence(player, card);
      if (!_isCurrent(generation, card)) return;
      switch (result) {
        case AudioPlaybackResult.completed:
          _recordCompletedSentencePlayback(card);
          state = state.copyWith(
            playbackState: BookmarkReviewPlaybackState.idle,
          );
        case AudioPlaybackResult.cancelled:
          state = state.copyWith(
            playbackState: BookmarkReviewPlaybackState.idle,
          );
        case AudioPlaybackResult.failed:
          state = state.copyWith(
            playbackState: BookmarkReviewPlaybackState.failed,
            mediaError: 'audio_unavailable',
          );
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(generation, card)) return;
      AppLogger.log(
        'FavoriteSentenceReview',
        'media failed error=$error\n$stackTrace',
      );
      state = state.copyWith(
        playbackState: BookmarkReviewPlaybackState.failed,
        mediaError: 'audio_unavailable',
      );
    }
  }

  /// 切换当前句的播放状态；收藏复习背面仅支持从句首播放或停止。
  Future<void> toggleCurrentPlayback() async {
    final playbackState = state.playbackState;
    if (playbackState == BookmarkReviewPlaybackState.loading ||
        playbackState == BookmarkReviewPlaybackState.playing) {
      await interruptPlayback();
      return;
    }
    await replayCurrent();
  }

  Future<void> revealBack() async {
    final controller = _controller;
    final card = state.currentCard;
    if (controller == null ||
        card == null ||
        state.face != BookmarkReviewFace.front) {
      return;
    }
    await interruptPlayback();
    controller.revealAnswer();
    state = state.copyWith(face: BookmarkReviewFace.back, clearPreview: true);
    await controller.preview();
    if (!identical(_controller, controller)) return;
    if (state.currentCard == card && state.face == BookmarkReviewFace.back) {
      state = state.copyWith(preview: controller.state.preview);
      if (ref.read(favoriteReviewSettingsProvider).autoPlayBack) {
        unawaited(replayCurrent());
      }
    }
  }

  /// 提交一次评分：先中断当前媒体，避免最后一张卡进入完成页后仍在播放。
  /// 成功则引擎推进队列并自动播放下一张；失败或乐观锁冲突则停留在背面，
  /// 解除提交中标记以便重试。
  Future<void> selectRating(MemoryRating rating) async {
    final controller = _controller;
    final card = state.currentCard;
    if (controller == null ||
        card == null ||
        state.face != BookmarkReviewFace.back) {
      return;
    }
    if (state.isSubmittingRating || state.preview == null) return;
    state = state.copyWith(isSubmittingRating: true);
    // 评分是当前卡片生命周期的终点，不能依赖下一张卡的自动播放间接停止旧媒体。
    try {
      await interruptPlayback();
    } catch (error, stackTrace) {
      AppLogger.log(
        'FavoriteSentenceReview',
        'interrupt playback before rating failed error=$error\n$stackTrace',
      );
      state = state.copyWith(isSubmittingRating: false);
      return;
    }
    if (!identical(_controller, controller) ||
        !identical(state.currentCard, card) ||
        state.face != BookmarkReviewFace.back) {
      return;
    }
    final submitted = await controller.submitRating(rating);
    if (!identical(_controller, controller)) return;
    if (submitted) {
      _summary = _summary.recordRating(
        subjectId: card.memorySubjectId,
        rating: rating,
      );
      final completionSummary = _completionSummaryIfFinished(controller);
      state = _stateFromController(
        controller,
        completionSummary: completionSummary,
      );
      if (controller.state.current != null) unawaited(startCurrentCard());
    } else {
      AppLogger.log(
        'FavoriteSentenceReview',
        'rating submission failed error=${controller.state.error}',
      );
      if (!identical(controller.state.current?.content, card)) {
        state = _stateFromController(
          controller,
          completionSummary: _completionSummaryIfFinished(controller),
        );
      } else {
        state = state.copyWith(
          isSubmittingRating: false,
          preview: controller.state.preview,
          clearPreview: controller.state.preview == null,
        );
      }
    }
  }

  Future<void> removeCurrentBookmark() async {
    final controller = _controller;
    final card = state.currentCard;
    if (controller == null || card == null || state.isRemoving) return;
    await interruptPlayback();
    state = state.copyWith(isRemoving: true, clearRemoveError: true);
    try {
      await ref
          .read(favoriteSentenceLifecycleProvider)
          .removeBySubjectId(card.memorySubjectId);
      if (!identical(_controller, controller)) return;
      controller.removeCurrent();
      state = _stateFromController(
        controller,
        completionSummary: _completionSummaryIfFinished(controller),
      );
      if (controller.state.current != null) unawaited(startCurrentCard());
    } catch (error, stackTrace) {
      AppLogger.log(
        'FavoriteSentenceReview',
        'unsave failed error=$error\n$stackTrace',
      );
      state = state.copyWith(isRemoving: false, removeError: 'unsave_failed');
    }
  }

  Future<void> interruptPlayback() async {
    _generation++;
    if (state.playbackState != BookmarkReviewPlaybackState.idle) {
      state = state.copyWith(playbackState: BookmarkReviewPlaybackState.idle);
    }
    await _stopForegroundPlaybackIfActive();
    await ref.read(shortAudioPlayerProvider).stop();
    await _videoSession?.cancelPlayback();
  }

  /// 仅清理确实正在播放的旧 just_audio 会话，避免 media_kit 播放时产生误导日志。
  Future<void> _stopForegroundPlaybackIfActive() async {
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    if (engine.isPlaying) {
      await engine.stop();
    }
  }

  /// 幂等结束复习会话，确保退出路由和页面回调不会重复清理资源或漏刷统计。
  Future<void> disposeSession() {
    // notifier 已销毁（页面 dispose 晚于容器/provider 释放）时无可收尾的状态。
    if (!ref.mounted) return Future<void>.value();
    final inFlight = _disposeSessionInFlight;
    if (inFlight != null) return inFlight;
    final operation = _disposeSessionImpl();
    late final Future<void> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_disposeSessionInFlight, tracked)) {
        _disposeSessionInFlight = null;
      }
    });
    _disposeSessionInFlight = tracked;
    return tracked;
  }

  Future<void> _disposeSessionImpl() async {
    _orderGeneration++;
    _hasSession = false;
    try {
      await interruptPlayback();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'favorite sentence playback cleanup failed error=$error\n$stackTrace',
      );
    }

    final timer = _studySessionTimer;
    final initialTotal = state.initialTotal;
    try {
      await timer?.stop();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'favorite sentence timer stop failed error=$error\n$stackTrace',
      );
    }
    try {
      await ref.read(studyTimeServiceProvider).flush();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'favorite sentence statistics flush failed error=$error\n$stackTrace',
      );
    } finally {
      try {
        await timer?.dispose();
      } catch (error, stackTrace) {
        AppLogger.log(
          'StudyExit',
          'favorite sentence timer cleanup failed error=$error\n$stackTrace',
        );
      }
      if (identical(_studySessionTimer, timer)) {
        _studySessionTimer = null;
      }
      if (initialTotal > 0) {
        ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceReviewCompleted,
              analyticsParams: {
                EventParams.totalSentencesCount: initialTotal,
                EventParams.durationMs: 0,
              },
            );
      }
      _videoGeneration++;
      await _releaseVideoSession(reason: 'session-dispose');
      _controller?.dispose();
      _controller = null;
      state = const BookmarkReviewState();
    }
  }

  /// 将通用会话的当前项和计数映射为页面所需的最小状态。
  BookmarkReviewState _stateFromController(
    ScheduledFlashcardController<BookmarkSentence> controller, {
    ReviewSessionSummary? completionSummary,
  }) => BookmarkReviewState(
    currentCard: controller.state.current?.content,
    initialTotal: controller.state.initialTotal,
    remainingCount: controller.state.remainingCount,
    reviewedCount: controller.state.reviewedCount,
    completionSummary: completionSummary,
    upcomingCards: _upcomingCards(controller),
    // 画面在切卡时保留，由 [_syncVideoForCurrentCard] 决定复用、重新加载或关闭，
    // 避免同一材料的相邻卡片之间布局闪回单栏。
    videoPhase: state.videoPhase,
    isVideoVisualVisible: state.isVideoVisualVisible,
    videoAspectRatio: state.videoAspectRatio,
  );

  List<BookmarkSentence> _upcomingCards(
    ScheduledFlashcardController<BookmarkSentence> controller,
  ) => controller
      .upcoming(kAiPrewarmAheadCount)
      .map((card) => card.content)
      .toList(growable: false);

  /// 调度器没有下一张可展示卡时，统一产出本次会话的完成快照。
  ///
  /// 评分结束和取消最后一张收藏句都会走这里；取消收藏本身不写入 [_summary]。
  ReviewSessionSummary? _completionSummaryIfFinished(
    ScheduledFlashcardController<BookmarkSentence> controller,
  ) {
    if (controller.state.phase != ScheduledFlashcardPhase.completed) {
      return null;
    }
    unawaited(_stopTimerSafely());
    return _summary.complete(
      elapsed: _studySessionTimer?.elapsed ?? Duration.zero,
      reviewedCount: controller.state.reviewedCount,
    );
  }

  bool _isCurrent(int generation, BookmarkSentence card) =>
      generation == _generation && identical(state.currentCard, card);

  /// 只有完整播放才提交输入统计；中断、切卡和退出都不会调用此方法。
  void _recordCompletedSentencePlayback(BookmarkSentence card) {
    ref
        .read(studyTimeServiceProvider)
        .submitSentencePlayback(
          duration: card.sentence.duration,
          text: card.sentence.text,
          stage: StudyStage.savedSentencesReview,
        );
  }

  Future<void> _stopTimerSafely() async {
    try {
      await _studySessionTimer?.stop();
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'favorite sentence timer stop failed error=$error\n$stackTrace',
      );
    }
  }

  /// 当前卡片画面就绪时由媒体引擎播放（画面随声音移动），否则复用短音频
  /// 播放器播放原始区间（视频文件只输出音轨）。
  Future<AudioPlaybackResult> _playCurrentSentence(
    LocalAudioClipPlayer player,
    BookmarkSentence card,
  ) async {
    final videoSession = this.videoSession;
    if (videoSession == null) {
      AppLogger.log(
        'FavoriteSentenceReview',
        'play path=audio card=${card.memorySubjectId}',
      );
      return _playSentenceRange(player, card);
    }
    AppLogger.log(
      'FavoriteSentenceReview',
      'play path=video card=${card.memorySubjectId} '
          'range=${card.sentence.startTime.inMilliseconds}-'
          '${card.sentence.endTime.inMilliseconds}ms',
    );
    final result = await videoSession.playRange(
      card.sentence.startTime,
      card.sentence.endTime,
    );
    AppLogger.log(
      'FavoriteSentenceReview',
      'play path=video result=${result.name} card=${card.memorySubjectId}',
    );
    return switch (result) {
      SentencePlaybackResult.completed => AudioPlaybackResult.completed,
      SentencePlaybackResult.cancelled => AudioPlaybackResult.cancelled,
      SentencePlaybackResult.failed => AudioPlaybackResult.failed,
    };
  }

  /// 复用短音频播放器播放收藏句原始区间；视频文件由 media_kit 只输出音轨。
  Future<AudioPlaybackResult> _playSentenceRange(
    LocalAudioClipPlayer player,
    BookmarkSentence card,
  ) async {
    return LocalAudioRangePlayer(
      audioItemDao: ref.read(audioItemDaoProvider),
      audioClipPlayer: player,
    ).play(
      audioItemId: card.audioItemId,
      start: card.sentence.startTime,
      end: card.sentence.endTime,
      playbackKey: 'favorite-sentence-review:${card.memorySubjectId}',
    );
  }

  /// 设置「显示视频画面」切换后立即生效：先停掉当前播放，再按新设置准备画面。
  Future<void> _applyShowVideoChange() async {
    await interruptPlayback();
    await _syncVideoForCurrentCard();
  }

  /// 让视频画面与当前卡片一致。
  ///
  /// - 需要画面（视频材料且设置开启）：同一材料只定位到句首，否则加载新材料；
  /// - 不需要画面：关闭视频会话，回到纯音频复习；
  /// - 加载失败：关闭会话并退回音频播放，不阻断复习。
  Future<void> _syncVideoForCurrentCard() async {
    final generation = ++_videoGeneration;
    try {
      await _applyVideoForCurrentCard(generation);
    } catch (error, stackTrace) {
      // 画面只是增强能力：同步异常只退回音频，不能让切卡中断或自动播放失效。
      // 被取代或已销毁时不改写状态，避免覆盖新卡片的画面阶段。
      AppLogger.log(
        'FavoriteSentenceReview',
        'video.sync failed generation=$generation error=$error\n$stackTrace',
      );
      if (generation == _videoGeneration) {
        state = state.copyWith(videoPhase: BookmarkReviewVideoPhase.none);
      }
    }
  }

  Future<void> _applyVideoForCurrentCard(int generation) async {
    final card = state.currentCard;
    final showVideo = ref.read(bookmarkReviewSettingsProvider).showVideo;
    final item = card == null || !showVideo
        ? null
        : await _readVideoItem(card.audioItemId);
    if (generation != _videoGeneration) return;
    if (card == null || item == null) {
      final reason = card == null
          ? 'no-card'
          : !showVideo
          ? 'setting-off'
          : 'not-video';
      if (_videoSession != null ||
          state.videoPhase != BookmarkReviewVideoPhase.none) {
        AppLogger.log(
          'FavoriteSentenceReview',
          'video.sync action=close reason=$reason '
              'card=${card?.memorySubjectId}',
        );
      }
      await _releaseVideoSession(reason: reason);
      return;
    }
    final session = _videoSession ??= FavoriteSentenceVideoSession(
      engine: ref.read(mediaEngineProvider.notifier),
      audioEngine: ref.read(audioEngineProvider.notifier),
      audioItemDao: ref.read(audioItemDaoProvider),
    );
    if (session.isLoaded(item.id)) {
      AppLogger.log(
        'FavoriteSentenceReview',
        'video.sync action=reuse card=${card.memorySubjectId} audio=${item.id} '
            'start=${card.sentence.startTime.inMilliseconds}ms',
      );
      await session.previewPosition(card.sentence.startTime);
      if (generation != _videoGeneration) return;
      state = state.copyWith(videoPhase: BookmarkReviewVideoPhase.ready);
      return;
    }
    AppLogger.log(
      'FavoriteSentenceReview',
      'video.sync action=open card=${card.memorySubjectId} audio=${item.id} '
          'start=${card.sentence.startTime.inMilliseconds}ms',
    );
    state = state.copyWith(videoPhase: BookmarkReviewVideoPhase.loading);
    final stopwatch = Stopwatch()..start();
    final result = await session.open(
      item: item,
      sentenceStart: card.sentence.startTime,
    );
    AppLogger.log(
      'FavoriteSentenceReview',
      'video.open result=${result.name} audio=${item.id} '
          'elapsedMs=${stopwatch.elapsedMilliseconds} '
          'stale=${generation != _videoGeneration}',
    );
    if (generation != _videoGeneration || !identical(_videoSession, session)) {
      return;
    }
    switch (result) {
      case FavoriteVideoOpenResult.opened:
        _bindVideoPresentation(session);
        // 本次复习中隐藏过画面时，新加载的视频（含音频卡之后重新创建的会话）
        // 保持隐藏。
        if (!state.isVideoVisualVisible && session.visualTrackVisible) {
          await session.setVisualTrackVisible(false);
          if (generation != _videoGeneration) return;
        }
        state = state.copyWith(
          videoPhase: BookmarkReviewVideoPhase.ready,
          isVideoVisualVisible: session.visualTrackVisible,
          videoAspectRatio: session.videoAspectRatio,
        );
      case FavoriteVideoOpenResult.cancelled:
        break;
      case FavoriteVideoOpenResult.failed:
        AppLogger.log(
          'FavoriteSentenceReview',
          'video.fallback to=audio card=${card.memorySubjectId} audio=${item.id}',
        );
        await _releaseVideoSession(reason: 'load-failed');
    }
  }

  /// 读取需要显示画面的视频材料；音频材料或记录缺失时返回 null。
  Future<AudioItem?> _readVideoItem(String audioItemId) async {
    final row = await ref.read(audioItemDaoProvider).getById(audioItemId);
    if (row == null) return null;
    final item = audioItemFromDatabaseRow(row);
    return item.isVideo ? item : null;
  }

  /// 首次加载成功后监听画面显示 / 隐藏与视频宽高比，同步进页面状态。
  void _bindVideoPresentation(FavoriteSentenceVideoSession session) {
    if (_videoAspectRatioSubscription != null) return;
    session.presentationChanges?.addListener(_handleVideoPresentationChanged);
    _videoAspectRatioSubscription = session.videoAspectRatioStream.listen((
      ratio,
    ) {
      if (!identical(_videoSession, session) || ratio == null) return;
      state = state.copyWith(videoAspectRatio: ratio);
    });
  }

  void _handleVideoPresentationChanged() {
    final session = _videoSession;
    if (session == null) return;
    final visible = session.visualTrackVisible;
    if (visible == state.isVideoVisualVisible) return;
    AppLogger.log(
      'FavoriteSentenceReview',
      'video.visual ${visible ? 'shown' : 'hidden'} '
          'card=${state.currentCard?.memorySubjectId}',
    );
    state = state.copyWith(isVideoVisualVisible: visible);
  }

  /// 关闭视频会话并回到无画面状态；先更新状态让页面卸下画面，再释放引擎。
  Future<void> _releaseVideoSession({required String reason}) async {
    final session = _videoSession;
    _videoSession = null;
    if (ref.mounted && state.videoPhase != BookmarkReviewVideoPhase.none) {
      state = state.copyWith(videoPhase: BookmarkReviewVideoPhase.none);
    }
    if (session == null) return;
    await _videoAspectRatioSubscription?.cancel();
    _videoAspectRatioSubscription = null;
    session.presentationChanges?.removeListener(
      _handleVideoPresentationChanged,
    );
    AppLogger.log('FavoriteSentenceReview', 'video.release reason=$reason');
    await session.close();
  }
}

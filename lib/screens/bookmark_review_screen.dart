/// 收藏句极简闪卡复习页面。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../features/chatbot/sentence_passage.dart';
import '../features/memory_scheduler/domain/memory_rating.dart';
import '../features/memory_scheduler/domain/memory_scheduler_results.dart';
import '../features/scheduled_flashcard/widgets/flashcard_rating_action_bar.dart';
import '../features/rating_prompt/rating_prompt_providers.dart';
import '../l10n/app_localizations.dart';
import '../database/providers.dart';
import '../models/bookmark_sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/bookmark_review_settings_provider.dart';
import '../providers/favorite_review_settings_provider.dart';
import '../providers/short_audio_player_provider.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/sentence_ai_prewarm.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/sense_group_range_playback_provider.dart';
import '../services/pronunciation/local_audio_sense_group_range_playback.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/common/media_startup_status.dart';
import '../widgets/common/media_visual_surface.dart';
import '../widgets/common/practice_media_presentation_host.dart';
import '../widgets/common/practice_media_split_layout.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/favorites/favorite_sentence_video_session.dart';
import '../widgets/practice/sentence_explanation_view.dart';
import '../widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import '../widgets/review/review_status_bar.dart';
import '../widgets/review/review_completion_summary.dart';
import '../widgets/review/review_front_layout.dart';
import '../widgets/study/study_activity_detector.dart';

class BookmarkReviewScreen extends ConsumerStatefulWidget {
  const BookmarkReviewScreen({super.key});

  @override
  ConsumerState<BookmarkReviewScreen> createState() =>
      _BookmarkReviewScreenState();
}

class _BookmarkReviewScreenState extends ConsumerState<BookmarkReviewScreen>
    with WakelockMixin {
  late final BookmarkReview _review;
  Future<void>? _disposeSessionFuture;
  bool _isExiting = false;
  bool _isDictionaryPanelOpen = false;
  final GlobalKey<DictionaryPanelHostState> _dictionaryHostKey =
      GlobalKey<DictionaryPanelHostState>();
  final GlobalKey _reviewContentKey = GlobalKey(
    debugLabel: 'bookmark-review-content',
  );

  @override
  void initState() {
    super.initState();
    _review = ref.read(bookmarkReviewProvider.notifier);
    // 只有显式完成摘要才代表本次复习正常结束，中途退出不记为任务完成。
    ref.listenManual(
      bookmarkReviewProvider.select((state) => state.completionSummary),
      (_, next) {
        if (next == null) return;
        unawaited(
          recordRatingTaskCompletion(
            () => ref.read(ratingPromptTaskCompletionStoreProvider),
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_review.startCurrentCard());
      }
    });
  }

  /// 页面生命周期内只启动一次会话收尾，避免返回回调与 dispose 兜底重复刷统计。
  Future<void> _disposeSessionOnce() =>
      _disposeSessionFuture ??= _review.disposeSession();

  @override
  void dispose() {
    // 外部路由替换不会经过页面返回按钮，销毁时后台启动同一幂等收尾。
    scheduleMicrotask(() => unawaited(_disposeSessionOnce()));
    super.dispose();
  }

  Future<void> _exit() async {
    if (_isExiting) return;
    _isExiting = true;
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.favorites);
      }
    }
    await _disposeSessionOnce();
  }

  Future<void> _openSettings() async {
    await _review.interruptPlayback();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const BookmarkReviewSettingsSheet(
        task: FavoriteReviewSettingsTask.sentence,
      ),
    );
  }

  Future<void> _removeCurrent() async {
    await _review.removeCurrentBookmark();
    if (!mounted) return;
    final error = ref.read(bookmarkReviewProvider).removeError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.bookmarkReviewUnsaveFailed,
            ),
          ),
        );
    }
  }

  /// 同步词典面板状态，让面板关闭时保留 iOS 原生边缘返回手势。
  void _handleDictionaryPanelOpenStateChanged(bool isOpen) {
    if (_isDictionaryPanelOpen == isOpen) return;
    setState(() => _isDictionaryPanelOpen = isOpen);
  }

  /// 仅把显式完成摘要映射为完成页，避免退出清理的空状态误触发完成态。
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookmarkReviewProvider);
    final card = state.currentCard;
    final completionSummary = state.completionSummary;
    final l10n = AppLocalizations.of(context)!;
    final player = _review;

    return StudyActivityDetector(
      onActivity: player.markStudyActivity,
      child: wakelockBody(
        child: PopScope(
          // 仅在词典面板打开时拦截返回；固定为 false 会禁用 iOS 边缘返回手势。
          canPop: !_isDictionaryPanelOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              // 原生返回手势已完成，只释放会话，避免再次触发 pop。
              if (!_isExiting) {
                _isExiting = true;
                unawaited(_disposeSessionOnce());
              }
              return;
            }
            if (_dictionaryHostKey.currentState?.closeIfOpen() == true) {
              return;
            }
            unawaited(_exit());
          },
          child: Scaffold(
            appBar: AppBar(
              actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
              leading: IconButton(
                key: const Key('bookmark-review-close'),
                onPressed: _exit,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(l10n.bookmarkReviewTitle),
              centerTitle: true,
              actions: [
                SentenceChatButton(
                  target: SentenceChatTarget(
                    text: card?.sentence.text ?? '',
                    audioItemId: card?.audioItemId,
                    sentenceIndex: card?.originalSentenceIndex,
                  ),
                  onBeforeOpen: () => unawaited(player.interruptPlayback()),
                ),
                IconButton(
                  key: const Key('bookmark-review-settings'),
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            // 当前卡片为空可能是退出清理，只有显式完成摘要才代表复习完成。
            body: completionSummary != null
                ? ReviewCompletionSummary(
                    title: l10n.bookmarkReviewCompleted,
                    summary: completionSummary,
                    onExit: _exit,
                    doneLabel: l10n.done,
                    durationLabel: l10n.reviewStatisticsDuration,
                    reviewedLabel: l10n.reviewCompletionReviewed,
                    retentionLabel: l10n.reviewStatisticsRetentionRate,
                    ratingsLabel: l10n.reviewStatisticsRatings,
                    againLabel: l10n.bookmarkReviewRatingAgain,
                    goodLabel: l10n.bookmarkReviewRatingGood,
                    easyLabel: l10n.bookmarkReviewRatingEasy,
                  )
                : card == null
                ? const SizedBox.shrink()
                : _buildReviewBody(context, state, card),
          ),
        ),
      ),
    );
  }

  /// 复习主体：当前卡片有视频画面时套用学习任务的自适应分栏（竖屏上下、
  /// 宽屏左右），否则保持纯音频的单栏布局。
  ///
  /// 卡片内容挂在固定 GlobalKey 下，切换有无画面时讲解视图等状态原样保留。
  Widget _buildReviewBody(
    BuildContext context,
    BookmarkReviewState state,
    BookmarkSentence card,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final player = _review;
    final videoSession = player.videoSession;
    final isPlaying =
        state.playbackState == BookmarkReviewPlaybackState.loading ||
        state.playbackState == BookmarkReviewPlaybackState.playing;
    final content = KeyedSubtree(
      key: _reviewContentKey,
      // 宽屏下整页（进度条、卡面、评分栏、状态栏）限宽居中，避免正文与评分按钮被拉满整窗。
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              _ReviewProgress(
                progress: state.progress,
                source: l10n.bookmarkReviewFromAudio(card.audioName),
                duration: l10n.sentenceDuration(
                  (card.sentence.duration.inMilliseconds / 1000)
                      .toStringAsFixed(1),
                ),
                isRemoving: state.isRemoving,
                onRemove: _removeCurrent,
              ),
              Expanded(
                child: state.face == BookmarkReviewFace.front
                    ? _ListeningFront(
                        playbackState: state.playbackState,
                        hasError: state.mediaError != null,
                        onReplay: () => unawaited(player.replayCurrent()),
                        onReveal: () => unawaited(player.revealBack()),
                      )
                    : ProviderScope(
                        // 意群播放与讲解视图创建时绑定播放器；视频 / 音频切换时整体
                        // 重建背面，避免沿用另一条播放链路。
                        key: ValueKey('answer-${videoSession != null}'),
                        overrides: [
                          senseGroupRangePlaybackProvider.overrideWith(
                            (ref) => videoSession != null
                                ? videoSession.rangePlaybackBuilder(() => 1.0)
                                : LocalAudioSenseGroupRangePlayback(
                                    audioItemDao: ref.read(
                                      audioItemDaoProvider,
                                    ),
                                    audioClipPlayer: ref.read(
                                      shortAudioPlayerProvider,
                                    ),
                                  ),
                          ),
                        ],
                        child: _ReviewAnswer(
                          card: card,
                          upcomingCards: state.upcomingCards,
                          preview: state.preview,
                          showNextReviewTime: ref.watch(
                            favoriteReviewSettingsProvider.select(
                              (settings) => settings.showNextReviewTime,
                            ),
                          ),
                          isSubmitting: state.isSubmittingRating,
                          playbackState: state.playbackState,
                          videoSession: videoSession,
                          onTogglePlayback: () =>
                              unawaited(player.toggleCurrentPlayback()),
                          onRating: (rating) =>
                              unawaited(player.selectRating(rating)),
                        ),
                      ),
              ),
              ReviewStatusBar(
                key: const Key('bookmark-review-status-bar'),
                elapsed: () => player.elapsed,
                reviewedCount: state.reviewedCount,
                remainingCount: state.remainingCount,
                elapsedLabel:
                    Localizations.localeOf(context).languageCode == 'zh'
                    ? '学习时长'
                    : 'Study time',
                reviewedLabel:
                    Localizations.localeOf(context).languageCode == 'zh'
                    ? '已复习'
                    : 'Reviewed',
                remainingLabel: l10n.reviewStatusRemaining,
              ),
            ],
          ),
        ),
      ),
    );
    Widget wrapDictionaryPanelHost(Widget child) => DictionaryPanelHost(
      key: _dictionaryHostKey,
      onOpenStateChanged: _handleDictionaryPanelOpenStateChanged,
      child: child,
    );
    if (state.videoPhase == BookmarkReviewVideoPhase.none) {
      return wrapDictionaryPanelHost(content);
    }
    return PracticeMediaSplitLayout(
      media: videoSession == null
          ? null
          : PracticeMediaVisualSurface(
              audioItemId: card.audioItemId,
              session: videoSession.mediaSession,
              isPlaying: isPlaying,
              onPlayPause: () => unawaited(player.toggleCurrentPlayback()),
              // 尺寸由分栏决定，画面铺满分给视频的区域。
              fillAvailableHeight: true,
              // 复习不显示字幕、不全屏；遮罩照常可开关。
              controls: const MediaVisualControls(
                showSubtitleTrackButton: false,
                showFullscreenButton: false,
              ),
            ),
      isMediaResizable: state.isVideoVisualVisible,
      videoAspectRatio: state.videoAspectRatio,
      panelHostBuilder: wrapDictionaryPanelHost,
      startupStatus: state.videoPhase == BookmarkReviewVideoPhase.loading
          ? const MediaStartupStatus(
              phase: ManagedMediaPhase.loading,
              retry: _noop,
            )
          : null,
      content: content,
    );
  }
}

/// 复习的视频加载失败会直接退回音频，不提供重试入口。
void _noop() {}

class _ReviewProgress extends StatelessWidget {
  const _ReviewProgress({
    required this.progress,
    required this.source,
    required this.duration,
    required this.isRemoving,
    required this.onRemove,
  });

  final double progress;
  final String source;
  final String duration;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            key: const Key('bookmark-review-progress'),
            value: progress,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.s),
          LayoutBuilder(
            builder: (context, constraints) {
              final details = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      source,
                      key: const Key('bookmark-review-source'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text('·', style: muted),
                  const SizedBox(width: AppSpacing.s),
                  Text(duration, style: muted),
                ],
              );
              // 取消收藏沿用复习页的轻量文字操作，不使用强调色按钮。
              final action = Semantics(
                key: const Key('bookmark-review-unsave'),
                button: true,
                enabled: !isRemoving,
                label: AppLocalizations.of(context)!.bookmarkReviewUnsave,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isRemoving ? null : onRemove,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.bookmarkReviewUnsave,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          if (isRemoving)
                            const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.bookmark,
                              size: 22,
                              color: AppTheme.bookmarkColor,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.xs),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ListeningFront extends StatelessWidget {
  const _ListeningFront({
    required this.playbackState,
    required this.hasError,
    required this.onReplay,
    required this.onReveal,
  });

  final BookmarkReviewPlaybackState playbackState;
  final bool hasError;
  final VoidCallback onReplay;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPlaybackActive =
        playbackState == BookmarkReviewPlaybackState.loading ||
        playbackState == BookmarkReviewPlaybackState.playing;
    final status = switch (playbackState) {
      BookmarkReviewPlaybackState.loading => l10n.bookmarkReviewLoadingAudio,
      BookmarkReviewPlaybackState.playing => l10n.bookmarkReviewPlaying,
      BookmarkReviewPlaybackState.failed => l10n.bookmarkReviewTapRetry,
      BookmarkReviewPlaybackState.idle => l10n.bookmarkReviewTapReplay,
    };
    return ReviewFrontLayout(
      listenZoneKey: const Key('bookmark-review-listen-zone'),
      revealZoneKey: const Key('bookmark-review-reveal-zone'),
      revealLabel: l10n.bookmarkReviewReadyTitle,
      onReplay: onReplay,
      onReveal: onReveal,
      listenContent: ReviewPlaybackPrompt(
        icon: hasError ? Icons.refresh_rounded : Icons.headphones_rounded,
        tone: hasError
            ? ReviewPlaybackTone.error
            : isPlaybackActive
            ? ReviewPlaybackTone.active
            : ReviewPlaybackTone.idle,
        status: status,
        detail: hasError
            ? l10n.bookmarkReviewAudioSkipped
            : l10n.bookmarkReviewListenPrompt,
      ),
    );
  }
}

class _ReviewAnswer extends ConsumerWidget {
  const _ReviewAnswer({
    required this.card,
    required this.upcomingCards,
    required this.preview,
    required this.showNextReviewTime,
    required this.isSubmitting,
    required this.playbackState,
    required this.videoSession,
    required this.onTogglePlayback,
    required this.onRating,
  });

  final BookmarkSentence card;

  /// 当前卡片画面就绪时的视频会话；逐词高亮改为跟随媒体引擎时间轴。
  final FavoriteSentenceVideoSession? videoSession;

  /// 当前卡之后即将展示的收藏句，答案面展示期间后台预热其 AI 内容。
  final List<BookmarkSentence> upcomingCards;
  final MemoryRatingPreviewSet? preview;
  final bool showNextReviewTime;
  final bool isSubmitting;
  final BookmarkReviewPlaybackState playbackState;
  final VoidCallback onTogglePlayback;
  final ValueChanged<MemoryRating> onRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sentenceSettings = ref.watch(bookmarkReviewSettingsProvider);
    final actions = [
      FlashcardRatingAction(
        rating: MemoryRating.again,
        emoji: '😕',
        label: l10n.bookmarkReviewRatingAgain,
        detail: formatNextReviewTimeDetail(
          context,
          showNextReviewTime: showNextReviewTime,
          interval: preview?.again.interval,
        ),
      ),
      FlashcardRatingAction(
        rating: MemoryRating.good,
        emoji: '🙂',
        label: l10n.bookmarkReviewRatingGood,
        detail: formatNextReviewTimeDetail(
          context,
          showNextReviewTime: showNextReviewTime,
          interval: preview?.good.interval,
        ),
      ),
      FlashcardRatingAction(
        rating: MemoryRating.easy,
        emoji: '😎',
        label: l10n.bookmarkReviewRatingEasy,
        detail: formatNextReviewTimeDetail(
          context,
          showNextReviewTime: showNextReviewTime,
          interval: preview?.easy.interval,
        ),
      ),
    ];
    final isPlaying =
        playbackState == BookmarkReviewPlaybackState.loading ||
        playbackState == BookmarkReviewPlaybackState.playing;
    return Column(
      key: const Key('bookmark-review-answer'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: SentenceExplanationView(
              text: card.sentence.text,
              aiNotifier: ref.read(sentenceAiNotifierProvider),
              audioItemId: card.audioItemId,
              sentenceIndex: card.originalSentenceIndex,
              sentenceStartMs: card.sentence.startTime.inMilliseconds,
              sentenceEndMs: card.sentence.endTime.inMilliseconds,
              wordHighlightSource:
                  videoSession?.wordHighlightSource(card.audioItemId) ??
                  WordHighlightSource(
                    audioItemId: card.audioItemId,
                    positionStream: ref
                        .read(shortAudioPlayerProvider)
                        .positionStream,
                    currentPosition: ref
                        .read(shortAudioPlayerProvider)
                        .currentPosition,
                    playbackStatus: ref
                        .read(shortAudioPlayerProvider)
                        .wordHighlightPlaybackStatus,
                    playbackStatusStream: ref
                        .read(shortAudioPlayerProvider)
                        .wordHighlightPlaybackStatusStream,
                  ),
              senseGroupRangePlayback: ref.read(
                senseGroupRangePlaybackProvider,
              ),
              enableGuide: false,
              explanationContext: const SentenceExplanationContext(
                source: 'bookmarkReview',
              ),
              autoShowAiExplanation: sentenceSettings.autoShowAiExplanation,
              autoShowAiAnalysis: sentenceSettings.autoShowAiAnalysis,
              autoShowAiTranslation: sentenceSettings.autoShowAiTranslation,
              autoShowAiSenseGroups: sentenceSettings.autoShowAiSenseGroups,
              prewarmTargets: [
                for (final upcoming in upcomingCards)
                  SentenceAiPrewarmTarget(
                    text: upcoming.sentence.text,
                    audioItemId: upcoming.audioItemId,
                    sentenceIndex: upcoming.originalSentenceIndex,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('bookmark-review-sentence-playback'),
                width: double.infinity,
                height: 44,
                child: FilledButton.tonalIcon(
                  key: const Key('bookmark-review-sentence-playback-toggle'),
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: onTogglePlayback,
                  icon: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: isPlaying
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    isPlaying
                        ? l10n.stopPlayback
                        : l10n.bookmarkReviewPlayOriginal,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              FlashcardRatingActionBar(
                actions: actions,
                enabled: preview != null && !isSubmitting,
                onSelected: (action) => onRating(action.rating),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

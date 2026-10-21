/// 收藏句极简闪卡复习页面。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../features/memory_scheduler/domain/memory_rating.dart';
import '../features/memory_scheduler/domain/memory_scheduler_results.dart';
import '../features/scheduled_flashcard/widgets/flashcard_rating_action_bar.dart';
import '../l10n/app_localizations.dart';
import '../database/providers.dart';
import '../models/bookmark_sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/bookmark_review_settings_provider.dart';
import '../providers/favorite_review_settings_provider.dart';
import '../providers/short_audio_player_provider.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/sense_group_range_playback_provider.dart';
import '../services/pronunciation/local_audio_sense_group_range_playback.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/sentence_explanation_view.dart';
import '../widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import '../widgets/review/review_status_bar.dart';
import '../widgets/review/review_completion_summary.dart';
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

  @override
  void initState() {
    super.initState();
    _review = ref.read(bookmarkReviewProvider.notifier);
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
                  sentenceText: card?.sentence.text ?? '',
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
                : DictionaryPanelHost(
                    key: _dictionaryHostKey,
                    onOpenStateChanged: _handleDictionaryPanelOpenStateChanged,
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
                                  onReplay: () =>
                                      unawaited(player.replayCurrent()),
                                  onReveal: () =>
                                      unawaited(player.revealBack()),
                                )
                              : ProviderScope(
                                  overrides: [
                                    senseGroupRangePlaybackProvider
                                        .overrideWith(
                                          (ref) =>
                                              LocalAudioSenseGroupRangePlayback(
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
                                    preview: state.preview,
                                    showNextReviewTime: ref.watch(
                                      favoriteReviewSettingsProvider.select(
                                        (settings) =>
                                            settings.showNextReviewTime,
                                      ),
                                    ),
                                    isSubmitting: state.isSubmittingRating,
                                    playbackState: state.playbackState,
                                    onTogglePlayback: () => unawaited(
                                      player.toggleCurrentPlayback(),
                                    ),
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
                              Localizations.localeOf(context).languageCode ==
                                  'zh'
                              ? '学习时长'
                              : 'Study time',
                          reviewedLabel:
                              Localizations.localeOf(context).languageCode ==
                                  'zh'
                              ? '已复习'
                              : 'Reviewed',
                          remainingLabel: l10n.reviewStatusRemaining,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            AppSpacing.xs,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Material(
                    key: const Key('bookmark-review-listen-zone'),
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.42,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onReplay,
                      child: SizedBox.expand(
                        child: _CenteredPrompt(
                          icon: hasError
                              ? Icons.refresh_rounded
                              : Icons.headphones_rounded,
                          title: status,
                          body: hasError
                              ? l10n.bookmarkReviewAudioSkipped
                              : l10n.bookmarkReviewListenPrompt,
                          accent: hasError
                              ? theme.colorScheme.error
                              : isPlaybackActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Expanded(
                  flex: 1,
                  child: Material(
                    key: const Key('bookmark-review-reveal-zone'),
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onReveal,
                      child: SizedBox.expand(
                        child: _CenteredPrompt(
                          icon: Icons.visibility_outlined,
                          title: l10n.bookmarkReviewReadyTitle,
                          body: l10n.bookmarkReviewRevealHint,
                          accent: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredPrompt extends StatelessWidget {
  const _CenteredPrompt({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.m),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - AppSpacing.m * 2).clamp(
            0,
            double.infinity,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, size: 28, color: accent),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReviewAnswer extends ConsumerWidget {
  const _ReviewAnswer({
    required this.card,
    required this.preview,
    required this.showNextReviewTime,
    required this.isSubmitting,
    required this.playbackState,
    required this.onTogglePlayback,
    required this.onRating,
  });

  final BookmarkSentence card;
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
              wordHighlightSource: WordHighlightSource(
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
              autoShowAiExplanation: sentenceSettings.autoShowAiExplanation,
              autoShowAiAnalysis: sentenceSettings.autoShowAiAnalysis,
              autoShowAiTranslation: sentenceSettings.autoShowAiTranslation,
              autoShowAiSenseGroups: sentenceSettings.autoShowAiSenseGroups,
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

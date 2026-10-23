/// 收藏词汇极简闪卡复习页面（本步仅实现正面 + 反面占位）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../features/chatbot/sentence_passage.dart';
import '../features/auth/sign_in_required_dialog.dart';
import '../features/subscription/widgets/feature_gate.dart';
import '../features/memory_scheduler/domain/memory_rating.dart';
import '../features/memory_scheduler/domain/memory_scheduler_results.dart';
import '../features/scheduled_flashcard/widgets/flashcard_rating_action_bar.dart';
import '../providers/learning_session/favorite_vocabulary_review_provider.dart';
import '../providers/favorite_review_settings_provider.dart';
import '../providers/dictionary/lookup_controller.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../providers/pronunciation/pronunciation_providers.dart';
import '../providers/tts/tts_controller_provider.dart';
import '../database/providers.dart';
import '../models/dictionary/dictionary_lookup_result.dart';
import '../models/dictionary/dict_speakable_texts.dart';
import '../models/flashcard_item.dart';
import '../router/app_router.dart';
import '../widgets/dictionary/ai_dict_result_view.dart';
import '../widgets/dictionary/local_dict_result_view.dart';
import '../widgets/dictionary/pronunciation_controls.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/selectable_sentence_text.dart';
import '../services/dictionary/dictionary_source.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import '../widgets/review/review_status_bar.dart';
import '../widgets/review/review_completion_summary.dart';
import '../widgets/study/study_activity_detector.dart';

class FavoriteVocabularyReviewScreen extends ConsumerStatefulWidget {
  const FavoriteVocabularyReviewScreen({super.key});

  @override
  ConsumerState<FavoriteVocabularyReviewScreen> createState() =>
      _FavoriteVocabularyReviewScreenState();
}

class _FavoriteVocabularyReviewScreenState
    extends ConsumerState<FavoriteVocabularyReviewScreen>
    with WakelockMixin {
  late final FavoriteVocabularyReview _review;
  Future<void>? _disposeSessionFuture;
  bool _isExiting = false;
  bool _isDictionaryPanelOpen = false;
  final GlobalKey<DictionaryPanelHostState> _dictionaryHostKey =
      GlobalKey<DictionaryPanelHostState>();

  @override
  void initState() {
    super.initState();
    _review = ref.read(favoriteVocabularyReviewProvider.notifier);
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
        task: FavoriteReviewSettingsTask.vocabulary,
      ),
    );
  }

  Future<void> _removeCurrent() async {
    await _review.removeCurrentVocabulary();
    if (!mounted) return;
    final error = ref.read(favoriteVocabularyReviewProvider).removeError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    final state = ref.watch(favoriteVocabularyReviewProvider);
    final card = state.currentCard;
    final completionSummary = state.completionSummary;
    final l10n = AppLocalizations.of(context)!;
    final player = _review;

    return StudyActivityDetector(
      onActivity: player.markStudyActivity,
      child: wakelockBody(
        child: PopScope(
          // 仅在词典面板打开时拦截返回，避免禁用 iOS 边缘返回手势。
          canPop: !_isDictionaryPanelOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              // 系统返回手势已完成，释放本次复习会话但不要再次触发 pop。
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
                key: const Key('favorite-vocabulary-review-close'),
                onPressed: _exit,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(l10n.favoriteVocabularyReviewTitle),
              centerTitle: true,
              actions: [
                SentenceChatButton(
                  target: SentenceChatTarget(
                    text: card?.displayText ?? '',
                    audioItemId: card?.audioItemId,
                    sentenceIndex: card?.sentenceIndex,
                  ),
                  onBeforeOpen: () => unawaited(player.interruptPlayback()),
                ),
                IconButton(
                  key: const Key('favorite-vocabulary-review-settings'),
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            // 当前卡片为空可能是退出清理，只有显式完成摘要才代表复习完成。
            body: completionSummary != null
                ? ReviewCompletionSummary(
                    title: l10n.favoriteVocabularyReviewCompleted,
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
                        _ReviewProgress(progress: state.progress),
                        Expanded(
                          child:
                              state.face == FavoriteVocabularyReviewFace.front
                              ? _VocabularyFront(
                                  vocabulary: card.displayText,
                                  showVocabulary: ref.watch(
                                    favoriteReviewSettingsProvider.select(
                                      (settings) =>
                                          settings.showVocabularyOnFront,
                                    ),
                                  ),
                                  playbackState: state.wordPlaybackState,
                                  hasError: state.mediaError != null,
                                  onReplay: () =>
                                      unawaited(player.replayCurrent()),
                                  onReveal: () =>
                                      unawaited(player.revealBack()),
                                )
                              : _VocabularyBack(
                                  key: ValueKey(card.dbKey),
                                  card: card,
                                  preview: state.preview,
                                  showNextReviewTime: ref.watch(
                                    favoriteReviewSettingsProvider.select(
                                      (settings) => settings.showNextReviewTime,
                                    ),
                                  ),
                                  autoShowAiLookup: ref.watch(
                                    favoriteReviewSettingsProvider.select(
                                      (settings) => settings.autoShowAiLookup,
                                    ),
                                  ),
                                  isSubmitting: state.isSubmittingRating,
                                  isRemoving: state.isRemoving,
                                  onRating: (rating) =>
                                      unawaited(player.selectRating(rating)),
                                  onRemove: () => unawaited(_removeCurrent()),
                                ),
                        ),
                        ReviewStatusBar(
                          key: const Key(
                            'favorite-vocabulary-review-status-bar',
                          ),
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
  const _ReviewProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.m,
        0,
      ),
      child: LinearProgressIndicator(
        key: const Key('favorite-vocabulary-review-progress'),
        value: progress,
        minHeight: 3,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _VocabularyFront extends StatelessWidget {
  const _VocabularyFront({
    required this.vocabulary,
    required this.showVocabulary,
    required this.playbackState,
    required this.hasError,
    required this.onReplay,
    required this.onReveal,
  });

  final String vocabulary;
  final bool showVocabulary;
  final FavoriteVocabularyReviewPlaybackState playbackState;
  final bool hasError;
  final VoidCallback onReplay;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isPlaybackActive =
        playbackState == FavoriteVocabularyReviewPlaybackState.loading ||
        playbackState == FavoriteVocabularyReviewPlaybackState.playing;
    final status = switch (playbackState) {
      FavoriteVocabularyReviewPlaybackState.loading =>
        l10n.favoriteVocabularyReviewLoadingAudio,
      FavoriteVocabularyReviewPlaybackState.playing =>
        l10n.favoriteVocabularyReviewPlaying,
      FavoriteVocabularyReviewPlaybackState.failed =>
        l10n.favoriteVocabularyReviewTapRetry,
      FavoriteVocabularyReviewPlaybackState.idle =>
        l10n.favoriteVocabularyReviewTapReplay,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.xs,
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
                    key: const Key('favorite-vocabulary-review-listen-zone'),
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.42,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onReplay,
                      child: SizedBox.expand(
                        child: _CenteredPrompt(
                          vocabulary: showVocabulary ? vocabulary : null,
                          icon: hasError
                              ? Icons.refresh_rounded
                              : Icons.volume_up_rounded,
                          title: status,
                          body: hasError
                              ? l10n.favoriteVocabularyReviewAudioSkipped
                              : '',
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
                    key: const Key('favorite-vocabulary-review-reveal-zone'),
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onReveal,
                      child: SizedBox.expand(
                        child: _CenteredPrompt(
                          icon: Icons.visibility_outlined,
                          title: l10n.favoriteVocabularyReviewReadyTitle,
                          body: l10n.favoriteVocabularyReviewRevealHint,
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
    this.vocabulary,
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
  final String? vocabulary;
  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final visibleVocabulary = vocabulary?.trim();
    return LayoutBuilder(
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
              if (visibleVocabulary != null &&
                  visibleVocabulary.isNotEmpty) ...[
                Text(
                  visibleVocabulary,
                  key: const Key('favorite-vocabulary-review-front-word'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
              ],
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
              if (body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 收藏词汇复习背面：标题内联播放入口，下方展示词典、来源句和 AI 内容。
class _VocabularyBack extends ConsumerStatefulWidget {
  const _VocabularyBack({
    super.key,
    required this.card,
    required this.preview,
    required this.showNextReviewTime,
    required this.autoShowAiLookup,
    required this.isSubmitting,
    required this.isRemoving,
    required this.onRating,
    required this.onRemove,
  });

  final FlashcardItem card;
  final MemoryRatingPreviewSet? preview;
  final bool showNextReviewTime;
  final bool autoShowAiLookup;
  final bool isSubmitting;
  final bool isRemoving;
  final ValueChanged<MemoryRating> onRating;
  final VoidCallback onRemove;

  @override
  ConsumerState<_VocabularyBack> createState() => _VocabularyBackState();
}

class _VocabularyBackState extends ConsumerState<_VocabularyBack> {
  late bool _showAi = widget.autoShowAiLookup;
  int _lastPrewarmConfigurationVersion = -1;
  TtsController? _ttsController;

  @override
  void didUpdateWidget(covariant _VocabularyBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoShowAiLookup != widget.autoShowAiLookup) {
      if (!widget.autoShowAiLookup) {
        _ttsController?.cancelTextsPrewarm();
      }
      _showAi = widget.autoShowAiLookup;
    }
  }

  bool get _isSingleWord =>
      !widget.card.displayText.trim().contains(RegExp(r'\s')) &&
      widget.card is FlashcardWordItem;

  Future<void> _toggleSourcePlayback() async {
    await ref
        .read(favoriteVocabularyReviewProvider.notifier)
        .toggleSourcePlayback();
  }

  /// 显式登录按钮直接打开登录页；认证完成后当前 AI 查词会自动续跑。
  void _openAiSignInPage() {
    openSignInPage(context);
  }

  /// 将当前 AI 查词结果中的可发音文本提交到统一 TTS 后台缓存。
  ///
  /// 结果可能在 build 前已从缓存返回，也可能在 AI 流式请求中逐帧到达，
  /// 因此调用方同时覆盖当前值和 provider 后续变化。文本去重及取消由
  /// [TtsController] 统一处理，页面只负责当前卡片生命周期。
  void _scheduleAiPrewarm(DictionaryLookupState lookup) {
    final current = lookup.current;
    final result = switch (current) {
      LookupStreaming(:final result) => result,
      LookupLoaded(:final result) => result,
      _ => null,
    };
    if (result == null) return;

    final hasLocalClip =
        _isSingleWord &&
        ref
            .read(pronunciationClipsProvider(widget.card.displayText))
            .isNotEmpty;
    final texts = dictionaryPrewarmTexts(result, hasLocalClip: hasLocalClip);
    if (texts.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ttsControllerProvider.notifier).prewarmTextsIncremental(texts);
    });
  }

  @override
  void dispose() {
    // 卡片翻面、切卡或离开页面时，停止旧 AI 结果的后台合成。
    _ttsController?.cancelTextsPrewarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final card = widget.card;
    final pronunciationClips = _isSingleWord
        ? ref.watch(pronunciationClipsProvider(card.displayText))
        : const [];
    final sourcePlaybackState = ref.watch(
      favoriteVocabularyReviewProvider.select(
        (state) => state.sourcePlaybackState,
      ),
    );
    final wordPlaybackState = ref.watch(
      favoriteVocabularyReviewProvider.select(
        (state) => state.wordPlaybackState,
      ),
    );
    final isWordPlaying =
        wordPlaybackState == FavoriteVocabularyReviewPlaybackState.loading ||
        wordPlaybackState == FavoriteVocabularyReviewPlaybackState.playing;
    final sourceSentenceText = card.sentenceText?.trim();
    final hasSourceSentence =
        sourceSentenceText != null && sourceSentenceText.isNotEmpty;
    final isSourcePlaying =
        sourcePlaybackState == FavoriteVocabularyReviewPlaybackState.loading ||
        sourcePlaybackState == FavoriteVocabularyReviewPlaybackState.playing;
    final aiLookup = _showAi
        ? ref.watch(
            dictionaryLookupControllerProvider(
              card.displayText,
              preferredSourceId: 'ai',
            ),
          )
        : null;
    // AI 折叠时不创建 TTS 控制器，保持默认关闭开关下的原有惰性行为。
    _ttsController = _showAi ? ref.read(ttsControllerProvider.notifier) : null;
    final aiLookupProvider = dictionaryLookupControllerProvider(
      card.displayText,
      preferredSourceId: 'ai',
    );
    if (_showAi) {
      ref.listen<DictionaryLookupState>(aiLookupProvider, (previous, next) {
        _scheduleAiPrewarm(next);
      });
      ref.listen<int>(
        ttsControllerProvider.select((state) => state.configurationVersion),
        (previous, next) {
          if (previous == next || next == _lastPrewarmConfigurationVersion) {
            return;
          }
          _lastPrewarmConfigurationVersion = next;
          _scheduleAiPrewarm(ref.read(aiLookupProvider));
        },
      );
      // provider 可能在 widget 建立前已完成，显式处理当前缓存结果。
    }
    if (aiLookup != null) {
      _scheduleAiPrewarm(aiLookup);
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.m,
              AppSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _VocabularyPlaybackAction(
                          vocabulary: card.displayText,
                          showPlaybackIcon: pronunciationClips.length <= 1,
                          isPlaying: isWordPlaying,
                          onReplay: () => unawaited(
                            ref
                                .read(favoriteVocabularyReviewProvider.notifier)
                                .replayCurrent(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    _VocabularyUnsaveAction(
                      isRemoving: widget.isRemoving,
                      onRemove: widget.onRemove,
                    ),
                  ],
                ),
                if (_isSingleWord) ...[
                  const SizedBox(height: AppSpacing.s),
                  _LocalDictionarySection(word: card.displayText),
                ],
                if (sourceSentenceText != null &&
                    sourceSentenceText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  _SourceSentenceCard(
                    sentenceText: sourceSentenceText,
                    audioItemId: card.audioItemId,
                    sentenceIndex: card.sentenceIndex,
                    sentenceStartMs: card.sentenceStartMs,
                    sentenceEndMs: card.sentenceEndMs,
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                _AiLookupToggle(
                  key: const Key('favorite-vocabulary-review-ai-toggle'),
                  expanded: _showAi,
                  onTap: () {
                    if (_showAi) {
                      _ttsController?.cancelTextsPrewarm();
                    }
                    setState(() => _showAi = !_showAi);
                  },
                ),
                if (_showAi) ...[
                  const SizedBox(height: AppSpacing.s),
                  AiDictResultView(
                    state: aiLookup?.current,
                    onRetry: () => ref
                        .read(
                          dictionaryLookupControllerProvider(
                            card.displayText,
                            preferredSourceId: 'ai',
                          ).notifier,
                        )
                        .retry(),
                    onSignIn: _openAiSignInPage,
                    onUpgrade: () => unawaited(openPaywall(context, ref)),
                  ),
                ],
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
              if (hasSourceSentence) ...[
                SizedBox(
                  key: const Key('favorite-vocabulary-review-source-playback'),
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.tonalIcon(
                    key: const Key(
                      'favorite-vocabulary-review-source-playback-toggle',
                    ),
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _toggleSourcePlayback,
                    icon: Icon(
                      isSourcePlaying
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      color: isSourcePlaying
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      isSourcePlaying
                          ? l10n.stopPlayback
                          : l10n.bookmarkReviewPlayOriginal,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
              ],
              FlashcardRatingActionBar(
                key: const Key('favorite-vocabulary-review-rating-bar'),
                actions: [
                  FlashcardRatingAction(
                    rating: MemoryRating.again,
                    emoji: '😕',
                    label: l10n.bookmarkReviewRatingAgain,
                    detail: formatNextReviewTimeDetail(
                      context,
                      showNextReviewTime: widget.showNextReviewTime,
                      interval: widget.preview?.again.interval,
                    ),
                  ),
                  FlashcardRatingAction(
                    rating: MemoryRating.good,
                    emoji: '🙂',
                    label: l10n.bookmarkReviewRatingGood,
                    detail: formatNextReviewTimeDetail(
                      context,
                      showNextReviewTime: widget.showNextReviewTime,
                      interval: widget.preview?.good.interval,
                    ),
                  ),
                  FlashcardRatingAction(
                    rating: MemoryRating.easy,
                    emoji: '😎',
                    label: l10n.bookmarkReviewRatingEasy,
                    detail: formatNextReviewTimeDetail(
                      context,
                      showNextReviewTime: widget.showNextReviewTime,
                      interval: widget.preview?.easy.interval,
                    ),
                  ),
                ],
                enabled: widget.preview != null && !widget.isSubmitting,
                onSelected: (action) => widget.onRating(action.rating),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 来源句卡片：把可播放句子与学习语境标签组合成一个明确的内容入口。
class _SourceSentenceCard extends StatelessWidget {
  const _SourceSentenceCard({
    required this.sentenceText,
    required this.audioItemId,
    required this.sentenceIndex,
    required this.sentenceStartMs,
    required this.sentenceEndMs,
  });

  final String sentenceText;
  final String? audioItemId;
  final int? sentenceIndex;
  final int? sentenceStartMs;
  final int? sentenceEndMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const Key('favorite-vocabulary-review-source'),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s, 8, AppSpacing.s, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableSentenceText(
              text: sentenceText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
              origin: DictionaryLookupOrigin(
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
              ),
            ),
            if (audioItemId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _SourceMaterialLink(audioItemId: audioItemId!),
            ],
          ],
        ),
      ),
    );
  }
}

/// AI 查词主入口：以整行卡片表达可展开内容，而不是普通次级按钮。
class _AiLookupToggle extends StatelessWidget {
  const _AiLookupToggle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      toggled: expanded,
      label: expanded ? '收起 AI 查词' : '显示 AI 查词',
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 9,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 查词',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.chevron_right_rounded,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 将词汇标题和发音入口合并为一个播放区域，避免误触取消收藏。
class _VocabularyPlaybackAction extends StatelessWidget {
  const _VocabularyPlaybackAction({
    required this.vocabulary,
    required this.showPlaybackIcon,
    required this.isPlaying,
    required this.onReplay,
  });

  final String vocabulary;
  final bool showPlaybackIcon;
  final bool isPlaying;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 多发音 badge 已提供逐条播放，标题行不再重复提供总播放入口。
    final word = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: vocabulary),
          if (showPlaybackIcon)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s),
                child: Icon(
                  key: const Key('favorite-vocabulary-review-word-speak'),
                  Icons.volume_up_outlined,
                  color: isPlaying
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      key: const Key('favorite-vocabulary-review-back-word'),
      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
      softWrap: true,
    );
    if (!showPlaybackIcon) return word;

    return Semantics(
      key: const Key('favorite-vocabulary-review-word-playback'),
      button: true,
      label: AppLocalizations.of(context)!.pronunciationPlay,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onReplay,
          borderRadius: BorderRadius.circular(8),
          child: word,
        ),
      ),
    );
  }
}

/// 收藏词汇背面标题行的轻量取消收藏操作，语义与收藏句复习保持一致。
class _VocabularyUnsaveAction extends StatelessWidget {
  const _VocabularyUnsaveAction({
    required this.isRemoving,
    required this.onRemove,
  });

  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      key: const Key('favorite-vocabulary-review-unsave'),
      button: true,
      enabled: !isRemoving,
      label: l10n.bookmarkReviewUnsave,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRemoving ? null : onRemove,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s,
              AppSpacing.s,
              0,
              AppSpacing.s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.bookmarkReviewUnsave,
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
  }
}

/// 单词背面直接查询本地源，不继承查词面板的默认源与会话偏好。
class _LocalDictionarySection extends ConsumerStatefulWidget {
  const _LocalDictionarySection({required this.word});

  final String word;

  @override
  ConsumerState<_LocalDictionarySection> createState() =>
      _LocalDictionarySectionState();
}

class _LocalDictionarySectionState
    extends ConsumerState<_LocalDictionarySection> {
  late Future<DictionaryLookupResult?> _lookup = _startLookup();

  Future<DictionaryLookupResult?> _startLookup() => ref
      .read(localDictionarySourceProvider)
      .lookup(DictionaryLookupRequest(word: widget.word));

  @override
  void didUpdateWidget(_LocalDictionarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word) _lookup = _startLookup();
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(pronunciationClipsProvider(widget.word));
    return FutureBuilder<DictionaryLookupResult?>(
      future: _lookup,
      builder: (context, snapshot) {
        if (snapshot.data case final LocalDictResult result) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (clips.length > 1) ...[
                PronunciationBadgeGroup(
                  clips: clips,
                  fallbackText: widget.word,
                ),
                const SizedBox(height: AppSpacing.s),
              ],
              LocalDictResultView(
                state: LookupLoaded(result),
                word: widget.word,
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// 来源材料入口只读取标题；播放仍由来源句统一播放编排负责。
class _SourceMaterialLink extends ConsumerWidget {
  const _SourceMaterialLink({required this.audioItemId});

  final String audioItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
    future: ref.read(audioItemDaoProvider).getById(audioItemId),
    builder: (context, snapshot) {
      final title = snapshot.data?.name ?? '来源材料';
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Semantics(
        button: true,
        label: '打开来源材料 $title',
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('favorite-vocabulary-review-source-material'),
              onTap: () =>
                  context.push(AppRoutes.audioLearningPlan(audioItemId)),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        l10n.bookmarkReviewFromAudio(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

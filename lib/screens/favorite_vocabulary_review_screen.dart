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
import '../features/rating_prompt/rating_prompt_providers.dart';
import '../providers/learning_session/favorite_vocabulary_review_provider.dart';
import '../providers/favorite_review_settings_provider.dart';
import '../providers/dictionary/lookup_controller.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../providers/pronunciation/pronunciation_providers.dart';
import '../providers/tts/tts_controller_provider.dart';
import '../models/dictionary/dictionary_entry.dart';
import '../models/dictionary/dictionary_lookup_result.dart';
import '../models/dictionary/dict_speakable_texts.dart';
import '../models/flashcard_item.dart';
import '../router/app_router.dart';
import '../widgets/dictionary/ai_dict_result_view.dart';
import '../widgets/dictionary/local_dict_result_view.dart';
import '../widgets/dictionary/subtitle_text_scale.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../services/app_logger.dart';
import '../services/dictionary/ai_dictionary_source.dart';
import '../services/dictionary/dictionary_source.dart';
import '../services/dictionary/local_dictionary_source.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import '../widgets/favorites/ai_lookup_toggle.dart';
import '../widgets/favorites/source_sentence_card.dart';
import '../widgets/review/review_status_bar.dart';
import '../widgets/review/review_completion_summary.dart';
import '../widgets/review/review_front_layout.dart';
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

  /// 当前卡的预热所有者：离开该卡（评分进入下一张、离开页面）时整体取消其例句预热。
  Object? _cardPrewarmOwner;

  /// [_cardPrewarmOwner] 对应卡片的标识，用于判断卡片是否已切换。
  String? _cardPrewarmKey;

  /// 当前卡的 AI 查词订阅。订阅期间查询由页面持有；关闭订阅即释放查询，未完成的请求随之取消。
  ProviderSubscription<DictionaryLookupState>? _aiLookupSubscription;

  /// [_aiLookupSubscription] 订阅的词，避免同一张卡重复订阅。
  String? _aiLookupWord;

  /// 页面级 TTS 控制器，dispose 时直接取消本页的预热，不再依赖 ref。
  late final TtsController _ttsController;

  @override
  void initState() {
    super.initState();
    _review = ref.read(favoriteVocabularyReviewProvider.notifier);
    _ttsController = ref.read(ttsControllerProvider.notifier);
    // 只有显式完成摘要才代表本次复习正常结束，中途退出不记为任务完成。
    ref.listenManual(
      favoriteVocabularyReviewProvider.select(
        (state) => state.completionSummary,
      ),
      (_, next) {
        if (next == null) return;
        unawaited(
          recordRatingTaskCompletion(
            () => ref.read(ratingPromptTaskCompletionStoreProvider),
          ),
        );
      },
    );
    ref.listenManual(
      favoriteVocabularyReviewProvider.select(
        (state) => (state.currentCard, state.upcomingCards),
      ),
      (_, _) => _syncReviewPrewarms(),
    );
    ref.listenManual(
      favoriteReviewSettingsProvider.select(
        (settings) => settings.autoShowAiLookup,
      ),
      (_, _) => _syncReviewPrewarms(),
    );
    ref.listenManual(
      ttsControllerProvider.select((state) => state.configurationVersion),
      // TTS 配置落定或变化后，TTS 层已清空本页的去重记录，需按新配置重新提交。
      (_, _) => _syncReviewPrewarms(),
    );
    _syncReviewPrewarms();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_review.startCurrentCard());
      }
    });
  }

  /// 同步复习页的预热：单词发音按窗口（当前卡与后续两张）同步；
  /// 当前卡的 AI 查词与例句随卡片生命周期，卡片切换时结束上一张的预热。
  void _syncReviewPrewarms() {
    // 退出或已销毁后，会话收尾引起的状态变化不能再发起预热。
    if (!mounted || _isExiting) return;
    final state = ref.read(favoriteVocabularyReviewProvider);
    final currentCard = state.completionSummary == null
        ? state.currentCard
        : null;
    _syncCardPrewarmOwner(currentCard);
    _syncWordAudioPrewarms();
    _syncAiLookupSubscription(currentCard);
  }

  /// 单词发音预热覆盖当前卡与后续卡，与「自动显示 AI 查词」无关。
  ///
  /// 重复调用安全：已提交的文本由 TtsController 按所有者去重，不会重复合成。
  /// 只在页面内预热，离开页面时由 [dispose] 统一取消。
  void _syncWordAudioPrewarms() {
    final state = ref.read(favoriteVocabularyReviewProvider);
    if (state.completionSummary != null) return;
    final currentCard = state.currentCard;
    final words = {
      if (currentCard != null) currentCard.displayText,
      for (final card in state.upcomingCards) card.displayText,
    };
    final playback = ref.read(textPlaybackProvider.notifier);
    for (final word in words) {
      unawaited(playback.prewarmWord(word, owner: this));
    }
  }

  /// 卡片变化时结束上一张的预热，并为新卡创建所有者。
  ///
  /// 取消上一张的例句 TTS 预热与 AI 查词订阅；翻面不改变卡片，因此翻面不会取消预热。
  void _syncCardPrewarmOwner(FlashcardItem? card) {
    final key = card?.dbKey;
    if (key == _cardPrewarmKey) return;
    _cancelCardPrewarms();
    _cardPrewarmKey = key;
    _cardPrewarmOwner = card == null ? null : Object();
  }

  /// 当前卡的 AI 查词：开启「自动显示 AI 查词」时在正面即开始查询，加载成功后预热例句。
  ///
  /// 只订阅当前卡，不提前查询后续卡；关闭开关或切到下一张时关闭订阅。
  void _syncAiLookupSubscription(FlashcardItem? card) {
    final isAutoShowEnabled = ref
        .read(favoriteReviewSettingsProvider)
        .autoShowAiLookup;
    final owner = _cardPrewarmOwner;
    if (!isAutoShowEnabled || card == null || owner == null) {
      _closeAiLookupSubscription();
      return;
    }
    final word = card.displayText;
    if (_aiLookupSubscription != null && _aiLookupWord == word) return;
    _closeAiLookupSubscription();
    _aiLookupWord = word;
    final provider = dictionaryLookupControllerProvider(
      word,
      preferredSourceId: AiDictionarySource.sourceId,
    );
    _aiLookupSubscription = ref.listenManual(provider, (_, next) {
      _prewarmLoadedAiLookup(context, ref, owner, next);
    });
    // listenManual 不回放已完成的结果（如来自缓存），需主动处理当前值。
    _prewarmLoadedAiLookup(context, ref, owner, ref.read(provider));
  }

  void _closeAiLookupSubscription() {
    _aiLookupSubscription?.close();
    _aiLookupSubscription = null;
    _aiLookupWord = null;
  }

  /// 离开复习页时停止全部后台预热：单词窗口与当前卡的例句 TTS，以及当前卡的 AI 查词。
  /// 不影响正在播放的音频。
  void _stopPrewarms() {
    _ttsController.cancelTextsPrewarm(owner: this);
    _cancelCardPrewarms();
  }

  /// 结束当前卡的全部预热：取消例句 TTS 并关闭 AI 查词订阅。
  void _cancelCardPrewarms() {
    _closeAiLookupSubscription();
    final owner = _cardPrewarmOwner;
    if (owner != null) {
      _ttsController.cancelTextsPrewarm(owner: owner);
    }
    _cardPrewarmOwner = null;
    _cardPrewarmKey = null;
  }

  /// 页面生命周期内只启动一次会话收尾，避免返回回调与 dispose 兜底重复刷统计。
  Future<void> _disposeSessionOnce() =>
      _disposeSessionFuture ??= _review.disposeSession();

  @override
  void dispose() {
    _stopPrewarms();
    // 外部路由替换不会经过页面返回按钮，销毁时后台启动同一幂等收尾。
    scheduleMicrotask(() => unawaited(_disposeSessionOnce()));
    super.dispose();
  }

  Future<void> _exit() async {
    if (_isExiting) return;
    _isExiting = true;
    _stopPrewarms();
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
              // 系统返回手势已完成：立即停止预热，再释放本次复习会话但不要再次触发 pop。
              _stopPrewarms();
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
                    // 收藏不存编号：打开对话时按来源句区间定位，不依赖页面异步现算结果。
                    sentenceStartMs: card?.sentenceStartMs,
                    sentenceEndMs: card?.sentenceEndMs,
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
                    // 宽屏下整页（进度条、卡面、评分栏、状态栏）限宽居中，避免正文与评分按钮被拉满整窗。
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          children: [
                            _ReviewProgress(progress: state.progress),
                            Expanded(
                              child:
                                  state.face ==
                                      FavoriteVocabularyReviewFace.front
                                  ? _VocabularyFront(
                                      vocabulary: card.displayText,
                                      showVocabulary: ref.watch(
                                        favoriteReviewSettingsProvider.select(
                                          (settings) =>
                                              settings.showVocabularyOnFront,
                                        ),
                                      ),
                                      showWordDefinition:
                                          _isSingleWordCard(card) &&
                                          ref.watch(
                                            favoriteReviewSettingsProvider
                                                .select(
                                                  (settings) => settings
                                                      .showWordDefinitionOnFront,
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
                                      prewarmOwner: _cardPrewarmOwner ?? this,
                                      card: card,
                                      preview: state.preview,
                                      showNextReviewTime: ref.watch(
                                        favoriteReviewSettingsProvider.select(
                                          (settings) =>
                                              settings.showNextReviewTime,
                                        ),
                                      ),
                                      autoShowAiLookup: ref.watch(
                                        favoriteReviewSettingsProvider.select(
                                          (settings) =>
                                              settings.autoShowAiLookup,
                                        ),
                                      ),
                                      isSubmitting: state.isSubmittingRating,
                                      isRemoving: state.isRemoving,
                                      onRating: (rating) => unawaited(
                                        player.selectRating(rating),
                                      ),
                                      onRemove: () =>
                                          unawaited(_removeCurrent()),
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
                                  Localizations.localeOf(context)
                                          .languageCode ==
                                      'zh'
                                  ? '学习时长'
                                  : 'Study time',
                              reviewedLabel:
                                  Localizations.localeOf(context)
                                          .languageCode ==
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

/// 收藏卡是否为单词（非词组）。词组判定与背面 AI 查词一致：文本含空白即为词组。
bool _isSingleWordCard(FlashcardItem card) =>
    card is FlashcardWordItem &&
    !card.displayText.trim().contains(RegExp(r'\s'));

class _VocabularyFront extends StatelessWidget {
  const _VocabularyFront({
    required this.vocabulary,
    required this.showVocabulary,
    required this.showWordDefinition,
    required this.playbackState,
    required this.hasError,
    required this.onReplay,
    required this.onReveal,
  });

  final String vocabulary;
  final bool showVocabulary;
  final bool showWordDefinition;
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
    final visibleVocabulary = showVocabulary ? vocabulary.trim() : '';
    final hasVisibleVocabulary = visibleVocabulary.isNotEmpty;
    return ReviewFrontLayout(
      listenZoneKey: const Key('favorite-vocabulary-review-listen-zone'),
      revealZoneKey: const Key('favorite-vocabulary-review-reveal-zone'),
      revealLabel: l10n.favoriteVocabularyReviewReadyTitle,
      onReplay: onReplay,
      onReveal: onReveal,
      listenContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasVisibleVocabulary) ...[
            Text(
              visibleVocabulary,
              key: const Key('favorite-vocabulary-review-front-word'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
          if (showWordDefinition)
            _FrontWordDefinition(
              word: vocabulary,
              // 单词隐藏时释义就是要回忆的主体，用主文字层级展示。
              isProminent: !hasVisibleVocabulary,
            ),
          if (hasVisibleVocabulary || showWordDefinition)
            const SizedBox(height: AppSpacing.m),
          ReviewPlaybackPrompt(
            icon: hasError ? Icons.refresh_rounded : Icons.volume_up_rounded,
            tone: hasError
                ? ReviewPlaybackTone.error
                : isPlaybackActive
                ? ReviewPlaybackTone.active
                : ReviewPlaybackTone.idle,
            status: status,
            detail: hasError ? l10n.favoriteVocabularyReviewAudioSkipped : null,
          ),
        ],
      ),
    );
  }
}

/// 收藏单词正面的释义，按顺序取：基础在线词典（本地缓存 → API），未查到时只读 AI 查词缓存。
/// AI 只读缓存未命中也不发起请求；两者都没有则不占位，释义只是辅助信息，不阻断复习。
class _FrontWordDefinition extends ConsumerWidget {
  const _FrontWordDefinition({required this.word, required this.isProminent});

  final String word;
  final bool isProminent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(
      dictionaryLookupControllerProvider(
        word,
        preferredSourceId: LocalDictionarySource.sourceId,
      ),
    );
    final current = lookup.current;
    if (current is LookupLoaded) {
      final translation = _basicTranslation(current.result);
      return translation == null
          ? const SizedBox.shrink()
          : _DefinitionText(translation, isProminent: isProminent);
    }
    if (current is LookupNotFound || current is LookupError) {
      // 按词区分 State：卡片切换时复用同一 State 会沿用上一张词的缓存结果。
      return _AiCachedDefinition(
        key: ValueKey(word),
        word: word,
        isProminent: isProminent,
      );
    }
    return const SizedBox.shrink();
  }
}

/// 基础词典的中文释义（每个义项一行，原样展示）。
String? _basicTranslation(DictionaryLookupResult result) {
  if (result is! LocalDictResult) return null;
  final translation = result.entry.translation?.trim();
  return translation == null || translation.isEmpty ? null : translation;
}

/// 读取 AI 查词的本地缓存（只读，绝不请求 AI）并取第一项释义。
class _AiCachedDefinition extends ConsumerStatefulWidget {
  const _AiCachedDefinition({
    super.key,
    required this.word,
    required this.isProminent,
  });

  final String word;
  final bool isProminent;

  @override
  ConsumerState<_AiCachedDefinition> createState() =>
      _AiCachedDefinitionState();
}

class _AiCachedDefinitionState extends ConsumerState<_AiCachedDefinition> {
  late final Future<String?> _definition = _readDefinition();

  Future<String?> _readDefinition() async {
    final entry = await ref
        .read(aiDictionarySourceProvider)
        .readCachedEntry(
          widget.word,
          targetLanguage: ref
              .read(dictionaryLookupContextProvider)
              .targetLanguage,
        );
    return _aiFirstMeaningText(entry);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _definition,
      builder: (context, snapshot) {
        final definition = snapshot.data;
        return definition == null
            ? const SizedBox.shrink()
            : _DefinitionText(definition, isProminent: widget.isProminent);
      },
    );
  }
}

/// AI 单词结果的第一项释义：词性 + 目标语言对译，无对译时回退英文释义。
String? _aiFirstMeaningText(AiDictionaryEntry? entry) {
  if (entry is! DictionaryEntry || entry.meanings.isEmpty) return null;
  final meaning = entry.meanings.first;
  final gloss = meaning.translation.isNotEmpty
      ? meaning.translation.join('；')
      : meaning.definition;
  final text = [
    meaning.partOfSpeech,
    gloss,
  ].where((part) => part.trim().isNotEmpty).join(' ');
  return text.isEmpty ? null : text;
}

/// 正面释义文本。单词隐藏时作为主内容放大加深，单词可见时作为辅助说明弱化。
class _DefinitionText extends StatelessWidget {
  const _DefinitionText(this.text, {required this.isProminent});

  final String text;
  final bool isProminent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      key: const Key('favorite-vocabulary-review-front-definition'),
      textAlign: TextAlign.center,
      style: isProminent
          ? theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.4,
            )
          : theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
    );
  }
}

/// AI 查词结果加载成功后预热其中的发音：标题走 CDN 优先，例句进入 TTS 后台预热。
///
/// 在下一帧提交，避免在 build 或 provider 通知期间修改 TTS 状态；页面已销毁时跳过，
/// 保证离开页面后不再产生新的预热。同一结果可重复调用，文本去重由 TtsController 按 [owner] 处理。
void _prewarmLoadedAiLookup(
  BuildContext context,
  WidgetRef ref,
  Object owner,
  DictionaryLookupState lookup,
) {
  final current = lookup.current;
  if (current is! LookupLoaded) return;
  final result = current.result;
  final texts = dictionaryPrewarmTexts(result);
  final playback = ref.read(textPlaybackProvider.notifier);
  final tts = ref.read(ttsControllerProvider.notifier);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    unawaited(playback.prewarmWord(result.headword, owner: owner));
    if (texts.isEmpty) return;
    unawaited(tts.prewarmTextsIncremental(texts, owner: owner));
  });
}

/// 收藏词汇复习背面：标题内联播放入口，下方展示词典、来源句和 AI 内容。
class _VocabularyBack extends ConsumerStatefulWidget {
  const _VocabularyBack({
    super.key,
    required this.prewarmOwner,
    required this.card,
    required this.preview,
    required this.showNextReviewTime,
    required this.autoShowAiLookup,
    required this.isSubmitting,
    required this.isRemoving,
    required this.onRating,
    required this.onRemove,
  });

  /// 复习页的预热所有者：离开复习页时由页面统一取消背面的例句预热。
  final Object prewarmOwner;
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

  @override
  void didUpdateWidget(covariant _VocabularyBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoShowAiLookup != widget.autoShowAiLookup) {
      _showAi = widget.autoShowAiLookup;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_showAi) _logAiLookupReadiness();
  }

  /// 翻到背面时记录 AI 查词是否已由预热就绪：loaded 为预期；streaming 说明预热未完成
  /// 但已复用同一请求；notPrewarmed 说明预热窗口未覆盖该卡，属于异常。
  void _logAiLookupReadiness() {
    final word = widget.card.displayText;
    final provider = dictionaryLookupControllerProvider(
      word,
      preferredSourceId: AiDictionarySource.sourceId,
    );
    final status = ref.exists(provider)
        ? switch (ref.read(provider).current) {
            LookupLoaded() => 'loaded',
            LookupStreaming() => 'streaming',
            LookupLoading() || null => 'loading',
            final other => other.runtimeType.toString(),
          }
        : 'notPrewarmed';
    AppLogger.log(
      'FavoriteVocabularyReview',
      '翻面 AI 查词状态 word=$word status=$status',
    );
  }

  Future<void> _toggleSourcePlayback() async {
    await ref
        .read(favoriteVocabularyReviewProvider.notifier)
        .toggleSourcePlayback();
  }

  /// 显式登录按钮直接打开登录页；认证完成后当前 AI 查词会自动续跑。
  void _openAiSignInPage() {
    openSignInPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final card = widget.card;
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
    final aiLookupProvider = dictionaryLookupControllerProvider(
      card.displayText,
      preferredSourceId: 'ai',
    );
    if (_showAi) {
      ref.listen<DictionaryLookupState>(aiLookupProvider, (previous, next) {
        _prewarmLoadedAiLookup(context, ref, widget.prewarmOwner, next);
      });
    }
    // 手动展开时 provider 可能已加载完成，显式处理当前缓存结果。
    if (aiLookup != null) {
      _prewarmLoadedAiLookup(context, ref, widget.prewarmOwner, aiLookup);
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
                if (_isSingleWordCard(widget.card)) ...[
                  const SizedBox(height: AppSpacing.s),
                  _LocalDictionarySection(word: card.displayText),
                ],
                if (sourceSentenceText != null &&
                    sourceSentenceText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.m),
                  SourceSentenceCard(
                    sentenceText: sourceSentenceText,
                    audioItemId: card.audioItemId,
                    sentenceStartMs: card.sentenceStartMs,
                    sentenceEndMs: card.sentenceEndMs,
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                AiLookupToggle(
                  key: const Key('favorite-vocabulary-review-ai-toggle'),
                  expanded: _showAi,
                  onTap: () => setState(() => _showAi = !_showAi),
                ),
                if (_showAi) ...[
                  const SizedBox(height: AppSpacing.s),
                  // AI 查词结果同样随学习内容字号缩放
                  SubtitleTextScale(
                    child: AiDictResultView(
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

/// 将词汇标题和发音入口合并为一个播放区域，避免误触取消收藏。
class _VocabularyPlaybackAction extends StatelessWidget {
  const _VocabularyPlaybackAction({
    required this.vocabulary,
    required this.isPlaying,
    required this.onReplay,
  });

  final String vocabulary;
  final bool isPlaying;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final word = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: vocabulary),
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
    return FutureBuilder<DictionaryLookupResult?>(
      future: _lookup,
      builder: (context, snapshot) {
        if (snapshot.data case final LocalDictResult result) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubtitleTextScale(
                child: LocalDictResultView(
                  state: LookupLoaded(result),
                  word: widget.word,
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

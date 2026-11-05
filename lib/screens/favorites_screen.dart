/// 收藏页面
///
/// 聚合两类核心资产：收藏句子（按音频分组）和收藏单词（按时间倒序）。
/// 通过 SegmentedButton 在句子/单词视图间切换。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../analytics/models/event_names.dart';
import '../features/usage/usage_event.dart';
import '../features/usage/usage_providers.dart';
import '../database/app_database.dart';
import '../database/daos/audio_item_dao.dart';
import '../database/daos/bookmark_dao.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/dict_entry.dart';
import '../models/sentence.dart';
import '../models/word_highlight_binding.dart';
import '../screens/sentence_detail_screen.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/short_audio_player_provider.dart';
import '../providers/tts/tts_controller_provider.dart';
import '../providers/pronunciation/pronunciation_providers.dart';
import '../widgets/tts/speak_button.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/favorite_vocabulary_review_provider.dart';
import '../providers/learning_session/favorite_review_due_count_provider.dart';
import '../providers/favorite_sentence_lifecycle_provider.dart';
import '../providers/new_user_guide_provider.dart';
import '../providers/saved_sense_group_provider.dart';
import '../providers/saved_word_provider.dart';
import '../providers/dictionary/dictionary_registry.dart';
import '../services/app_logger.dart';
import '../services/pronunciation/local_audio_clip_player.dart';
import '../services/pronunciation/local_audio_range_player.dart';
import '../services/pronunciation/source_sentence_player.dart';
import '../services/subtitle_parser.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/favorites/sentence_recycle_bin_sheet.dart';
import '../widgets/favorites/vocabulary_recycle_bin_sheet.dart';
import '../widgets/bookmark_review/bookmark_review_settings_sheet.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/prewarm_visibility.dart';
import '../widgets/guide_flow.dart';

/// 判断 tile 是否真实位于最近滚动视口内；`cacheExtent` 保留的离屏 widget 不预热。
bool _isInScrollableViewport(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final viewport = RenderAbstractViewport.maybeOf(renderObject);
  if (viewport is! RenderBox) return true;
  // RenderAbstractViewport 的公开工厂返回抽象类型；实际滚动视口同时是 RenderBox。
  final viewportBox = viewport as RenderBox;
  if (!viewportBox.hasSize) return true;
  final rect = MatrixUtils.transformRect(
    renderObject.getTransformTo(viewportBox),
    Offset.zero & renderObject.size,
  );
  return (Offset.zero & viewportBox.size).overlaps(rect);
}

/// 收藏页面视图模式
enum _FavoritesView { sentences, words }

/// 收藏页分段控件中的标题与数量 badge。
class _FavoritesSegmentLabel extends StatelessWidget {
  final String title;
  final int? count;
  final Key badgeKey;

  const _FavoritesSegmentLabel({
    required this.title,
    required this.count,
    required this.badgeKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final countValue = count;
    final showCount = countValue != null && countValue > 0;
    if (!showCount) return Text(title, style: textStyle);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: textStyle),
        const SizedBox(width: 6),
        Container(
          key: badgeKey,
          constraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 20,
            maxHeight: 20,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '$countValue',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 收藏页单个分段；使用固定等宽布局，避免标题和 badge 触发 intrinsic 错位。
class _FavoritesSegment extends StatelessWidget {
  final Key segmentKey;
  final GuideStep? guideStep;
  final bool selected;
  final IconData icon;
  final String title;
  final int? count;
  final Key badgeKey;
  final VoidCallback onTap;

  const _FavoritesSegment({
    required this.segmentKey,
    this.guideStep,
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.badgeKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 图标作为辅助信息使用次要色，避免与标题争夺视觉焦点。
    final foregroundColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

    final segment = Material(
      key: segmentKey,
      color: selected ? colorScheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foregroundColor),
                const SizedBox(width: 8),
                _FavoritesSegmentLabel(
                  title: title,
                  count: count,
                  badgeKey: badgeKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: guideStep == null
            ? segment
            : GuideTarget(step: guideStep!, child: segment),
      ),
    );
  }
}

/// 收藏页 AppBar 的更多操作。
enum _FavoritesMoreAction { recycleBin, reviewSettings }

Future<AudioPlaybackResult> _playSourceSentence(
  WidgetRef ref, {
  required String key,
  required String? audioItemId,
  required int? sentenceIndex,
  required String? sentenceText,
  required int? sentenceStartMs,
  required int? sentenceEndMs,
}) {
  AppLogger.log(
    'FavoritesPlayback',
    'source request key=$key text="$sentenceText" audio=$audioItemId',
  );
  final player = SourceSentencePlayer(
    audioItemDao: ref.read(audioItemDaoProvider),
    audioClipPlayer: ref.read(shortAudioPlayerProvider),
    speak: (text, playbackKey) => ref
        .read(ttsControllerProvider.notifier)
        .speakWithResult(text, key: playbackKey),
  );
  return player.play(
    audioItemId: audioItemId,
    sentenceIndex: sentenceIndex,
    sentenceText: sentenceText,
    sentenceStartMs: sentenceStartMs,
    sentenceEndMs: sentenceEndMs,
    playbackKey: key,
  );
}

/// 收藏页面
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  _FavoritesView _currentView = _FavoritesView.sentences;
  late final AppLifecycleListener _lifecycleListener;

  /// 收藏 Tab 新手引导 step key（生命周期内稳定）。
  final GlobalKey _keySentencesTab = GlobalKey();
  final GlobalKey _keyVocabularyTab = GlobalKey();

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        // 应用回到前台时，到期时间可能已跨过当前时刻；重新读取当前入口数量。
        if (state == AppLifecycleState.resumed) {
          refreshFavoriteReviewDueCounts(ref);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// 收藏页重新可见时同时刷新两类入口，避免 StatefulShell 保留旧 Future。
  void _refreshDueCounts() => refreshFavoriteReviewDueCounts(ref);

  /// 打开收藏复习共享设置；收藏页不预展开任一内容分区。
  Future<void> _openReviewSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => BookmarkReviewSettingsSheet(
        task: FavoriteReviewSettingsTask.favorites,
      ),
    );
  }

  /// 打开当前收藏类型对应的回收站，并在返回后刷新待复习数量。
  Future<void> _openRecycleBin() async {
    if (_currentView == _FavoritesView.sentences) {
      await showSentenceRecycleBinSheet(context: context);
    } else {
      await showVocabularyRecycleBinSheet(context: context);
    }
    if (mounted) _refreshDueCounts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isMainTabActive = MainTabVisibilityScope.isVisible(context, 2);

    // 获取收藏数量
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final sentenceCount = bookmarksAsync.value?.length;
    final wordCount = ref.watch(savedWordListProvider).value?.length ?? 0;
    final phraseCount =
        ref.watch(savedSenseGroupListProvider).value?.length ?? 0;
    final vocabCount = wordCount + phraseCount;

    // ----- 新手引导 flow 声明 -----
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tooltipDescColor = isDark
        ? const Color(0xFF9BA3AE)
        : const Color(0xFF5A6270);
    final stepSentencesList = GuideStep(
      key: _keySentencesTab,
      description: l10n.guideFavoritesSentencesListDescription,
      descriptionWidget: Text(
        l10n.guideFavoritesSentencesListDescription,
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          fontWeight: FontWeight.w400,
          color: tooltipDescColor,
        ),
      ),
    );
    final stepWordsList = GuideStep(
      key: _keyVocabularyTab,
      description: l10n.guideFavoritesVocabularyListDescription,
    );

    final flows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.favoritesTabsOverview,
        // 两个目标都是固定存在的 Tab；页面首次可见时连续展示，不依赖收藏数据。
        shouldRun: true,
        steps: [stepSentencesList, stepWordsList],
      ),
    ];

    return GuideFlowSequenceHost(
      flows: flows,
      child: Scaffold(
        appBar: AppBar(
          actionsPadding: const EdgeInsets.only(right: AppSpacing.s),
          title: Text(l10n.favorites),
          actions: [
            IconButton(
              key: const Key('favorites-statistics'),
              icon: SvgPicture.asset(
                'assets/icon/bar-chart.svg',
                width: 21,
                height: 21,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.onSurfaceVariant,
                  BlendMode.srcIn,
                ),
              ),
              tooltip: '复习统计',
              onPressed: () async {
                await context.push<void>(AppRoutes.reviewStatistics);
                if (mounted) _refreshDueCounts();
              },
            ),
            PopupMenuButton<_FavoritesMoreAction>(
              key: const Key('favorites-more'),
              icon: const Icon(Icons.more_horiz),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onSelected: (action) {
                switch (action) {
                  case _FavoritesMoreAction.recycleBin:
                    unawaited(_openRecycleBin());
                  case _FavoritesMoreAction.reviewSettings:
                    unawaited(_openReviewSettings());
                }
              },
              itemBuilder: (context) => [
                appPopupMenuItem(
                  context,
                  value: _FavoritesMoreAction.reviewSettings,
                  icon: const Icon(Icons.tune),
                  label: l10n.bookmarkReviewSettingsTitle,
                ),
                appPopupMenuItem(
                  context,
                  value: _FavoritesMoreAction.recycleBin,
                  icon: const Icon(Icons.restore),
                  label: l10n.recycleBinTitle,
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // SegmentedButton 切换
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: DecoratedBox(
                key: const Key('favorites-segmented-control-shell'),
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        _FavoritesSegment(
                          guideStep: stepSentencesList,
                          segmentKey: const Key('favorites-sentences-segment'),
                          selected: _currentView == _FavoritesView.sentences,
                          icon: Icons.subject,
                          title: l10n.favoritesSentences,
                          count: sentenceCount,
                          badgeKey: const Key('favorites-sentences-count'),
                          onTap: () =>
                              _selectFavoritesView(_FavoritesView.sentences),
                        ),
                        _FavoritesSegment(
                          guideStep: stepWordsList,
                          segmentKey: const Key('favorites-vocabulary-segment'),
                          selected: _currentView == _FavoritesView.words,
                          icon: Icons.menu_book_outlined,
                          title: l10n.favoritesVocabulary,
                          count: vocabCount,
                          badgeKey: const Key('favorites-vocabulary-count'),
                          onTap: () =>
                              _selectFavoritesView(_FavoritesView.words),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 内容区域（Stack：列表 + 底部悬浮按钮）
            Expanded(
              child: Stack(
                children: [
                  // 列表（IndexedStack 保留两个 tab 的状态，切换不重建）
                  IndexedStack(
                    index: _currentView.index,
                    children: [
                      const _SentencesView(),
                      _WordsView(
                        // 仅词汇 tab 激活时才预热（IndexedStack 会同时构建两个 tab，
                        // 不门控则停在句子 tab 也会为词汇起引擎合成、浪费 CPU）。
                        isActive:
                            isMainTabActive &&
                            _currentView == _FavoritesView.words,
                      ),
                    ],
                  ),

                  // 底部悬浮复习按钮
                  if (_currentView == _FavoritesView.sentences)
                    const _FloatingSentenceReviewButton()
                  else if (_currentView == _FavoritesView.words)
                    const _FloatingFlashcardButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换收藏视图并刷新两个入口的待复习数量。
  void _selectFavoritesView(_FavoritesView nextView) {
    if (_currentView == nextView) return;
    debugPrint('[PERF] tab 切换: $nextView');
    final sw = Stopwatch()..start();
    setState(() => _currentView = nextView);
    // IndexedStack 会保留两个 Tab；显式失效避免复用旧 Future 结果。
    _refreshDueCounts();
    debugPrint('[PERF] setState 完成: ${sw.elapsedMilliseconds}ms');
  }
}

// ============================================================
// 句子视图
// ============================================================

/// 句子视图 — 按音频分组展示收藏的书签句子
class _SentencesView extends ConsumerStatefulWidget {
  const _SentencesView();

  @override
  ConsumerState<_SentencesView> createState() => _SentencesViewState();
}

class _SentencesViewState extends ConsumerState<_SentencesView> {
  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);

    return bookmarksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allBookmarks) {
        if (allBookmarks.isEmpty) {
          return _buildEmptyState(context, isSentences: true);
        }

        // 按音频名称分组
        final grouped = <String, List<BookmarkWithAudio>>{};
        for (final item in allBookmarks) {
          (grouped[item.bookmark.audioItemId] ??= []).add(item);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.s,
            AppSpacing.m,
            80, // 底部留出悬浮按钮空间
          ),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final audioId = grouped.keys.elementAt(index);
            final items = grouped[audioId]!;
            final audioName = items.first.audioName;
            final tile = _AudioBookmarkGroup(
              audioId: audioId,
              audioName: audioName,
              bookmarks: items,
            );
            return tile;
          },
        );
      },
    );
  }
}

/// 底部悬浮句子复习按钮
class _FloatingSentenceReviewButton extends ConsumerWidget {
  const _FloatingSentenceReviewButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBookmarks = ref.watch(bookmarkListProvider).value ?? [];
    if (allBookmarks.isEmpty) return const SizedBox.shrink();

    // 过滤掉无效书签（迁移遗留的无时长条目）
    final validBookmarks = allBookmarks.where((b) {
      final duration = b.bookmark.endTime - b.bookmark.startTime;
      return duration > 0 && b.bookmark.sentenceText.isNotEmpty;
    }).toList();
    if (validBookmarks.isEmpty) return const SizedBox.shrink();

    final dueCountAsync = ref.watch(favoriteSentenceDueCountProvider);
    final dueCount = dueCountAsync.value;
    final l10n = AppLocalizations.of(context)!;

    return _FloatingReviewButton(
      leading: dueCount == 0
          ? const Text('🎉', style: TextStyle(fontSize: 18))
          : const Icon(Icons.style_outlined, size: 18),
      // 待复习数量尚未加载时不回退显示总收藏数，避免切换 Tab 时文案闪烁。
      label: dueCount == null
          ? l10n.downloadLoading
          : dueCount == 0
          ? l10n.bookmarkReviewNothingToReview
          : l10n.bookmarkReviewDueCount(dueCount),
      enabled: dueCount != null && dueCount > 0,
      onPressed: () async {
        ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkReviewButtonTapped,
              analyticsParams: {
                EventParams.totalSentencesCount: validBookmarks.length,
              },
            );
        final sw = Stopwatch()..start();
        final provider = ref.read(bookmarkReviewProvider.notifier);
        debugPrint(
          '[PERF] bookmark review read providers: ${sw.elapsedMilliseconds}ms',
        );
        await provider.initialize();
        debugPrint(
          '[PERF] bookmark review initialize: ${sw.elapsedMilliseconds}ms',
        );
        if (!context.mounted) return;
        await context.push<void>(AppRoutes.bookmarkReview);
        if (context.mounted) {
          // 返回收藏页时重新计算，覆盖评分、取消收藏及会话停留期间到期的卡片。
          refreshFavoriteReviewDueCounts(ref);
        }
        debugPrint(
          '[PERF] bookmarkReview returned: ${sw.elapsedMilliseconds}ms',
        );
      },
    );
  }
}

/// 底部悬浮 Flashcard 按钮
class _FloatingFlashcardButton extends ConsumerWidget {
  const _FloatingFlashcardButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedWordsAsync = ref.watch(savedWordListProvider);
    final savedPhrasesAsync = ref.watch(savedSenseGroupListProvider);

    final words = savedWordsAsync.value ?? [];
    final phrases = savedPhrasesAsync.value ?? [];
    final totalCount = words.length + phrases.length;

    if (totalCount == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final dueCountAsync = ref.watch(favoriteVocabularyDueCountProvider);
    final dueCount = dueCountAsync.value;
    return _FloatingReviewButton(
      leading: dueCount == 0
          ? const Text('🎉', style: TextStyle(fontSize: 18))
          : const Icon(Icons.style_outlined, size: 18),
      // 待复习数量尚未加载时不回退显示总收藏数，避免切换 Tab 时文案闪烁。
      label: dueCount == null
          ? l10n.downloadLoading
          : dueCount == 0
          ? l10n.favoriteReviewNothingToReview
          : l10n.favoriteVocabularyReviewDueCount(dueCount),
      enabled: dueCount != null && dueCount > 0,
      onPressed: () async {
        ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.flashcardButtonTapped,
              analyticsParams: {EventParams.totalCards: totalCount},
            );
        await ref.read(favoriteVocabularyReviewProvider.notifier).initialize();
        if (!context.mounted) return;
        await context.push<void>(AppRoutes.favoriteVocabularyReview);
        if (context.mounted) {
          // 返回收藏页时重新计算，避免保留进入复习前的缓存数量。
          refreshFavoriteReviewDueCounts(ref);
        }
      },
    );
  }
}

/// 底部悬浮复习按钮 — 渐变遮罩 + 全宽 FilledButton
class _FloatingReviewButton extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback onPressed;

  final bool enabled;

  const _FloatingReviewButton({
    required this.leading,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 常规字号保持紧凑 36px；放大系统字体时允许按文本自然增高，
    // 避免全局 FilledButton 的垂直内边距把复习文案裁切掉。
    Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 8),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
    final buttonBox = Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: button,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 渐变遮罩
          IgnorePointer(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface.withValues(alpha: 0.0),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          // 按钮区域
          buttonBox,
        ],
      ),
    );
  }
}

/// 单个音频的书签分组卡片
class _AudioBookmarkGroup extends StatelessWidget {
  final String audioId;
  final String audioName;
  final List<BookmarkWithAudio> bookmarks;

  const _AudioBookmarkGroup({
    required this.audioId,
    required this.audioName,
    required this.bookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        collapsedIconColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.4,
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        title: Row(
          children: [
            Expanded(
              child: Text(
                audioName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              l10n.favoritesBookmarkCount(bookmarks.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: [
          for (int i = 0; i < bookmarks.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: AppSpacing.m,
                endIndent: AppSpacing.m,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            _BookmarkSentenceTile(
              bookmark: bookmarks[i].bookmark,
              audioId: audioId,
              audioName: audioName,
              displayNumber: i + 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// 单条书签句子列表项（可展开查看翻译/解析，支持播放和点词查词典）
class _BookmarkSentenceTile extends ConsumerStatefulWidget {
  final Bookmark bookmark;
  final String audioId;
  final String audioName;
  final int displayNumber;

  const _BookmarkSentenceTile({
    required this.bookmark,
    required this.audioId,
    required this.audioName,
    required this.displayNumber,
  });

  @override
  ConsumerState<_BookmarkSentenceTile> createState() =>
      _BookmarkSentenceTileState();
}

class _BookmarkSentenceTileState extends ConsumerState<_BookmarkSentenceTile> {
  /// 播放该句子的原声片段
  Future<void> _playSentence() async {
    final key = 'saved-sentence:${widget.bookmark.id}';
    final player = ref.read(shortAudioPlayerProvider);
    if (player.state.playingKey == key) {
      await player.stop();
      return;
    }
    try {
      final start = Duration(
        milliseconds: (widget.bookmark.startTime * 1000).round(),
      );
      final end = Duration(
        milliseconds: (widget.bookmark.endTime * 1000).round(),
      );
      await LocalAudioRangePlayer(
        audioItemDao: ref.read(audioItemDaoProvider),
        audioClipPlayer: player,
      ).play(
        audioItemId: widget.audioId,
        start: start,
        end: end,
        playbackKey: key,
      );
    } catch (_) {
      // 忽略播放错误（音频文件不存在等）
    }
  }

  /// 跳转到句子详情页（单句精听）
  void _openDetail() {
    final bm = widget.bookmark;
    AppRoutes.pushNested(
      context,
      AppRoutes.sentenceDetailSegment,
      extra: SentenceDetailArgs(
        audioItemId: widget.audioId,
        audioName: widget.audioName,
        sentenceText: bm.sentenceText,
        sentenceIndex: bm.sentenceIndex,
        startTimeMs: (bm.startTime * 1000).round(),
        endTimeMs: (bm.endTime * 1000).round(),
        wordHighlightSource: _audioEngineWordHighlightSource(
          ref,
          widget.audioId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bm = widget.bookmark;

    // 提前捕获统一生命周期服务，避免 Dismissible 销毁 widget 后 ref 失效。
    final sentenceLifecycle = ref.read(favoriteSentenceLifecycleProvider);

    return Dismissible(
      key: ValueKey('bookmark_${bm.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(Icons.bookmark_remove, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        unawaited(sentenceLifecycle.remove(widget.audioId, {bm.sentenceIndex}));
      },
      child: _FavoriteSourceSentenceTile(
        sentenceText: bm.sentenceText,
        displayNumber: widget.displayNumber,
        displayNumberKey: ValueKey('saved-sentence-number-${bm.id}'),
        onPlay: _playSentence,
        onOpenDetail: _openDetail,
      ),
    );
  }
}

/// 收藏句与词汇来源句共用的分段交互行。
///
/// 左侧正文负责来源句试听；右侧整块操作区进入句子讲解页，降低箭头误触。
class _FavoriteSourceSentenceTile extends StatelessWidget {
  final String sentenceText;
  final int? displayNumber;
  final Key? displayNumberKey;
  final VoidCallback onPlay;
  final VoidCallback? onOpenDetail;

  const _FavoriteSourceSentenceTile({
    super.key,
    required this.sentenceText,
    required this.onPlay,
    this.displayNumber,
    this.displayNumberKey,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = displayNumber;
    final canOpenDetail = onOpenDetail != null;
    final leftPadding = number == null ? 0.0 : AppSpacing.s;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: InkWell(
                onTap: onPlay,
                child: Padding(
                  // 无编号的来源句与外层释义、分隔线共用左边界；收藏句保留编号所需的内边距。
                  padding: EdgeInsets.only(
                    left: leftPadding,
                    right: AppSpacing.s,
                    top: 8,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      if (number != null) ...[
                        SizedBox(
                          key: displayNumberKey,
                          width: 24,
                          child: Text(
                            '$number',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          sentenceText,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (canOpenDetail)
              SizedBox(
                key: const Key('favorite-source-sentence-open-action'),
                width: 42,
                child: Material(
                  // 默认保持透明，仅由 InkWell 提供按下、悬停等即时反馈。
                  color: Colors.transparent,
                  child: Semantics(
                    button: true,
                    label: 'Open sentence explanation',
                    child: InkWell(
                      onTap: onOpenDetail,
                      child: Center(
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 解析收藏词汇来源句进入讲解页所需的位置。
///
/// 新数据直接使用持久化的句序和时间；旧数据缺少其中任一字段时，改从当前
/// 材料字幕按句序或文本恢复，避免把错误的时间范围传给讲解页。
Future<void> _openFavoriteSourceSentenceDetail({
  required BuildContext context,
  required WidgetRef ref,
  required String audioItemId,
  required String sentenceText,
  required int? sentenceIndex,
  required int? sentenceStartMs,
  required int? sentenceEndMs,
}) async {
  final audioItemDao = ref.read(audioItemDaoProvider);
  final audio = await audioItemDao.getById(audioItemId);
  if (audio == null) return;

  final storedRangeIsValid =
      sentenceStartMs != null &&
      sentenceEndMs != null &&
      sentenceEndMs - sentenceStartMs >= 200;
  final storedIndexIsValid = sentenceIndex != null && sentenceIndex >= 0;
  final storedLocation = storedRangeIsValid && storedIndexIsValid
      ? (
          sentenceIndex: sentenceIndex,
          startTimeMs: sentenceStartMs,
          endTimeMs: sentenceEndMs,
        )
      : null;
  final location =
      storedLocation ??
      await _resolveSourceSentenceLocation(
        audioItemDao: audioItemDao,
        audioItemId: audioItemId,
        sentenceText: sentenceText,
        preferredSentenceIndex: sentenceIndex,
      );
  if (location == null || !context.mounted) return;

  AppRoutes.pushNested(
    context,
    AppRoutes.sentenceDetailSegment,
    extra: SentenceDetailArgs(
      audioItemId: audioItemId,
      audioName: audio.name,
      sentenceText: sentenceText,
      sentenceIndex: location.sentenceIndex,
      startTimeMs: location.startTimeMs,
      endTimeMs: location.endTimeMs,
      wordHighlightSource: _audioEngineWordHighlightSource(ref, audioItemId),
    ),
  );
}

/// 收藏详情页的句子试听由全局音频引擎播放，因此显式绑定该引擎的时间轴。
WordHighlightSource _audioEngineWordHighlightSource(
  WidgetRef ref,
  String audioItemId,
) {
  final engine = ref.read(audioEngineProvider.notifier);
  return WordHighlightSource(
    audioItemId: audioItemId,
    positionStream: engine.absolutePositionStream,
    currentPosition: engine.absoluteCurrentPosition,
    playbackStatus: engine.wordHighlightPlaybackStatus,
    playbackStatusStream: engine.wordHighlightPlaybackStatusStream,
  );
}

/// 从材料字幕恢复来源句的位置；优先信任仍与文本一致的原句序。
Future<({int sentenceIndex, int startTimeMs, int endTimeMs})?>
_resolveSourceSentenceLocation({
  required AudioItemDao audioItemDao,
  required String audioItemId,
  required String sentenceText,
  required int? preferredSentenceIndex,
}) async {
  final srt = await audioItemDao.getTranscriptSrt(audioItemId);
  if (srt == null || srt.isEmpty) return null;
  final sentences = await SubtitleParser.parseSubtitleString(srt);
  final normalizedText = sentenceText.trim();
  if (normalizedText.isEmpty) return null;

  final preferred =
      preferredSentenceIndex != null &&
          preferredSentenceIndex >= 0 &&
          preferredSentenceIndex < sentences.length
      ? sentences[preferredSentenceIndex]
      : null;
  final resolved = preferred?.text.trim() == normalizedText
      ? preferred
      : sentences.cast<Sentence?>().firstWhere(
          (candidate) => candidate?.text.trim() == normalizedText,
          orElse: () => null,
        );
  if (resolved == null) return null;
  return (
    sentenceIndex: resolved.index,
    startTimeMs: resolved.startTime.inMilliseconds,
    endTimeMs: resolved.endTime.inMilliseconds,
  );
}

// ============================================================
// 单词视图
// ============================================================

/// 单词视图 — 按收藏时间倒序展示
///
/// 批量预加载字典释义，所有释义一次性渲染（不会逐个闪烁）。
class _WordsView extends ConsumerStatefulWidget {
  /// 词汇 tab 当前是否激活（IndexedStack 会同时构建两个 tab，用此门控预热——
  /// 仅激活时才为词汇起引擎合成，停在句子 tab 不预热）。
  final bool isActive;

  const _WordsView({this.isActive = false});

  @override
  ConsumerState<_WordsView> createState() => _WordsViewState();
}

class _WordsViewState extends ConsumerState<_WordsView> {
  /// 批量查询得到的字典条目缓存
  Map<String, DictEntry> _dictMap = {};

  /// 上次触发查询的单词列表，用于去重
  List<String> _lastWordKeys = [];

  /// 统一 TTS 控制器（build 时缓存，供 dispose 取消预热——dispose 内不可用 ref，§7.14）。
  TtsController? _ttsController;
  bool _isScrolling = false;
  int _scrollSession = 0;
  bool _hasWarmedCurrentEngine = false;

  void _scheduleEngineWarmup() {
    if (!widget.isActive || _hasWarmedCurrentEngine) return;
    _hasWarmedCurrentEngine = true;
    final controller = _ttsController;
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        controller.warmUpCurrentEngine();
      }
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.isActive) return false;
    if (notification is ScrollStartNotification && !_isScrolling) {
      _isScrolling = true;
      final startedSession = ++_scrollSession;
      AppLogger.log(
        'FavoritesTts',
        'scroll start session=$startedSession: cancel prewarm',
      );
      _ttsController?.cancelTextsPrewarm();
      // 让已创建的 tile 收到 isScrolling=true 并清除提交标记；滚动停止后
      // 才能对当前视口重新提交预热。通知在布局期派发，延后重建避免 frame 异常。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.isActive &&
            _isScrolling &&
            _scrollSession == startedSession) {
          setState(() {});
        }
      });
    } else if (notification is ScrollEndNotification && _isScrolling) {
      _isScrolling = false;
      final completedSession = ++_scrollSession;
      AppLogger.log(
        'FavoritesTts',
        'scroll end session=$completedSession: schedule visible tile prewarm',
      );
      // ScrollEndNotification 可能由 Viewport 布局期间派发，延后重建以避免在布局期
      // 调度 build；会话号确保下一次滚动已开始时不恢复旧视口的预热。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.isActive &&
            !_isScrolling &&
            _scrollSession == completedSession) {
          AppLogger.log(
            'FavoritesTts',
            'scroll restore session=$completedSession: rebuild visible tiles',
          );
          setState(() {});
        } else {
          AppLogger.log(
            'FavoritesTts',
            'scroll restore discarded session=$completedSession '
                'active=${widget.isActive} scrolling=$_isScrolling '
                'current=$_scrollSession',
          );
        }
      });
    }
    return false;
  }

  @override
  void didUpdateWidget(_WordsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切离词汇 tab（IndexedStack 不销毁本视图）→ 停在途预热；重置签名使重新
    // 激活时可再次触发（届时已缓存的命中即跳过，未完成的续上）。
    if (oldWidget.isActive && !widget.isActive) {
      _ttsController?.cancelTextsPrewarm();
      _hasWarmedCurrentEngine = false;
    }
  }

  @override
  void dispose() {
    // 离开收藏页即停在途预热，避免继续占用 CPU 合成用不到的发音。
    _ttsController?.cancelTextsPrewarm();
    super.dispose();
  }

  /// 当单词列表变化时，批量查询字典释义
  Future<void> _loadDictEntries(List<SavedWord> words) async {
    final wordStrings = words.map((w) => w.word).toList();
    // 单词列表未变化时跳过
    if (_listEquals(wordStrings, _lastWordKeys)) return;
    _lastWordKeys = wordStrings;

    final entries = await ref
        .read(dictionaryServiceProvider)
        .lookupAll(wordStrings);
    // 查询期间列表已变化时丢弃过期结果，避免旧释义覆盖新列表
    if (!mounted || !_listEquals(wordStrings, _lastWordKeys)) return;
    setState(() => _dictMap = entries);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final savedWordsAsync = ref.watch(savedWordListProvider);
    final savedPhrasesAsync = ref.watch(savedSenseGroupListProvider);

    // 等待两个数据源都加载完成
    if (savedWordsAsync.isLoading || savedPhrasesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (savedWordsAsync.hasError) {
      return Center(child: Text('Error: ${savedWordsAsync.error}'));
    }

    final words = savedWordsAsync.value ?? [];
    final phrases = savedPhrasesAsync.value ?? [];

    if (words.isEmpty && phrases.isEmpty) {
      return _buildEmptyState(context, isSentences: false);
    }

    // 触发批量字典查询
    _loadDictEntries(words);

    // 合并并按 createdAt 倒序排列
    final items = <_VocabularyItem>[
      for (final w in words) _VocabularyWord(w),
      for (final p in phrases) _VocabularyPhrase(p),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Tile 负责提交自己的预热；父视图保留同一控制器，以便切 tab 或离页时
    // 取消尚未完成的增量预热队列。
    if (widget.isActive) {
      _ttsController = ref.read(ttsControllerProvider.notifier);
      _scheduleEngineWarmup();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          AppSpacing.s,
          AppSpacing.m,
          80,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final tile = switch (item) {
            _VocabularyWord(word: final w) => _SavedWordTile(
              key: ValueKey('w_${w.id}'),
              savedWord: w,
              dictEntry: _dictMap[w.word],
              expansionController: null,
              isActive: widget.isActive,
              isScrolling: _isScrolling,
            ),
            _VocabularyPhrase(phrase: final p) => _SavedPhraseTile(
              key: ValueKey('p_${p.id}'),
              savedPhrase: p,
              expansionController: null,
              isActive: widget.isActive,
              isScrolling: _isScrolling,
            ),
          };
          return tile;
        },
      ),
    );
  }
}

/// 词汇列表项（单词 / 意群）
sealed class _VocabularyItem {
  DateTime get createdAt;
}

class _VocabularyWord extends _VocabularyItem {
  final SavedWord word;
  _VocabularyWord(this.word);
  @override
  DateTime get createdAt => word.createdAt;
}

class _VocabularyPhrase extends _VocabularyItem {
  final SavedSenseGroup phrase;
  _VocabularyPhrase(this.phrase);
  @override
  DateTime get createdAt => phrase.createdAt;
}

/// 收藏意群列表项（可展开，样式与 _SavedWordTile 一致）
/// 收藏单词、词组和意群共用的发音行，保证各平台的水平位置一致。
class _FavoritePronunciationRow extends StatelessWidget {
  const _FavoritePronunciationRow({
    required this.rowKey,
    required this.buttonKey,
    required this.text,
    this.phonetic,
    this.speakKey,
  });

  final Key rowKey;
  final Key buttonKey;
  final String text;
  final String? phonetic;
  final String? speakKey;

  @override
  Widget build(BuildContext context) {
    final normalizedPhonetic = phonetic?.trim();
    final speakButton = SpeakButton(
      key: buttonKey,
      text: text,
      speakKey: speakKey,
      size: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    return SizedBox(
      key: rowKey,
      width: double.infinity,
      height: 44,
      child: Align(
        alignment: Alignment.centerLeft,
        child: normalizedPhonetic == null || normalizedPhonetic.isEmpty
            ? speakButton
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      '/$normalizedPhonetic/',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  speakButton,
                ],
              ),
      ),
    );
  }
}

class _SavedPhraseTile extends ConsumerStatefulWidget {
  final SavedSenseGroup savedPhrase;

  /// 仅词汇 tab 激活时预热，避免 IndexedStack 预建子树造成后台合成。
  final bool isActive;
  final bool isScrolling;

  /// 展开控制器（可选）：用于新手引导时由外部主动展开
  final ExpansibleController? expansionController;

  const _SavedPhraseTile({
    super.key,
    required this.savedPhrase,
    this.expansionController,
    required this.isActive,
    required this.isScrolling,
  });

  @override
  ConsumerState<_SavedPhraseTile> createState() => _SavedPhraseTileState();
}

class _SavedPhraseTileState extends ConsumerState<_SavedPhraseTile> {
  bool _isExpanded = false;
  String? _audioName;
  bool _sourceAudioResolved = false;
  bool _hasSubmittedPrewarm = false;
  int _lastPrewarmConfigurationVersion = -1;

  @override
  void initState() {
    super.initState();
    _sourceAudioResolved = widget.savedPhrase.audioItemId == null;
    _loadAudioName();
    _schedulePrewarm();
  }

  @override
  void didUpdateWidget(_SavedPhraseTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.isActive && !widget.isActive) ||
        (!oldWidget.isScrolling && widget.isScrolling)) {
      _hasSubmittedPrewarm = false;
    }
    if ((!oldWidget.isActive && widget.isActive) ||
        (oldWidget.isScrolling && !widget.isScrolling)) {
      _schedulePrewarm();
    }
  }

  /// Tile 被列表创建后才提交意群预热；增量接口负责跨 tile 去重与后台排队。
  void _schedulePrewarm() {
    final configurationVersion = ref.read(
      ttsControllerProvider.select((state) => state.configurationVersion),
    );
    if (!widget.isActive ||
        widget.isScrolling ||
        (_hasSubmittedPrewarm &&
            _lastPrewarmConfigurationVersion == configurationVersion)) {
      return;
    }
    _hasSubmittedPrewarm = true;
    _lastPrewarmConfigurationVersion = configurationVersion;
    final text = widget.savedPhrase.displayText;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.isActive &&
          !widget.isScrolling &&
          _isInScrollableViewport(context)) {
        ref.read(ttsControllerProvider.notifier).prewarmTextsIncremental([
          text,
        ]);
      }
    });
  }

  Future<void> _loadAudioName() async {
    final audioId = widget.savedPhrase.audioItemId;
    if (audioId == null) return;
    final dao = ref.read(audioItemDaoProvider);
    final row = await dao.getById(audioId);
    if (mounted) {
      setState(() {
        _audioName = row?.name;
        _sourceAudioResolved = true;
      });
    }
  }

  /// 打开来源句讲解；历史收藏缺少定位字段时由共享解析器回填。
  Future<void> _openSourceSentenceDetail() {
    final phrase = widget.savedPhrase;
    final audioItemId = phrase.audioItemId;
    final sentenceText = phrase.sentenceText;
    if (audioItemId == null || sentenceText == null) return Future.value();
    return _openFavoriteSourceSentenceDetail(
      context: context,
      ref: ref,
      audioItemId: audioItemId,
      sentenceText: sentenceText,
      sentenceIndex: phrase.sentenceIndex,
      sentenceStartMs: phrase.sentenceStartMs,
      sentenceEndMs: phrase.sentenceEndMs,
    );
  }

  /// 播放意群片段（优先意群时间，回退句子时间）
  Future<void> _playSentence() async {
    final phrase = widget.savedPhrase;
    AppLogger.log(
      'FavoritesPlayback',
      'source sentence tap phraseId=${phrase.id} text="${phrase.sentenceText}"',
    );
    final key = 'saved-phrase-source:${phrase.id}';
    final player = ref.read(shortAudioPlayerProvider);

    // 播放来源句子（非意群片段）
    if (player.state.playingKey == key) {
      await player.stop();
      return;
    }
    if (ref.read(ttsControllerProvider).speakingKey == key) {
      await ref.read(ttsControllerProvider.notifier).stop();
      return;
    }
    await _playSourceSentence(
      ref,
      key: key,
      audioItemId: phrase.audioItemId,
      sentenceIndex: phrase.sentenceIndex,
      sentenceText: phrase.sentenceText,
      sentenceStartMs: phrase.sentenceStartMs,
      sentenceEndMs: phrase.sentenceEndMs,
    );
    return;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      ttsControllerProvider.select((state) => state.configurationVersion),
    );
    _schedulePrewarm();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final phrase = widget.savedPhrase;

    return Dismissible(
      key: ValueKey('phrase_${phrase.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(Icons.bookmark_remove, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        ref
            .read(savedSenseGroupListProvider.notifier)
            .removeSenseGroup(phrase.phraseText);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          controller: widget.expansionController,
          childrenPadding: EdgeInsets.zero,
          dense: true,
          minTileHeight: 40,
          iconColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          collapsedIconColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.4,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          // 收起态仅预览一行来源句子，超长内容省略以保持列表紧凑。
          title: Text(
            phrase.displayText,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: !_isExpanded && phrase.sentenceText != null
              ? Text(
                  phrase.sentenceText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          // 展开状态：来源句子 + 来源音频
          children: [
            SizedBox(
              key: const Key('favorite-phrase-expanded-content'),
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                  AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 词组和意群没有音标，播放入口与单词卡保持左对齐。
                    _FavoritePronunciationRow(
                      rowKey: const Key('favorite-phrase-pronunciation-row'),
                      buttonKey: const Key('favorite_phrase_speak'),
                      text: phrase.displayText,
                      speakKey: 'favorite-phrase:${phrase.id}',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // 来源句复用收藏句行：正文试听，箭头打开讲解。
                    if (phrase.sentenceText != null) ...[
                      _FavoriteSourceSentenceTile(
                        key: const Key('favorite-phrase-source-sentence'),
                        sentenceText: phrase.sentenceText!,
                        onPlay: _playSentence,
                        onOpenDetail: _audioName != null
                            ? () => unawaited(_openSourceSentenceDetail())
                            : null,
                      ),
                    ],

                    // 来源音频
                    if (_audioName != null && phrase.audioItemId != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      _SourceAudioReference(
                        key: const Key('favorite-source-audio-reference'),
                        label: l10n.bookmarkReviewFromAudio(_audioName!),
                        onTap: () => context.push(
                          AppRoutes.audioLearningPlan(phrase.audioItemId!),
                        ),
                      ),
                    ] else if (phrase.sentenceText != null &&
                        _sourceAudioResolved) ...[
                      const SizedBox(height: AppSpacing.s),
                      const _MissingSourceAudioReference(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条收藏单词列表项（可展开）
class _SavedWordTile extends ConsumerStatefulWidget {
  final SavedWord savedWord;

  /// 仅词汇 tab 激活时预热，避免 IndexedStack 预建子树造成后台合成。
  final bool isActive;
  final bool isScrolling;

  /// 由父组件批量预加载的字典条目，避免每个 tile 独立异步查询
  final DictEntry? dictEntry;

  /// 展开控制器（可选）：用于新手引导时由外部主动展开
  final ExpansibleController? expansionController;

  const _SavedWordTile({
    super.key,
    required this.savedWord,
    this.dictEntry,
    this.expansionController,
    required this.isActive,
    required this.isScrolling,
  });

  @override
  ConsumerState<_SavedWordTile> createState() => _SavedWordTileState();
}

class _SavedWordTileState extends ConsumerState<_SavedWordTile> {
  bool _isExpanded = false;

  /// 源音频名称（异步加载）
  String? _audioName;
  bool _sourceAudioResolved = false;
  bool _hasSubmittedPrewarm = false;
  int _lastPrewarmConfigurationVersion = -1;

  @override
  void initState() {
    super.initState();
    _sourceAudioResolved = widget.savedWord.audioItemId == null;
    _loadAudioName();
    _schedulePrewarm();
  }

  @override
  void didUpdateWidget(_SavedWordTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.isActive && !widget.isActive) ||
        (!oldWidget.isScrolling && widget.isScrolling)) {
      _hasSubmittedPrewarm = false;
    }
    if ((!oldWidget.isActive && widget.isActive) ||
        (oldWidget.isScrolling && !widget.isScrolling)) {
      _schedulePrewarm();
    }
  }

  /// Tile 被列表创建后才预热；CDN 单词音频命中时无需再生成同词的 TTS 缓存。
  void _schedulePrewarm() {
    final configurationVersion = ref.read(
      ttsControllerProvider.select((state) => state.configurationVersion),
    );
    if (!widget.isActive ||
        widget.isScrolling ||
        (_hasSubmittedPrewarm &&
            _lastPrewarmConfigurationVersion == configurationVersion)) {
      return;
    }
    _hasSubmittedPrewarm = true;
    _lastPrewarmConfigurationVersion = configurationVersion;
    final word = widget.savedWord.word;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.isActive ||
          widget.isScrolling ||
          !_isInScrollableViewport(context)) {
        return;
      }
      ref.read(textPlaybackProvider.notifier).prewarmWord(word);
    });
  }

  /// 加载源音频名称
  Future<void> _loadAudioName() async {
    final audioId = widget.savedWord.audioItemId;
    if (audioId == null) return;
    final dao = ref.read(audioItemDaoProvider);
    final row = await dao.getById(audioId);
    if (mounted) {
      setState(() {
        _audioName = row?.name;
        _sourceAudioResolved = true;
      });
    }
  }

  /// 打开来源句讲解；历史收藏缺少定位字段时由共享解析器回填。
  Future<void> _openSourceSentenceDetail() {
    final word = widget.savedWord;
    final audioItemId = word.audioItemId;
    final sentenceText = word.sentenceText;
    if (audioItemId == null || sentenceText == null) return Future.value();
    return _openFavoriteSourceSentenceDetail(
      context: context,
      ref: ref,
      audioItemId: audioItemId,
      sentenceText: sentenceText,
      sentenceIndex: word.sentenceIndex,
      sentenceStartMs: word.sentenceStartMs,
      sentenceEndMs: word.sentenceEndMs,
    );
  }

  /// 播放来源句子的原声片段
  ///
  /// 优先使用冗余存储的 sentenceStartMs/sentenceEndMs（不依赖字幕文件），
  /// 仅在无时间信息时回退到加载字幕。
  Future<void> _playSentence() async {
    final word = widget.savedWord;
    final key = 'saved-word-source:${word.id}';
    final player = ref.read(shortAudioPlayerProvider);
    if (player.state.playingKey == key) {
      await player.stop();
      return;
    }
    if (ref.read(ttsControllerProvider).speakingKey == key) {
      await ref.read(ttsControllerProvider.notifier).stop();
      return;
    }
    await _playSourceSentence(
      ref,
      key: key,
      audioItemId: word.audioItemId,
      sentenceIndex: word.sentenceIndex,
      sentenceText: word.sentenceText,
      sentenceStartMs: word.sentenceStartMs,
      sentenceEndMs: word.sentenceEndMs,
    );
    return;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      ttsControllerProvider.select((state) => state.configurationVersion),
    );
    _schedulePrewarm();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final word = widget.savedWord;
    final previewText = _collapsedPreviewText(word, widget.dictEntry);
    return Dismissible(
      key: ValueKey('word_${word.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.l),
        color: theme.colorScheme.error,
        child: Icon(Icons.bookmark_remove, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        ref.read(savedWordListProvider.notifier).removeWord(word.word);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          controller: widget.expansionController,
          childrenPadding: EdgeInsets.zero,
          dense: true,
          minTileHeight: 40,
          iconColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          collapsedIconColor: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: 0.4,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          // 收起状态：单词 + 收藏图标 + 音标 + 简释
          title: Text(
            word.word,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: !_isExpanded && previewText != null
              ? Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          // 展开状态：完整释义（仅多行时）+ 柯林斯星级 + 考试标签 + 来源句子
          children: [
            SizedBox(
              key: const Key('favorite-word-expanded-content'),
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.m,
                  AppSpacing.s,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 播放入口不依赖在线词典命中，固定跟随音标左侧排列。
                    _FavoritePronunciationRow(
                      rowKey: const Key('favorite-word-pronunciation-row'),
                      buttonKey: const Key('favorite_speak'),
                      text: word.word,
                      phonetic: widget.dictEntry?.phonetic,
                    ),
                    // 完整释义仅在在线词典精确命中时展示。
                    if (widget.dictEntry != null) ...[
                      if (widget.dictEntry!.translation != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.dictEntry!.translation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],

                    // 柯林斯星级 + 考试标签
                    if (widget.dictEntry != null &&
                        (widget.dictEntry!.collins > 0 ||
                            widget.dictEntry!.examTags.isNotEmpty)) ...[
                      const SizedBox(height: AppSpacing.s),
                      _buildMetaTags(theme, widget.dictEntry!),
                    ],

                    // 来源句复用收藏句行：正文试听，箭头打开讲解。
                    if (word.sentenceText != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(height: 0),
                      _FavoriteSourceSentenceTile(
                        key: const Key('favorite-word-source-sentence'),
                        sentenceText: word.sentenceText!,
                        onPlay: _playSentence,
                        onOpenDetail: _audioName != null
                            ? () => unawaited(_openSourceSentenceDetail())
                            : null,
                      ),
                    ],

                    // 源音频引用
                    if (_audioName != null && word.audioItemId != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _SourceAudioReference(
                        key: const Key('favorite-source-audio-reference'),
                        label: l10n.bookmarkReviewFromAudio(_audioName!),
                        onTap: () => context.push(
                          AppRoutes.audioLearningPlan(word.audioItemId!),
                        ),
                      ),
                    ] else if (word.sentenceText != null &&
                        _sourceAudioResolved) ...[
                      const SizedBox(height: AppSpacing.s),
                      const _MissingSourceAudioReference(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 简短副标题：音标 + 首行释义
  String _buildSubtitle(DictEntry entry) {
    final parts = <String>[];
    if (entry.phonetic.isNotEmpty) {
      parts.add('/${entry.phonetic}/');
    }
    if (entry.translation != null && entry.translation!.isNotEmpty) {
      final firstLine = entry.translation!.split('\n').first.trim();
      parts.add(firstLine);
    }
    return parts.join(' ');
  }

  /// 多词收藏优先预览来源句子，单词继续展示词典摘要。
  String? _collapsedPreviewText(SavedWord word, DictEntry? dictEntry) {
    final hasMultipleWords = word.word.trim().contains(RegExp(r'\s'));
    if (hasMultipleWords && (word.sentenceText?.isNotEmpty ?? false)) {
      return word.sentenceText;
    }
    if (dictEntry == null) return null;
    return _buildSubtitle(dictEntry);
  }

  /// 柯林斯星级 + 考试标签 Wrap
  Widget _buildMetaTags(ThemeData theme, DictEntry entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (entry.collins > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              return Icon(
                Icons.star_rounded,
                size: 12,
                color: i < entry.collins
                    ? Colors.amber.shade600
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              );
            }),
          ),
        for (final tag in entry.examTags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// 来源音频固定为单行右对齐，并以箭头提示该行可跳转。
class _SourceAudioReference extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SourceAudioReference({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      label: '打开来源材料 $label',
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headphones, size: 14, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 已删除来源材料的只读提示，外观与可跳转的来源材料行保持一致。
class _MissingSourceAudioReference extends StatelessWidget {
  const _MissingSourceAudioReference();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outline.withValues(alpha: 0.7);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.favoriteSourceMaterialNotFound,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.headphones, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.favoriteSourceMaterialNotFound,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 共用空状态
// ============================================================

Widget _buildEmptyState(BuildContext context, {required bool isSentences}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSentences ? Icons.subject : Icons.menu_book_outlined,
            size: 56,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            isSentences
                ? l10n.favoritesNoSentences
                : l10n.favoritesNoVocabulary,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            isSentences
                ? l10n.favoritesNoSentencesHint
                : l10n.favoritesNoVocabularyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    ),
  );
}

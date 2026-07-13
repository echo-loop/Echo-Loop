import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../models/playback_settings.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../router/app_router.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sleep_timer.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/common/audio_app_bar_title.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/annotation_content_view.dart';
import 'sentence_detail_screen.dart';

const kPlayerSingleSentenceSwipeAreaKey = ValueKey(
  'player-single-sentence-swipe-area',
);
const kPlayerBookmarkSingleSentenceSwipeAreaKey = ValueKey(
  'player-bookmark-single-sentence-swipe-area',
);
const kPlayerInfoBarStatusRowKey = ValueKey('player-info-bar-status-row');

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final ListeningPractice _notifier;

  /// 精听单句模式横向分页控制器。全文 / 收藏两 tab 各持一个：TabBarView 切换动画
  /// 期间两 tab body 会同时存在，单个 PageController 不能同时挂到两个 PageView。
  /// 在字段初始化时创建、[dispose] 释放，绝不在 build 内重建。
  final PageController _fullPageController = PageController();
  final PageController _bookmarkPageController = PageController();

  /// 各 pager 是否已完成首次对齐。首次用 jumpToPage 瞬切到当前句（恢复进度不滑动），
  /// 之后的索引变化用 animateToPage 滑动过渡。
  bool _fullPagerSynced = false;
  bool _bookmarkPagerSynced = false;

  /// provider→PageView 程序化对齐（jumpToPage/animateToPage）进行中为 true。
  ///
  /// 跨多页的滑动（如整篇循环回卷 50→0）会途经中间页并**逐页**触发 onPageChanged，
  /// 若被当作用户滑动会反向 `selectFullSentence(autoPlay)` → 重启整篇循环并清零已播
  /// 遍数（徽标回到 1/N）。该标志让 [_onSentencePageChanged] 在程序化对齐期间忽略
  /// 回调，只放行真正的用户跟手滑动。
  bool _fullPagerProgrammatic = false;
  bool _bookmarkPagerProgrammatic = false;

  late TabController _tabController;
  int _previousTabIndex = 0;
  Duration? _seekPreviewPosition;
  int _seekPreviewToken = 0;

  /// 防止进入讲解页重入（点击主体区 → pause + 导航）
  bool _isNavigatingToDetail = false;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(listeningPracticeProvider.notifier);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 自愈：每次进入播放页夺回锁屏控制（学习/复习任务离开时会把全局回调槽置 null），
      // 并清除任务残留的逻辑播放态/静音保活，保证 Free Player 后台播放与锁屏不被破坏。
      _notifier.reattachLockScreen();
      await _notifier.setPlaylistMode(PlaylistMode.full);
    });
    _tabController.addListener(() {
      if (_tabController.index != _previousTabIndex) {
        _previousTabIndex = _tabController.index;
        ref
            .read(listeningPracticeProvider.notifier)
            .setPlaylistMode(
              _tabController.index == 0
                  ? PlaylistMode.full
                  : PlaylistMode.bookmarks,
            );
      }
    });
  }

  @override
  void dispose() {
    scheduleMicrotask(() async {
      await _notifier.pause();
      await _notifier.saveCurrentPlaybackState();
    });
    _tabController.dispose();
    _fullPageController.dispose();
    _bookmarkPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return LearningHotkeyScope(
      onPlayPause: () =>
          playerState.isPlaying ? controller.pause() : controller.play(),
      onPrevious: () {
        if (playerState.hasSentences) controller.previousSentence();
      },
      onNext: () {
        if (playerState.hasSentences) controller.nextSentence();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _buildAppBarTitle(playerState, l10n),
          actions: const [SleepTimerButton()],
        ),
        // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）。
        // 页面自身无 PopScope，由宿主代管返回键（面板开着时先关面板）。
        body: DictionaryPanelHost(
          handleBackButton: true,
          child: !playerState.hasAudio
              ? Center(child: Text(l10n.noAudioLoaded))
              : _buildLayout(context, playerState),
        ),
      ),
    );
  }

  /// AppBar 标题：音频名为主标题，下方附带所属合集副标题。
  /// 与学习计划页共用 [AudioAppBarTitle] 且合集名同源（按音频 id 查
  /// [collectionListProvider] 的 audioToCollectionsMap），保证两页一致。
  Widget _buildAppBarTitle(
    ListeningPracticeState playerState,
    AppLocalizations l10n,
  ) {
    final audioItem = playerState.currentAudioItem;
    final audioName = audioItem?.name ?? l10n.player;
    final collectionNames = audioItem == null
        ? const <String>[]
        : ref.watch(
            collectionListProvider.select((s) {
              final ids = s.audioToCollectionsMap[audioItem.id] ?? const [];
              if (ids.isEmpty) return const <String>[];
              final idSet = ids.toSet();
              return s.collections
                  .where((c) => idSet.contains(c.id))
                  .map((c) => c.name)
                  .toList(growable: false);
            }),
          );

    return AudioAppBarTitle(
      audioName: audioName,
      collectionNames: collectionNames,
    );
  }

  Widget _buildLayout(
    BuildContext context,
    ListeningPracticeState playerState,
  ) {
    return Column(
      children: [
        Expanded(child: _buildTranscriptView(playerState)),
        _buildControlPanel(context, playerState),
      ],
    );
  }

  Widget _buildTranscriptView(ListeningPracticeState playerState) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(listeningPracticeProvider.notifier);

    if (!playerState.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.noSubtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.article, size: 18),
                  const SizedBox(width: 8),
                  Text('${l10n.fullText} (${playerState.sentences.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.bookmarked} (${playerState.bookmarkedSentences.length})',
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            // Free Player 的横向手势保留给学习态切句，这里只允许点 tab 切换。
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFullTextTab(playerState, controller),
              _buildBookmarkedTab(playerState, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullTextTab(
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final settings = playerState.fullSettings;

    if (settings.singleSentenceMode) {
      if (playerState.currentFullIndex == null &&
          playerState.sentences.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.selectFullSentence(0, autoPlay: false);
        });
        return const Center(child: CircularProgressIndicator());
      }
      if (playerState.currentFullIndex != null) {
        return _buildSingleSentenceView(
          playerState,
          controller,
          playerState.currentFullIndex!,
          settings,
          PlaylistMode.full,
        );
      }
      return Center(
        child: Text(
          l10n.noSentenceSelected,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (playerState.currentFullIndex == null &&
        playerState.sentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectFullSentence(0, autoPlay: false);
      });
    }
    // 全文列表中 sentence.index == 列表位置，currentFullIndex 即本地位置索引
    return ParagraphSentenceListCard(
      sentences: playerState.sentences,
      displayMode: settings.showTranscript
          ? RetellDisplayMode.showAll
          : RetellDisplayMode.hideAll,
      keywordMap: const {},
      playingSentenceIndex: playerState.currentFullIndex ?? -1,
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectFullSentence(s.index),
      onSentenceTap: _handleSentenceDetail,
      onSentenceBookmarkToggle: (s) => controller.toggleBookmark(s.index),
    );
  }

  Widget _buildBookmarkedTab(
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bookmarkedSentences = playerState.bookmarkedSentences;
    final settings = playerState.bookmarkSettings;

    if (bookmarkedSentences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.noBookmarkedSentences,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.tapBookmarkIcon,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (settings.singleSentenceMode) {
      if (playerState.currentBookmarkIndex == null ||
          !playerState.bookmarkedIndices.contains(
            playerState.currentBookmarkIndex,
          )) {
        if (bookmarkedSentences.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.selectBookmarkedSentence(
              bookmarkedSentences.first.index,
              autoPlay: false,
            );
          });
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Text(
            l10n.noSentenceSelected,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      return _buildSingleSentenceView(
        playerState,
        controller,
        playerState.currentBookmarkIndex!,
        settings,
        PlaylistMode.bookmarks,
      );
    }

    if ((playerState.currentBookmarkIndex == null ||
            !playerState.bookmarkedIndices.contains(
              playerState.currentBookmarkIndex,
            )) &&
        bookmarkedSentences.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.selectBookmarkedSentence(
          bookmarkedSentences.first.index,
          autoPlay: false,
        );
      });
    }
    // 收藏子集中列表位置 ≠ 全局 index，需将 currentBookmarkIndex 换算成本地位置
    final playingLocalIndex = bookmarkedSentences.indexWhere(
      (s) => s.index == playerState.currentBookmarkIndex,
    );
    return ParagraphSentenceListCard(
      sentences: bookmarkedSentences,
      displayMode: settings.showTranscript
          ? RetellDisplayMode.showAll
          : RetellDisplayMode.hideAll,
      keywordMap: const {},
      playingSentenceIndex: playingLocalIndex,
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectBookmarkedSentence(s.index),
      onSentenceTap: _handleSentenceDetail,
      onSentenceBookmarkToggle: (s) => controller.toggleBookmark(s.index),
    );
  }

  /// 单句模式（= 精听模式）：复用逐句精听的解析内容视图
  ///
  /// 与「逐句精听」共享 [AnnotationContentView]（解析/翻译/意群工具栏 + 句子 +
  /// 翻译 + 解析），并在顶部叠加难句标记行。与逐句精听唯一的不同：本页支持
  /// 「隐藏字幕」——[PlaybackSettings.showTranscript] 为 false 时，整个解析内容区
  /// （含工具栏、句子、翻译、解析）被模糊遮罩并禁用点击，由控制栏眼睛图标恢复
  /// 显示后才可操作。
  Widget _buildSingleSentenceView(
    ListeningPracticeState playerState,
    ListeningPractice controller,
    int index,
    PlaybackSettings settings,
    PlaylistMode mode,
  ) {
    final currentSentence = playerState.sentences[index];
    final isBookmarked = playerState.bookmarkedIndices.contains(
      currentSentence.index,
    );
    final audioItem = playerState.currentAudioItem;
    if (audioItem == null) {
      return const SizedBox.shrink();
    }

    // 当前 tab 的播放列表：全文 → sentences；收藏 → bookmarkedSentences。
    // 用入参 mode 而非 playerState.playlistMode：TabBarView 切换动画期间离屏 tab 仍
    // 在重建，全局 playlistMode 可能已切到另一个 tab，会与本 tab 的列表/索引错配。
    // PageView 的页按列表内「位置」索引，位置↔句子经 playable[pos].index 映射。
    final isBookmarkMode = mode == PlaylistMode.bookmarks;
    final playable = isBookmarkMode
        ? playerState.bookmarkedSentences
        : playerState.sentences;
    final pageController = isBookmarkMode
        ? _bookmarkPageController
        : _fullPageController;
    // index 是全局句下标，换算成 playable 列表内的位置。
    final targetPosition = playable.indexWhere((s) => s.index == index);

    // provider → PageView 单向对齐（自动推进/程序选句的外部变化）。
    // post-frame + 位置比较 guard 避免回环，详见 _onSentencePageChanged 注释。
    if (targetPosition >= 0) {
      final firstSync = isBookmarkMode
          ? !_bookmarkPagerSynced
          : !_fullPagerSynced;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !pageController.hasClients) return;
        if (pageController.page?.round() == targetPosition) return;
        // 程序化对齐期间置位标志，使途经中间页触发的 onPageChanged 不被当作用户滑动。
        void setProgrammatic(bool v) {
          if (isBookmarkMode) {
            _bookmarkPagerProgrammatic = v;
          } else {
            _fullPagerProgrammatic = v;
          }
        }

        setProgrammatic(true);
        // 仅相邻 ±1 的推进（逐句自动播放/外部推进）滑动过渡；跨多页（整篇循环
        // 回卷末句→首句、恢复进度等）直接瞬切——否则 animateToPage 会在 280ms 内
        // 扫过数十页，呈现刺眼的“甩动”。
        final currentPage = pageController.page?.round();
        final isAdjacent =
            !firstSync &&
            currentPage != null &&
            (targetPosition - currentPage).abs() == 1;
        if (isAdjacent) {
          pageController
              .animateToPage(
                targetPosition,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              )
              .whenComplete(() => setProgrammatic(false));
        } else {
          // jumpToPage 同步派发回调，调用后立即清零标志。
          pageController.jumpToPage(targetPosition);
          setProgrammatic(false);
        }
      });
      if (isBookmarkMode) {
        _bookmarkPagerSynced = true;
      } else {
        _fullPagerSynced = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 序号 + 时间区间（弱化辅助信息）—— 固定在 PageView 之上，随当前页重渲。
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.m,
              bottom: AppSpacing.s,
            ),
            child: Row(
              children: [
                Text(
                  '#${currentSentence.index + 1}',
                  style: AppTextStyles.caption(context),
                ),
                const SizedBox(width: AppSpacing.l),
                Text(
                  '${SubtitleParser.formatDuration(currentSentence.startTime)} - ${SubtitleParser.formatDuration(currentSentence.endTime)}',
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
          // 难句标记行（复用精听）—— 不被遮蔽，盲听时仍可标记。
          BookmarkToggleRow(
            isDifficult: isBookmarked,
            onTap: () => controller.toggleBookmark(currentSentence.index),
          ),
          const SizedBox(height: AppSpacing.m),
          // 精听解析内容 + 隐藏字幕遮罩。横向 PageView 跟手翻页，松手吸附，
          // 类似 iPhone 相册照片切换（无淡入淡出文字遮挡）。
          Expanded(
            child: PageView.builder(
              key: isBookmarkMode
                  ? kPlayerBookmarkSingleSentenceSwipeAreaKey
                  : kPlayerSingleSentenceSwipeAreaKey,
              controller: pageController,
              itemCount: playable.length,
              onPageChanged: (pos) =>
                  _onSentencePageChanged(pos, playerState, controller, mode),
              itemBuilder: (context, position) => _buildSentencePage(
                playable[position],
                audioItem,
                controller,
                settings,
                // 仅当前页启用新手引导：离屏预建页注册 showcase 后随 PageView 回收
                // 销毁会崩溃（见 AnnotationContentView.enableGuide 注释）。
                isActivePage: position == targetPosition,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 PageView 单页内容：解析视图 + 可选隐藏字幕遮罩。
  ///
  /// 每页按句子 index keyed，PageView.builder 会预建相邻 ±1 页。
  /// 预建安全：[AnnotationContentView] 初始化只查本地词级时间戳缓存与 L2 SQLite，
  /// 不发起 AI/网络请求；若未来其初始化新增 eager 网络调用，需重新评估预建开销。
  Widget _buildSentencePage(
    Sentence sentence,
    AudioItem audioItem,
    ListeningPractice controller,
    PlaybackSettings settings, {
    required bool isActivePage,
  }) {
    return Stack(
      children: [
        AnnotationContentView(
          // 按句 index keyed，确保 AnnotationContentView 内部意群等状态随句重置
          key: ValueKey(sentence.index),
          text: sentence.text,
          aiNotifier: ref.read(sentenceAiNotifierProvider),
          audioItemId: audioItem.id,
          sentenceIndex: sentence.index,
          sentenceStartMs: sentence.startTime.inMilliseconds,
          sentenceEndMs: sentence.endTime.inMilliseconds,
          // 意群试听与主播放共用引擎，播放前需立即暂停主播放
          onStopMainPlayer: () => controller.pause(),
          // 点击解析/翻译/意群工具栏按钮时，等当前句自然播完后再暂停，避免打断朗读。
          // 暂停保留循环遍数，恢复播放时从记住的进度继续。
          onToolbarButtonTapped: () => controller.pauseAfterCurrentSentence(),
          // 仅当前页启用引导，避免离屏预建页 showcase 注册后回收崩溃。
          enableGuide: isActivePage,
        ),
        // 隐藏字幕遮罩：覆盖整个内容区（含工具栏），模糊且不可点击
        if (!settings.showTranscript)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// PageView → provider：用户跟手滑动落到新页时更新真相源索引。
  ///
  /// [pos] 是 playable 列表内的位置，换算成全局句下标后经 select* 写回，
  /// `autoPlay: state.isPlaying` 复刻原 swipe「保持播放/暂停态」语义（用逻辑播放
  /// 态而非引擎 flag，后者自然播完后仍为 true，见 CLAUDE.md §7.6）。
  ///
  /// 防回环：`animateToPage` 落点会再触发一次本回调，此时目标全局下标已等于当前
  /// 真相源 → 直接 return，不二次写、不再触发 provider→PageView 对齐。
  void _onSentencePageChanged(
    int pos,
    ListeningPracticeState state,
    ListeningPractice controller,
    PlaylistMode mode,
  ) {
    final isBookmarkMode = mode == PlaylistMode.bookmarks;
    // 程序化对齐（provider→PageView）触发的回调不是用户滑动，忽略——否则整篇循环
    // 回卷等多页滚动途经的中间页会反向重启播放并清零循环遍数。
    if (isBookmarkMode ? _bookmarkPagerProgrammatic : _fullPagerProgrammatic) {
      return;
    }
    final playable = isBookmarkMode
        ? state.bookmarkedSentences
        : state.sentences;
    if (pos < 0 || pos >= playable.length) return;
    final globalIndex = playable[pos].index;
    final currentGlobal = isBookmarkMode
        ? state.currentBookmarkIndex
        : state.currentFullIndex;
    if (globalIndex == currentGlobal) return;
    if (isBookmarkMode) {
      unawaited(
        controller.selectBookmarkedSentence(
          globalIndex,
          autoPlay: state.isPlaying,
        ),
      );
    } else {
      unawaited(
        controller.selectFullSentence(globalIndex, autoPlay: state.isPlaying),
      );
    }
  }

  /// 点击句子主体 → 暂停播放 → 进入句子讲解页
  ///
  /// 与盲听任务行为一致：导航前停止音频，返回后同步收藏状态。
  /// 仅本页持有，不与盲听共享（共享面只到句子列表组件）。
  Future<void> _handleSentenceDetail(Sentence sentence) async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;

    final controller = ref.read(listeningPracticeProvider.notifier);
    final playerState = ref.read(listeningPracticeProvider);
    final audioItem = playerState.currentAudioItem;
    if (audioItem == null) {
      _isNavigatingToDetail = false;
      return;
    }

    await _selectSentenceForDetail(controller, playerState, sentence);
    await controller.pause();
    if (!mounted) {
      _isNavigatingToDetail = false;
      return;
    }

    await context.push(
      AppRoutes.sentenceDetail,
      extra: SentenceDetailArgs(
        audioItemId: audioItem.id,
        audioName: audioItem.name,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
      ),
    );

    _isNavigatingToDetail = false;

    if (!mounted) return;
    // 讲解页试听旁路驱动并 stop 了共享引擎，会改写 clip/position。返回后显式把
    // 引擎对齐回当前句起点，使主播放按钮从「原来的句子」继续，而非跳第一句。
    await controller.restorePosition();
    // 返回后刷新收藏状态（讲解页可能修改了收藏）
    await controller.syncBookmarks();
  }

  /// 正文点击进入讲解页时，先把播放器真相源同步到被点句。
  ///
  /// 左侧编号区仍负责“从这句播放”；正文区只切换焦点并保持暂停，避免返回列表时
  /// 自动跟随旧播放句，同时不因为查看讲解而误启动播放。
  Future<void> _selectSentenceForDetail(
    ListeningPractice controller,
    ListeningPracticeState playerState,
    Sentence sentence,
  ) async {
    if (playerState.playlistMode == PlaylistMode.bookmarks) {
      if (playerState.currentBookmarkIndex == sentence.index) return;
      await controller.selectBookmarkedSentence(
        sentence.index,
        autoPlay: false,
      );
      return;
    }

    if (playerState.currentFullIndex == sentence.index) return;
    await controller.selectFullSentence(sentence.index, autoPlay: false);
  }

  Widget _buildControlPanel(
    BuildContext context,
    ListeningPracticeState playerState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgressBar(playerState),
                const PlaybackControls(),
                _buildInfoBar(playerState, centered: isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(ListeningPracticeState playerState) {
    final engineNotifier = ref.read(audioEngineProvider.notifier);
    final controller = ref.read(listeningPracticeProvider.notifier);
    final engine = ref.watch(audioEngineProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: StreamBuilder<Duration>(
        stream: engineNotifier.absolutePositionStream,
        builder: (context, snapshot) {
          // 恢复断点/详情页返回时，provider 可能已先 seek 成功，但 positionStream
          // 还未来得及发下一帧。这里直接读引擎当前绝对位置作为首帧真相源，避免
          // 进度条短暂回到 0:00。
          final position =
              _seekPreviewPosition ?? engineNotifier.absoluteCurrentPosition;
          final total = engine.totalDuration ?? Duration.zero;

          // 时间标签直接用 ProgressBar 内置的 sides 布局放在进度条两侧同一行，
          // 节省竖向空间；右侧显示剩余时间（-0:04 形式）。
          return ProgressBar(
            progress: position,
            total: total,
            onSeek: (duration) {
              final token = ++_seekPreviewToken;
              setState(() {
                _seekPreviewPosition = duration;
              });
              unawaited(_settleSeekPreview(token, duration, controller));
            },
            barHeight: 3,
            thumbRadius: 8,
            thumbGlowRadius: 14,
            timeLabelTextStyle: AppTextStyles.caption(context),
            timeLabelLocation: TimeLabelLocation.sides,
            timeLabelType: TimeLabelType.remainingTime,
          );
        },
      ),
    );
  }

  Future<void> _settleSeekPreview(
    int token,
    Duration target,
    ListeningPractice controller,
  ) async {
    await controller.seekAbsolute(target);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || token != _seekPreviewToken) return;
    setState(() {
      _seekPreviewPosition = null;
    });
  }

  /// 底部状态栏：模式 + 循环徽标 + 倍速。
  ///
  /// [centered] 为 true（移动端）时状态行整体居中显示在播放按钮下方，且不显示
  /// macOS 快捷键提示；为 false（桌面端）时左对齐并在右侧排布快捷键提示。
  Widget _buildInfoBar(
    ListeningPracticeState playerState, {
    bool centered = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // 状态栏为辅助信息，统一弱化到低对比灰，避免与控制按钮抢注意力
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final captionStyle = AppTextStyles.caption(
      context,
    ).copyWith(color: mutedColor);
    final iconColor = mutedColor;

    final statusRow = Row(
      key: kPlayerInfoBarStatusRowKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 模式标签（列表/精听）依赖字幕分句，无字幕时隐藏。
        if (playerState.hasSentences) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playerState.settings.singleSentenceMode
                    ? Icons.format_quote
                    : Icons.article,
                size: 14,
                color: iconColor,
              ),
              const SizedBox(width: 3),
              Text(
                playerState.settings.singleSentenceMode
                    ? l10n.singleSentenceMode
                    : l10n.listMode,
                style: captionStyle,
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
        // 倍速
        Text('${playerState.settings.playbackSpeed}x', style: captionStyle),
        // 整篇循环徽标：播放中显示「当前遍/总遍」进度，未播放时显示设置值。
        if (playerState.settings.loopWhole) ...[
          const SizedBox(width: 12),
          _buildLoopBadge(
            icon: Icons.repeat,
            count: playerState.settings.wholeLoopCount,
            current: playerState.isPlaying
                ? playerState.wholeLoopsDone + 1
                : null,
            iconColor: iconColor,
            captionStyle: captionStyle,
          ),
        ],
        // 单句循环徽标：播放中显示当前句「当前遍/总遍」进度，未播放时显示设置值。
        if (playerState.settings.loopSentence) ...[
          const SizedBox(width: 12),
          _buildLoopBadge(
            icon: Icons.repeat_one,
            count: playerState.settings.sentenceLoopCount,
            current: playerState.isPlaying
                ? playerState.sentenceRepeatsDone + 1
                : null,
            iconColor: iconColor,
            captionStyle: captionStyle,
          ),
        ],
      ],
    );

    final mediaPadding = MediaQuery.paddingOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = mediaPadding.bottom > viewPadding.bottom
        ? mediaPadding.bottom
        : viewPadding.bottom;
    final bottomPadding = centered
        ? (bottomInset * 0.5).clamp(AppSpacing.s, AppSpacing.m).toDouble()
        : AppSpacing.s;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.s,
        AppSpacing.m,
        bottomPadding,
      ),
      child: centered
          ? Center(child: statusRow)
          : Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                statusRow,
                const Spacer(),
                if (!kIsWeb && Platform.isMacOS)
                  SizedBox(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: _HotkeyTipsCarousel(l10n: l10n),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// 单个循环状态徽标：图标 + 次数（∞ 或 xN）。
  /// 循环徽标。
  ///
  /// [count] 为设置的循环次数（`0` 表示 ∞）。[current] 非空表示「正在循环」，
  /// 此时展示进度：有限次显示 `当前/总数`（如 `2/3`，钳制在区间内），
  /// 无限次显示 `当前/∞`；为空（未播放）时显示设置值 `x$count` 或 `∞`。
  Widget _buildLoopBadge({
    required IconData icon,
    required int count,
    required Color iconColor,
    required TextStyle? captionStyle,
    int? current,
  }) {
    final String label;
    if (current != null) {
      if (count == 0) {
        label = '$current/∞';
      } else {
        final cur = current.clamp(1, count);
        label = '$cur/$count';
      }
    } else {
      label = count == 0 ? '∞' : 'x$count';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 3),
        Text(label, style: captionStyle),
      ],
    );
  }
}

class _HotkeyTipsCarousel extends StatefulWidget {
  final AppLocalizations l10n;

  const _HotkeyTipsCarousel({required this.l10n});

  @override
  State<_HotkeyTipsCarousel> createState() => _HotkeyTipsCarouselState();
}

class _HotkeyTipsCarouselState extends State<_HotkeyTipsCarousel> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCarousel();
  }

  void _startCarousel() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getCurrentTip() {
    switch (_currentIndex) {
      case 0:
        return widget.l10n.hotkeyReplay;
      case 1:
        return widget.l10n.hotkeyPlayPause;
      case 2:
        return widget.l10n.hotkeyToggleTranscript;
      case 3:
        return widget.l10n.hotkeyNavigation;
      default:
        return widget.l10n.hotkeyReplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        _getCurrentTip(),
        key: ValueKey<int>(_currentIndex),
        style: AppTextStyles.caption(context),
        textAlign: TextAlign.right,
      ),
    );
  }
}

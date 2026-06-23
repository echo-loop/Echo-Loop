import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
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
import '../widgets/practice/annotation_content_view.dart';
import 'sentence_detail_screen.dart';

const kPlayerSingleSentenceSwipeAreaKey = ValueKey(
  'player-single-sentence-swipe-area',
);

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  static const double _singleSentenceSwipeVelocityThreshold = 250;
  String? _lastSingleSentenceContentId;
  PlaylistMode? _lastSingleSentencePlaylistMode;
  int? _lastSingleSentenceIndex;
  int _singleSentenceTransitionDirection = 0;

  late TabController _tabController;
  int _previousTabIndex = 0;
  Duration? _seekPreviewPosition;
  int _seekPreviewToken = 0;

  /// 防止进入讲解页重入（点击主体区 → pause + 导航）
  bool _isNavigatingToDetail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(listeningPracticeProvider.notifier)
          .setPlaylistMode(PlaylistMode.full);
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
  void deactivate() {
    // 延迟到下一帧执行，避免在 widget 树销毁过程中修改 provider state
    final notifier = ref.read(listeningPracticeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.pause();
      notifier.saveCurrentPlaybackState();
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        body: !playerState.hasAudio
            ? Center(child: Text(l10n.noAudioLoaded))
            : _buildLayout(context, playerState),
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
  ) {
    final currentSentence = playerState.sentences[index];
    final isBookmarked = playerState.bookmarkedIndices.contains(
      currentSentence.index,
    );
    final audioItem = playerState.currentAudioItem;
    if (audioItem == null) {
      return const SizedBox.shrink();
    }
    final contentId = '${playerState.playlistMode.name}-$index';
    if (_lastSingleSentenceContentId != contentId) {
      if (_lastSingleSentencePlaylistMode == playerState.playlistMode &&
          _lastSingleSentenceIndex != null) {
        final previousIndex = _lastSingleSentenceIndex!;
        _singleSentenceTransitionDirection = index > previousIndex
            ? 1
            : index < previousIndex
            ? -1
            : 0;
      } else {
        _singleSentenceTransitionDirection = 0;
      }
      _lastSingleSentenceContentId = contentId;
      _lastSingleSentencePlaylistMode = playerState.playlistMode;
      _lastSingleSentenceIndex = index;
    }

    return GestureDetector(
      key: kPlayerSingleSentenceSwipeAreaKey,
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) =>
          _handleSingleSentenceSwipe(details, playerState, controller),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 序号 + 时间区间（弱化辅助信息）
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
            // 难句标记行（复用精听）—— 不被遮蔽，盲听时仍可标记
            BookmarkToggleRow(
              isDifficult: isBookmarked,
              onTap: () => controller.toggleBookmark(currentSentence.index),
            ),
            const SizedBox(height: AppSpacing.m),
            // 精听解析内容 + 隐藏字幕遮罩。切句时做轻量滑动过渡，降低跳变感。
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                transitionBuilder: (child, animation) {
                  final page = child is _SingleSentenceAnimatedPage
                      ? child
                      : _SingleSentenceAnimatedPage(direction: 0, child: child);
                  final beginOffset = switch (page.direction) {
                    1 => const Offset(0.1, 0),
                    -1 => const Offset(-0.1, 0),
                    _ => const Offset(0, 0),
                  };
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: beginOffset,
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: page.child,
                    ),
                  );
                },
                child: _SingleSentenceAnimatedPage(
                  key: ValueKey(contentId),
                  direction: _singleSentenceTransitionDirection,
                  child: Stack(
                    children: [
                      AnnotationContentView(
                        // 切句时重建，确保 AnnotationContentView 内部意群等状态重置
                        key: ValueKey(currentSentence.index),
                        text: currentSentence.text,
                        aiNotifier: ref.read(sentenceAiNotifierProvider),
                        audioItemId: audioItem.id,
                        sentenceIndex: currentSentence.index,
                        sentenceStartMs:
                            currentSentence.startTime.inMilliseconds,
                        sentenceEndMs: currentSentence.endTime.inMilliseconds,
                        // 意群试听与主播放共用引擎，播放前先暂停主播放
                        onStopMainPlayer: () => controller.pause(),
                      ),
                      // 隐藏字幕遮罩：覆盖整个内容区（含工具栏），模糊且不可点击
                      if (!settings.showTranscript)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.05),
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
          ],
        ),
      ),
    );
  }

  void _handleSingleSentenceSwipe(
    DragEndDetails details,
    ListeningPracticeState playerState,
    ListeningPractice controller,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _singleSentenceSwipeVelocityThreshold) {
      return;
    }
    if (velocity < 0) {
      if (playerState.playlistMode == PlaylistMode.bookmarks) {
        final currentIndex = playerState.currentBookmarkIndex;
        final bookmarked = playerState.bookmarkedSentences;
        final currentPos = currentIndex == null
            ? -1
            : bookmarked.indexWhere((s) => s.index == currentIndex);
        if (currentPos >= bookmarked.length - 1) {
          return;
        }
      } else if ((playerState.currentFullIndex ?? 0) >=
          playerState.sentences.length - 1) {
        return;
      }
      unawaited(controller.nextSentence());
      return;
    }

    if (playerState.playlistMode == PlaylistMode.bookmarks) {
      final currentIndex = playerState.currentBookmarkIndex;
      final bookmarked = playerState.bookmarkedSentences;
      final currentPos = currentIndex == null
          ? -1
          : bookmarked.indexWhere((s) => s.index == currentIndex);
      if (currentPos <= 0) {
        return;
      }
    } else if ((playerState.currentFullIndex ?? 0) <= 0) {
      return;
    }
    unawaited(controller.previousSentence());
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
          final position =
              _seekPreviewPosition ?? snapshot.data ?? Duration.zero;
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
      mainAxisSize: MainAxisSize.min,
      children: [
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
        // 倍速
        const SizedBox(width: 12),
        Text('${playerState.settings.playbackSpeed}x', style: captionStyle),
        // 整篇循环徽标
        if (playerState.settings.loopWhole) ...[
          const SizedBox(width: 12),
          _buildLoopBadge(
            icon: Icons.repeat,
            count: playerState.settings.wholeLoopCount,
            iconColor: iconColor,
            captionStyle: captionStyle,
          ),
        ],
        // 单句循环徽标
        if (playerState.settings.loopSentence) ...[
          const SizedBox(width: 12),
          _buildLoopBadge(
            icon: Icons.repeat_one,
            count: playerState.settings.sentenceLoopCount,
            iconColor: iconColor,
            captionStyle: captionStyle,
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
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
  Widget _buildLoopBadge({
    required IconData icon,
    required int count,
    required Color iconColor,
    required TextStyle? captionStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 3),
        Text(count == 0 ? '∞' : 'x$count', style: captionStyle),
      ],
    );
  }
}

class _SingleSentenceAnimatedPage extends StatelessWidget {
  final int direction;
  final Widget child;

  const _SingleSentenceAnimatedPage({
    super.key,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../l10n/app_localizations.dart';
import '../models/playback_settings.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/collection_provider.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/playback_controls.dart';
import '../widgets/sleep_timer.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/common/audio_app_bar_title.dart';
import '../widgets/common/free_player_sentence_pager.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/study/study_activity_detector.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import 'sentence_detail_screen.dart';

const kPlayerSingleSentenceSwipeAreaKey = kFullSingleSentenceSwipeAreaKey;
const kPlayerBookmarkSingleSentenceSwipeAreaKey =
    kBookmarkSingleSentenceSwipeAreaKey;
const kPlayerInfoBarStatusRowKey = ValueKey('player-info-bar-status-row');

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final ListeningPractice _notifier;
  late final int _studyPageGeneration;

  // 两个常驻 tab 各自持有分页控制器，避免切换列表时覆盖另一分页器的状态。
  final _fullSentencePagerController = FreePlayerSentencePagerController();
  final _bookmarkSentencePagerController = FreePlayerSentencePagerController();

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
    _studyPageGeneration = _notifier.beginStudyPage();
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
    // 计时器同步释放：provider 可能早于微任务销毁，残留计时器会导致泄漏。
    _notifier.releaseStudyTimer();
    // 页面销毁时同步启动幂等收尾（provider 仍挂载，暂停与保存在此完成）。
    unawaited(_notifier.finishStudyPage(generation: _studyPageGeneration));
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(listeningPracticeProvider);
    final controller = ref.read(listeningPracticeProvider.notifier);

    return StudyActivityDetector(
      onActivity: controller.markStudyActivity,
      child: LearningHotkeyScope(
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
    final audioItemId = playerState.currentAudioItem?.id;

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
      wordHighlightSource: audioItemId == null
          ? null
          : _wordHighlightSource(audioItemId),
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectFullSentence(s.index),
      onSentenceExplanationTap: _handleSentenceDetail,
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
    final audioItemId = playerState.currentAudioItem?.id;

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
      wordHighlightSource: audioItemId == null
          ? null
          : _wordHighlightSource(audioItemId),
      autoFocusEnabled: true,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      onSentencePlayFrom: (s) => controller.selectBookmarkedSentence(s.index),
      onSentenceExplanationTap: _handleSentenceDetail,
      onSentenceBookmarkToggle: (s) => controller.toggleBookmark(s.index),
    );
  }

  /// 用播放器无关的共享组件组装单句模式，音频 controller 行为保持不变。
  Widget _buildSingleSentenceView(
    ListeningPracticeState playerState,
    ListeningPractice controller,
    int index,
    PlaybackSettings settings,
    PlaylistMode mode,
  ) {
    final audioItem = playerState.currentAudioItem;
    if (audioItem == null) return const SizedBox.shrink();
    final isBookmarkMode = mode == PlaylistMode.bookmarks;
    final playable = isBookmarkMode
        ? playerState.bookmarkedSentences
        : playerState.sentences;
    return FreePlayerSentencePager(
      controller: isBookmarkMode
          ? _bookmarkSentencePagerController
          : _fullSentencePagerController,
      audioItem: audioItem,
      sentences: playable,
      currentSentenceIndex: index,
      bookmarkedSentenceIndices: playerState.bookmarkedIndices,
      showTranscript: settings.showTranscript,
      isPlaying: playerState.isPlaying,
      scope: isBookmarkMode
          ? FreePlayerSentenceScope.bookmarks
          : FreePlayerSentenceScope.full,
      actions: FreePlayerSentenceActions(
        onSentenceSelected: isBookmarkMode
            ? controller.selectBookmarkedSentence
            : controller.selectFullSentence,
        onBookmarkToggle: (sentenceIndex) =>
            controller.toggleBookmark(sentenceIndex),
        onStopMainPlayer: () => unawaited(controller.pause()),
        onToolbarButtonTapped: () =>
            unawaited(controller.pauseAfterCurrentSentence()),
      ),
      wordHighlightSource: _wordHighlightSource(audioItem.id),
    );
  }

  WordHighlightSource _wordHighlightSource(String audioItemId) {
    final engine = ref.read(audioEngineProvider.notifier);
    return WordHighlightSource(
      audioItemId: audioItemId,
      positionStream: engine.absolutePositionStream,
      currentPosition: engine.absoluteCurrentPosition,
      playbackStatus: engine.wordHighlightPlaybackStatus,
      playbackStatusStream: engine.wordHighlightPlaybackStatusStream,
    );
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

    AppLogger.log(
      'Navigation',
      'player push sentence-detail audio=${audioItem.id} '
          'sentence=${sentence.index}',
    );
    await AppRoutes.pushNested(
      context,
      AppRoutes.sentenceDetailSegment,
      extra: SentenceDetailArgs(
        audioItemId: audioItem.id,
        audioName: audioItem.name,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
        wordHighlightSource: _wordHighlightSource(audioItem.id),
      ),
    );
    AppLogger.log(
      'Navigation',
      'player returned from sentence-detail audio=${audioItem.id} '
          'sentence=${sentence.index} mounted=$mounted',
    );

    _isNavigatingToDetail = false;

    if (!mounted) return;
    // 讲解页试听旁路驱动并 stop 了共享引擎，会改写 clip/position。返回后显式把
    // 引擎对齐回当前句起点，使主播放按钮从「原来的句子」继续，而非跳第一句。
    await controller.restorePosition();
    // 返回后刷新收藏状态（讲解页可能修改了收藏）
    await controller.syncBookmarks();
  }

  /// 点击左侧讲解按钮进入讲解页时，先把播放器真相源同步到被点句。
  ///
  /// 句子正文负责“从这句播放”；打开讲解时只切换焦点并保持暂停，避免返回列表时
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
            top: false,
            bottom: true,
            maintainBottomViewPadding: true,
            minimum: const EdgeInsets.only(bottom: AppSpacing.s),
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
            // 使用不透明的容器色绘制未播放轨道，避免低透明度边缘抗锯齿
            // 造成其视觉上比已播放轨道更细。
            baseBarColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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

    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, 0),
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

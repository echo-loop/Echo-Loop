import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../models/listening_practice_state.dart';
import '../models/media_playback_state.dart';
import '../models/playback_settings.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../models/word_highlight_binding.dart';
import '../providers/collection_provider.dart';
import '../providers/media_engine/media_engine_provider.dart';
import '../providers/media_playback/media_playback_provider.dart';
import '../providers/media_playback/media_sleep_timer_provider.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import '../services/media_fullscreen_service.dart';
import '../theme/app_theme.dart';
import '../utils/playback_speed.dart';
import '../widgets/common/anchored_bubble.dart';
import '../widgets/common/audio_app_bar_title.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/common/free_player_sentence_pager.dart';
import '../widgets/common/media_visual_surface.dart';
import '../widgets/common/managed_media_visual_surface.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/study/study_activity_detector.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sleep_timer.dart';
import 'sentence_detail_screen.dart';

/// media_kit 随心听页面。
///
/// 音频与视频共用页面、播放控制和媒体会话，仅视频材料渲染画面。
class MediaPlaybackScreen extends ConsumerStatefulWidget {
  const MediaPlaybackScreen({super.key, required this.audioItem});

  final AudioItem audioItem;

  @override
  ConsumerState<MediaPlaybackScreen> createState() =>
      _MediaPlaybackScreenState();
}

class _MediaPlaybackScreenState extends ConsumerState<MediaPlaybackScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  /// 单列播放器控制区的紧凑基准高度。
  ///
  /// 双栏复用同一基准，避免宽屏时把视频下方的控制区人为拉高。
  static const _singleColumnControlPanelHeight = 176.0;
  static const _progressTimeLabelWidth = 48.0;

  late final TabController _playlistViewController;
  final _fullSentencePagerController = FreePlayerSentencePagerController();
  final _bookmarkSentencePagerController = FreePlayerSentencePagerController();
  late final MediaPlayback _controller;
  late final int _studyPageGeneration;
  late final MediaSleepTimer _sleepTimer;
  late final MediaFullscreenService _fullscreenService;
  late final StreamSubscription<bool> _fullscreenSubscription;
  ModalRoute<void>? _observedRoute;
  AppLifecycleListener? _lifecycle;
  Duration? _seekPreviewPosition;
  int _seekPreviewToken = 0;
  int _focusRestoreRevision = 0;
  bool _isProgressDragging = false;
  bool _routeVisible = true;
  bool _isNavigatingToDetail = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(mediaPlaybackProvider.notifier);
    _studyPageGeneration = _controller.beginStudyPage();
    _sleepTimer = ref.read(mediaSleepTimerProvider.notifier);
    _fullscreenService = MediaFullscreenService();
    _fullscreenSubscription = _fullscreenService.changes.listen((expanded) {
      if (!mounted) return;
      unawaited(_controller.setVisualTrackExpanded(expanded));
    });
    _playlistViewController = TabController(length: 2, vsync: this);
    _lifecycle = AppLifecycleListener(onStateChange: _handleLifecycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _observedRoute)) return;
    if (_observedRoute != null) {
      rootRouteObserver.unsubscribe(this);
    }
    _observedRoute = route;
    rootRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (!mounted || !_routeVisible) return;
    setState(() => _routeVisible = false);
  }

  @override
  void didPopNext() {
    // 返回播放器时要求活动字幕列表按最新当前句立即定位。
    if (!mounted) return;
    setState(() {
      _routeVisible = true;
      _focusRestoreRevision += 1;
    });
  }

  void _handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_controller.handleLifecycleHidden());
      case AppLifecycleState.resumed:
        unawaited(_controller.handleLifecycleResumed());
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        unawaited(_fullscreenService.exit());
        unawaited(
          _controller.releaseFromScreen(
            studyPageGeneration: _studyPageGeneration,
          ),
        );
    }
  }

  Future<void> _setVisualTrackExpanded(bool expanded) async {
    if (expanded) {
      await _fullscreenService.enter(
        isLandscapeVideo:
            ref.read(mediaPlaybackProvider).isLandscapeVideo ?? false,
      );
      return;
    }
    await _fullscreenService.exit();
  }

  @override
  void dispose() {
    if (_observedRoute != null) {
      rootRouteObserver.unsubscribe(this);
    }
    _lifecycle?.dispose();
    unawaited(_fullscreenSubscription.cancel());
    unawaited(_releaseFullscreen());
    _playlistViewController.dispose();
    _scheduleStudyPageFinish();
    scheduleMicrotask(_sleepTimer.cancel);
    super.dispose();
  }

  /// 销毁兜底在当前生命周期结束后执行，避免暂停或清空状态时修改构建中的 provider。
  ///
  /// 捕获当前页面代际，防止延迟任务释放新页面；后台收尾没有调用方等待，
  /// 因此必须记录并接住异常，避免释放失败变成未处理的异步异常。
  void _scheduleStudyPageFinish() {
    final controller = _controller;
    final generation = _studyPageGeneration;
    scheduleMicrotask(() async {
      try {
        await controller.finishStudyPage(generation: generation);
      } catch (error, stackTrace) {
        AppLogger.log(
          'StudyExit',
          'media dispose cleanup failed generation=$generation '
              'error=$error\n$stackTrace',
        );
      }
    });
  }

  Future<void> _releaseFullscreen() async {
    await _fullscreenService.exit();
    await _fullscreenService.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaPlaybackProvider);
    final l10n = AppLocalizations.of(context)!;
    return StudyActivityDetector(
      onActivity: _controller.markStudyActivity,
      child: LearningHotkeyScope(
        onPlayPause: () => state.isPlaying
            ? unawaited(_controller.pause())
            : unawaited(_controller.play()),
        onPrevious: () =>
            unawaited(_handleSentenceNavigation(-1, trigger: 'hotkey')),
        onNext: () =>
            unawaited(_handleSentenceNavigation(1, trigger: 'hotkey')),
        child: Scaffold(
          backgroundColor: widget.audioItem.isVideo && state.visualTrackExpanded
              ? Colors.black
              : null,
          appBar: widget.audioItem.isVideo && state.visualTrackExpanded
              ? null
              : AppBar(
                  titleSpacing: 0,
                  title: _buildAppBarTitle(state, l10n),
                  actions: const [SleepTimerButton.mediaPlayback()],
                ),
          body: ManagedMediaVisualSurface(
            loadKey: widget.audioItem.id,
            load: () => _controller.load(widget.audioItem),
            cancel: _controller.cancelLoad,
            showVideoLoading: widget.audioItem.isVideo,
            child: DictionaryPanelHost(
              handleBackButton: true,
              child: _buildBody(context, state, l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(MediaPlaybackState state, AppLocalizations l10n) {
    final loadedItem = state.audioItem;
    final item = loadedItem != null && loadedItem.id == widget.audioItem.id
        ? loadedItem
        : widget.audioItem;
    final collectionNames = ref.watch(
      collectionListProvider.select((s) {
        final ids = s.audioToCollectionsMap[item.id] ?? const <String>[];
        if (ids.isEmpty) return const <String>[];
        final idSet = ids.toSet();
        return s.collections
            .where((c) => idSet.contains(c.id))
            .map((c) => c.name)
            .toList(growable: false);
      }),
    );
    return AudioAppBarTitle(
      audioName: item.name.isEmpty ? l10n.player : item.name,
      collectionNames: collectionNames,
    );
  }

  Widget _buildBody(
    BuildContext context,
    MediaPlaybackState state,
    AppLocalizations l10n,
  ) {
    final hasVideoTrack = widget.audioItem.isVideo;
    if (hasVideoTrack && state.visualTrackExpanded) {
      return _buildMediaVisualSurface(state);
    }

    if (!hasVideoTrack) {
      return Column(
        key: const ValueKey('media-playback-audio-layout'),
        children: [
          Expanded(child: _buildTranscriptView(context, state, l10n)),
          _buildControlPanel(context, state),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWideLayout = _useWideMediaLayout(constraints, state);
        if (!useWideLayout) {
          return Column(
            key: const ValueKey('media-playback-single-layout'),
            children: [
              _buildMediaVisualSurface(state),
              const _MediaContentDivider(),
              Expanded(child: _buildTranscriptView(context, state, l10n)),
              _buildControlPanel(context, state),
            ],
          );
        }

        return Row(
          key: const ValueKey('media-playback-wide-layout'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: _buildMediaVisualSurface(
                      state,
                      fillAvailableHeight: true,
                    ),
                  ),
                  _buildControlPanel(
                    context,
                    state,
                    minimumHeight: _singleColumnControlPanelHeight,
                    compact: true,
                  ),
                ],
              ),
            ),
            const _MediaContentDivider(vertical: true),
            Expanded(
              flex: 2,
              child: _buildTranscriptView(context, state, l10n),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaVisualSurface(
    MediaPlaybackState state, {
    bool fillAvailableHeight = false,
  }) {
    // 讲解子路由正在显示同一个 media_kit 会话时，父路由不再同时创建第二个
    // Video 纹理；但必须保留同尺寸黑色画布，避免路由交接首帧露出下方字幕区。
    // 返回后由本页面恢复唯一画面宿主。
    if (_isNavigatingToDetail) {
      return _MediaVisualHandoffCanvas(
        fillAvailableHeight: fillAvailableHeight,
        expanded: state.visualTrackExpanded,
      );
    }
    final controller = ref.read(mediaPlaybackProvider.notifier);
    return MediaVisualSurface(
      state: MediaVisualSurfaceState(
        visible: state.visualTrackVisible,
        expanded: state.visualTrackExpanded,
        isPlaying: state.isPlaying,
        subtitleVisible: state.videoSubtitleVisible,
      ),
      actions: MediaVisualSurfaceActions(
        onShow: () => unawaited(controller.setVisualTrackVisible(true)),
        onHide: () => unawaited(controller.setVisualTrackVisible(false)),
        onPlayPause: () =>
            unawaited(state.isPlaying ? controller.pause() : controller.play()),
        onSubtitleToggle: () => unawaited(
          controller.setVideoSubtitleVisible(!state.videoSubtitleVisible),
        ),
        onFullscreenToggle: () =>
            unawaited(_setVisualTrackExpanded(!state.visualTrackExpanded)),
      ),
      fillAvailableHeight: fillAvailableHeight,
      buildVideoView: (size) => ref
          .read(mediaEngineProvider.notifier)
          .buildVideoView(viewportSize: size),
    );
  }

  /// 根据页面实际可用空间决定是否采用视频与字幕双栏。
  ///
  /// 此策略刻意只存在于 UI 层：窗口缩放不应影响媒体会话、播放进度或字幕状态。
  /// 画面可见时，仅按实际内容区宽高比决定布局，避免等待字幕异步加载后再跳变。
  bool _useWideMediaLayout(
    BoxConstraints constraints,
    MediaPlaybackState state,
  ) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    return state.visualTrackVisible &&
        width.isFinite &&
        height.isFinite &&
        height > 0 &&
        width / height > 1;
  }

  Widget _buildTranscriptView(
    BuildContext context,
    MediaPlaybackState state,
    AppLocalizations l10n,
  ) {
    final controller = ref.read(mediaPlaybackProvider.notifier);
    final isTranscriptPending =
        state.audioItem?.id != widget.audioItem.id || state.isTranscriptLoading;
    if (isTranscriptPending) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('media-transcript-loading-indicator'),
        ),
      );
    }
    if (!state.hasSentences) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              l10n.noTranscript,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_playlistViewController.index != state.playlistMode.index) {
      _playlistViewController.index = state.playlistMode.index;
    }

    // 保留原有 TabBarView/PageView 的列表保活、自动聚焦和命中测试
    // 行为；只移除可见 TabBar，由底部按钮驱动 playlistMode。
    return TabBarView(
      controller: _playlistViewController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSentencePane(
          state,
          state.sentences,
          state.currentFullIndex,
          PlaylistMode.full,
          (s) => controller.selectFullSentence(s.index),
          pagerController: _fullSentencePagerController,
        ),
        _buildBookmarkPane(state, l10n),
      ],
    );
  }

  Widget _buildBookmarkPane(MediaPlaybackState state, AppLocalizations l10n) {
    final bookmarked = state.bookmarkedSentences;
    if (bookmarked.isEmpty) {
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
    final playingLocalIndex = bookmarked.indexWhere(
      (s) => s.index == state.currentBookmarkIndex,
    );
    final controller = ref.read(mediaPlaybackProvider.notifier);
    return _buildSentencePane(
      state,
      bookmarked,
      state.currentBookmarkIndex,
      PlaylistMode.bookmarks,
      (s) => controller.selectBookmarkedSentence(s.index),
      playingLocalIndex: playingLocalIndex,
      pagerController: _bookmarkSentencePagerController,
    );
  }

  /// 为随心听字幕和句子详情提供共用的 MediaEngine 播放时间轴。
  WordHighlightSource _wordHighlightSource(
    String audioItemId, {
    String? debugLabel,
  }) {
    final engine = ref.read(mediaEngineProvider.notifier);
    return WordHighlightSource(
      audioItemId: audioItemId,
      positionStream: engine.wordHighlightPositionStream,
      currentPosition: engine.wordHighlightPosition,
      playbackStatus: engine.wordHighlightPlaybackStatus,
      playbackStatusStream: engine.wordHighlightPlaybackStatusStream,
      debugLabel: debugLabel,
    );
  }

  Widget _buildSentencePane(
    MediaPlaybackState state,
    List<Sentence> sentences,
    int? currentSentenceIndex,
    PlaylistMode mode,
    ValueChanged<Sentence> onPlayFrom, {
    int? playingLocalIndex,
    required FreePlayerSentencePagerController pagerController,
  }) {
    final controller = ref.read(mediaPlaybackProvider.notifier);
    final settings = mode == PlaylistMode.bookmarks
        ? state.bookmarkSettings
        : state.fullSettings;
    final audioItem = state.audioItem ?? widget.audioItem;
    final isBookmarkMode = mode == PlaylistMode.bookmarks;
    final showSingleSentence =
        settings.singleSentenceMode && currentSentenceIndex != null;
    final wordHighlightSource = _wordHighlightSource(
      audioItem.id,
      debugLabel: showSingleSentence ? null : 'free-player-list-${mode.name}',
    );
    final resolvedPlayingLocalIndex =
        playingLocalIndex ?? currentSentenceIndex ?? -1;

    final singleSentencePane = FreePlayerSentencePager(
      key: PageStorageKey('media-single-sentence-${audioItem.id}-${mode.name}'),
      controller: pagerController,
      audioItem: audioItem,
      sentences: sentences,
      currentSentenceIndex: currentSentenceIndex ?? 0,
      bookmarkedSentenceIndices: state.bookmarkedIndices,
      showTranscript: settings.showTranscript,
      isPlaying: state.isPlaying,
      scope: isBookmarkMode
          ? FreePlayerSentenceScope.bookmarks
          : FreePlayerSentenceScope.full,
      actions: FreePlayerSentenceActions(
        onSentenceSelected: isBookmarkMode
            ? controller.selectBookmarkedSentence
            : controller.selectFullSentence,
        onBookmarkToggle: _handleBookmarkToggle,
        onStopMainPlayer: () => unawaited(controller.pause()),
        onToolbarButtonTapped: () =>
            unawaited(controller.pauseAfterCurrentSentence()),
      ),
      wordHighlightSource: wordHighlightSource,
    );
    final listPane = ParagraphSentenceListCard(
      key: ValueKey('media-sentence-list-${audioItem.id}-${mode.name}'),
      sentences: sentences,
      displayMode: state.settings.showTranscript
          ? RetellDisplayMode.showAll
          : RetellDisplayMode.hideAll,
      keywordMap: const {},
      playingSentenceIndex: resolvedPlayingLocalIndex,
      wordHighlightSource: wordHighlightSource,
      autoFocusEnabled: true,
      focusActive:
          !showSingleSentence &&
          _routeVisible &&
          !_isProgressDragging &&
          mode == state.playlistMode,
      focusRequestRevision: state.sentenceFocusRevision,
      focusReason: state.sentenceFocusReason,
      focusRestoreRevision: _focusRestoreRevision,
      directInitialPositioning: true,
      preserveScrollPositionOnReactivation: true,
      bookmarkedSentenceIndices: state.bookmarkedIndices,
      onSentencePlayFrom: onPlayFrom,
      onSentenceExplanationTap: _handleSentenceDetail,
      onSentenceBookmarkToggle: (s) => _handleBookmarkToggle(s.index),
    );

    return _MediaSentencePaneSwitcher(
      key: ValueKey('media-sentence-pane-${audioItem.id}-${mode.name}'),
      showList: !showSingleSentence,
      listPane: listPane,
      singleSentencePane: singleSentencePane,
    );
  }

  /// 收藏模式删除最后一条时，controller 会回到全文；页面只负责
  /// 给出一次可见反馈，避免用户对列表突然切换感到困惑。
  Future<void> _handleBookmarkToggle(int index) async {
    final before = ref.read(mediaPlaybackProvider);
    await ref.read(mediaPlaybackProvider.notifier).toggleBookmark(index);
    if (!mounted) return;
    final after = ref.read(mediaPlaybackProvider);
    if (before.playlistMode == PlaylistMode.bookmarks &&
        before.bookmarkedSentences.length == 1 &&
        after.playlistMode == PlaylistMode.full &&
        after.bookmarkedSentences.isEmpty) {
      _showBookmarkFallbackSnackBar();
    }
  }

  void _showBookmarkFallbackSnackBar() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.bookmarksEmptyReturned),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// 点击字幕正文后暂停媒体，进入嵌套句子讲解页；返回时恢复媒体侧状态。
  Future<void> _handleSentenceDetail(Sentence sentence) async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;
    if (mounted) setState(() {});
    final controller = ref.read(mediaPlaybackProvider.notifier);

    try {
      final returnPosition = await controller.prepareSentenceDetail();
      if (!mounted) return;

      AppLogger.log(
        'Navigation',
        'media-player push sentence-detail audio=${widget.audioItem.id} '
            'sentence=${sentence.index}',
      );
      await AppRoutes.pushNested(
        context,
        AppRoutes.sentenceDetailSegment,
        extra: SentenceDetailArgs(
          audioItemId: widget.audioItem.id,
          audioName: widget.audioItem.name,
          sentenceText: sentence.text,
          sentenceIndex: sentence.index,
          totalSentenceCount: ref.read(mediaPlaybackProvider).sentences.length,
          startTimeMs: sentence.startTime.inMilliseconds,
          endTimeMs: sentence.endTime.inMilliseconds,
          rangePlayback: controller.senseGroupRangePlayback,
          wordHighlightSource: _wordHighlightSource(widget.audioItem.id),
          mediaSession: widget.audioItem.isVideo
              ? SentenceDetailMediaSession(
                  readState: () => ref.read(mediaPlaybackProvider),
                  setVisible: controller.setVisualTrackVisible,
                  setSubtitleVisible: controller.setVideoSubtitleVisible,
                  setFullscreen: _setVisualTrackExpanded,
                  buildVideoView: (size) => ref
                      .read(mediaEngineProvider.notifier)
                      .buildVideoView(viewportSize: size),
                )
              : null,
        ),
      );
      if (!mounted) return;

      AppLogger.log(
        'Navigation',
        'media-player returned from sentence-detail '
            'audio=${widget.audioItem.id} sentence=${sentence.index}',
      );
      final modeBeforeRestore = ref.read(mediaPlaybackProvider).playlistMode;
      await controller.restoreAfterSentenceDetail(returnPosition);
      if (mounted &&
          modeBeforeRestore == PlaylistMode.bookmarks &&
          ref.read(mediaPlaybackProvider).playlistMode == PlaylistMode.full) {
        _showBookmarkFallbackSnackBar();
      }
    } finally {
      _isNavigatingToDetail = false;
      if (mounted) setState(() {});
    }
  }

  Widget _buildControlPanel(
    BuildContext context,
    MediaPlaybackState state, {
    double? minimumHeight,
    bool compact = false,
  }) {
    final controls = _MediaControls(
      state: state,
      compact: compact,
      onPrevious: () =>
          unawaited(_handleSentenceNavigation(-1, trigger: 'button')),
      onNext: () => unawaited(_handleSentenceNavigation(1, trigger: 'button')),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minimumHeight ?? 0),
      child: Container(
        key: const ValueKey('media-control-panel'),
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
              _buildProgressBar(state),
              controls,
              _MediaInfoBar(state: state),
            ],
          ),
        ),
      ),
    );
  }

  /// 将页面内的上一句/下一句统一路由到当前播放列表的单句分页器。
  Future<void> _handleSentenceNavigation(
    int offset, {
    required String trigger,
  }) async {
    final state = ref.read(mediaPlaybackProvider);
    final direction = offset < 0 ? 'previous' : 'next';
    final currentPosition = state.currentPlayablePosition;
    final sourceIndex =
        currentPosition == null ||
            currentPosition < 0 ||
            currentPosition >= state.playableSentences.length
        ? null
        : state.playableSentences[currentPosition].index;
    AppLogger.log(
      'FreePlayerNavigation',
      'request trigger=$trigger item=${state.audioItem?.id ?? widget.audioItem.id} '
          'playlist=${state.playlistMode.name} direction=$direction '
          'from=$sourceIndex isPlaying=${state.isPlaying} '
          'singleSentence=${state.settings.singleSentenceMode}',
    );
    if (!state.hasSentences) {
      if (offset < 0) {
        await _controller.previousSentence();
      } else {
        await _controller.nextSentence();
      }
      return;
    }
    if (!state.settings.singleSentenceMode) {
      if (offset < 0) {
        await _controller.previousSentence();
      } else {
        await _controller.nextSentence();
      }
      return;
    }

    final sentences = state.playableSentences;
    if (currentPosition == null) {
      AppLogger.log(
        'FreePlayerNavigation',
        'ignored trigger=$trigger reason=no_current_position direction=$direction',
      );
      return;
    }
    final targetPosition = currentPosition + offset;
    if (targetPosition < 0 || targetPosition >= sentences.length) {
      AppLogger.log(
        'FreePlayerNavigation',
        'ignored trigger=$trigger reason=boundary direction=$direction '
            'from=$sourceIndex targetPosition=$targetPosition '
            'playableCount=${sentences.length}',
      );
      return;
    }
    final targetIndex = sentences[targetPosition].index;
    AppLogger.log(
      'FreePlayerNavigation',
      'target trigger=$trigger direction=$direction from=$sourceIndex '
          'to=$targetIndex autoPlay=${state.isPlaying}',
    );

    final pagerController = state.playlistMode == PlaylistMode.bookmarks
        ? _bookmarkSentencePagerController
        : _fullSentencePagerController;
    await pagerController.animateToSentence(
      sentences[targetPosition].index,
      autoPlay: state.isPlaying,
    );
  }

  Widget _buildProgressBar(MediaPlaybackState state) {
    final isPlaybackPending =
        state.audioItem?.id != widget.audioItem.id || state.isLoading;
    if (isPlaybackPending) {
      return const SizedBox(
        key: ValueKey('media-progress-placeholder'),
        height: 36,
      );
    }
    final controller = ref.read(mediaPlaybackProvider.notifier);
    final progress = _seekPreviewPosition ?? state.position;
    final total = state.duration ?? Duration.zero;
    final labelStyle = AppTextStyles.caption(
      context,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            key: const ValueKey('media-progress-elapsed-slot'),
            width: _progressTimeLabelWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                _formatMediaTime(progress),
                key: const ValueKey('media-progress-elapsed-label'),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
          ),
          Expanded(
            // audio_video_progress_bar 会先更新 progress 再更新 total。若进度先于
            // 总时长到达，内部会把进度钳成 0；总时长变化时重建 render object，
            // 让它用同一帧的完整数据计算滑块比例。
            child: KeyedSubtree(
              key: ValueKey('media-progress-total-${total.inMilliseconds}'),
              child: ProgressBar(
                key: const ValueKey('media-progress-bar'),
                progress: progress,
                total: total,
                onDragStart: (details) {
                  _seekPreviewToken += 1;
                  setState(() {
                    _isProgressDragging = true;
                    _seekPreviewPosition = details.timeStamp;
                  });
                },
                onDragUpdate: (details) =>
                    _updateSeekPreview(details.timeStamp),
                onSeek: (duration) {
                  final token = ++_seekPreviewToken;
                  setState(() => _seekPreviewPosition = duration);
                  unawaited(_settleSeekPreview(token, duration, controller));
                },
                barHeight: 3,
                thumbRadius: 8,
                thumbGlowRadius: 14,
                timeLabelLocation: TimeLabelLocation.none,
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('media-progress-remaining-slot'),
            width: _progressTimeLabelWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                _formatRemainingMediaTime(progress: progress, total: total),
                key: const ValueKey('media-progress-remaining-label'),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: labelStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateSeekPreview(Duration position) {
    if (_seekPreviewPosition == position) return;
    setState(() => _seekPreviewPosition = position);
  }

  Future<void> _settleSeekPreview(
    int token,
    Duration target,
    MediaPlayback controller,
  ) async {
    await controller.seekAbsolute(target);
    if (!mounted || token != _seekPreviewToken) return;
    setState(() {
      _isProgressDragging = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || token != _seekPreviewToken) return;
    setState(() => _seekPreviewPosition = null);
  }
}

/// 父子路由交接同一个视频纹理时的临时黑色画布。
///
/// [MediaVisualSurface] 不能在两个路由树中同时挂载同一纹理；交接期间父页以
/// 相同的布局尺寸保留黑色观看区域，避免用户误以为先回到了纯字幕列表。
class _MediaVisualHandoffCanvas extends StatelessWidget {
  const _MediaVisualHandoffCanvas({
    required this.fillAvailableHeight,
    required this.expanded,
  });

  final bool fillAvailableHeight;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        final preferredHeight = width / (16 / 9);
        final height = expanded || fillAvailableHeight
            ? maxHeight
            : preferredHeight
                  .clamp(0.0, maxHeight < 260 ? maxHeight : 260.0)
                  .toDouble();
        return SizedBox(
          key: const ValueKey('media-visual-handoff-canvas'),
          width: double.infinity,
          height: height,
          child: const ColoredBox(color: Colors.black),
        );
      },
    );
  }
}

/// 在视频画面和字幕阅读区之间提供不占空间的细分割线。
class _MediaContentDivider extends StatelessWidget {
  const _MediaContentDivider({this.vertical = false});

  static const _opacity = 0.45;

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('media-visual-transcript-divider'),
      height: vertical ? double.infinity : 1,
      width: vertical ? 1 : double.infinity,
      color: colorScheme.outlineVariant.withValues(alpha: _opacity),
    );
  }
}

String _formatMediaTime(Duration value) {
  final safe = value < Duration.zero ? Duration.zero : value;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatRemainingMediaTime({
  required Duration progress,
  required Duration total,
}) {
  final remaining = total - progress;
  return '-${_formatMediaTime(remaining)}';
}

class _MediaControls extends ConsumerWidget {
  const _MediaControls({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  static const double _controlButtonSize = 56;
  static const double _mainControlGap = 48;
  static const double _compactControlGap = 12;

  final MediaPlaybackState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(mediaPlaybackProvider.notifier);
    final isMobile = compact || MediaQuery.sizeOf(context).width < 600;
    final compactControlGap = MediaQuery.sizeOf(context).width <= 360
        ? 4.0
        : _compactControlGap;
    if (!state.hasSentences) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isMobile ? 0 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MediaSpeedButton(),
                SizedBox(width: 12),
                _MediaLoopButton(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _navButton(Icons.replay_10, onPrevious),
                const SizedBox(width: _mainControlGap),
                _playPauseButton(context, controller),
                const SizedBox(width: _mainControlGap),
                _navButton(Icons.forward_10, onNext),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 0 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _playlistModeButton(context, controller),
              SizedBox(width: compactControlGap),
              _toggleButton(
                context,
                icon: state.settings.singleSentenceMode
                    ? Icons.format_quote
                    : Icons.menu,
                key: const ValueKey('media-list-mode-toggle-button'),
                active: state.settings.singleSentenceMode,
                onPressed: () => controller.updateSettings(
                  state.settings.copyWith(
                    singleSentenceMode: !state.settings.singleSentenceMode,
                  ),
                ),
              ),
              SizedBox(width: compactControlGap),
              const _MediaSpeedButton(),
              SizedBox(width: compactControlGap),
              _toggleButton(
                context,
                icon: state.settings.showTranscript
                    ? Icons.visibility
                    : Icons.visibility_off,
                active: state.settings.showTranscript,
                onPressed: () => controller.updateSettings(
                  state.settings.copyWith(
                    showTranscript: !state.settings.showTranscript,
                  ),
                ),
              ),
              SizedBox(width: compactControlGap),
              const _MediaLoopButton(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _navButton(
                Icons.skip_previous,
                state.isFirstSentence ? null : onPrevious,
              ),
              const SizedBox(width: _mainControlGap),
              _playPauseButton(context, controller),
              const SizedBox(width: _mainControlGap),
              _navButton(Icons.skip_next, state.isLastSentence ? null : onNext),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playlistModeButton(BuildContext context, MediaPlayback controller) {
    final l10n = AppLocalizations.of(context)!;
    final isBookmarks = state.playlistMode == PlaylistMode.bookmarks;
    final bookmarkCount = state.bookmarkedSentences.length;
    final targetLabel = isBookmarks
        ? '${l10n.fullText} (${state.sentences.length})'
        : '${l10n.bookmarked} ($bookmarkCount)';
    final badgeLabel = bookmarkCount > 99 ? '99+' : '$bookmarkCount';
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      key: const ValueKey('media-playlist-mode-button'),
      tooltip: targetLabel,
      isSelected: isBookmarks,
      icon: Badge(
        isLabelVisible: bookmarkCount > 0,
        backgroundColor: AppTheme.bookmarkCountBadgeColor,
        textColor: AppTheme.bookmarkCountBadgeTextColor,
        label: Text(badgeLabel),
        child: const Icon(Icons.bookmarks_outlined),
      ),
      selectedIcon: Badge(
        isLabelVisible: bookmarkCount > 0,
        backgroundColor: AppTheme.bookmarkCountSelectedBadgeColor,
        textColor: AppTheme.bookmarkCountSelectedBadgeTextColor,
        label: Text(badgeLabel),
        child: const Icon(Icons.bookmarks, color: AppTheme.bookmarkColor),
      ),
      color: colorScheme.onSurface.withValues(alpha: 0.6),
      style: isBookmarks
          ? IconButton.styleFrom(
              foregroundColor: colorScheme.primary,
              backgroundColor: colorScheme.primaryContainer,
            )
          : null,
      onPressed: () {
        if (!isBookmarks && bookmarkCount == 0) {
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.noBookmarksHint),
                duration: const Duration(seconds: 3),
              ),
            );
          return;
        }
        unawaited(
          controller.setPlaylistMode(
            isBookmarks ? PlaylistMode.full : PlaylistMode.bookmarks,
          ),
        );
      },
    );
  }

  Widget _playPauseButton(BuildContext context, MediaPlayback controller) {
    return SizedBox.square(
      dimension: _controlButtonSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 36,
          color: Theme.of(context).colorScheme.onPrimary,
          onPressed: () => state.isPlaying
              ? unawaited(controller.pause())
              : unawaited(controller.play()),
        ),
      ),
    );
  }

  static Widget _navButton(IconData icon, VoidCallback? onPressed) {
    return SizedBox.square(
      dimension: _controlButtonSize,
      child: IconButton(icon: Icon(icon), iconSize: 32, onPressed: onPressed),
    );
  }

  static Widget _toggleButton(
    BuildContext context, {
    required IconData icon,
    required bool active,
    required VoidCallback onPressed,
    Key? key,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = active
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.6);
    return IconButton(
      key: key,
      icon: Icon(icon),
      iconSize: 22,
      color: iconColor,
      style: active
          ? IconButton.styleFrom(backgroundColor: colorScheme.primaryContainer)
          : null,
      onPressed: onPressed,
    );
  }
}

/// 首次打开列表后保留其滚动状态；列表未曾显示时不提前创建单句之外的内容。
class _MediaSentencePaneSwitcher extends StatefulWidget {
  const _MediaSentencePaneSwitcher({
    super.key,
    required this.showList,
    required this.listPane,
    required this.singleSentencePane,
  });

  final bool showList;
  final Widget listPane;
  final Widget singleSentencePane;

  @override
  State<_MediaSentencePaneSwitcher> createState() =>
      _MediaSentencePaneSwitcherState();
}

class _MediaSentencePaneSwitcherState
    extends State<_MediaSentencePaneSwitcher> {
  late bool _hasShownList;

  @override
  void initState() {
    super.initState();
    _hasShownList = widget.showList;
  }

  @override
  void didUpdateWidget(covariant _MediaSentencePaneSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showList) _hasShownList = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasShownList) return widget.singleSentencePane;

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !widget.showList,
          child: TickerMode(enabled: widget.showList, child: widget.listPane),
        ),
        if (!widget.showList) widget.singleSentencePane,
      ],
    );
  }
}

class _MediaSpeedButton extends ConsumerStatefulWidget {
  const _MediaSpeedButton();

  @override
  ConsumerState<_MediaSpeedButton> createState() => _MediaSpeedButtonState();
}

class _MediaSpeedButtonState extends ConsumerState<_MediaSpeedButton> {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final speed = ref.watch(
      mediaPlaybackProvider.select((s) => s.settings.playbackSpeed),
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return AnchoredBubble(
      controller: _portalController,
      direction: BubbleDirection.up,
      width: 120,
      contentBuilder: (_) =>
          _MediaSpeedPopup(onSelected: _portalController.hide),
      child: TextButton(
        onPressed: _portalController.toggle,
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: color,
        ),
        child: Text(
          formatPlaybackSpeedLabel(speed),
          style: TextStyle(fontSize: 14, color: color),
        ),
      ),
    );
  }
}

class _MediaSpeedPopup extends ConsumerWidget {
  const _MediaSpeedPopup({required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mediaPlaybackProvider);
    final controller = ref.read(mediaPlaybackProvider.notifier);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final speed in kFreePlayerPlaybackSpeeds)
            BubbleMenuRow(
              label: formatPlaybackSpeedLabel(speed),
              selected: speed == state.settings.playbackSpeed,
              color: speed == state.settings.playbackSpeed
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              trailing: speed == state.settings.playbackSpeed
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  : null,
              onTap: () {
                controller.updateSettings(
                  state.settings.copyWith(playbackSpeed: speed),
                );
                onSelected();
              },
            ),
        ],
      ),
    );
  }
}

class _MediaLoopButton extends ConsumerStatefulWidget {
  const _MediaLoopButton();

  @override
  ConsumerState<_MediaLoopButton> createState() => _MediaLoopButtonState();
}

class _MediaLoopButtonState extends ConsumerState<_MediaLoopButton> {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(mediaPlaybackProvider.select((s) => s.settings));
    final active = settings.loopWhole || settings.loopSentence;
    final icon = settings.loopSentence && !settings.loopWhole
        ? Icons.repeat_one
        : Icons.repeat;
    final colorScheme = Theme.of(context).colorScheme;
    return AnchoredBubble(
      controller: _portalController,
      direction: BubbleDirection.up,
      width: 280,
      contentBuilder: (_) => const _MediaLoopPopup(),
      child: IconButton(
        icon: Icon(icon),
        iconSize: 22,
        color: active
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.6),
        style: active
            ? IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
              )
            : null,
        onPressed: _portalController.toggle,
      ),
    );
  }
}

class _MediaLoopPopup extends ConsumerWidget {
  const _MediaLoopPopup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mediaPlaybackProvider);
    final controller = ref.read(mediaPlaybackProvider.notifier);
    return LoopSettingsContent(
      settings: state.settings,
      hasSentences: state.hasSentences,
      onChanged: controller.updateSettings,
    );
  }
}

class _MediaInfoBar extends StatelessWidget {
  const _MediaInfoBar({required this.state});

  final MediaPlaybackState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mutedColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final captionStyle = AppTextStyles.caption(
      context,
    ).copyWith(color: mutedColor);
    final groupSpacing = MediaQuery.sizeOf(context).width <= 360 ? 4.0 : 12.0;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.hasSentences) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                key: const ValueKey('media-info-playlist-mode-icon'),
                state.playlistMode == PlaylistMode.bookmarks
                    ? Icons.bookmarks
                    : Icons.article,
                size: 14,
                color: mutedColor,
              ),
              const SizedBox(width: 3),
              Text(
                state.playlistMode == PlaylistMode.bookmarks
                    ? l10n.bookmarked
                    : l10n.fullText,
                style: captionStyle,
              ),
            ],
          ),
          SizedBox(width: groupSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.settings.singleSentenceMode)
                Icon(Icons.format_quote, size: 14, color: mutedColor)
              else
                Icon(
                  key: const ValueKey('media-info-sentence-mode-icon'),
                  Icons.menu,
                  size: 14,
                  color: mutedColor,
                ),
              const SizedBox(width: 3),
              Text(
                state.settings.singleSentenceMode
                    ? l10n.singleSentenceMode
                    : l10n.listMode,
                style: captionStyle,
              ),
            ],
          ),
          SizedBox(width: groupSpacing),
        ],
        Text(
          formatPlaybackSpeedLabel(state.settings.playbackSpeed),
          style: captionStyle,
        ),
        if (state.settings.loopWhole) ...[
          SizedBox(width: groupSpacing),
          _loopBadge(
            Icons.repeat,
            state.settings.wholeLoopCount,
            state.wholeLoopsDone,
            captionStyle,
            mutedColor,
          ),
        ],
        if (state.settings.loopSentence) ...[
          SizedBox(width: groupSpacing),
          _loopBadge(
            Icons.repeat_one,
            state.settings.sentenceLoopCount,
            state.sentenceRepeatsDone,
            captionStyle,
            mutedColor,
          ),
        ],
      ],
    );
    return Padding(
      key: const ValueKey('media-info-bar'),
      padding: EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, 0),
      child: Center(
        child: FittedBox(fit: BoxFit.scaleDown, child: row),
      ),
    );
  }

  Widget _loopBadge(
    IconData icon,
    int count,
    int done,
    TextStyle? style,
    Color color,
  ) {
    final label = count == 0
        ? '${done + 1}/∞'
        : '${(done + 1).clamp(1, count)}/$count';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: style),
      ],
    );
  }
}

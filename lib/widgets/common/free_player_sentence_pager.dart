import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/sentence_ai_prewarm.dart';
import '../../services/app_logger.dart';
import '../../services/subtitle_parser.dart';
import '../../theme/app_theme.dart';
import 'bookmark_toggle_row.dart';
import '../dictionary/dictionary_panel_host.dart';
import '../practice/practice_progress_section.dart';
import '../practice/sentence_explanation_view.dart';

const kFullSingleSentenceSwipeAreaKey = ValueKey(
  'player-single-sentence-swipe-area',
);
const kBookmarkSingleSentenceSwipeAreaKey = ValueKey(
  'player-bookmark-single-sentence-swipe-area',
);

/// 单句视图所在的播放列表，用于隔离全文与收藏两个分页器。
enum FreePlayerSentenceScope { full, bookmarks }

/// 页面外部控制单句分页的入口。
///
/// 页面内的上一句/下一句按钮通过此控制器完成卡片动画，再提交选句动作。
class FreePlayerSentencePagerController {
  _FreePlayerSentencePagerState? _state;

  void _attach(_FreePlayerSentencePagerState state) => _state = state;

  void _detach(_FreePlayerSentencePagerState state) {
    if (identical(_state, state)) _state = null;
  }

  /// 动画切换到全局句子索引后，按 [autoPlay] 提交选句动作。
  Future<void> animateToSentence(
    int sentenceIndex, {
    required bool autoPlay,
  }) async {
    await _state?.animateToSentence(sentenceIndex, autoPlay: autoPlay);
  }
}

/// 单句视图触发的播放器动作。
///
/// 组件只表达交互意图，不依赖 just_audio 或 media_kit 的 controller。
class FreePlayerSentenceActions {
  const FreePlayerSentenceActions({
    required this.onSentenceSelected,
    required this.onBookmarkToggle,
    required this.onStopMainPlayer,
    required this.onToolbarButtonTapped,
    this.senseGroupRangePlayback,
  });

  final Future<void> Function(int index, {bool autoPlay}) onSentenceSelected;
  final ValueChanged<int> onBookmarkToggle;
  final VoidCallback onStopMainPlayer;
  final VoidCallback onToolbarButtonTapped;

  /// 可选的会话级意群区间播放器；未提供时正文保持原音频路径。
  final SenseGroupRangePlayback? senseGroupRangePlayback;
}

/// 音频与视频随心听共用的单句分页器。
///
/// 仅负责随心听的列表位置映射、左右分页和宿主布局；讲解展示统一由
/// [SentenceExplanationView] 管理。程序化分页期间会屏蔽回调，避免自动推进或
/// 循环回卷反向重启播放。
class FreePlayerSentencePager extends StatefulWidget {
  const FreePlayerSentencePager({
    super.key,
    required this.controller,
    required this.audioItem,
    required this.sentences,
    required this.currentSentenceIndex,
    required this.bookmarkedSentenceIndices,
    required this.showTranscript,
    required this.isPlaying,
    required this.scope,
    required this.actions,
    this.wordHighlightSource,
  });

  final FreePlayerSentencePagerController controller;
  final AudioItem audioItem;
  final List<Sentence> sentences;
  final int currentSentenceIndex;
  final Set<int> bookmarkedSentenceIndices;
  final bool showTranscript;
  final bool isPlaying;
  final FreePlayerSentenceScope scope;
  final FreePlayerSentenceActions actions;

  /// 页面实际播放原音的时间轴；为空时分页器保持普通文本。
  final WordHighlightSource? wordHighlightSource;

  @override
  State<FreePlayerSentencePager> createState() =>
      _FreePlayerSentencePagerState();
}

class _FreePlayerSentencePagerState extends State<FreePlayerSentencePager> {
  final PageController _pageController = PageController();
  bool _pagerSynced = false;
  bool _pageSyncScheduled = false;
  bool _programmaticPageChange = false;
  bool _userScrollInProgress = false;
  bool _transitionInFlight = false;
  int? _pendingUserPosition;
  bool? _pendingAutoPlayIntent;
  int? _deferredProviderPosition;
  int? _userScrollSourcePosition;
  Stopwatch? _userScrollStopwatch;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  /// 切句即结束查词会话（本视图由播放器真相源的 [currentSentenceIndex] 驱动，
  /// 横滑 / 自动推进 / 进度条跳句 / 底部切句最终都收敛到这里，是单一入口）。
  ///
  /// 面板与选区绑定在同一个句子上：`PageView` 每页是独立实例，跨句存活会让
  /// 已离屏的旧 owner 继续把焦点和操作条投影到离屏页的几何上。
  @override
  void didUpdateWidget(FreePlayerSentencePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (oldWidget.currentSentenceIndex != widget.currentSentenceIndex) {
      DictionaryPanelHost.maybeOf(context)?.closeIfOpen();
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetPosition = widget.sentences.indexWhere(
      (sentence) => sentence.index == widget.currentSentenceIndex,
    );
    if (targetPosition < 0) return const SizedBox.shrink();

    _schedulePageSync();

    final currentSentence = widget.sentences[targetPosition];
    return Column(
      children: [
        PracticeSentenceInfoRow(
          progressText: AppLocalizations.of(context)!.intensiveListenProgress(
            targetPosition + 1,
            widget.sentences.length,
          ),
          durationText: AppLocalizations.of(context)!.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000).toStringAsFixed(1),
          ),
          timestampText:
              '${SubtitleParser.formatDuration(currentSentence.startTime)} - '
              '${SubtitleParser.formatDuration(currentSentence.endTime)}',
          trailing: BookmarkToggleRow(
            isDifficult: widget.bookmarkedSentenceIndices.contains(
              currentSentence.index,
            ),
            onTap: () => widget.actions.onBookmarkToggle(currentSentence.index),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: PageView.builder(
                key: widget.scope == FreePlayerSentenceScope.bookmarks
                    ? kBookmarkSingleSentenceSwipeAreaKey
                    : kFullSingleSentenceSwipeAreaKey,
                // 面板开着时不接受滑动：屏障按区域放行正文文本以支持连续点词，而触屏的
                // 水平拖拽不被文本消费，会穿到这里造成「切句了但面板还开着」。
                // 文本区域的 tap / 长按 / 手柄拖拽不受影响。
                physics: DictionaryPanelHost.isPanelOpenOf(context)
                    ? const NeverScrollableScrollPhysics()
                    : null,
                controller: _pageController,
                itemCount: widget.sentences.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, position) => _buildSentencePage(
                  widget.sentences[position],
                  position: position,
                  isActivePage: position == targetPosition,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 延迟对齐播放器句索引，避免 build 过程启动分页副作用。
  void _schedulePageSync() {
    if (_pageSyncScheduled) return;
    _pageSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageSyncScheduled = false;
      _syncPageIfReady();
    });
  }

  /// 将播放器真相源同步到分页器；交互期间只记录最新目标，停稳后再对齐。
  void _syncPageIfReady() {
    if (!mounted || !_pageController.hasClients) return;
    final targetPosition = widget.sentences.indexWhere(
      (sentence) => sentence.index == widget.currentSentenceIndex,
    );
    if (targetPosition < 0) return;
    if (_userScrollInProgress || _transitionInFlight) {
      _deferredProviderPosition = targetPosition;
      return;
    }

    final firstSync = !_pagerSynced;
    _deferredProviderPosition = null;
    final page = _pageController.page;
    if (page?.round() == targetPosition) {
      _pagerSynced = true;
      return;
    }

    _transitionInFlight = true;
    _programmaticPageChange = true;
    final currentPage = page?.round();
    final isAdjacent =
        !firstSync &&
        currentPage != null &&
        (targetPosition - currentPage).abs() == 1;
    if (isAdjacent) {
      unawaited(
        _pageController
            .animateToPage(
              targetPosition,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(_finishTransition),
      );
    } else {
      _pageController.jumpToPage(targetPosition);
      _finishTransition();
    }
    _pagerSynced = true;
  }

  void _finishTransition() {
    _programmaticPageChange = false;
    _transitionInFlight = false;
    if (_deferredProviderPosition != null) _schedulePageSync();
  }

  /// 页面内导航先完成卡片动画，再调用与手势相同的选句动作。
  Future<void> animateToSentence(
    int sentenceIndex, {
    required bool autoPlay,
  }) async {
    final targetPosition = widget.sentences.indexWhere(
      (sentence) => sentence.index == sentenceIndex,
    );
    final sourcePosition = widget.sentences.indexWhere(
      (sentence) => sentence.index == widget.currentSentenceIndex,
    );
    if (!mounted ||
        !_pageController.hasClients ||
        _userScrollInProgress ||
        _transitionInFlight) {
      AppLogger.log(
        'FreePlayerPager',
        'navigation ignored item=${widget.audioItem.id} scope=${widget.scope.name} '
            'from=$sourcePosition to=$targetPosition mounted=$mounted '
            'hasClients=${_pageController.hasClients} '
            'userScroll=$_userScrollInProgress transition=$_transitionInFlight',
      );
      return;
    }
    if (targetPosition < 0 || sourcePosition < 0) {
      AppLogger.log(
        'FreePlayerPager',
        'navigation ignored item=${widget.audioItem.id} scope=${widget.scope.name} '
            'reason=sentence_position_missing from=$sourcePosition '
            'to=$targetPosition',
      );
      return;
    }
    if (targetPosition == sourcePosition) {
      AppLogger.log(
        'FreePlayerPager',
        'navigation ignored item=${widget.audioItem.id} scope=${widget.scope.name} '
            'reason=already_current index=$sentenceIndex',
      );
      return;
    }

    final transitionTimer = Stopwatch()..start();
    _transitionInFlight = true;
    _programmaticPageChange = true;
    AppLogger.log(
      'FreePlayerPager',
      'navigation animation begin trigger=control item=${widget.audioItem.id} '
          'scope=${widget.scope.name} from=${widget.sentences[sourcePosition].index} '
          'to=$sentenceIndex cardDirection=${_cardDirection(sourcePosition, targetPosition)} '
          'autoPlay=$autoPlay',
    );
    try {
      if (_pageController.page?.round() != targetPosition) {
        await _pageController.animateToPage(
          targetPosition,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      final settledPosition = _pageController.page?.round();
      AppLogger.log(
        'FreePlayerPager',
        'navigation animation end trigger=control item=${widget.audioItem.id} '
            'scope=${widget.scope.name} from=${widget.sentences[sourcePosition].index} '
            'to=$sentenceIndex settledPosition=$settledPosition '
            'elapsedMs=${transitionTimer.elapsedMilliseconds}',
      );
      if (!mounted || settledPosition != targetPosition) {
        AppLogger.log(
          'FreePlayerPager',
          'navigation selection skipped trigger=control item=${widget.audioItem.id} '
              'target=$sentenceIndex mounted=$mounted settledPosition=$settledPosition',
        );
        return;
      }
      await _selectSentenceAt(targetPosition, autoPlay: autoPlay);
    } catch (error, stackTrace) {
      AppLogger.log(
        'FreePlayerPager',
        'navigation failed trigger=control item=${widget.audioItem.id} '
            'from=${widget.sentences[sourcePosition].index} to=$sentenceIndex '
            'elapsedMs=${transitionTimer.elapsedMilliseconds} error=$error\n$stackTrace',
      );
      rethrow;
    } finally {
      _finishTransition();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrollInProgress = true;
      _pendingAutoPlayIntent = widget.isPlaying;
      _userScrollSourcePosition = widget.sentences.indexWhere(
        (sentence) => sentence.index == widget.currentSentenceIndex,
      );
      _userScrollStopwatch = Stopwatch()..start();
      AppLogger.log(
        'FreePlayerPager',
        'swipe begin item=${widget.audioItem.id} scope=${widget.scope.name} '
            'from=${widget.currentSentenceIndex} position=$_userScrollSourcePosition '
            'isPlaying=${widget.isPlaying}',
      );
      return false;
    }
    if (notification is! ScrollEndNotification || !_userScrollInProgress) {
      return false;
    }

    _userScrollInProgress = false;
    final targetPosition = _pageController.page?.round();
    final sourcePosition = widget.sentences.indexWhere(
      (sentence) => sentence.index == widget.currentSentenceIndex,
    );
    final gestureSourcePosition = _userScrollSourcePosition ?? sourcePosition;
    final pendingPosition = _pendingUserPosition;
    final autoPlay = _pendingAutoPlayIntent ?? widget.isPlaying;
    final elapsedMs = _userScrollStopwatch?.elapsedMilliseconds;
    AppLogger.log(
      'FreePlayerPager',
      'swipe settled item=${widget.audioItem.id} scope=${widget.scope.name} '
          'from=${gestureSourcePosition >= 0 && gestureSourcePosition < widget.sentences.length ? widget.sentences[gestureSourcePosition].index : null} '
          'candidate=${pendingPosition != null && pendingPosition >= 0 && pendingPosition < widget.sentences.length ? widget.sentences[pendingPosition].index : null} '
          'settled=${targetPosition != null && targetPosition >= 0 && targetPosition < widget.sentences.length ? widget.sentences[targetPosition].index : null} '
          'cardDirection=${targetPosition != null && targetPosition >= 0 && targetPosition < widget.sentences.length && gestureSourcePosition >= 0 && gestureSourcePosition < widget.sentences.length ? _cardDirection(gestureSourcePosition, targetPosition) : 'none'} '
          'autoPlay=$autoPlay elapsedMs=$elapsedMs',
    );
    _pendingUserPosition = null;
    _pendingAutoPlayIntent = null;
    _userScrollSourcePosition = null;
    _userScrollStopwatch = null;
    if (targetPosition == null ||
        targetPosition < 0 ||
        targetPosition >= widget.sentences.length ||
        targetPosition == sourcePosition ||
        targetPosition != pendingPosition ||
        gestureSourcePosition < 0 ||
        gestureSourcePosition >= widget.sentences.length) {
      AppLogger.log(
        'FreePlayerPager',
        'swipe selection skipped item=${widget.audioItem.id} '
            'reason=${targetPosition == pendingPosition ? 'same_sentence_or_invalid' : 'settled_page_mismatch'} '
            'providerPosition=$sourcePosition settledPosition=$targetPosition '
            'candidatePosition=$pendingPosition',
      );
      _scheduleDeferredPageSync();
      return false;
    }
    unawaited(
      _commitUserSelection(
        targetPosition,
        autoPlay: autoPlay,
        sourcePosition: gestureSourcePosition,
      ),
    );
    return false;
  }

  void _scheduleDeferredPageSync() {
    if (_deferredProviderPosition == null ||
        _userScrollInProgress ||
        _transitionInFlight) {
      return;
    }
    _schedulePageSync();
  }

  Future<void> _commitUserSelection(
    int targetPosition, {
    required bool autoPlay,
    required int sourcePosition,
  }) async {
    if (_transitionInFlight) return;
    _transitionInFlight = true;
    final targetSentence = widget.sentences[targetPosition];
    final sourceSentence = widget.sentences[sourcePosition];
    AppLogger.log(
      'FreePlayerPager',
      'selection commit begin trigger=swipe item=${widget.audioItem.id} '
          'scope=${widget.scope.name} from=${sourceSentence.index} '
          'to=${targetSentence.index} '
          'cardDirection=${_cardDirection(sourcePosition, targetPosition)} '
          'autoPlay=$autoPlay',
    );
    try {
      await _selectSentenceAt(targetPosition, autoPlay: autoPlay);
    } catch (error, stackTrace) {
      AppLogger.log(
        'FreePlayerPager',
        'selection commit failed trigger=swipe item=${widget.audioItem.id} '
            'from=${sourceSentence.index} to=${targetSentence.index} '
            'error=$error\n$stackTrace',
      );
      rethrow;
    } finally {
      AppLogger.log(
        'FreePlayerPager',
        'selection commit end trigger=swipe item=${widget.audioItem.id} '
            'to=${targetSentence.index} providerIndex=${widget.currentSentenceIndex} '
            'isPlaying=${widget.isPlaying}',
      );
      _transitionInFlight = false;
      _scheduleDeferredPageSync();
    }
  }

  Future<void> _selectSentenceAt(int position, {required bool autoPlay}) async {
    if (position < 0 || position >= widget.sentences.length) return;
    final sentence = widget.sentences[position];
    if (sentence.index == widget.currentSentenceIndex) return;
    AppLogger.log(
      'FreePlayerPager',
      'selection dispatch begin item=${widget.audioItem.id} '
          'scope=${widget.scope.name} index=${sentence.index} autoPlay=$autoPlay',
    );
    await widget.actions.onSentenceSelected(sentence.index, autoPlay: autoPlay);
    AppLogger.log(
      'FreePlayerPager',
      'selection dispatch end item=${widget.audioItem.id} '
          'scope=${widget.scope.name} index=${sentence.index} autoPlay=$autoPlay',
    );
  }

  /// 手势过程中只记录候选页，等滚动结束再提交选句。
  void _onPageChanged(int position) {
    if (_programmaticPageChange ||
        position < 0 ||
        position >= widget.sentences.length) {
      return;
    }
    if (widget.sentences[position].index == widget.currentSentenceIndex) {
      _pendingUserPosition = null;
      return;
    }
    _pendingUserPosition = position;
    _pendingAutoPlayIntent ??= widget.isPlaying;
    final sourcePosition =
        _userScrollSourcePosition ??
        widget.sentences.indexWhere(
          (sentence) => sentence.index == widget.currentSentenceIndex,
        );
    AppLogger.log(
      'FreePlayerPager',
      'swipe page candidate item=${widget.audioItem.id} scope=${widget.scope.name} '
          'from=${sourcePosition >= 0 && sourcePosition < widget.sentences.length ? widget.sentences[sourcePosition].index : null} '
          'to=${widget.sentences[position].index} '
          'cardDirection=${sourcePosition >= 0 && sourcePosition < widget.sentences.length ? _cardDirection(sourcePosition, position) : 'unknown'}',
    );
  }

  String _cardDirection(int sourcePosition, int targetPosition) {
    final nextPageMovesLeft =
        (targetPosition > sourcePosition) ==
        (Directionality.of(context) == TextDirection.ltr);
    return nextPageMovesLeft ? 'right_to_left' : 'left_to_right';
  }

  Widget _buildSentencePage(
    Sentence sentence, {
    required int position,
    required bool isActivePage,
  }) {
    // 分页页填满视口，讲解组件只滚动工具栏和正文。
    return Column(
      children: [
        Expanded(
          // 滑动区已由宿主提供水平留白，内容无需再次缩进。
          child: SentenceExplanationView(
            key: ValueKey(sentence.index),
            text: sentence.text,
            audioItemId: widget.audioItem.id,
            wordHighlightSource: isActivePage
                ? widget.wordHighlightSource
                : null,
            sentenceIndex: sentence.index,
            sentenceStartMs: sentence.startTime.inMilliseconds,
            sentenceEndMs: sentence.endTime.inMilliseconds,
            explanationContext: const SentenceExplanationContext(
              source: 'freePlayer',
            ),
            onStopMainPlayer: widget.actions.onStopMainPlayer,
            senseGroupRangePlayback: widget.actions.senseGroupRangePlayback,
            onToolbarButtonTapped: widget.actions.onToolbarButtonTapped,
            enableGuide: isActivePage,
            isActiveSentence: isActivePage,
            showTranscript: widget.showTranscript,
            prewarmTargets: isActivePage
                ? upcomingSentencePrewarmTargets(
                    sentences: widget.sentences,
                    position: position,
                    audioItemId: widget.audioItem.id,
                  )
                : const [],
          ),
        ),
      ],
    );
  }
}

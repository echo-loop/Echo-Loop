/// 段落句子列表卡片
///
/// 统一渲染段落内句子列表，供全文盲听和段落复述共用。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/retell_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../models/sentence.dart';
import '../../models/word_highlight_binding.dart';
import '../../models/sentence_focus_reason.dart';
import '../../theme/app_theme.dart';
import '../../services/app_logger.dart';
import '../guide_flow.dart';
import 'masked_sentence_tile.dart';
import 'sentence_context_menu.dart';
import 'text_context_menu.dart';

/// 判断列表中的句子集合或顺序是否真正变化。
///
/// provider 的派生 getter 可能在每次播放进度更新时返回新 List；不能
/// 用 List 实例身份判断段落变化，否则会持续重启自动滚动并吞掉 item 点击。
bool _sentenceSequenceChanged(List<Sentence> previous, List<Sentence> next) {
  if (previous.length != next.length) return true;
  for (var i = 0; i < previous.length; i += 1) {
    if (previous[i].index != next[i].index) return true;
  }
  return false;
}

/// 初次定位可见性容器的 key（供测试断言定位完成前列表不可见）。
@visibleForTesting
const Key kParagraphListInitialFocusKey = ValueKey(
  'paragraph-list-initial-focus',
);

/// 段落句子列表卡片
class ParagraphSentenceListCard extends StatefulWidget {
  final List<Sentence> sentences;
  final RetellDisplayMode displayMode;
  final Map<int, Set<int>> keywordMap;
  final int playingSentenceIndex;
  final bool autoFocusEnabled;
  final bool focusActive;
  final int? focusRequestRevision;
  final SentenceFocusReason? focusReason;
  final int focusRestoreRevision;

  /// 是否在定位完成前隐藏列表并在完成后瞬时显示，供需要无初始动画的播放器使用。
  final bool directInitialPositioning;

  /// 列表暂时隐藏后，若焦点没有变化则保留滚动位置。
  final bool preserveScrollPositionOnReactivation;

  /// 当前任务实际使用的原音播放时间轴。
  final WordHighlightSource? wordHighlightSource;
  final Duration autoFocusResumeDelay;

  /// 已收藏句子索引集合（用于显示只读标记）
  final Set<int> bookmarkedSentenceIndices;

  /// 点击左侧讲解按钮回调：进入句子讲解页
  final ValueChanged<Sentence>? onSentenceExplanationTap;

  /// 点击句子主体回调：从该句开始播放
  final ValueChanged<Sentence>? onSentencePlayFrom;

  /// 切换句子收藏状态；菜单等待写入完成后才反馈成功，失败应向上传播。
  final Future<void> Function(Sentence)? onSentenceBookmarkToggle;

  /// 新手引导：挂引导 step 的句子本地索引（默认挂在 idx=1，回退到 idx=0）
  final int? guideTargetLocalIdx;

  /// 新手引导：左侧讲解按钮 step
  final GuideStep? explanationAreaGuideStep;

  /// 新手引导：句子主体播放 step
  final GuideStep? bodyAreaGuideStep;

  const ParagraphSentenceListCard({
    super.key,
    required this.sentences,
    required this.displayMode,
    required this.keywordMap,
    required this.playingSentenceIndex,
    this.autoFocusEnabled = false,
    this.focusActive = true,
    this.focusRequestRevision,
    this.focusReason,
    this.focusRestoreRevision = 0,
    this.directInitialPositioning = false,
    this.preserveScrollPositionOnReactivation = false,
    this.wordHighlightSource,
    this.autoFocusResumeDelay = const Duration(seconds: 2),
    this.bookmarkedSentenceIndices = const {},
    this.onSentenceExplanationTap,
    this.onSentencePlayFrom,
    this.onSentenceBookmarkToggle,
    this.guideTargetLocalIdx,
    this.explanationAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  State<ParagraphSentenceListCard> createState() =>
      _ParagraphSentenceListCardState();
}

class _ParagraphSentenceListCardState extends State<ParagraphSentenceListCard>
    with AutomaticKeepAliveClientMixin {
  // 在 TabBarView（底层 PageView）中保活：切 Tab 不销毁本列表 State，避免回到全文/
  // 收藏 Tab 时重跑「初次定位 + 淡入」造成的列表重渲染闪烁，并保留滚动位置。
  @override
  bool get wantKeepAlive => true;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  ScrollPosition? _scrollPosition;
  BuildContext? _playingItemContext;
  Timer? _resumeFocusTimer;
  bool _userSuspendedFocus = false;
  int _focusRequestGeneration = 0;
  bool _hasInactiveFocusSnapshot = false;
  int? _inactivePlayingSentenceIndex;
  int? _inactiveFocusRequestRevision;
  int _inactiveFocusRestoreRevision = 0;
  SentenceFocusReason? _inactiveFocusReason;
  bool _inactiveSentenceSequenceChanged = false;

  /// 菜单与提交共用防重入标记；材料切换使旧会话失效，播放切句不影响目标。
  bool _contextMenuActive = false;
  int _contextMenuGeneration = 0;

  /// 初始定位时当前句在列表中的 item 索引。
  int _initialScrollIndex = 0;

  /// 「初次定位」是否完成。完成前列表不可见，避免用户看到定位过程；直接定位模式
  /// 完成后瞬时显出，其他复用场景沿用原有淡入。
  bool _initialFocusDone = false;

  @override
  void initState() {
    super.initState();
    // 按当前索引初始化，并在列表不可见时完成边界校正。
    final localSentenceIndex = _playingSentenceLocalIndex();
    final shouldCenter = widget.autoFocusEnabled && localSentenceIndex != null;
    if (shouldCenter) {
      _initialScrollIndex = localSentenceIndex * 2;
      // 保持列表 anchor=0；非零 initialAlignment 在首尾会产生空白，故通过可见 item
      // 的滚动分支校正后再瞬时显示。
      if (widget.focusActive) _centerInitialFocus(localSentenceIndex * 2);
    } else {
      // 无需自动居中（如段落复述）：列表直接可见，从顶部开始。
      _initialFocusDone = true;
    }
  }

  /// 在不可见状态下把当前句定位到视口锚点，完成后更新 [_initialFocusDone]。
  ///
  /// 先 [ItemScrollController.jumpTo]（alignment=0）把目标放到顶边并保持普通列表 anchor；
  /// 布局完成后通过原生 ScrollPosition 校正偏移，保持 anchor=0，
  /// 校正期间列表不可见；初次定位与后续自动跟随统一使用 0.4 锚点。首尾边界由滚动
  /// 范围自然约束。
  void _centerInitialFocus(int targetIndex) {
    final generation = ++_focusRequestGeneration;
    _hideWhilePositioning();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoFocusEnabled ||
          !widget.focusActive ||
          generation != _focusRequestGeneration ||
          !_itemScrollController.isAttached) {
        return;
      }
      _itemScrollController.jumpTo(index: targetIndex, alignment: 0);
      _schedulePositionCorrection(generation);
    });
  }

  /// 确保安全跳转后的下一次布局执行 0.4 对齐校正。
  ///
  /// post-frame 回调自身不会请求新帧；恢复页面时若没有其他状态变化，单纯注册回调
  /// 会让定位停在安全顶边位置，因此这里显式安排下一帧。
  void _schedulePositionCorrection(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _correctPositionImmediately(generation);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _hideWhilePositioning() {
    if (widget.directInitialPositioning && _initialFocusDone) {
      setState(() => _initialFocusDone = false);
    }
  }

  void _correctPositionImmediately(int generation) {
    if (!mounted ||
        !widget.autoFocusEnabled ||
        !widget.focusActive ||
        generation != _focusRequestGeneration ||
        !_itemScrollController.isAttached) {
      return;
    }

    final scroll = _scrollPosition;
    final itemContext = _playingItemContext;
    if (scroll == null ||
        !scroll.hasContentDimensions ||
        itemContext == null ||
        !itemContext.mounted) {
      return;
    }
    final render = itemContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return;
    final viewport = RenderAbstractViewport.of(render);
    final target =
        (viewport.getOffsetToReveal(render, 0).offset -
                0.4 * scroll.viewportDimension)
            .clamp(scroll.minScrollExtent, scroll.maxScrollExtent)
            .toDouble();
    scroll.jumpTo(target);
    setState(() => _initialFocusDone = true);
  }

  /// 无动画定位到指定当前句；仅首次定位和页面恢复需要暂时隐藏列表。
  void _focusImmediately({bool hideWhilePositioning = true}) {
    if (!widget.autoFocusEnabled || !widget.focusActive) return;
    final localSentenceIndex = _playingSentenceLocalIndex();
    if (localSentenceIndex == null) return;
    final targetIndex = localSentenceIndex * 2;
    final generation = ++_focusRequestGeneration;
    if (hideWhilePositioning) _hideWhilePositioning();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoFocusEnabled ||
          !widget.focusActive ||
          generation != _focusRequestGeneration ||
          !_itemScrollController.isAttached) {
        return;
      }
      _itemScrollController.jumpTo(index: targetIndex, alignment: 0);
      _schedulePositionCorrection(generation);
    });
  }

  /// 从当前偏移连续滚动，远处句子进入布局范围后再精确对齐。
  ///
  /// 始终保留 anchor=0，不切换底层列表或先跳到目标顶部。按视口分段可支持
  /// 高度不同的句子且保留按需渲染；每段均限制在真实滚动范围内。
  void _focusWithPlaybackAnimation() {
    if (!widget.autoFocusEnabled ||
        !widget.focusActive ||
        _userSuspendedFocus) {
      return;
    }
    final localIndex = _playingSentenceLocalIndex();
    if (localIndex == null) return;
    final generation = ++_focusRequestGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_animateToSentence(localIndex * 2, generation));
    });
  }

  /// 新请求、手势和页面离开都会使旧滚动失效，防止过期动画继续追赶旧句。
  bool _canContinueFocus(int generation) =>
      mounted &&
      widget.autoFocusEnabled &&
      widget.focusActive &&
      !_userSuspendedFocus &&
      generation == _focusRequestGeneration;

  Future<void> _animateToSentence(int targetIndex, int generation) async {
    while (_canContinueFocus(generation)) {
      final scroll = _scrollPosition;
      if (scroll == null || !scroll.hasContentDimensions) return;
      final position = _targetPosition(targetIndex);
      if (position != null) {
        final target =
            (scroll.pixels +
                    (position.itemLeadingEdge - 0.4) * scroll.viewportDimension)
                .clamp(scroll.minScrollExtent, scroll.maxScrollExtent)
                .toDouble();
        if ((target - scroll.pixels).abs() < 0.5) return;
        await scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isEmpty) return;
      final first = positions.reduce((a, b) => a.index < b.index ? a : b);
      final last = positions.reduce((a, b) => a.index > b.index ? a : b);
      final direction = targetIndex < first.index ? -1 : 1;
      final remaining = direction < 0
          ? first.index - targetIndex
          : targetIndex - last.index;
      final visibleCount = last.index - first.index + 1;
      final duration = (280 * visibleCount / remaining).round().clamp(16, 90);
      final target =
          (scroll.pixels + direction * scroll.viewportDimension * 0.8)
              .clamp(scroll.minScrollExtent, scroll.maxScrollExtent)
              .toDouble();
      if ((target - scroll.pixels).abs() < 0.5) return;
      await scroll.animateTo(
        target,
        duration: Duration(milliseconds: duration),
        curve: Curves.linear,
      );
      // 位置监听在布局后更新，等本帧完成再读取下一段目标。
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void didUpdateWidget(covariant ParagraphSentenceListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wordHighlightSource?.audioItemId !=
        oldWidget.wordHighlightSource?.audioItemId) {
      _contextMenuGeneration += 1;
    }
    final playingChanged =
        widget.playingSentenceIndex != oldWidget.playingSentenceIndex;
    final paragraphChanged = _sentenceSequenceChanged(
      oldWidget.sentences,
      widget.sentences,
    );
    final focusReenabled =
        !oldWidget.autoFocusEnabled && widget.autoFocusEnabled;
    final becameFocusActive = !oldWidget.focusActive && widget.focusActive;
    final becameFocusInactive = oldWidget.focusActive && !widget.focusActive;
    final focusRestoreRequested =
        widget.focusRestoreRevision != oldWidget.focusRestoreRevision;
    final focusRequestChanged =
        widget.focusRequestRevision != null &&
        widget.focusRequestRevision != oldWidget.focusRequestRevision;

    if (!widget.autoFocusEnabled) {
      _cancelFocusAnimation();
      _resumeFocusTimer?.cancel();
      _userSuspendedFocus = false;
      return;
    }

    if (widget.preserveScrollPositionOnReactivation && becameFocusInactive) {
      _captureInactiveFocusSnapshot();
      _resumeFocusTimer?.cancel();
      _cancelFocusAnimation();
      return;
    }

    if (!widget.focusActive) {
      if (widget.preserveScrollPositionOnReactivation) {
        _inactiveSentenceSequenceChanged =
            _inactiveSentenceSequenceChanged || paragraphChanged;
        _resumeFocusTimer?.cancel();
      }
      _cancelFocusAnimation();
      return;
    }

    if (becameFocusActive &&
        widget.preserveScrollPositionOnReactivation &&
        _hasInactiveFocusSnapshot) {
      final focusChangedWhileInactive =
          widget.playingSentenceIndex != _inactivePlayingSentenceIndex ||
          widget.focusRequestRevision != _inactiveFocusRequestRevision ||
          widget.focusRestoreRevision != _inactiveFocusRestoreRevision ||
          widget.focusReason != _inactiveFocusReason ||
          _inactiveSentenceSequenceChanged ||
          !_initialFocusDone;
      _clearInactiveFocusSnapshot();
      if (focusChangedWhileInactive) {
        _resumeFocusTimer?.cancel();
        _userSuspendedFocus = false;
        _focusImmediately(hideWhilePositioning: false);
      } else if (_userSuspendedFocus) {
        _scheduleFocusResumeTimer();
      }
      return;
    }

    if (becameFocusActive || focusRestoreRequested) {
      _userSuspendedFocus = false;
      if (becameFocusActive &&
          !focusRestoreRequested &&
          widget.focusReason == SentenceFocusReason.navigation) {
        _focusWithPlaybackAnimation();
      } else {
        _focusImmediately(hideWhilePositioning: false);
      }
      return;
    }

    if (focusReenabled) {
      _userSuspendedFocus = false;
      if (widget.focusRequestRevision != null) {
        _focusImmediately();
      } else {
        _focusPlayingSentence();
      }
      return;
    }

    if (paragraphChanged) {
      if (widget.focusRequestRevision != null) {
        _focusImmediately();
      } else if (!_userSuspendedFocus) {
        _focusPlayingSentence();
      }
      return;
    }

    if (playingChanged || focusRequestChanged) {
      if (widget.focusRequestRevision != null &&
          widget.focusReason == SentenceFocusReason.immediate) {
        _focusImmediately(hideWhilePositioning: false);
      } else if (widget.focusRequestRevision != null &&
          widget.focusReason == SentenceFocusReason.navigation) {
        _resumeFocusTimer?.cancel();
        _userSuspendedFocus = false;
        _focusWithPlaybackAnimation();
      } else if (!_userSuspendedFocus && widget.focusRequestRevision != null) {
        _focusWithPlaybackAnimation();
      } else if (!_userSuspendedFocus) {
        _focusPlayingSentence();
      }
    }
  }

  /// 暂停聚焦时同时取消当前像素动画，防止拖动进度条期间列表仍在移动。
  void _cancelFocusAnimation() {
    _focusRequestGeneration += 1;
    final scroll = _scrollPosition;
    if (scroll != null &&
        scroll.hasPixels &&
        scroll.isScrollingNotifier.value) {
      scroll.jumpTo(scroll.pixels);
    }
  }

  @override
  void dispose() {
    _contextMenuGeneration += 1;
    _resumeFocusTimer?.cancel();
    super.dispose();
  }

  /// 冻结目标句与动作回调，避免播放进度更新后误操作当前播放句。
  ///
  /// 生命周期校验在每次异步返回后执行；成功提示由列表持有，收藏行移除时
  /// 不依赖已经卸载的 tile，也不新增本地收藏状态。
  Future<void> _showSentenceMenu(Sentence sentence, Offset position) async {
    if (_contextMenuActive || sentence.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    _contextMenuActive = true;
    final generation = _contextMenuGeneration;
    final toggleBookmark = widget.onSentenceBookmarkToggle;
    final explain = widget.onSentenceExplanationTap;
    final wasBookmarked = widget.bookmarkedSentenceIndices.contains(
      sentence.index,
    );
    bool isCurrentSession() => mounted && generation == _contextMenuGeneration;
    SentenceContextAction? action;
    try {
      action = await showSentenceContextMenu(
        context: context,
        position: position,
        isBookmarked: wasBookmarked,
        canToggleBookmark: toggleBookmark != null,
        canExplain: explain != null,
      );
      if (!isCurrentSession() || action == null) return;
      AppLogger.log(
        'SentenceContextMenu',
        'event=action action=${action.name} sentence=${sentence.index}',
      );
      switch (action) {
        case SentenceContextAction.copy:
          await Clipboard.setData(ClipboardData(text: sentence.text));
          if (isCurrentSession()) _showMenuFeedback(l10n.copied);
        case SentenceContextAction.toggleBookmark:
          if (toggleBookmark == null) return;
          // 菜单打开期间若其他入口已经完成目标状态，不再反向切换。
          if (widget.bookmarkedSentenceIndices.contains(sentence.index) ==
              wasBookmarked) {
            await toggleBookmark(sentence);
          }
          if (isCurrentSession()) {
            _showMenuFeedback(
              wasBookmarked ? l10n.sentenceMenuUnsaved : l10n.sentenceMenuSaved,
            );
          }
        case SentenceContextAction.explain:
          explain?.call(sentence);
      }
    } catch (error, stackTrace) {
      AppLogger.log(
        'SentenceContextMenu',
        'event=failed action=${action?.name} sentence=${sentence.index} '
            'error=$error\n$stackTrace',
      );
      if (isCurrentSession()) {
        _showMenuFeedback(
          l10n.sentenceMenuActionFailed,
          icon: Icons.error_outline,
        );
      }
    } finally {
      _contextMenuActive = false;
    }
  }

  /// 在页面级宿主显示操作结果，保证字幕行被移除后仍有即时反馈。
  void _showMenuFeedback(String message, {IconData icon = Icons.check}) {
    TextContextMenu.showFeedback(context, message, icon: icon);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.autoFocusEnabled || notification is! UserScrollNotification) {
      return false;
    }

    if (notification.direction == ScrollDirection.idle) {
      if (_userSuspendedFocus) {
        _scheduleFocusResumeTimer();
      }
      return false;
    }

    _resumeFocusTimer?.cancel();
    _userSuspendedFocus = true;
    _focusRequestGeneration += 1;
    return false;
  }

  /// 记录列表隐藏前的焦点；隐藏期间的更新会与这份快照比较。
  void _captureInactiveFocusSnapshot() {
    _hasInactiveFocusSnapshot = true;
    _inactivePlayingSentenceIndex = widget.playingSentenceIndex;
    _inactiveFocusRequestRevision = widget.focusRequestRevision;
    _inactiveFocusRestoreRevision = widget.focusRestoreRevision;
    _inactiveFocusReason = widget.focusReason;
    _inactiveSentenceSequenceChanged = false;
  }

  /// 清除列表失焦期间用于比较的焦点快照。
  void _clearInactiveFocusSnapshot() {
    _hasInactiveFocusSnapshot = false;
    _inactivePlayingSentenceIndex = null;
    _inactiveFocusRequestRevision = null;
    _inactiveFocusRestoreRevision = 0;
    _inactiveFocusReason = null;
    _inactiveSentenceSequenceChanged = false;
  }

  /// 手动滚动暂停期间先等待一段时间，再按当前焦点恢复自动跟随。
  void _scheduleFocusResumeTimer() {
    _resumeFocusTimer?.cancel();
    _resumeFocusTimer = Timer(widget.autoFocusResumeDelay, () {
      if (!mounted || !widget.autoFocusEnabled || !widget.focusActive) return;
      _userSuspendedFocus = false;
      if (widget.focusRequestRevision != null &&
          widget.focusReason == SentenceFocusReason.immediate) {
        _focusImmediately(hideWhilePositioning: false);
      } else if (widget.focusRequestRevision != null) {
        _focusWithPlaybackAnimation();
      } else {
        _focusPlayingSentence();
      }
    });
  }

  /// 学习页面与随心听共享同一套连续滚动及边界处理。
  void _focusPlayingSentence() => _focusWithPlaybackAnimation();

  /// 获取已布局元素的位置，用于计算保持 anchor=0 的像素偏移。
  ItemPosition? _targetPosition(int targetIndex) {
    for (final position in _itemPositionsListener.itemPositions.value) {
      if (position.index == targetIndex) return position;
    }
    return null;
  }

  int? _playingSentenceLocalIndex() {
    if (widget.sentences.isEmpty || widget.playingSentenceIndex < 0) {
      return null;
    }
    return _clampLocalSentenceIndex(widget.playingSentenceIndex);
  }

  int _clampLocalSentenceIndex(int index) {
    if (index < 0) return 0;
    final lastIndex = widget.sentences.length - 1;
    if (index > lastIndex) return lastIndex;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求调用
    final theme = Theme.of(context);
    return Card(
      // 列表贴边铺满：去左右边距与圆角，读作整块内容区而非浮起卡片。
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: _buildInitialFocusVisibility(
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            initialScrollIndex: _initialScrollIndex,
            // 保持普通列表 anchor，居中校正时边界才会自然贴顶/贴底。
            initialAlignment: 0,
            // 硬停物理：自动跟随滚到自然边界即停，越界被逐帧 clamp，杜绝到头/尾时
            // 的自动回弹。
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            itemCount: widget.sentences.isEmpty
                ? 0
                : widget.sentences.length * 2 - 1,
            itemBuilder: (context, index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  indent: AppSpacing.m,
                  endIndent: AppSpacing.m,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                );
              }

              final sentenceIndex = index ~/ 2;
              final sentence = widget.sentences[sentenceIndex];
              final isGuideTarget = widget.guideTargetLocalIdx == sentenceIndex;
              final onSentenceExplanationTap = widget.onSentenceExplanationTap;
              final onSentencePlayFrom = widget.onSentencePlayFrom;
              final onSentenceBookmarkToggle = widget.onSentenceBookmarkToggle;
              final wordHighlightSource = widget.wordHighlightSource;
              return Builder(
                builder: (itemContext) {
                  _scrollPosition = Scrollable.of(itemContext).position;
                  if (sentenceIndex == _playingSentenceLocalIndex()) {
                    _playingItemContext = itemContext;
                  }
                  return MaskedSentenceTile(
                    sentence: sentence,
                    displayMode: widget.displayMode,
                    keywordIndices:
                        widget.keywordMap[sentence.index] ?? const {},
                    isPlayingSentence:
                        sentenceIndex == widget.playingSentenceIndex,
                    wordHighlightBinding:
                        sentenceIndex == widget.playingSentenceIndex &&
                            wordHighlightSource != null
                        ? WordHighlightBinding(
                            source: wordHighlightSource,
                            sentenceStartMs: sentence.startTime.inMilliseconds,
                            sentenceEndMs: sentence.endTime.inMilliseconds,
                            positionRollbackFloorMs:
                                sentence.startTime.inMilliseconds,
                          )
                        : null,
                    isBookmarked: widget.bookmarkedSentenceIndices.contains(
                      sentence.index,
                    ),
                    onDetailTap: onSentenceExplanationTap == null
                        ? null
                        : () => onSentenceExplanationTap(sentence),
                    onPlayFromTap: onSentencePlayFrom == null
                        ? null
                        : () => onSentencePlayFrom(sentence),
                    onContextMenuRequested: (position) =>
                        unawaited(_showSentenceMenu(sentence, position)),
                    onBookmarkTap: onSentenceBookmarkToggle == null
                        ? null
                        : () => onSentenceBookmarkToggle(sentence),
                    explanationAreaGuideStep: isGuideTarget
                        ? widget.explanationAreaGuideStep
                        : null,
                    bodyAreaGuideStep: isGuideTarget
                        ? widget.bodyAreaGuideStep
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInitialFocusVisibility(Widget child) {
    if (widget.directInitialPositioning) {
      return Opacity(
        key: kParagraphListInitialFocusKey,
        opacity: _initialFocusDone ? 1 : 0,
        child: child,
      );
    }
    return AnimatedOpacity(
      key: kParagraphListInitialFocusKey,
      opacity: _initialFocusDone ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: child,
    );
  }
}

/// 段落句子列表卡片
///
/// 统一渲染段落内句子列表，供全文盲听和段落复述共用。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../guide_flow.dart';
import 'masked_sentence_tile.dart';

/// 计算自动跟随当前播放句时 [ItemScrollController.scrollTo] 的锚定 alignment。
///
/// 纯函数，便于单元测试。列表统一使用 [ClampingScrollPhysics]，越界滚动会被逐帧
/// clamp 到自然边界（详见 [_ParagraphSentenceListCardState.build]），因此边界句的
/// 贴边交给物理处理，这里只需决定锚点：
/// - **目标可见**：命中 `scrollTo` 的「可见分支」（不改底层 `anchor`），返回 0.5
///   让中间句居中；靠边时居中会超界、被 clamp 到自然边缘（末句贴底 / 首句贴顶，
///   无留白、无回弹）。
/// - **目标不可见**（大跳转，命中 else 分支会把底层 `anchor` 设为传入 alignment）：
///   返回 0.0，令 `anchor` 维持 0（普通列表语义），目标落到顶部、若为末句则被
///   clamp 到底部，均无留白。
double autoFollowAlignment({required bool targetVisible}) {
  return targetVisible ? 0.5 : 0.0;
}

/// 自动跟随的「居中容差带」半宽（占视口比例）。
///
/// 目标句的 leading edge 落在 `[0.5 - 容差, 0.5 + 容差]` 内即视为已大致居中。
const double kAutoFollowCenterTolerance = 0.18;

/// 目标句当前是否已大致居中，居中则无需再滚动。
///
/// 纯函数，便于单元测试。仅用 leading edge 判断：随播放逐句推进，下一句的 leading
/// edge 会比当前句更靠下；一旦越出容差带就重新居中，避免「当前句逐句下移直到贴底、
/// 再突然跳回顶部」的漂移（参见 [_ParagraphSentenceListCardState._focusPlayingSentence]）。
///
/// [leadingEdge] 为目标 item 顶边相对视口的比例（[ItemPosition.itemLeadingEdge]）。
bool isTargetWellCentered({
  required double leadingEdge,
  double tolerance = kAutoFollowCenterTolerance,
}) {
  return (leadingEdge - 0.5).abs() <= tolerance;
}

/// 初次定位淡入层的 key（供测试断言「居中完成前列表隐藏」）。
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
  final Duration autoFocusResumeDelay;

  /// 已收藏句子索引集合（用于显示只读标记）
  final Set<int> bookmarkedSentenceIndices;

  /// 点击句子主体（文本 / 书签）回调：进入句子讲解页
  final ValueChanged<Sentence>? onSentenceTap;

  /// 点击句子编号区回调：从该句开始播放
  final ValueChanged<Sentence>? onSentencePlayFrom;

  /// 新手引导：挂引导 step 的句子本地索引（默认挂在 idx=1，回退到 idx=0）
  final int? guideTargetLocalIdx;

  /// 新手引导：编号区 step
  final GuideStep? numberAreaGuideStep;

  /// 新手引导：主体区 step
  final GuideStep? bodyAreaGuideStep;

  const ParagraphSentenceListCard({
    super.key,
    required this.sentences,
    required this.displayMode,
    required this.keywordMap,
    required this.playingSentenceIndex,
    this.autoFocusEnabled = false,
    this.autoFocusResumeDelay = const Duration(seconds: 2),
    this.bookmarkedSentenceIndices = const {},
    this.onSentenceTap,
    this.onSentencePlayFrom,
    this.guideTargetLocalIdx,
    this.numberAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  State<ParagraphSentenceListCard> createState() =>
      _ParagraphSentenceListCardState();
}

class _ParagraphSentenceListCardState extends State<ParagraphSentenceListCard> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  Timer? _resumeFocusTimer;
  bool _userSuspendedFocus = false;

  /// 首帧把当前句渲染在顶部的初始锚点 item 索引（保持底层 anchor=0，见 [initState]）。
  int _initialScrollIndex = 0;

  /// 「初次定位」是否完成。完成前列表不可见，避免用户看到「目标句从顶部滚到中部」
  /// 的多余移动；完成后淡入（已在中部），观感为「直接显示在中间」。
  bool _initialFocusDone = false;

  @override
  void initState() {
    super.initState();
    // 「初次定位」（首次进入 / 切 Tab 重建）的业界标准做法：
    // ① 用 initialScrollIndex 让首帧就把当前句渲染在顶部（底层 anchor 仍为 0，
    //    不破坏既有「anchor=0 + ClampingScrollPhysics 硬停」的到头/尾防回弹设计）；
    // ② 在列表不可见时瞬时滚到居中（[_centerInitialFocus]），完成后淡入。
    //    用户看不到从顶部到中部的滚动，等同「直接显示在中间」。
    final localSentenceIndex = _playingSentenceLocalIndex();
    final shouldCenter = widget.autoFocusEnabled && localSentenceIndex != null;
    if (shouldCenter) {
      _initialScrollIndex = localSentenceIndex * 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerInitialFocus(localSentenceIndex * 2);
      });
    } else {
      // 无需自动居中（如段落复述）：列表直接可见，从顶部开始。
      _initialFocusDone = true;
    }
  }

  /// 在不可见状态下把当前句瞬时滚到视口中部，完成后置 [_initialFocusDone] 触发淡入。
  ///
  /// 两阶段（与 [_focusPlayingSentence] 的大跳转路径同源，只是瞬时、无动画、在不可见
  /// 时完成）：先 [ItemScrollController.jumpTo]（alignment=0）把目标渲染到顶部、底层
  /// anchor 保持 0（不破坏到头/尾防回弹设计）；下一帧目标已可见，再走 [scrollTo] 的
  /// 「可见分支」瞬时居中（只移动偏移、不改 anchor，边界句被 [ClampingScrollPhysics]
  /// 硬停到自然边缘）。不能直接 scrollTo——首帧 itemPositions 可能尚未就绪，会落入
  /// 「不可见分支」把 anchor 设成 0.5、边界留白且引入回弹。
  void _centerInitialFocus(int targetIndex) {
    if (!mounted ||
        !widget.autoFocusEnabled ||
        !_itemScrollController.isAttached) {
      if (mounted) setState(() => _initialFocusDone = true);
      return;
    }
    _itemScrollController.jumpTo(index: targetIndex, alignment: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoFocusEnabled ||
          !_itemScrollController.isAttached) {
        if (mounted) setState(() => _initialFocusDone = true);
        return;
      }
      _itemScrollController
          .scrollTo(
            index: targetIndex,
            // scrollTo 要求 duration > 0，瞬时落位用 1ms 近似（不可见，无观感）。
            duration: const Duration(milliseconds: 1),
            curve: Curves.easeInOut,
            alignment: autoFollowAlignment(targetVisible: true),
          )
          .whenComplete(() {
            if (mounted) setState(() => _initialFocusDone = true);
          });
    });
  }

  @override
  void didUpdateWidget(covariant ParagraphSentenceListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final playingChanged =
        widget.playingSentenceIndex != oldWidget.playingSentenceIndex;
    final paragraphChanged = widget.sentences != oldWidget.sentences;
    final focusReenabled =
        !oldWidget.autoFocusEnabled && widget.autoFocusEnabled;

    if (!widget.autoFocusEnabled) {
      _resumeFocusTimer?.cancel();
      _userSuspendedFocus = false;
      return;
    }

    if (focusReenabled) {
      _userSuspendedFocus = false;
      _focusPlayingSentence();
      return;
    }

    if ((playingChanged || paragraphChanged) && !_userSuspendedFocus) {
      _focusPlayingSentence();
    }
  }

  @override
  void dispose() {
    _resumeFocusTimer?.cancel();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.autoFocusEnabled || notification is! UserScrollNotification) {
      return false;
    }

    if (notification.direction == ScrollDirection.idle) {
      if (_userSuspendedFocus) {
        _resumeFocusTimer?.cancel();
        _resumeFocusTimer = Timer(widget.autoFocusResumeDelay, () {
          if (!mounted || !widget.autoFocusEnabled) return;
          _userSuspendedFocus = false;
          _focusPlayingSentence();
        });
      }
      return false;
    }

    _resumeFocusTimer?.cancel();
    _userSuspendedFocus = true;
    return false;
  }

  /// 自动跟随当前播放句，同时尊重用户手动滚动后的短暂停留。
  ///
  /// 仅用于「播放中逐句推进」的平滑跟随（[didUpdateWidget] / 手动滚动后恢复）。
  /// 「初次定位」（首次进入 / 切 Tab）不走这里，而是由 [initState] /
  /// [_centerInitialFocus] 在列表不可见时瞬时居中后淡入。
  void _focusPlayingSentence() {
    if (!widget.autoFocusEnabled || _userSuspendedFocus) return;
    final localSentenceIndex = _playingSentenceLocalIndex();
    if (localSentenceIndex == null) return;
    final targetIndex = localSentenceIndex * 2;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.autoFocusEnabled ||
          _userSuspendedFocus ||
          !_itemScrollController.isAttached) {
        return;
      }
      final position = _targetPosition(targetIndex);
      if (position == null) {
        // 目标尚未渲染（首次进入恢复进度 / 大跳转）。此时不能直接 scrollTo 居中：
        // 不可见分支会把底层 anchor 设为 alignment，居中会在边界留白。改为先即时
        // jumpTo 到 clamp 安全的 anchor=0 位置把目标渲染出来，下一帧再走可见分支
        // 居中，避免恢复进度时把当前句卡在顶部。
        _itemScrollController.jumpTo(
          index: targetIndex,
          alignment: autoFollowAlignment(targetVisible: false),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusPlayingSentence();
        });
        return;
      }
      // 已大致居中则不动，否则重新居中——边界句滚到自然边缘被 clamp 硬停。
      if (isTargetWellCentered(leadingEdge: position.itemLeadingEdge)) {
        return;
      }
      _itemScrollController.scrollTo(
        index: targetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: autoFollowAlignment(targetVisible: true),
      );
    });
  }

  /// 目标元素当前的可见位置；不在可见集合中（大跳转/未渲染）时返回 null。
  ///
  /// 用于：① 判断是否已居中（[isTargetWellCentered]）；② 决定 [scrollTo] 走
  /// 「可见分支」还是「跳转分支」，据此选 alignment（见 [autoFollowAlignment]）。
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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      // 初次定位完成前列表不可见，居中后淡入——用户看不到从顶部到中部的滚动。
      child: AnimatedOpacity(
        key: kParagraphListInitialFocusKey,
        opacity: _initialFocusDone ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            // 初次定位：首帧把当前句渲染在顶部（底层 anchor 仍为 0），随后在不可见
            // 时瞬时滚到居中（见 [initState] / [_centerInitialFocus]）。
            initialScrollIndex: _initialScrollIndex,
            // 硬停物理：自动跟随滚到自然边界即停，越界被逐帧 clamp，杜绝到头/尾时
            // 的自动回弹（详见 [autoFollowAlignment]）。
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
              final onSentenceTap = widget.onSentenceTap;
              final onSentencePlayFrom = widget.onSentencePlayFrom;
              return MaskedSentenceTile(
                sentence: sentence,
                displayMode: widget.displayMode,
                keywordIndices: widget.keywordMap[sentence.index] ?? const {},
                isPlayingSentence: sentenceIndex == widget.playingSentenceIndex,
                isBookmarked: widget.bookmarkedSentenceIndices.contains(
                  sentence.index,
                ),
                onDetailTap: onSentenceTap == null
                    ? null
                    : () => onSentenceTap(sentence),
                onPlayFromTap: onSentencePlayFrom == null
                    ? null
                    : () => onSentencePlayFrom(sentence),
                numberAreaGuideStep: isGuideTarget
                    ? widget.numberAreaGuideStep
                    : null,
                bodyAreaGuideStep: isGuideTarget
                    ? widget.bodyAreaGuideStep
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

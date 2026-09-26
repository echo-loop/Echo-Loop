import 'dart:async';

import 'package:flutter/material.dart';

import '../dictionary/dictionary_panel_host.dart';

/// 学习任务句子分页器的外部控制器。
///
/// 底部切句通过 [animateAndCommit] 先完成页面动画，再提交业务状态；自动推进与
/// 进度条跳转则由 [PracticeSentencePager.currentIndex] 反向同步页面。
class PracticeSentencePagerController {
  _PracticeSentencePagerState? _state;

  /// 将页面动画到 [targetIndex]，停稳后执行一次 [commit]。
  Future<void> animateAndCommit(
    int targetIndex, {
    required Future<void> Function() commit,
  }) async {
    final state = _state;
    if (state == null) {
      await commit();
      return;
    }
    await state.animateAndCommit(targetIndex, commit: commit);
  }

  void _attach(_PracticeSentencePagerState state) => _state = state;

  void _detach(_PracticeSentencePagerState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// 逐句精听与难句跟读共用的横向切句协调器。
///
/// 用户手势只在分页停稳后提交；程序化同步不会反向触发业务切句，避免自动推进
/// 或跨句恢复造成重复播放。相邻句统一使用 320ms 动画。
class PracticeSentencePager extends StatefulWidget {
  const PracticeSentencePager({
    super.key,
    required this.pageViewKey,
    required this.controller,
    required this.currentIndex,
    required this.itemCount,
    this.isTransitionLocked = false,
    required this.onSentenceSettled,
    required this.itemBuilder,
  });

  /// 供测试和页面定位内部 PageView 的稳定 key。
  final Key pageViewKey;

  /// 底部按钮等外部控件使用的分页控制器。
  final PracticeSentencePagerController controller;

  /// 业务状态中的当前句索引，是分页位置的唯一真实来源。
  final int currentIndex;

  /// 可分页的句子总数。
  final int itemCount;

  /// 是否正在执行不可被用户手势打断的自动翻页。
  final bool isTransitionLocked;

  /// 用户手势停稳后提交目标句索引。
  final Future<void> Function(int index) onSentenceSettled;

  /// 按句索引构建页面内容。
  final NullableIndexedWidgetBuilder itemBuilder;

  @override
  State<PracticeSentencePager> createState() => _PracticeSentencePagerState();
}

class _PracticeSentencePagerState extends State<PracticeSentencePager> {
  final PageController _pageController = PageController();
  bool _synced = false;
  bool _programmatic = false;
  bool _transitionInFlight = false;
  int? _pendingTarget;
  int? _pendingSource;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void didUpdateWidget(covariant PracticeSentencePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
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
    _syncPage(widget.currentIndex);
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: PageView.builder(
        key: widget.pageViewKey,
        physics:
            widget.isTransitionLocked ||
                DictionaryPanelHost.isPanelOpenOf(context)
            ? const NeverScrollableScrollPhysics()
            : null,
        controller: _pageController,
        itemCount: widget.itemCount,
        onPageChanged: _handlePageChanged,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }

  void _syncPage(int targetIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_transitionInFlight || widget.isTransitionLocked) {
        return;
      }
      final current = _pageController.page?.round();
      if (current == targetIndex) {
        _synced = true;
        return;
      }
      _programmatic = true;
      final animate =
          _synced && current != null && (targetIndex - current).abs() == 1;
      if (animate) {
        _pageController
            .animateToPage(
              targetIndex,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _programmatic = false);
      } else {
        _pageController.jumpToPage(targetIndex);
        _programmatic = false;
      }
      _synced = true;
    });
  }

  void _handlePageChanged(int index) {
    if (_programmatic) return;
    if (index == widget.currentIndex) {
      _pendingTarget = null;
      _pendingSource = null;
      return;
    }
    _pendingTarget = index;
    _pendingSource = widget.currentIndex;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal ||
        notification is! ScrollEndNotification ||
        _programmatic ||
        _transitionInFlight ||
        widget.isTransitionLocked) {
      return false;
    }
    final target = _pendingTarget;
    final source = _pendingSource;
    _pendingTarget = null;
    _pendingSource = null;
    if (target == null || source == null) return false;
    if (_pageController.page?.round() != target) return false;
    if (widget.currentIndex != source) return false;
    _transitionInFlight = true;
    unawaited(_commitSettledSentence(target));
    return false;
  }

  /// 提交用户滑动产生的目标句，并在异步业务提交完成前保持分页锁定。
  Future<void> _commitSettledSentence(int target) async {
    try {
      await widget.onSentenceSettled(target);
    } finally {
      _transitionInFlight = false;
    }
  }

  Future<void> animateAndCommit(
    int targetIndex, {
    required Future<void> Function() commit,
  }) async {
    if (!mounted ||
        _programmatic ||
        _pendingTarget != null ||
        _transitionInFlight ||
        widget.isTransitionLocked) {
      return;
    }
    _transitionInFlight = true;
    var shouldCommit = false;
    try {
      shouldCommit = await _animateToTarget(targetIndex);
    } finally {
      _transitionInFlight = false;
    }
    if (!shouldCommit || !mounted || widget.currentIndex == targetIndex) return;
    await commit();
  }

  /// 分页锁只保护动画；业务提交可能包含整句播放，不能占住交互锁。
  Future<bool> _animateToTarget(int targetIndex) async {
    if (targetIndex == widget.currentIndex) return false;
    if (!_pageController.hasClients) return true;
    _programmatic = true;
    try {
      await _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _programmatic = false;
    }
    return mounted && _pageController.page?.round() == targetIndex;
  }
}

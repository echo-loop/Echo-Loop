/// 调度 Flashcard 的纯 Dart 状态机。
library;

import 'dart:collection';

import 'package:collection/collection.dart';

import '../../memory_scheduler/domain/memory_rating.dart';
import '../../memory_scheduler/domain/memory_scheduler_results.dart';
import '../../../services/app_logger.dart';
import '../domain/scheduled_flashcard.dart';

/// 状态机快照。
final class ScheduledFlashcardSessionState<T> {
  /// 创建状态。
  const ScheduledFlashcardSessionState({
    required this.phase,
    required this.answerRevealed,
    required this.preview,
    required this.rating,
    required this.reviewedCount,
    required this.initialTotal,
    required this.remainingCount,
    required this.current,
    this.error,
  });

  final ScheduledFlashcardPhase phase;
  final bool answerRevealed;
  final MemoryRatingPreviewSet? preview;
  final MemoryRating? rating;
  final int reviewedCount;
  final int initialTotal;
  final int remainingCount;
  final ScheduledFlashcard<T>? current;
  final Object? error;

  int get processedCount => initialTotal - remainingCount;
}

/// 不执行 IO 的卡片状态机。
final class ScheduledFlashcardEngine<T> {
  /// 创建空会话。
  ScheduledFlashcardEngine()
    : _state = ScheduledFlashcardSessionState<T>(
        phase: ScheduledFlashcardPhase.loadingDeck,
        answerRevealed: false,
        preview: null,
        rating: null,
        reviewedCount: 0,
        initialTotal: 0,
        remainingCount: 0,
        current: null,
      );

  static const Duration retryWindow = Duration(minutes: 2);
  static const int _loggedCardLimit = 5;

  late ScheduledFlashcardSessionState<T> _state;
  final Queue<ScheduledFlashcard<T>> _pending = Queue<ScheduledFlashcard<T>>();
  final HeapPriorityQueue<_RetryEntry<T>> _retries =
      HeapPriorityQueue<_RetryEntry<T>>(_compareRetries);
  int _retrySequence = 0;
  ScheduledFlashcardSessionState<T> get state => _state;

  /// 当前卡之后即将展示的普通卡（按队列顺序，最多 [count] 张），供页面提前预热 AI 内容。
  ///
  /// 重试卡展示时机取决于到期时间且此前已展示过（内容已缓存），不纳入预热范围。
  List<ScheduledFlashcard<T>> upcoming(int count) {
    final current = _state.current;
    return _pending
        .where((card) => !identical(card, current))
        .take(count)
        .toList(growable: false);
  }

  void setDeck(List<ScheduledFlashcard<T>> deck, DateTime now) {
    _pending
      ..clear()
      ..addAll(deck);
    _retries.clear();
    _retrySequence = 0;
    _log('set_deck input=${_ids(deck)}');
    _setNext(now: now.toUtc(), initialTotal: deck.length);
  }

  /// 按新队列顺序重排尚未处理的卡片；新首卡变化时切回正面。
  bool reorderPending(List<ScheduledFlashcard<T>> orderedDeck) {
    if (_state.phase == ScheduledFlashcardPhase.completed ||
        _pending.length < 2) {
      return false;
    }
    final current = _state.current;
    final pending = _pending.toList(growable: false);
    final currentIsPending =
        current != null &&
        pending.isNotEmpty &&
        identical(pending.first, current);
    final order = {
      for (var index = 0; index < orderedDeck.length; index++)
        _subjectKey(orderedDeck[index]): index,
    };
    final remaining = pending.toList();
    final originalOrder = {
      for (var index = 0; index < remaining.length; index++)
        _subjectKey(remaining[index]): index,
    };
    remaining.sort((left, right) {
      final leftOrder = order[_subjectKey(left)];
      final rightOrder = order[_subjectKey(right)];
      if (leftOrder == null && rightOrder == null) {
        return (originalOrder[_subjectKey(left)] ?? 0).compareTo(
          originalOrder[_subjectKey(right)] ?? 0,
        );
      }
      if (leftOrder == null) return 1;
      if (rightOrder == null) return -1;
      final orderComparison = leftOrder.compareTo(rightOrder);
      return orderComparison != 0
          ? orderComparison
          : (originalOrder[_subjectKey(left)] ?? 0).compareTo(
              originalOrder[_subjectKey(right)] ?? 0,
            );
    });
    final nextCurrent = currentIsPending ? remaining.first : current;
    final currentChanged = currentIsPending && !identical(current, nextCurrent);
    _pending
      ..clear()
      ..addAll(remaining);
    _log('reorder_pending ordered=${_ids(_pending)}');
    _state = currentChanged
        ? _copy(
            phase: ScheduledFlashcardPhase.prompt,
            answerRevealed: false,
            current: nextCurrent ?? _state.current,
            clearPreview: true,
            rating: null,
            clearError: true,
          )
        : _copy();
    return currentChanged;
  }

  String _subjectKey(ScheduledFlashcard<T> card) =>
      '${card.subject.namespace}:${card.subject.subjectId}';

  /// 从队列中移除当前卡片，不提交评分、不计入 reviewedCount。
  ///
  /// 取消收藏后直接移除当前项，不产生评分事件或已复习计数。
  void removeCurrent(DateTime now) {
    if (_state.current == null) return;
    _log('remove_current card=${_id(_state.current!)} before=${_snapshot()}');
    _removeCurrentFromContainer();
    _setNext(now: now.toUtc());
  }

  void revealAnswer() {
    if (_state.phase != ScheduledFlashcardPhase.prompt) return;
    _state = _copy(phase: ScheduledFlashcardPhase.answer, answerRevealed: true);
  }

  void setPreview(MemoryRatingPreviewSet preview) {
    if (_state.phase != ScheduledFlashcardPhase.answer) return;
    _state = _copy(preview: preview, clearError: true);
  }

  void setError(Object error) => _state = _copy(error: error);

  /// 用服务端最新 revision 更新当前对象，保留其所在会话容器。
  void replaceCurrentRevision(int revision) {
    final current = _state.current;
    if (current == null) return;
    current.scheduleRevision = revision;
    _state = _copy();
  }

  void beginSubmitting(MemoryRating rating) {
    if (!_state.answerRevealed ||
        _state.phase != ScheduledFlashcardPhase.answer) {
      return;
    }
    _state = _copy(
      phase: ScheduledFlashcardPhase.submittingRating,
      rating: rating,
      clearError: true,
    );
  }

  /// 提交失败时回到可重试的答案面。
  void returnToAnswer(Object error) {
    _state = _copy(
      phase: ScheduledFlashcardPhase.answer,
      answerRevealed: true,
      error: error,
    );
  }

  /// 持久化评分成功后更新会话容器。
  void completeRating({
    required MemoryRating rating,
    required int scheduleRevision,
    required DateTime dueAt,
    required DateTime now,
  }) {
    final current = _state.current;
    if (current == null) return;
    _removeCurrentFromContainer();
    if (rating == MemoryRating.again) {
      current
        ..scheduleRevision = scheduleRevision
        ..dueAt = dueAt.toUtc()
        ..status = ScheduledFlashcardStatus.retry
        ..retryCount += 1;
      _retries.add(_RetryEntry<T>(current, _retrySequence++));
      _log(
        'rating_again card=${_id(current)} dueAt=${current.dueAt.toIso8601String()} '
        'retryCount=${current.retryCount} after=${_snapshot()}',
      );
      _setNext(now: now.toUtc());
      return;
    }
    _log(
      'rating_complete card=${_id(current)} rating=$rating before=${_snapshot()}',
    );
    _setNext(now: now.toUtc(), reviewedCount: _state.reviewedCount + 1);
  }

  ScheduledFlashcardSessionState<T> _copy({
    ScheduledFlashcardPhase? phase,
    bool? answerRevealed,
    MemoryRatingPreviewSet? preview,
    bool clearPreview = false,
    MemoryRating? rating,
    ScheduledFlashcard<T>? current,
    Object? error,
    bool clearError = false,
  }) {
    return ScheduledFlashcardSessionState<T>(
      phase: phase ?? _state.phase,
      answerRevealed: answerRevealed ?? _state.answerRevealed,
      preview: clearPreview ? null : preview ?? _state.preview,
      rating: rating ?? _state.rating,
      reviewedCount: _state.reviewedCount,
      initialTotal: _state.initialTotal,
      remainingCount: _state.remainingCount,
      current: current ?? _state.current,
      error: clearError ? null : error ?? _state.error,
    );
  }

  /// 选择下一个可处理项；普通卡永远优先，retry 仅在窗口内提前显示。
  void _setNext({
    required DateTime now,
    int? initialTotal,
    int? reviewedCount,
  }) {
    final retry = _retries.isNotEmpty ? _retries.first : null;
    final current = _pending.isNotEmpty
        ? _pending.first
        : retry != null && !retry.card.dueAt.isAfter(now.add(retryWindow))
        ? retry.card
        : null;
    final remainingCount = _pending.length + _retries.length;
    final source = _pending.isNotEmpty
        ? 'pending'
        : current == null
        ? 'none'
        : 'retry';
    _state = ScheduledFlashcardSessionState<T>(
      phase: current == null
          ? ScheduledFlashcardPhase.completed
          : ScheduledFlashcardPhase.prompt,
      answerRevealed: false,
      preview: null,
      rating: null,
      reviewedCount: reviewedCount ?? _state.reviewedCount,
      initialTotal: initialTotal ?? _state.initialTotal,
      remainingCount: remainingCount,
      current: current,
    );
    _log(
      'next source=$source card=${current == null ? 'none' : _id(current)} '
      'pending=${_ids(_pending)} retry=${_retryIds()} '
      'remaining=$remainingCount reviewed=${_state.reviewedCount} '
      'phase=${_state.phase}',
    );
  }

  void _removeCurrentFromContainer() {
    final current = _state.current;
    if (current == null) return;
    if (_pending.isNotEmpty && identical(_pending.first, current)) {
      _pending.removeFirst();
      return;
    }
    if (_retries.isNotEmpty && identical(_retries.first.card, current)) {
      _retries.removeFirst();
    }
  }

  static int _compareRetries<T>(_RetryEntry<T> left, _RetryEntry<T> right) {
    final due = left.card.dueAt.compareTo(right.card.dueAt);
    return due != 0 ? due : left.sequence.compareTo(right.sequence);
  }

  String _snapshot() =>
      'pending=${_ids(_pending)} retry=${_retryIds()} '
      'remaining=${_pending.length + _retries.length}';

  String _retryIds() {
    final entries = _retries.toList();
    final preview = entries
        .take(_loggedCardLimit)
        .map(
          (entry) =>
              '${_id(entry.card)}@${entry.card.dueAt.toIso8601String()}#${entry.sequence}',
        )
        .join(',');
    return 'count=${entries.length} first=[$preview]';
  }

  String _ids(Iterable<ScheduledFlashcard<T>> cards) {
    final count = cards.length;
    final preview = cards.take(_loggedCardLimit).map(_id).join(',');
    return 'count=$count first=[$preview]';
  }

  String _id(ScheduledFlashcard<T> card) =>
      '${card.subject.namespace}:${card.subject.subjectId}';

  void _log(String message) =>
      AppLogger.log('ScheduledFlashcardEngine', message);
}

final class _RetryEntry<T> {
  const _RetryEntry(this.card, this.sequence);
  final ScheduledFlashcard<T> card;
  final int sequence;
}

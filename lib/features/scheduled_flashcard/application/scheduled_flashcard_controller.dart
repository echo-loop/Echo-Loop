/// 调度 Flashcard 的异步应用控制器。
library;

import 'dart:async';

import 'package:clock/clock.dart';

import '../../memory_scheduler/domain/memory_rating.dart';
import '../../memory_scheduler/domain/memory_scheduler_commands.dart';
import '../../memory_scheduler/domain/memory_scheduler_exceptions.dart';
import '../../memory_scheduler/domain/memory_scheduler_results.dart';
import '../../memory_scheduler/application/memory_scheduler.dart';
import '../domain/scheduled_flashcard.dart';
import 'scheduled_flashcard_engine.dart';

/// 调度 Flashcard 的 IO 编排层。
final class ScheduledFlashcardController<T> {
  ScheduledFlashcardController({
    required FlashcardDeckSource<T> deckSource,
    required FlashcardRatingPort ratingPort,
    required MemoryIdGenerator operationIdGenerator,
    Clock? clock,
    void Function(String message)? logger,
  }) : _deckSource = deckSource,
       _ratingPort = ratingPort,
       _clock = clock ?? const Clock(),
       _operationIdGenerator = operationIdGenerator,
       _logger = logger ?? _ignoreLog;

  final FlashcardDeckSource<T> _deckSource;
  final FlashcardRatingPort _ratingPort;
  final Clock _clock;

  /// 为每次用户评分动作提供跨会话唯一的幂等键。
  ///
  /// 该依赖必须由生产装配注入 UUID 实现；控制器内递增值会在新会话中
  /// 重置，无法满足审计事件的持久化唯一约束。
  final MemoryIdGenerator _operationIdGenerator;
  final void Function(String message) _logger;
  final ScheduledFlashcardEngine<T> _engine = ScheduledFlashcardEngine<T>();
  final List<void Function()> _listeners = <void Function()>[];
  int _generation = 0;
  DateTime? _promptedAt;
  _PendingRatingSubmission? _pendingRatingSubmission;
  List<ScheduledFlashcard<T>>? _deferredOrder;
  bool _disposed = false;

  ScheduledFlashcardSessionState<T> get state => _engine.state;

  /// 当前卡之后即将展示的普通卡，见 [ScheduledFlashcardEngine.upcoming]。
  List<ScheduledFlashcard<T>> upcoming(int count) => _engine.upcoming(count);

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  Future<void> load() async {
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    _log('load.start generation=$generation');
    _engine.setError(StateError('loading'));
    _notify();
    try {
      final deck = await _deckSource.load();
      if (!_valid(generation)) {
        _log('load.discarded generation=$generation');
        return;
      }
      _engine.setDeck(deck, _clock.now().toUtc());
      _log(
        'load.success generation=$generation cards=${deck.length} '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      _promptedAt = _clock.now().toUtc();
      _pendingRatingSubmission = null;
      _notify();
    } catch (error) {
      if (!_valid(generation)) return;
      _log(
        'load.error generation=$generation '
        'elapsedMs=${stopwatch.elapsedMilliseconds} error=$error',
      );
      _engine.setError(error);
      _notify();
    }
  }

  /// 按新顺序重排待处理卡片，并返回当前卡是否因此发生变化。
  bool reorderPending(List<ScheduledFlashcard<T>> orderedDeck) {
    if (_disposed) {
      _log('reorder.ignored reason=disposed orderCount=${orderedDeck.length}');
      return false;
    }
    if (state.phase == ScheduledFlashcardPhase.submittingRating ||
        _pendingRatingSubmission != null) {
      final replaced = _deferredOrder != null;
      _deferredOrder = List<ScheduledFlashcard<T>>.unmodifiable(orderedDeck);
      _log(
        'reorder.deferred current=${_subjectId(state.current)} '
        'phase=${state.phase} orderCount=${orderedDeck.length} '
        'first=${_subjectId(orderedDeck.isEmpty ? null : orderedDeck.first)} '
        'pendingOperationId=${_pendingRatingSubmission?.operationId ?? 'none'} '
        'replacedPrevious=$replaced',
      );
      return false;
    }
    final currentBefore = _subjectId(state.current);
    final currentChanged = _applyOrder(orderedDeck);
    _log(
      'reorder.applied orderCount=${orderedDeck.length} '
      'requestedFirst=${_subjectId(orderedDeck.isEmpty ? null : orderedDeck.first)} '
      'currentBefore=$currentBefore currentAfter=${_subjectId(state.current)} '
      'currentChanged=$currentChanged generation=$_generation',
    );
    _notify();
    return currentChanged;
  }

  /// 应用提交期间暂存的顺序；只在提交结果已明确时调用。
  void _applyDeferredOrder() {
    final orderedDeck = _deferredOrder;
    _deferredOrder = null;
    if (orderedDeck == null) return;
    final currentBefore = _subjectId(state.current);
    final currentChanged = _applyOrder(orderedDeck);
    _log(
      'reorder.deferred_applied orderCount=${orderedDeck.length} '
      'requestedFirst=${_subjectId(orderedDeck.isEmpty ? null : orderedDeck.first)} '
      'currentBefore=$currentBefore currentAfter=${_subjectId(state.current)} '
      'currentChanged=$currentChanged generation=$_generation',
    );
  }

  bool _applyOrder(List<ScheduledFlashcard<T>> orderedDeck) {
    final currentChanged = _engine.reorderPending(orderedDeck);
    if (!currentChanged) return false;
    _generation++;
    _pendingRatingSubmission = null;
    _promptedAt = _clock.now().toUtc();
    return true;
  }

  void revealAnswer() {
    _log('reveal card=${state.current?.subject.subjectId}');
    _engine.revealAnswer();
    _notify();
  }

  Future<void> preview() async {
    final card = state.current;
    if (card == null || state.phase != ScheduledFlashcardPhase.answer) return;
    final generation = _generation;
    final reviewedAt = _clock.now().toUtc();
    _log(
      'preview.start card=${card.subject.subjectId} revision=${card.scheduleRevision} generation=$generation',
    );
    try {
      final result = await _requestPreview(
        card: card,
        generation: generation,
        reviewedAt: reviewedAt,
      );
      if (result == null) {
        _log(
          'preview.discarded card=${card.subject.subjectId} generation=$generation',
        );
        return;
      }
      _engine.setPreview(result);
      _log(
        'preview.success card=${card.subject.subjectId} revision=${result.revision} '
        'reviewedAt=${result.reviewedAt.toIso8601String()} '
        'again=${_previewSummary(result.again)} '
        'hard=${_previewSummary(result.hard)} '
        'good=${_previewSummary(result.good)} '
        'easy=${_previewSummary(result.easy)}',
      );
      _notify();
    } catch (error) {
      if (!_valid(generation)) return;
      _log('preview.error card=${card.subject.subjectId} error=$error');
      _engine.setError(error);
      _notify();
    }
  }

  /// 提交评分，并在持久化成功时返回 `true`。
  Future<bool> submitRating(MemoryRating rating) async {
    final card = state.current;
    if (card == null) {
      _log('submit.ignored reason=no_current_card phase=${state.phase}');
      return false;
    }
    if (state.phase != ScheduledFlashcardPhase.answer) {
      _log(
        'submit.ignored reason=wrong_phase card=${card.subject.subjectId} '
        'phase=${state.phase}',
      );
      return false;
    }
    final preview = state.preview;
    if (preview == null) {
      _log(
        'submit.ignored reason=missing_preview '
        'card=${card.subject.subjectId} phase=${state.phase}',
      );
      return false;
    }
    var pending = _pendingRatingSubmission;
    if (pending != null && pending.rating != rating) {
      // 改选评分是新的用户动作，不能复用旧动作的幂等快照。
      _pendingRatingSubmission = null;
      _log(
        'submit.replaced_different_rating card=${card.subject.subjectId} '
        'pending=${pending.rating} requested=$rating operationId=${pending.operationId}',
      );
      pending = null;
    }
    final isRetry = pending != null;
    _engine.beginSubmitting(rating);
    _notify();
    final generation = _generation;
    final submittedAt = _clock.now().toUtc();
    final responseTime = _responseTimeAt(submittedAt);
    var submission = pending;
    if (submission == null) {
      // 答案页的预测是本张卡唯一的时间快照；提交和重试都不能重算它。
      submission = _PendingRatingSubmission(
        rating: rating,
        preview: _previewFor(preview, rating),
        responseTime: responseTime,
        operationId: _operationIdGenerator.newId(),
      );
      _pendingRatingSubmission = submission;
    }
    final pendingSubmission = submission;
    _log(
      'submit.start card=${card.subject.subjectId} rating=$rating '
      'revision=${card.scheduleRevision} '
      'operationId=${pendingSubmission.operationId} generation=$generation '
      'retry=$isRetry '
      'reviewedAt=${pendingSubmission.preview.reviewedAt.toIso8601String()} '
      'dueAt=${pendingSubmission.preview.dueAt.toIso8601String()} '
      'intervalMs=${pendingSubmission.preview.interval.inMilliseconds} '
      'responseTimeMs=${pendingSubmission.responseTime.inMilliseconds}',
    );
    try {
      final result = await _ratingPort.submit(
        subject: card.subject,
        rating: rating,
        preview: pendingSubmission.preview,
        expectedRevision: card.scheduleRevision,
        responseTime: pendingSubmission.responseTime,
        operationId: pendingSubmission.operationId,
      );
      if (!_valid(generation) || state.current?.subject != card.subject) {
        _log(
          'submit.discarded card=${card.subject.subjectId} '
          'operationId=${pendingSubmission.operationId} generation=$generation '
          'activeGeneration=$_generation disposed=$_disposed '
          'current=${_subjectId(state.current)}',
        );
        return false;
      }
      _pendingRatingSubmission = null;
      _engine.completeRating(
        rating: rating,
        scheduleRevision: result.schedule.revision,
        dueAt: result.schedule.dueAt,
        now: _clock.now().toUtc(),
      );
      _applyDeferredOrder();
      _log(
        'submit.success card=${card.subject.subjectId} '
        'rating=$rating operationId=${pendingSubmission.operationId} '
        'revision=${result.schedule.revision} '
        'dueAt=${result.schedule.dueAt.toIso8601String()} '
        'reviewedAt=${result.event.reviewedAt.toIso8601String()} '
        'wasIdempotentReplay=${result.wasIdempotentReplay}',
      );
      _notify();
      return true;
    } catch (error) {
      if (!_valid(generation)) {
        _log(
          'submit.discarded_error card=${card.subject.subjectId} '
          'operationId=${pendingSubmission.operationId} generation=$generation '
          'activeGeneration=$_generation disposed=$_disposed error=$error',
        );
        return false;
      }
      if (error is MemoryScheduleConflictException) {
        _log(
          'submit.conflict card=${card.subject.subjectId} '
          'operationId=${pendingSubmission.operationId}',
        );
        // 乐观锁明确拒绝了该动作，不再用旧幂等快照重试。
        _pendingRatingSubmission = null;
        await _reloadAfterConflict(card, generation);
        _applyDeferredOrder();
        _notify();
        return false;
      }
      if (error is MemoryOperationIdConflictException ||
          error is MemoryIdempotencyReplayStaleException) {
        // 此 ID 已被历史事件确定性拒绝；下次用户主动评分必须创建新动作。
        _pendingRatingSubmission = null;
        _engine.returnToAnswer(error);
        _applyDeferredOrder();
        _log(
          'submit.operation_id_rejected card=${card.subject.subjectId} '
          'operationId=${pendingSubmission.operationId} error=$error',
        );
        _notify();
        return false;
      }
      _engine.returnToAnswer(error);
      _log(
        'submit.error card=${card.subject.subjectId} '
        'operationId=${pendingSubmission.operationId} outcome=unknown '
        'snapshotRetained=${identical(_pendingRatingSubmission, pendingSubmission)} '
        'deferredOrder=${_deferredOrder != null} error=$error',
      );
      _notify();
      return false;
    }
  }

  /// 跳过当前卡片但不提交评分，用于"取消收藏"等业务动作完成后推进队列。
  void removeCurrent() {
    _generation++;
    _pendingRatingSubmission = null;
    _log('remove_current card=${state.current?.subject.subjectId}');
    _engine.removeCurrent(_clock.now().toUtc());
    _promptedAt = _clock.now().toUtc();
    _notify();
  }

  void dispose() {
    _log('dispose generation=$_generation');
    _disposed = true;
    _generation++;
    _deferredOrder = null;
    _listeners.clear();
  }

  Future<void> _reloadAfterConflict(
    ScheduledFlashcard<T> card,
    int generation,
  ) async {
    _log(
      'submit.conflict_reload.start card=${card.subject.subjectId} '
      'generation=$generation',
    );
    try {
      final revision = await _ratingPort.reloadRevision(card.subject);
      if (!_valid(generation) || state.current?.subject != card.subject) {
        _log(
          'submit.conflict_reload.discarded card=${card.subject.subjectId} '
          'generation=$generation activeGeneration=$_generation '
          'current=${_subjectId(state.current)} disposed=$_disposed',
        );
        return;
      }
      _pendingRatingSubmission = null;
      _engine.replaceCurrentRevision(revision);
      _log(
        'submit.conflict_reload.success card=${card.subject.subjectId} '
        'revision=$revision',
      );
      _engine.returnToAnswer(
        const MemoryScheduleConflictException('评分已刷新，请重新确认。'),
      );
      _notify();
      await preview();
    } catch (error) {
      if (!_valid(generation)) {
        _log(
          'submit.conflict_reload.discarded_error '
          'card=${card.subject.subjectId} generation=$generation '
          'activeGeneration=$_generation disposed=$_disposed error=$error',
        );
        return;
      }
      _log(
        'submit.conflict_reload.error card=${card.subject.subjectId} '
        'generation=$generation error=$error',
      );
      _engine.returnToAnswer(error);
      _notify();
    }
  }

  Duration _responseTimeAt(DateTime at) {
    final start = _promptedAt;
    if (start == null) return Duration.zero;
    final elapsed = at.difference(start);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Future<MemoryRatingPreviewSet?> _requestPreview({
    required ScheduledFlashcard<T> card,
    required int generation,
    required DateTime reviewedAt,
  }) async {
    final result = await _ratingPort.preview(
      subject: card.subject,
      expectedRevision: card.scheduleRevision,
      reviewedAt: reviewedAt,
    );
    if (!_valid(generation) || state.current?.subject != card.subject) {
      return null;
    }
    return result;
  }

  MemoryRatingPreview _previewFor(
    MemoryRatingPreviewSet previews,
    MemoryRating rating,
  ) => switch (rating) {
    MemoryRating.again => previews.again,
    MemoryRating.hard => previews.hard,
    MemoryRating.good => previews.good,
    MemoryRating.easy => previews.easy,
  };

  String _previewSummary(MemoryRatingPreview preview) =>
      'dueAt=${preview.dueAt.toIso8601String()},'
      'intervalMs=${preview.interval.inMilliseconds}';

  String _subjectId(ScheduledFlashcard<T>? card) =>
      card?.subject.subjectId ?? 'none';

  bool _valid(int generation) => !_disposed && generation == _generation;
  static void _ignoreLog(String message) {}
  void _log(String message) => _logger('[SCHEDULED_FLASHCARD] $message');
  void _notify() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}

/// 一次评分动作的不可变提交快照，保证失败重试不会改变已选结果。
final class _PendingRatingSubmission {
  const _PendingRatingSubmission({
    required this.rating,
    required this.preview,
    required this.responseTime,
    required this.operationId,
  });

  final MemoryRating rating;
  final MemoryRatingPreview preview;
  final Duration responseTime;
  final String operationId;
}

/// 将通用评分端口映射到 MemoryScheduler facade。
final class MemorySchedulerFlashcardRatingPort implements FlashcardRatingPort {
  const MemorySchedulerFlashcardRatingPort(this._scheduler);
  final MemoryScheduler _scheduler;

  @override
  Future<MemoryRatingPreviewSet> preview({
    required subject,
    required int expectedRevision,
    required DateTime reviewedAt,
  }) => _scheduler.previewRatings(
    PreviewMemoryRatingsQuery(
      subject: subject,
      expectedRevision: expectedRevision,
      reviewedAt: reviewedAt,
    ),
  );

  @override
  Future<MemoryReviewResult> submit({
    required subject,
    required MemoryRating rating,
    required MemoryRatingPreview preview,
    required int expectedRevision,
    required Duration responseTime,
    required String operationId,
  }) => _scheduler.review(
    ReviewMemoryCommand(
      subject: subject,
      rating: rating,
      preview: preview,
      expectedRevision: expectedRevision,
      reviewedAt: preview.reviewedAt,
      responseTime: responseTime,
      operationId: operationId,
    ),
  );

  @override
  Future<int> reloadRevision(subject) async {
    final schedule = await _scheduler.getSchedule(subject);
    if (schedule == null) {
      throw const MemoryScheduleNotFoundException('调度不存在。');
    }
    return schedule.revision;
  }
}

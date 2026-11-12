import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/features/memory_scheduler/domain/memory_profile.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_model_adapter.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_review_event.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_exceptions.dart';
import 'package:echo_loop/features/memory_scheduler/application/memory_scheduler.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_results.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/features/scheduled_flashcard/application/scheduled_flashcard_controller.dart';
import 'package:echo_loop/features/scheduled_flashcard/application/scheduled_flashcard_engine.dart';
import 'package:echo_loop/features/scheduled_flashcard/domain/scheduled_flashcard.dart';

void main() {
  final now = DateTime.utc(2026, 8, 22, 12);
  ScheduledFlashcard<String> card(String id, {DateTime? dueAt}) =>
      ScheduledFlashcard<String>(
        subject: MemorySubjectRef(namespace: 'test', subjectId: id),
        content: id,
        scheduleRevision: 3,
        dueAt: dueAt ?? now,
      );

  test('engine enforces prompt, answer, submitting and completion order', () {
    final first = card('one');
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(<ScheduledFlashcard<String>>[first], now);
    expect(engine.state.phase, ScheduledFlashcardPhase.prompt);

    engine.beginSubmitting(MemoryRating.good);
    expect(engine.state.phase, ScheduledFlashcardPhase.prompt);
    engine.revealAnswer();
    engine.beginSubmitting(MemoryRating.again);
    expect(engine.state.phase, ScheduledFlashcardPhase.submittingRating);
    engine.completeRating(
      rating: MemoryRating.good,
      scheduleRevision: 4,
      dueAt: now.add(const Duration(days: 1)),
      now: now,
    );
    expect(engine.state.phase, ScheduledFlashcardPhase.completed);
    expect(engine.state.reviewedCount, 1);
  });

  test('empty deck completes immediately', () {
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(const <ScheduledFlashcard<String>>[], now);
    expect(engine.state.phase, ScheduledFlashcardPhase.completed);
  });

  test('reordering immediately selects the first unreviewed card', () {
    final first = card('one');
    final second = card('two');
    final third = card('three');
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(<ScheduledFlashcard<String>>[first, second, third], now);
    engine.revealAnswer();

    engine.reorderPending(<ScheduledFlashcard<String>>[third, second, first]);

    expect(engine.state.current, same(third));
    expect(engine.state.phase, ScheduledFlashcardPhase.prompt);
    expect(engine.state.answerRevealed, isFalse);
    expect(engine.state.initialTotal, 3);
    expect(engine.state.remainingCount, 3);
    expect(engine.state.reviewedCount, 0);

    engine.removeCurrent(now);
    expect(engine.state.current, same(second));
    expect(engine.state.remainingCount, 2);
  });

  test('upcoming 返回当前卡之后的普通卡，不含当前卡与重试卡', () {
    final first = card('one');
    final second = card('two');
    final third = card('three');
    final fourth = card('four');
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(<ScheduledFlashcard<String>>[
      first,
      second,
      third,
      fourth,
    ], now);

    expect(engine.upcoming(2), <ScheduledFlashcard<String>>[second, third]);

    // 评「重来」进入重试队列：重试卡不纳入预热，后续普通卡顺延。
    engine.revealAnswer();
    engine.beginSubmitting(MemoryRating.again);
    engine.completeRating(
      rating: MemoryRating.again,
      scheduleRevision: 4,
      dueAt: now,
      now: now,
    );
    expect(engine.state.current, same(second));
    expect(engine.upcoming(2), <ScheduledFlashcard<String>>[third, fourth]);

    engine
      ..removeCurrent(now)
      ..removeCurrent(now)
      ..removeCurrent(now);
    // 普通卡用尽、当前为重试卡时没有可预热的后续卡。
    expect(engine.state.current, same(first));
    expect(engine.upcoming(2), isEmpty);
  });

  group('removeCurrent', () {
    final first = card('one');
    final second = card('two');
    final third = card('three');

    test(
      'removing current advances the FIFO queue without a snapshot or index',
      () {
        final engine = ScheduledFlashcardEngine<String>();
        engine.setDeck(<ScheduledFlashcard<String>>[first, second, third], now);
        engine.removeCurrent(now);
        expect(engine.state.current, second);
        expect(engine.state.phase, ScheduledFlashcardPhase.prompt);
        expect(engine.state.reviewedCount, 0);
        expect(engine.state.initialTotal, 3);
        expect(engine.state.remainingCount, 2);
      },
    );

    test('removing the only remaining card completes the session', () {
      final engine = ScheduledFlashcardEngine<String>();
      engine.setDeck(<ScheduledFlashcard<String>>[first], now);
      engine.removeCurrent(now);
      expect(engine.state.current, isNull);
      expect(engine.state.phase, ScheduledFlashcardPhase.completed);
    });

    test('controller bumps generation so stale preview is discarded', () async {
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[
          first,
          second,
        ]),
        ratingPort: _FakeRatingPort(),
        operationIdGenerator: _FixedIds(),
      );
      await controller.load();
      controller.revealAnswer();
      final stalePreview = controller.preview();
      controller.removeCurrent();
      await stalePreview;
      expect(controller.state.current, second);
      expect(controller.state.preview, isNull);
    });
  });

  test(
    'Again requeues the identical card after pending cards without duplication',
    () {
      final first = card('one');
      final second = card('two');
      final engine = ScheduledFlashcardEngine<String>();
      engine.setDeck(<ScheduledFlashcard<String>>[first, second], now);

      engine.completeRating(
        rating: MemoryRating.again,
        scheduleRevision: 4,
        dueAt: now.add(const Duration(minutes: 1)),
        now: now,
      );

      expect(engine.state.current, second);
      expect(engine.state.remainingCount, 2);
      expect(engine.state.reviewedCount, 0);

      engine.completeRating(
        rating: MemoryRating.good,
        scheduleRevision: 4,
        dueAt: now.add(const Duration(days: 1)),
        now: now,
      );

      expect(identical(engine.state.current, first), isTrue);
      expect(first.status, ScheduledFlashcardStatus.retry);
      expect(first.retryCount, 1);
      expect(first.scheduleRevision, 4);
      expect(engine.state.initialTotal, 2);
      expect(engine.state.reviewedCount, 1);
    },
  );

  test('retry inside the two-minute window is shown without waiting', () {
    final first = card('one');
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(<ScheduledFlashcard<String>>[first], now);

    engine.completeRating(
      rating: MemoryRating.again,
      scheduleRevision: 4,
      dueAt: now.add(const Duration(minutes: 2)),
      now: now,
    );

    expect(engine.state.current, first);
    expect(engine.state.phase, ScheduledFlashcardPhase.prompt);
  });

  test('retry outside the two-minute window completes this session', () {
    final first = card('one');
    final engine = ScheduledFlashcardEngine<String>();
    engine.setDeck(<ScheduledFlashcard<String>>[first], now);

    engine.completeRating(
      rating: MemoryRating.again,
      scheduleRevision: 4,
      dueAt: now.add(const Duration(minutes: 2, seconds: 1)),
      now: now,
    );

    expect(engine.state.current, isNull);
    expect(engine.state.phase, ScheduledFlashcardPhase.completed);
    expect(engine.state.remainingCount, 1);
  });

  test(
    'retry priority uses earliest dueAt instead of Again submission order',
    () {
      final first = card('one');
      final second = card('two');
      final engine = ScheduledFlashcardEngine<String>();
      engine.setDeck(<ScheduledFlashcard<String>>[first, second], now);

      engine.completeRating(
        rating: MemoryRating.again,
        scheduleRevision: 4,
        dueAt: now.add(const Duration(minutes: 1)),
        now: now,
      );
      engine.completeRating(
        rating: MemoryRating.again,
        scheduleRevision: 4,
        dueAt: now.add(const Duration(seconds: 30)),
        now: now,
      );

      expect(engine.state.current, second);
    },
  );

  test('controller submits rating with stable idempotent revision', () async {
    final first = card('one');
    final port = _FakeRatingPort();
    final controller = ScheduledFlashcardController<String>(
      deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[first]),
      ratingPort: port,
      operationIdGenerator: _FixedIds(),
    );
    await controller.load();
    controller.revealAnswer();
    await controller.preview();
    await controller.submitRating(MemoryRating.again);

    expect(port.lastRevision, 3);
    expect(port.lastOperationId, 'op-1');
    expect(controller.state.phase, ScheduledFlashcardPhase.prompt);
    expect(identical(controller.state.current, first), isTrue);
    expect(first.status, ScheduledFlashcardStatus.retry);
    expect(first.retryCount, 1);
    expect(controller.state.initialTotal, 1);
    expect(controller.state.reviewedCount, 0);
    controller.dispose();
  });

  test(
    'controller submits the preview created when the answer is revealed',
    () async {
      var currentTime = now;
      final port = _RecordingRatingPort();
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[card('one')]),
        ratingPort: port,
        clock: Clock(() => currentTime),
        operationIdGenerator: _FixedIds(),
      );

      await controller.load();
      controller.revealAnswer();
      await controller.preview();

      currentTime = now.add(const Duration(minutes: 30));
      await controller.submitRating(MemoryRating.good);

      expect(port.previewTimes, <DateTime>[now]);
      expect(port.submittedPreviews, hasLength(1));
      expect(port.submittedPreviews.single.reviewedAt, now);
      expect(port.submittedResponseTimes.single, const Duration(minutes: 30));
      controller.dispose();
    },
  );

  test(
    'rating retries reuse the first submission snapshot for idempotency',
    () async {
      var currentTime = now;
      final port = _RecordingRatingPort(failFirstSubmit: true);
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[card('one')]),
        ratingPort: port,
        clock: Clock(() => currentTime),
        operationIdGenerator: _FixedIds(),
      );

      await controller.load();
      controller.revealAnswer();
      await controller.preview();
      currentTime = now.add(const Duration(minutes: 30));

      await controller.submitRating(MemoryRating.good);
      expect(controller.state.phase, ScheduledFlashcardPhase.answer);

      currentTime = now.add(const Duration(hours: 1));
      await controller.submitRating(MemoryRating.good);

      expect(port.operationIds, <String>['op-1', 'op-1']);
      expect(port.submittedPreviews, hasLength(2));
      expect(
        port.submittedPreviews[0].reviewedAt,
        port.submittedPreviews[1].reviewedAt,
      );
      expect(port.submittedResponseTimes, <Duration>[
        const Duration(minutes: 30),
        const Duration(minutes: 30),
      ]);
      expect(controller.state.phase, ScheduledFlashcardPhase.completed);
      controller.dispose();
    },
  );

  test(
    'reordering waits for a rating retry after an uncertain submission',
    () async {
      final first = card('one');
      final second = card('two');
      final third = card('three');
      final port = _GatedRatingPort();
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[
          first,
          second,
          third,
        ]),
        ratingPort: port,
        operationIdGenerator: _FixedIds(),
      );

      await controller.load();
      controller.revealAnswer();
      await controller.preview();
      final firstSubmission = controller.submitRating(MemoryRating.good);
      await port.firstSubmitStarted.future;

      expect(
        controller.reorderPending(<ScheduledFlashcard<String>>[
          third,
          second,
          first,
        ]),
        isFalse,
      );
      expect(controller.state.current, same(first));
      port.firstSubmit.completeError(StateError('submit response lost'));
      expect(await firstSubmission, isFalse);
      expect(controller.state.current, same(first));
      expect(controller.state.phase, ScheduledFlashcardPhase.answer);

      controller.reorderPending(<ScheduledFlashcard<String>>[
        third,
        second,
        first,
      ]);
      expect(controller.state.current, same(first));
      expect(await controller.submitRating(MemoryRating.good), isTrue);

      expect(port.operationIds, <String>['op-1', 'op-1']);
      expect(controller.state.current, same(third));
      expect(controller.state.reviewedCount, 1);
      expect(controller.state.remainingCount, 2);
      controller.dispose();
    },
  );

  test(
    'a different rating after a failed submission creates a new action',
    () async {
      var currentTime = now;
      final port = _RecordingRatingPort(failFirstSubmit: true);
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[card('one')]),
        ratingPort: port,
        clock: Clock(() => currentTime),
        operationIdGenerator: _SequenceIds(<String>['op-1', 'op-2']),
      );

      await controller.load();
      controller.revealAnswer();
      await controller.preview();
      currentTime = now.add(const Duration(minutes: 30));
      await controller.submitRating(MemoryRating.good);

      currentTime = now.add(const Duration(hours: 1));
      await controller.submitRating(MemoryRating.again);

      expect(port.operationIds, <String>['op-1', 'op-2']);
      expect(port.submittedRatings, <MemoryRating>[
        MemoryRating.good,
        MemoryRating.again,
      ]);
      expect(port.previewTimes, <DateTime>[now]);
      expect(controller.state.phase, ScheduledFlashcardPhase.prompt);
      controller.dispose();
    },
  );

  test('late deck result is discarded after dispose', () async {
    final first = card('one');
    final source = _CompletingDeckSource();
    final controller = ScheduledFlashcardController<String>(
      deckSource: source,
      ratingPort: _FakeRatingPort(),
      operationIdGenerator: _FixedIds(),
    );
    final load = controller.load();
    controller.dispose();
    source.complete(<ScheduledFlashcard<String>>[first]);
    await load;
    expect(controller.state.current, isNull);
  });

  test('late deck result is discarded after a newer initialization', () async {
    final source = _SequencedCompletingDeckSource();
    final controller = ScheduledFlashcardController<String>(
      deckSource: source,
      ratingPort: _FakeRatingPort(),
      operationIdGenerator: _FixedIds(),
    );
    final firstLoad = controller.load();
    final secondLoad = controller.load();

    source.complete(1, <ScheduledFlashcard<String>>[card('new')]);
    await secondLoad;
    source.complete(0, <ScheduledFlashcard<String>>[card('old')]);
    await firstLoad;

    expect(controller.state.current?.content, 'new');
    controller.dispose();
  });

  test('independent sessions use different operation IDs', () async {
    final ids = _SequenceIds(<String>['uuid-action-1', 'uuid-action-2']);
    final port = _FakeRatingPort();

    for (var index = 0; index < 2; index++) {
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[
          card('$index'),
        ]),
        ratingPort: port,
        operationIdGenerator: ids,
      );
      await controller.load();
      controller.revealAnswer();
      await controller.preview();
      await controller.submitRating(MemoryRating.good);
      controller.dispose();
    }

    expect(port.operationIds, <String>['uuid-action-1', 'uuid-action-2']);
  });

  test(
    'operation ID rejection clears the pending ID for a new user action',
    () async {
      final port = _RejectOnceRatingPort();
      final controller = ScheduledFlashcardController<String>(
        deckSource: _FakeDeckSource(<ScheduledFlashcard<String>>[card('one')]),
        ratingPort: port,
        operationIdGenerator: _SequenceIds(<String>[
          'legacy-conflict',
          'uuid-action-2',
        ]),
      );
      await controller.load();
      controller.revealAnswer();
      await controller.preview();

      await controller.submitRating(MemoryRating.good);
      expect(controller.state.phase, ScheduledFlashcardPhase.answer);
      await controller.submitRating(MemoryRating.good);

      expect(port.operationIds, <String>['legacy-conflict', 'uuid-action-2']);
      expect(controller.state.phase, ScheduledFlashcardPhase.completed);
    },
  );
}

final class _FakeDeckSource implements FlashcardDeckSource<String> {
  _FakeDeckSource(this.cards);
  final List<ScheduledFlashcard<String>> cards;
  @override
  Future<List<ScheduledFlashcard<String>>> load() async => cards;
}

final class _CompletingDeckSource implements FlashcardDeckSource<String> {
  final _completer = Completer<List<ScheduledFlashcard<String>>>();
  @override
  Future<List<ScheduledFlashcard<String>>> load() => _completer.future;
  void complete(List<ScheduledFlashcard<String>> cards) =>
      _completer.complete(cards);
}

final class _SequencedCompletingDeckSource
    implements FlashcardDeckSource<String> {
  final _completers = <Completer<List<ScheduledFlashcard<String>>>>[
    Completer<List<ScheduledFlashcard<String>>>(),
    Completer<List<ScheduledFlashcard<String>>>(),
  ];
  var _next = 0;

  @override
  Future<List<ScheduledFlashcard<String>>> load() =>
      _completers[_next++].future;

  void complete(int index, List<ScheduledFlashcard<String>> cards) =>
      _completers[index].complete(cards);
}

final class _FixedIds implements MemoryIdGenerator {
  @override
  String newId() => 'op-1';
}

final class _SequenceIds implements MemoryIdGenerator {
  _SequenceIds(this._ids);
  final List<String> _ids;
  var _index = 0;

  @override
  String newId() => _ids[_index++];
}

final class _RecordingRatingPort extends _FakeRatingPort {
  _RecordingRatingPort({this.failFirstSubmit = false});

  final bool failFirstSubmit;
  final previewTimes = <DateTime>[];
  final submittedPreviews = <MemoryRatingPreview>[];
  final submittedResponseTimes = <Duration>[];
  final submittedRatings = <MemoryRating>[];
  var _submitAttempts = 0;

  @override
  Future<MemoryRatingPreviewSet> preview({
    required MemorySubjectRef subject,
    required int expectedRevision,
    required DateTime reviewedAt,
  }) async {
    previewTimes.add(reviewedAt);
    return super.preview(
      subject: subject,
      expectedRevision: expectedRevision,
      reviewedAt: reviewedAt,
    );
  }

  @override
  Future<MemoryReviewResult> submit({
    required MemorySubjectRef subject,
    required MemoryRating rating,
    required MemoryRatingPreview preview,
    required int expectedRevision,
    required Duration responseTime,
    required String operationId,
  }) {
    _submitAttempts++;
    submittedPreviews.add(preview);
    submittedResponseTimes.add(responseTime);
    submittedRatings.add(rating);
    if (failFirstSubmit && _submitAttempts == 1) {
      operationIds.add(operationId);
      return Future<MemoryReviewResult>.error(StateError('submit failed'));
    }
    return super.submit(
      subject: subject,
      rating: rating,
      preview: preview,
      expectedRevision: expectedRevision,
      responseTime: responseTime,
      operationId: operationId,
    );
  }
}

final class _GatedRatingPort extends _FakeRatingPort {
  final firstSubmitStarted = Completer<void>();
  final firstSubmit = Completer<MemoryReviewResult>();
  var _submitAttempts = 0;

  @override
  Future<MemoryReviewResult> submit({
    required MemorySubjectRef subject,
    required MemoryRating rating,
    required MemoryRatingPreview preview,
    required int expectedRevision,
    required Duration responseTime,
    required String operationId,
  }) {
    _submitAttempts++;
    if (_submitAttempts == 1) {
      operationIds.add(operationId);
      firstSubmitStarted.complete();
      return firstSubmit.future;
    }
    return super.submit(
      subject: subject,
      rating: rating,
      preview: preview,
      expectedRevision: expectedRevision,
      responseTime: responseTime,
      operationId: operationId,
    );
  }
}

class _FakeRatingPort implements FlashcardRatingPort {
  int? lastRevision;
  String? lastOperationId;
  final operationIds = <String>[];
  @override
  Future<MemoryRatingPreviewSet> preview({
    required MemorySubjectRef subject,
    required int expectedRevision,
    required DateTime reviewedAt,
  }) async {
    final state = MemoryModelState(
      version: 1,
      values: const <String, Object?>{},
    );
    MemoryRatingPreview item(MemoryRating rating) => MemoryRatingPreview(
      scheduleId: 'schedule',
      revision: expectedRevision,
      rating: rating,
      reviewedAt: reviewedAt,
      dueAt: reviewedAt,
      interval: Duration.zero,
      phase: MemorySchedulePhase.learning,
      transition: MemoryModelTransition(
        state: state,
        phase: MemorySchedulePhase.learning,
        dueAt: reviewedAt,
        lastReviewedAt: reviewedAt,
      ),
    );
    return MemoryRatingPreviewSet(
      scheduleId: 'schedule',
      revision: expectedRevision,
      reviewedAt: reviewedAt,
      again: item(MemoryRating.again),
      hard: item(MemoryRating.hard),
      good: item(MemoryRating.good),
      easy: item(MemoryRating.easy),
    );
  }

  @override
  Future<MemoryReviewResult> submit({
    required MemorySubjectRef subject,
    required MemoryRating rating,
    required MemoryRatingPreview preview,
    required int expectedRevision,
    required Duration responseTime,
    required String operationId,
  }) async {
    lastRevision = expectedRevision;
    lastOperationId = operationId;
    operationIds.add(operationId);
    final now = preview.reviewedAt;
    final profile = MemoryProfileRef(profileId: 'test', profileVersion: 1);
    final schedule = MemorySchedule(
      id: 'schedule',
      subject: subject,
      profile: profile,
      modelId: 'test',
      modelStateVersion: 1,
      phase: MemorySchedulePhase.learning,
      status: MemoryScheduleStatus.active,
      createdAt: now,
      updatedAt: now,
      lastReviewedAt: now,
      dueAt: now,
      reviewCount: 1,
      lapseCount: rating == MemoryRating.again ? 1 : 0,
      revision: expectedRevision + 1,
      modelState: const <String, Object?>{},
      archivedAt: null,
    );
    final event = MemoryReviewEvent(
      id: 'event',
      scheduleId: schedule.id,
      sequence: 1,
      operationId: operationId,
      rating: rating,
      isLapse: rating == MemoryRating.again,
      reviewedAt: now,
      responseTime: responseTime,
      profile: profile,
      modelId: 'test',
      modelStateVersion: 1,
      dueBefore: now,
      dueAfter: now,
      scheduleRevisionAfter: expectedRevision + 1,
      createdAt: now,
    );
    return MemoryReviewResult(
      schedule: schedule,
      event: event,
      wasIdempotentReplay: false,
    );
  }

  @override
  Future<int> reloadRevision(MemorySubjectRef subject) async => 4;
}

final class _RejectOnceRatingPort extends _FakeRatingPort {
  var _shouldReject = true;

  @override
  Future<MemoryReviewResult> submit({
    required MemorySubjectRef subject,
    required MemoryRating rating,
    required MemoryRatingPreview preview,
    required int expectedRevision,
    required Duration responseTime,
    required String operationId,
  }) {
    if (_shouldReject) {
      _shouldReject = false;
      operationIds.add(operationId);
      return Future<MemoryReviewResult>.error(
        const MemoryOperationIdConflictException('legacy operation ID'),
      );
    }
    return super.submit(
      subject: subject,
      rating: rating,
      preview: preview,
      expectedRevision: expectedRevision,
      responseTime: responseTime,
      operationId: operationId,
    );
  }
}

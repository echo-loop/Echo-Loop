import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/study_statistics_dao.dart';
import 'package:echo_loop/features/review_statistics/review_statistics_repository.dart';
import 'package:echo_loop/models/study_stage.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
  });

  tearDown(() => db.close());

  test('空数据库返回稳定的零值趋势', () async {
    final now = DateTime(2026, 8, 22, 10);
    final stats = await ReviewStatisticsRepository(db).load(now: now);

    expect(stats.todayReviewedCards, 0);
    expect(stats.todaySeconds, 0);
    expect(stats.dueNow, 0);
    expect(stats.streak, 0);
    expect(stats.retentionRate, 0);
    expect(stats.dailyTrend, hasLength(30));
    expect(stats.upcomingDue, hasLength(7));
    expect(stats.dailyTrend.every((day) => day.reviewedCards == 0), isTrue);
  });

  test('评分仅统计近30天首次评分，安排区分当前到期与未来自然日', () async {
    final now = DateTime(2026, 8, 22, 10);
    await db.savedWordDao.saveWord(word: 'tomorrow');
    final savedWord = await db.savedWordDao.getByWord('tomorrow');
    await _insertSchedule(
      db,
      id: 'sentence-due-now',
      namespace: 'saved_sentence',
      dueAt: now.subtract(const Duration(minutes: 1)),
    );
    await _insertSchedule(
      db,
      id: 'vocabulary-tomorrow',
      namespace: 'saved_word_or_phrase',
      subjectId: savedWord!.memorySubjectId!,
      dueAt: now.add(const Duration(days: 1)),
    );
    await _insertSchedule(
      db,
      id: 'vocabulary-orphan',
      namespace: 'saved_word_or_phrase',
      dueAt: now.add(const Duration(days: 1)),
    );
    await _insertSchedule(
      db,
      id: 'sentence-recent-good',
      namespace: 'saved_sentence',
      dueAt: now.add(const Duration(days: 3)),
    );
    await _insertEvent(
      db,
      id: 'old-good',
      scheduleId: 'sentence-due-now',
      sequence: 1,
      rating: 'good',
      reviewedAt: now.subtract(const Duration(days: 31)),
    );
    await _insertEvent(
      db,
      id: 'recent-again',
      scheduleId: 'sentence-due-now',
      sequence: 2,
      rating: 'again',
      reviewedAt: now.subtract(const Duration(minutes: 10)),
    );
    await _insertEvent(
      db,
      id: 'recent-retry',
      scheduleId: 'sentence-due-now',
      sequence: 3,
      rating: 'easy',
      reviewedAt: now.subtract(const Duration(minutes: 5)),
    );
    await _insertEvent(
      db,
      id: 'recent-good',
      scheduleId: 'sentence-recent-good',
      sequence: 1,
      rating: 'good',
      reviewedAt: now.subtract(const Duration(minutes: 2)),
    );

    final stats = await ReviewStatisticsRepository(db).load(now: now);

    expect(stats.ratings.total, 2);
    expect(stats.ratings.again, 1);
    expect(stats.ratings.good, 1);
    expect(stats.ratings.easy, 0);
    expect(stats.retentionRate, 0.5);
    expect(stats.dueNow, 1);
    expect(stats.overdueNow, 0);
    expect(stats.upcomingDue[0], 1);
    expect(stats.upcomingDue[1], 1);
  });

  test('当前待复习数明确拆分逾期与今天到期', () async {
    final now = DateTime(2026, 8, 22, 10);
    await _insertSchedule(
      db,
      id: 'overdue',
      namespace: 'saved_sentence',
      dueAt: DateTime(2026, 8, 21, 23),
    );
    await _insertSchedule(
      db,
      id: 'today',
      namespace: 'saved_sentence',
      dueAt: DateTime(2026, 8, 22, 23),
    );
    await _insertSchedule(
      db,
      id: 'today-later',
      namespace: 'saved_sentence',
      dueAt: DateTime(2026, 8, 22, 23, 30),
    );

    final stats = await ReviewStatisticsRepository(db).load(now: now);

    expect(stats.dueNow, 1);
    expect(stats.overdueNow, 1);
    expect(stats.upcomingDue[0], 2);
  });

  test('全部时长仅汇总收藏句子和收藏词汇复习阶段', () async {
    final now = DateTime(2026, 8, 22, 10);
    await db.studyStatisticsDao.applyDelta(
      StudyStatisticsDelta(
        date: DateTime(2026, 8, 22, 10),
        stage: StudyStage.intensiveListen,
        studyTimeMilliseconds: 90000,
      ),
    );
    await db.studyStatisticsDao.applyDelta(
      StudyStatisticsDelta(
        date: DateTime(2026, 8, 22, 10),
        stage: StudyStage.savedSentencesReview,
        studyTimeMilliseconds: 30000,
      ),
    );
    await db.studyStatisticsDao.applyDelta(
      StudyStatisticsDelta(
        date: DateTime(2026, 8, 22, 10),
        stage: StudyStage.savedVocabularyReview,
        studyTimeMilliseconds: 60000,
      ),
    );

    final repository = ReviewStatisticsRepository(db);
    final all = await repository.load(now: now);
    final sentences = await repository.load(
      now: now,
      scope: ReviewStatisticsScope.sentences,
    );
    final vocabulary = await repository.load(
      now: now,
      scope: ReviewStatisticsScope.vocabulary,
    );

    expect(all.todaySeconds, 90);
    expect(sentences.todaySeconds, 30);
    expect(vocabulary.todaySeconds, 60);
    expect(all.dailyTrend.last.seconds, 90);
    expect(sentences.dailyTrend.last.seconds, 30);
    expect(vocabulary.dailyTrend.last.seconds, 60);
  });
}

Future<void> _insertSchedule(
  AppDatabase db, {
  required String id,
  required String namespace,
  required DateTime dueAt,
  String? subjectId,
}) => db
    .into(db.memorySchedules)
    .insert(
      MemorySchedulesCompanion.insert(
        id: id,
        namespace: namespace,
        subjectId: subjectId ?? '$id-subject',
        profileId: 'test-profile',
        profileVersion: 1,
        modelId: 'test-model',
        modelStateVersion: 1,
        phase: 'review',
        status: 'active',
        dueAt: dueAt,
        createdAt: dueAt.subtract(const Duration(days: 2)),
        updatedAt: dueAt,
      ),
    );

Future<void> _insertEvent(
  AppDatabase db, {
  required String id,
  required String scheduleId,
  required int sequence,
  required String rating,
  required DateTime reviewedAt,
}) => db
    .into(db.memoryReviewEvents)
    .insert(
      MemoryReviewEventsCompanion.insert(
        id: id,
        scheduleId: scheduleId,
        sequence: sequence,
        operationId: '$id-operation',
        rating: rating,
        isLapse: rating == 'again',
        reviewedAt: reviewedAt,
        profileId: 'test-profile',
        profileVersion: 1,
        modelId: 'test-model',
        modelStateVersion: 1,
        dueBefore: reviewedAt,
        dueAfter: reviewedAt.add(const Duration(days: 1)),
        scheduleRevisionAfter: sequence,
        createdAt: reviewedAt,
      ),
    );

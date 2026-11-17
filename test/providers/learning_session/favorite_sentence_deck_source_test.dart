import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' hide MemorySchedule;
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/features/memory_scheduler/adapters/fsrs/fsrs_memory_model_adapter.dart';
import 'package:echo_loop/features/memory_scheduler/application/default_memory_scheduler.dart';
import 'package:echo_loop/features/memory_scheduler/application/memory_model_registry.dart';
import 'package:echo_loop/features/memory_scheduler/application/memory_scheduler.dart';
import 'package:echo_loop/features/memory_scheduler/config/memory_profiles.dart';
import 'package:echo_loop/features/memory_scheduler/data/drift_memory_schedule_repository.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_rating.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_schedule.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_scheduler_commands.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_subject_ref.dart';
import 'package:echo_loop/models/favorite_review_settings.dart';
import 'package:echo_loop/providers/learning_session/favorite_sentence_deck_source.dart';
import 'package:flutter_test/flutter_test.dart';

BookmarkWithAudio _bookmark(String subjectId, int index) => BookmarkWithAudio(
  bookmark: Bookmark(
    id: index,
    audioItemId: 'audio-1',
    memorySubjectId: subjectId,
    sentenceText: 'Sentence $index',
    startTime: index.toDouble(),
    endTime: index + 1.0,
    createdAt: DateTime.utc(2026, 1, index + 1),
    updatedAt: DateTime.utc(2026, 1, index + 1),
    syncStatus: 0,
  ),
  audioName: 'Material',
);

void main() {
  late AppDatabase database;
  late MemoryScheduler scheduler;
  final now = DateTime.utc(2026, 8, 15, 8);

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    scheduler = DefaultMemoryScheduler(
      repository: DriftMemoryScheduleRepository(database),
      profileRegistry: kMemoryProfileRegistry,
      modelRegistry: StaticMemoryModelRegistry(<FsrsMemoryModelAdapter>[
        FsrsMemoryModelAdapter(),
      ]),
      idGenerator: _IncrementingIdGenerator(),
      clock: Clock.fixed(now),
    );
  });

  tearDown(() => database.close());

  FavoriteSentenceDeckSource source({
    FavoriteReviewSettings settings = const FavoriteReviewSettings(),
  }) => FavoriteSentenceDeckSource(
    favoriteReviewDao: database.favoriteReviewDao,
    scheduler: scheduler,
    settings: settings,
    now: () => now,
  );

  Future<void> persistBookmarks(List<BookmarkWithAudio> bookmarks) async {
    await database.audioItemDao.upsert(
      AudioItemsCompanion.insert(
        id: 'audio-1',
        name: 'Material',
        addedDate: now,
        updatedAt: now,
      ),
    );
    for (final item in bookmarks) {
      final bookmark = item.bookmark;
      await database
          .into(database.bookmarks)
          .insertOnConflictUpdate(
            BookmarksCompanion.insert(
              memorySubjectId: Value(bookmark.memorySubjectId),
              audioItemId: bookmark.audioItemId,
              sentenceText: bookmark.sentenceText,
              startTime: bookmark.startTime,
              endTime: bookmark.endTime,
              createdAt: bookmark.createdAt,
              updatedAt: bookmark.updatedAt,
              deletedAt: Value(bookmark.deletedAt),
            ),
          );
      final subjectId = bookmark.memorySubjectId;
      if (subjectId != null && subjectId.trim().isNotEmpty) {
        final subject = MemorySubjectRef(
          namespace: kSavedSentenceNamespace,
          subjectId: subjectId,
        );
        if (await scheduler.getSchedule(subject) == null) {
          await scheduler.ensureSchedule(
            EnsureMemoryScheduleCommand(
              subject: subject,
              profile: kFsrsDefaultProfileRef,
              occurredAt: now,
            ),
          );
        }
      }
    }
  }

  /// 让某个 subject 拥有一个到期时间在未来的既有 schedule（模拟已复习过、尚未到期）。
  Future<void> pushDueIntoFuture(String subjectId) async {
    final subject = MemorySubjectRef(
      namespace: kSavedSentenceNamespace,
      subjectId: subjectId,
    );
    final schedule = await scheduler.ensureSchedule(
      EnsureMemoryScheduleCommand(
        subject: subject,
        profile: kFsrsDefaultProfileRef,
        occurredAt: now,
      ),
    );
    final preview = await scheduler.previewRatings(
      PreviewMemoryRatingsQuery(
        subject: subject,
        reviewedAt: now,
        expectedRevision: schedule.revision,
      ),
    );
    await scheduler.review(
      ReviewMemoryCommand(
        subject: subject,
        rating: MemoryRating.easy,
        preview: preview.easy,
        reviewedAt: now,
        responseTime: Duration.zero,
        operationId: 'seed-$subjectId',
        expectedRevision: schedule.revision,
      ),
    );
  }

  test('新卡立即到期，未到期的既有卡片被过滤', () async {
    await pushDueIntoFuture('future-subject');
    await persistBookmarks([
      _bookmark('future-subject', 1),
      _bookmark('new-subject', 2),
    ]);
    final due = await source().load();

    expect(due, hasLength(1));
    expect(due.single.subject.subjectId, 'new-subject');
    expect(due.single.content.sentence.text, 'Sentence 2');
  });

  test('过滤无效书签：零时长、空文本、缺失 memorySubjectId', () async {
    final zeroDuration = _bookmark('a', 1).bookmark.copyWith(endTime: 1);
    final emptyText = _bookmark('b', 2).bookmark.copyWith(sentenceText: '   ');
    final noSubject = _bookmark(
      'c',
      3,
    ).bookmark.copyWith(memorySubjectId: const Value(null));

    await persistBookmarks([
      BookmarkWithAudio(bookmark: zeroDuration, audioName: 'Material'),
      BookmarkWithAudio(bookmark: emptyText, audioName: 'Material'),
      BookmarkWithAudio(bookmark: noSubject, audioName: 'Material'),
      _bookmark('d', 4),
    ]);
    final due = await source().load();

    expect(due, hasLength(1));
    expect(due.single.subject.subjectId, 'd');
  });

  test('dueAt 排序：dueAt 相同时按 subjectId 稳定排序', () async {
    await persistBookmarks([_bookmark('earlier', 1), _bookmark('also-new', 2)]);
    final due = await source(
      settings: const FavoriteReviewSettings(order: FavoriteReviewOrder.dueAt),
    ).load();

    // 两张都是新卡，dueAt 相同（都等于 now），退化为按 subjectId 排序。
    expect(due.map((c) => c.subject.subjectId), ['also-new', 'earlier']);
  });

  test('切换顺序读取队列时不会恢复已归档收藏', () async {
    final subject = MemorySubjectRef(
      namespace: kSavedSentenceNamespace,
      subjectId: 'archived-subject',
    );
    final schedule = await scheduler.ensureSchedule(
      EnsureMemoryScheduleCommand(
        subject: subject,
        profile: kFsrsDefaultProfileRef,
        occurredAt: now,
      ),
    );
    await scheduler.archive(
      ArchiveMemoryScheduleCommand(
        subject: subject,
        archivedAt: now,
        expectedRevision: schedule.revision,
      ),
    );

    await persistBookmarks([_bookmark('archived-subject', 1)]);
    final due = await source().loadForReordering();

    expect(due, isEmpty);
    expect(
      (await scheduler.getSchedule(subject))?.status,
      MemoryScheduleStatus.archived,
    );
  });

  test('无每日目标时重复查询返回所有到期新卡', () async {
    final settings = const FavoriteReviewSettings();
    final bookmarks = [_bookmark('first', 1), _bookmark('second', 2)];
    await persistBookmarks(bookmarks);

    final firstLoad = await source(settings: settings).load();
    expect(firstLoad, hasLength(2));

    final secondLoad = await source(settings: settings).load();
    expect(secondLoad, hasLength(2));
  });

  test('随机排序不丢卡也不重复', () async {
    final bookmarks = [
      _bookmark('r1', 1),
      _bookmark('r2', 2),
      _bookmark('r3', 3),
    ];
    await persistBookmarks(bookmarks);
    final due = await source(
      settings: const FavoriteReviewSettings(order: FavoriteReviewOrder.random),
    ).load();
    expect(due.map((c) => c.subject.subjectId).toSet(), {'r1', 'r2', 'r3'});
  });
}

final class _IncrementingIdGenerator implements MemoryIdGenerator {
  int _next = 0;
  @override
  String newId() => 'id-${++_next}';
}

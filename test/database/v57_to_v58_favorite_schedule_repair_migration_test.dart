import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

final _createdAt = DateTime.utc(2026, 8, 24, 1);
final _reviewedDueAt = DateTime.utc(2026, 9, 1, 1);
const _state =
    '{"cardId":0,"state":1,"step":0,"stability":null,"difficulty":null,"due":"2026-08-24T01:00:00.000Z","lastReview":null}';

void main() {
  test('v57→v58 为缺失主体或调度的有效收藏补齐活动快照', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v57_v58_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    await _seedV57(file);

    var database = _open(file);
    final bookmarks = await database.select(database.bookmarks).get();
    final words = await database.select(database.savedWords).get();
    final groups = await database.select(database.savedSenseGroups).get();
    final schedules = await database.select(database.memorySchedules).get();

    final sentenceId = bookmarks.single.memorySubjectId;
    final wordId = words
        .singleWhere((row) => row.word == 'missing schedule')
        .memorySubjectId;
    final groupId = groups.single.memorySubjectId;
    expect(sentenceId, isNotNull);
    expect(wordId, isNotNull);
    expect(groupId, isNotNull);
    expect(
      _find(schedules, kSavedSentenceNamespace, sentenceId)?.status,
      'active',
    );
    expect(
      _find(schedules, kSavedWordOrPhraseNamespace, wordId)?.status,
      'active',
    );
    expect(
      _find(schedules, kSavedSenseGroupNamespace, groupId)?.status,
      'active',
    );

    final restored = _find(
      schedules,
      kSavedWordOrPhraseNamespace,
      'archived-word',
    );
    expect(restored?.status, 'active');
    expect(restored?.revision, 3);
    expect(restored?.reviewCount, 2);
    expect(restored?.dueAt.toUtc(), _reviewedDueAt);
    final reviewIndexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE '%_active_memory_subject'",
        )
        .get();
    expect(
      reviewIndexes.map((row) => row.data['name']),
      containsAll([
        'idx_bookmarks_active_memory_subject',
        'idx_saved_words_active_memory_subject',
        'idx_saved_sense_groups_active_memory_subject',
      ]),
    );
    final revisionsBeforeReopen = {
      for (final schedule in schedules)
        '${schedule.namespace}:${schedule.subjectId}': schedule.revision,
    };

    await database.close();
    database = _open(file);
    final reopened = await database.select(database.memorySchedules).get();
    expect({
      for (final schedule in reopened)
        '${schedule.namespace}:${schedule.subjectId}': schedule.revision,
    }, revisionsBeforeReopen);
    await database.close();
  });
}

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys = ON')),
);

Future<void> _seedV57(File file) async {
  final database = _open(file);
  await database
      .into(database.audioItems)
      .insert(
        AudioItemsCompanion.insert(
          id: 'audio',
          name: 'Audio',
          addedDate: _createdAt,
          updatedAt: _createdAt,
        ),
      );
  await database
      .into(database.bookmarks)
      .insert(
        BookmarksCompanion.insert(
          audioItemId: 'audio',
          sentenceIndex: 1,
          sentenceText: 'Valid sentence',
          startTime: 0,
          endTime: 2,
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ),
      );
  await database
      .into(database.savedWords)
      .insert(
        SavedWordsCompanion.insert(
          word: 'missing schedule',
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ),
      );
  await database
      .into(database.savedWords)
      .insert(
        SavedWordsCompanion.insert(
          word: 'archived word',
          memorySubjectId: const Value('archived-word'),
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ),
      );
  await database
      .into(database.savedSenseGroups)
      .insert(
        SavedSenseGroupsCompanion.insert(
          phraseText: 'missing group schedule',
          displayText: 'Missing group schedule',
          createdAt: _createdAt,
          updatedAt: _createdAt,
        ),
      );
  await _insertSchedule(
    database,
    id: 'archived',
    namespace: kSavedWordOrPhraseNamespace,
    subjectId: 'archived-word',
    status: 'archived',
    revision: 2,
    reviewCount: 2,
    dueAt: _reviewedDueAt,
  );
  await database.close();

  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 57');
  } finally {
    raw.close();
  }
}

Future<void> _insertSchedule(
  AppDatabase database, {
  required String id,
  required String namespace,
  required String subjectId,
  String status = 'active',
  int revision = 0,
  int reviewCount = 0,
  DateTime? dueAt,
}) => database
    .into(database.memorySchedules)
    .insert(
      MemorySchedulesCompanion.insert(
        id: id,
        namespace: namespace,
        subjectId: subjectId,
        profileId: 'fsrs.default',
        profileVersion: 1,
        modelId: 'fsrs',
        modelStateVersion: 1,
        modelStateJson: const Value(_state),
        phase: 'review',
        status: status,
        dueAt: dueAt ?? _createdAt,
        reviewCount: Value(reviewCount),
        revision: Value(revision),
        createdAt: _createdAt,
        updatedAt: _createdAt,
        archivedAt: Value(status == 'archived' ? _createdAt : null),
      ),
    );

MemorySchedule? _find(
  List<MemorySchedule> schedules,
  String namespace,
  String? subjectId,
) {
  if (subjectId == null) return null;
  for (final schedule in schedules) {
    if (schedule.namespace == namespace && schedule.subjectId == subjectId) {
      return schedule;
    }
  }
  return null;
}

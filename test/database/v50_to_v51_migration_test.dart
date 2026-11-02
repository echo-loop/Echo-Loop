import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/features/memory_scheduler/domain/memory_namespaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

final _seededAt = DateTime.utc(2026, 8, 24, 1);
final _reviewedDueAt = DateTime.utc(2026, 9, 1, 1);
const _state =
    '{"cardId":0,"state":1,"step":0,"stability":null,"difficulty":null,"due":"2026-08-24T01:00:00.000Z","lastReview":null}';

void main() {
  test('v50 升级回填收藏且后续启动不再重复扫描', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v50_to_v51_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File([dir.path, 'echo_loop.db'].join('/'));
    await _seedV50(file);
    var db = _open(file);
    var rows = await db.select(db.memorySchedules).get();

    expect(
      _find(rows, kSavedSentenceNamespace, 'sentence-active')?.status,
      'active',
    );
    expect(
      _find(rows, kSavedWordOrPhraseNamespace, 'word-active')?.status,
      'active',
    );
    expect(
      _find(rows, kSavedSenseGroupNamespace, 'group-active')?.status,
      'active',
    );
    expect(
      _find(rows, kSavedSentenceNamespace, 'sentence-deleted')?.status,
      'archived',
    );
    expect(
      _find(rows, kSavedSentenceNamespace, 'sentence-invalid')?.status,
      'archived',
    );
    expect(
      _find(rows, kSavedSentenceNamespace, 'sentence-hidden')?.status,
      'archived',
    );
    expect(
      _find(rows, kSavedWordOrPhraseNamespace, 'orphan-word')?.status,
      'archived',
    );
    expect(
      _find(rows, kSavedWordOrPhraseNamespace, 'word-deleted')?.status,
      'archived',
    );

    final restored = _find(rows, kSavedWordOrPhraseNamespace, 'word-restored');
    expect(restored?.status, 'active');
    expect(restored?.reviewCount, 2);
    expect(restored?.dueAt.toUtc(), _reviewedDueAt);
    final reviewed = _find(rows, kSavedSentenceNamespace, 'sentence-reviewed');
    expect(reviewed?.status, 'active');
    expect(reviewed?.reviewCount, 4);
    expect(reviewed?.dueAt.toUtc(), _reviewedDueAt);

    final beforeReopen = _snapshot(rows);
    await db.close();
    db = _open(file);
    rows = await db.select(db.memorySchedules).get();
    expect(_snapshot(rows), beforeReopen);
    await db.close();
  });
}

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys = ON')),
);

Future<void> _seedV50(File file) async {
  final db = _open(file);
  await db
      .into(db.audioItems)
      .insert(
        AudioItemsCompanion.insert(
          id: 'audio-active',
          name: 'Active',
          addedDate: _seededAt,
          updatedAt: _seededAt,
        ),
      );
  await db
      .into(db.audioItems)
      .insert(
        AudioItemsCompanion.insert(
          id: 'audio-deleted',
          name: 'Deleted',
          addedDate: _seededAt,
          updatedAt: _seededAt,
          deletedAt: Value(_seededAt),
        ),
      );
  await _bookmark(db, 'sentence-active');
  await _bookmark(db, 'sentence-reviewed', index: 2);
  await _bookmark(db, 'sentence-deleted', index: 3, deletedAt: _seededAt);
  await _bookmark(db, 'sentence-invalid', index: 4, text: ' ', end: 0);
  await _bookmark(db, 'sentence-hidden', index: 5, audioId: 'audio-deleted');
  await _word(db, 'active word', 'word-active');
  await _word(db, 'restored word', 'word-restored');
  await _word(db, 'deleted word', 'word-deleted', deletedAt: _seededAt);
  await db
      .into(db.savedSenseGroups)
      .insert(
        SavedSenseGroupsCompanion.insert(
          phraseText: 'active group',
          memorySubjectId: const Value('group-active'),
          displayText: 'active group',
          createdAt: _seededAt,
          updatedAt: _seededAt,
        ),
      );
  await _schedule(
    db,
    id: 'reviewed',
    namespace: kSavedSentenceNamespace,
    subjectId: 'sentence-reviewed',
    reviewCount: 4,
    dueAt: _reviewedDueAt,
  );
  await _schedule(
    db,
    id: 'restored',
    namespace: kSavedWordOrPhraseNamespace,
    subjectId: 'word-restored',
    status: 'archived',
    reviewCount: 2,
    dueAt: _reviewedDueAt,
  );
  await _schedule(
    db,
    id: 'invalid',
    namespace: kSavedSentenceNamespace,
    subjectId: 'sentence-invalid',
  );
  await _schedule(
    db,
    id: 'hidden',
    namespace: kSavedSentenceNamespace,
    subjectId: 'sentence-hidden',
  );
  await _schedule(
    db,
    id: 'orphan',
    namespace: kSavedWordOrPhraseNamespace,
    subjectId: 'orphan-word',
  );
  await db.close();
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 50');
  } finally {
    raw.close();
  }
}

Future<void> _bookmark(
  AppDatabase db,
  String subjectId, {
  int index = 1,
  String audioId = 'audio-active',
  String text = 'Valid sentence.',
  double end = 3,
  DateTime? deletedAt,
}) => db
    .into(db.bookmarks)
    .insert(
      BookmarksCompanion.insert(
        memorySubjectId: Value(subjectId),
        audioItemId: audioId,
        sentenceIndex: index,
        sentenceText: text,
        startTime: 0,
        endTime: end,
        createdAt: _seededAt,
        updatedAt: _seededAt,
        deletedAt: Value(deletedAt),
      ),
    );
Future<void> _word(
  AppDatabase db,
  String word,
  String subjectId, {
  DateTime? deletedAt,
}) => db
    .into(db.savedWords)
    .insert(
      SavedWordsCompanion.insert(
        word: word,
        memorySubjectId: Value(subjectId),
        createdAt: _seededAt,
        updatedAt: _seededAt,
        deletedAt: Value(deletedAt),
      ),
    );
Future<void> _schedule(
  AppDatabase db, {
  required String id,
  required String namespace,
  required String subjectId,
  String status = 'active',
  int reviewCount = 0,
  DateTime? dueAt,
}) => db
    .into(db.memorySchedules)
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
        phase: 'newItem',
        status: status,
        dueAt: dueAt ?? _seededAt,
        reviewCount: Value(reviewCount),
        revision: const Value(0),
        createdAt: _seededAt,
        updatedAt: _seededAt,
        archivedAt: Value(status == 'archived' ? _seededAt : null),
      ),
    );

MemorySchedule? _find(
  List<MemorySchedule> rows,
  String namespace,
  String subjectId,
) {
  for (final row in rows) {
    if (row.namespace == namespace && row.subjectId == subjectId) return row;
  }
  return null;
}

List<String> _snapshot(List<MemorySchedule> rows) {
  final result = rows
      .map(
        (row) => [
          row.id,
          row.status,
          row.revision,
          row.updatedAt.toUtc().toIso8601String(),
        ].join('|'),
      )
      .toList();
  result.sort();
  return result;
}

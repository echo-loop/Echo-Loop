import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// 还原为 v69 的三张收藏表：都带 sentence_index 列，收藏句另有唯一约束。
void _restoreV69FavoriteTables(sqlite.Database raw) {
  raw.execute('DROP TABLE bookmarks');
  raw.execute('''
    CREATE TABLE bookmarks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      memory_subject_id TEXT NULL,
      audio_item_id TEXT NOT NULL REFERENCES audio_items (id) ON DELETE CASCADE,
      sentence_index INTEGER NOT NULL,
      sentence_text TEXT NOT NULL,
      start_time REAL NOT NULL,
      end_time REAL NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER NULL,
      sync_status INTEGER NOT NULL DEFAULT 0,
      UNIQUE (audio_item_id, sentence_index)
    )
  ''');
  raw.execute(
    "INSERT INTO bookmarks (memory_subject_id, audio_item_id, sentence_index, "
    "sentence_text, start_time, end_time, created_at, updated_at) "
    "VALUES ('subject-1', 'audio-1', 2, 'Hello', 4.0, 6.0, 0, 0)",
  );
  raw.execute(
    "INSERT INTO bookmarks (memory_subject_id, audio_item_id, sentence_index, "
    "sentence_text, start_time, end_time, created_at, updated_at, "
    "deleted_at, sync_status) "
    "VALUES ('subject-deleted', 'audio-1', 3, 'Bye', 6.0, 8.0, 0, 0, 5, 2)",
  );
  raw.execute('ALTER TABLE saved_words ADD COLUMN sentence_index INTEGER NULL');
  raw.execute(
    'ALTER TABLE saved_sense_groups ADD COLUMN sentence_index INTEGER NULL',
  );
  raw.execute("UPDATE saved_words SET sentence_index = 3 WHERE word = 'hello'");
  raw.execute(
    "UPDATE saved_sense_groups SET sentence_index = 4 "
    "WHERE phrase_text = 'as a result'",
  );
  raw.execute('PRAGMA user_version = 69');
}

Set<String> _columns(sqlite.Database raw, String table) => {
  for (final row in raw.select('PRAGMA table_info($table)'))
    row['name'] as String,
};

void main() {
  test('v69→v71 删除收藏表的句子编号列与收藏句唯一约束，数据完整保留', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v69_v71_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    final now = DateTime.utc(2026, 11, 17);
    var database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('Audio'),
        audioPath: const Value('audio.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
    await database.savedWordDao.saveWord(
      word: 'hello',
      audioItemId: 'audio-1',
      sentenceText: 'Hello there.',
      sentenceStartMs: 6000,
      sentenceEndMs: 8000,
    );
    await database.savedSenseGroupDao.saveSenseGroup(
      phraseText: 'as a result',
      displayText: 'As a result',
      audioItemId: 'audio-1',
      sentenceText: 'As a result, it works.',
      sentenceStartMs: 8000,
      sentenceEndMs: 10000,
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      _restoreV69FavoriteTables(raw);
    } finally {
      raw.close();
    }

    database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    addTearDown(database.close);

    // 收藏句：正常与回收站中的收藏、同步状态都保留。
    final bookmarks = {
      for (final row in await database.select(database.bookmarks).get())
        row.memorySubjectId: row,
    };
    expect(bookmarks.keys.toSet(), {'subject-1', 'subject-deleted'});
    expect(bookmarks['subject-1']!.startTime, 4.0);
    expect(bookmarks['subject-1']!.sentenceText, 'Hello');
    expect(bookmarks['subject-1']!.deletedAt, isNull);
    expect(bookmarks['subject-deleted']!.deletedAt, isNotNull);
    expect(bookmarks['subject-deleted']!.syncStatus, 2);

    // 收藏词汇 / 意群：来源句文字与区间保留。
    final word = (await database.savedWordDao.getByAudioId('audio-1')).single;
    expect(word.sentenceText, 'Hello there.');
    expect(word.sentenceStartMs, 6000);
    final group = (await database.savedSenseGroupDao.getByAudioId('audio-1'))
        .single;
    expect(group.sentenceText, 'As a result, it works.');
    expect(group.sentenceEndMs, 10000);

    // 同一区间可再收藏一条（字幕合并后同一句可对应多条收藏）。
    await database.bookmarkDao.addBookmark(
      BookmarksCompanion(
        memorySubjectId: const Value('subject-2'),
        audioItemId: const Value('audio-1'),
        sentenceText: const Value('Hello'),
        startTime: const Value(4.0),
        endTime: const Value(6.0),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    expect(await database.bookmarkDao.getByAudioId('audio-1'), hasLength(2));

    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('idx_bookmarks_audio', "
          "'idx_bookmarks_active_memory_subject', 'idx_saved_words_active', "
          "'idx_saved_words_active_memory_subject', "
          "'idx_saved_sense_groups_active_memory_subject')",
        )
        .get();
    expect(indexes, hasLength(5));
    await database.close();

    final check = sqlite.sqlite3.open(file.path);
    try {
      for (final table in ['bookmarks', 'saved_words', 'saved_sense_groups']) {
        expect(
          _columns(check, table),
          isNot(contains('sentence_index')),
          reason: '$table 不应再有 sentence_index 列',
        );
      }
    } finally {
      check.close();
    }
  });
}

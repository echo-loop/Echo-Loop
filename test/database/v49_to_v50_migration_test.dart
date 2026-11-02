import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v49→v50 迁移测试：
/// - 为 saved_words、saved_sense_groups 回填不可变 memory_subject_id UUID；
/// - 把收藏句专属的 bookmark_review_queue_entries 泛化为带 namespace 的
///   memory_review_queue_entries，并保留存量行（回填 namespace='saved_sentence'）。
void main() {
  test('v49→v50 回填词汇 UUID 并泛化每日新卡计数表', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v49_to_v50_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV49Fixture(file);

    final db = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(db.close);

    // saved_words / saved_sense_groups 存量行都回填了非空、彼此不同的 UUID。
    final wordRows = await db
        .customSelect('SELECT id, memory_subject_id FROM saved_words')
        .get();
    expect(wordRows, hasLength(2));
    final wordIds = wordRows.map((r) => r.data['memory_subject_id']).toSet();
    expect(wordIds, hasLength(2));
    expect(wordIds, isNot(contains(null)));

    final phraseRows = await db
        .customSelect('SELECT id, memory_subject_id FROM saved_sense_groups')
        .get();
    expect(phraseRows, hasLength(1));
    expect(phraseRows.single.data['memory_subject_id'], isNotNull);

    // 队列表已改名，旧表名不再存在。
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = {for (final row in tables) row.data['name']};
    expect(tableNames, contains('memory_review_queue_entries'));
    expect(tableNames, isNot(contains('bookmark_review_queue_entries')));

    // 存量行回填 namespace='saved_sentence'，原 subject_id/local_date 不变。
    final queueRows = await db
        .customSelect(
          'SELECT namespace, subject_id, local_date FROM memory_review_queue_entries',
        )
        .get();
    expect(queueRows, hasLength(1));
    expect(queueRows.single.data['namespace'], 'saved_sentence');
    expect(queueRows.single.data['subject_id'], 'legacy-subject-1');
    expect(queueRows.single.data['local_date'], '2026-01-01');

    // 新唯一索引按 (namespace, subject_id, local_date) 生效：不同 namespace
    // 复用同一 subject_id + local_date 必须能共存（旧的双列唯一约束会拒绝）。
    await db.customStatement('''
      INSERT INTO memory_review_queue_entries
        (namespace, subject_id, local_date, enqueued_at)
      VALUES ('saved_word_or_phrase', 'legacy-subject-1', '2026-01-01', 0)
    ''');
    final afterInsert = await db
        .customSelect('SELECT namespace FROM memory_review_queue_entries')
        .get();
    expect(afterInsert, hasLength(2));

    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final indexNames = {for (final row in indexes) row.data['name']};
    expect(
      indexNames,
      contains('idx_memory_review_queue_namespace_subject_day'),
    );
  });
}

Future<void> _createV49Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE saved_words');
    raw.execute('DROP TABLE saved_sense_groups');
    raw.execute('DROP TABLE memory_review_queue_entries');
    raw.execute('''
      CREATE TABLE saved_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL UNIQUE,
        memory_subject_id TEXT,
        audio_item_id TEXT,
        sentence_index INTEGER,
        sentence_text TEXT,
        sentence_start_ms INTEGER,
        sentence_end_ms INTEGER,
        practice_count INTEGER NOT NULL DEFAULT 0,
        total_study_ms INTEGER NOT NULL DEFAULT 0,
        viewed_back INTEGER NOT NULL DEFAULT 0,
        last_practiced_at INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');
    raw.execute("INSERT INTO saved_words (word) VALUES ('apple')");
    raw.execute("INSERT INTO saved_words (word) VALUES ('banana')");

    raw.execute('''
      CREATE TABLE saved_sense_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phrase_text TEXT NOT NULL UNIQUE,
        memory_subject_id TEXT,
        display_text TEXT NOT NULL DEFAULT '',
        audio_item_id TEXT,
        sentence_index INTEGER,
        sentence_text TEXT,
        sentence_start_ms INTEGER,
        sentence_end_ms INTEGER,
        group_start_ms INTEGER,
        group_end_ms INTEGER,
        practice_count INTEGER NOT NULL DEFAULT 0,
        total_study_ms INTEGER NOT NULL DEFAULT 0,
        viewed_back INTEGER NOT NULL DEFAULT 0,
        last_practiced_at INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');
    raw.execute(
      "INSERT INTO saved_sense_groups (phrase_text) VALUES ('give up')",
    );

    raw.execute('''
      CREATE TABLE bookmark_review_queue_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id TEXT NOT NULL,
        local_date TEXT NOT NULL,
        enqueued_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE UNIQUE INDEX idx_bookmark_review_queue_subject_day
      ON bookmark_review_queue_entries(subject_id, local_date)
    ''');
    raw.execute('''
      INSERT INTO bookmark_review_queue_entries
        (subject_id, local_date, enqueued_at)
      VALUES ('legacy-subject-1', '2026-01-01', 0)
    ''');

    raw.execute('PRAGMA user_version = 49');
  } finally {
    raw.close();
  }
}

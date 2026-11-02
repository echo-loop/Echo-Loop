import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v35 → v36 迁移：audio_items 新增 transcript_srt 列（字幕内容入库）。
///
/// 验证：
/// 1. 升级后 transcript_srt 列存在且初始为 NULL；
/// 2. 旧行（含 transcript_path 等字段）数据无损。
void main() {
  test('v35→v36 加 transcript_srt 列且旧数据无损', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v35_to_v36_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV35Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    // transcript_srt 列存在
    final columns = await db
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final columnNames = columns
        .map((row) => row.data['name'] as String)
        .toSet();
    expect(columnNames, contains('transcript_srt'));

    // 旧行数据无损，transcript_srt 初始为 NULL
    final row = await db
        .customSelect(
          "SELECT name, transcript_path, transcript_source, transcript_srt "
          "FROM audio_items WHERE id = 'a1'",
        )
        .getSingle();
    expect(row.data['name'], 'Old Audio');
    expect(row.data['transcript_path'], 'transcripts/a1.srt');
    expect(row.data['transcript_source'], 0);
    expect(row.data['transcript_srt'], isNull);
  });
}

Future<void> _createV35Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE audio_items');
    // 模拟 v35 schema 的 audio_items（无 transcript_srt 列）
    raw.execute('''
      CREATE TABLE audio_items (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        audio_path TEXT,
        transcript_path TEXT,
        added_date INTEGER NOT NULL,
        total_duration INTEGER NOT NULL DEFAULT 0,
        sentence_count INTEGER NOT NULL DEFAULT 0,
        word_count INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        transcript_source INTEGER,
        audio_sha256 TEXT,
        transcript_language TEXT,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        word_timestamps_json TEXT,
        sync_status INTEGER NOT NULL DEFAULT 0,
        remote_audio_id TEXT,
        original_date INTEGER
      );
    ''');

    final now = DateTime(2026, 5, 1).millisecondsSinceEpoch;
    raw.execute(
      '''
      INSERT INTO audio_items (
        id, name, audio_path, transcript_path, added_date,
        sentence_count, word_count, transcript_source, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        'a1',
        'Old Audio',
        'audios/a1.mp3',
        'transcripts/a1.srt',
        now,
        3,
        12,
        0,
        now,
      ],
    );

    raw.execute('PRAGMA user_version = 35');
  } finally {
    raw.close();
  }
}

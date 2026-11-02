import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v36 → v37 迁移：audio_items 新增用户导入来源字段。
void main() {
  test('v36→v37 加 import_source_type/import_source_url 且旧数据无损', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v36_to_v37_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV36Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final byName = {for (final row in columns) row.data['name'] as String: row};

    expect(byName, contains('import_source_type'));
    expect(byName, contains('import_source_url'));
    expect(byName['import_source_type']!.data['notnull'], 0);
    expect(byName['import_source_url']!.data['notnull'], 0);

    final row = await db
        .customSelect(
          "SELECT name, import_source_type, import_source_url "
          "FROM audio_items WHERE id = 'a1'",
        )
        .getSingle();
    expect(row.data['name'], 'Old Audio');
    expect(row.data['import_source_type'], isNull);
    expect(row.data['import_source_url'], isNull);
  });
}

Future<void> _createV36Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE audio_items');
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
        transcript_srt TEXT,
        sync_status INTEGER NOT NULL DEFAULT 0,
        remote_audio_id TEXT,
        original_date INTEGER
      );
    ''');

    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    raw.execute(
      '''
      INSERT INTO audio_items (
        id, name, audio_path, added_date, updated_at
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      ['a1', 'Old Audio', 'audios/a1.mp3', now, now],
    );

    raw.execute('PRAGMA user_version = 36');
  } finally {
    raw.close();
  }
}

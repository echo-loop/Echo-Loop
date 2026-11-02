import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v37 → v38 迁移：podcast 合集与 episode 字段。
void main() {
  test('v37→v38 加 podcast 字段且旧数据无损', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v37_to_v38_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV37Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    // ── collections 新列 ────────────────────────────────────────────────
    final collCols = await db
        .customSelect('PRAGMA table_info(collections)')
        .get();
    final collByName = {for (final r in collCols) r.data['name'] as String: r};
    for (final col in [
      'podcast_input_url',
      'podcast_feed_url',
      'podcast_meta_json',
      'podcast_last_refreshed_at',
    ]) {
      expect(collByName, contains(col), reason: 'collections 缺列 $col');
      expect(collByName[col]!.data['notnull'], 0);
    }

    // ── audio_items 新列 ─────────────────────────────────────────────────
    // podcast_description 已在 v63 迁入 description 并删除，此处不再断言。
    final audioCols = await db
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final audioByName = {
      for (final r in audioCols) r.data['name'] as String: r,
    };
    for (final col in [
      'podcast_episode_guid',
      'podcast_enclosure_url',
      'podcast_enclosure_type',
      'podcast_image_url',
      'podcast_link',
    ]) {
      expect(audioByName, contains(col), reason: 'audio_items 缺列 $col');
      expect(audioByName[col]!.data['notnull'], 0);
    }

    // ── 旧数据无损 ───────────────────────────────────────────────────────
    final coll = await db
        .customSelect(
          "SELECT name, podcast_input_url FROM collections WHERE id = 'c1'",
        )
        .getSingle();
    expect(coll.data['name'], 'My Podcast');
    expect(coll.data['podcast_input_url'], isNull);

    final audio = await db
        .customSelect(
          "SELECT name, podcast_episode_guid FROM audio_items WHERE id = 'a1'",
        )
        .getSingle();
    expect(audio.data['name'], 'Episode 1');
    expect(audio.data['podcast_episode_guid'], isNull);
  });

  test('v38 已打开过但缺 podcast 字段时启动自愈补列', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v38_repair_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV37Fixture(file, userVersion: 38);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    // 触发 beforeOpen，自愈已是 v38 但缺列的数据库。
    final audioCols = await db
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final audioByName = {
      for (final r in audioCols) r.data['name'] as String: r,
    };
    expect(audioByName, contains('podcast_episode_guid'));
    expect(audioByName, contains('podcast_enclosure_url'));
    expect(audioByName, contains('podcast_link'));

    final collCols = await db
        .customSelect('PRAGMA table_info(collections)')
        .get();
    final collByName = {for (final r in collCols) r.data['name'] as String: r};
    expect(collByName, contains('podcast_input_url'));
    expect(collByName, contains('podcast_feed_url'));
    expect(collByName, contains('podcast_last_refreshed_at'));

    final audio = await db
        .customSelect("SELECT name FROM audio_items WHERE id = 'a1'")
        .getSingle();
    expect(audio.data['name'], 'Episode 1');
  });
}

Future<void> _createV37Fixture(File file, {int userVersion = 37}) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE collections');
    raw.execute('DROP TABLE audio_items');
    raw.execute('''
      CREATE TABLE collections (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        created_date INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'local',
        remote_id TEXT,
        cover_url TEXT,
        description TEXT,
        deprecated_at INTEGER
      );
    ''');
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
        original_date INTEGER,
        import_source_type TEXT,
        import_source_url TEXT
      );
    ''');

    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    raw.execute(
      'INSERT INTO collections (id, name, created_date, updated_at) VALUES (?, ?, ?, ?)',
      ['c1', 'My Podcast', now, now],
    );
    raw.execute(
      'INSERT INTO audio_items (id, name, audio_path, added_date, updated_at) VALUES (?, ?, ?, ?, ?)',
      ['a1', 'Episode 1', 'audios/a1.mp3', now, now],
    );

    raw.execute('PRAGMA user_version = $userVersion');
  } finally {
    raw.close();
  }
}

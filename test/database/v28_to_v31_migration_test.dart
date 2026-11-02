import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

void main() {
  test('v28 直接升级到当前版本时保留已有本地合集和音频', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v28_migration_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV28Database(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    final audios = await db.audioItemDao.getAllActive();
    expect(audios, hasLength(1));
    expect(audios.single.id, 'audio-1');
    expect(audios.single.audioPath, 'audios/old.mp3');
    expect(audios.single.remoteAudioId, isNull);
    expect(audios.single.originalDate, isNull);

    final collections = await db.collectionDao.getAllActive();
    expect(collections, hasLength(1));
    expect(collections.single.id, 'col-1');
    expect(collections.single.name, 'Old Collection');
    expect(collections.single.source, 'local');

    final audioIds = await db.collectionDao.getAudioIds('col-1');
    expect(audioIds, ['audio-1']);

    final columns = await db
        .customSelect('PRAGMA table_info(audio_items)')
        .get();
    final columnNames = columns
        .map((row) => row.data['name'] as String)
        .toSet();
    expect(columnNames, contains('remote_audio_id'));
    expect(columnNames, contains('original_date'));
    expect(columnNames, isNot(contains('is_audio_downloaded')));
  });
}

Future<void> _createV28Database(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE collection_audio_items');
    raw.execute('DROP TABLE collections');
    raw.execute('DROP TABLE audio_items');
    raw.execute(
      'ALTER TABLE learning_progresses DROP COLUMN blind_listen_sentence_index',
    );
    raw.execute(
      'ALTER TABLE learning_progresses DROP COLUMN free_play_blind_listen_sentence_index',
    );
    raw.execute(
      'ALTER TABLE learning_progresses DROP COLUMN free_play_retell_sentence_index',
    );
    raw.execute(
      'ALTER TABLE learning_progresses DROP COLUMN retell_sentence_index',
    );
    raw.execute(
      'ALTER TABLE learning_progresses ADD COLUMN blind_listen_paragraph_index INTEGER',
    );
    raw.execute(
      'ALTER TABLE learning_progresses ADD COLUMN free_play_blind_listen_paragraph_index INTEGER',
    );
    raw.execute(
      'ALTER TABLE learning_progresses ADD COLUMN free_play_retell_paragraph_index INTEGER',
    );
    raw.execute(
      'ALTER TABLE learning_progresses ADD COLUMN retell_paragraph_index INTEGER',
    );
    raw.execute('PRAGMA foreign_keys = ON');
    raw.execute('''
      CREATE TABLE audio_items (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        audio_path TEXT NOT NULL,
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
        sync_status INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE collections (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        created_date INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE collection_audio_items (
        collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
        audio_item_id TEXT NOT NULL REFERENCES audio_items(id) ON DELETE CASCADE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (collection_id, audio_item_id)
      );
    ''');

    final now = DateTime(2026, 4, 20).millisecondsSinceEpoch;
    raw
      ..execute(
        '''
        INSERT INTO audio_items (
          id, name, audio_path, added_date, updated_at
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        ['audio-1', 'Old Audio', 'audios/old.mp3', now, now],
      )
      ..execute(
        '''
        INSERT INTO collections (
          id, name, created_date, updated_at
        ) VALUES (?, ?, ?, ?)
        ''',
        ['col-1', 'Old Collection', now, now],
      )
      ..execute(
        '''
        INSERT INTO collection_audio_items (
          collection_id, audio_item_id, sort_order, added_at
        ) VALUES (?, ?, ?, ?)
        ''',
        ['col-1', 'audio-1', 0, now],
      )
      ..execute('PRAGMA user_version = 28');
  } finally {
    raw.close();
  }
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

void main() {
  test('v32 升级到 v33 时为 learning_progresses 加 is_paused 列且默认 false', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v32_to_v33_');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV32LearningProgress(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    final columns = await db
        .customSelect('PRAGMA table_info(learning_progresses)')
        .get();
    final columnNames = columns
        .map((row) => row.data['name'] as String)
        .toSet();
    expect(columnNames, contains('is_paused'));

    final row = await db
        .customSelect(
          "SELECT is_paused FROM learning_progresses WHERE audio_item_id = 'audio-1'",
        )
        .getSingle();
    expect(row.data['is_paused'], 0);
  });
}

Future<void> _createV32LearningProgress(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE learning_progresses');
    raw.execute('''
      CREATE TABLE learning_progresses (
        audio_item_id TEXT NOT NULL PRIMARY KEY,
        current_stage TEXT NOT NULL DEFAULT 'firstLearn',
        current_sub_stage TEXT NOT NULL DEFAULT 'blindListen',
        difficulty INTEGER NOT NULL DEFAULT 1,
        first_learn_completed_at INTEGER,
        last_stage_completed_at INTEGER,
        current_stage_started_at INTEGER,
        total_study_duration_ms INTEGER NOT NULL DEFAULT 0,
        blind_listen_pass_count INTEGER NOT NULL DEFAULT 0,
        intensive_listen_sentence_index INTEGER,
        intensive_listen_difficult_count INTEGER,
        intensive_listen_pass_count INTEGER,
        shadowing_pass_count INTEGER,
        shadowing_sentence_index INTEGER,
        difficult_practice_sentence_index INTEGER,
        retell_paragraph_index INTEGER,
        retell_pass_count INTEGER,
        blind_listen_paragraph_index INTEGER,
        free_play_blind_listen_paragraph_index INTEGER,
        free_play_intensive_listen_sentence_index INTEGER,
        free_play_shadowing_sentence_index INTEGER,
        free_play_difficult_practice_sentence_index INTEGER,
        free_play_retell_paragraph_index INTEGER,
        new_learning_breakpoint_saved_at INTEGER,
        free_play_breakpoint_saved_at INTEGER,
        updated_at INTEGER NOT NULL,
        skipped_sub_stages TEXT NOT NULL DEFAULT ''
      );
    ''');

    final now = DateTime(2026, 5, 1).millisecondsSinceEpoch;
    raw
      ..execute(
        '''
        INSERT INTO learning_progresses (
          audio_item_id, current_stage, current_sub_stage, updated_at
        ) VALUES (?, ?, ?, ?)
        ''',
        ['audio-1', 'review1', 'blindListen', now],
      )
      ..execute('PRAGMA user_version = 32');
  } finally {
    raw.close();
  }
}

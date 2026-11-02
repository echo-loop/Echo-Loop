import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

/// v46→v47 迁移测试：learning_progresses 新增 manual_unlock_at 列
/// （「立即解锁」当前复习轮的时刻），旧行迁移后该列为 NULL。
void main() {
  test('v46→v47 learning_progresses 新增 manual_unlock_at，旧行为 NULL', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v46_to_v47_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV46Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    // 触发打开与迁移后检查表结构
    final columns = await db
        .customSelect(
          "SELECT name FROM pragma_table_info('learning_progresses')",
        )
        .get();
    final columnNames = {for (final row in columns) row.data['name'] as String};
    expect(columnNames, contains('manual_unlock_at'));

    // 旧行迁移后 manual_unlock_at 为 NULL（未手动解锁）
    final rows = await db
        .customSelect(
          'SELECT audio_item_id, manual_unlock_at FROM learning_progresses',
        )
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.data['audio_item_id'], 'audio-1');
    expect(rows.single.data['manual_unlock_at'], isNull);
  });
}

/// 构造 v46 版本的最小 fixture：仅含 learning_progresses（v46 形状）+ 一行旧数据。
Future<void> _createV46Fixture(File file) async {
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
        retell_sentence_index INTEGER,
        retell_pass_count INTEGER,
        blind_listen_sentence_index INTEGER,
        free_play_blind_listen_sentence_index INTEGER,
        free_play_intensive_listen_sentence_index INTEGER,
        free_play_shadowing_sentence_index INTEGER,
        free_play_difficult_practice_sentence_index INTEGER,
        free_play_retell_sentence_index INTEGER,
        new_learning_breakpoint_saved_at INTEGER,
        free_play_breakpoint_saved_at INTEGER,
        updated_at INTEGER NOT NULL,
        skipped_sub_stages TEXT NOT NULL DEFAULT '',
        is_paused INTEGER NOT NULL DEFAULT 0,
        plan_versions_json TEXT NOT NULL DEFAULT '{}'
      );
    ''');

    final now = DateTime(2026, 7, 20).millisecondsSinceEpoch ~/ 1000;
    raw.execute(
      '''
      INSERT INTO learning_progresses (
        audio_item_id, current_stage, current_sub_stage,
        last_stage_completed_at, updated_at
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      ['audio-1', 'review0', 'blindListen', now, now],
    );

    raw.execute('PRAGMA user_version = 46');
  } finally {
    raw.close();
  }
}

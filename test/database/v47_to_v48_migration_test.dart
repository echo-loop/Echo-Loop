import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v47→v48 迁移测试：只新增通用记忆调度表和查询索引，不回填业务数据。
void main() {
  test('v47→v48 创建调度表、事件表、索引与级联外键', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v47_to_v48_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV47Fixture(file);

    final db = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(db.close);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = {for (final row in tables) row.data['name']};
    expect(
      tableNames,
      containsAll(<String>['memory_schedules', 'memory_review_events']),
    );

    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final indexNames = {for (final row in indexes) row.data['name']};
    expect(
      indexNames,
      containsAll(<String>[
        'idx_memory_schedules_active_namespace_due',
        'idx_memory_schedules_active_due',
        'idx_memory_schedules_active_phase_due',
        'idx_memory_schedules_profile',
        'idx_memory_review_events_schedule_reviewed',
      ]),
    );

    await db.customStatement('''
      INSERT INTO memory_schedules (
        id, namespace, subject_id, profile_id, profile_version, model_id,
        model_state_version, phase, status, due_at, review_count, lapse_count,
        revision, created_at, updated_at
      ) VALUES ('schedule-1', 'test', 'subject-1', 'fsrs.default', 1, 'fsrs',
        1, 'newItem', 'active', 0, 0, 0, 0, 0, 0)
    ''');
    await db.customStatement('''
      INSERT INTO memory_review_events (
        id, schedule_id, sequence, operation_id, rating, is_lapse, reviewed_at,
        profile_id, profile_version, model_id, model_state_version, due_before,
        due_after, schedule_revision_after, created_at
      ) VALUES ('event-1', 'schedule-1', 1, 'op-1', 'good', 0, 0,
        'fsrs.default', 1, 'fsrs', 1, 0, 1, 1, 0)
    ''');
    await db.customStatement(
      "DELETE FROM memory_schedules WHERE id = 'schedule-1'",
    );
    final events = await db
        .customSelect('SELECT id FROM memory_review_events')
        .get();
    expect(events, isEmpty);
  });
}

Future<void> _createV47Fixture(File file) async {
  // 先用当前 schema 创建完整业务表，再移除 v47 之后才引入的表。
  // 这样 fixture 仍然只验证 v47 起的迁移，但不会因 v50 回填读取收藏表时
  // 把测试专用的“只含目标表”数据库误当成真实用户数据库。
  final seedDb = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
  await seedDb.customSelect('SELECT 1').get();
  await seedDb.close();

  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE IF EXISTS memory_review_events');
    raw.execute('DROP TABLE IF EXISTS memory_schedules');
    raw.execute('DROP TABLE IF EXISTS memory_review_queue_entries');
    raw.execute('DROP TABLE IF EXISTS tts_cache');
    raw.execute('CREATE TABLE legacy_fixture (id TEXT PRIMARY KEY)');
    raw.execute('PRAGMA user_version = 47');
  } finally {
    raw.close();
  }
}

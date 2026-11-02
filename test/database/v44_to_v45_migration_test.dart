import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

void main() {
  test('v44→当前：清理旧解析（v45）与旧翻译（v46）缓存，保留查词/意群', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v44_to_v45_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV44Fixture(file);

    final db = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT type, result FROM sentence_ai_cache ORDER BY type, text_hash',
        )
        .get();
    final remaining = {for (final row in rows) row.data['type'] as String};

    // v45 清解析、v46 清翻译，均已随迁移执行
    expect(remaining, isNot(contains('analysis:zh-CN')));
    expect(remaining, isNot(contains('analysis_v2:zh-CN')));
    expect(remaining, isNot(contains('translation:zh-CN')));
    // 查词/意群不受影响
    expect(remaining, contains('ai_dictionary'));
    expect(remaining, contains('sense_groups'));
  });
}

Future<void> _createV44Fixture(File file) async {
  await seedCurrentSchema(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('DROP TABLE sentence_ai_cache');
    raw.execute('''
      CREATE TABLE sentence_ai_cache (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        text_hash TEXT NOT NULL,
        type TEXT NOT NULL,
        result TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL,
        UNIQUE(text_hash, type)
      );
    ''');

    final now = DateTime(2026, 7, 11).millisecondsSinceEpoch ~/ 1000;
    final rows = <(String, String, String)>[
      ('h1', 'analysis:zh-CN', '{"old":true}'),
      ('h2', 'analysis_v2:zh-CN', '{"draft":true}'),
      ('h3', 'translation:zh-CN', '{"translation":"你好"}'),
      ('h4', 'ai_dictionary', '{"word":"run"}'),
      ('h5', 'sense_groups', '{"medium":["hello"],"fine":["hello"]}'),
    ];
    for (final (hash, type, result) in rows) {
      raw.execute(
        '''
        INSERT INTO sentence_ai_cache (
          text_hash, type, result, created_at, last_accessed_at
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        [hash, type, result, now, now],
      );
    }

    raw.execute('PRAGMA user_version = 44');
  } finally {
    raw.close();
  }
}

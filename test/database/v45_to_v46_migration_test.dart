import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'migration_fixture_helper.dart';

void main() {
  test('v45→v46 只清理旧翻译缓存（translation:%），不影响解析/查词/意群', () async {
    final dir = Directory.systemTemp.createTempSync('fluency_v45_to_v46_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/echo_loop.db');
    await _createV45Fixture(file);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT type, result FROM sentence_ai_cache ORDER BY type, text_hash',
        )
        .get();
    final remaining = {for (final row in rows) row.data['type'] as String};

    // 旧裸 translation: 被清理
    expect(remaining, isNot(contains('translation:zh-CN')));
    // 解析（v45 后的 analysis_v2）、查词、意群保留
    expect(remaining, contains('analysis_v2:zh-CN'));
    expect(remaining, contains('ai_dictionary'));
    expect(remaining, contains('sense_groups'));
  });
}

Future<void> _createV45Fixture(File file) async {
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

    final now = DateTime(2026, 7, 12).millisecondsSinceEpoch ~/ 1000;
    final rows = <(String, String, String)>[
      ('h1', 'translation:zh-CN', '{"translation":"你好"}'),
      (
        'h2',
        'analysis_v2:zh-CN',
        '{"grammar":[],"vocabulary":[],"listening":[]}',
      ),
      ('h3', 'ai_dictionary', '{"word":"run"}'),
      ('h4', 'sense_groups', '{"medium":["hello"],"fine":["hello"]}'),
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

    raw.execute('PRAGMA user_version = 45');
  } finally {
    raw.dispose();
  }
}

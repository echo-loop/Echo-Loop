import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v66_v67_');
    file = File('${directory.path}/echo_loop.db');
    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    await database.customSelect('SELECT 1').get();
    await database.close();
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('v66→v67 新增 lookup_histories 表，且保留既有词典缓存数据', () async {
    // 还原 v66 结构：删除查词历史表、写入一行已有数据并回退版本号
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('DROP TABLE lookup_histories');
      raw.execute(
        "INSERT INTO dictionary_cache (dict, word, data, created_at) "
        "VALUES ('en_zh-CN', 'run', '{}', 1767225600)",
      );
      raw.execute('PRAGMA user_version = 66');
    } finally {
      raw.close();
    }

    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    final cached = await database.dictionaryCacheDao.get('en_zh-CN', 'run');
    final history = await database.lookupHistoryDao.watchRecent().first;
    await database.close();

    expect(cached, '{}');
    expect(history, isEmpty);

    final check = sqlite.sqlite3.open(file.path);
    try {
      final version = check.select('PRAGMA user_version').first.values.first;
      expect(version, 67);
    } finally {
      check.close();
    }
  });
}

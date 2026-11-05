import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v64_v65_');
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

  test('v64→v65 新增 dictionary_cache 表，且不影响已有数据', () async {
    // 还原 v64 结构：删除新表并回退版本号
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('DROP TABLE IF EXISTS dictionary_cache');
      raw.execute('PRAGMA user_version = 64');
    } finally {
      raw.close();
    }

    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    await database.dictionaryCacheDao.upsert('en_zh-CN', 'run', '{}');
    final cached = await database.dictionaryCacheDao.get('en_zh-CN', 'run');
    await database.close();

    expect(cached, '{}');

    final check = sqlite.sqlite3.open(file.path);
    try {
      final version = check.select('PRAGMA user_version').first.values.first;
      expect(version, 65);
    } finally {
      check.close();
    }
  });
}

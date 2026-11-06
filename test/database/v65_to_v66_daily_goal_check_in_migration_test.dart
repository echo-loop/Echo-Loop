import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v65_v66_');
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

  test('v65→v66 新增 checked_in_goal_minutes 列，且保留既有统计数据', () async {
    // 还原 v65 结构：删除打卡列、写入一行历史统计并回退版本号
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute(
        'ALTER TABLE daily_study_records DROP COLUMN checked_in_goal_minutes',
      );
      raw.execute(
        'INSERT INTO daily_study_records (date, study_time_milliseconds) '
        "VALUES (1767225600, 1234)",
      );
      raw.execute('PRAGMA user_version = 65');
    } finally {
      raw.close();
    }

    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    final record = await database.dailyStudyRecordDao.getAll();
    await database.close();

    expect(record.single.studyTimeMilliseconds, 1234);
    expect(record.single.checkedInGoalMinutes, isNull);

    final check = sqlite.sqlite3.open(file.path);
    try {
      final version = check.select('PRAGMA user_version').first.values.first;
      expect(version, 66);
    } finally {
      check.close();
    }
  });
}

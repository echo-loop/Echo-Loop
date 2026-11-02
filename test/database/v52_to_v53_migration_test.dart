import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v52→v53 按列回填毫秒并保留旧秒字段', () async {
    final directory = await Directory.systemTemp.createTemp('echo_loop_v53_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/echo_loop.db');

    var db = _open(file);
    await db
        .into(db.dailyStudyRecords)
        .insert(
          DailyStudyRecordsCompanion.insert(
            date: DateTime(2026, 9, 16),
            studyTimeSeconds: const Value(2),
            studyTimeMilliseconds: const Value(2000),
            inputTimeSeconds: const Value(3),
            outputTimeSeconds: const Value(4),
            outputTimeMilliseconds: const Value(4000),
          ),
        );
    await db
        .into(db.dailyStageStudyRecords)
        .insert(
          DailyStageStudyRecordsCompanion.insert(
            date: DateTime(2026, 9, 16),
            stage: StudyStage.retell,
            studyTimeSeconds: const Value(5),
            inputTimeSeconds: const Value(6),
            inputTimeMilliseconds: const Value(6000),
            outputTimeSeconds: const Value(7),
          ),
        );
    await db.close();
    _setUserVersion(file, 52);

    db = _open(file);
    final daily = await db.dailyStudyRecordDao.getByDate(DateTime(2026, 9, 16));
    final stage = (await db.dailyStageStudyRecordDao.getByDate(
      DateTime(2026, 9, 16),
    )).single;

    expect(daily?.studyTimeMilliseconds, 2000);
    expect(daily?.inputTimeMilliseconds, 3000);
    expect(daily?.outputTimeMilliseconds, 4000);
    expect(daily?.studyTimeSeconds, 2);
    expect(daily?.inputTimeSeconds, 3);
    expect(daily?.outputTimeSeconds, 4);
    expect(stage.studyTimeMilliseconds, 5000);
    expect(stage.inputTimeMilliseconds, 6000);
    expect(stage.outputTimeMilliseconds, 7000);
    expect(stage.studyTimeSeconds, 5);
    expect(stage.inputTimeSeconds, 6);
    expect(stage.outputTimeSeconds, 7);
    await db.close();
  });

  test('v51 旧秒级 schema 升级后可正常补齐毫秒字段', () async {
    final directory = await Directory.systemTemp.createTemp('echo_loop_v51_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/echo_loop.db');

    var db = _open(file);
    await db
        .into(db.dailyStudyRecords)
        .insert(
          DailyStudyRecordsCompanion.insert(
            date: DateTime(2026, 9, 15),
            studyTimeSeconds: const Value(8),
            inputTimeSeconds: const Value(9),
            outputTimeSeconds: const Value(10),
          ),
        );
    await db.close();
    _dropMillisecondColumns(file);
    _setUserVersion(file, 51);

    db = _open(file);
    final daily = await db.dailyStudyRecordDao.getByDate(DateTime(2026, 9, 15));

    expect(daily?.studyTimeMilliseconds, 8000);
    expect(daily?.inputTimeMilliseconds, 9000);
    expect(daily?.outputTimeMilliseconds, 10000);
    expect(daily?.studyTimeSeconds, 8);
    expect(daily?.inputTimeSeconds, 9);
    expect(daily?.outputTimeSeconds, 10);
    await db.close();
  });
}

AppDatabase _open(File file) => AppDatabase(
  NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys = ON')),
);

void _setUserVersion(File file, int version) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = $version');
  } finally {
    raw.close();
  }
}

void _dropMillisecondColumns(File file) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    for (final table in ['daily_study_records', 'daily_stage_study_records']) {
      for (final column in [
        'study_time_milliseconds',
        'input_time_milliseconds',
        'output_time_milliseconds',
      ]) {
        raw.execute('ALTER TABLE $table DROP COLUMN $column');
      }
    }
  } finally {
    raw.close();
  }
}

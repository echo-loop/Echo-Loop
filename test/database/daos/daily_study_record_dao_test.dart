import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/daily_study_record_dao.dart';
import 'package:echo_loop/database/daos/study_statistics_dao.dart';
import 'package:echo_loop/models/study_stage.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

void main() {
  late AppDatabase db;
  late DailyStudyRecordDao dao;

  setUp(() {
    db = _createTestDb();
    dao = db.dailyStudyRecordDao;
  });

  Future<void> addRecord(
    DateTime date, {
    int studyTime = 0,
    int inputWords = 0,
    int outputWords = 0,
    int inputTime = 0,
    int outputTime = 0,
  }) {
    return db.studyStatisticsDao.applyDelta(
      StudyStatisticsDelta(
        date: date,
        stage: StudyStage.intensiveListen,
        studyTimeMilliseconds: studyTime * 1000,
        inputTimeMilliseconds: inputTime * 1000,
        outputTimeMilliseconds: outputTime * 1000,
        inputWords: inputWords,
        outputWords: outputWords,
      ),
    );
  }

  tearDown(() async {
    await db.close();
  });

  group('DailyStudyRecordDao - 查询', () {
    test('首次插入创建新行', () async {
      final date = DateTime(2026, 3, 10);
      await addRecord(date, studyTime: 60);

      final record = await dao.getByDate(date);
      expect(record, isNotNull);
      expect(record!.studyTimeMilliseconds, 60000);
      expect(record.inputWords, 0);
    });

    test('重复日期累加', () async {
      final date = DateTime(2026, 3, 10);
      await addRecord(date, studyTime: 30);
      await addRecord(date, studyTime: 45);

      final record = await dao.getByDate(date);
      expect(record!.studyTimeMilliseconds, 75000);
    });

    test('多字段同时累加', () async {
      final date = DateTime(2026, 3, 10);
      await addRecord(
        date,
        studyTime: 60,
        inputWords: 100,
        outputWords: 50,
        inputTime: 30,
        outputTime: 20,
      );
      await addRecord(date, inputWords: 50, outputTime: 10);

      final record = await dao.getByDate(date);
      expect(record!.studyTimeMilliseconds, 60000);
      expect(record.inputWords, 150);
      expect(record.outputWords, 50);
      expect(record.inputTimeMilliseconds, 30000);
      expect(record.outputTimeMilliseconds, 30000);
    });

    test('不同日期互不干扰', () async {
      final day1 = DateTime(2026, 3, 10);
      final day2 = DateTime(2026, 3, 11);

      await addRecord(day1, studyTime: 100);
      await addRecord(day2, studyTime: 200);

      expect((await dao.getByDate(day1))!.studyTimeMilliseconds, 100000);
      expect((await dao.getByDate(day2))!.studyTimeMilliseconds, 200000);
    });
  });

  group('DailyStudyRecordDao - getByDate', () {
    test('不存在时返回 null', () async {
      final record = await dao.getByDate(DateTime(2026, 1, 1));
      expect(record, isNull);
    });
  });

  group('DailyStudyRecordDao - getBetween', () {
    test('返回范围内的记录', () async {
      await addRecord(DateTime(2026, 3, 5), studyTime: 10);
      await addRecord(DateTime(2026, 3, 6), studyTime: 20);
      await addRecord(DateTime(2026, 3, 7), studyTime: 30);
      await addRecord(DateTime(2026, 3, 8), studyTime: 40);

      final records = await dao.getBetween(
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 7),
      );
      expect(records.length, 2);
      expect(records[0].studyTimeMilliseconds, 20000);
      expect(records[1].studyTimeMilliseconds, 30000);
    });

    test('范围外的记录不包含', () async {
      await addRecord(DateTime(2026, 3, 1), studyTime: 999);
      await addRecord(DateTime(2026, 3, 10), studyTime: 999);
      await addRecord(DateTime(2026, 3, 5), studyTime: 42);

      final records = await dao.getBetween(
        DateTime(2026, 3, 4),
        DateTime(2026, 3, 6),
      );
      expect(records.length, 1);
      expect(records[0].studyTimeMilliseconds, 42000);
    });

    test('按日期升序排列', () async {
      await addRecord(DateTime(2026, 3, 8), studyTime: 80);
      await addRecord(DateTime(2026, 3, 6), studyTime: 60);
      await addRecord(DateTime(2026, 3, 7), studyTime: 70);

      final records = await dao.getBetween(
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 8),
      );
      expect(records.map((r) => r.studyTimeMilliseconds).toList(), [
        60000,
        70000,
        80000,
      ]);
    });
  });

  group('DailyStudyRecordDao - getStreak', () {
    test('无记录时返回 0', () async {
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 0);
    });

    test('仅今天有记录返回 1', () async {
      await addRecord(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 1);
    });

    test('连续 3 天返回 3', () async {
      await addRecord(DateTime(2026, 3, 6), studyTime: 60);
      await addRecord(DateTime(2026, 3, 7), studyTime: 60);
      await addRecord(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 3);
    });

    test('中间断一天则中断', () async {
      await addRecord(DateTime(2026, 3, 5), studyTime: 60);
      // 3月6日无记录
      await addRecord(DateTime(2026, 3, 7), studyTime: 60);
      await addRecord(DateTime(2026, 3, 8), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 2);
    });

    test('今天无记录但昨天有', () async {
      await addRecord(DateTime(2026, 3, 6), studyTime: 60);
      await addRecord(DateTime(2026, 3, 7), studyTime: 60);
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 2);
    });

    test('学习毫秒为 0 不算有记录', () async {
      await addRecord(DateTime(2026, 3, 7), inputWords: 100);
      await addRecord(DateTime(2026, 3, 8), studyTime: 60);
      // 3月7日 studyTimeMilliseconds=0，streak 中断
      expect(await dao.getStreak(now: DateTime(2026, 3, 8)), 1);
    });
  });
}

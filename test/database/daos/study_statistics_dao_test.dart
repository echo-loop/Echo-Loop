import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/study_statistics_dao.dart';
import 'package:echo_loop/models/study_stage.dart';

void main() {
  late AppDatabase db;
  late StudyStatisticsDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    dao = db.studyStatisticsDao;
  });

  tearDown(() async => db.close());

  test('一个 delta 在同一事务写入总量、阶段、词数和词形', () async {
    final date = DateTime(2026, 9, 8);
    await dao.applyDelta(
      StudyStatisticsDelta(
        date: date,
        stage: StudyStage.retell,
        studyTimeMilliseconds: 1500,
        inputTimeMilliseconds: 500,
        outputTimeMilliseconds: 1000,
        inputWords: 2,
        outputWords: 3,
        wordForms: {'Hello': DateTime(2026, 9, 8, 10)},
      ),
    );
    final total = await db.dailyStudyRecordDao.getByDate(date);
    final stage = (await db.dailyStageStudyRecordDao.getByDate(date)).single;
    final word = (await (db.select(
      db.learnedWordForms,
    )..where((t) => t.wordForm.equals('Hello'))).get()).single;
    expect(total?.studyTimeMilliseconds, 1500);
    expect(total?.studyTimeSeconds, 0);
    expect(total?.inputWords, 2);
    expect(total?.outputWords, 3);
    expect(stage.inputTimeMilliseconds, 500);
    expect(stage.outputTimeMilliseconds, 1000);
    expect(word.firstLearnedAt, DateTime(2026, 9, 8, 10));
  });

  test('亚秒累计不按单次事件取整，旧秒字段不参与业务写入', () async {
    final date = DateTime(2026, 9, 8);
    for (var i = 0; i < 3; i += 1) {
      await dao.applyDelta(
        StudyStatisticsDelta(
          date: date,
          stage: StudyStage.intensiveListen,
          studyTimeMilliseconds: 400,
        ),
      );
    }
    var row = await db.dailyStudyRecordDao.getByDate(date);
    expect(row?.studyTimeMilliseconds, 1200);
    expect(row?.studyTimeSeconds, 0);
    await db
        .into(db.dailyStudyRecords)
        .insert(
          DailyStudyRecordsCompanion.insert(
            date: DateTime(2026, 9, 9),
            studyTimeSeconds: const Value(2),
            studyTimeMilliseconds: const Value(2000),
          ),
        );
    await dao.applyDelta(
      StudyStatisticsDelta(
        date: DateTime(2026, 9, 9),
        stage: StudyStage.intensiveListen,
        studyTimeMilliseconds: 500,
      ),
    );
    row = await db.dailyStudyRecordDao.getByDate(DateTime(2026, 9, 9));
    expect(row?.studyTimeMilliseconds, 2500);
    expect(row?.studyTimeSeconds, 2);
  });

  test('词形冲突保留真正最早时间', () async {
    final date = DateTime(2026, 9, 8);
    await dao.applyDelta(
      StudyStatisticsDelta(
        date: date,
        stage: StudyStage.retell,
        wordForms: {'child': DateTime(2026, 9, 8, 12)},
      ),
    );
    await dao.applyDelta(
      StudyStatisticsDelta(
        date: date,
        stage: StudyStage.retell,
        wordForms: {'child': DateTime(2026, 9, 8, 8)},
      ),
    );
    final rows = await (db.select(
      db.learnedWordForms,
    )..where((t) => t.wordForm.equals('child'))).get();
    expect(rows.single.firstLearnedAt, DateTime(2026, 9, 8, 8));
  });

  test('词形插入失败会回滚整个 delta', () async {
    await db.customStatement('''
      CREATE TRIGGER fail_study_word BEFORE INSERT ON learned_word_forms
      BEGIN SELECT RAISE(ABORT, 'forced word failure'); END
    ''');
    await expectLater(
      dao.applyDelta(
        StudyStatisticsDelta(
          date: DateTime(2026, 9, 8),
          stage: StudyStage.retell,
          studyTimeMilliseconds: 1000,
          outputWords: 2,
          wordForms: {'rollback': DateTime(2026, 9, 8)},
        ),
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      await db.dailyStudyRecordDao.getByDate(DateTime(2026, 9, 8)),
      isNull,
    );
    expect(
      await db.dailyStageStudyRecordDao.getByDate(DateTime(2026, 9, 8)),
      isEmpty,
    );
  });

  test('负数和空 delta 的契约', () async {
    await expectLater(
      dao.applyDelta(
        StudyStatisticsDelta(
          date: DateTime(2026, 9, 8),
          stage: StudyStage.retell,
          outputWords: -1,
        ),
      ),
      throwsArgumentError,
    );
    await dao.applyDelta(
      StudyStatisticsDelta(
        date: DateTime(2026, 9, 8),
        stage: StudyStage.retell,
      ),
    );
    expect(await db.dailyStudyRecordDao.getAll(), isEmpty);
  });
}

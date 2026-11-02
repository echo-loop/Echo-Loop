import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/services/study_time_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late StudyTimeService service;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    service = StudyTimeService(
      db.dailyStudyRecordDao,
      db.dailyStageStudyRecordDao,
      statisticsDao: db.studyStatisticsDao,
    );
  });

  tearDown(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await db.close();
  });

  Future<void> study(int seconds, {DateTime? date}) =>
      service.recordActiveDuration(
        Duration(seconds: seconds),
        stage: StudyStage.intensiveListen,
        date: date,
      );

  test('事件按日和阶段累计，查询等待队列尾部', () async {
    final date = DateTime(2026, 3, 8);
    final write = service.recordActiveDuration(
      const Duration(milliseconds: 1500),
      stage: StudyStage.intensiveListen,
      recordInputDuration: true,
      date: date,
    );
    expect(await service.getStudyTime(date), 1);
    await write;
    final record = await db.dailyStudyRecordDao.getByDate(date);
    expect(record?.studyTimeMilliseconds, 1500);
    expect(record?.inputTimeMilliseconds, 1500);
    expect((await service.getStageBreakdown(date)).single.studyTimeSeconds, 1);
  });

  test('总学习时长和输入时长可以独立累计', () async {
    final date = DateTime(2026, 3, 8);
    await service.recordSessionDurations(
      studyDuration: const Duration(seconds: 5),
      inputDuration: const Duration(seconds: 2),
      stage: StudyStage.freePlayer,
      date: date,
    );

    final record = await db.dailyStudyRecordDao.getByDate(date);
    expect(record?.studyTimeMilliseconds, 5000);
    expect(record?.inputTimeMilliseconds, 2000);
  });

  test('连续天数和周查询保持只读契约', () async {
    final today = DateTime(2026, 3, 8);
    await study(60, date: DateTime(2026, 3, 6));
    await study(60, date: DateTime(2026, 3, 7));
    await study(60, date: today);
    expect(await service.getStudyStreak(now: today), 3);
    expect(await service.getWeeklyStudyTimes(now: today), [
      0,
      0,
      0,
      0,
      60,
      60,
      60,
    ]);
    expect(await service.getWeekTotalStudyTime(now: today), 180);
  });

  test('输入、输出时长和词数按日期隔离', () async {
    final day1 = DateTime(2026, 3, 5);
    final day2 = DateTime(2026, 3, 6);
    await service.recordSentencePlayback(
      duration: const Duration(seconds: 2),
      text: 'one two',
      stage: StudyStage.freePlayer,
      date: day1,
    );
    await service.recordSpeechRecognition(
      duration: const Duration(milliseconds: 450),
      producedWordCount: 3,
      stage: StudyStage.retell,
      date: day2,
    );
    await service.recordOutputWords(4, stage: StudyStage.retell, date: day2);
    expect(await service.getInputTime(day1), 2);
    expect(await service.getInputWords(day1), 2);
    expect(await service.getOutputTime(day2), 0);
    expect(await service.getOutputWords(day2), 7);
  });

  test('句子事件自动计算词数，且不计输入时长时仍记录词形', () async {
    final date = DateTime(2026, 3, 8);
    await service.recordSentencePlayback(
      duration: const Duration(milliseconds: 700),
      text: "Hello, don't re-enter 123 !!! ‘Quoted’",
      stage: StudyStage.freePlayer,
      recordInputDuration: false,
      date: date,
    );

    final row = await db.dailyStudyRecordDao.getByDate(date);
    expect(row?.inputWords, 6);
    expect(row?.inputTimeMilliseconds, 0);
    final forms = await (db.select(
      db.learnedWordForms,
    )..orderBy([(t) => OrderingTerm.asc(t.wordForm)])).get();
    expect(forms.map((form) => form.wordForm), [
      "don't",
      'hello',
      'quoted',
      're-enter',
    ]);
  });

  test('负数由 DAO 抛出，零事件不创建记录', () async {
    await expectLater(
      service.recordActiveDuration(
        const Duration(milliseconds: -1),
        stage: StudyStage.retell,
      ),
      throwsArgumentError,
    );
    await expectLater(service.flush(), throwsArgumentError);
    await service.recordOutputWords(0, stage: StudyStage.retell);
    expect(await db.dailyStudyRecordDao.getAll(), isEmpty);
  });

  test('统计写入不依赖 App 前后台状态', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

    await service.recordSentencePlayback(
      duration: const Duration(seconds: 1),
      text: 'background sentence',
      stage: StudyStage.freePlayer,
      date: DateTime(2026, 9, 8),
    );
    await service.recordSpeechRecognition(
      duration: const Duration(seconds: 1),
      producedWordCount: 3,
      stage: StudyStage.retell,
      date: DateTime(2026, 9, 8),
    );
    await service.recordOutputWords(
      4,
      stage: StudyStage.retell,
      date: DateTime(2026, 9, 8),
    );
    await service.recordActiveDuration(
      const Duration(milliseconds: 250),
      stage: StudyStage.freePlayer,
      date: DateTime(2026, 9, 8),
    );
    await service.flush();
    final record = await db.dailyStudyRecordDao.getByDate(DateTime(2026, 9, 8));
    expect(record?.inputWords, 2);
    expect(record?.inputTimeMilliseconds, 1000);
    expect(record?.outputTimeMilliseconds, 1000);
    expect(record?.outputWords, 7);
    expect(record?.studyTimeMilliseconds, 250);
  });

  test('单个事件失败后队列继续，flush 报告并清除最早失败', () async {
    await db.customStatement('''
      CREATE TRIGGER fail_one_word BEFORE INSERT ON learned_word_forms
      WHEN NEW.word_form = 'bad'
      BEGIN SELECT RAISE(ABORT, 'forced service failure'); END
    ''');
    final failed = service.recordSentencePlayback(
      duration: Duration.zero,
      text: 'bad',
      stage: StudyStage.intensiveListen,
    );
    final continued = service.recordActiveDuration(
      const Duration(seconds: 1),
      stage: StudyStage.intensiveListen,
    );
    await expectLater(failed, throwsA(isA<Exception>()));
    await continued;
    await expectLater(service.flush(), throwsA(isA<Exception>()));
    await service.flush();
    expect(
      (await db.dailyStudyRecordDao.getByDate(
        DateTime.now(),
      ))?.studyTimeMilliseconds,
      1000,
    );
  });

  test('submit 失败不会产生未处理 Future 异常', () async {
    await db.customStatement('''
      CREATE TRIGGER fail_submit_word BEFORE INSERT ON learned_word_forms
      BEGIN SELECT RAISE(ABORT, 'forced submit failure'); END
    ''');
    service.submitSentencePlayback(
      duration: Duration.zero,
      text: 'submit',
      stage: StudyStage.intensiveListen,
    );
    await expectLater(service.flush(), throwsA(isA<Exception>()));
    await service.flush();
  });
}

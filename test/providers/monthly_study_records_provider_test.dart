import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/monthly_study_records_provider.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/services/study_time_service.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late StudyTimeService service;

  setUp(() async {
    db = _createTestDb();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    service = StudyTimeService(
      db.dailyStudyRecordDao,
      db.dailyStageStudyRecordDao,
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('空月份返回空 Map', () async {
    final records = await container.read(
      monthlyStudyRecordsProvider(2026, 1).future,
    );
    expect(records, isEmpty);
  });

  test('有数据月份正确映射', () async {
    await service.recordActiveDuration(
      const Duration(seconds: 600),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 5),
    );
    await service.recordSentencePlayback(
      duration: const Duration(seconds: 300),
      text: '',
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 5),
    );
    await service.recordSpeechRecognition(
      duration: const Duration(seconds: 200),
      stage: StudyStage.retell,
      date: DateTime(2026, 3, 5),
    );
    await service.recordActiveDuration(
      const Duration(seconds: 1800),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 15),
    );
    await service.recordSentencePlayback(
      duration: const Duration(seconds: 900),
      text: '',
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 15),
    );

    final records = await container.read(
      monthlyStudyRecordsProvider(2026, 3).future,
    );

    expect(records.length, 2);
    expect(records[5]!.studyTimeSeconds, 600);
    expect(records[5]!.inputTimeSeconds, 300);
    expect(records[5]!.outputTimeSeconds, 200);
    expect(records[5]!.hasActivity, isTrue);
    expect(records[15]!.studyTimeSeconds, 1800);
    expect(records[15]!.inputTimeSeconds, 900);
    expect(records[1], isNull);
  });

  test('跨月边界不泄漏', () async {
    // 2 月末和 4 月初的数据不应出现在 3 月
    await service.recordActiveDuration(
      const Duration(seconds: 100),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 2, 28),
    );
    await service.recordActiveDuration(
      const Duration(seconds: 200),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 1),
    );
    await service.recordActiveDuration(
      const Duration(seconds: 300),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 3, 31),
    );
    await service.recordActiveDuration(
      const Duration(seconds: 400),
      stage: StudyStage.intensiveListen,
      date: DateTime(2026, 4, 1),
    );

    final records = await container.read(
      monthlyStudyRecordsProvider(2026, 3).future,
    );

    expect(records.length, 2);
    expect(records[1]!.studyTimeSeconds, 200);
    expect(records[31]!.studyTimeSeconds, 300);
  });

  test('MonthDayRecord.hasActivity 为 false 当 studyTime 为 0', () {
    const record = MonthDayRecord(
      studyTimeSeconds: 0,
      inputTimeSeconds: 0,
      outputTimeSeconds: 0,
    );
    expect(record.hasActivity, isFalse);
  });
}

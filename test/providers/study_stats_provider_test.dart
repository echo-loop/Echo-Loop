import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:echo_loop/models/study_stage.dart';

AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = _createTestDb();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('StudyStatsNotifier 聚合已学习词形统计', () async {
    final now = DateTime.now();
    final service = StudyTimeService(
      db.dailyStudyRecordDao,
      db.dailyStageStudyRecordDao,
    );
    await service.recordActiveDuration(
      const Duration(seconds: 1800),
      stage: StudyStage.intensiveListen,
      date: now,
    );
    await service.recordSentencePlayback(
      duration: Duration.zero,
      text: List.filled(40, 'word').join(' '),
      stage: StudyStage.intensiveListen,
      date: now,
    );
    await service.recordSpeechRecognition(
      duration: Duration.zero,
      producedWordCount: 21,
      stage: StudyStage.retell,
      date: now,
    );
    await service.recordSentencePlayback(
      duration: Duration.zero,
      text: 'child children',
      stage: StudyStage.intensiveListen,
      date: now,
    );
    await service.recordSentencePlayback(
      duration: Duration.zero,
      text: 'run',
      stage: StudyStage.intensiveListen,
      date: now.subtract(const Duration(days: 1)),
    );

    final stats = await container.read(studyStatsProvider.future);
    expect(stats.todaySeconds, 1800);
    expect(stats.todayInputWords, 42);
    expect(stats.todayOutputWords, 21);
    expect(stats.learnedWordFormCount, 4);
    expect(stats.todayNewWordForms, 3);
  });
}

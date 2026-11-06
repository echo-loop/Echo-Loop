/// DailyGoalCheckInNotifier 单元测试
///
/// 覆盖：
/// - 当天时长首次达标后打卡并更新 state
/// - 同日再次学习不会再次打卡，state 保持不变
/// - 未达标不打卡
/// - 重建 Provider（模拟重启或切库）后同日不重复打卡
library;

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/daily_goal_check_in/providers/daily_goal_check_in_provider.dart';
import 'package:echo_loop/features/onboarding_survey/providers/onboarding_survey_provider.dart';
import 'package:echo_loop/models/study_stage.dart';
import 'package:echo_loop/providers/study_stats_provider.dart';
import 'package:echo_loop/services/study_time_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late StudyTimeService service;
  late SharedPreferences prefs;
  final today = DateTime(2026, 11, 6);

  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    SharedPreferences.setMockInitialValues({'learning_daily_goal_minutes': 5});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    service = _buildService(db);
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer makeContainer(StudyTimeService studyService) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        studyTimeServiceProvider.overrideWithValue(studyService),
      ],
    );
    addTearDown(container.dispose);
    // 保持 Provider 存活，与应用根部 presenter 的监听方式一致
    container.listen(dailyGoalCheckInProvider, (_, __) {});
    return container;
  }

  Future<void> study(StudyTimeService studyService, int minutes) =>
      studyService.recordSessionDurations(
        studyDuration: Duration(minutes: minutes),
        stage: StudyStage.intensiveListen,
        date: today,
      );

  test('当天时长首次达标后打卡，写入 state 与数据库', () async {
    final container = makeContainer(service);

    await study(service, 5);
    await _waitFor(() => container.read(dailyGoalCheckInProvider) != null);

    final checkIn = container.read(dailyGoalCheckInProvider);
    expect(checkIn?.goalMinutes, 5);
    expect(checkIn?.date, today);
    final row = await db.dailyStudyRecordDao.getByDate(today);
    expect(row?.checkedInGoalMinutes, 5);
  });

  test('未达标时不打卡', () async {
    final container = makeContainer(service);

    await study(service, 4);
    await _settle();

    expect(container.read(dailyGoalCheckInProvider), isNull);
  });

  test('同日再次学习不会再次打卡，state 保持首次实例', () async {
    final container = makeContainer(service);
    await study(service, 5);
    await _waitFor(() => container.read(dailyGoalCheckInProvider) != null);
    final first = container.read(dailyGoalCheckInProvider);

    await study(service, 3);
    await _settle();

    expect(identical(container.read(dailyGoalCheckInProvider), first), isTrue);
  });

  test('打卡成功后刷新学习统计，今日打卡状态无需等待下次进入页面', () async {
    final now = DateTime.now();
    final container = makeContainer(service);
    // 保持学习统计存活，与学习页的监听方式一致
    container.listen(studyStatsProvider, (_, __) {});
    await container.read(studyStatsProvider.future);
    expect(container.read(studyStatsProvider).value?.isTodayCheckedIn, isFalse);

    await service.recordSessionDurations(
      studyDuration: const Duration(minutes: 5),
      stage: StudyStage.intensiveListen,
      date: now,
    );
    await _waitFor(
      () => container.read(studyStatsProvider).value?.isTodayCheckedIn == true,
    );

    expect(container.read(studyStatsProvider).value?.isTodayCheckedIn, isTrue);
  });

  test('重建 Provider（模拟重启）后同日不重复打卡', () async {
    final first = makeContainer(service);
    await study(service, 5);
    await _waitFor(() => first.read(dailyGoalCheckInProvider) != null);

    // 新 service 实例对应重启后的应用，写入的时长已超过目标，但今天已打卡
    final restartedService = _buildService(db);
    final restarted = makeContainer(restartedService);
    await study(restartedService, 2);
    await _settle();

    expect(restarted.read(dailyGoalCheckInProvider), isNull);
    final row = await db.dailyStudyRecordDao.getByDate(today);
    expect(row?.checkedInGoalMinutes, 5);
  });
}

StudyTimeService _buildService(AppDatabase db) => StudyTimeService(
  db.dailyStudyRecordDao,
  db.dailyStageStudyRecordDao,
  statisticsDao: db.studyStatisticsDao,
);

/// 等待异步判定完成；上限约 1 秒，避免测试挂起。
Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// 给异步判定留出足够时间，用于断言「没有发生」。
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

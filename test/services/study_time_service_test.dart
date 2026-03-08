import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluency/services/study_time_service.dart';

void main() {
  group('StudyTimeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('首次调用 getTodayStudyTime 返回 0', () async {
      final service = StudyTimeService();
      final result = await service.getTodayStudyTime();
      expect(result, 0);
    });

    test('addStudyTime 累加到今日 key', () async {
      final service = StudyTimeService();

      await service.addStudyTime(30);
      expect(await service.getTodayStudyTime(), 30);

      await service.addStudyTime(45);
      expect(await service.getTodayStudyTime(), 75);
    });

    test('addStudyTime(0) 不改变已有值', () async {
      final service = StudyTimeService();

      await service.addStudyTime(60);
      await service.addStudyTime(0);
      expect(await service.getTodayStudyTime(), 60);
    });

    test('负数被忽略', () async {
      final service = StudyTimeService();

      await service.addStudyTime(60);
      await service.addStudyTime(-10);
      expect(await service.getTodayStudyTime(), 60);
    });

    test('自定义日期 key 读写正确', () async {
      final service = StudyTimeService();
      final customDate = DateTime(2026, 1, 15);

      await service.addStudyTime(120, date: customDate);
      expect(await service.getStudyTime(customDate), 120);

      // 今日仍为 0
      expect(await service.getTodayStudyTime(), 0);
    });

    test('跨天时 key 自动切换', () async {
      final service = StudyTimeService();

      final day1 = DateTime(2026, 3, 5);
      final day2 = DateTime(2026, 3, 6);

      await service.addStudyTime(100, date: day1);
      await service.addStudyTime(200, date: day2);

      expect(await service.getStudyTime(day1), 100);
      expect(await service.getStudyTime(day2), 200);
    });
  });

  group('StudyTimeService - streak', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('无学习记录时 streak 为 0', () async {
      final service = StudyTimeService();
      final streak = await service.getStudyStreak(
        now: DateTime(2026, 3, 8),
      );
      expect(streak, 0);
    });

    test('仅今天有记录时 streak 为 1', () async {
      final service = StudyTimeService();
      final today = DateTime(2026, 3, 8);
      await service.addStudyTime(60, date: today);

      final streak = await service.getStudyStreak(now: today);
      expect(streak, 1);
    });

    test('连续 3 天学习 streak 为 3', () async {
      final service = StudyTimeService();
      final today = DateTime(2026, 3, 8);
      await service.addStudyTime(60, date: DateTime(2026, 3, 6));
      await service.addStudyTime(60, date: DateTime(2026, 3, 7));
      await service.addStudyTime(60, date: today);

      final streak = await service.getStudyStreak(now: today);
      expect(streak, 3);
    });

    test('中间断一天则 streak 中断', () async {
      final service = StudyTimeService();
      final today = DateTime(2026, 3, 8);
      await service.addStudyTime(60, date: DateTime(2026, 3, 5));
      // 3月6日无记录
      await service.addStudyTime(60, date: DateTime(2026, 3, 7));
      await service.addStudyTime(60, date: today);

      final streak = await service.getStudyStreak(now: today);
      expect(streak, 2); // 只有 7号+8号
    });

    test('今天无记录但昨天有则 streak 从昨天开始计', () async {
      final service = StudyTimeService();
      final today = DateTime(2026, 3, 8);
      await service.addStudyTime(60, date: DateTime(2026, 3, 6));
      await service.addStudyTime(60, date: DateTime(2026, 3, 7));
      // 今天无记录

      final streak = await service.getStudyStreak(now: today);
      expect(streak, 2); // 6号+7号
    });
  });

  group('StudyTimeService - weeklyStudyTimes', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('无记录时返回全 0', () async {
      final service = StudyTimeService();
      final times = await service.getWeeklyStudyTimes(
        now: DateTime(2026, 3, 8),
      );
      expect(times, [0, 0, 0, 0, 0, 0, 0]);
    });

    test('返回过去 7 天的正确数据', () async {
      final service = StudyTimeService();
      final today = DateTime(2026, 3, 8); // Sunday
      await service.addStudyTime(100, date: DateTime(2026, 3, 2)); // Mon
      await service.addStudyTime(200, date: DateTime(2026, 3, 5)); // Thu
      await service.addStudyTime(300, date: today); // Sun

      final times = await service.getWeeklyStudyTimes(now: today);
      // [3/2, 3/3, 3/4, 3/5, 3/6, 3/7, 3/8]
      expect(times, [100, 0, 0, 200, 0, 0, 300]);
    });

    test('列表长度固定为 7', () async {
      final service = StudyTimeService();
      final times = await service.getWeeklyStudyTimes(
        now: DateTime(2026, 3, 8),
      );
      expect(times.length, 7);
    });
  });

  group('StudyTimeService - weekTotalStudyTime', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('无记录时返回 0', () async {
      final service = StudyTimeService();
      final total = await service.getWeekTotalStudyTime(
        now: DateTime(2026, 3, 8),
      );
      expect(total, 0);
    });

    test('累加本周一至今的学习时长', () async {
      final service = StudyTimeService();
      // 2026-3-8 是周日，本周一是 3-2
      final today = DateTime(2026, 3, 8);
      await service.addStudyTime(100, date: DateTime(2026, 3, 2)); // Mon
      await service.addStudyTime(200, date: DateTime(2026, 3, 4)); // Wed
      await service.addStudyTime(300, date: today); // Sun
      // 上周日 3-1 不计入
      await service.addStudyTime(999, date: DateTime(2026, 3, 1));

      final total = await service.getWeekTotalStudyTime(now: today);
      expect(total, 600); // 100+200+300
    });

    test('周一时只计当天', () async {
      final service = StudyTimeService();
      final monday = DateTime(2026, 3, 2); // Monday
      await service.addStudyTime(150, date: monday);
      // 上周日不计入
      await service.addStudyTime(999, date: DateTime(2026, 3, 1));

      final total = await service.getWeekTotalStudyTime(now: monday);
      expect(total, 150);
    });
  });
}

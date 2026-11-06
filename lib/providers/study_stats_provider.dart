import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/providers.dart';

part 'study_stats_provider.g.dart';

/// 学习统计数据模型
class StudyStats {
  /// 连续学习天数
  final int streak;

  /// 今日学习时长（秒）
  final int todaySeconds;

  /// 本周累计学习时长（秒）
  final int weekTotalSeconds;

  /// 过去 7 天每天学习时长（秒），索引 0 = 6 天前，索引 6 = 今天
  final List<int> dailySeconds;

  /// 今日输入词数（听了多少词）
  final int todayInputWords;

  /// 今日输出词数（跟读/复述了多少词）
  final int todayOutputWords;

  /// 累计唯一已学词形数
  final int learnedWordFormCount;

  /// 今日新增唯一词形数
  final int todayNewWordForms;

  /// 今日输入时间（秒）— 音频播放时间
  final int todayInputSeconds;

  /// 今日输出时间（秒）— 跟读/复述暂停时间
  final int todayOutputSeconds;

  /// 过去 7 天每天输入时间（秒），索引 0 = 6 天前，索引 6 = 今天
  final List<int> dailyInputSeconds;

  /// 过去 7 天每天输出时间（秒），索引 0 = 6 天前，索引 6 = 今天
  final List<int> dailyOutputSeconds;

  /// 今日是否已完成每日学习目标打卡
  final bool isTodayCheckedIn;

  const StudyStats({
    this.streak = 0,
    this.todaySeconds = 0,
    this.weekTotalSeconds = 0,
    this.dailySeconds = const [0, 0, 0, 0, 0, 0, 0],
    this.todayInputWords = 0,
    this.todayOutputWords = 0,
    this.learnedWordFormCount = 0,
    this.todayNewWordForms = 0,
    this.todayInputSeconds = 0,
    this.todayOutputSeconds = 0,
    this.dailyInputSeconds = const [0, 0, 0, 0, 0, 0, 0],
    this.dailyOutputSeconds = const [0, 0, 0, 0, 0, 0, 0],
    this.isTodayCheckedIn = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyStats &&
          streak == other.streak &&
          todaySeconds == other.todaySeconds &&
          weekTotalSeconds == other.weekTotalSeconds &&
          todayInputWords == other.todayInputWords &&
          todayOutputWords == other.todayOutputWords &&
          learnedWordFormCount == other.learnedWordFormCount &&
          todayNewWordForms == other.todayNewWordForms &&
          todayInputSeconds == other.todayInputSeconds &&
          todayOutputSeconds == other.todayOutputSeconds &&
          listEquals(dailySeconds, other.dailySeconds) &&
          listEquals(dailyInputSeconds, other.dailyInputSeconds) &&
          listEquals(dailyOutputSeconds, other.dailyOutputSeconds) &&
          isTodayCheckedIn == other.isTodayCheckedIn;

  @override
  int get hashCode => Object.hash(
    streak,
    todaySeconds,
    weekTotalSeconds,
    todayInputWords,
    todayOutputWords,
    learnedWordFormCount,
    todayNewWordForms,
    todayInputSeconds,
    todayOutputSeconds,
    Object.hashAll(dailySeconds),
    Object.hashAll(dailyInputSeconds),
    Object.hashAll(dailyOutputSeconds),
    isTodayCheckedIn,
  );
}

/// 学习统计 Provider
///
/// 聚合 streak、今日时长、本周时长、7 天每日时长。
@riverpod
class StudyStatsNotifier extends _$StudyStatsNotifier {
  @override
  Future<StudyStats> build() async {
    return _load();
  }

  Future<StudyStats> _load() async {
    final service = ref.read(studyTimeServiceProvider);
    final learnedWordFormDao = ref.read(learnedWordFormDaoProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final results = await Future.wait([
      service.getStudyStreak(),
      service.getTodayStudyTime(),
      service.getWeekTotalStudyTime(),
      service.getWeeklyStudyTimes(),
      service.getTodayInputWords(),
      service.getTodayOutputWords(),
      learnedWordFormDao.countAll(),
      learnedWordFormDao.countFirstLearnedBetween(todayStart, tomorrowStart),
      service.getTodayInputTime(),
      service.getTodayOutputTime(),
      service.getWeeklyInputTimes(),
      service.getWeeklyOutputTimes(),
      service.isDailyGoalCheckedIn(now),
    ]);
    return StudyStats(
      streak: results[0] as int,
      todaySeconds: results[1] as int,
      weekTotalSeconds: results[2] as int,
      dailySeconds: results[3] as List<int>,
      todayInputWords: results[4] as int,
      todayOutputWords: results[5] as int,
      learnedWordFormCount: results[6] as int,
      todayNewWordForms: results[7] as int,
      todayInputSeconds: results[8] as int,
      todayOutputSeconds: results[9] as int,
      dailyInputSeconds: results[10] as List<int>,
      dailyOutputSeconds: results[11] as List<int>,
      isTodayCheckedIn: results[12] as bool,
    );
  }

  /// 手动刷新统计数据
  ///
  /// 跳过 AsyncLoading 中间态以避免图表闪烁；
  /// 若新数据与当前数据相同则不发射新状态，减少不必要的重建。
  Future<void> refresh() async {
    final newStats = await _load();
    // 加载期间 notifier 可能已销毁，过期则不再写入 state。
    if (!ref.mounted) return;
    if (newStats != state.value) {
      state = AsyncData(newStats);
    }
  }
}

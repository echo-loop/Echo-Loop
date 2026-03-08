import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/study_time_service.dart';

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

  const StudyStats({
    this.streak = 0,
    this.todaySeconds = 0,
    this.weekTotalSeconds = 0,
    this.dailySeconds = const [0, 0, 0, 0, 0, 0, 0],
  });
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
    final service = StudyTimeService();
    final results = await Future.wait([
      service.getStudyStreak(),
      service.getTodayStudyTime(),
      service.getWeekTotalStudyTime(),
      service.getWeeklyStudyTimes(),
    ]);
    return StudyStats(
      streak: results[0] as int,
      todaySeconds: results[1] as int,
      weekTotalSeconds: results[2] as int,
      dailySeconds: results[3] as List<int>,
    );
  }

  /// 手动刷新统计数据
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }
}

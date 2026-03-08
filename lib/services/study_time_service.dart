import 'package:shared_preferences/shared_preferences.dart';

/// 学习时长存储服务
///
/// 使用 SharedPreferences 按日累计学习秒数。
/// Key 格式：`study_time_YYYY-MM-DD`，value 为当日累计秒数。
class StudyTimeService {
  static const String _keyPrefix = 'study_time_';

  /// 获取指定日期的学习时长（秒）
  Future<int> getStudyTime(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyFor(date)) ?? 0;
  }

  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyTime() => getStudyTime(DateTime.now());

  /// 累加学习时长（秒）到指定日期
  ///
  /// [seconds] 必须 > 0，否则忽略。
  /// [date] 默认为今天。
  Future<void> addStudyTime(int seconds, {DateTime? date}) async {
    if (seconds <= 0) return;

    final targetDate = date ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(targetDate);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + seconds);
  }

  /// 获取连续学习天数（streak）
  ///
  /// 从昨天往回数连续有学习记录的天数，今天有学习则 +1。
  /// 上限 365 天，避免无限循环。
  Future<int> getStudyStreak({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();

    int streak = 0;
    final todaySeconds = prefs.getInt(_keyFor(today)) ?? 0;
    if (todaySeconds > 0) streak = 1;

    // 从昨天开始往回数
    for (int i = 1; i <= 365; i++) {
      final date = today.subtract(Duration(days: i));
      final seconds = prefs.getInt(_keyFor(date)) ?? 0;
      if (seconds <= 0) break;
      streak++;
    }

    return streak;
  }

  /// 获取过去 7 天每天的学习时长（秒）
  ///
  /// 返回长度为 7 的列表，索引 0 = 6 天前，索引 6 = 今天。
  Future<List<int>> getWeeklyStudyTimes({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final result = <int>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      result.add(prefs.getInt(_keyFor(date)) ?? 0);
    }
    return result;
  }

  /// 获取本周一至今的累计学习时长（秒）
  Future<int> getWeekTotalStudyTime({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    // weekday: 1=Monday, 7=Sunday
    final daysSinceMonday = today.weekday - 1;
    int total = 0;
    for (int i = 0; i <= daysSinceMonday; i++) {
      final date = today.subtract(Duration(days: daysSinceMonday - i));
      total += prefs.getInt(_keyFor(date)) ?? 0;
    }
    return total;
  }

  /// 生成日期对应的存储 key
  String _keyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$_keyPrefix$y-$m-$d';
  }

  /// 截断时间部分，只保留日期
  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

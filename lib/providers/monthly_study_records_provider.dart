import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/providers.dart';

part 'monthly_study_records_provider.g.dart';

/// 月度某天的学习摘要
class MonthDayRecord {
  /// 当日学习时长（秒），由数据库毫秒真值转换。
  final int studyTimeSeconds;

  /// 当日输入时间（秒），由数据库毫秒真值转换。
  final int inputTimeSeconds;

  /// 当日输出时间（秒），由数据库毫秒真值转换。
  final int outputTimeSeconds;

  /// 当日打卡时的每日学习目标（分钟）；为空表示当天未打卡。
  ///
  /// 上线打卡功能前的日期没有该值，因此不回填，日历上只标记真实打卡。
  final int? checkedInGoalMinutes;

  const MonthDayRecord({
    required this.studyTimeSeconds,
    required this.inputTimeSeconds,
    required this.outputTimeSeconds,
    this.checkedInGoalMinutes,
  });

  /// 当日是否有学习活动
  bool get hasActivity => studyTimeSeconds > 0;

  /// 当日是否已完成每日学习目标
  bool get isCheckedIn => checkedInGoalMinutes != null;
}

/// 查询指定月份的每日学习记录
///
/// 返回 `Map<int, MonthDayRecord>`，key 为日期（1~31），
/// 无记录的日期不在 map 中。
@riverpod
Future<Map<int, MonthDayRecord>> monthlyStudyRecords(
  Ref ref,
  int year,
  int month,
) async {
  final dao = ref.read(dailyStudyRecordDaoProvider);
  final firstDay = DateTime(year, month, 1);
  final lastDay = DateTime(year, month + 1, 0); // 月末最后一天
  final records = await dao.getBetween(firstDay, lastDay);

  final map = <int, MonthDayRecord>{};
  for (final r in records) {
    if (r.studyTimeMilliseconds > 0) {
      map[r.date.day] = MonthDayRecord(
        studyTimeSeconds: r.studyTimeMilliseconds ~/ 1000,
        inputTimeSeconds: r.inputTimeMilliseconds ~/ 1000,
        outputTimeSeconds: r.outputTimeMilliseconds ~/ 1000,
        checkedInGoalMinutes: r.checkedInGoalMinutes,
      );
    }
  }
  return map;
}

import 'package:drift/drift.dart';

/// 每日学习统计表
///
/// 每天一行，记录学习时长、输入/输出词数和时间。
/// `date` 为唯一索引，存储日期（不含时间部分）。
class DailyStudyRecords extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 日期（唯一），只保留年月日
  DateTimeColumn get date => dateTime().unique()();

  /// 旧版当日累计学习时长（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  IntColumn get studyTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日累计学习时长（毫秒）；新统计写入的真实精度来源。
  IntColumn get studyTimeMilliseconds =>
      integer().withDefault(const Constant(0))();

  /// 当日输入词数（听了多少词）
  IntColumn get inputWords => integer().withDefault(const Constant(0))();

  /// 当日输出词数（跟读/复述了多少词）
  IntColumn get outputWords => integer().withDefault(const Constant(0))();

  /// 旧版当日输入时间（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  IntColumn get inputTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日累计输入时间（毫秒）。
  IntColumn get inputTimeMilliseconds =>
      integer().withDefault(const Constant(0))();

  /// 旧版当日输出时间（秒）。仅保留用于旧备份/历史迁移兼容，业务不读取。
  IntColumn get outputTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日累计输出时间（毫秒）。
  IntColumn get outputTimeMilliseconds =>
      integer().withDefault(const Constant(0))();

  /// 当日打卡时的每日学习目标（分钟）。
  ///
  /// 非空表示当天已打卡成功，值为打卡时的目标；为空表示当天尚未打卡。
  /// 与时长同一行存储，保证「是否打卡」与「学习时长」同日一致。
  IntColumn get checkedInGoalMinutes => integer().nullable()();
}

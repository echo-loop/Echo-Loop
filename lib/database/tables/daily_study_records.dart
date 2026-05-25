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

  /// 当日累计学习时长（秒）
  IntColumn get studyTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日输入词数（听了多少词）
  IntColumn get inputWords => integer().withDefault(const Constant(0))();

  /// 当日输出词数（跟读/复述了多少词）
  IntColumn get outputWords => integer().withDefault(const Constant(0))();

  /// 当日输入时间（秒）— 音频播放时间
  IntColumn get inputTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日输出时间（秒）— 跟读/复述暂停时间
  IntColumn get outputTimeSeconds => integer().withDefault(const Constant(0))();
}

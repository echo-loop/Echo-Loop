import 'package:drift/drift.dart';

import '../../models/study_stage.dart';

/// 每日分阶段学习统计表
///
/// 每天每阶段一行，记录该阶段的学习时长、输入时间和输出时间。
/// `{date, stage}` 为唯一组合键。
class DailyStageStudyRecords extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 日期（只保留年月日）
  DateTimeColumn get date => dateTime()();

  /// 学习阶段（intEnum，按 StudyStage.index 存储）
  IntColumn get stage => intEnum<StudyStage>()();

  /// 当日该阶段累计学习时长（秒）
  IntColumn get studyTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日该阶段输入时间（秒）— 音频播放时间
  IntColumn get inputTimeSeconds => integer().withDefault(const Constant(0))();

  /// 当日该阶段输出时间（秒）— 跟读/复述时间
  IntColumn get outputTimeSeconds => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, stage},
  ];
}

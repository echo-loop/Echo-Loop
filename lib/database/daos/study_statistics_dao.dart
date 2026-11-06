import 'package:drift/drift.dart';

import '../../models/study_stage.dart';
import '../app_database.dart';
import '../tables/daily_stage_study_records.dart';
import '../tables/daily_study_records.dart';
import '../tables/learned_word_forms.dart';

part 'study_statistics_dao.g.dart';

/// 一个不可拆分的学习统计事件增量。
final class StudyStatisticsDelta {
  const StudyStatisticsDelta({
    required this.date,
    required this.stage,
    this.studyTimeMilliseconds = 0,
    this.inputTimeMilliseconds = 0,
    this.outputTimeMilliseconds = 0,
    this.inputWords = 0,
    this.outputWords = 0,
    this.wordForms = const <String, DateTime>{},
  });

  final DateTime date;
  final StudyStage stage;
  final int studyTimeMilliseconds;
  final int inputTimeMilliseconds;
  final int outputTimeMilliseconds;
  final int inputWords;
  final int outputWords;
  final Map<String, DateTime> wordForms;

  bool get isEmpty =>
      studyTimeMilliseconds == 0 &&
      inputTimeMilliseconds == 0 &&
      outputTimeMilliseconds == 0 &&
      inputWords == 0 &&
      outputWords == 0 &&
      wordForms.isEmpty;
}

/// 学习统计唯一写入 DAO。
///
/// [applyDelta] 把日总量、阶段时长和词形放进同一个 Drift transaction，
/// 任何一步失败都会回滚整个事件。时长毫秒字段是唯一业务真值，旧秒字段
/// 仅由历史迁移保留，不在业务写入中读取或更新。
@DriftAccessor(
  tables: [DailyStudyRecords, DailyStageStudyRecords, LearnedWordForms],
)
final class StudyStatisticsDao extends DatabaseAccessor<AppDatabase>
    with _$StudyStatisticsDaoMixin {
  StudyStatisticsDao(super.db);

  /// 原子应用一个统计事件；零增量不会创建空的日记录或阶段记录。
  Future<void> applyDelta(StudyStatisticsDelta delta) async {
    _validateDelta(delta);
    if (delta.isEmpty) return;

    final date = DateTime(delta.date.year, delta.date.month, delta.date.day);
    await transaction(() async {
      await _upsertDailyRecord(date, delta);
      if (delta.hasStageDuration) {
        await _upsertStageRecord(date, delta);
      }
      await _upsertWordForms(delta.wordForms);
    });
  }

  /// 当日学习时长首次达到目标时记录打卡，返回本次调用是否完成打卡。
  ///
  /// 判定、去重与落库放在同一条条件 UPDATE 里：只有当天行存在、尚未打卡、
  /// 且时长已达标时才写入，因此并发或重复调用只会有一次返回 true。
  /// 时长与打卡标记同一行，保证两者日期口径一致。
  Future<bool> markDailyGoalCheckIn({
    required DateTime date,
    required int goalMinutes,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final updatedRows = await customUpdate(
      '''
      UPDATE daily_study_records
      SET checked_in_goal_minutes = ?
      WHERE date = ?
        AND checked_in_goal_minutes IS NULL
        AND study_time_milliseconds >= ?
      ''',
      variables: [
        Variable<int>(goalMinutes),
        Variable<int>(dateOnly.millisecondsSinceEpoch ~/ 1000),
        Variable<int>(goalMinutes * Duration.millisecondsPerMinute),
      ],
      updates: {dailyStudyRecords},
    );
    return updatedRows > 0;
  }

  Future<void> _upsertDailyRecord(
    DateTime date,
    StudyStatisticsDelta delta,
  ) async {
    await customStatement(
      '''
      INSERT INTO daily_study_records (
        date,
        study_time_milliseconds,
        input_words,
        output_words,
        input_time_milliseconds,
        output_time_milliseconds
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        study_time_milliseconds = daily_study_records.study_time_milliseconds +
          excluded.study_time_milliseconds,
        input_words = daily_study_records.input_words + excluded.input_words,
        output_words = daily_study_records.output_words + excluded.output_words,
        input_time_milliseconds = daily_study_records.input_time_milliseconds +
          excluded.input_time_milliseconds,
        output_time_milliseconds = daily_study_records.output_time_milliseconds +
          excluded.output_time_milliseconds
      ''',
      [
        date.millisecondsSinceEpoch ~/ 1000,
        delta.studyTimeMilliseconds,
        delta.inputWords,
        delta.outputWords,
        delta.inputTimeMilliseconds,
        delta.outputTimeMilliseconds,
      ],
    );
  }

  Future<void> _upsertStageRecord(
    DateTime date,
    StudyStatisticsDelta delta,
  ) async {
    await customStatement(
      '''
      INSERT INTO daily_stage_study_records (
        date,
        stage,
        study_time_milliseconds,
        input_time_milliseconds,
        output_time_milliseconds
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date, stage) DO UPDATE SET
        study_time_milliseconds = daily_stage_study_records.study_time_milliseconds +
          excluded.study_time_milliseconds,
        input_time_milliseconds = daily_stage_study_records.input_time_milliseconds +
          excluded.input_time_milliseconds,
        output_time_milliseconds = daily_stage_study_records.output_time_milliseconds +
          excluded.output_time_milliseconds
      ''',
      [
        date.millisecondsSinceEpoch ~/ 1000,
        delta.stage.index,
        delta.studyTimeMilliseconds,
        delta.inputTimeMilliseconds,
        delta.outputTimeMilliseconds,
      ],
    );
  }

  Future<void> _upsertWordForms(Map<String, DateTime> wordForms) async {
    for (final entry in wordForms.entries) {
      await customStatement(
        '''
        INSERT INTO learned_word_forms (word_form, first_learned_at)
        VALUES (?, ?)
        ON CONFLICT(word_form) DO UPDATE SET
          first_learned_at = MIN(learned_word_forms.first_learned_at,
                                 excluded.first_learned_at)
        ''',
        [entry.key, entry.value.millisecondsSinceEpoch ~/ 1000],
      );
    }
  }

  void _validateDelta(StudyStatisticsDelta delta) {
    final values = <String, int>{
      'studyTimeMilliseconds': delta.studyTimeMilliseconds,
      'inputTimeMilliseconds': delta.inputTimeMilliseconds,
      'outputTimeMilliseconds': delta.outputTimeMilliseconds,
      'inputWords': delta.inputWords,
      'outputWords': delta.outputWords,
    };
    for (final entry in values.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(entry.value, entry.key, '不能为负数。');
      }
    }
  }
}

extension on StudyStatisticsDelta {
  bool get hasStageDuration =>
      studyTimeMilliseconds > 0 ||
      inputTimeMilliseconds > 0 ||
      outputTimeMilliseconds > 0;
}

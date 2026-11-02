// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_stage_study_record_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyStageStudyRecordDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyStageStudyRecordsTable get dailyStageStudyRecords =>
      attachedDatabase.dailyStageStudyRecords;
  DailyStageStudyRecordDaoManager get managers =>
      DailyStageStudyRecordDaoManager(this);
}

class DailyStageStudyRecordDaoManager {
  final _$DailyStageStudyRecordDaoMixin _db;
  DailyStageStudyRecordDaoManager(this._db);
  $$DailyStageStudyRecordsTableTableManager get dailyStageStudyRecords =>
      $$DailyStageStudyRecordsTableTableManager(
        _db.attachedDatabase,
        _db.dailyStageStudyRecords,
      );
}

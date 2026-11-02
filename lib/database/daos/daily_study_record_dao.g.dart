// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_study_record_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyStudyRecordDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyStudyRecordsTable get dailyStudyRecords =>
      attachedDatabase.dailyStudyRecords;
  DailyStudyRecordDaoManager get managers => DailyStudyRecordDaoManager(this);
}

class DailyStudyRecordDaoManager {
  final _$DailyStudyRecordDaoMixin _db;
  DailyStudyRecordDaoManager(this._db);
  $$DailyStudyRecordsTableTableManager get dailyStudyRecords =>
      $$DailyStudyRecordsTableTableManager(
        _db.attachedDatabase,
        _db.dailyStudyRecords,
      );
}

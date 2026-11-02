// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_statistics_dao.dart';

// ignore_for_file: type=lint
mixin _$StudyStatisticsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyStudyRecordsTable get dailyStudyRecords =>
      attachedDatabase.dailyStudyRecords;
  $DailyStageStudyRecordsTable get dailyStageStudyRecords =>
      attachedDatabase.dailyStageStudyRecords;
  $LearnedWordFormsTable get learnedWordForms =>
      attachedDatabase.learnedWordForms;
  StudyStatisticsDaoManager get managers => StudyStatisticsDaoManager(this);
}

class StudyStatisticsDaoManager {
  final _$StudyStatisticsDaoMixin _db;
  StudyStatisticsDaoManager(this._db);
  $$DailyStudyRecordsTableTableManager get dailyStudyRecords =>
      $$DailyStudyRecordsTableTableManager(
        _db.attachedDatabase,
        _db.dailyStudyRecords,
      );
  $$DailyStageStudyRecordsTableTableManager get dailyStageStudyRecords =>
      $$DailyStageStudyRecordsTableTableManager(
        _db.attachedDatabase,
        _db.dailyStageStudyRecords,
      );
  $$LearnedWordFormsTableTableManager get learnedWordForms =>
      $$LearnedWordFormsTableTableManager(
        _db.attachedDatabase,
        _db.learnedWordForms,
      );
}

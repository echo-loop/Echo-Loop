// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $LearningProgressesTable get learningProgresses =>
      attachedDatabase.learningProgresses;
  LearningProgressDaoManager get managers => LearningProgressDaoManager(this);
}

class LearningProgressDaoManager {
  final _$LearningProgressDaoMixin _db;
  LearningProgressDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$LearningProgressesTableTableManager get learningProgresses =>
      $$LearningProgressesTableTableManager(
        _db.attachedDatabase,
        _db.learningProgresses,
      );
}

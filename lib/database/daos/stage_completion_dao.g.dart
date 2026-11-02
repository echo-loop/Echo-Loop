// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stage_completion_dao.dart';

// ignore_for_file: type=lint
mixin _$StageCompletionDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $StageCompletionsTable get stageCompletions =>
      attachedDatabase.stageCompletions;
  StageCompletionDaoManager get managers => StageCompletionDaoManager(this);
}

class StageCompletionDaoManager {
  final _$StageCompletionDaoMixin _db;
  StageCompletionDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$StageCompletionsTableTableManager get stageCompletions =>
      $$StageCompletionsTableTableManager(
        _db.attachedDatabase,
        _db.stageCompletions,
      );
}

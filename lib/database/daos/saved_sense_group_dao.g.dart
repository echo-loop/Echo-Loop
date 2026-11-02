// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_sense_group_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedSenseGroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $SavedSenseGroupsTable get savedSenseGroups =>
      attachedDatabase.savedSenseGroups;
  SavedSenseGroupDaoManager get managers => SavedSenseGroupDaoManager(this);
}

class SavedSenseGroupDaoManager {
  final _$SavedSenseGroupDaoMixin _db;
  SavedSenseGroupDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$SavedSenseGroupsTableTableManager get savedSenseGroups =>
      $$SavedSenseGroupsTableTableManager(
        _db.attachedDatabase,
        _db.savedSenseGroups,
      );
}

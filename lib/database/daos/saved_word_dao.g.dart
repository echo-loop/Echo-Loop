// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_word_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedWordDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $SavedWordsTable get savedWords => attachedDatabase.savedWords;
  SavedWordDaoManager get managers => SavedWordDaoManager(this);
}

class SavedWordDaoManager {
  final _$SavedWordDaoMixin _db;
  SavedWordDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$SavedWordsTableTableManager get savedWords =>
      $$SavedWordsTableTableManager(_db.attachedDatabase, _db.savedWords);
}

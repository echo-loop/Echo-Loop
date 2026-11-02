// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_item_dao.dart';

// ignore_for_file: type=lint
mixin _$AudioItemDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  AudioItemDaoManager get managers => AudioItemDaoManager(this);
}

class AudioItemDaoManager {
  final _$AudioItemDaoMixin _db;
  AudioItemDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
}

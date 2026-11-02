// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CollectionsTable get collections => attachedDatabase.collections;
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $CollectionAudioItemsTable get collectionAudioItems =>
      attachedDatabase.collectionAudioItems;
  CollectionDaoManager get managers => CollectionDaoManager(this);
}

class CollectionDaoManager {
  final _$CollectionDaoMixin _db;
  CollectionDaoManager(this._db);
  $$CollectionsTableTableManager get collections =>
      $$CollectionsTableTableManager(_db.attachedDatabase, _db.collections);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$CollectionAudioItemsTableTableManager get collectionAudioItems =>
      $$CollectionAudioItemsTableTableManager(
        _db.attachedDatabase,
        _db.collectionAudioItems,
      );
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_dao.dart';

// ignore_for_file: type=lint
mixin _$TagDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagsTable get tags => attachedDatabase.tags;
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $AudioItemTagsTable get audioItemTags => attachedDatabase.audioItemTags;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$AudioItemTagsTableTableManager get audioItemTags =>
      $$AudioItemTagsTableTableManager(_db.attachedDatabase, _db.audioItemTags);
}

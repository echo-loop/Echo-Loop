// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_review_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoriteReviewDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemorySchedulesTable get memorySchedules => attachedDatabase.memorySchedules;
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $BookmarksTable get bookmarks => attachedDatabase.bookmarks;
  $SavedWordsTable get savedWords => attachedDatabase.savedWords;
  $SavedSenseGroupsTable get savedSenseGroups =>
      attachedDatabase.savedSenseGroups;
  FavoriteReviewDaoManager get managers => FavoriteReviewDaoManager(this);
}

class FavoriteReviewDaoManager {
  final _$FavoriteReviewDaoMixin _db;
  FavoriteReviewDaoManager(this._db);
  $$MemorySchedulesTableTableManager get memorySchedules =>
      $$MemorySchedulesTableTableManager(
        _db.attachedDatabase,
        _db.memorySchedules,
      );
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db.attachedDatabase, _db.bookmarks);
  $$SavedWordsTableTableManager get savedWords =>
      $$SavedWordsTableTableManager(_db.attachedDatabase, _db.savedWords);
  $$SavedSenseGroupsTableTableManager get savedSenseGroups =>
      $$SavedSenseGroupsTableTableManager(
        _db.attachedDatabase,
        _db.savedSenseGroups,
      );
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_subtitle_mask_dao.dart';

// ignore_for_file: type=lint
mixin _$VideoSubtitleMaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $VideoSubtitleMasksTable get videoSubtitleMasks =>
      attachedDatabase.videoSubtitleMasks;
  VideoSubtitleMaskDaoManager get managers => VideoSubtitleMaskDaoManager(this);
}

class VideoSubtitleMaskDaoManager {
  final _$VideoSubtitleMaskDaoMixin _db;
  VideoSubtitleMaskDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$VideoSubtitleMasksTableTableManager get videoSubtitleMasks =>
      $$VideoSubtitleMasksTableTableManager(
        _db.attachedDatabase,
        _db.videoSubtitleMasks,
      );
}

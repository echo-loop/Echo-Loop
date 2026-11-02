// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_state_dao.dart';

// ignore_for_file: type=lint
mixin _$PlaybackStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $AudioItemsTable get audioItems => attachedDatabase.audioItems;
  $PlaybackStatesTable get playbackStates => attachedDatabase.playbackStates;
  PlaybackStateDaoManager get managers => PlaybackStateDaoManager(this);
}

class PlaybackStateDaoManager {
  final _$PlaybackStateDaoMixin _db;
  PlaybackStateDaoManager(this._db);
  $$AudioItemsTableTableManager get audioItems =>
      $$AudioItemsTableTableManager(_db.attachedDatabase, _db.audioItems);
  $$PlaybackStatesTableTableManager get playbackStates =>
      $$PlaybackStatesTableTableManager(
        _db.attachedDatabase,
        _db.playbackStates,
      );
}

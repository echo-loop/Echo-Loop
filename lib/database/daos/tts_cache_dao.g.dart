// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$TtsCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $TtsCacheTable get ttsCache => attachedDatabase.ttsCache;
  TtsCacheDaoManager get managers => TtsCacheDaoManager(this);
}

class TtsCacheDaoManager {
  final _$TtsCacheDaoMixin _db;
  TtsCacheDaoManager(this._db);
  $$TtsCacheTableTableManager get ttsCache =>
      $$TtsCacheTableTableManager(_db.attachedDatabase, _db.ttsCache);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$DictionaryCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictionaryCacheTable get dictionaryCache => attachedDatabase.dictionaryCache;
  DictionaryCacheDaoManager get managers => DictionaryCacheDaoManager(this);
}

class DictionaryCacheDaoManager {
  final _$DictionaryCacheDaoMixin _db;
  DictionaryCacheDaoManager(this._db);
  $$DictionaryCacheTableTableManager get dictionaryCache =>
      $$DictionaryCacheTableTableManager(
        _db.attachedDatabase,
        _db.dictionaryCache,
      );
}

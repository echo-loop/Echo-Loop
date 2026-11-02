// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_ai_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$SentenceAiCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $SentenceAiCacheTable get sentenceAiCache => attachedDatabase.sentenceAiCache;
  SentenceAiCacheDaoManager get managers => SentenceAiCacheDaoManager(this);
}

class SentenceAiCacheDaoManager {
  final _$SentenceAiCacheDaoMixin _db;
  SentenceAiCacheDaoManager(this._db);
  $$SentenceAiCacheTableTableManager get sentenceAiCache =>
      $$SentenceAiCacheTableTableManager(
        _db.attachedDatabase,
        _db.sentenceAiCache,
      );
}

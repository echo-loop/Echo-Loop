import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/dictionary_cache.dart';

part 'dictionary_cache_dao.g.dart';

/// 在线词典查词缓存 DAO
///
/// 以 (dict, word) 读写词条 JSON 原文。批量读取按 SQLite 变量上限分批，
/// 避免收藏页或 PDF 导出一次传入大量词时超限。
@DriftAccessor(tables: [DictionaryCache])
class DictionaryCacheDao extends DatabaseAccessor<AppDatabase>
    with _$DictionaryCacheDaoMixin {
  DictionaryCacheDao(super.db);

  /// SQLite 绑定变量上限（默认 999）之内的单批词数
  static const _batchSize = 500;

  /// 读取单个词条 JSON 原文；未命中返回 null。
  Future<String?> get(String dict, String word) async {
    final row =
        await (select(dictionaryCache)
              ..where((t) => t.dict.equals(dict) & t.word.equals(word)))
            .getSingleOrNull();
    return row?.data;
  }

  /// 批量读取词条 JSON 原文，返回 `word → JSON`；未命中的词不在结果中。
  Future<Map<String, String>> getMany(String dict, List<String> words) async {
    final result = <String, String>{};
    for (var i = 0; i < words.length; i += _batchSize) {
      final end = i + _batchSize > words.length ? words.length : i + _batchSize;
      final batch = words.sublist(i, end);
      final rows = await (select(
        dictionaryCache,
      )..where((t) => t.dict.equals(dict) & t.word.isIn(batch))).get();
      for (final row in rows) {
        result[row.word] = row.data;
      }
    }
    return result;
  }

  /// 插入或覆盖词条 JSON 原文（以 (dict, word) 为唯一键）。
  Future<void> upsert(String dict, String word, String data) {
    return into(dictionaryCache).insert(
      DictionaryCacheCompanion.insert(
        dict: dict,
        word: word,
        data: data,
        createdAt: DateTime.now(),
      ),
      onConflict: DoUpdate(
        (old) => DictionaryCacheCompanion(data: Value(data)),
        target: [dictionaryCache.dict, dictionaryCache.word],
      ),
    );
  }

  /// 删除单条缓存（用于缓存行损坏时强制回源）。
  Future<int> deleteOne(String dict, String word) {
    return (delete(
      dictionaryCache,
    )..where((t) => t.dict.equals(dict) & t.word.equals(word))).go();
  }

  /// 清空全部词典缓存（用户清除缓存时调用）。
  Future<int> deleteAll() => delete(dictionaryCache).go();
}

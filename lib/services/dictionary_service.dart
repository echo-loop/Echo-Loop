/// 本地词典查询服务
///
/// 基于 SQLite 的离线词典，由 [DictionaryProvider] 负责下载和打开 `dict.sqlite`，
/// 本服务仅提供查询能力。数据库未就绪时，查询方法返回 null / 空 map。
library;

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/dict_entry.dart';
import '../utils/text_normalize.dart';
import 'app_logger.dart';

/// 词典服务单例
class DictionaryService {
  DictionaryService._();

  /// 测试用构造器，允许注入已打开的数据库
  @visibleForTesting
  DictionaryService.withDatabase(Database db) : _db = db;

  static DictionaryService _instance = DictionaryService._();

  /// 全局单例
  static DictionaryService get instance => _instance;

  /// 测试用：替换全局单例，返回旧实例以便恢复
  @visibleForTesting
  static DictionaryService replaceInstance(DictionaryService service) {
    final old = _instance;
    _instance = service;
    return old;
  }

  Database? _db;

  /// 词典数据库是否已就绪
  bool get isAvailable => _db != null;

  /// 打开指定路径的词典数据库
  ///
  /// 由 [DictionaryProvider] 在词典下载完成后调用。
  /// 如果之前已打开其他数据库，会先关闭。
  ///
  /// 首次打开时补建 `word` 列的 **NOCASE 索引**：查询用
  /// `WHERE word = ? COLLATE NOCASE` / `word COLLATE NOCASE IN (...)`，
  /// 若无 NOCASE 索引则每次都全表扫描（770k 行 ~百 ms/次），补索引后变索引查找。
  /// `CREATE INDEX IF NOT EXISTS` 幂等：仅首次构建耗时，之后启动即时。
  /// 为能建索引改用读写模式打开；失败（只读介质等）退化为全表扫描，不致命。
  void openDatabase(String dbPath) {
    _db?.close();
    final db = sqlite3.open(dbPath);
    try {
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_words_word_nocase '
        'ON words(word COLLATE NOCASE)',
      );
    } catch (_) {
      // 建索引失败不致命，仍可查询（退化为全表扫描）
    }
    _db = db;
  }

  /// 预热词典数据库页缓存
  ///
  /// [openDatabase] 只 `open` + 建索引，不读 `words` 行数据；首次批量查词
  /// （如 PDF 导出）要冷加载 B-tree 索引页/数据页（770k 行，~百 ms）。
  /// 启动空闲期跑一条走 NOCASE 索引的批量查询，把索引页与部分数据页带进
  /// SQLite page cache，使首次真实查词命中热缓存。幂等、可安全多次调用。
  void warmUpDatabase() {
    if (_db == null) {
      AppLogger.log('DictWarmUp', '数据库预热跳过：DB 未就绪');
      return;
    }
    final sw = Stopwatch()..start();
    try {
      // 用一组常见词走 `word COLLATE NOCASE IN (...)`，与真实批量查词同路径。
      const probeWords = ['the', 'be', 'have', 'do', 'say', 'word'];
      final found = _queryWords(probeWords);
      AppLogger.log(
        'DictWarmUp',
        '数据库页预热 ${sw.elapsedMilliseconds}ms '
            '(探测 ${probeWords.length} 词，命中 ${found.length})',
      );
    } catch (e) {
      // 预热失败不致命，首次真实查询时再冷加载
      AppLogger.log('DictWarmUp', '数据库预热失败 ${sw.elapsedMilliseconds}ms: $e');
    }
  }

  /// 关闭当前数据库连接
  ///
  /// 切换母语词典时需要先关闭再打开新词典。
  void close() {
    _db?.close();
    _db = null;
  }

  /// 查询单词，返回词典条目；未找到或数据库未就绪时返回 null
  ///
  /// 仅按清洗后的表面词形精确匹配，避免原形条目的音标、释义与发音
  /// 错配到用户实际查询或收藏的变形词。
  DictEntry? lookup(String word) {
    if (_db == null) return null;

    final lower = _normalizeLookupWord(word);
    if (lower.isEmpty) return null;

    return _queryWord(lower);
  }

  String _normalizeLookupWord(String word) => normalizeWord(word);

  /// 直接查询数据库
  DictEntry? _queryWord(String word) {
    final result = _db!.select(
      'SELECT word, phonetic, translation, collins, tag FROM words WHERE word = ? COLLATE NOCASE',
      [word],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return DictEntry.fromRow(
      word: row['word'] as String,
      phonetic: row['phonetic'] as String,
      translation: row['translation'] as String?,
      collins: (row['collins'] as int?) ?? 0,
      tag: row['tag'] as String?,
    );
  }

  /// 批量查询多个单词的词典条目
  ///
  /// 返回 word → DictEntry 的映射，未找到的单词不包含在结果中。
  /// 数据库未就绪时返回空 map。
  Map<String, DictEntry> lookupAll(List<String> words) {
    if (_db == null) return {};
    final result = <String, DictEntry>{};

    // 1. 归一化，建立 normalizedWord → [原始 word] 的映射
    final normalizedToOriginals = <String, List<String>>{};
    for (final word in words) {
      final lower = _normalizeLookupWord(word);
      if (lower.isEmpty) continue;
      (normalizedToOriginals[lower] ??= []).add(word);
    }
    if (normalizedToOriginals.isEmpty) return result;

    // 2. 批量精确匹配（单次 SQL IN 查询）
    final allNormalized = normalizedToOriginals.keys.toList();
    final found = _queryWords(allNormalized);
    for (final MapEntry(key: lower, value: entry) in found.entries) {
      for (final original in normalizedToOriginals[lower]!) {
        result[original] = entry;
      }
    }

    return result;
  }

  /// 批量查询多个单词（单次 SQL），返回 normalizedWord → DictEntry
  Map<String, DictEntry> _queryWords(List<String> words) {
    if (words.isEmpty) return {};
    final result = <String, DictEntry>{};

    // SQLite 变量上限通常 999，分批查询
    const batchSize = 500;
    for (var i = 0; i < words.length; i += batchSize) {
      final batch = words.sublist(
        i,
        i + batchSize > words.length ? words.length : i + batchSize,
      );
      final placeholders = List.filled(batch.length, '?').join(',');
      final rows = _db!.select(
        'SELECT word, phonetic, translation, collins, tag '
        'FROM words WHERE word COLLATE NOCASE IN ($placeholders)',
        batch,
      );
      for (final row in rows) {
        final word = (row['word'] as String).toLowerCase();
        result[word] = DictEntry.fromRow(
          word: row['word'] as String,
          phonetic: row['phonetic'] as String,
          translation: row['translation'] as String?,
          collins: (row['collins'] as int?) ?? 0,
          tag: row['tag'] as String?,
        );
      }
    }
    return result;
  }

  /// 释放资源
  void dispose() {
    _db?.close();
    _db = null;
  }
}

/// 在线词典查询服务
///
/// 查词顺序：本地缓存（`dictionary_cache` 表）→ 后端 `/api/v1/dictionary/{dict}`（免登录）。
/// - 200：写入缓存并返回词条；
/// - 404：未收录，返回 null 且**不缓存**，词典补录后下次查询即可命中；
/// - 其它失败（网络、超时、5xx）：抛出异常，由调用方转为错误态，不伪装成未收录。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../database/daos/dictionary_cache_dao.dart';
import '../models/dict_entry.dart';
import '../utils/text_normalize.dart';
import 'app_logger.dart';

/// 词典查询键：与后端 `normalizeWord` 同规则（缩写保留大写，其余小写）。
///
/// 缓存键必须与后端口径一致，否则 `US`（缩写）与 `us`（代词）会互相覆盖。
/// 长度超限或为空时返回 null，调用方不发请求。
String? dictionaryQueryKey(String word) {
  final cleaned = normalizeDictionaryQueryForPrompt(word);
  if (cleaned.isEmpty || cleaned.length > _maxWordLength) return null;
  return _acronymPattern.hasMatch(cleaned) ? cleaned : cleaned.toLowerCase();
}

/// 与后端 `DICTIONARY_WORD_MAX_LENGTH` 一致
const _maxWordLength = 200;

/// 两个及以上纯大写字母视为缩写
final _acronymPattern = RegExp(r'^[A-Z]{2,}$');

/// 批量查词时同时发出的请求数上限，避免大量收藏词一次打满连接
const _maxConcurrentRequests = 3;

/// 在线词典只收录单个词（导入时只保留纯字母词条）。多词短语与整句必然 404，
/// 且未收录不缓存，每次都会重复请求，因此查询前直接排除。
bool _isDictionaryHeadwordKey(String key) => !key.contains(' ');

/// 在线词典服务
class DictionaryService {
  DictionaryService({
    required DictionaryCacheDao cacheDao,
    required Dio dio,
    required String dictId,
  }) : _cacheDao = cacheDao,
       _dio = dio,
       _dictId = dictId;

  final DictionaryCacheDao _cacheDao;
  final Dio _dio;

  /// 词典 ID，如 `en_zh-CN`，由母语决定
  final String _dictId;

  /// 同一查询键的在途请求。面板查询、收藏页与 PDF 导出并发查同一个词时只发一次请求。
  final Map<String, Future<DictEntry?>> _inFlight = {};

  /// 查询单个词。返回 null 表示未收录或词无效；网络等失败抛出异常。
  Future<DictEntry?> lookup(String word) async {
    final key = dictionaryQueryKey(word);
    if (key == null || !_isDictionaryHeadwordKey(key)) return null;

    final cached = await _readCache(key);
    if (cached != null) return cached;
    return _requestShared(key);
  }

  /// 批量查询，返回 `原始输入词 → 词条` 映射；未收录或失败的词不在结果中。
  ///
  /// 先一次性读取缓存，只对缺失的词发请求（最多 [_maxConcurrentRequests] 路并发）。
  /// 单个词请求失败只记日志并跳过，不影响其它词的结果。
  Future<Map<String, DictEntry>> lookupAll(List<String> words) async {
    final keyToWords = <String, List<String>>{};
    for (final word in words) {
      final key = dictionaryQueryKey(word);
      if (key == null || !_isDictionaryHeadwordKey(key)) continue;
      (keyToWords[key] ??= []).add(word);
    }
    if (keyToWords.isEmpty) return {};

    final keys = keyToWords.keys.toList();
    final cachedRaw = await _cacheDao.getMany(_dictId, keys);
    final entryByKey = <String, DictEntry>{};
    final missingKeys = <String>[];
    for (final key in keys) {
      final raw = cachedRaw[key];
      final entry = raw == null ? null : _decodeCached(key, raw);
      if (entry != null) {
        entryByKey[key] = entry;
      } else {
        missingKeys.add(key);
      }
    }

    await _forEachWithConcurrency(missingKeys, (key) async {
      final entry = await _requestSharedSafely(key);
      if (entry != null) entryByKey[key] = entry;
    });

    final result = <String, DictEntry>{};
    for (final MapEntry(key: key, value: entry) in entryByKey.entries) {
      for (final word in keyToWords[key]!) {
        result[word] = entry;
      }
    }
    return result;
  }

  /// 滑动窗口并发：最多 [_maxConcurrentRequests] 个 worker 从队列取词，
  /// 任一请求完成即补位，慢请求不会阻塞后面的词。
  Future<void> _forEachWithConcurrency(
    List<String> keys,
    Future<void> Function(String key) task,
  ) async {
    var nextIndex = 0;
    Future<void> worker() async {
      // Dart 单线程事件循环，取下标与自增之间没有await，无需加锁
      while (nextIndex < keys.length) {
        final key = keys[nextIndex++];
        await task(key);
      }
    }

    final workerCount = keys.length < _maxConcurrentRequests
        ? keys.length
        : _maxConcurrentRequests;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  }

  /// 读取缓存并解析；缓存行损坏时删除该行，返回 null 以回源重取。
  Future<DictEntry?> _readCache(String key) async {
    final raw = await _cacheDao.get(_dictId, key);
    if (raw == null) return null;
    final entry = _decodeCached(key, raw);
    if (entry == null) {
      await _cacheDao.deleteOne(_dictId, key);
    }
    return entry;
  }

  DictEntry? _decodeCached(String key, String raw) {
    try {
      return _parseEntry(raw);
    } on FormatException catch (error) {
      AppLogger.log('Dict', '缓存词条损坏，已丢弃 word=$key error=$error');
      return null;
    }
  }

  /// 共享同一查询键的在途请求
  Future<DictEntry?> _requestShared(String key) {
    return _inFlight.putIfAbsent(
      key,
      () => _fetchAndCache(key).whenComplete(() {
        // 必须用语句体：表达式形式会返回被移除的 Future 本身，whenComplete 将等待自己而死锁
        _inFlight.remove(key);
      }),
    );
  }

  /// 批量场景使用：单词失败只记日志，返回 null
  Future<DictEntry?> _requestSharedSafely(String key) async {
    try {
      return await _requestShared(key);
    } on DioException catch (error) {
      AppLogger.log('Dict', '批量查词失败 word=$key type=${error.type}');
      return null;
    } on FormatException catch (error) {
      AppLogger.log('Dict', '批量查词返回无效词条 word=$key error=$error');
      return null;
    }
  }

  Future<DictEntry?> _fetchAndCache(String key) async {
    final stopwatch = Stopwatch()..start();
    final response = await _dio.get<String>(
      '/api/v1/dictionary/$_dictId',
      queryParameters: {'word': key},
      options: Options(
        responseType: ResponseType.plain,
        // 404 是「未收录」的正常结果，不走异常分支
        validateStatus: (status) => status == 200 || status == 404,
      ),
    );

    if (response.statusCode == 404) {
      AppLogger.log(
        'Dict',
        '未收录 word=$key elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return null;
    }

    final raw = response.data;
    if (raw == null) {
      throw const FormatException('dictionary response body is empty');
    }
    // 先解析再写缓存：无效词条不入库，避免之后每次都命中坏数据
    final entry = _parseEntry(raw);
    await _cacheDao.upsert(_dictId, key, raw);
    AppLogger.log(
      'Dict',
      '请求并缓存 word=$key elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return entry;
  }

  DictEntry _parseEntry(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('dictionary entry is not a JSON object');
    }
    return DictEntry.fromApiJson(decoded);
  }
}

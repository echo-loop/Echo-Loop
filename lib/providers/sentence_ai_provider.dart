/// AI 句子翻译/解析 Provider
///
/// 三级缓存查找：L1 内存 → L2 SQLite → L3 API。
/// 支持并发请求去重，避免同一句子重复发起 API 调用。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_logger.dart';

import '../database/daos/sentence_ai_cache_dao.dart';
import '../database/providers.dart';
import '../models/sense_group_result.dart';
import '../models/sentence_ai_result.dart';
import '../services/sentence_ai_api_client.dart';
import '../utils/text_normalize.dart';

/// AI 句子翻译/解析服务
///
/// 通过三级缓存（内存 → SQLite → API）获取句子的翻译和解析结果。
/// 使用 pending 请求 Map 实现并发去重。
class SentenceAiNotifier {
  final SentenceAiCacheDao _cacheDao;
  final SentenceAiApiClient _apiClient;

  /// L1 内存缓存
  final Map<String, SentenceTranslation> _translationCache = {};
  final Map<String, SentenceAnalysis> _analysisCache = {};
  final Map<String, SenseGroupResult> _senseGroupCache = {};

  /// 正在进行的请求（用于去重）
  final Map<String, Future<SentenceTranslation>> _pendingTranslations = {};
  final Map<String, Future<SentenceAnalysis>> _pendingAnalyses = {};
  final Map<String, Future<SenseGroupResult>> _pendingSenseGroups = {};

  SentenceAiNotifier({
    required SentenceAiCacheDao cacheDao,
    required SentenceAiApiClient apiClient,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient;

  /// 获取翻译（三级缓存查找）
  ///
  /// L1 内存 → L2 SQLite → L3 API。
  /// 并发请求同一句子会复用同一个 Future。
  /// [targetLanguage] 为 BCP 47 代码，用于缓存隔离和 API 调用。
  Future<SentenceTranslation> getTranslation(
    String text, {
    required String targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';

    // L1: 内存缓存
    final cached = _translationCache[cacheKey];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingTranslations.containsKey(cacheKey)) {
      return _pendingTranslations[cacheKey]!;
    }

    final future = _fetchTranslation(
      hash,
      text,
      targetLanguage: targetLanguage,
      cancelToken: cancelToken,
    );
    _pendingTranslations[cacheKey] = future;
    try {
      return await future;
    } finally {
      _pendingTranslations.remove(cacheKey);
    }
  }

  /// 获取解析（三级缓存查找）
  ///
  /// [targetLanguage] 为 BCP 47 代码，用于缓存隔离和 API 调用。
  Future<SentenceAnalysis> getAnalysis(
    String text, {
    required String targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';

    // L1: 内存缓存
    final cached = _analysisCache[cacheKey];
    if (cached != null) return cached;

    // 去重：复用正在进行的请求
    if (_pendingAnalyses.containsKey(cacheKey)) {
      return _pendingAnalyses[cacheKey]!;
    }

    final future = _fetchAnalysis(
      hash,
      text,
      targetLanguage: targetLanguage,
      cancelToken: cancelToken,
    );
    _pendingAnalyses[cacheKey] = future;
    try {
      return await future;
    } finally {
      _pendingAnalyses.remove(cacheKey);
    }
  }

  /// 获取意群拆分（三级缓存查找）
  Future<SenseGroupResult> getSenseGroups(
    String text, {
    CancelToken? cancelToken,
  }) async {
    final hash = hashText(text);

    // L1: 内存缓存（空结果不视为有效缓存）
    final cached = _senseGroupCache[hash];
    if (cached != null && cached.medium.isNotEmpty) {
      AppLogger.log(
        'SenseGroup',
        'L1 命中 | medium=${cached.medium.length}组 fine=${cached.fine.length}组 | "${text.length > 40 ? '${text.substring(0, 40)}...' : text}"',
      );
      return cached;
    }
    if (cached != null) {
      _senseGroupCache.remove(hash);
    }

    // 去重：复用正在进行的请求
    if (_pendingSenseGroups.containsKey(hash)) {
      AppLogger.log('SenseGroup', '复用进行中请求 | "$text"');
      return _pendingSenseGroups[hash]!;
    }

    AppLogger.log('SenseGroup', 'L1 未命中，开始查找 | "$text"');
    final future = _fetchSenseGroups(hash, text, cancelToken: cancelToken);
    _pendingSenseGroups[hash] = future;
    try {
      return await future;
    } finally {
      _pendingSenseGroups.remove(hash);
    }
  }

  /// 同步查找 L1 翻译缓存（仅内存）
  ///
  /// [targetLanguage] 不传时遍历所有语言版本（向后兼容），传入时精确匹配。
  SentenceTranslation? getCachedTranslation(
    String text, {
    String? targetLanguage,
  }) {
    final hash = hashText(text);
    if (targetLanguage != null) {
      return _translationCache['$hash:$targetLanguage'];
    }
    // 向后兼容：遍历查找任意语言版本
    for (final entry in _translationCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 解析缓存（仅内存）
  ///
  /// [targetLanguage] 不传时遍历所有语言版本（向后兼容），传入时精确匹配。
  SentenceAnalysis? getCachedAnalysis(
    String text, {
    String? targetLanguage,
  }) {
    final hash = hashText(text);
    if (targetLanguage != null) {
      return _analysisCache['$hash:$targetLanguage'];
    }
    for (final entry in _analysisCache.entries) {
      if (entry.key.startsWith('$hash:')) return entry.value;
    }
    return null;
  }

  /// 同步查找 L1 意群缓存（仅内存）
  SenseGroupResult? getCachedSenseGroups(String text) {
    return _senseGroupCache[hashText(text)];
  }

  /// 从 L2 SQLite 预加载翻译到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadTranslationFromDb(
    String text, {
    required String targetLanguage,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    if (_translationCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(hash, 'translation:$targetLanguage');
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _translationCache[cacheKey] = translation;
        return true;
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载解析到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadAnalysisFromDb(
    String text, {
    required String targetLanguage,
  }) async {
    final hash = hashText(text);
    final cacheKey = '$hash:$targetLanguage';
    if (_analysisCache.containsKey(cacheKey)) return true;
    final dbResult = await _cacheDao.getByHash(hash, 'analysis:$targetLanguage');
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _analysisCache[cacheKey] = analysis;
        return true;
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 从 L2 SQLite 预加载意群到 L1 内存（不调用 L3 API）
  ///
  /// 返回 true 表示 L1 或 L2 命中，false 表示无缓存。
  Future<bool> preloadSenseGroupsFromDb(String text) async {
    final hash = hashText(text);
    if (_senseGroupCache.containsKey(hash)) return true;
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          return true;
        }
      } catch (_) {
        // JSON 损坏，跳过
      }
    }
    return false;
  }

  /// 清除内存缓存
  void clearMemoryCache() {
    _translationCache.clear();
    _analysisCache.clear();
    _senseGroupCache.clear();
  }

  /// L2 + L3 翻译查找
  Future<SentenceTranslation> _fetchTranslation(
    String hash,
    String text, {
    required String targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'translation:$targetLanguage';

    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final translation = SentenceTranslation.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _translationCache[cacheKey] = translation;
        return translation;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    final translation = await _apiClient.translate(
      text,
      targetLanguage: targetLanguage,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _translationCache[cacheKey] = translation;
    await _cacheDao.upsert(
      hash,
      l2Type,
      jsonEncode({'translation': translation.translation}),
    );
    return translation;
  }

  /// L2 + L3 解析查找
  Future<SentenceAnalysis> _fetchAnalysis(
    String hash,
    String text, {
    required String targetLanguage,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '$hash:$targetLanguage';
    final l2Type = 'analysis:$targetLanguage';

    // L2: SQLite 缓存（JSON 损坏时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, l2Type);
    if (dbResult != null) {
      try {
        final analysis = SentenceAnalysis.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        _analysisCache[cacheKey] = analysis;
        return analysis;
      } catch (_) {
        // L2 数据损坏或结构变更，继续到 L3 API 调用
      }
    }

    // L3: API 调用
    final analysis = await _apiClient.analyze(
      text,
      targetLanguage: targetLanguage,
      cancelToken: cancelToken,
    );
    // 写入 L1 + L2
    _analysisCache[cacheKey] = analysis;
    await _cacheDao.upsert(
      hash,
      l2Type,
      jsonEncode({
        'analysis': {
          'grammar': analysis.grammar,
          'vocabulary': analysis.vocabulary,
          'listening': analysis.listening,
        },
      }),
    );
    return analysis;
  }

  /// L2 + L3 意群查找
  Future<SenseGroupResult> _fetchSenseGroups(
    String hash,
    String text, {
    CancelToken? cancelToken,
  }) async {
    // L2: SQLite 缓存（JSON 损坏或字段不一致时跳过，fallthrough 到 L3）
    final dbResult = await _cacheDao.getByHash(hash, 'sense_groups');
    if (dbResult != null) {
      try {
        final result = SenseGroupResult.fromJson(
          jsonDecode(dbResult) as Map<String, dynamic>,
        );
        // 检查结果是否有效（旧格式数据 fromJson 不会报错但会返回空列表）
        if (result.medium.isNotEmpty) {
          _senseGroupCache[hash] = result;
          AppLogger.log(
            'SenseGroup',
            'L2 SQLite 命中 | medium=${result.medium.length}组 fine=${result.fine.length}组 equal=${result.areBothEqual}',
          );
          return result;
        }
        // 空结果视为旧格式缓存，删除并 fallthrough 到 L3
        AppLogger.log('SenseGroup', 'L2 SQLite 缓存为空（可能是旧格式），删除并重新请求');
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      } catch (e) {
        // 缓存格式不兼容，删除旧数据后 fallthrough 到 L3
        AppLogger.log('SenseGroup', 'L2 SQLite 格式不兼容，删除旧缓存 | error=$e');
        await _cacheDao.deleteByHash(hash, 'sense_groups');
      }
    }

    // L3: API 调用
    AppLogger.log('SenseGroup', 'L3 调用 API...');
    final sw = Stopwatch()..start();
    final result = await _apiClient.splitSenseGroups(
      text,
      cancelToken: cancelToken,
    );
    sw.stop();
    AppLogger.log(
      'SenseGroup',
      'L3 API 返回 | ${sw.elapsedMilliseconds}ms | medium=${result.medium.length}组 fine=${result.fine.length}组 equal=${result.areBothEqual}',
    );

    // 打印具体分组内容
    for (var i = 0; i < result.medium.length; i++) {
      AppLogger.log('SenseGroup', '  中等[$i]: "${result.medium[i]}"');
    }
    for (var i = 0; i < result.fine.length; i++) {
      AppLogger.log('SenseGroup', '  细粒[$i]: "${result.fine[i]}"');
    }

    // 空结果不缓存（允许用户重试）
    if (result.medium.isEmpty) return result;

    // 写入 L1 + L2
    _senseGroupCache[hash] = result;
    await _cacheDao.upsert(hash, 'sense_groups', jsonEncode(result.toJson()));
    return result;
  }
}

/// SentenceAiNotifier Provider
final sentenceAiNotifierProvider = Provider<SentenceAiNotifier>((ref) {
  return SentenceAiNotifier(
    cacheDao: ref.watch(sentenceAiCacheDaoProvider),
    apiClient: ref.watch(sentenceAiApiClientProvider),
  );
});

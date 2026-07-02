/// AI 词典数据源
///
/// 对接后端 `POST /api/v2/ai/dictionary`（需登录态），三级缓存查找：
/// L1 内存 → L2 SQLite（`sentence_ai_cache` type `ai_dictionary`）→ L3 API。
/// 并发请求同一词复用同一 Future，避免重复调用。不可禁用、需联网。
///
/// **后台单请求语义**：AI 调用烧 token、耗时数秒，故请求一经发起就跑到底——
/// 刻意忽略调用方传入的 [CancelToken]（如关闭弹窗触发的取消），让请求在后台
/// 完成并落 L1+L2 缓存。重查/并发同词命中在途 Future 或缓存，全程只有一个请求。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../database/daos/sentence_ai_cache_dao.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../utils/text_normalize.dart';
import '../sentence_ai_api_client.dart';
import 'dictionary_source.dart';

/// AI 词典源
class AiDictionarySource implements DictionarySource {
  /// 延迟解析依赖：仅在真正查词时才触碰（避免枚举注册表即初始化数据库）
  final ValueGetter<SentenceAiCacheDao> _cacheDao;
  final ValueGetter<SentenceAiApiClient> _apiClient;

  /// L1 内存缓存（key 含 targetLanguage）
  final Map<String, DictionaryEntry> _memCache = {};

  /// 在途请求（并发去重）
  final Map<String, Future<DictionaryEntry>> _pending = {};

  /// SQLite 缓存 type 列，与句子翻译/解析（`translation`/`analysis`）隔离
  static const _cacheType = 'ai_dictionary';

  /// 缺省目标语言
  static const _defaultLanguage = 'zh-CN';

  AiDictionarySource({
    required ValueGetter<SentenceAiCacheDao> cacheDao,
    required ValueGetter<SentenceAiApiClient> apiClient,
  }) : _cacheDao = cacheDao,
       _apiClient = apiClient;

  /// 稳定源 id（供控制器等处引用，避免散落魔法字符串）
  static const sourceId = 'ai';

  @override
  String get id => sourceId;

  @override
  IconData get icon => Icons.auto_awesome;

  @override
  bool get canBeDisabled => false;

  @override
  bool get requiresNetwork => true;

  /// 清空 L1 内存缓存。
  ///
  /// 用户「清除缓存」或切换数据库时调用——SQLite（L2）由 DAO 单独清，
  /// 内存这层必须显式清，否则清缓存后重查仍命中 L1 返回旧结果。
  /// 不动 `_pending`：在途请求让其自然完成（清掉反而可能引发重复请求）。
  void clearMemoryCache() => _memCache.clear();

  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    // 刻意忽略：AI 采用后台单请求语义，调用方取消不中断在途请求（见库级注释）
    CancelToken? cancelToken,
  }) async {
    final token = request.accessToken;
    if (token == null || token.isEmpty) {
      throw const DictionaryAuthRequiredException();
    }
    final language = request.targetLanguage ?? _defaultLanguage;
    // request.word 已由 controller 归一化（见 DictionaryLookupRequest.word 契约），
    // 缓存键、发往后端的词、LLM 输入三者共用同一清洗结果
    final word = request.word;
    final key = hashText('$word|$language');

    // L1 内存
    final mem = _memCache[key];
    if (mem != null) return AiDictResult(mem);

    // 并发去重：同词在途请求复用同一 Future（与 widget 生命周期解耦）
    final inflight = _pending[key];
    if (inflight != null) return AiDictResult(await inflight);

    final future = _fetch(
      key: key,
      word: word,
      accessToken: token,
      language: language,
    );
    _pending[key] = future;
    try {
      return AiDictResult(await future);
    } finally {
      _pending.remove(key);
    }
  }

  /// L2 + L3 查找
  ///
  /// 不接受 CancelToken：请求一经发起即跑到底并落缓存（后台单请求语义）。
  Future<DictionaryEntry> _fetch({
    required String key,
    required String word,
    required String accessToken,
    required String language,
  }) async {
    final cacheDao = _cacheDao();
    final apiClient = _apiClient();

    // L2 SQLite（JSON 损坏则跳过，fallthrough 到 L3）
    final cached = await cacheDao.getByHash(key, _cacheType);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          final entry = DictionaryEntry.fromJson(decoded);
          _memCache[key] = entry;
          return entry;
        }
      } catch (_) {
        // 损坏数据，继续 L3
      }
    }

    // L3 API（null = 后端无 analysis，视作空条目）
    final entry =
        await apiClient.lookupDictionary(
          word,
          accessToken: accessToken,
          targetLanguage: language,
        ) ??
        _emptyEntry(word);

    _memCache[key] = entry;
    await cacheDao.upsert(key, _cacheType, jsonEncode(entry.toJson()));
    return entry;
  }

  /// 空条目（后端无结果时的占位，视图层据 isEmpty 显示空态）
  DictionaryEntry _emptyEntry(String word) => DictionaryEntry(
    headword: word,
    pronunciation: const Pronunciation(uk: '', us: ''),
    meanings: const [],
    commonExpressions: const [],
    wordFamily: const [],
    forms: const [],
    etymology: '',
    learnerTips: const [],
  );
}

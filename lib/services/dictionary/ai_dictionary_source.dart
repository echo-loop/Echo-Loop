/// AI 词典数据源（流式）
///
/// 对接后端流式端点（需登录态），三级缓存查找：
/// L1 内存 → L2 SQLite（`sentence_ai_cache` type `ai_dictionary_v2`）→ L3 流式 API。
/// 按查询是否含空白路由到 `lookup-word`（单词）或 `lookup-phrase`（词组）端点，
/// 规则与后端原 `resolveQueryType` 一致。
///
/// **流式路径尊重取消**（区别于旧「后台单请求语义」）：调用方取消（如关闭
/// 弹窗）会中断在途 HTTP → 后端 `request.signal` abort → 中断 LLM，止损 token；
/// 未完整完成不落缓存（部分结果丢弃）。只有收到后端显式 final 帧才写 L1+L2。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../database/daos/sentence_ai_cache_dao.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/dictionary/dictionary_lookup_result.dart';
import '../../utils/text_normalize.dart';
import '../app_logger.dart';
import '../sentence_ai_api_client.dart';
import 'dictionary_source.dart';

/// AI 词典源
class AiDictionarySource implements DictionarySource {
  /// 延迟解析依赖：仅在真正查词时才触碰（避免枚举注册表即初始化数据库）
  final ValueGetter<SentenceAiCacheDao> _cacheDao;
  final ValueGetter<SentenceAiApiClient> _apiClient;

  /// L1 内存缓存（key 含 targetLanguage）
  final Map<String, AiDictionaryEntry> _memCache = {};

  /// SQLite 缓存 type 列，与句子翻译/解析（`translation`/`analysis`）隔离。
  ///
  /// v2 避开旧多词 prompt 的缓存结构，防止旧 JSON 被新模型解析为空结果。
  static const _cacheType = 'ai_dictionary_v2';

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
  void clearMemoryCache() => _memCache.clear();

  /// 只读缓存（L1 内存 → L2 SQLite）：不发起网络请求，也不要求登录。
  ///
  /// 供只读展示使用（如收藏单词正面释义），调用方借此不会消耗 AI 额度；未命中返回 null。
  Future<AiDictionaryEntry?> readCachedEntry(
    String word, {
    String? targetLanguage,
  }) {
    final cacheWord = normalizeWord(word);
    final language = targetLanguage ?? _defaultLanguage;
    return _readCachedEntry(
      _cacheKey(cacheWord, language),
      cacheWord: cacheWord,
      language: language,
      isPhrase: cacheWord.contains(' '),
    );
  }

  String _cacheKey(String cacheWord, String language) =>
      hashText('$cacheWord|$language');

  /// L1 内存 → L2 SQLite；L2 命中时回填 L1，JSON 损坏视为未命中。
  Future<AiDictionaryEntry?> _readCachedEntry(
    String key, {
    required String cacheWord,
    required String language,
    required bool isPhrase,
  }) async {
    final mem = _memCache[key];
    if (mem != null) {
      AppLogger.log('AI-Dict', '命中内存缓存 词=$cacheWord 语言=$language');
      return mem;
    }
    final cached = await _cacheDao().getByHash(key, _cacheType);
    if (cached == null) return null;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is Map<String, dynamic>) {
        final entry = isPhrase
            ? MultiWordDictionaryEntry.fromJson(decoded)
            : DictionaryEntry.fromJson(decoded);
        _memCache[key] = entry;
        AppLogger.log('AI-Dict', '命中数据库缓存 词=$cacheWord 语言=$language');
        return entry;
      }
    } catch (error) {
      // 损坏数据，按未命中处理（调用方决定是否继续走网络）
      AppLogger.log('AI-Dict', '数据库缓存损坏，按未命中处理 词=$cacheWord error=$error');
    }
    return null;
  }

  /// 流式查词：按 L1 内存 → L2 SQLite → L3 登录/API 的顺序查找。
  /// L1/L2 命中即时单帧返回；未命中且已登录时走 L3 流式，逐帧 yield，
  /// 收到 final 帧（完整完成）才写 L1+L2。取消/异常在写入前抛出 → 不落缓存。
  /// 登录只保护 L3 网络请求，不阻止已缓存结果离线展示。
  Stream<DictionaryLookupResult?> lookupStream(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async* {
    final token = request.accessToken;
    final language = request.targetLanguage ?? _defaultLanguage;
    // request.word 保留大小写进入后端 prompt；缓存键用小写词形，
    // 确保 NASA/nasa 复用同一 L1/L2/L3 缓存。
    final word = request.word;
    final cacheWord = normalizeWord(word);
    final key = _cacheKey(cacheWord, language);
    // 单词 / 词组是两条独立功能，类型仅由查询是否含空白决定（同后端 resolveQueryType）；
    // 缓存读取与端点路由都据此选择具体模型，不靠 originalExpression 结构嗅探。
    final isPhrase = cacheWord.contains(' ');

    final cachedEntry = await _readCachedEntry(
      key,
      cacheWord: cacheWord,
      language: language,
      isPhrase: isPhrase,
    );
    if (cachedEntry != null) {
      yield AiDictResult(cachedEntry);
      return;
    }

    final cacheDao = _cacheDao();

    // L3 网络请求需要登录；缓存读取不受登录状态限制。
    if (token == null || token.isEmpty) {
      AppLogger.log('AI-Dict', '未命中缓存且未登录，跳过网络请求 词=$cacheWord');
      throw const DictionaryAuthRequiredException();
    }
    AppLogger.log(
      'AI-Dict',
      '未命中缓存，发起流式请求 词=$cacheWord 类型=${isPhrase ? '词组' : '单词'} 语言=$language',
    );

    // L3 流式 API：按 isPhrase 分流到单词/词组端点
    final apiClient = _apiClient();
    final stream = isPhrase
        ? apiClient.lookupPhraseStreamFrames(
            word,
            accessToken: token,
            targetLanguage: language,
            cancelToken: cancelToken,
          )
        : apiClient.lookupWordStreamFrames(
            word,
            accessToken: token,
            targetLanguage: language,
            cancelToken: cancelToken,
          );

    AiDictionaryEntry? last;
    var sawFinal = false;
    try {
      await for (final frame in stream) {
        last = frame.entry;
        sawFinal = sawFinal || frame.isFinal;
        yield AiDictResult(frame.entry);
      }
    } catch (error) {
      // 取消、网络或协议错误：未完整完成，不落缓存。
      AppLogger.log('AI-Dict', '流式中断，未写入缓存 词=$cacheWord error=$error');
      rethrow;
    }

    // 只有显式 final 帧才落缓存；正常 EOF 但无 final 视为协议中断/损坏。
    if (last != null && !sawFinal) {
      AppLogger.log('AI-Dict', '流式结束但缺少完成帧，未写入缓存 词=$cacheWord');
      throw const DictionaryStreamException();
    }
    if (last != null && sawFinal) {
      _memCache[key] = last;
      await cacheDao.upsert(key, _cacheType, jsonEncode(last.toJson()));
      AppLogger.log(
        'AI-Dict',
        '完成并写入缓存 词=$cacheWord headword=${last.headword}',
      );
    } else {
      AppLogger.log('AI-Dict', '流式结束但无任何结果 词=$cacheWord');
    }
  }

  /// 接口要求的 [lookup]：消费 [lookupStream] 取最后一帧（完整结果）。
  ///
  /// controller 对 AI 源走 [lookupStream] 逐帧渲染；此方法供其它非流式消费方兜底。
  @override
  Future<DictionaryLookupResult?> lookup(
    DictionaryLookupRequest request, {
    CancelToken? cancelToken,
  }) async {
    DictionaryLookupResult? last;
    await for (final r in lookupStream(request, cancelToken: cancelToken)) {
      last = r;
    }
    return last;
  }
}

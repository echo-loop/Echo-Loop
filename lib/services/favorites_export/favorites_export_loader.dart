/// 收藏导出的数据聚合器
///
/// 只读本地数据，全程不发起任何网络请求：
/// - 句子：收藏句 + 本地句子翻译缓存（上下文哈希，与运行时缓存契约一致）；
/// - 词汇：收藏词/意群 + 本地 AI 查词缓存（第一个义项与其第一个例句）；
///   单词在 AI 缓存未命中时回落到基础词典缓存（第一行释义，无例句）。
///
/// 缓存读取函数经构造注入，纯 Dart 可用 drift 内存库与替身函数直接测试。
library;

import 'package:flutter/foundation.dart' show compute;

import '../../database/daos/audio_item_dao.dart';
import '../../database/daos/bookmark_dao.dart';
import '../../database/daos/saved_sense_group_dao.dart';
import '../../database/daos/saved_word_dao.dart';
import '../../database/daos/sentence_ai_cache_dao.dart';
import '../../models/dict_entry.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/audio_item.dart' show MediaType, mediaTypeForPath;
import '../../models/favorites_export/favorites_export_data.dart';
import '../../models/favorites_export/favorites_export_options.dart';
import '../../models/sentence.dart';
import '../../utils/text_normalize.dart';
import '../pdf_export/common/pdf_ai_cache.dart';
import '../pdf_export/common/pdf_transcript.dart';
import 'favorites_export_definitions.dart';

/// 读取单词 / 意群的 AI 查词缓存（注入 `AiDictionarySource.readCachedEntry`）
///
/// 契约：只读缓存，不发请求、不消耗额度；未命中返回 null。
typedef AiDictionaryCacheReader = Future<AiDictionaryEntry?> Function(
  String word, {
  required String targetLanguage,
});

/// 批量读取基础词典缓存（注入 `DictionaryService.readCachedAll`）
///
/// 契约：只读缓存，不发请求；未缓存的词不在结果中。
typedef LocalDictCacheReader = Future<Map<String, DictEntry>> Function(
  List<String> words,
);

/// 收藏导出数据聚合器
class FavoritesExportLoader {
  final AudioItemDao _audioItemDao;
  final BookmarkDao _bookmarkDao;
  final SavedWordDao _savedWordDao;
  final SavedSenseGroupDao _savedSenseGroupDao;
  final SentenceAiCacheDao _aiCacheDao;
  final AiDictionaryCacheReader _readAiEntry;
  final LocalDictCacheReader _readLocalDict;

  FavoritesExportLoader({
    required AudioItemDao audioItemDao,
    required BookmarkDao bookmarkDao,
    required SavedWordDao savedWordDao,
    required SavedSenseGroupDao savedSenseGroupDao,
    required SentenceAiCacheDao aiCacheDao,
    required AiDictionaryCacheReader readAiEntry,
    required LocalDictCacheReader readLocalDict,
  }) : _audioItemDao = audioItemDao,
       _bookmarkDao = bookmarkDao,
       _savedWordDao = savedWordDao,
       _savedSenseGroupDao = savedSenseGroupDao,
       _aiCacheDao = aiCacheDao,
       _readAiEntry = readAiEntry,
       _readLocalDict = readLocalDict;

  /// 按选项聚合导出文档；未选中的内容类别不读取对应数据
  Future<FavoritesExportDocument> load(
    FavoritesExportOptions options, {
    required String targetLanguage,
  }) async {
    final sentenceGroups = options.includeSentences
        ? await _loadSentenceGroups(
            includeTranslation: options.includeTranslation,
            targetLanguage: targetLanguage,
          )
        : const <FavoriteSentenceGroup>[];
    final vocabulary = options.includeWords
        ? await _loadVocabulary(
            includeDefinition: options.includeDefinition,
            targetLanguage: targetLanguage,
          )
        : const <FavoriteVocabularyEntry>[];
    return FavoritesExportDocument(
      sentenceGroups: sentenceGroups,
      vocabulary: vocabulary,
    );
  }

  // ---------- 句子 ----------

  /// 收藏句子按来源材料分组，组序与 DAO 返回的材料名序一致
  Future<List<FavoriteSentenceGroup>> _loadSentenceGroups({
    required bool includeTranslation,
    required String targetLanguage,
  }) async {
    final bookmarks = await _bookmarkDao.getAllWithAudioName();
    final itemsByAudio = <String, List<BookmarkWithAudio>>{};
    for (final item in bookmarks) {
      (itemsByAudio[item.bookmark.audioItemId] ??= []).add(item);
    }

    final sources = await _audioItemDao.getActiveSourcesByIds(
      itemsByAudio.keys,
    );
    final groups = <FavoriteSentenceGroup>[];
    for (final entry in itemsByAudio.entries) {
      final items = entry.value;
      final source = sources[entry.key];
      final translations = includeTranslation
          ? await _loadTranslationsForAudio(
              entry.key,
              items,
              targetLanguage: targetLanguage,
            )
          : const <int, String>{};
      groups.add(
        FavoriteSentenceGroup(
          sourceName: nonEmptyOrNull(source?.name),
          sourceMedia: _mediaOf(source),
          sentences: [
            for (final item in items)
              FavoriteSentence(
                text: item.bookmark.sentenceText,
                translation: translations[item.bookmark.sentenceIndex],
              ),
          ],
        ),
      );
    }
    return groups;
  }

  /// 读取某材料下收藏句的本地译文：键为收藏句的 sentenceIndex
  ///
  /// 收藏句的当前字幕位置经 [resolvePdfSentenceIndex] 解析（防字幕重解析后错位）；
  /// 解析失败或无缓存的句子不返回译文，不影响句子本身导出。
  Future<Map<int, String>> _loadTranslationsForAudio(
    String audioItemId,
    List<BookmarkWithAudio> items, {
    required String targetLanguage,
  }) async {
    final srt = await _audioItemDao.getTranscriptSrt(audioItemId);
    if (srt == null || srt.isEmpty) return const {};
    final sentences = await compute(parsePdfTranscript, srt);
    if (sentences.isEmpty) return const {};

    final textIndex = <String, int>{};
    for (final s in sentences) {
      textIndex.putIfAbsent(s.text.trim(), () => s.index);
    }

    // 收藏句 sentenceIndex → 字幕位置（解析失败的不入表）
    final resolved = <int, int>{};
    for (final item in items) {
      final position = resolvePdfSentenceIndex(
        storedIndex: item.bookmark.sentenceIndex,
        storedText: item.bookmark.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (position != null) {
        resolved[item.bookmark.sentenceIndex] = position;
      }
    }
    if (resolved.isEmpty) return const {};

    final hashByPosition = <int, String>{
      for (final position in resolved.values)
        position: _translationHash(sentences, position),
    };
    final rawByHash = await _aiCacheDao.getManyByHash(
      hashByPosition.values,
      'translation_v2:$targetLanguage',
    );

    final translations = <int, String>{};
    for (final entry in resolved.entries) {
      final translation = decodeCachedTranslation(
        rawByHash[hashByPosition[entry.value]],
      );
      if (translation != null) translations[entry.key] = translation;
    }
    return translations;
  }

  /// 翻译缓存键：前句 + 本句 + 后句的上下文哈希（与运行时 getTranslationStream 一致）
  String _translationHash(List<Sentence> sentences, int position) {
    return translationContextHash(
      sentences[position].text,
      previous: position > 0 ? sentences[position - 1].text : null,
      next: position < sentences.length - 1
          ? sentences[position + 1].text
          : null,
    );
  }

  // ---------- 词汇 ----------

  /// 收藏词汇平铺，按词形字母序（不区分大小写）
  Future<List<FavoriteVocabularyEntry>> _loadVocabulary({
    required bool includeDefinition,
    required String targetLanguage,
  }) async {
    final words = await _savedWordDao.getAll();
    final groups = await _savedSenseGroupDao.getAll();
    final seeds = [
      for (final word in words)
        VocabularySeed(
          term: word.word,
          lookupKey: word.word,
          isPhrase: false,
          audioItemId: word.audioItemId,
          sentenceText: word.sentenceText,
        ),
      for (final group in groups)
        VocabularySeed(
          term: group.displayText,
          lookupKey: group.phraseText,
          isPhrase: true,
          audioItemId: group.audioItemId,
          sentenceText: group.sentenceText,
        ),
    ]..sort((a, b) => a.term.toLowerCase().compareTo(b.term.toLowerCase()));

    final sources = await _audioItemDao.getActiveSourcesByIds(
      seeds.map((seed) => seed.audioItemId).whereType<String>(),
    );
    final definitions = includeDefinition
        ? await _loadDefinitions(seeds, targetLanguage: targetLanguage)
        : const <String, WordDefinition>{};

    return [
      for (final seed in seeds)
        FavoriteVocabularyEntry(
          term: seed.term,
          isPhrase: seed.isPhrase,
          phonetic: definitions[seed.key]?.phonetic,
          definition: definitions[seed.key]?.definition,
          example: definitions[seed.key]?.example,
          sourceSentence: nonEmptyOrNull(seed.sentenceText),
          sourceName: sources[seed.audioItemId]?.name,
          sourceMedia: _mediaOf(sources[seed.audioItemId]),
        ),
    ];
  }

  /// 释义查找：单词 AI 优先、基础词典兜底；意群只有 AI 结果
  ///
  /// 返回 `seed.key → 释义`，未命中的词条不在结果中。
  Future<Map<String, WordDefinition>> _loadDefinitions(
    List<VocabularySeed> seeds, {
    required String targetLanguage,
  }) async {
    final result = <String, WordDefinition>{};
    for (final seed in seeds) {
      final entry = await _readAiEntry(
        seed.lookupKey,
        targetLanguage: targetLanguage,
      );
      final definition = entry == null ? null : definitionFromAiEntry(entry);
      if (definition != null) result[seed.key] = definition;
    }

    final missingWordKeys = [
      for (final seed in seeds)
        if (!seed.isPhrase && !result.containsKey(seed.key)) seed.lookupKey,
    ];
    if (missingWordKeys.isNotEmpty) {
      final localEntries = await _readLocalDict(missingWordKeys);
      for (final seed in seeds) {
        if (seed.isPhrase || result.containsKey(seed.key)) continue;
        final local = localEntries[seed.lookupKey];
        final definition = local == null
            ? null
            : definitionFromLocalEntry(local);
        if (definition != null) result[seed.key] = definition;
      }
    }
    return result;
  }

  /// 来源媒体类型：按音频路径扩展名判定（与 App 内 mediaType 口径一致）；来源未知为 null
  FavoriteSourceMedia? _mediaOf(ActiveAudioSource? source) {
    if (source == null) return null;
    return mediaTypeForPath(source.audioPath) == MediaType.video
        ? FavoriteSourceMedia.video
        : FavoriteSourceMedia.audio;
  }
}

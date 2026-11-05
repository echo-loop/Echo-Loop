/// 学习材料导出 PDF 的数据聚合器
///
/// 从数据库聚合一篇音频的全部导出内容：字幕句子、段落分组、收藏句标记、
/// 收藏词/意群及其释义（AI 词典缓存优先、在线词典兜底）、句子翻译与
/// AI 解析（只读已有缓存，不发起任何网络请求）。
///
/// 依赖经构造函数注入（DAO + 在线词典查询函数），纯 Dart 可用
/// drift 内存库直接测试。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;

import '../../database/daos/audio_item_dao.dart';
import '../../database/daos/bookmark_dao.dart';
import '../../database/daos/saved_sense_group_dao.dart';
import '../../database/daos/saved_word_dao.dart';
import '../../database/daos/sentence_ai_cache_dao.dart';
import '../../models/dict_entry.dart';
import '../../models/dictionary/dictionary_entry.dart';
import '../../models/pdf_export/study_pdf_data.dart';
import '../../models/sentence.dart';
import '../../models/sentence_ai_result.dart';
import '../../services/app_logger.dart';
import '../../services/subtitle_parser.dart';
import '../../utils/paragraph_grouping.dart';
import '../../utils/saved_text_index.dart';
import '../../utils/text_normalize.dart';
import '../../widgets/practice/sentence_word_selection.dart'
    show WordToken, savedCharRanges, tokenizeSentence;

/// 在线词典**批量**查询函数签名（注入 `DictionaryService.lookupAll`）
///
/// 一次性批量查：先读本地缓存，缺失的词并发请求后端。返回 `原始输入词 → 词条`
/// 映射，未收录或失败的词不含。
typedef LocalDictLookup =
    Future<Map<String, DictEntry>> Function(List<String> words);

/// 词条笔记中间记录：笔记 + 查询键（全局标记计算 / 标号分配用）
///
/// [sourceIndex] 为收藏来源句列表位置，仅在词条无法在任何句子命中
/// （变形词等）时作为归句兜底；正常按全文档首现句归位。
class _VocabNoteSeed {
  final StudyPdfVocabNote note;
  final String lookupKey;
  final bool isPhrase;
  final int sourceIndex;

  const _VocabNoteSeed(
    this.note,
    this.lookupKey,
    this.isPhrase,
    this.sourceIndex,
  );
}

/// 已编号词条：查询键 + 全文档标号（逐句计算标记位用）
class _NumberedTerm {
  final String lookupKey;
  final bool isPhrase;
  final int number;

  const _NumberedTerm(this.lookupKey, this.isPhrase, this.number);
}

/// 词条候选：词典批量查之前先算好的展示信息 + 句中命中区间
///
/// 查询键就是收藏词/意群本身（[lookupKey]，用户在字幕中收藏的表面词形），
/// 所有候选的 AI 缓存与在线词典各**合并成单次批量查**，拼装期不再触库。
class _VocabCandidate {
  final int idx;
  final String term;
  final String lookupKey;
  final bool isPhrase;
  final List<(int, int)> ranges;

  const _VocabCandidate({
    required this.idx,
    required this.term,
    required this.lookupKey,
    required this.isPhrase,
    required this.ranges,
  });
}

/// 段落分组目标时长（与全文盲听默认粒度一致，仅影响版式段间距）
const _paragraphTargetDuration = Duration(seconds: 30);

/// 逐句组装的 compute 入参（只含可跨 isolate 的类型）
///
/// 主 isolate 负责 DB 读取与词条编号（在线词典仅主 isolate 可用），把
/// O(句数×收藏词数) 的分词/命中区间计算连同段落分组、词数统计打包到本
/// 请求里，交由 [_assembleStudyPdfDocument] 在 isolate 中执行，避免占用
/// 主 isolate（字幕解析已单独走 [_parseStudyPdfSrt]）。
class _AssembleRequest {
  final List<Sentence> sentences;
  final Set<int> bookmarkedIndices;
  final Set<String> savedWords;
  final Set<String> savedPhrases;
  final List<_NumberedTerm> numberedTerms;
  final Map<int, List<StudyPdfVocabNote>> notesBySentence;

  /// 句子索引 → 翻译原始 JSON（命中缓存的句子才有条目）
  final Map<int, String> translationJson;

  /// 句子索引 → 解析原始 JSON
  final Map<int, String> analysisJson;

  final String title;
  final int totalDuration;
  final String targetLanguage;

  const _AssembleRequest({
    required this.sentences,
    required this.bookmarkedIndices,
    required this.savedWords,
    required this.savedPhrases,
    required this.numberedTerms,
    required this.notesBySentence,
    required this.translationJson,
    required this.analysisJson,
    required this.title,
    required this.totalDuration,
    required this.targetLanguage,
  });
}

/// compute 入口：字幕解析（数百 ms 级 CPU，放 isolate 不占主 isolate）
Future<List<Sentence>> _parseStudyPdfSrt(String srt) =>
    SubtitleParser.parseSubtitleString(srt);

/// compute 入口：逐句组装 PDF 文档
///
/// 纯函数：分词 + 收藏命中区间 + 词条标号 + 段落分组 + 词数统计，
/// 全部在 isolate 中完成，产出可跨 isolate 回传的 [StudyPdfDocument]。
StudyPdfDocument _assembleStudyPdfDocument(_AssembleRequest req) {
  final sentences = req.sentences;

  // 收藏命中索引：全音频收藏词/意群 → 每句命中字符区间
  final savedIndex = SavedTextIndex.build(
    savedWords: req.savedWords,
    savedPhrases: req.savedPhrases,
  );

  final pdfSentences = <StudyPdfSentence>[];
  for (final s in sentences) {
    final translation = _decodeTranslation(req.translationJson[s.index]);
    final analysis = _decodeAnalysis(req.analysisJson[s.index]);
    final tokens = savedIndex.isEmpty ? null : tokenizeSentence(s.text);
    pdfSentences.add(
      StudyPdfSentence(
        index: s.index,
        text: s.text,
        isBookmarked: req.bookmarkedIndices.contains(s.index),
        savedRanges: tokens == null
            ? const []
            : savedCharRanges(s.text, tokens, savedIndex),
        translation: translation,
        grammar: _nonEmptyOrNull(analysis?.grammarText),
        vocabulary: _nonEmptyOrNull(analysis?.vocabularyText),
        listening: _nonEmptyOrNull(analysis?.listeningText),
        vocabNotes: req.notesBySentence[s.index] ?? const [],
        vocabMarkers: tokens == null
            ? const []
            : _vocabMarkersFor(s.text, tokens, req.numberedTerms),
      ),
    );
  }

  // 段落分组：groupSentencesIntoParagraphs 按原句列表分组，
  // 再映射回已组装的 StudyPdfSentence（index 一一对应）
  final bySentenceIndex = {for (final p in pdfSentences) p.index: p};
  final paragraphs = groupSentencesIntoParagraphs(
    sentences,
    _paragraphTargetDuration,
  ).map((p) => p.map((s) => bySentenceIndex[s.index]!).toList()).toList();

  // 元信息：时长优先取音频元数据，缺失（未探测 = 0）时回退字幕末句结束时间；
  // 词数按 App 统一分词器统计全文 isWord token
  final durationSeconds = req.totalDuration > 0
      ? req.totalDuration
      : sentences.last.endTime.inSeconds;
  var wordCount = 0;
  for (final s in sentences) {
    wordCount += tokenizeSentence(s.text).where((t) => t.isWord).length;
  }

  return StudyPdfDocument(
    title: req.title,
    paragraphs: paragraphs,
    durationSeconds: durationSeconds,
    wordCount: wordCount,
  );
}

/// 解码句子翻译 JSON（非空 translation 才返回）
String? _decodeTranslation(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return _nonEmptyOrNull(SentenceTranslation.fromJson(decoded).translation);
    }
  } catch (_) {
    // 损坏数据视作未命中
  }
  return null;
}

/// 解码句子解析 JSON
SentenceAnalysis? _decodeAnalysis(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return SentenceAnalysis.fromJson(decoded);
    }
  } catch (_) {
    // 损坏数据视作未命中
  }
  return null;
}

/// 计算一句正文的词条标号插入点：(命中区间末尾, 词条标号) 升序列表
///
/// 用**全文档**已编号词条逐个匹配本句——同一收藏词在任何句子出现
/// 都标同一个号，不限于收藏来源句（与橙色下划线的全局语义一致）。
List<(int, int)> _vocabMarkersFor(
  String text,
  List<WordToken> tokens,
  List<_NumberedTerm> terms,
) {
  if (terms.isEmpty) return const [];
  final markers = <(int, int)>[];
  for (final term in terms) {
    final ranges = savedCharRanges(
      text,
      tokens,
      SavedTextIndex.build(
        savedWords: term.isPhrase ? const {} : {term.lookupKey},
        savedPhrases: term.isPhrase ? {term.lookupKey} : const {},
      ),
    );
    for (final (_, end) in ranges) {
      markers.add((end, term.number));
    }
  }
  markers.sort((a, b) => a.$1.compareTo(b.$1));
  return markers;
}

String? _nonEmptyOrNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// 学习材料 PDF 数据聚合器
class StudyPdfLoader {
  final AudioItemDao _audioItemDao;
  final BookmarkDao _bookmarkDao;
  final SavedWordDao _savedWordDao;
  final SavedSenseGroupDao _savedSenseGroupDao;
  final SentenceAiCacheDao _aiCacheDao;
  final LocalDictLookup _localDictLookup;

  StudyPdfLoader({
    required AudioItemDao audioItemDao,
    required BookmarkDao bookmarkDao,
    required SavedWordDao savedWordDao,
    required SavedSenseGroupDao savedSenseGroupDao,
    required SentenceAiCacheDao aiCacheDao,
    required LocalDictLookup localDictLookup,
  }) : _audioItemDao = audioItemDao,
       _bookmarkDao = bookmarkDao,
       _savedWordDao = savedWordDao,
       _savedSenseGroupDao = savedSenseGroupDao,
       _aiCacheDao = aiCacheDao,
       _localDictLookup = localDictLookup;

  /// 聚合指定音频的导出数据
  ///
  /// [targetLanguage] 为 BCP 47 代码（来自用户母语设置），用于定位
  /// 翻译/解析/AI 词典的缓存条目。
  ///
  /// 音频不存在或无字幕时抛 [StateError]（UI 入口已按 hasTranscript
  /// 过滤，正常不应到达）。
  Future<StudyPdfDocument> load(
    String audioItemId, {
    required String targetLanguage,
  }) async {
    // 阶段耗时打点：total 为整个 load 的墙钟耗时，sw 每阶段结束后重置
    final total = Stopwatch()..start();
    final sw = Stopwatch()..start();
    final audio = await _audioItemDao.getById(audioItemId);
    if (audio == null) {
      throw StateError('音频不存在: $audioItemId');
    }
    final srt = await _audioItemDao.getTranscriptSrt(audioItemId);
    if (srt == null || srt.isEmpty) {
      throw StateError('音频无字幕: $audioItemId');
    }
    AppLogger.log('PdfExport', '读取音频+字幕 ${sw.elapsedMilliseconds}ms');
    sw
      ..reset()
      ..start();
    // 字幕解析（数百 ms 级 CPU）放 isolate，避免进预览页时卡住主 isolate
    final sentences = await compute(_parseStudyPdfSrt, srt);
    if (sentences.isEmpty) {
      throw StateError('字幕解析为空: $audioItemId');
    }
    AppLogger.log(
      'PdfExport',
      '字幕解析 ${sw.elapsedMilliseconds}ms (${sentences.length} 句)',
    );
    sw
      ..reset()
      ..start();

    // 文本 → 句子索引的兜底匹配表（重复文本取首个）
    final textIndex = <String, int>{};
    for (final s in sentences) {
      textIndex.putIfAbsent(s.text.trim(), () => s.index);
    }

    // 收藏句索引集合
    final bookmarkedIndices = <int>{};
    for (final b in await _bookmarkDao.getByAudioId(audioItemId)) {
      final idx = _resolveSentenceIndex(
        storedIndex: b.sentenceIndex,
        storedText: b.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx != null) bookmarkedIndices.add(idx);
    }

    // 收藏词/意群 → 按句子归组（附带查询键，全局标记计算用）；
    // 无任何词典结果的条目不产出笔记（右栏不显示）
    final savedWords = await _savedWordDao.getByAudioId(audioItemId);
    final savedGroups = await _savedSenseGroupDao.getByAudioId(audioItemId);

    // ① 候选收集（纯内存）：只处理收藏词/意群**本身**，按其表面词形算命中
    //    区间。不再扫描整句所有单词——收藏词即用户在字幕中收藏的表面词形，
    //    查词直接用它即可。保持「先词后意群、各自按原表顺序」的插入序
    //    （编号排序对同位并列依赖此序，见下方 numbering）。
    final candidates = <_VocabCandidate>[];
    for (final w in savedWords) {
      final idx = _resolveSentenceIndex(
        storedIndex: w.sentenceIndex,
        storedText: w.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx == null) continue;
      candidates.add(
        _makeVocabCandidate(
          idx: idx,
          term: w.word,
          lookupKey: w.word,
          isPhrase: false,
          sentenceText: sentences[idx].text,
        ),
      );
    }
    final wordCandidateCount = candidates.length;
    for (final g in savedGroups) {
      final idx = _resolveSentenceIndex(
        storedIndex: g.sentenceIndex,
        storedText: g.sentenceText,
        sentences: sentences,
        textIndex: textIndex,
      );
      if (idx == null) continue;
      candidates.add(
        _makeVocabCandidate(
          idx: idx,
          term: g.displayText,
          lookupKey: g.phraseText,
          isPhrase: true,
          sentenceText: sentences[idx].text,
        ),
      );
    }

    // ② 词典缓存两路**各一次性批量查**（只查收藏词本身，不查整句）：
    //    - AI 词典缓存（键 = hashText('词|语言')，与 ai_dictionary_source 契约一致）
    //    - 在线词典（仅按收藏词的表面词形精确匹配）
    final aiHashes = {
      for (final c in candidates) hashText('${c.lookupKey}|$targetLanguage'),
    };
    final aiDictRaw = await _aiCacheDao.getManyByHash(
      aiHashes,
      'ai_dictionary',
    );
    final localDict = await _localDictLookup([
      for (final c in candidates) c.lookupKey,
    ]);
    AppLogger.log(
      'PdfExport',
      '  词典批量查 ${sw.elapsedMilliseconds}ms '
          '(${candidates.length} 词条/词 $wordCandidateCount '
          '意群 ${candidates.length - wordCandidateCount}，'
          'AI命中${aiDictRaw.length}/本地命中${localDict.length})',
    );
    sw
      ..reset()
      ..start();

    // ⑤ 构建笔记（AI 优先，在线词典兜底）——纯本地，不再触 DB。
    //    按 (isPhrase, lookupKey) 去重：同一词条多次收藏（或收藏词与正文
    //    变形指向同一查询键）只保留首个，避免右栏重复条目、正文重复标号。
    final seeds = <_VocabNoteSeed>[];
    final seenKeys = <String>{};
    for (final c in candidates) {
      final dedupKey = '${c.isPhrase ? 'p' : 'w'}|${c.lookupKey}';
      if (!seenKeys.add(dedupKey)) continue;
      final note = _buildVocabNoteFromCache(
        c,
        aiDictRaw,
        targetLanguage,
        localDict,
      );
      if (note != null) {
        seeds.add(_VocabNoteSeed(note, c.lookupKey, c.isPhrase, c.idx));
      }
    }

    // 右栏词条按**全文档首次出现位置**（reading order）排序、编号、归句：
    // 每个词条算出它在正文中首次出现的 (句序 order, 句内字符起点 charStart)，
    // 据此升序（首现更早者标号更小、右栏更靠前），笔记归到首现句的右栏
    // （不再归到收藏来源句——用户在末句收藏的词若更早出现，标号/位置都应靠前）。
    // 任何句均未命中的变形词排最后（保留插入序），归回收藏来源句。
    final tokensBySentence = [
      for (final s in sentences) tokenizeSentence(s.text),
    ];
    (int order, int charStart, int sentenceIndex)? firstOccurrence(
      _VocabNoteSeed seed,
    ) {
      final index = SavedTextIndex.build(
        savedWords: seed.isPhrase ? const {} : {seed.lookupKey},
        savedPhrases: seed.isPhrase ? {seed.lookupKey} : const {},
      );
      for (var i = 0; i < sentences.length; i++) {
        final ranges = savedCharRanges(
          sentences[i].text,
          tokensBySentence[i],
          index,
        );
        if (ranges.isNotEmpty) return (i, ranges.first.$1, sentences[i].index);
      }
      return null;
    }

    // (seed, 原插入序, 首现位置)，按首现位置升序；未命中的 order 视为最大
    final located =
        seeds
            .asMap()
            .entries
            .map(
              (e) => (seed: e.value, ord: e.key, occ: firstOccurrence(e.value)),
            )
            .toList()
          ..sort((a, b) {
            final oa = a.occ, ob = b.occ;
            if (oa == null || ob == null) {
              if (oa == null && ob == null) return a.ord.compareTo(b.ord);
              return oa == null ? 1 : -1;
            }
            if (oa.$1 != ob.$1) return oa.$1.compareTo(ob.$1);
            if (oa.$2 != ob.$2) return oa.$2.compareTo(ob.$2);
            return a.ord.compareTo(b.ord);
          });

    final numberedTerms = <_NumberedTerm>[];
    final notesBySentence = <int, List<StudyPdfVocabNote>>{};
    for (final item in located) {
      final seed = item.seed;
      final number = numberedTerms.length + 1;
      final placementIndex = item.occ?.$3 ?? seed.sourceIndex;
      (notesBySentence[placementIndex] ??= []).add(
        seed.note.withNumber(number),
      );
      numberedTerms.add(_NumberedTerm(seed.lookupKey, seed.isPhrase, number));
    }

    AppLogger.log(
      'PdfExport',
      '收藏句/词条组装 ${sw.elapsedMilliseconds}ms '
          '(${numberedTerms.length} 词条)',
    );
    sw
      ..reset()
      ..start();

    // 翻译/解析批量读一次（原逐句 getByHash 会产生 O(句数) 串行往返 +
    // 每读一条附带一次 UPDATE 写放大；这里合并为两次批量查询）。
    // 翻译键 = 上下文相关哈希（前句+本句+后句+version，type=translation_v2），与运行时
    // getTranslationStream 缓存契约一致；解析键 = 单句哈希（type=analysis_v2）。
    final translationHashes = [
      for (var i = 0; i < sentences.length; i++)
        translationContextHash(
          sentences[i].text,
          previous: i > 0 ? sentences[i - 1].text : null,
          next: i < sentences.length - 1 ? sentences[i + 1].text : null,
        ),
    ];
    final analysisHashes = [for (final s in sentences) hashText(s.text)];
    final translationRaw = await _aiCacheDao.getManyByHash(
      translationHashes,
      'translation_v2:$targetLanguage',
    );
    final analysisRaw = await _aiCacheDao.getManyByHash(
      analysisHashes,
      'analysis_v2:$targetLanguage',
    );
    final translationJson = <int, String>{};
    final analysisJson = <int, String>{};
    for (var i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      final t = translationRaw[translationHashes[i]];
      if (t != null) translationJson[s.index] = t;
      final a = analysisRaw[analysisHashes[i]];
      if (a != null) analysisJson[s.index] = a;
    }

    AppLogger.log('PdfExport', '翻译/解析批量读 ${sw.elapsedMilliseconds}ms');
    sw
      ..reset()
      ..start();

    // 逐句组装（分词 + 命中区间 + 标号 + 段落分组 + 词数）放 isolate
    final document = await compute(
      _assembleStudyPdfDocument,
      _AssembleRequest(
        sentences: sentences,
        bookmarkedIndices: bookmarkedIndices,
        savedWords: {for (final w in savedWords) w.word},
        savedPhrases: {for (final g in savedGroups) g.phraseText},
        numberedTerms: numberedTerms,
        notesBySentence: notesBySentence,
        translationJson: translationJson,
        analysisJson: analysisJson,
        title: audio.name,
        totalDuration: audio.totalDuration,
        targetLanguage: targetLanguage,
      ),
    );
    AppLogger.log('PdfExport', '逐句组装 ${sw.elapsedMilliseconds}ms');
    AppLogger.log('PdfExport', '数据加载总耗时 ${total.elapsedMilliseconds}ms');
    return document;
  }

  /// 解析存储的句子归属（索引 + 文本双重校验，防字幕重解析后索引错位）
  ///
  /// 1. 索引有效且文本匹配（或无存储文本）→ 用索引；
  /// 2. 否则按文本精确匹配兜底；
  /// 3. 都失败返回 null（调用方丢弃该条目）。
  int? _resolveSentenceIndex({
    required int? storedIndex,
    required String? storedText,
    required List<Sentence> sentences,
    required Map<String, int> textIndex,
  }) {
    final trimmedText = storedText?.trim();
    if (storedIndex != null &&
        storedIndex >= 0 &&
        storedIndex < sentences.length) {
      if (trimmedText == null ||
          trimmedText.isEmpty ||
          sentences[storedIndex].text.trim() == trimmedText) {
        return storedIndex;
      }
    }
    if (trimmedText != null && trimmedText.isNotEmpty) {
      return textIndex[trimmedText];
    }
    return null;
  }

  /// 收集词条候选：句中命中区间（查询键即收藏词/意群本身）
  ///
  /// [term] 用于展示（意群保留原始大小写），[lookupKey] 用于查询
  /// （用户在字幕中收藏的表面词形 / 归一化意群，与缓存键契约一致）。
  _VocabCandidate _makeVocabCandidate({
    required int idx,
    required String term,
    required String lookupKey,
    required bool isPhrase,
    required String sentenceText,
  }) {
    // 词条在句中的命中区间（builder 放正文标号用），与词典结果无关
    final ranges = savedCharRanges(
      sentenceText,
      tokenizeSentence(sentenceText),
      SavedTextIndex.build(
        savedWords: isPhrase ? const {} : {lookupKey},
        savedPhrases: isPhrase ? {lookupKey} : const {},
      ),
    );
    return _VocabCandidate(
      idx: idx,
      term: term,
      lookupKey: lookupKey,
      isPhrase: isPhrase,
      ranges: ranges,
    );
  }

  /// 从批量读到的缓存构建词条笔记（AI 词典优先，在线词典兜底）
  ///
  /// 查询键即收藏词本身：AI 词典有义项则只用 AI（义项为空则不显示该词条），
  /// 否则用按收藏词表面词形精确匹配的在线词典。
  StudyPdfVocabNote? _buildVocabNoteFromCache(
    _VocabCandidate c,
    Map<String, String> aiDictRaw,
    String targetLanguage,
    Map<String, DictEntry> localDict,
  ) {
    // AI 词典缓存：键 = hashText('词|目标语言')，与 ai_dictionary_source 契约一致
    final entry = _decodeAiDict(
      aiDictRaw[hashText('${c.lookupKey}|$targetLanguage')],
    );
    if (entry != null) {
      // 有 AI 查词结果时只用 AI，不再混入在线词典
      final glosses = <StudyPdfGloss>[];
      for (final m in entry.meanings) {
        final text = m.translation
            .where((t) => t.trim().isNotEmpty)
            .map((t) => t.trim())
            .join('；');
        if (text.isEmpty) continue;
        glosses.add(StudyPdfGloss(pos: m.partOfSpeech.trim(), text: text));
      }
      if (glosses.isNotEmpty) {
        final phonetic = entry.pronunciation.us.trim().isNotEmpty
            ? entry.pronunciation.us.trim()
            : entry.pronunciation.uk.trim();
        return StudyPdfVocabNote(
          term: c.term,
          phonetic: phonetic,
          glosses: glosses,
          ranges: c.ranges,
        );
      }
      return null;
    }

    // 在线词典兜底（未就绪/未收录时返回 null → 不显示该词条）
    final local = localDict[c.lookupKey];
    if (local != null) {
      final glosses = (local.translation ?? '')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map(_splitLocalGloss)
          .toList();
      if (glosses.isNotEmpty) {
        return StudyPdfVocabNote(
          term: c.term,
          phonetic: local.phonetic.trim(),
          glosses: glosses,
          ranges: c.ranges,
        );
      }
    }
    return null;
  }

  /// 解码 AI 词典缓存 JSON；未命中 / 损坏 / 无义项返回 null
  DictionaryEntry? _decodeAiDict(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final entry = DictionaryEntry.fromJson(decoded);
        return entry.meanings.isNotEmpty ? entry : null;
      }
    } catch (_) {
      // 损坏数据视作未命中
    }
    return null;
  }

  /// 在线词典行首词性剥离：`n. 生日` → pos `n.` + text `生日`
  ///
  /// 支持连写词性（如 `vt.vi.`）；无法识别时整行作为释义文本。
  StudyPdfGloss _splitLocalGloss(String line) {
    final match = RegExp(r'^((?:[a-z]+\.\s*)+)(.*)$').firstMatch(line);
    final text = match?.group(2)?.trim() ?? '';
    if (match == null || text.isEmpty) {
      return StudyPdfGloss(text: line);
    }
    return StudyPdfGloss(pos: match.group(1)!.trim(), text: text);
  }
}

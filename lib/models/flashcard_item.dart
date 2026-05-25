/// 闪卡项基类
///
/// 统一单词和意群在闪卡复习中的接口。
/// [FlashcardWordItem] 为单词，[FlashcardPhraseItem] 为意群/短语。
library;

import '../database/app_database.dart';
import 'dict_entry.dart';

/// 闪卡项基类
sealed class FlashcardItem {
  /// 正面展示文本
  String get displayText;

  /// 来源音频 ID
  String? get audioItemId;

  /// 来源句子索引
  int? get sentenceIndex;

  /// 来源句子文本
  String? get sentenceText;

  /// 来源句子起始时间（毫秒）
  int? get sentenceStartMs;

  /// 来源句子结束时间（毫秒）
  int? get sentenceEndMs;

  /// 练习次数
  int get practiceCount;

  /// 上次练习时间
  DateTime? get lastPracticedAt;

  /// 收藏时间
  DateTime get createdAt;

  /// 词典条目（仅单词有）
  DictEntry? get dictEntry;

  /// 词典是否已加载
  bool get dictLoaded;

  /// 数据库回写键（单词=word, 意群=phraseText）
  String get dbKey;

  /// 带更新词典的副本
  FlashcardItem withDictEntry(DictEntry? entry);
}

/// 单词闪卡项
class FlashcardWordItem extends FlashcardItem {
  /// 收藏单词数据
  final SavedWord savedWord;

  final DictEntry? _dictEntry;
  final bool _dictLoaded;

  FlashcardWordItem({
    required this.savedWord,
    DictEntry? dictEntry,
    bool dictLoaded = false,
  }) : _dictEntry = dictEntry,
       _dictLoaded = dictLoaded;

  @override
  String get displayText => savedWord.word;

  @override
  String? get audioItemId => savedWord.audioItemId;

  @override
  int? get sentenceIndex => savedWord.sentenceIndex;

  @override
  String? get sentenceText => savedWord.sentenceText;

  @override
  int? get sentenceStartMs => savedWord.sentenceStartMs;

  @override
  int? get sentenceEndMs => savedWord.sentenceEndMs;

  @override
  int get practiceCount => savedWord.practiceCount;

  @override
  DateTime? get lastPracticedAt => savedWord.lastPracticedAt;

  @override
  DateTime get createdAt => savedWord.createdAt;

  @override
  DictEntry? get dictEntry => _dictEntry;

  @override
  bool get dictLoaded => _dictLoaded;

  @override
  String get dbKey => savedWord.word;

  @override
  FlashcardWordItem withDictEntry(DictEntry? entry) => FlashcardWordItem(
    savedWord: savedWord,
    dictEntry: entry,
    dictLoaded: true,
  );
}

/// 意群/短语闪卡项
class FlashcardPhraseItem extends FlashcardItem {
  /// 收藏意群数据
  final SavedSenseGroup savedPhrase;

  final DictEntry? _dictEntry;
  final bool _dictLoaded;

  FlashcardPhraseItem({
    required this.savedPhrase,
    DictEntry? dictEntry,
    bool dictLoaded = false,
  }) : _dictEntry = dictEntry,
       _dictLoaded = dictLoaded;

  @override
  String get displayText => savedPhrase.displayText;

  @override
  String? get audioItemId => savedPhrase.audioItemId;

  @override
  int? get sentenceIndex => savedPhrase.sentenceIndex;

  @override
  String? get sentenceText => savedPhrase.sentenceText;

  @override
  int? get sentenceStartMs => savedPhrase.sentenceStartMs;

  @override
  int? get sentenceEndMs => savedPhrase.sentenceEndMs;

  @override
  int get practiceCount => savedPhrase.practiceCount;

  @override
  DateTime? get lastPracticedAt => savedPhrase.lastPracticedAt;

  @override
  DateTime get createdAt => savedPhrase.createdAt;

  @override
  DictEntry? get dictEntry => _dictEntry;

  @override
  bool get dictLoaded => _dictLoaded;

  @override
  String get dbKey => savedPhrase.phraseText;

  @override
  FlashcardPhraseItem withDictEntry(DictEntry? entry) => FlashcardPhraseItem(
    savedPhrase: savedPhrase,
    dictEntry: entry,
    dictLoaded: true,
  );
}

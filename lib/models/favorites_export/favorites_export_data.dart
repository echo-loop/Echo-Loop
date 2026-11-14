/// 收藏导出的格式无关数据模型
///
/// 由 [FavoritesExportLoader] 只读本地数据组装，再交给具体格式的渲染器。
/// 全部为不可变纯数据，可跨 isolate 传递。
library;

/// 来源材料的媒体类型，用于在来源名称前显示音频 / 视频图标
enum FavoriteSourceMedia { audio, video }

/// 导出文档：收藏句子（按材料分组）+ 收藏词汇（平铺）
class FavoritesExportDocument {
  /// 句子分组，顺序与收藏页一致（按材料名排序）
  final List<FavoriteSentenceGroup> sentenceGroups;

  /// 词汇条目，已按词形字母序排列
  final List<FavoriteVocabularyEntry> vocabulary;

  const FavoritesExportDocument({
    this.sentenceGroups = const [],
    this.vocabulary = const [],
  });

  /// 收藏句子总数（跨所有分组）
  int get sentenceCount =>
      sentenceGroups.fold(0, (sum, group) => sum + group.sentences.length);

  /// 词汇条目总数
  int get vocabularyCount => vocabulary.length;
}

/// 同一来源材料下的收藏句子
class FavoriteSentenceGroup {
  /// 来源材料名；材料已删除或名称缺失时为 null，渲染层显示「未知来源」
  final String? sourceName;

  /// 来源材料的媒体类型；来源未知时为 null（不显示图标）
  final FavoriteSourceMedia? sourceMedia;

  final List<FavoriteSentence> sentences;

  const FavoriteSentenceGroup({
    required this.sourceName,
    this.sourceMedia,
    required this.sentences,
  });
}

/// 收藏句子：原文 + 可选译文（无本地缓存时为 null）
class FavoriteSentence {
  final String text;
  final String? translation;

  const FavoriteSentence({required this.text, this.translation});
}

/// 收藏词汇条目
class FavoriteVocabularyEntry {
  /// 展示词形（意群保留原始大小写）
  final String term;

  /// 是否为意群（多词表达）
  final bool isPhrase;

  /// 音标，无则 null
  final String? phonetic;

  /// 第一个释义（含词性前缀，如 `n. 小猫`），无则 null
  final String? definition;

  /// 第一个释义的第一个例句，无则 null
  final FavoriteExample? example;

  /// 来源句原文（来源句已清除或无记录时为 null）
  final String? sourceSentence;

  /// 来源材料名（材料已删除时为 null）
  final String? sourceName;

  /// 来源材料的媒体类型（来源未知时为 null）
  final FavoriteSourceMedia? sourceMedia;

  const FavoriteVocabularyEntry({
    required this.term,
    required this.isPhrase,
    this.phonetic,
    this.definition,
    this.example,
    this.sourceSentence,
    this.sourceName,
    this.sourceMedia,
  });
}

/// 词汇例句：原文 + 可选译文
class FavoriteExample {
  final String text;
  final String? translation;

  const FavoriteExample({required this.text, this.translation});
}

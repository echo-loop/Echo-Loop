/// 收藏文本匹配索引（正文收藏标记用，纯 Dart 可独立单测）
///
/// 合并「收藏单词表」与「收藏意群表」的 key，**两侧统一经 [normalizeWord]
/// 归一化**后按词数分桶：
/// - 存储侧 key 可能不是 normalizeWord 形式（单词表存在线词典 headword 仅
///   小写化，可含点号/重音，如 `e.g.`；意群表用只剥句末标点的宽松规则，
///   可能残留引号/多空格）——在索引构建时统一归一，读侧修复历史数据；
/// - 匹配侧候选子串同样经 [normalizeWord] 归一（折叠弯撇号/剥边缘标点/
///   折叠空白），两侧同一函数，从根上消除「面板显示已收藏、正文不标记」
///   的归一化不对称。
///
/// 索引仅在收藏集合变化时重建（provider 层 keepAlive），被所有可见句子共享。
library;

import 'text_normalize.dart';

/// 收藏文本匹配索引
class SavedTextIndex {
  /// 单词条目（归一化后不含空格的 key）
  final Set<String> singleWords;

  /// 多词条目（归一化后含空格的 key，来自单词表词组与意群表）
  final Set<String> phrases;

  /// [phrases] 中实际出现的词数集合（滑动窗口只按这些词数扫描）
  final Set<int> phraseWordCounts;

  const SavedTextIndex.empty()
    : singleWords = const {},
      phrases = const {},
      phraseWordCounts = const {};

  const SavedTextIndex._(this.singleWords, this.phrases, this.phraseWordCounts);

  /// 从两张收藏表的原始 key 集合构建索引（key 逐条 [normalizeWord] 归一化）
  factory SavedTextIndex.build({
    required Set<String> savedWords,
    required Set<String> savedPhrases,
  }) {
    final singles = <String>{};
    final phrases = <String>{};
    final counts = <int>{};
    for (final key in savedWords.followedBy(savedPhrases)) {
      final normalized = normalizeWord(key);
      if (normalized.isEmpty) continue;
      final wordCount = ' '.allMatches(normalized).length + 1;
      if (wordCount == 1) {
        singles.add(normalized);
      } else {
        phrases.add(normalized);
        counts.add(wordCount);
      }
    }
    return SavedTextIndex._(singles, phrases, counts);
  }

  /// 是否无任何收藏条目（匹配可整体短路）
  bool get isEmpty => singleWords.isEmpty && phrases.isEmpty;
}

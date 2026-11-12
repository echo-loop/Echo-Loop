/// 手动查词用的本地英文词表索引（纯 Dart，无 Flutter 依赖）
///
/// 数据源为 SCOWL 拼写词表（assets/dictionary/wordlist-en_US.txt）。它只用于
/// 即时搜索建议：词表缺失的专有名词、缩写、短语仍可经词典 API 查询，因此这里
/// 不作为「是否可查」的判断依据。
library;

/// 建议列表的最大条数
const kWordlistSuggestionLimit = 8;

/// 解析词表原文：逐行去空白、转小写、去重排序，丢弃带撇号的所有格形式。
///
/// 所有格（如 `aa's`）占词表约 17%，会挤占有限的 8 条建议名额，且查词时
/// 用户几乎总是输入原形，因此不纳入索引。顶层函数，供 `compute` 在后台
/// isolate 中调用，避免大字符串解析阻塞 UI。
List<String> parseWordlist(String raw) {
  final words = <String>{};
  for (final line in raw.split('\n')) {
    final word = line.trim().toLowerCase();
    if (word.isEmpty || word.contains("'")) continue;
    words.add(word);
  }
  final sorted = words.toList()..sort();
  return sorted;
}

/// 已排序词表的前缀搜索索引。
///
/// 查询复杂度为 O(log n + k)：二分定位首个候选，再顺序取至多 [kWordlistSuggestionLimit] 条。
class WordlistIndex {
  /// 已按 [String.compareTo]（码点序）升序排列的去重小写词
  final List<String> _words;

  /// [sortedWords] 必须已升序且全小写，由 [parseWordlist] 保证。
  WordlistIndex(this._words);

  /// 返回以 [prefix] 开头（大小写不敏感）的前若干个词；空输入返回空列表。
  List<String> suggest(String prefix, {int limit = kWordlistSuggestionLimit}) {
    final needle = prefix.trim().toLowerCase();
    if (needle.isEmpty || limit <= 0) return const [];

    final result = <String>[];
    for (var i = _lowerBound(needle); i < _words.length; i++) {
      final word = _words[i];
      if (!word.startsWith(needle)) break;
      result.add(word);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// 首个大于等于 [target] 的下标（标准下界二分）。
  int _lowerBound(String target) {
    var low = 0;
    var high = _words.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_words[mid].compareTo(target) < 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

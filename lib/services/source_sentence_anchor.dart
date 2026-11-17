/// 来源句定位：收藏句、收藏词汇 / 意群按音频时间锚定到当前字幕的句子。
///
/// 收藏记录来源句的文字与起止时间，不记句子编号：编号会随拆分、合并、插入、
/// 删除句子而变化。需要知道「当前是第几句」时，用区间中点在当前字幕里现算。
/// 字幕替换后由 `TranscriptChangeSync` 按同样规则把收藏改写为当前对应的句子。
library;

import '../models/sentence.dart';

/// 收藏时记录的来源句时间区间。
class SourceSentenceAnchor {
  const SourceSentenceAnchor({required this.start, required this.end});

  /// 收藏句表以秒（浮点）存储时间。
  factory SourceSentenceAnchor.fromSeconds({
    required double startSeconds,
    required double endSeconds,
  }) {
    return SourceSentenceAnchor(
      start: Duration(milliseconds: (startSeconds * 1000).round()),
      end: Duration(milliseconds: (endSeconds * 1000).round()),
    );
  }

  /// 收藏词汇 / 意群表以毫秒存储时间，可能缺失（无来源句）。
  factory SourceSentenceAnchor.fromMilliseconds({
    required int? startMs,
    required int? endMs,
  }) {
    return SourceSentenceAnchor(
      start: startMs == null ? null : Duration(milliseconds: startMs),
      end: endMs == null ? null : Duration(milliseconds: endMs),
    );
  }

  final Duration? start;
  final Duration? end;

  /// 没有时间或起止相同的收藏无法定位。
  bool get hasTimeRange {
    final s = start;
    final e = end;
    return s != null && e != null && e > s;
  }
}

/// 收藏区间在当前字幕中对应第几句；无法定位返回 null。
///
/// 取包含区间中点的句子。字幕时间可能重叠（多句同时包含中点）时取与区间重叠
/// 最长的，一样长取靠前的。中点不落在任何句子里（来源句已删除）或没有有效
/// 时间时返回 null，不做其他匹配。
int? resolveSourceSentenceIndex(
  SourceSentenceAnchor anchor,
  List<Sentence> sentences,
) {
  if (!anchor.hasTimeRange) return null;
  final start = anchor.start!;
  final end = anchor.end!;
  final midpoint = start + (end - start) ~/ 2;
  int? best;
  var bestOverlap = const Duration(microseconds: -1);
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    if (midpoint < sentence.startTime || midpoint >= sentence.endTime) {
      continue;
    }
    final overlap = _overlap(start, end, sentence.startTime, sentence.endTime);
    if (overlap > bestOverlap) {
      best = i;
      bestOverlap = overlap;
    }
  }
  return best;
}

/// 收藏词汇 / 意群的来源句在当前字幕中对应第几句；无法定位返回 null。
///
/// 来源句被拆分时，区间中点可能落在不含该词的另一半，所以先在与收藏区间重叠
/// 的句子里找含 [vocabularyText] 的那句（多句都含取重叠最长的）；都不含（如
/// 收藏的是词元、正文是变形）时退回 [resolveSourceSentenceIndex]。
int? resolveVocabularySourceSentenceIndex(
  SourceSentenceAnchor anchor,
  List<Sentence> sentences,
  String vocabularyText,
) {
  if (!anchor.hasTimeRange) return null;
  final start = anchor.start!;
  final end = anchor.end!;
  int? best;
  var bestOverlap = Duration.zero;
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    final overlap = _overlap(start, end, sentence.startTime, sentence.endTime);
    if (overlap > bestOverlap &&
        _containsVocabulary(sentence.text, vocabularyText)) {
      best = i;
      bestOverlap = overlap;
    }
  }
  return best ?? resolveSourceSentenceIndex(anchor, sentences);
}

/// 句子是否含该词 / 意群：不区分大小写，且匹配位置前不是字母或数字（避免
/// "it" 命中 "exciting"）；不限制词尾，词元也能命中变形（watch → watching）。
bool _containsVocabulary(String sentenceText, String vocabularyText) {
  final needle = vocabularyText.trim().toLowerCase();
  if (needle.isEmpty) return false;
  final pattern = RegExp(
    '(?<![\\p{L}\\p{N}])${RegExp.escape(needle)}',
    unicode: true,
  );
  return pattern.hasMatch(sentenceText.toLowerCase());
}

Duration _overlap(
  Duration aStart,
  Duration aEnd,
  Duration bStart,
  Duration bEnd,
) {
  final overlapStart = aStart > bStart ? aStart : bStart;
  final overlapEnd = aEnd < bEnd ? aEnd : bEnd;
  final overlap = overlapEnd - overlapStart;
  return overlap > Duration.zero ? overlap : Duration.zero;
}

/// 把旧字幕中的句子索引换算到新字幕（用于学习断点）。
///
/// 续学应从旧句内容的开头继续：取第一个「包含旧句中点」或「大半落在旧句内」
/// 的新句（旧句被拆分时落在前半句，被合并时落在合并句；相邻句仅因拖边界
/// 略有重叠不算）。旧句被删（无重叠）时取其后第一句；后面没有句子返回 null。
int? remapSentenceIndex(
  int oldIndex,
  List<Sentence> oldSentences,
  List<Sentence> newSentences,
) {
  if (oldIndex < 0 || oldIndex >= oldSentences.length) return null;
  final old = oldSentences[oldIndex];
  final midpoint = old.startTime + (old.endTime - old.startTime) ~/ 2;
  for (var i = 0; i < newSentences.length; i++) {
    final sentence = newSentences[i];
    final overlap = _overlap(
      old.startTime,
      old.endTime,
      sentence.startTime,
      sentence.endTime,
    );
    if (overlap <= Duration.zero) continue;
    final containsMidpoint =
        midpoint >= sentence.startTime && midpoint < sentence.endTime;
    final mostlyInside = overlap * 2 >= sentence.endTime - sentence.startTime;
    if (containsMidpoint || mostlyInside) return i;
  }
  for (var i = 0; i < newSentences.length; i++) {
    if (newSentences[i].startTime >= midpoint) return i;
  }
  return null;
}

/// 新旧字幕的句子是否一一对应且顺序不变（只调整了时间或文字）。
bool hasSameSentenceStructure(
  List<Sentence> oldSentences,
  List<Sentence> newSentences,
) {
  if (oldSentences.length != newSentences.length) return false;
  for (var i = 0; i < oldSentences.length; i++) {
    if (remapSentenceIndex(i, oldSentences, newSentences) != i) return false;
  }
  return true;
}

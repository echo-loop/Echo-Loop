/// 意群时间戳映射工具
///
/// 将 AI 返回的意群文本与词级时间戳匹配，
/// 计算每个意群的精确播放时间范围。
library;

import '../models/word_timestamp.dart';

/// 意群时间范围
class SenseGroupTiming {
  /// 意群起始时间
  final Duration start;

  /// 意群结束时间
  final Duration end;

  const SenseGroupTiming({required this.start, required this.end});
}

/// 将意群列表与词时间戳对齐，返回每个意群的播放时间范围
///
/// [chunks] AI 拆分的意群文本列表。
/// [words] 全文词级时间戳数组。
/// [sentenceStart] 句子起始时间（fallback 用）。
/// [sentenceEnd] 句子结束时间（fallback 用）。
/// [sentenceStartWordIndex] 本句在全文 words 中的起始索引（含）。
/// [sentenceEndWordIndex] 本句在全文 words 中的结束索引（含）。
List<SenseGroupTiming> mapSenseGroupTimings({
  required List<String> chunks,
  required List<WordTimestamp> words,
  required Duration sentenceStart,
  required Duration sentenceEnd,
  required int sentenceStartWordIndex,
  required int sentenceEndWordIndex,
}) {
  // 取出本句的词子集
  final clampedStart = sentenceStartWordIndex.clamp(0, words.length);
  final clampedEnd = (sentenceEndWordIndex + 1).clamp(0, words.length);
  final sentenceWords = words.sublist(clampedStart, clampedEnd);

  if (sentenceWords.isEmpty || chunks.isEmpty) {
    return _fallbackTimings(chunks, sentenceStart, sentenceEnd);
  }

  final timings = <SenseGroupTiming>[];
  var wordCursor = 0;

  for (final chunk in chunks) {
    final groupTokens = _tokenize(chunk);
    if (groupTokens.isEmpty) {
      // 空意群，使用前一个意群的结束时间作为起始
      final prevEnd = timings.isNotEmpty ? timings.last.end : sentenceStart;
      timings.add(SenseGroupTiming(start: prevEnd, end: prevEnd));
      continue;
    }

    // 尝试从当前 cursor 开始匹配意群的第一个词
    final matchStart = _findMatchStart(
      sentenceWords,
      wordCursor,
      groupTokens.first,
    );

    if (matchStart == null) {
      // 匹配失败，回退到均分
      return _fallbackTimings(chunks, sentenceStart, sentenceEnd);
    }

    // 从 matchStart 开始，匹配整个意群的词数
    final matchEnd = (matchStart + groupTokens.length - 1).clamp(
      0,
      sentenceWords.length - 1,
    );

    timings.add(
      SenseGroupTiming(
        start: sentenceWords[matchStart].startTime,
        end: sentenceWords[matchEnd].endTime,
      ),
    );

    wordCursor = matchEnd + 1;
  }

  return timings;
}

/// 从 words[startFrom..] 查找与 targetToken 匹配的词索引
int? _findMatchStart(
  List<WordTimestamp> words,
  int startFrom,
  String targetToken,
) {
  for (var i = startFrom; i < words.length; i++) {
    if (_normalizeWord(words[i].word) == targetToken) {
      return i;
    }
  }
  return null;
}

/// 将意群文本拆分为归一化 token 列表
List<String> _tokenize(String text) {
  return text
      .split(RegExp(r'\s+'))
      .map(_normalizeWord)
      .where((w) => w.isNotEmpty)
      .toList();
}

/// 归一化单词：小写 + 去除标点
String _normalizeWord(String word) {
  return word
      .toLowerCase()
      .replaceAll(RegExp(r'''[.,!?;:\-—…''"""\[\](){}]'''), '')
      .trim();
}

/// 匹配失败时的 fallback：按词数均分时间
List<SenseGroupTiming> _fallbackTimings(
  List<String> chunks,
  Duration sentenceStart,
  Duration sentenceEnd,
) {
  if (chunks.isEmpty) return [];

  final totalMs = sentenceEnd.inMilliseconds - sentenceStart.inMilliseconds;
  final totalWords = chunks.fold<int>(
    0,
    (sum, chunk) => sum + chunk.split(RegExp(r'\s+')).length,
  );

  if (totalWords == 0) {
    return chunks
        .map((_) => SenseGroupTiming(start: sentenceStart, end: sentenceEnd))
        .toList();
  }

  final timings = <SenseGroupTiming>[];
  var currentMs = sentenceStart.inMilliseconds;

  for (final chunk in chunks) {
    final wordCount = chunk.split(RegExp(r'\s+')).length;
    final durationMs = (totalMs * wordCount / totalWords).round();
    final start = Duration(milliseconds: currentMs);
    final end = Duration(milliseconds: currentMs + durationMs);
    timings.add(SenseGroupTiming(start: start, end: end));
    currentMs += durationMs;
  }

  return timings;
}

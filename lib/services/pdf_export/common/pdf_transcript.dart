/// 字幕句子解析与句子归属解析（学习材料与收藏导出共用）
library;

import '../../../models/sentence.dart';
import '../../subtitle_parser.dart';

/// compute 入口：字幕解析（数百 ms 级 CPU，放 isolate 不占主 isolate）
Future<List<Sentence>> parsePdfTranscript(String srt) =>
    SubtitleParser.parseSubtitleString(srt);

/// 解析存储的句子归属（索引 + 文本双重校验，防字幕重解析后索引错位）
///
/// 1. 索引有效且文本匹配（或无存储文本）→ 用索引；
/// 2. 否则按文本精确匹配兜底（[textIndex] 为 trim 后文本 → 句子索引）；
/// 3. 都失败返回 null（调用方丢弃该条目）。
int? resolvePdfSentenceIndex({
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

// 合集内节目的本地搜索工具。
//
// 纯客户端匹配标题与描述，不访问后端。关键词按不区分大小写的普通子串匹配，
// 正则特殊字符一律按字面量处理。
import '../models/audio_item.dart';

/// 描述中匹配位置超过此字符数时，截掉匹配位置之前的文本，保证关键词在 3 行内可见。
const int _kSnippetLeadingLimit = 40;

/// 截取描述时，关键词前保留的上下文字符数。
const int _kSnippetContextChars = 20;

/// 将关键词转换为匹配模式；去除首尾空格后为空时返回 null（表示不过滤）。
RegExp? buildSearchKeywordPattern(String rawKeyword) {
  final keyword = rawKeyword.trim();
  if (keyword.isEmpty) return null;
  return RegExp(RegExp.escape(keyword), caseSensitive: false);
}

/// 按关键词过滤节目，标题或描述任一命中即保留。保持传入的顺序，由调用方负责排序。
List<AudioItem> filterAudioItemsByKeyword(
  List<AudioItem> items,
  String rawKeyword,
) {
  final pattern = buildSearchKeywordPattern(rawKeyword);
  if (pattern == null) return items;
  return items
      .where(
        (item) =>
            pattern.hasMatch(item.name) ||
            (item.description != null && pattern.hasMatch(item.description!)),
      )
      .toList();
}

/// 为描述生成展示用文本。匹配靠前时返回原文；匹配靠后时从关键词附近开始截取，
/// 并以「…」标记前文被省略，避免长描述里的命中内容被 maxLines 截断掉。
String buildDescriptionSnippet(String description, String rawKeyword) {
  final pattern = buildSearchKeywordPattern(rawKeyword);
  final match = pattern?.firstMatch(description);
  if (match == null || match.start <= _kSnippetLeadingLimit) return description;

  var start = match.start - _kSnippetContextChars;
  // 尽量从单词边界开始，但不能越过关键词本身。
  final spaceIndex = description.indexOf(' ', start);
  if (spaceIndex != -1 && spaceIndex < match.start) start = spaceIndex + 1;
  // 不能切开 UTF-16 代理对（如 emoji），否则会渲染成乱码。
  if (_isLowSurrogate(description.codeUnitAt(start))) start += 1;

  return '…${description.substring(start)}';
}

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

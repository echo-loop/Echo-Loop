// 搜索关键词高亮文本。
//
// 高亮采用行业通用的黄色系底色（浏览器查找、阅读类 App 的惯例），
// 明暗主题分别取柔和的琥珀色，正文颜色不变，保证可读性。关键词为空时等同于普通 Text。
import 'package:flutter/material.dart';

import '../utils/audio_search.dart';

class SearchHighlightText extends StatelessWidget {
  final String text;

  /// 原始搜索输入；首尾空格会被忽略，为空时不做高亮。
  final String searchQuery;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const SearchHighlightText({
    super.key,
    required this.text,
    required this.searchQuery,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final pattern = buildSearchKeywordPattern(searchQuery);
    if (pattern == null) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final highlightStyle = TextStyle(
      backgroundColor: _highlightBackgroundColor(Theme.of(context).brightness),
    );

    // 保留原文的大小写：只切分不改写，高亮段使用原始子串。
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// 命中高亮的底色：浅色主题用柔和琥珀色，深色主题用压暗的琥珀色以免刺眼。
Color _highlightBackgroundColor(Brightness brightness) {
  return brightness == Brightness.dark
      ? const Color(0xFF6B5400)
      : const Color(0xFFFFE08A);
}

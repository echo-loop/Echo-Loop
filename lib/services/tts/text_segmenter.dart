/// 本地 TTS 长文本切分器。
///
/// 参考 TinyTTS 的 TextSegmenter 行为，用 Dart 重写：优先在自然句末切分，
/// 避开常见缩写、小数、URL 和文件名中的点；单句过长时再按逗号/冒号/空白软切。
library;

/// 单段默认最大字符数。Kokoro 对单次文本长度敏感，过长会显著增加首段延迟。
const int kDefaultTtsMaxChars = 240;

/// 句子级文本切分器。
class TextSegmenter {
  const TextSegmenter({this.maxChars = kDefaultTtsMaxChars});

  final int maxChars;

  /// 把 [text] 切为有序段落；空输入返回空列表。
  List<String> split(String text) {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    final rawSegments = _splitNatural(normalized)
        .expand((segment) => _splitOverlong(segment, maxChars))
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return rawSegments;
  }

  List<String> _splitNatural(String text) {
    final result = <String>[];
    var start = 0;
    for (var index = 0; index < text.length; index++) {
      final char = text[index];
      if (char == '\n') {
        _appendNonEmpty(result, text.substring(start, index));
        start = index + 1;
        continue;
      }
      if (!_isSentenceBoundary(text, index)) continue;

      var end = index + 1;
      while (end < text.length && _isSentenceTerminator(text[end])) {
        end++;
      }
      _appendNonEmpty(result, text.substring(start, end));
      start = end;
      index = end - 1;
    }
    if (start < text.length) {
      _appendNonEmpty(result, text.substring(start));
    }
    return result;
  }

  bool _isSentenceBoundary(String text, int index) {
    final char = text[index];
    if (char == '。' || char == '！' || char == '？' || char == '；') {
      return true;
    }
    if (char != '.' && char != '!' && char != '?' && char != ';') {
      return false;
    }
    if (char != '.') return true;
    if (_isDecimalDot(text, index)) return false;
    if (_isUrlOrFileDot(text, index)) return false;
    return !_isAbbreviationDot(text, index);
  }

  bool _isSentenceTerminator(String char) =>
      char == '.' ||
      char == '!' ||
      char == '?' ||
      char == ';' ||
      char == '。' ||
      char == '！' ||
      char == '？' ||
      char == '；';

  bool _isDecimalDot(String text, int index) {
    if (index <= 0 || index + 1 >= text.length) return false;
    final previous = text.codeUnitAt(index - 1);
    final next = text.codeUnitAt(index + 1);
    return _isAsciiDigit(previous) && _isAsciiDigit(next);
  }

  bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  bool _isUrlOrFileDot(String text, int index) {
    var start = index;
    while (start > 0 && !_isWhitespace(text[start - 1])) {
      start--;
    }
    var end = index + 1;
    while (end < text.length && !_isWhitespace(text[end])) {
      end++;
    }
    final token = text.substring(start, end).toLowerCase();
    if (token.contains('://') || token.startsWith('www.')) return true;
    if (token.contains('/') || token.contains('\\')) return true;
    return RegExp(
      r'\.(?:com|org|net|io|cn|dev|app|pdf|txt|md|json|dart|wav|mp3|m4a)$',
    ).hasMatch(token);
  }

  bool _isAbbreviationDot(String text, int index) {
    final prefix = text.substring(0, index);
    return RegExp(
      r'(?:^|[\s(])(?:mr|mrs|ms|dr|prof|sr|jr|st|vs|etc|e\.g|i\.e|u\.s|u\.k|a\.m|p\.m)$',
      caseSensitive: false,
    ).hasMatch(prefix);
  }

  bool _isWhitespace(String char) => RegExp(r'\s').hasMatch(char);

  void _appendNonEmpty(List<String> target, String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) target.add(trimmed);
  }

  List<String> _splitOverlong(String segment, int limit) {
    final normalizedLimit = limit < 80 ? 80 : limit;
    var current = segment.trim();
    final result = <String>[];
    while (current.length > normalizedLimit) {
      final cut = _findSecondaryCut(current, normalizedLimit);
      if (cut <= 0) {
        final hardCut = _findHardCut(current, normalizedLimit);
        result.add(current.substring(0, hardCut).trim());
        current = current.substring(hardCut).trim();
        continue;
      }
      result.add(current.substring(0, cut).trim());
      current = current.substring(cut).trim();
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  int _findSecondaryCut(String text, int limit) {
    const punctuation = {',', '，', ':', '：', '、'};
    for (var index = limit; index >= limit ~/ 2; index--) {
      if (index < text.length && punctuation.contains(text[index - 1])) {
        return index;
      }
    }
    for (var index = limit; index >= limit ~/ 2; index--) {
      if (index < text.length && _isWhitespace(text[index - 1])) return index;
    }
    return -1;
  }

  int _findHardCut(String text, int limit) {
    final codeUnits = text.codeUnits;
    var cut = limit;
    // 不要把 UTF-16 surrogate pair 从中间切开。
    if (cut < codeUnits.length &&
        codeUnits[cut - 1] >= 0xD800 &&
        codeUnits[cut - 1] <= 0xDBFF) {
      cut--;
    }
    return cut > 0 ? cut : 1;
  }
}

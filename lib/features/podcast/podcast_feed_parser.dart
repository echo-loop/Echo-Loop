/// Podcast RSS Feed 解析器
///
/// 解析 RSS/Atom XML，提取 feed 元信息与 episode 列表。
/// 只导入有 guid + enclosure 的 episode，无 guid 的跳过。
library;

import 'package:xml/xml.dart';

import 'podcast_models.dart';

/// 根据 `<podcast:transcript>` 的 MIME type（优先）或 URL 扩展名（兜底），
/// 返回可直接入库的字幕格式 `srt` / `vtt`；不支持的格式返回 null。
///
/// 只支持现有字幕解析器能处理的标准格式，JSON / HTML / 纯文本一律忽略。
String? podcastTranscriptFormatFor(String? mimeType, String url) {
  switch (mimeType?.toLowerCase().split(';').first.trim()) {
    case 'application/srt':
    case 'application/x-subrip':
    case 'text/srt':
      return 'srt';
    case 'text/vtt':
      return 'vtt';
  }
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.srt')) return 'srt';
  if (path.endsWith('.vtt')) return 'vtt';
  return null;
}

class PodcastFeedParser {
  /// 解析 RSS XML 字符串，返回 [PodcastFeedResult]。
  PodcastFeedResult parse(String xmlContent, {required String feedUrl}) {
    final document = XmlDocument.parse(xmlContent);
    final channel = document.findAllElements('channel').firstOrNull;
    if (channel == null) {
      throw const PodcastParseException('无效的 RSS：缺少 channel 元素');
    }

    final meta = _parseMeta(channel, feedUrl: feedUrl);
    final episodes = _parseEpisodes(channel);
    return PodcastFeedResult(meta: meta, episodes: episodes);
  }

  PodcastFeedMeta _parseMeta(XmlElement channel, {required String feedUrl}) {
    final title = _text(channel, 'title') ?? '';
    final author =
        _text(channel, 'itunes:author') ?? _text(channel, 'managingEditor');
    final description = _cleanText(_text(channel, 'description'));
    final websiteUrl = _cleanText(_text(channel, 'link'));
    final categories = _parseCategories(channel);
    final language = _cleanText(_text(channel, 'language'));
    final copyright = _cleanText(_text(channel, 'copyright'));
    final explicit = _cleanText(_text(channel, 'itunes:explicit'));
    // RSS 2.0 image url 在 <image><url>；iTunes 在 <itunes:image href="...">
    final imageUrl =
        channel
            .findElements('image')
            .firstOrNull
            ?.findElements('url')
            .firstOrNull
            ?.innerText
            .trim() ??
        channel
            .findAllElements('itunes:image')
            .firstOrNull
            ?.getAttribute('href');
    return PodcastFeedMeta(
      title: title,
      feedUrl: feedUrl,
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      description: description?.trim().isEmpty == true ? null : description,
      imageUrl: imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      categories: categories,
      language: language?.trim().isEmpty == true ? null : language,
      copyright: copyright?.trim().isEmpty == true ? null : copyright,
      websiteUrl: websiteUrl?.trim().isEmpty == true ? null : websiteUrl,
      explicit: explicit?.trim().isEmpty == true ? null : explicit,
    );
  }

  /// 提取 RSS 与 iTunes 分类。iTunes 支持嵌套分类，这里保留每层 text 并去重。
  List<String> _parseCategories(XmlElement channel) {
    final seen = <String>{};
    final categories = <String>[];

    void add(String? raw) {
      final text = _cleanText(raw)?.trim();
      if (text == null || text.isEmpty) return;
      if (seen.add(text.toLowerCase())) categories.add(text);
    }

    for (final element in channel.findElements('category')) {
      add(element.innerText);
    }
    for (final element in channel.findAllElements('itunes:category')) {
      add(element.getAttribute('text'));
    }
    return categories;
  }

  List<PodcastEpisode> _parseEpisodes(XmlElement channel) {
    final episodes = <PodcastEpisode>[];
    for (final item in channel.findElements('item')) {
      final guid = _text(item, 'guid')?.trim();
      if (guid == null || guid.isEmpty) continue; // 无 guid 跳过

      final enclosure = item.findElements('enclosure').firstOrNull;
      final secureEnclosure = item
          .findElements('ppg:enclosureSecure')
          .firstOrNull;
      final enclosureUrl =
          secureEnclosure?.getAttribute('url') ??
          enclosure?.getAttribute('url') ??
          '';
      final enclosureType =
          secureEnclosure?.getAttribute('type') ??
          enclosure?.getAttribute('type') ??
          'audio/mpeg';
      if (enclosureUrl.isEmpty) continue; // 无音频 URL 跳过

      final title = _text(item, 'title') ?? guid;
      final pubDate = _parseDate(_text(item, 'pubDate'));
      final duration = _parseDuration(_text(item, 'itunes:duration'));
      final transcript = _parseTranscript(item);

      episodes.add(
        PodcastEpisode(
          guid: guid,
          title: title.trim(),
          enclosureUrl: enclosureUrl,
          enclosureType: enclosureType,
          pubDate: pubDate,
          durationSeconds: duration,
          description: _cleanText(
            _text(item, 'description') ?? _text(item, 'itunes:summary'),
          ),
          imageUrl: item
              .findAllElements('itunes:image')
              .firstOrNull
              ?.getAttribute('href')
              ?.trim(),
          link: _cleanText(_text(item, 'link')),
          transcriptUrl: transcript?.url,
          transcriptFormat: transcript?.format,
        ),
      );
    }
    return episodes;
  }

  /// 取 item 下第一个受支持格式的 `<podcast:transcript>`；没有则返回 null。
  _TranscriptRef? _parseTranscript(XmlElement item) {
    for (final tag in item.findElements('podcast:transcript')) {
      final url = tag.getAttribute('url')?.trim();
      if (url == null || url.isEmpty) continue;
      final format = podcastTranscriptFormatFor(tag.getAttribute('type'), url);
      if (format == null) continue;
      return _TranscriptRef(url: url, format: format);
    }
    return null;
  }

  String? _text(XmlElement parent, String tag) {
    return parent.findElements(tag).firstOrNull?.innerText;
  }

  String? _cleanText(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    // RSS 的 description 常混入 HTML 片段或 CDATA。这里在数据入口统一转成
    // 纯文本，但**保留段落换行**：块级标签（p / div / li / br）转成 `\n`，
    // 其余标签删除，行内空白合并，避免发现预览、本地合集详情和单集列表分别
    // 做 UI 层补丁。正文内的裸链接由展示层（_LinkifiedText）识别为可点击。
    final decodedText = _decodeHtmlEntities(text);
    final withBreaks = decodedText
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'<\s*/\s*(p|div|li)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    final unescaped = _decodeHtmlEntities(withBreaks);

    // 逐行清理：合并行内空白并 trim；多个连续空行压成最多一个，去掉首尾空行。
    final rawLines = unescaped
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim());
    final lines = <String>[];
    var lastBlank = false;
    for (final line in rawLines) {
      if (line.isEmpty) {
        if (!lastBlank && lines.isNotEmpty) lines.add('');
        lastBlank = true;
      } else {
        lines.add(line);
        lastBlank = false;
      }
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    final normalized = lines.join('\n');
    return normalized.isEmpty ? null : normalized;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      // RFC 2822 格式（常见于 RSS）：尝试简单解析月份缩写
      return _parseRfc2822(raw);
    }
  }

  static final _months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  DateTime? _parseRfc2822(String raw) {
    // e.g. "Mon, 02 Jan 2006 15:04:05 +0000"
    final parts = raw.trim().split(RegExp(r'[\s,]+'));
    try {
      final day = int.parse(parts[1]);
      final month = _months[parts[2]] ?? 1;
      final year = int.parse(parts[3]);
      return DateTime.utc(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// 解析 itunes:duration：支持 "HH:MM:SS"、"MM:SS"、纯秒数
  int? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    try {
      if (parts.length == 3) {
        return int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            int.parse(parts[2]);
      } else if (parts.length == 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      } else {
        return int.parse(raw);
      }
    } catch (_) {
      return null;
    }
  }
}

class PodcastParseException implements Exception {
  final String message;
  const PodcastParseException(this.message);
  @override
  String toString() => 'PodcastParseException: $message';
}

/// 解析出的字幕引用（URL + 规范化格式）。
class _TranscriptRef {
  final String url;
  final String format;
  const _TranscriptRef({required this.url, required this.format});
}

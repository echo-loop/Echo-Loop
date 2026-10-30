import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/podcast/podcast_feed_parser.dart';

/// 构造只含一个 episode 的 RSS，[transcriptTags] 原样插入 item 中。
String _feedWithTranscripts(String transcriptTags) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:podcast="https://podcastindex.org/namespace/1.0">
  <channel>
    <title>Show</title>
    <item>
      <guid>ep-1</guid>
      <title>Episode 1</title>
      <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
      $transcriptTags
    </item>
  </channel>
</rss>''';

void main() {
  const feedUrl = 'https://example.com/feed.xml';
  final parser = PodcastFeedParser();

  group('podcastTranscriptFormatFor', () {
    test('按 MIME type 识别 srt 与 vtt 的常见写法', () {
      expect(
        podcastTranscriptFormatFor('application/srt', 'https://e.com/a'),
        'srt',
      );
      expect(
        podcastTranscriptFormatFor('application/x-subrip', 'https://e.com/a'),
        'srt',
      );
      expect(podcastTranscriptFormatFor('text/vtt', 'https://e.com/a'), 'vtt');
    });

    test('type 不认识时按 URL 扩展名兜底（忽略大小写与查询串）', () {
      expect(
        podcastTranscriptFormatFor('text/plain', 'https://e.com/a/b.SRT'),
        'srt',
      );
      expect(
        podcastTranscriptFormatFor(null, 'https://e.com/a/b.vtt?x=1'),
        'vtt',
      );
    });

    test('json、html、纯文本等不支持的格式返回 null', () {
      expect(
        podcastTranscriptFormatFor('application/json', 'https://e.com/a.json'),
        isNull,
      );
      expect(
        podcastTranscriptFormatFor('text/html', 'https://e.com/a.html'),
        isNull,
      );
      expect(
        podcastTranscriptFormatFor('text/plain', 'https://e.com/a.txt'),
        isNull,
      );
    });
  });

  group('PodcastFeedParser 字幕解析', () {
    test('单集带 srt 字幕时解析出 url 与 srt 格式', () {
      final result = parser.parse(
        _feedWithTranscripts(
          '<podcast:transcript url="https://e.com/09.srt" '
          'type="application/srt" language="en"/>',
        ),
        feedUrl: feedUrl,
      );

      final episode = result.episodes.single;
      expect(episode.transcriptUrl, 'https://e.com/09.srt');
      expect(episode.transcriptFormat, 'srt');
    });

    test('单集带 vtt 字幕时解析出 vtt 格式', () {
      final result = parser.parse(
        _feedWithTranscripts(
          '<podcast:transcript url="https://e.com/09.vtt" type="text/vtt"/>',
        ),
        feedUrl: feedUrl,
      );

      expect(result.episodes.single.transcriptFormat, 'vtt');
    });

    test('多个字幕时取第一个受支持的格式，跳过 json', () {
      final result = parser.parse(
        _feedWithTranscripts(
          '<podcast:transcript url="https://e.com/a.json" '
          'type="application/json"/>'
          '<podcast:transcript url="https://e.com/a.srt" '
          'type="application/srt"/>',
        ),
        feedUrl: feedUrl,
      );

      expect(result.episodes.single.transcriptUrl, 'https://e.com/a.srt');
    });

    test('只有不支持的字幕格式时 transcriptUrl 为 null', () {
      final result = parser.parse(
        _feedWithTranscripts(
          '<podcast:transcript url="https://e.com/a.json" '
          'type="application/json"/>',
        ),
        feedUrl: feedUrl,
      );

      final episode = result.episodes.single;
      expect(episode.transcriptUrl, isNull);
      expect(episode.transcriptFormat, isNull);
    });

    test('url 为空的字幕标签被跳过', () {
      final result = parser.parse(
        _feedWithTranscripts(
          '<podcast:transcript url="" type="application/srt"/>',
        ),
        feedUrl: feedUrl,
      );

      expect(result.episodes.single.transcriptUrl, isNull);
    });

    test('没有字幕标签时 transcriptUrl 为 null，音频解析不受影响', () {
      final result = parser.parse(_feedWithTranscripts(''), feedUrl: feedUrl);

      final episode = result.episodes.single;
      expect(episode.transcriptUrl, isNull);
      expect(episode.enclosureUrl, 'https://example.com/ep1.mp3');
    });
  });
}

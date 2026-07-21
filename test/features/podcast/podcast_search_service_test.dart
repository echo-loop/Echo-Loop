import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/podcast/podcast_search_service.dart';

void main() {
  group('PodcastSearchService.parseSearchResults', () {
    Map<String, dynamic> resultItem({
      Object? trackId = 123,
      String? feedUrl = 'https://feeds.example.com/rss.xml',
      String? collectionName = 'Example Show',
      String? artistName = 'Example Author',
      String? artworkUrl600 = 'https://img.example.com/600.jpg',
      String? artworkUrl100 = 'https://img.example.com/100.jpg',
      String? collectionViewUrl = 'https://podcasts.apple.com/id123',
    }) {
      return {
        if (trackId != null) 'trackId': trackId,
        if (feedUrl != null) 'feedUrl': feedUrl,
        if (collectionName != null) 'collectionName': collectionName,
        if (artistName != null) 'artistName': artistName,
        if (artworkUrl600 != null) 'artworkUrl600': artworkUrl600,
        if (artworkUrl100 != null) 'artworkUrl100': artworkUrl100,
        if (collectionViewUrl != null) 'collectionViewUrl': collectionViewUrl,
      };
    }

    test('解析 Map 响应，映射全部字段', () {
      final results = PodcastSearchService.parseSearchResults({
        'resultCount': 1,
        'results': [resultItem()],
      });

      expect(results, hasLength(1));
      final r = results.first;
      expect(r.id, '123');
      expect(r.title, 'Example Show');
      expect(r.author, 'Example Author');
      expect(r.feedUrl, 'https://feeds.example.com/rss.xml');
      expect(r.artworkUrl, 'https://img.example.com/600.jpg');
      expect(r.applePodcastUrl, 'https://podcasts.apple.com/id123');
    });

    test('解析原始 String 响应（Dio 未自动解码）', () {
      final json = jsonEncode({
        'results': [resultItem()],
      });
      final results = PodcastSearchService.parseSearchResults(json);
      expect(results, hasLength(1));
      expect(results.first.feedUrl, 'https://feeds.example.com/rss.xml');
    });

    test('跳过缺少 feedUrl 的项', () {
      final results = PodcastSearchService.parseSearchResults({
        'results': [
          resultItem(feedUrl: null),
          resultItem(feedUrl: '   '),
          resultItem(feedUrl: 'https://ok.example.com/rss'),
        ],
      });
      expect(results, hasLength(1));
      expect(results.first.feedUrl, 'https://ok.example.com/rss');
    });

    test('artwork 回退到 artworkUrl100', () {
      final results = PodcastSearchService.parseSearchResults({
        'results': [resultItem(artworkUrl600: null)],
      });
      expect(results.first.artworkUrl, 'https://img.example.com/100.jpg');
    });

    test('artwork 全缺时为 null', () {
      final results = PodcastSearchService.parseSearchResults({
        'results': [resultItem(artworkUrl600: null, artworkUrl100: null)],
      });
      expect(results.first.artworkUrl, isNull);
    });

    test('trackId 缺失时用 feedUrl 兜底作为 id', () {
      final results = PodcastSearchService.parseSearchResults({
        'results': [resultItem(trackId: null)],
      });
      expect(results.first.id, 'https://feeds.example.com/rss.xml');
    });

    test('title 缺失时用 feedUrl 兜底', () {
      final results = PodcastSearchService.parseSearchResults({
        'results': [resultItem(collectionName: null)],
      });
      expect(results.first.title, 'https://feeds.example.com/rss.xml');
    });

    test('results 为空或缺失返回空列表', () {
      expect(
        PodcastSearchService.parseSearchResults({'results': <dynamic>[]}),
        isEmpty,
      );
      expect(
        PodcastSearchService.parseSearchResults({'resultCount': 0}),
        isEmpty,
      );
    });

    test('响应格式无效抛 PodcastSearchException', () {
      expect(
        () => PodcastSearchService.parseSearchResults(42),
        throwsA(isA<PodcastSearchException>()),
      );
    });
  });
}

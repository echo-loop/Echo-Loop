import 'package:dio/dio.dart';
import 'package:echo_loop/features/podcast/podcast_feed_parser.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/features/podcast/podcast_preview_provider.dart';
import 'package:echo_loop/features/podcast/podcast_url_resolver.dart';
import 'package:echo_loop/features/podcast/screens/podcast_preview_screen.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// 计数/可注错的 Dio 替身：feed 内容由 [bodyProvider] 提供。
class _FakeDio extends Fake implements Dio {
  Object? error;
  String Function() bodyProvider;
  int callCount = 0;

  _FakeDio({required String body, this.error}) : bodyProvider = (() => body);
  _FakeDio.withBodyProvider({required this.bodyProvider});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    callCount++;
    final e = error;
    if (e != null) throw e;
    return Response<T>(
      data: bodyProvider() as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

const _rss = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>6 Minute English</title>
    <description>Short lessons</description>
    <item>
      <guid>ep-1</guid>
      <title>Episode One</title>
      <description>Episode summary</description>
      <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
      <pubDate>Mon, 02 Jan 2006 15:04:05 +0000</pubDate>
      <itunes:duration>06:00</itunes:duration>
    </item>
  </channel>
</rss>''';

const _rssWithChallengePhrase = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Bob's Short English Lessons</title>
    <item>
      <guid>ep-just-a-moment</guid>
      <title>Just a moment</title>
      <description><![CDATA[Just a moment is an ordinary English phrase.]]></description>
      <enclosure url="https://example.com/just-a-moment.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

const _feedUrl = 'https://example.com/rss';

PodcastPreviewService _service(_FakeDio dio, {DateTime Function()? now}) {
  return PodcastPreviewService(
    dio: dio,
    resolver: PodcastUrlResolver(dio: dio),
    parser: PodcastFeedParser(),
    now: now,
  );
}

const _previewData = PodcastPreviewData(
  meta: PodcastFeedMeta(
    title: '6 Minute English',
    feedUrl: _feedUrl,
    description: 'Short lessons',
  ),
  episodes: [
    PodcastEpisode(
      guid: 'ep-1',
      title: 'Episode One',
      enclosureUrl: 'https://example.com/ep1.mp3',
      enclosureType: 'audio/mpeg',
      description: 'Episode summary',
      durationSeconds: 360,
    ),
  ],
);

void main() {
  group('PodcastPreviewService.fetchByUrl', () {
    test('直接用 RSS URL 拉取并解析 episode', () async {
      final dio = _FakeDio(body: _rss);
      final data = await _service(dio).fetchByUrl(_feedUrl);

      expect(data.meta.title, '6 Minute English');
      expect(data.episodes, hasLength(1));
      expect(data.episodes.single.title, 'Episode One');
      expect(data.episodes.single.durationSeconds, 360);
    });

    test('RSS 正文含反爬特征短语时仍解析预览', () async {
      final data = await _service(
        _FakeDio(body: _rssWithChallengePhrase),
      ).fetchByUrl(_feedUrl);

      expect(data.meta.title, "Bob's Short English Lessons");
      expect(data.episodes.single.guid, 'ep-just-a-moment');
    });

    test('10 分钟内复用同一 feedUrl 的预览缓存', () async {
      var now = DateTime(2026, 6, 14, 12);
      final dio = _FakeDio(body: _rss);
      final service = _service(dio, now: () => now);

      final first = await service.fetchByUrl(_feedUrl);
      now = now.add(const Duration(minutes: 3));
      final second = await service.fetchByUrl(_feedUrl);

      expect(first.episodes.single.title, 'Episode One');
      expect(second.episodes.single.title, 'Episode One');
      expect(dio.callCount, 1);
    });

    test('force=true 绕过缓存重新拉取', () async {
      var version = 1;
      final dio = _FakeDio.withBodyProvider(
        bodyProvider: () =>
            _rss.replaceFirst('Episode One', 'Episode $version'),
      );
      final service = _service(dio);

      final first = await service.fetchByUrl(_feedUrl);
      version = 2;
      final second = await service.fetchByUrl(_feedUrl, force: true);

      expect(first.episodes.single.title, 'Episode 1');
      expect(second.episodes.single.title, 'Episode 2');
      expect(dio.callCount, 2);
    });

    test('网络错误映射为 preview exception', () async {
      AppLogger.instance.clear();
      final dio = _FakeDio(
        body: '',
        error: DioException(
          requestOptions: RequestOptions(path: _feedUrl),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(
        _service(dio).fetchByUrl(_feedUrl),
        throwsA(
          isA<PodcastPreviewException>().having(
            (e) => e.kind,
            'kind',
            PodcastPreviewErrorKind.network,
          ),
        ),
      );

      expect(
        AppLogger.instance.entries.map((entry) => entry.message),
        contains(allOf(contains('rss request failed'), contains(_feedUrl))),
      );
    });
  });

  group('PodcastPreviewScreen', () {
    testWidgets('失败后重试只发起一次强制请求', (tester) async {
      final dio = _FakeDio(
        body: _rss,
        error: DioException(
          requestOptions: RequestOptions(path: _feedUrl),
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpWidget(
        createTestApp(
          const PodcastPreviewScreen(
            arg: PodcastPreviewArg(
              title: '6 Minute English',
              feedUrl: _feedUrl,
            ),
          ),
          overrides: [
            collectionListProvider.overrideWith(() => TestCollectionList()),
            podcastPreviewDioProvider.overrideWithValue(dio),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(dio.callCount, 1);
      dio.error = null;

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(dio.callCount, 2);
      expect(find.text('Episode One'), findsOneWidget);
    });

    testWidgets('有字幕的单集显示 CC 标记，不显示描述长文', (tester) async {
      const data = PodcastPreviewData(
        meta: PodcastFeedMeta(
          title: '6 Minute English',
          feedUrl: _feedUrl,
          description: 'Short lessons',
        ),
        episodes: [
          PodcastEpisode(
            guid: 'ep-subtitled',
            title: 'Subtitled Episode',
            enclosureUrl: 'https://example.com/sub.mp3',
            enclosureType: 'audio/mpeg',
            description: '附逐句 srt 字幕',
            transcriptUrl: 'https://example.com/sub.srt',
            transcriptFormat: 'srt',
          ),
          PodcastEpisode(
            guid: 'ep-plain',
            title: 'Plain Episode',
            enclosureUrl: 'https://example.com/plain.mp3',
            enclosureType: 'audio/mpeg',
            description: 'Plain summary',
          ),
        ],
      );
      await tester.pumpWidget(
        createTestApp(
          const PodcastPreviewScreen(
            arg: PodcastPreviewArg(
              title: '6 Minute English',
              feedUrl: _feedUrl,
            ),
          ),
          overrides: [
            collectionListProvider.overrideWith(() => TestCollectionList()),
            podcastPreviewProvider(_feedUrl).overrideWith((ref) async => data),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final subtitledRow = find.ancestor(
        of: find.text('Subtitled Episode'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: subtitledRow.first, matching: find.text('CC')),
        findsOneWidget,
      );
      expect(find.text('附逐句 srt 字幕'), findsNothing);

      final plainRow = find.ancestor(
        of: find.text('Plain Episode'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: plainRow.first, matching: find.text('CC')),
        findsNothing,
      );
      expect(find.text('Plain summary'), findsOneWidget);
    });

    testWidgets('点击 episode 打开单集详情弹窗', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PodcastPreviewScreen(
            arg: PodcastPreviewArg(
              title: '6 Minute English',
              feedUrl: _feedUrl,
            ),
          ),
          overrides: [
            collectionListProvider.overrideWith(() => TestCollectionList()),
            podcastPreviewProvider(
              _feedUrl,
            ).overrideWith((ref) async => _previewData),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Episode One'));
      await tester.pumpAndSettle();

      // 打开单集详情 sheet：标题「Episode Info」+ 音频下载链接。
      expect(find.text('Episode Info'), findsOneWidget);
      expect(find.text('Audio URL'), findsOneWidget);
      expect(find.text('https://example.com/ep1.mp3'), findsOneWidget);
    });

    testWidgets('详情用已加载 feed meta（完整简介/作者），不受搜索摘要影响', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PodcastPreviewScreen(
            arg: PodcastPreviewArg(
              title: '6 Minute English',
              description: 'Short search summary',
              feedUrl: _feedUrl,
            ),
          ),
          overrides: [
            collectionListProvider.overrideWith(() => TestCollectionList()),
            podcastPreviewProvider(_feedUrl).overrideWith(
              (ref) async => const PodcastPreviewData(
                meta: PodcastFeedMeta(
                  title: '6 Minute English',
                  feedUrl: _feedUrl,
                  author: 'BBC Radio',
                  description: 'Full feed description.',
                ),
                episodes: [
                  PodcastEpisode(
                    guid: 'ep-1',
                    title: 'Episode One',
                    enclosureUrl: 'https://example.com/ep1.mp3',
                    enclosureType: 'audio/mpeg',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // AppBar 已显示标题，头部封面右侧不再重复展示标题。
      expect(find.text('6 Minute English'), findsOneWidget);
      // feed 加载后内联头图已用完整简介，搜索摘要不再出现。
      expect(find.text('Short search summary'), findsNothing);
      expect(
        find.textContaining('Full feed description. More', findRichText: true),
        findsOneWidget,
      );
      final summaryFinder = find.byKey(
        const ValueKey('podcast-feed-summary-inline-more'),
      );
      final summary = tester.widget<Text>(summaryFinder);
      final summaryContext = tester.element(summaryFinder);
      expect(
        summary.style?.fontSize,
        Theme.of(summaryContext).textTheme.bodyMedium?.fontSize,
      );
      expect(summary.maxLines, 4);

      await tester.tap(summaryFinder);
      await tester.pumpAndSettle();

      // 详情弹窗展示 feed 的作者与完整简介。
      expect(find.text('BBC Radio'), findsOneWidget);
      expect(find.text('Full feed description.'), findsWidgets);
    });

    testWidgets('已订阅时 CTA 显示「去学习」', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PodcastPreviewScreen(
            arg: PodcastPreviewArg(
              title: '6 Minute English',
              feedUrl: _feedUrl,
            ),
          ),
          overrides: [
            collectionListProvider.overrideWith(
              () => TestCollectionList(
                CollectionState(
                  rawCollections: [
                    Collection(
                      id: 'c1',
                      name: '6 Minute English',
                      createdDate: DateTime(2026, 1, 1),
                      source: CollectionSource.podcast,
                      podcastFeedUrl: _feedUrl,
                    ),
                  ],
                ),
              ),
            ),
            podcastPreviewProvider(
              _feedUrl,
            ).overrideWith((ref) async => _previewData),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Practicing'), findsOneWidget);
      expect(find.text('Add to My Collections'), findsNothing);
    });
  });
}

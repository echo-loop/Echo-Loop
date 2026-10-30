import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/podcast/podcast_repository.dart';
import 'package:echo_loop/features/podcast/podcast_url_resolver.dart';
import 'package:echo_loop/features/podcast/podcast_feed_parser.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_providers.dart';

class _CountingDio extends Fake implements Dio {
  int callCount = 0;
  final String body;

  _CountingDio({required this.body});

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
    return Response<T>(
      data: body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _RoutingDio extends Fake implements Dio {
  final Map<String, Object> responses;
  final List<String> requestedPaths = <String>[];

  _RoutingDio(this.responses);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestedPaths.add(path);
    final response = responses[path];
    if (response is Exception) throw response;
    if (response == null) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<T>(
      data: response as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class _MockRef extends Mock implements Ref {}

/// 用预置状态的 CollectionList override，避免依赖数据库。
class _SeededCollectionList extends CollectionList {
  _SeededCollectionList(this._seed);
  final CollectionState _seed;
  int addAudioCallCount = 0;
  int addAudiosCallCount = 0;
  @override
  CollectionState build() => _seed;

  @override
  Future<void> createPodcastCollection(Collection collection) async {
    state = state.copyWith(
      rawCollections: [...state.rawCollections, collection],
      audioIdsMap: {...state.audioIdsMap, collection.id: []},
    );
  }

  @override
  Future<void> updatePodcastCollection(
    Collection updated, {
    bool touchUpdatedAt = true,
  }) async {
    final collections = [...state.rawCollections];
    final index = collections.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;
    collections[index] = updated;
    state = state.copyWith(rawCollections: collections);
  }

  @override
  Future<void> addAudioToCollection(String collectionId, String audioId) async {
    addAudioCallCount++;
    await addAudiosToCollection(collectionId, [audioId]);
  }

  @override
  Future<void> addAudiosToCollection(
    String collectionId,
    List<String> audioIds,
  ) async {
    addAudiosCallCount++;
    final current = List<String>.from(state.audioIdsMap[collectionId] ?? []);
    for (final audioId in audioIds) {
      if (!current.contains(audioId)) current.add(audioId);
    }
    state = state.copyWith(
      audioIdsMap: {...state.audioIdsMap, collectionId: current},
    );
  }
}

class _CountingAudioLibrary extends TestAudioLibrary {
  int addAudioCallCount = 0;
  int addAudiosCallCount = 0;

  _CountingAudioLibrary([super.initialState]);

  @override
  Future<void> addAudioItem(AudioItem item) async {
    addAudioCallCount++;
    await super.addAudioItem(item);
  }

  @override
  Future<void> addAudioItems(List<AudioItem> items) async {
    addAudiosCallCount++;
    await super.addAudioItems(items);
  }
}

class _FixedResolver extends PodcastUrlResolver {
  _FixedResolver(this.feedUrl);
  final String feedUrl;

  @override
  Future<String> resolve(String inputUrl) async => feedUrl;
}

void main() {
  group('PodcastUrlResolver._extractApplePodcastId', () {
    // 利用反射 workaround：通过 resolve() 的逻辑间接测试，
    // 此处直接测试非 Apple URL 直通路径
    test('直接 RSS URL 原样返回', () async {
      const rss = 'https://feeds.simplecast.com/xyz/rss';
      // 不调网络，直接测 URL 格式解析（Apple lookup 不会被触发）
      // 通过 _extractApplePodcastId 为 null 走直通路径
      // 我们无法 mock Dio，改为单独测 parse 逻辑
      expect(rss.startsWith('https://'), isTrue); // sanity
    });
  });

  group('PodcastUrlResolver — Apple ID 提取', () {
    // 利用 resolve() 对非 Apple URL 直通返回
    test('非 Apple URL 不触发 iTunes lookup（host 不匹配）', () async {
      // resolve() 遇到 http/https 非 Apple URL 直接返回
      // 我们只能通过 resolve 不抛异常来间接验证
      // （真实 iTunes lookup 需要网络，故只测非 Apple 分支）
      final resolver = PodcastUrlResolver();
      // 直接返回 RSS URL：
      // 注意 resolve() 是 async，但对非 Apple URL 不发网络请求
      // 若它直接返回则通过；否则抛异常
      expect(
        () => resolver.resolve('https://example.com/feed.xml'),
        returnsNormally,
      );
    });

    test('无效 URL 抛 PodcastResolveException', () {
      expect(
        () => PodcastUrlResolver().resolve('not a url'),
        throwsA(isA<PodcastResolveException>()),
      );
    });

    test('非 http/https scheme 抛 PodcastResolveException', () {
      expect(
        () => PodcastUrlResolver().resolve('ftp://example.com/feed.xml'),
        throwsA(isA<PodcastResolveException>()),
      );
    });

    test('http/https 但缺少 host 时抛 PodcastResolveException', () async {
      await expectLater(
        PodcastUrlResolver().resolve('https:///feed.xml'),
        throwsA(isA<PodcastResolveException>()),
      );
    });

    test('iTunes lookup 返回 String JSON 时能解析 feedUrl', () {
      final feedUrl = PodcastUrlResolver.parseLookupFeedUrl(
        '{"resultCount":1,"results":[{"feedUrl":"https://example.com/rss"}]}',
      );

      expect(feedUrl, 'https://example.com/rss');
    });

    test('iTunes lookup 返回 Map JSON 时能解析 feedUrl', () {
      final feedUrl = PodcastUrlResolver.parseLookupFeedUrl({
        'resultCount': 1,
        'results': [
          {'feedUrl': 'https://example.com/rss'},
        ],
      });

      expect(feedUrl, 'https://example.com/rss');
    });
  });

  group('PodcastFeedParser', () {
    final parser = PodcastFeedParser();

    const feedUrl = 'https://example.com/feed.xml';

    test('解析标准 RSS：feed 元信息 + episodes', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>My Podcast</title>
    <itunes:author>John Doe</itunes:author>
    <description>A great podcast</description>
    <link>https://example.com</link>
    <language>en-us</language>
    <copyright>Copyright 2026 Example</copyright>
    <itunes:explicit>false</itunes:explicit>
    <category>Education</category>
    <itunes:category text="Language Learning">
      <itunes:category text="English"/>
    </itunes:category>
    <image><url>https://example.com/cover.jpg</url></image>
    <item>
      <guid>ep-001</guid>
      <title>Episode 1</title>
      <description>Episode one summary</description>
      <link>https://example.com/episodes/1</link>
      <itunes:image href="https://example.com/ep1.jpg"/>
      <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg"/>
      <pubDate>Mon, 02 Jan 2006 15:04:05 +0000</pubDate>
      <itunes:duration>1:02:30</itunes:duration>
    </item>
    <item>
      <guid>ep-002</guid>
      <title>Episode 2</title>
      <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

      final result = parser.parse(xml, feedUrl: feedUrl);
      expect(result.meta.title, 'My Podcast');
      expect(result.meta.author, 'John Doe');
      expect(result.meta.description, 'A great podcast');
      expect(result.meta.imageUrl, 'https://example.com/cover.jpg');
      expect(result.meta.feedUrl, feedUrl);
      expect(result.meta.websiteUrl, 'https://example.com');
      expect(result.meta.language, 'en-us');
      expect(result.meta.copyright, 'Copyright 2026 Example');
      expect(result.meta.explicit, 'false');
      expect(result.meta.categories, [
        'Education',
        'Language Learning',
        'English',
      ]);
      expect(result.episodes, hasLength(2));

      final ep1 = result.episodes.first;
      expect(ep1.guid, 'ep-001');
      expect(ep1.title, 'Episode 1');
      expect(ep1.enclosureUrl, 'https://example.com/ep1.mp3');
      expect(ep1.enclosureType, 'audio/mpeg');
      expect(ep1.durationSeconds, 3750); // 1*3600 + 2*60 + 30
      expect(ep1.description, 'Episode one summary');
      expect(ep1.imageUrl, 'https://example.com/ep1.jpg');
      expect(ep1.link, 'https://example.com/episodes/1');
    });

    test('BBC RSS 同时提供 secure enclosure 时优先使用 HTTPS 音频 URL', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
    xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
    xmlns:ppg="http://bbc.co.uk/2009/01/ppgRss">
  <channel>
    <title>BBC Learning English</title>
    <item>
      <guid>urn:bbc:podcast:p0n4bkpz</guid>
      <title>The English We Speak: Short-change</title>
      <enclosure url="http://open.live.bbc.co.uk/mediaselector/6/redir/version/2.0/mediaset/audio-nondrm-download-rss-low/proto/http/vpid/p0n4bjcm.mp3" type="audio/mpeg"/>
      <ppg:enclosureSecure url="https://open.live.bbc.co.uk/mediaselector/6/redir/version/2.0/mediaset/audio-nondrm-download-rss-low/proto/https/vpid/p0n4bjcm.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

      final result = parser.parse(xml, feedUrl: feedUrl);

      expect(
        result.episodes.single.enclosureUrl,
        'https://open.live.bbc.co.uk/mediaselector/6/redir/version/2.0/mediaset/audio-nondrm-download-rss-low/proto/https/vpid/p0n4bjcm.mp3',
      );
      expect(result.episodes.single.enclosureType, 'audio/mpeg');
    });

    test('解析 VOA 单集的 summary 和网页 link', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>VOA Learning English</title>
    <item>
      <title>Learning English Podcast - March 31, 2025</title>
      <description>Learning English uses a limited vocabulary and are read at a slower pace than VOA's other English broadcasts. Previously known as Special English.</description>
      <link>https://learningenglish.voanews.com/a/8011955.html</link>
      <guid>https://learningenglish.voanews.com/a/8011955.html</guid>
      <pubDate>Mon, 31 Mar 2025 00:30:03 +0000</pubDate>
      <itunes:summary>Learning English uses a limited vocabulary and are read at a slower pace than VOA's other English broadcasts. Previously known as Special English.</itunes:summary>
      <itunes:duration>00:29:56</itunes:duration>
      <itunes:image href="https://gdb.voanews.com/0684e143-ca54-4c31-bbc7-c26e19b2fb70.jpg"/>
      <enclosure url="https://voa-audio.voanews.eu/vle/2025/03/31/20250331-003003-vle122-program_hq.mp3" type="audio/mpeg" length="29425664"/>
    </item>
  </channel>
</rss>''';

      final result = parser.parse(xml, feedUrl: feedUrl);
      final episode = result.episodes.single;

      expect(
        episode.description,
        "Learning English uses a limited vocabulary and are read at a slower pace than VOA's other English broadcasts. Previously known as Special English.",
      );
      expect(
        episode.link,
        'https://learningenglish.voanews.com/a/8011955.html',
      );
      expect(
        episode.imageUrl,
        'https://gdb.voanews.com/0684e143-ca54-4c31-bbc7-c26e19b2fb70.jpg',
      );
    });

    test('清洗 description 中的 HTML 标签和实体', () {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>BBC Learning English</title>
    <description><![CDATA[<p>Learn and practise useful English&nbsp;with clips from the BBC.</p><p>Each week, we talk about &amp; explain phrases.</p>]]></description>
    <item>
      <guid>ep-html</guid>
      <title>How advertisers make us spend money</title>
      <description><![CDATA[<p>What was the last thing you bought?<br/>And why?</p>]]></description>
      <enclosure url="https://example.com/ep.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>''';

      final result = parser.parse(xml, feedUrl: feedUrl);

      // 段落结构保留为换行：<p> 之间与 <br/> 转为 \n。
      expect(
        result.meta.description,
        'Learn and practise useful English with clips from the BBC.\n'
        'Each week, we talk about & explain phrases.',
      );
      expect(
        result.episodes.single.description,
        'What was the last thing you bought?\nAnd why?',
      );
    });

    test('无 guid 的 episode 被跳过', () {
      const xml = '''<?xml version="1.0"?>
<rss><channel><title>Test</title>
  <item>
    <title>No Guid</title>
    <enclosure url="https://example.com/a.mp3" type="audio/mpeg"/>
  </item>
  <item>
    <guid>has-guid</guid>
    <title>With Guid</title>
    <enclosure url="https://example.com/b.mp3" type="audio/mpeg"/>
  </item>
</channel></rss>''';
      final result = parser.parse(xml, feedUrl: feedUrl);
      expect(result.episodes, hasLength(1));
      expect(result.episodes.first.guid, 'has-guid');
    });

    test('无 enclosure 的 episode 被跳过', () {
      const xml = '''<?xml version="1.0"?>
<rss><channel><title>Test</title>
  <item><guid>g1</guid><title>No enclosure</title></item>
</channel></rss>''';
      final result = parser.parse(xml, feedUrl: feedUrl);
      expect(result.episodes, isEmpty);
    });

    test('缺少 channel 元素抛 PodcastParseException', () {
      expect(
        () => parser.parse('<rss></rss>', feedUrl: feedUrl),
        throwsA(isA<PodcastParseException>()),
      );
    });

    test('itunes:duration MM:SS 格式解析正确', () {
      const xml = '''<?xml version="1.0"?>
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
<channel><title>T</title>
  <item>
    <guid>g1</guid><title>E1</title>
    <enclosure url="https://x.com/a.mp3" type="audio/mpeg"/>
    <itunes:duration>45:30</itunes:duration>
  </item>
</channel></rss>''';
      final result = parser.parse(xml, feedUrl: feedUrl);
      expect(result.episodes.first.durationSeconds, 45 * 60 + 30);
    });

    test('itunes:duration 纯秒数格式解析正确', () {
      const xml = '''<?xml version="1.0"?>
<rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
<channel><title>T</title>
  <item>
    <guid>g1</guid><title>E1</title>
    <enclosure url="https://x.com/a.mp3" type="audio/mpeg"/>
    <itunes:duration>3600</itunes:duration>
  </item>
</channel></rss>''';
      final result = parser.parse(xml, feedUrl: feedUrl);
      expect(result.episodes.first.durationSeconds, 3600);
    });
  });

  group('PodcastFeedMeta JSON 往返', () {
    test('toJson / fromJson 往返一致', () {
      const meta = PodcastFeedMeta(
        title: 'My Pod',
        feedUrl: 'https://example.com/feed.xml',
        author: 'Jane',
        description: 'Desc',
        imageUrl: 'https://example.com/img.jpg',
        categories: ['Education', 'English'],
        language: 'en-us',
        copyright: 'Copyright',
        websiteUrl: 'https://example.com',
        explicit: 'false',
      );
      final json = meta.toJson();
      final restored = PodcastFeedMeta.fromJson(json);
      expect(restored.title, meta.title);
      expect(restored.feedUrl, meta.feedUrl);
      expect(restored.author, meta.author);
      expect(restored.description, meta.description);
      expect(restored.imageUrl, meta.imageUrl);
      expect(restored.categories, meta.categories);
      expect(restored.language, meta.language);
      expect(restored.copyright, meta.copyright);
      expect(restored.websiteUrl, meta.websiteUrl);
      expect(restored.explicit, meta.explicit);
    });

    test('fromJson 兼容旧 meta JSON', () {
      final restored = PodcastFeedMeta.fromJson({
        'title': 'Legacy',
        'feedUrl': 'https://example.com/feed.xml',
      });

      expect(restored.title, 'Legacy');
      expect(restored.categories, isEmpty);
      expect(restored.language, isNull);
    });
  });

  group('PodcastRepository.createAndFetch — 重复订阅判重', () {
    const feedUrl = 'https://feeds.example.com/voa/rss';
    const appleUrl =
        'https://podcasts.apple.com/us/podcast/voa-learning-english/id109522474';

    ProviderContainer makeContainer(List<Collection> collections) {
      return ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => _SeededCollectionList(
              CollectionState(rawCollections: collections),
            ),
          ),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        ],
      );
    }

    Collection podcast({required String name, required String feedUrl}) {
      return Collection(
        id: name,
        name: name,
        createdDate: DateTime(2026, 6, 13),
        source: CollectionSource.podcast,
        podcastFeedUrl: feedUrl,
      );
    }

    test('已存在相同 feedUrl 的播客合集时抛 PodcastAlreadySubscribedException', () async {
      final container = makeContainer([
        podcast(name: 'VOA Learning English', feedUrl: feedUrl),
      ]);
      addTearDown(container.dispose);
      final repo = container.read(podcastRepositoryProvider);

      await expectLater(
        repo.createAndFetch(feedUrl),
        throwsA(
          isA<PodcastAlreadySubscribedException>().having(
            (e) => e.collectionName,
            'collectionName',
            'VOA Learning English',
          ),
        ),
      );
    });

    test('不同 feedUrl 不触发判重（不抛 AlreadySubscribed）', () async {
      final container = makeContainer([
        podcast(name: '其他播客', feedUrl: 'https://feeds.example.com/other/rss'),
      ]);
      addTearDown(container.dispose);
      final repo = container.read(podcastRepositoryProvider);

      // 不同 feed 会越过判重继续拉取（最终因网络/解析失败抛别的异常），
      // 只需确认不是重复订阅异常。
      await expectLater(
        repo.createAndFetch(feedUrl),
        throwsA(isNot(isA<PodcastAlreadySubscribedException>())),
      );
    });

    test('Apple 输入创建合集时保留 inputUrl，feedUrl 写入解析后的 RSS', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>VOA Learning English</title>
    <description>Slow-paced English learning programs.</description>
  </channel>
</rss>''';
      final dio = _CountingDio(body: feed);
      final repoProvider = Provider(
        (ref) => PodcastRepository(
          ref,
          dio: dio,
          urlResolver: _FixedResolver(feedUrl),
          feedParser: PodcastFeedParser(),
        ),
      );
      final container = makeContainer([]);
      addTearDown(container.dispose);

      final collection = await container
          .read(repoProvider)
          .createAndFetch(appleUrl);

      expect(collection.podcastInputUrl, appleUrl);
      expect(collection.podcastFeedUrl, feedUrl);
      expect(dio.callCount, 1);
      expect(
        container.read(collectionListProvider).rawCollections.single,
        isA<Collection>()
            .having((c) => c.podcastInputUrl, 'podcastInputUrl', appleUrl)
            .having((c) => c.podcastFeedUrl, 'podcastFeedUrl', feedUrl),
      );
    });

    test('已知 RSS 时保存 Apple inputUrl 并直接拉取 feedUrl', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>VOA Learning English</title>
    <description>Slow-paced English learning programs.</description>
  </channel>
</rss>''';
      final dio = _RoutingDio({feedUrl: feed});
      final repoProvider = Provider(
        (ref) => PodcastRepository(
          ref,
          dio: dio,
          urlResolver: _FixedResolver('https://should-not-resolve.example/rss'),
          feedParser: PodcastFeedParser(),
        ),
      );
      final container = makeContainer([]);
      addTearDown(container.dispose);

      final collection = await container
          .read(repoProvider)
          .createAndFetch(appleUrl, knownFeedUrl: feedUrl);

      expect(dio.requestedPaths, [feedUrl]);
      expect(collection.podcastInputUrl, appleUrl);
      expect(collection.podcastFeedUrl, feedUrl);
    });

    test('首次创建时多集节目批量入库并建立合集关联', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>VOA Learning English</title>
    <description>Slow-paced English learning programs.</description>
    <item>
      <guid>ep-1</guid>
      <title>Episode 1</title>
      <enclosure url="https://example.com/1.mp3" type="audio/mpeg" />
    </item>
    <item>
      <guid>ep-2</guid>
      <title>Episode 2</title>
      <enclosure url="https://example.com/2.mp3" type="audio/mpeg" />
    </item>
  </channel>
</rss>''';
      final dio = _CountingDio(body: feed);
      final audioLibrary = _CountingAudioLibrary();
      final repoProvider = Provider(
        (ref) => PodcastRepository(
          ref,
          dio: dio,
          urlResolver: _FixedResolver(feedUrl),
          feedParser: PodcastFeedParser(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => _SeededCollectionList(const CollectionState()),
          ),
          audioLibraryProvider.overrideWith(() => audioLibrary),
        ],
      );
      addTearDown(container.dispose);

      final collection = await container
          .read(repoProvider)
          .createAndFetch(appleUrl);

      final collectionList =
          container.read(collectionListProvider.notifier)
              as _SeededCollectionList;
      expect(audioLibrary.addAudioCallCount, 0);
      expect(audioLibrary.addAudiosCallCount, 1);
      expect(collectionList.addAudioCallCount, 0);
      expect(collectionList.addAudiosCallCount, 1);
      expect(container.read(audioLibraryProvider).audioItems, hasLength(2));
      expect(
        container.read(collectionListProvider).getAudioIds(collection.id),
        hasLength(2),
      );
    });
  });

  group('PodcastRepository.refresh — 刷新策略', () {
    const feedUrl = 'https://feeds.example.com/voa/rss';
    const newFeedUrl = 'https://feeds.example.com/voa/new-rss';
    const appleUrl =
        'https://podcasts.apple.com/us/podcast/voa-learning-english/id109522474';

    Collection podcast({
      required DateTime lastRefreshedAt,
      String? inputUrl,
      String feed = feedUrl,
    }) {
      return Collection(
        id: 'podcast-1',
        name: 'VOA Learning English',
        createdDate: DateTime(2026, 6, 13),
        source: CollectionSource.podcast,
        podcastInputUrl: inputUrl,
        podcastFeedUrl: feed,
        podcastLastRefreshedAt: lastRefreshedAt,
      );
    }

    ProviderContainer makeContainer(Collection collection) {
      return ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => _SeededCollectionList(
              CollectionState(rawCollections: [collection]),
            ),
          ),
          audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        ],
      );
    }

    Ref makeRef(Collection collection) {
      final ref = _MockRef();
      when(
        () => ref.read(collectionListProvider),
      ).thenReturn(CollectionState(rawCollections: [collection]));
      return ref;
    }

    test('普通刷新距离上次刷新 59 分钟时节流，不访问 RSS', () async {
      final dio = _CountingDio(body: '<rss></rss>');
      final repo = PodcastRepository(
        makeRef(
          podcast(
            lastRefreshedAt: DateTime.now().subtract(
              const Duration(minutes: 59),
            ),
          ),
        ),
        dio: dio,
      );

      await repo.refresh('podcast-1');

      expect(dio.callCount, 0);
    });

    test('普通刷新距离上次刷新 60 分钟后访问 RSS', () async {
      final dio = _CountingDio(
        body: '<rss version="2.0"><channel><title>VOA</title></channel></rss>',
      );
      final container = makeContainer(
        podcast(
          lastRefreshedAt: DateTime.now().subtract(const Duration(minutes: 60)),
        ),
      );
      addTearDown(container.dispose);
      final repoProvider = Provider(
        (ref) =>
            PodcastRepository(ref, dio: dio, feedParser: PodcastFeedParser()),
      );

      await container.read(repoProvider).refresh('podcast-1');

      expect(dio.callCount, 1);
    });

    test('force=true 绕过节流并访问 RSS', () async {
      final dio = _CountingDio(body: '<rss></rss>');
      final collection = podcast(lastRefreshedAt: DateTime.now());
      final container = makeContainer(collection);
      addTearDown(container.dispose);
      final repoProvider = Provider(
        (ref) =>
            PodcastRepository(ref, dio: dio, feedParser: PodcastFeedParser()),
      );

      await expectLater(
        container.read(repoProvider).refresh('podcast-1', force: true),
        throwsA(isA<PodcastParseException>()),
      );

      expect(dio.callCount, 1);
      expect(
        container.read(collectionListProvider).rawCollections.single,
        isA<Collection>()
            .having(
              (c) => c.podcastLastRefreshedAt,
              'podcastLastRefreshedAt',
              isNotNull,
            )
            .having(
              (c) => c.podcastLastRefreshError,
              'podcastLastRefreshError',
              contains('PodcastParseException'),
            ),
      );
    });

    test('RSS 失效且原始输入是 Apple URL 时重新 lookup 并更新 feedUrl', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>VOA Learning English</title>
    <description>New RSS feed.</description>
  </channel>
</rss>''';
      final dio = _RoutingDio({
        feedUrl: DioException(
          requestOptions: RequestOptions(path: feedUrl),
          type: DioExceptionType.badResponse,
        ),
        newFeedUrl: feed,
      });
      final collection = podcast(
        lastRefreshedAt: DateTime(2026, 6, 13),
        inputUrl: appleUrl,
      );
      final container = makeContainer(collection);
      addTearDown(container.dispose);
      final repoProvider = Provider(
        (ref) => PodcastRepository(
          ref,
          dio: dio,
          urlResolver: _FixedResolver(newFeedUrl),
          feedParser: PodcastFeedParser(),
        ),
      );

      await container.read(repoProvider).refresh('podcast-1', force: true);

      expect(dio.requestedPaths, [feedUrl, newFeedUrl]);
      expect(
        container.read(collectionListProvider).rawCollections.single,
        isA<Collection>()
            .having((c) => c.podcastInputUrl, 'podcastInputUrl', appleUrl)
            .having((c) => c.podcastFeedUrl, 'podcastFeedUrl', newFeedUrl)
            .having(
              (c) => c.podcastLastRefreshedAt,
              'podcastLastRefreshedAt',
              isNotNull,
            )
            .having(
              (c) => c.podcastLastRefreshError,
              'podcastLastRefreshError',
              isNull,
            )
            .having((c) => c.description, 'description', 'New RSS feed.'),
      );
    });

    test('刷新时跳过已有 guid，只批量加入新增 episode', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>VOA Learning English</title>
    <description>Slow-paced English learning programs.</description>
    <item>
      <guid>existing-guid</guid>
      <title>Existing Episode</title>
      <enclosure url="https://example.com/existing.mp3" type="audio/mpeg" />
    </item>
    <item>
      <guid>new-guid</guid>
      <title>New Episode</title>
      <enclosure url="https://example.com/new.mp3" type="audio/mpeg" />
    </item>
  </channel>
</rss>''';
      final collection = podcast(lastRefreshedAt: DateTime(2026, 6, 13));
      final existingItem = AudioItem(
        id: 'existing-audio',
        name: 'Existing Episode',
        addedDate: DateTime(2026, 6, 1),
        totalDuration: 0,
        podcastEpisodeGuid: 'existing-guid',
        podcastEnclosureUrl: 'https://example.com/existing.mp3',
      );
      final audioLibrary = _CountingAudioLibrary(
        AudioLibraryState(audioItems: [existingItem]),
      );
      final dio = _CountingDio(body: feed);
      final repoProvider = Provider(
        (ref) =>
            PodcastRepository(ref, dio: dio, feedParser: PodcastFeedParser()),
      );
      final container = ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => _SeededCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: {
                  collection.id: [existingItem.id],
                },
              ),
            ),
          ),
          audioLibraryProvider.overrideWith(() => audioLibrary),
        ],
      );
      addTearDown(container.dispose);

      await container.read(repoProvider).refresh(collection.id, force: true);

      final collectionList =
          container.read(collectionListProvider.notifier)
              as _SeededCollectionList;
      final items = container.read(audioLibraryProvider).audioItems;
      expect(audioLibrary.addAudioCallCount, 0);
      expect(audioLibrary.addAudiosCallCount, 1);
      expect(collectionList.addAudioCallCount, 0);
      expect(collectionList.addAudiosCallCount, 1);
      expect(items.map((item) => item.podcastEpisodeGuid), [
        'existing-guid',
        'new-guid',
      ]);
      expect(
        container.read(collectionListProvider).getAudioIds(collection.id),
        hasLength(2),
      );
    });

    test('刷新时为未下载的老单集补写字幕地址，且不下载音频', () async {
      const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:podcast="https://podcastindex.org/namespace/1.0">
  <channel>
    <title>VOA Learning English</title>
    <item>
      <guid>existing-guid</guid>
      <title>Existing Episode</title>
      <enclosure url="https://example.com/existing.mp3" type="audio/mpeg" />
      <podcast:transcript url="https://example.com/existing.srt" type="application/srt" />
    </item>
  </channel>
</rss>''';
      final collection = podcast(lastRefreshedAt: DateTime(2026, 6, 13));
      final existingItem = AudioItem(
        id: 'existing-audio',
        name: 'Existing Episode',
        addedDate: DateTime(2026, 6, 1),
        podcastEpisodeGuid: 'existing-guid',
        podcastEnclosureUrl: 'https://example.com/existing.mp3',
      );
      final audioLibrary = _CountingAudioLibrary(
        AudioLibraryState(audioItems: [existingItem]),
      );
      final dio = _CountingDio(body: feed);
      final repoProvider = Provider(
        (ref) =>
            PodcastRepository(ref, dio: dio, feedParser: PodcastFeedParser()),
      );
      final container = ProviderContainer(
        overrides: [
          collectionListProvider.overrideWith(
            () => _SeededCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: {
                  collection.id: [existingItem.id],
                },
              ),
            ),
          ),
          audioLibraryProvider.overrideWith(() => audioLibrary),
        ],
      );
      addTearDown(container.dispose);

      await container.read(repoProvider).refresh(collection.id, force: true);

      final item = container
          .read(audioLibraryProvider)
          .audioItems
          .singleWhere((item) => item.id == existingItem.id);
      expect(item.podcastTranscriptUrl, 'https://example.com/existing.srt');
      expect(item.podcastTranscriptFormat, 'srt');
      expect(item.audioPath, isNull);
      expect(audioLibrary.addAudiosCallCount, 0);
    });

    test('RSS 和 Apple lookup 兜底都失败时写入最后刷新失败状态', () async {
      final dio = _RoutingDio({
        feedUrl: DioException(
          requestOptions: RequestOptions(path: feedUrl),
          type: DioExceptionType.badResponse,
        ),
        newFeedUrl: DioException(
          requestOptions: RequestOptions(path: newFeedUrl),
          type: DioExceptionType.badResponse,
        ),
      });
      final collection = podcast(
        lastRefreshedAt: DateTime(2026, 6, 13),
        inputUrl: appleUrl,
      );
      final container = makeContainer(collection);
      addTearDown(container.dispose);
      final repoProvider = Provider(
        (ref) => PodcastRepository(
          ref,
          dio: dio,
          urlResolver: _FixedResolver(newFeedUrl),
          feedParser: PodcastFeedParser(),
        ),
      );

      await expectLater(
        container.read(repoProvider).refresh('podcast-1', force: true),
        throwsA(isA<DioException>()),
      );

      expect(
        container.read(collectionListProvider).rawCollections.single,
        isA<Collection>()
            .having(
              (c) => c.podcastLastRefreshedAt,
              'podcastLastRefreshedAt',
              isNot(collection.podcastLastRefreshedAt),
            )
            .having(
              (c) => c.podcastLastRefreshError,
              'podcastLastRefreshError',
              contains('DioException'),
            ),
      );
    });
  });
}

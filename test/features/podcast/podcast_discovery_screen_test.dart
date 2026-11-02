import 'dart:async';

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/podcast/data/featured_podcast_service.dart';
import 'package:echo_loop/features/podcast/models/featured_podcast.dart';
import 'package:echo_loop/features/podcast/podcast_preview_provider.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/features/podcast/providers/featured_podcasts_provider.dart';
import 'package:echo_loop/features/podcast/podcast_repository.dart';
import 'package:echo_loop/features/podcast/podcast_search_provider.dart';
import 'package:echo_loop/features/podcast/podcast_search_service.dart';
import 'package:echo_loop/features/podcast/screens/podcast_discovery_screen.dart';
import 'package:echo_loop/features/podcast/widgets/podcast_subscribe_tile.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

class _FakeSearchService extends PodcastSearchService {
  _FakeSearchService(this.results);

  final List<PodcastSearchResult> results;
  String? lastTerm;

  @override
  Future<List<PodcastSearchResult>> search(
    String term, {
    int limit = 25,
  }) async {
    lastTerm = term;
    return results;
  }
}

class _FakePodcastRepository extends Fake implements PodcastRepository {
  final List<String> subscribed = [];
  final List<String?> knownFeedUrls = [];

  @override
  Future<Collection> createAndFetch(
    String inputUrl, {
    String? knownFeedUrl,
  }) async {
    subscribed.add(inputUrl);
    knownFeedUrls.add(knownFeedUrl);
    return Collection(
      id: 'subscribed',
      name: 'Subscribed',
      createdDate: DateTime(2026, 1, 1),
      source: CollectionSource.podcast,
      podcastInputUrl: inputUrl,
      podcastFeedUrl: knownFeedUrl ?? inputUrl,
    );
  }
}

class _FakeFeaturedPodcastService extends Fake
    implements FeaturedPodcastService {
  _FakeFeaturedPodcastService({
    FeaturedPodcastSnapshot? snapshot,
    List<FeaturedPodcastRefreshOutcome>? firstPageOutcomes,
  }) : _snapshot = snapshot,
       _firstPageOutcomes = firstPageOutcomes ?? [];

  FeaturedPodcastSnapshot? _snapshot;
  final List<FeaturedPodcastRefreshOutcome> _firstPageOutcomes;
  int firstPageRefreshCalls = 0;
  final List<String?> requestedCursors = [];
  final List<String> refreshOrder = [];
  Completer<void>? nextPageRefreshStarted;
  Completer<FeaturedPodcastRefreshOutcome>? nextPageOutcome;

  @override
  FeaturedPodcastSnapshot? get cachedSnapshot => _snapshot;

  @override
  Future<FeaturedPodcastSnapshot?> loadCachedFirstPage() async => _snapshot;

  @override
  Future<FeaturedPodcastPage?> loadCachedPage({String? cursor}) async => null;

  @override
  Future<FeaturedPodcastRefreshOutcome> refreshFirstPage({
    bool force = false,
  }) async {
    firstPageRefreshCalls++;
    refreshOrder.add('first');
    final outcome = _firstPageOutcomes.isEmpty
        ? const FeaturedPodcastUnchanged()
        : _firstPageOutcomes.removeAt(0);
    if (outcome case FeaturedPodcastUpdated(:final snapshot)) {
      _snapshot = snapshot;
    }
    return outcome;
  }

  @override
  Future<FeaturedPodcastRefreshOutcome> refreshPage({
    String? cursor,
    bool force = false,
  }) async {
    requestedCursors.add(cursor);
    refreshOrder.add('page:$cursor');
    nextPageRefreshStarted?.complete();
    final pendingOutcome = nextPageOutcome;
    if (pendingOutcome != null) {
      final outcome = await pendingOutcome.future;
      if (outcome case FeaturedPodcastUpdated(:final snapshot)) {
        _snapshot = snapshot;
      }
      return outcome;
    }
    final currentPodcasts = _snapshot?.podcasts ?? const <FeaturedPodcast>[];
    final snapshot = FeaturedPodcastSnapshot(
      podcasts: currentPodcasts,
      contentHash: 'updated',
      fetchedAt: DateTime(2026, 1, 2),
    );
    _snapshot = snapshot;
    return FeaturedPodcastUpdated(snapshot);
  }
}

FeaturedPodcast _featuredPodcast({
  String id = 'featured-1',
  String title = 'Featured English',
  String applePodcastUrl = '',
  String rssUrl = 'https://example.com/feed.xml',
}) => FeaturedPodcast(
  id: id,
  applePodcastUrl: applePodcastUrl,
  rssUrl: rssUrl,
  imageUrl: null,
  title: title,
  description: 'Short English lessons',
);

_FakeFeaturedPodcastService _serviceWithPodcasts(
  List<FeaturedPodcast> podcasts, {
  String? nextCursor,
}) => _FakeFeaturedPodcastService(
  snapshot: FeaturedPodcastSnapshot(
    podcasts: podcasts,
    contentHash: 'test-snapshot',
    fetchedAt: DateTime(2026, 1, 1),
    nextCursor: nextCursor,
  ),
);

void main() {
  testWidgets('精选目录为空时仍可下拉刷新且不加载 Apple 搜索', (tester) async {
    final service = _serviceWithPodcasts(const []);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No curated podcasts yet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.firstPageRefreshCalls, 1);

    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(service.firstPageRefreshCalls, 2);
  });

  testWidgets('空搜索词恢复展示精选 Podcast', (tester) async {
    final service = _serviceWithPodcasts([_featuredPodcast()]);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Featured English'), findsOneWidget);
    expect(find.text('Short English lessons'), findsOneWidget);
    expect(find.text('Search podcasts or paste a link'), findsOneWidget);
    expect(service.firstPageRefreshCalls, 1);
  });

  testWidgets('下拉精选列表时刷新第一页', (tester) async {
    final podcasts = List.generate(
      20,
      (index) => _featuredPodcast(
        id: 'featured-$index',
        title: 'Featured Podcast $index',
        rssUrl: 'https://example.com/$index.xml',
      ),
    );
    final service = _serviceWithPodcasts(podcasts, nextCursor: 'cursor-1');

    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();
    expect(service.firstPageRefreshCalls, 1);

    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(service.firstPageRefreshCalls, 2);
  });

  testWidgets('精选列表无缓存时刷新失败可重试', (tester) async {
    final service = _FakeFeaturedPodcastService(
      firstPageOutcomes: [
        FeaturedPodcastFailed(StateError('offline')),
        FeaturedPodcastUpdated(
          FeaturedPodcastSnapshot(
            podcasts: [_featuredPodcast()],
            contentHash: 'retried-snapshot',
            fetchedAt: DateTime(2026, 1, 2),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Featured English'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Featured English'), findsOneWidget);
    expect(service.firstPageRefreshCalls, 2);
  });

  testWidgets('滚动到精选列表底部时按 nextCursor 加载下一页', (tester) async {
    final podcasts = List.generate(
      20,
      (index) => _featuredPodcast(
        id: 'featured-$index',
        title: 'Featured Podcast $index',
        rssUrl: 'https://example.com/$index.xml',
      ),
    );
    final service = _FakeFeaturedPodcastService(
      snapshot: FeaturedPodcastSnapshot(
        podcasts: podcasts,
        contentHash: 'first-page',
        fetchedAt: DateTime(2026, 1, 1),
        nextCursor: 'cursor-1',
      ),
    );

    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(service.requestedCursors, ['cursor-1']);
  });

  test('第一页刷新等待正在进行的分页，避免混入旧游标链', () async {
    final initialSnapshot = FeaturedPodcastSnapshot(
      podcasts: [_featuredPodcast(id: 'old-first')],
      contentHash: 'old-first-page',
      fetchedAt: DateTime(2026, 1, 1),
      nextCursor: 'old-cursor',
    );
    final paginatedSnapshot = FeaturedPodcastSnapshot(
      podcasts: [
        _featuredPodcast(id: 'old-first'),
        _featuredPodcast(id: 'old-second'),
      ],
      contentHash: 'old-pages',
      fetchedAt: DateTime(2026, 1, 1),
      nextCursor: 'old-next-cursor',
    );
    final refreshedSnapshot = FeaturedPodcastSnapshot(
      podcasts: [_featuredPodcast(id: 'new-first')],
      contentHash: 'new-first-page',
      fetchedAt: DateTime(2026, 1, 2),
      nextCursor: 'new-cursor',
    );
    final paginationStarted = Completer<void>();
    final paginationOutcome = Completer<FeaturedPodcastRefreshOutcome>();
    final service =
        _FakeFeaturedPodcastService(
            snapshot: initialSnapshot,
            firstPageOutcomes: [FeaturedPodcastUpdated(refreshedSnapshot)],
          )
          ..nextPageRefreshStarted = paginationStarted
          ..nextPageOutcome = paginationOutcome;
    final container = ProviderContainer(
      overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(featuredPodcastsProvider.future);
    final notifier = container.read(featuredPodcastsProvider.notifier);
    final loadMore = notifier.loadMore();
    final refreshFirstPage = notifier.refreshFirstPage();
    await paginationStarted.future;

    expect(service.firstPageRefreshCalls, 0);
    expect(service.refreshOrder, ['page:old-cursor']);

    paginationOutcome.complete(FeaturedPodcastUpdated(paginatedSnapshot));
    await Future.wait([loadMore, refreshFirstPage]);

    final snapshot = container
        .read(featuredPodcastsProvider)
        .value
        ?.snapshot;
    expect(service.refreshOrder, ['page:old-cursor', 'first']);
    expect(snapshot?.podcasts.map((podcast) => podcast.id), ['new-first']);
    expect(snapshot?.nextCursor, 'new-cursor');
  });

  testWidgets('精选 Podcast 订阅优先使用 Apple URL 且停留在本页', (tester) async {
    final fakeRepo = _FakePodcastRepository();
    final service = _serviceWithPodcasts([
      _featuredPodcast(applePodcastUrl: 'https://podcasts.apple.com/example'),
    ]);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: dedupeOverrides([
          featuredPodcastServiceProvider.overrideWithValue(service),
          isAuthenticatedProvider.overrideWithValue(true),
          podcastRepositoryProvider.overrideWithValue(fakeRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(fakeRepo.subscribed, ['https://podcasts.apple.com/example']);
    expect(fakeRepo.knownFeedUrls, ['https://example.com/feed.xml']);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Added to My Collections'), findsWidgets);
  });

  testWidgets('已订阅的精选 Podcast 显示静态对勾而不是去学习', (tester) async {
    final service = _serviceWithPodcasts([_featuredPodcast()]);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: dedupeOverrides([
          featuredPodcastServiceProvider.overrideWithValue(service),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [
                  Collection(
                    id: 'existing',
                    name: 'Existing Podcast',
                    createdDate: DateTime(2026, 1, 1),
                    source: CollectionSource.podcast,
                    podcastFeedUrl: 'https://example.com/feed.xml',
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Start Practicing'), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);

    final tileRect = tester.getRect(find.byType(PodcastSubscribeTile));
    final badgeRect = tester.getRect(find.text('Added'));
    final checkRect = tester.getRect(
      find.byIcon(Icons.check_circle_outline_rounded),
    );
    expect(badgeRect.top, greaterThanOrEqualTo(tileRect.top));
    expect(badgeRect.bottom, lessThan(checkRect.top));
  });

  testWidgets('未登录订阅精选 Podcast 显示登录提示且不调用仓库', (tester) async {
    final fakeRepo = _FakePodcastRepository();
    final service = _serviceWithPodcasts([_featuredPodcast()]);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: dedupeOverrides([
          featuredPodcastServiceProvider.overrideWithValue(service),
          isAuthenticatedProvider.overrideWithValue(false),
          podcastRepositoryProvider.overrideWithValue(fakeRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(fakeRepo.subscribed, isEmpty);
  });

  testWidgets('进入页面时搜索框不会自动聚焦', (tester) async {
    final service = _serviceWithPodcasts(const []);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: [featuredPodcastServiceProvider.overrideWithValue(service)],
      ),
    );
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isFalse);
  });

  testWidgets('输入关键词展示 Apple 搜索结果', (tester) async {
    final fakeSearch = _FakeSearchService([
      const PodcastSearchResult(
        id: 's1',
        title: 'BBC Global News',
        author: 'BBC',
        feedUrl: 'https://feeds.bbc.co.uk/news.xml',
      ),
    ]);
    final service = _serviceWithPodcasts(const []);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: dedupeOverrides([
          featuredPodcastServiceProvider.overrideWithValue(service),
          podcastSearchServiceProvider.overrideWithValue(fakeSearch),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bbc');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('BBC Global News'), findsOneWidget);
    expect(fakeSearch.lastTerm, 'bbc');
  });

  testWidgets('输入链接解析为可订阅 item', (tester) async {
    const url = 'https://example.com/feed.xml';
    final service = _serviceWithPodcasts(const []);
    await tester.pumpWidget(
      createTestApp(
        const PodcastDiscoveryScreen(),
        overrides: dedupeOverrides([
          featuredPodcastServiceProvider.overrideWithValue(service),
          podcastPreviewProvider(url).overrideWith(
            (ref) async => const PodcastPreviewData(
              meta: PodcastFeedMeta(
                title: 'Example Cast',
                feedUrl: url,
                author: 'Example Author',
              ),
              episodes: [],
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), url);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Example Cast'), findsOneWidget);
    expect(find.text('Subscribe to this link'), findsNothing);
  });
}

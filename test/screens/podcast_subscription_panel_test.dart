import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/official_collections/providers/discover_podcasts_provider.dart';
import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/features/podcast/podcast_repository.dart';
import 'package:echo_loop/features/podcast/podcast_search_provider.dart';
import 'package:echo_loop/features/podcast/podcast_search_service.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/screens/collection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/official_collections/fixtures/catalog_fixtures.dart';
import '../helpers/test_app.dart';

/// 搜索服务替身：返回预置结果，记录调用词。
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

/// Podcast 仓库替身：记录订阅输入 URL，随后抛错以避免触发导航。
class _FakePodcastRepository extends Fake implements PodcastRepository {
  final List<String> subscribed = [];

  @override
  Future<Collection> createAndFetch(String inputUrl) async {
    subscribed.add(inputUrl);
    throw const PodcastFeedBlockedException();
  }
}

/// 打开「订阅 Podcast」面板：点开 sheet → 选择「订阅 Podcast」。
Future<void> _openPodcastPanel(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Subscribe Podcast'));
  await tester.pumpAndSettle();
}

Widget _host() {
  return Builder(
    builder: (context) => Center(
      child: ElevatedButton(
        onPressed: () => showCreateCollectionDialog(context),
        child: const Text('open'),
      ),
    ),
  );
}

void main() {
  testWidgets('搜索框为空时展示精选播客列表', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _host(),
        overrides: [
          discoverPodcastsProvider.overrideWith(
            (ref) => [
              makeCatalogPodcast(id: 'p1', title: '6 Minute English'),
              makeCatalogPodcast(id: 'p2', title: 'VOA Learning English'),
            ],
          ),
        ],
      ),
    );
    await _openPodcastPanel(tester);

    expect(find.text('6 Minute English'), findsOneWidget);
    expect(find.text('VOA Learning English'), findsOneWidget);
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
    await tester.pumpWidget(
      createTestApp(
        _host(),
        overrides: [
          discoverPodcastsProvider.overrideWith((ref) => const []),
          podcastSearchServiceProvider.overrideWithValue(fakeSearch),
        ],
      ),
    );
    await _openPodcastPanel(tester);

    await tester.enterText(find.byType(TextField), 'bbc');
    // 等待 350ms 防抖 + 异步搜索完成
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('BBC Global News'), findsOneWidget);
    expect(fakeSearch.lastTerm, 'bbc');
  });

  testWidgets('输入 http 链接自动识别为「订阅此链接」', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        _host(),
        overrides: [discoverPodcastsProvider.overrideWith((ref) => const [])],
      ),
    );
    await _openPodcastPanel(tester);

    await tester.enterText(
      find.byType(TextField),
      'https://example.com/feed.xml',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe to this link'), findsOneWidget);
  });

  testWidgets('点击精选项的 + 触发订阅（传订阅输入 URL）', (tester) async {
    final fakeRepo = _FakePodcastRepository();
    await tester.pumpWidget(
      createTestApp(
        _host(),
        overrides: [
          discoverPodcastsProvider.overrideWith(
            (ref) => [
              makeCatalogPodcast(
                id: 'p1',
                title: '6 Minute English',
                applePodcastUrl: 'https://podcasts.apple.com/id262026947',
                rssUrl: 'https://feeds.bbci.co.uk/6min.rss',
              ),
            ],
          ),
          isAuthenticatedProvider.overrideWithValue(true),
          podcastRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      ),
    );
    await _openPodcastPanel(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    // subscriptionInputUrl 优先 Apple 链接
    expect(fakeRepo.subscribed, ['https://podcasts.apple.com/id262026947']);
  });
}

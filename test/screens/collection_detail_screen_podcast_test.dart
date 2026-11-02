import 'dart:convert';

import 'package:echo_loop/features/podcast/podcast_models.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/features/podcast/podcast_repository.dart';
import 'package:echo_loop/features/podcast/widgets/podcast_feed_summary_header.dart';
import 'package:echo_loop/features/community_collections/widgets/community_collection_header.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/screens/collection_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _MockPodcastRepository extends Mock implements PodcastRepository {}

class _PodcastTestCollectionList extends TestCollectionList {
  _PodcastTestCollectionList(super.initialState);

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
}

void main() {
  testWidgets('community collection detail displays the shared local header', (
    tester,
  ) async {
    final collection = Collection(
      id: 'community-1',
      name: 'Community English',
      createdDate: DateTime(2026, 6, 12),
      source: CollectionSource.community,
      remoteId: 'remote-1',
      description: 'A short collection.',
      authorNickname: 'Echo Studio',
      publishedAt: DateTime(2026, 6, 12),
    );

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'community-1'),
        overrides: dedupeOverrides([
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: const {'community-1': []},
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Echo Studio'), findsOneWidget);
    expect(find.text('2026-06-12 00:00'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('A short collection.'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(CommunityCollectionHeader),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('podcast 合集详情头部随列表滚动且更多展示完整 feed 元信息', (tester) async {
    const longDescription =
        'Short episodes for careful listening. Each episode is designed for '
        'slow practice with clear speech, focused vocabulary, and repeatable '
        'daily listening routines that help learners notice details. Learners '
        'can replay the same story several times, compare small pronunciation '
        'changes, and build confidence with a predictable listening rhythm. '
        'The archive also gives teachers enough material to choose topics for '
        'different levels without leaving the podcast collection.';
    final collection = Collection(
      id: 'podcast-1',
      name: 'Learning Podcast',
      createdDate: DateTime(2026, 6, 12),
      source: CollectionSource.podcast,
      podcastInputUrl: 'https://podcasts.apple.com/podcast/id123',
      podcastFeedUrl: 'https://example.com/feed.xml',
      podcastMetaJson: jsonEncode(
        const PodcastFeedMeta(
          title: 'Learning Podcast',
          author: 'Echo Studio',
          description: longDescription,
          feedUrl: 'https://example.com/feed.xml',
        ).toJson(),
      ),
      podcastLastRefreshedAt: DateTime(2026, 6, 12, 8, 30),
    );
    final items = List.generate(
      12,
      (index) => AudioItem(
        id: 'episode-$index',
        name: 'Episode $index',
        audioPath: null,
        addedDate: DateTime(2026, 6, 12),
        podcastEpisodeGuid: 'guid-$index',
        podcastEnclosureUrl: 'https://example.com/episode-$index.mp3',
        podcastEnclosureType: 'audio/mpeg',
      ),
    );
    final podcastRepo = _MockPodcastRepository();
    when(
      () => podcastRepo.refresh('podcast-1', force: any(named: 'force')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'podcast-1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: items)),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: {
                  'podcast-1': items.map((item) => item.id).toList(),
                },
              ),
            ),
          ),
          podcastRepositoryProvider.overrideWithValue(podcastRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // 标题由 AppBar 承载，header 不再重复展示；作者也不在 header
    expect(find.text('Learning Podcast'), findsWidgets);
    expect(find.text('Echo Studio'), findsNothing);
    // header 仅保留 4 行简介预览 + 内联更多，不展示封面或完整长简介
    expect(find.text(longDescription), findsNothing);
    expect(
      find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    final header = tester.widget<PodcastFeedSummaryHeader>(
      find.byType(PodcastFeedSummaryHeader),
    );
    final headerPadding = header.padding.resolve(TextDirection.ltr);
    expect(headerPadding.top, headerPadding.bottom);
    // 头部保持紧凑，不展示上次刷新时间
    expect(find.text('Last refreshed: 2026-06-12 08:30'), findsNothing);
    expect(find.byIcon(Icons.podcasts_rounded), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
      findsNothing,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 450));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    // 作者移入详情弹窗
    expect(find.text('Echo Studio'), findsOneWidget);
    // 详情弹窗只展示 RSS/来源链接，不混入刷新状态。
    expect(find.text('Last refreshed: 2026-06-12 08:30'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('RSS URL'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple Podcasts'), findsOneWidget);
    expect(
      find.text('https://podcasts.apple.com/podcast/id123'),
      findsOneWidget,
    );
    expect(find.text('RSS URL'), findsOneWidget);
    expect(find.text('https://example.com/feed.xml'), findsOneWidget);
  });

  testWidgets('podcast 合集详情只有 RSS 输入时不重复展示为普通链接', (tester) async {
    final collection = Collection(
      id: 'podcast-1',
      name: 'Speak English with ESLPod.com',
      createdDate: DateTime(2026, 6, 15),
      source: CollectionSource.podcast,
      podcastInputUrl: 'https://www.eslpod.com/feed.xml',
      podcastFeedUrl: 'https://www.eslpod.com/feed.xml',
      podcastMetaJson: jsonEncode(
        const PodcastFeedMeta(
          title: 'Speak English with ESLPod.com',
          author: 'ESLPod.com',
          description: 'Learn English Fast',
          feedUrl: 'https://www.eslpod.com/feed.xml',
        ).toJson(),
      ),
      podcastLastRefreshedAt: DateTime(2026, 6, 15, 8, 12),
    );
    final item = AudioItem(
      id: 'episode-1',
      name: 'Episode One',
      audioPath: null,
      addedDate: DateTime(2026, 6, 15),
      podcastEpisodeGuid: 'guid-1',
      podcastEnclosureUrl: 'https://example.com/episode-1.mp3',
      podcastEnclosureType: 'audio/mpeg',
    );
    final podcastRepo = _MockPodcastRepository();
    when(
      () => podcastRepo.refresh('podcast-1', force: any(named: 'force')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'podcast-1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: const {
                  'podcast-1': ['episode-1'],
                },
              ),
            ),
          ),
          podcastRepositoryProvider.overrideWithValue(podcastRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('RSS URL'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple Podcasts'), findsNothing);
    expect(find.text('Link'), findsNothing);
    expect(find.text('RSS URL'), findsOneWidget);
    expect(find.text('https://www.eslpod.com/feed.xml'), findsOneWidget);
  });

  testWidgets('podcast 合集详情下拉刷新强制刷新 feed', (tester) async {
    final collection = Collection(
      id: 'podcast-1',
      name: 'Learning Podcast',
      createdDate: DateTime(2026, 6, 12),
      source: CollectionSource.podcast,
      podcastFeedUrl: 'https://example.com/feed.xml',
      podcastMetaJson: jsonEncode(
        const PodcastFeedMeta(
          title: 'Learning Podcast',
          feedUrl: 'https://example.com/feed.xml',
        ).toJson(),
      ),
      podcastLastRefreshedAt: DateTime(2026, 6, 12, 8, 30),
    );
    final item = AudioItem(
      id: 'episode-1',
      name: 'Episode One',
      audioPath: null,
      addedDate: DateTime(2026, 6, 12),
      podcastEpisodeGuid: 'guid-1',
      podcastEnclosureUrl: 'https://example.com/episode-1.mp3',
      podcastEnclosureType: 'audio/mpeg',
    );
    final podcastRepo = _MockPodcastRepository();
    when(
      () => podcastRepo.refresh('podcast-1', force: any(named: 'force')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'podcast-1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
          collectionListProvider.overrideWith(
            () => TestCollectionList(
              CollectionState(
                rawCollections: [collection],
                audioIdsMap: const {
                  'podcast-1': ['episode-1'],
                },
              ),
            ),
          ),
          podcastRepositoryProvider.overrideWithValue(podcastRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    clearInteractions(podcastRepo);
    await tester.drag(find.text('Episode One'), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => podcastRepo.refresh('podcast-1', force: true)).called(1);
  });

  testWidgets('podcast 合集强刷失败后详情弹窗展示刷新失败状态和时间', (tester) async {
    final collection = Collection(
      id: 'podcast-1',
      name: 'Learning Podcast',
      createdDate: DateTime(2026, 6, 12),
      source: CollectionSource.podcast,
      podcastInputUrl: 'https://podcasts.apple.com/podcast/id123',
      podcastFeedUrl: 'https://example.com/feed.xml',
      podcastMetaJson: jsonEncode(
        const PodcastFeedMeta(
          title: 'Learning Podcast',
          feedUrl: 'https://example.com/feed.xml',
        ).toJson(),
      ),
      podcastLastRefreshedAt: DateTime(2026, 6, 12, 8, 30),
    );
    final item = AudioItem(
      id: 'episode-1',
      name: 'Episode One',
      audioPath: null,
      addedDate: DateTime(2026, 6, 12),
      podcastEpisodeGuid: 'guid-1',
      podcastEnclosureUrl: 'https://example.com/episode-1.mp3',
      podcastEnclosureType: 'audio/mpeg',
    );
    final podcastRepo = _MockPodcastRepository();
    final collectionList = _PodcastTestCollectionList(
      CollectionState(
        rawCollections: [collection],
        audioIdsMap: const {
          'podcast-1': ['episode-1'],
        },
      ),
    );
    when(() => podcastRepo.refresh('podcast-1', force: true)).thenAnswer((
      _,
    ) async {
      await collectionList.updatePodcastCollection(
        collection.copyWith(
          podcastLastRefreshedAt: DateTime(2026, 6, 15, 11, 22),
          podcastLastRefreshError: 'Exception: rss failed',
        ),
      );
      throw Exception('rss failed');
    });

    await tester.pumpWidget(
      createTestScreen(
        const CollectionDetailScreen(collectionId: 'podcast-1'),
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: [item])),
          ),
          collectionListProvider.overrideWith(() => collectionList),
          podcastRepositoryProvider.overrideWithValue(podcastRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Episode One'), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Failed to refresh: Exception: rss failed'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('podcast-feed-summary-inline-more')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last refreshed: 2026-06-15 11:22'), findsNothing);
    expect(find.text('Failed · 2026-06-15 11:22'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:echo_loop/features/podcast/podcast_refresh_controller.dart';
import 'package:echo_loop/features/podcast/podcast_repository.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_providers.dart';

class _MockPodcastRepository extends Mock implements PodcastRepository {}

void main() {
  Collection podcastCollection(String id) => Collection(
    id: id,
    name: 'Podcast $id',
    createdDate: DateTime(2026, 7, 13),
    source: CollectionSource.podcast,
    podcastFeedUrl: 'https://example.com/$id.xml',
  );

  Collection localCollection(String id) =>
      Collection(id: id, name: 'Local $id', createdDate: DateTime(2026, 7, 13));

  Collection communityCollection(String id) => Collection(
    id: id,
    name: 'Community $id',
    createdDate: DateTime(2026, 7, 13),
    source: CollectionSource.community,
    remoteId: 'remote-$id',
  );

  test('只刷新已订阅的 podcast 合集', () async {
    final repo = _MockPodcastRepository();
    when(
      () => repo.refresh(any(), force: any(named: 'force')),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        collectionListProvider.overrideWith(
          () => TestCollectionList(
            CollectionState(
              rawCollections: [
                podcastCollection('podcast-1'),
                localCollection('local-1'),
                communityCollection('community-1'),
                podcastCollection('podcast-2'),
              ],
            ),
          ),
        ),
        podcastRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    addTearDown(container.dispose);

    await container.read(podcastRefreshControllerProvider).refreshIfStale();

    verify(() => repo.refresh('podcast-1', force: false)).called(1);
    verify(() => repo.refresh('podcast-2', force: false)).called(1);
    verifyNever(() => repo.refresh('local-1', force: false));
    verifyNever(() => repo.refresh('official-1', force: false));
  });

  test('单个 podcast 刷新失败不影响后续合集', () async {
    final repo = _MockPodcastRepository();
    when(
      () => repo.refresh('podcast-1', force: false),
    ).thenThrow(Exception('rss failed'));
    when(
      () => repo.refresh('podcast-2', force: false),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        collectionListProvider.overrideWith(
          () => TestCollectionList(
            CollectionState(
              rawCollections: [
                podcastCollection('podcast-1'),
                podcastCollection('podcast-2'),
              ],
            ),
          ),
        ),
        podcastRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    addTearDown(container.dispose);

    await container.read(podcastRefreshControllerProvider).refreshIfStale();

    verifyInOrder([
      () => repo.refresh('podcast-1', force: false),
      () => repo.refresh('podcast-2', force: false),
    ]);
  });

  test('并发触发时复用同一条刷新链路', () async {
    final repo = _MockPodcastRepository();
    final completer = Completer<void>();
    when(
      () => repo.refresh('podcast-1', force: false),
    ).thenAnswer((_) => completer.future);
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        collectionListProvider.overrideWith(
          () => TestCollectionList(
            CollectionState(rawCollections: [podcastCollection('podcast-1')]),
          ),
        ),
        podcastRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    addTearDown(container.dispose);

    final controller = container.read(podcastRefreshControllerProvider);
    final first = controller.refreshIfStale();
    final second = controller.refreshIfStale();

    verify(() => repo.refresh('podcast-1', force: false)).called(1);

    completer.complete();
    await Future.wait([first, second]);
  });
}

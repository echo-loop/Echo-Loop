import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/community_collections/data/community_collection_api.dart';
import 'package:echo_loop/features/community_collections/data/community_collection_cache.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_paging.dart';
import 'package:echo_loop/features/community_collections/providers/community_collection_detail_provider.dart';
import 'package:echo_loop/features/community_collections/providers/discover_community_collections_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCommunityApi extends CommunityCollectionApi {
  _FakeCommunityApi({this.collectionsResponse, this.filesResponse})
    : super.withDio(Dio());

  final Future<PublicCollectionPage> Function(String? cursor)?
  collectionsResponse;
  final Future<CommunityCollectionDetailPage> Function(String? cursor)?
  filesResponse;
  var collectionsCalls = 0;
  var filesCalls = 0;
  final collectionCursors = <String?>[];
  final fileCursors = <String?>[];

  @override
  Future<PublicCollectionPage> getCollections({
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    collectionsCalls++;
    collectionCursors.add(cursor);
    final response = collectionsResponse;
    if (response != null) return response(cursor);
    return PublicCollectionPage(
      items: [
        _catalogEntry(
          'collection-$collectionsCalls',
          'Collection $collectionsCalls',
        ),
      ],
      nextCursor: cursor == null ? 'collections-next' : null,
    );
  }

  @override
  Future<CommunityCollectionDetailPage> getCollectionDetail(
    String collectionId, {
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    filesCalls++;
    fileCursors.add(cursor);
    final response = filesResponse;
    if (response != null) return response(cursor);
    return CommunityCollectionDetailPage(
      collection: _catalogEntry('collection-1', 'Cached collection'),
      items: [_file('file-$filesCalls', 'Lesson $filesCalls')],
      nextCursor: cursor == null ? 'files-next' : null,
    );
  }
}

void main() {
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('community-catalog-');
  });

  tearDown(() => directory.delete(recursive: true));

  test('首次只请求一页，下一页显式加载并按页持久化', () async {
    final api = _FakeCommunityApi(
      collectionsResponse: (cursor) async => cursor == null
          ? PublicCollectionPage(
              items: [_catalogEntry('collection-1', 'First page')],
              nextCursor: 'collections-next',
            )
          : PublicCollectionPage(
              items: [_catalogEntry('collection-2', 'Second page')],
              nextCursor: null,
            ),
      filesResponse: (cursor) async => cursor == null
          ? CommunityCollectionDetailPage(
              collection: _catalogEntry('collection-1', 'Cached collection'),
              items: [_file('file-1', 'First lesson')],
              nextCursor: 'files-next',
            )
          : CommunityCollectionDetailPage(
              collection: _catalogEntry('collection-1', 'Cached collection'),
              items: [_file('file-2', 'Second lesson')],
              nextCursor: null,
            ),
    );
    final service = CommunityCollectionCatalogService(
      api: api,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23, 12),
    );

    await service.refreshCollectionsPage(cursor: null, force: true);
    await service.refreshFilesPage('collection-1', cursor: null, force: true);
    expect(api.collectionsCalls, 1);
    expect(api.filesCalls, 1);
    expect(api.collectionCursors, [null]);
    expect(api.fileCursors, [null]);

    await service.refreshCollectionsPage(
      cursor: 'collections-next',
      force: true,
    );
    await service.refreshFilesPage(
      'collection-1',
      cursor: 'files-next',
      force: true,
    );
    expect(api.collectionsCalls, 2);
    expect(api.filesCalls, 2);
    expect(
      (await service.loadCachedCollectionsPage(
        cursor: 'collections-next',
      ))?.items.single.name,
      'Second page',
    );
    expect(
      (await service.loadCachedFilesPage(
        'collection-1',
        cursor: 'files-next',
      ))?.items.single.title,
      'Second lesson',
    );
    expect(
      (await service.loadCachedFilesPage(
        'collection-1',
        cursor: null,
      ))?.collection?.name,
      'Cached collection',
    );

    final readerApi = _FakeCommunityApi();
    final reader = CommunityCollectionCatalogService(
      api: readerApi,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23, 12),
    );
    expect(
      await reader.refreshCollectionsPage(cursor: null),
      isA<CommunityCollectionRefreshUpdated>(),
    );
    expect(
      await reader.refreshCollectionsPage(cursor: 'collections-next'),
      isA<CommunityCollectionRefreshUpdated>(),
    );
    expect(
      await reader.refreshFilesPage('collection-1', cursor: null),
      isA<CommunityCollectionRefreshUpdated>(),
    );
    expect(
      await reader.refreshFilesPage('collection-1', cursor: 'files-next'),
      isA<CommunityCollectionRefreshUpdated>(),
    );
    expect(readerApi.collectionsCalls, 2);
    expect(readerApi.filesCalls, 2);
  });

  test('旧版 SharedPreferences 目录缓存迁移为 stale 首页面', () async {
    final catalogEntry = _catalogEntry('collection-1', 'Migrated collection');
    SharedPreferences.setMockInitialValues({
      'community_collection_discovery_v2': jsonEncode([catalogEntry.toJson()]),
    });
    final preferences = await SharedPreferences.getInstance();
    final api = _FakeCommunityApi(
      collectionsResponse: (_) async => PublicCollectionPage(
        items: [_catalogEntry('collection-2', 'Fresh collection')],
        nextCursor: null,
      ),
    );
    final service = CommunityCollectionCatalogService(
      api: api,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23),
    );

    expect(
      (await service.loadCachedCollectionsPage(
        cursor: null,
      ))?.items.single.name,
      'Migrated collection',
    );
    expect(preferences.getString('community_collection_discovery_v2'), isNull);
    expect(
      await service.refreshCollectionsPage(cursor: null),
      isA<CommunityCollectionRefreshUpdated>(),
    );
    expect(api.collectionCursors, [null]);
    expect(
      (await service.loadCachedCollectionsPage(
        cursor: null,
      ))?.items.single.name,
      'Fresh collection',
    );
  });

  test('页面请求失败时不覆盖已有页面缓存', () async {
    final writer = CommunityCollectionCatalogService(
      api: _FakeCommunityApi(
        filesResponse: (cursor) async => CommunityCollectionDetailPage(
          collection: _catalogEntry('collection-1', 'Cached collection'),
          items: [_file(cursor ?? 'first', 'Old lesson')],
          nextCursor: cursor == null ? 'next' : null,
        ),
      ),
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23),
    );
    await writer.refreshFilesPage('collection-1', cursor: null, force: true);
    await writer.refreshFilesPage('collection-1', cursor: 'next', force: true);

    final reader = CommunityCollectionCatalogService(
      api: _FakeCommunityApi(
        filesResponse: (cursor) async {
          if (cursor == 'next') throw StateError('second page failed');
          return CommunityCollectionDetailPage(
            collection: _catalogEntry('collection-1', 'Cached collection'),
            items: [_file('first', 'New first page')],
            nextCursor: 'next',
          );
        },
      ),
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 24),
    );

    expect(
      await reader.refreshFilesPage(
        'collection-1',
        cursor: 'next',
        force: true,
      ),
      isA<CommunityCollectionRefreshFailed>(),
    );
    expect(
      (await reader.loadCachedFilesPage(
        'collection-1',
        cursor: 'next',
      ))?.items.single.title,
      'Old lesson',
    );
  });

  test('第一页 cursor 变化时丢弃断开的后续页面', () async {
    var firstPageVersion = 0;
    final api = _FakeCommunityApi(
      filesResponse: (cursor) async {
        if (cursor == null) {
          firstPageVersion++;
          return CommunityCollectionDetailPage(
            collection: _catalogEntry('collection-1', 'Cached collection'),
            items: [_file('first-$firstPageVersion', 'First')],
            nextCursor: firstPageVersion == 1 ? 'old-next' : 'new-next',
          );
        }
        return CommunityCollectionDetailPage(
          collection: _catalogEntry('collection-1', 'Cached collection'),
          items: [_file('second', 'Second')],
          nextCursor: null,
        );
      },
    );
    final service = CommunityCollectionCatalogService(
      api: api,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23),
    );

    await service.refreshFilesPage('collection-1', cursor: null, force: true);
    await service.refreshFilesPage(
      'collection-1',
      cursor: 'old-next',
      force: true,
    );
    await service.refreshFilesPage('collection-1', cursor: null, force: true);

    expect(
      await service.loadCachedFilesPage('collection-1', cursor: 'old-next'),
      isNull,
    );
  });

  test('详情 Provider 先展示第一页缓存，loadMore 才请求下一页', () async {
    final cachedFile = _file('file-1', 'Cached lesson');
    final writer = CommunityCollectionCatalogService(
      api: _FakeCommunityApi(
        filesResponse: (cursor) async => CommunityCollectionDetailPage(
          collection: _catalogEntry('collection-1', 'Cached collection'),
          items: [
            cursor == null
                ? cachedFile
                : _file('file-2', 'Cached second lesson'),
          ],
          nextCursor: cursor == null ? 'next' : null,
        ),
      ),
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23),
    );
    await writer.refreshFilesPage('collection-1', cursor: null, force: true);
    await writer.refreshFilesPage('collection-1', cursor: 'next', force: true);

    final firstPageGate = Completer<CommunityCollectionDetailPage>();
    final secondPageGate = Completer<CommunityCollectionDetailPage>();
    final firstRequestStarted = Completer<void>();
    final secondRequestStarted = Completer<void>();
    final readerApi = _FakeCommunityApi(
      filesResponse: (cursor) {
        if (cursor == null) {
          if (!firstRequestStarted.isCompleted) {
            firstRequestStarted.complete();
          }
          return firstPageGate.future;
        }
        if (!secondRequestStarted.isCompleted) {
          secondRequestStarted.complete();
        }
        return secondPageGate.future;
      },
    );
    final reader = CommunityCollectionCatalogService(
      api: readerApi,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23, 12, 1),
    );
    final container = ProviderContainer(
      overrides: [
        communityCollectionCatalogServiceProvider.overrideWithValue(reader),
      ],
    );
    addTearDown(container.dispose);

    final values =
        <AsyncValue<CommunityCollectionPagedState<CommunityCollectionFile>>>[];
    final cachedVisible = Completer<void>();
    final freshVisible = Completer<void>();
    final cachedSecondVisible = Completer<void>();
    final secondVisible = Completer<void>();
    final subscription = container.listen(
      communityCollectionFilesProvider('collection-1'),
      (previous, next) {
        values.add(next);
        final page = next.valueOrNull;
        if (!cachedVisible.isCompleted &&
            page?.items.length == 1 &&
            page?.items.first.title == 'Cached lesson') {
          cachedVisible.complete();
        }
        if (!freshVisible.isCompleted &&
            page?.items.length == 1 &&
            page?.items.first.title == 'Fresh lesson') {
          freshVisible.complete();
        }
        if (!cachedSecondVisible.isCompleted &&
            page?.items.any((item) => item.title == 'Cached second lesson') ==
                true) {
          cachedSecondVisible.complete();
        }
        if (!secondVisible.isCompleted &&
            page?.items.any((item) => item.title == 'Fresh second lesson') ==
                true) {
          secondVisible.complete();
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await cachedVisible.future.timeout(const Duration(seconds: 1));
    await firstRequestStarted.future.timeout(const Duration(seconds: 1));
    expect(readerApi.fileCursors, [null]);
    expect(firstPageGate.isCompleted, isFalse);

    firstPageGate.complete(
      CommunityCollectionDetailPage(
        collection: _catalogEntry('collection-1', 'Cached collection'),
        items: [_file('file-1', 'Fresh lesson')],
        nextCursor: 'next',
      ),
    );
    await freshVisible.future.timeout(const Duration(seconds: 1));
    expect(readerApi.fileCursors, [null]);

    final loadMore = container
        .read(communityCollectionFilesProvider('collection-1').notifier)
        .loadMore();
    await cachedSecondVisible.future.timeout(const Duration(seconds: 1));
    await secondRequestStarted.future.timeout(const Duration(seconds: 1));
    expect(readerApi.fileCursors, [null, 'next']);
    expect(secondPageGate.isCompleted, isFalse);

    secondPageGate.complete(
      CommunityCollectionDetailPage(
        collection: _catalogEntry('collection-1', 'Cached collection'),
        items: [_file('file-2', 'Fresh second lesson')],
        nextCursor: null,
      ),
    );
    await loadMore;
    await secondVisible.future.timeout(const Duration(seconds: 1));
    expect(values.last.valueOrNull?.items.length, 2);
  });

  test('发现页目录 Provider 首次只请求第一页', () async {
    final writer = CommunityCollectionCatalogService(
      api: _FakeCommunityApi(
        collectionsResponse: (cursor) async => PublicCollectionPage(
          items: [
            _catalogEntry(
              cursor == null ? 'collection-1' : 'collection-2',
              cursor == null ? 'Cached collection' : 'Cached second collection',
            ),
          ],
          nextCursor: cursor == null ? 'next' : null,
        ),
      ),
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23),
    );
    await writer.refreshCollectionsPage(cursor: null, force: true);
    await writer.refreshCollectionsPage(cursor: 'next', force: true);

    final secondRequestStarted = Completer<void>();
    final secondPageGate = Completer<PublicCollectionPage>();
    final api = _FakeCommunityApi(
      collectionsResponse: (cursor) async {
        if (cursor == null) {
          return PublicCollectionPage(
            items: [_catalogEntry('collection-1', 'Fresh collection')],
            nextCursor: 'next',
          );
        }
        if (!secondRequestStarted.isCompleted) {
          secondRequestStarted.complete();
        }
        return secondPageGate.future;
      },
    );
    final service = CommunityCollectionCatalogService(
      api: api,
      resolveDir: () async => directory,
      now: () => DateTime(2026, 9, 23, 12, 1),
    );
    final container = ProviderContainer(
      overrides: [
        communityCollectionCatalogServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final freshVisible = Completer<void>();
    final cachedSecondVisible = Completer<void>();
    final subscription = container.listen(
      discoverCommunityCollectionsProvider,
      (previous, next) {
        if (!cachedSecondVisible.isCompleted &&
            next.valueOrNull?.items.any(
                  (item) => item.name == 'Cached second collection',
                ) ==
                true) {
          cachedSecondVisible.complete();
        }
        if (!freshVisible.isCompleted &&
            next.valueOrNull?.items.length == 1 &&
            next.valueOrNull?.items.first.name == 'Fresh collection') {
          freshVisible.complete();
        }
      },
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await freshVisible.future.timeout(const Duration(seconds: 1));
    expect(api.collectionCursors, [null]);

    final loadMore = container
        .read(discoverCommunityCollectionsProvider.notifier)
        .loadMore();
    await cachedSecondVisible.future.timeout(const Duration(seconds: 1));
    await secondRequestStarted.future.timeout(const Duration(seconds: 1));
    expect(api.collectionCursors, [null, 'next']);
    secondPageGate.complete(
      PublicCollectionPage(
        items: [_catalogEntry('collection-2', 'Second collection')],
        nextCursor: null,
      ),
    );
    await loadMore;
    expect(
      container.read(discoverCommunityCollectionsProvider).value?.items.length,
      2,
    );
  });
}

PublicCollectionCatalogEntry _catalogEntry(String id, String name) {
  return PublicCollectionCatalogEntry(
    id: id,
    name: name,
    description: null,
    coverUrl: null,
    fileCount: 1,
    publishedAt: DateTime(2026, 1, 1),
  );
}

CommunityCollectionFile _file(String id, String title) {
  return CommunityCollectionFile(
    id: id,
    title: title,
    description: null,
    mediaType: CommunityMediaType.audio,
    durationSec: 42,
    fileSizeBytes: null,
    difficulty: CommunityDifficulty.b1,
    publishedAt: DateTime(2026, 1, 1),
    sortOrder: 0,
    mediaUrl: 'https://example.com/$id.m4a',
  );
}

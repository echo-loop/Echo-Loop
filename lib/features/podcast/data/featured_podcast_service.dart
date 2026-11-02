import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/api_config.dart';
import '../../../providers/package_info_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../../../services/refresh_coordinator.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../../utils/app_data_dir.dart';
import '../models/featured_podcast.dart';

part 'featured_podcast_service.g.dart';

sealed class FeaturedPodcastRefreshOutcome {
  const FeaturedPodcastRefreshOutcome();
}

class FeaturedPodcastThrottled extends FeaturedPodcastRefreshOutcome {
  const FeaturedPodcastThrottled();
}

class FeaturedPodcastUnchanged extends FeaturedPodcastRefreshOutcome {
  const FeaturedPodcastUnchanged();
}

class FeaturedPodcastUpdated extends FeaturedPodcastRefreshOutcome {
  final FeaturedPodcastSnapshot snapshot;

  const FeaturedPodcastUpdated(this.snapshot);
}

class FeaturedPodcastFailed extends FeaturedPodcastRefreshOutcome {
  final Object error;

  const FeaturedPodcastFailed(this.error);
}

/// 精选 Podcast 的分页缓存与刷新服务。
///
/// 该服务只通过 `/api/v1/featured-podcasts` 按 cursor 获取精选播客分页，
/// 首屏缓存读取时兼容迁移旧版本地精选列表。
class FeaturedPodcastService {
  final Dio _dio;
  final Future<Directory> Function() _resolveDir;
  late final RefreshCoordinator<String, FeaturedPodcastRefreshOutcome> _refresh;

  final Map<String, FeaturedPodcastPage> _pages = {};
  FeaturedPodcastSnapshot? _snapshot;

  FeaturedPodcastService({
    required String baseUrl,
    String? appVersion,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = createBackendDio(
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'PODCAST-FEATURED',
       ),
       _resolveDir = _defaultDir {
    _refresh = RefreshCoordinator<String, FeaturedPodcastRefreshOutcome>();
  }

  FeaturedPodcastService.withDio({
    required Dio dio,
    required Future<Directory> Function() resolveDir,
    RefreshCoordinator<String, FeaturedPodcastRefreshOutcome>?
    refreshCoordinator,
  }) : _dio = dio,
       _resolveDir = resolveDir {
    _refresh =
        refreshCoordinator ??
        RefreshCoordinator<String, FeaturedPodcastRefreshOutcome>();
  }

  FeaturedPodcastSnapshot? get cachedSnapshot => _snapshot;

  static Future<Directory> _defaultDir() async {
    final base = await resolveAppCacheDirectory();
    // Keep the established cache directory and catalog filenames for upgrades.
    final directory = Directory(p.join(base.path, 'podcast_catalog'));
    await directory.create(recursive: true);
    return directory;
  }

  String _pageKey(String? cursor) => cursor ?? 'first';

  Future<File> _pageFile({String? cursor}) async {
    final directory = await _resolveDir();
    if (cursor == null) return File(p.join(directory.path, 'catalog.json'));
    final cursorHash = sha256.convert(utf8.encode(cursor)).toString();
    return File(p.join(directory.path, 'page-$cursorHash.json'));
  }

  Future<File> _pageMetaFile({String? cursor}) async {
    final directory = await _resolveDir();
    if (cursor == null) {
      return File(p.join(directory.path, 'catalog.meta.json'));
    }
    final cursorHash = sha256.convert(utf8.encode(cursor)).toString();
    return File(p.join(directory.path, 'page-$cursorHash.meta.json'));
  }

  /// 读取第一页缓存，并兼容旧版全量 catalog 磁盘缓存。
  Future<FeaturedPodcastSnapshot?> loadCachedFirstPage() async {
    await loadCachedPage();
    return _snapshot;
  }

  /// 读取本地指定分页；旧版 catalog 缓存作为第一页继续展示。
  Future<FeaturedPodcastPage?> loadCachedPage({String? cursor}) async {
    final key = _pageKey(cursor);
    final existing = _pages[key];
    if (existing != null) return existing;

    try {
      var pageFile = await _pageFile(cursor: cursor);
      var metaFile = await _pageMetaFile(cursor: cursor);
      if (!await pageFile.exists() || !await metaFile.exists()) {
        if (cursor != null) return null;
        final legacy = await _findLegacyCache();
        if (legacy == null) {
          return null;
        }
        final target = await _resolveDir();
        await target.create(recursive: true);
        await pageFile.writeAsBytes(await legacy.catalog.readAsBytes());
        await metaFile.writeAsBytes(await legacy.meta.readAsBytes());
      }

      final meta = jsonDecode(await metaFile.readAsString());
      final body = await pageFile.readAsString();
      if (meta is! Map<String, dynamic>) {
        throw const FormatException('Invalid featured podcast cache');
      }
      final page = _pageFromJson(
        body,
        cursor: cursor,
        contentHash: meta['contentHash'] as String? ?? '',
        fetchedAt: DateTime.parse(meta['lastFetchedAt'] as String),
        allowLegacyCatalogCache: cursor == null,
      );
      _storePage(page);
      return page;
    } catch (error) {
      AppLogger.log('FeaturedPodcast', 'cache load failed: $error');
      return null;
    }
  }

  Future<FeaturedPodcastRefreshOutcome> refreshFirstPage({bool force = false}) {
    return refreshPage(force: force);
  }

  /// 刷新指定游标页；第一页刷新会丢弃此前加载的后续页。
  Future<FeaturedPodcastRefreshOutcome> refreshPage({
    String? cursor,
    bool force = false,
  }) {
    final key = _pageKey(cursor);
    return _refresh
        .run(
          key: 'featured-podcasts:$key',
          force: force,
          lastRefreshedAt: null,
          // 与社区合集目录一致：调用方决定何时刷新，协调器只合并并发请求。
          throttleWindow: Duration.zero,
          refresh: () => _doRefresh(cursor),
        )
        .then(
          (result) => switch (result) {
            RefreshThrottled<FeaturedPodcastRefreshOutcome>() =>
              const FeaturedPodcastThrottled(),
            RefreshCompleted<FeaturedPodcastRefreshOutcome>(:final result) =>
              result,
          },
        );
  }

  Future<FeaturedPodcastRefreshOutcome> _doRefresh(String? cursor) async {
    try {
      final response = await _dio.get<String>(
        '/api/v1/featured-podcasts',
        queryParameters: cursor == null ? null : {'cursor': cursor},
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        return FeaturedPodcastFailed(
          StateError('empty featured podcast response'),
        );
      }

      final hash = sha256.convert(utf8.encode(body)).toString();
      final now = DateTime.now();
      final oldPage = _pages[_pageKey(cursor)];
      if (hash == oldPage?.contentHash && oldPage != null) {
        await _writePageMeta(cursor: cursor, hash: hash, fetchedAt: now);
        _storePage(oldPage.withFetchedAt(now));
        return const FeaturedPodcastUnchanged();
      }

      final page = _pageFromJson(
        body,
        cursor: cursor,
        contentHash: hash,
        fetchedAt: now,
      );
      final pageFile = await _pageFile(cursor: cursor);
      await pageFile.parent.create(recursive: true);
      await pageFile.writeAsString(body);
      await _writePageMeta(cursor: cursor, hash: hash, fetchedAt: now);
      final snapshot = _storePage(page, reset: cursor == null);
      return FeaturedPodcastUpdated(snapshot);
    } catch (error, stackTrace) {
      AppLogger.log('FeaturedPodcast', 'refresh failed: $error');
      AppLogger.log('FeaturedPodcast', stackTrace.toString());
      return FeaturedPodcastFailed(error);
    }
  }

  FeaturedPodcastPage _pageFromJson(
    String body, {
    required String? cursor,
    required String contentHash,
    required DateTime fetchedAt,
    bool allowLegacyCatalogCache = false,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid featured podcast response');
    }
    final rawItems =
        decoded['items'] ??
        (allowLegacyCatalogCache ? decoded['podcastCatalogs'] : null);
    if (rawItems is! List) {
      throw const FormatException('Missing featured podcast items');
    }
    final rawNextCursor = decoded['nextCursor'];
    final String? nextCursor;
    if (rawNextCursor == null) {
      nextCursor = null;
    } else if (rawNextCursor is String) {
      nextCursor = rawNextCursor;
    } else {
      throw const FormatException('Invalid featured podcast cursor');
    }
    final podcasts = rawItems
        .whereType<Map>()
        .map(
          (item) => FeaturedPodcast.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return FeaturedPodcastPage(
      cursor: cursor,
      podcasts: podcasts,
      nextCursor: nextCursor,
      contentHash: contentHash,
      fetchedAt: fetchedAt,
    );
  }

  FeaturedPodcastSnapshot _storePage(
    FeaturedPodcastPage page, {
    bool reset = false,
  }) {
    if (reset) _pages.clear();
    _pages[_pageKey(page.cursor)] = page;
    final snapshot = _snapshotFromPages();
    _snapshot = snapshot;
    return snapshot;
  }

  FeaturedPodcastSnapshot _snapshotFromPages() {
    final pages = _pages.values.toList(growable: false);
    final lastPage = pages.last;
    final contentHash = sha256
        .convert(utf8.encode(pages.map((page) => page.contentHash).join('|')))
        .toString();
    return FeaturedPodcastSnapshot(
      podcasts: pages.expand((page) => page.podcasts).toList(growable: false),
      contentHash: contentHash,
      fetchedAt: lastPage.fetchedAt,
      nextCursor: lastPage.nextCursor,
    );
  }

  Future<void> _writePageMeta({
    required String? cursor,
    required String hash,
    required DateTime fetchedAt,
  }) async {
    final file = await _pageMetaFile(cursor: cursor);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'contentHash': hash,
        'lastFetchedAt': fetchedAt.toIso8601String(),
      }),
    );
  }

  Future<_LegacyPodcastCache?> _findLegacyCache() async {
    final base = await resolveAppCacheDirectory();
    final candidates = <Directory>[
      Directory(p.join(base.path, 'official_catalog')),
      Directory(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'official_catalog',
        ),
      ),
    ];
    for (final directory in candidates) {
      final catalog = File(p.join(directory.path, 'catalog.json'));
      final meta = File(p.join(directory.path, 'catalog.meta.json'));
      if (await catalog.exists() && await meta.exists()) {
        return _LegacyPodcastCache(catalog: catalog, meta: meta);
      }
    }
    return null;
  }
}

class _LegacyPodcastCache {
  final File catalog;
  final File meta;

  const _LegacyPodcastCache({required this.catalog, required this.meta});
}

@Riverpod(keepAlive: true)
FeaturedPodcastService featuredPodcastService(Ref ref) {
  return FeaturedPodcastService(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
  );
}

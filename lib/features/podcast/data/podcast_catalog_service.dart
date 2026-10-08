import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
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
import '../models/podcast_catalog.dart';

part 'podcast_catalog_service.g.dart';

sealed class PodcastCatalogRefreshOutcome {
  const PodcastCatalogRefreshOutcome();
}

class PodcastCatalogThrottled extends PodcastCatalogRefreshOutcome {
  const PodcastCatalogThrottled();
}

class PodcastCatalogUnchanged extends PodcastCatalogRefreshOutcome {
  const PodcastCatalogUnchanged();
}

class PodcastCatalogUpdated extends PodcastCatalogRefreshOutcome {
  final PodcastCatalogSnapshot snapshot;

  const PodcastCatalogUpdated(this.snapshot);
}

class PodcastCatalogFailed extends PodcastCatalogRefreshOutcome {
  final Object error;

  const PodcastCatalogFailed(this.error);
}

const _podcastCatalogThrottleWindow = Duration(days: 1);

/// Podcast catalog 的独立缓存与刷新服务。
///
/// 该服务只消费旧有 `/api/v1/catalog` 响应中的 `podcastCatalogs` 字段，
/// 不参与社区合集 v2 的列表、文件或字幕同步。
class PodcastCatalogService {
  final Dio _dio;
  final Future<Directory> Function() _resolveDir;
  late final RefreshCoordinator<String, PodcastCatalogRefreshOutcome> _refresh;

  PodcastCatalogSnapshot? _cached;
  bool _hasInitialized = false;

  PodcastCatalogService({
    required String baseUrl,
    String? appVersion,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = createBackendDio(
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'PODCAST-CATALOG',
       ),
       _resolveDir = _defaultDir {
    _refresh = RefreshCoordinator<String, PodcastCatalogRefreshOutcome>();
  }

  PodcastCatalogService.withDio({
    required Dio dio,
    required Future<Directory> Function() resolveDir,
    RefreshCoordinator<String, PodcastCatalogRefreshOutcome>?
    refreshCoordinator,
  }) : _dio = dio,
       _resolveDir = resolveDir {
    _refresh =
        refreshCoordinator ??
        RefreshCoordinator<String, PodcastCatalogRefreshOutcome>();
  }

  PodcastCatalogSnapshot? get cached => _cached;

  bool get hasInitialized => _hasInitialized;

  static Future<Directory> _defaultDir() async {
    final base = await resolveAppCacheDirectory();
    final directory = Directory(p.join(base.path, 'podcast_catalog'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _catalogFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.json'));

  Future<File> _metaFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.meta.json'));

  /// 启动时读取新缓存，并兼容旧版本的 official_catalog 缓存目录。
  Future<PodcastCatalogSnapshot?> loadCachedCatalog() async {
    try {
      var catalogFile = await _catalogFile();
      var metaFile = await _metaFile();
      if (!await catalogFile.exists() || !await metaFile.exists()) {
        final legacy = await _findLegacyCache();
        if (legacy == null) {
          _hasInitialized = true;
          return null;
        }
        final target = await _resolveDir();
        await target.create(recursive: true);
        await catalogFile.writeAsBytes(await legacy.catalog.readAsBytes());
        await metaFile.writeAsBytes(await legacy.meta.readAsBytes());
      }

      final meta = jsonDecode(await metaFile.readAsString());
      final body = jsonDecode(await catalogFile.readAsString());
      if (meta is! Map<String, dynamic> || body is! Map<String, dynamic>) {
        throw const FormatException('Invalid podcast catalog cache');
      }
      final snapshot = _snapshotFromJson(
        body,
        contentHash: meta['contentHash'] as String? ?? '',
        fetchedAt: DateTime.parse(meta['lastFetchedAt'] as String),
      );
      _cached = snapshot;
      _hasInitialized = true;
      return snapshot;
    } catch (error) {
      AppLogger.log('PodcastCatalog', 'cache load failed: $error');
      _hasInitialized = true;
      return null;
    }
  }

  Future<PodcastCatalogRefreshOutcome> refresh({bool force = false}) {
    return _refresh
        .run(
          key: 'podcast-catalog',
          force: force,
          lastRefreshedAt: _cached?.fetchedAt,
          throttleWindow: _podcastCatalogThrottleWindow,
          refresh: _doRefresh,
        )
        .then(
          (result) => switch (result) {
            RefreshThrottled<PodcastCatalogRefreshOutcome>() =>
              const PodcastCatalogThrottled(),
            RefreshCompleted<PodcastCatalogRefreshOutcome>(:final result) =>
              result,
          },
        );
  }

  Future<PodcastCatalogRefreshOutcome> _doRefresh() async {
    try {
      final response = await _dio.get<String>(
        '/api/v1/catalog',
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null || body.isEmpty) {
        return PodcastCatalogFailed(StateError('empty response'));
      }

      final hash = sha256.convert(utf8.encode(body)).toString();
      final oldHash = _cached?.contentHash;
      final now = DateTime.now();
      if (hash == oldHash && _cached != null) {
        await _writeMeta(hash: hash, fetchedAt: now);
        _cached = PodcastCatalogSnapshot(
          podcasts: _cached!.podcasts,
          contentHash: hash,
          fetchedAt: now,
        );
        return const PodcastCatalogUnchanged();
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const PodcastCatalogFailed(
          FormatException('Invalid podcast catalog response'),
        );
      }
      final snapshot = _snapshotFromJson(
        decoded,
        contentHash: hash,
        fetchedAt: now,
      );
      await (await _catalogFile()).writeAsString(body);
      await _writeMeta(hash: hash, fetchedAt: now);
      _cached = snapshot;
      _hasInitialized = true;
      return PodcastCatalogUpdated(snapshot);
    } catch (error, stackTrace) {
      AppLogger.log('PodcastCatalog', 'refresh failed: $error');
      AppLogger.log('PodcastCatalog', stackTrace.toString());
      return PodcastCatalogFailed(error);
    }
  }

  PodcastCatalogSnapshot _snapshotFromJson(
    Map<String, dynamic> json, {
    required String contentHash,
    required DateTime fetchedAt,
  }) {
    final raw = json['podcastCatalogs'];
    final podcasts = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => PodcastCatalogItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <PodcastCatalogItem>[];
    return PodcastCatalogSnapshot(
      podcasts: podcasts,
      contentHash: contentHash,
      fetchedAt: fetchedAt,
    );
  }

  Future<void> _writeMeta({
    required String hash,
    required DateTime fetchedAt,
  }) async {
    final file = await _metaFile();
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
PodcastCatalogService podcastCatalogService(Ref ref) {
  return PodcastCatalogService(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
  );
}

@Riverpod(keepAlive: true)
PodcastCatalogSnapshot? cachedPodcastCatalog(Ref ref) {
  return ref.read(podcastCatalogServiceProvider).cached;
}

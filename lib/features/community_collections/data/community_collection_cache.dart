import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/app_logger.dart';
import '../../../services/refresh_coordinator.dart';
import '../../../utils/app_data_dir.dart';
import '../models/community_collection_models.dart';
import '../models/community_collection_paging.dart';
import 'community_collection_api.dart';

const _logTag = 'CommunityCollectionCatalog';
const _cacheVersion = 4;
const _legacyDiscoveryCacheKey = 'community_collection_discovery_v2';
const _firstPageKey = 'first';

/// 社区合集 catalog 刷新结果。
sealed class CommunityCollectionRefreshOutcome<T> {
  const CommunityCollectionRefreshOutcome();
}

/// 本次刷新命中节流窗口，没有发起网络请求。
class CommunityCollectionRefreshThrottled<T>
    extends CommunityCollectionRefreshOutcome<T> {
  const CommunityCollectionRefreshThrottled();
}

/// 刷新成功。
class CommunityCollectionRefreshUpdated<T>
    extends CommunityCollectionRefreshOutcome<T> {
  final T items;

  const CommunityCollectionRefreshUpdated(this.items);
}

/// 刷新失败；调用方可根据是否已有缓存决定是否降级。
class CommunityCollectionRefreshFailed<T>
    extends CommunityCollectionRefreshOutcome<T> {
  final Object error;
  final StackTrace stackTrace;

  const CommunityCollectionRefreshFailed(this.error, this.stackTrace);
}

class _PageCacheDocument<T> {
  final Map<String, CommunityCollectionCatalogPage<T>> pages;
  final Map<String, DateTime> fetchedAt;

  _PageCacheDocument({required this.pages, required this.fetchedAt});
}

/// 社区合集 catalog 的统一分页缓存与刷新服务。
///
/// 公开合集目录和详情文件元数据都使用同一套 Application Support/cache 下的
/// JSON + meta 文件格式，并通过 [RefreshCoordinator] 合并同页并发请求。
/// 媒体文件与字幕不属于本服务的缓存范围。
class CommunityCollectionCatalogService {
  final CommunityCollectionApi _api;
  final Future<Directory> Function() _resolveDir;
  final DateTime Function() _now;
  late final RefreshCoordinator<
    String,
    CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
  >
  _collectionsRefresh;
  late final RefreshCoordinator<
    String,
    CommunityCollectionCatalogPage<CommunityCollectionFile>
  >
  _filesRefresh;

  _PageCacheDocument<PublicCollectionCatalogEntry>? _collectionsDocument;
  final _filesDocuments =
      <String, _PageCacheDocument<CommunityCollectionFile>>{};
  bool _collectionsLoaded = false;
  final _filesLoaded = <String>{};
  Future<void> _collectionsWriteTail = Future<void>.value();
  final _filesWriteTails = <String, Future<void>>{};

  CommunityCollectionCatalogService({
    required CommunityCollectionApi api,
    Future<Directory> Function()? resolveDir,
    DateTime Function()? now,
    RefreshCoordinator<
      String,
      CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
    >?
    collectionsRefresh,
    RefreshCoordinator<
      String,
      CommunityCollectionCatalogPage<CommunityCollectionFile>
    >?
    filesRefresh,
  }) : _api = api,
       _resolveDir = resolveDir ?? _defaultDir,
       _now = now ?? DateTime.now {
    _collectionsRefresh =
        collectionsRefresh ??
        RefreshCoordinator<
          String,
          CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
        >(now: _now);
    _filesRefresh =
        filesRefresh ??
        RefreshCoordinator<
          String,
          CommunityCollectionCatalogPage<CommunityCollectionFile>
        >(now: _now);
  }

  /// 读取公开合集指定页面的缓存；不存在或损坏时返回 null。
  Future<CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>?>
  loadCachedCollectionsPage({required String? cursor}) async {
    await _ensureCollectionsDocument();
    return _collectionsDocument?.pages[_pageKey(cursor)];
  }

  /// 读取指定合集文件指定页面的缓存；空页面仍返回非 null 页面。
  Future<CommunityCollectionCatalogPage<CommunityCollectionFile>?>
  loadCachedFilesPage(String remoteId, {required String? cursor}) async {
    await _ensureFilesDocument(remoteId);
    return _filesDocuments[remoteId]?.pages[_pageKey(cursor)];
  }

  /// 刷新公开合集的单个页面；一次只发起一个 API 请求。
  Future<
    CommunityCollectionRefreshOutcome<
      CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
    >
  >
  refreshCollectionsPage({required String? cursor, bool force = false}) async {
    await _ensureCollectionsDocument();
    final normalizedCursor = _normalizeCursor(cursor);
    final pageKey = _pageKey(normalizedCursor);
    try {
      final result = await _collectionsRefresh.run(
        key: 'collections:$pageKey',
        force: force,
        lastRefreshedAt: null,
        throttleWindow: Duration.zero,
        refresh: () async {
          final response = await _api.getCollections(cursor: normalizedCursor);
          final page =
              CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>(
                cursor: normalizedCursor,
                items: response.items,
                nextCursor: _normalizeCursor(response.nextCursor),
              );
          await _writeCollectionsPage(page, fetchedAt: _now());
          return page;
        },
      );
      return switch (result) {
        RefreshThrottled<
          CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
        >() =>
          const CommunityCollectionRefreshThrottled(),
        RefreshCompleted<
          CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
        >(
          :final result,
        ) =>
          CommunityCollectionRefreshUpdated(result),
      };
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'collections page refresh failed cursor=$normalizedCursor error=$error',
      );
      AppLogger.log(_logTag, stackTrace.toString());
      return CommunityCollectionRefreshFailed<
        CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>
      >(error, stackTrace);
    }
  }

  /// 刷新指定合集文件的单个页面；一次只发起一个 API 请求。
  Future<
    CommunityCollectionRefreshOutcome<
      CommunityCollectionCatalogPage<CommunityCollectionFile>
    >
  >
  refreshFilesPage(
    String remoteId, {
    required String? cursor,
    bool force = false,
  }) async {
    await _ensureFilesDocument(remoteId);
    final normalizedCursor = _normalizeCursor(cursor);
    final pageKey = _pageKey(normalizedCursor);
    try {
      final result = await _filesRefresh.run(
        key: 'files:$remoteId:$pageKey',
        force: force,
        lastRefreshedAt: null,
        throttleWindow: Duration.zero,
        refresh: () async {
          final response = await _api.getCollectionDetail(
            remoteId,
            cursor: normalizedCursor,
          );
          final page = CommunityCollectionCatalogPage<CommunityCollectionFile>(
            cursor: normalizedCursor,
            collection: response.collection,
            items: response.items,
            nextCursor: _normalizeCursor(response.nextCursor),
          );
          await _writeFilesPage(remoteId, page, fetchedAt: _now());
          return page;
        },
      );
      return switch (result) {
        RefreshThrottled<
          CommunityCollectionCatalogPage<CommunityCollectionFile>
        >() =>
          const CommunityCollectionRefreshThrottled(),
        RefreshCompleted<
          CommunityCollectionCatalogPage<CommunityCollectionFile>
        >(
          :final result,
        ) =>
          CommunityCollectionRefreshUpdated(result),
      };
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'files page refresh failed remoteId=$remoteId '
        'cursor=$normalizedCursor error=$error',
      );
      AppLogger.log(_logTag, stackTrace.toString());
      return CommunityCollectionRefreshFailed<
        CommunityCollectionCatalogPage<CommunityCollectionFile>
      >(error, stackTrace);
    }
  }

  static Future<Directory> _defaultDir() async {
    final base = await resolveAppCacheDirectory();
    final directory = Directory(
      p.join(base.path, 'community_collection_catalog'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _collectionsFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.json'));

  Future<File> _collectionsMetaFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.meta.json'));

  Future<Directory> _filesDirectory() async {
    final directory = Directory(p.join((await _resolveDir()).path, 'files'));
    await directory.create(recursive: true);
    return directory;
  }

  String _fileCacheStem(String remoteId) =>
      sha256.convert(utf8.encode(remoteId)).toString();

  Future<(File, File)> _filesCacheFiles(String remoteId) async {
    final directory = await _filesDirectory();
    final stem = _fileCacheStem(remoteId);
    return (
      File(p.join(directory.path, '$stem.json')),
      File(p.join(directory.path, '$stem.meta.json')),
    );
  }

  Future<void> _ensureCollectionsDocument() async {
    if (_collectionsLoaded) return;
    try {
      _collectionsDocument = await _readCollectionsDocument();
      if (_collectionsDocument == null) {
        final legacy = await _readLegacyCollectionsPage();
        if (legacy != null) {
          _collectionsDocument = _PageCacheDocument(
            pages: {_firstPageKey: legacy},
            fetchedAt: {_firstPageKey: DateTime.fromMillisecondsSinceEpoch(0)},
          );
          final document = _collectionsDocument;
          if (document != null) {
            await _writeCollectionsDocument(document);
          }
          await (await SharedPreferences.getInstance()).remove(
            _legacyDiscoveryCacheKey,
          );
        }
      }
    } catch (error, stackTrace) {
      AppLogger.log(_logTag, 'collections cache load failed: $error');
      AppLogger.log(_logTag, stackTrace.toString());
      _collectionsDocument = null;
    }
    _collectionsLoaded = true;
  }

  Future<void> _ensureFilesDocument(String remoteId) async {
    if (_filesLoaded.contains(remoteId)) return;
    try {
      final document = await _readFilesDocument(remoteId);
      if (document != null) _filesDocuments[remoteId] = document;
    } catch (error, stackTrace) {
      AppLogger.log(
        _logTag,
        'files cache load failed remoteId=$remoteId error=$error',
      );
      AppLogger.log(_logTag, stackTrace.toString());
      _filesDocuments.remove(remoteId);
    }
    _filesLoaded.add(remoteId);
  }

  Future<_PageCacheDocument<PublicCollectionCatalogEntry>?>
  _readCollectionsDocument() async {
    final file = await _collectionsFile();
    final metaFile = await _collectionsMetaFile();
    if (!await file.exists() || !await metaFile.exists()) return null;
    return _readDocument(
      file: file,
      metaFile: metaFile,
      decodeItem: _decodePublicCollectionCatalogEntry,
    );
  }

  Future<_PageCacheDocument<CommunityCollectionFile>?> _readFilesDocument(
    String remoteId,
  ) async {
    final (file, metaFile) = await _filesCacheFiles(remoteId);
    if (!await file.exists() || !await metaFile.exists()) return null;
    final document = await _readDocument(
      file: file,
      metaFile: metaFile,
      decodeItem: _decodeCommunityCollectionFile,
    );
    if (document == null) {
      final legacy = await _readLegacyFilesPage(file, remoteId);
      if (legacy == null) return null;
      return _PageCacheDocument(
        pages: {_firstPageKey: legacy},
        fetchedAt: {_firstPageKey: DateTime.fromMillisecondsSinceEpoch(0)},
      );
    }
    return document;
  }

  Future<_PageCacheDocument<T>?> _readDocument<T>({
    required File file,
    required File metaFile,
    required T Function(Object? value) decodeItem,
  }) async {
    final body = _decodeObject(await file.readAsString());
    final meta = _decodeObject(await metaFile.readAsString());
    if (body['version'] != _cacheVersion || meta['version'] != _cacheVersion) {
      return null;
    }
    final rawPages = body['pages'];
    final rawMetaPages = meta['pages'];
    if (rawPages is! Map || rawMetaPages is! Map) return null;

    final pages = <String, CommunityCollectionCatalogPage<T>>{};
    for (final entry in rawPages.entries) {
      final key = entry.key;
      final rawPage = entry.value;
      if (key is! String || rawPage is! Map) return null;
      final page = Map<String, Object?>.from(rawPage);
      final rawItems = page['items'];
      if (rawItems is! List) return null;
      pages[key] = CommunityCollectionCatalogPage(
        cursor: _normalizeCursor(_readNullableString(page['cursor'])),
        collection: page['collection'] is Map
            ? _decodePublicCollectionCatalogEntry(page['collection'])
            : null,
        items: rawItems.map(decodeItem).toList(growable: false),
        nextCursor: _normalizeCursor(_readNullableString(page['nextCursor'])),
      );
    }

    final fetchedAt = <String, DateTime>{};
    for (final entry in rawMetaPages.entries) {
      final key = entry.key;
      final rawPageMeta = entry.value;
      if (key is! String || rawPageMeta is! Map) return null;
      final pageMeta = Map<String, Object?>.from(rawPageMeta);
      final value = pageMeta['lastFetchedAt'];
      if (value is! String) return null;
      fetchedAt[key] = DateTime.parse(value);
    }
    if (!pages.keys.every(fetchedAt.containsKey)) return null;
    return _PageCacheDocument(pages: pages, fetchedAt: fetchedAt);
  }

  Future<CommunityCollectionCatalogPage<PublicCollectionCatalogEntry>?>
  _readLegacyCollectionsPage() async {
    final file = await _collectionsFile();
    if (await file.exists()) {
      final body = _decodeObject(await file.readAsString());
      final rawItems = body['collections'];
      if (body['version'] != _cacheVersion && rawItems is List) {
        return CommunityCollectionCatalogPage(
          cursor: null,
          items: rawItems
              .map(_decodePublicCollectionCatalogEntry)
              .toList(growable: false),
          nextCursor: null,
        );
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_legacyDiscoveryCacheKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return CommunityCollectionCatalogPage(
      cursor: null,
      items: decoded
          .map(_decodePublicCollectionCatalogEntry)
          .toList(growable: false),
      nextCursor: null,
    );
  }

  Future<CommunityCollectionCatalogPage<CommunityCollectionFile>?>
  _readLegacyFilesPage(File file, String remoteId) async {
    final body = _decodeObject(await file.readAsString());
    if (body['remoteId'] != remoteId) return null;
    final rawItems = body['files'];
    if (body['version'] == _cacheVersion || rawItems is! List) return null;
    return CommunityCollectionCatalogPage(
      cursor: null,
      items: rawItems
          .map(_decodeCommunityCollectionFile)
          .toList(growable: false),
      nextCursor: null,
    );
  }

  Future<void> _writeCollectionsPage(
    CommunityCollectionCatalogPage<PublicCollectionCatalogEntry> page, {
    required DateTime fetchedAt,
  }) async {
    await _ensureCollectionsDocument();
    final document =
        _collectionsDocument ??
        _PageCacheDocument<PublicCollectionCatalogEntry>(
          pages: {},
          fetchedAt: {},
        );
    _setPage(document, page, fetchedAt: fetchedAt);
    _collectionsDocument = document;
    await _writeCollectionsDocument(document);
  }

  Future<void> _writeFilesPage(
    String remoteId,
    CommunityCollectionCatalogPage<CommunityCollectionFile> page, {
    required DateTime fetchedAt,
  }) async {
    await _ensureFilesDocument(remoteId);
    final document =
        _filesDocuments[remoteId] ??
        _PageCacheDocument<CommunityCollectionFile>(pages: {}, fetchedAt: {});
    _setPage(document, page, fetchedAt: fetchedAt);
    _filesDocuments[remoteId] = document;
    await _writeFilesDocument(remoteId, document);
  }

  void _setPage<T>(
    _PageCacheDocument<T> document,
    CommunityCollectionCatalogPage<T> page, {
    required DateTime fetchedAt,
  }) {
    final key = _pageKey(page.cursor);
    document.pages[key] = page;
    document.fetchedAt[key] = fetchedAt;
    _pruneDisconnectedPages(document);
  }

  void _pruneDisconnectedPages<T>(_PageCacheDocument<T> document) {
    final first = document.pages[_firstPageKey];
    if (first == null) return;

    final reachable = <String>{_firstPageKey};
    var cursor = first.nextCursor;
    while (cursor != null && cursor.isNotEmpty) {
      final key = _pageKey(cursor);
      if (!reachable.add(key)) break;
      final page = document.pages[key];
      if (page == null) break;
      cursor = page.nextCursor;
    }

    document.pages.removeWhere((key, _) => !reachable.contains(key));
    document.fetchedAt.removeWhere((key, _) => !reachable.contains(key));
  }

  Future<void> _writeCollectionsDocument(
    _PageCacheDocument<PublicCollectionCatalogEntry> document,
  ) async {
    final previous = _collectionsWriteTail;
    final write = previous.then<void>(
      (_) => _writeCollectionsDocumentNow(document),
    );
    _collectionsWriteTail = write.catchError((_) {});
    await write;
  }

  Future<void> _writeCollectionsDocumentNow(
    _PageCacheDocument<PublicCollectionCatalogEntry> document,
  ) async {
    final file = await _collectionsFile();
    final metaFile = await _collectionsMetaFile();
    await file.parent.create(recursive: true);
    final body = jsonEncode({
      'version': _cacheVersion,
      'pages': _encodePages(document.pages),
    });
    await file.writeAsString(body);
    await metaFile.writeAsString(
      jsonEncode({
        'version': _cacheVersion,
        'contentHash': sha256.convert(utf8.encode(body)).toString(),
        'pages': _encodePageMeta(document.fetchedAt),
      }),
    );
  }

  Future<void> _writeFilesDocument(
    String remoteId,
    _PageCacheDocument<CommunityCollectionFile> document,
  ) async {
    final previous = _filesWriteTails[remoteId] ?? Future<void>.value();
    final write = previous.then<void>(
      (_) => _writeFilesDocumentNow(remoteId, document),
    );
    _filesWriteTails[remoteId] = write.catchError((_) {});
    await write;
  }

  Future<void> _writeFilesDocumentNow(
    String remoteId,
    _PageCacheDocument<CommunityCollectionFile> document,
  ) async {
    final (file, metaFile) = await _filesCacheFiles(remoteId);
    final body = jsonEncode({
      'version': _cacheVersion,
      'remoteId': remoteId,
      'pages': _encodePages(document.pages),
    });
    await file.writeAsString(body);
    await metaFile.writeAsString(
      jsonEncode({
        'version': _cacheVersion,
        'contentHash': sha256.convert(utf8.encode(body)).toString(),
        'pages': _encodePageMeta(document.fetchedAt),
      }),
    );
  }

  Map<String, Object?> _encodePages<T>(
    Map<String, CommunityCollectionCatalogPage<T>> pages,
  ) {
    return pages.map(
      (key, page) => MapEntry(key, {
        'cursor': page.cursor,
        'collection': page.collection?.toJson(),
        'nextCursor': page.nextCursor,
        'items': page.items.map(_encodeItem).toList(growable: false),
      }),
    );
  }

  Object? _encodeItem<T>(T item) {
    return switch (item) {
      final PublicCollectionCatalogEntry catalogEntry => catalogEntry.toJson(),
      final CommunityCollectionFile file => file.toJson(),
      _ => throw StateError('Unsupported community catalog item'),
    };
  }

  Map<String, Object?> _encodePageMeta(Map<String, DateTime> fetchedAt) {
    return fetchedAt.map(
      (key, value) => MapEntry(key, {'lastFetchedAt': value.toIso8601String()}),
    );
  }

  String _pageKey(String? cursor) {
    final normalized = _normalizeCursor(cursor);
    if (normalized == null) return _firstPageKey;
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String? _normalizeCursor(String? cursor) {
    final value = cursor?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

Map<String, Object?> _decodeObject(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) throw const FormatException('Expected JSON object');
  return Map<String, Object?>.from(decoded);
}

String? _readNullableString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  throw const FormatException('Expected nullable string');
}

PublicCollectionCatalogEntry _decodePublicCollectionCatalogEntry(
  Object? value,
) {
  if (value is! Map) {
    throw const FormatException('Invalid collection catalog entry');
  }
  return PublicCollectionCatalogEntry.fromJson(
    Map<String, Object?>.from(value),
  );
}

CommunityCollectionFile _decodeCommunityCollectionFile(Object? value) {
  if (value is! Map) throw const FormatException('Invalid collection file');
  return CommunityCollectionFile.fromJson(Map<String, Object?>.from(value));
}

final communityCollectionCatalogServiceProvider =
    Provider<CommunityCollectionCatalogService>((ref) {
      return CommunityCollectionCatalogService(
        api: ref.watch(communityCollectionApiProvider),
      );
    });

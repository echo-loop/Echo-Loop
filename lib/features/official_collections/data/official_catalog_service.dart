import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../analytics/geo_interceptor.dart';
import '../../../config/api_config.dart';
import '../../../services/app_logger.dart';
import '../models/catalog.dart';

part 'official_catalog_service.g.dart';

const _logTag = 'OfficialCatalog';

/// catalog refresh 决策结果。
sealed class CatalogRefreshOutcome {
  const CatalogRefreshOutcome();
}

/// 节流命中（距上次成功 refresh < 10 分钟），未发请求。
class CatalogThrottled extends CatalogRefreshOutcome {
  const CatalogThrottled();
}

/// 发了请求；body sha256 与上次一致，本地文件**未改写**。
/// 调用方应整链路跳过：不 reload provider、不 diff、不 invalidate UI。
class CatalogUnchanged extends CatalogRefreshOutcome {
  const CatalogUnchanged();
}

/// 发了请求；内容变化，本地文件已更新。
/// 调用方应 reload catalog provider + 对所有已加入合集做 diff。
class CatalogUpdated extends CatalogRefreshOutcome {
  final CatalogSnapshot snapshot;
  const CatalogUpdated(this.snapshot);
}

/// 网络/解析失败，本地文件保留。
class CatalogFailed extends CatalogRefreshOutcome {
  final Object error;
  const CatalogFailed(this.error);
}

/// 节流窗口（10 分钟）。force=true 可绕过。
const _kThrottleWindow = Duration(minutes: 10);

/// 官方合集 catalog 的本地缓存服务。
///
/// 职责：
/// - 拉远端 `/api/v1/catalog` → 计算 body sha256 → 仅在变化时写本地文件
/// - 读本地文件 → 反序列化为 [CatalogSnapshot]
/// - 节流：10 分钟内不重复发请求（force 可绕过）
/// - inflight 防重入：并发 refresh 调用复用同一个 future，
///   保证 5 个触发点（冷启动 / resumed / 详情页 init / Discover init / 下拉刷新）
///   即便重叠触发，最多只发 1 个并发 HTTP
///
/// 文件存储：`<applicationSupport>/official_catalog/`
/// - `catalog.json`：data
/// - `catalog.meta.json`：`{ lastFetchedAt, contentHash, serverTime }`
///
/// 状态唯一来源：[cached] 字段。`cachedCatalogProvider` 只读不写，
/// service 内 cached 变更通过 `ref.invalidate(serviceProvider)` 让 watcher 重 build。
class OfficialCatalogService {
  final Dio _dio;
  Future<Directory> Function() _resolveDir;

  /// service 内存缓存；nullable 表示从未成功加载过。
  CatalogSnapshot? _cached;
  CatalogSnapshot? get cached => _cached;

  /// 是否曾经成功加载过 catalog（含从磁盘读 + 网络拉）。
  /// UI 用此区分 "首次安装等待中" vs "已加载但内容为空"。
  bool _hasInitialized = false;
  bool get hasInitialized => _hasInitialized;

  /// 防重入：并发 refresh 复用同一个 future。
  Future<CatalogRefreshOutcome>? _inflight;

  OfficialCatalogService({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ),
      _resolveDir = _defaultDir {
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
  }

  /// 测试用构造：注入 Dio + 自定义目录。
  OfficialCatalogService.withDio({
    required Dio dio,
    required Future<Directory> Function() resolveDir,
  }) : _dio = dio,
       _resolveDir = resolveDir;

  static Future<Directory> _defaultDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'official_catalog'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _catalogFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.json'));
  Future<File> _metaFile() async =>
      File(p.join((await _resolveDir()).path, 'catalog.meta.json'));

  /// 启动时调一次：尝试从磁盘加载已缓存的 catalog 到内存。
  /// 失败（文件不存在 / 解析错误）静默返回 null。
  Future<CatalogSnapshot?> loadCachedCatalog() async {
    try {
      final metaFile = await _metaFile();
      final catalogFile = await _catalogFile();
      if (!await metaFile.exists() || !await catalogFile.exists()) {
        return null;
      }
      final metaJson =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final body = await catalogFile.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final collections = (json['collections'] as List? ?? const [])
          .map((e) => CatalogCollection.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

      final snapshot = CatalogSnapshot(
        collections: collections,
        contentHash: metaJson['contentHash'] as String? ?? '',
        fetchedAt: DateTime.parse(metaJson['lastFetchedAt'] as String),
      );
      _cached = snapshot;
      _hasInitialized = true;
      AppLogger.log(
        _logTag,
        'loadCachedCatalog ok: collections=${collections.length} fetchedAt=${snapshot.fetchedAt}',
      );
      return snapshot;
    } catch (e) {
      AppLogger.log(
        _logTag,
        'loadCachedCatalog failed (treat as no cache): $e',
      );
      _hasInitialized = true; // 解析失败也算 init 完成；避免无限 loading
      return null;
    }
  }

  /// 拉远端 catalog；按 outcome 决定是否更新本地文件。
  ///
  /// - force=false 且距上次 < 10min → throttled
  /// - 已有 inflight → 复用同一个 future
  /// - 网络失败 → failed，本地不动
  /// - body hash 与上次一致 → unchanged，仅刷新 lastFetchedAt
  /// - body hash 变化 → updated，写文件 + 更新 _cached + _hasInitialized
  Future<CatalogRefreshOutcome> refresh({bool force = false}) {
    final existing = _inflight;
    if (existing != null) {
      AppLogger.log(_logTag, 'refresh: reusing inflight (force=$force)');
      return existing;
    }
    final future = _doRefresh(force: force);
    _inflight = future;
    return future.whenComplete(() => _inflight = null);
  }

  Future<CatalogRefreshOutcome> _doRefresh({required bool force}) async {
    if (!force) {
      final last = _cached?.fetchedAt;
      if (last != null && DateTime.now().difference(last) < _kThrottleWindow) {
        return const CatalogThrottled();
      }
    }

    final Response<String> response;
    try {
      response = await _dio.get<String>(
        '/api/v1/catalog',
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      AppLogger.log(_logTag, 'refresh network failed: $e');
      return CatalogFailed(e);
    }

    final body = response.data;
    if (body == null || body.isEmpty) {
      return CatalogFailed(StateError('empty response'));
    }

    final newHash = sha256.convert(utf8.encode(body)).toString();
    final oldHash = _cached?.contentHash;
    final now = DateTime.now();

    if (newHash == oldHash) {
      // 仅更新 meta.lastFetchedAt（让 10min 节流以"上次发请求"为基准）
      // 不重写 catalog.json，文件 mtime 不变
      try {
        await _writeMeta(
          contentHash: newHash,
          lastFetchedAt: now,
          serverTime: _readServerTime(body),
        );
      } catch (e) {
        AppLogger.log(_logTag, 'refresh meta write failed (ignored): $e');
      }
      _cached = CatalogSnapshot(
        collections: _cached?.collections ?? const [],
        contentHash: newHash,
        fetchedAt: now,
      );
      AppLogger.log(_logTag, 'refresh unchanged');
      return const CatalogUnchanged();
    }

    // body 变化：写文件 + 更新 cached
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final collections = (json['collections'] as List? ?? const [])
          .map((e) => CatalogCollection.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

      await (await _catalogFile()).writeAsString(body);
      await _writeMeta(
        contentHash: newHash,
        lastFetchedAt: now,
        serverTime: json['serverTime'] as String? ?? now.toIso8601String(),
      );

      final snapshot = CatalogSnapshot(
        collections: collections,
        contentHash: newHash,
        fetchedAt: now,
      );
      _cached = snapshot;
      _hasInitialized = true;
      AppLogger.log(
        _logTag,
        'refresh updated: collections=${collections.length}',
      );
      return CatalogUpdated(snapshot);
    } catch (e) {
      AppLogger.log(_logTag, 'refresh parse/write failed: $e');
      return CatalogFailed(e);
    }
  }

  Future<void> _writeMeta({
    required String contentHash,
    required DateTime lastFetchedAt,
    required String serverTime,
  }) async {
    final meta = {
      'contentHash': contentHash,
      'lastFetchedAt': lastFetchedAt.toIso8601String(),
      'serverTime': serverTime,
    };
    await (await _metaFile()).writeAsString(jsonEncode(meta));
  }

  String _readServerTime(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['serverTime'] as String? ?? DateTime.now().toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }
}

/// catalog service Provider（keepAlive；进程内单例）。
@Riverpod(keepAlive: true)
OfficialCatalogService officialCatalogService(Ref ref) {
  return OfficialCatalogService(baseUrl: apiBaseUrl);
}

/// catalog 内存快照 provider。
///
/// 只读 service.cached；不直接持有数据。service 通过
/// `ref.invalidate(officialCatalogServiceProvider)` 触发重 build。
/// 注意：实际场景中我们也通过更直接的方式让 watcher 更新 — 见 sync service。
@Riverpod(keepAlive: true)
CatalogSnapshot? cachedCatalog(Ref ref) {
  // 注意：这里 read 而非 watch，service 是单例，不会被 invalidate；
  // 实际触发重 build 是通过 ref.invalidate(cachedCatalogProvider) 在 sync 完成后。
  return ref.read(officialCatalogServiceProvider).cached;
}

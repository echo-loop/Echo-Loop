import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../providers/learning_settings_provider.dart'
    show sharedPreferencesProvider;
import '../../../services/app_logger.dart';
import '../../../services/refresh_coordinator.dart';
import '../models/community_collection_models.dart';
import 'community_collection_api.dart';
import 'community_file_lifecycle.dart';

part 'community_sync_service.g.dart';

/// 社区合集同步结果，供日志、启动流程和测试使用。
sealed class CommunitySyncOutcome {
  const CommunitySyncOutcome();
}

/// 成功完成一次远端同步；部分合集失败时仍返回此结果，保证其它合集继续更新。
class CommunitySyncCompleted extends CommunitySyncOutcome {
  final int collectionsScanned;
  final int collectionsDeprecated;
  final int collectionsUndeprecated;
  final int filesAdded;
  final int filesRemoved;
  final int filesMarkedUnavailable;
  final int failedCollections;
  final int failedFiles;

  const CommunitySyncCompleted({
    required this.collectionsScanned,
    required this.collectionsDeprecated,
    required this.collectionsUndeprecated,
    required this.filesAdded,
    required this.filesRemoved,
    this.filesMarkedUnavailable = 0,
    this.failedCollections = 0,
    this.failedFiles = 0,
  });
}

/// 没有合集需要执行远端同步时返回该结果。
class CommunitySyncThrottled extends CommunitySyncOutcome {
  const CommunitySyncThrottled();
}

/// 没有订阅社区合集时跳过网络同步。
class CommunitySyncSkipped extends CommunitySyncOutcome {
  const CommunitySyncSkipped();
}

/// 网络或数据解析失败；本地缓存继续可用。
class CommunitySyncFailed extends CommunitySyncOutcome {
  final Object error;

  const CommunitySyncFailed(this.error);
}

class _CommunityCollectionSnapshot {
  final PublicCollectionCatalogEntry collection;
  final List<CommunityCollectionFile> files;

  const _CommunityCollectionSnapshot({
    required this.collection,
    required this.files,
  });
}

/// 社区合集本地缓存与 v2 远端数据的协调层。
class CommunitySyncService {
  final db.AppDatabase _db;
  final CommunityCollectionApi _api;
  final CommunityFileLifecycleService _fileLifecycle;
  final SharedPreferences? _preferences;
  final DateTime Function() _now;
  late final RefreshCoordinator<String, CommunitySyncOutcome> _refresh;
  Future<void> _syncQueue = Future<void>.value();

  static const throttleWindow = Duration(hours: 2);
  static const _legacyLastSyncAtKey = 'community_collection_last_sync_at_v2';
  static const _collectionLastSyncAtKeyPrefix =
      'community_collection_last_sync_at_v2:';

  CommunitySyncService({
    required db.AppDatabase database,
    required CommunityCollectionApi api,
    CommunityFileLifecycleService? fileLifecycle,
    SharedPreferences? preferences,
    DateTime Function()? now,
  }) : _db = database,
       _api = api,
       _fileLifecycle =
           fileLifecycle ?? CommunityFileLifecycleService(database: database),
       _preferences = preferences,
       _now = now ?? DateTime.now {
    _refresh = RefreshCoordinator<String, CommunitySyncOutcome>(now: _now);
  }

  /// 同一时刻只允许一个全量同步；后台逐个检查合集的 2 小时基线。
  /// [force] 会绕过基线并刷新全部合集。
  Future<CommunitySyncOutcome> syncAll({bool force = false}) {
    return _refresh
        .run(
          key: force
              ? 'community-subscriptions-forced'
              : 'community-subscriptions-background',
          // 全量入口每次都需扫描订阅列表；是否请求远端由单合集基线决定。
          force: true,
          lastRefreshedAt: null,
          throttleWindow: Duration.zero,
          refresh: () => _serializeSync(() => _runSyncAll(force: force)),
        )
        .then((result) {
          return switch (result) {
            RefreshThrottled<CommunitySyncOutcome>() =>
              const CommunitySyncThrottled(),
            RefreshCompleted<CommunitySyncOutcome>(:final result) => result,
          };
        });
  }

  /// 强制同步单个本地合集，并只重置该合集自己的自动同步基线。
  Future<CommunitySyncOutcome> syncCollection(String localCollectionId) {
    return _refresh
        .run(
          key: 'community-collection:$localCollectionId',
          force: true,
          lastRefreshedAt: null,
          throttleWindow: Duration.zero,
          refresh: () =>
              _serializeSync(() => _runSyncCollection(localCollectionId)),
        )
        .then((result) {
          return switch (result) {
            RefreshThrottled<CommunitySyncOutcome>() =>
              const CommunitySyncThrottled(),
            RefreshCompleted<CommunitySyncOutcome>(:final result) => result,
          };
        });
  }

  /// 全量同步与单合集同步共用串行队列，避免并发写入同一批本地数据。
  Future<T> _serializeSync<T>(Future<T> Function() action) async {
    final previous = _syncQueue;
    final completer = Completer<void>();
    _syncQueue = completer.future;
    try {
      await previous;
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// 读取合集独立基线；缺少时兼容旧版全局时间戳或加入合集的时间。
  DateTime _lastSyncAt(db.Collection local) {
    final collectionMillis = _preferences?.getInt(
      _collectionLastSyncAtKey(local.id),
    );
    if (collectionMillis != null) {
      return DateTime.fromMillisecondsSinceEpoch(collectionMillis);
    }

    final legacyMillis = _preferences?.getInt(_legacyLastSyncAtKey);
    if (legacyMillis == null) return local.createdDate;
    final legacyLastSyncAt = DateTime.fromMillisecondsSinceEpoch(legacyMillis);
    return local.createdDate.isAfter(legacyLastSyncAt)
        ? local.createdDate
        : legacyLastSyncAt;
  }

  /// 成功后只持久化当前合集的刷新时间，不影响其它合集。
  Future<void> _recordCollectionSyncAt(String localCollectionId) async {
    final stored = await _preferences?.setInt(
      _collectionLastSyncAtKey(localCollectionId),
      _now().millisecondsSinceEpoch,
    );
    if (stored == false) {
      throw StateError(
        'Failed to persist community collection sync baseline '
        'for $localCollectionId',
      );
    }
  }

  String _collectionLastSyncAtKey(String localCollectionId) =>
      '$_collectionLastSyncAtKeyPrefix$localCollectionId';

  /// 判断单合集是否需要同步；force 忽略基线。
  /// 缺少远端 ID 的失效合集只修复一次。
  bool _shouldSyncCollection(db.Collection local, {required bool force}) {
    if (force) return true;
    if (local.remoteId == null) return local.deprecatedAt == null;
    return _now().difference(_lastSyncAt(local)) >= throttleWindow;
  }

  Future<CommunitySyncOutcome> _runSyncAll({required bool force}) async {
    try {
      final locals =
          await (_db.select(_db.collections)..where(
                (t) => t.source.equals('community') & t.deletedAt.isNull(),
              ))
              .get();
      return await _syncCollections(locals, force: force);
    } catch (error, stackTrace) {
      AppLogger.log('CommunitySync', 'sync failed: $error');
      AppLogger.log('CommunitySync', stackTrace.toString());
      return CommunitySyncFailed(error);
    }
  }

  /// 按本地合集 ID 加载仍有效的社区合集并执行单合集同步。
  Future<CommunitySyncOutcome> _runSyncCollection(
    String localCollectionId,
  ) async {
    try {
      final local =
          await (_db.select(_db.collections)..where(
                (t) =>
                    t.id.equals(localCollectionId) &
                    t.source.equals('community') &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (local == null) return const CommunitySyncSkipped();
      return await _syncCollections([local], force: true);
    } catch (error, stackTrace) {
      AppLogger.log(
        'CommunitySync',
        'single collection sync failed localId=$localCollectionId: $error',
      );
      AppLogger.log('CommunitySync', stackTrace.toString());
      return CommunitySyncFailed(error);
    }
  }

  /// 同步给定的本地社区合集，并汇总每个合集及文件的结果。
  Future<CommunitySyncOutcome> _syncCollections(
    List<db.Collection> locals, {
    required bool force,
  }) async {
    if (locals.isEmpty) return const CommunitySyncSkipped();

    var scanned = 0;
    var deprecated = 0;
    var undeprecated = 0;
    var added = 0;
    var removed = 0;
    var unavailable = 0;
    var failedCollections = 0;
    var failedFiles = 0;

    for (final local in locals) {
      if (!_shouldSyncCollection(local, force: force)) continue;
      scanned++;
      try {
        final remoteId = local.remoteId;
        if (remoteId == null) {
          if (local.deprecatedAt == null) {
            await _markDeprecated(local.id);
            deprecated++;
          }
          continue;
        }

        // 只同步本地已加入的合集；详情第一页的 404 才代表合集已下架。
        final snapshot = await _fetchCollection(remoteId);
        if (snapshot == null) {
          if (local.deprecatedAt == null) {
            await _markDeprecated(local.id);
            deprecated++;
          }
          await _recordCollectionSyncAt(local.id);
          continue;
        }
        if (local.deprecatedAt != null) {
          await _restore(local.id);
          undeprecated++;
        }
        final result = await _applyCollection(
          local,
          snapshot.collection,
          snapshot.files,
        );
        added += result.added;
        removed += result.removed;
        unavailable += result.unavailable;
        failedFiles += result.failedFiles;
        await _recordCollectionSyncAt(local.id);
      } catch (error, stackTrace) {
        failedCollections++;
        AppLogger.log(
          'CommunitySync',
          'collection sync failed localId=${local.id} remoteId=${local.remoteId}: $error',
        );
        AppLogger.log('CommunitySync', stackTrace.toString());
      }
    }

    if (scanned == 0) return const CommunitySyncThrottled();

    return CommunitySyncCompleted(
      collectionsScanned: scanned,
      collectionsDeprecated: deprecated,
      collectionsUndeprecated: undeprecated,
      filesAdded: added,
      filesRemoved: removed,
      filesMarkedUnavailable: unavailable,
      failedCollections: failedCollections,
      failedFiles: failedFiles,
    );
  }

  /// 拉取单个已加入合集的全部详情页；第一页 404 返回 null 表示合集已下架。
  Future<_CommunityCollectionSnapshot?> _fetchCollection(
    String collectionId,
  ) async {
    final result = <CommunityCollectionFile>[];
    late final CommunityCollectionDetailPage firstPage;
    try {
      firstPage = await _api.getCollectionDetail(collectionId);
    } on CommunityCollectionNotFound {
      return null;
    }
    result.addAll(firstPage.items);
    var cursor = firstPage.nextCursor;
    while (cursor?.isNotEmpty ?? false) {
      final page = await _api.getCollectionDetail(collectionId, cursor: cursor);
      result.addAll(page.items);
      cursor = page.nextCursor;
    }
    return _CommunityCollectionSnapshot(
      collection: firstPage.collection,
      files: result,
    );
  }

  Future<void> _markDeprecated(String localId) async {
    final now = _now();
    await (_db.update(
      _db.collections,
    )..where((t) => t.id.equals(localId))).write(
      db.CollectionsCompanion(deprecatedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> _restore(String localId) async {
    await (_db.update(
      _db.collections,
    )..where((t) => t.id.equals(localId))).write(
      db.CollectionsCompanion(
        deprecatedAt: const Value(null),
        source: const Value('community'),
        updatedAt: Value(_now()),
      ),
    );
  }

  /// 复用已存在的远端音频行，并仅为当前合集补充关联。
  Future<_CollectionDiff> _applyCollection(
    db.Collection local,
    PublicCollectionCatalogEntry catalogEntry,
    List<CommunityCollectionFile> files,
  ) async {
    final junctions = await (_db.select(
      _db.collectionAudioItems,
    )..where((t) => t.collectionId.equals(local.id))).get();
    final sortOrderByAudioId = <String, int>{
      for (final junction in junctions)
        junction.audioItemId: junction.sortOrder,
    };
    final audioRows = <String, db.AudioItem>{};
    for (final junction in junctions) {
      final row = await _db.audioItemDao.getById(junction.audioItemId);
      if (row != null && row.deletedAt == null) audioRows[row.id] = row;
    }
    final localByRemoteId = <String, db.AudioItem>{};
    for (final row in audioRows.values) {
      final remoteId = row.remoteAudioId;
      if (remoteId != null) localByRemoteId[remoteId] = row;
    }
    final remoteIds = files.map((file) => file.id).toSet();
    var added = 0;
    var removed = 0;
    var unavailable = 0;
    var failedFiles = 0;

    await _db.transaction(() async {
      for (final file in files) {
        final existingInCollection = localByRemoteId[file.id];
        final alreadyLinked = existingInCollection != null;
        final existingAudio =
            existingInCollection ??
            await _db.audioItemDao.getByRemoteAudioId(file.id);
        late final db.AudioItem audio;

        if (existingAudio == null) {
          final id = const Uuid().v4();
          final now = _now();
          await _db.audioItemDao.upsert(
            db.AudioItemsCompanion(
              id: Value(id),
              name: Value(file.title),
              addedDate: Value(now),
              totalDuration: Value(file.durationSec ?? 0),
              remoteAudioId: Value(file.id),
              originalDate: Value(file.publishedAt),
              communityUnavailableAt: const Value(null),
              communityDifficulty: Value(file.difficulty?.code),
              updatedAt: Value(now),
            ),
          );
          final insertedAudio = await _db.audioItemDao.getById(id);
          if (insertedAudio == null) {
            throw StateError('Inserted community audio $id was not found');
          }
          audio = insertedAudio;
        } else {
          audio = existingAudio;
        }

        if (!alreadyLinked) {
          final now = _now();
          await _db
              .into(_db.collectionAudioItems)
              .insertOnConflictUpdate(
                db.CollectionAudioItemsCompanion(
                  collectionId: Value(local.id),
                  audioItemId: Value(audio.id),
                  sortOrder: Value(file.sortOrder),
                  addedAt: Value(now),
                ),
              );
          added++;
        } else if (sortOrderByAudioId[audio.id] != file.sortOrder) {
          await (_db.update(_db.collectionAudioItems)..where(
                (t) =>
                    t.collectionId.equals(local.id) &
                    t.audioItemId.equals(audio.id),
              ))
              .write(
                db.CollectionAudioItemsCompanion(
                  sortOrder: Value(file.sortOrder),
                ),
              );
        }
        sortOrderByAudioId[audio.id] = file.sortOrder;
        localByRemoteId[file.id] = audio;

        await (_db.update(
          _db.audioItems,
        )..where((t) => t.id.equals(audio.id))).write(
          db.AudioItemsCompanion(
            name: Value(file.title),
            totalDuration: file.durationSec == null
                ? const Value.absent()
                : Value(file.durationSec!),
            originalDate: Value(file.publishedAt),
            communityUnavailableAt: const Value(null),
            communityDifficulty: Value(file.difficulty?.code),
            updatedAt: Value(_now()),
          ),
        );
      }

      await (_db.update(
        _db.collections,
      )..where((t) => t.id.equals(local.id))).write(
        db.CollectionsCompanion(
          source: const Value('community'),
          name: Value(catalogEntry.name),
          description: Value(catalogEntry.description),
          coverUrl: Value(catalogEntry.coverUrl),
          coverUrlChina: Value(catalogEntry.coverUrlChina),
          authorNickname: Value(catalogEntry.authorNickname),
          publishedAt: Value(catalogEntry.publishedAt),
          updatedAt: Value(catalogEntry.updatedAt),
        ),
      );
    });

    for (final row in localByRemoteId.values) {
      if (remoteIds.contains(row.remoteAudioId)) continue;
      try {
        final result = await _fileLifecycle.markUnavailable(
          audioItemId: row.id,
          localCollectionId: local.id,
        );
        switch (result) {
          case CommunityFileRemovalResult.removed:
            removed++;
          case CommunityFileRemovalResult.markedUnavailable:
            unavailable++;
          case CommunityFileRemovalResult.unchanged:
            break;
        }
      } catch (error, stackTrace) {
        failedFiles++;
        AppLogger.log(
          'CommunitySync',
          'file removal failed audioItemId=${row.id}: $error',
        );
        AppLogger.log('CommunitySync', stackTrace.toString());
      }
    }
    return _CollectionDiff(
      added: added,
      removed: removed,
      unavailable: unavailable,
      failedFiles: failedFiles,
    );
  }
}

class _CollectionDiff {
  final int added;
  final int removed;
  final int unavailable;
  final int failedFiles;

  const _CollectionDiff({
    required this.added,
    required this.removed,
    required this.unavailable,
    required this.failedFiles,
  });
}

@Riverpod(keepAlive: true)
CommunitySyncService communitySyncService(Ref ref) {
  return CommunitySyncService(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(communityCollectionApiProvider),
    fileLifecycle: ref.watch(communityFileLifecycleServiceProvider),
    preferences: ref.read(sharedPreferencesProvider),
  );
}

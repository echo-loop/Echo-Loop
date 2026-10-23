import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';
import '../models/community_collection_models.dart';
import 'community_collection_api.dart';

part 'community_collection_repository.g.dart';

const _logTag = 'CommunityCollectionRepo';

/// 已加入过的社区合集冲突；通常由并发 enroll 触发。
class CommunityCollectionAlreadyEnrolledError implements Exception {
  final String remoteId;
  final String localId;

  const CommunityCollectionAlreadyEnrolledError({
    required this.remoteId,
    required this.localId,
  });
}

/// v2 列表中不存在该社区合集，可能已下架。
class CommunityCollectionNotFoundError implements Exception {
  final String remoteId;

  const CommunityCollectionNotFoundError(this.remoteId);
}

class _CommunityCollectionSnapshot {
  final PublicCollectionCatalogEntry collection;
  final List<CommunityCollectionFile> files;

  const _CommunityCollectionSnapshot({
    required this.collection,
    required this.files,
  });
}

/// 社区合集与本地 Drift 数据的协调层。
class CommunityCollectionRepository {
  final db.AppDatabase _db;
  final CommunityCollectionApi _api;
  final Future<Directory> Function() _docsDir;

  CommunityCollectionRepository({
    required db.AppDatabase database,
    required CommunityCollectionApi api,
    Future<Directory> Function()? docsDir,
  }) : _db = database,
       _api = api,
       _docsDir = docsDir ?? getAppDataDirectory;

  /// 拉取 v2 合集及其全部文件后，以事务方式创建本地占位数据。
  ///
  /// 若远端音频已存在于其他合集，则复用该本地音频项并只新增合集关联。
  Future<String> enroll(String remoteId) async {
    final existing = await _db.collectionDao.getByRemoteId(remoteId);
    if (existing != null) {
      throw CommunityCollectionAlreadyEnrolledError(
        remoteId: remoteId,
        localId: existing.id,
      );
    }

    final snapshot = await _fetchCollection(remoteId);
    final catalogEntry = snapshot.collection;
    final localCollectionId = const Uuid().v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.collectionDao.upsert(
        db.CollectionsCompanion(
          id: Value(localCollectionId),
          name: Value(catalogEntry.name),
          createdDate: Value(now),
          updatedAt: Value(catalogEntry.updatedAt),
          source: const Value('community'),
          remoteId: Value(catalogEntry.id),
          coverUrl: Value(catalogEntry.coverUrl),
          coverUrlChina: Value(catalogEntry.coverUrlChina),
          description: Value(catalogEntry.description),
          authorNickname: Value(catalogEntry.authorNickname),
          publishedAt: Value(catalogEntry.publishedAt),
        ),
      );
      for (final file in snapshot.files) {
        final existingAudio = await _db.audioItemDao.getByRemoteAudioId(
          file.id,
        );
        final audioId = existingAudio?.id ?? const Uuid().v4();
        if (existingAudio == null) {
          await _db.audioItemDao.upsert(
            db.AudioItemsCompanion(
              id: Value(audioId),
              name: Value(file.title),
              addedDate: Value(now),
              totalDuration: Value(file.durationSec ?? 0),
              remoteAudioId: Value(file.id),
              originalDate: Value(file.publishedAt),
              communityDifficulty: Value(file.difficulty?.code),
              updatedAt: Value(now),
            ),
          );
        } else {
          await (_db.update(
            _db.audioItems,
          )..where((row) => row.id.equals(audioId))).write(
            db.AudioItemsCompanion(
              communityDifficulty: Value(file.difficulty?.code),
              updatedAt: Value(now),
            ),
          );
        }
        await _db
            .into(_db.collectionAudioItems)
            .insertOnConflictUpdate(
              db.CollectionAudioItemsCompanion(
                collectionId: Value(localCollectionId),
                audioItemId: Value(audioId),
                sortOrder: Value(file.sortOrder),
                addedAt: Value(now),
              ),
            );
      }
    });
    AppLogger.log(_logTag, 'enrolled $remoteId as $localCollectionId');
    return localCollectionId;
  }

  /// 彻底移除社区合集及其未共享的本地媒体和学习数据。
  Future<void> remove(String localCollectionId) async {
    final orphanedAudioRows = <db.AudioItem>[];
    await _db.transaction(() async {
      final audioIds = await _db.collectionDao.getAudioIds(localCollectionId);
      for (final audioId in audioIds) {
        final audioRow = await _db.audioItemDao.getById(audioId);
        await (_db.delete(_db.collectionAudioItems)..where(
              (row) =>
                  row.collectionId.equals(localCollectionId) &
                  row.audioItemId.equals(audioId),
            ))
            .go();

        final remainingMembership = await (_db.select(
          _db.collectionAudioItems,
        )..where((row) => row.audioItemId.equals(audioId))).getSingleOrNull();
        // 仅在最后一个合集关联移除后清理音频行和对应学习数据。
        if (remainingMembership != null) continue;

        for (final table in [
          'learning_progresses',
          'stage_completions',
          'playback_states',
          'bookmarks',
          'saved_words',
          'saved_sense_groups',
          'audio_item_tags',
        ]) {
          await _db.customStatement(
            'DELETE FROM $table WHERE audio_item_id = ?',
            [audioId],
          );
        }
        await _db.audioItemDao.hardDelete(audioId);
        if (audioRow != null) orphanedAudioRows.add(audioRow);
      }
      await _db.collectionDao.hardDelete(localCollectionId);
    });
    await _deleteLocalFiles(orphanedAudioRows);
  }

  Future<_CommunityCollectionSnapshot> _fetchCollection(String remoteId) async {
    final files = <CommunityCollectionFile>[];
    CommunityCollectionDetailPage firstPage;
    try {
      firstPage = await _api.getCollectionDetail(remoteId);
    } on CommunityCollectionNotFound {
      throw CommunityCollectionNotFoundError(remoteId);
    }
    files.addAll(firstPage.items);
    var cursor = firstPage.nextCursor;
    while (cursor?.isNotEmpty ?? false) {
      final page = await _api.getCollectionDetail(remoteId, cursor: cursor);
      files.addAll(page.items);
      cursor = page.nextCursor;
    }
    return _CommunityCollectionSnapshot(
      collection: firstPage.collection,
      files: files,
    );
  }

  Future<void> _deleteLocalFiles(List<db.AudioItem> rows) async {
    if (rows.isEmpty) return;
    final dir = await _docsDir();
    for (final row in rows) {
      for (final relativePath in [row.audioPath, row.transcriptPath]) {
        if (relativePath == null) continue;
        try {
          final file = File(p.join(dir.path, relativePath));
          if (await file.exists()) await file.delete();
        } catch (error) {
          AppLogger.log(_logTag, 'failed to delete $relativePath: $error');
        }
      }
    }
  }
}

@Riverpod(keepAlive: true)
CommunityCollectionRepository communityCollectionRepository(Ref ref) {
  return CommunityCollectionRepository(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(communityCollectionApiProvider),
  );
}

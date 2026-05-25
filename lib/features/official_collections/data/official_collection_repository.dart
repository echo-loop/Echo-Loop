import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';
import '../models/catalog.dart';
import 'official_catalog_service.dart';

part 'official_collection_repository.g.dart';

const _logTag = 'OfficialRepo';

/// 已加入过（当前仍在本地）的合集冲突；通常由并发 enroll 触发。
class AlreadyEnrolledError implements Exception {
  final String remoteId;
  final String localId;
  const AlreadyEnrolledError({required this.remoteId, required this.localId});
  @override
  String toString() =>
      'AlreadyEnrolledError(remoteId=$remoteId, localId=$localId)';
}

/// catalog 还没拉到本地（首次安装、文件被清等）。UI 应引导用户下拉刷新。
class CatalogNotInitializedError implements Exception {
  const CatalogNotInitializedError();
  @override
  String toString() => 'CatalogNotInitializedError';
}

/// catalog 中查不到该 remoteId（运营下架了或从未发布）。
class OfficialCollectionNotFoundInCatalog implements Exception {
  final String remoteId;
  const OfficialCollectionNotFoundInCatalog(this.remoteId);
  @override
  String toString() => 'OfficialCollectionNotFoundInCatalog($remoteId)';
}

/// 官方合集与本地 Drift 数据的协调层。
///
/// 职责：
/// - [enroll]：拉 detail → 落 collections + audio_items + junction（事务原子）
/// - [remove]：删该合集的所有本地数据（含关联 learning_progresses 等）+ 清文件
///
/// 不负责：下载音频/字幕（由 Stage 4 的 `OfficialDownloadNotifier` 处理）；
/// 不负责：UI 状态（由 Stage 3 的 enrollment provider 包装调用这里的方法）。
class OfficialCollectionRepository {
  final db.AppDatabase _db;
  final OfficialCatalogService _catalog;
  final Future<Directory> Function() _docsDir;

  OfficialCollectionRepository({
    required db.AppDatabase database,
    required OfficialCatalogService catalog,
    Future<Directory> Function()? docsDir,
  }) : _db = database,
       _catalog = catalog,
       _docsDir = docsDir ?? getAppDataDirectory;

  /// 把官方合集加入用户的 Collections 列表。
  ///
  /// **不发网络请求**：从本地 catalog 缓存读 detail 直接落库。
  /// catalog 必须先 init（启动时由 syncAll 触发）；UI 通过 `hasInitialized`
  /// 区分 "首次安装等待中" 和 "已加载但合集不存在"。
  ///
  /// 行为：
  /// - 若 remoteId 已存在 source='official' 活跃行 → 抛 [AlreadyEnrolledError]
  /// - catalog 未初始化 → 抛 [CatalogNotInitializedError]
  /// - catalog 中无 remoteId → 抛 [OfficialCollectionNotFoundInCatalog]
  /// - 音频占位行：`audioPath` / `transcriptPath` 均为 NULL（未下载），
  ///   下载完成时由 download notifier 一次写入实际路径
  Future<String> enroll(String remoteId) async {
    AppLogger.log(_logTag, 'enroll pre-check remoteId=$remoteId');
    final existing = await _db.collectionDao.getByRemoteId(remoteId);
    if (existing != null) {
      AppLogger.log(
        _logTag,
        'enroll rejected: already enrolled localId=${existing.id}',
      );
      throw AlreadyEnrolledError(remoteId: remoteId, localId: existing.id);
    }

    if (!_catalog.hasInitialized) {
      AppLogger.log(_logTag, 'enroll rejected: catalog not initialized');
      throw const CatalogNotInitializedError();
    }
    final snapshot = _catalog.cached;
    final CatalogCollection? detail = snapshot?.collections
        .where((c) => c.id == remoteId)
        .cast<CatalogCollection?>()
        .firstWhere((_) => true, orElse: () => null);
    if (detail == null) {
      AppLogger.log(
        _logTag,
        'enroll rejected: catalog has no such remoteId=$remoteId',
      );
      throw OfficialCollectionNotFoundInCatalog(remoteId);
    }

    AppLogger.log(
      _logTag,
      'enroll catalog-hit: name="${detail.name}", audios=${detail.audios.length}',
    );
    final localCollectionId = const Uuid().v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.collectionDao.upsert(
        db.CollectionsCompanion(
          id: Value(localCollectionId),
          name: Value(detail.name),
          createdDate: Value(now),
          isPinned: const Value(false),
          updatedAt: Value(now),
          source: const Value('official'),
          remoteId: Value(detail.id),
          coverUrl: Value(detail.coverUrl),
          description: Value(detail.description),
        ),
      );

      for (final audio in detail.audios) {
        final localAudioId = const Uuid().v4();
        await _db.audioItemDao.upsert(
          db.AudioItemsCompanion(
            id: Value(localAudioId),
            name: Value(audio.title),
            // audioPath / transcriptPath 保持 NULL，下载成功时再写入
            addedDate: Value(now),
            totalDuration: Value(audio.durationSec),
            sentenceCount: const Value(0),
            wordCount: const Value(0),
            isPinned: const Value(false),
            transcriptSource: const Value(null),
            audioSha256: Value(audio.sha256),
            remoteAudioId: Value(audio.id),
            originalDate: Value(audio.originalDate),
            updatedAt: Value(now),
          ),
        );
        await _db.collectionDao.addAudio(localCollectionId, localAudioId);
      }
    });

    AppLogger.log(
      _logTag,
      'enroll inserted localId=$localCollectionId (audios=${detail.audios.length})',
    );
    return localCollectionId;
  }

  /// 彻底移除官方合集：
  /// 1. 查出所有 audio_items id
  /// 2. 事务内级联清理 learning_progresses / bookmarks / saved_words /
  ///    saved_sense_groups / playback_states / stage_completions / audio_item_tags /
  ///    collection_audio_items 等所有按 audioItemId 关联的表
  /// 3. 事务成功后删本地音频/字幕文件
  ///
  /// 对于下载中的任务（Stage 4）调用方负责先 cancel，这里只负责 DB + 文件清理。
  Future<void> remove(String localCollectionId) async {
    AppLogger.log(_logTag, 'remove start localId=$localCollectionId');
    final audioIds = await _db.collectionDao.getAudioIds(localCollectionId);
    AppLogger.log(_logTag, 'remove has ${audioIds.length} audios to clean');
    final audioRows = <db.AudioItem>[];
    for (final id in audioIds) {
      final row = await _db.audioItemDao.getById(id);
      if (row != null) audioRows.add(row);
    }

    await _db.transaction(() async {
      for (final audioId in audioIds) {
        // learning_progresses / stage_completions / playback_states /
        // bookmarks / saved_words / saved_sense_groups / audio_item_tags
        // 都没有提供"按 audioItemId 硬删"的直接接口，
        // 通过 customStatement 执行 DELETE 更干脆；每张表若不存在数据则无副作用。
        await _db.customStatement(
          'DELETE FROM learning_progresses WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM stage_completions WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM playback_states WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM bookmarks WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM saved_words WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM saved_sense_groups WHERE audio_item_id = ?',
          [audioId],
        );
        await _db.customStatement(
          'DELETE FROM audio_item_tags WHERE audio_item_id = ?',
          [audioId],
        );
      }

      await _db.customStatement(
        'DELETE FROM collection_audio_items WHERE collection_id = ?',
        [localCollectionId],
      );

      for (final audioId in audioIds) {
        await _db.audioItemDao.hardDelete(audioId);
      }

      await _db.collectionDao.hardDelete(localCollectionId);
    });

    // 事务成功后再清文件；中途失败下次启动 tmp 清理能兜底
    await _deleteLocalFiles(audioRows);
    AppLogger.log(_logTag, 'remove done localId=$localCollectionId');
  }

  /// 删除本合集相关的音频文件和字幕文件。失败静默忽略。
  Future<void> _deleteLocalFiles(List<db.AudioItem> audioRows) async {
    final dir = await _docsDir();
    for (final row in audioRows) {
      final audioPath = row.audioPath;
      if (audioPath != null) {
        try {
          final f = File(p.join(dir.path, audioPath));
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      final transcript = row.transcriptPath;
      if (transcript != null) {
        try {
          final f = File(p.join(dir.path, transcript));
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }
}

@Riverpod(keepAlive: true)
OfficialCollectionRepository officialCollectionRepository(Ref ref) {
  return OfficialCollectionRepository(
    database: ref.watch(appDatabaseProvider),
    catalog: ref.watch(officialCatalogServiceProvider),
  );
}

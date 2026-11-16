import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart' as db;
import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/word_timestamp.dart';
import '../../services/app_logger.dart';
import '../../services/subtitle_parser.dart';
import 'media_trim_clip.dart';

final mediaTrimRepositoryProvider = Provider<MediaTrimRepository>(
  (ref) => MediaTrimRepository(ref.watch(appDatabaseProvider)),
);

/// 剪辑产物的保存位置。
sealed class MediaTrimDestination {
  const MediaTrimDestination();
}

class MediaTrimExistingCollection extends MediaTrimDestination {
  const MediaTrimExistingCollection(this.collectionId);
  final String collectionId;
}

class MediaTrimNewCollection extends MediaTrimDestination {
  const MediaTrimNewCollection(this.name);
  final String name;
}

/// 已生成并校验过文件的新材料，等待整批入库。
class MediaTrimDraft {
  const MediaTrimDraft({
    required this.id,
    required this.name,
    required this.relativePath,
    required this.sha256,
    required this.durationSeconds,
    required this.transcriptSource,
    required this.transcriptLanguage,
    required this.transcriptSrt,
    required this.wordTimestampsJson,
    required this.sentenceCount,
    required this.wordCount,
  });

  final String id;
  final String name;
  final String relativePath;
  final String sha256;
  final int durationSeconds;
  final TranscriptSource? transcriptSource;
  final String? transcriptLanguage;
  final String? transcriptSrt;
  final String? wordTimestampsJson;
  final int sentenceCount;
  final int wordCount;
}

class MediaTrimCommitResult {
  const MediaTrimCommitResult({
    required this.collectionId,
    required this.createdIds,
    required this.reusedIds,
    required this.unusedRelativePaths,
  });

  final String collectionId;
  final List<String> createdIds;

  /// 内容与库中已有材料相同、直接加入合集的已有材料。
  final List<String> reusedIds;

  /// 因复用已有材料而未入库的产物文件，由调用方删除。
  final List<String> unusedRelativePaths;
}

/// 剪辑的数据访问：读取原字幕、单事务发布整批材料、清理未发布的产物目录。
class MediaTrimRepository {
  MediaTrimRepository(this._database);

  final db.AppDatabase _database;

  /// 读取原材料字幕。原材料声明有字幕时，内容缺失或无效都视为失败，不静默当作无字幕。
  Future<(List<Sentence>, List<WordTimestamp>)> loadTranscript(
    AudioItem source,
  ) async {
    if (!source.hasTranscript) {
      return (const <Sentence>[], const <WordTimestamp>[]);
    }
    final dao = _database.audioItemDao;
    final srt = await dao.getTranscriptSrt(source.id);
    if (srt == null || srt.trim().isEmpty) {
      throw const MediaTrimException(MediaTrimFailure.transcriptNotReady);
    }
    final List<Sentence> sentences;
    try {
      sentences = await SubtitleParser.parseSubtitleStrictString(srt);
    } on SubtitleParseException catch (error) {
      throw MediaTrimException(MediaTrimFailure.transcriptInvalid, error);
    }
    final wordsJson = await dao.getWordTimestamps(source.id);
    if (wordsJson == null) return (sentences, const <WordTimestamp>[]);
    final words = decodeWordTimestamps(wordsJson);
    if (words == null) {
      throw const MediaTrimException(MediaTrimFailure.transcriptInvalid);
    }
    return (sentences, words);
  }

  /// 可作为保存目标的本地合集；播客和社区合集由各自来源管理，不接收剪辑产物。
  Future<List<db.Collection>> localCollections() async {
    final collections = await _database.collectionDao.getAllActive();
    return [
      for (final collection in collections)
        if (collection.source == 'local') collection,
    ];
  }

  /// 单事务发布整批材料。任一步失败整体回滚，文件由调用方清理。
  Future<MediaTrimCommitResult> commit({
    required List<MediaTrimDraft> drafts,
    required MediaTrimDestination destination,
  }) => _database.transaction(() async {
    final now = DateTime.now();
    final collectionId = await _resolveCollection(destination, now);
    final createdIds = <String>[];
    final reusedIds = <String>[];
    final unusedPaths = <String>[];
    final memberIds = <String>[];
    for (final draft in drafts) {
      final existing =
          await (_database.select(_database.audioItems)
                ..where(
                  (row) =>
                      row.deletedAt.isNull() &
                      (row.audioSha256.equals(draft.sha256) |
                          row.originalAudioSha256.equals(draft.sha256)),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        reusedIds.add(existing.id);
        unusedPaths.add(draft.relativePath);
        if (!memberIds.contains(existing.id)) memberIds.add(existing.id);
        continue;
      }
      await _database.into(_database.audioItems).insert(_companion(draft, now));
      createdIds.add(draft.id);
      memberIds.add(draft.id);
    }
    await _database.collectionDao.addAudios(collectionId, memberIds);
    return MediaTrimCommitResult(
      collectionId: collectionId,
      createdIds: createdIds,
      reusedIds: reusedIds,
      unusedRelativePaths: unusedPaths,
    );
  });

  Future<String> _resolveCollection(
    MediaTrimDestination destination,
    DateTime now,
  ) async {
    switch (destination) {
      case MediaTrimNewCollection(:final name):
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          throw const MediaTrimException(MediaTrimFailure.collectionNameEmpty);
        }
        final id = const Uuid().v4();
        await _database
            .into(_database.collections)
            .insert(
              db.CollectionsCompanion.insert(
                id: id,
                name: trimmed,
                createdDate: now,
                updatedAt: now,
              ),
            );
        return id;
      case MediaTrimExistingCollection(:final collectionId):
        final target = await _database.collectionDao.getById(collectionId);
        if (target == null ||
            target.deletedAt != null ||
            target.source != 'local') {
          throw const MediaTrimException(MediaTrimFailure.invalidCollection);
        }
        return collectionId;
    }
  }

  db.AudioItemsCompanion _companion(MediaTrimDraft draft, DateTime now) =>
      db.AudioItemsCompanion.insert(
        id: draft.id,
        name: draft.name,
        audioPath: Value(draft.relativePath),
        addedDate: now,
        updatedAt: now,
        totalDuration: Value(draft.durationSeconds),
        audioSha256: Value(draft.sha256),
        originalAudioSha256: Value(draft.sha256),
        importSourceType: Value(AudioImportSourceType.trimmed.storageValue),
        transcriptSource: Value(draft.transcriptSource?.index),
        transcriptLanguage: Value(draft.transcriptLanguage),
        transcriptSrt: Value(draft.transcriptSrt),
        wordTimestampsJson: Value(draft.wordTimestampsJson),
        sentenceCount: Value(draft.sentenceCount),
        wordCount: Value(draft.wordCount),
      );

  /// 删除没有任何数据库引用（含软删记录）的剪辑任务目录。
  ///
  /// 与 [commit] 走同一数据库事务串行：要么在发布前执行（任务目录仍处于活动状态被跳过），
  /// 要么在发布后执行（已被引用而保留），不会误删刚发布的文件。
  Future<int> cleanupUncommitted({
    required Directory dataDirectory,
    required bool Function(String directoryPath) isActive,
  }) => _database.transaction(() async {
    final references = await _database.audioItemDao.getAllReferencedRelPaths();
    var removed = 0;
    for (final media in ['audios', 'videos']) {
      final root = Directory(p.join(dataDirectory.path, media, 'trimmed'));
      if (!await root.exists()) continue;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory || isActive(entity.path)) continue;
        final relative = p.relative(entity.path, from: dataDirectory.path);
        if (references.any((path) => p.isWithin(relative, path))) continue;
        await entity.delete(recursive: true);
        removed++;
      }
    }
    if (removed > 0) {
      AppLogger.log('MediaTrim', '启动清理未发布的剪辑目录 count=$removed');
    }
    return removed;
  });
}

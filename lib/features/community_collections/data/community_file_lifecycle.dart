import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../database/app_database.dart' as db;
import '../../../database/providers.dart';
import '../../../services/app_logger.dart';
import '../../../utils/app_data_dir.dart';

part 'community_file_lifecycle.g.dart';

/// 远端社区文件消失后的本地处理结果。
enum CommunityFileRemovalResult {
  /// 没有学习记录，条目和当前合集关联已删除。
  removed,

  /// 有学习记录，保留条目但标记为不可用。
  markedUnavailable,

  /// 条目不存在、当前关联已处理，或音频仍由其它合集引用。
  unchanged,
}

/// 负责处理社区文件下架、媒体清理和本地不可用状态。
///
/// 数据库状态先完成原子更新，磁盘清理采用 best effort，避免一个文件的 IO
/// 异常中断其它合集同步。重新出现的文件由同步服务清除不可用状态。
class CommunityFileLifecycleService {
  final db.AppDatabase _db;
  final Future<Directory> Function() _dataDir;

  CommunityFileLifecycleService({
    required db.AppDatabase database,
    Future<Directory> Function()? dataDir,
  }) : _db = database,
       _dataDir = dataDir ?? getAppDataDirectory;

  /// 标记某个本地合集中的远端文件已下架。
  Future<CommunityFileRemovalResult> markUnavailable({
    required String audioItemId,
    required String localCollectionId,
  }) async {
    final row = await _db.audioItemDao.getById(audioItemId);
    if (row == null) return CommunityFileRemovalResult.unchanged;

    final learningDataExists = await _hasLearningData(audioItemId);
    final junctions = await (_db.select(
      _db.collectionAudioItems,
    )..where((table) => table.audioItemId.equals(audioItemId))).get();
    final hasOtherCollectionReference = junctions.any(
      (junction) => junction.collectionId != localCollectionId,
    );
    final referencedAudioPath = row.audioPath;
    final audioPathUsedElsewhere =
        referencedAudioPath != null &&
        (await (_db.select(_db.audioItems)..where(
                  (item) =>
                      item.id.isNotValue(audioItemId) &
                      item.audioPath.equals(referencedAudioPath),
                ))
                .get())
            .isNotEmpty;

    final now = DateTime.now();
    final shouldRemoveRow = !learningDataExists && !hasOtherCollectionReference;
    await _db.transaction(() async {
      if (hasOtherCollectionReference) {
        await (_db.delete(_db.collectionAudioItems)..where(
              (table) =>
                  table.collectionId.equals(localCollectionId) &
                  table.audioItemId.equals(audioItemId),
            ))
            .go();
        return;
      }

      if (shouldRemoveRow) {
        await (_db.delete(_db.collectionAudioItems)..where(
              (table) =>
                  table.collectionId.equals(localCollectionId) &
                  table.audioItemId.equals(audioItemId),
            ))
            .go();
        await _deleteLearningData(audioItemId);
        await _db.audioItemDao.hardDelete(audioItemId);
        return;
      }

      await (_db.update(
        _db.audioItems,
      )..where((item) => item.id.equals(audioItemId))).write(
        db.AudioItemsCompanion(
          audioPath: const Value(null),
          audioContentStatus: const Value(null),
          originalAudioSha256: const Value(null),
          communityUnavailableAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });

    if (shouldRemoveRow) {
      await _deleteFiles(row, deleteTranscript: true);
      return CommunityFileRemovalResult.removed;
    }
    if (hasOtherCollectionReference) {
      // 共享音频仍可由其它合集使用，只解除当前合集关联并保留全局状态。
      return CommunityFileRemovalResult.unchanged;
    }

    if (!audioPathUsedElsewhere) {
      await _deleteFiles(row, deleteTranscript: false);
    }
    return CommunityFileRemovalResult.markedUnavailable;
  }

  Future<bool> _hasLearningData(String audioItemId) async {
    for (final table in [
      'learning_progresses',
      'stage_completions',
      'playback_states',
      'bookmarks',
      'saved_words',
      'saved_sense_groups',
    ]) {
      final rows = await _db
          .customSelect(
            'SELECT 1 FROM $table WHERE audio_item_id = ? LIMIT 1',
            variables: [Variable<String>(audioItemId)],
          )
          .get();
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _deleteLearningData(String audioItemId) async {
    for (final table in [
      'learning_progresses',
      'stage_completions',
      'playback_states',
      'bookmarks',
      'saved_words',
      'saved_sense_groups',
      'audio_item_tags',
    ]) {
      await _db.customStatement('DELETE FROM $table WHERE audio_item_id = ?', [
        audioItemId,
      ]);
    }
  }

  Future<void> _deleteFiles(
    db.AudioItem row, {
    required bool deleteTranscript,
  }) async {
    final directory = await _dataDir();
    final paths = <String?>[
      row.audioPath,
      if (deleteTranscript) row.transcriptPath,
    ];
    for (final relativePath in paths) {
      if (relativePath == null || relativePath.isEmpty) continue;
      try {
        final file = File(p.join(directory.path, relativePath));
        if (await file.exists()) await file.delete();
      } catch (error) {
        AppLogger.log(
          'CommunityFileLifecycle',
          'failed to delete local file $relativePath: $error',
        );
      }
    }
  }
}

@Riverpod(keepAlive: true)
CommunityFileLifecycleService communityFileLifecycleService(Ref ref) {
  return CommunityFileLifecycleService(
    database: ref.watch(appDatabaseProvider),
  );
}

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/audio_items.dart';

part 'audio_item_dao.g.dart';

/// 音频元数据 DAO
/// 提供音频项的 CRUD 操作
@DriftAccessor(tables: [AudioItems])
class AudioItemDao extends DatabaseAccessor<AppDatabase>
    with _$AudioItemDaoMixin {
  AudioItemDao(super.db);

  /// 获取所有未删除的音频项
  Future<List<AudioItem>> getAllActive() {
    return (select(audioItems)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.addedDate)]))
        .get();
  }

  /// 监听所有未删除的音频项
  Stream<List<AudioItem>> watchAllActive() {
    return (select(audioItems)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.addedDate)]))
        .watch();
  }

  /// 根据 ID 获取音频项
  Future<AudioItem?> getById(String id) {
    return (select(
      audioItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入或更新音频项
  Future<void> upsert(AudioItemsCompanion entry) {
    return into(audioItems).insertOnConflictUpdate(entry);
  }

  /// 批量插入音频项（用于迁移）
  Future<void> batchInsert(List<AudioItemsCompanion> entries) async {
    await batch((b) {
      b.insertAll(audioItems, entries, mode: InsertMode.insertOrReplace);
    });
  }

  /// 软删除音频项
  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (update(audioItems)..where((t) => t.id.equals(id))).write(
      AudioItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: Value(2), // pendingDelete
      ),
    );
  }

  /// 硬删除音频项（真正从数据库移除）
  Future<void> hardDelete(String id) {
    return (delete(audioItems)..where((t) => t.id.equals(id))).go();
  }

  /// 获取指定音频的词级时间戳 JSON
  ///
  /// 独立查询，避免列表加载时读取大 JSON 字段。
  Future<String?> getWordTimestamps(String audioItemId) async {
    final query = select(audioItems)
      ..where((t) => t.id.equals(audioItemId));
    final row = await query.getSingleOrNull();
    return row?.wordTimestampsJson;
  }

  /// 更新词级时间戳（独立更新，不影响其他字段）
  Future<void> updateWordTimestamps(String audioItemId, String? json) {
    return (update(audioItems)..where((t) => t.id.equals(audioItemId))).write(
      AudioItemsCompanion(wordTimestampsJson: Value(json)),
    );
  }
}

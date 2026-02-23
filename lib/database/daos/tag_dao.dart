import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tags.dart';
import '../tables/audio_item_tags.dart';

part 'tag_dao.g.dart';

/// 标签 DAO
/// 提供标签的 CRUD 操作及标签-音频关联管理
@DriftAccessor(tables: [Tags, AudioItemTags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  /// 获取所有未删除的标签
  Future<List<Tag>> getAllActive() {
    return (select(tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdDate)]))
        .get();
  }

  /// 根据 ID 获取标签
  Future<Tag?> getById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 插入或更新标签
  Future<void> upsert(TagsCompanion entry) {
    return into(tags).insertOnConflictUpdate(entry);
  }

  /// 软删除标签
  Future<void> softDelete(String id) {
    final now = DateTime.now();
    return (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: Value(2),
      ),
    );
  }

  /// 硬删除标签
  Future<void> hardDelete(String id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  // --- Junction 表操作 ---

  /// 获取标签关联的所有音频 ID 列表
  Future<List<String>> getAudioIds(String tagId) async {
    final rows =
        await (select(audioItemTags)..where((t) => t.tagId.equals(tagId)))
            .get();
    return rows.map((r) => r.audioItemId).toList();
  }

  /// 添加音频到标签
  Future<void> addAudio(String tagId, String audioItemId) async {
    await into(audioItemTags).insertOnConflictUpdate(
      AudioItemTagsCompanion(
        tagId: Value(tagId),
        audioItemId: Value(audioItemId),
        addedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 从标签中移除音频
  Future<void> removeAudio(String tagId, String audioItemId) {
    return (delete(audioItemTags)..where(
          (t) => t.tagId.equals(tagId) & t.audioItemId.equals(audioItemId),
        ))
        .go();
  }

  /// 从所有标签中移除指定音频（当音频被删除时调用）
  Future<void> removeAudioFromAll(String audioItemId) {
    return (delete(audioItemTags)
          ..where((t) => t.audioItemId.equals(audioItemId)))
        .go();
  }
}

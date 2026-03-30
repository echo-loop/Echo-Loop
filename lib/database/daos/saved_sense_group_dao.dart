import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/saved_sense_groups.dart';

part 'saved_sense_group_dao.g.dart';

/// 收藏意群 DAO
///
/// 提供收藏意群的 CRUD 操作，支持流式监听。
/// 与 [SavedWordDao] 独立，各自管理各自的数据。
@DriftAccessor(tables: [SavedSenseGroups])
class SavedSenseGroupDao extends DatabaseAccessor<AppDatabase>
    with _$SavedSenseGroupDaoMixin {
  SavedSenseGroupDao(super.db);

  /// 监听所有未删除的收藏意群（按收藏时间倒序）
  Stream<List<SavedSenseGroup>> watchAll() {
    return (select(savedSenseGroups)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 保存意群（先到先得：已存在且未删除时只更新 updatedAt）
  ///
  /// [phraseText] 必须是归一化后的文本（小写 + trim + 去句末标点）。
  /// [displayText] 保留原始大小写，用于展示。
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) {
    final now = DateTime.now();
    return into(savedSenseGroups).insert(
      SavedSenseGroupsCompanion(
        phraseText: Value(phraseText),
        displayText: Value(displayText),
        audioItemId: Value(audioItemId),
        sentenceIndex: Value(sentenceIndex),
        sentenceText: Value(sentenceText),
        sentenceStartMs: Value(sentenceStartMs),
        sentenceEndMs: Value(sentenceEndMs),
        groupStartMs: Value(groupStartMs),
        groupEndMs: Value(groupEndMs),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      onConflict: DoUpdate(
        (old) => SavedSenseGroupsCompanion(
          // 先到先得：不覆盖来源信息，只更新时间和恢复软删除
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
        target: [savedSenseGroups.phraseText],
      ),
    );
  }

  /// 移除收藏意群（软删除）
  Future<void> removeSenseGroup(String phraseText) {
    return (update(savedSenseGroups)
          ..where((t) => t.phraseText.equals(phraseText)))
        .write(
      SavedSenseGroupsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// 查询意群是否已收藏
  Future<bool> isSenseGroupSaved(String phraseText) async {
    final row = await (select(savedSenseGroups)
          ..where(
            (t) => t.phraseText.equals(phraseText) & t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// 流式监听意群是否已收藏
  Stream<bool> watchIsSenseGroupSaved(String phraseText) {
    return (select(savedSenseGroups)
          ..where(
            (t) => t.phraseText.equals(phraseText) & t.deletedAt.isNull(),
          )
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  /// 监听所有已收藏意群的归一化文本集合（用于 badge 染色）
  Stream<Set<String>> watchSavedPhraseTexts() {
    return watchAll().map(
      (list) => list.map((e) => e.phraseText).toSet(),
    );
  }

  /// 清除指定音频关联的上下文信息
  Future<void> clearContextForAudio(String audioItemId) {
    return (update(savedSenseGroups)
          ..where((t) => t.audioItemId.equals(audioItemId)))
        .write(
      const SavedSenseGroupsCompanion(
        sentenceIndex: Value(null),
        sentenceText: Value(null),
      ),
    );
  }
}

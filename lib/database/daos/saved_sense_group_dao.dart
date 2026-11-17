import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/sentence.dart';
import '../../services/source_sentence_anchor.dart';
import '../app_database.dart';
import '../tables/saved_sense_groups.dart';
import 'bookmark_dao.dart' show RecycleBinSortMode;

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

  /// 获取所有未删除的收藏意群。
  Future<List<SavedSenseGroup>> getAll() =>
      (select(savedSenseGroups)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// 按唯一意群文本查询收藏记录，包含回收站中的软删除记录。
  ///
  /// 收藏—调度生命周期需要先读取稳定的 [SavedSenseGroup.memorySubjectId]，
  /// 才能对同一张记忆调度快照执行归档或恢复。
  Future<SavedSenseGroup?> getByPhraseText(String phraseText) => (select(
    savedSenseGroups,
  )..where((t) => t.phraseText.equals(phraseText))).getSingleOrNull();

  /// 获取指定音频关联的未删除收藏意群（按来源句时间升序）
  ///
  /// 用于学习材料导出 PDF 时将收藏意群归到所属句子。
  Future<List<SavedSenseGroup>> getByAudioId(String audioItemId) {
    return (select(savedSenseGroups)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sentenceStartMs)]))
        .get();
  }

  /// 保存意群（先到先得：已存在且未删除时只更新 updatedAt）
  ///
  /// [phraseText] 必须是归一化后的文本（小写 + trim + 去句末标点）。
  /// [displayText] 保留原始大小写，用于展示。
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
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
        memorySubjectId: Value(const Uuid().v4()),
        displayText: Value(displayText),
        audioItemId: Value(audioItemId),
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
        .write(SavedSenseGroupsCompanion(deletedAt: Value(DateTime.now())));
  }

  /// 查询意群是否已收藏
  Future<bool> isSenseGroupSaved(String phraseText) async {
    final row =
        await (select(savedSenseGroups)
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
          ..where((t) => t.phraseText.equals(phraseText) & t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  /// 监听所有已收藏意群的归一化文本集合（用于 badge 染色与正文收藏标记）
  ///
  /// 只查 phraseText 一列（Set 无序，不需 orderBy）；内容级去重——练习
  /// 统计等与 key 无关的表写入不会向下游重发相同集合。
  Stream<Set<String>> watchSavedPhraseTexts() {
    final query = selectOnly(savedSenseGroups)
      ..addColumns([savedSenseGroups.phraseText])
      ..where(savedSenseGroups.deletedAt.isNull());
    return query
        .watch()
        .map(
          (rows) => rows
              .map((r) => r.read(savedSenseGroups.phraseText))
              .whereType<String>()
              .toSet(),
        )
        .distinct(const SetEquality<String>().equals);
  }

  /// 字幕替换后，把来源为该音频的收藏意群（含回收站）的来源句改写为当前字幕中
  /// 对应那一句的文字与区间；定位不到（来源句已删除）的保持原样。
  ///
  /// 只依据收藏自身的来源句区间，重复执行结果不变。返回改写的条数。
  Future<int> relinkSourceSentences(
    String audioItemId,
    List<Sentence> sentences,
  ) async {
    final rows = await (select(
      savedSenseGroups,
    )..where((t) => t.audioItemId.equals(audioItemId))).get();
    final now = DateTime.now();
    var relinked = 0;
    await batch((batch) {
      for (final row in rows) {
        final index = resolveVocabularySourceSentenceIndex(
          SourceSentenceAnchor.fromMilliseconds(
            startMs: row.sentenceStartMs,
            endMs: row.sentenceEndMs,
          ),
          sentences,
          row.phraseText,
        );
        if (index == null) continue;
        final target = sentences[index];
        final startMs = target.startTime.inMilliseconds;
        final endMs = target.endTime.inMilliseconds;
        if (row.sentenceText == target.text &&
            row.sentenceStartMs == startMs &&
            row.sentenceEndMs == endMs) {
          continue;
        }
        batch.update(
          savedSenseGroups,
          SavedSenseGroupsCompanion(
            sentenceText: Value(target.text),
            sentenceStartMs: Value(startMs),
            sentenceEndMs: Value(endMs),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(row.id),
        );
        relinked++;
      }
    });
    return relinked;
  }

  /// 更新 Flashcard 练习统计
  ///
  /// 每次翻转到背面时调用：practiceCount +1，累加学习时长，
  /// 标记已翻看背面，记录练习时间。
  Future<void> updatePracticeStats({
    required String phraseText,
    required int studyMs,
  }) async {
    final clampedMs = studyMs.clamp(0, 60000);
    await customStatement(
      '''
      UPDATE saved_sense_groups
      SET practice_count = practice_count + 1,
          total_study_ms = total_study_ms + ?,
          viewed_back = 1,
          last_practiced_at = ?,
          updated_at = ?
      WHERE phrase_text = ? AND deleted_at IS NULL
    ''',
      [
        clampedMs,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        phraseText,
      ],
    );
    // customStatement 不会自动通知 stream watcher，手动触发
    attachedDatabase.notifyUpdates({
      TableUpdate.onTable(savedSenseGroups, kind: UpdateKind.update),
    });
  }

  /// 清除指定音频关联的上下文信息
  ///
  /// 音频删除时调用，将非 FK 字段全部置 NULL。
  /// audioItemId 由 FK SET NULL 自动处理。
  Future<void> clearContextForAudio(String audioItemId) {
    return clearContextForAudios({audioItemId});
  }

  /// 批量清除多个音频关联的上下文信息。
  ///
  /// 必须在删除 `audio_items` 前执行；否则 FK SET NULL 后将无法再按
  /// audioItemId 定位这些冗余上下文字段。
  Future<void> clearContextForAudios(Set<String> audioItemIds) {
    if (audioItemIds.isEmpty) return Future.value();
    return (update(
      savedSenseGroups,
    )..where((t) => t.audioItemId.isIn(audioItemIds))).write(
      const SavedSenseGroupsCompanion(
        sentenceText: Value(null),
        sentenceStartMs: Value(null),
        sentenceEndMs: Value(null),
        groupStartMs: Value(null),
        groupEndMs: Value(null),
      ),
    );
  }

  /// 获取所有已软删除的意群
  ///
  /// 用于回收站弹窗展示。
  Future<List<SavedSenseGroup>> getDeletedSenseGroups({
    required RecycleBinSortMode sortMode,
  }) {
    return (select(savedSenseGroups)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) => _buildDeletedOrdering(t, sortMode),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// 恢复已软删除的意群（清除 deletedAt）
  Future<void> restoreSenseGroup(String phraseText) {
    return (update(
      savedSenseGroups,
    )..where((t) => t.phraseText.equals(phraseText))).write(
      SavedSenseGroupsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 永久删除单个已软删除的意群
  Future<void> permanentlyDeleteSenseGroup(String phraseText) {
    return (delete(savedSenseGroups)..where(
          (t) => t.phraseText.equals(phraseText) & t.deletedAt.isNotNull(),
        ))
        .go();
  }

  /// 永久删除所有已软删除的意群（清空回收站）
  Future<void> permanentlyDeleteAllDeleted() {
    return (delete(
      savedSenseGroups,
    )..where((t) => t.deletedAt.isNotNull())).go();
  }

  /// 构建回收站排序条件
  OrderingTerm _buildDeletedOrdering(
    $SavedSenseGroupsTable t,
    RecycleBinSortMode sortMode,
  ) {
    return switch (sortMode) {
      RecycleBinSortMode.timeDesc => OrderingTerm.desc(t.deletedAt),
      RecycleBinSortMode.timeAsc => OrderingTerm.asc(t.deletedAt),
      RecycleBinSortMode.alphaAsc => OrderingTerm.asc(t.displayText),
      RecycleBinSortMode.alphaDesc => OrderingTerm.desc(t.displayText),
    };
  }
}

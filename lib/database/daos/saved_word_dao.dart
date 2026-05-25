import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/saved_words.dart';
import 'bookmark_dao.dart' show RecycleBinSortMode;

part 'saved_word_dao.g.dart';

/// 收藏单词 DAO
///
/// 提供收藏单词的 CRUD 操作，支持流式监听。
@DriftAccessor(tables: [SavedWords])
class SavedWordDao extends DatabaseAccessor<AppDatabase>
    with _$SavedWordDaoMixin {
  SavedWordDao(super.db);

  /// 监听所有未删除的收藏单词（按收藏时间倒序）
  Stream<List<SavedWord>> watchAll() {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// 获取所有未删除的收藏单词
  Future<List<SavedWord>> getAll() {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// 保存单词（冲突时更新来源信息和更新时间）
  ///
  /// [word] 必须是小写 lemmatized 形式。
  /// [audioItemId]、[sentenceIndex]、[sentenceText] 为可选来源信息。
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    int? sentenceIndex,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) {
    final now = DateTime.now();
    return into(savedWords).insert(
      SavedWordsCompanion(
        word: Value(word),
        audioItemId: Value(audioItemId),
        sentenceIndex: Value(sentenceIndex),
        sentenceText: Value(sentenceText),
        sentenceStartMs: Value(sentenceStartMs),
        sentenceEndMs: Value(sentenceEndMs),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      onConflict: DoUpdate(
        (old) => SavedWordsCompanion(
          audioItemId: Value(audioItemId),
          sentenceIndex: Value(sentenceIndex),
          sentenceText: Value(sentenceText),
          sentenceStartMs: Value(sentenceStartMs),
          sentenceEndMs: Value(sentenceEndMs),
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
        target: [savedWords.word],
      ),
    );
  }

  /// 移除收藏单词（软删除，设置 deletedAt）
  Future<void> removeWord(String word) {
    return (update(savedWords)..where((t) => t.word.equals(word))).write(
      SavedWordsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// 查询单词是否已收藏
  Future<bool> isWordSaved(String word) async {
    final row =
        await (select(savedWords)
              ..where((t) => t.word.equals(word) & t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// 清除指定音频关联的上下文信息（音频删除时调用）
  ///
  /// 将 sentenceIndex、sentenceText 和时间信息置 NULL，保留单词本身。
  /// audioItemId 由 FK SET NULL 自动处理，此方法处理非外键字段。
  /// 注意：sentenceStartMs/sentenceEndMs 保留不清除，确保删除字幕后仍可播放。
  Future<void> clearContextForAudio(String audioItemId) {
    return (update(
      savedWords,
    )..where((t) => t.audioItemId.equals(audioItemId))).write(
      const SavedWordsCompanion(
        sentenceIndex: Value(null),
        sentenceText: Value(null),
      ),
    );
  }

  /// 更新 Flashcard 练习统计
  ///
  /// 每次翻转到背面时调用：practiceCount +1，totalStudyMs 累加，
  /// viewedBack 置 true，更新 lastPracticedAt。
  /// [studyMs] 会被截断到 60000ms 防止挂机污染。
  Future<void> updatePracticeStats({
    required String word,
    required int studyMs,
  }) async {
    final clampedMs = studyMs.clamp(0, 60000);
    await customStatement(
      '''
      UPDATE saved_words
      SET practice_count = practice_count + 1,
          total_study_ms = total_study_ms + ?,
          viewed_back = 1,
          last_practiced_at = ?,
          updated_at = ?
      WHERE word = ? AND deleted_at IS NULL
    ''',
      [
        clampedMs,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        word,
      ],
    );
    // customStatement 不会自动通知 stream watcher，手动触发
    attachedDatabase.notifyUpdates({
      TableUpdate.onTable(savedWords, kind: UpdateKind.update),
    });
  }

  /// 监听所有未删除的收藏单词（按指定排序）
  ///
  /// 用于 Flashcard 功能，支持多种排序方式。
  Stream<List<SavedWord>> watchAllSorted({required OrderingMode timeOrder}) {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: timeOrder),
          ]))
        .watch();
  }

  /// 流式监听单词是否已收藏
  Stream<bool> watchIsWordSaved(String word) {
    return (select(savedWords)
          ..where((t) => t.word.equals(word) & t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  /// 获取所有已软删除的单词
  ///
  /// 用于回收站弹窗展示。
  Future<List<SavedWord>> getDeletedWords({
    required RecycleBinSortMode sortMode,
  }) {
    return (select(savedWords)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) => _buildDeletedOrdering(t, sortMode),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// 恢复已软删除的单词（清除 deletedAt）
  Future<void> restoreWord(String word) {
    return (update(savedWords)..where((t) => t.word.equals(word))).write(
      SavedWordsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 永久删除单个已软删除的单词
  Future<void> permanentlyDeleteWord(String word) {
    return (delete(
      savedWords,
    )..where((t) => t.word.equals(word) & t.deletedAt.isNotNull())).go();
  }

  /// 永久删除所有已软删除的单词（清空回收站）
  Future<void> permanentlyDeleteAllDeleted() {
    return (delete(savedWords)..where((t) => t.deletedAt.isNotNull())).go();
  }

  /// 构建回收站排序条件
  OrderingTerm _buildDeletedOrdering(
    $SavedWordsTable t,
    RecycleBinSortMode sortMode,
  ) {
    return switch (sortMode) {
      RecycleBinSortMode.timeDesc => OrderingTerm.desc(t.deletedAt),
      RecycleBinSortMode.timeAsc => OrderingTerm.asc(t.deletedAt),
      RecycleBinSortMode.alphaAsc => OrderingTerm.asc(t.word),
      RecycleBinSortMode.alphaDesc => OrderingTerm.desc(t.word),
    };
  }
}

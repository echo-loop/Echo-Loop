import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/audio_items.dart';
import '../tables/bookmarks.dart';

part 'bookmark_dao.g.dart';

/// 书签 + 音频名称的复合数据类
///
/// 用于 Favorites 页面按音频分组展示收藏句子。
class BookmarkWithAudio {
  /// 书签数据
  final Bookmark bookmark;

  /// 音频名称
  final String audioName;

  const BookmarkWithAudio({required this.bookmark, required this.audioName});
}

/// 回收站排序方式
enum RecycleBinSortMode {
  /// 取消收藏时间倒序（默认）
  timeDesc,

  /// 取消收藏时间正序
  timeAsc,

  /// 字母 A→Z
  alphaAsc,

  /// 字母 Z→A
  alphaDesc,
}

/// 书签 DAO
/// 提供书签的 CRUD 操作
@DriftAccessor(tables: [Bookmarks, AudioItems])
class BookmarkDao extends DatabaseAccessor<AppDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  /// 获取指定音频的所有未删除书签
  Future<List<Bookmark>> getByAudioId(String audioItemId) {
    return (select(bookmarks)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sentenceIndex)]))
        .get();
  }

  /// 监听指定音频的所有未删除书签
  Stream<List<Bookmark>> watchByAudioId(String audioItemId) {
    return (select(bookmarks)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sentenceIndex)]))
        .watch();
  }

  /// 添加书签
  ///
  /// 以 (audioItemId, sentenceIndex) 为冲突键，冲突时更新已有行。
  Future<void> addBookmark(BookmarksCompanion entry) {
    return into(bookmarks).insert(
      entry,
      onConflict: DoUpdate(
        (old) => BookmarksCompanion(
          sentenceText: entry.sentenceText,
          startTime: entry.startTime,
          endTime: entry.endTime,
          updatedAt: entry.updatedAt,
          deletedAt: const Value(null),
          syncStatus: const Value(0),
        ),
        target: [bookmarks.audioItemId, bookmarks.sentenceIndex],
      ),
    );
  }

  /// 批量添加书签（用于迁移）
  Future<void> batchInsert(List<BookmarksCompanion> entries) async {
    await batch((b) {
      b.insertAll(bookmarks, entries, mode: InsertMode.insertOrReplace);
    });
  }

  /// 软删除指定音频的某个书签（通过句子索引）
  ///
  /// 设置 deletedAt 标记而非物理删除，便于未来同步和数据恢复。
  Future<void> removeBookmark(String audioItemId, int sentenceIndex) {
    return (update(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.equals(sentenceIndex),
        ))
        .write(
          BookmarksCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 软删除指定音频的多个书签（通过句子索引集合）
  ///
  /// 设置 deletedAt 标记而非物理删除，便于未来同步和数据恢复。
  Future<void> removeBookmarks(String audioItemId, Set<int> sentenceIndices) {
    return (update(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.isIn(sentenceIndices),
        ))
        .write(
          BookmarksCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 移除指定音频的所有书签
  Future<void> removeAllForAudio(String audioItemId) {
    return (delete(
      bookmarks,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }

  /// 获取指定音频的书签句子索引集合
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async {
    final rows =
        await (select(bookmarks)..where(
              (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
            ))
            .get();
    return rows.map((r) => r.sentenceIndex).toSet();
  }

  /// 获取所有未删除书签的总数
  Future<int> countAll() async {
    final count = bookmarks.id.count();
    final query = selectOnly(bookmarks)
      ..addColumns([count])
      ..where(bookmarks.deletedAt.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// 监听所有未删除书签（含音频名称），按音频分组
  ///
  /// JOIN audio_items 获取音频名称，用于 Favorites 页面展示。
  /// 音频已删除（CASCADE）的书签不会出现在结果中。
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() {
    final query =
        select(bookmarks).join([
            innerJoin(
              audioItems,
              audioItems.id.equalsExp(bookmarks.audioItemId),
            ),
          ])
          ..where(bookmarks.deletedAt.isNull() & audioItems.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.asc(audioItems.name),
            OrderingTerm.asc(bookmarks.sentenceIndex),
          ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return BookmarkWithAudio(
          bookmark: row.readTable(bookmarks),
          audioName: row.readTable(audioItems).name,
        );
      }).toList();
    });
  }

  /// 获取所有已软删除的书签（含音频名称）
  ///
  /// 用于回收站弹窗展示。音频已删除的书签不会出现。
  Future<List<BookmarkWithAudio>> getDeletedBookmarks({
    required RecycleBinSortMode sortMode,
  }) async {
    final query =
        select(bookmarks).join([
            innerJoin(
              audioItems,
              audioItems.id.equalsExp(bookmarks.audioItemId),
            ),
          ])
          ..where(
            bookmarks.deletedAt.isNotNull() & audioItems.deletedAt.isNull(),
          )
          ..orderBy([
            _buildDeletedOrdering(sortMode),
            // 次要排序保证稳定性
            OrderingTerm.desc(bookmarks.id),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return BookmarkWithAudio(
        bookmark: row.readTable(bookmarks),
        audioName: row.readTable(audioItems).name,
      );
    }).toList();
  }

  /// 恢复已软删除的书签（清除 deletedAt）
  Future<void> restoreBookmark(String audioItemId, int sentenceIndex) {
    return (update(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.equals(sentenceIndex),
        ))
        .write(
          BookmarksCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 永久删除单个已软删除的书签
  Future<void> permanentlyDeleteBookmark(
    String audioItemId,
    int sentenceIndex,
  ) {
    return (delete(bookmarks)..where(
          (t) =>
              t.audioItemId.equals(audioItemId) &
              t.sentenceIndex.equals(sentenceIndex) &
              t.deletedAt.isNotNull(),
        ))
        .go();
  }

  /// 永久删除所有已软删除的书签（清空回收站）
  Future<void> permanentlyDeleteAllDeleted() {
    return (delete(bookmarks)..where((t) => t.deletedAt.isNotNull())).go();
  }

  /// 构建回收站排序条件
  OrderingTerm _buildDeletedOrdering(RecycleBinSortMode sortMode) {
    return switch (sortMode) {
      RecycleBinSortMode.timeDesc => OrderingTerm.desc(bookmarks.deletedAt),
      RecycleBinSortMode.timeAsc => OrderingTerm.asc(bookmarks.deletedAt),
      RecycleBinSortMode.alphaAsc => OrderingTerm.asc(bookmarks.sentenceText),
      RecycleBinSortMode.alphaDesc => OrderingTerm.desc(bookmarks.sentenceText),
    };
  }
}

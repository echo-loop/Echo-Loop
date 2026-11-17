import 'package:drift/drift.dart';

import '../../models/sentence.dart';
import '../../services/source_sentence_anchor.dart';
import '../../services/subtitle_parser.dart';
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

/// 书签的收藏区间。
SourceSentenceAnchor anchorOfBookmark(Bookmark bookmark) {
  return SourceSentenceAnchor.fromSeconds(
    startSeconds: bookmark.startTime,
    endSeconds: bookmark.endTime,
  );
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

  /// 获取指定音频的所有未删除书签（按时间排序）
  Future<List<Bookmark>> getByAudioId(String audioItemId) {
    return (select(bookmarks)
          ..where(
            (t) => t.audioItemId.equals(audioItemId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
  }

  /// 按主键读取一条书签（包含回收站内容）。
  Future<Bookmark?> getById(int id) =>
      (select(bookmarks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 按记忆主体读取一条未删除书签。
  Future<Bookmark?> getActiveBySubjectId(String memorySubjectId) =>
      (select(bookmarks)
            ..where(
              (t) =>
                  t.memorySubjectId.equals(memorySubjectId) &
                  t.deletedAt.isNull(),
            )
            ..limit(1))
          .getSingleOrNull();

  /// 读取音频当前字幕的句子列表，作为收藏定位的参照。
  ///
  /// 字幕唯一真相源是 audio_items.transcript_srt；无字幕返回空列表。
  Future<List<Sentence>> loadCurrentSentences(String audioItemId) async {
    final row =
        await (selectOnly(audioItems)
              ..addColumns([audioItems.transcriptSrt])
              ..where(audioItems.id.equals(audioItemId)))
            .getSingleOrNull();
    final srt = row?.read(audioItems.transcriptSrt);
    if (srt == null || srt.isEmpty) return const [];
    return SubtitleParser.parseSubtitleString(srt);
  }

  /// 监听指定音频当前字幕中被收藏的句子索引。
  ///
  /// 同时监听书签与字幕列：字幕被编辑后，即使书签行未变化，定位结果也会更新。
  Stream<Set<int>> watchBookmarkedIndices(String audioItemId) {
    final query = select(audioItems).join([
      leftOuterJoin(
        bookmarks,
        bookmarks.audioItemId.equalsExp(audioItems.id) &
            bookmarks.deletedAt.isNull(),
      ),
    ])..where(audioItems.id.equals(audioItemId));
    return query.watch().asyncMap((rows) async {
      final bookmarkRows = [
        for (final row in rows)
          if (row.readTableOrNull(bookmarks) case final Bookmark bookmark)
            bookmark,
      ];
      if (bookmarkRows.isEmpty) return <int>{};
      final srt = rows.first.readTable(audioItems).transcriptSrt;
      if (srt == null || srt.isEmpty) return <int>{};
      final sentences = await SubtitleParser.parseSubtitleString(srt);
      return _resolveIndices(bookmarkRows, sentences);
    });
  }

  /// 新增书签。同一句可能存在多条（字幕合并后），由调用方按定位结果去重。
  Future<void> addBookmark(BookmarksCompanion entry) {
    return into(bookmarks).insert(entry);
  }

  /// 软删除一组书签
  ///
  /// 设置 deletedAt 标记而非物理删除，便于回收站恢复。
  Future<void> softDeleteByIds(Iterable<int> ids) {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return Future.value();
    final now = DateTime.now();
    return (update(bookmarks)..where((t) => t.id.isIn(idSet))).write(
      BookmarksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// 移除指定音频的所有书签
  Future<void> removeAllForAudio(String audioItemId) {
    return (delete(
      bookmarks,
    )..where((t) => t.audioItemId.equals(audioItemId))).go();
  }

  /// 获取指定音频当前字幕中被收藏的句子索引集合
  ///
  /// 按收藏时间区间定位到当前字幕（见 [resolveSourceSentenceIndex]），
  /// 定位不到的收藏（来源句已被删除）不计入。
  Future<Set<int>> getBookmarkedIndices(String audioItemId) async {
    final rows = await getByAudioId(audioItemId);
    if (rows.isEmpty) return <int>{};
    final sentences = await loadCurrentSentences(audioItemId);
    return _resolveIndices(rows, sentences);
  }

  /// 把调用方持有的句子按其时间区间定位到当前字幕，并返回落在同一句上的书签
  /// （包含回收站）。
  ///
  /// 只看时间，不看 [sentence] 的 index：调用方的句子列表可能是字幕编辑前加载
  /// 的旧列表。定位不到（该句已不在当前字幕中）时 index 为 null、书签为空。
  Future<({int? index, List<Bookmark> bookmarks})> getForSentence(
    String audioItemId,
    Sentence sentence,
  ) async {
    final sentences = await loadCurrentSentences(audioItemId);
    final index = resolveSourceSentenceIndex(
      SourceSentenceAnchor(start: sentence.startTime, end: sentence.endTime),
      sentences,
    );
    if (index == null) return (index: null, bookmarks: const <Bookmark>[]);
    final rows = await (select(
      bookmarks,
    )..where((t) => t.audioItemId.equals(audioItemId))).get();
    return (
      index: index,
      bookmarks: [
        for (final row in rows)
          if (resolveSourceSentenceIndex(anchorOfBookmark(row), sentences) ==
              index)
            row,
      ],
    );
  }

  /// 重新收藏时复用回收站里的原行：改写为本次收藏的区间并移出回收站，
  /// 记忆主体不变（保留复习记录）。
  Future<void> reviveWithSentence(int id, Sentence sentence) {
    return (update(bookmarks)..where((t) => t.id.equals(id))).write(
      BookmarksCompanion(
        sentenceText: Value(sentence.text),
        startTime: Value(sentence.startTime.inMilliseconds / 1000.0),
        endTime: Value(sentence.endTime.inMilliseconds / 1000.0),
        updatedAt: Value(DateTime.now()),
        deletedAt: const Value(null),
        syncStatus: const Value(0),
      ),
    );
  }

  /// 字幕替换后，把该音频的收藏（含回收站）改写为当前字幕中对应那一句的文字
  /// 与区间，记忆主体与复习进度不变；定位不到（来源句已删除）的保持原样。
  ///
  /// 只依据收藏自身的区间，重复执行结果不变。返回改写的条数。
  Future<int> relinkToSentences(
    String audioItemId,
    List<Sentence> sentences,
  ) async {
    final rows = await (select(
      bookmarks,
    )..where((t) => t.audioItemId.equals(audioItemId))).get();
    final now = DateTime.now();
    var relinked = 0;
    await batch((batch) {
      for (final row in rows) {
        final index = resolveSourceSentenceIndex(
          anchorOfBookmark(row),
          sentences,
        );
        if (index == null) continue;
        final target = sentences[index];
        final startTime = target.startTime.inMilliseconds / 1000.0;
        final endTime = target.endTime.inMilliseconds / 1000.0;
        if (row.sentenceText == target.text &&
            row.startTime == startTime &&
            row.endTime == endTime) {
          continue;
        }
        batch.update(
          bookmarks,
          BookmarksCompanion(
            sentenceText: Value(target.text),
            startTime: Value(startTime),
            endTime: Value(endTime),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(row.id),
        );
        relinked++;
      }
    });
    return relinked;
  }

  Set<int> _resolveIndices(List<Bookmark> rows, List<Sentence> sentences) {
    final indices = <int>{};
    for (final row in rows) {
      final index = resolveSourceSentenceIndex(
        anchorOfBookmark(row),
        sentences,
      );
      if (index != null) indices.add(index);
    }
    return indices;
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
  Stream<List<BookmarkWithAudio>> watchAllWithAudioName() =>
      _activeWithAudioQuery().watch().map(_toBookmarksWithAudio);

  /// 一次性读取所有未删除书签（含音频名称），口径同 [watchAllWithAudioName]
  ///
  /// 供导出等非流式场景使用。
  Future<List<BookmarkWithAudio>> getAllWithAudioName() async =>
      _toBookmarksWithAudio(await _activeWithAudioQuery().get());

  JoinedSelectStatement<HasResultSet, dynamic> _activeWithAudioQuery() {
    return select(bookmarks).join([
        innerJoin(audioItems, audioItems.id.equalsExp(bookmarks.audioItemId)),
      ])
      ..where(bookmarks.deletedAt.isNull() & audioItems.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.asc(audioItems.name),
        OrderingTerm.asc(bookmarks.startTime),
      ]);
  }

  List<BookmarkWithAudio> _toBookmarksWithAudio(List<TypedResult> rows) {
    return rows.map((row) {
      return BookmarkWithAudio(
        bookmark: row.readTable(bookmarks),
        audioName: row.readTable(audioItems).name,
      );
    }).toList();
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
  Future<void> restoreById(int id) {
    return (update(bookmarks)..where((t) => t.id.equals(id))).write(
      BookmarksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 永久删除单个已软删除的书签
  Future<void> permanentlyDeleteById(int id) {
    return (delete(
      bookmarks,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).go();
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

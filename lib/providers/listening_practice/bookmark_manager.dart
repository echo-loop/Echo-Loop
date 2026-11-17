import '../../services/app_logger.dart';
import '../../database/daos/bookmark_dao.dart';
import '../../models/sentence.dart';

/// 书签读取与句子收藏状态转换工具。
class BookmarkManager {
  /// 加载书签（从 Drift 数据库）
  static Future<Set<int>> loadBookmarks(
    String audioId, {
    required BookmarkDao dao,
  }) async {
    try {
      return await dao.getBookmarkedIndices(audioId);
    } catch (e) {
      AppLogger.log('Bookmark', '✗ 加载书签失败: $e');
      return {};
    }
  }

  /// 更新句子的书签状态
  static void updateSentenceBookmarkStatus(
    List<Sentence> sentences,
    Set<int> bookmarkedIndices,
  ) {
    for (var sentence in sentences) {
      sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
    }
  }

  /// 基于收藏索引创建会话专用的句子快照。
  ///
  /// 字幕缓存是跨页面共享的只读投影，不能在进入某个学习会话时原地写入
  /// [Sentence.isBookmarked]。调用方应使用本方法得到独立副本，避免一个会话
  /// 的收藏状态污染其他页面或后续会话。
  static List<Sentence> createSentenceBookmarkSnapshot(
    Iterable<Sentence> sentences,
    Set<int> bookmarkedIndices,
  ) {
    return [
      for (final sentence in sentences)
        sentence.copyWith(
          isBookmarked: bookmarkedIndices.contains(sentence.index),
        ),
    ];
  }

  /// 基于收藏索引创建保留段落结构的会话句子快照。
  static List<List<Sentence>> createParagraphBookmarkSnapshot(
    Iterable<List<Sentence>> paragraphs,
    Set<int> bookmarkedIndices,
  ) {
    return [
      for (final paragraph in paragraphs)
        createSentenceBookmarkSnapshot(paragraph, bookmarkedIndices),
    ];
  }

  /// 切换书签状态：只作用于当前这一句。
  /// 返回: (isRemoving, replacementIndex)
  ///
  /// 收藏模式删除当前句时，替代焦点优先取后一条收藏；后面没有时回退到前一条。
  /// 只有删除后确实无收藏可选时才返回 null。
  static (bool, int?) toggleBookmark(
    int index,
    List<Sentence> sentences,
    Set<int> bookmarkedIndices,
    bool inBookmarksMode,
  ) {
    final isRemoving = bookmarkedIndices.contains(index);
    if (!isRemoving || !inBookmarksMode) return (isRemoving, null);

    final bookmarked = [
      for (final s in sentences)
        if (bookmarkedIndices.contains(s.index)) s.index,
    ];
    final pos = bookmarked.indexOf(index);
    if (pos == -1) return (isRemoving, null);
    if (pos + 1 < bookmarked.length) return (isRemoving, bookmarked[pos + 1]);
    // 当前句在收藏末尾时，回退到最近的前一条，避免收藏仍有内容却丢失当前
    // 焦点，导致精听页误退回列表。
    if (pos > 0) return (isRemoving, bookmarked[pos - 1]);
    return (isRemoving, null);
  }
}

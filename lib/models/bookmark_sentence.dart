// 带音频来源信息的句子（用于跨音频收藏复习）。
// 包装 Sentence 并附加音频来源信息，支持跨音频复习场景。
import 'sentence.dart';

/// 带音频来源的收藏句子
class BookmarkSentence {
  /// 句子数据
  final Sentence sentence;

  /// 来源音频 ID
  final String audioItemId;

  /// 来源音频名称（用于 UI 显示）
  final String audioName;

  /// 稳定关联 FSRS 调度快照的业务主体 ID。
  final String memorySubjectId;

  const BookmarkSentence({
    required this.sentence,
    required this.audioItemId,
    required this.audioName,
    required this.memorySubjectId,
  });

  /// 创建一份 isBookmarked 状态不同的副本
  BookmarkSentence copyWithBookmark(bool isBookmarked) => BookmarkSentence(
    sentence: sentence.copyWith(isBookmarked: isBookmarked),
    audioItemId: audioItemId,
    audioName: audioName,
    memorySubjectId: memorySubjectId,
  );
}

/// 收藏句复习的内容适配器。
library;

import '../../database/daos/favorite_review_dao.dart';
import '../../features/memory_scheduler/application/memory_scheduler.dart';
import '../../features/memory_scheduler/data/memory_schedule_mapper.dart';
import '../../features/scheduled_flashcard/domain/scheduled_flashcard.dart';
import '../../models/bookmark_sentence.dart';
import '../../models/favorite_review_settings.dart';
import '../../models/sentence.dart';
import 'favorite_review_deck_source.dart';

/// 把收藏句转换为共享收藏复习队列的输入项。
final class FavoriteSentenceDeckSource
    implements FlashcardDeckSource<BookmarkSentence> {
  FavoriteSentenceDeckSource({
    required FavoriteReviewDao favoriteReviewDao,
    required MemoryScheduler scheduler,
    required FavoriteReviewSettings settings,
    DateTime Function()? now,
  }) : _favoriteReviewDao = favoriteReviewDao,
       _scheduler = scheduler,
       _settings = settings,
       _now = now;

  final FavoriteReviewDao _favoriteReviewDao;
  final MemoryScheduler _scheduler;
  final FavoriteReviewSettings _settings;
  final DateTime Function()? _now;
  final MemoryScheduleMapper _scheduleMapper = MemoryScheduleMapper();

  @override
  Future<List<ScheduledFlashcard<BookmarkSentence>>> load() async =>
      (await _source()).load();

  /// 切换顺序时重新查询到期队列，但不恢复或写入任何调度状态。
  Future<List<ScheduledFlashcard<BookmarkSentence>>>
  loadForReordering() async => (await _source()).loadForReordering();

  Future<FavoriteReviewDeckSource<BookmarkSentence>> _source() async {
    final now = (_now ?? DateTime.now)().toUtc();
    final rows = await _favoriteReviewDao.getDueSentences(now);
    final items = <FavoriteReviewDeckItem<BookmarkSentence>>[];
    for (final row in rows) {
      final schedule = _scheduleMapper.scheduleFromRow(row.schedule);
      items.add(
        FavoriteReviewDeckItem(
          content: _toCard(row),
          subject: schedule.subject,
          createdAt: row.bookmark.createdAt,
          schedule: schedule,
        ),
      );
    }
    return FavoriteReviewDeckSource<BookmarkSentence>(
      items: items,
      scheduler: _scheduler,
      settings: _settings,
      now: () => now,
    );
  }

  BookmarkSentence _toCard(DueFavoriteSentenceRow item) {
    final subjectId = item.schedule.subjectId;
    return BookmarkSentence(
      // 收藏不存句子编号：卡片句子不对应当前字幕的某一句，编号记为 -1；需要前后句
      // 时用 sourceSentenceIndexProvider 按收藏区间现算。
      sentence: Sentence(
        index: -1,
        text: item.bookmark.sentenceText,
        startTime: Duration(
          milliseconds: (item.bookmark.startTime * 1000).round(),
        ),
        endTime: Duration(milliseconds: (item.bookmark.endTime * 1000).round()),
        isBookmarked: true,
      ),
      audioItemId: item.bookmark.audioItemId,
      audioName: item.audioName,
      memorySubjectId: subjectId,
    );
  }
}

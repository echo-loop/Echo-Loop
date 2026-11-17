/// 收藏句与 FSRS 调度快照的一致性入口。
library;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/bookmark_dao.dart';
import '../database/providers.dart';
import '../features/memory_scheduler/config/memory_profiles.dart';
import '../features/memory_scheduler/domain/memory_namespaces.dart';
import '../features/memory_scheduler/domain/memory_schedule.dart';
import '../features/memory_scheduler/domain/memory_scheduler_commands.dart';
import '../features/memory_scheduler/domain/memory_subject_ref.dart';
import '../features/memory_scheduler/providers/memory_scheduler_providers.dart';
import '../models/sentence.dart';
import 'learning_session/favorite_review_due_count_provider.dart';

/// 统一所有收藏句新增、取消、恢复和批量清理时的调度生命周期。
final favoriteSentenceLifecycleProvider = Provider<FavoriteSentenceLifecycle>(
  (ref) => FavoriteSentenceLifecycle(ref),
);

class FavoriteSentenceLifecycle {
  FavoriteSentenceLifecycle(this._ref);

  final Ref _ref;

  /// 写入收藏句并立即创建或恢复其 FSRS 快照。
  ///
  /// 收藏的就是 [sentence] 的时间区间（不看其 index）：当前字幕中这一句已有
  /// 收藏时只确保调度为 active；回收站里有落在这一句上的收藏时复用原行与原
  /// 记忆主体（保留复习记录）；否则新建。
  Future<void> save(String audioItemId, Sentence sentence) async {
    await _transaction(() async {
      final dao = _ref.read(bookmarkDaoProvider);
      final located = await dao.getForSentence(audioItemId, sentence);
      final matches = located.bookmarks;
      final active = matches.where((b) => b.deletedAt == null).toList();
      if (active.isNotEmpty) {
        for (final bookmark in active) {
          await _ensureActive(_requireSubjectId(bookmark));
        }
        return;
      }
      if (matches.isNotEmpty) {
        final latest = matches.reduce(
          (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
        );
        await dao.reviveWithSentence(latest.id, sentence);
        await _ensureActive(_requireSubjectId(latest));
        return;
      }
      final now = DateTime.now();
      final subjectId = const Uuid().v4();
      await dao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value(audioItemId),
          memorySubjectId: Value(subjectId),
          sentenceText: Value(sentence.text),
          startTime: Value(sentence.startTime.inMilliseconds / 1000.0),
          endTime: Value(sentence.endTime.inMilliseconds / 1000.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _ensureActive(subjectId);
    });
    _invalidateDueCount();
  }

  /// 取消一个句子区间的收藏，并归档其 active 调度快照。
  ///
  /// 与 [save] 对称：按 [sentence] 自身的时间区间定位到当前字幕（不信任其
  /// index），取消落在这一句上的收藏。字幕合并后一句可能挂着多条收藏，一起
  /// 取消，否则这一句仍显示为已收藏。
  Future<void> remove(String audioItemId, Sentence sentence) async {
    await _transaction(() async {
      final located = await _ref
          .read(bookmarkDaoProvider)
          .getForSentence(audioItemId, sentence);
      await _removeRows([
        for (final bookmark in located.bookmarks)
          if (bookmark.deletedAt == null) bookmark,
      ]);
    });
    _invalidateDueCount();
  }

  /// 取消一条具体的收藏（收藏列表、收藏复习按收藏本身操作，不经句子索引）。
  Future<void> removeBookmark(Bookmark bookmark) async {
    await _transaction(() => _removeRows([bookmark]));
    _invalidateDueCount();
  }

  /// 按记忆主体取消收藏（收藏复习卡片只持有记忆主体）。
  Future<void> removeBySubjectId(String memorySubjectId) async {
    await _transaction(() async {
      final bookmark = await _ref
          .read(bookmarkDaoProvider)
          .getActiveBySubjectId(memorySubjectId);
      if (bookmark == null) return;
      await _removeRows([bookmark]);
    });
    _invalidateDueCount();
  }

  /// 恢复书签和其原有调度快照。
  Future<void> restore(BookmarkWithAudio item) async {
    await _transaction(() async {
      final subjectId = _requireSubjectId(item.bookmark);
      await _ref.read(bookmarkDaoProvider).restoreById(item.bookmark.id);
      await _ensureActive(subjectId);
    });
    _invalidateDueCount();
  }

  Future<void> _removeRows(List<Bookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;
    for (final bookmark in bookmarks) {
      final subjectId = bookmark.memorySubjectId;
      if (bookmark.deletedAt == null &&
          subjectId != null &&
          subjectId.isNotEmpty) {
        await _archiveActive(subjectId);
      }
    }
    await _ref
        .read(bookmarkDaoProvider)
        .softDeleteByIds(bookmarks.map((b) => b.id));
  }

  String _requireSubjectId(Bookmark bookmark) {
    final subjectId = bookmark.memorySubjectId;
    if (subjectId == null || subjectId.isEmpty) {
      throw StateError('收藏句缺少 memorySubjectId');
    }
    return subjectId;
  }

  /// 清空一个音频的收藏句前归档所有关联调度。
  Future<void> removeAllForAudio(String audioItemId) async {
    await _transaction(() async {
      final dao = _ref.read(bookmarkDaoProvider);
      final bookmarks = await dao.getByAudioId(audioItemId);
      for (final bookmark in bookmarks) {
        final subjectId = bookmark.memorySubjectId;
        if (subjectId != null && subjectId.isNotEmpty) {
          await _archiveActive(subjectId);
        }
      }
      await dao.removeAllForAudio(audioItemId);
    });
    _invalidateDueCount();
  }

  /// 生命周期写入提交后立即失效入口缓存，滑删和普通取消共享此时机。
  void _invalidateDueCount() =>
      _ref.invalidate(favoriteSentenceDueCountProvider);

  Future<void> _ensureActive(String subjectId) async {
    final scheduler = _ref.read(memorySchedulerProvider);
    final subject = MemorySubjectRef(
      namespace: kSavedSentenceNamespace,
      subjectId: subjectId,
    );
    final existing = await scheduler.getSchedule(subject);
    if (existing == null) {
      await scheduler.ensureSchedule(
        EnsureMemoryScheduleCommand(
          subject: subject,
          profile: kFsrsDefaultProfileRef,
          occurredAt: DateTime.now().toUtc(),
        ),
      );
    } else if (existing.status == MemoryScheduleStatus.archived) {
      await scheduler.restore(
        RestoreMemoryScheduleCommand(
          subject: subject,
          restoredAt: DateTime.now().toUtc(),
          expectedRevision: existing.revision,
        ),
      );
    }
  }

  Future<void> _archiveActive(String subjectId) async {
    final scheduler = _ref.read(memorySchedulerProvider);
    final schedule = await scheduler.getSchedule(
      MemorySubjectRef(
        namespace: kSavedSentenceNamespace,
        subjectId: subjectId,
      ),
    );
    if (schedule == null || schedule.status != MemoryScheduleStatus.active) {
      return;
    }
    await scheduler.archive(
      ArchiveMemoryScheduleCommand(
        subject: schedule.subject,
        archivedAt: DateTime.now().toUtc(),
        expectedRevision: schedule.revision,
      ),
    );
  }

  Future<void> _transaction(Future<void> Function() operation) =>
      _ref.read(appDatabaseProvider).transaction(operation);
}

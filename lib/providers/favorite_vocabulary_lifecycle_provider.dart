/// 收藏词汇与记忆调度的一致性入口。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/providers.dart';
import '../features/memory_scheduler/config/memory_profiles.dart';
import '../features/memory_scheduler/domain/memory_namespaces.dart';
import '../features/memory_scheduler/domain/memory_schedule.dart';
import '../features/memory_scheduler/domain/memory_scheduler_commands.dart';
import '../features/memory_scheduler/domain/memory_subject_ref.dart';
import '../features/memory_scheduler/providers/memory_scheduler_providers.dart';
import '../services/app_logger.dart';
import 'learning_session/favorite_review_due_count_provider.dart';

/// 统一单词和意群收藏与记忆调度的原子生命周期操作。
final favoriteVocabularyLifecycleProvider =
    Provider<FavoriteVocabularyLifecycle>(
      (ref) => FavoriteVocabularyLifecycle(ref),
    );

class FavoriteVocabularyLifecycle {
  FavoriteVocabularyLifecycle(this._ref);

  static const _logTag = 'FavoriteVocabularyLifecycle';

  final Ref _ref;

  /// 保存单词收藏，并在同一事务中创建或恢复其记忆调度。
  Future<void> saveWord({
    required String word,
    String? audioItemId,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
  }) async {
    String? subjectId;
    var stage = 'content_save';
    await _transactionWithLog(
      operation: 'save',
      entity: 'word',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedWordDaoProvider);
        await dao.saveWord(
          word: word,
          audioItemId: audioItemId,
          sentenceText: sentenceText,
          sentenceStartMs: sentenceStartMs,
          sentenceEndMs: sentenceEndMs,
        );
        stage = 'content_lookup';
        final item = await dao.getByWord(word);
        subjectId = item?.memorySubjectId;
        stage = 'schedule_restore_or_ensure';
        await _restoreSchedule(
          kSavedWordOrPhraseNamespace,
          subjectId,
          operation: 'save',
          entity: 'word',
        );
      },
    );
    _invalidateDueCount();
  }

  /// 保存意群收藏，并在同一事务中创建或恢复其记忆调度。
  Future<void> saveSenseGroup({
    required String phraseText,
    required String displayText,
    String? audioItemId,
    String? sentenceText,
    int? sentenceStartMs,
    int? sentenceEndMs,
    int? groupStartMs,
    int? groupEndMs,
  }) async {
    String? subjectId;
    var stage = 'content_save';
    await _transactionWithLog(
      operation: 'save',
      entity: 'sense_group',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedSenseGroupDaoProvider);
        await dao.saveSenseGroup(
          phraseText: phraseText,
          displayText: displayText,
          audioItemId: audioItemId,
          sentenceText: sentenceText,
          sentenceStartMs: sentenceStartMs,
          sentenceEndMs: sentenceEndMs,
          groupStartMs: groupStartMs,
          groupEndMs: groupEndMs,
        );
        stage = 'content_lookup';
        final item = await dao.getByPhraseText(phraseText);
        subjectId = item?.memorySubjectId;
        stage = 'schedule_restore_or_ensure';
        await _restoreSchedule(
          kSavedSenseGroupNamespace,
          subjectId,
          operation: 'save',
          entity: 'sense_group',
        );
      },
    );
    _invalidateDueCount();
  }

  /// 软删除单词，并归档其仍 active 的记忆调度。
  Future<void> removeWord(String word) async {
    String? subjectId;
    String? skipReason;
    var stage = 'content_lookup';
    final changed = await _transactionWithLog(
      operation: 'remove',
      entity: 'word',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedWordDaoProvider);
        final item = await dao.getByWord(word);
        if (item == null) {
          skipReason = 'not_found';
          return false;
        }
        subjectId = item.memorySubjectId;
        if (item.deletedAt != null) {
          skipReason = 'already_deleted';
          return false;
        }
        await _remove(
          namespace: kSavedWordOrPhraseNamespace,
          subjectId: item.memorySubjectId,
          entity: 'word',
          setStage: (value) => stage = value,
          removeContent: () => dao.removeWord(word),
        );
        return true;
      },
    );
    if (!changed) {
      _log(
        'event=operation_skipped operation=remove entity=word '
        'reason=${skipReason ?? 'no_change'} subjectId=${_subjectIdForLog(subjectId)}',
      );
    }
    if (changed) _invalidateDueCount();
  }

  /// 软删除意群，并归档其仍 active 的记忆调度。
  Future<void> removeSenseGroup(String phraseText) async {
    String? subjectId;
    String? skipReason;
    var stage = 'content_lookup';
    final changed = await _transactionWithLog(
      operation: 'remove',
      entity: 'sense_group',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedSenseGroupDaoProvider);
        final item = await dao.getByPhraseText(phraseText);
        if (item == null) {
          skipReason = 'not_found';
          return false;
        }
        subjectId = item.memorySubjectId;
        if (item.deletedAt != null) {
          skipReason = 'already_deleted';
          return false;
        }
        await _remove(
          namespace: kSavedSenseGroupNamespace,
          subjectId: item.memorySubjectId,
          entity: 'sense_group',
          setStage: (value) => stage = value,
          removeContent: () => dao.removeSenseGroup(phraseText),
        );
        return true;
      },
    );
    if (!changed) {
      _log(
        'event=operation_skipped operation=remove entity=sense_group '
        'reason=${skipReason ?? 'no_change'} subjectId=${_subjectIdForLog(subjectId)}',
      );
    }
    if (changed) _invalidateDueCount();
  }

  /// 从回收站恢复单词，并恢复既有归档调度。
  Future<void> restoreWord(String word) async {
    String? subjectId;
    String? skipReason;
    var stage = 'content_lookup';
    final changed = await _transactionWithLog(
      operation: 'restore',
      entity: 'word',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedWordDaoProvider);
        final item = await dao.getByWord(word);
        if (item == null) {
          skipReason = 'not_found';
          return false;
        }
        subjectId = item.memorySubjectId;
        if (item.deletedAt == null) {
          skipReason = 'not_deleted';
          return false;
        }
        await _restore(
          namespace: kSavedWordOrPhraseNamespace,
          subjectId: item.memorySubjectId,
          entity: 'word',
          setStage: (value) => stage = value,
          restoreContent: () => dao.restoreWord(word),
        );
        return true;
      },
    );
    if (!changed) {
      _log(
        'event=operation_skipped operation=restore entity=word '
        'reason=${skipReason ?? 'no_change'} subjectId=${_subjectIdForLog(subjectId)}',
      );
    }
    if (changed) _invalidateDueCount();
  }

  /// 从回收站恢复意群，并恢复既有归档调度。
  Future<void> restoreSenseGroup(String phraseText) async {
    String? subjectId;
    String? skipReason;
    var stage = 'content_lookup';
    final changed = await _transactionWithLog(
      operation: 'restore',
      entity: 'sense_group',
      subjectId: () => subjectId,
      stage: () => stage,
      action: () async {
        final dao = _ref.read(savedSenseGroupDaoProvider);
        final item = await dao.getByPhraseText(phraseText);
        if (item == null) {
          skipReason = 'not_found';
          return false;
        }
        subjectId = item.memorySubjectId;
        if (item.deletedAt == null) {
          skipReason = 'not_deleted';
          return false;
        }
        await _restore(
          namespace: kSavedSenseGroupNamespace,
          subjectId: item.memorySubjectId,
          entity: 'sense_group',
          setStage: (value) => stage = value,
          restoreContent: () => dao.restoreSenseGroup(phraseText),
        );
        return true;
      },
    );
    if (!changed) {
      _log(
        'event=operation_skipped operation=restore entity=sense_group '
        'reason=${skipReason ?? 'no_change'} subjectId=${_subjectIdForLog(subjectId)}',
      );
    }
    if (changed) _invalidateDueCount();
  }

  /// 归档调度并移除内容；调用方需在同一数据库事务中执行。
  Future<void> _remove({
    required String namespace,
    required String? subjectId,
    required String entity,
    required void Function(String) setStage,
    required Future<void> Function() removeContent,
  }) async {
    setStage('schedule_archive');
    await _archiveSchedule(
      namespace,
      subjectId,
      operation: 'remove',
      entity: entity,
    );
    setStage('content_remove');
    await removeContent();
  }

  /// 恢复内容与调度；调用方需在同一数据库事务中执行。
  Future<void> _restore({
    required String namespace,
    required String? subjectId,
    required String entity,
    required void Function(String) setStage,
    required Future<void> Function() restoreContent,
  }) async {
    setStage('content_restore');
    await restoreContent();
    setStage('schedule_restore_or_ensure');
    await _restoreSchedule(
      namespace,
      subjectId,
      operation: 'restore',
      entity: entity,
    );
  }

  Future<MemorySchedule?> _archiveSchedule(
    String namespace,
    String? subjectId, {
    required String operation,
    required String entity,
  }) async {
    if (subjectId == null || subjectId.isEmpty) {
      _log(
        'event=schedule_archive_skipped operation=$operation entity=$entity '
        'namespace=$namespace reason=missing_subject_id',
      );
      return null;
    }
    final scheduler = _ref.read(memorySchedulerProvider);
    final schedule = await scheduler.getSchedule(
      MemorySubjectRef(namespace: namespace, subjectId: subjectId),
    );
    if (schedule == null) {
      _log(
        'event=schedule_archive_skipped operation=$operation entity=$entity '
        'namespace=$namespace subjectId=$subjectId reason=missing_schedule',
      );
      return null;
    }
    if (schedule.status != MemoryScheduleStatus.active) {
      _log(
        'event=schedule_archive_skipped operation=$operation entity=$entity '
        'namespace=$namespace subjectId=$subjectId '
        'status=${schedule.status.name} revision=${schedule.revision}',
      );
      return null;
    }
    final archived = await scheduler.archive(
      ArchiveMemoryScheduleCommand(
        subject: schedule.subject,
        archivedAt: DateTime.now().toUtc(),
        expectedRevision: schedule.revision,
      ),
    );
    _log(
      'event=schedule_archived operation=$operation entity=$entity '
      'namespace=$namespace subjectId=$subjectId '
      'revision=${schedule.revision}->${archived.revision}',
    );
    return archived;
  }

  Future<void> _restoreSchedule(
    String namespace,
    String? subjectId, {
    required String operation,
    required String entity,
  }) async {
    if (subjectId == null || subjectId.isEmpty) {
      _log(
        'event=schedule_restore_skipped operation=$operation entity=$entity '
        'namespace=$namespace reason=missing_subject_id',
      );
      return;
    }
    final scheduler = _ref.read(memorySchedulerProvider);
    final subject = MemorySubjectRef(
      namespace: namespace,
      subjectId: subjectId,
    );
    final schedule = await scheduler.getSchedule(subject);
    if (schedule == null) {
      final created = await scheduler.ensureSchedule(
        EnsureMemoryScheduleCommand(
          subject: subject,
          profile: kFsrsDefaultProfileRef,
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      _log(
        'event=schedule_ensured operation=$operation entity=$entity '
        'namespace=$namespace subjectId=$subjectId '
        'status=${created.status.name} revision=${created.revision}',
      );
      return;
    }
    if (schedule.status != MemoryScheduleStatus.archived) {
      _log(
        'event=schedule_unchanged operation=$operation entity=$entity '
        'namespace=$namespace subjectId=$subjectId '
        'status=${schedule.status.name} revision=${schedule.revision}',
      );
      return;
    }
    await _restoreArchivedSchedule(
      schedule,
      operation: operation,
      entity: entity,
    );
  }

  Future<void> _restoreArchivedSchedule(
    MemorySchedule schedule, {
    required String operation,
    required String entity,
  }) async {
    final restored = await _ref
        .read(memorySchedulerProvider)
        .restore(
          RestoreMemoryScheduleCommand(
            subject: schedule.subject,
            restoredAt: DateTime.now().toUtc(),
            expectedRevision: schedule.revision,
          ),
        );
    _log(
      'event=schedule_restored operation=$operation entity=$entity '
      'namespace=${schedule.subject.namespace} '
      'subjectId=${schedule.subject.subjectId} '
      'revision=${schedule.revision}->${restored.revision}',
    );
  }

  /// 所有词汇收藏生命周期完成后统一刷新入口数量。
  void _invalidateDueCount() =>
      _ref.invalidate(favoriteVocabularyDueCountProvider);

  /// 记录事务开始、提交或回滚，便于按操作与调度主体串联日志。
  /// 回滚时只记录阶段和异常类型，避免 SQLite 异常文本包含 SQL 参数或收藏原文。
  Future<T> _transactionWithLog<T>({
    required String operation,
    required String entity,
    required String? Function() subjectId,
    required String Function() stage,
    required Future<T> Function() action,
  }) async {
    _log(
      'event=transaction_started operation=$operation entity=$entity '
      'subjectId=${_subjectIdForLog(subjectId())} stage=${stage()}',
    );
    try {
      final result = await _transaction(action);
      _log(
        'event=transaction_committed operation=$operation entity=$entity '
        'subjectId=${_subjectIdForLog(subjectId())} stage=complete',
      );
      return result;
    } catch (error) {
      _log(
        'event=transaction_rolled_back operation=$operation entity=$entity '
        'subjectId=${_subjectIdForLog(subjectId())} '
        'stage=${stage()} errorType=${error.runtimeType}',
      );
      rethrow;
    }
  }

  void _log(String message) => AppLogger.log(_logTag, message);

  String _subjectIdForLog(String? subjectId) => subjectId ?? 'none';

  Future<T> _transaction<T>(Future<T> Function() operation) =>
      _ref.read(appDatabaseProvider).transaction(operation);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/enums.dart';
import '../models/learning_progress.dart';
import 'audio_library_provider.dart';
import 'learning_progress_provider.dart';
import 'time_provider.dart';

/// 学习任务类型
enum StudyTaskType {
  /// 可立即开始的复习任务
  reviewReady,

  /// 尚未到时间的复习任务
  reviewUpcoming,

  /// 首学任务
  firstStudy,
}

/// 学习页任务视图模型
class StudyTask {
  final String audioId;
  final String audioName;
  final StudyTaskType type;
  final LearningStage stage;
  final SubStageType subStage;
  final DateTime? nextReviewAt;
  final bool isOverdue;
  final Duration? overdueDuration;
  final DateTime updatedAt;

  const StudyTask({
    required this.audioId,
    required this.audioName,
    required this.type,
    required this.stage,
    required this.subStage,
    required this.updatedAt,
    this.nextReviewAt,
    this.isOverdue = false,
    this.overdueDuration,
  });
}

/// 学习页任务列表 Provider（复习优先）
///
/// 输出稳定排序的任务清单：
/// 1) 可开始复习
/// 2) 未到时间复习
/// 3) 首学
final studyTaskProvider = Provider<List<StudyTask>>((ref) {
  final audioState = ref.watch(audioLibraryProvider);
  final progressMap = ref.watch(
    learningProgressNotifierProvider.select((s) => s.progressMap),
  );
  final now = ref.watch(nowProvider)();

  final tasks = <StudyTask>[];
  for (final item in audioState.audioItems) {
    final progress = progressMap[item.id];
    final task = _buildTaskForAudio(
      audioId: item.id,
      audioName: item.name,
      progress: progress,
      now: now,
    );
    if (task != null) {
      tasks.add(task);
    }
  }

  tasks.sort(_compareTask);
  return tasks;
});

/// 当天是否存在未完成任务（用于提醒调度）
final pendingStudyTaskCountProvider = Provider<int>((ref) {
  return ref.watch(studyTaskProvider).length;
});

/// 已完成音频（LearningStage.completed）列表
final completedAudioProvider = Provider<List<({String audioId, String audioName})>>((ref) {
  final audioState = ref.watch(audioLibraryProvider);
  final progressMap = ref.watch(
    learningProgressNotifierProvider.select((s) => s.progressMap),
  );

  final completed = <({String audioId, String audioName})>[];
  for (final item in audioState.audioItems) {
    final progress = progressMap[item.id];
    if (progress != null && progress.isCompleted) {
      completed.add((audioId: item.id, audioName: item.name));
    }
  }
  return completed;
});

StudyTask? _buildTaskForAudio({
  required String audioId,
  required String audioName,
  required LearningProgress? progress,
  required DateTime now,
}) {
  if (progress == null) {
    return StudyTask(
      audioId: audioId,
      audioName: audioName,
      type: StudyTaskType.firstStudy,
      stage: LearningStage.firstLearn,
      subStage: SubStageType.blindListen,
      updatedAt: now,
    );
  }

  if (progress.isCompleted) {
    return null;
  }

  if (progress.currentStage == LearningStage.firstLearn) {
    return StudyTask(
      audioId: audioId,
      audioName: audioName,
      type: StudyTaskType.firstStudy,
      stage: progress.currentStage,
      subStage: progress.currentSubStage,
      updatedAt: progress.updatedAt,
    );
  }

  final inReviewRange =
      progress.currentStage.index >= LearningStage.review0.index &&
      progress.currentStage.index <= LearningStage.review28.index;
  if (!inReviewRange) {
    return null;
  }

  return StudyTask(
    audioId: audioId,
    audioName: audioName,
    type: progress.isReviewReadyAt(now)
        ? StudyTaskType.reviewReady
        : StudyTaskType.reviewUpcoming,
    stage: progress.currentStage,
    subStage: progress.currentSubStage,
    nextReviewAt: progress.nextReviewAt,
    isOverdue: progress.isReviewOverdueAt(now),
    overdueDuration: progress.overdueDurationAt(now),
    updatedAt: progress.updatedAt,
  );
}

int _compareTask(StudyTask a, StudyTask b) {
  final typeCmp = _typeRank(a.type).compareTo(_typeRank(b.type));
  if (typeCmp != 0) return typeCmp;

  // 可复习任务内部：逾期优先，且逾期越久优先。
  if (a.type == StudyTaskType.reviewReady && b.type == StudyTaskType.reviewReady) {
    if (a.isOverdue != b.isOverdue) {
      return a.isOverdue ? -1 : 1;
    }
    if (a.isOverdue && b.isOverdue) {
      final aOverdue = a.overdueDuration?.inSeconds ?? 0;
      final bOverdue = b.overdueDuration?.inSeconds ?? 0;
      final overdueCmp = bOverdue.compareTo(aOverdue);
      if (overdueCmp != 0) return overdueCmp;
    }
  }

  final aNext = a.nextReviewAt;
  final bNext = b.nextReviewAt;
  if (aNext != null && bNext != null) {
    final nextCmp = aNext.compareTo(bNext);
    if (nextCmp != 0) return nextCmp;
  } else if (aNext != null) {
    return -1;
  } else if (bNext != null) {
    return 1;
  }

  final updatedCmp = b.updatedAt.compareTo(a.updatedAt);
  if (updatedCmp != 0) return updatedCmp;

  return a.audioName.toLowerCase().compareTo(b.audioName.toLowerCase());
}

int _typeRank(StudyTaskType type) {
  return switch (type) {
    StudyTaskType.reviewReady => 0,
    StudyTaskType.reviewUpcoming => 1,
    StudyTaskType.firstStudy => 2,
  };
}

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_item.dart';
import '../database/daos/stage_completion_dao.dart';
import '../database/enums.dart';
import '../database/providers.dart';
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

  /// 首次学习任务
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

  /// 当前阶段是否已有真实完成记录（≥1 个子步骤完成）。
  ///
  /// 来自 `stage_completions` 历史（非 `subStage` 位置推导），用于判定"学习中"。
  /// 待解锁任务本轮尚未解锁、无任何完成记录 → 恒为 false。
  final bool hasRoundProgress;

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
    this.hasRoundProgress = false,
  });
}

/// 学习页任务列表 Provider（复习优先）
///
/// 输出稳定排序的任务清单：
/// 1) 可开始复习
/// 2) 未到时间复习
/// 3) 首次学习
final studyTaskProvider = Provider<List<StudyTask>>((ref) {
  final audioState = ref.watch(audioLibraryProvider);
  final progressMap = ref.watch(
    learningProgressProvider.select((s) => s.progressMap),
  );
  final completionsByAudio = ref.watch(
    learningProgressProvider.select((s) => s.completionsByAudio),
  );
  final now = ref.watch(nowProvider)();

  final tasks = <StudyTask>[];
  final activeProgresses = <LearningProgress>[];
  final unstartedAudioItems = <AudioItem>[];

  for (final item in audioState.audioItems) {
    final progress = progressMap[item.id];
    if (progress == null) {
      unstartedAudioItems.add(item);
      continue;
    }

    final task = _buildTaskForAudio(
      audioId: item.id,
      audioName: item.name,
      progress: progress,
      completions: completionsByAudio[item.id] ?? const {},
      now: now,
    );
    if (task != null) {
      tasks.add(task);
      activeProgresses.add(progress);
    }
  }

  // 只保留学习进度最深的首次学习任务（规则：同时只允许一个首次学习）
  // 优先级：子阶段更靠后 > updatedAt 更新
  final firstStudyTasks = tasks
      .where((t) => t.type == StudyTaskType.firstStudy)
      .toList();
  if (firstStudyTasks.length > 1) {
    firstStudyTasks.sort((a, b) {
      final stageCmp = b.subStage.index.compareTo(a.subStage.index);
      if (stageCmp != 0) return stageCmp;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    final keepId = firstStudyTasks.first.audioId;
    tasks.removeWhere(
      (t) => t.type == StudyTaskType.firstStudy && t.audioId != keepId,
    );
    activeProgresses.removeWhere(
      (p) =>
          p.currentStage == LearningStage.firstLearn && p.audioItemId != keepId,
    );
  }

  if (_shouldInjectNewAudio(tasks: tasks, activeProgresses: activeProgresses)) {
    final selectedAudio = _pickNextNewAudio(unstartedAudioItems);
    if (selectedAudio != null) {
      tasks.add(
        StudyTask(
          audioId: selectedAudio.id,
          audioName: selectedAudio.name,
          type: StudyTaskType.firstStudy,
          stage: LearningStage.firstLearn,
          subStage: SubStageType.blindListen,
          updatedAt: now,
        ),
      );
    }
  }

  tasks.sort(_compareTask);
  return tasks;
});

/// 当天待学习任务数量（用于提醒调度），仅计算可操作任务（不含待解锁）
final pendingStudyTaskCountProvider = Provider<int>((ref) {
  final tasks = ref.watch(studyTaskProvider);
  return tasks.where((t) => t.type != StudyTaskType.reviewUpcoming).length;
});

/// 已完成音频（LearningStage.completed）列表
final completedAudioProvider =
    Provider<List<({String audioId, String audioName})>>((ref) {
      final audioState = ref.watch(audioLibraryProvider);
      final progressMap = ref.watch(
        learningProgressProvider.select((s) => s.progressMap),
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
  required LearningProgress progress,
  required Set<String> completions,
  required DateTime now,
}) {
  if (progress.isCompleted) {
    return null;
  }

  // 暂停学习的音频不参与调度，恢复后按 nextReviewAt 原地继续。
  if (progress.isPaused) {
    return null;
  }

  // 当前阶段是否已有真实完成记录（key 带冒号，'review1:' 不会误匹配 'review14:...'）。
  final hasRoundProgress = completions.any(
    (k) => k.startsWith('${progress.currentStage.key}:'),
  );

  if (progress.currentStage == LearningStage.firstLearn) {
    return StudyTask(
      audioId: audioId,
      audioName: audioName,
      type: StudyTaskType.firstStudy,
      stage: progress.currentStage,
      subStage: progress.currentSubStage,
      updatedAt: progress.updatedAt,
      hasRoundProgress: hasRoundProgress,
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
    hasRoundProgress: hasRoundProgress,
  );
}

/// 是否应该向学习页额外投放 1 篇新音频。
///
/// 只有当当前任务数不超过 3，且所有在学音频都已进入 review1 及之后，
/// 才允许从未学习音频里补 1 篇首次学习任务。
bool _shouldInjectNewAudio({
  required List<StudyTask> tasks,
  required List<LearningProgress> activeProgresses,
}) {
  if (tasks.length > 3) {
    return false;
  }
  if (activeProgresses.isEmpty) {
    return true;
  }

  for (final progress in activeProgresses) {
    if (progress.currentStage.index < LearningStage.review1.index ||
        progress.currentStage.index > LearningStage.review28.index) {
      return false;
    }
  }

  return true;
}

/// 从未学习音频中选择最适合投放的一篇。
///
/// 选择优先级：
/// 1. 有效时长更短（`totalDuration > 0` 才视为有效）
/// 2. 时长同级时，导入时间更早
/// 3. 仍相同时，按名称和 id 稳定排序
AudioItem? _pickNextNewAudio(List<AudioItem> candidates) {
  if (candidates.isEmpty) {
    return null;
  }

  final sortedCandidates = [...candidates]..sort(_compareNewAudioCandidate);
  return sortedCandidates.first;
}

int _compareNewAudioCandidate(AudioItem a, AudioItem b) {
  final aHasDuration = a.totalDuration > 0;
  final bHasDuration = b.totalDuration > 0;
  if (aHasDuration != bHasDuration) {
    return aHasDuration ? -1 : 1;
  }

  if (aHasDuration && bHasDuration) {
    final durationCmp = a.totalDuration.compareTo(b.totalDuration);
    if (durationCmp != 0) {
      return durationCmp;
    }
  }

  final addedDateCmp = a.addedDate.compareTo(b.addedDate);
  if (addedDateCmp != 0) {
    return addedDateCmp;
  }

  final nameCmp = a.audioNameForSort.compareTo(b.audioNameForSort);
  if (nameCmp != 0) {
    return nameCmp;
  }

  return a.id.compareTo(b.id);
}

int _compareTask(StudyTask a, StudyTask b) {
  final typeCmp = _typeRank(a.type).compareTo(_typeRank(b.type));
  if (typeCmp != 0) return typeCmp;

  // 可复习任务内部：逾期优先，且逾期越久优先。
  if (a.type == StudyTaskType.reviewReady &&
      b.type == StudyTaskType.reviewReady) {
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

extension on AudioItem {
  String get audioNameForSort => name.toLowerCase();
}

final _playbackSavedAtByAudioProvider = StreamProvider<Map<String, DateTime>>((
  ref,
) {
  return ref.watch(playbackStateDaoProvider).watchLastSavedAtByAudio();
});

final _latestCompletionAtByAudioProvider =
    StreamProvider<Map<String, DateTime>>((ref) {
      return ref
          .watch(stageCompletionDaoProvider)
          .watchLatestCompletionAtByAudio();
    });

/// 学习页推荐的单条材料；依赖数据尚未就绪时保持 loading。
final studyRecommendationProvider = Provider<AsyncValue<AudioItem?>>((ref) {
  final audioState = ref.watch(audioLibraryProvider);
  final progressState = ref.watch(learningProgressProvider);
  final playbackSavedAt = ref.watch(_playbackSavedAtByAudioProvider);
  final latestCompletionAt = ref.watch(_latestCompletionAtByAudioProvider);
  final recentCompletions = ref.watch(recentCompletionsProvider);

  if (audioState.isLoading || progressState.isLoading) {
    return const AsyncLoading();
  }

  return playbackSavedAt.when(
    data: (playbackTimes) => latestCompletionAt.when(
      data: (completionTimes) => recentCompletions.when(
        data: (recentItems) => AsyncData(
          selectStudyRecommendation(
            materials: audioState.audioItems,
            progressByAudioId: progressState.progressMap,
            playbackSavedAtByAudioId: playbackTimes,
            latestCompletionAtByAudioId: completionTimes,
            recentCompletions: recentItems,
          ),
        ),
        loading: () => const AsyncLoading(),
        error: (error, stackTrace) => AsyncError(error, stackTrace),
      ),
      loading: () => const AsyncLoading(),
      error: (error, stackTrace) => AsyncError(error, stackTrace),
    ),
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
  );
});

/// 按学习活动时间和最近完成记录选择学习页推荐材料。
@visibleForTesting
AudioItem? selectStudyRecommendation({
  required List<AudioItem> materials,
  required Map<String, LearningProgress> progressByAudioId,
  required Map<String, DateTime> playbackSavedAtByAudioId,
  required Map<String, DateTime> latestCompletionAtByAudioId,
  required List<RecentCompletion> recentCompletions,
}) {
  final recentCompletionIds = recentCompletions
      .map((completion) => completion.audioId)
      .toSet();
  bool isEligibleForRecommendation(AudioItem material) =>
      !recentCompletionIds.contains(material.id) &&
      progressByAudioId[material.id]?.isCompleted != true;

  AudioItem? mostRecentlyStudied;
  DateTime? mostRecentActivityAt;
  for (final material in materials) {
    if (!isEligibleForRecommendation(material)) continue;

    final activityAt = _latestStudyActivityAt(
      material.id,
      progressByAudioId,
      playbackSavedAtByAudioId,
      latestCompletionAtByAudioId,
    );
    if (activityAt == null) continue;

    final currentMaterial = mostRecentlyStudied;
    final currentActivityAt = mostRecentActivityAt;
    if (currentMaterial == null ||
        currentActivityAt == null ||
        activityAt.isAfter(currentActivityAt) ||
        (activityAt.isAtSameMomentAs(currentActivityAt) &&
            _compareRecommendedMaterials(material, currentMaterial) < 0)) {
      mostRecentlyStudied = material;
      mostRecentActivityAt = activityAt;
    }
  }
  if (mostRecentlyStudied != null) return mostRecentlyStudied;

  final sortedMaterials = [...materials]..sort(_compareRecommendedMaterials);
  if (sortedMaterials.isEmpty) return null;

  AudioItem? firstEligibleMaterial({int startIndex = 0}) {
    for (var index = startIndex; index < sortedMaterials.length; index++) {
      final material = sortedMaterials[index];
      if (isEligibleForRecommendation(material)) return material;
    }
    return null;
  }

  if (recentCompletions.isEmpty) return firstEligibleMaterial();

  final sortedRecentCompletions = [...recentCompletions]
    ..sort((a, b) {
      final completedAtComparison = b.completedAt.compareTo(a.completedAt);
      if (completedAtComparison != 0) return completedAtComparison;
      return a.audioId.compareTo(b.audioId);
    });

  var anchorIndex = -1;
  for (final completion in sortedRecentCompletions) {
    anchorIndex = sortedMaterials.indexWhere(
      (material) => material.id == completion.audioId,
    );
    if (anchorIndex >= 0) break;
  }
  if (anchorIndex < 0) return firstEligibleMaterial();
  return firstEligibleMaterial(startIndex: anchorIndex + 1);
}

/// 汇总播放断点、学习断点和子步骤完成时间，忽略普通进度更新时间。
DateTime? _latestStudyActivityAt(
  String audioId,
  Map<String, LearningProgress> progressByAudioId,
  Map<String, DateTime> playbackSavedAtByAudioId,
  Map<String, DateTime> latestCompletionAtByAudioId,
) {
  final progress = progressByAudioId[audioId];
  final activityTimes = [
    playbackSavedAtByAudioId[audioId],
    progress?.newLearningBreakpointSavedAt,
    progress?.freePlayBreakpointSavedAt,
    latestCompletionAtByAudioId[audioId],
  ];

  DateTime? latest;
  for (final activityAt in activityTimes) {
    if (activityAt == null) continue;
    if (latest == null || activityAt.isAfter(latest)) latest = activityAt;
  }
  return latest;
}

/// 按展示名称不区分大小写排序，并以材料 ID 稳定处理同名材料。
int _compareRecommendedMaterials(AudioItem a, AudioItem b) {
  final nameComparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (nameComparison != 0) return nameComparison;
  return a.id.compareTo(b.id);
}

/// 最近 24 小时完成的子步骤记录
///
/// 用于学习页底部"最近完成"折叠区展示。
/// 按完成时间倒序排列，无记录时返回空列表。
/// 依赖 [learningProgressProvider] 实现自动刷新：
/// 完成子步骤时 progressMap 变化 → 触发重新查询。
final recentCompletionsProvider = FutureProvider<List<RecentCompletion>>((ref) {
  // 监听进度变化，确保完成子步骤后自动刷新
  ref.watch(learningProgressProvider.select((s) => s.progressMap));
  final dao = ref.watch(stageCompletionDaoProvider);
  final now = ref.watch(nowProvider)();
  final since = now.subtract(const Duration(hours: 24));
  return dao.getRecentCompletions(since);
});

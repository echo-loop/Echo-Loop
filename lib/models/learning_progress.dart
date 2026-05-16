import '../database/enums.dart';
import 'learning_plan.dart';

/// 学习进度模型
///
/// 封装单个音频的学习进度数据。学习流程严格线性，
/// 完成状态由 [currentStage] + [currentSubStage] 推导。
/// 总子步骤数动态计算，从各阶段的 subStages 列表推导。
class LearningProgress {
  /// 关联的音频 ID
  final String audioItemId;

  /// 当前大阶段
  final LearningStage currentStage;

  /// 当前子步骤
  final SubStageType currentSubStage;

  /// 难度等级
  final DifficultyLevel difficulty;

  /// 首次学习完成时间（复习间隔计算基准）
  final DateTime? firstLearnCompletedAt;

  /// 上一阶段完成时间（复习调度核心字段）
  final DateTime? lastStageCompletedAt;

  /// 当前阶段开始时间（断点续学 + 耗时计算）
  final DateTime? currentStageStartedAt;

  /// 累计学习时长（毫秒）
  final int totalStudyDurationMs;

  /// 盲听已完成遍数
  final int blindListenPassCount;

  /// 精听标记的难句数量
  final int? intensiveListenDifficultCount;

  /// 精听总完成遍数（每次完成精听 +1）
  final int? intensiveListenPassCount;

  /// 跟读总完成遍数（每次完成跟读 +1）
  final int? shadowingPassCount;

  /// 盲听断点续学段落索引（null 表示从头开始）
  final int? blindListenParagraphIndex;

  /// 精听断点续学句子索引（null 表示从头开始）
  final int? intensiveListenSentenceIndex;

  /// 跟读断点续学句子索引（null 表示从头开始）
  final int? shadowingSentenceIndex;

  /// 难句补练断点续学句子索引（null 表示从头开始）
  final int? difficultPracticeSentenceIndex;

  /// 复述断点续学段落索引（null 表示从头开始）
  final int? retellParagraphIndex;

  /// 复述总完成遍数（每次完成复述 +1）
  final int? retellPassCount;

  /// 自由练习-盲听断点段落索引
  final int? freePlayBlindListenParagraphIndex;

  /// 自由练习-精听断点句子索引
  final int? freePlayIntensiveListenSentenceIndex;

  /// 自由练习-跟读断点句子索引
  final int? freePlayShadowingSentenceIndex;

  /// 自由练习-难句补练断点句子索引
  final int? freePlayDifficultPracticeSentenceIndex;

  /// 自由练习-复述断点段落索引
  final int? freePlayRetellParagraphIndex;

  /// 新学习断点保存时间（>3天则不恢复）
  final DateTime? newLearningBreakpointSavedAt;

  /// 自由练习断点保存时间（>3天则不恢复）
  final DateTime? freePlayBreakpointSavedAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 用户（或自动跳过策略）在该音频上跳过的子步骤集合
  ///
  /// 每个元素为 `'stage.key:subStage.key'`。与 `stage_completions` 互斥：
  /// 写 completion 时该 key 会从此集合清除；写 skip 时若该 key 已 completed
  /// 则早返回（参见 [LearningProgressNotifier.skipCurrentSubStage]）。
  final Set<String> skippedSubStageKeys;

  const LearningProgress({
    required this.audioItemId,
    this.currentStage = LearningStage.firstLearn,
    this.currentSubStage = SubStageType.blindListen,
    this.difficulty = DifficultyLevel.medium,
    this.firstLearnCompletedAt,
    this.lastStageCompletedAt,
    this.currentStageStartedAt,
    this.totalStudyDurationMs = 0,
    this.blindListenPassCount = 0,
    this.intensiveListenDifficultCount,
    this.intensiveListenPassCount,
    this.shadowingPassCount,
    this.blindListenParagraphIndex,
    this.intensiveListenSentenceIndex,
    this.shadowingSentenceIndex,
    this.difficultPracticeSentenceIndex,
    this.retellParagraphIndex,
    this.retellPassCount,
    this.freePlayBlindListenParagraphIndex,
    this.freePlayIntensiveListenSentenceIndex,
    this.freePlayShadowingSentenceIndex,
    this.freePlayDifficultPracticeSentenceIndex,
    this.freePlayRetellParagraphIndex,
    this.newLearningBreakpointSavedAt,
    this.freePlayBreakpointSavedAt,
    required this.updatedAt,
    this.skippedSubStageKeys = const {},
  });

  /// 所有阶段的总子步骤数（动态计算）
  static int get totalSubStages =>
      LearningStage.values.fold(0, (sum, s) => sum + s.subStageCount);

  /// 当前子步骤在所属阶段中的索引
  int get currentSubStageIndex =>
      currentStage.allSubStages.indexOf(currentSubStage);

  /// 是否已开始学习
  bool get isStarted =>
      currentStage != LearningStage.firstLearn ||
      currentSubStage != SubStageType.blindListen;

  /// 是否已完成全部学习
  bool get isCompleted => currentStage == LearningStage.completed;

  /// 下次复习可用时间（仅复习阶段有意义）
  ///
  /// 基于 [lastStageCompletedAt] + 当前阶段的 [intervalHours] 计算。
  /// 首次学习阶段或缺少完成时间时返回 null。
  DateTime? get nextReviewAt {
    if (lastStageCompletedAt == null) return null;
    if (currentStage.intervalHours <= 0) return null;
    return lastStageCompletedAt!.add(
      Duration(hours: currentStage.intervalHours),
    );
  }

  /// 复习可学习窗口时长（仅复习阶段有意义）。
  ///
  /// - review0：到点后 6 小时内不算逾期
  /// - review1~review28：到点后 24 小时内不算逾期
  Duration? get reviewWindowDuration {
    if (!isInReviewStage) return null;
    if (currentStage == LearningStage.review0) {
      return const Duration(hours: 6);
    }
    return const Duration(hours: 24);
  }

  /// 复习可学习窗口结束时间。
  DateTime? get reviewWindowEndAt {
    final reviewAt = nextReviewAt;
    final window = reviewWindowDuration;
    if (reviewAt == null || window == null) return null;
    return reviewAt.add(window);
  }

  /// 当前是否可以开始复习
  bool get isReviewReady {
    return isReviewReadyAt(DateTime.now());
  }

  /// 指定时间点是否可以开始复习。
  ///
  /// 规则：`now >= nextReviewAt` 即可复习；无复习时间时视为可复习。
  bool isReviewReadyAt(DateTime now) {
    final reviewAt = nextReviewAt;
    if (reviewAt == null) return true;
    return now.isAfter(reviewAt) || now.isAtSameMomentAs(reviewAt);
  }

  /// 当前是否处于复习阶段（review0 ~ review28）
  bool get isInReviewStage =>
      currentStage.index >= LearningStage.review0.index &&
      currentStage.index <= LearningStage.review28.index;

  /// 复习是否未解锁（处于复习阶段且未到时间）
  bool get isReviewLocked => isReviewLockedAt(DateTime.now());

  /// 指定时间点的复习锁定状态。
  bool isReviewLockedAt(DateTime now) =>
      isInReviewStage && !isReviewReadyAt(now);

  /// 当前是否已逾期（超过可学习窗口结束时间）。
  bool get isReviewOverdue => isReviewOverdueAt(DateTime.now());

  /// 指定时间点是否已逾期。
  ///
  /// 规则：`now > reviewWindowEndAt` 才算逾期。
  bool isReviewOverdueAt(DateTime now) {
    final windowEnd = reviewWindowEndAt;
    if (windowEnd == null) return false;
    return now.isAfter(windowEnd);
  }

  /// 指定时间点的逾期时长（未逾期返回 null）。
  Duration? overdueDurationAt(DateTime now) {
    final windowEnd = reviewWindowEndAt;
    if (windowEnd == null || !isReviewOverdueAt(now)) return null;
    return now.difference(windowEnd);
  }

  /// 总完成进度（0.0 ~ 1.0）。
  ///
  /// 分母 = `inPlan ∪ isDone ∪ isUserSkipped` 的子步骤总数（跨所有阶段）。
  /// 分子 = `isDone ∪ isUserSkipped` 的子步骤数。
  ///
  /// 跳过视为「已处理」占位（用户表态过、不再阻塞推进），与 completed 等价
  /// 计入分子。否则纯跳过场景永远卡在 < 100%。
  double progressPercent(LearningPlan plan, Set<String> completedKeys) {
    if (isCompleted) return 1.0;
    int total = 0;
    int handled = 0;
    for (final s in LearningStage.values) {
      for (final sub in s.allSubStages) {
        final key = '${s.key}:${sub.key}';
        final isDone = completedKeys.contains(key);
        final isSkipped = skippedSubStageKeys.contains(key);
        final inPlan = plan.includes(s, sub);
        if (!isDone && !isSkipped && !inPlan) continue;
        total += 1;
        if (isDone || isSkipped) handled += 1;
      }
    }
    if (total == 0) return 0.0;
    return handled / total;
  }

  /// 指定阶段是否已完成
  bool isStageCompleted(LearningStage stage) =>
      stage.index < currentStage.index;

  /// 指定子步骤是否**真做过**（基于 stage_completions 真实历史）。
  ///
  /// [completedKeys] 由 `LearningProgressState.completionsFor(audioId)` 提供，
  /// 是该音频已写入 `stage_completions` 表的 `'stage.key:subStage.key'` 集合。
  /// 跳过（reconcile 推进但未真做）的子步骤不会出现在该集合内 → 返回 false。
  bool isSubStageCompleted(
    LearningStage stage,
    SubStageType subStage,
    Set<String> completedKeys,
  ) {
    return completedKeys.contains('${stage.key}:${subStage.key}');
  }

  /// 指定子步骤是否被「跳过」（手动 / 自动均算）。
  ///
  /// 与 [isSubStageCompleted] 互斥：写 completion 时会同步清除此集合中对应 key。
  /// 渲染优先级：completed > skipped > planned。
  bool isSubStageSkipped(LearningStage stage, SubStageType subStage) {
    return skippedSubStageKeys.contains('${stage.key}:${subStage.key}');
  }

  /// 指定阶段是否为当前活跃阶段
  bool isCurrentStage(LearningStage stage) => stage.index == currentStage.index;

  /// 指定子步骤是否为当前活跃子步骤
  bool isCurrentSubStage(LearningStage stage, SubStageType subStage) =>
      stage == currentStage && subStage == currentSubStage;

  /// 已完成的首次学习步骤数（按真实完成历史 [completedKeys] 派生）。
  ///
  /// 分母 = firstLearn 阶段可见子步骤（plan 内 ∪ 已完成），分子 = 已完成数。
  int completedFirstStudySteps(LearningPlan plan, Set<String> completedKeys) {
    int count = 0;
    for (final sub in LearningStage.firstLearn.allSubStages) {
      if (completedKeys.contains('${LearningStage.firstLearn.key}:${sub.key}')) {
        count += 1;
      }
    }
    return count;
  }

  /// 已完成的复习阶段数（review0 ~ review28 共 7 个）
  int get completedReviewStages {
    if (currentStage.index <= LearningStage.firstLearn.index) return 0;
    if (isCompleted) return 7;
    // currentStage.index - 1 = 已完成的复习阶段数
    // （因为 review0 的 index 是 1，firstLearn 是 0）
    return currentStage.index - 1;
  }

  LearningProgress copyWith({
    String? audioItemId,
    LearningStage? currentStage,
    SubStageType? currentSubStage,
    DifficultyLevel? difficulty,
    DateTime? firstLearnCompletedAt,
    DateTime? lastStageCompletedAt,
    DateTime? currentStageStartedAt,
    int? totalStudyDurationMs,
    int? blindListenPassCount,
    int? intensiveListenDifficultCount,
    int? intensiveListenPassCount,
    int? shadowingPassCount,
    int? blindListenParagraphIndex,
    bool clearBlindListenParagraphIndex = false,
    int? intensiveListenSentenceIndex,
    int? shadowingSentenceIndex,
    int? difficultPracticeSentenceIndex,
    int? retellParagraphIndex,
    int? retellPassCount,
    int? freePlayBlindListenParagraphIndex,
    bool clearFreePlayBlindListenParagraphIndex = false,
    int? freePlayIntensiveListenSentenceIndex,
    bool clearFreePlayIntensiveListenSentenceIndex = false,
    int? freePlayShadowingSentenceIndex,
    bool clearFreePlayShadowingSentenceIndex = false,
    int? freePlayDifficultPracticeSentenceIndex,
    bool clearFreePlayDifficultPracticeSentenceIndex = false,
    int? freePlayRetellParagraphIndex,
    bool clearFreePlayRetellParagraphIndex = false,
    DateTime? newLearningBreakpointSavedAt,
    bool clearNewLearningBreakpointSavedAt = false,
    DateTime? freePlayBreakpointSavedAt,
    bool clearFreePlayBreakpointSavedAt = false,
    DateTime? updatedAt,
    bool clearIntensiveListenSentenceIndex = false,
    bool clearShadowingSentenceIndex = false,
    bool clearDifficultPracticeSentenceIndex = false,
    bool clearRetellParagraphIndex = false,
    Set<String>? skippedSubStageKeys,
  }) {
    return LearningProgress(
      audioItemId: audioItemId ?? this.audioItemId,
      currentStage: currentStage ?? this.currentStage,
      currentSubStage: currentSubStage ?? this.currentSubStage,
      difficulty: difficulty ?? this.difficulty,
      firstLearnCompletedAt:
          firstLearnCompletedAt ?? this.firstLearnCompletedAt,
      lastStageCompletedAt: lastStageCompletedAt ?? this.lastStageCompletedAt,
      currentStageStartedAt:
          currentStageStartedAt ?? this.currentStageStartedAt,
      totalStudyDurationMs: totalStudyDurationMs ?? this.totalStudyDurationMs,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      intensiveListenDifficultCount:
          intensiveListenDifficultCount ?? this.intensiveListenDifficultCount,
      intensiveListenPassCount:
          intensiveListenPassCount ?? this.intensiveListenPassCount,
      shadowingPassCount: shadowingPassCount ?? this.shadowingPassCount,
      blindListenParagraphIndex: clearBlindListenParagraphIndex
          ? null
          : (blindListenParagraphIndex ?? this.blindListenParagraphIndex),
      intensiveListenSentenceIndex: clearIntensiveListenSentenceIndex
          ? null
          : (intensiveListenSentenceIndex ?? this.intensiveListenSentenceIndex),
      shadowingSentenceIndex: clearShadowingSentenceIndex
          ? null
          : (shadowingSentenceIndex ?? this.shadowingSentenceIndex),
      difficultPracticeSentenceIndex: clearDifficultPracticeSentenceIndex
          ? null
          : (difficultPracticeSentenceIndex ??
                this.difficultPracticeSentenceIndex),
      retellParagraphIndex: clearRetellParagraphIndex
          ? null
          : (retellParagraphIndex ?? this.retellParagraphIndex),
      retellPassCount: retellPassCount ?? this.retellPassCount,
      freePlayBlindListenParagraphIndex: clearFreePlayBlindListenParagraphIndex
          ? null
          : (freePlayBlindListenParagraphIndex ??
                this.freePlayBlindListenParagraphIndex),
      freePlayIntensiveListenSentenceIndex:
          clearFreePlayIntensiveListenSentenceIndex
          ? null
          : (freePlayIntensiveListenSentenceIndex ??
                this.freePlayIntensiveListenSentenceIndex),
      freePlayShadowingSentenceIndex: clearFreePlayShadowingSentenceIndex
          ? null
          : (freePlayShadowingSentenceIndex ??
                this.freePlayShadowingSentenceIndex),
      freePlayDifficultPracticeSentenceIndex:
          clearFreePlayDifficultPracticeSentenceIndex
          ? null
          : (freePlayDifficultPracticeSentenceIndex ??
                this.freePlayDifficultPracticeSentenceIndex),
      freePlayRetellParagraphIndex: clearFreePlayRetellParagraphIndex
          ? null
          : (freePlayRetellParagraphIndex ?? this.freePlayRetellParagraphIndex),
      newLearningBreakpointSavedAt: clearNewLearningBreakpointSavedAt
          ? null
          : (newLearningBreakpointSavedAt ?? this.newLearningBreakpointSavedAt),
      freePlayBreakpointSavedAt: clearFreePlayBreakpointSavedAt
          ? null
          : (freePlayBreakpointSavedAt ?? this.freePlayBreakpointSavedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      skippedSubStageKeys: skippedSubStageKeys ?? this.skippedSubStageKeys,
    );
  }
}

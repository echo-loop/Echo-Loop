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

  /// 盲听断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，段时长 > 10s 时段内从该句开播。
  final int? blindListenSentenceIndex;

  /// 精听断点续学句子索引（null 表示从头开始）
  final int? intensiveListenSentenceIndex;

  /// 跟读断点续学句子索引（null 表示从头开始）
  final int? shadowingSentenceIndex;

  /// 难句补练断点续学句子索引（null 表示从头开始）
  final int? difficultPracticeSentenceIndex;

  /// 复述断点续学句子索引（全局句子 index，null 表示从头开始）
  ///
  /// 段内位置：恢复时按句子 index 反查段，段时长 > 10s 时段内从该句开播。
  final int? retellSentenceIndex;

  /// 复述总完成遍数（每次完成复述 +1）
  final int? retellPassCount;

  /// 自由练习-盲听断点句子索引（全局句子 index）
  final int? freePlayBlindListenSentenceIndex;

  /// 自由练习-精听断点句子索引
  final int? freePlayIntensiveListenSentenceIndex;

  /// 自由练习-跟读断点句子索引
  final int? freePlayShadowingSentenceIndex;

  /// 自由练习-难句补练断点句子索引
  final int? freePlayDifficultPracticeSentenceIndex;

  /// 自由练习-复述断点句子索引（全局句子 index）
  final int? freePlayRetellSentenceIndex;

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

  /// 是否暂停学习。true 时该音频不参与复习调度，可由用户随时恢复。
  /// 进度数据完整保留，恢复时按 [nextReviewAt] 原地继续。
  final bool isPaused;

  /// 每个 [LearningStage] 的 plan 版本快照（dense map，snapshot-per-entity）。
  ///
  /// **写入规则**：仅在创建 progress / 迁移时由系统 stamp。日常用户操作
  /// （完成 / 跳过 substep、暂停等）**都不修改**此字段。如未来需要让存量
  /// audio 也升级到新版本，需写显式迁移。
  ///
  /// 新建 progress 时 stamp [kLatestPlanVersions]（dense baseline）；
  /// 既有 audio 在 v33→v34 迁移时按规则回填：baseline 全 v1，未碰过的
  /// review stage（无 stage_completion 记录）升级到 v2。
  ///
  /// 默认 `const {}` 仅用于老测试 / fixture 占位；正常路径下 ensureProgress
  /// 会 stamp [kLatestPlanVersions]。读取用 [planVersionFor] 兜底确保安全。
  ///
  /// 真实子步骤列表由 `LearningPlan.standard(stagePlanVersions: ...)` 派生。
  final Map<LearningStage, int> planVersionsByStage;

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
    this.blindListenSentenceIndex,
    this.intensiveListenSentenceIndex,
    this.shadowingSentenceIndex,
    this.difficultPracticeSentenceIndex,
    this.retellSentenceIndex,
    this.retellPassCount,
    this.freePlayBlindListenSentenceIndex,
    this.freePlayIntensiveListenSentenceIndex,
    this.freePlayShadowingSentenceIndex,
    this.freePlayDifficultPracticeSentenceIndex,
    this.freePlayRetellSentenceIndex,
    this.newLearningBreakpointSavedAt,
    this.freePlayBreakpointSavedAt,
    required this.updatedAt,
    this.skippedSubStageKeys = const {},
    this.isPaused = false,
    this.planVersionsByStage = const {},
  });

  /// 取指定 stage 的 plan 版本：先查 audio snapshot，未指定回退到代码当前最新版。
  ///
  /// 兜底场景：(1) 老 audio 没经历过新增 stage（如未来加 review60）；
  /// (2) 数据损坏 / fixture 未初始化。
  int planVersionFor(LearningStage stage) =>
      planVersionsByStage[stage] ?? kLatestPlanVersions[stage] ?? 1;

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
      if (completedKeys.contains(
        '${LearningStage.firstLearn.key}:${sub.key}',
      )) {
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
    int? blindListenSentenceIndex,
    bool clearBlindListenSentenceIndex = false,
    int? intensiveListenSentenceIndex,
    int? shadowingSentenceIndex,
    int? difficultPracticeSentenceIndex,
    int? retellSentenceIndex,
    int? retellPassCount,
    int? freePlayBlindListenSentenceIndex,
    bool clearFreePlayBlindListenSentenceIndex = false,
    int? freePlayIntensiveListenSentenceIndex,
    bool clearFreePlayIntensiveListenSentenceIndex = false,
    int? freePlayShadowingSentenceIndex,
    bool clearFreePlayShadowingSentenceIndex = false,
    int? freePlayDifficultPracticeSentenceIndex,
    bool clearFreePlayDifficultPracticeSentenceIndex = false,
    int? freePlayRetellSentenceIndex,
    bool clearFreePlayRetellSentenceIndex = false,
    DateTime? newLearningBreakpointSavedAt,
    bool clearNewLearningBreakpointSavedAt = false,
    DateTime? freePlayBreakpointSavedAt,
    bool clearFreePlayBreakpointSavedAt = false,
    DateTime? updatedAt,
    bool clearIntensiveListenSentenceIndex = false,
    bool clearShadowingSentenceIndex = false,
    bool clearDifficultPracticeSentenceIndex = false,
    bool clearRetellSentenceIndex = false,
    Set<String>? skippedSubStageKeys,
    bool? isPaused,
    Map<LearningStage, int>? planVersionsByStage,
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
      blindListenSentenceIndex: clearBlindListenSentenceIndex
          ? null
          : (blindListenSentenceIndex ?? this.blindListenSentenceIndex),
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
      retellSentenceIndex: clearRetellSentenceIndex
          ? null
          : (retellSentenceIndex ?? this.retellSentenceIndex),
      retellPassCount: retellPassCount ?? this.retellPassCount,
      freePlayBlindListenSentenceIndex: clearFreePlayBlindListenSentenceIndex
          ? null
          : (freePlayBlindListenSentenceIndex ??
                this.freePlayBlindListenSentenceIndex),
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
      freePlayRetellSentenceIndex: clearFreePlayRetellSentenceIndex
          ? null
          : (freePlayRetellSentenceIndex ?? this.freePlayRetellSentenceIndex),
      newLearningBreakpointSavedAt: clearNewLearningBreakpointSavedAt
          ? null
          : (newLearningBreakpointSavedAt ?? this.newLearningBreakpointSavedAt),
      freePlayBreakpointSavedAt: clearFreePlayBreakpointSavedAt
          ? null
          : (freePlayBreakpointSavedAt ?? this.freePlayBreakpointSavedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      skippedSubStageKeys: skippedSubStageKeys ?? this.skippedSubStageKeys,
      isPaused: isPaused ?? this.isPaused,
      planVersionsByStage: planVersionsByStage ?? this.planVersionsByStage,
    );
  }
}

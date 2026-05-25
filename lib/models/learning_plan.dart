/// 全局学习计划值对象
///
/// 单一事实来源：每个大阶段当前实际计划做哪些子步骤。
/// 按 audio 持久化的 `planVersionsByStage` 派生，snapshot-per-entity 模式。
/// 「跳过复述」等行为通过 `LearningProgress.skippedSubStageKeys` 在进度侧承载。
library;

import '../database/enums.dart';

/// 每个**带 plan 的** [LearningStage] 当前版本（dense baseline）。
///
/// **dense 原则**：包含所有「带 plan」的 stage，即使该阶段当前只有一个版本
/// （如 `firstLearn`），也显式写出来。这样未来任一带 plan 的 stage 需要新版本：
/// 仅修改本 map + [LearningPlan.standard] 派生分支，迁移结构与持久化格式不变。
///
/// **不包含 `LearningStage.completed`**：completed 是「毕业」终态标记，
/// 无子步骤、无 plan，版本号永远派不上用场。仅作为 `current_stage` 列的状态值。
///
/// **snapshot 写入规则**：新建 progress 时 stamp 本 map（成为该 audio 的快照）。
/// 之后用户的日常操作（完成 / 跳过 substep、暂停等）都**不修改**这个 snapshot。
/// 代码升级 `kLatestPlanVersions[review2] = 3` 后：
/// - 存量 audio 仍保留旧 snapshot（review2=2），自动维持旧 plan
/// - 新建 audio 自动 stamp 新值（review2=3）
/// 如未来需要让存量 audio 也升级，需写一次性迁移显式修改本字段。
const Map<LearningStage, int> kLatestPlanVersions = {
  LearningStage.firstLearn: 1,
  LearningStage.review0: 2,
  LearningStage.review1: 2,
  LearningStage.review2: 2,
  LearningStage.review4: 2,
  LearningStage.review7: 2,
  LearningStage.review14: 2,
  LearningStage.review28: 2,
};

/// 不可变学习计划。
class LearningPlan {
  final Map<LearningStage, List<SubStageType>> _stages;

  const LearningPlan(this._stages);

  /// 按 stage → version map 派生标准计划。
  ///
  /// [stagePlanVersions]：每个 stage 的版本号。空 map 视为「全用 [kLatestPlanVersions]」。
  /// 单个 stage 未在 map 中 → 回退到 `kLatestPlanVersions[stage] ?? 1`（兜底）。
  ///
  /// 各 stage / 版本对应的子步骤：
  /// - firstLearn v1：`[blindListen, intensiveListen, listenAndRepeat, retell]`
  /// - review0 v1：`[reviewDifficultPractice, reviewRetellParagraph]`（旧版）
  /// - review0 v2：`[reviewDifficultPractice, blindListen]`（新版）
  /// - review1 v1：`[blindListen, reviewDifficultPractice, reviewRetellParagraph]`
  /// - review1 v2：`[reviewDifficultPractice, blindListen]`（去段落复述）
  /// - review2/4/7/14 v1：`[blindListen, reviewDifficultPractice, reviewRetellParagraph]`
  /// - review2/4/7/14 v2：`[reviewDifficultPractice, blindListen, reviewRetellParagraph]`
  /// - review28 v1：`[blindListen, reviewDifficultPractice, reviewRetellSummary]`
  /// - review28 v2：`[reviewDifficultPractice, blindListen, reviewRetellParagraph]`
  /// - completed v1：`[]`（终态，无子步骤）
  factory LearningPlan.standard({
    Map<LearningStage, int> stagePlanVersions = const {},
  }) {
    int versionFor(LearningStage stage) =>
        stagePlanVersions[stage] ?? kLatestPlanVersions[stage] ?? 1;

    List<SubStageType> subsFor(LearningStage stage) {
      final v = versionFor(stage);
      switch (stage) {
        case LearningStage.firstLearn:
          // 当前仅 v1；未来加 v2 在此 switch v 分支
          return const [
            SubStageType.blindListen,
            SubStageType.intensiveListen,
            SubStageType.listenAndRepeat,
            SubStageType.retell,
          ];
        case LearningStage.review0:
          return v == 1
              ? const [
                  SubStageType.reviewDifficultPractice,
                  SubStageType.reviewRetellParagraph,
                ]
              : const [
                  SubStageType.reviewDifficultPractice,
                  SubStageType.blindListen,
                ];
        case LearningStage.review1:
          return v == 1
              ? const [
                  SubStageType.blindListen,
                  SubStageType.reviewDifficultPractice,
                  SubStageType.reviewRetellParagraph,
                ]
              : const [
                  SubStageType.reviewDifficultPractice,
                  SubStageType.blindListen,
                ];
        case LearningStage.review2:
        case LearningStage.review4:
        case LearningStage.review7:
        case LearningStage.review14:
          return v == 1
              ? const [
                  SubStageType.blindListen,
                  SubStageType.reviewDifficultPractice,
                  SubStageType.reviewRetellParagraph,
                ]
              : const [
                  SubStageType.reviewDifficultPractice,
                  SubStageType.blindListen,
                  SubStageType.reviewRetellParagraph,
                ];
        case LearningStage.review28:
          return v == 1
              ? const [
                  SubStageType.blindListen,
                  SubStageType.reviewDifficultPractice,
                  SubStageType.reviewRetellSummary,
                ]
              : const [
                  SubStageType.reviewDifficultPractice,
                  SubStageType.blindListen,
                  SubStageType.reviewRetellParagraph,
                ];
        case LearningStage.completed:
          return const [];
      }
    }

    return LearningPlan({
      for (final stage in LearningStage.values)
        stage: List<SubStageType>.unmodifiable(subsFor(stage)),
    });
  }

  /// 指定大阶段的计划子步骤列表（有序）。
  ///
  /// 该阶段无任何 planned 子步骤时返回空列表（如 [LearningStage.completed]）。
  List<SubStageType> subStagesFor(LearningStage stage) =>
      _stages[stage] ?? const [];

  /// 判断 [sub] 是否在 [stage] 的计划列表内。
  bool includes(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).contains(sub);

  /// 返回 [sub] 在 [stage] 计划列表中的索引；不在列表返回 -1。
  int indexOf(LearningStage stage, SubStageType sub) =>
      subStagesFor(stage).indexOf(sub);

  /// 全部 planned 子步骤计数（跨所有阶段，用作进度比例分母）。
  int get totalPlannedCount => _stages.values.fold(0, (s, l) => s + l.length);

  /// 找当前阶段 plan 内 [currentSubStage] 之后的下一个 planned 子步骤。
  ///
  /// - 当前阶段 plan 内有后续 → 返回 `(stage, nextSubStage)`
  /// - 当前是 plan 末尾、不在 plan、或阶段 plan 空 → 返回 `null`
  ({LearningStage stage, SubStageType subStage})? nextPlannedAfter(
    LearningStage currentStage,
    SubStageType currentSubStage,
  ) {
    final planned = subStagesFor(currentStage);
    final idx = planned.indexOf(currentSubStage);
    if (idx < 0) return null;
    if (idx + 1 >= planned.length) return null;
    return (stage: currentStage, subStage: planned[idx + 1]);
  }
}

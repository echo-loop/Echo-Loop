/// 全局学习计划 Provider
///
/// 计划现在是静态结构（每个大阶段的全量 `allSubStages`），不再依赖任何用户设置。
/// 「不做某类子阶段」改由 `LearningProgress.skippedSubStageKeys` 在进度侧承载，
/// 与未来「用户自定义学习计划」正交。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_plan.dart';

final learningPlanProvider = Provider<LearningPlan>((ref) {
  return LearningPlan.standard();
});

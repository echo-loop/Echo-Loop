/// 学习计划 Provider
///
/// 默认 plan（[learningPlanProvider]）使用 [kLatestPlanVersions]（代码当前最新版），
/// 仅用于无音频上下文的全局求和、设置页统计等场景。
///
/// 渲染或推进某条音频时必须用 [learningPlanForAudioProvider]：直读
/// `progress.planVersionsByStage`（snapshot），永不从可变数据反推。
///
/// 「不做某类子阶段」语义由 `LearningProgress.skippedSubStageKeys` 在进度侧承载。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_plan.dart';
import 'learning_progress_provider.dart';

/// 全局默认 plan（kLatestPlanVersions）。不绑定具体音频。
final learningPlanProvider = Provider<LearningPlan>((ref) {
  return LearningPlan.standard();
});

/// 按音频派生 plan。直读 `progress.planVersionsByStage` 持久化快照。
///
/// progress 不存在（音频从未开始）时退化为默认 plan（kLatestPlanVersions）。
final learningPlanForAudioProvider = Provider.family<LearningPlan, String>((
  ref,
  audioItemId,
) {
  final progressState = ref.watch(learningProgressNotifierProvider);
  final progress = progressState.progressMap[audioItemId];
  return LearningPlan.standard(
    stagePlanVersions: progress?.planVersionsByStage ?? const {},
  );
});

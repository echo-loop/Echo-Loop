/// AI 功能的「免费试用次数」配置（永久额度，非每月重置）。
///
/// 每个 [PremiumFeature] 各自配置一个**永久**试用次数：未订阅用户在登录后，
/// 每个功能可免费使用该次数，用尽即触发订阅升级（Paywall）。次数累计计数、
/// 不随时间重置（区别于「每月配额」）。
///
/// **当前全部设为 0**：即未订阅用户登录后任何 AI 功能都直接撞墙、引导升级。
/// 后续要放开试用，只需调大对应数值（接口已就绪）。
///
/// 注意（C1）：本地次数仅作**预测性**额度，最终配额裁决在后端（Phase 1 接入）。
/// 本地计数可被卸载重装绕过，不作可信裁决依据。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/premium_feature.dart';

/// 各 AI 功能的永久免费试用次数（缺省 0）。
const Map<PremiumFeature, int> kAiTrialLimits = {
  PremiumFeature.aiTranslation: 0,
  PremiumFeature.aiAnalysis: 0,
  PremiumFeature.aiSenseGroup: 0,
  PremiumFeature.aiWordAnalysis: 0,
  PremiumFeature.aiTranscription: 0,
  PremiumFeature.aiChat: 0,
};

/// 某功能的永久免费试用次数（未配置视为 0）。
int aiTrialLimitOf(PremiumFeature feature) => kAiTrialLimits[feature] ?? 0;

/// 试用次数配置 Provider（测试可 override 以验证 limit > 0 时的放行）。
final aiTrialLimitsProvider = Provider<Map<PremiumFeature, int>>((ref) {
  return kAiTrialLimits;
});

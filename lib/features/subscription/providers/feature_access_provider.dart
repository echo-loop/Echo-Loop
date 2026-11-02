/// 付费墙挂接 API：查询某能力是否解锁。
///
/// 业务各处只 `ref.watch(featureAccessProvider(feature))`，对订阅 / RevenueCat 零感知
/// （解耦核心）。新增付费点 = 给 [PremiumFeature] 加一项 + 配置免费额度，调用点不变。
///
/// 判定口径（三层，自上而下）：
/// - **未登录 → 一律锁定**：高级功能（含免费额度）只发放给已登录用户。权益须绑定
///   Supabase user_id 才可信、可跨设备恢复（匿名 RevenueCat 身份随重装重置、不可靠）。
///   未登录用户撞墙时统一引导先登录（见 `openPaywall`）。
/// - 已确认 Premium（pro）→ 解锁。
/// - 已登录的免费用户 → 交由 [FreeAllowancePolicy] 做**本地预测性放行**（有限免费额度，
///   Phase 0 一律放行）。注意：最终撞墙真相在后端（C1），本地放行不代表后端一定放行。
/// - unknown 中间态按「未持有权益」处理，由免费额度策略兜底，避免冷启动误锁。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/premium_feature.dart';
import '../services/free_allowance_policy.dart';
import 'subscription_controller.dart';

part 'feature_access_provider.g.dart';

/// 某 [feature] 当前是否对用户可用。
@riverpod
bool featureAccess(Ref ref, PremiumFeature feature) {
  // 第一层：未登录禁用一切高级功能（连免费额度也不发放，须先登录）。
  if (!ref.watch(isAuthenticatedProvider)) return false;
  // 第二层：已确认 Premium → 无限解锁。
  final entitlement = ref.watch(subscriptionControllerProvider);
  if (entitlement.isActive) return true;
  // 第三层：已登录的免费用户 → 由免费额度策略决定（有限次数）。
  return ref.watch(freeAllowancePolicyProvider).allows(feature);
}

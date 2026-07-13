/// 购买服务接口（IAP 抽象层）。
///
/// 业务层与 SubscriptionController 只依赖本接口，**不依赖 RevenueCat**。
/// RevenueCat 实现（唯一 import purchases_flutter 处）留待 Phase 2，
/// 届时新增 `RevenueCatPurchaseService implements PurchaseService` 替换 [StubPurchaseService]，
/// 上层零改动（解耦核心，便于将来迁移）。
library;

import '../models/entitlement.dart';
import '../models/subscription_plan.dart';

/// 购买流程异常。
class PurchaseException implements Exception {
  PurchaseException(this.message, {this.cancelled = false});

  /// 错误描述。
  final String message;

  /// 是否为用户主动取消（取消不应视为错误弹窗，仅回到 Paywall）。
  final bool cancelled;

  @override
  String toString() => 'PurchaseException($message, cancelled: $cancelled)';
}

/// IAP 购买服务抽象。
abstract class PurchaseService {
  /// 拉取可购买套餐（从平台 SDK 取本地化价格）。
  ///
  /// 关闭 [includeIntroEligibility] 时优先返回基础价格，避免 iOS 促销资格查询
  /// 阻塞 paywall 首屏；购买行为始终由平台在成交时应用真实可用 offer。
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  });

  /// 当前权益快照（来自平台 / RevenueCat 已校验的 CustomerInfo）。
  ///
  /// 作为「在线权威源」供 SubscriptionController 对账（RevenueCat 已做服务端收据
  /// 校验，结果不可被客户端伪造）。无购买返回 [Entitlement.free]；
  /// 平台不可达时抛异常，由调用方走缓存兜底。
  Future<Entitlement> currentEntitlement();

  /// 权益变化流（续费 / 退款 / 试用转正等平台侧事件触发）。
  ///
  /// SubscriptionController 监听它在 app 运行期实时刷新权益。
  Stream<Entitlement> get entitlementStream;

  /// 发起购买。成功返回购买后本地可见的权益快照（如 RC CustomerInfo 派生），
  /// 用户取消 / 失败抛出 [PurchaseException]。
  Future<Entitlement> purchase(String planId);

  /// 恢复购买。返回恢复后的权益快照（无可恢复购买返回 [Entitlement.free]）。
  Future<Entitlement> restore();

  /// 将购买服务绑定到指定用户（如 RevenueCat `logIn`）。匿名为 null。
  Future<void> identify(String? userId);

  /// 确保购买服务已绑定到 [userId]，并**核对绑定确已生效**。
  ///
  /// 购买 / 恢复前的 fail-closed 校验入口：权益必须挂在 Supabase user_id 上，
  /// 绝不允许落在 RevenueCat 匿名身份（否则 webhook 无法映射用户、Supabase 无记录）。
  /// RC 实现：`logIn(userId)` 后核对 `Purchases.appUserID == userId`；
  /// 未就绪 / 不匹配 / 异常一律返回 false，调用方据此中止购买。
  Future<bool> ensureIdentified(String userId);

  /// 使平台 SDK 的 CustomerInfo 本地缓存失效，强制下次回源服务端。
  ///
  /// 调试用：后台删除订阅后，SDK 仍会优先返回本地缓存的 CustomerInfo，
  /// 导致权益看似仍生效。失效后配合 [currentEntitlement] 重新对账可看到真实结果。
  Future<void> invalidateCustomerInfoCache();

  /// 返回平台 SDK 的原始权益诊断快照（调试面板展示用）。
  ///
  /// 暴露 activeEntitlements / allEntitlements / activeSubscriptions /
  /// originalAppUserId / 期望的 entitlementId 等原始字段，便于定位
  /// 「商品没挂 entitlement」「entitlement 标识没对上」等配置问题。
  Future<Map<String, Object?>> debugCustomerInfoSnapshot();

  /// 当前 App Store / 商店账号所在 storefront 的国家码（ISO 3166-1 alpha-3，
  /// 如 `USA` / `CHN`）。用于按用户真实商店区判定行为（如更新检查查哪个区的
  /// Lookup），口径与本地化价格一致。取不到（未配置 / 无 storefront 概念）返回
  /// `null`，由调用方回退默认区。
  Future<String?> storefrontCountryCode();
}

/// Phase 0 占位实现：无平台依赖，不发起真实购买。
///
/// 让解耦骨架可独立联调与单测；真实购买能力在 Phase 2 接入 RevenueCat。
class StubPurchaseService implements PurchaseService {
  const StubPurchaseService();

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async => const [];

  @override
  Future<Entitlement> currentEntitlement() async => Entitlement.free;

  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();

  @override
  Future<Entitlement> purchase(String planId) async {
    throw PurchaseException('购买能力未配置（缺 RevenueCat API Key）');
  }

  @override
  Future<Entitlement> restore() async => Entitlement.free;

  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<bool> ensureIdentified(String userId) async => false;

  @override
  Future<void> invalidateCustomerInfoCache() async {}

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async => const {};

  @override
  Future<String?> storefrontCountryCode() async => null;
}

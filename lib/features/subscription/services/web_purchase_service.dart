/// 网页支付渠道的购买服务（侧载 APK / macOS 官网 / Windows）。
///
/// 这些端**没有可用的 RevenueCat 原生 SDK**：购买在 in-app browser 打开
/// RevenueCat 托管的 Web Paywall（底层计费引擎为 Paddle），本进程内无法同步拿到购买结果。因此本服务
/// 只作为 [SubscriptionController] 的最小占位，**权益一律经后端
/// `/api/entitlements`（[BackendEntitlementRepository]）读回**：
///
/// - [purchase] / [restore]：不由本服务承担——Paywall 网页态直接打开托管 Paywall
///   （见 `web_purchase_config.dart` 的 [buildWebPurchaseUri]）并轮询
///   [SubscriptionController.refresh] 等后端到账，不走 `PurchaseService.purchase`。
///   故这两个方法抛 [UnsupportedError]（正常路径不会调用）。
/// - [currentEntitlement]：**抛异常**（平台不可达语义）——使 [refresh] 在后端仓库
///   返回 null（离线/未就绪）时走缓存兜底，而非把「无 RC 在线源」误判为
///   [Entitlement.free] 造成付费用户离线被误降级。
library;

import 'dart:async';

import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import 'purchase_service.dart';
import '../../../config/web_purchase_config.dart';
import '../../../services/app_logger.dart';

/// 网页支付渠道购买服务（详见文件级文档）。
class WebPurchaseService implements PurchaseService {
  const WebPurchaseService();

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async {
    // 无商店 SDK 取本地化价；套餐、价格与促销由 RevenueCat 托管 Paywall 展示。
    logWebPurchaseConfig(stage: 'fetchPlans');
    AppLogger.log(
      'Subscription',
      'webPurchase[fetchPlans] plans=empty reason=hosted_paywall_prices_managed_by_revenuecat_paddle',
    );
    return const [];
  }

  @override
  Future<Entitlement> currentEntitlement() async {
    // 抛异常 = 平台不可达，交由上层走缓存兜底（不可返回 free，否则离线误降级）。
    AppLogger.log(
      'Subscription',
      'webPurchase[currentEntitlement] unavailable: entitlement must be read from backend /api/entitlements',
    );
    throw StateError('网页支付渠道无客户端权益源，权益经后端 /api/entitlements 读回');
  }

  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();

  @override
  Future<Entitlement> purchase(String planId) async {
    AppLogger.log(
      'Subscription',
      'webPurchase[purchase] unsupported planId=$planId reason=hosted_paywall',
    );
    throw UnsupportedError('网页支付经浏览器结账，不走 PurchaseService.purchase');
  }

  @override
  Future<Entitlement> restore() async {
    AppLogger.log(
      'Subscription',
      'webPurchase[restore] unsupported reason=use_backend_refresh',
    );
    throw UnsupportedError('网页支付无平台恢复，改为触发后端权益对账（refresh）');
  }

  @override
  Future<void> identify(String? userId) async {
    // 身份通过 Web Purchase Link 里的 app_user_id 传递，无需在此绑定。
  }

  @override
  Future<bool> ensureIdentified(String userId) async {
    // 网页渠道结账时以 supabase user_id 作 app_user_id，身份不经 RC 匿名机制，
    // 无匿名购买风险，门禁直接通过。
    AppLogger.log(
      'Subscription',
      'webPurchase[ensureIdentified] userIdPresent=${userId.isNotEmpty} '
          'userIdLength=${userId.length} result=true',
    );
    return true;
  }

  @override
  Future<void> invalidateCustomerInfoCache() async {}

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async => const {};

  @override
  Future<String?> storefrontCountryCode() async => null;
}

/// 本地 StoreKit 购买服务（开发/测试专用，**绕开 RevenueCat**）。
///
/// 直连 `in_app_purchase` 操作 Xcode `.storekit` 本地配置的商品，权益状态只存在于
/// StoreKit 本地，**不经过、也不上报 RevenueCat**（RC SDK 在此模式下不初始化，见
/// `revenuecat_config.dart` 的 [useLocalStoreKit] 与 `main.dart`）。这样 Xcode /
/// App 两处状态单一可控，不会污染 RevenueCat 的 Sandbox customers，也避免「RC 缓存
/// 让 app 一直显示已订阅」。
///
/// 重置：在 Xcode「Debug ▸ StoreKit ▸ Manage Transactions」删交易（或取消订阅 + 加速
/// 续期使其到期）后，调「恢复购买 / 清缓存强刷」即重建活跃集合、正确降级，无需重启。
///
/// 仅供本地开发联调；release 构建不应启用本服务。
library;

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../config/revenuecat_config.dart' show revenueCatEntitlementId;
import '../../../services/app_logger.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import 'purchase_service.dart';

// ── 商品标识与纯映射逻辑（可单测，不依赖平台通道）────────────────

/// 月度订阅商品 ID（与 `.storekit` / 商店后台一致）。
const echoLoopMonthlyProductId = 'echo_loop_plus_monthly';

/// 年度订阅商品 ID（含 7 天免费试用）。
const echoLoopAnnualProductId = 'echo_loop_plus_annual';

/// 本地 StoreKit 测试涉及的全部商品 ID。
const localStoreKitProductIds = {
  echoLoopMonthlyProductId,
  echoLoopAnnualProductId,
};

/// 商品 ID → 订阅周期（未知商品容错为月付）。
SubscriptionPeriod localPlanPeriod(String productId) =>
    productId == echoLoopAnnualProductId
    ? SubscriptionPeriod.yearly
    : SubscriptionPeriod.monthly;

/// 商品 ID → 免费试用天数（仅年付含 7 天，与 `.storekit` introductoryOffer 一致）。
int localPlanTrialDays(String productId) =>
    productId == echoLoopAnnualProductId ? 7 : 0;

/// 活跃订阅商品 ID 集合 → [Entitlement]（单等级会员，不分级）。
///
/// 无活跃订阅返回 [Entitlement.free]；有则任取一个作代表（年付优先）。
/// 不设 [Entitlement.expiresAt]（视为持续有效），到期/退款由 StoreKit 本地交易控制——
/// 在 Xcode「Manage Transactions」删除交易即失效。
Entitlement localEntitlementFromActiveIds(
  Set<String> activeProductIds, {
  required String entitlementId,
}) {
  if (activeProductIds.isEmpty) return Entitlement.free;
  final productId = activeProductIds.contains(echoLoopAnnualProductId)
      ? echoLoopAnnualProductId
      : activeProductIds.first;
  return Entitlement(
    isPremium: true,
    activeEntitlements: {entitlementId},
    productId: productId,
    period: localPlanPeriod(productId),
    willRenew: true,
  );
}

// ── 服务实现 ────────────────────────────────────────────────────

/// 基于 `in_app_purchase` 的本地 StoreKit 购买服务。
class LocalStoreKitPurchaseService implements PurchaseService {
  LocalStoreKitPurchaseService({
    InAppPurchase? iap,
    String entitlementId = revenueCatEntitlementId,
    Duration restoreSettleDelay = const Duration(seconds: 1),
  }) : _iap = iap ?? InAppPurchase.instance,
       _entitlementId = entitlementId,
       _restoreSettleDelay = restoreSettleDelay {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object e) =>
          AppLogger.log('Subscription', '本地 StoreKit 购买流错误: $e'),
    );
    // 启动即恢复历史交易，重建当前权益（`.storekit` 续订交易会重新投递）。
    unawaited(_iap.restorePurchases());
  }

  final InAppPurchase _iap;
  final String _entitlementId;

  /// 重建活跃集合时，等待购买流投递 restored 回执的时间窗口。
  ///
  /// `restorePurchases` 的回执经 `purchaseStream` 异步到达，无跨平台「完成」信号，
  /// 故用一个有界等待让回执落地后再读取快照。测试可传 [Duration.zero]。
  final Duration _restoreSettleDelay;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  /// 当前活跃的订阅商品 ID（由购买流维护，是本服务的真相源）。
  final Set<String> _activeProductIds = {};

  /// 桥接购买流 → [Entitlement] 的广播流（供 SubscriptionController 监听）。
  final StreamController<Entitlement> _entitlementController =
      StreamController<Entitlement>.broadcast();

  /// 等待结果的购买请求：productId → Completer。
  final Map<String, Completer<Entitlement>> _pending = {};

  /// 资源释放（由 provider 的 `ref.onDispose` 调用）。
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_entitlementController.close());
  }

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async {
    final available = await _iap.isAvailable();
    if (!available) {
      AppLogger.log('Subscription', '本地 StoreKit 不可用（IAP isAvailable=false）');
      return const [];
    }
    final response = await _iap.queryProductDetails(localStoreKitProductIds);
    if (response.error != null) {
      AppLogger.log('Subscription', '本地 StoreKit 查询商品失败: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      AppLogger.log(
        'Subscription',
        '本地 StoreKit 未找到商品: ${response.notFoundIDs}（检查 scheme 是否挂了 .storekit）',
      );
    }
    return response.productDetails.map(_planFrom).toList();
  }

  @override
  Future<Entitlement> currentEntitlement() async => _currentEntitlement();

  @override
  Stream<Entitlement> get entitlementStream => _entitlementController.stream;

  @override
  Future<Entitlement> purchase(String planId) async {
    final response = await _iap.queryProductDetails({planId});
    final matches = response.productDetails.where((p) => p.id == planId);
    if (matches.isEmpty) {
      throw PurchaseException('商品不存在或 .storekit 未配置：$planId');
    }
    final product = matches.first;
    AppLogger.log(
      'Subscription',
      '本地 StoreKit 发起购买: planId=$planId price=${product.price}',
    );
    // 用 Completer 等待购买流回执（buyNonConsumable 仅表示请求已发起）。
    final completer = Completer<Entitlement>();
    _pending[planId] = completer;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _pending.remove(planId);
      throw PurchaseException('发起购买失败：$e');
    }
    return completer.future;
  }

  @override
  Future<Entitlement> restore() async => _rebuildActiveFromStore();

  @override
  Future<void> identify(String? userId) async {
    // 本地模式无用户绑定（StoreKit 本地交易与账号无关）。
  }

  @override
  Future<bool> ensureIdentified(String userId) async {
    // 本地 StoreKit 测试态，不经 RC 匿名机制，门禁直接通过。
    return true;
  }

  @override
  Future<void> invalidateCustomerInfoCache() async {
    // 无 RC 缓存可失效；以重建活跃集合作为「回源刷新」（删交易/取消后能正确降级）。
    await _rebuildActiveFromStore();
  }

  /// 从 StoreKit 重建活跃订阅集合。
  ///
  /// **先清空再恢复**：`restorePurchases` 只会重新投递「当前仍有效」的订阅，
  /// 已取消/过期/删除的交易不再投递，集合自然收敛。这样在 Xcode 删交易或订阅到期后，
  /// 调一次本方法（恢复购买 / 清缓存强刷）即可正确降级，**无需重启 App**。
  Future<Entitlement> _rebuildActiveFromStore() async {
    _activeProductIds.clear();
    await _iap.restorePurchases();
    // 等回执经购买流落地后再读快照（详见 [_restoreSettleDelay]）。
    await Future<void>.delayed(_restoreSettleDelay);
    AppLogger.log(
      'Subscription',
      '本地 StoreKit 重建活跃集合: ${_activeProductIds.toList()}',
    );
    return _currentEntitlement();
  }

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async {
    return {
      'mode': 'localStoreKit（已绕开 RevenueCat）',
      'lookForEntitlementId': _entitlementId,
      'activeProductIds': _activeProductIds.toList(),
      'isPremium': _activeProductIds.isNotEmpty,
    };
  }

  @override
  Future<String?> storefrontCountryCode() async => null;

  // ── 内部 ──────────────────────────────────────────────────────

  Entitlement _currentEntitlement() => localEntitlementFromActiveIds(
    _activeProductIds,
    entitlementId: _entitlementId,
  );

  SubscriptionPlan _planFrom(ProductDetails product) {
    final trialDays = localPlanTrialDays(product.id);
    return SubscriptionPlan(
      planId: product.id,
      title: product.title,
      priceString: product.price,
      period: localPlanPeriod(product.id),
      hasFreeTrial: trialDays > 0,
      trialDays: trialDays,
    );
  }

  /// 处理购买流更新：维护活跃商品集合、兑现等待中的购买、回执完成交易。
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue; // 等待中，不处理。
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _activeProductIds.add(purchase.productID);
          AppLogger.log(
            'Subscription',
            '本地 StoreKit 交易回执: productId=${purchase.productID} '
                'status=${purchase.status.name} 活跃集合=${_activeProductIds.toList()}',
          );
          _pending.remove(purchase.productID)?.complete(_currentEntitlement());
        case PurchaseStatus.canceled:
          _pending
              .remove(purchase.productID)
              ?.completeError(PurchaseException('用户取消购买', cancelled: true));
        case PurchaseStatus.error:
          AppLogger.log('Subscription', '本地 StoreKit 购买出错: ${purchase.error}');
          _pending
              .remove(purchase.productID)
              ?.completeError(
                PurchaseException(purchase.error?.message ?? '购买失败'),
              );
      }
      // 未完成的交易必须回执，否则会反复投递。
      await _completePurchaseSafely(purchase);
    }
    if (!_entitlementController.isClosed) {
      _entitlementController.add(_currentEntitlement());
    }
  }

  /// 安全回执交易，规避 `in_app_purchase_storekit` 0.4.10 的 SK2 崩溃。
  ///
  /// StoreKit2 默认开启，其 `completePurchase` 执行 `int.parse(purchaseID!)`；当原生
  /// 交易 `id` 为 0（取消/无效交易）时 `purchaseID` 为 null，`!` 直接抛
  /// `Null check operator used on a null value`。这类交易无有效 id，本就无法 finish，
  /// 故直接跳过；其余异常也兜住，避免插件层崩溃拖垮整个 app。
  Future<void> _completePurchaseSafely(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    if (purchase.purchaseID == null) {
      AppLogger.log(
        'Subscription',
        '跳过回执：交易缺少 purchaseID（SK2 id=0），product=${purchase.productID} status=${purchase.status}',
      );
      return;
    }
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      AppLogger.log('Subscription', '本地 StoreKit 回执交易失败: $e');
    }
  }
}

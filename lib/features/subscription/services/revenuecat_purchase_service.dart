/// RevenueCat 购买服务实现（**唯一 import purchases_flutter 的文件**）。
///
/// 把 RevenueCat 的 Offerings / Package / CustomerInfo 等 SDK 类型映射为业务层的
/// [SubscriptionPlan] / [Entitlement]，对上层完全隐藏第三方 SDK（解耦核心，便于迁移）。
///
/// RevenueCat 已在服务端做收据校验，[currentEntitlement] 返回的权益不可被客户端伪造，
/// 因此作为「在线权威源」可信。SDK 的 `Purchases.configure(...)` 在 main.dart 完成。
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../config/client_distribution.dart';
import '../../../config/revenuecat_config.dart';
import '../../../config/web_purchase_config.dart';
import '../../../services/app_logger.dart';
import '../models/entitlement.dart';
import '../models/subscription_plan.dart';
import 'local_storekit_purchase_service.dart';
import 'purchase_service.dart';
import 'web_purchase_service.dart';

class RevenueCatPurchaseService implements PurchaseService {
  RevenueCatPurchaseService({String entitlementId = revenueCatEntitlementId})
    : _entitlementId = entitlementId;

  /// 代表 Premium 的 RevenueCat entitlement identifier。
  final String _entitlementId;

  /// 商品 ID → 订阅周期缓存。由 offering/package（含权威 packageType）填充，
  /// 供 [_entitlementFrom] 给已购权益标注准确周期（CustomerInfo 本身不含周期）。
  final Map<String, SubscriptionPeriod> _periodByProductId = {};

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async {
    try {
      if (kDebugMode) {
        unawaited(_logStorefront('fetchPlans:beforeOfferings'));
      }
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      AppLogger.log(
        'Subscription',
        'getOfferings: allOfferings=${offerings.all.keys.toList()} '
            'current=${current?.identifier} '
            'packages=${current?.availablePackages.length ?? 0}',
      );
      if (current == null) {
        AppLogger.log(
          'Subscription',
          'current offering 为空：RevenueCat 未设 current offering，或商品未同步。',
        );
        return const [];
      }
      if (current.availablePackages.isEmpty) {
        AppLogger.log(
          'Subscription',
          'current offering 有但 packages 为空：商品未挂到 offering，或 StoreKit '
              '取不到商品（macOS 本地构建沙盒常见 / 商品未传播 / metadata 不全）。',
        );
      }
      for (final p in current.availablePackages) {
        _logPackageDiagnostics(p, stage: 'fetchPlans:offering');
      }
      if (kDebugMode) {
        unawaited(
          _logDirectProductsForDiagnostics(
            current.availablePackages
                .map((p) => p.storeProduct.identifier)
                .toSet()
                .toList(),
            stage: 'fetchPlans:directProducts',
          ),
        );
      }
      final eligibility = includeIntroEligibility
          ? await _introEligibilityFor(current.availablePackages)
          : const <String, IntroEligibilityStatus>{};
      final plans = current.availablePackages
          .map((p) => _packageToPlan(p, eligibility[p.storeProduct.identifier]))
          .toList();
      for (final plan in plans) {
        _logMappedPlan(plan, stage: 'fetchPlans:mappedPlan');
      }
      return plans;
    } catch (e) {
      AppLogger.log('Subscription', 'getOfferings 异常: $e');
      rethrow;
    }
  }

  @override
  Future<Entitlement> currentEntitlement() async {
    final info = await Purchases.getCustomerInfo();
    return _entitlementFrom(info);
  }

  @override
  Stream<Entitlement> get entitlementStream {
    // 把 RevenueCat 的 CustomerInfo 更新监听桥接成 Entitlement 流。
    final controller = StreamController<Entitlement>();
    void listener(CustomerInfo info) {
      controller.add(_entitlementFrom(info));
    }

    Purchases.addCustomerInfoUpdateListener(listener);
    controller.onCancel = () {
      Purchases.removeCustomerInfoUpdateListener(listener);
    };
    return controller.stream;
  }

  @override
  Future<Entitlement> purchase(String planId) async {
    final package = await _findPackage(planId);
    if (package == null) {
      AppLogger.log('Subscription', 'RC purchase: 套餐不存在或已下架 planId=$planId');
      throw PurchaseException('套餐不存在或已下架：$planId');
    }
    AppLogger.log(
      'Subscription',
      'RC purchase 发起: package=${package.identifier} '
          'product=${package.storeProduct.identifier} '
          'price=${package.storeProduct.priceString}',
    );
    await _logStorefront('purchase:beforeSheet');
    await _logDirectProductsForDiagnostics([
      package.storeProduct.identifier,
    ], stage: 'purchase:directProductBeforeSheet');
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      AppLogger.log('Subscription', 'RC purchase 完成: 交易成功，开始映射权益');
      return _entitlementFrom(result.customerInfo);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseException('用户取消购买', cancelled: true);
      }
      AppLogger.log('Subscription', 'purchase 失败 code=$code msg=${e.message}');
      throw PurchaseException(e.message ?? '购买失败');
    }
  }

  @override
  Future<Entitlement> restore() async {
    AppLogger.log('Subscription', 'RC restorePurchases 发起');
    try {
      final info = await Purchases.restorePurchases();
      return _entitlementFrom(info);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseException('用户取消恢复', cancelled: true);
      }
      AppLogger.log('Subscription', 'restore 失败 code=$code msg=${e.message}');
      throw PurchaseException(e.message ?? '恢复失败');
    }
  }

  @override
  Future<void> identify(String? userId) async {
    // 把 RevenueCat App User ID 绑定到 Supabase user.id；登出回到匿名 ID。
    if (userId == null) {
      await Purchases.logOut();
    } else {
      await Purchases.logIn(userId);
    }
  }

  @override
  Future<bool> ensureIdentified(String userId) async {
    // 购买前 fail-closed 校验：logIn（幂等）后核对 RC 当前 App User ID 确为
    // 该 Supabase user_id，绑不上宁可返回 false 让上层报错，也不产生匿名购买。
    try {
      await Purchases.logIn(userId);
      final current = await Purchases.appUserID;
      final ok = current == userId;
      AppLogger.log(
        'Subscription',
        'ensureIdentified: 期望=$userId 实际=$current → ${ok ? "已绑定" : "未匹配"}',
      );
      return ok;
    } catch (e) {
      AppLogger.log('Subscription', 'ensureIdentified 失败: $e');
      return false;
    }
  }

  @override
  Future<void> invalidateCustomerInfoCache() async {
    await Purchases.invalidateCustomerInfoCache();
    AppLogger.log('Subscription', 'invalidateCustomerInfoCache: 已使 RC 缓存失效');
  }

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async {
    final info = await Purchases.getCustomerInfo();
    return {
      'lookForEntitlementId': _entitlementId,
      'activeEntitlements': info.entitlements.active.keys.toList(),
      'allEntitlements': info.entitlements.all.keys.toList(),
      'activeSubscriptions': info.activeSubscriptions.toList(),
      'originalAppUserId': info.originalAppUserId,
      'managementURL': info.managementURL,
      'latestExpirationDate': info.latestExpirationDate,
    };
  }

  // ── 映射：SDK 类型 → 业务模型 ──────────────────────────────

  Future<Package?> _findPackage(String planId) async {
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const [];
    for (final p in packages) {
      // 顺带填充周期缓存：购买后 _entitlementFrom 即可给权益标注准确周期，
      // 无需依赖 Paywall 是否先调过 fetchPlans。
      _periodByProductId[p.storeProduct.identifier] = _periodFrom(
        p.packageType,
      );
      if (p.identifier == planId || p.storeProduct.identifier == planId) {
        return p;
      }
    }
    return null;
  }

  Future<Map<String, IntroEligibilityStatus>> _introEligibilityFor(
    List<Package> packages,
  ) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) return const {};
    final productIds = packages
        .where((p) => p.storeProduct.introductoryPrice != null)
        .map((p) => p.storeProduct.identifier)
        .toList();
    if (productIds.isEmpty) return const {};
    try {
      final result = await Purchases.checkTrialOrIntroductoryPriceEligibility(
        productIds,
      );
      return result.map((key, value) => MapEntry(key, value.status));
    } catch (e) {
      AppLogger.log('Subscription', 'intro eligibility 查询失败: $e');
      return const {};
    }
  }

  SubscriptionPlan _packageToPlan(
    Package package,
    IntroEligibilityStatus? introEligibility,
  ) {
    final product = package.storeProduct;
    final intro = _introOfferFrom(product, introEligibility);
    final hasFreeTrial = intro != null && intro.isFreeTrial;
    final period = _periodFrom(package.packageType);
    // 记录商品 ID → 周期，供已购权益（CustomerInfo 无周期字段）标注准确套餐名。
    // storeProduct.identifier 与 EntitlementInfo.productIdentifier 同源可对应。
    _periodByProductId[product.identifier] = period;
    return SubscriptionPlan(
      planId: package.identifier,
      title: product.title,
      priceString: product.priceString,
      period: period,
      hasFreeTrial: hasFreeTrial,
      trialDays: hasFreeTrial ? _trialDays(intro) : 0,
      introOffer: intro,
    );
  }

  void _logPackageDiagnostics(Package package, {required String stage}) {
    final product = package.storeProduct;
    final intro = product.introductoryPrice;
    AppLogger.log(
      'Subscription',
      'package[$stage] package=${package.identifier} type=${package.packageType} '
          'product=${product.identifier} title=${product.title} '
          'price=${product.priceString} rawPrice=${product.price} '
          'currency=${product.currencyCode} subscriptionPeriod=${product.subscriptionPeriod ?? "null"} '
          'pricePerMonth=${product.pricePerMonthString ?? "null"} '
          'pricePerYear=${product.pricePerYearString ?? "null"} '
          'introductoryPrice=${intro == null ? "null" : _introPriceSummary(intro)} '
          'defaultOption=${_optionSummary(product.defaultOption)} '
          'subscriptionOptions=${_optionsSummary(product.subscriptionOptions)}',
    );
  }

  void _logMappedPlan(SubscriptionPlan plan, {required String stage}) {
    AppLogger.log(
      'Subscription',
      'plan[$stage] id=${plan.planId} title=${plan.title} '
          'period=${plan.period} price=${plan.priceString} '
          'hasFreeTrial=${plan.hasFreeTrial} trialDays=${plan.trialDays} '
          'introOffer=${_mappedIntroSummary(plan.introOffer)}',
    );
  }

  String _introPriceSummary(IntroductoryPrice intro) {
    return '{price=${intro.priceString}, raw=${intro.price}, period=${intro.period}, '
        'unit=${intro.periodUnit}, units=${intro.periodNumberOfUnits}, cycles=${intro.cycles}}';
  }

  String _optionsSummary(List<SubscriptionOption>? options) {
    if (options == null) return 'null';
    if (options.isEmpty) return 'empty';
    return options.map(_optionSummary).join(' | ');
  }

  String _optionSummary(SubscriptionOption? option) {
    if (option == null) return 'null';
    return '{id=${option.id}, storeProductId=${option.storeProductId}, '
        'productId=${option.productId}, isBasePlan=${option.isBasePlan}, '
        'billingPeriod=${_periodSummary(option.billingPeriod)}, '
        'tags=${option.tags}, fullPrice=${_phaseSummary(option.fullPricePhase)}, '
        'free=${_phaseSummary(option.freePhase)}, intro=${_phaseSummary(option.introPhase)}, '
        'phases=[${option.pricingPhases.map(_phaseSummary).join(", ")}]}';
  }

  String _phaseSummary(PricingPhase? phase) {
    if (phase == null) return 'null';
    return '{price=${phase.price.formatted}, micros=${phase.price.amountMicros}, '
        'currency=${phase.price.currencyCode}, period=${_periodSummary(phase.billingPeriod)}, '
        'recurrence=${phase.recurrenceMode}, cycles=${phase.billingCycleCount}, '
        'paymentMode=${phase.offerPaymentMode}}';
  }

  String _periodSummary(Period? period) {
    if (period == null) return 'null';
    return '${period.iso8601}/${period.value}${period.unit}';
  }

  String _mappedIntroSummary(SubscriptionIntroOffer? offer) {
    if (offer == null) return 'null';
    return '{price=${offer.priceString}, period=${offer.period}, '
        'units=${offer.periodNumberOfUnits}, cycles=${offer.cycles}, '
        'isFreeTrial=${offer.isFreeTrial}, renewal=${offer.renewalPriceString}}';
  }

  SubscriptionIntroOffer? _introOfferFrom(
    StoreProduct product,
    IntroEligibilityStatus? introEligibility,
  ) {
    final defaultOption = product.defaultOption;
    final introPhase = defaultOption?.introPhase ?? defaultOption?.freePhase;
    final fullPricePhase = defaultOption?.fullPricePhase;
    if (introPhase != null && fullPricePhase != null) {
      return SubscriptionIntroOffer(
        priceString: introPhase.price.formatted,
        period: _offerPeriodFromPricingPhase(introPhase),
        periodNumberOfUnits: introPhase.billingPeriod?.value ?? 1,
        cycles: introPhase.billingCycleCount ?? 1,
        isFreeTrial: introPhase.price.amountMicros == 0,
        renewalPriceString: fullPricePhase.price.formatted,
      );
    }

    final intro = product.introductoryPrice;
    if (intro == null) return null;
    // iOS/macOS 无法确认资格时不展示促销，避免误导；Android 不走本分支。
    if (introEligibility !=
        IntroEligibilityStatus.introEligibilityStatusEligible) {
      return null;
    }
    return SubscriptionIntroOffer(
      priceString: intro.priceString,
      period: _offerPeriodFromIntro(intro),
      periodNumberOfUnits: intro.periodNumberOfUnits,
      cycles: intro.cycles,
      isFreeTrial: intro.price == 0,
      renewalPriceString: product.priceString,
    );
  }

  SubscriptionPeriod _periodFrom(PackageType type) {
    return switch (type) {
      PackageType.annual => SubscriptionPeriod.yearly,
      PackageType.lifetime => SubscriptionPeriod.lifetime,
      _ => SubscriptionPeriod.monthly,
    };
  }

  int _trialDays(SubscriptionIntroOffer intro) {
    final units = intro.periodNumberOfUnits * intro.cycles;
    return switch (intro.period) {
      SubscriptionOfferPeriod.day => units,
      SubscriptionOfferPeriod.week => units * 7,
      SubscriptionOfferPeriod.month => units * 30,
      SubscriptionOfferPeriod.year => units * 365,
      SubscriptionOfferPeriod.unknown => units,
    };
  }

  SubscriptionOfferPeriod _offerPeriodFromIntro(IntroductoryPrice intro) {
    return switch (intro.periodUnit) {
      PeriodUnit.day => SubscriptionOfferPeriod.day,
      PeriodUnit.week => SubscriptionOfferPeriod.week,
      PeriodUnit.month => SubscriptionOfferPeriod.month,
      PeriodUnit.year => SubscriptionOfferPeriod.year,
      PeriodUnit.unknown => SubscriptionOfferPeriod.unknown,
    };
  }

  SubscriptionOfferPeriod _offerPeriodFromPricingPhase(PricingPhase phase) {
    return switch (phase.billingPeriod?.unit) {
      PeriodUnit.day => SubscriptionOfferPeriod.day,
      PeriodUnit.week => SubscriptionOfferPeriod.week,
      PeriodUnit.month => SubscriptionOfferPeriod.month,
      PeriodUnit.year => SubscriptionOfferPeriod.year,
      PeriodUnit.unknown || null => SubscriptionOfferPeriod.unknown,
    };
  }

  @override
  Future<String?> storefrontCountryCode() async {
    final storefront = await Purchases.storefront;
    return storefront?.countryCode;
  }

  /// 记录当前 Apple/Google 商店账号所在 storefront。
  ///
  /// 该值决定平台本地化价格。诊断时用它对齐 Offering 商品价、direct product
  /// 查询价与系统付款弹窗价格，判断是否存在 SDK/商店商品详情缓存不一致。
  Future<void> _logStorefront(String stage) async {
    try {
      final countryCode = await storefrontCountryCode();
      AppLogger.log(
        'Subscription',
        'storefront[$stage]=${countryCode ?? "null"}',
      );
    } catch (e) {
      AppLogger.log('Subscription', 'storefront[$stage] 获取失败: $e');
    }
  }

  /// 直接向 RevenueCat/商店查询商品详情并记录价格。
  ///
  /// Offering 的 package 内也带 [StoreProduct]，但本问题需要确认它是否与
  /// 当前 storefront 下的 direct product 查询结果一致。这里只做诊断日志，
  /// 不参与业务决策，避免改变现有购买路径。
  Future<void> _logDirectProductsForDiagnostics(
    List<String> productIds, {
    required String stage,
  }) async {
    if (productIds.isEmpty) return;
    try {
      final products = await Purchases.getProducts(productIds);
      final foundIds = <String>{};
      for (final product in products) {
        foundIds.add(product.identifier);
        AppLogger.log(
          'Subscription',
          'direct product[$stage] product=${product.identifier} '
              'price=${product.priceString} currency=${product.currencyCode} '
              'rawPrice=${product.price}',
        );
      }
      final missingIds = productIds.where((id) => !foundIds.contains(id));
      if (missingIds.isNotEmpty) {
        AppLogger.log(
          'Subscription',
          'direct product[$stage] 未返回商品: ${missingIds.toList()}',
        );
      }
    } catch (e) {
      AppLogger.log('Subscription', 'direct product[$stage] 查询失败: $e');
    }
  }

  Entitlement _entitlementFrom(CustomerInfo info) {
    final active = info.entitlements.active;
    // 诊断：打印 RevenueCat 实际返回的 active 权益键 + 全部权益键 + 我们要找的标识。
    // 若 activeKeys 为空但 allKeys 也空 → 商品没挂到任何 entitlement；
    // 若 key 与 lookFor 大小写/拼写不一致 → entitlement 标识没对上。
    AppLogger.log(
      'Subscription',
      'CustomerInfo activeEntitlements=${active.keys.toList()} '
          'allEntitlements=${info.entitlements.all.keys.toList()} '
          'lookFor=$_entitlementId '
          'activeSubs=${info.activeSubscriptions.toList()}',
    );
    final premium = active[_entitlementId];
    if (premium == null || !premium.isActive) {
      return Entitlement.free;
    }
    final expiry = premium.expirationDate;
    final productId = premium.productIdentifier;
    return Entitlement(
      isPremium: true,
      activeEntitlements: active.keys.toSet(),
      productId: productId,
      // 优先用平台 packageType 缓存（权威），未命中退回 ID 字符串启发式。
      period:
          _periodByProductId[productId] ??
          subscriptionPeriodFromProductId(productId),
      expiresAt: expiry != null ? DateTime.tryParse(expiry) : null,
      willRenew: premium.willRenew,
    );
  }
}

/// 购买服务 Provider。
///
/// 路由优先级：
/// 1. [useLocalStoreKit]（本地 StoreKit 测试模式）→ 本地实现，绕开 RevenueCat；
/// 2. 网页支付渠道（[isWebCheckoutConfigured]，侧载 APK / 桌面）→ [WebPurchaseService]，
///    权益经后端读回；
/// 3. 已配置 RevenueCat（注入了平台 API Key）→ 真实 RC 实现；
/// 4. 否则回退 Stub（匿名可运行）。
/// 测试通过 override 注入 Fake。
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final serviceType = purchaseServiceTypeFor(
    channel: clientPaymentChannel,
    useLocalStoreKit: useLocalStoreKit,
    nativeStoreConfigured: isRevenueCatConfigured,
    webConfigured: isWebCheckoutConfigured,
  );
  if (serviceType == PurchaseServiceType.localStoreKit) {
    final service = LocalStoreKitPurchaseService();
    ref.onDispose(service.dispose);
    return service;
  }
  if (serviceType == PurchaseServiceType.web) {
    return const WebPurchaseService();
  }
  if (serviceType == PurchaseServiceType.revenueCat) {
    return RevenueCatPurchaseService();
  }
  return const StubPurchaseService();
});

/// 购买服务实现类型，供 provider 与单测共享同一裁决规则。
enum PurchaseServiceType { localStoreKit, revenueCat, web, stub }

/// 按本地渠道选择购买服务；配置只对匹配的渠道生效。
PurchaseServiceType purchaseServiceTypeFor({
  required ClientPaymentChannel channel,
  required bool useLocalStoreKit,
  required bool nativeStoreConfigured,
  required bool webConfigured,
}) {
  if (useLocalStoreKit && channel == ClientPaymentChannel.appleStore) {
    return PurchaseServiceType.localStoreKit;
  }
  return switch (channel) {
    ClientPaymentChannel.appleStore || ClientPaymentChannel.googlePlay =>
      nativeStoreConfigured
          ? PurchaseServiceType.revenueCat
          : PurchaseServiceType.stub,
    ClientPaymentChannel.web =>
      webConfigured ? PurchaseServiceType.web : PurchaseServiceType.stub,
    ClientPaymentChannel.unavailable => PurchaseServiceType.stub,
  };
}

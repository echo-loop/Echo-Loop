import 'dart:async';

import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/providers/subscription_plans_provider.dart';
import 'package:echo_loop/features/subscription/services/purchase_service.dart';
import 'package:echo_loop/features/subscription/services/revenuecat_purchase_service.dart'
    show purchaseServiceProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _chinaPlans = [
  SubscriptionPlan(
    planId: 'monthly',
    title: 'Monthly',
    priceString: '¥30',
    period: SubscriptionPeriod.monthly,
  ),
];

const _usPlans = [
  SubscriptionPlan(
    planId: 'monthly',
    title: 'Monthly',
    priceString: r'$4.99',
    period: SubscriptionPeriod.monthly,
  ),
];

class _FakePurchaseService implements PurchaseService {
  String? storefront = 'CHN';
  int fastFetches = 0;
  int fullFetches = 0;
  Future<List<SubscriptionPlan>> Function(bool includeIntroEligibility)?
  onFetch;

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async {
    if (includeIntroEligibility) {
      fullFetches++;
    } else {
      fastFetches++;
    }
    return onFetch?.call(includeIntroEligibility) ?? _chinaPlans;
  }

  @override
  Future<String?> storefrontCountryCode() async => storefront;

  @override
  Future<Entitlement> currentEntitlement() async => Entitlement.free;

  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();

  @override
  Future<void> identify(String? userId) async {}

  @override
  Future<bool> ensureIdentified(String userId) async => true;

  @override
  Future<void> invalidateCustomerInfoCache() async {}

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async => const {};

  @override
  Future<Entitlement> purchase(String planId) async => Entitlement.free;

  @override
  Future<Entitlement> restore() async => Entitlement.free;
}

void main() {
  late _FakePurchaseService purchases;
  late DateTime now;
  late ProviderContainer container;

  setUp(() {
    purchases = _FakePurchaseService();
    now = DateTime.utc(2026, 7, 13, 8);
    container = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(purchases),
        subscriptionPlansNowProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('首次读取先返回基础价格，再静默补充促销信息', () async {
    purchases.onFetch = (includeIntroEligibility) async =>
        includeIntroEligibility ? _usPlans : _chinaPlans;

    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
    expect(purchases.fastFetches, 1);
    expect(purchases.fullFetches, 1);
  });

  test('同 storefront 静默刷新时保留已有价格', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    final pending = Completer<List<SubscriptionPlan>>();
    purchases.onFetch = (_) => pending.future;
    final refresh = container
        .read(subscriptionPlansProvider.notifier)
        .refresh(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(subscriptionPlansProvider).valueOrNull, _chinaPlans);
    pending.complete(_usPlans);
    await refresh;
    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
  });

  test('同 storefront 刷新失败时保留本会话最后成功价格', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;
    purchases.onFetch = (_) async => throw StateError('offline');

    await container
        .read(subscriptionPlansProvider.notifier)
        .refresh(force: true);

    expect(container.read(subscriptionPlansProvider).valueOrNull, _chinaPlans);
  });

  test('storefront 变化后立即撤下旧价格并提交新价格', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    purchases.storefront = 'USA';
    final pending = Completer<List<SubscriptionPlan>>();
    purchases.onFetch = (_) => pending.future;
    final refresh = container
        .read(subscriptionPlansProvider.notifier)
        .refreshIfStale();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(subscriptionPlansProvider).isLoading, isTrue);
    pending.complete(_usPlans);
    await refresh;
    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
  });

  test('同 storefront 在五分钟内不重复刷新，过期后刷新', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;
    expect(purchases.fastFetches, 1);

    now = now.add(const Duration(minutes: 4));
    await container.read(subscriptionPlansProvider.notifier).refreshIfStale();
    expect(purchases.fastFetches, 1);

    now = now.add(const Duration(minutes: 2));
    await container.read(subscriptionPlansProvider.notifier).refreshIfStale();
    expect(purchases.fastFetches, 2);
  });

  test('过期请求结果不能覆盖较新的 storefront 请求', () async {
    final first = Completer<List<SubscriptionPlan>>();
    purchases.onFetch = (_) => first.future;
    container.read(subscriptionPlansProvider);
    await Future<void>.delayed(Duration.zero);

    purchases.storefront = 'USA';
    purchases.onFetch = (_) async => _usPlans;
    await container
        .read(subscriptionPlansProvider.notifier)
        .refresh(force: true);
    first.complete(_chinaPlans);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
  });

  test('套餐查询期间 storefront 变化时丢弃旧区域结果并重试', () async {
    var firstFastFetch = true;
    purchases.onFetch = (includeIntroEligibility) async {
      if (!includeIntroEligibility && firstFastFetch) {
        firstFastFetch = false;
        purchases.storefront = 'USA';
        return _chinaPlans;
      }
      return _usPlans;
    };

    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
    expect(purchases.fastFetches, 2);
  });
}

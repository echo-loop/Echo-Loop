import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/providers/subscription_plans_provider.dart';
import 'package:echo_loop/features/subscription/services/paddle_billing_repository.dart';
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
  final List<bool> forceCalls = [];
  Future<List<SubscriptionPlan>> Function(bool includeIntroEligibility)?
  onFetch;

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
    bool force = false,
  }) async {
    forceCalls.add(force);
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
  Future<Entitlement> purchase(String planId) async => Entitlement.free;

  @override
  Future<RestorePurchaseResult> restore() async =>
      const RestorePurchaseResult(entitlement: Entitlement.free);
}

class _FakePaddleBillingRepository extends PaddleBillingRepository {
  _FakePaddleBillingRepository() : super.withDio(Dio());

  List<SubscriptionPlan>? cachedPlans;
  Future<List<SubscriptionPlan>> Function(bool force)? onFetch;
  final List<bool> forceCalls = [];

  @override
  Future<List<SubscriptionPlan>?> loadCachedPlans() async => cachedPlans;

  @override
  Future<List<SubscriptionPlan>> fetchPlans({bool force = false}) {
    forceCalls.add(force);
    return onFetch?.call(force) ?? Future.value(cachedPlans ?? _chinaPlans);
  }
}

void main() {
  late _FakePurchaseService purchases;
  late DateTime now;
  late ProviderContainer container;
  late _FakePaddleBillingRepository paddleRepository;

  setUp(() {
    purchases = _FakePurchaseService();
    paddleRepository = _FakePaddleBillingRepository();
    now = DateTime.utc(2026, 7, 13, 8);
    container = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(purchases),
        subscriptionPlansNowProvider.overrideWithValue(() => now),
        subscriptionPlansTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
        paddleBillingRepositoryProvider.overrideWithValue(paddleRepository),
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

  test('强制刷新将 force 传递给基础套餐请求，但不重复强制补充请求', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;
    purchases.forceCalls.clear();

    await container
        .read(subscriptionPlansProvider.notifier)
        .refresh(force: true);

    expect(purchases.forceCalls, [true, false]);
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

  test('同 storefront 在一天内不重复刷新，过期后刷新', () async {
    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;
    expect(purchases.fastFetches, 1);

    now = now.add(const Duration(hours: 23));
    await container.read(subscriptionPlansProvider.notifier).refreshIfStale();
    expect(purchases.fastFetches, 1);

    now = now.add(const Duration(hours: 2));
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

  test('无缓存套餐请求超时后进入错误态', () async {
    final pending = Completer<List<SubscriptionPlan>>();
    purchases.onFetch = (_) => pending.future;

    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    expect(container.read(subscriptionPlansProvider).hasError, isTrue);
  });

  test('套餐请求超时后重试可以恢复，旧请求不能覆盖新结果', () async {
    final pending = Completer<List<SubscriptionPlan>>();
    var firstRequest = true;
    purchases.onFetch = (_) {
      if (firstRequest) {
        firstRequest = false;
        return pending.future;
      }
      return Future<List<SubscriptionPlan>>.value(_usPlans);
    };

    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;
    expect(container.read(subscriptionPlansProvider).hasError, isTrue);

    await container
        .read(subscriptionPlansProvider.notifier)
        .refresh(force: true);
    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);

    pending.complete(_chinaPlans);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(subscriptionPlansProvider).valueOrNull, _usPlans);
  });

  test('基础套餐成功后促销查询超时仍保留基础套餐', () async {
    var fullRequest = false;
    purchases.onFetch = (includeIntroEligibility) {
      if (includeIntroEligibility) {
        fullRequest = true;
        return Completer<List<SubscriptionPlan>>().future;
      }
      return Future<List<SubscriptionPlan>>.value(_chinaPlans);
    };

    container.read(subscriptionPlansProvider);
    await container.read(subscriptionPlansProvider.notifier).settled;

    expect(fullRequest, isTrue);
    expect(container.read(subscriptionPlansProvider).valueOrNull, _chinaPlans);
  });

  test('Paddle 缓存先展示，网络完成后更新价格', () async {
    const cachedPlans = [
      SubscriptionPlan(
        planId: 'plus_monthly',
        title: 'Monthly',
        priceString: r'$4.99',
        period: SubscriptionPeriod.monthly,
      ),
    ];
    const updatedPlans = [
      SubscriptionPlan(
        planId: 'plus_monthly',
        title: 'Monthly',
        priceString: r'$5.99',
        period: SubscriptionPeriod.monthly,
      ),
    ];
    final pending = Completer<List<SubscriptionPlan>>();
    paddleRepository.cachedPlans = cachedPlans;
    paddleRepository.onFetch = (_) => pending.future;

    final refresh = container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(paddleSubscriptionPlansProvider).valueOrNull,
      cachedPlans,
    );
    expect(container.read(paddleSubscriptionPlansProvider).isLoading, isFalse);

    pending.complete(updatedPlans);
    await refresh;
    expect(
      container.read(paddleSubscriptionPlansProvider).valueOrNull,
      updatedPlans,
    );
  });

  test('Paddle 后台刷新失败时保留缓存价格', () async {
    paddleRepository.cachedPlans = _usPlans;
    paddleRepository.onFetch = (_) async => throw StateError('offline');

    await container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);

    expect(
      container.read(paddleSubscriptionPlansProvider).valueOrNull,
      _usPlans,
    );
    expect(container.read(paddleSubscriptionPlansProvider).hasError, isFalse);
  });

  test('Paddle 无缓存且首次请求失败进入错误态', () async {
    paddleRepository.onFetch = (_) async => throw StateError('offline');

    await container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);

    expect(container.read(paddleSubscriptionPlansProvider).hasError, isTrue);
  });

  test('Paddle 旧 generation 不能覆盖较新的结果', () async {
    final first = Completer<List<SubscriptionPlan>>();
    var requestCount = 0;
    paddleRepository.onFetch = (_) {
      requestCount++;
      return requestCount == 1
          ? first.future
          : Future<List<SubscriptionPlan>>.value(_usPlans);
    };

    final firstRefresh = container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);
    await Future<void>.delayed(Duration.zero);
    await container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);

    first.complete(_chinaPlans);
    await firstRefresh;

    expect(
      container.read(paddleSubscriptionPlansProvider).valueOrNull,
      _usPlans,
    );
  });

  test('Paddle refresh 会传递 force 参数', () async {
    await container
        .read(paddleSubscriptionPlansProvider.notifier)
        .refresh(force: true);

    expect(paddleRepository.forceCalls, [true]);
  });
}

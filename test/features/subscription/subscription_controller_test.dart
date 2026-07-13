import 'dart:async';

import 'package:clock/clock.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/providers/subscription_identity.dart';
import 'package:echo_loop/features/subscription/services/entitlement_cache.dart';
import 'package:echo_loop/features/subscription/services/entitlement_repository.dart';
import 'package:echo_loop/features/subscription/services/purchase_service.dart';
import 'package:echo_loop/features/subscription/services/revenuecat_purchase_service.dart'
    show PurchaseServiceType, purchaseServiceProvider, purchaseServiceTypeFor;
import 'package:echo_loop/config/client_distribution.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可注入处理函数的后端仓库替身。
class FakeEntitlementRepository implements EntitlementRepository {
  FakeEntitlementRepository(this.handler);
  Future<Entitlement?> Function(String userId) handler;
  final List<String> calls = [];

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) {
    calls.add(userId);
    return handler(userId);
  }
}

/// 内存购买服务替身。
class FakePurchaseService implements PurchaseService {
  Entitlement purchaseResult = const Entitlement(
    isPremium: true,
    productId: 'pro_yearly',
  );
  Entitlement restoreResult = Entitlement.free;

  /// currentEntitlement 返回值（模拟 RevenueCat CustomerInfo）。
  Entitlement currentResult = Entitlement.free;

  /// 非 null 时 currentEntitlement 抛此异常（模拟 RC 离线 / 不可达）。
  Object? currentError;
  Object? purchaseError;
  final List<String?> identifyCalls = [];

  /// ensureIdentified 返回值（默认已绑定，购买门禁通过）。
  bool ensureIdentifiedResult = true;

  /// ensureIdentified 调用记录。
  final List<String> ensureIdentifiedCalls = [];

  /// purchase 实际被调次数（验证门禁不通过时不成交）。
  int purchaseCalls = 0;

  /// invalidateCustomerInfoCache 调用次数（验证清缓存动作）。
  int invalidateCalls = 0;

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool includeIntroEligibility = true,
  }) async => const [];

  @override
  Future<Entitlement> currentEntitlement() async {
    final error = currentError;
    if (error != null) throw error;
    return currentResult;
  }

  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();

  @override
  Future<Entitlement> purchase(String planId) async {
    purchaseCalls++;
    final error = purchaseError;
    if (error != null) throw error;
    return purchaseResult;
  }

  @override
  Future<Entitlement> restore() async => restoreResult;

  @override
  Future<void> identify(String? userId) async => identifyCalls.add(userId);

  @override
  Future<bool> ensureIdentified(String userId) async {
    ensureIdentifiedCalls.add(userId);
    return ensureIdentifiedResult;
  }

  @override
  Future<void> invalidateCustomerInfoCache() async => invalidateCalls++;

  @override
  Future<Map<String, Object?>> debugCustomerInfoSnapshot() async => const {};

  @override
  Future<String?> storefrontCountryCode() async => null;
}

/// 内存缓存替身（覆盖 secure_storage 实现）。
class FakeEntitlementCache extends EntitlementCache {
  CachedEntitlement? stored;
  int clears = 0;

  @override
  Future<CachedEntitlement?> read() async => stored;

  @override
  Future<void> write(CachedEntitlement cached) async {
    stored = cached;
  }

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
  }
}

void main() {
  group('purchaseServiceTypeFor', () {
    test('app_store / play 选择 RevenueCat', () {
      for (final channel in [
        ClientPaymentChannel.appleStore,
        ClientPaymentChannel.googlePlay,
      ]) {
        expect(
          purchaseServiceTypeFor(
            channel: channel,
            useLocalStoreKit: false,
            nativeStoreConfigured: true,
            webConfigured: true,
          ),
          PurchaseServiceType.revenueCat,
        );
      }
    });

    test('direct 只选择 Web service', () {
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.web,
          useLocalStoreKit: false,
          nativeStoreConfigured: true,
          webConfigured: true,
        ),
        PurchaseServiceType.web,
      );
    });

    test('缺配置或未知渠道回退 stub', () {
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.googlePlay,
          useLocalStoreKit: false,
          nativeStoreConfigured: false,
          webConfigured: true,
        ),
        PurchaseServiceType.stub,
      );
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.unavailable,
          useLocalStoreKit: false,
          nativeStoreConfigured: true,
          webConfigured: true,
        ),
        PurchaseServiceType.stub,
      );
    });

    test('useLocalStoreKit 仅对 Apple 渠道生效', () {
      // Apple 渠道：即便未配 RC，本地 StoreKit 模式也可用。
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.appleStore,
          useLocalStoreKit: true,
          nativeStoreConfigured: false,
          webConfigured: false,
        ),
        PurchaseServiceType.localStoreKit,
      );
      // Google Play 渠道：useLocalStoreKit 不生效，无 RC key 时仍回退 stub
      // （与 subscriptionAvailability 门控对齐，避免「门控可用、购买落 stub」）。
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.googlePlay,
          useLocalStoreKit: true,
          nativeStoreConfigured: false,
          webConfigured: false,
        ),
        PurchaseServiceType.stub,
      );
    });
  });

  final now = DateTime.utc(2026, 6, 22, 12);
  const proEntitlement = Entitlement(isPremium: true, productId: 'pro_yearly');
  const signedIn = SubscriptionIdentity(userId: 'u1', accessToken: 't1');

  // 身份注入 seam：测试可改其 state 触发 controller 监听。
  final testIdentityProvider = StateProvider<SubscriptionIdentity>(
    (_) => SubscriptionIdentity.anonymous,
  );

  ProviderContainer makeContainer({
    required SubscriptionIdentity identity,
    required EntitlementRepository repo,
    required EntitlementCache cache,
    PurchaseService? purchases,
  }) {
    final container = ProviderContainer(
      overrides: [
        entitlementRepositoryProvider.overrideWithValue(repo),
        entitlementCacheProvider.overrideWithValue(cache),
        purchaseServiceProvider.overrideWithValue(
          purchases ?? FakePurchaseService(),
        ),
        subscriptionIdentityProvider.overrideWith(
          (ref) => ref.watch(testIdentityProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(testIdentityProvider.notifier).state = identity;
    return container;
  }

  CachedEntitlement cached(
    Entitlement ent, {
    String? userId = 'u1',
    Duration age = const Duration(hours: 1),
  }) {
    return CachedEntitlement(
      userId: userId,
      entitlement: ent,
      cachedAt: now.subtract(age),
    );
  }

  test('冷启动首帧为 unknown 中间态（对账前，C5）', () async {
    await withClock(Clock.fixed(now), () async {
      final container = makeContainer(
        identity: SubscriptionIdentity.anonymous,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
      );
      // 读取后立即检查（refresh 尚未完成）。
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.unknown,
      );
    });
  });

  test('匿名对账后 → free（RevenueCat 返回无购买）', () async {
    await withClock(Clock.fixed(now), () async {
      final container = makeContainer(
        identity: SubscriptionIdentity.anonymous,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: FakePurchaseService()..currentResult = Entitlement.free,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('登录冷启动 + 远端 active → pro，并落盘缓存', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => proEntitlement),
        cache: cache,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(state.status, EntitlementStatus.premium);
      expect(state.isStale, isFalse);
      expect(cache.stored?.userId, 'u1');
      expect(cache.stored?.entitlement.isPremium, isTrue);
    });
  });

  test('离线（后端 + RC 均不可达）+ 新鲜缓存 active → pro 且 isStale', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache()..stored = cached(proEntitlement);
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: cache,
        purchases: FakePurchaseService()..currentError = Exception('offline'),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(state.status, EntitlementStatus.premium);
      expect(state.isStale, isTrue);
    });
  });

  test('C4 退款：远端 free 覆盖仍 active 的缓存 → free', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache()..stored = cached(proEntitlement);
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: cache,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('缓存 userId 与当前用户不一致 → 作废，离线时退回 unknown', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache()
        ..stored = cached(proEntitlement, userId: 'other-user');
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: cache,
        purchases: FakePurchaseService()..currentError = Exception('offline'),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.unknown,
      );
    });
  });

  test('登出 → 清权益为 free + 清缓存 + 解绑购买身份', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final purchases = FakePurchaseService();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => proEntitlement),
        cache: cache,
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );

      container.read(testIdentityProvider.notifier).state =
          SubscriptionIdentity.anonymous;
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
      expect(purchases.identifyCalls, contains(null));
      expect(cache.clears, greaterThanOrEqualTo(1));
    });
  });

  test('切换用户 → 重对账并绑定新购买身份', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository(
          (userId) async => userId == 'u2' ? proEntitlement : Entitlement.free,
        ),
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );

      container.read(testIdentityProvider.notifier).state =
          const SubscriptionIdentity(userId: 'u2', accessToken: 't2');
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
      expect(purchases.identifyCalls, contains('u2'));
    });
  });

  test('purchase 成功 → 立即本地解锁', () async {
    await withClock(Clock.fixed(now), () async {
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        // 购买后 RevenueCat 的 CustomerInfo 也反映为 pro（后续对账保持解锁）。
        purchases: FakePurchaseService()
          ..purchaseResult = proEntitlement
          ..currentResult = proEntitlement,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await container
          .read(subscriptionControllerProvider.notifier)
          .purchase('pro_yearly');
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('fail-closed：身份未绑定 → purchase 报错且不成交', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()
        ..purchaseResult = proEntitlement
        ..ensureIdentifiedResult = false; // 绑定未就绪
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      await expectLater(
        controller.purchase('pro_yearly'),
        throwsA(isA<PurchaseException>()),
      );
      // 门禁被调用，但实际购买未发起。
      expect(purchases.ensureIdentifiedCalls, contains('u1'));
      expect(purchases.purchaseCalls, 0);
    });
  });

  test('fail-closed：身份未绑定 → restore 报错且不发起恢复', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()..ensureIdentifiedResult = false;
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      await expectLater(
        controller.restore(),
        throwsA(isA<PurchaseException>()),
      );
      expect(purchases.ensureIdentifiedCalls, contains('u1'));
    });
  });

  test('已登录冷启动 → build 即绑定 RC 身份（logIn）', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      // fireImmediately 令 build 即以当前已登录身份触发 identify(logIn)。
      expect(purchases.identifyCalls, contains('u1'));
    });
  });

  test('匿名冷启动 → 不误调 logOut', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()..currentResult = Entitlement.free;
      final container = makeContainer(
        identity: SubscriptionIdentity.anonymous,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      // 匿名→匿名无变化，_onIdentityChanged 提前 return，不应调 logOut(null)。
      expect(purchases.identifyCalls, isEmpty);
    });
  });

  test('clearLocalCacheAndRefresh：清缓存 + 失效 RC 缓存 + 回源重对账', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache()..stored = cached(proEntitlement);
      final purchases = FakePurchaseService()..currentResult = Entitlement.free;
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => null),
        cache: cache,
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await container
          .read(subscriptionControllerProvider.notifier)
          .clearLocalCacheAndRefresh();
      await pumpEventQueue();

      // RC 缓存被失效、本地缓存被清，回源得到 free。
      expect(purchases.invalidateCalls, greaterThanOrEqualTo(1));
      expect(cache.clears, greaterThanOrEqualTo(1));
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('debugOverrideEntitlement：强制 Pro/Free 覆盖在线对账，传 null 解除', () async {
    await withClock(Clock.fixed(now), () async {
      final container = makeContainer(
        identity: signedIn,
        // 在线源恒为 free，验证覆盖确实压过在线结果。
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: FakeEntitlementCache(),
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      controller.debugOverrideEntitlement(EntitlementStatus.premium);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );

      // 覆盖期间即便重对账也保持覆盖状态。
      await controller.refresh();
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );

      controller.debugOverrideEntitlement(EntitlementStatus.free);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );

      // 解除覆盖 → 回到在线 free。
      controller.debugOverrideEntitlement(null);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('generation 竞态：旧用户的迟到回调不污染新用户 state', () async {
    await withClock(Clock.fixed(now), () async {
      final pendingU1 = Completer<Entitlement?>();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository(
          (userId) =>
              userId == 'u1' ? pendingU1.future : Future.value(proEntitlement),
        ),
        cache: FakeEntitlementCache(),
      );
      // u1 对账挂起。
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.unknown,
      );

      // 切到 u2：立即对账为 pro。
      container.read(testIdentityProvider.notifier).state =
          const SubscriptionIdentity(userId: 'u2', accessToken: 't2');
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );

      // u1 的迟到结果到达（free），应被 generation 校验丢弃。
      pendingU1.complete(Entitlement.free);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });
}

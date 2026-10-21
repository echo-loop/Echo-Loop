import 'dart:async';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/entitlement_source.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/providers/subscription_controller.dart';
import 'package:echo_loop/features/subscription/providers/subscription_identity.dart';
import 'package:echo_loop/features/subscription/services/entitlement_cache.dart';
import 'package:echo_loop/features/subscription/services/entitlement_repository.dart';
import 'package:echo_loop/features/subscription/services/paddle_billing_repository.dart';
import 'package:echo_loop/features/subscription/services/purchase_service.dart';
import 'package:echo_loop/features/subscription/services/revenuecat_purchase_service.dart'
    show PurchaseServiceType, purchaseServiceProvider, purchaseServiceTypeFor;
import 'package:echo_loop/config/client_distribution.dart';
import 'package:echo_loop/features/subscription/state/entitlement_state.dart';
import 'package:echo_loop/services/entitlement_signal_interceptor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// 可注入处理函数的后端仓库替身。
///
/// [FakeEntitlementRepository.queue] 支持按调用顺序出队的结果序列
/// （成交收敛用例需要「第一次 free、force 后 premium」）；队列耗尽后
/// 重复返回最后一个结果。
class FakeEntitlementRepository implements EntitlementRepository {
  FakeEntitlementRepository(this.handler);

  FakeEntitlementRepository.queue(List<Entitlement?> results)
    : assert(results.isNotEmpty),
      _queue = List.of(results),
      handler = ((_) async => null);

  Future<Entitlement?> Function(String userId) handler;
  List<Entitlement?>? _queue;

  /// 每次调用的 userId。
  final List<String> calls = [];

  /// 每次调用的 force 标记（与 [calls] 一一对应）。
  final List<bool> forceCalls = [];

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
    bool force = false,
  }) {
    calls.add(userId);
    forceCalls.add(force);
    final queue = _queue;
    if (queue != null) {
      return Future.value(queue.length > 1 ? queue.removeAt(0) : queue.first);
    }
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

  /// 非 null 时 restore 抛此异常（如 receiptInUse）。
  Object? restoreError;

  /// 非 null 时 purchase 在返回前等待它（模拟成交 await 期间的竞态窗口）。
  Completer<void>? purchaseCompleter;
  Object? identifyError;
  Completer<void>? identifyCompleter;
  Object? ensureIdentifiedError;
  final Map<String, Completer<void>> ensureIdentifiedCompleters = {};
  int currentCalls = 0;
  final List<String?> identifyCalls = [];

  /// ensureIdentified 返回值（默认已绑定，购买门禁通过）。
  bool ensureIdentifiedResult = true;

  /// ensureIdentified 调用记录。
  final List<String> ensureIdentifiedCalls = [];

  /// purchase 实际被调次数（验证门禁不通过时不成交）。
  int purchaseCalls = 0;

  /// restore 实际被调次数（验证 Web 渠道不穿透到底层恢复）。
  int restoreCalls = 0;

  /// restore 后返回的 RevenueCat 原始 App User ID。
  String? restoreOriginalAppUserId;

  @override
  Future<List<SubscriptionPlan>> fetchPlans({
    bool force = false,
    bool includeIntroEligibility = true,
  }) async => const [];

  @override
  Future<Entitlement> currentEntitlement() async {
    currentCalls++;
    final error = currentError;
    if (error != null) throw error;
    return currentResult;
  }

  @override
  Stream<Entitlement> get entitlementStream => const Stream.empty();

  @override
  Future<Entitlement> purchase(String planId) async {
    purchaseCalls++;
    final completer = purchaseCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = purchaseError;
    if (error != null) throw error;
    return purchaseResult;
  }

  @override
  Future<RestorePurchaseResult> restore() async {
    restoreCalls++;
    final error = restoreError;
    if (error != null) throw error;
    return RestorePurchaseResult(
      entitlement: restoreResult,
      originalAppUserId: restoreOriginalAppUserId,
    );
  }

  @override
  Future<void> identify(String? userId) async {
    identifyCalls.add(userId);
    final completer = identifyCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = identifyError;
    if (error != null) throw error;
  }

  @override
  Future<bool> ensureIdentified(String userId) async {
    ensureIdentifiedCalls.add(userId);
    final completer = ensureIdentifiedCompleters[userId];
    if (completer != null) {
      await completer.future;
    }
    final error = ensureIdentifiedError;
    if (error != null) throw error;
    return ensureIdentifiedResult;
  }

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
    test('app_store / play 仅在 SDK 已就绪时选择 RevenueCat', () {
      for (final channel in [
        ClientPaymentChannel.appleStore,
        ClientPaymentChannel.googlePlay,
      ]) {
        expect(
          purchaseServiceTypeFor(
            channel: channel,
            useLocalStoreKit: false,
            nativeStoreReady: true,
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
          nativeStoreReady: true,
          webConfigured: true,
        ),
        PurchaseServiceType.web,
      );
    });

    test('SDK 未就绪或未知渠道回退 stub', () {
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.googlePlay,
          useLocalStoreKit: false,
          nativeStoreReady: false,
          webConfigured: true,
        ),
        PurchaseServiceType.stub,
      );
      expect(
        purchaseServiceTypeFor(
          channel: ClientPaymentChannel.unavailable,
          useLocalStoreKit: false,
          nativeStoreReady: true,
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
          nativeStoreReady: false,
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
          nativeStoreReady: false,
          webConfigured: false,
        ),
        PurchaseServiceType.stub,
      );
    });
  });

  group('canStartPaddleCheckoutForChannel', () {
    test('direct 默认允许，商店包必须显式允许 fallback', () {
      expect(
        canStartPaddleCheckoutForChannel(
          channel: ClientPaymentChannel.web,
          allowStoreFallback: false,
        ),
        isTrue,
      );
      for (final channel in [
        ClientPaymentChannel.appleStore,
        ClientPaymentChannel.googlePlay,
      ]) {
        expect(
          canStartPaddleCheckoutForChannel(
            channel: channel,
            allowStoreFallback: false,
          ),
          isFalse,
        );
        expect(
          canStartPaddleCheckoutForChannel(
            channel: channel,
            allowStoreFallback: true,
          ),
          isTrue,
        );
      }
      expect(
        canStartPaddleCheckoutForChannel(
          channel: ClientPaymentChannel.unavailable,
          allowStoreFallback: true,
        ),
        isFalse,
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
    ClientPaymentChannel paymentChannel = ClientPaymentChannel.web,
    PaddleBillingRepository? paddleRepository,
  }) {
    final container = ProviderContainer(
      overrides: [
        entitlementRepositoryProvider.overrideWithValue(repo),
        entitlementCacheProvider.overrideWithValue(cache),
        purchaseServiceProvider.overrideWithValue(
          purchases ?? FakePurchaseService(),
        ),
        if (paddleRepository != null)
          paddleBillingRepositoryProvider.overrideWithValue(paddleRepository),
        subscriptionIdentityProvider.overrideWith(
          (ref) => ref.watch(testIdentityProvider),
        ),
        subscriptionPaymentChannelProvider.overrideWithValue(paymentChannel),
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

  test('匿名对账后 → 明确 free，不调 repo 也不调 currentEntitlement', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository((_) async => null);
      final purchases = FakePurchaseService()..currentResult = Entitlement.free;
      final container = makeContainer(
        identity: SubscriptionIdentity.anonymous,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
      expect(repo.calls, isEmpty);
      expect(purchases.currentCalls, 0);
    });
  });

  test('direct 匿名对账 → free，不穿透到 Paddle currentEntitlement', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()
        ..currentError = StateError('Paddle has no anonymous entitlement');
      final container = makeContainer(
        identity: SubscriptionIdentity.anonymous,
        repo: FakeEntitlementRepository((_) async => null),
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.web,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(state.status, EntitlementStatus.free);
      expect(state.isStale, isFalse);
      expect(state.error, isNull);
      expect(purchases.currentCalls, 0);
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

  test('认证未解析期间保持 unknown，随后登录不执行匿名 free 对账', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository((_) async => proEntitlement);
      final cache = FakeEntitlementCache();
      final container = ProviderContainer(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(repo),
          entitlementCacheProvider.overrideWithValue(cache),
          purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
          subscriptionIdentityProvider.overrideWith(
            (ref) => ref.watch(testIdentityProvider),
          ),
          subscriptionPaymentChannelProvider.overrideWithValue(
            ClientPaymentChannel.web,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(testIdentityProvider.notifier).state =
          SubscriptionIdentity.pending;
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.unknown,
      );
      expect(repo.calls, isEmpty);

      container.read(testIdentityProvider.notifier).state = signedIn;
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
      expect(repo.calls, ['u1']);
    });
  });

  test('premium expiresAt 到期时自动 refresh 并降级为 free', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 6, 22, 12);
      withClock(async.getClock(start), () {
        var fetches = 0;
        final expiry = start.add(const Duration(minutes: 10));
        final repo = FakeEntitlementRepository((_) async {
          fetches++;
          return fetches == 1
              ? Entitlement(
                  isPremium: true,
                  productId: 'pro_monthly',
                  expiresAt: expiry,
                )
              : Entitlement.free;
        });
        final container = makeContainer(
          identity: signedIn,
          repo: repo,
          cache: FakeEntitlementCache(),
        );
        container.read(subscriptionControllerProvider);
        async.flushMicrotasks();

        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );
        expect(fetches, 1);

        async.elapse(const Duration(minutes: 9, seconds: 59));
        async.flushMicrotasks();
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );
        expect(fetches, 1);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(fetches, 2);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.free,
        );
      });
    });
  });

  test('新 premium 权益会取消旧到期 timer 并按新 expiresAt 重排', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 6, 22, 12);
      withClock(async.getClock(start), () {
        var fetches = 0;
        final firstExpiry = start.add(const Duration(minutes: 10));
        final secondExpiry = start.add(const Duration(minutes: 30));
        final repo = FakeEntitlementRepository((_) async {
          fetches++;
          return switch (fetches) {
            1 => Entitlement(
              isPremium: true,
              productId: 'pro_monthly',
              expiresAt: firstExpiry,
            ),
            2 => Entitlement(
              isPremium: true,
              productId: 'pro_yearly',
              expiresAt: secondExpiry,
            ),
            _ => Entitlement.free,
          };
        });
        final container = makeContainer(
          identity: signedIn,
          repo: repo,
          cache: FakeEntitlementCache(),
        );
        final controller = container.read(
          subscriptionControllerProvider.notifier,
        );
        container.read(subscriptionControllerProvider);
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 5));
        unawaited(controller.refresh());
        async.flushMicrotasks();
        expect(fetches, 2);
        expect(
          container.read(subscriptionControllerProvider).entitlement?.productId,
          'pro_yearly',
        );

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(fetches, 2);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );

        async.elapse(const Duration(minutes: 20));
        async.flushMicrotasks();
        expect(fetches, 3);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.free,
        );
      });
    });
  });

  test('expiresAt 为空的永久 premium 不安排到期 refresh', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 6, 22, 12);
      withClock(async.getClock(start), () {
        var fetches = 0;
        final repo = FakeEntitlementRepository((_) async {
          fetches++;
          return const Entitlement(isPremium: true, productId: 'lifetime');
        });
        final container = makeContainer(
          identity: signedIn,
          repo: repo,
          cache: FakeEntitlementCache(),
        );
        container.read(subscriptionControllerProvider);
        async.flushMicrotasks();

        async.elapse(const Duration(days: 30));
        async.flushMicrotasks();
        expect(fetches, 1);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );
      });
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

  test('登出时 RC 解绑未完成 → 本地立即清权益与缓存', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final identify = Completer<void>();
      final purchases = FakePurchaseService()..identifyCompleter = identify;
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
      expect(cache.clears, greaterThanOrEqualTo(1));
      expect(purchases.identifyCalls, contains(null));

      identify.complete();
      await pumpEventQueue();
    });
  });

  test('登出时 RC 解绑失败 → 本地仍保持 free 且缓存已清', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final purchases = FakePurchaseService()
        ..identifyError = Exception('logout failed');
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
      expect(cache.clears, greaterThanOrEqualTo(1));
      expect(purchases.identifyCalls, contains(null));
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
      expect(purchases.ensureIdentifiedCalls, contains('u2'));
    });
  });

  test('purchase 成功 → forced 回源收敛 premium（不做本地裁决）', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      // 冷启动读到 free，成交后 force 调用读到后端 premium。
      final backendPremium = Entitlement(
        isPremium: true,
        productId: 'backend_pro_yearly',
        expiresAt: now.add(const Duration(days: 365)),
        source: EntitlementSource.apple,
      );
      final repo = FakeEntitlementRepository.queue([
        Entitlement.free,
        backendPremium,
      ]);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: cache,
        // 平台成交快照与后端结果不同，用于证明生效的是后端结果。
        purchases: FakePurchaseService()
          ..purchaseResult = const Entitlement(
            isPremium: true,
            productId: 'store_snapshot',
          ),
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );

      await container
          .read(subscriptionControllerProvider.notifier)
          .purchase('pro_yearly');
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(state.status, EntitlementStatus.premium);
      expect(state.entitlement?.productId, 'backend_pro_yearly');
      expect(repo.forceCalls, contains(true));
      expect(cache.stored?.entitlement.productId, 'backend_pro_yearly');
    });
  });

  test('外部 checkout 回跳 → 复用 forced 回源收敛 premium', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository.queue([
        Entitlement.free,
        proEntitlement,
      ]);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );

      await container
          .read(subscriptionControllerProvider.notifier)
          .refreshAfterExternalCheckout();

      expect(container.read(subscriptionControllerProvider).isActive, isTrue);
      expect(repo.forceCalls, [false, true]);
    });
  });

  test('native 登录冷启动 → 读取后端权威源，不读 RC CustomerInfo', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository((_) async => proEntitlement);
      final purchases = FakePurchaseService()..currentResult = Entitlement.free;
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      expect(repo.calls, contains('u1'));
      expect(purchases.currentCalls, 0);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('native 登录冷启动 → identify 完成前不读取权益', () async {
    await withClock(Clock.fixed(now), () async {
      final identify = Completer<void>();
      final purchases = FakePurchaseService()
        ..ensureIdentifiedCompleters['u1'] = identify;
      final repo = FakeEntitlementRepository((_) async => proEntitlement);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );

      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      // identify 尚未完成时，不能抢先读取旧匿名 / 旧账号的权益。
      expect(purchases.ensureIdentifiedCalls, contains('u1'));
      expect(repo.calls, isEmpty);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.unknown,
      );

      identify.complete();
      await pumpEventQueue();

      expect(repo.calls, hasLength(1));
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('native identify 失败 → 不读取 CustomerInfo 且不覆盖当前用户缓存', () async {
    await withClock(Clock.fixed(now), () async {
      final cachedEntitlement = cached(proEntitlement);
      final cache = FakeEntitlementCache()..stored = cachedEntitlement;
      final purchases = FakePurchaseService()
        ..ensureIdentifiedError = Exception('identify failed')
        // 若被错误读取，会返回 free 并污染缓存；断言应证明它未被调用。
        ..currentResult = Entitlement.free;
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: cache,
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );

      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(purchases.currentCalls, 0);
      expect(cache.stored, same(cachedEntitlement));
      expect(state.status, EntitlementStatus.premium);
      expect(state.isStale, isTrue);
      expect(state.error, contains('identify failed'));
    });
  });

  test('native 快速切换身份 → refresh 必须等待最新用户 identify 完成', () async {
    await withClock(Clock.fixed(now), () async {
      final identifyU1 = Completer<void>();
      final identifyU2 = Completer<void>();
      final purchases = FakePurchaseService()
        ..ensureIdentifiedCompleters['u1'] = identifyU1
        ..ensureIdentifiedCompleters['u2'] = identifyU2;
      final repo = FakeEntitlementRepository((_) async => proEntitlement);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );

      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final refreshFuture = controller.refresh();
      await pumpEventQueue();

      container.read(testIdentityProvider.notifier).state =
          const SubscriptionIdentity(userId: 'u2', accessToken: 't2');
      await pumpEventQueue();
      expect(purchases.ensureIdentifiedCalls, containsAll(['u1', 'u2']));

      identifyU1.complete();
      await pumpEventQueue();

      // refresh 原本等的是 u1；u1 完成后必须发现 u2 是更新的身份任务并继续等待。
      expect(repo.calls, isEmpty);

      identifyU2.complete();
      await refreshFuture;
      await pumpEventQueue();

      expect(repo.calls, isNotEmpty);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('restore：后端 free → RC 认领 active → forced 收敛 premium', () async {
    await withClock(Clock.fixed(now), () async {
      // 冷启动 + restore 前置 forced refresh 均为 free；认领后收敛读到 premium。
      final repo = FakeEntitlementRepository.queue([
        Entitlement.free,
        Entitlement.free,
        proEntitlement,
      ]);
      final purchases = FakePurchaseService()..restoreResult = proEntitlement;
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await container.read(subscriptionControllerProvider.notifier).restore();
      await pumpEventQueue();

      expect(purchases.restoreCalls, greaterThanOrEqualTo(1));
      expect(repo.forceCalls, contains(true));
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('restore active 且归属为当前用户 → forced 收敛并写缓存', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final repo = FakeEntitlementRepository.queue([
        Entitlement.free,
        Entitlement.free,
        proEntitlement,
      ]);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: cache,
        purchases: FakePurchaseService()
          ..restoreResult = proEntitlement
          ..restoreOriginalAppUserId = 'u1',
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await container.read(subscriptionControllerProvider.notifier).restore();
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
      expect(cache.stored?.userId, 'u1');
      expect(cache.stored?.entitlement.isPremium, isTrue);
    });
  });

  test('restore active 但归属不是当前用户 → 抛错且不写入权益', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache();
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: cache,
        purchases: FakePurchaseService()
          ..restoreResult = proEntitlement
          ..restoreOriginalAppUserId = 'u_other',
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      await expectLater(
        controller.restore(),
        throwsA(
          isA<PurchaseException>().having(
            (e) => e.ownershipConflict,
            'ownershipConflict',
            isTrue,
          ),
        ),
      );
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        isNot(EntitlementStatus.premium),
      );
      expect(cache.stored?.entitlement.isPremium, isNot(isTrue));
    });
  });

  test('restore free 且存在其他 originalAppUserId → 不触发归属冲突', () async {
    await withClock(Clock.fixed(now), () async {
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: FakeEntitlementCache(),
        purchases: FakePurchaseService()
          ..restoreResult = Entitlement.free
          ..restoreOriginalAppUserId = 'u_other',
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      await controller.restore();
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('Web 渠道 restore → forced 后端刷新，不调用底层恢复', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository((_) async => proEntitlement);
      final purchases = FakePurchaseService()..restoreResult = Entitlement.free;
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.web,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await container.read(subscriptionControllerProvider.notifier).restore();
      await pumpEventQueue();

      expect(repo.calls, contains('u1'));
      expect(repo.forceCalls, contains(true));
      expect(purchases.restoreCalls, 0);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('商店渠道 + Paddle 来源权益 → 允许创建 Paddle Portal', () async {
    await withClock(Clock.fixed(now), () async {
      final dio = _MockDio();
      when(
        () => dio.post<Map<String, dynamic>>(
          '/api/paddle/portal',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/api/paddle/portal'),
          statusCode: 200,
          data: {'portalUrl': 'https://customer-portal.paddle.test/session'},
        ),
      );
      final paddleEntitlement = Entitlement(
        isPremium: true,
        productId: 'plus_yearly',
        expiresAt: now.add(const Duration(days: 30)),
        source: EntitlementSource.paddle,
      );
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => paddleEntitlement),
        cache: FakeEntitlementCache(),
        purchases: FakePurchaseService()..currentResult = Entitlement.free,
        paymentChannel: ClientPaymentChannel.appleStore,
        paddleRepository: PaddleBillingRepository.withDio(dio),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final uri = await container
          .read(subscriptionControllerProvider.notifier)
          .createPaddlePortal();

      expect(uri.host, 'customer-portal.paddle.test');
      final options =
          verify(
                () => dio.post<Map<String, dynamic>>(
                  '/api/paddle/portal',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as Options;
      expect(options.headers?['Authorization'], 'Bearer t1');
    });
  });

  test('商店渠道 + 非 Paddle 来源权益 → 拒绝创建 Paddle Portal', () async {
    await withClock(Clock.fixed(now), () async {
      final appleEntitlement = Entitlement(
        isPremium: true,
        productId: 'pro_yearly',
        expiresAt: now.add(const Duration(days: 30)),
        source: EntitlementSource.apple,
      );
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => appleEntitlement),
        cache: FakeEntitlementCache(),
        purchases: FakePurchaseService()..currentResult = appleEntitlement,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      await expectLater(
        container
            .read(subscriptionControllerProvider.notifier)
            .createPaddlePortal(),
        throwsA(isA<PurchaseException>()),
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
        paymentChannel: ClientPaymentChannel.appleStore,
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

  test('fail-closed：身份未绑定 → restore 报错且不发起恢复（先经后端刷新）', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()..ensureIdentifiedResult = false;
      final repo = FakeEntitlementRepository((_) async => null);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      final controller = container.read(
        subscriptionControllerProvider.notifier,
      );
      await pumpEventQueue();

      await expectLater(
        controller.restore(),
        throwsA(isA<PurchaseException>()),
      );
      // fail-closed 前先做过一次 forced 后端刷新（identify 故障不阻断纯后端路径）。
      expect(repo.forceCalls, contains(true));
      expect(purchases.ensureIdentifiedCalls, contains('u1'));
      expect(purchases.restoreCalls, 0);
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

      // fireImmediately 令 build 即以当前已登录身份触发 ensureIdentified(logIn + appUserID 核对)。
      expect(purchases.ensureIdentifiedCalls, contains('u1'));
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

  // Paddle 来源的会员权益样本（Bug1/Bug3/R2 用）。
  final paddlePremium = Entitlement(
    isPremium: true,
    productId: 'plus_yearly',
    expiresAt: now.add(const Duration(days: 30)),
    source: EntitlementSource.paddle,
  );

  test(
    'Bug3：appleStore + 后端不可达 + 新鲜 Paddle premium 缓存 → premium 且 isStale',
    () async {
      await withClock(Clock.fixed(now), () async {
        final cache = FakeEntitlementCache()..stored = cached(paddlePremium);
        final container = makeContainer(
          identity: signedIn,
          repo: FakeEntitlementRepository((_) async => null),
          cache: cache,
          paymentChannel: ClientPaymentChannel.appleStore,
        );
        container.read(subscriptionControllerProvider);
        await pumpEventQueue();

        final state = container.read(subscriptionControllerProvider);
        expect(state.status, EntitlementStatus.premium);
        expect(state.isStale, isTrue);
      });
    },
  );

  test('Bug3b：appleStore + 后端明确 free + premium 缓存 → free（权威降级）', () async {
    await withClock(Clock.fixed(now), () async {
      final cache = FakeEntitlementCache()..stored = cached(paddlePremium);
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => Entitlement.free),
        cache: cache,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final state = container.read(subscriptionControllerProvider);
      expect(state.status, EntitlementStatus.free);
      expect(state.isStale, isFalse);
    });
  });

  test(
    'Bug1：Paddle 会员在 appleStore 包 restore → premium 且不调 RC restore',
    () async {
      await withClock(Clock.fixed(now), () async {
        final purchases = FakePurchaseService();
        final container = makeContainer(
          identity: signedIn,
          repo: FakeEntitlementRepository((_) async => paddlePremium),
          cache: FakeEntitlementCache(),
          purchases: purchases,
          paymentChannel: ClientPaymentChannel.appleStore,
        );
        container.read(subscriptionControllerProvider);
        await pumpEventQueue();

        await container.read(subscriptionControllerProvider.notifier).restore();
        await pumpEventQueue();

        expect(purchases.restoreCalls, 0);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );
      });
    },
  );

  test('R1：purchase 后首次读到旧投影 free，force 重试收敛 premium', () {
    fakeAsync((async) {
      withClock(async.getClock(now), () {
        // 冷启动 free → 收敛第一次读到未更新投影 free → 第二次 force 读到 premium。
        final repo = FakeEntitlementRepository.queue([
          Entitlement.free,
          Entitlement.free,
          proEntitlement,
        ]);
        final container = makeContainer(
          identity: signedIn,
          repo: repo,
          cache: FakeEntitlementCache(),
          purchases: FakePurchaseService()..purchaseResult = proEntitlement,
          paymentChannel: ClientPaymentChannel.appleStore,
        );
        container.read(subscriptionControllerProvider);
        async.flushMicrotasks();

        unawaited(
          container
              .read(subscriptionControllerProvider.notifier)
              .purchase('pro_yearly'),
        );
        async.flushMicrotasks();
        // 第一次收敛读到 free，等待 2s 重试。
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.free,
        );

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.premium,
        );
        // 收敛调用均为 force。
        expect(repo.forceCalls.where((f) => f).length, greaterThanOrEqualTo(2));
      });
    });
  });

  test('R2：RC identify 故障 + 后端 Paddle premium → restore 正常返回，不抛异常', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()..ensureIdentifiedResult = false;
      final container = makeContainer(
        identity: signedIn,
        repo: FakeEntitlementRepository((_) async => paddlePremium),
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      // identify 故障不得阻断纯后端刷新：restore 命中 premium 即返回。
      await container.read(subscriptionControllerProvider.notifier).restore();
      await pumpEventQueue();

      expect(purchases.restoreCalls, 0);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });
  });

  test('receiptInUse：RC 收据被占用 → 不 rethrow，转 forced 回源确认', () async {
    await withClock(Clock.fixed(now), () async {
      final purchases = FakePurchaseService()
        ..restoreError = PurchaseException('收据已被占用', receiptInUse: true);
      final repo = FakeEntitlementRepository((_) async => Entitlement.free);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      // 不应把 receiptInUse 冒泡为「购买失败」。
      await container.read(subscriptionControllerProvider.notifier).restore();
      await pumpEventQueue();

      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
      // 前置 forced refresh + 占用后回源确认 → repo 至少两次 forced 调用。
      expect(repo.forceCalls.where((f) => f).length, greaterThanOrEqualTo(2));
    });
  });

  test('切号竞态：purchase 成交 await 期间身份变化 → 跳过收敛，不污染新身份', () async {
    await withClock(Clock.fixed(now), () async {
      final purchaseGate = Completer<void>();
      final purchases = FakePurchaseService()
        ..purchaseResult = proEntitlement
        ..purchaseCompleter = purchaseGate;
      final repo = FakeEntitlementRepository(
        (userId) async => userId == 'u2' ? Entitlement.free : null,
      );
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
        purchases: purchases,
        paymentChannel: ClientPaymentChannel.appleStore,
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();

      final purchaseFuture = container
          .read(subscriptionControllerProvider.notifier)
          .purchase('pro_yearly');
      await pumpEventQueue();

      // 成交 await 期间切换身份。
      container.read(testIdentityProvider.notifier).state =
          const SubscriptionIdentity(userId: 'u2', accessToken: 't2');
      await pumpEventQueue();

      purchaseGate.complete();
      await purchaseFuture;
      await pumpEventQueue();

      // 收敛被跳过（无 forced 调用），state 归新身份对账结果。
      expect(repo.forceCalls, isNot(contains(true)));
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('收敛失败：后端持续不可达 → 三次尝试后保持现状，不抛异常', () {
    fakeAsync((async) {
      withClock(async.getClock(now), () {
        final repo = FakeEntitlementRepository((_) async => null);
        final container = makeContainer(
          identity: signedIn,
          repo: repo,
          cache: FakeEntitlementCache(),
          purchases: FakePurchaseService()..purchaseResult = proEntitlement,
          paymentChannel: ClientPaymentChannel.appleStore,
        );
        container.read(subscriptionControllerProvider);
        async.flushMicrotasks();

        var completed = false;
        Object? thrown;
        container
            .read(subscriptionControllerProvider.notifier)
            .purchase('pro_yearly')
            .then((_) => completed = true, onError: (Object e) => thrown = e);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(completed, isTrue);
        expect(thrown, isNull);
        expect(repo.forceCalls.where((f) => f).length, 3);
        expect(
          container.read(subscriptionControllerProvider).status,
          EntitlementStatus.unknown,
        );
      });
    });
  });

  test('E7：后端配额拒绝且本地 premium → 触发重对账收敛；free 则不动作', () async {
    await withClock(Clock.fixed(now), () async {
      // 冷启动 premium（过时缓存投影），配额拒绝后回源读到权威 free。
      final repo = FakeEntitlementRepository.queue([
        proEntitlement,
        Entitlement.free,
      ]);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
      final callsBefore = repo.calls.length;

      container
          .read(subscriptionControllerProvider.notifier)
          .reconcileOnServerQuotaRejection('test');
      await pumpEventQueue();

      expect(repo.calls.length, callsBefore + 1);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );

      // 已是 free：配额拒绝属正常路径，不再触发对账。
      container
          .read(subscriptionControllerProvider.notifier)
          .reconcileOnServerQuotaRejection('test');
      await pumpEventQueue();
      expect(repo.calls.length, callsBefore + 1);
    });
  });

  test('E6：后端权益信号与本地分歧 → 回源对账；一致或 unknown 不动作', () async {
    await withClock(Clock.fixed(now), () async {
      final repo = FakeEntitlementRepository.queue([
        proEntitlement,
        Entitlement.free,
      ]);
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
      final callsBefore = repo.calls.length;
      // controller build 时注册的信号处理器（模拟拦截器读到响应头）。
      final onSignal = EntitlementSignalInterceptor.onSignal;
      expect(onSignal, isNotNull);

      // 与本地一致（server=1, local=premium）→ 不刷新。
      onSignal!(serverActive: true, path: '/api/v1/stream/translate');
      await pumpEventQueue();
      expect(repo.calls.length, callsBefore);

      // /api/entitlements 自身的信号 → 忽略（响应体即权威）。
      onSignal(serverActive: false, path: '/api/entitlements');
      await pumpEventQueue();
      expect(repo.calls.length, callsBefore);

      // 分歧（server=0, local=premium）→ 回源对账，读到权威 free。
      onSignal(serverActive: false, path: '/api/v1/stream/translate');
      await pumpEventQueue();
      expect(repo.calls.length, callsBefore + 1);
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('E6：并发分歧信号去重，只触发一次对账', () async {
    await withClock(Clock.fixed(now), () async {
      final refreshGate = Completer<Entitlement?>();
      var calls = 0;
      final repo = FakeEntitlementRepository((_) async {
        calls++;
        // 第一次（冷启动）premium；后续对账挂起直到 gate 完成。
        if (calls == 1) return proEntitlement;
        return refreshGate.future;
      });
      final container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      final onSignal = EntitlementSignalInterceptor.onSignal!;

      // 一批并发响应触发多个分歧信号：仅第一个进入 refresh。
      onSignal(serverActive: false, path: '/api/v1/stream/translate');
      onSignal(serverActive: false, path: '/api/v1/stream/analyze');
      onSignal(serverActive: false, path: '/api/v1/stream/sense-groups');
      await pumpEventQueue();
      expect(calls, 2); // 冷启动 1 次 + 信号触发 1 次。

      refreshGate.complete(Entitlement.free);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.free,
      );
    });
  });

  test('E8：refreshIfStale 新鲜窗内跳过，超窗回源', () async {
    final repo = FakeEntitlementRepository((_) async => proEntitlement);
    late ProviderContainer container;
    await withClock(Clock.fixed(now), () async {
      container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(repo.calls.length, 1);

      // 刚确认过：跳过。
      await container
          .read(subscriptionControllerProvider.notifier)
          .refreshIfStale();
      expect(repo.calls.length, 1);
    });

    // 25 小时后（默认 24 小时新鲜窗外）：回源。
    await withClock(Clock.fixed(now.add(const Duration(hours: 25))), () async {
      await container
          .read(subscriptionControllerProvider.notifier)
          .refreshIfStale();
      expect(repo.calls.length, 2);
    });
  });

  test('E8：后台期间越过 expiresAt → refreshIfStale 立即回源', () async {
    final expiry = now.add(const Duration(hours: 1));
    final repo = FakeEntitlementRepository.queue([
      Entitlement(isPremium: true, productId: 'pro_monthly', expiresAt: expiry),
      Entitlement.free,
    ]);
    late ProviderContainer container;
    await withClock(Clock.fixed(now), () async {
      container = makeContainer(
        identity: signedIn,
        repo: repo,
        cache: FakeEntitlementCache(),
      );
      container.read(subscriptionControllerProvider);
      await pumpEventQueue();
      expect(
        container.read(subscriptionControllerProvider).status,
        EntitlementStatus.premium,
      );
    });

    // 模拟进程挂起 2 小时后 resume（到期 one-shot timer 未能触发），
    // maxAge 放大以隔离「越过到期点」这一条件。
    await withClock(Clock.fixed(now.add(const Duration(hours: 2))), () async {
      await container
          .read(subscriptionControllerProvider.notifier)
          .refreshIfStale(maxAge: const Duration(days: 7));
      expect(repo.calls.length, 2);
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

  test('并发普通权益刷新 single-flight，只执行一次 GET', () async {
    final gate = Completer<Entitlement?>();
    var block = false;
    final repo = FakeEntitlementRepository(
      (_) => block ? gate.future : Future.value(Entitlement.free),
    );
    final container = makeContainer(
      identity: signedIn,
      repo: repo,
      cache: FakeEntitlementCache(),
    );
    container.read(subscriptionControllerProvider);
    await pumpEventQueue();
    repo.calls.clear();
    repo.forceCalls.clear();
    block = true;

    final controller = container.read(subscriptionControllerProvider.notifier);
    final first = controller.refresh();
    final second = controller.refresh();
    await pumpEventQueue();

    expect(repo.calls, hasLength(1));
    gate.complete(Entitlement.free);
    await Future.wait([first, second]);
    expect(repo.calls, hasLength(1));
  });

  test('普通刷新期间到达 force，普通完成后补执行 force', () async {
    final normalGate = Completer<Entitlement?>();
    var call = 0;
    final repo = FakeEntitlementRepository((_) {
      final current = call++;
      if (current == 0) return Future.value(Entitlement.free);
      if (current == 1) return normalGate.future;
      return Future.value(proEntitlement);
    });
    final container = makeContainer(
      identity: signedIn,
      repo: repo,
      cache: FakeEntitlementCache(),
    );
    container.read(subscriptionControllerProvider);
    await pumpEventQueue();
    repo.calls.clear();
    repo.forceCalls.clear();

    final controller = container.read(subscriptionControllerProvider.notifier);
    final normal = controller.refresh();
    await pumpEventQueue();
    final forced = controller.refresh(force: true);
    await pumpEventQueue();
    expect(repo.forceCalls, [false]);

    normalGate.complete(Entitlement.free);
    await Future.wait([normal, forced]);
    expect(repo.forceCalls, [false, true]);
    expect(container.read(subscriptionControllerProvider).isActive, isTrue);
  });
}

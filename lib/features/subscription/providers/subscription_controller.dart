/// 订阅权益控制器：App 内权益的**唯一真相源**。
///
/// 职责（对齐项目「单向数据流 + 集中状态变更入口」）：
/// - 启动用本地缓存 seed，再触发与在线权威源（后端 / RC）的对账（C4 合并规则）。
/// - 监听 [supabaseSessionProvider]：登出清权益、切换用户重对账（身份单一来源）。
/// - 用 generation counter 防异步竞态（吸取 CLAUDE.md §7.1/§7.2 教训：
///   旧用户的异步回调到达时必须丢弃，不能污染新用户 state）。
///
/// UI 永远只读本 controller 的 state，不直接读缓存 / RC / 后端。
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/client_distribution.dart';
import '../../../services/app_logger.dart';
import '../models/entitlement.dart';
import '../models/entitlement_source.dart';
import '../services/entitlement_cache.dart';
import '../services/entitlement_reconciler.dart';
import '../services/entitlement_repository.dart';
import '../services/paddle_billing_repository.dart';
import '../services/purchase_service.dart';
import '../services/revenuecat_purchase_service.dart';
import '../state/entitlement_state.dart';
import 'subscription_identity.dart';

part 'subscription_controller.g.dart';

/// 当前支付渠道 seam：生产读取编译期平台/渠道，测试可 override。
final subscriptionPaymentChannelProvider = Provider<ClientPaymentChannel>(
  (ref) => clientPaymentChannel,
);

/// Paddle checkout 的渠道级门控：direct/Web 默认允许；商店包必须由 UI 在远程开关
/// 命中后显式声明 fallback，避免默认原生购买链路误走 Paddle。
bool canStartPaddleCheckoutForChannel({
  required ClientPaymentChannel channel,
  required bool allowStoreFallback,
}) {
  return switch (channel) {
    ClientPaymentChannel.web => true,
    ClientPaymentChannel.appleStore ||
    ClientPaymentChannel.googlePlay => allowStoreFallback,
    ClientPaymentChannel.unavailable => false,
  };
}

@Riverpod(keepAlive: true)
class SubscriptionController extends _$SubscriptionController {
  /// 防竞态代际计数。每次重对账 / 登录切换前自增，异步回调校验不匹配则丢弃。
  int _generation = 0;

  /// 当前身份同步任务。外部 refresh 必须等待它完成，避免 RevenueCat logIn 尚未
  /// 生效时读取到旧匿名用户 / 旧账号的 CustomerInfo。
  Future<void>? _identitySync;

  /// 调试用权益覆盖（仅 debug 构建）。非 null 时 [refresh] 短路为该状态，
  /// 用于不发起真实购买即测试会员 UI / Paywall 门禁。release 不暴露入口。
  EntitlementStatus? _debugOverride;

  /// 当前权益到期刷新计时器。只在 premium 且存在未来 expiresAt 时启用。
  Timer? _expiryRefreshTimer;

  @override
  EntitlementState build() {
    // 监听身份变化：登出清权益、切换用户重对账。
    // fireImmediately：build 时立即以当前身份触发一次，确保已登录用户即使在
    // 「身份早已落定后」才首次创建本 controller，也会执行一次 Purchases.logIn 绑定
    // （否则默认只在值变化时回调 → 老用户登录态无变化 → logIn 从不执行 → 匿名购买）。
    ref.listen(subscriptionIdentityProvider, (previous, next) {
      final sync = _onIdentityChanged(previous, next);
      _identitySync = sync;
      unawaited(
        sync.then(
          (_) {
            if (identical(_identitySync, sync)) {
              _identitySync = null;
            }
          },
          onError: (Object e, StackTrace stackTrace) {
            if (identical(_identitySync, sync)) {
              _identitySync = null;
            }
            AppLogger.log('Subscription', '身份同步异常: $e');
          },
        ),
      );
    }, fireImmediately: true);
    // 监听平台侧权益变化（续费 / 退款 / 试用转正），运行期实时刷新。
    final sub = _purchases.entitlementStream.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    ref.onDispose(_cancelExpiryRefreshTimer);
    // 冷启动首帧返回「未知」中间态（C5）。后续对账由上面的身份监听串行触发：
    // 已登录时先 RevenueCat identify，再读取权益；匿名启动则直接匿名对账。
    return const EntitlementState.unknown();
  }

  EntitlementCache get _cache => ref.read(entitlementCacheProvider);
  EntitlementRepository get _repository =>
      ref.read(entitlementRepositoryProvider);
  PurchaseService get _purchases => ref.read(purchaseServiceProvider);
  ClientPaymentChannel get _paymentChannel =>
      ref.read(subscriptionPaymentChannelProvider);

  SubscriptionIdentity get _identity => ref.read(subscriptionIdentityProvider);

  /// 与在线权威源对账并刷新权益。集中状态变更入口之一。
  Future<void> refresh() async {
    await _waitForIdentitySync();
    await _refreshOnline();
  }

  /// 等待当前最新身份同步完成。等待过程中若身份再次切换，会继续等待新的任务，
  /// 避免 refresh 只等到旧用户 identify 就读取到新用户尚未绑定时的 CustomerInfo。
  Future<void> _waitForIdentitySync() async {
    while (true) {
      final sync = _identitySync;
      if (sync == null) return;
      await sync;
      if (_identitySync == null || identical(_identitySync, sync)) return;
    }
  }

  /// 执行实际在线对账。调用方必须保证需要绑定购买身份时已完成 identify。
  Future<void> _refreshOnline() async {
    // 调试覆盖生效时跳过在线对账，保持人为设定的状态。
    final override = _debugOverride;
    if (override != null) {
      _setEntitlementState(_stateForOverride(override));
      return;
    }
    final generation = ++_generation;
    final identity = _identity;
    final userId = identity.userId;
    final accessToken = identity.accessToken;
    AppLogger.log(
      'Subscription',
      '权益刷新开始: generation=$generation channel=${_paymentChannel.name} '
          'userId=${userId ?? "匿名"} hasToken=${accessToken != null}',
    );

    final cached = await _readValidCache(userId);
    Entitlement? remote;
    String? error;
    try {
      // Web/direct 无原生商店 SDK，权益经后端 /api/entitlements 读回；
      // App Store / Google Play 则以 RevenueCat SDK CustomerInfo 为准。
      if (_paymentChannel == ClientPaymentChannel.web &&
          userId != null &&
          accessToken != null) {
        AppLogger.log('Subscription', 'Web/direct 权益刷新读取后端: userId=$userId');
        remote = await _repository.fetchRemote(
          userId: userId,
          accessToken: accessToken,
        );
      }
      if (_paymentChannel == ClientPaymentChannel.web &&
          remote == null &&
          (userId == null || accessToken == null)) {
        // Direct/Paddle 权益只能通过已登录账号从后端读取。匿名或 token 未就绪时
        // 与 native 匿名无购买保持同一上层语义：明确 free，而不是把无 token 当错误态。
        remote = Entitlement.free;
      }
      // Native 渠道或后端不可达时，用平台购买服务的当前权益快照兜底。
      if (remote == null) {
        AppLogger.log(
          'Subscription',
          '权益刷新读取购买服务快照: channel=${_paymentChannel.name}',
        );
        remote = await _purchases.currentEntitlement();
        // 需求1：native 商店渠道在 RC 判定为「非会员」时，回退查后端补充识别。
        // RevenueCat CustomerInfo 不含 Paddle 订阅——用户若在 Web/direct 用 Paddle
        // 订阅后换到商店版 App 登录同一账号，仅凭 RC 会被漏判为免费。此处补一次
        // /api/entitlements（后端已合并 RC + Paddle），命中会员则以后端结果为准。
        if (_paymentChannel != ClientPaymentChannel.web &&
            !remote.isPremium &&
            userId != null &&
            accessToken != null) {
          AppLogger.log(
            'Subscription',
            'native RC 非会员，回退查后端补充: userId=$userId',
          );
          final backend = await _repository.fetchRemote(
            userId: userId,
            accessToken: accessToken,
          );
          if (backend != null && backend.isPremium) {
            AppLogger.log(
              'Subscription',
              'native 后端补查命中会员: source=${backend.source.name} '
                  'productId=${backend.productId}',
            );
            remote = backend;
          }
        }
      }
    } catch (e) {
      // 失败不静默吞：记录错误、保留兜底，不误判为无权益。
      error = e.toString();
      AppLogger.log(
        'Subscription',
        '权益刷新在线源失败: generation=$generation error=$error',
      );
    }

    if (generation != _generation) return; // 已被更新的对账 / 登录切换作废。

    final next = reconcileEntitlement(
      remote: remote,
      cached: cached,
      now: clock.now(),
    );
    _setEntitlementState(
      error == null ? next : next.copyWith(error: error, isStale: true),
    );

    // 对账关键日志：在线源 / 缓存各自结果 + 合并后最终态，便于排查
    // 「删了订阅仍显示已订阅」「在线不可达走缓存」等问题。
    AppLogger.log(
      'Subscription',
      '对账完成: remote=${remote != null ? "isPremium=${remote.isPremium}" : "无"} '
          'cached=${cached != null ? "isPremium=${cached.entitlement.isPremium}" : "无"} '
          '→ status=${state.status.name} isStale=${state.isStale}'
          ' source=${state.entitlement?.source.name ?? "none"} '
          'channel=${_paymentChannel.name}'
          '${error != null ? " error=$error" : ""}',
    );

    if (remote != null) {
      await _writeCache(remote, userId);
    }
  }

  /// 发起购买。成功后立即以平台返回的权益快照解锁。
  Future<void> purchase(String planId) async {
    AppLogger.log(
      'Subscription',
      '发起购买: planId=$planId userId=${_identity.userId ?? "匿名"}',
    );
    await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止。
    try {
      final entitlement = await _purchases.purchase(planId);
      await _applyEntitlement(entitlement, _identity.userId);
      AppLogger.log(
        'Subscription',
        '购买成功: isPremium=${entitlement.isPremium} productId=${entitlement.productId} '
            'expiresAt=${entitlement.expiresAt?.toIso8601String() ?? "无"}',
      );
    } on PurchaseException catch (e) {
      // 取消与失败分别记录：取消属正常路径，不当错误处理。
      AppLogger.log(
        'Subscription',
        e.cancelled
            ? '购买取消: planId=$planId'
            : '购买失败: planId=$planId msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      AppLogger.log('Subscription', '购买异常: planId=$planId error=$e');
      rethrow;
    }
  }

  /// 创建 Paddle checkout。创建成功只返回 URL，不改变 premium 状态；
  /// 只有 webhook 更新后端权益并由 [refresh] 读回才算购买完成。
  ///
  /// 默认只允许 direct/Web 渠道；商店包只能由 Paywall 在远程门控通过后显式传入
  /// [allowStoreFallback]，避免原生购买路径误穿到 Paddle。
  Future<Uri> startPaddleCheckout(
    String planId, {
    bool allowStoreFallback = false,
  }) async {
    if (!canStartPaddleCheckoutForChannel(
      channel: _paymentChannel,
      allowStoreFallback: allowStoreFallback,
    )) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 中止: channel=${_paymentChannel.name} '
            'allowStoreFallback=$allowStoreFallback planId=$planId',
      );
      throw PurchaseException('当前渠道不支持 Paddle checkout');
    }
    AppLogger.log(
      'Subscription',
      'Paddle checkout 创建入口: planId=$planId '
          'userId=${_identity.userId ?? "匿名"}',
    );
    await _ensurePurchaseIdentity();
    final token = _identity.accessToken;
    if (token == null || token.isEmpty) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 中止: planId=$planId reason=tokenEmpty',
      );
      throw PurchaseException('订阅身份未就绪，请稍后重试');
    }
    try {
      final session = await ref
          .read(paddleBillingRepositoryProvider)
          .createCheckout(accessToken: token, planId: planId);
      AppLogger.log(
        'Subscription',
        'Paddle checkout 创建完成: planId=$planId '
            'attemptId=${session.attemptId} host=${session.checkoutUrl.host}',
      );
      return session.checkoutUrl;
    } catch (error) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 创建失败: planId=$planId error=$error',
      );
      rethrow;
    }
  }

  /// 创建 Paddle Customer Portal session，供 direct 用户取消订阅或更新支付方式。
  Future<Uri> createPaddlePortal() async {
    final currentEntitlement = state.entitlement;
    final hasActivePaddleEntitlement =
        currentEntitlement?.source == EntitlementSource.paddle &&
        (currentEntitlement?.isActive(clock.now()) ?? false);
    if (_paymentChannel != ClientPaymentChannel.web &&
        !hasActivePaddleEntitlement) {
      AppLogger.log(
        'Subscription',
        'Paddle Portal 中止: channel=${_paymentChannel.name} '
            'source=${currentEntitlement?.source.name ?? "none"}',
      );
      throw PurchaseException('当前渠道不支持 Paddle Portal');
    }
    AppLogger.log(
      'Subscription',
      'Paddle Portal 创建入口: userId=${_identity.userId ?? "匿名"} '
          'channel=${_paymentChannel.name} '
          'source=${currentEntitlement?.source.name ?? "none"}',
    );
    await _ensurePurchaseIdentity();
    final token = _identity.accessToken;
    if (token == null || token.isEmpty) {
      AppLogger.log('Subscription', 'Paddle Portal 中止: reason=tokenEmpty');
      throw PurchaseException('订阅身份未就绪，请稍后重试');
    }
    try {
      final uri = await ref
          .read(paddleBillingRepositoryProvider)
          .createPortal(accessToken: token);
      AppLogger.log(
        'Subscription',
        'Paddle Portal 创建完成: host=${uri.host} path=${uri.path}',
      );
      return uri;
    } catch (error) {
      AppLogger.log('Subscription', 'Paddle Portal 创建失败: error=$error');
      rethrow;
    }
  }

  /// 恢复购买。
  Future<void> restore() async {
    AppLogger.log('Subscription', '发起恢复购买: userId=${_identity.userId ?? "匿名"}');
    if (_paymentChannel == ClientPaymentChannel.web) {
      // Web/direct 无平台恢复入口，恢复语义等价于回源刷新后端权益。
      AppLogger.log('Subscription', 'Web 渠道恢复购买转为刷新后端权益');
      await refresh();
      return;
    }
    await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止。
    try {
      final result = await _purchases.restore();
      final entitlement = result.entitlement;
      final currentUserId = _identity.userId;
      final ownerUserId = result.originalAppUserId;
      if (entitlement.isActive(clock.now()) &&
          currentUserId != null &&
          ownerUserId != null &&
          ownerUserId != currentUserId) {
        AppLogger.log(
          'Subscription',
          '恢复购买归属冲突: currentUserId=$currentUserId '
              'originalAppUserId=$ownerUserId productId=${entitlement.productId}',
        );
        throw PurchaseException(
          '此订阅已绑定到另一个 Echo Loop 账号。请登录原账号后重试。',
          ownershipConflict: true,
        );
      }
      await _applyEntitlement(entitlement, _identity.userId);
      AppLogger.log(
        'Subscription',
        '恢复完成: isPremium=${entitlement.isPremium} productId=${entitlement.productId}',
      );
    } catch (e) {
      AppLogger.log('Subscription', '恢复购买失败: error=$e');
      rethrow;
    }
  }

  /// 清本地权益缓存 + 失效平台 SDK 缓存后强制重对账（调试用）。
  ///
  /// 解决「后台已删订阅但 App 仍显示已订阅」：本地 secure_storage 缓存与
  /// RevenueCat SDK 的 CustomerInfo 缓存都会让旧权益继续生效，这里一并清掉
  /// 再回源对账。同时解除调试覆盖，回到真实在线结果。
  Future<void> clearLocalCacheAndRefresh() async {
    _debugOverride = null;
    _generation++; // 作废在途对账。
    await _cache.clear();
    await _purchases.invalidateCustomerInfoCache();
    await refresh();
  }

  /// 手动覆盖权益状态（仅 debug 构建）。传 null 解除覆盖并重新对账。
  ///
  /// 用于不发起真实购买即验证会员 UI / Paywall 门禁；release 构建无入口。
  void debugOverrideEntitlement(EntitlementStatus? status) {
    if (!kDebugMode) return;
    _debugOverride = status;
    if (status == null) {
      unawaited(refresh());
      return;
    }
    _generation++; // 作废在途对账，避免被真实结果覆盖。
    _setEntitlementState(_stateForOverride(status));
  }

  /// 由覆盖状态构造对应的 [EntitlementState]。
  EntitlementState _stateForOverride(EntitlementStatus status) {
    return switch (status) {
      EntitlementStatus.premium => EntitlementState(
        status: EntitlementStatus.premium,
        entitlement: const Entitlement(
          isPremium: true,
          productId: 'debug_override',
        ),
        isStale: false,
      ),
      EntitlementStatus.free => const EntitlementState.free(),
      EntitlementStatus.unknown => const EntitlementState.unknown(),
    };
  }

  /// 立即把一份权益应用为当前 state 并落盘（购买 / 恢复成功路径）。
  Future<void> _applyEntitlement(
    Entitlement entitlement,
    String? userId,
  ) async {
    final generation = ++_generation;
    if (generation != _generation) return;
    _setEntitlementState(
      EntitlementState(
        status: entitlement.isActive(clock.now())
            ? EntitlementStatus.premium
            : EntitlementStatus.free,
        entitlement: entitlement,
        isStale: false,
      ),
    );
    await _writeCache(entitlement, userId);
  }

  /// 购买 / 恢复前的 fail-closed 身份门禁。
  ///
  /// 权益必须绑定到 Supabase user_id（跨设备、可恢复、能被 webhook 落库）。
  /// 未登录，或购买服务无法确认已绑定到该用户（RC 仍是匿名 / 绑定异常）时，
  /// 抛 [PurchaseException] 中止，**绝不允许在匿名身份上成交**。
  Future<void> _ensurePurchaseIdentity() async {
    final userId = _identity.userId;
    if (userId == null) {
      AppLogger.log('Subscription', '购买中止：未登录，无法绑定 Supabase user_id');
      throw PurchaseException('订阅需先登录账号');
    }
    final bound = await _purchases.ensureIdentified(userId);
    if (!bound) {
      AppLogger.log('Subscription', '购买中止：身份未就绪（未绑定到 userId=$userId）');
      throw PurchaseException('订阅身份未就绪，请稍后重试');
    }
  }

  /// 响应订阅身份变化。
  Future<void> _onIdentityChanged(
    SubscriptionIdentity? previous,
    SubscriptionIdentity next,
  ) async {
    final isInitialIdentity = previous == null;
    final previousUserId = previous?.userId;
    final nextUserId = next.userId;
    if (!isInitialIdentity && previousUserId == nextUserId) {
      return; // 仅 token 刷新，忽略。
    }

    _generation++; // 作废在途对账。
    if (nextUserId == null) {
      if (isInitialIdentity) {
        // 匿名冷启动没有身份要绑定，但仍要做一次对账，避免 state 停在 unknown。
        await _refreshOnline();
        return;
      }
      // 登出是账号隔离边界：先本地 fail-closed，最后 best-effort 解绑购买身份。
      _setEntitlementState(const EntitlementState.free());
      await _cache.clear();
      try {
        await _purchases.identify(null);
      } catch (e) {
        AppLogger.log('Subscription', '登出解绑购买身份失败，本地权益已清理: $e');
      }
      return;
    }
    // 登录 / 切换用户：绑定购买身份后重对账。
    final generation = _generation;
    bool bound;
    try {
      bound = await _purchases.ensureIdentified(nextUserId);
    } catch (e) {
      await _applyIdentityFailure(
        userId: nextUserId,
        generation: generation,
        error: e,
      );
      return;
    }
    if (!bound) {
      await _applyIdentityFailure(
        userId: nextUserId,
        generation: generation,
        error: PurchaseException('订阅身份未就绪，请稍后重试'),
      );
      return;
    }
    if (generation != _generation) return;
    await _refreshOnline();
  }

  /// identify 失败时 fail-closed：不读取平台 CustomerInfo，不写缓存，只使用当前用户
  /// 已有的新鲜缓存兜底，并把错误显式暴露给 UI / 调试日志。
  Future<void> _applyIdentityFailure({
    required String userId,
    required int generation,
    required Object error,
  }) async {
    final cached = await _readValidCache(userId);
    if (generation != _generation) return;
    final next = reconcileEntitlement(
      remote: null,
      cached: cached,
      now: clock.now(),
    );
    _setEntitlementState(next.copyWith(error: error.toString(), isStale: true));
    AppLogger.log('Subscription', '身份绑定失败，跳过权益查询: userId=$userId error=$error');
  }

  /// 写入权益状态并按 [Entitlement.expiresAt] 重排一次性到期刷新。
  ///
  /// App 长时间保持前台时不会触发 lifecycle resumed；这里用到期点的 one-shot
  /// refresh 兜住时效边界，避免内存态越过 expiresAt 后仍保持 premium。
  void _setEntitlementState(EntitlementState next) {
    state = next;
    _rescheduleExpiryRefresh(next);
  }

  void _rescheduleExpiryRefresh(EntitlementState next) {
    _cancelExpiryRefreshTimer();
    if (next.status != EntitlementStatus.premium) return;
    final expiresAt = next.entitlement?.expiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(clock.now());
    if (delay <= Duration.zero) return;
    _expiryRefreshTimer = Timer(delay, () {
      _expiryRefreshTimer = null;
      unawaited(refresh());
    });
  }

  void _cancelExpiryRefreshTimer() {
    _expiryRefreshTimer?.cancel();
    _expiryRefreshTimer = null;
  }

  /// 读取缓存，并校验归属用户；与当前用户不一致的缓存视为无效（防跨账号泄漏）。
  Future<CachedEntitlement?> _readValidCache(String? userId) async {
    final cached = await _cache.read();
    if (cached == null) return null;
    if (cached.userId != userId) return null;
    return cached;
  }

  Future<void> _writeCache(Entitlement entitlement, String? userId) async {
    await _cache.write(
      CachedEntitlement(
        userId: userId,
        entitlement: entitlement,
        cachedAt: clock.now(),
      ),
    );
  }
}

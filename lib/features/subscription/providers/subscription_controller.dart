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
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../config/client_distribution.dart';
import '../../../services/app_logger.dart';
import '../../../services/entitlement_signal_interceptor.dart';
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

/// E7 收敛回调：供 AI / 转录等后端 402 触发点调用，测试可 override 为 spy。
///
/// 惰性读取 controller（仅真实 402 发生时才触达订阅栈），让数据层不静态依赖
/// 订阅实现（副作用经接口注入，见 CLAUDE.md §2.5-22）。
final entitlementQuotaDivergenceHandlerProvider =
    Provider<void Function(String context)>((ref) {
      return (context) => ref
          .read(subscriptionControllerProvider.notifier)
          .reconcileOnServerQuotaRejection(context);
    });

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

  /// 当前权益到期刷新计时器。只在 premium 且存在未来 expiresAt 时启用。
  Timer? _expiryRefreshTimer;

  /// 最近一次在线权威确认时刻（remote 非 null 落定时更新）。
  /// [refreshIfStale]（E8）据此判断 resume 时是否需要真正回源。
  DateTime? _lastOnlineSyncAt;

  /// E6 信号触发的对账是否在途（去重：一批并发响应只触发一次 refresh）。
  bool _signalRefreshInFlight = false;

  /// 权益请求级 single-flight；force 比普通刷新强，不能被普通刷新吞掉。
  Future<void>? _normalRefreshInFlight;
  Future<void>? _forceRefreshInFlight;

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
    // E6：注册后端权益信号处理（backend Dio 拦截器读响应头转发到这里）。
    // 静态槽位：谁注册谁解除；dispose 时仅当仍是本实例的回调才清除。
    void signalHandler({required bool serverActive, required String path}) {
      _onServerEntitlementSignal(serverActive: serverActive, path: path);
    }

    EntitlementSignalInterceptor.onSignal = signalHandler;
    ref.onDispose(() {
      if (identical(EntitlementSignalInterceptor.onSignal, signalHandler)) {
        EntitlementSignalInterceptor.onSignal = null;
      }
    });
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

  /// 与后端权威源对账并刷新权益。集中状态变更入口之一。
  /// [force] 让后端绕过节流回源 RC（成交收敛 / 用户主动刷新用）。
  Future<void> refresh({bool force = false}) async {
    await _waitForIdentitySync();
    if (!force) {
      final stronger = _forceRefreshInFlight;
      if (stronger != null) {
        AppLogger.log('Subscription', '权益刷新合并: requested=normal joined=force');
        return stronger;
      }
      final existing = _normalRefreshInFlight;
      if (existing != null) {
        AppLogger.log('Subscription', '权益刷新合并: requested=normal joined=normal');
        return existing;
      }
      final operation = _refreshOnline();
      _normalRefreshInFlight = operation;
      try {
        await operation;
      } finally {
        if (identical(_normalRefreshInFlight, operation)) {
          _normalRefreshInFlight = null;
        }
      }
      return;
    }

    final existingForce = _forceRefreshInFlight;
    if (existingForce != null) {
      AppLogger.log('Subscription', '权益刷新合并: requested=force joined=force');
      return existingForce;
    }
    final normal = _normalRefreshInFlight;
    if (normal != null) {
      AppLogger.log('Subscription', '强制权益刷新排队: waitingFor=normal');
      await normal;
      AppLogger.log('Subscription', '强制权益刷新开始补执行: after=normal');
    }
    final forceAfterWait = _forceRefreshInFlight;
    if (forceAfterWait != null) {
      AppLogger.log(
        'Subscription',
        '权益刷新合并: requested=force joined=forceAfterWait',
      );
      return forceAfterWait;
    }
    final operation = _refreshOnline(force: true);
    _forceRefreshInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_forceRefreshInFlight, operation)) {
        _forceRefreshInFlight = null;
      }
    }
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

  /// 执行实际在线对账（全渠道单一来源）。调用方必须保证需要绑定购买身份时
  /// 已完成 identify。
  Future<void> _refreshOnline({bool force = false}) async {
    final generation = ++_generation;
    final identity = _identity;
    final userId = identity.userId;
    final accessToken = identity.accessToken;
    AppLogger.log(
      'Subscription',
      '权益刷新开始: generation=$generation force=$force '
          'channel=${_paymentChannel.name} userId=${userId ?? "匿名"} '
          'hasToken=${accessToken != null}',
    );

    final cached = await _readValidCache(userId);
    if (generation != _generation) {
      AppLogger.log(
        'Subscription',
        '权益刷新丢弃: phase=afterCache generation=$generation '
            'currentGeneration=$_generation',
      );
      return;
    }
    _setEntitlementState(
      state.copyWith(
        isRefreshing: true,
        clearError: true,
        clearFailureReason: true,
      ),
    );
    var settled = false;
    try {
      Entitlement? remote;
      if (userId != null && accessToken != null) {
        // 唯一权威源：后端 /api/entitlements（服务端已合并 RC + Paddle）。
        remote = await _repository.fetchRemote(
          userId: userId,
          accessToken: accessToken,
          force: force,
        );
      } else if (userId == null) {
        // 匿名：无账号可绑定的权益，明确 free。
        remote = Entitlement.free;
      } else {
        AppLogger.log(
          'Subscription',
          '权益请求跳过: reason=tokenUnavailable generation=$generation '
              'hasCached=${cached != null}',
        );
      }

      if (generation != _generation) {
        AppLogger.log(
          'Subscription',
          '权益刷新丢弃: phase=afterRemote generation=$generation '
              'currentGeneration=$_generation',
        );
        return;
      }

      final next = reconcileEntitlement(
        remote: remote,
        cached: cached,
        now: clock.now(),
      );
      _setEntitlementState(
        next.copyWith(
          isRefreshing: false,
          failureReason: remote == null
              ? EntitlementFailureReason.temporarilyUnavailable
              : null,
          clearFailureReason: remote != null,
          error: remote == null ? 'entitlement_temporarily_unavailable' : null,
          clearError: remote != null,
        ),
      );
      settled = true;
      if (remote != null) {
        _lastOnlineSyncAt = clock.now();
      }

      AppLogger.log(
        'Subscription',
        '对账完成: remote=${remote != null ? "isPremium=${remote.isPremium}" : "无"} '
            'cached=${cached != null ? "isPremium=${cached.entitlement.isPremium}" : "无"} '
            '→ status=${state.status.name} isStale=${state.isStale} '
            'source=${state.entitlement?.source.name ?? "none"} '
            'channel=${_paymentChannel.name}',
      );

      if (remote != null) {
        await _writeCache(remote, userId);
      }
    } finally {
      // 仅当前代际仍属于本请求时收尾，旧请求不能关闭新请求的刷新态。
      if (!settled && generation == _generation && state.isRefreshing) {
        _setEntitlementState(
          state.copyWith(
            isRefreshing: false,
            failureReason: EntitlementFailureReason.temporarilyUnavailable,
            error: 'entitlement_temporarily_unavailable',
          ),
        );
      }
    }
  }

  /// 发起购买。成交后不做本地裁决，统一回源后端收敛（单一来源）。
  Future<void> purchase(String planId) async {
    AppLogger.log(
      'Subscription',
      '发起购买: planId=$planId userId=${_identity.userId ?? "匿名"}',
    );
    await _ensurePurchaseIdentity(); // fail-closed：未绑定 Supabase user_id 直接中止。
    final generation = _generation; // 成交期间身份若变化，跳过收敛（新身份自有对账）。
    try {
      final entitlement = await _purchases.purchase(planId);
      AppLogger.log(
        'Subscription',
        '购买成交: productId=${entitlement.productId} '
            'isPremium=${entitlement.isPremium}（结果仅记录，不作裁决）',
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
    if (generation != _generation) {
      AppLogger.log('Subscription', '购买期间身份已变化，跳过收敛刷新');
      return;
    }
    await _convergeAfterTransaction('purchase');
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
    } on PurchaseException catch (error) {
      if (error.alreadyEntitled) {
        AppLogger.log('Subscription', 'Paddle checkout 已有权益，开始强制对账');
        await refresh(force: true);
      }
      AppLogger.log(
        'Subscription',
        'Paddle checkout 创建失败: planId=$planId type=${error.runtimeType} '
            'alreadyEntitled=${error.alreadyEntitled}',
      );
      rethrow;
    } catch (error) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 创建失败: planId=$planId type=${error.runtimeType}',
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

  /// 找回/刷新会员（全渠道统一语义）。
  /// 1) 先回源后端（唯一权威，含 Paddle 与已同步的商店订阅），命中即结束；
  /// 2) 仍非会员且是商店渠道 → RC restore 认领游离商店收据，认领后回源收敛。
  Future<void> restore() async {
    AppLogger.log(
      'Subscription',
      '恢复/刷新会员发起: channel=${_paymentChannel.name} '
          'source=${state.entitlement?.source.name ?? "none"} '
          'userId=${_identity.userId ?? "匿名"}',
    );

    // 用户主动动作 → force 取最新权威（后端 60s 防刷兜底）。
    // 注意：_ensurePurchaseIdentity 在此步之后——RC identify 故障不得阻断纯后端刷新。
    await refresh(force: true);
    if (state.isActive) return; // 命中（含 Paddle 会员在商店包：不调 RC restore）。

    final isStoreChannel =
        _paymentChannel == ClientPaymentChannel.appleStore ||
        _paymentChannel == ClientPaymentChannel.googlePlay;
    if (!isStoreChannel) return; // web/direct/unavailable：恢复=后端刷新，已完成。

    await _ensurePurchaseIdentity(); // fail-closed：仅 RC restore 需要。
    final generation = _generation;
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
      if (!entitlement.isActive(clock.now())) {
        AppLogger.log('Subscription', 'RC 无可恢复收据，保持后端对账结果'); // 不降级。
        return;
      }
      AppLogger.log(
        'Subscription',
        '商店收据认领成功: productId=${entitlement.productId}',
      );
    } on PurchaseException catch (e) {
      if (e.receiptInUse) {
        // 收据属其他 RC 订阅者，但本账号可能已被后端判为会员：回源确认，
        // 不当「购买失败」。
        AppLogger.log('Subscription', 'RC 收据被占用，回源确认真实会员态');
        await refresh(force: true);
        return;
      }
      AppLogger.log('Subscription', '恢复购买失败: error=$e');
      rethrow;
    }
    if (generation != _generation) return; // 认领期间身份已变化，跳过收敛。
    await _convergeAfterTransaction('restore'); // 认领→RC 已知→force 回源即收敛。
  }

  /// E8：resume 等低信号触发点用的条件刷新——仅在以下任一情况才真正回源：
  /// - 从未获得在线确认（unknown / 无确认时刻），或当前 state 本就 isStale；
  /// - 距上次在线确认超过 [maxAge]（长新鲜窗，兜住长期只用本地功能、无后端
  ///   流量的用户；退款等分歧主要靠 E6/E7 被动收敛，这里只是天级兜底）；
  /// - 后台期间越过了 expiresAt（到期 one-shot timer 在挂起时不可靠）。
  /// 其余情况跳过，避免频繁切前台盲查后端。
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    // 冷启动身份绑定本身会完成首次对账；先等它落定再判断，避免 Paywall 进入事件
    // 与启动对账并发造成第二次 entitlement GET。
    await _waitForIdentitySync();
    final lastSync = _lastOnlineSyncAt;
    final now = clock.now();
    final expiresAt = state.entitlement?.expiresAt;
    final crossedExpiry =
        state.status == EntitlementStatus.premium &&
        expiresAt != null &&
        !expiresAt.isAfter(now);
    final needsRefresh =
        state.status == EntitlementStatus.unknown ||
        state.isStale ||
        lastSync == null ||
        now.difference(lastSync) > maxAge ||
        crossedExpiry;
    if (!needsRefresh) {
      AppLogger.log(
        'Subscription',
        'resume 权益刷新跳过：距上次在线确认 '
            '${now.difference(lastSync).inSeconds}s（<${maxAge.inSeconds}s）',
      );
      return;
    }
    await refresh();
  }

  /// E6：后端权益信号与本地 state 分歧时回源对账。
  ///
  /// 信号来自 backend Dio 拦截器读到的 `x-entitlement-active` 响应头。
  /// 跳过 /api/entitlements 自身（其响应体即权威，正常对账流程会落定）；
  /// unknown 中间态不比对；in-flight 标记去重并发信号。
  void _onServerEntitlementSignal({
    required bool serverActive,
    required String path,
  }) {
    if (path.contains('/api/entitlements')) return;
    if (state.status == EntitlementStatus.unknown) return;
    if (serverActive == state.isActive) return;
    if (_signalRefreshInFlight) return;
    AppLogger.log(
      'Subscription',
      '后端权益信号与本地分歧: server=$serverActive local=${state.isActive} '
          'path=$path，触发对账',
    );
    _signalRefreshInFlight = true;
    unawaited(refresh().whenComplete(() => _signalRefreshInFlight = false));
  }

  /// E7：后端按权威权益拒绝请求（402 配额超限）而本地仍 premium 时的收敛入口。
  ///
  /// 分歧说明本地权益已过时（退款/到期未同步到客户端），立即回源对账拉平；
  /// 本地非 premium 时属免费额度用尽的正常路径，不动作。
  /// 后端配额裁决读实时库，普通 refresh 即可取到权威结果，无需 force。
  void reconcileOnServerQuotaRejection(String context) {
    if (!state.isActive) return;
    AppLogger.log(
      'Subscription',
      '后端配额拒绝与本地 premium 分歧，触发权益对账: context=$context',
    );
    unawaited(refresh());
  }

  /// 成交后回源收敛：force 绕过后端节流读取 RC 最新权益。
  /// 短重试兜住瞬时网络失败（每次都完整走 refresh 的 generation 防竞态）；
  /// 重试后仍未 active 只记日志——钱已成交，权益由后续触发点（RC 流 / 到期
  /// timer / resume）自然收敛，UI 据 state 提示「同步中」，绝不报「购买失败」。
  Future<void> _convergeAfterTransaction(String reason) async {
    const maxAttempts = 3;
    const interval = Duration(seconds: 2);
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await refresh(force: true);
      if (state.isActive) {
        AppLogger.log(
          'Subscription',
          '成交收敛完成: reason=$reason attempt=$attempt',
        );
        return;
      }
      if (attempt < maxAttempts) await Future<void>.delayed(interval);
    }
    AppLogger.log(
      'Subscription',
      '成交收敛未确认（等待后续触发点）: reason=$reason status=${state.status.name}',
    );
  }

  /// 外部 checkout 回跳后的权益收敛；回跳本身不是支付凭证。
  Future<void> refreshAfterExternalCheckout() {
    return _convergeAfterTransaction('external-checkout');
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
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      'Subscription',
      'identity_sync_start previousUserId=${previous?.userId ?? "none"} '
          'nextUserId=${next.userId ?? "none"} '
          'hasToken=${next.accessToken != null}',
    );
    try {
      await _syncIdentity(previous, next);
    } finally {
      AppLogger.log(
        'Subscription',
        'identity_sync_end nextUserId=${next.userId ?? "none"} '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  /// 执行既有身份绑定和权益对账流程；外层仅负责记录完整耗时。
  Future<void> _syncIdentity(
    SubscriptionIdentity? previous,
    SubscriptionIdentity next,
  ) async {
    if (!next.isResolved) {
      AppLogger.log(
        'Subscription',
        'identity_sync_pending 等待 Supabase initialSession',
      );
      return;
    }
    final isInitialIdentity = previous == null;
    final previousUserId = previous?.userId;
    final previousResolved = previous?.isResolved ?? false;
    final nextUserId = next.userId;
    if (!isInitialIdentity && previousUserId == nextUserId) {
      if (previous.accessToken != next.accessToken &&
          (state.status == EntitlementStatus.unknown || state.isStale)) {
        Future.microtask(() => refreshIfStale());
      }
      return;
    }

    _generation++; // 作废在途对账。
    if (nextUserId == null) {
      if (isInitialIdentity || !previousResolved) {
        // 只有明确收到匿名结果才对账；pending → anonymous 也属于首次解析。
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

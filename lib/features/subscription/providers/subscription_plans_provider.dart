/// 可购买套餐的会话缓存与刷新控制器。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_logger.dart';
import '../models/subscription_plan.dart';
import '../services/paddle_billing_repository.dart';
import '../services/purchase_service.dart';
import '../services/revenuecat_purchase_service.dart';

/// 同一 storefront 下套餐自动刷新的最长期限。
const subscriptionPlansRefreshInterval = Duration(days: 1);

/// 原生商店套餐一次刷新允许占用的最长时间。
const subscriptionPlansRequestTimeout = Duration(seconds: 15);

/// 套餐刷新超时配置注入点，测试可缩短等待时间。
final subscriptionPlansTimeoutProvider = Provider<Duration>((ref) {
  return subscriptionPlansRequestTimeout;
});

/// 当前时间注入点，便于稳定验证缓存过期行为。
final subscriptionPlansNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// 当前可购买套餐。
///
/// Provider 在本次进程内保留最后成功结果，刷新由页面显式触发。
final subscriptionPlansProvider =
    NotifierProvider<
      SubscriptionPlansController,
      AsyncValue<List<SubscriptionPlan>>
    >(SubscriptionPlansController.new);

/// Paddle Web 支付套餐。
///
/// 商店包 Web 支付兜底不能复用 App Store / Google Play 的本地价格，否则页面展示价
/// 会和实际 Web checkout 价格不一致。这里独立读取 Paddle plans，供 Paywall 在用户
/// 主动切换到 Web 支付时展示。
final paddleSubscriptionPlansProvider =
    NotifierProvider<
      PaddleSubscriptionPlansController,
      AsyncValue<List<SubscriptionPlan>>
    >(PaddleSubscriptionPlansController.new);

class PaddleSubscriptionPlansController
    extends Notifier<AsyncValue<List<SubscriptionPlan>>> {
  int _generation = 0;
  Future<void> _settled = Future<void>.value();

  /// 当前预热或刷新链路完成时兑现，主要供测试和启动编排观察。
  Future<void> get settled => _settled;

  @override
  AsyncValue<List<SubscriptionPlan>> build() => const AsyncLoading();

  Future<void> refresh({bool force = false}) {
    final operation = _refresh(force: force);
    _settled = operation;
    return operation;
  }

  /// 先发布可用缓存，再执行网络刷新；只有没有任何可展示价格时才进入 loading。
  Future<void> _refresh({required bool force}) async {
    final generation = ++_generation;
    final previousPlans = state.value;
    final repository = ref.read(paddleBillingRepositoryProvider);
    var hasDisplayablePlans = previousPlans != null;
    AppLogger.log(
      'Subscription',
      'Paddle plans 刷新开始: generation=$generation force=$force',
    );

    try {
      if (!hasDisplayablePlans) {
        final cachedPlans = await repository.loadCachedPlans();
        if (generation != _generation) {
          AppLogger.log(
            'Subscription',
            'Paddle plans 缓存加载丢弃: generation=$generation '
                'reason=outdated',
          );
          return;
        }
        if (cachedPlans != null) {
          state = AsyncData(cachedPlans);
          hasDisplayablePlans = true;
          AppLogger.log(
            'Subscription',
            'Paddle plans 缓存已发布: generation=$generation '
                'count=${cachedPlans.length}',
          );
        }
      }

      if (!hasDisplayablePlans) state = const AsyncLoading();

      final plans = await repository.fetchPlans(force: force);
      if (generation != _generation) {
        AppLogger.log(
          'Subscription',
          'Paddle plans 刷新结果丢弃: generation=$generation reason=outdated',
        );
        return;
      }
      state = AsyncData(plans);
      AppLogger.log(
        'Subscription',
        'Paddle plans 刷新成功: generation=$generation count=${plans.length} '
            'ids=${plans.map((p) => p.planId).toList()}',
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      final retainedPlans = state.value ?? previousPlans;
      if (retainedPlans != null) {
        state = AsyncData(retainedPlans);
        AppLogger.log('Subscription', 'Paddle plans 后台刷新失败，保留已有价格: $error');
        AppLogger.log('Subscription', stackTrace.toString());
      } else {
        state = AsyncError(error, stackTrace);
        AppLogger.log(
          'Subscription',
          'Paddle plans 刷新失败，进入错误态: generation=$generation error=$error',
        );
      }
    }
  }
}

class SubscriptionPlansController
    extends Notifier<AsyncValue<List<SubscriptionPlan>>> {
  DateTime? _lastSuccessAt;
  String? _lastStorefront;
  int _generation = 0;
  Future<void> _settled = Future<void>.value();

  /// 当前预热或刷新链路完成时兑现，主要供测试和启动编排观察。
  Future<void> get settled => _settled;

  @override
  AsyncValue<List<SubscriptionPlan>> build() {
    _settled = Future<void>.microtask(() => _refresh(force: false));
    return const AsyncLoading();
  }

  /// 启动预热入口；已有五分钟内的新鲜结果时不重复查询。
  Future<void> prefetch() => refreshIfStale();

  /// App 回前台时检查 storefront，并按 TTL 刷新套餐。
  Future<void> refreshIfStale() => refresh();

  /// 刷新套餐。
  ///
  /// [force] 用于 paywall 可见时主动读取 SDK；SDK 自身仍可命中内部缓存。
  Future<void> refresh({bool force = false}) {
    final operation = _refresh(force: force);
    _settled = operation;
    return operation;
  }

  Future<void> _refresh({required bool force}) async {
    // generation 必须在任何 await 前创建，保证后发请求始终拥有提交权。
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();
    AppLogger.log(
      'Subscription',
      '套餐刷新开始: generation=$generation force=$force',
    );
    final service = ref.read(purchaseServiceProvider);
    final timeout = ref.read(subscriptionPlansTimeoutProvider);
    final previousPlans = state.value;
    late final String? storefront;
    try {
      storefront = await _readStorefront(
        service,
        remaining: _remaining(timeout, stopwatch),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return;
      if (previousPlans != null) {
        state = AsyncData(previousPlans);
        AppLogger.log('Subscription', '套餐 storefront 刷新失败，保留会话缓存: $error');
      } else {
        state = AsyncError(error, stackTrace);
        AppLogger.log(
          'Subscription',
          '套餐 storefront 刷新失败，进入错误态: generation=$generation error=$error',
        );
      }
      return;
    }
    if (!_isCurrent(generation)) {
      AppLogger.log(
        'Subscription',
        '套餐刷新丢弃: generation=$generation reason=storefrontOutdated',
      );
      return;
    }
    final storefrontChanged =
        _lastStorefront != null &&
        storefront != null &&
        _lastStorefront != storefront;
    final lastSuccessAt = _lastSuccessAt;
    final isFresh =
        lastSuccessAt != null &&
        ref.read(subscriptionPlansNowProvider)().difference(lastSuccessAt) <
            subscriptionPlansRefreshInterval;

    if (!force && !storefrontChanged && isFresh) {
      AppLogger.log(
        'Subscription',
        '套餐刷新跳过: generation=$generation reason=freshCache '
            'storefront=${storefront ?? "unknown"}',
      );
      return;
    }

    if (storefrontChanged || previousPlans == null) {
      state = const AsyncLoading();
    }
    AppLogger.log(
      'Subscription',
      '套餐刷新执行: generation=$generation storefront=${storefront ?? "unknown"} '
          'storefrontChanged=$storefrontChanged '
          'previousCount=${previousPlans?.length ?? 0}',
    );

    try {
      // 先提交不依赖 iOS 促销资格查询的基础价格，缩短首次可见时间。
      final fastPlans = await service
          .fetchPlans(includeIntroEligibility: false, force: force)
          .timeout(_remaining(timeout, stopwatch));
      if (!_isCurrent(generation)) {
        AppLogger.log(
          'Subscription',
          '套餐基础价格丢弃: generation=$generation reason=outdated',
        );
        return;
      }
      final storefrontAfterFetch = await _readStorefront(
        service,
        remaining: _remaining(timeout, stopwatch),
      );
      if (!_isCurrent(generation)) {
        AppLogger.log(
          'Subscription',
          '套餐基础价格丢弃: generation=$generation '
              'reason=storefrontAfterFetchOutdated',
        );
        return;
      }
      if (storefront != null &&
          storefrontAfterFetch != null &&
          storefront != storefrontAfterFetch) {
        // StoreKit 在查询期间完成了跨区切换，当前返回值可能属于旧 storefront。
        AppLogger.log(
          'Subscription',
          '套餐刷新检测到 storefront 切换: before=$storefront '
              'after=$storefrontAfterFetch generation=$generation',
        );
        state = const AsyncLoading();
        await refresh(force: true);
        return;
      }
      state = AsyncData(fastPlans);
      _lastStorefront = storefrontAfterFetch ?? storefront ?? _lastStorefront;
      _lastSuccessAt = ref.read(subscriptionPlansNowProvider)();
      AppLogger.log(
        'Subscription',
        '套餐基础价格刷新成功: generation=$generation count=${fastPlans.length} '
            'ids=${fastPlans.map((p) => p.planId).toList()}',
      );

      // 再从 SDK 缓存补全促销资格；失败时继续保留已可用的基础价格。
      try {
        final completePlans = await service.fetchPlans().timeout(
          _remaining(timeout, stopwatch),
        );
        if (!_isCurrent(generation)) {
          AppLogger.log(
            'Subscription',
            '套餐完整价格丢弃: generation=$generation reason=outdated',
          );
          return;
        }
        state = AsyncData(completePlans);
        _lastSuccessAt = ref.read(subscriptionPlansNowProvider)();
        AppLogger.log(
          'Subscription',
          '套餐完整价格刷新成功: generation=$generation '
              'count=${completePlans.length} '
              'ids=${completePlans.map((p) => p.planId).toList()}',
        );
      } catch (error, stackTrace) {
        AppLogger.log('Subscription', '套餐促销资格刷新失败，保留基础价格: $error');
        AppLogger.log('Subscription', '$stackTrace');
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) {
        AppLogger.log(
          'Subscription',
          '套餐刷新失败但已过期: generation=$generation error=$error',
        );
        return;
      }
      if (!storefrontChanged && previousPlans != null) {
        state = AsyncData(previousPlans);
        AppLogger.log('Subscription', '套餐刷新失败，保留会话缓存: $error');
      } else {
        state = AsyncError(error, stackTrace);
        AppLogger.log(
          'Subscription',
          '套餐刷新失败，进入错误态: generation=$generation error=$error',
        );
      }
    }
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<String?> _readStorefront(
    PurchaseService service, {
    required Duration remaining,
  }) async {
    try {
      return await service.storefrontCountryCode().timeout(remaining);
    } on TimeoutException {
      AppLogger.log(
        'Subscription',
        'storefront 获取超时: timeout=${remaining.inMilliseconds}ms',
      );
      rethrow;
    } catch (error) {
      AppLogger.log('Subscription', 'storefront 获取失败，沿用已有套餐区域: $error');
      return null;
    }
  }

  Duration _remaining(Duration timeout, Stopwatch stopwatch) {
    final remainingMs = timeout.inMilliseconds - stopwatch.elapsedMilliseconds;
    return Duration(milliseconds: math.max(1, remainingMs));
  }
}

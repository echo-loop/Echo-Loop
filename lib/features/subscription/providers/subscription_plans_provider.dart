/// 可购买套餐的会话缓存与刷新控制器。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_logger.dart';
import '../models/subscription_plan.dart';
import '../services/purchase_service.dart';
import '../services/revenuecat_purchase_service.dart';

/// 同一 storefront 下套餐自动刷新的最长期限。
const subscriptionPlansRefreshInterval = Duration(minutes: 5);

/// 当前时间注入点，便于稳定验证缓存过期行为。
final subscriptionPlansNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// 当前可购买套餐。
///
/// Provider 在首次读取时立即预热，并在本次进程内保留最后成功结果。普通刷新采用
/// stale-while-revalidate；确认 storefront 变化后则撤下旧价格，避免展示错误币种。
final subscriptionPlansProvider =
    NotifierProvider<
      SubscriptionPlansController,
      AsyncValue<List<SubscriptionPlan>>
    >(SubscriptionPlansController.new);

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
    _settled = Future<void>.microtask(() => _refresh(force: true));
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
    final service = ref.read(purchaseServiceProvider);
    final storefront = await _readStorefront(service);
    if (!_isCurrent(generation)) return;
    final storefrontChanged =
        _lastStorefront != null &&
        storefront != null &&
        _lastStorefront != storefront;
    final lastSuccessAt = _lastSuccessAt;
    final isFresh =
        lastSuccessAt != null &&
        ref.read(subscriptionPlansNowProvider)().difference(lastSuccessAt) <
            subscriptionPlansRefreshInterval;

    if (!force && !storefrontChanged && isFresh) return;

    final previousPlans = state.valueOrNull;
    if (storefrontChanged || previousPlans == null) {
      state = const AsyncLoading();
    }

    try {
      // 先提交不依赖 iOS 促销资格查询的基础价格，缩短首次可见时间。
      final fastPlans = await service.fetchPlans(
        includeIntroEligibility: false,
      );
      if (!_isCurrent(generation)) return;
      final storefrontAfterFetch = await _readStorefront(service);
      if (!_isCurrent(generation)) return;
      if (storefront != null &&
          storefrontAfterFetch != null &&
          storefront != storefrontAfterFetch) {
        // StoreKit 在查询期间完成了跨区切换，当前返回值可能属于旧 storefront。
        state = const AsyncLoading();
        await refresh(force: true);
        return;
      }
      state = AsyncData(fastPlans);
      _lastStorefront = storefrontAfterFetch ?? storefront ?? _lastStorefront;
      _lastSuccessAt = ref.read(subscriptionPlansNowProvider)();

      // 再从 SDK 缓存补全促销资格；失败时继续保留已可用的基础价格。
      try {
        final completePlans = await service.fetchPlans();
        if (!_isCurrent(generation)) return;
        state = AsyncData(completePlans);
        _lastSuccessAt = ref.read(subscriptionPlansNowProvider)();
      } catch (error, stackTrace) {
        AppLogger.log('Subscription', '套餐促销资格刷新失败，保留基础价格: $error');
        AppLogger.log('Subscription', '$stackTrace');
      }
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return;
      if (!storefrontChanged && previousPlans != null) {
        state = AsyncData(previousPlans);
        AppLogger.log('Subscription', '套餐刷新失败，保留会话缓存: $error');
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<String?> _readStorefront(PurchaseService service) async {
    try {
      return await service.storefrontCountryCode();
    } catch (error) {
      AppLogger.log('Subscription', 'storefront 获取失败，沿用已有套餐区域: $error');
      return null;
    }
  }
}

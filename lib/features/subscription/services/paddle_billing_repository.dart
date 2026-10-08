/// Paddle direct 渠道的后端 API client。
library;

import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../config/api_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../providers/package_info_provider.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../../services/app_logger.dart';
import '../../../services/supabase_token_coordinator.dart';
import '../models/subscription_plan.dart';
import 'purchase_service.dart';
import '../utils/plan_pricing.dart';
import 'paddle_plans_service.dart';

const _uuid = Uuid();

/// 一次 Paddle checkout 的服务端结果。
class PaddleCheckoutSession {
  const PaddleCheckoutSession({
    required this.attemptId,
    required this.checkoutUrl,
  });

  final String attemptId;
  final Uri checkoutUrl;
}

/// Paddle 后端 API 访问层；不负责登录状态或 UI 编排。
class PaddleBillingRepository {
  PaddleBillingRepository({
    required String baseUrl,
    String? appVersion,
    SupabaseTokenCoordinator? tokenCoordinator,
    RuntimeEndpointRouter? endpointRouter,
  }) : _authenticatedDio = createAuthenticatedBackendDio(
         tokenCoordinator: tokenCoordinator,
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         connectTimeout: const Duration(seconds: 15),
         receiveTimeout: const Duration(seconds: 30),
         apiLogTag: 'PADDLE',
       ),
       _plans = PaddlePlansService(
         dio: createBackendDio(
           baseUrl: baseUrl,
           endpointRouter: endpointRouter,
           appVersion: appVersion,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 30),
           apiLogTag: 'PADDLE-PLANS',
         ),
       );

  @visibleForTesting
  PaddleBillingRepository.withDio(Dio dio)
    : _authenticatedDio = dio,
      _plans = PaddlePlansService(dio: dio, persist: false);

  /// 为缓存与刷新链路测试注入真实套餐服务，避免测试绕过持久化行为。
  @visibleForTesting
  PaddleBillingRepository.withPlans({
    required Dio authenticatedDio,
    required PaddlePlansService plans,
  }) : _authenticatedDio = authenticatedDio,
       _plans = plans;

  final Dio _authenticatedDio;
  final PaddlePlansService _plans;

  /// 只读取本地 Paddle 套餐缓存，不触发网络请求。
  Future<List<SubscriptionPlan>?> loadCachedPlans() async {
    final data = await _plans.loadCachedPlans();
    if (data == null) return null;

    try {
      return _plansFrom(data);
    } catch (error, stackTrace) {
      AppLogger.log('Subscription', 'Paddle plans 缓存映射失败，丢弃缓存: $error');
      AppLogger.log('Subscription', stackTrace.toString());
      _plans.discardCachedPlans();
      return null;
    }
  }

  /// 刷新服务端 Paddle 套餐；地区化价格由后端按请求来源判定。
  Future<List<SubscriptionPlan>> fetchPlans({bool force = false}) async {
    await _plans.refresh(force: force);
    final data = _plans.cached;
    if (data == null) {
      throw StateError('Paddle plans unavailable');
    }
    return _plansFrom(data);
  }

  List<SubscriptionPlan> _plansFrom(Map<String, dynamic> data) {
    final rawPlans = data['plans'];
    if (rawPlans is! List) {
      throw StateError('Paddle plans response is invalid');
    }
    final subscriptionPlans = rawPlans
        .whereType<Map>()
        .map((raw) => _planFrom(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
    final oneTimePlans = _oneTimePlansFrom(data['oneTimePlans']);
    final plans = [...subscriptionPlans, ...oneTimePlans];
    AppLogger.log(
      'Subscription',
      'Paddle plans 映射完成: subscriptionCount=${subscriptionPlans.length} '
          'oneTimeCount=${oneTimePlans.length} '
          'ids=${plans.map((p) => p.planId).toList()}',
    );
    return plans;
  }

  /// 创建服务端 Paddle transaction；客户端不能提交 discount 或 redirect URL。
  Future<PaddleCheckoutSession> createCheckout({
    required String accessToken,
    required String planId,
  }) async {
    final locale = _localeTag();
    final idempotencyKey = _uuid.v4();
    AppLogger.log(
      'Subscription',
      'Paddle checkout 请求开始: planId=$planId locale=$locale '
          'hasIdempotencyKey=true',
    );
    try {
      final response = await _authenticatedDio.post<Map<String, dynamic>>(
        '/api/paddle/hosted-checkout',
        data: {'planId': planId, 'locale': locale},
        options: authRetryOnceOptions(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Idempotency-Key': idempotencyKey,
          },
        ),
      );
      final data = response.data;
      final attemptId = data?['attemptId'];
      final checkoutUrl = data?['checkoutUrl'];
      if (attemptId is! String || checkoutUrl is! String) {
        AppLogger.log(
          'Subscription',
          'Paddle checkout 响应无效: status=${response.statusCode} '
              'keys=${data?.keys.toList() ?? const []}',
        );
        throw StateError('Paddle checkout response is invalid');
      }
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        AppLogger.log(
          'Subscription',
          'Paddle checkout URL 无效: attemptId=$attemptId url=$checkoutUrl',
        );
        throw StateError('Paddle checkout URL is invalid');
      }
      AppLogger.log(
        'Subscription',
        'Paddle checkout 请求成功: status=${response.statusCode} '
            'attemptId=$attemptId host=${uri.host} path=${uri.path}',
      );
      return PaddleCheckoutSession(attemptId: attemptId, checkoutUrl: uri);
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map<String, dynamic> ? data['code'] : null;
      if (error.response?.statusCode == 409 && code == 'already_entitled') {
        AppLogger.log(
          'Subscription',
          'Paddle checkout 已有权益: planId=$planId '
              'requestId=${data is Map<String, dynamic> ? data['requestId'] : null}',
        );
        throw PurchaseException(
          'User already has an active entitlement',
          alreadyEntitled: true,
        );
      }
      AppLogger.log(
        'Subscription',
        'Paddle checkout 请求失败: planId=$planId '
            'http=${error.response?.statusCode ?? "none"}',
      );
      rethrow;
    } catch (error) {
      AppLogger.log(
        'Subscription',
        'Paddle checkout 请求失败: planId=$planId type=${error.runtimeType}',
      );
      rethrow;
    }
  }

  /// 创建短期 Customer Portal session，返回服务端生成的 overview URL。
  Future<Uri> createPortal({required String accessToken}) async {
    AppLogger.log('Subscription', 'Paddle Portal 请求开始');
    try {
      final response = await _authenticatedDio.post<Map<String, dynamic>>(
        '/api/paddle/portal',
        options: authRetryOnceOptions(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      final data = response.data;
      final raw = data?['portalUrl'];
      if (raw is! String) {
        AppLogger.log(
          'Subscription',
          'Paddle Portal 响应无效: status=${response.statusCode} '
              'keys=${data?.keys.toList() ?? const []}',
        );
        throw StateError('Paddle portal response is invalid');
      }
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        AppLogger.log('Subscription', 'Paddle Portal URL 无效: url=$raw');
        throw StateError('Paddle portal URL is invalid');
      }
      AppLogger.log(
        'Subscription',
        'Paddle Portal 请求成功: status=${response.statusCode} '
            'host=${uri.host} path=${uri.path}',
      );
      return uri;
    } catch (error) {
      AppLogger.log('Subscription', 'Paddle Portal 请求失败: error=$error');
      rethrow;
    }
  }

  SubscriptionPlan _planFrom(Map<String, dynamic> json) {
    final planId = json['planId'];
    final priceString = json['priceString'];
    if (planId is! String || priceString is! String) {
      throw StateError('Paddle plan fields are invalid');
    }
    final period = switch (planId) {
      'plus_monthly' => SubscriptionPeriod.monthly,
      'plus_yearly' => SubscriptionPeriod.yearly,
      _ => throw StateError('Unsupported Paddle plan id: $planId'),
    };
    final offer = json['introOffer'];
    return SubscriptionPlan(
      planId: planId,
      title: _titleForPeriod(period),
      priceString: priceString,
      period: period,
      hasFreeTrial: json['hasFreeTrial'] == true,
      trialDays: _intValue(json['trialDays'], fallback: 0),
      introOffer: offer is Map
          ? _introOfferFrom(Map<String, dynamic>.from(offer))
          : null,
    );
  }

  /// 独立解析附加的一次性套餐；单项异常不能拖垮现有订阅目录。
  List<SubscriptionPlan> _oneTimePlansFrom(Object? value) {
    if (value is! List) return const [];
    final plans = <SubscriptionPlan>[];
    for (final raw in value.whereType<Map>()) {
      try {
        plans.add(_oneTimePlanFrom(Map<String, dynamic>.from(raw)));
      } catch (error) {
        AppLogger.log('Subscription', '忽略无效 Paddle 一次性套餐: $error');
      }
    }
    return plans;
  }

  /// 映射当前唯一的一年期一次性套餐，并严格校验不会自动续费。
  SubscriptionPlan _oneTimePlanFrom(Map<String, dynamic> json) {
    final planId = json['planId'];
    final priceString = json['priceString'];
    final duration = json['duration'];
    if (planId != 'plus_yearly_one_time' ||
        priceString is! String ||
        json['purchaseType'] != 'one_time' ||
        json['accessType'] != 'fixed_term' ||
        json['autoRenew'] != false ||
        duration is! Map ||
        duration['unit'] != 'year' ||
        duration['count'] != 1) {
      throw StateError('Paddle one-time plan fields are invalid');
    }
    return SubscriptionPlan(
      planId: planId,
      title: 'Yearly one-time',
      priceString: priceString,
      period: SubscriptionPeriod.yearly,
      purchaseType: PurchaseType.oneTime,
    );
  }

  SubscriptionIntroOffer _introOfferFrom(Map<String, dynamic> json) {
    final discountType = json['discountType'];
    final discountPercent = json['discountPercent'];
    final renewalPriceString = json['renewalPriceString'];
    if (discountType != 'percentage' ||
        discountPercent is! num ||
        renewalPriceString is! String) {
      throw StateError('Paddle intro offer fields are invalid');
    }
    final priceString = discountedPriceString(
      renewalPriceString,
      discountPercent,
    );
    if (priceString == null) {
      throw StateError('Paddle intro offer discount is invalid');
    }
    final period = switch (json['period']) {
      'day' => SubscriptionOfferPeriod.day,
      'week' => SubscriptionOfferPeriod.week,
      'month' => SubscriptionOfferPeriod.month,
      'year' => SubscriptionOfferPeriod.year,
      _ => SubscriptionOfferPeriod.unknown,
    };
    return SubscriptionIntroOffer(
      priceString: priceString,
      period: period,
      periodNumberOfUnits: _intValue(json['periodNumberOfUnits'], fallback: 1),
      cycles: _intValue(json['cycles'], fallback: 1),
      isFreeTrial: json['isFreeTrial'] == true,
      renewalPriceString: renewalPriceString,
    );
  }

  String _titleForPeriod(SubscriptionPeriod period) => switch (period) {
    SubscriptionPeriod.monthly => 'Monthly',
    SubscriptionPeriod.yearly => 'Yearly',
    SubscriptionPeriod.lifetime => 'Lifetime',
  };

  String _localeTag() => ui.PlatformDispatcher.instance.locale.toLanguageTag();

  int _intValue(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : fallback;
}

final paddleBillingRepositoryProvider = Provider<PaddleBillingRepository>((
  ref,
) {
  return PaddleBillingRepository(
    baseUrl: apiBaseUrl,
    endpointRouter: runtimeEndpointRouter,
    appVersion: readAppVersion(ref),
    tokenCoordinator: ref.read(supabaseTokenCoordinatorProvider),
  );
});

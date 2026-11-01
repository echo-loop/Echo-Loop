import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/services/paddle_billing_repository.dart';
import 'package:echo_loop/features/subscription/services/paddle_plans_service.dart';
import 'package:echo_loop/features/subscription/services/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late PaddleBillingRepository repository;

  setUp(() {
    dio = _MockDio();
    repository = PaddleBillingRepository.withDio(dio);
  });

  test('loadCachedPlans 只读取缓存，不触发网络请求', () async {
    expect(await repository.loadCachedPlans(), isNull);
    verifyNever(() => dio.get<Map<String, dynamic>>('/api/paddle/plans'));
  });

  test('缓存价格在 Paddle 刷新失败时仍可用于展示', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'paddle_billing_repository_test_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final data = <String, dynamic>{
      'plans': [
        {
          'planId': 'plus_monthly',
          'priceString': r'US$8.99',
          'hasFreeTrial': false,
          'trialDays': 0,
          'introOffer': null,
        },
      ],
    };
    final body = jsonEncode(data);
    await File('${tempDir.path}/plans.json').writeAsString(body);
    await File('${tempDir.path}/plans.meta.json').writeAsString(
      jsonEncode({
        'contentHash': sha256.convert(utf8.encode(body)).toString(),
        'lastFetchedAt': '2026-09-16T00:00:00.000Z',
      }),
    );
    when(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        type: DioExceptionType.connectionError,
      ),
    );
    repository = PaddleBillingRepository.withPlans(
      authenticatedDio: dio,
      plans: PaddlePlansService(dio: dio, resolveDir: () async => tempDir),
    );

    final plans = await repository.fetchPlans(force: true);

    expect(plans.single.planId, 'plus_monthly');
    expect(plans.single.priceString, r'US$8.99');
    verify(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).called(1);
  });

  test('fetchPlans 映射月付、年付和首年优惠', () async {
    when(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        statusCode: 200,
        data: {
          'plans': [
            {
              'planId': 'plus_monthly',
              'priceString': r'US$8.99',
              'period': 'monthly',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': {
                'discountType': 'percentage',
                'discountPercent': 20,
                'period': 'month',
                'periodNumberOfUnits': 1,
                'cycles': 1,
                'isFreeTrial': false,
                'renewalPriceString': r'US$8.99',
              },
            },
            {
              'planId': 'plus_yearly',
              'priceString': r'US$50.00',
              'period': 'yearly',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': {
                'discountType': 'percentage',
                'discountPercent': 50,
                'period': 'year',
                'periodNumberOfUnits': 1,
                'cycles': 1,
                'isFreeTrial': false,
                'renewalPriceString': r'US$50.00',
              },
            },
          ],
        },
      ),
    );

    final plans = await repository.fetchPlans();

    expect(plans, hasLength(2));
    expect(plans.first.period, SubscriptionPeriod.monthly);
    expect(plans.first.title, 'Monthly');
    expect(plans.first.introOffer?.priceString, r'US$7.19');
    expect(plans.first.introOffer?.period, SubscriptionOfferPeriod.month);
    expect(plans.first.introOffer?.renewalPriceString, r'US$8.99');
    expect(plans.last.period, SubscriptionPeriod.yearly);
    expect(plans.last.title, 'Yearly');
    expect(plans.last.introOffer?.priceString, r'US$25.00');
    expect(plans.last.introOffer?.renewalPriceString, r'US$50.00');
    verify(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).called(1);
  });

  test('fetchPlans 映射 Paddle price 自带免费试用', () async {
    when(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        statusCode: 200,
        data: {
          'plans': [
            {
              'planId': 'plus_yearly',
              'priceString': r'£47.99',
              'period': 'yearly',
              'hasFreeTrial': true,
              'trialDays': 7,
              'introOffer': null,
            },
          ],
        },
      ),
    );

    final plans = await repository.fetchPlans();

    expect(plans.single.hasFreeTrial, isTrue);
    expect(plans.single.trialDays, 7);
    expect(plans.single.introOffer, isNull);
  });

  test('fetchPlans 合并一次性年付，并隔离无效一次性套餐', () async {
    when(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        statusCode: 200,
        data: {
          'plans': [
            {
              'planId': 'plus_yearly',
              'priceString': r'US$50.00',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': null,
            },
          ],
          'oneTimePlans': [
            {
              'planId': 'plus_yearly_one_time',
              'priceString': 'CN¥298.00',
              'purchaseType': 'one_time',
              'accessType': 'fixed_term',
              'duration': {'unit': 'year', 'count': 1},
              'autoRenew': false,
            },
            {'planId': 'unsupported_one_time', 'priceString': 'CN¥1.00'},
          ],
        },
      ),
    );

    final plans = await repository.fetchPlans();

    expect(plans, hasLength(2));
    expect(plans.first.purchaseType, PurchaseType.subscription);
    expect(plans.last.planId, 'plus_yearly_one_time');
    expect(plans.last.period, SubscriptionPeriod.yearly);
    expect(plans.last.purchaseType, PurchaseType.oneTime);
    expect(plans.last.hasFreeTrial, isFalse);
    expect(plans.last.introOffer, isNull);
  });

  test('fetchPlans 兼容旧后端缺少 oneTimePlans', () async {
    when(() => dio.get<Map<String, dynamic>>('/api/paddle/plans')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/plans'),
        statusCode: 200,
        data: {
          'plans': [
            {
              'planId': 'plus_monthly',
              'priceString': r'US$8.99',
              'hasFreeTrial': false,
              'trialDays': 0,
              'introOffer': null,
            },
          ],
        },
      ),
    );

    final plans = await repository.fetchPlans();

    expect(plans.single.planId, 'plus_monthly');
    expect(plans.single.purchaseType, PurchaseType.subscription);
  });

  test('createCheckout 请求 Hosted Checkout 并携带 Bearer 与 UUID 幂等键', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/hosted-checkout',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/hosted-checkout'),
        statusCode: 200,
        data: {
          'attemptId': 'attempt-1',
          'checkoutUrl':
              'https://sandbox-pay.paddle.io/hsc_test?transaction_id=txn_1',
        },
      ),
    );

    final session = await repository.createCheckout(
      accessToken: 'token',
      planId: 'plus_yearly',
    );

    expect(session.attemptId, 'attempt-1');
    expect(session.checkoutUrl.host, 'sandbox-pay.paddle.io');
    expect(session.checkoutUrl.path, '/hsc_test');
    expect(session.checkoutUrl.queryParameters['transaction_id'], 'txn_1');
    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/hosted-checkout',
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    final data = Map<String, dynamic>.from(captured[0] as Map);
    final options = captured[1] as Options;
    expect(data.keys, containsAll(<String>['planId', 'locale']));
    expect(data, isNot(contains('discountId')));
    expect(options.headers?['Authorization'], 'Bearer token');
    expect(
      options.headers?['Idempotency-Key'],
      matches(RegExp(r'^[0-9a-f-]{36}$')),
    );
  });

  test('createPortal 返回服务端短期 overview URL', () async {
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

    final uri = await repository.createPortal(accessToken: 'token');

    expect(uri.host, 'customer-portal.paddle.test');
  });

  test('checkout 非 HTTPS URL fail closed', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/hosted-checkout',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/paddle/hosted-checkout'),
        statusCode: 200,
        data: {'attemptId': 'attempt-1', 'checkoutUrl': 'http://unsafe.test'},
      ),
    );

    expect(
      repository.createCheckout(accessToken: 'token', planId: 'plus_yearly'),
      throwsStateError,
    );
  });

  test('409 already_entitled 映射为类型化 PurchaseException', () async {
    when(
      () => dio.post<Map<String, dynamic>>(
        '/api/paddle/hosted-checkout',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException.badResponse(
        statusCode: 409,
        requestOptions: RequestOptions(path: '/api/paddle/hosted-checkout'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/paddle/hosted-checkout'),
          statusCode: 409,
          data: {'code': 'already_entitled', 'requestId': 'request-1'},
        ),
      ),
    );

    await expectLater(
      repository.createCheckout(accessToken: 'token', planId: 'plus_yearly'),
      throwsA(
        isA<PurchaseException>().having(
          (error) => error.alreadyEntitled,
          'alreadyEntitled',
          isTrue,
        ),
      ),
    );
  });
}

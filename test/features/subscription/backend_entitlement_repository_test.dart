import 'package:dio/dio.dart';
import 'package:echo_loop/features/subscription/models/entitlement.dart';
import 'package:echo_loop/features/subscription/models/entitlement_source.dart';
import 'package:echo_loop/features/subscription/models/subscription_plan.dart';
import 'package:echo_loop/features/subscription/services/entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// [BackendEntitlementRepository] 单测：验证 `GET /api/entitlements` 响应到
/// [Entitlement] 的映射，以及「获取失败一律返回 null（不误判为无权益）」的契约。
void main() {
  late _MockDio dio;
  late BackendEntitlementRepository repo;

  Response<Map<String, dynamic>> resp(Map<String, dynamic> data) => Response(
    requestOptions: RequestOptions(path: '/api/entitlements'),
    statusCode: 200,
    data: data,
  );

  setUp(() {
    dio = _MockDio();
    repo = BackendEntitlementRepository.withDio(dio);
  });

  test('isPremium=true：映射周期/到期/权益集合', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_plus_annual',
        'expiresAtMs': 1750000000000,
        'willRenew': true,
        'source': 'paddle',
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e, isNotNull);
    expect(e!.isPremium, isTrue);
    expect(e.activeEntitlements, {'Echo Loop Plus'});
    expect(e.productId, 'echo_loop_plus_annual');
    expect(e.period, SubscriptionPeriod.yearly);
    expect(
      e.expiresAt,
      DateTime.fromMillisecondsSinceEpoch(1750000000000, isUtc: true),
    );
    expect(e.willRenew, isTrue);
    expect(e.source, EntitlementSource.paddle);
  });

  test('source 字段按购买来源映射，未知值回退 unknown', () async {
    for (final entry in {
      'apple': EntitlementSource.apple,
      'google': EntitlementSource.google,
      'paddle': EntitlementSource.paddle,
      'stripe': EntitlementSource.unknown,
    }.entries) {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/api/entitlements',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => resp({
          'isPremium': true,
          'entitlementIds': ['Echo Loop Plus'],
          'productId': 'echo_loop_plus_monthly',
          'expiresAtMs': 1750000000000,
          'willRenew': true,
          'source': entry.key,
        }),
      );

      final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
      expect(e!.source, entry.value);
      reset(dio);
    }
  });

  test('source 字段缺失：兼容旧后端，映射为 unknown', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_plus_monthly',
        'expiresAtMs': 1750000000000,
        'willRenew': true,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e!.source, EntitlementSource.unknown);
  });

  test('source 字段类型异常：兼容异常后端，映射为 unknown', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_plus_monthly',
        'expiresAtMs': 1750000000000,
        'willRenew': true,
        'source': 42,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e!.source, EntitlementSource.unknown);
  });

  test('willRenew=false：premium 有效但不再自动续订', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_plus_monthly',
        'expiresAtMs': 1750000000000,
        'willRenew': false,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e!.isPremium, isTrue);
    expect(e.willRenew, isFalse);
  });

  test('willRenew 字段缺失：兼容旧后端，保守映射为 false', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_plus_monthly',
        'expiresAtMs': 1750000000000,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e!.isPremium, isTrue);
    expect(e.willRenew, isFalse);
  });

  test('isPremium=false：返回权威的 Entitlement.free（非 null，可据此降级）', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': false,
        'entitlementIds': <String>[],
        'productId': null,
        'expiresAtMs': null,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e, isNotNull);
    expect(e, Entitlement.free);
  });

  test('Lifetime（expiresAtMs 为空）：premium 且 expiresAt 为 null', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': true,
        'entitlementIds': ['Echo Loop Plus'],
        'productId': 'echo_loop_lifetime',
        'expiresAtMs': null,
      }),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e!.isPremium, isTrue);
    expect(e.expiresAt, isNull);
    expect(e.period, SubscriptionPeriod.lifetime);
  });

  test('DioException（网络/非 2xx）→ 返回 null（走兜底，不误降级）', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/entitlements'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e, isNull);
  });

  test('响应体为空 → 返回 null', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/api/entitlements'),
        statusCode: 200,
        data: null,
      ),
    );

    final e = await repo.fetchRemote(userId: 'u1', accessToken: 't');
    expect(e, isNull);
  });

  test('fetchRemote：GET /api/entitlements 携带 Bearer token', () async {
    when(
      () => dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => resp({
        'isPremium': false,
        'entitlementIds': <String>[],
        'productId': null,
        'expiresAtMs': null,
      }),
    );

    await repo.fetchRemote(userId: 'u1', accessToken: 't');

    final captured =
        verify(
              () => dio.get<Map<String, dynamic>>(
                '/api/entitlements',
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as Options;
    expect(captured.headers?['Authorization'], 'Bearer t');
  });
}

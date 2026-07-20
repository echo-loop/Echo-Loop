/// 后端权益仓库接口 + 实现。
///
/// 查询后端权威权益。
///
/// 该仓库只供 Web/direct 支付渠道使用：这些端没有可用的原生商店 SDK，
/// 权益必须经后端 `/api/entitlements` 读回。App Store / Google Play
/// 渠道的客户端权益以 RevenueCat SDK CustomerInfo 为准。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../providers/package_info_provider.dart';
import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../models/entitlement.dart';
import '../models/entitlement_source.dart';
import '../models/subscription_plan.dart';

/// 后端权益仓库抽象。
abstract class EntitlementRepository {
  /// 查询后端权威权益。
  ///
  /// - 返回非空：后端确认的权益（active 或 [Entitlement.free]）。
  /// - 返回 **null**：未能获取（离线 / 错误 / 后端未就绪），调用方据此走缓存兜底，
  ///   **不可**把「获取失败」误判为「无权益」。
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  });
}

/// Phase 0 占位实现：恒返回 null（触发缓存兜底 / 未知态）。
///
/// 保留供未接后端的构建 / 测试使用（如未注入 `API_BASE_URL` 的纯离线场景）。
class StubEntitlementRepository implements EntitlementRepository {
  const StubEntitlementRepository();

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) async {
    return null;
  }
}

/// 后端权益仓库实现（`GET /api/entitlements`）。
///
/// 响应体：`{ isPremium, entitlementIds, productId, expiresAtMs, willRenew, source }`（见后端
/// `apps/app/app/api/entitlements/route.ts`）。带 `Authorization: Bearer <token>`，
/// 参照 [TranscriptionApiClient] 的既有鉴权模式。
///
/// 错误策略（对齐接口契约）：
/// - HTTP 2xx → 映射为 [Entitlement]（`isPremium:false` 即权威的 [Entitlement.free]，
///   允许后端据此**降级**，而非误判为「获取失败」）。
/// - 网络异常 / 非 2xx / 解析失败 → 返回 **null**（走缓存 / RC 兜底，绝不误降级）。
class BackendEntitlementRepository implements EntitlementRepository {
  BackendEntitlementRepository({required String baseUrl, String? appVersion})
    : _dio = createBackendDio(
        baseUrl: baseUrl,
        appVersion: appVersion,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        apiLogTag: 'ENTITLEMENT',
      );

  /// 测试用构造：注入 Dio。
  BackendEntitlementRepository.withDio(this._dio);

  final Dio _dio;

  @override
  Future<Entitlement?> fetchRemote({
    required String userId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/entitlements',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (data == null) {
        AppLogger.log('Subscription', '后端权益：响应体为空，走兜底');
        return null;
      }
      _logEntitlementResponse(data, response.statusCode);
      return _entitlementFrom(data);
    } on DioException catch (e) {
      // 网络 / 超时 / 非 2xx：不可误判为无权益，返回 null 由上层走缓存兜底。
      AppLogger.log(
        'Subscription',
        '后端权益查询失败（走兜底）: ${e.type} ${e.response?.statusCode ?? ""}',
      );
      return null;
    } catch (e) {
      AppLogger.log('Subscription', '后端权益解析异常（走兜底）: $e');
      return null;
    }
  }

  /// 把后端响应映射为 [Entitlement]。周期用 productId 启发式补全（后端不存周期）。
  Entitlement _entitlementFrom(Map<String, dynamic> json) {
    final isPremium = json['isPremium'] == true;
    if (!isPremium) return Entitlement.free;
    final rawIds = json['entitlementIds'];
    final entitlements = rawIds is List
        ? rawIds.whereType<String>().toSet()
        : <String>{};
    final productId = json['productId'] is String
        ? json['productId'] as String
        : null;
    final rawExpiry = json['expiresAtMs'];
    final expiresAt = rawExpiry is int
        ? DateTime.fromMillisecondsSinceEpoch(rawExpiry, isUtc: true)
        : null;
    final rawSource = json['source'];
    return Entitlement(
      isPremium: true,
      activeEntitlements: entitlements,
      productId: productId,
      // 后端无周期字段：用 productId 字符串启发式推断，供会员 UI 显示套餐名。
      period: subscriptionPeriodFromProductId(productId),
      expiresAt: expiresAt,
      willRenew: json['willRenew'] == true,
      source: entitlementSourceFromApi(rawSource is String ? rawSource : null),
    );
  }

  /// 打印 App 实际收到的权益响应，避免排查时只看后端预期。
  ///
  /// 只记录业务摘要与字段存在性，不打印 access token / Authorization header。
  void _logEntitlementResponse(Map<String, dynamic> json, int? statusCode) {
    final rawIds = json['entitlementIds'];
    final entitlementIds = rawIds is List
        ? rawIds.whereType<String>().toList()
        : const <String>[];
    AppLogger.log(
      'Subscription',
      '后端权益响应: http=${statusCode ?? "unknown"} '
          'isPremium=${json['isPremium'] == true} '
          'entitlementIds=$entitlementIds '
          'productId=${json['productId'] is String ? json['productId'] : "null"} '
          'expiresAtMs=${json['expiresAtMs'] is int ? json['expiresAtMs'] : "null"} '
          'willRenew=${json['willRenew'] == true} '
          'hasWillRenew=${json.containsKey('willRenew')} '
          'source=${json['source'] is String ? json['source'] : "null"} '
          'hasSource=${json.containsKey('source')}',
    );
  }
}

/// 后端权益仓库 Provider（测试可 override 注入 Fake）。
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return BackendEntitlementRepository(
    baseUrl: apiBaseUrl,
    appVersion: readAppVersion(ref),
  );
});

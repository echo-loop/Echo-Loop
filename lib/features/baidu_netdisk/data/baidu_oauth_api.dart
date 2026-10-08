/// 自家后端百度 OAuth API 客户端。
///
/// 该客户端只访问自家后端 OAuth 桥接接口；文件列表和下载会在后续任务中用独立
/// 百度 API 客户端实现，避免把百度 dlink 或 access token 打进通用日志。
library;

import 'package:dio/dio.dart';

import '../../../config/api_config.dart';
import '../../../services/backend_dio.dart';
import '../../../services/runtime_endpoint_router.dart';
import '../../baidu_netdisk/models/baidu_credential_bundle.dart';
import '../../baidu_netdisk/models/baidu_netdisk_error.dart';
import '../../baidu_netdisk/models/baidu_oauth_session.dart';
import '../../baidu_netdisk/models/baidu_oauth_session_status.dart';

/// 百度 OAuth API 抽象，便于 Controller 与测试注入。
abstract interface class BaiduOAuthApi {
  /// 创建授权会话。
  Future<BaiduOAuthSession> createSession(
    BaiduNetdiskPlatform platform, {
    required bool forceLogin,
  });

  /// 查询授权状态。
  Future<BaiduOAuthSessionStatus> fetchStatus({
    required String sessionId,
    required String pollToken,
  });

  /// 在 secure storage 写入成功后确认后端删除临时 credential。
  Future<void> acknowledge({
    required String sessionId,
    required String pollToken,
  });

  /// 刷新凭证。
  Future<BaiduCredentialBundle> refresh({required String refreshToken});
}

/// 自家后端实现。
class BackendBaiduOAuthApi implements BaiduOAuthApi {
  /// 构造后端 OAuth API。
  BackendBaiduOAuthApi({
    required String baseUrl,
    String? appVersion,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = createBackendDio(
         baseUrl: baseUrl,
         endpointRouter: endpointRouter,
         appVersion: appVersion,
         apiLogTag: 'BAIDU-OAUTH',
       );

  /// 测试用构造。
  BackendBaiduOAuthApi.withDio(this._dio);

  final Dio _dio;

  @override
  Future<BaiduOAuthSession> createSession(
    BaiduNetdiskPlatform platform, {
    required bool forceLogin,
  }) async {
    final response = await _postJson(
      '/api/v1/netdisk/baidu/oauth/session',
      data: <String, Object?>{
        'platform': platform.wireName,
        if (forceLogin) 'forceLogin': true,
      },
    );
    return BaiduOAuthSession.fromJson(response);
  }

  @override
  Future<BaiduOAuthSessionStatus> fetchStatus({
    required String sessionId,
    required String pollToken,
  }) async {
    final response = await _postJson(
      '/api/v1/netdisk/baidu/oauth/session/status',
      data: <String, Object?>{'sessionId': sessionId, 'pollToken': pollToken},
    );
    return BaiduOAuthSessionStatus.fromJson(response);
  }

  @override
  Future<void> acknowledge({
    required String sessionId,
    required String pollToken,
  }) async {
    await _postJson(
      '/api/v1/netdisk/baidu/oauth/session/acknowledge',
      data: <String, Object?>{'sessionId': sessionId, 'pollToken': pollToken},
    );
  }

  @override
  Future<BaiduCredentialBundle> refresh({required String refreshToken}) async {
    final response = await _postJson(
      '/api/v1/netdisk/baidu/oauth/refresh',
      data: <String, Object?>{'refreshToken': refreshToken},
    );
    return BaiduCredentialBundle.fromJson(response);
  }

  Future<Object?> _postJson(String path, {required Object? data}) async {
    try {
      final response = await _dio.post<Object?>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Exception _mapDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final rawError = data['error'];
      if (rawError is Map) {
        return BaiduNetdiskApiError(
          code: BaiduNetdiskOAuthErrorCode.fromWireName(rawError['code']),
          message: rawError['message'] is String
              ? rawError['message'] as String
              : 'Baidu OAuth request failed.',
        );
      }
    }
    return error;
  }
}

/// 默认后端 OAuth API。
BackendBaiduOAuthApi createDefaultBaiduOAuthApi({String? appVersion}) {
  return BackendBaiduOAuthApi(
    baseUrl: apiBaseUrl,
    appVersion: appVersion,
    endpointRouter: runtimeEndpointRouter,
  );
}

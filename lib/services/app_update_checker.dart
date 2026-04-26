/// App 版本更新检查服务
///
/// 从远程静态 JSON 获取版本信息。使用独立 Dio 实例（不复用 AI API 的 Dio），
/// 超时设置为 connect 5s + receive 5s。所有异常静默返回 null。
library;

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/app_update_info.dart';

/// App 版本更新检查器
///
/// 版本检查 URL 基于 [apiBaseUrl]（通过 `--dart-define=API_BASE_URL` 配置），
/// 本地开发时访问 `http://localhost:3000/version.json`，
/// 生产环境访问 `https://www.echo-loop.top/version.json`。
class AppUpdateChecker {
  final Dio _dio;
  final String _url;

  /// 使用默认配置创建检查器
  AppUpdateChecker()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
        _url = '$apiBaseUrl/version.json';

  /// 用于测试的构造函数，允许注入 Dio 实例和 URL
  AppUpdateChecker.withDio(this._dio, [this._url = '']);

  /// 检查远程版本信息
  ///
  /// 失败时返回 null（网络错误、JSON 解析失败等均静默处理）。
  Future<AppUpdateInfo?> check() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_url);
      if (response.data == null) return null;
      return AppUpdateInfo.fromJson(response.data!);
    } catch (_) {
      return null;
    }
  }

  /// 释放资源
  void dispose() => _dio.close();
}

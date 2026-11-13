import 'package:dio/dio.dart';

import '../../../services/backend_dio.dart';
import '../domain/account_usage.dart';

abstract interface class AccountUsageRemoteDataSource {
  Future<AccountUsage> getUsage();
}

/// 后端 `/api/v1/me/usage` 的客户端，只读。
class AccountUsageApi implements AccountUsageRemoteDataSource {
  const AccountUsageApi(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/me/usage';

  @override
  Future<AccountUsage> getUsage() async {
    final response = await _dio.get<Object?>(
      _path,
      options: authRetryOnceOptions(),
    );
    return AccountUsage.fromJson(response.data);
  }
}

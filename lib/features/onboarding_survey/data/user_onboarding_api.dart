import 'package:dio/dio.dart';

import '../../../services/backend_dio.dart';

abstract interface class UserOnboardingRemoteDataSource {
  /// 保存当前登录用户的 onboarding 答案快照。
  Future<void> saveAnswers(Map<String, Object?> answers);
}

/// 调用前端 `PUT /api/v1/me/onboarding` 保存 onboarding 答案。
class UserOnboardingApi implements UserOnboardingRemoteDataSource {
  const UserOnboardingApi(this._dio);

  final Dio _dio;

  @override
  Future<void> saveAnswers(Map<String, Object?> answers) async {
    final response = await _dio.put<void>(
      '/api/v1/me/onboarding',
      data: answers,
      options: authRetryOnceOptions(),
    );
    if (response.statusCode != 204) {
      throw FormatException(
        'Onboarding endpoint returned unexpected status ${response.statusCode}',
      );
    }
  }
}

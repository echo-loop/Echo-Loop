import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../services/app_logger.dart';
import '../../../services/backend_dio.dart';
import '../domain/user_profile.dart';

abstract interface class UserProfileRemoteDataSource {
  Future<UserProfile> getProfile();

  Future<UserProfile> updateNickname(String nickname);

  /// [jpegBytes] 必须已由 `encodeAvatar` 处理为 512 KB 以内的 JPEG。
  Future<UserProfile> uploadAvatar(Uint8List jpegBytes);

  Future<UserProfile> removeAvatar();
}

/// 后端 `/api/v1/me/profile` 的客户端，一次只改一项资料。
class UserProfileApi implements UserProfileRemoteDataSource {
  const UserProfileApi(this._dio);

  final Dio _dio;

  static const _path = '/api/v1/me/profile';

  @override
  Future<UserProfile> getProfile() async {
    final response = await _dio.get<Object?>(
      _path,
      options: authRetryOnceOptions(),
    );
    return UserProfile.fromJson(response.data);
  }

  @override
  Future<UserProfile> updateNickname(String nickname) {
    return _patch(FormData.fromMap({'nickname': nickname}));
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List jpegBytes) {
    return _patch(
      FormData.fromMap({
        'avatar': MultipartFile.fromBytes(jpegBytes, filename: 'avatar.jpg'),
      }),
    );
  }

  @override
  Future<UserProfile> removeAvatar() {
    return _patch(FormData.fromMap({'removeAvatar': 'true'}));
  }

  /// PATCH 不声明 [authRetryOnceOptions]：multipart 请求体发送后不可重放，
  /// 发送前的 token 有效性已由 Token Gate 保证。
  Future<UserProfile> _patch(FormData form) async {
    try {
      final response = await _dio.patch<Object?>(_path, data: form);
      return UserProfile.fromJson(response.data);
    } on DioException catch (error) {
      AppLogger.log(
        'UserProfile',
        'PATCH failed status=${error.response?.statusCode ?? 'no_response'}',
      );
      rethrow;
    }
  }
}

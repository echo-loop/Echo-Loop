import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../analytics/geo_interceptor.dart';
import '../../../config/api_config.dart';
import '../models/audio_content_dto.dart';

part 'official_collection_api.g.dart';

/// 官方音频学习内容请求过窄的范围错误：HTTP 422 + `{ code: 'no_transcript' }`
/// 表示该 audio 没有任何 transcript 记录，无法生成 SRT。
class AudioTranscriptUnavailable implements Exception {
  final String remoteAudioId;
  const AudioTranscriptUnavailable(this.remoteAudioId);
  @override
  String toString() => 'AudioTranscriptUnavailable($remoteAudioId)';
}

/// 官方合集的按需 API 客户端。
///
/// 仅保留 `getAudioContent` —— 用户点击官方音频开始学习时，
/// download notifier 调一次拿最新 audioUrl + SRT + wordTimestamps。
///
/// 浏览类数据（collections list / detail）不再走 API，由
/// [OfficialCatalogService] 统一从本地 catalog 文件读取。
class OfficialCollectionApi {
  final Dio _dio;

  OfficialCollectionApi({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    SharedPreferences.getInstance().then(
      (prefs) => _dio.interceptors.add(GeoInterceptor(prefs)),
    );
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) => print('[OfficialCollection] $obj'),
      ),
    );
  }

  /// 测试用构造，允许注入 Dio。
  OfficialCollectionApi.withDio(this._dio);

  /// GET /api/v1/audios/:id/content
  ///
  /// 异常：
  /// - [AudioTranscriptUnavailable]：HTTP 422
  /// - 其他网络错误以 [DioException] 抛出
  Future<AudioContent> getAudioContent(
    String remoteAudioId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/audios/$remoteAudioId/content',
        cancelToken: cancelToken,
      );
      return AudioContent.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw AudioTranscriptUnavailable(remoteAudioId);
      }
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
OfficialCollectionApi officialCollectionApi(Ref ref) {
  return OfficialCollectionApi(baseUrl: apiBaseUrl);
}

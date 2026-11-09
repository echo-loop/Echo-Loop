import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/share_card_template.dart';

abstract interface class ShareCardRemoteDataSource {
  Future<ShareCardTemplate> getToday();
  Future<ShareCardTemplate> getRandom(String excludeId);
  Future<Uint8List> downloadImage(String url);
  Future<void> recordShare(String id);
}

/// API 与公网图片分别使用不同的 client，避免向图片主机泄露账号和渠道信息。
class ShareCardApi implements ShareCardRemoteDataSource {
  const ShareCardApi(this._backend, this._images);
  final Dio _backend;
  final Dio _images;

  @override
  Future<ShareCardTemplate> getToday() => _get('/api/v1/share-cards/today');

  @override
  Future<ShareCardTemplate> getRandom(String excludeId) =>
      _get('/api/v1/share-cards/random', {'excludeId': excludeId});

  Future<ShareCardTemplate> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _backend.get<Object?>(path, queryParameters: query);
    final body = response.data;
    if (body is! Map<String, Object?>) {
      throw const FormatException('分享卡片响应无效');
    }
    return ShareCardTemplate.fromJson(body['card']);
  }

  @override
  Future<Uint8List> downloadImage(String url) async {
    final response = await _images.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('分享图片为空或超过大小限制');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> recordShare(String id) async {
    // 点击计数不是幂等操作，不设置自动重试。
    await _backend.post<void>('/api/v1/share-cards/$id/shares');
  }
}

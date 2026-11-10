import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/share_card_template.dart';

abstract interface class ShareCardRemoteDataSource {
  /// [date] 为用户本地日历日；服务端按该日期选卡，使各时区同一天看到同一张卡。
  Future<ShareCardTemplate> getToday(DateTime date);
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
  Future<ShareCardTemplate> getToday(DateTime date) async {
    final requested = _formatLocalDate(date);
    final body = await _getBody('/api/v1/share-cards/today', {
      'date': requested,
    });
    // 缓存按本地日期保存，服务端若回显其它日期必须拒绝，避免错日卡片被当作今日卡。
    if (body['date'] != requested) {
      throw const FormatException('分享卡片日期与请求不一致');
    }
    return ShareCardTemplate.fromJson(body['card']);
  }

  @override
  Future<ShareCardTemplate> getRandom(String excludeId) async {
    final body = await _getBody('/api/v1/share-cards/random', {
      'excludeId': excludeId,
    });
    return ShareCardTemplate.fromJson(body['card']);
  }

  Future<Map<String, Object?>> _getBody(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _backend.get<Object?>(path, queryParameters: query);
    final body = response.data;
    if (body is! Map<String, Object?>) {
      throw const FormatException('分享卡片响应无效');
    }
    return body;
  }

  static String _formatLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

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

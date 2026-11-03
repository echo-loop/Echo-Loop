import '../../services/app_logger.dart';
import '../../services/background_file_download_service.dart'
    show resourceKeyForUrl;

const _logTag = 'AudioImport';

/// 播客单集的下载资源 key：按规范化后的地址计算，与下载时使用的 key 一致。
/// 地址无法解析时返回 null。
String? podcastResourceKey(String enclosureUrl) {
  final uri = Uri.tryParse(enclosureUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return resourceKeyForUrl(normalizePodcastAudioUri(uri));
}

/// BBC RSS 历史数据常落库为 HTTP enclosure，而同一 feed 同时提供 HTTPS 版本。
/// Anchor 的 podcast/play enclosure 会把真实媒体 URL 编码在路径最后一段；
/// 直接请求该地址，避免下载器依赖 Anchor 重定向服务。
/// BBC RSS 历史数据则升级到 HTTPS，避免 Android cleartext 策略拦截 HTTP。
Uri normalizePodcastAudioUri(Uri uri) {
  if (uri.host == 'anchor.fm' || uri.host == 'www.anchor.fm') {
    final segments = uri.pathSegments;
    if (segments.length >= 5 &&
        segments[2] == 'podcast' &&
        segments[3] == 'play') {
      try {
        final mediaUri = Uri.tryParse(Uri.decodeComponent(segments.last));
        if (mediaUri != null &&
            (mediaUri.scheme == 'http' || mediaUri.scheme == 'https') &&
            mediaUri.host.isNotEmpty) {
          AppLogger.log(
            _logTag,
            'resolved Anchor media URL host=${mediaUri.host}',
          );
          return mediaUri;
        }
      } on FormatException {
        // URL 编码损坏时保留原始 enclosure，让下载器返回实际错误。
      }
    }
  }
  if (uri.scheme != 'http' || uri.host != 'open.live.bbc.co.uk') {
    return uri;
  }
  final segments = uri.pathSegments;
  final protoIndex = segments.indexOf('proto');
  if (protoIndex == -1 || protoIndex + 1 >= segments.length) {
    return uri.replace(scheme: 'https');
  }
  final nextSegments = List<String>.from(segments);
  if (nextSegments[protoIndex + 1] == 'http') {
    nextSegments[protoIndex + 1] = 'https';
  }
  return uri.replace(scheme: 'https', pathSegments: nextSegments);
}

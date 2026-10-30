/// 播客单集字幕下载器
///
/// 下载 RSS `<podcast:transcript>` 指向的字幕文件，并解码为文本。
/// 只负责「取字节 → 解码」，不解析句子、不入库；入库由调用方统一走
/// `importLocalSubtitleWithRef`，与本地字幕导入保持同一主干。
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:subtitle/subtitle.dart' show SubtitleType;

import '../../utils/transcript_picker.dart';

part 'podcast_transcript_downloader.g.dart';

/// 字幕下载或解码失败，携带可读原因（仅用于日志）。
class PodcastTranscriptException implements Exception {
  final String message;
  const PodcastTranscriptException(this.message);
  @override
  String toString() => 'PodcastTranscriptException: $message';
}

class PodcastTranscriptDownloader {
  PodcastTranscriptDownloader({Dio? dio}) : _dio = dio ?? Dio();

  /// 字幕文件体积上限。播客字幕通常只有几十 KB，超过即视为异常文件。
  static const maxBytes = 5 * 1024 * 1024;

  /// 连接与接收超时。Dio 默认无超时，挂起的服务器会让下载流程永久等待。
  static const requestTimeout = Duration(seconds: 20);

  final Dio _dio;

  /// 下载 [url] 处的字幕并解码为文本。[format] 为 `srt` 或 `vtt`，
  /// 用于选择解码器的字幕类型。
  ///
  /// HTTP 非 2xx、空响应或超过 [maxBytes] 时抛出 [PodcastTranscriptException]；
  /// 网络错误与取消（[DioException]）原样抛出。[cancelToken] 取消时同样抛出。
  Future<String> download(
    String url, {
    required String format,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.bytes,
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        validateStatus: (_) => true,
      ),
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw PodcastTranscriptException('HTTP $status');
    }
    final bytes = response.data ?? const <int>[];
    if (bytes.isEmpty) {
      throw const PodcastTranscriptException('empty body');
    }
    if (bytes.length > maxBytes) {
      throw PodcastTranscriptException('body too large: ${bytes.length}');
    }
    final decoded = await decodeTranscriptBytes(
      bytes,
      type: format == 'vtt' ? SubtitleType.vtt : SubtitleType.srt,
    );
    return decoded.text;
  }
}

@riverpod
PodcastTranscriptDownloader podcastTranscriptDownloader(Ref ref) {
  return PodcastTranscriptDownloader();
}

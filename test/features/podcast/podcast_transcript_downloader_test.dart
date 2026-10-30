import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/podcast/podcast_transcript_downloader.dart';

/// 按 [status] / [body] 返回字幕字节的假 Dio，并记录请求地址。
class _FakeTranscriptDio extends Fake implements Dio {
  _FakeTranscriptDio({this.status = 200, this.body, this.error});

  final int status;
  final List<int>? body;
  final DioException? error;
  final List<String> requestedUrls = <String>[];
  Options? lastOptions;
  CancelToken? lastCancelToken;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestedUrls.add(path);
    lastOptions = options;
    lastCancelToken = cancelToken;
    if (error != null) throw error!;
    return Response<T>(
      data: Uint8List.fromList(body ?? const <int>[]) as T,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );
  }
}

const _srt = '''1
00:00:00,000 --> 00:00:02,000
Hello there.

2
00:00:02,500 --> 00:00:04,000
Second line.
''';

void main() {
  const url = 'https://example.com/09.srt';

  test('下载成功时返回解码后的字幕文本', () async {
    final dio = _FakeTranscriptDio(body: utf8.encode(_srt));
    final downloader = PodcastTranscriptDownloader(dio: dio);

    final text = await downloader.download(url, format: 'srt');

    expect(text, _srt);
    expect(dio.requestedUrls, [url]);
  });

  test('HTTP 非 2xx 时抛出 PodcastTranscriptException', () async {
    final downloader = PodcastTranscriptDownloader(
      dio: _FakeTranscriptDio(status: 404, body: utf8.encode(_srt)),
    );

    await expectLater(
      downloader.download(url, format: 'srt'),
      throwsA(isA<PodcastTranscriptException>()),
    );
  });

  test('空响应体时抛出 PodcastTranscriptException', () async {
    final downloader = PodcastTranscriptDownloader(
      dio: _FakeTranscriptDio(body: const <int>[]),
    );

    await expectLater(
      downloader.download(url, format: 'srt'),
      throwsA(isA<PodcastTranscriptException>()),
    );
  });

  test('超过体积上限时抛出 PodcastTranscriptException', () async {
    final oversized = List<int>.filled(
      PodcastTranscriptDownloader.maxBytes + 1,
      0x41,
    );
    final downloader = PodcastTranscriptDownloader(
      dio: _FakeTranscriptDio(body: oversized),
    );

    await expectLater(
      downloader.download(url, format: 'srt'),
      throwsA(isA<PodcastTranscriptException>()),
    );
  });

  test('请求设置连接与接收超时，避免挂起的服务器卡住下载流程', () async {
    final dio = _FakeTranscriptDio(body: utf8.encode(_srt));
    final downloader = PodcastTranscriptDownloader(dio: dio);

    await downloader.download(url, format: 'srt');

    expect(dio.lastOptions?.connectTimeout, isNotNull);
    expect(dio.lastOptions?.receiveTimeout, isNotNull);
  });

  test('传入的 CancelToken 原样透传给 Dio，支持取消', () async {
    final dio = _FakeTranscriptDio(body: utf8.encode(_srt));
    final downloader = PodcastTranscriptDownloader(dio: dio);
    final token = CancelToken();

    await downloader.download(url, format: 'srt', cancelToken: token);

    expect(dio.lastCancelToken, same(token));
  });

  test('网络错误原样向上传播，由调用方决定降级', () async {
    final downloader = PodcastTranscriptDownloader(
      dio: _FakeTranscriptDio(
        error: DioException(
          requestOptions: RequestOptions(path: url),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );

    await expectLater(
      downloader.download(url, format: 'srt'),
      throwsA(isA<DioException>()),
    );
  });
}

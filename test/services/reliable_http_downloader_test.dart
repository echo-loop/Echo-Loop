import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _QueuedResponse {
  const _QueuedResponse(
    this.statusCode,
    this.body, {
    this.headers = const {},
    this.chunks,
  });

  final int statusCode;
  final List<int> body;
  final Map<String, List<String>> headers;
  final List<List<int>>? chunks;
}

/// 排队的连接层异常（模拟超时/连接失败，不经过 HTTP 状态码）。
class _QueuedError {
  const _QueuedError(this.type);

  final DioExceptionType type;
}

/// 排队的“响应头正常但流中途失败”场景，模拟已建立连接后网络中断。
class _QueuedStreamFailure {
  const _QueuedStreamFailure(
    this.statusCode,
    this.headers,
    this.error, {
    this.chunksBeforeError = const [],
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final Object error;
  final List<List<int>> chunksBeforeError;
}

Stream<Uint8List> _chunksThenError(
  List<List<int>> chunks,
  Object error,
) async* {
  for (final chunk in chunks) {
    yield Uint8List.fromList(chunk);
  }
  throw error;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  final List<Object> responses;
  final requestHeaders = <Map<String, Object?>>[];
  final requestUris = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestHeaders.add(Map<String, Object?>.from(options.headers));
    requestUris.add(options.uri);
    final next = responses.removeAt(0);
    if (next is _QueuedError) {
      throw DioException(requestOptions: options, type: next.type);
    }
    if (next is _QueuedStreamFailure) {
      return ResponseBody(
        _chunksThenError(next.chunksBeforeError, next.error),
        next.statusCode,
        headers: next.headers,
      );
    }
    final response = next as _QueuedResponse;
    return ResponseBody(
      Stream<Uint8List>.fromIterable(
        (response.chunks ?? [response.body]).map(Uint8List.fromList),
      ),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 阻塞在 fetch 内，直到 [release] 被调用；用于验证同一 savePath 并发保护。
class _BlockingAdapter implements HttpClientAdapter {
  final _gate = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _gate.future;
    return ResponseBody(
      Stream<Uint8List>.fromIterable([
        Uint8List.fromList([1, 2, 3]),
      ]),
      200,
      headers: const {
        'content-length': ['3'],
      },
    );
  }

  void release() => _gate.complete();

  @override
  void close({bool force = false}) {}
}

void main() {
  group('DioReliableHttpDownloader', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reliable-download-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    DioReliableHttpDownloader downloaderWith(
      _RecordingAdapter adapter, {
      int maxRetries = 3,
    }) {
      final dio = Dio();
      dio.httpClientAdapter = adapter;
      return DioReliableHttpDownloader(
        dio: dio,
        maxRetries: maxRetries,
        // 测试注入零延迟退避，避免真实等待重试间隔。
        backoffDelay: (_) => Future<void>.value(),
      );
    }

    File targetFile(String name) => File(p.join(tempDir.path, name));

    test('首次下载成功后原子落盘并清理 part/meta', () async {
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          200,
          [1, 2, 3],
          headers: {
            'content-length': ['3'],
          },
        ),
      ]);
      final target = targetFile('lesson.mp3');

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
        identityKey: 'file:1',
      );

      expect(await target.readAsBytes(), [1, 2, 3]);
      expect(await File('${target.path}.part').exists(), isFalse);
      expect(await File('${target.path}.part.meta.json').exists(), isFalse);
      expect(result.bytesWritten, 3);
      expect(result.resumed, isFalse);
    });

    test('多块下载在每次进度回调前已有续传身份元数据', () async {
      final target = targetFile('lesson.mp3');
      final metadataAtProgress = <String?>[];
      final receivedBytes = <int>[];
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          200,
          [],
          chunks: [
            [1, 2],
            [3, 4],
          ],
          headers: {
            'content-length': ['4'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 4,
        identityKey: 'file:1',
        onProgress: (received, _) {
          receivedBytes.add(received);
          final metadataFile = File('${target.path}.part.meta.json');
          metadataAtProgress.add(
            metadataFile.existsSync() ? metadataFile.readAsStringSync() : null,
          );
        },
      );

      expect(metadataAtProgress, hasLength(2));
      expect(
        metadataAtProgress,
        everyElement(contains('"identityKey":"file:1"')),
      );
      expect(receivedBytes, [2, 4]);
      expect(result.bytesWritten, 4);
      expect(await target.readAsBytes(), [1, 2, 3, 4]);
    });

    test('流中断后按 part 实际长度自动 Range 续传并拼接', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([
        _QueuedStreamFailure(
          200,
          const {},
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
          ),
          chunksBeforeError: const [
            [1, 2],
          ],
        ),
        const _QueuedResponse(
          206,
          [3, 4],
          headers: {
            'content-range': ['bytes 2-3/4'],
            'content-length': ['2'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 4,
        identityKey: 'file:1',
      );

      expect(adapter.requestHeaders[0].containsKey('Range'), isFalse);
      expect(adapter.requestHeaders[1]['Range'], 'bytes=2-');
      expect(await target.readAsBytes(), [1, 2, 3, 4]);
      expect(result.bytesWritten, 4);
      expect(result.resumed, isTrue);
      expect(await File('${target.path}.part.meta.json').exists(), isFalse);
    });

    test('已有匹配 part 时发送 Range 并按 206 追加续传', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([1, 2, 3]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          206,
          [4, 5],
          headers: {
            'content-range': ['bytes 3-4/5'],
            'content-length': ['2'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 5,
        identityKey: 'file:1',
      );

      expect(adapter.requestHeaders.single['Range'], 'bytes=3-');
      expect(await target.readAsBytes(), [1, 2, 3, 4, 5]);
      expect(result.resumed, isTrue);
    });

    test('手动跟随 redirect 并保留下载请求头', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([1, 2, 3]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          302,
          [],
          headers: {
            'location': ['https://cdn.example.com/lesson.mp3?sign=ok'],
          },
        ),
        const _QueuedResponse(
          206,
          [4, 5],
          headers: {
            'content-range': ['bytes 3-4/5'],
            'content-length': ['2'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        headers: const {'User-Agent': 'pan.baidu.com'},
        expectedSize: 5,
        identityKey: 'file:1',
      );

      expect(adapter.requestUris, [
        Uri.parse('https://example.com/lesson.mp3'),
        Uri.parse('https://cdn.example.com/lesson.mp3?sign=ok'),
      ]);
      expect(adapter.requestHeaders, [
        containsPair('User-Agent', 'pan.baidu.com'),
        containsPair('User-Agent', 'pan.baidu.com'),
      ]);
      expect(adapter.requestHeaders, [
        containsPair('Range', 'bytes=3-'),
        containsPair('Range', 'bytes=3-'),
      ]);
      expect(await target.readAsBytes(), [1, 2, 3, 4, 5]);
      expect(result.resumed, isTrue);
    });

    test('服务端忽略 Range 返回 200 时丢弃旧 part 并从头写入', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([9, 9, 9]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(200, [1, 2, 3, 4]),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 4,
        identityKey: 'file:1',
      );

      expect(adapter.requestHeaders.single['Range'], 'bytes=3-');
      expect(await target.readAsBytes(), [1, 2, 3, 4]);
      expect(result.resumed, isFalse);
    });

    test('416 且本地 part 大小匹配时直接完成', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([1, 2, 3]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([const _QueuedResponse(416, [])]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
        identityKey: 'file:1',
      );

      expect(adapter.requestHeaders.single['Range'], 'bytes=3-');
      expect(await target.readAsBytes(), [1, 2, 3]);
      expect(result.resumed, isTrue);
    });

    test('identityKey 不匹配时删除旧 part 并普通下载', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([9, 9, 9]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"old","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(200, [1, 2]),
      ]);

      await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 2,
        identityKey: 'new',
      );

      expect(adapter.requestHeaders.single.containsKey('Range'), isFalse);
      expect(await target.readAsBytes(), [1, 2]);
    });

    test('最终大小不匹配时报错并保留 part', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(200, [1, 2]),
      ]);

      await expectLater(
        downloaderWith(adapter).download(
          uri: Uri.parse('https://example.com/lesson.mp3'),
          savePath: target.path,
          expectedSize: 3,
          identityKey: 'file:1',
        ),
        throwsA(isA<ReliableDownloadException>()),
      );

      expect(await target.exists(), isFalse);
      expect(await File('${target.path}.part').readAsBytes(), [1, 2]);
    });

    test('目标文件已存在时下载成功直接原子覆盖，不做 backup', () async {
      final target = targetFile('lesson.mp3');
      await target.writeAsBytes([9, 9, 9, 9, 9]);
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          200,
          [1, 2, 3],
          headers: {
            'content-length': ['3'],
          },
        ),
      ]);

      await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
      );

      expect(await target.readAsBytes(), [1, 2, 3]);
    });

    test('连接错误自动重试并最终成功', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([
        const _QueuedError(DioExceptionType.connectionError),
        const _QueuedResponse(
          200,
          [1, 2, 3],
          headers: {
            'content-length': ['3'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
      );

      expect(adapter.requestUris, hasLength(2));
      expect(result.bytesWritten, 3);
    });

    test('404 不重试，立即失败', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([const _QueuedResponse(404, [])]);

      await expectLater(
        downloaderWith(adapter).download(
          uri: Uri.parse('https://example.com/lesson.mp3'),
          savePath: target.path,
        ),
        throwsA(
          isA<ReliableDownloadException>()
              .having((e) => e.kind, 'kind', ReliableDownloadFailure.httpStatus)
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
      expect(adapter.requestUris, hasLength(1));
    });

    test('重试次数耗尽后抛出最后一次分类错误', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([
        const _QueuedError(DioExceptionType.connectionError),
        const _QueuedError(DioExceptionType.connectionError),
        const _QueuedError(DioExceptionType.connectionError),
      ]);

      await expectLater(
        downloaderWith(adapter, maxRetries: 2).download(
          uri: Uri.parse('https://example.com/lesson.mp3'),
          savePath: target.path,
        ),
        throwsA(
          isA<ReliableDownloadException>()
              .having((e) => e.kind, 'kind', ReliableDownloadFailure.network)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
      expect(adapter.requestUris, hasLength(3));
    });

    test('429 响应遵循 Retry-After 头的退避时长', () async {
      final target = targetFile('lesson.mp3');
      final durations = <Duration>[];
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          429,
          [],
          headers: {
            'retry-after': ['2'],
          },
        ),
        const _QueuedResponse(
          200,
          [1, 2, 3],
          headers: {
            'content-length': ['3'],
          },
        ),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final downloader = DioReliableHttpDownloader(
        dio: dio,
        backoffDelay: (duration) {
          durations.add(duration);
          return Future<void>.value();
        },
      );

      await downloader.download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
      );

      expect(durations.single, const Duration(seconds: 2));
    });

    test('续传被服务端忽略后，后续重试不再发送 Range', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([1, 2, 3]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        _QueuedStreamFailure(
          200,
          const {},
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
          ),
        ),
        const _QueuedResponse(
          200,
          [7, 8, 9, 10],
          headers: {
            'content-length': ['4'],
          },
        ),
      ]);

      final result = await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 4,
        identityKey: 'file:1',
      );

      expect(adapter.requestHeaders[0]['Range'], 'bytes=3-');
      expect(adapter.requestHeaders[1].containsKey('Range'), isFalse);
      expect(await target.readAsBytes(), [7, 8, 9, 10]);
      expect(result.resumed, isFalse);
    });

    test('Content-Range 起点不一致时清理 part/meta 并报 integrity', () async {
      final target = targetFile('lesson.mp3');
      await File('${target.path}.part').writeAsBytes([1, 2, 3]);
      await File(
        '${target.path}.part.meta.json',
      ).writeAsString('{"identityKey":"file:1","downloadedBytes":3}');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          206,
          [9, 9],
          headers: {
            'content-range': ['bytes 5-6/10'],
            'content-length': ['2'],
          },
        ),
      ]);

      await expectLater(
        downloaderWith(adapter).download(
          uri: Uri.parse('https://example.com/lesson.mp3'),
          savePath: target.path,
          expectedSize: 10,
          identityKey: 'file:1',
        ),
        throwsA(
          isA<ReliableDownloadException>().having(
            (e) => e.kind,
            'kind',
            ReliableDownloadFailure.integrity,
          ),
        ),
      );

      expect(await File('${target.path}.part').exists(), isFalse);
      expect(await File('${target.path}.part.meta.json').exists(), isFalse);
    });

    test('跨域重定向剥离 Authorization/Cookie，同域重定向保留', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _RecordingAdapter([
        const _QueuedResponse(
          302,
          [],
          headers: {
            'location': ['https://cdn.example.com/lesson.mp3'],
          },
        ),
        const _QueuedResponse(
          200,
          [1, 2, 3],
          headers: {
            'content-length': ['3'],
          },
        ),
      ]);

      await downloaderWith(adapter).download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        headers: const {
          'User-Agent': 'ua',
          'Authorization': 'Bearer secret',
          'Cookie': 'a=b',
        },
        expectedSize: 3,
      );

      expect(adapter.requestHeaders[0]['Authorization'], 'Bearer secret');
      expect(adapter.requestHeaders[1].containsKey('Authorization'), isFalse);
      expect(adapter.requestHeaders[1].containsKey('Cookie'), isFalse);
      expect(adapter.requestHeaders[1]['User-Agent'], 'ua');
    });

    test('并发下载同一 savePath 时第二次调用抛出 conflict', () async {
      final target = targetFile('lesson.mp3');
      final adapter = _BlockingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final downloader = DioReliableHttpDownloader(
        dio: dio,
        backoffDelay: (_) => Future<void>.value(),
      );

      final first = downloader.download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
      );
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        downloader.download(
          uri: Uri.parse('https://example.com/lesson.mp3'),
          savePath: target.path,
          expectedSize: 3,
        ),
        throwsA(
          isA<ReliableDownloadException>().having(
            (e) => e.kind,
            'kind',
            ReliableDownloadFailure.conflict,
          ),
        ),
      );

      adapter.release();
      await first;
    });

    test('退避等待期间取消不再重试，按 cancelled 分类', () async {
      AppLogger.instance.clear();
      final target = targetFile('lesson.mp3');
      final cancelToken = CancelToken();
      final adapter = _RecordingAdapter([
        const _QueuedError(DioExceptionType.connectionError),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final downloader = DioReliableHttpDownloader(
        dio: dio,
        backoffDelay: (_) => Completer<void>().future,
      );

      final future = downloader.download(
        uri: Uri.parse('https://example.com/lesson.mp3'),
        savePath: target.path,
        expectedSize: 3,
        cancelToken: cancelToken,
      );
      await Future<void>.delayed(Duration.zero);
      cancelToken.cancel();

      await expectLater(
        future,
        throwsA(
          isA<ReliableDownloadException>().having(
            (e) => e.kind,
            'kind',
            ReliableDownloadFailure.cancelled,
          ),
        ),
      );
      expect(AppLogger.instance.entries.last.message, contains('下载已取消'));
      expect(AppLogger.instance.entries.last.message, isNot(contains('下载失败')));
    });
  });
}

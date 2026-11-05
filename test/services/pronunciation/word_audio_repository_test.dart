import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/pronunciation/word_audio_identity.dart';
import 'package:echo_loop/services/pronunciation/word_audio_repository.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _cdn = 'https://cdn.example.test';
const _hello = 'Hello';

/// 可编排结果的假下载器：成功时写入字节，失败时抛出指定异常。
class _FakeDownloader implements ReliableHttpDownloader {
  final requestedUris = <Uri>[];
  Object? failure;
  Completer<void>? gate;

  @override
  Future<ReliableDownloadResult> download({
    required Uri uri,
    required String savePath,
    Map<String, String> headers = const <String, String>{},
    int? expectedSize,
    String? identityKey,
    bool allowResume = true,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    requestedUris.add(uri);
    await gate?.future;
    final error = failure;
    if (error != null) throw error;
    final file = File(savePath)..createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3]);
    return ReliableDownloadResult(
      savePath: savePath,
      bytesWritten: 3,
      resumed: false,
    );
  }
}

void main() {
  late Directory tempDir;
  late _FakeDownloader downloader;
  late WordAudioRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('word_audio_repository_');
    downloader = _FakeDownloader();
    final router = RuntimeEndpointRouter(
      endpoints: const RegionalServiceEndpoints(
        globalApiBaseUrl: '',
        chinaApiBaseUrl: '',
        globalStaticCdnBaseUrl: _cdn,
        chinaStaticCdnBaseUrl: '',
      ),
    )..updateFromUserRegion(isChinaUser: false);
    repository = WordAudioRepository(
      downloader: downloader,
      resolveCacheDir: () async => tempDir,
      endpointRouter: router,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String cachePathFor(String word) =>
      p.join(tempDir.path, 'word_audio', 'en-US', wordAudioFileName(word)!);

  test('缓存未命中时从 CDN 下载并落盘，之后直接命中缓存', () async {
    final first = await repository.resolve(_hello);
    final second = await repository.resolve(_hello);

    expect(first, cachePathFor(_hello));
    expect(second, first);
    expect(File(first!).readAsBytesSync(), [1, 2, 3]);
    expect(downloader.requestedUris, hasLength(1));
    expect(
      downloader.requestedUris.single.toString(),
      '$_cdn/words/en-US/${wordAudioFileName(_hello)}',
    );
  });

  test('已存在非空缓存文件时不发起网络请求', () async {
    final path = cachePathFor(_hello);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([9]);

    expect(await repository.resolve(_hello), path);
    expect(downloader.requestedUris, isEmpty);
  });

  test('0 字节缓存文件视为损坏，删除后重新下载', () async {
    final path = cachePathFor(_hello);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync([]);

    expect(await repository.resolve(_hello), path);
    expect(downloader.requestedUris, hasLength(1));
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });

  test('CDN 返回 404 时返回 null，且本进程内不再重复请求同一个词', () async {
    downloader.failure = const ReliableDownloadException(
      'not found',
      kind: ReliableDownloadFailure.httpStatus,
      statusCode: 404,
    );

    expect(await repository.resolve(_hello), isNull);
    expect(await repository.resolve(_hello), isNull);
    expect(downloader.requestedUris, hasLength(1));
  });

  test('网络错误返回 null，且不做负缓存，下次仍会重试', () async {
    downloader.failure = const ReliableDownloadException(
      'offline',
      kind: ReliableDownloadFailure.network,
    );
    expect(await repository.resolve(_hello), isNull);

    downloader.failure = null;
    expect(await repository.resolve(_hello), cachePathFor(_hello));
    expect(downloader.requestedUris, hasLength(2));
  });

  test('同一个词的并发请求共享同一次下载', () async {
    downloader.gate = Completer<void>();

    final pending = Future.wait([
      repository.resolve(_hello),
      repository.resolve(_hello),
    ]);
    downloader.gate!.complete();
    final results = await pending;

    expect(results, [cachePathFor(_hello), cachePathFor(_hello)]);
    expect(downloader.requestedUris, hasLength(1));
  });

  test('不合规的输入直接返回 null，不发起请求', () async {
    expect(await repository.resolve('two words'), isNull);
    expect(await repository.resolve('a1'), isNull);
    expect(downloader.requestedUris, isEmpty);
  });
}

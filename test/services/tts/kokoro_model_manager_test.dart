import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart';
import 'package:echo_loop/services/tts/kokoro_model_catalog.dart';

/// 返回预置归档字节的 mock dio adapter（按 URL 末段匹配）。
class _MockArchiveAdapter implements HttpClientAdapter {
  _MockArchiveAdapter(this.payload, {this.requestUris});

  /// 末段文件名 → 字节；命中返回 200，否则 404。
  final List<int> payload;
  final List<Uri>? requestUris;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestUris?.add(options.uri);
    if (!options.path.endsWith('.tar.gz')) {
      return ResponseBody(const Stream.empty(), 404, headers: {});
    }
    return ResponseBody(
      Stream.fromIterable([Uint8List.fromList(payload)]),
      200,
      headers: {
        'content-length': [payload.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<RuntimeEndpointRouter> _routerWithChinaCdn() async {
  final router = RuntimeEndpointRouter(
    endpoints: const RegionalServiceEndpoints(
      globalApiBaseUrl: 'https://global-api.example',
      chinaApiBaseUrl: 'https://china-api.example',
      globalModelCdnBaseUrl: 'https://global-cdn.example',
      chinaModelCdnBaseUrl: 'https://china-cdn.example',
    ),
  );
  return router..updateFromUserRegion(isChinaUser: true);
}

/// 对任何请求都返回 404 的 mock adapter，用于模拟归档下载的网络失败。
class _AlwaysNotFoundAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(const Stream.empty(), 404, headers: {});

  @override
  void close({bool force = false}) {}
}

/// 支持 Range 的归档 mock，用于验证断点续传请求和完成后的残留清理。
class _RangeArchiveAdapter implements HttpClientAdapter {
  _RangeArchiveAdapter(this.payload);

  final List<int> payload;
  final requests = <Map<String, Object?>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(Map<String, Object?>.from(options.headers));
    final range = options.headers['Range']?.toString();
    if (range == null) {
      return ResponseBody(
        Stream.value(Uint8List.fromList(payload)),
        200,
        headers: {
          'content-length': [payload.length.toString()],
        },
      );
    }
    final start = int.parse(range.substring('bytes='.length, range.length - 1));
    final body = payload.sublist(start);
    return ResponseBody(
      Stream.value(Uint8List.fromList(body)),
      206,
      headers: {
        'content-length': [body.length.toString()],
        'content-range': [
          'bytes $start-${payload.length - 1}/${payload.length}',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 构造一个含关键文件的 tar.gz 字节。
List<int> _buildArchive({bool includeDataDir = true}) {
  final archive = Archive();
  archive.add(ArchiveFile('model.int8.onnx', 8, List<int>.filled(8, 1)));
  archive.add(ArchiveFile('voices.bin', 4, List<int>.filled(4, 2)));
  archive.add(ArchiveFile('tokens.txt', 3, List<int>.filled(3, 3)));
  if (includeDataDir) {
    // 目录由文件路径隐式建立。
    archive.add(
      ArchiveFile('espeak-ng-data/phontab', 5, List<int>.filled(5, 4)),
    );
  }
  final tar = TarEncoder().encodeBytes(archive);
  return GZipEncoder().encodeBytes(tar);
}

KokoroModelManager _manager(
  Directory root,
  List<int> archive, {
  String? sha,
  RuntimeEndpointRouter? endpointRouter,
  List<Uri>? requestUris,
}) {
  final dio = Dio();
  dio.httpClientAdapter = _MockArchiveAdapter(
    archive,
    requestUris: requestUris,
  );
  return KokoroModelManager(
    dio: dio,
    baseUrlOverride: endpointRouter == null ? 'http://mock.local' : null,
    endpointRouter: endpointRouter,
    spec: KokoroModelSpec(
      variant: KokoroModelVariant.int8,
      id: 'test-model',
      archivePath: 'tts/test.tar.gz',
      sha256: sha ?? sha256.convert(archive).toString(),
      modelFileName: 'model.int8.onnx',
      estimatedDownloadBytes: 1024,
    ),
    modelsRootResolver: () async => root.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kokoro-model-test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('下载 → 校验 → 解包：关键文件就位且 isModelDownloaded 为真', () async {
    final archive = _buildArchive();
    final requestedUris = <Uri>[];
    final manager = _manager(
      root,
      archive,
      endpointRouter: await _routerWithChinaCdn(),
      requestUris: requestedUris,
    );

    final progresses = <double>[];
    await manager.downloadModel(onProgress: (p) => progresses.add(p.progress));

    expect(requestedUris.single.host, 'china-cdn.example');
    expect(requestedUris.single.path, '/model/tts/test.tar.gz');
    expect(await manager.isModelDownloaded(), isTrue);
    final paths = await manager.kokoroConfigPaths();
    expect(File(paths.model).existsSync(), isTrue);
    expect(File(paths.voices).existsSync(), isTrue);
    expect(File(paths.tokens).existsSync(), isTrue);
    expect(Directory(paths.dataDir).existsSync(), isTrue);
    expect(p.basename(paths.dataDir), 'espeak-ng-data');
    // 进度应抵达 1.0。
    expect(progresses.last, 1.0);
  });

  test('归档 SHA-256 不匹配 → 抛错且模型未安装', () async {
    final archive = _buildArchive();
    final manager = _manager(root, archive, sha: 'deadbeef');

    await expectLater(manager.downloadModel(), throwsA(isA<StateError>()));
    expect(await manager.isModelDownloaded(), isFalse);
    // 临时归档应被清理。
    final leftovers = root.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.tar.gz'),
    );
    expect(leftovers, isEmpty);
  });

  test('归档下载网络失败 → 抛结构化异常且不留 .part 残留', () async {
    final dio = Dio();
    dio.httpClientAdapter = _AlwaysNotFoundAdapter();
    final manager = KokoroModelManager(
      dio: dio,
      baseUrlOverride: 'http://mock.local',
      spec: const KokoroModelSpec(
        variant: KokoroModelVariant.int8,
        id: 'test-model',
        archivePath: 'tts/test.tar.gz',
        sha256: 'irrelevant',
        modelFileName: 'model.int8.onnx',
        estimatedDownloadBytes: 1024,
      ),
      modelsRootResolver: () async => root.path,
    );

    await expectLater(
      manager.downloadModel(),
      throwsA(
        isA<ReliableDownloadException>().having(
          (e) => e.kind,
          'kind',
          ReliableDownloadFailure.httpStatus,
        ),
      ),
    );
    final leftovers = root.listSync().whereType<File>();
    expect(leftovers, isEmpty);
  });

  test('预置 .part → 使用 Range 续传并在安装后清理残留', () async {
    final archive = _buildArchive();
    final sha = sha256.convert(archive).toString();
    final partialLength = archive.length ~/ 2;
    final partial = File(p.join(root.path, '_download_test-model.tar.gz.part'));
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(archive.sublist(0, partialLength));
    await File(
      '${partial.path}.meta.json',
    ).writeAsString('{"identityKey":"$sha","downloadedBytes":$partialLength}');
    final adapter = _RangeArchiveAdapter(archive);
    final dio = Dio()..httpClientAdapter = adapter;
    final manager = KokoroModelManager(
      dio: dio,
      baseUrlOverride: 'http://mock.local',
      spec: KokoroModelSpec(
        variant: KokoroModelVariant.int8,
        id: 'test-model',
        archivePath: 'tts/test.tar.gz',
        sha256: sha,
        modelFileName: 'model.int8.onnx',
        estimatedDownloadBytes: archive.length,
      ),
      modelsRootResolver: () async => root.path,
    );

    await manager.downloadModel();

    expect(adapter.requests.single['Range'], 'bytes=$partialLength-');
    expect(await manager.isModelDownloaded(), isTrue);
    expect(partial.existsSync(), isFalse);
    expect(File('${partial.path}.meta.json').existsSync(), isFalse);
  });

  test('安装失败不会覆盖已有模型，staging 会清理', () async {
    final valid = _buildArchive();
    final manager = _manager(root, valid);
    await manager.downloadModel();
    final oldModel = File(p.join(await manager.modelDir(), 'model.int8.onnx'));
    final invalid = _buildArchive(includeDataDir: false);
    final invalidManager = _manager(
      root,
      invalid,
      sha: sha256.convert(invalid).toString(),
    );

    await expectLater(
      invalidManager.downloadModel(),
      throwsA(isA<StateError>()),
    );

    expect(oldModel.existsSync(), isTrue);
    expect(await manager.isModelDownloaded(), isTrue);
    expect(
      root.listSync().whereType<Directory>().where(
        (directory) => p.basename(directory.path).startsWith('_staging_'),
      ),
      isEmpty,
    );
  });

  test('deleteModel 清理续传归档、元数据和 staging', () async {
    final manager = _manager(root, _buildArchive());
    final archive = File(p.join(root.path, '_download_test-model.tar.gz'));
    final partial = File('${archive.path}.part');
    final meta = File('${partial.path}.meta.json');
    final staging = Directory(p.join(root.path, '_staging_test-model_old'));
    await staging.create(recursive: true);
    await archive.writeAsBytes([1]);
    await partial.writeAsBytes([1, 2]);
    await meta.writeAsString('{}');

    await manager.deleteModel();

    expect(archive.existsSync(), isFalse);
    expect(partial.existsSync(), isFalse);
    expect(meta.existsSync(), isFalse);
    expect(staging.existsSync(), isFalse);
  });

  test('解包后缺关键文件（无 espeak-ng-data）→ 抛错', () async {
    final archive = _buildArchive(includeDataDir: false);
    final manager = _manager(root, archive);

    await expectLater(manager.downloadModel(), throwsA(isA<StateError>()));
    expect(await manager.isModelDownloaded(), isFalse);
  });

  test('deleteModel 删除本地目录', () async {
    final archive = _buildArchive();
    final manager = _manager(root, archive);
    await manager.downloadModel();
    expect(await manager.isModelDownloaded(), isTrue);

    await manager.deleteModel();
    expect(await manager.isModelDownloaded(), isFalse);
    expect(await manager.modelLocalSize(), 0);
  });

  test('modelLocalSize 在下载后大于 0', () async {
    final archive = _buildArchive();
    final manager = _manager(root, archive);
    await manager.downloadModel();
    expect(await manager.modelLocalSize(), greaterThan(0));
  });
}

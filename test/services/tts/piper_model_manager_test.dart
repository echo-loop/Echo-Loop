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
import 'package:echo_loop/services/tts/piper_model_manager.dart';
import 'package:echo_loop/services/tts/piper_model_catalog.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

/// 返回预置归档字节的 mock dio adapter（任何 .tar.gz 请求都返回该字节）。
class _MockArchiveAdapter implements HttpClientAdapter {
  _MockArchiveAdapter(this.payload, {this.requestUris});
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

/// 构造含关键文件的 tar.gz：`<id>.onnx` + `<id>.onnx.json`（应被忽略）+ tokens +
/// espeak-ng-data。Piper 单说话人，无 voices.bin。
List<int> _buildArchive({
  String onnxName = 'en_US-amy-medium.onnx',
  bool includeDataDir = true,
}) {
  final archive = Archive();
  archive.add(ArchiveFile(onnxName, 8, List<int>.filled(8, 1)));
  // 同名 json 元数据：必须不被当作模型挑中。
  archive.add(ArchiveFile('$onnxName.json', 4, List<int>.filled(4, 9)));
  archive.add(ArchiveFile('tokens.txt', 3, List<int>.filled(3, 3)));
  if (includeDataDir) {
    archive.add(
      ArchiveFile('espeak-ng-data/phontab', 5, List<int>.filled(5, 4)),
    );
  }
  final tar = TarEncoder().encodeBytes(archive);
  return GZipEncoder().encodeBytes(tar);
}

PiperModelManager _manager(
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
  return PiperModelManager(
    dio: dio,
    baseUrlOverride: endpointRouter == null ? 'http://mock.local' : null,
    endpointRouter: endpointRouter,
    voice: PiperVoice(
      id: 'en_US-amy-medium',
      displayName: 'Amy',
      accent: TtsAccent.us,
      isFemale: true,
      archivePath: 'tts/vits-piper-en_US-amy-medium.tar.gz',
      sha256: sha ?? sha256.convert(archive).toString(),
      estimatedDownloadBytes: 1024,
    ),
    modelsRootResolver: () async => root.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('piper-model-test');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('下载 → 校验 → 解包：onnx/tokens/espeak-ng-data 就位，忽略 .onnx.json', () async {
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
    expect(
      requestedUris.single.path,
      '/model/tts/vits-piper-en_US-amy-medium.tar.gz',
    );
    expect(await manager.isModelDownloaded(), isTrue);
    final paths = await manager.piperConfigPaths();
    expect(p.basename(paths.model), 'en_US-amy-medium.onnx');
    expect(File(paths.model).existsSync(), isTrue);
    expect(File(paths.tokens).existsSync(), isTrue);
    expect(p.basename(paths.dataDir), 'espeak-ng-data');
    expect(progresses.last, 1.0);
  });

  test('SHA-256 不匹配 → 抛错且模型未安装，临时归档已清理', () async {
    final archive = _buildArchive();
    final manager = _manager(root, archive, sha: 'deadbeef');

    await expectLater(manager.downloadModel(), throwsA(isA<StateError>()));
    expect(await manager.isModelDownloaded(), isFalse);
    final leftovers = root.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.tar.gz'),
    );
    expect(leftovers, isEmpty);
  });

  test('归档下载网络失败 → 抛结构化异常且不留 .part 残留', () async {
    final dio = Dio();
    dio.httpClientAdapter = _AlwaysNotFoundAdapter();
    final manager = PiperModelManager(
      dio: dio,
      baseUrlOverride: 'http://mock.local',
      voice: const PiperVoice(
        id: 'en_US-amy-medium',
        displayName: 'Amy',
        accent: TtsAccent.us,
        isFemale: true,
        archivePath: 'tts/vits-piper-en_US-amy-medium.tar.gz',
        sha256: 'irrelevant',
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
    final partial = File(
      p.join(root.path, '_download_en_US-amy-medium.tar.gz.part'),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(archive.sublist(0, partialLength));
    await File(
      '${partial.path}.meta.json',
    ).writeAsString('{"identityKey":"$sha","downloadedBytes":$partialLength}');
    final adapter = _RangeArchiveAdapter(archive);
    final dio = Dio()..httpClientAdapter = adapter;
    final manager = PiperModelManager(
      dio: dio,
      baseUrlOverride: 'http://mock.local',
      voice: PiperVoice(
        id: 'en_US-amy-medium',
        displayName: 'Amy',
        accent: TtsAccent.us,
        isFemale: true,
        archivePath: 'tts/vits-piper-en_US-amy-medium.tar.gz',
        sha256: sha,
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
    final oldModel = File(
      p.join(await manager.modelDir(), 'en_US-amy-medium.onnx'),
    );
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
    final archive = File(
      p.join(root.path, '_download_en_US-amy-medium.tar.gz'),
    );
    final partial = File('${archive.path}.part');
    final meta = File('${partial.path}.meta.json');
    final staging = Directory(
      p.join(root.path, '_staging_en_US-amy-medium_old'),
    );
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

  test('sha256 为空串（开发期占位）→ 跳过校验，仍可安装', () async {
    final archive = _buildArchive();
    final manager = _manager(root, archive, sha: '');
    await manager.downloadModel();
    expect(await manager.isModelDownloaded(), isTrue);
  });

  test('解包后缺 espeak-ng-data → 抛错', () async {
    final archive = _buildArchive(includeDataDir: false);
    final manager = _manager(root, archive);
    await expectLater(manager.downloadModel(), throwsA(isA<StateError>()));
    expect(await manager.isModelDownloaded(), isFalse);
  });

  test('deleteModel 删除本地目录；modelLocalSize 归零', () async {
    final manager = _manager(root, _buildArchive());
    await manager.downloadModel();
    expect(await manager.modelLocalSize(), greaterThan(0));
    await manager.deleteModel();
    expect(await manager.isModelDownloaded(), isFalse);
    expect(await manager.modelLocalSize(), 0);
  });
}

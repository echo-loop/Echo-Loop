import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.payload, {this.requestUris});
  final List<int> payload;
  final List<Uri>? requestUris;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    requestUris?.add(options.uri);
    return ResponseBody(
      Stream.value(Uint8List.fromList(payload)),
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

class _RangeAdapter implements HttpClientAdapter {
  _RangeAdapter(this.payload);

  final List<int> payload;
  final requestHeaders = <Map<String, Object?>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    requestHeaders.add(Map<String, Object?>.from(options.headers));
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

void main() {
  test('发布目录使用 v1 归档及实测摘要', () {
    expect(
      asrModelResourceCatalog.values.every(
        (spec) => spec.archivePath.endsWith('-v1.zip'),
      ),
      isTrue,
    );
    expect(
      asrModelResourceCatalog['whisper-base-en-int8']!.sha256,
      'ff8af5965f6d017ad317e9a7c023c3f457259cef3de33e543c2fa87338a32fbb',
    );
  });

  test('归档安装写入清单并扁平化顶层目录', () async {
    final root = await Directory.systemTemp.createTemp('asr-archive-test');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory(p.join(root.path, 'source', 'test-model-v1'));
    await source.create(recursive: true);
    await File(p.join(source.path, 'encoder.onnx')).writeAsBytes([1, 2, 3]);
    final archive = File(p.join(root.path, 'test-model.zip'));
    final encoder = ZipFileEncoder();
    encoder.create(archive.path);
    await encoder.addFile(
      File(p.join(source.path, 'encoder.onnx')),
      'test-model-v1/encoder.onnx',
    );
    await encoder.close();
    final payload = await archive.readAsBytes();
    final requestedUris = <Uri>[];
    final dio = Dio()
      ..httpClientAdapter = _Adapter(payload, requestUris: requestedUris);
    final progress = <double>[];
    final manager = AsrModelManager(
      dio: dio,
      endpointRouter: await _routerWithChinaCdn(),
      modelsRootResolver: () async => p.join(root.path, 'models'),
      resourceRegistryOverride: {
        'test-model': AsrModelResourceSpec(
          id: 'test-model',
          archivePath: 'asr/test-model.zip',
          sha256: sha256.convert(payload).toString(),
          estimatedDownloadBytes: payload.length,
          requiredFiles: const ['encoder.onnx'],
        ),
      },
    );
    final staleStaging = Directory(
      p.join(root.path, 'models', '_staging_test-model_old'),
    );
    await staleStaging.create(recursive: true);
    await File(p.join(staleStaging.path, 'stale.tmp')).writeAsString('stale');
    await manager.downloadModel(
      'test-model',
      onProgress: (value) => progress.add(value.progress),
    );
    expect(requestedUris.single.host, 'china-cdn.example');
    expect(requestedUris.single.path, '/model/asr/test-model.zip');
    final modelDir = await manager.modelDir('test-model');
    expect(File(p.join(modelDir, 'encoder.onnx')).existsSync(), isTrue);
    expect(
      File(p.join(modelDir, 'test-model', 'encoder.onnx')).existsSync(),
      isFalse,
    );
    expect(await manager.isModelDownloaded('test-model'), isTrue);
    expect(progress, isNotEmpty);
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }
    expect(staleStaging.existsSync(), isFalse);
    final remainingEntities = await Directory(
      p.join(root.path, 'models'),
    ).list().toList();
    expect(
      remainingEntities.where(
        (entity) => p.basename(entity.path).startsWith('_staging_'),
      ),
      isEmpty,
    );
    expect(
      (await manager.readInstallManifest('test-model'))!.resourceId,
      'test-model',
    );
    manager.dispose();
  });

  test('保留的归档 part 使用 Range 续传，并在安装后清理残留', () async {
    final root = await Directory.systemTemp.createTemp('asr-resume-test');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory(p.join(root.path, 'source', 'test-model-v1'));
    await source.create(recursive: true);
    await File(p.join(source.path, 'encoder.onnx')).writeAsBytes([1, 2, 3]);
    final archive = File(p.join(root.path, 'test-model.zip'));
    final encoder = ZipFileEncoder()..create(archive.path);
    await encoder.addFile(
      File(p.join(source.path, 'encoder.onnx')),
      'test-model-v1/encoder.onnx',
    );
    await encoder.close();
    final payload = await archive.readAsBytes();
    final sha = sha256.convert(payload).toString();
    final modelsRoot = Directory(p.join(root.path, 'models'));
    await modelsRoot.create(recursive: true);
    final partialLength = payload.length ~/ 2;
    final partial = File(
      p.join(modelsRoot.path, '_download_test-model.zip.part'),
    );
    await partial.writeAsBytes(payload.sublist(0, partialLength));
    await File(
      '${partial.path}.meta.json',
    ).writeAsString('{"identityKey":"$sha","downloadedBytes":$partialLength}');
    final adapter = _RangeAdapter(payload);
    final manager = AsrModelManager(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrlOverride: 'http://mock.local',
      modelsRootResolver: () async => modelsRoot.path,
      resourceRegistryOverride: {
        'test-model': AsrModelResourceSpec(
          id: 'test-model',
          archivePath: 'asr/test-model.zip',
          sha256: sha,
          estimatedDownloadBytes: payload.length,
          requiredFiles: const ['encoder.onnx'],
        ),
      },
    );

    await manager.downloadModel('test-model');

    expect(adapter.requestHeaders.single['Range'], 'bytes=$partialLength-');
    expect(await manager.isModelDownloaded('test-model'), isTrue);
    expect(partial.existsSync(), isFalse);
    expect(File('${partial.path}.meta.json').existsSync(), isFalse);
    manager.dispose();
  });

  test('删除模型和 VAD 半成品会在用户取消后清理', () async {
    final root = await Directory.systemTemp.createTemp('asr-cancel-test');
    addTearDown(() => root.delete(recursive: true));
    final manager = AsrModelManager(
      modelsRootResolver: () async => root.path,
      resourceRegistryOverride: const {},
    );
    final partial = File(p.join(root.path, '_download_test-model.zip.part'));
    final vadPartial = File(
      p.join(root.path, '_download_$vadModelId.zip.part'),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes([1, 2, 3]);
    await File('${partial.path}.meta.json').writeAsString('{}');
    await vadPartial.writeAsBytes([4, 5, 6]);
    await File('${vadPartial.path}.meta.json').writeAsString('{}');

    await manager.deleteModel('test-model');
    await manager.discardPartialDownload(vadModelId);

    expect(partial.existsSync(), isFalse);
    expect(File('${partial.path}.meta.json').existsSync(), isFalse);
    expect(vadPartial.existsSync(), isFalse);
    expect(File('${vadPartial.path}.meta.json').existsSync(), isFalse);
    manager.dispose();
  });

  test('缺少安装清单的旧目录不会被当作已安装', () async {
    final root = await Directory.systemTemp.createTemp('asr-manifest-test');
    addTearDown(() => root.delete(recursive: true));
    final manager = AsrModelManager(
      modelsRootResolver: () async => root.path,
      resourceRegistryOverride: {
        'test-model': const AsrModelResourceSpec(
          id: 'test-model',
          archivePath: 'asr/test-model.zip',
          sha256: 'a',
          estimatedDownloadBytes: 1,
          requiredFiles: ['encoder.onnx'],
        ),
      },
    );
    final dir = Directory(await manager.modelDir('test-model'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'encoder.onnx')).writeAsBytes([1]);
    expect(await manager.isModelDownloaded('test-model'), isFalse);
    manager.dispose();
  });

  test('归档文件直接位于根目录时也能完成安装', () async {
    final root = await Directory.systemTemp.createTemp('asr-root-archive-test');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory(p.join(root.path, 'source'));
    await source.create(recursive: true);
    await File(p.join(source.path, 'encoder.onnx')).writeAsBytes([1, 2, 3]);
    final archive = File(p.join(root.path, 'test-model.zip'));
    final encoder = ZipFileEncoder()..create(archive.path);
    await encoder.addFile(
      File(p.join(source.path, 'encoder.onnx')),
      'encoder.onnx',
    );
    await encoder.close();
    final payload = await archive.readAsBytes();
    final dio = Dio()..httpClientAdapter = _Adapter(payload);
    final manager = AsrModelManager(
      dio: dio,
      baseUrlOverride: 'http://mock.local',
      modelsRootResolver: () async => p.join(root.path, 'models'),
      resourceRegistryOverride: {
        'test-model': AsrModelResourceSpec(
          id: 'test-model',
          archivePath: 'asr/test-model.zip',
          sha256: sha256.convert(payload).toString(),
          estimatedDownloadBytes: payload.length,
          requiredFiles: const ['encoder.onnx'],
        ),
      },
    );
    await manager.downloadModel('test-model');
    expect(
      File(
        p.join(await manager.modelDir('test-model'), 'encoder.onnx'),
      ).existsSync(),
      isTrue,
    );
    manager.dispose();
  });

  test('归档顶层目录改为 v2 时无需修改资源配置', () async {
    final root = await Directory.systemTemp.createTemp('asr-v2-archive-test');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory(p.join(root.path, 'source', 'test-model-v2'));
    await source.create(recursive: true);
    await File(p.join(source.path, 'encoder.onnx')).writeAsBytes([4, 5, 6]);
    final archive = File(p.join(root.path, 'test-model-v2.zip'));
    final encoder = ZipFileEncoder()..create(archive.path);
    await encoder.addFile(
      File(p.join(source.path, 'encoder.onnx')),
      'test-model-v2/encoder.onnx',
    );
    await encoder.close();
    final payload = await archive.readAsBytes();
    final manager = AsrModelManager(
      dio: Dio()..httpClientAdapter = _Adapter(payload),
      baseUrlOverride: 'http://mock.local',
      modelsRootResolver: () async => p.join(root.path, 'models'),
      resourceRegistryOverride: {
        'test-model': AsrModelResourceSpec(
          id: 'test-model',
          archivePath: 'asr/test-model-v2.zip',
          sha256: sha256.convert(payload).toString(),
          estimatedDownloadBytes: payload.length,
          requiredFiles: const ['encoder.onnx'],
        ),
      },
    );
    await manager.downloadModel('test-model');
    expect(
      File(
        p.join(await manager.modelDir('test-model'), 'encoder.onnx'),
      ).existsSync(),
      isTrue,
    );
    manager.dispose();
  });
}

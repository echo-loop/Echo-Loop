/// ASR 模型归档下载、原子安装和缓存管理。
library;

export 'asr_model_catalog.dart';

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';
import '../reliable_http_downloader.dart';
import '../resource_install_manifest.dart';
import 'asr_archive_installer.dart';
import 'asr_model_catalog.dart';
import '../runtime_endpoint_router.dart';
import 'offline_asr_engine.dart';

/// 旧版逐文件安装布局的文件元数据，仅用于迁移和兼容校验。
class AsrModelFileSpec {
  const AsrModelFileSpec({required this.path, required this.sha256});
  final String path;
  final String sha256;
}

/// 旧版逐文件安装布局的清单，仅用于迁移既有缓存。
class AsrModelManifest {
  const AsrModelManifest({required this.files});
  final List<AsrModelFileSpec> files;
}

/// 旧缓存完整性清单。新安装不再以单文件哈希作为状态真相。
const defaultLegacyModelFileRegistry = <String, AsrModelManifest>{
  vadModelId: AsrModelManifest(
    files: [
      AsrModelFileSpec(
        path: 'silero_vad.onnx',
        sha256:
            '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6',
      ),
    ],
  ),
  'whisper-tiny-en-int8': AsrModelManifest(
    files: [
      AsrModelFileSpec(
        path: 'tiny.en-encoder.int8.onnx',
        sha256:
            '0ce578b827c94a961aacb8fa14b02f096504b337e5c94be37c36238cbe3e8bc6',
      ),
      AsrModelFileSpec(
        path: 'tiny.en-decoder.int8.onnx',
        sha256:
            '06c0e6ff6348d427e51839219d1c886c18cfdf411e629e33f5e1679bff9c1527',
      ),
      AsrModelFileSpec(
        path: 'tiny.en-tokens.txt',
        sha256:
            '306cd27f03c1a714eca7108e03d66b7dc042abe8c258b44c199a7ed9838dd930',
      ),
    ],
  ),
  'whisper-base-en-int8': AsrModelManifest(
    files: [
      AsrModelFileSpec(
        path: 'base.en-encoder.int8.onnx',
        sha256:
            'ef6b936f4c9b1d90a3b68634b60c4ed8576b26172b33c2535ec0e933c9edb823',
      ),
      AsrModelFileSpec(
        path: 'base.en-decoder.int8.onnx',
        sha256:
            'f7162ad6db2dbef16cfaeaa7f945b9d7dd9c1b8d472f6aca82f2273d185e4d41',
      ),
      AsrModelFileSpec(
        path: 'base.en-tokens.txt',
        sha256:
            '306cd27f03c1a714eca7108e03d66b7dc042abe8c258b44c199a7ed9838dd930',
      ),
    ],
  ),
  'whisper-small-en-int8': AsrModelManifest(
    files: [
      AsrModelFileSpec(
        path: 'small.en-encoder.int8.onnx',
        sha256:
            '8bdac288f369aa94ee2194059238c465ed82ea9d47ee8fa4a8c0a891873e462f',
      ),
      AsrModelFileSpec(
        path: 'small.en-decoder.int8.onnx',
        sha256:
            '710ccf890e10f3faa15f51ec346081a2723c9f3adb6e4da81c6573a5a6f877fb',
      ),
      AsrModelFileSpec(
        path: 'small.en-tokens.txt',
        sha256:
            '306cd27f03c1a714eca7108e03d66b7dc042abe8c258b44c199a7ed9838dd930',
      ),
    ],
  ),
};

final List<AsrModelInfo> availableModels = [
  const AsrModelInfo(
    id: 'whisper-tiny-en-int8',
    displayName: 'Echo Loop AI (Fast)',
    type: AsrModelType.whisper,
  ),
  const AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Echo Loop AI (Balanced)',
    type: AsrModelType.whisper,
  ),
  const AsrModelInfo(
    id: 'whisper-small-en-int8',
    displayName: 'Echo Loop AI (Accurate)',
    type: AsrModelType.whisper,
  ),
];

enum AsrModelDownloadStatus { notDownloaded, downloading, downloaded, failed }

class AsrModelDownloadProgress {
  const AsrModelDownloadProgress({
    required this.status,
    this.progress = 0,
    this.error,
  });
  final AsrModelDownloadStatus status;
  final double progress;
  final String? error;
  static const notDownloaded = AsrModelDownloadProgress(
    status: AsrModelDownloadStatus.notDownloaded,
  );
}

/// 统一使用归档校验、staging 和原子替换的 ASR 安装器。
class AsrModelManager {
  AsrModelManager({
    Dio? dio,
    this.baseUrlOverride,
    RuntimeEndpointRouter? endpointRouter,
    Map<String, AsrModelResourceSpec>? resourceRegistryOverride,
    this.modelsRootResolver,
  }) : _endpointRouter = endpointRouter ?? runtimeEndpointRouter,
       resourceRegistry = resourceRegistryOverride ?? asrModelResourceCatalog {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
    _downloader = DioReliableHttpDownloader(dio: _dio);
    _installer = AsrArchiveInstaller(_downloader);
  }

  late final Dio _dio;
  late final ReliableHttpDownloader _downloader;
  late final AsrArchiveInstaller _installer;
  final String? baseUrlOverride;
  final RuntimeEndpointRouter _endpointRouter;
  final Map<String, AsrModelResourceSpec> resourceRegistry;
  final Future<String> Function()? modelsRootResolver;

  Future<String> get _modelsRoot async {
    final resolver = modelsRootResolver;
    if (resolver != null) return resolver();
    return p.join((await getApplicationSupportDirectory()).path, 'asr-models');
  }

  Future<String> modelDir(String modelId) async =>
      p.join(await _modelsRoot, modelId);

  Future<ResourceInstallManifest?> readInstallManifest(String modelId) async {
    final spec = resourceRegistry[modelId];
    if (spec == null) return null;
    final directory = Directory(await modelDir(modelId));
    try {
      final manifest = await readResourceInstallManifest(directory);
      if (manifest == null || manifest.resourceId != modelId) return null;
      for (final requiredFile in spec.requiredFiles) {
        if (!File(p.join(directory.path, requiredFile)).existsSync()) {
          return null;
        }
      }
      return manifest;
    } on FormatException {
      return null;
    }
  }

  /// 资源自身及其 catalog 声明的共享依赖均完整时才可供引擎使用。
  Future<bool> isModelDownloaded(String modelId) async {
    final spec = resourceRegistry[modelId];
    if (spec == null || await readInstallManifest(modelId) == null) {
      return false;
    }
    for (final dependency in spec.dependencies) {
      if (!await isModelDownloaded(dependency)) return false;
    }
    return true;
  }

  Future<int> modelLocalSize(String modelId) async =>
      (await readInstallManifest(modelId))?.resourceSize ?? 0;

  /// 下载、归档哈希校验、解压关键文件校验后才原子替换当前安装。
  Future<String> downloadModel(
    String modelId, {
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final spec = resourceRegistry[modelId];
    if (spec == null) throw ArgumentError('Unknown model: $modelId');
    // 模型本体与共享 VAD 分开安装；VAD 缺失时不能触发模型本体重复下载。
    if (await readInstallManifest(modelId) != null) {
      onProgress?.call(
        const AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloaded,
          progress: 1,
        ),
      );
      return modelDir(modelId);
    }
    final root = Directory(await _modelsRoot);
    final target = Directory(await modelDir(modelId));
    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloading,
      ),
    );
    await _installer.install(
      root: root,
      target: target,
      resourceId: modelId,
      uri: baseUrlOverride == null
          ? _endpointRouter.modelCdnUri('/model/${spec.archivePath}')
          : Uri.parse('$baseUrlOverride/model/${spec.archivePath}'),
      expectedSha256: spec.sha256,
      cancelToken: cancelToken,
      onProgress: (value) => onProgress?.call(
        AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: value,
        ),
      ),
      onInstalling: () => onProgress?.call(
        const AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: 1,
        ),
      ),
      extractAndValidate: (archive, staging) =>
          _extractAndValidate(archive, staging, spec),
    );
    final result = await validateModel(modelId);
    if (!result.isValid) throw StateError(result.describe());
    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloaded,
        progress: 1,
      ),
    );
    return target.path;
  }

  Future<AsrModelValidationResult> validateModel(String modelId) async =>
      (await readInstallManifest(modelId)) == null
      ? AsrModelValidationResult(
          modelId: modelId,
          isValid: false,
          reason: 'Missing or invalid install manifest',
        )
      : AsrModelValidationResult(modelId: modelId, isValid: true);

  /// 校验旧逐文件目录，用于把历史可用缓存转换为新的安装清单。
  Future<bool> validateLegacyModelFiles(String modelId) async {
    final legacy = defaultLegacyModelFileRegistry[modelId];
    if (legacy == null) return false;
    final dir = Directory(await modelDir(modelId));
    for (final spec in legacy.files) {
      final file = File(p.join(dir.path, spec.path));
      if (!file.existsSync() || await _sha256(file) != spec.sha256) {
        return false;
      }
    }
    return true;
  }

  Future<void> deleteModel(String modelId) async {
    final dir = Directory(await modelDir(modelId));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await discardPartialDownload(modelId);
  }

  /// 丢弃指定资源的续传缓存，但不影响已经安装完成的模型目录。
  ///
  /// 下载模型时用户主动取消，需要清理模型本体和共享 VAD 两类资源的半成品。
  Future<void> discardPartialDownload(String modelId) async {
    await _installer.discardPartial(
      root: Directory(await _modelsRoot),
      resourceId: modelId,
    );
  }

  Future<void> cleanupUnknownModels() async {
    final root = Directory(await _modelsRoot);
    if (!root.existsSync()) return;
    await for (final entity in root.list()) {
      if (entity is Directory &&
          !resourceRegistry.containsKey(p.basename(entity.path))) {
        AppLogger.log('ASRModel', '清理旧模型: ${p.basename(entity.path)}');
        await entity.delete(recursive: true);
      }
    }
  }

  AsrModelInfo recommendModel({int ramBytes = 0}) =>
      availableModels.firstWhere((model) => model.id == 'whisper-base-en-int8');
  void dispose() => _dio.close();

  Future<void> _extractAndValidate(
    File archive,
    Directory staging,
    AsrModelResourceSpec spec,
  ) async {
    await staging.create(recursive: true);
    await extractFileToDisk(archive.path, staging.path);
    final topLevelEntities = await staging.list(followLinks: false).toList();
    final topLevelDirectories = topLevelEntities
        .whereType<Directory>()
        .toList();
    final topLevelFiles = topLevelEntities.whereType<File>().toList();
    final packageRoot = topLevelFiles.isEmpty && topLevelDirectories.length == 1
        ? topLevelDirectories.single
        : staging;

    for (final file in spec.requiredFiles) {
      if (!File(p.join(packageRoot.path, file)).existsSync()) {
        throw StateError('ASR archive missing required file: $file');
      }
    }

    if (packageRoot.path != staging.path) {
      // 归档版本目录名不参与安装；只把其内容展开到资源 staging 根目录。
      await for (final entity in packageRoot.list(followLinks: false)) {
        await entity.rename(p.join(staging.path, p.basename(entity.path)));
      }
      await packageRoot.delete();
    }
  }

  Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}

class AsrModelValidationResult {
  const AsrModelValidationResult({
    required this.modelId,
    required this.isValid,
    this.reason,
  });
  final String modelId;
  final bool isValid;
  final String? reason;
  String describe() => isValid
      ? 'Model validation passed: $modelId'
      : 'Downloaded model failed integrity check: $modelId | reason=$reason';
}

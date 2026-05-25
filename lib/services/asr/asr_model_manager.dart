/// ASR 模型下载、校验、缓存管理。
///
/// 负责从远程下载模型文件到本地，校验完整性，
/// 管理缓存目录。不依赖具体引擎实现。
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';
import 'offline_asr_engine.dart';

// ---------------------------------------------------------------------------
// 模型注册表
// ---------------------------------------------------------------------------

/// CDN 基础 URL。
const _cdnBase = 'https://cdn.echo-loop.top';

/// 单个模型文件的固定元数据。
class AsrModelFileSpec {
  final String path;
  final String sha256;

  const AsrModelFileSpec({required this.path, required this.sha256});
}

/// 模型文件清单：每个模型需要下载的文件及其固定校验信息。
class AsrModelManifest {
  final List<AsrModelFileSpec> files;
  const AsrModelManifest({required this.files});
}

/// Silero VAD 模型 ID。
///
/// VAD 模型是所有 whisper 模型的共享依赖，用于转录前裁剪静音段。
const vadModelId = 'silero-vad';

/// 各模型的文件清单。
///
/// 下载 URL: `$_cdnBase/model/$modelId/$filename`
const _defaultModelFileRegistry = <String, AsrModelManifest>{
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

/// 所有可用模型的元信息。
final List<AsrModelInfo> availableModels = [
  const AsrModelInfo(
    id: 'whisper-tiny-en-int8',
    displayName: 'Whisper Tiny.en',
    type: AsrModelType.whisper,
  ),
  const AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
  ),
  const AsrModelInfo(
    id: 'whisper-small-en-int8',
    displayName: 'Whisper Small.en',
    type: AsrModelType.whisper,
  ),
];

// ---------------------------------------------------------------------------
// 模型下载状态
// ---------------------------------------------------------------------------

/// 模型下载状态。
enum AsrModelDownloadStatus {
  /// 未下载。
  notDownloaded,

  /// 下载中。
  downloading,

  /// 已下载。
  downloaded,

  /// 下载失败。
  failed,
}

/// 模型下载进度。
class AsrModelDownloadProgress {
  /// 下载状态。
  final AsrModelDownloadStatus status;

  /// 下载进度 0.0 ~ 1.0。
  final double progress;

  /// 错误信息（仅 [AsrModelDownloadStatus.failed] 时有值）。
  final String? error;

  const AsrModelDownloadProgress({
    required this.status,
    this.progress = 0,
    this.error,
  });

  /// 未下载的初始状态。
  static const notDownloaded = AsrModelDownloadProgress(
    status: AsrModelDownloadStatus.notDownloaded,
  );
}

// ---------------------------------------------------------------------------
// AsrModelManager
// ---------------------------------------------------------------------------

/// ASR 模型管理器。
///
/// 职责：模型下载、本地缓存管理、完整性校验、设备推荐。
class AsrModelManager {
  final Dio _dio;

  /// 可选的下载基地址覆盖，仅用于测试。
  final String? baseUrlOverride;

  /// 可选的模型清单覆盖，仅用于测试。
  final Map<String, AsrModelManifest> modelRegistryOverride;

  AsrModelManager({
    Dio? dio,
    this.baseUrlOverride,
    Map<String, AsrModelManifest>? modelRegistryOverride,
  }) : _dio = dio ?? Dio(),
       modelRegistryOverride =
           modelRegistryOverride ?? _defaultModelFileRegistry;

  /// 模型存储根目录。
  Future<String> get _modelsRoot async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'asr-models');
  }

  /// 获取指定模型的本地目录路径。
  Future<String> modelDir(String modelId) async {
    final root = await _modelsRoot;
    return p.join(root, modelId);
  }

  /// 检查模型是否已下载且完整。
  Future<bool> isModelDownloaded(String modelId) async {
    final result = await validateModel(modelId);
    return result.isValid;
  }

  /// 获取模型本地占用空间（字节）。
  Future<int> modelLocalSize(String modelId) async {
    final dir = Directory(await modelDir(modelId));
    if (!dir.existsSync()) return 0;

    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// 下载模型，通过 [onProgress] 回调报告进度。
  ///
  /// 下载过程中可通过 [cancelToken] 取消。
  /// 返回模型本地目录路径。
  Future<String> downloadModel(
    String modelId, {
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final manifest = modelRegistryOverride[modelId];
    if (manifest == null) {
      throw ArgumentError('Unknown model: $modelId');
    }

    final dir = await modelDir(modelId);
    await Directory(dir).create(recursive: true);

    final baseUrl = baseUrlOverride ?? _cdnBase;
    AppLogger.log('ASRModel', '┌ downloadModel modelId=$modelId dir=$dir');
    AppLogger.log('ASRModel', '│ baseUrl=$baseUrl');

    final totalFileCount = manifest.files.length;
    var completedFileCount = 0;

    // 预处理已存在文件：哈希符合清单则视为完成，否则删除重下。
    for (final file in manifest.files) {
      final localFile = File(p.join(dir, file.path));
      if (!localFile.existsSync()) continue;
      if (await _matchesExpectedHash(localFile, file.sha256)) {
        completedFileCount++;
        continue;
      }
      AppLogger.log(
        'ASRModel',
        '│ remove stale file=${file.path} (hash mismatch)',
      );
      await localFile.delete();
    }

    void reportProgress([double currentFileProgress = 0]) {
      final progress = totalFileCount > 0
          ? (completedFileCount + currentFileProgress) / totalFileCount
          : 0.0;
      onProgress?.call(
        AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: progress.clamp(0.0, 1.0),
        ),
      );
    }

    reportProgress();

    // 逐个下载缺失的文件。
    for (final file in manifest.files) {
      final localFile = File(p.join(dir, file.path));
      if (localFile.existsSync()) continue;

      final tempFile = File('${localFile.path}.tmp');
      try {
        final downloadUrl = '$baseUrl/model/$modelId/${file.path}';
        AppLogger.log('ASRModel', '│ downloading file=${file.path}');
        await _dio.download(
          downloadUrl,
          tempFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            final fileFraction = total > 0 ? received / total : 0.0;
            reportProgress(fileFraction);
          },
        );
        await tempFile.rename(localFile.path);
        completedFileCount++;
        AppLogger.log(
          'ASRModel',
          '│ file done=${file.path} size=${localFile.lengthSync()}',
        );
      } catch (e) {
        // 清理临时文件。
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
        AppLogger.log(
          'ASRModel',
          '└ downloadModel failed file=${file.path} error=$e',
        );
        rethrow;
      }
    }

    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloaded,
        progress: 1.0,
      ),
    );
    AppLogger.log('ASRModel', '└ downloadModel done modelId=$modelId dir=$dir');

    final validation = await validateModel(modelId);
    if (!validation.isValid) {
      throw StateError(validation.describe());
    }

    return dir;
  }

  /// 校验本地模型文件是否和固定清单完全一致。
  Future<AsrModelValidationResult> validateModel(String modelId) async {
    final manifest = modelRegistryOverride[modelId];
    if (manifest == null) {
      return AsrModelValidationResult(
        modelId: modelId,
        isValid: false,
        reason: 'Unknown model',
      );
    }

    final dir = await modelDir(modelId);
    for (final file in manifest.files) {
      final localFile = File(p.join(dir, file.path));
      if (!localFile.existsSync()) {
        return AsrModelValidationResult(
          modelId: modelId,
          isValid: false,
          reason: 'Missing file',
          filePath: file.path,
        );
      }

      final actualSha256 = await _computeSha256(localFile);
      if (actualSha256 != file.sha256) {
        return AsrModelValidationResult(
          modelId: modelId,
          isValid: false,
          reason: 'SHA-256 mismatch',
          filePath: file.path,
          expectedSha256: file.sha256,
          actualSha256: actualSha256,
        );
      }
    }

    return AsrModelValidationResult(modelId: modelId, isValid: true);
  }

  /// 删除本地模型缓存。
  Future<void> deleteModel(String modelId) async {
    final dir = Directory(await modelDir(modelId));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// 清理不再使用的旧模型目录。
  ///
  /// 保留 [keepModelId] 对应的目录，删除其他所有模型目录。
  /// 在启动时调用，防止推荐模型变更后旧文件残留。
  Future<void> cleanupUnusedModels(String keepModelId) async {
    final root = Directory(await _modelsRoot);
    if (!root.existsSync()) return;

    await for (final entity in root.list()) {
      if (entity is Directory) {
        final dirName = p.basename(entity.path);
        // 保留当前使用的 whisper 模型和共享的 VAD 模型。
        if (dirName != keepModelId && dirName != vadModelId) {
          AppLogger.log('ASRModel', '🗑 清理旧模型: $dirName');
          await entity.delete(recursive: true);
        }
      }
    }
  }

  /// 根据设备硬件推荐模型。
  ///
  /// [ramBytes] 由原生层提供（全平台统一）。
  /// - 核心数 ≥ 8 且 RAM ≥ 8GB → Base (Balanced)
  /// - 其他 → Tiny (Fast)
  AsrModelInfo recommendModel({int ramBytes = 0}) {
    final cores = Platform.numberOfProcessors;
    final ramGb = ramBytes ~/ (1024 * 1024 * 1024);
    AppLogger.log('ASR', 'recommendModel: cores=$cores, ramGb=$ramGb');
    if (cores >= 8 && ramGb >= 8) {
      return availableModels.firstWhere((m) => m.id == 'whisper-base-en-int8');
    }
    return availableModels.firstWhere((m) => m.id == 'whisper-tiny-en-int8');
  }

  /// 释放资源。
  void dispose() {
    _dio.close();
  }

  Future<bool> _matchesExpectedHash(File file, String expectedSha256) async {
    final actualSha256 = await _computeSha256(file);
    return actualSha256 == expectedSha256;
  }

  Future<String> _computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

/// 本地模型校验结果。
class AsrModelValidationResult {
  final String modelId;
  final bool isValid;
  final String? reason;
  final String? filePath;
  final String? expectedSha256;
  final String? actualSha256;

  const AsrModelValidationResult({
    required this.modelId,
    required this.isValid,
    this.reason,
    this.filePath,
    this.expectedSha256,
    this.actualSha256,
  });

  String describe() {
    if (isValid) return 'Model validation passed: $modelId';
    final details = <String>[
      'Downloaded model failed integrity check: $modelId',
      if (filePath != null) 'file=$filePath',
      if (reason != null) 'reason=$reason',
      if (expectedSha256 != null) 'expectedSha256=$expectedSha256',
      if (actualSha256 != null) 'actualSha256=$actualSha256',
    ];
    return details.join(' | ');
  }
}

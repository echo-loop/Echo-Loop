/// Piper VITS 模型下载、校验、缓存管理（按音色，每音色一个独立模型）。
///
/// 镜像 `KokoroModelManager`，但绑定单个 [PiperVoice]（而非 Kokoro 的精度变体）：
/// 每个音色一个 `.tar.gz` 归档，下载 → 校验整包 SHA-256 → staging 解包校验 →
/// 原子替换以音色 id 命名的目录（`*.onnx` / `tokens.txt` / `espeak-ng-data/`）。
///
/// 与 Kokoro 的唯一差异：Piper 为单说话人，**无 `voices.bin`**；模型文件名由各音色
/// 决定（如 `en_US-amy-medium.onnx`），故按扩展名定位 `.onnx`（排除 `.onnx.json`）。
/// 归档约束同 §7.17（gzip、无 macOS xattr、换包先传 CDN 再改 SHA）。
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_logger.dart';
import '../asr/asr_model_manager.dart'
    show AsrModelDownloadStatus, AsrModelDownloadProgress;
import '../reliable_http_downloader.dart';
import '../resource_archive_installer.dart';
import 'piper_model_catalog.dart';
import '../runtime_endpoint_router.dart';
import '../resource_install_manifest.dart';

// 复用 ASR 的下载状态/进度类型（已是通用命名，避免重复定义）。
export '../asr/asr_model_manager.dart'
    show AsrModelDownloadStatus, AsrModelDownloadProgress;

/// Piper 引擎初始化所需的本地绝对路径集合（无 voices.bin）。
class PiperModelPaths {
  /// `*.onnx` 模型绝对路径（如 `en_US-amy-medium.onnx`）。
  final String model;

  /// `tokens.txt` 绝对路径。
  final String tokens;

  /// `espeak-ng-data` 目录绝对路径。
  final String dataDir;

  const PiperModelPaths({
    required this.model,
    required this.tokens,
    required this.dataDir,
  });
}

/// Piper 模型管理器（绑定单个音色 [voice]）。
///
/// 每个音色一个实例（见 `piperModelManagerProvider` 的 family）；方法均针对本实例
/// 绑定的音色操作，互不干扰，故各音色可独立下载/删除/校验。
class PiperModelManager {
  /// `ReliableHttpDownloader` 接口本身不提供释放能力，[dispose] 需要靠持有
  /// 同一个 [_dio] 来关闭底层 HTTP 客户端。
  late final Dio _dio;
  late final ReliableHttpDownloader _downloader;
  late final ResourceArchiveInstaller _installer;

  /// 本管理器绑定的音色（决定目录名/归档/SHA）。
  final PiperVoice voice;

  final RuntimeEndpointRouter _endpointRouter;

  /// 下载基地址覆盖（仅测试）。
  final String? baseUrlOverride;

  /// 模型存储根目录解析器（仅测试覆盖；默认 `${appSupport}/tts-models`）。
  final Future<String> Function()? modelsRootResolver;

  PiperModelManager({
    required this.voice,
    Dio? dio,
    this.baseUrlOverride,
    this.modelsRootResolver,
    RuntimeEndpointRouter? endpointRouter,
  }) : _endpointRouter = endpointRouter ?? runtimeEndpointRouter {
    // TTS 模型下载体积较大，但断网时不能无限等待；接收超时只限制长时间无数据。
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
    _installer = ResourceArchiveInstaller(_downloader);
  }

  /// 模型存储根目录（与 Kokoro 共用 `tts-models`，各音色子目录隔离）。
  Future<String> get _modelsRoot async {
    if (modelsRootResolver != null) return modelsRootResolver!();
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'tts-models');
  }

  /// 本音色模型本地目录（目录名 = 音色 id）。
  Future<String> modelDir() async => p.join(await _modelsRoot, voice.id);

  /// 模型是否已下载且关键文件齐全。
  Future<bool> isModelDownloaded() async {
    final dir = Directory(await modelDir());
    if (!dir.existsSync()) return false;
    return await _resolvePaths(dir) != null;
  }

  /// 读取安装清单；ready 门控不读取 SharedPreferences。
  Future<ResourceInstallManifest?> readInstallManifest() async {
    final directory = Directory(await modelDir());
    final manifestFile = File(p.join(directory.path, 'install.json'));
    AppLogger.log(
      'PiperModel',
      '检查安装状态 resource=${voice.id} dir=${directory.path} '
          'dirExists=${directory.existsSync()} '
          'manifestExists=${manifestFile.existsSync()}',
    );
    final ResourceInstallManifest? manifest;
    try {
      manifest = await readResourceInstallManifest(directory);
    } on FormatException catch (error) {
      AppLogger.log('PiperModel', 'invalid install manifest: $error');
      return null;
    }
    if (manifest == null) {
      AppLogger.log('PiperModel', '检查结果 resource=${voice.id} manifest=null');
      return null;
    }
    if (manifest.resourceId != voice.id) {
      AppLogger.log(
        'PiperModel',
        '检查结果 resource=${voice.id} manifestResource=${manifest.resourceId} matched=false',
      );
      return null;
    }
    AppLogger.log(
      'PiperModel',
      '检查结果 resource=${voice.id} manifestResource=${manifest.resourceId} '
          'resourceSize=${manifest.resourceSize} matched=true',
    );
    return manifest;
  }

  /// 兼容旧调用方的安装标记检查。
  Future<bool> hasInstallMarker() async => await readInstallManifest() != null;

  /// 模型本地占用空间（字节，递归统计）。
  Future<int> modelLocalSize() async {
    final dir = Directory(await modelDir());
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// 解析引擎所需文件路径；任一关键文件缺失抛 [StateError]。
  Future<PiperModelPaths> piperConfigPaths() async {
    final dir = Directory(await modelDir());
    final paths = await _resolvePaths(dir);
    if (paths == null) {
      throw StateError('Piper model files missing under ${dir.path}');
    }
    return paths;
  }

  /// 下载并安装模型，通过 [onProgress] 报告进度，可经 [cancelToken] 取消。
  ///
  /// 流程：下载归档 → 校验 SHA-256 → staging 解包校验 → 原子替换模型目录。
  Future<String> downloadModel({
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final root = await _modelsRoot;
    final uri = baseUrlOverride == null
        ? _endpointRouter.modelCdnUri('/model/${voice.archivePath}')
        : Uri.parse('$baseUrlOverride/model/${voice.archivePath}');
    final target = Directory(await modelDir());
    AppLogger.log('PiperModel', '┌ downloadModel dir=${target.path} url=$uri');

    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloading,
      ),
    );

    await _installer.install(
      root: Directory(root),
      target: target,
      resourceId: voice.id,
      archiveFileName: '_download_${voice.id}.tar.gz',
      uri: uri,
      expectedSha256: voice.sha256.isEmpty ? null : voice.sha256,
      cancelToken: cancelToken,
      onProgress: (progress) => onProgress?.call(
        AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: progress,
        ),
      ),
      onInstalling: () => onProgress?.call(
        const AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: 1,
        ),
      ),
      extractAndValidate: (archive, staging) async {
        await extractFileToDisk(archive.path, staging.path);
        if (await _resolvePaths(staging) == null) {
          throw StateError(
            'Piper key files missing after extraction in ${staging.path}',
          );
        }
      },
    );
    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloaded,
        progress: 1,
      ),
    );
    AppLogger.log('PiperModel', '└ downloadModel done dir=${target.path}');
    return target.path;
  }

  /// 删除本地模型。
  Future<void> deleteModel() async {
    final dir = Directory(await modelDir());
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await discardPartialDownload();
  }

  /// 清理用户主动取消或删除时遗留的下载归档、续传文件和 staging。
  Future<void> discardPartialDownload() async {
    await _installer.discardPartial(
      root: Directory(await _modelsRoot),
      resourceId: voice.id,
      archiveFileName: '_download_${voice.id}.tar.gz',
    );
  }

  /// 释放资源。
  void dispose() {
    _dio.close();
  }

  /// 在 [dir] 下递归定位关键文件；任一缺失返回 null。
  ///
  /// 兼容归档解包后文件在根目录或某子目录下两种布局。模型按扩展名 `.onnx` 定位
  /// （排除 sherpa 不需要的 `.onnx.json` 元数据）。
  Future<PiperModelPaths?> _resolvePaths(Directory dir) async {
    final model = await _findOnnx(dir);
    final tokens = await _findFile(dir, piperTokensFileName);
    final dataDir = await _findDir(dir, piperDataDirectoryName);
    if (model == null || tokens == null || dataDir == null) {
      return null;
    }
    return PiperModelPaths(model: model, tokens: tokens, dataDir: dataDir);
  }

  /// 递归定位首个 `.onnx`（排除 `.onnx.json`）。
  Future<String?> _findOnnx(Directory root) async {
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) {
        final name = p.basename(e.path);
        if (name.endsWith('.onnx') && !name.endsWith('.onnx.json')) {
          return e.path;
        }
      }
    }
    return null;
  }

  Future<String?> _findFile(Directory root, String name) async {
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File && p.basename(e.path) == name) return e.path;
    }
    return null;
  }

  Future<String?> _findDir(Directory root, String name) async {
    if (p.basename(root.path) == name) return root.path;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is Directory && p.basename(e.path) == name) return e.path;
    }
    return null;
  }
}

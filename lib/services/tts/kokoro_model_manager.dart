/// Kokoro（Echo Loop TTS）模型下载、校验、缓存管理。
///
/// 与 Whisper 不同，Kokoro 含 `espeak-ng-data` 目录树，故托管为单个 `tar.gz`
/// 归档：下载归档 → 校验整包 SHA-256 → staging 解包校验 → 原子替换模型目录。
/// 下载基于 `ReliableHttpDownloader`，网络中断时保留 `.part` 供后续 Range 续传。
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
import 'kokoro_model_catalog.dart';
import '../runtime_endpoint_router.dart';
import '../resource_install_manifest.dart';

// 复用 ASR 的下载状态/进度类型（已是通用命名，避免重复定义）。
export '../asr/asr_model_manager.dart'
    show AsrModelDownloadStatus, AsrModelDownloadProgress;
// 重导出变体枚举，便于管理器使用方（main/provider）无需再单独 import。
export 'tts_engine.dart' show KokoroModelVariant;

/// Kokoro 引擎初始化所需的本地绝对路径集合。
class KokoroModelPaths {
  /// `model.int8.onnx` 绝对路径。
  final String model;

  /// `voices.bin` 绝对路径。
  final String voices;

  /// `tokens.txt` 绝对路径。
  final String tokens;

  /// `espeak-ng-data` 目录绝对路径。
  final String dataDir;

  const KokoroModelPaths({
    required this.model,
    required this.voices,
    required this.tokens,
    required this.dataDir,
  });
}

/// Kokoro 模型管理器（绑定单个变体规格）。
///
/// 每个变体一个实例（见 `kokoroModelManagerProvider` 的 family）；方法均针对
/// 本实例绑定的 [spec] 操作，互不干扰，故各模型可独立下载/删除/校验。
class KokoroModelManager {
  /// `ReliableHttpDownloader` 接口本身不提供释放能力，[dispose] 需要靠持有
  /// 同一个 [_dio] 来关闭底层 HTTP 客户端。
  late final Dio _dio;
  late final ReliableHttpDownloader _downloader;
  late final ResourceArchiveInstaller _installer;

  /// 本管理器绑定的模型规格（决定目录名/归档/SHA/模型文件名）。
  final KokoroModelSpec spec;

  final RuntimeEndpointRouter _endpointRouter;

  /// 下载基地址覆盖（仅测试）。
  final String? baseUrlOverride;

  /// 模型存储根目录解析器（仅测试覆盖；默认 `${appSupport}/tts-models`）。
  final Future<String> Function()? modelsRootResolver;

  KokoroModelManager({
    Dio? dio,
    KokoroModelSpec? spec,
    this.baseUrlOverride,
    this.modelsRootResolver,
    RuntimeEndpointRouter? endpointRouter,
  }) : _endpointRouter = endpointRouter ?? runtimeEndpointRouter,
       spec = spec ?? kokoroSpecOf(kokoroDefaultVariant) {
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

  /// 模型存储根目录。
  Future<String> get _modelsRoot async {
    if (modelsRootResolver != null) return modelsRootResolver!();
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'tts-models');
  }

  /// Kokoro 模型本地目录。
  Future<String> modelDir() async => p.join(await _modelsRoot, spec.id);

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
      'KokoroModel',
      '检查安装状态 resource=${spec.id} dir=${directory.path} '
          'dirExists=${directory.existsSync()} '
          'manifestExists=${manifestFile.existsSync()}',
    );
    final ResourceInstallManifest? manifest;
    try {
      manifest = await readResourceInstallManifest(directory);
    } on FormatException catch (error) {
      AppLogger.log('KokoroModel', 'invalid install manifest: $error');
      return null;
    }
    if (manifest == null) {
      AppLogger.log('KokoroModel', '检查结果 resource=${spec.id} manifest=null');
      return null;
    }
    if (manifest.resourceId != spec.id) {
      AppLogger.log(
        'KokoroModel',
        '检查结果 resource=${spec.id} manifestResource=${manifest.resourceId} matched=false',
      );
      return null;
    }
    AppLogger.log(
      'KokoroModel',
      '检查结果 resource=${spec.id} manifestResource=${manifest.resourceId} '
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

  /// 解析引擎所需文件路径；任一关键文件缺失返回 null。
  Future<KokoroModelPaths> kokoroConfigPaths() async {
    final dir = Directory(await modelDir());
    final paths = await _resolvePaths(dir);
    if (paths == null) {
      throw StateError('Kokoro model files missing under ${dir.path}');
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
        ? _endpointRouter.modelCdnUri('/model/${spec.archivePath}')
        : Uri.parse('$baseUrlOverride/model/${spec.archivePath}');
    final target = Directory(await modelDir());
    AppLogger.log('KokoroModel', '┌ downloadModel dir=${target.path} url=$uri');

    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloading,
      ),
    );

    await _installer.install(
      root: Directory(root),
      target: target,
      resourceId: spec.id,
      archiveFileName: '_download_${spec.id}.tar.gz',
      uri: uri,
      expectedSha256: spec.sha256,
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
            'Kokoro key files missing after extraction in ${staging.path}',
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
    AppLogger.log('KokoroModel', '└ downloadModel done dir=${target.path}');
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
      resourceId: spec.id,
      archiveFileName: '_download_${spec.id}.tar.gz',
    );
  }

  /// 释放资源。
  void dispose() {
    _dio.close();
  }

  /// 在 [dir] 下递归定位关键文件；任一缺失返回 null。
  ///
  /// 兼容归档解包后文件在根目录或某子目录下两种布局。
  Future<KokoroModelPaths?> _resolvePaths(Directory dir) async {
    final model = await _findFile(dir, spec.modelFileName);
    final voices = await _findFile(dir, kokoroVoicesFileName);
    final tokens = await _findFile(dir, kokoroTokensFileName);
    final dataDir = await _findDir(dir, kokoroDataDirectoryName);
    if (model == null || voices == null || tokens == null || dataDir == null) {
      return null;
    }
    return KokoroModelPaths(
      model: model,
      voices: voices,
      tokens: tokens,
      dataDir: dataDir,
    );
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

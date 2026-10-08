import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../app_logger.dart';
import '../reliable_http_downloader.dart';
import '../resource_archive_installer.dart';
import '../resource_install_manifest.dart';
import 'pronunciation_catalog.dart';
import 'pronunciation_repository.dart';
import '../runtime_endpoint_router.dart';

class PronunciationLibraryPaths {
  const PronunciationLibraryPaths({
    required this.database,
    required this.audioDirectory,
  });
  final String database;
  final String audioDirectory;
}

/// 发音资源包下载、校验与安装管理器。
class PronunciationLibraryManager {
  PronunciationLibraryManager({
    Dio? dio,
    String? url,
    String? sha256,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = dio ?? Dio(),
       _ownsDio = dio == null,
       _endpointRouter = endpointRouter ?? runtimeEndpointRouter,
       _urlOverride = url,
       _sha256 = sha256 ?? pronunciationSpec.archiveSha256 {
    _downloader = DioReliableHttpDownloader(dio: _dio);
    _installer = ResourceArchiveInstaller(_downloader);
  }

  @visibleForTesting
  PronunciationLibraryManager.withDownloader(
    ReliableHttpDownloader downloader, {
    String? url,
    String? sha256,
    RuntimeEndpointRouter? endpointRouter,
  }) : _dio = Dio(),
       _ownsDio = true,
       _endpointRouter = endpointRouter ?? runtimeEndpointRouter,
       _downloader = downloader,
       _urlOverride = url,
       _sha256 = sha256 ?? pronunciationSpec.archiveSha256 {
    _installer = ResourceArchiveInstaller(_downloader);
  }

  final Dio _dio;
  final bool _ownsDio;
  final RuntimeEndpointRouter _endpointRouter;
  late final ReliableHttpDownloader _downloader;
  late final ResourceArchiveInstaller _installer;
  final String? _urlOverride;
  final String _sha256;

  Future<String> _root() async =>
      p.join((await getApplicationSupportDirectory()).path, 'pronunciation');
  Future<String> _parentRoot() async =>
      (await getApplicationSupportDirectory()).path;
  Future<PronunciationLibraryPaths?> installedPaths() async {
    final paths = await _validatedPathsForDirectory(Directory(await _root()));
    if (paths != null) await _removeLegacyV1();
    return paths;
  }

  /// v2 已确认可用后清理不再使用的 v1 资源，避免长期占用磁盘空间。
  Future<void> _removeLegacyV1() async {
    final legacy = Directory(p.join(await _root(), 'v1'));
    if (!legacy.existsSync()) return;
    try {
      await legacy.delete(recursive: true);
      AppLogger.log('Pronunciation', 'removed legacy v1 library');
    } catch (error, stackTrace) {
      // 清理失败不应让已可用的 v2 发音库降级为失败状态。
      AppLogger.log(
        'Pronunciation',
        'failed to remove legacy v1 library: $error\n$stackTrace',
      );
    }
  }

  Future<PronunciationLibraryPaths?> _validatedPathsForDirectory(
    Directory dir,
  ) async {
    final marker = File(p.join(dir.path, 'install.json'));
    final database = File(p.join(dir.path, 'pronunciation.sqlite'));
    final audio = Directory(p.join(dir.path, 'audio'));
    if (!marker.existsSync() || !database.existsSync() || !audio.existsSync()) {
      return null;
    }
    try {
      final manifest = await readResourceInstallManifest(dir);
      if (manifest?.resourceId != pronunciationSpec.resourceId) {
        return null;
      }
      validatePronunciationDatabase(database.path);
      return PronunciationLibraryPaths(
        database: database.path,
        audioDirectory: audio.path,
      );
    } catch (error) {
      AppLogger.log(
        'Pronunciation',
        'installed library validation failed: $error',
      );
      return null;
    }
  }

  Future<int> localSizeBytes() async {
    final dir = Directory(await _root());
    if (!dir.existsSync()) return 0;
    var size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) size += await entity.length();
    }
    return size;
  }

  Future<PronunciationLibraryPaths> downloadAndInstall({
    CancelToken? cancelToken,
    void Function(double progress)? onDownloadProgress,
    void Function()? onInstalling,
  }) async {
    final root = await _root();
    await Directory(root).create(recursive: true);
    await _installer.install(
      root: Directory(await _parentRoot()),
      target: Directory(root),
      downloadDirectory: Directory(p.join(root, '.download')),
      resourceId: pronunciationSpec.resourceId,
      uri: _urlOverride == null
          ? _endpointRouter.modelCdnUri(pronunciationSpec.archivePath)
          : Uri.parse(_urlOverride),
      expectedSha256: _sha256,
      cancelToken: cancelToken,
      onProgress: onDownloadProgress,
      onInstalling: onInstalling,
      extractAndValidate: (archive, staging) async {
        await compute(_extractPronunciationZip, (
          archivePath: archive.path,
          outputPath: staging.path,
        ));
        final database = File(p.join(staging.path, 'pronunciation.sqlite'));
        final audio = Directory(p.join(staging.path, 'audio'));
        validatePronunciationDatabase(database.path);
        _validateAudioReferences(database.path, audio.path);
      },
    );
    await _removeLegacyV1();
    return PronunciationLibraryPaths(
      database: p.join(root, 'pronunciation.sqlite'),
      audioDirectory: p.join(root, 'audio'),
    );
  }

  void dispose() {
    if (_ownsDio) _dio.close();
  }
}

/// 在后台 isolate 解压发音包，只接收可发送的路径值，避免捕获 UI 回调和状态对象。
void _extractPronunciationZip(({String archivePath, String outputPath}) paths) {
  final archive = ZipDecoder().decodeBytes(
    File(paths.archivePath).readAsBytesSync(),
  );
  final output = Directory(paths.outputPath)..createSync(recursive: true);
  for (final entry in archive) {
    final name = p.posix.normalize(entry.name);
    final allowed = entry.isFile
        ? name == 'pronunciation.sqlite' ||
              RegExp(r'^audio/[^/]+\.opus$').hasMatch(name)
        : name == 'audio';
    if (!allowed ||
        p.posix.isAbsolute(name) ||
        name.split('/').contains('..') ||
        entry.isSymbolicLink) {
      throw StateError('Invalid pronunciation archive entry: ${entry.name}');
    }
    if (!entry.isFile) continue;
    final file = File(p.joinAll([output.path, ...name.split('/')]));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.content as List<int>, flush: true);
  }
}

void _validateAudioReferences(String databasePath, String audioDirectory) {
  final database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
  try {
    final rows = database.select(
      'SELECT audio_filename FROM pronunciation_audio',
    );
    for (final row in rows) {
      final filename = row['audio_filename'] as String;
      if (filename != p.basename(filename) ||
          !filename.endsWith('.opus') ||
          !File(p.join(audioDirectory, filename)).existsSync()) {
        throw StateError('Pronunciation audio files missing or invalid');
      }
    }
  } finally {
    database.dispose();
  }
}

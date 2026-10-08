/// 词典下载与本地存储管理
///
/// 负责从固定 CDN 下载词典 ZIP、解压安装并管理本地缓存。
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dictionary/dictionary_catalog.dart';
import 'app_logger.dart';
import 'reliable_http_downloader.dart';
import 'resource_archive_installer.dart';
import 'resource_install_manifest.dart';
import 'runtime_endpoint_router.dart';

/// 词典下载管理器
class DictionaryDownloadManager {
  DictionaryDownloadManager({
    this.specs = dictionarySpecs,
    RuntimeEndpointRouter? endpointRouter,
  }) : _endpointRouter = endpointRouter ?? runtimeEndpointRouter,
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(minutes: 5),
         ),
       ) {
    _downloader = DioReliableHttpDownloader(dio: _dio);
    _installer = ResourceArchiveInstaller(_downloader);
  }

  /// 测试用构造器
  @visibleForTesting
  DictionaryDownloadManager.withDio(
    this._dio, {
    this.specs = dictionarySpecs,
    RuntimeEndpointRouter? endpointRouter,
  }) : _endpointRouter = endpointRouter ?? runtimeEndpointRouter {
    _downloader = DioReliableHttpDownloader(dio: _dio);
    _installer = ResourceArchiveInstaller(_downloader);
  }

  final Dio _dio;
  final RuntimeEndpointRouter _endpointRouter;
  final Map<String, DictionarySpec> specs;

  /// `ReliableHttpDownloader` 接口本身不提供释放能力，[dispose] 需要靠持有
  /// 同一个 [_dio] 来关闭底层 HTTP 客户端。
  late final ReliableHttpDownloader _downloader;
  late final ResourceArchiveInstaller _installer;

  /// 获取词典本地存储目录
  Future<String> _dictionaryDir(String langKey) async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'dictionary', langKey);
  }

  /// 获取词典文件路径（不检查是否存在）
  Future<String> dictionaryPath(String nativeLanguage) async {
    final langKey = 'en_$nativeLanguage';
    final dir = await _dictionaryDir(langKey);
    return p.join(dir, 'dict.sqlite');
  }

  /// 检查本地数据库与统一安装清单是否匹配当前 catalog 版本。
  Future<bool> isDictionaryDownloaded(String nativeLanguage) async {
    final spec = _specOf(nativeLanguage);
    final directory = Directory(await _dictionaryDir('en_$nativeLanguage'));
    final database = File(p.join(directory.path, 'dict.sqlite'));
    if (!database.existsSync()) return false;
    try {
      final manifest = await readResourceInstallManifest(directory);
      return manifest?.resourceId == spec.resourceId;
    } on FormatException catch (error) {
      AppLogger.log(
        'Dict',
        'invalid install manifest lang=$nativeLanguage error=$error',
      );
      return false;
    }
  }

  /// 下载词典文件
  ///
  /// [onProgress] 报告下载进度（0.0-1.0）。
  /// [cancelToken] 用于取消下载。
  /// 返回下载后的本地文件路径。
  Future<String> download(
    String nativeLanguage, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final spec = _specOf(nativeLanguage);

      // 2. 准备本地目录
      final langKey = 'en_$nativeLanguage';
      final dir = await _dictionaryDir(langKey);
      final dbPath = p.join(dir, 'dict.sqlite');
      final root = Directory(p.dirname(dir));
      await _installer.install(
        root: root,
        target: Directory(dir),
        resourceId: spec.resourceId,
        uri: _endpointRouter.modelCdnUri(spec.archivePath),
        expectedSha256: spec.archiveSha256,
        cancelToken: cancelToken,
        onProgress: onProgress,
        extractAndValidate: (archive, staging) async {
          await extractFileToDisk(archive.path, staging.path);
          await _removeMacOsMetadata(staging);
          final extracted = await _findDatabaseFile(staging);
          if (extracted == null) {
            throw StateError('Dictionary database missing after extraction');
          }
          final installedDatabase = File(p.join(staging.path, 'dict.sqlite'));
          if (extracted.path != installedDatabase.path) {
            await extracted.rename(installedDatabase.path);
          }
        },
      );

      AppLogger.log(
        'Dict',
        'download finished lang=$nativeLanguage '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      return dbPath;
    } catch (error) {
      AppLogger.log(
        'Dict',
        'download failed lang=$nativeLanguage '
            'elapsedMs=${stopwatch.elapsedMilliseconds} error=$error',
      );
      rethrow;
    } finally {
      final spec = _specOf(nativeLanguage);
      final dir = await _dictionaryDir('en_$nativeLanguage');
      final root = p.dirname(dir);
      final archiveFile = File(
        p.join(root, '_download_${spec.resourceId}.zip'),
      );
      final staging = Directory(p.join(root, '_staging_${spec.resourceId}'));
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }
      if (staging.existsSync()) await staging.delete(recursive: true);
    }
  }

  Future<File?> _findDatabaseFile(Directory directory) async {
    File? found;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      if (name.endsWith('.sqlite') || name.endsWith('.db')) {
        if (found != null) {
          throw StateError(
            'Dictionary archive contains multiple database files',
          );
        }
        found = entity;
      }
    }
    return found;
  }

  DictionarySpec _specOf(String nativeLanguage) {
    final spec = specs[nativeLanguage];
    if (spec == null) {
      throw ArgumentError.value(nativeLanguage, 'nativeLanguage');
    }
    return spec;
  }

  Future<void> _removeMacOsMetadata(Directory directory) async {
    final metadata = Directory(p.join(directory.path, '__MACOSX'));
    if (metadata.existsSync()) await metadata.delete(recursive: true);
  }

  /// 删除非当前语言的词典文件（清缓存时调用）
  ///
  /// 同时清理旧版遗留的 `<appSupport>/dict.db`。
  /// 返回释放的字节数。
  Future<int> deleteUnusedDictionaries(String currentNativeLanguage) async {
    var freedBytes = 0;
    final appDir = await getApplicationSupportDirectory();

    // 1. 清理旧版遗留的 dict.db
    final legacyDb = File(p.join(appDir.path, 'dict.db'));
    if (legacyDb.existsSync()) {
      freedBytes += legacyDb.lengthSync();
      await legacyDb.delete();
    }

    // 2. 清理非当前语言的词典目录
    final dictRoot = Directory(p.join(appDir.path, 'dictionary'));
    if (!dictRoot.existsSync()) return freedBytes;

    final currentKey = 'en_$currentNativeLanguage';
    await for (final entity in dictRoot.list()) {
      if (entity is! Directory) continue;
      final dirName = p.basename(entity.path);
      if (dirName == currentKey) continue;

      // 统计并删除
      await for (final file in entity.list(recursive: true)) {
        if (file is File) {
          freedBytes += file.lengthSync();
        }
      }
      await entity.delete(recursive: true);
    }

    return freedBytes;
  }

  /// 释放资源
  void dispose() => _dio.close();
}

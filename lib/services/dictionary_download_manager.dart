/// 词典下载与本地存储管理
///
/// 负责从 CDN 下载词典文件、检查版本更新、管理本地缓存。
/// 下载地址和版本信息从后端 version.json 获取，不硬编码在客户端。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'app_logger.dart';

/// 单个词典的远程版本信息
class DictionaryVersionInfo {
  final String url;
  final DateTime updatedAt;

  const DictionaryVersionInfo({required this.url, required this.updatedAt});
}

/// 词典下载管理器
class DictionaryDownloadManager {
  DictionaryDownloadManager() : _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// 测试用构造器
  @visibleForTesting
  DictionaryDownloadManager.withDio(this._dio);

  final Dio _dio;

  /// SharedPreferences key 前缀：记录各词典的本地下载时间
  static const _downloadedAtKeyPrefix = 'dictionary_downloaded_at_';

  /// 获取词典本地存储目录
  Future<String> _dictionaryDir(String langKey) async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'dictionary', langKey);
  }

  /// 获取词典文件路径（不检查是否存在）
  Future<String> dictionaryPath(String nativeLanguage) async {
    final langKey = 'en_$nativeLanguage';
    final dir = await _dictionaryDir(langKey);
    return p.join(dir, 'dict.db');
  }

  /// 检查本地是否已有指定语言的词典
  Future<bool> isDictionaryDownloaded(String nativeLanguage) async {
    final path = await dictionaryPath(nativeLanguage);
    return File(path).existsSync();
  }

  /// 从后端 version.json 获取词典版本信息
  ///
  /// 失败时返回 null（网络错误等静默处理）。
  Future<DictionaryVersionInfo?> fetchVersionInfo(
    String nativeLanguage,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$apiBaseUrl/version.json',
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      if (data == null) return null;

      final dictionary = data['dictionary'] as Map<String, dynamic>?;
      if (dictionary == null) return null;

      final langKey = 'en_$nativeLanguage';
      final entry = dictionary[langKey] as Map<String, dynamic>?;
      if (entry == null) return null;

      return DictionaryVersionInfo(
        url: entry['url'] as String,
        updatedAt: DateTime.parse(entry['updatedAt'] as String),
      );
    } catch (e) {
      AppLogger.log('Dict', 'version check failed: $e');
      return null;
    }
  }

  /// 检查是否需要更新词典
  ///
  /// 对比远程 updatedAt 与本地记录的下载时间。
  Future<bool> needsUpdate(String nativeLanguage) async {
    final isDownloaded = await isDictionaryDownloaded(nativeLanguage);
    if (!isDownloaded) return true;

    final versionInfo = await fetchVersionInfo(nativeLanguage);
    if (versionInfo == null) return false; // 无法检查，不更新

    final prefs = await SharedPreferences.getInstance();
    final langKey = 'en_$nativeLanguage';
    final localDownloadedAtMs = prefs.getInt('$_downloadedAtKeyPrefix$langKey');
    if (localDownloadedAtMs == null) return true;

    final localDownloadedAt = DateTime.fromMillisecondsSinceEpoch(
      localDownloadedAtMs,
    );
    return versionInfo.updatedAt.isAfter(localDownloadedAt);
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
    // 1. 获取下载地址
    final versionInfo = await fetchVersionInfo(nativeLanguage);
    if (versionInfo == null) {
      throw StateError(
        'Failed to fetch dictionary version info for $nativeLanguage',
      );
    }

    // 2. 准备本地目录
    final langKey = 'en_$nativeLanguage';
    final dir = await _dictionaryDir(langKey);
    await Directory(dir).create(recursive: true);
    final dbPath = p.join(dir, 'dict.db');
    final tempPath = '$dbPath.tmp';
    final tempFile = File(tempPath);

    try {
      // 3. 下载到临时文件
      AppLogger.log('Dict', 'downloading url=${versionInfo.url} → $dbPath');
      await _dio.download(
        versionInfo.url,
        tempPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        },
      );

      // 4. 原子替换
      final dbFile = File(dbPath);
      if (dbFile.existsSync()) {
        await dbFile.delete();
      }
      await tempFile.rename(dbPath);

      // 5. 记录下载时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_downloadedAtKeyPrefix$langKey',
        DateTime.now().millisecondsSinceEpoch,
      );

      return dbPath;
    } catch (e) {
      // 清理临时文件
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
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

      // 清理对应的 SharedPreferences 记录
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_downloadedAtKeyPrefix$dirName');
    }

    return freedBytes;
  }

  /// 释放资源
  void dispose() => _dio.close();
}

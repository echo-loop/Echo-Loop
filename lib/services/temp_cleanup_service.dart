/// 临时目录清理服务。
///
/// 录音 .caf 文件、导出/导入临时目录等在 app 非正常退出时可能残留，
/// 提供统一的清理入口供启动时和手动清缓存时调用。
///
/// iOS/macOS 原生录音用 `NSTemporaryDirectory()`（沙盒根/tmp/），
/// 而 Flutter `getTemporaryDirectory()` 返回 `Library/Caches`（不同目录）。
/// Android 不支持录音功能，无 .caf 文件，tmp/ 不存在时自动跳过。
///
/// 注意：`Library/Caches` 是系统与各框架共享目录，其中含 `URLSession.shared`
/// (NSURLCache) 正在打开的 SQLite 缓存库 `<bundleId>/Cache.db`。**禁止整目录删除**，
/// 否则文件被 unlink 后 URLSession 再写缓存会报 disk I/O error（SQLITE_IOERR）。
/// 故对 `Library/Caches` 只清 app 自建的导出/导入临时目录（按前缀白名单），
/// 网络图片缓存由 `flutter_cache_manager` 的 `emptyCache()` API 负责（见调用方）。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/file_size.dart';
import 'app_logger.dart';

/// 清理结果。
class CleanupResult {
  const CleanupResult({required this.freedBytes});

  /// 释放的字节数。
  final int freedBytes;
}

/// 启动时清理：只清沙盒根/tmp/ 中超过 [minAge] 的文件。
///
/// 不清 Library/Caches（避免误删其他插件缓存）。
/// [minAge] 默认 60 秒，防止极端情况下删掉刚创建的录音文件。
Future<CleanupResult> cleanupRecordingTempFiles({
  Duration minAge = const Duration(seconds: 60),
}) async {
  final nsTmpDir = await _getNsTmpDir();
  if (nsTmpDir == null) return const CleanupResult(freedBytes: 0);
  return _cleanupDirectory(nsTmpDir, minAge: minAge);
}

/// app 自建在 `Library/Caches` 下的导出/导入临时目录前缀白名单。
///
/// 仅这些目录可在清缓存时删除，其余条目（系统 URLCache `Cache.db`、
/// `app_network_images`、各框架缓存）一律跳过。
/// 前缀来源：`audio_export_service.dart`、`backup_service.dart` 的 `_createTempDir`。
const _ownCacheTempPrefixes = <String>[
  'audio_export_',
  'echoloop_export_',
  'echoloop_import_',
];

/// 设置页「清除缓存」：清理 tmp/（全量）+ Library/Caches（仅 app 自建临时目录）。
///
/// tmp/ 为沙盒私有、语义上可随时丢弃，整目录清理；
/// Library/Caches 为共享目录，只删 [_ownCacheTempPrefixes] 命中的导出/导入临时目录。
Future<CleanupResult> cleanupAllTempFiles() async {
  var totalBytes = 0;

  // 1. 沙盒根 tmp/：全量清理
  final nsTmpDir = await _getNsTmpDir();
  if (nsTmpDir != null) {
    totalBytes += (await _cleanupDirectory(nsTmpDir)).freedBytes;
  }

  // 2. Library/Caches：只清 app 自建的导出/导入临时目录
  try {
    final cachesDir = await getTemporaryDirectory();
    totalBytes += (await _cleanupDirectory(
      cachesDir,
      nameFilter: _isOwnCacheTemp,
    )).freedBytes;
  } catch (_) {}

  return CleanupResult(freedBytes: totalBytes);
}

/// 判断 [path] 是否为 app 自建的导出/导入临时目录（按 basename 前缀）。
bool _isOwnCacheTemp(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return _ownCacheTempPrefixes.any(name.startsWith);
}

/// 获取沙盒根/tmp/ 目录（iOS/macOS），不存在时返回 null。
///
/// 此处保留 getApplicationDocumentsDirectory()：目的是导航沙盒目录结构
/// 找到 tmp 目录，而非存储用户数据。
Future<Directory?> _getNsTmpDir() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.parent.path}/tmp');
    if (await dir.exists()) return dir;
  } catch (_) {}
  return null;
}

/// 清理指定目录中的文件，可选按文件年龄过滤、按名称白名单过滤。
///
/// [minAge] 不为空时跳过修改时间不足该时长的条目。
/// [nameFilter] 不为空时只删除其返回 true 的条目（用于 Library/Caches 白名单）。
Future<CleanupResult> _cleanupDirectory(
  Directory dir, {
  Duration? minAge,
  bool Function(String path)? nameFilter,
}) async {
  var totalBytes = 0;
  var deletedCount = 0;
  var failedCount = 0;
  var skippedCount = 0;
  final now = DateTime.now();

  try {
    AppLogger.log('TempCleanup', 'Scanning ${dir.path}');
    await for (final entity in dir.list()) {
      try {
        // 白名单过滤：不在白名单内的条目跳过（保护系统/框架缓存）
        if (nameFilter != null && !nameFilter(entity.path)) {
          skippedCount++;
          continue;
        }

        // 按年龄过滤：跳过修改时间不足 minAge 的文件
        if (minAge != null) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) < minAge) continue;
        }

        if (entity is File) {
          totalBytes += await entity.length();
        } else if (entity is Directory) {
          totalBytes += await calculateDirectorySize(entity);
        }
        await entity.delete(recursive: true);
        deletedCount++;
      } catch (e) {
        failedCount++;
        AppLogger.log('TempCleanup', 'Failed: ${entity.path}: $e');
      }
    }
    AppLogger.log(
      'TempCleanup',
      'Done: deleted=$deletedCount, failed=$failedCount, '
          'skipped=$skippedCount, freed=${formatBytes(totalBytes)}',
    );
  } catch (e) {
    AppLogger.log('TempCleanup', 'Error: $e');
  }
  return CleanupResult(freedBytes: totalBytes);
}

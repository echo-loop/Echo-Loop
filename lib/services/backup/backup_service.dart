import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import '../../utils/app_data_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import 'backup_constants.dart';
import 'backup_manifest.dart';
import 'backup_progress.dart';

/// 不应导出的 SharedPreferences key 黑名单
///
/// 这些 key 属于设备相关状态或开发者调试用途，不应跨设备迁移。
const _spBlacklist = {
  'demo_mode',
  'developer_time_machine_at_ms',
  'anonymous_id',
  'unlock_all_reviews',
};

/// key 前缀黑名单（匹配以这些前缀开头的 key）
const _spPrefixBlacklist = ['app_update_'];

/// 数据库文件名
const _dbFileName = 'echo_loop.db';

/// 数据备份与恢复服务
///
/// 纯业务逻辑，不依赖 UI 框架或 Riverpod。
/// 导出为 ZIP 文件，内含 SQLite 数据库 + SharedPreferences + 媒体文件。
class BackupService {
  final AppDatabase _database;

  BackupService(this._database);

  /// 导出全部数据到指定目录，返回生成的 .zip 文件路径。
  ///
  /// [onProgress] 回调报告进度。
  Future<String> exportData({
    required String outputDir,
    required String appVersion,
    required String platform,
    void Function(BackupProgress)? onProgress,
  }) async {
    final docsDir = await getAppDataDirectory();
    final tempDir = await _createTempDir('echoloop_export');

    try {
      // Step 1: WAL checkpoint — 确保所有数据写入主文件
      onProgress?.call(const BackupProgress(stage: 'exportingDatabase'));
      await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      // Step 2: 复制数据库文件
      final dbSrc = File(p.join(docsDir.path, _dbFileName));
      final dbDst = File(p.join(tempDir.path, _dbFileName));
      await dbSrc.copy(dbDst.path);

      // Step 3: 导出 SharedPreferences
      onProgress?.call(const BackupProgress(stage: 'exportingPreferences'));
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = _dumpPreferences(prefs);
      final prefsFile = File(p.join(tempDir.path, 'preferences.json'));
      await prefsFile.writeAsString(jsonEncode(prefsJson));

      // Step 4: 复制媒体文件
      onProgress?.call(const BackupProgress(stage: 'exportingMedia'));
      final mediaPaths = await _collectMediaPaths();
      final mediaDir = Directory(p.join(tempDir.path, 'media'));
      var copiedCount = 0;
      for (final relPath in mediaPaths) {
        final src = File(p.join(docsDir.path, relPath));
        if (await src.exists()) {
          final dst = File(p.join(mediaDir.path, relPath));
          await dst.parent.create(recursive: true);
          await src.copy(dst.path);
          copiedCount++;
        }
        if (onProgress != null && mediaPaths.isNotEmpty) {
          onProgress(
            BackupProgress(
              stage: 'exportingMedia',
              progress: copiedCount / mediaPaths.length,
            ),
          );
        }
      }

      // Step 5: 复制可跨设备复用且体积可控的离线词典资源。
      onProgress?.call(const BackupProgress(stage: 'exportingResources'));
      final resources = await _copyOfflineResources(tempDir);

      // Step 6: 生成 manifest
      final dbSha256 = await _computeFileSha256(dbDst.path);
      final totalSize = await _calculateDirSize(tempDir);
      final manifest = BackupManifest(
        version: 2,
        appVersion: appVersion,
        schemaVersion: _database.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        platform: platform,
        dbSha256: dbSha256,
        mediaFileCount: copiedCount,
        totalSizeBytes: totalSize,
        offlineResourceFileCount: resources.fileCount,
        offlineResourceSizeBytes: resources.sizeBytes,
      );
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

      // Step 7: 打包为 ZIP
      onProgress?.call(const BackupProgress(stage: 'exportingPacking'));
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      final backupFileName = 'echoloop_backup_$timestamp.$backupFileExtension';
      final backupPath = p.join(outputDir, backupFileName);
      await _packZip(tempDir, backupPath);

      return backupPath;
    } finally {
      // Step 8: 清理 temp
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// 读取备份文件的 manifest 信息（导入前预览用）。
  ///
  /// 备份外层文件名为 `.elbak`，内部仍是 ZIP 容器，保持应用内压缩/解压能力。
  Future<BackupManifest> readManifest(String backupPath) async {
    final manifestJson = await Isolate.run(
      () => _readManifestJsonSync(backupPath),
    );
    return BackupManifest.fromJson(manifestJson);
  }

  /// 从 .zip 文件导入全部数据。
  ///
  /// 返回导入的 manifest 信息。
  /// 调用方负责在导入前关闭数据库、导入后重新打开并热切换 Provider。
  Future<BackupManifest> importData({
    required String zipPath,
    void Function(BackupProgress)? onProgress,
  }) async {
    final docsDir = await getAppDataDirectory();
    final tempDir = await _createTempDir('echoloop_import');

    try {
      // Step 1: 解压
      onProgress?.call(const BackupProgress(stage: 'importingExtracting'));
      await Isolate.run(() => _extractZipSync(zipPath, tempDir.path));

      // Step 2: 验证 manifest
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const BackupException('Invalid backup: manifest.json not found');
      }
      final manifest = BackupManifest.fromJson(
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
      );
      if (manifest.version != 1 && manifest.version != 2) {
        throw BackupException(
          'Unsupported backup version: ${manifest.version}',
        );
      }

      // Step 3: 检查 schema 版本
      if (manifest.schemaVersion > _database.schemaVersion) {
        throw const BackupException('incompatibleVersion');
      }

      // Step 4: 验证数据库 SHA256
      final importDbFile = File(p.join(tempDir.path, _dbFileName));
      if (!await importDbFile.exists()) {
        throw const BackupException('Invalid backup: database file not found');
      }
      final actualSha256 = await _computeFileSha256(importDbFile.path);
      if (actualSha256 != manifest.dbSha256) {
        throw const BackupException(
          'Database file corrupted (SHA256 mismatch)',
        );
      }

      // Step 5: 清空旧媒体文件，再复制导入的媒体文件
      onProgress?.call(const BackupProgress(stage: 'importingMedia'));
      for (final subdir in ['audios', 'transcripts']) {
        final dir = Directory(p.join(docsDir.path, subdir));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
      final mediaDir = Directory(p.join(tempDir.path, 'media'));
      if (await mediaDir.exists()) {
        await _copyDirectory(mediaDir, docsDir);
      }

      // Step 5.5: v2 备份仅替换可安全迁移的离线词典，不覆盖本机模型文件。
      if (manifest.version >= 2) {
        onProgress?.call(const BackupProgress(stage: 'importingResources'));
        await _restoreOfflineResources(tempDir);
      }

      // Step 6: 替换数据库文件（.bak 原子性保护）
      onProgress?.call(const BackupProgress(stage: 'importingDatabase'));
      final currentDb = File(p.join(docsDir.path, _dbFileName));
      final backupDb = File(p.join(docsDir.path, '$_dbFileName.bak'));

      // 关闭当前数据库由调用方负责（在调用 importData 之前）

      // 备份旧文件
      if (await currentDb.exists()) {
        await currentDb.rename(backupDb.path);
      }
      // 放入新文件
      await importDbFile.copy(currentDb.path);

      // 同时删除可能存在的 WAL 和 SHM 文件
      final walFile = File(p.join(docsDir.path, '$_dbFileName-wal'));
      final shmFile = File(p.join(docsDir.path, '$_dbFileName-shm'));
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // Step 7: 恢复 SharedPreferences
      onProgress?.call(const BackupProgress(stage: 'importingPreferences'));
      final prefsFile = File(p.join(tempDir.path, 'preferences.json'));
      if (await prefsFile.exists()) {
        final prefsJson =
            jsonDecode(await prefsFile.readAsString()) as Map<String, dynamic>;
        await _restorePreferences(prefsJson);
      }

      // 删除 .bak
      if (await backupDb.exists()) {
        await backupDb.delete();
      }

      return manifest;
    } catch (e) {
      // 导入失败：尝试从 .bak 恢复
      final docsPath = docsDir.path;
      final backupDb = File(p.join(docsPath, '$_dbFileName.bak'));
      final currentDb = File(p.join(docsPath, _dbFileName));
      if (await backupDb.exists() && !await currentDb.exists()) {
        await backupDb.rename(currentDb.path);
      }
      rethrow;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  // ---- 私有方法 ----

  /// 收集所有音频和字幕文件的相对路径（含软删除的记录）
  Future<List<String>> _collectMediaPaths() async {
    final rows = await _database
        .customSelect('SELECT audio_path, transcript_path FROM audio_items')
        .get();

    final paths = <String>{};
    for (final row in rows) {
      final audioPath = row.readNullable<String>('audio_path');
      if (audioPath != null) {
        paths.add(audioPath);
      }
      final transcriptPath = row.readNullable<String>('transcript_path');
      if (transcriptPath != null) {
        paths.add(transcriptPath);
      }
    }
    return paths.toList();
  }

  /// 将可跨设备使用的离线词典复制到 ZIP 的 resources 目录。
  ///
  /// ASR/TTS 模型体积过大，且往往可在目标设备按需重新下载，因此不进入备份。
  Future<({int fileCount, int sizeBytes})> _copyOfflineResources(
    Directory tempDir,
  ) async {
    final appSupport = await getApplicationSupportDirectory();
    final resourcesDir = Directory(p.join(tempDir.path, 'resources'));
    var fileCount = 0;
    var sizeBytes = 0;

    for (final name in ['dictionary']) {
      final source = Directory(p.join(appSupport.path, name));
      if (!await source.exists()) continue;
      await for (final entity in source.list(recursive: true)) {
        if (entity is! File) continue;
        final basename = p.basename(entity.path);
        if (basename.startsWith('_dl_') || basename.endsWith('.tmp')) continue;
        final relative = p.relative(entity.path, from: appSupport.path);
        final target = File(p.join(resourcesDir.path, relative));
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
        fileCount++;
        sizeBytes += await entity.length();
      }
    }
    return (fileCount: fileCount, sizeBytes: sizeBytes);
  }

  /// 用备份中的离线词典替换本机对应目录。
  ///
  /// 模型文件不在备份范围内，因此恢复时也不能删除或覆盖本机已下载模型。
  Future<void> _restoreOfflineResources(Directory tempDir) async {
    final resourcesDir = Directory(p.join(tempDir.path, 'resources'));
    if (!await resourcesDir.exists()) return;
    final appSupport = await getApplicationSupportDirectory();
    for (final name in ['dictionary']) {
      final target = Directory(p.join(appSupport.path, name));
      if (await target.exists()) await target.delete(recursive: true);
      final source = Directory(p.join(resourcesDir.path, name));
      if (await source.exists()) await _copyDirectory(source, target);
    }
  }

  /// 导出 SharedPreferences（黑名单排除）
  Map<String, dynamic> _dumpPreferences(SharedPreferences prefs) {
    final result = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_spBlacklist.contains(key)) continue;
      if (_spPrefixBlacklist.any((prefix) => key.startsWith(prefix))) continue;
      // geo_country 也排除（设备相关缓存）
      if (key == 'geo_country') continue;
      result[key] = prefs.get(key);
    }
    return result;
  }

  /// 恢复 SharedPreferences
  Future<void> _restorePreferences(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // 先清除可恢复的 key
    for (final key in prefs.getKeys()) {
      if (_spBlacklist.contains(key)) continue;
      if (_spPrefixBlacklist.any((prefix) => key.startsWith(prefix))) continue;
      if (key == 'geo_country') continue;
      await prefs.remove(key);
    }
    // 写入导入数据
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, value.cast<String>());
      }
    }
  }

  /// 计算文件 SHA256
  Future<String> _computeFileSha256(String path) async {
    final file = File(path);
    final sink = AccumulatorSink<Digest>();
    final output = sha256.startChunkedConversion(sink);
    final stream = file.openRead();
    await for (final chunk in stream) {
      output.add(chunk);
    }
    output.close();
    return sink.events.first.toString();
  }

  /// 计算目录总大小
  Future<int> _calculateDirSize(Directory dir) async {
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// 创建临时目录
  Future<Directory> _createTempDir(String prefix) async {
    final systemTemp = await getTemporaryDirectory();
    final dir = Directory(
      p.join(
        systemTemp.path,
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// 递归复制目录内容到目标目录（保持相对路径结构）
  Future<void> _copyDirectory(Directory src, Directory dst) async {
    await for (final entity in src.list(recursive: true)) {
      if (entity is File) {
        final relPath = p.relative(entity.path, from: src.path);
        final dstFile = File(p.join(dst.path, relPath));
        await dstFile.parent.create(recursive: true);
        await entity.copy(dstFile.path);
      }
    }
  }

  /// 将目录打包为 ZIP 文件
  Future<void> _packZip(Directory sourceDir, String zipPath) async {
    await Isolate.run(() => _packZipSync(sourceDir.path, zipPath));
  }
}

/// 后台 isolate 读取备份 manifest，避免 ZIP 解码阻塞主线程动画。
Map<String, dynamic> _readManifestJsonSync(String backupPath) {
  final bytes = File(backupPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final manifestEntry = archive.findFile('manifest.json');
  if (manifestEntry == null) {
    throw const BackupException('Invalid backup: manifest.json not found');
  }
  final jsonStr = utf8.decode((manifestEntry.content as List).cast<int>());
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

/// 后台 isolate 将临时目录打包成 ZIP 容器，输出为 `.elbak` 备份文件。
void _packZipSync(String sourceDirPath, String zipPath) {
  final archive = Archive();
  for (final entity in Directory(sourceDirPath).listSync(recursive: true)) {
    if (entity is! File) continue;
    final relPath = p.relative(entity.path, from: sourceDirPath);
    final bytes = entity.readAsBytesSync();
    archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
  }
  final zipData = ZipEncoder().encode(archive);
  File(zipPath).writeAsBytesSync(zipData);
}

/// 后台 isolate 解压 ZIP 容器到临时目录，避免主线程在大备份上卡顿。
void _extractZipSync(String backupPath, String outputDirPath) {
  final bytes = File(backupPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final entry in archive) {
    final cleanName = entry.name;
    if (cleanName.contains('..') || p.isAbsolute(cleanName)) {
      throw BackupException('Invalid path in archive: $cleanName');
    }
    final outPath = p.join(outputDirPath, cleanName);
    if (entry.isFile) {
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync((entry.content as List).cast<int>());
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

/// 备份操作异常
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => 'BackupException: $message';
}

/// crypto 包辅助类：收集 chunked conversion 结果
class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];

  @override
  void add(T event) => events.add(event);

  @override
  void close() {}
}

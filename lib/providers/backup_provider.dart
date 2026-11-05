import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/providers.dart';
import '../services/backup/backup_manifest.dart';
import '../services/backup/backup_progress.dart';
import '../services/backup/backup_service.dart';
import '../services/app_logger.dart';
import 'audio_library_provider.dart';
import 'collection_provider.dart';
import 'learning_progress_provider.dart';
import 'package_info_provider.dart';
import 'settings_provider.dart';
import 'tag_provider.dart';

/// BackupService Provider
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(appDatabaseProvider));
});

/// 导出数据，返回生成的 ZIP 文件路径
///
/// [onProgress] 回调报告进度。
Future<String> performExport(
  WidgetRef ref, {
  void Function(BackupProgress)? onProgress,
}) async {
  final service = ref.read(backupServiceProvider);
  final packageInfo = ref.read(packageInfoProvider);
  final tempDir = await getTemporaryDirectory();

  return service.exportData(
    outputDir: tempDir.path,
    appVersion: packageInfo.version,
    platform: _currentPlatform,
    onProgress: onProgress,
  );
}

/// 读取备份文件 manifest（导入前预览用）
Future<BackupManifest> readBackupManifest(WidgetRef ref, String path) {
  return ref.read(backupServiceProvider).readManifest(path);
}

/// 导入数据（含数据库热切换）
///
/// 完整流程：校验备份 → 关闭旧数据库 → 应用 → 打开并验证新数据库 → 提交。
/// 新数据库或 Provider 加载失败时，恢复会话会先回滚全部文件与设置，再重连旧库。
Future<BackupManifest> performImport(
  WidgetRef ref,
  String zipPath, {
  void Function(BackupProgress)? onProgress,
}) async {
  final service = ref.read(backupServiceProvider);
  PreparedBackupImport? prepared;
  AppliedBackupImport? applied;
  AppDatabase? candidateDatabase;
  var databaseWasClosed = false;

  try {
    // 完整校验和数据库快照提取期间保持当前 Drift 连接可用。
    prepared = await service.prepareImport(
      zipPath: zipPath,
      onProgress: onProgress,
    );

    await closeCurrentDatabase(
      studyTimeService: ref.read(studyTimeServiceProvider),
    );
    databaseWasClosed = true;
    AppLogger.log('Backup', 'database_closed_for_restore');
    applied = await service.applyPreparedImport(
      prepared,
      onProgress: onProgress,
    );

    candidateDatabase = AppDatabase(openConnectionWithName('echo_loop.db'));
    AppLogger.log('Backup', 'candidate_database_opened');
    switchAppDatabase(candidateDatabase, (p) => ref.invalidate(p));
    await _reloadDatabaseProviders(ref);
    // 可重新下载的资源不进入备份。恢复后重建母语相关状态。
    ref.invalidate(appSettingsProvider);
    ref.read(appSettingsProvider);
    AppLogger.log('Backup', 'database_providers_reloaded');
    await applied.commit();
    AppLogger.log('Backup', 'restore_committed');

    return prepared.manifest;
  } catch (error, stackTrace) {
    AppLogger.log('Backup', 'restore_provider_failed error=$error');
    AppLogger.log('Backup', 'restore_provider_failed stackTrace=$stackTrace');
    await candidateDatabase?.close();
    await applied?.rollback();
    if (databaseWasClosed) {
      final fallbackDb = AppDatabase(openConnectionWithName('echo_loop.db'));
      switchAppDatabase(fallbackDb, (p) => ref.invalidate(p));
      await _reloadDatabaseProviders(ref);
      AppLogger.log('Backup', 'fallback_database_reopened');
    }
    rethrow;
  } finally {
    await prepared?.dispose();
  }
}

/// 数据库切换后重新加载恢复页依赖的核心数据。
Future<void> _reloadDatabaseProviders(WidgetRef ref) async {
  await ref.read(audioLibraryProvider.notifier).loadLibrary();
  await ref.read(collectionListProvider.notifier).loadCollections();
  await ref.read(tagListProvider.notifier).loadTags();
  await ref.read(learningProgressProvider.notifier).loadAll();
}

/// 获取当前平台标识
String get _currentPlatform {
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isAndroid) return 'android';
  return defaultTargetPlatform.name;
}

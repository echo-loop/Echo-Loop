import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/learning_settings_provider.dart';
import '../providers/tts/tts_settings_provider.dart';
import 'app_logger.dart';
import 'asr/asr_model_manager.dart';
import 'resource_install_manifest.dart';
import 'storage_migration_service.dart';

/// SharedPreferences 中记录应用升级迁移链进度的 key。
const appUpdateMigrationVersionKey = 'app_update_migration_version';

/// 当前已注册的应用升级迁移版本。
const currentAppUpdateMigrationVersion = 11;

/// 删除已废弃的 TTS 模型下载状态缓存；模型状态现在以安装清单和文件校验为准。
Future<void> removeLegacyTtsModelDownloadFlags(SharedPreferences prefs) async {
  final legacyKeys = prefs.getKeys().where(
    (key) =>
        key.startsWith('kokoro_model_downloaded_') ||
        key.startsWith('piper_model_downloaded_'),
  );
  for (final key in legacyKeys) {
    await prefs.remove(key);
  }
}

/// 将旧版逐文件 ASR 缓存升级为 install.json；无效缓存不会被误标记为可用。
Future<void> migrateLegacyAsrModelInstallLayout(SharedPreferences prefs) async {
  final manager = AsrModelManager();
  try {
    for (final resourceId in asrModelResourceCatalog.keys) {
      if (await manager.readInstallManifest(resourceId) != null) continue;
      if (!await manager.validateLegacyModelFiles(resourceId)) continue;
      await writeResourceInstallManifest(
        Directory(await manager.modelDir(resourceId)),
        resourceId: resourceId,
        installAt: DateTime.now(),
      );
    }
  } finally {
    manager.dispose();
  }
  final keys = prefs
      .getKeys()
      .where((key) => key.startsWith('offline_asr_downloaded_'))
      .toList();
  for (final key in keys) {
    await prefs.remove(key);
  }
}

typedef AppUpdateMigrationAction = Future<void> Function();
typedef AppUpdateMigrationRunnerCallback =
    Future<void> Function(
      AppUpdateMigration migration,
      AppUpdateMigrationAction action,
    );

/// 单个应用升级迁移步骤，version 表示执行完成后的目标版本。
class AppUpdateMigration {
  const AppUpdateMigration({
    required this.version,
    required this.name,
    required this.action,
  });

  final int version;
  final String name;
  final AppUpdateMigrationAction action;
}

/// 按连续版本顺序执行应用升级迁移。
///
/// 迁移动作完成后才写入版本号；动作失败时版本保持不变，下次启动会从
/// 当前版本重试。因此每个动作都必须设计为可安全重复执行。
class AppUpdateMigrationRunner {
  AppUpdateMigrationRunner({
    required SharedPreferences prefs,
    required List<AppUpdateMigration> migrations,
    this.onMigration,
  }) : _prefs = prefs,
       _migrations = List.unmodifiable(migrations);

  final SharedPreferences _prefs;
  final List<AppUpdateMigration> _migrations;
  final AppUpdateMigrationRunnerCallback? onMigration;

  Future<int> migrate() async {
    try {
      _validateMigrations();
    } catch (error, stackTrace) {
      AppLogger.log('AppUpdateMigration', '迁移版本链校验失败: $error\n$stackTrace');
      rethrow;
    }
    var version = _prefs.getInt(appUpdateMigrationVersionKey) ?? 0;
    final targetVersion = _migrations.isEmpty ? 0 : _migrations.last.version;
    AppLogger.log(
      'AppUpdateMigration',
      '开始检查迁移: current=v$version, target=v$targetVersion',
    );
    var appliedCount = 0;
    for (final migration in _migrations) {
      if (migration.version <= version) {
        AppLogger.log(
          'AppUpdateMigration',
          '跳过已完成迁移: v${migration.version} ${migration.name}',
        );
        continue;
      }
      if (migration.version != version + 1) {
        final error = StateError(
          'App update migration gap: expected v${version + 1}, '
          'found v${migration.version}',
        );
        AppLogger.log('AppUpdateMigration', '迁移版本缺口: $error');
        throw error;
      }
      AppLogger.log(
        'AppUpdateMigration',
        '开始迁移: v${migration.version} ${migration.name}',
      );
      final action = migration.action;
      try {
        final callback = onMigration;
        if (callback == null) {
          await action();
        } else {
          await callback(migration, action);
        }
        final persisted = await _prefs.setInt(
          appUpdateMigrationVersionKey,
          migration.version,
        );
        if (!persisted) {
          throw StateError(
            'Failed to persist app update migration version '
            '${migration.version}',
          );
        }
      } catch (error, stackTrace) {
        AppLogger.log(
          'AppUpdateMigration',
          '迁移失败，保留 current=v$version，等待下次重试: '
              'v${migration.version} ${migration.name}: $error\n$stackTrace',
        );
        rethrow;
      }
      version = migration.version;
      appliedCount++;
      AppLogger.log(
        'AppUpdateMigration',
        '迁移完成并记录版本: v$version ${migration.name}',
      );
    }
    AppLogger.log(
      'AppUpdateMigration',
      '迁移检查完成: current=v$version, applied=$appliedCount',
    );
    return version;
  }

  void _validateMigrations() {
    var expected = 1;
    for (final migration in _migrations) {
      if (migration.version != expected) {
        throw StateError(
          'Invalid app update migration list: expected v$expected, '
          'found v${migration.version}',
        );
      }
      expected++;
    }
  }
}

/// 构造当前应用的全部升级迁移步骤。
List<AppUpdateMigration> buildAppUpdateMigrations(
  SharedPreferences prefs, {
  required bool isAndroid,
}) {
  return [
    AppUpdateMigration(
      version: 1,
      name: 'data_directory_migration',
      action: migrateToAppSupportDirectory,
    ),
    AppUpdateMigration(
      version: 2,
      name: 'legacy_offline_asr_settings_migration',
      action: () => migrateLegacyOfflineAsrEnabledToRatingSettings(prefs),
    ),
    AppUpdateMigration(
      version: 3,
      name: 'legacy_learning_settings_cleanup',
      action: () => cleanupLegacyLearningSettingsKeys(prefs),
    ),
    AppUpdateMigration(
      version: 4,
      name: 'legacy_tts_settings_migration',
      action: () => migrateLegacyEchoLoopTtsPreference(prefs),
    ),
    AppUpdateMigration(
      version: 5,
      name: 'android_tts_settings_migration',
      action: isAndroid
          ? () => migrateAndroidPlatformTtsPreference(prefs)
          : () async {},
    ),
    AppUpdateMigration(
      version: 6,
      name: 'tts_model_install_layout_migration',
      action: () async {
        await migrateTtsModelInstallLayout();
        await removeLegacyTtsModelDownloadFlags(prefs);
      },
    ),
    // 旧离线词典布局迁移已由 v12 的整体删除取代；保留版本位以维持迁移链连续。
    AppUpdateMigration(
      version: 7,
      name: 'dictionary_install_layout_migration',
      action: () async {},
    ),
    // 旧发音包布局迁移已由 v11 的整体删除取代；保留版本位以维持迁移链连续。
    AppUpdateMigration(
      version: 8,
      name: 'pronunciation_install_layout_migration',
      action: () async {},
    ),
    AppUpdateMigration(
      version: 9,
      name: 'asr_model_install_layout_migration',
      action: () => migrateLegacyAsrModelInstallLayout(prefs),
    ),
    AppUpdateMigration(
      version: 10,
      name: 'edge_tts_default_engine_migration',
      action: () => migrateDefaultTtsEngineToEdge(prefs),
    ),
    AppUpdateMigration(
      version: 11,
      name: 'remove_offline_pronunciation_library',
      action: removeOfflinePronunciationLibrary,
    ),
    AppUpdateMigration(
      version: 12,
      name: 'remove_offline_dictionary_library',
      action: removeOfflineDictionaryLibrary,
    ),
  ];
}

/// 在读取同步设置前完成所有应用升级迁移。
Future<int> runAppUpdateMigrations(
  SharedPreferences prefs, {
  AppUpdateMigrationRunnerCallback? onMigration,
}) async {
  final isAndroid = !kIsWeb && Platform.isAndroid;
  final runner = AppUpdateMigrationRunner(
    prefs: prefs,
    migrations: buildAppUpdateMigrations(prefs, isAndroid: isAndroid),
    onMigration: onMigration,
  );
  return runner.migrate();
}

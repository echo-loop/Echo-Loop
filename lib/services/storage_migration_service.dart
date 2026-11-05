import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'resource_install_manifest.dart';
import 'dictionary/dictionary_catalog.dart';
import 'app_logger.dart';

/// Documents → Application Support 一次性数据迁移。
///
/// iOS 会在「设置 > 存储」中展示 Documents 目录的内容，导致用户看到
/// 数据库和字幕等内部文件。此迁移将所有用户数据移至 Application Support，
/// 该目录不会暴露给用户但仍会被 iCloud 备份。
///
/// 必须在数据库初始化之前调用。迁移是幂等的：中断后下次启动自动重试。
Future<void> migrateToAppSupportDirectory() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final appSupportDir = await getApplicationSupportDirectory();

  // 确保目标目录存在
  if (!appSupportDir.existsSync()) {
    await appSupportDir.create(recursive: true);
  }

  // 迁移数据库文件（含 WAL / SHM 伴随文件）
  for (final name in _dbFiles) {
    await _migrateFile(docsDir.path, appSupportDir.path, name);
  }

  // 迁移媒体目录
  for (final name in _mediaDirs) {
    await _migrateDirectory(docsDir.path, appSupportDir.path, name);
  }
}

/// 将旧版本仍位于 Documents 下的 TTS 模型目录移动到 Application Support。
Future<void> migrateTtsModelInstallLayout() async {
  final documents = await getApplicationDocumentsDirectory();
  final support = await getApplicationSupportDirectory();
  await _migrateDirectory(documents.path, support.path, 'tts-models');
  final modelsRoot = Directory(p.join(support.path, 'tts-models'));
  if (!await modelsRoot.exists()) return;
  await for (final entity in modelsRoot.list(followLinks: false)) {
    if (entity is! Directory || p.basename(entity.path).startsWith('_')) {
      continue;
    }
    final marker = File(p.join(entity.path, 'install.json'));
    if (!await marker.exists()) {
      final stat = await entity.stat();
      await writeResourceInstallManifest(
        entity,
        resourceId: p.basename(entity.path),
        installAt: stat.changed,
      );
    }
  }
}

/// 将旧版按需下载的词典文件迁移到统一资源安装布局。
///
/// 迁移只处理本地文件，不联网；重命名和写入清单分别可安全重试。
Future<void> migrateLegacyDictionaryInstallLayout() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'dictionary'));
  for (final spec in dictionarySpecs.values) {
    final directory = Directory(p.join(root.path, 'en_${spec.nativeLanguage}'));
    if (!await directory.exists()) continue;

    final legacy = File(p.join(directory.path, 'dict.db'));
    final database = File(p.join(directory.path, 'dict.sqlite'));
    if (await legacy.exists() && !await database.exists()) {
      await legacy.rename(database.path);
      AppLogger.log(
        'DictMigration',
        'renamed legacy dictionary lang=${spec.nativeLanguage} '
            'from=dict.db to=dict.sqlite',
      );
    }
    if (!await database.exists()) {
      AppLogger.log(
        'DictMigration',
        'no dictionary to migrate lang=${spec.nativeLanguage}',
      );
      continue;
    }

    ResourceInstallManifest? manifest;
    try {
      manifest = await readResourceInstallManifest(directory);
    } on FormatException {
      manifest = null;
    }
    if (manifest == null || manifest.resourceId != spec.resourceId) {
      final stat = await database.stat();
      await writeResourceInstallManifest(
        directory,
        resourceId: spec.resourceId,
        installAt: stat.changed,
      );
      AppLogger.log(
        'DictMigration',
        'install manifest migrated lang=${spec.nativeLanguage} '
            'resource=${spec.resourceId}',
      );
    } else {
      AppLogger.log(
        'DictMigration',
        'dictionary install already current lang=${spec.nativeLanguage} '
            'resource=${spec.resourceId}',
      );
    }
  }
}

/// 删除旧版离线单词发音库（约 41MB）。单词发音已改为按需从 CDN 获取并缓存，
/// 旧目录不再有读取方，删除失败只记日志，不阻塞启动。
Future<void> removeOfflinePronunciationLibrary() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'pronunciation'));
  if (!await root.exists()) return;
  try {
    await root.delete(recursive: true);
    AppLogger.log('PronunciationMigration', '已删除旧版离线单词发音库');
  } on FileSystemException catch (error) {
    AppLogger.log('PronunciationMigration', '删除旧版离线单词发音库失败：$error');
  }
}

/// 需要迁移的数据库相关文件。
const _dbFiles = [
  // 当前版本
  'echo_loop.db',
  'echo_loop.db-wal',
  'echo_loop.db-shm',
  'echo_loop_demo.db',
  'echo_loop_demo.db-wal',
  'echo_loop_demo.db-shm',
  // 旧版本名称（fluency → echo_loop 重命名迁移已删除，这里兜底）
  'fluency.db',
  'fluency.db-wal',
  'fluency.db-shm',
  'fluency_demo.db',
  'fluency_demo.db-wal',
  'fluency_demo.db-shm',
];

/// 需要迁移的媒体目录。
const _mediaDirs = ['audios', 'transcripts', 'demo'];

/// 将单个文件从 [srcRoot] 移动到 [dstRoot]（同名）。
///
/// 仅在源存在且目标不存在时执行，保证幂等。
Future<void> _migrateFile(String srcRoot, String dstRoot, String name) async {
  final src = File(p.join(srcRoot, name));
  final dst = File(p.join(dstRoot, name));
  if (await src.exists() && !await dst.exists()) {
    await src.rename(dst.path);
  }
}

/// 将目录从 [srcRoot] 移动到 [dstRoot]（同名）。
///
/// 仅在源存在且目标不存在时执行，保证幂等。
Future<void> _migrateDirectory(
  String srcRoot,
  String dstRoot,
  String name,
) async {
  final src = Directory(p.join(srcRoot, name));
  final dst = Directory(p.join(dstRoot, name));
  if (await src.exists() && !await dst.exists()) {
    await src.rename(dst.path);
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../database/app_database.dart';
import '../app_logger.dart';
import '../../utils/app_data_dir.dart';
import '../app_update_migration.dart';
import 'backup_constants.dart';
import 'backup_manifest.dart';
import 'backup_progress.dart';

/// 不应跨设备恢复的 SharedPreferences key。
const _spBlacklist = {
  'demo_mode',
  'developer_time_machine_at_ms',
  'anonymous_id',
  'unlock_all_reviews',
  'SUPABASE_PERSIST_SESSION_KEY',
};

/// 不应跨设备恢复的 SharedPreferences key 前缀。
const _spPrefixBlacklist = [
  'app_update_',
  // Supabase Flutter 持久化会话，内含 access/refresh token。
  'sb-',
  // GoTrue PKCE code verifier 等临时认证状态。
  'supabase.auth.',
];

const _dbFileName = 'echo_loop.db';
const _v3DatabaseEntry = 'database.sqlite';
const _legacyDatabaseEntry = 'echo_loop.db';
const _v3SettingsEntry = 'settings.json';
const _legacySettingsEntry = 'preferences.json';
const _manifestEntry = 'manifest.json';
const _manifestSizeLimit = 256 * 1024;
const _settingsSizeLimit = 4 * 1024 * 1024;
const _ioBufferSize = 1024 * 1024;

typedef RestoredAppUpdateMigrator =
    Future<void> Function(SharedPreferences preferences, int fromVersion);

/// 将备份文件流式复制到桌面端用户选择的位置。
Future<void> copyBackupFileStreaming(
  String sourcePath,
  String targetPath,
) async {
  if (p.equals(p.normalize(sourcePath), p.normalize(targetPath))) return;
  final output = File(targetPath).openWrite();
  await File(sourcePath).openRead().pipe(output);
}

/// 数据备份与恢复服务。
///
/// ZIP 的文件内容始终通过磁盘流处理；内存中仅保留 manifest、设置、路径和
/// ZIP 中央目录元数据。调用方通过 [PreparedBackupImport] 和
/// [AppliedBackupImport] 将恢复提交点延迟到新数据库重新打开之后。
class BackupService {
  BackupService(
    this._database, {
    RestoredAppUpdateMigrator restoredAppUpdateMigrator =
        _runRestoredAppUpdateMigrations,
  }) : _restoredAppUpdateMigrator = restoredAppUpdateMigrator;

  final AppDatabase _database;
  final RestoredAppUpdateMigrator _restoredAppUpdateMigrator;

  /// 导出 v3 备份到 [outputDir]，返回页面会话持有的临时 `.elbak` 路径。
  Future<String> exportData({
    required String outputDir,
    required String appVersion,
    required String platform,
    void Function(BackupProgress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final dataDir = await getAppDataDirectory();
    final scratchDir = await _createTempDir('echoloop_export');
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp('[-:.]'), '')
        .replaceFirst('Z', '');
    final outputDirectory = Directory(outputDir);
    await outputDirectory.create(recursive: true);
    final finalFile = File(
      p.join(
        outputDirectory.path,
        'echoloop_backup_$timestamp.$backupFileExtension',
      ),
    );
    final partialFile = File('${finalFile.path}.part');
    _log(
      'export_start outputDir=${outputDirectory.path} '
      'scratchDir=${scratchDir.path} finalPath=${finalFile.path}',
    );

    try {
      onProgress?.call(const BackupProgress(stage: 'exportingDatabase'));
      final snapshot = File(p.join(scratchDir.path, _v3DatabaseEntry));
      await _database.createBackupSnapshot(snapshot);
      _log(
        'export_database_done path=${snapshot.path} bytes=${await snapshot.length()}',
      );

      onProgress?.call(const BackupProgress(stage: 'exportingPreferences'));
      final preferences = await SharedPreferences.getInstance();
      final settingsFile = File(p.join(scratchDir.path, _v3SettingsEntry));
      await settingsFile.writeAsString(
        jsonEncode(_dumpPreferences(preferences)),
      );
      _log('export_settings_done bytes=${await settingsFile.length()}');

      onProgress?.call(const BackupProgress(stage: 'exportingMedia'));
      final mediaSources = await _collectMediaSources(dataDir);
      _log('export_media_collected count=${mediaSources.length}');

      final dbSha256 = await sha256.bind(snapshot.openRead()).first;
      final databaseSize = await snapshot.length();
      final settingsSize = await settingsFile.length();
      final mediaSize = mediaSources.fold<int>(
        0,
        (total, source) => total + source.size,
      );
      final manifest = BackupManifest(
        version: BackupManifest.currentVersion,
        appVersion: appVersion,
        schemaVersion: _database.schemaVersion,
        appUpdateMigrationVersion:
            preferences.getInt(appUpdateMigrationVersionKey) ?? 0,
        createdAt: DateTime.now().toUtc(),
        platform: platform,
        dbSha256: dbSha256.toString(),
        mediaFileCount: mediaSources.length,
        totalSizeBytes: databaseSize + settingsSize + mediaSize,
      );

      final sources = <_ArchiveSource>[
        _ArchiveSource(_v3DatabaseEntry, snapshot.path, databaseSize),
        _ArchiveSource(_v3SettingsEntry, settingsFile.path, settingsSize),
        ...mediaSources,
      ];

      onProgress?.call(const BackupProgress(stage: 'exportingPacking'));
      final partialPath = partialFile.path;
      final manifestJson = jsonEncode(manifest.toJson());
      await Isolate.run(
        () => _createStreamingZipSync(partialPath, manifestJson, sources),
      );
      await partialFile.rename(finalFile.path);
      _log(
        'export_success path=${finalFile.path} bytes=${await finalFile.length()} '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return finalFile.path;
    } catch (error, stackTrace) {
      _logFailure('export_failed path=${finalFile.path}', error, stackTrace);
      await _deleteFileIfExists(partialFile);
      await _deleteFileIfExists(finalFile);
      rethrow;
    } finally {
      await _deleteDirectoryIfExists(scratchDir);
    }
  }

  /// 只读取受限大小的 manifest，供恢复确认弹窗预览。
  Future<BackupManifest> readManifest(String backupPath) {
    _log('manifest_read_start path=$backupPath');
    return Isolate.run(() => _readManifestSync(backupPath)).then(
      (manifest) {
        _log(
          'manifest_read_success path=$backupPath version=${manifest.version} '
          'schema=${manifest.schemaVersion}',
        );
        return manifest;
      },
      onError: (Object error, StackTrace stackTrace) {
        _logFailure('manifest_read_failed path=$backupPath', error, stackTrace);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  /// 在当前数据库仍打开时完成恢复前的全部只读校验。
  ///
  /// 数据库 entry 会流式写入临时文件；媒体内容在此阶段不会解压。
  Future<PreparedBackupImport> prepareImport({
    required String zipPath,
    void Function(BackupProgress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    onProgress?.call(const BackupProgress(stage: 'importingExtracting'));
    final tempDir = await _createTempDir('echoloop_import');
    _log('prepare_import_start zipPath=$zipPath tempDir=${tempDir.path}');
    try {
      final tempPath = tempDir.path;
      final preparedData = await Isolate.run(
        () => _prepareArchiveSync(
          zipPath,
          tempPath,
          AppDatabase.currentSchemaVersion,
        ),
      );
      final currentMediaPaths = await _collectSafeMediaPaths();
      final preferences = await SharedPreferences.getInstance();
      final prepared = PreparedBackupImport._(
        manifest: preparedData.manifest,
        zipPath: zipPath,
        tempDirectory: tempDir,
        databaseSnapshot: File(preparedData.databasePath),
        settings: preparedData.settings,
        importedMediaPaths: preparedData.importedMediaPaths,
        archiveMediaPaths: preparedData.archiveMediaPaths,
        currentMediaPaths: currentMediaPaths,
        previousSettings: _dumpPreferences(preferences),
        previousAppUpdateMigrationVersion: preferences.getInt(
          appUpdateMigrationVersionKey,
        ),
      );
      _log(
        'prepare_import_success zipPath=$zipPath version=${prepared.manifest.version} '
        'schema=${prepared.manifest.schemaVersion} media=${prepared.importedMediaPaths.length} '
        'resources=ignored durationMs=${stopwatch.elapsedMilliseconds}',
      );
      return prepared;
    } catch (error, stackTrace) {
      _logFailure('prepare_import_failed zipPath=$zipPath', error, stackTrace);
      await _deleteDirectoryIfExists(tempDir);
      rethrow;
    }
  }

  /// 数据库关闭后应用已校验的备份，并返回延迟提交的恢复会话。
  Future<AppliedBackupImport> applyPreparedImport(
    PreparedBackupImport prepared, {
    void Function(BackupProgress)? onProgress,
  }) async {
    final dataDir = await getAppDataDirectory();
    final session = AppliedBackupImport._(
      prepared: prepared,
      dataDirectory: dataDir,
    );
    _log(
      'apply_import_start zipPath=${prepared.zipPath} '
      'dataDir=${dataDir.path} '
      'rollbackDir=${session._rollbackDirectory.path}',
    );

    try {
      await session._protectCurrentData();
      _log('apply_import_data_protected');

      onProgress?.call(const BackupProgress(stage: 'importingMedia'));
      session._payloadExtractionStarted = true;
      final archiveMediaPaths = prepared.archiveMediaPaths.toList();
      await Isolate.run(
        () => _extractPayloadSync(
          prepared.zipPath,
          dataDir.path,
          prepared.manifest.version,
          archiveMediaPaths,
        ),
      );
      _log(
        'apply_import_payload_done media=${prepared.archiveMediaPaths.length} '
        'resources=ignored',
      );

      onProgress?.call(const BackupProgress(stage: 'importingDatabase'));
      await session._installDatabase();
      _log(
        'apply_import_database_done path=${p.join(dataDir.path, _dbFileName)}',
      );

      onProgress?.call(const BackupProgress(stage: 'importingPreferences'));
      session._settingsWereApplied = true;
      await _restorePreferences(prepared.settings);
      final preferences = await SharedPreferences.getInstance();
      await _restoredAppUpdateMigrator(
        preferences,
        prepared.manifest.appUpdateMigrationVersion,
      );
      _log('apply_import_preferences_done');
      return session;
    } catch (error, stackTrace) {
      _logFailure(
        'apply_import_failed zipPath=${prepared.zipPath}',
        error,
        stackTrace,
      );
      try {
        await session.rollback();
        _log('apply_import_rollback_success');
      } catch (rollbackError, rollbackStackTrace) {
        _logFailure(
          'apply_import_rollback_failed',
          rollbackError,
          rollbackStackTrace,
        );
      }
      rethrow;
    }
  }

  Future<List<_ArchiveSource>> _collectMediaSources(Directory dataDir) async {
    final paths = await _collectSafeMediaPaths();
    final sources = <_ArchiveSource>[];
    final resolvedRoot = await dataDir.resolveSymbolicLinks();
    for (final relativePath in paths) {
      final file = File(_joinRelative(dataDir.path, relativePath));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.file) continue;
      final resolvedFile = await file.resolveSymbolicLinks();
      if (!p.isWithin(resolvedRoot, resolvedFile)) continue;
      sources.add(
        _ArchiveSource('media/$relativePath', file.path, await file.length()),
      );
    }
    return sources;
  }

  Future<Set<String>> _collectSafeMediaPaths() async {
    final rows = await _database
        .customSelect('SELECT audio_path, transcript_path FROM audio_items')
        .get();
    final paths = <String>{};
    for (final row in rows) {
      for (final column in ['audio_path', 'transcript_path']) {
        final value = row.readNullable<String>(column);
        if (value == null || value.isEmpty) continue;
        final safePath = _tryNormalizeDataPath(value);
        if (safePath != null) paths.add(safePath);
      }
    }
    return paths;
  }
}

/// 已通过完整只读校验、等待应用的恢复数据。
class PreparedBackupImport {
  PreparedBackupImport._({
    required this.manifest,
    required this.zipPath,
    required this.tempDirectory,
    required this.databaseSnapshot,
    required this.settings,
    required this.importedMediaPaths,
    required this.archiveMediaPaths,
    required this.currentMediaPaths,
    required this.previousSettings,
    required this.previousAppUpdateMigrationVersion,
  });

  final BackupManifest manifest;
  final String zipPath;
  final Directory tempDirectory;
  final File databaseSnapshot;
  final Map<String, Object?> settings;
  final Set<String> importedMediaPaths;
  final Set<String> archiveMediaPaths;
  final Set<String> currentMediaPaths;
  final Map<String, Object?> previousSettings;
  final int? previousAppUpdateMigrationVersion;

  /// 清理数据库快照和恢复准备目录。
  Future<void> dispose() => _deleteDirectoryIfExists(tempDirectory);
}

/// 已写入新数据但尚未最终提交的恢复会话。
class AppliedBackupImport {
  AppliedBackupImport._({required this.prepared, required this.dataDirectory})
    : _token = DateTime.now().microsecondsSinceEpoch.toString(),
      _rollbackDirectory = Directory(
        p.join(
          dataDirectory.path,
          '.backup_restore_rollback_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );

  final PreparedBackupImport prepared;
  final Directory dataDirectory;
  final String _token;
  final Directory _rollbackDirectory;
  final List<String> _protectedMediaPaths = [];
  final Map<String, String> _protectedDatabaseFiles = {};
  bool _payloadExtractionStarted = false;
  bool _databaseWasInstalled = false;
  bool _settingsWereApplied = false;
  bool _finalized = false;

  Future<void> _protectCurrentData() async {
    await _rollbackDirectory.create(recursive: true);
    _log('rollback_area_created path=${_rollbackDirectory.path}');
    final allMediaPaths = <String>{
      ...prepared.currentMediaPaths,
      ...prepared.importedMediaPaths,
    }.toList()..sort();

    for (final relativePath in allMediaPaths) {
      final source = File(_joinRelative(dataDirectory.path, relativePath));
      final type = await FileSystemEntity.type(source.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw BackupException(
          'Invalid media destination: $relativePath',
          code: BackupFailureCode.unsafeArchive,
        );
      }
      await _ensureNoSymlinkAncestors(dataDirectory.path, relativePath);
      final rollback = File(
        _joinRelative(p.join(_rollbackDirectory.path, 'media'), relativePath),
      );
      await rollback.parent.create(recursive: true);
      await source.rename(rollback.path);
      _protectedMediaPaths.add(relativePath);
    }

    for (final suffix in ['', '-wal', '-shm']) {
      final source = File(p.join(dataDirectory.path, '$_dbFileName$suffix'));
      if (!await source.exists()) continue;
      final rollback = File(
        p.join(_rollbackDirectory.path, 'database', '$_dbFileName$suffix'),
      );
      await rollback.parent.create(recursive: true);
      await source.rename(rollback.path);
      _protectedDatabaseFiles[source.path] = rollback.path;
    }
    _log(
      'current_data_protected media=${_protectedMediaPaths.length} '
      'databaseFiles=${_protectedDatabaseFiles.length}',
    );
  }

  Future<void> _installDatabase() async {
    final destination = File(p.join(dataDirectory.path, _dbFileName));
    final partial = File('${destination.path}.restore-$_token.part');
    await _deleteFileIfExists(partial);
    final sink = partial.openWrite();
    try {
      await prepared.databaseSnapshot.openRead().pipe(sink);
      await partial.rename(destination.path);
      _databaseWasInstalled = true;
    } catch (_) {
      await sink.close();
      await _deleteFileIfExists(partial);
      rethrow;
    }
  }

  /// 确认新数据库和 Provider 已正常加载，删除旧数据回滚区。
  Future<void> commit() async {
    if (_finalized) return;
    _finalized = true;
    await _deleteDirectoryIfExists(_rollbackDirectory);
    _log('apply_import_commit_success rollbackDir=${_rollbackDirectory.path}');
  }

  /// 删除新数据并恢复旧数据库、媒体和 SharedPreferences。
  Future<void> rollback() async {
    if (_finalized) return;
    _finalized = true;

    if (_payloadExtractionStarted) {
      for (final relativePath in prepared.importedMediaPaths) {
        await _deleteFileIfExists(
          File(_joinRelative(dataDirectory.path, relativePath)),
        );
      }
    }
    for (final relativePath in _protectedMediaPaths.reversed) {
      final rollback = File(
        _joinRelative(p.join(_rollbackDirectory.path, 'media'), relativePath),
      );
      if (!await rollback.exists()) continue;
      final target = File(_joinRelative(dataDirectory.path, relativePath));
      await target.parent.create(recursive: true);
      await rollback.rename(target.path);
    }

    if (_databaseWasInstalled) {
      for (final suffix in ['', '-wal', '-shm']) {
        await _deleteFileIfExists(
          File(p.join(dataDirectory.path, '$_dbFileName$suffix')),
        );
      }
    }
    for (final entry in _protectedDatabaseFiles.entries) {
      final rollback = File(entry.value);
      if (!await rollback.exists()) continue;
      await _deleteFileIfExists(File(entry.key));
      await rollback.parent.create(recursive: true);
      await rollback.rename(entry.key);
    }

    if (_settingsWereApplied) {
      await _restorePreferences(prepared.previousSettings);
      final preferences = await SharedPreferences.getInstance();
      final previousVersion = prepared.previousAppUpdateMigrationVersion;
      if (previousVersion == null) {
        await preferences.remove(appUpdateMigrationVersionKey);
      } else {
        await preferences.setInt(appUpdateMigrationVersionKey, previousVersion);
      }
    }
    await _deleteDirectoryIfExists(_rollbackDirectory);
    _log('apply_import_rollback_cleaned path=${_rollbackDirectory.path}');
  }
}

void _log(String message) => AppLogger.log('Backup', message);

void _logFailure(String operation, Object error, StackTrace stackTrace) {
  _log('$operation error=$error');
  _log('$operation stackTrace=$stackTrace');
}

/// 使恢复数据从备份时的迁移进度继续升级到当前版本。
Future<void> _runRestoredAppUpdateMigrations(
  SharedPreferences preferences,
  int fromVersion,
) async {
  if (fromVersion < 0 || fromVersion > currentAppUpdateMigrationVersion) {
    throw BackupException(
      'Unsupported app update migration version: $fromVersion',
      code: BackupFailureCode.incompatibleVersion,
    );
  }
  await preferences.setInt(appUpdateMigrationVersionKey, fromVersion);
  await runAppUpdateMigrations(preferences);
}

void _createStreamingZipSync(
  String outputPath,
  String manifestJson,
  List<_ArchiveSource> sources,
) {
  final output = OutputFileStream(outputPath, bufferSize: _ioBufferSize);
  final encoder = ZipEncoder()..startEncode(output, level: 0);
  try {
    final manifest = ArchiveFile.string(_manifestEntry, manifestJson)
      ..compression = CompressionType.none;
    encoder.add(manifest);
    for (final directory in ['media/']) {
      final entry = ArchiveFile.directory(directory)
        ..compression = CompressionType.none;
      encoder.add(entry);
    }
    for (final source in sources) {
      final input = InputFileStream(source.filePath, bufferSize: _ioBufferSize);
      final entry = ArchiveFile.stream(source.archivePath, input)
        ..compression = CompressionType.none;
      encoder.add(entry);
    }
    encoder.endEncode();
    output.closeSync();
  } catch (_) {
    output.closeSync();
    rethrow;
  }
}

BackupManifest _readManifestSync(String backupPath) {
  final headers = _validateZipHeaders(backupPath);
  return _withDecodedArchive(backupPath, (archive) {
    final entry = archive.findFile(_manifestEntry);
    if (entry == null || !entry.isFile) {
      throw const BackupException(
        'Invalid backup: manifest.json not found',
        code: BackupFailureCode.invalidArchive,
      );
    }
    final manifest = _decodeManifest(
      _readSmallEntry(entry, _manifestSizeLimit),
    );
    if (manifest.version < 1 ||
        manifest.version > BackupManifest.currentVersion) {
      throw BackupException(
        'Unsupported backup version: ${manifest.version}',
        code: BackupFailureCode.unsupportedVersion,
      );
    }
    _validateAppUpdateMigrationVersion(manifest);
    _validateVersionSpecificEntries(headers, manifest.version);
    return manifest;
  });
}

_PreparedArchiveData _prepareArchiveSync(
  String backupPath,
  String tempDirectory,
  int currentSchemaVersion,
) {
  final headers = _validateZipHeaders(backupPath);
  return _withDecodedArchive(backupPath, (archive) {
    final manifestEntry = archive.findFile(_manifestEntry);
    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const BackupException(
        'Invalid backup: manifest.json not found',
        code: BackupFailureCode.invalidArchive,
      );
    }
    final manifest = _decodeManifest(
      _readSmallEntry(manifestEntry, _manifestSizeLimit),
    );
    if (manifest.version < 1 ||
        manifest.version > BackupManifest.currentVersion) {
      throw BackupException(
        'Unsupported backup version: ${manifest.version}',
        code: BackupFailureCode.unsupportedVersion,
      );
    }
    _validateAppUpdateMigrationVersion(manifest);
    if (manifest.schemaVersion > currentSchemaVersion) {
      throw const BackupException(
        'incompatibleVersion',
        code: BackupFailureCode.incompatibleVersion,
      );
    }

    _validateVersionSpecificEntries(headers, manifest.version);
    final databaseEntryName = manifest.version >= 3
        ? _v3DatabaseEntry
        : _legacyDatabaseEntry;
    final settingsEntryName = manifest.version >= 3
        ? _v3SettingsEntry
        : _legacySettingsEntry;
    final databaseEntry = archive.findFile(databaseEntryName);
    final settingsEntry = archive.findFile(settingsEntryName);
    if (databaseEntry == null || !databaseEntry.isFile) {
      throw const BackupException(
        'Invalid backup: database file not found',
        code: BackupFailureCode.invalidArchive,
      );
    }
    if (settingsEntry == null || !settingsEntry.isFile) {
      throw const BackupException(
        'Invalid backup: settings file not found',
        code: BackupFailureCode.invalidArchive,
      );
    }

    final databasePath = p.join(tempDirectory, _v3DatabaseEntry);
    _writeEntryToFileVerified(databaseEntry, databasePath);
    final databaseHash = _computeFileSha256Sync(databasePath);
    if (databaseHash.toLowerCase() != manifest.dbSha256.toLowerCase()) {
      throw const BackupException(
        'Database file corrupted (SHA256 mismatch)',
        code: BackupFailureCode.corruptedArchive,
      );
    }

    final importedMediaPaths = _validateDatabaseSnapshot(
      databasePath,
      manifest.schemaVersion,
    );
    final archiveMediaPaths = <String>{};
    for (final header in headers) {
      final name = _canonicalArchivePath(header.filename);
      if (name.startsWith('media/') && !name.endsWith('/')) {
        final relative = name.substring('media/'.length);
        if (!importedMediaPaths.contains(relative)) {
          throw BackupException(
            'Media entry is not referenced by database: $name',
            code: BackupFailureCode.unsafeArchive,
          );
        }
        archiveMediaPaths.add(relative);
      }
    }

    final settings = _decodeSettings(
      _readSmallEntry(settingsEntry, _settingsSizeLimit),
    );
    return _PreparedArchiveData(
      manifest: manifest,
      databasePath: databasePath,
      settings: settings,
      importedMediaPaths: importedMediaPaths,
      archiveMediaPaths: archiveMediaPaths,
    );
  });
}

void _extractPayloadSync(
  String backupPath,
  String dataDirectory,
  int expectedVersion,
  List<String> expectedMediaPaths,
) {
  final headers = _validateZipHeaders(backupPath);
  _validateVersionSpecificEntries(headers, expectedVersion);
  final expectedMedia = expectedMediaPaths.toSet();
  _withDecodedArchive<void>(backupPath, (archive) {
    for (final entry in archive) {
      final name = _canonicalArchivePath(entry.name);
      if (!entry.isFile) continue;
      if (name.startsWith('media/')) {
        final relative = name.substring('media/'.length);
        if (!expectedMedia.contains(relative)) {
          throw BackupException(
            'Unexpected media entry: $name',
            code: BackupFailureCode.unsafeArchive,
          );
        }
        _writeEntryAtomically(entry, _joinRelative(dataDirectory, relative));
      }
    }
  });
}

List<ZipFileHeader> _validateZipHeaders(String backupPath) {
  final file = File(backupPath);
  if (!file.existsSync()) {
    throw const BackupException(
      'Backup file does not exist',
      code: BackupFailureCode.invalidArchive,
    );
  }
  final input = InputFileStream(backupPath, bufferSize: _ioBufferSize);
  try {
    final directory = ZipDirectory()..read(input);
    if (directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.fileHeaders.length !=
            directory.totalCentralDirectoryEntries ||
        directory.fileHeaders.isEmpty) {
      throw const BackupException(
        'Invalid or multi-part ZIP archive',
        code: BackupFailureCode.invalidArchive,
      );
    }
    final exactPaths = <String>{};
    final foldedPaths = <String>{};
    for (final header in directory.fileHeaders) {
      final name = _canonicalArchivePath(header.filename);
      if (!exactPaths.add(name) || !foldedPaths.add(name.toLowerCase())) {
        throw BackupException(
          'Duplicate archive entry: $name',
          code: BackupFailureCode.unsafeArchive,
        );
      }
      if ((header.generalPurposeBitFlag & 0x1) != 0) {
        throw BackupException(
          'Encrypted archive entry is not supported: $name',
          code: BackupFailureCode.unsafeArchive,
        );
      }
      if (header.compressionMethod != ZipFile.zipCompressionStore &&
          header.compressionMethod != ZipFile.zipCompressionDeflate) {
        throw BackupException(
          'Unsupported ZIP compression method: ${header.compressionMethod}',
          code: BackupFailureCode.invalidArchive,
        );
      }
      final fileType = (header.externalFileAttributes >> 16) & 0xf000;
      if (fileType == 0xa000 ||
          (fileType != 0 && fileType != 0x4000 && fileType != 0x8000)) {
        throw BackupException(
          'Unsupported archive entry type: $name',
          code: BackupFailureCode.unsafeArchive,
        );
      }
    }
    return List<ZipFileHeader>.unmodifiable(directory.fileHeaders);
  } on BackupException {
    rethrow;
  } catch (error) {
    throw BackupException(
      'Invalid ZIP archive: $error',
      code: BackupFailureCode.invalidArchive,
    );
  } finally {
    input.closeSync();
  }
}

void _validateVersionSpecificEntries(List<ZipFileHeader> headers, int version) {
  var hasManifest = false;
  var hasDatabase = false;
  var hasSettings = false;
  for (final header in headers) {
    final name = _canonicalArchivePath(header.filename);
    final isDirectory = name.endsWith('/');
    final isManifest = name == _manifestEntry;
    final isDatabase =
        name == (version >= 3 ? _v3DatabaseEntry : _legacyDatabaseEntry);
    final isSettings =
        name == (version >= 3 ? _v3SettingsEntry : _legacySettingsEntry);
    final isMedia = name == 'media/' || name.startsWith('media/');
    final isResource =
        version >= 2 &&
        (name == 'resources/' ||
            name == 'resources/dictionary/' ||
            name.startsWith('resources/dictionary/'));
    if (!isManifest && !isDatabase && !isSettings && !isMedia && !isResource) {
      throw BackupException(
        'Unexpected archive entry: $name',
        code: BackupFailureCode.unsafeArchive,
      );
    }
    if (version >= 3 &&
        !isDirectory &&
        header.compressionMethod != ZipFile.zipCompressionStore) {
      throw BackupException(
        'v3 entry must use Store mode: $name',
        code: BackupFailureCode.invalidArchive,
      );
    }
    hasManifest |= isManifest;
    hasDatabase |= isDatabase;
    hasSettings |= isSettings;
  }
  if (!hasManifest || !hasDatabase || !hasSettings) {
    throw const BackupException(
      'Backup is missing required entries',
      code: BackupFailureCode.invalidArchive,
    );
  }
}

T _withDecodedArchive<T>(
  String backupPath,
  T Function(Archive archive) action,
) {
  final input = InputFileStream(backupPath, bufferSize: _ioBufferSize);
  Archive? archive;
  try {
    archive = ZipDecoder().decodeStream(input);
    return action(archive);
  } on BackupException {
    rethrow;
  } catch (error) {
    throw BackupException(
      'Corrupted ZIP archive: $error',
      code: BackupFailureCode.corruptedArchive,
    );
  } finally {
    archive?.clearSync();
    input.closeSync();
  }
}

void _validateAppUpdateMigrationVersion(BackupManifest manifest) {
  final version = manifest.appUpdateMigrationVersion;
  if (version < 0 || version > currentAppUpdateMigrationVersion) {
    throw BackupException(
      'Unsupported app update migration version: $version',
      code: BackupFailureCode.incompatibleVersion,
    );
  }
}

String _canonicalArchivePath(String rawName) {
  if (rawName.isEmpty ||
      rawName.length > 1024 ||
      rawName.contains('\u0000') ||
      rawName.contains('\\') ||
      p.posix.isAbsolute(rawName) ||
      p.windows.isAbsolute(rawName)) {
    throw BackupException(
      'Invalid archive path: $rawName',
      code: BackupFailureCode.unsafeArchive,
    );
  }
  final isDirectory = rawName.endsWith('/');
  final pathWithoutSlash = isDirectory
      ? rawName.substring(0, rawName.length - 1)
      : rawName;
  if (pathWithoutSlash.isEmpty) {
    throw const BackupException(
      'Invalid empty archive path',
      code: BackupFailureCode.unsafeArchive,
    );
  }
  final normalized = p.posix.normalize(pathWithoutSlash);
  final segments = p.posix.split(pathWithoutSlash);
  if (normalized != pathWithoutSlash ||
      normalized == '.' ||
      normalized == '..' ||
      segments.any((segment) => segment.isEmpty || segment == '..')) {
    throw BackupException(
      'Invalid archive path: $rawName',
      code: BackupFailureCode.unsafeArchive,
    );
  }
  return isDirectory ? '$normalized/' : normalized;
}

String? _tryNormalizeDataPath(String rawPath) {
  if (rawPath.isEmpty ||
      rawPath.contains('\u0000') ||
      rawPath.contains('\\') ||
      p.posix.isAbsolute(rawPath) ||
      p.windows.isAbsolute(rawPath)) {
    return null;
  }
  final normalized = p.posix.normalize(rawPath);
  final segments = p.posix.split(rawPath);
  if (normalized != rawPath ||
      normalized == '.' ||
      normalized == '..' ||
      segments.any((segment) => segment.isEmpty || segment == '..')) {
    return null;
  }
  const reservedRoots = {
    'echo_loop.db',
    'echo_loop.db-wal',
    'echo_loop.db-shm',
    'echo_loop_demo.db',
    'dictionary',
    'tmp',
    'cache',
    'logs',
    'asr-models',
    'tts-models',
    'official_catalog',
  };
  if (reservedRoots.contains(segments.first) ||
      segments.first.startsWith('.backup_restore_')) {
    return null;
  }
  return normalized;
}

Set<String> _validateDatabaseSnapshot(
  String databasePath,
  int expectedSchemaVersion,
) {
  Database? database;
  try {
    database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
    final integrityRows = database.select('PRAGMA integrity_check');
    final integrity = integrityRows.isEmpty
        ? null
        : integrityRows.first.values.first;
    if (integrity != 'ok') {
      throw const BackupException(
        'Database integrity check failed',
        code: BackupFailureCode.corruptedArchive,
      );
    }
    final versionRows = database.select('PRAGMA user_version');
    final version = versionRows.isEmpty ? null : versionRows.first.values.first;
    if (version != expectedSchemaVersion) {
      throw const BackupException(
        'Database schema does not match manifest',
        code: BackupFailureCode.corruptedArchive,
      );
    }

    final paths = <String>{};
    final rows = database.select(
      'SELECT audio_path, transcript_path FROM audio_items',
    );
    for (final row in rows) {
      for (final column in ['audio_path', 'transcript_path']) {
        final value = row[column];
        if (value == null || value == '') continue;
        if (value is! String) {
          throw const BackupException(
            'Invalid media path in database',
            code: BackupFailureCode.corruptedArchive,
          );
        }
        final normalized = _tryNormalizeDataPath(value);
        if (normalized == null) {
          throw BackupException(
            'Unsafe media path in database: $value',
            code: BackupFailureCode.unsafeArchive,
          );
        }
        paths.add(normalized);
      }
    }
    return paths;
  } on BackupException {
    rethrow;
  } catch (error) {
    throw BackupException(
      'Invalid SQLite database: $error',
      code: BackupFailureCode.corruptedArchive,
    );
  } finally {
    database?.dispose();
  }
}

BackupManifest _decodeManifest(Uint8List bytes) {
  try {
    return BackupManifest.fromJson(_decodeJsonObject(bytes));
  } catch (error) {
    throw BackupException(
      'Invalid backup manifest: $error',
      code: BackupFailureCode.invalidArchive,
    );
  }
}

Map<String, Object?> _decodeSettings(Uint8List bytes) {
  final decoded = _decodeJsonObject(bytes);
  final normalized = <String, Object?>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value == null ||
        value is String ||
        value is int ||
        value is double ||
        value is bool) {
      normalized[entry.key] = value;
      continue;
    }
    if (value is List) {
      final strings = <String>[];
      for (final item in value) {
        if (item is! String) {
          throw const BackupException(
            'Invalid settings list value',
            code: BackupFailureCode.invalidArchive,
          );
        }
        strings.add(item);
      }
      normalized[entry.key] = strings;
      continue;
    }
    throw BackupException(
      'Unsupported setting value: ${entry.key}',
      code: BackupFailureCode.invalidArchive,
    );
  }
  return normalized;
}

Map<String, Object?> _decodeJsonObject(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object');
  }
  final result = <String, Object?>{};
  for (final entry in decoded.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException('JSON object key must be a string');
    }
    result[key] = entry.value;
  }
  return result;
}

Uint8List _readSmallEntry(ArchiveFile entry, int limit) {
  if (entry.size < 0 || entry.size > limit) {
    throw BackupException(
      'Archive entry is too large: ${entry.name}',
      code: BackupFailureCode.invalidArchive,
    );
  }
  final output = OutputMemoryStream(size: entry.size);
  _writeEntryVerified(entry, output, sizeLimit: limit);
  return output.getBytes();
}

void _writeEntryToFileVerified(ArchiveFile entry, String outputPath) {
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  final output = OutputFileStream(outputPath, bufferSize: _ioBufferSize);
  try {
    _writeEntryVerified(entry, output);
    output.closeSync();
  } catch (_) {
    output.closeSync();
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}

void _writeEntryAtomically(ArchiveFile entry, String outputPath) {
  final target = File(outputPath);
  target.parent.createSync(recursive: true);
  final partial = File('$outputPath.restore.part');
  if (partial.existsSync()) partial.deleteSync();
  try {
    _writeEntryToFileVerified(entry, partial.path);
    if (target.existsSync()) target.deleteSync();
    partial.renameSync(target.path);
  } catch (_) {
    if (partial.existsSync()) partial.deleteSync();
    rethrow;
  }
}

void _writeEntryVerified(
  ArchiveFile entry,
  OutputStream output, {
  int? sizeLimit,
}) {
  final verified = _VerifyingOutputStream(output, sizeLimit: sizeLimit);
  entry.writeContent(verified, freeMemory: false);
  verified.flush();
  if (verified.length != entry.size ||
      (entry.crc32 != null && verified.crc32 != entry.crc32)) {
    throw BackupException(
      'Archive entry is truncated or corrupted: ${entry.name}',
      code: BackupFailureCode.corruptedArchive,
    );
  }
}

String _computeFileSha256Sync(String path) {
  final input = InputFileStream(path, bufferSize: _ioBufferSize);
  final collector = _SingleValueSink<Digest>();
  final digestSink = sha256.startChunkedConversion(collector);
  try {
    while (!input.isEOS) {
      final size = input.length > _ioBufferSize ? _ioBufferSize : input.length;
      if (size <= 0) break;
      digestSink.add(input.readBytes(size).toUint8List());
    }
    digestSink.close();
    final digest = collector.value;
    if (digest == null) {
      throw StateError('SHA-256 digest was not produced');
    }
    return digest.toString();
  } finally {
    input.closeSync();
  }
}

Map<String, Object?> _dumpPreferences(SharedPreferences preferences) {
  final result = <String, Object?>{};
  for (final key in preferences.getKeys()) {
    if (_shouldSkipPreference(key)) continue;
    result[key] = preferences.get(key);
  }
  return result;
}

Future<void> _restorePreferences(Map<String, Object?> data) async {
  final preferences = await SharedPreferences.getInstance();
  for (final key in preferences.getKeys()) {
    if (_shouldSkipPreference(key)) continue;
    await preferences.remove(key);
  }
  for (final entry in data.entries) {
    if (_shouldSkipPreference(entry.key)) continue;
    final value = entry.value;
    if (value is String) {
      await preferences.setString(entry.key, value);
    } else if (value is int) {
      await preferences.setInt(entry.key, value);
    } else if (value is double) {
      await preferences.setDouble(entry.key, value);
    } else if (value is bool) {
      await preferences.setBool(entry.key, value);
    } else if (value is List<String>) {
      await preferences.setStringList(entry.key, value);
    }
  }
}

bool _shouldSkipPreference(String key) {
  return _spBlacklist.contains(key) ||
      _spPrefixBlacklist.any(key.startsWith) ||
      // 旧版本 GeoInterceptor 写入；避免无用的历史地区值进入备份。
      key == 'geo_country';
}

String _joinRelative(String root, String relativePath) {
  return p.joinAll([root, ...p.posix.split(relativePath)]);
}

Future<void> _ensureNoSymlinkAncestors(String root, String relativePath) async {
  var current = root;
  final segments = p.posix.split(relativePath);
  for (final segment in segments.take(segments.length - 1)) {
    current = p.join(current, segment);
    final type = await FileSystemEntity.type(current, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw BackupException(
        'Symbolic link in media destination: $relativePath',
        code: BackupFailureCode.unsafeArchive,
      );
    }
  }
}

Future<Directory> _createTempDir(String prefix) async {
  final systemTemp = await getTemporaryDirectory();
  return systemTemp.createTemp('${prefix}_');
}

Future<void> _deleteFileIfExists(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (error, stackTrace) {
    _logFailure('cleanup_file_failed path=${file.path}', error, stackTrace);
  }
}

Future<void> _deleteDirectoryIfExists(Directory directory) async {
  try {
    if (await directory.exists()) await directory.delete(recursive: true);
  } catch (error, stackTrace) {
    _logFailure(
      'cleanup_directory_failed path=${directory.path}',
      error,
      stackTrace,
    );
  }
}

class _ArchiveSource {
  const _ArchiveSource(this.archivePath, this.filePath, this.size);

  final String archivePath;
  final String filePath;
  final int size;
}

class _PreparedArchiveData {
  const _PreparedArchiveData({
    required this.manifest,
    required this.databasePath,
    required this.settings,
    required this.importedMediaPaths,
    required this.archiveMediaPaths,
  });

  final BackupManifest manifest;
  final String databasePath;
  final Map<String, Object?> settings;
  final Set<String> importedMediaPaths;
  final Set<String> archiveMediaPaths;
}

/// 转发输出的同时计算实际大小与 CRC32，并实施可选大小上限。
class _VerifyingOutputStream extends OutputStream {
  _VerifyingOutputStream(this._target, {this.sizeLimit})
    : super(byteOrder: _target.byteOrder);

  final OutputStream _target;
  final int? sizeLimit;
  int _length = 0;
  int crc32 = 0;

  @override
  int get length => _length;

  @override
  bool get isOpen => _target.isOpen;

  @override
  void clear() => _target.clear();

  @override
  Future<void> close() => _target.close();

  @override
  void closeSync() => _target.closeSync();

  @override
  void flush() => _target.flush();

  @override
  void writeByte(int value) => writeBytes([value]);

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    final nextLength = _length + writeLength;
    if (sizeLimit != null && nextLength > sizeLimit!) {
      throw const BackupException(
        'Archive entry exceeds size limit',
        code: BackupFailureCode.invalidArchive,
      );
    }
    final checksumBytes = writeLength == bytes.length
        ? bytes
        : bytes.sublist(0, writeLength);
    crc32 = getCrc32(checksumBytes, crc32);
    _target.writeBytes(bytes, length: writeLength);
    _length = nextLength;
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final size = stream.length > _ioBufferSize
          ? _ioBufferSize
          : stream.length;
      if (size <= 0) break;
      writeBytes(stream.readBytes(size).toUint8List());
    }
  }

  @override
  Uint8List subset(int start, [int? end]) => _target.subset(start, end);
}

class _SingleValueSink<T> implements Sink<T> {
  T? value;

  @override
  void add(T data) => value = data;

  @override
  void close() {}
}

/// 备份失败分类，供 UI 映射稳定的本地化提示。
enum BackupFailureCode {
  invalidArchive,
  corruptedArchive,
  unsafeArchive,
  unsupportedVersion,
  incompatibleVersion,
}

/// 备份操作异常。
class BackupException implements Exception {
  const BackupException(
    this.message, {
    this.code = BackupFailureCode.invalidArchive,
  });

  final String message;
  final BackupFailureCode code;

  @override
  String toString() => 'BackupException: $message';
}

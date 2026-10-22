import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/services/backup/backup_manifest.dart';
import 'package:echo_loop/services/backup/backup_service.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:echo_loop/services/app_update_migration.dart';
import 'package:echo_loop/services/app_logger.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getTemporaryPath() async => rootPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupManifest', () {
    test('v3 JSON 往返与大小格式化正确', () {
      final manifest = BackupManifest(
        version: BackupManifest.currentVersion,
        appVersion: '1.2.3',
        schemaVersion: 51,
        createdAt: DateTime.utc(2026, 8, 30),
        platform: 'ios',
        dbSha256: 'abc',
        mediaFileCount: 3,
        totalSizeBytes: 2 * 1024 * 1024,
      );

      final restored = BackupManifest.fromJson(manifest.toJson());

      expect(restored.version, 3);
      expect(restored.createdAt, manifest.createdAt);
      expect(restored.formattedSize, '2.0 MB');
    });

    test('字段类型错误时拒绝解析', () {
      expect(
        () => BackupManifest.fromJson(const {
          'version': '3',
          'appVersion': '1.0.0',
        }),
        throwsFormatException,
      );
    });
  });

  group('BackupService 流式导出与恢复', () {
    late Directory root;
    late Directory dataDir;
    late Directory outputDir;
    late AppDatabase database;
    late BackupService service;
    var databaseClosed = false;

    setUp(() async {
      AppLogger.instance.clear();
      root = await Directory.systemTemp.createTemp('backup_service_test_');
      dataDir = Directory(p.join(root.path, 'data'))
        ..createSync(recursive: true);
      outputDir = Directory(p.join(root.path, 'output'))
        ..createSync(recursive: true);
      PathProviderPlatform.instance = _FakePathProvider(root.path);
      SharedPreferences.setMockInitialValues({});
      appDataDirectoryOverride = dataDir;
      database = AppDatabase(
        NativeDatabase(File(p.join(dataDir.path, 'echo_loop.db'))),
      );
      await database.customSelect('SELECT 1').get();
      service = BackupService(
        database,
        restoredAppUpdateMigrator: (preferences, fromVersion) async {
          await preferences.setInt(
            appUpdateMigrationVersionKey,
            currentAppUpdateMigrationVersion,
          );
        },
      );
    });

    tearDown(() async {
      if (!databaseClosed) {
        await database.close();
      }
      appDataDirectoryOverride = null;
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('v3 使用 Store、固定名称且不创建媒体 staging', () async {
      await _insertAudio(
        database,
        id: 'local',
        name: 'Local',
        path: 'audios/imported/local.m4a',
      );
      final audio = File(p.join(dataDir.path, 'audios/imported/local.m4a'));
      await audio.parent.create(recursive: true);
      await audio.writeAsBytes(List<int>.filled(1024 * 1024, 7));
      final dictionary = File(
        p.join(root.path, 'dictionary', 'en_zh', 'dict.sqlite'),
      );
      await dictionary.parent.create(recursive: true);
      await dictionary.writeAsBytes([1, 2, 3]);

      var checkedPackingStage = false;
      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'macos',
        onProgress: (progress) {
          if (progress.stage != 'exportingPacking') return;
          checkedPackingStage = true;
          final scratchDirs = root.listSync().whereType<Directory>().where(
            (dir) => p.basename(dir.path).startsWith('echoloop_export_'),
          );
          for (final dir in scratchDirs) {
            expect(Directory(p.join(dir.path, 'media')).existsSync(), isFalse);
          }
        },
      );

      expect(checkedPackingStage, isTrue);
      final decoded = _decodeStreaming(backupPath);
      addTearDown(decoded.close);
      final archive = decoded.archive;
      for (final name in [
        'manifest.json',
        'database.sqlite',
        'settings.json',
        'media/audios/imported/local.m4a',
      ]) {
        final entry = archive.findFile(name);
        expect(entry, isNotNull, reason: name);
        expect(entry?.compression, CompressionType.none, reason: name);
      }
      expect(archive.findFile('echo_loop.db'), isNull);
      expect(archive.findFile('preferences.json'), isNull);
      expect(archive.findFile('resources/'), isNull);
      expect(
        archive.findFile('resources/dictionary/en_zh/dict.sqlite'),
        isNull,
      );

      final manifest = await service.readManifest(backupPath);
      expect(manifest.version, BackupManifest.currentVersion);
      expect(manifest.mediaFileCount, 1);
      expect(manifest.offlineResourceFileCount, 0);
      expect(manifest.offlineResourceSizeBytes, 0);
      final logs = AppLogger.instance.entries.map((entry) => entry.message);
      expect(
        logs.any((message) => message.startsWith('export_start ')),
        isTrue,
      );
      expect(
        logs.any((message) => message.startsWith('export_success ')),
        isTrue,
      );
    });

    test('备份记录应用迁移版本但 settings 不包含进度 key', () async {
      SharedPreferences.setMockInitialValues({
        appUpdateMigrationVersionKey: 4,
        'theme_mode': 'dark',
        'sb-project-ref-auth-token': '{"refresh_token":"secret"}',
        'supabase.auth.token-code-verifier': 'pkce-secret',
        'SUPABASE_PERSIST_SESSION_KEY': 'legacy-session',
        'user_preferences_sync_state_v1': 'device-local-metadata',
        'rating_prompt_last_attempt_ms_v1': 123456789,
      });

      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'ios',
      );
      final decoded = _decodeStreaming(backupPath);
      addTearDown(decoded.close);
      final manifest = BackupManifest.fromJson(
        jsonDecode(
              utf8.decode(decoded.archive.findFile('manifest.json')!.content),
            )
            as Map<String, Object?>,
      );
      final settings =
          jsonDecode(
                utf8.decode(decoded.archive.findFile('settings.json')!.content),
              )
              as Map<String, Object?>;

      expect(manifest.appUpdateMigrationVersion, 4);
      expect(settings, containsPair('theme_mode', 'dark'));
      expect(settings, isNot(contains(appUpdateMigrationVersionKey)));
      expect(settings, isNot(contains('sb-project-ref-auth-token')));
      expect(settings, isNot(contains('supabase.auth.token-code-verifier')));
      expect(settings, isNot(contains('SUPABASE_PERSIST_SESSION_KEY')));
      expect(settings, isNot(contains('user_preferences_sync_state_v1')));
      expect(settings, isNot(contains('rating_prompt_last_attempt_ms_v1')));
    });

    test('恢复时从 manifest 版本继续执行应用迁移', () async {
      SharedPreferences.setMockInitialValues({
        appUpdateMigrationVersionKey: 4,
        'user_preferences_sync_state_v1': 'current-device-metadata',
      });
      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'ios',
      );
      SharedPreferences.setMockInitialValues({
        appUpdateMigrationVersionKey: currentAppUpdateMigrationVersion,
        'rating_prompt_last_attempt_ms_v1': 987654321,
        'user_preferences_sync_state_v1': 'current-device-metadata',
      });
      int? restoredFromVersion;
      service = BackupService(
        database,
        restoredAppUpdateMigrator: (preferences, fromVersion) async {
          restoredFromVersion = fromVersion;
          await preferences.setInt(
            appUpdateMigrationVersionKey,
            currentAppUpdateMigrationVersion,
          );
        },
      );

      final prepared = await service.prepareImport(zipPath: backupPath);
      addTearDown(prepared.dispose);
      await database.close();
      databaseClosed = true;
      final applied = await service.applyPreparedImport(prepared);
      addTearDown(applied.rollback);

      expect(restoredFromVersion, 4);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'rating_prompt_last_attempt_ms_v1',
        ),
        987654321,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getInt(appUpdateMigrationVersionKey),
        currentAppUpdateMigrationVersion,
      );
      expect(
        preferences.getString('user_preferences_sync_state_v1'),
        'current-device-metadata',
      );
    });

    test('恢复旧 schema 数据库后 Drift 自动迁移到当前版本', () async {
      final snapshot = File(p.join(root.path, 'schema_50.sqlite'));
      await database.createBackupSnapshot(snapshot);
      final raw = sqlite.sqlite3.open(snapshot.path);
      raw.execute('PRAGMA user_version = 50');
      raw.dispose();
      final hash = await sha256.bind(snapshot.openRead()).first;
      final backup = File(p.join(outputDir.path, 'schema_50.elbak'));
      _writeZip(backup.path, [
        ArchiveFile.string(
          'manifest.json',
          jsonEncode(
            BackupManifest(
              version: 3,
              appVersion: '1.0.0',
              schemaVersion: 50,
              appUpdateMigrationVersion: currentAppUpdateMigrationVersion,
              createdAt: DateTime.utc(2026, 8, 30),
              platform: 'test',
              dbSha256: hash.toString(),
              mediaFileCount: 0,
              totalSizeBytes: await snapshot.length(),
            ).toJson(),
          ),
        )..compression = CompressionType.none,
        ArchiveFile.stream('database.sqlite', InputFileStream(snapshot.path))
          ..compression = CompressionType.none,
        ArchiveFile.string('settings.json', '{}')
          ..compression = CompressionType.none,
      ]);

      final prepared = await service.prepareImport(zipPath: backup.path);
      addTearDown(prepared.dispose);
      await database.close();
      databaseClosed = true;
      final applied = await service.applyPreparedImport(prepared);
      final restored = AppDatabase(
        NativeDatabase(File(p.join(dataDir.path, 'echo_loop.db'))),
      );
      final version = await restored
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(
        version.read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
      await restored.close();
      await applied.commit();
    });

    test('缺失的数据库媒体引用被静默跳过', () async {
      await _insertAudio(
        database,
        id: 'missing',
        name: 'Missing',
        path: 'audios/missing.m4a',
      );

      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'android',
      );
      final decoded = _decodeStreaming(backupPath);
      addTearDown(decoded.close);

      expect(decoded.archive.findFile('media/audios/missing.m4a'), isNull);
      expect((await service.readManifest(backupPath)).mediaFileCount, 0);
    });

    for (final fixture in [
      (version: 1, compression: CompressionType.deflate),
      (version: 2, compression: CompressionType.none),
    ]) {
      test('兼容 v${fixture.version} ${fixture.compression.name} 恢复', () async {
        await _insertAudio(
          database,
          id: 'legacy',
          name: 'Legacy Backup',
          path: 'audios/legacy.m4a',
        );
        final media = File(p.join(dataDir.path, 'audios/legacy.m4a'));
        await media.parent.create(recursive: true);
        await media.writeAsBytes([1, 2, 3]);
        final legacyBackup = await _createLegacyBackup(
          root: root,
          database: database,
          media: media,
          version: fixture.version,
          compression: fixture.compression,
          includeDictionary: fixture.version >= 2,
        );

        await database.customStatement(
          "UPDATE audio_items SET name = 'Current Data' WHERE id = 'legacy'",
        );
        await media.writeAsBytes([9, 9, 9]);
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'sb-project-ref-auth-token',
          'current-session',
        );
        await preferences.setString(
          'supabase.auth.token-code-verifier',
          'current-pkce',
        );
        await preferences.setInt('rating_prompt_last_attempt_ms_v1', 987654321);
        final currentDictionary = File(
          p.join(root.path, 'dictionary', 'legacy', 'dict.sqlite'),
        );
        await currentDictionary.parent.create(recursive: true);
        await currentDictionary.writeAsBytes([9, 9, 9]);

        final prepared = await service.prepareImport(
          zipPath: legacyBackup.path,
        );
        addTearDown(prepared.dispose);
        await database.close();
        databaseClosed = true;
        final applied = await service.applyPreparedImport(prepared);

        final restoredDb = AppDatabase(
          NativeDatabase(File(p.join(dataDir.path, 'echo_loop.db'))),
        );
        final row = await restoredDb
            .customSelect("SELECT name FROM audio_items WHERE id = 'legacy'")
            .getSingle();
        expect(row.read<String>('name'), 'Legacy Backup');
        await restoredDb.close();
        await applied.commit();
        expect(await media.readAsBytes(), [1, 2, 3]);
        expect(
          preferences.getString('sb-project-ref-auth-token'),
          'current-session',
        );
        expect(
          preferences.getString('supabase.auth.token-code-verifier'),
          'current-pkce',
        );

        expect(
          preferences.getInt('rating_prompt_last_attempt_ms_v1'),
          987654321,
        );

        if (fixture.version == 2) {
          expect(await currentDictionary.readAsBytes(), [9, 9, 9]);
        }
      });
    }

    test('恢复会话回滚数据库、媒体和设置且不修改词典', () async {
      await _insertAudio(
        database,
        id: 'rollback',
        name: 'Backup Data',
        path: 'audios/rollback.m4a',
      );
      final media = File(p.join(dataDir.path, 'audios/rollback.m4a'));
      await media.parent.create(recursive: true);
      await media.writeAsBytes([1, 1, 1]);
      final dictionary = File(
        p.join(root.path, 'dictionary', 'main', 'dict.sqlite'),
      );
      await dictionary.parent.create(recursive: true);
      await dictionary.writeAsBytes([2, 2, 2]);
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'backup',
        appUpdateMigrationVersionKey: 4,
      });
      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'ios',
      );

      await database.customStatement(
        "UPDATE audio_items SET name = 'Current Data' WHERE id = 'rollback'",
      );
      await media.writeAsBytes([9, 9, 9]);
      await dictionary.writeAsBytes([8, 8, 8]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', 'current');
      await prefs.setInt(appUpdateMigrationVersionKey, 7);

      final prepared = await service.prepareImport(zipPath: backupPath);
      addTearDown(prepared.dispose);
      await database.close();
      databaseClosed = true;
      final applied = await service.applyPreparedImport(prepared);
      await applied.rollback();

      final restoredCurrent = AppDatabase(
        NativeDatabase(File(p.join(dataDir.path, 'echo_loop.db'))),
      );
      final row = await restoredCurrent
          .customSelect("SELECT name FROM audio_items WHERE id = 'rollback'")
          .getSingle();
      expect(row.read<String>('name'), 'Current Data');
      expect(await media.readAsBytes(), [9, 9, 9]);
      expect(await dictionary.readAsBytes(), [8, 8, 8]);
      expect(prefs.getString('theme_mode'), 'current');
      expect(prefs.getInt(appUpdateMigrationVersionKey), 7);
      expect(
        dataDir.listSync().whereType<Directory>().where(
          (dir) => p.basename(dir.path).startsWith('.backup_restore_rollback_'),
        ),
        isEmpty,
      );
      await restoredCurrent.close();
    });

    test('媒体 entry 损坏时自动回滚已保护的数据', () async {
      await _insertAudio(
        database,
        id: 'corrupt-media',
        name: 'Backup Data',
        path: 'audios/corrupt.m4a',
      );
      final media = File(p.join(dataDir.path, 'audios/corrupt.m4a'));
      await media.parent.create(recursive: true);
      await media.writeAsBytes([1, 2, 3, 4]);
      final backupPath = await service.exportData(
        outputDir: outputDir.path,
        appVersion: '1.0.0',
        platform: 'ios',
      );
      _corruptStoredEntry(backupPath, 'media/audios/corrupt.m4a');

      await database.customStatement(
        "UPDATE audio_items SET name = 'Current Data' "
        "WHERE id = 'corrupt-media'",
      );
      await media.writeAsBytes([9, 9, 9, 9]);

      final prepared = await service.prepareImport(zipPath: backupPath);
      addTearDown(prepared.dispose);
      await database.close();
      databaseClosed = true;

      await expectLater(
        service.applyPreparedImport(prepared),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            BackupFailureCode.corruptedArchive,
          ),
        ),
      );

      final restoredCurrent = AppDatabase(
        NativeDatabase(File(p.join(dataDir.path, 'echo_loop.db'))),
      );
      final row = await restoredCurrent
          .customSelect(
            "SELECT name FROM audio_items WHERE id = 'corrupt-media'",
          )
          .getSingle();
      expect(row.read<String>('name'), 'Current Data');
      expect(await media.readAsBytes(), [9, 9, 9, 9]);
      await restoredCurrent.close();
    });

    test('数据库哈希错误在关闭当前数据库前失败', () async {
      await _insertAudio(
        database,
        id: 'safe',
        name: 'Safe',
        path: 'audios/safe.m4a',
      );
      final media = File(p.join(dataDir.path, 'audios/safe.m4a'));
      await media.parent.create(recursive: true);
      await media.writeAsBytes([7]);
      final backup = await _createLegacyBackup(
        root: root,
        database: database,
        media: media,
        version: 1,
        compression: CompressionType.none,
        dbHashOverride: 'bad-hash',
      );

      await expectLater(
        service.prepareImport(zipPath: backup.path),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            BackupFailureCode.corruptedArchive,
          ),
        ),
      );
      expect(await database.customSelect('SELECT 1').getSingle(), isNotNull);
      expect(await media.readAsBytes(), [7]);
    });

    test('readManifest 不读取大型 Store 媒体到内存', () async {
      final largeFile = File(p.join(root.path, 'large.m4a'));
      final random = await largeFile.open(mode: FileMode.write);
      await random.truncate(16 * 1024 * 1024);
      await random.close();
      final backup = File(p.join(outputDir.path, 'large.elbak'));
      _writeZip(backup.path, [
        ArchiveFile.string(
          'manifest.json',
          jsonEncode(_manifest(version: 3, dbSha256: 'unused').toJson()),
        )..compression = CompressionType.none,
        ArchiveFile.string('database.sqlite', 'unused')
          ..compression = CompressionType.none,
        ArchiveFile.string('settings.json', '{}')
          ..compression = CompressionType.none,
        ArchiveFile.stream(
          'media/audios/large.m4a',
          InputFileStream(largeFile.path),
        )..compression = CompressionType.none,
      ]);

      final manifest = await service.readManifest(backup.path);

      expect(manifest.version, 3);
      expect(await backup.length(), greaterThan(16 * 1024 * 1024));
    });

    test('桌面保存通过文件流复制完整备份', () async {
      final source = File(p.join(root.path, 'source.elbak'));
      final handle = await source.open(mode: FileMode.write);
      await handle.writeFrom(List<int>.generate(1024 * 1024, (i) => i % 251));
      await handle.close();
      final target = File(p.join(root.path, 'saved.elbak'));

      await copyBackupFileStreaming(source.path, target.path);

      expect(
        await sha256.bind(source.openRead()).first,
        await sha256.bind(target.openRead()).first,
      );
      expect(await target.length(), await source.length());
    });
  });

  group('BackupService ZIP 安全校验', () {
    late Directory root;
    late AppDatabase database;
    late BackupService service;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('backup_security_test_');
      database = AppDatabase(NativeDatabase.memory());
      service = BackupService(database);
    });

    tearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });

    for (final unsafePath in [
      '../outside',
      '/absolute/path',
      r'C:\absolute\path',
      'media/../../secret',
    ]) {
      test('拒绝危险路径 $unsafePath', () async {
        final backup = File(p.join(root.path, 'unsafe.elbak'));
        _writeZip(backup.path, [ArchiveFile.string(unsafePath, 'bad')]);

        await expectLater(
          service.readManifest(backup.path),
          throwsA(
            isA<BackupException>().having(
              (error) => error.code,
              'code',
              BackupFailureCode.unsafeArchive,
            ),
          ),
        );
      });
    }

    test('拒绝重复 entry', () async {
      final backup = File(p.join(root.path, 'duplicate.elbak'));
      _writeZip(backup.path, [
        ArchiveFile.string('manifest.json', '{}'),
        ArchiveFile.string('manifest.json', '{}'),
      ]);

      await expectLater(
        service.readManifest(backup.path),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            BackupFailureCode.unsafeArchive,
          ),
        ),
      );
    });

    test('拒绝符号链接 entry', () async {
      final backup = File(p.join(root.path, 'symlink.elbak'));
      final symlink = ArchiveFile.string('media/audios/link', '../outside')
        ..mode = 0xa1ff;
      _writeZip(backup.path, [symlink]);

      await expectLater(
        service.readManifest(backup.path),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            BackupFailureCode.unsafeArchive,
          ),
        ),
      );
    });

    test('拒绝加密 entry', () async {
      final backup = File(p.join(root.path, 'encrypted.elbak'));
      _writeZip(backup.path, [
        ArchiveFile.string('manifest.json', '{}'),
      ], password: 'secret');

      await expectLater(
        service.readManifest(backup.path),
        throwsA(
          isA<BackupException>().having(
            (error) => error.code,
            'code',
            BackupFailureCode.unsafeArchive,
          ),
        ),
      );
    });
  });
}

Future<void> _insertAudio(
  AppDatabase database, {
  required String id,
  required String name,
  required String path,
}) {
  final now = DateTime.utc(2026, 8, 30);
  return database
      .into(database.audioItems)
      .insert(
        AudioItemsCompanion.insert(
          id: id,
          name: name,
          addedDate: now,
          updatedAt: now,
          audioPath: Value(path),
        ),
      );
}

Future<File> _createLegacyBackup({
  required Directory root,
  required AppDatabase database,
  required File media,
  required int version,
  required CompressionType compression,
  bool includeDictionary = false,
  String? dbHashOverride,
}) async {
  final snapshot = File(
    p.join(root.path, 'legacy_snapshot_${version}_${compression.name}.sqlite'),
  );
  await database.createBackupSnapshot(snapshot);
  final hash = await sha256.bind(snapshot.openRead()).first;
  final backup = File(
    p.join(root.path, 'legacy_${version}_${compression.name}.elbak'),
  );
  final entries = <ArchiveFile>[
    ArchiveFile.string(
      'manifest.json',
      jsonEncode(
        _manifest(
          version: version,
          dbSha256: dbHashOverride ?? hash.toString(),
        ).toJson(),
      ),
    )..compression = compression,
    ArchiveFile.stream('echo_loop.db', InputFileStream(snapshot.path))
      ..compression = compression,
    ArchiveFile.string(
      'preferences.json',
      jsonEncode({
        'theme_mode': 'legacy',
        'rating_prompt_last_attempt_ms_v1': 111111111,
        'sb-project-ref-auth-token': 'backup-session',
        'supabase.auth.token-code-verifier': 'backup-pkce',
      }),
    )..compression = compression,
    ArchiveFile.stream('media/audios/legacy.m4a', InputFileStream(media.path))
      ..compression = compression,
  ];
  if (includeDictionary) {
    entries.add(
      ArchiveFile.bytes('resources/dictionary/legacy/dict.sqlite', [4, 5, 6])
        ..compression = compression,
    );
  }
  _writeZip(backup.path, entries);
  return backup;
}

BackupManifest _manifest({required int version, required String dbSha256}) {
  return BackupManifest(
    version: version,
    appVersion: '1.0.0',
    schemaVersion: AppDatabase.currentSchemaVersion,
    createdAt: DateTime.utc(2026, 8, 30),
    platform: 'test',
    dbSha256: dbSha256,
    mediaFileCount: 1,
    totalSizeBytes: 1,
  );
}

void _writeZip(String path, List<ArchiveFile> entries, {String? password}) {
  final output = OutputFileStream(path);
  final encoder = ZipEncoder(password: password)..startEncode(output);
  for (final entry in entries) {
    encoder.add(entry);
  }
  encoder.endEncode();
  output.closeSync();
}

void _corruptStoredEntry(String path, String entryName) {
  final bytes = File(path).readAsBytesSync();
  final input = InputMemoryStream(bytes);
  final directory = ZipDirectory()..read(input);
  final header = directory.fileHeaders.firstWhere(
    (candidate) => candidate.filename == entryName,
  );
  final localHeader = InputMemoryStream(bytes)
    ..setPosition(header.localHeaderOffset + 26);
  final filenameLength = localHeader.readUint16();
  final extraLength = localHeader.readUint16();
  final payloadOffset =
      header.localHeaderOffset + 30 + filenameLength + extraLength;
  bytes[payloadOffset] ^= 0xff;
  File(path).writeAsBytesSync(bytes);
}

({Archive archive, void Function() close}) _decodeStreaming(String path) {
  final input = InputFileStream(path);
  final archive = ZipDecoder().decodeStream(input);
  return (
    archive: archive,
    close: () {
      archive.clearSync();
      input.closeSync();
    },
  );
}

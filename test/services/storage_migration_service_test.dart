import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/services/resource_install_manifest.dart';
import 'package:echo_loop/services/storage_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeDocsDir;
  late Directory fakeAppSupportDir;

  setUp(() {
    fakeDocsDir = Directory.systemTemp.createTempSync('migration_docs_');
    fakeAppSupportDir = Directory.systemTemp.createTempSync(
      'migration_support_',
    );
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return fakeDocsDir.path;
            }
            if (call.method == 'getApplicationSupportDirectory') {
              return fakeAppSupportDir.path;
            }
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (fakeDocsDir.existsSync()) fakeDocsDir.deleteSync(recursive: true);
    if (fakeAppSupportDir.existsSync()) {
      fakeAppSupportDir.deleteSync(recursive: true);
    }
  });

  group('migrateToAppSupportDirectory', () {
    test('迁移数据库文件到 Application Support', () async {
      File('${fakeDocsDir.path}/echo_loop.db').writeAsStringSync('db-data');
      File('${fakeDocsDir.path}/echo_loop.db-wal').writeAsStringSync('wal');

      await migrateToAppSupportDirectory();

      expect(File('${fakeDocsDir.path}/echo_loop.db').existsSync(), isFalse);
      expect(
        File('${fakeDocsDir.path}/echo_loop.db-wal').existsSync(),
        isFalse,
      );
      expect(
        File('${fakeAppSupportDir.path}/echo_loop.db').readAsStringSync(),
        'db-data',
      );
      expect(
        File('${fakeAppSupportDir.path}/echo_loop.db-wal').readAsStringSync(),
        'wal',
      );
    });

    test('迁移媒体目录到 Application Support', () async {
      final audiosDir = Directory('${fakeDocsDir.path}/audios')..createSync();
      File('${audiosDir.path}/test.mp3').writeAsStringSync('audio');
      final transcriptsDir = Directory('${fakeDocsDir.path}/transcripts')
        ..createSync();
      File('${transcriptsDir.path}/test.srt').writeAsStringSync('srt');

      await migrateToAppSupportDirectory();

      expect(audiosDir.existsSync(), isFalse);
      expect(transcriptsDir.existsSync(), isFalse);
      expect(
        File('${fakeAppSupportDir.path}/audios/test.mp3').readAsStringSync(),
        'audio',
      );
      expect(
        File(
          '${fakeAppSupportDir.path}/transcripts/test.srt',
        ).readAsStringSync(),
        'srt',
      );
    });

    test('目标文件已存在时保持幂等', () async {
      File('${fakeDocsDir.path}/echo_loop.db').writeAsStringSync('db');
      File('${fakeAppSupportDir.path}/echo_loop.db').writeAsStringSync('new');

      await migrateToAppSupportDirectory();

      expect(File('${fakeDocsDir.path}/echo_loop.db').existsSync(), isTrue);
      expect(
        File('${fakeAppSupportDir.path}/echo_loop.db').readAsStringSync(),
        'new',
      );
    });

    test('目标已存在时不覆盖', () async {
      File('${fakeDocsDir.path}/echo_loop.db').writeAsStringSync('old');
      File('${fakeAppSupportDir.path}/echo_loop.db').writeAsStringSync('new');

      await migrateToAppSupportDirectory();

      expect(
        File('${fakeAppSupportDir.path}/echo_loop.db').readAsStringSync(),
        'new',
      );
      expect(File('${fakeDocsDir.path}/echo_loop.db').existsSync(), isTrue);
    });

    test('全新安装无文件时正常完成', () async {
      await migrateToAppSupportDirectory();
    });

    test('迁移旧版本数据库文件名', () async {
      File('${fakeDocsDir.path}/fluency.db').writeAsStringSync('legacy');

      await migrateToAppSupportDirectory();

      expect(File('${fakeDocsDir.path}/fluency.db').existsSync(), isFalse);
      expect(
        File('${fakeAppSupportDir.path}/fluency.db').readAsStringSync(),
        'legacy',
      );
    });
  });

  test('迁移旧 dict.db 为 dict.sqlite 并写入统一安装清单', () async {
    final directory = Directory(
      p.join(fakeAppSupportDir.path, 'dictionary', 'en_zh-CN'),
    )..createSync(recursive: true);
    final legacy = File(p.join(directory.path, 'dict.db'))
      ..writeAsBytesSync(List<int>.filled(8, 1));

    await migrateLegacyDictionaryInstallLayout();

    expect(legacy.existsSync(), isFalse);
    final database = File(p.join(directory.path, 'dict.sqlite'));
    expect(database.existsSync(), isTrue);
    final manifest = await readResourceInstallManifest(directory);
    expect(manifest?.resourceId, 'dict-en_zh-CN-v1');
    expect(manifest?.resourceSize, 8);
  });

  test('词典迁移可重复执行且不会覆盖已有 dict.sqlite', () async {
    final directory = Directory(
      p.join(fakeAppSupportDir.path, 'dictionary', 'en_zh-TW'),
    )..createSync(recursive: true);
    final database = File(p.join(directory.path, 'dict.sqlite'))
      ..writeAsBytesSync(List<int>.filled(4, 2));

    await migrateLegacyDictionaryInstallLayout();
    await migrateLegacyDictionaryInstallLayout();

    expect(database.readAsBytesSync(), List<int>.filled(4, 2));
    final manifest = await readResourceInstallManifest(directory);
    expect(manifest?.resourceId, 'dict-en_zh-TW-v1');
  });

  test('删除旧版离线单词发音库目录', () async {
    final root = Directory(p.join(fakeAppSupportDir.path, 'pronunciation'))
      ..createSync(recursive: true);
    File(p.join(root.path, 'pronunciation.sqlite')).writeAsBytesSync([1, 2]);
    Directory(p.join(root.path, 'audio')).createSync();

    await removeOfflinePronunciationLibrary();

    expect(root.existsSync(), isFalse);
  });

  test('旧发音库不存在时删除为空操作', () async {
    await removeOfflinePronunciationLibrary();

    expect(
      Directory(p.join(fakeAppSupportDir.path, 'pronunciation')).existsSync(),
      isFalse,
    );
  });
}

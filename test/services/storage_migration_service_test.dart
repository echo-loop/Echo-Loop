import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

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

  test('删除旧版离线词典目录与遗留 dict.db', () async {
    final directory = Directory(
      p.join(fakeAppSupportDir.path, 'dictionary', 'en_zh-CN'),
    )..createSync(recursive: true);
    File(p.join(directory.path, 'dict.sqlite')).writeAsBytesSync([1, 2]);
    File(p.join(fakeAppSupportDir.path, 'dict.db')).writeAsBytesSync([3]);

    await removeOfflineDictionaryLibrary();

    expect(
      Directory(p.join(fakeAppSupportDir.path, 'dictionary')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(fakeAppSupportDir.path, 'dict.db')).existsSync(),
      isFalse,
    );
  });

  test('旧离线词典不存在时删除为空操作', () async {
    await removeOfflineDictionaryLibrary();

    expect(
      Directory(p.join(fakeAppSupportDir.path, 'dictionary')).existsSync(),
      isFalse,
    );
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

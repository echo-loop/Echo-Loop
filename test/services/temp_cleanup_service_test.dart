import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/temp_cleanup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fakeDocsDir;
  late Directory fakeCacheDir;
  late Directory fakeTmpDir;

  setUp(() {
    // 创建模拟的沙盒结构：sandbox/Documents, sandbox/tmp, sandbox/Library/Caches
    final sandbox = Directory.systemTemp.createTempSync('cleanup_test_');
    fakeDocsDir = Directory('${sandbox.path}/Documents')..createSync();
    fakeTmpDir = Directory('${sandbox.path}/tmp')..createSync();
    fakeCacheDir = Directory('${sandbox.path}/Library/Caches')
      ..createSync(recursive: true);

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return fakeDocsDir.path;
            }
            if (call.method == 'getTemporaryDirectory') {
              return fakeCacheDir.path;
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
    // 清理整个模拟沙盒
    final sandbox = fakeDocsDir.parent;
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  group('cleanupRecordingTempFiles', () {
    test('删除 tmp/ 中的旧文件', () async {
      final oldFile = File('${fakeTmpDir.path}/old.caf');
      oldFile.writeAsBytesSync(List.filled(1000, 0));
      // 将修改时间设为 2 分钟前
      oldFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 2)),
      );

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 1000);
      expect(oldFile.existsSync(), false);
    });

    test('跳过 tmp/ 中不足 minAge 的文件', () async {
      final newFile = File('${fakeTmpDir.path}/new.caf');
      newFile.writeAsBytesSync(List.filled(500, 0));
      // 刚创建的文件，不足 60 秒

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 0);
      expect(newFile.existsSync(), true);
    });

    test('不清理 Library/Caches', () async {
      final cacheFile = File('${fakeCacheDir.path}/cached.dat');
      cacheFile.writeAsBytesSync(List.filled(2000, 0));
      cacheFile.setLastModifiedSync(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await cleanupRecordingTempFiles();

      expect(cacheFile.existsSync(), true);
    });

    test('tmp/ 不存在时返回 0', () async {
      fakeTmpDir.deleteSync(recursive: true);

      final result = await cleanupRecordingTempFiles();

      expect(result.freedBytes, 0);
    });
  });

  group('cleanupAllTempFiles', () {
    test('tmp/ 全量清理（任意名字文件都删）', () async {
      final tmpFile = File('${fakeTmpDir.path}/rec.caf');
      tmpFile.writeAsBytesSync(List.filled(1000, 0));

      final result = await cleanupAllTempFiles();

      expect(result.freedBytes, greaterThanOrEqualTo(1000));
      expect(tmpFile.existsSync(), false);
    });

    test('Library/Caches 只删 app 自建导出/导入临时目录', () async {
      final exportDir = Directory('${fakeCacheDir.path}/echoloop_export_123')
        ..createSync();
      File('${exportDir.path}/data.zip').writeAsBytesSync(List.filled(5000, 0));
      final importDir = Directory('${fakeCacheDir.path}/echoloop_import_9')
        ..createSync();
      File('${importDir.path}/x.bin').writeAsBytesSync(List.filled(100, 0));
      final audioExportDir = Directory('${fakeCacheDir.path}/audio_export_7')
        ..createSync();
      File(
        '${audioExportDir.path}/a.m4a',
      ).writeAsBytesSync(List.filled(200, 0));

      await cleanupAllTempFiles();

      expect(exportDir.existsSync(), false);
      expect(importDir.existsSync(), false);
      expect(audioExportDir.existsSync(), false);
    });

    test('Library/Caches 保护系统 URLCache 与框架缓存', () async {
      // 系统 URLCache：<bundleId>/Cache.db* 及散落的 Cache.db 文件
      final cacheDbFile = File('${fakeCacheDir.path}/Cache.db');
      cacheDbFile.writeAsBytesSync(List.filled(1000, 0));
      final urlCacheDir = Directory('${fakeCacheDir.path}/top.echo-loop.dev')
        ..createSync();
      File(
        '${urlCacheDir.path}/Cache.db',
      ).writeAsBytesSync(List.filled(2000, 0));
      File(
        '${urlCacheDir.path}/Cache.db-wal',
      ).writeAsBytesSync(List.filled(500, 0));
      // 网络图片缓存（由 flutter_cache_manager API 单独清，不在文件扫描范围）
      final imageCacheDir = Directory('${fakeCacheDir.path}/app_network_images')
        ..createSync();
      File(
        '${imageCacheDir.path}/img.bin',
      ).writeAsBytesSync(List.filled(300, 0));
      // 随机框架缓存
      final otherCache = File('${fakeCacheDir.path}/cached.dat');
      otherCache.writeAsBytesSync(List.filled(400, 0));

      await cleanupAllTempFiles();

      expect(cacheDbFile.existsSync(), true);
      expect(urlCacheDir.existsSync(), true);
      expect(imageCacheDir.existsSync(), true);
      expect(otherCache.existsSync(), true);
    });
  });
}

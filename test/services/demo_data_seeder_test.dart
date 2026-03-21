import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:fluency/data/demo_content.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/services/demo_data_seeder.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;

  setUp(() {
    db = _createTestDatabase();
    // 创建临时目录模拟 documents 目录
    tempDir = Directory.systemTemp.createTempSync('demo_seeder_test_');

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    await db.close();
    // 清理临时目录
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    // 清除 mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  group('DemoDataSeeder', () {
    group('seedIfEmpty', () {
      test('在空数据库上正确 seed 所有 AudioItem', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final audioItems = await db.select(db.audioItems).get();
        expect(audioItems.length, 5);

        // 验证每个 AudioItem 名称匹配
        for (var i = 0; i < demoAudios.length; i++) {
          final item = audioItems.firstWhere((a) => a.id == demoAudios[i].id);
          expect(item.name, demoAudios[i].title);
        }
      });

      test('在空数据库上正确 seed 合集及关联', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final collections = await db.select(db.collections).get();
        expect(collections.length, 1);
        expect(collections.first.id, demoCollectionId);
        expect(collections.first.name, 'Demo Content');

        final collectionItems =
            await db.select(db.collectionAudioItems).get();
        expect(collectionItems.length, 5);
      });

      test('在空数据库上正确 seed 学习进度', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final progresses = await db.select(db.learningProgresses).get();
        expect(progresses.length, 5);

        // 验证各阶段/子阶段
        final p1 =
            progresses.firstWhere((p) => p.audioItemId == 'demo-audio-0001');
        expect(p1.currentStage, 'review4');
        expect(p1.currentSubStage, 'blindListen');

        final p5 =
            progresses.firstWhere((p) => p.audioItemId == 'demo-audio-0005');
        expect(p5.currentStage, 'firstLearn');
        expect(p5.currentSubStage, 'retell');
      });

      test('在空数据库上正确 seed 阶段完成历史', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final completions = await db.select(db.stageCompletions).get();
        // 12 + 9 + 6 + 4 + 3 = 34
        expect(completions.length, 34);
      });

      test('在空数据库上正确 seed 书签', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final bookmarks = await db.select(db.bookmarks).get();
        final totalBookmarks = demoAudios.fold<int>(
          0,
          (sum, audio) => sum + audio.bookmarkIndices.length,
        );
        expect(bookmarks.length, totalBookmarks);
      });

      test('在空数据库上正确 seed 收藏单词', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final savedWords = await db.select(db.savedWords).get();
        expect(savedWords.length, 22);
      });

      test('在空数据库上正确 seed 已学习词形', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final wordForms = await db.select(db.learnedWordForms).get();
        expect(wordForms.length, greaterThan(100));
      });

      test('在空数据库上正确 seed 每日学习记录', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final records = await db.select(db.dailyStudyRecords).get();
        expect(records.length, 14);
      });

      test('在非空数据库上不重复 seed', () async {
        final seeder = DemoDataSeeder(db);

        await seeder.seedIfEmpty();
        final firstCount =
            (await db.select(db.audioItems).get()).length;

        await seeder.seedIfEmpty();
        final secondCount =
            (await db.select(db.audioItems).get()).length;

        expect(firstCount, 5);
        expect(secondCount, 5);
      });
    });

    group('SRT 文件生成', () {
      test('toSrt 生成有效的 SRT 格式', () {
        final srt = demoAudios[0].toSrt();

        expect(srt, contains('1\n'));
        expect(srt, contains('00:00:00,000 --> 00:00:04,200'));
        expect(srt, contains(demoAudios[0].sentences[0].text));
      });

      test('seed 后 SRT 文件正确生成在 demo 目录', () async {
        final seeder = DemoDataSeeder(db);
        await seeder.seedIfEmpty();

        final demoDir = Directory(p.join(tempDir.path, 'demo'));
        expect(demoDir.existsSync(), isTrue);

        for (var i = 0; i < demoAudios.length; i++) {
          final srtFile = File(p.join(demoDir.path, 'audio_${i + 1}.srt'));
          expect(srtFile.existsSync(), isTrue);
          final content = await srtFile.readAsString();
          expect(content, contains(demoAudios[i].sentences[0].text));
        }
      });
    });

    group('cleanupFiles', () {
      test('清理演示目录和数据库文件', () async {
        // 先创建演示文件
        final demoDir = Directory(p.join(tempDir.path, 'demo'));
        await demoDir.create(recursive: true);
        await File(p.join(demoDir.path, 'test.srt'))
            .writeAsString('test');
        await File(p.join(tempDir.path, 'echo_loop_demo.db'))
            .writeAsString('db');

        await DemoDataSeeder.cleanupFiles();

        expect(demoDir.existsSync(), isFalse);
        expect(
          File(p.join(tempDir.path, 'echo_loop_demo.db')).existsSync(),
          isFalse,
        );
      });

      test('清理不存在的目录不抛异常', () async {
        await expectLater(
          DemoDataSeeder.cleanupFiles(),
          completes,
        );
      });
    });
  });
}

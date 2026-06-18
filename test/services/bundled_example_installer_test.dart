import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/services/bundled_example_installer.dart';
import 'package:echo_loop/utils/app_data_dir.dart';

AppDatabase _createDb() {
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

  late Directory tempDir;
  late AppDatabase db;
  late SharedPreferences prefs;

  BundledExampleInstaller installer() {
    return BundledExampleInstaller(db, prefs, assetBundle: _FakeAssets());
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'bundled_example_installer_',
    );
    appDataDirectoryOverride = tempDir;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = _createDb();
  });

  tearDown(() async {
    appDataDirectoryOverride = null;
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('空库首次安装 6 条 CEFR 示例且无字幕', () async {
    await installer().installOnFirstLaunch();

    final collections = await db.collectionDao.getAllActive();
    expect(collections, hasLength(1));
    expect(collections.single.id, BundledExampleInstaller.collectionId);
    expect(collections.single.name, 'Examples');

    final audioIds = await db.collectionDao.getAudioIds(
      BundledExampleInstaller.collectionId,
    );
    expect(audioIds, [
      'bundled-example-audio-a1',
      'bundled-example-audio-a2',
      'bundled-example-audio-b1',
      'bundled-example-audio-b2',
      'bundled-example-audio-c1',
      'bundled-example-audio-c2',
    ]);

    final items = await db.audioItemDao.getAllActive();
    expect(items, hasLength(6));
    for (final item in items) {
      expect(item.audioPath, startsWith('audios/CEFR '));
      expect(item.transcriptPath, isNull);
      expect(item.transcriptSrt, isNull);
      expect(item.transcriptSource, isNull);
      expect(await File('${tempDir.path}/${item.audioPath}').exists(), isTrue);
    }
    expect(prefs.getInt('bundled_example_installed_version'), 2);
    expect(prefs.getBool('bundled_example_installed'), isTrue);
  });

  test('已是最新版时跳过安装', () async {
    await prefs.setInt('bundled_example_installed_version', 2);

    await installer().installOnFirstLaunch();

    expect(await db.audioItemDao.getAllActive(), isEmpty);
    expect(Directory('${tempDir.path}/audios').existsSync(), isFalse);
  });

  test('版本标记丢失但新示例已存在时保持幂等', () async {
    await installer().installOnFirstLaunch();
    await db.audioItemDao.saveTranscriptContent(
      'bundled-example-audio-a1',
      srt: '1\n00:00:00,000 --> 00:00:01,000\nhello\n',
      wordTimestampsJson: '[{"word":"hello"}]',
    );
    await (db.update(
      db.audioItems,
    )..where((t) => t.id.equals('bundled-example-audio-a1'))).write(
      const AudioItemsCompanion(
        transcriptSource: Value(1),
        transcriptLanguage: Value('en'),
        sentenceCount: Value(1),
        wordCount: Value(1),
      ),
    );
    await prefs.remove('bundled_example_installed_version');

    await installer().installOnFirstLaunch();

    final audioIds = await db.collectionDao.getAudioIds(
      BundledExampleInstaller.collectionId,
    );
    expect(audioIds, hasLength(6));
    expect(await db.audioItemDao.getAllActive(), hasLength(6));
    final a1 = await db.audioItemDao.getById('bundled-example-audio-a1');
    expect(a1!.transcriptSrt, contains('hello'));
    expect(a1.wordTimestampsJson, '[{"word":"hello"}]');
    expect(a1.transcriptSource, 1);
    expect(a1.transcriptLanguage, 'en');
    expect(prefs.getInt('bundled_example_installed_version'), 2);
  });

  test('旧 English in a Minute 示例迁移为 6 条新示例并删除旧文件', () async {
    final now = DateTime.now();
    await Directory('${tempDir.path}/audios').create(recursive: true);
    final legacyFile = File(
      '${tempDir.path}/audios/English in a Minute - On the Ball.m4a',
    );
    await legacyFile.writeAsBytes([1, 2, 3]);
    await db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            id: BundledExampleInstaller.collectionId,
            name: 'Examples',
            createdDate: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.audioItems)
        .insert(
          AudioItemsCompanion.insert(
            id: 'bundled-example-audio-0001',
            name: 'English in a Minute - On the Ball',
            audioPath: const Value(
              'audios/English in a Minute - On the Ball.m4a',
            ),
            addedDate: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.collectionAudioItems)
        .insert(
          CollectionAudioItemsCompanion.insert(
            collectionId: BundledExampleInstaller.collectionId,
            audioItemId: 'bundled-example-audio-0001',
            addedAt: now,
          ),
        );
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            audioItemId: 'bundled-example-audio-0001',
            sentenceIndex: 0,
            sentenceText: 'legacy sentence',
            startTime: 0,
            endTime: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.learningProgresses)
        .insert(
          LearningProgressesCompanion.insert(
            audioItemId: 'bundled-example-audio-0001',
            updatedAt: now,
          ),
        );
    await db
        .into(db.stageCompletions)
        .insert(
          StageCompletionsCompanion.insert(
            audioItemId: 'bundled-example-audio-0001',
            stage: 'firstLearn',
            subStage: 'blindListen',
            completedAt: now,
          ),
        );
    await db
        .into(db.playbackStates)
        .insert(
          PlaybackStatesCompanion.insert(
            audioItemId: 'bundled-example-audio-0001',
            positionMs: 1000,
            savedAt: now,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'tag-1',
            name: 'legacy',
            color: 0xff000000,
            createdDate: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.audioItemTags)
        .insert(
          AudioItemTagsCompanion.insert(
            tagId: 'tag-1',
            audioItemId: 'bundled-example-audio-0001',
            addedAt: now,
          ),
        );
    await db.savedWordDao.saveWord(
      word: 'legacy',
      audioItemId: 'bundled-example-audio-0001',
      sentenceIndex: 0,
      sentenceText: 'legacy sentence',
      sentenceStartMs: 0,
      sentenceEndMs: 1000,
    );
    await db.savedSenseGroupDao.saveSenseGroup(
      phraseText: 'legacy phrase',
      displayText: 'legacy phrase',
      audioItemId: 'bundled-example-audio-0001',
      sentenceIndex: 0,
      sentenceText: 'legacy sentence',
      sentenceStartMs: 0,
      sentenceEndMs: 1000,
      groupStartMs: 100,
      groupEndMs: 900,
    );
    await prefs.setBool('bundled_example_installed', true);

    await installer().installOnFirstLaunch();

    expect(await db.audioItemDao.getById('bundled-example-audio-0001'), isNull);
    expect(await legacyFile.exists(), isFalse);
    expect(
      await (db.select(db.bookmarks)
            ..where((t) => t.audioItemId.equals('bundled-example-audio-0001')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.learningProgresses)
            ..where((t) => t.audioItemId.equals('bundled-example-audio-0001')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.stageCompletions)
            ..where((t) => t.audioItemId.equals('bundled-example-audio-0001')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.playbackStates)
            ..where((t) => t.audioItemId.equals('bundled-example-audio-0001')))
          .get(),
      isEmpty,
    );
    expect(
      await (db.select(db.audioItemTags)
            ..where((t) => t.audioItemId.equals('bundled-example-audio-0001')))
          .get(),
      isEmpty,
    );
    final savedWord = (await db.savedWordDao.getAll()).single;
    expect(savedWord.audioItemId, isNull);
    expect(savedWord.sentenceIndex, isNull);
    expect(savedWord.sentenceText, isNull);
    expect(savedWord.sentenceStartMs, isNull);
    expect(savedWord.sentenceEndMs, isNull);
    final savedGroup = (await db.select(db.savedSenseGroups).get()).single;
    expect(savedGroup.audioItemId, isNull);
    expect(savedGroup.sentenceIndex, isNull);
    expect(savedGroup.sentenceText, isNull);
    expect(savedGroup.sentenceStartMs, isNull);
    expect(savedGroup.sentenceEndMs, isNull);
    expect(savedGroup.groupStartMs, isNull);
    expect(savedGroup.groupEndMs, isNull);
    expect(
      await db.collectionDao.getAudioIds(BundledExampleInstaller.collectionId),
      hasLength(6),
    );
    expect(prefs.getInt('bundled_example_installed_version'), 2);
  });

  test('非空用户库且无旧示例时不自动插入 examples', () async {
    final now = DateTime.now();
    await db
        .into(db.audioItems)
        .insert(
          AudioItemsCompanion.insert(
            id: 'user-audio-1',
            name: 'User Audio',
            audioPath: const Value('audios/user.m4a'),
            addedDate: now,
            updatedAt: now,
          ),
        );

    await installer().installOnFirstLaunch();

    final items = await db.audioItemDao.getAllActive();
    expect(items, hasLength(1));
    expect(items.single.id, 'user-audio-1');
    expect(
      await db.collectionDao.getById(BundledExampleInstaller.collectionId),
      isNull,
    );
    expect(prefs.getInt('bundled_example_installed_version'), 2);
  });
}

class _FakeAssets extends AssetBundle {
  static const _assets = {
    'assets/demo/CEFR A1 - Book a table.m4a': 'a1',
    'assets/demo/CEFR A2 - Invitation to a party.m4a': 'a2',
    'assets/demo/CEFR B1 - Work-life balance.m4a': 'b1',
    'assets/demo/CEFR B2 - Incentives.m4a': 'b2',
    'assets/demo/CEFR C1 - Rent a house.m4a': 'c1',
    'assets/demo/CEFR C2 - Conducting yourself.m4a': 'c2',
  };

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw StateError('Missing fake asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(value.codeUnits));
  }
}

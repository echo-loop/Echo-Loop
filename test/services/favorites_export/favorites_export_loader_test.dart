import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/models/favorites_export/favorites_export_data.dart';
import 'package:echo_loop/models/favorites_export/favorites_export_options.dart';
import 'package:echo_loop/services/favorites_export/favorites_export_loader.dart';
import 'package:echo_loop/utils/text_normalize.dart';

/// 内存数据库，每个用例独立
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

/// 三句测试字幕
const _srtAlpha = '''
1
00:00:00,000 --> 00:00:03,000
Hello world.

2
00:00:03,500 --> 00:00:06,000
This is a test.

3
00:00:06,500 --> 00:00:09,000
Goodbye now.
''';

const _srtBeta = '''
1
00:00:00,000 --> 00:00:03,000
Look it up tonight.
''';

void main() {
  late AppDatabase db;

  /// 调用记录：AI 查词 / 本地词典读取次数（只读契约：不发请求，这里仅记录）
  late List<String> aiReads;
  late List<String> localReads;

  /// 测试用的 AI 查词缓存（词 → 结果）
  late Map<String, AiDictionaryEntry> aiEntries;

  /// 测试用的基础词典缓存（词 → 条目）
  late Map<String, DictEntry> localEntries;

  setUp(() async {
    db = _createTestDb();
    aiReads = [];
    localReads = [];
    aiEntries = {};
    localEntries = {};

    await _insertAudio(db, id: 'audio-alpha', name: 'Alpha', srt: _srtAlpha);
    await _insertAudio(db, id: 'audio-beta', name: 'Beta', srt: _srtBeta);
  });

  tearDown(() async {
    await db.close();
  });

  FavoritesExportLoader buildLoader() {
    return FavoritesExportLoader(
      audioItemDao: db.audioItemDao,
      bookmarkDao: db.bookmarkDao,
      savedWordDao: db.savedWordDao,
      savedSenseGroupDao: db.savedSenseGroupDao,
      aiCacheDao: db.sentenceAiCacheDao,
      readAiEntry: (word, {required targetLanguage}) async {
        aiReads.add(word);
        return aiEntries[word];
      },
      readLocalDict: (words) async {
        localReads.addAll(words);
        return {
          for (final word in words)
            if (localEntries[word] case final entry?) word: entry,
        };
      },
    );
  }

  group('收藏句子', () {
    test('按来源材料分组，并附上本地翻译缓存', () async {
      await _bookmark(db, 'audio-alpha', 1, 'This is a test.');
      await _bookmark(db, 'audio-alpha', 0, 'Hello world.');
      await _bookmark(db, 'audio-beta', 0, 'Look it up tonight.');
      await db.sentenceAiCacheDao.upsert(
        translationContextHash(
          'This is a test.',
          previous: 'Hello world.',
          next: 'Goodbye now.',
        ),
        'translation_v2:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeWords: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.sentenceGroups.map((g) => g.sourceName), [
        'Alpha',
        'Beta',
      ]);
      final alpha = document.sentenceGroups.first.sentences;
      expect(alpha.map((s) => s.text), ['Hello world.', 'This is a test.']);
      expect(alpha.map((s) => s.translation), [null, '这是一个测试。']);
      expect(document.sentenceGroups.last.sentences.single.translation, isNull);
      expect(document.sentenceCount, 3);
    });

    test('来源媒体类型：视频材料标注 video，音频材料标注 audio', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('video-1'),
          name: const Value('Clip'),
          audioPath: const Value('movie.mp4'),
          addedDate: Value(now),
          updatedAt: Value(now),
          transcriptSrt: Value(_srtBeta),
        ),
      );
      await _bookmark(db, 'video-1', 0, 'Look it up tonight.');
      await _bookmark(db, 'audio-alpha', 1, 'This is a test.');

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeWords: false),
        targetLanguage: 'zh-CN',
      );

      final byName = {for (final g in document.sentenceGroups) g.sourceName: g};
      expect(byName['Clip']?.sourceMedia, FavoriteSourceMedia.video);
      expect(byName['Alpha']?.sourceMedia, FavoriteSourceMedia.audio);
    });

    test('已软删除的收藏句不导出', () async {
      await _bookmark(db, 'audio-alpha', 1, 'This is a test.');
      await _bookmark(db, 'audio-alpha', 2, 'Goodbye now.');
      await db.bookmarkDao.removeBookmark('audio-alpha', 2);

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeWords: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.sentenceCount, 1);
      expect(
        document.sentenceGroups.single.sentences.single.text,
        'This is a test.',
      );
    });

    test('includeTranslation 关闭时不附译文', () async {
      await _bookmark(db, 'audio-alpha', 1, 'This is a test.');
      await db.sentenceAiCacheDao.upsert(
        translationContextHash(
          'This is a test.',
          previous: 'Hello world.',
          next: 'Goodbye now.',
        ),
        'translation_v2:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );

      final document = await buildLoader().load(
        const FavoritesExportOptions(
          includeWords: false,
          includeTranslation: false,
        ),
        targetLanguage: 'zh-CN',
      );

      expect(
        document.sentenceGroups.single.sentences.single.translation,
        isNull,
      );
    });

    test('字幕已重解析导致索引错位时，按文本兜底找回译文', () async {
      // 收藏时记录的索引是 0，但当前字幕中该句位于第 1 位
      await _bookmark(db, 'audio-alpha', 0, 'This is a test.');
      await db.sentenceAiCacheDao.upsert(
        translationContextHash(
          'This is a test.',
          previous: 'Hello world.',
          next: 'Goodbye now.',
        ),
        'translation_v2:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeWords: false),
        targetLanguage: 'zh-CN',
      );

      expect(
        document.sentenceGroups.single.sentences.single.translation,
        '这是一个测试。',
      );
    });

    test('不包含句子时不读取句子数据', () async {
      await _bookmark(db, 'audio-alpha', 1, 'This is a test.');

      final document = await buildLoader().load(
        const FavoritesExportOptions(
          includeSentences: false,
          includeWords: false,
        ),
        targetLanguage: 'zh-CN',
      );

      expect(document.sentenceGroups, isEmpty);
    });
  });

  group('收藏词汇', () {
    test('单词与意群平铺并按字母序排列，附来源句与来源材料', () async {
      await db.savedWordDao.saveWord(
        word: 'Test',
        audioItemId: 'audio-alpha',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.savedWordDao.saveWord(word: 'apple');
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'look up',
        displayText: 'Look up',
        audioItemId: 'audio-beta',
        sentenceIndex: 0,
        sentenceText: 'Look it up tonight.',
      );

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeSentences: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.vocabulary.map((v) => v.term), [
        'apple',
        'Look up',
        'Test',
      ]);
      final test = document.vocabulary.last;
      expect(test.sourceSentence, 'This is a test.');
      expect(test.sourceName, 'Alpha');
      expect(document.vocabulary.first.sourceSentence, isNull);
      expect(document.vocabulary.first.sourceName, isNull);
      expect(document.vocabulary[1].isPhrase, isTrue);
    });

    test('来源材料已删除时来源名为空，词条仍导出', () async {
      await db.savedWordDao.saveWord(
        word: 'Test',
        audioItemId: 'audio-alpha',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await (db.update(db.audioItems)..where((t) => t.id.equals('audio-alpha')))
          .write(AudioItemsCompanion(deletedAt: Value(DateTime.now())));

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeSentences: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.vocabulary.single.term, 'Test');
      expect(document.vocabulary.single.sourceName, isNull);
      expect(document.vocabulary.single.sourceSentence, 'This is a test.');
    });

    test('已软删除的词不导出', () async {
      await db.savedWordDao.saveWord(word: 'apple');
      await db.savedWordDao.saveWord(word: 'banana');
      await db.savedWordDao.removeWord('banana');

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeSentences: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.vocabulary.map((v) => v.term), ['apple']);
    });

    test('释义：单词 AI 优先，AI 未命中回落基础词典，意群只看 AI', () async {
      await db.savedWordDao.saveWord(word: 'Test');
      await db.savedWordDao.saveWord(word: 'apple');
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'look up',
        displayText: 'Look up',
      );
      aiEntries['Test'] = DictionaryEntry.fromJson({
        'headword': 'Test',
        'pronunciation': {'uk': '', 'us': 'test-us'},
        'meanings': [
          {
            'partOfSpeech': 'n.',
            'translation': ['测试'],
            'definition': 'a trial',
            'examples': [
              {'sentence': 'A test.', 'translation': '一次测试。'},
            ],
          },
        ],
      });
      localEntries['apple'] = const DictEntry(
        word: 'apple',
        phonetic: 'æpl',
        translation: 'n. 苹果',
      );
      localEntries['look up'] = const DictEntry(
        word: 'look up',
        phonetic: '',
        translation: 'v. 查阅',
      );

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeSentences: false),
        targetLanguage: 'zh-CN',
      );

      final byTerm = {for (final v in document.vocabulary) v.term: v};
      expect(byTerm['Test']?.definition, 'n. 测试');
      expect(byTerm['Test']?.phonetic, 'test-us');
      expect(byTerm['Test']?.example?.text, 'A test.');
      expect(byTerm['apple']?.definition, 'n. 苹果');
      expect(byTerm['apple']?.phonetic, 'æpl');
      expect(byTerm['apple']?.example, isNull);
      // 意群不查基础词典：只有 AI 结果才有释义，这里 AI 未命中则无释义
      expect(byTerm['Look up']?.definition, isNull);
      expect(localReads, isNot(contains('look up')));
    });

    test('includeDefinition 关闭时不读取任何释义缓存', () async {
      await db.savedWordDao.saveWord(word: 'apple');

      final document = await buildLoader().load(
        const FavoritesExportOptions(
          includeSentences: false,
          includeDefinition: false,
        ),
        targetLanguage: 'zh-CN',
      );

      expect(document.vocabulary.single.definition, isNull);
      expect(aiReads, isEmpty);
      expect(localReads, isEmpty);
    });

    test('includeWords 关闭时不读取词汇数据', () async {
      await db.savedWordDao.saveWord(word: 'apple');

      final document = await buildLoader().load(
        const FavoritesExportOptions(includeWords: false),
        targetLanguage: 'zh-CN',
      );

      expect(document.vocabulary, isEmpty);
      expect(aiReads, isEmpty);
    });
  });
}

/// 插入测试音频（带字幕）
Future<void> _insertAudio(
  AppDatabase db, {
  required String id,
  required String name,
  required String srt,
}) {
  final now = DateTime.now();
  return db.audioItemDao.upsert(
    AudioItemsCompanion(
      id: Value(id),
      name: Value(name),
      audioPath: const Value('test.mp3'),
      addedDate: Value(now),
      updatedAt: Value(now),
      transcriptSrt: Value(srt),
    ),
  );
}

/// 插入一条收藏句（文本与时间戳仅为满足表约束）
Future<void> _bookmark(
  AppDatabase db,
  String audioItemId,
  int sentenceIndex,
  String sentenceText,
) {
  final now = DateTime.now();
  return db.bookmarkDao.addBookmark(
    BookmarksCompanion.insert(
      audioItemId: audioItemId,
      sentenceIndex: sentenceIndex,
      sentenceText: sentenceText,
      startTime: sentenceIndex.toDouble(),
      endTime: sentenceIndex + 1.0,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

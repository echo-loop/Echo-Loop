import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/dict_entry.dart';
import 'package:echo_loop/services/pdf_export/study_pdf_loader.dart';
import 'package:echo_loop/utils/text_normalize.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

/// 三句测试字幕（句间静音小，30s 目标分组为单段）
const _testSrt = '''
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

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  /// 插入测试音频（带字幕）
  Future<void> insertAudio({
    String id = 'audio-1',
    String? srt = _testSrt,
    int totalDuration = 0,
  }) {
    final now = DateTime.now();
    return db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: const Value('Test Audio'),
        audioPath: const Value('test.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
        transcriptSrt: Value(srt),
        totalDuration: Value(totalDuration),
      ),
    );
  }

  /// 构建 loader（本地词典默认查不到）
  ///
  /// 测试仍用「单词查询」函数表达断言，这里包成 loader 需要的批量查询签名。
  StudyPdfLoader buildLoader({DictEntry? Function(String)? localDictLookup}) {
    final single = localDictLookup ?? (_) => null;
    return StudyPdfLoader(
      audioItemDao: db.audioItemDao,
      bookmarkDao: db.bookmarkDao,
      savedWordDao: db.savedWordDao,
      savedSenseGroupDao: db.savedSenseGroupDao,
      aiCacheDao: db.sentenceAiCacheDao,
      localDictLookup: (words) => {
        for (final w in words)
          if (single(w) case final e?) w: e,
      },
    );
  }

  group('StudyPdfLoader 基础组装', () {
    test('解析字幕并分段，缓存全空时导出纯文章', () async {
      await insertAudio();

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');

      expect(doc.title, 'Test Audio');
      expect(doc.sentenceCount, 3);
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.text).toList(), [
        'Hello world.',
        'This is a test.',
        'Goodbye now.',
      ]);
      for (final s in all) {
        expect(s.isBookmarked, false);
        expect(s.translation, isNull);
        expect(s.grammar, isNull);
        expect(s.vocabNotes, isEmpty);
      }
      // 元信息：音频未探测时长（0）→ 回退字幕末句结束时间 9s；
      // 词数 = Hello world(2) + This is a test(4) + Goodbye now(2)
      expect(doc.durationSeconds, 9);
      expect(doc.wordCount, 8);
    });

    test('音频元数据有时长时优先于字幕末句结束时间', () async {
      await insertAudio(totalDuration: 125);

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');

      expect(doc.durationSeconds, 125);
    });

    test('音频不存在 / 无字幕时抛 StateError', () async {
      expect(
        () => buildLoader().load('missing', targetLanguage: 'zh-CN'),
        throwsStateError,
      );

      await insertAudio(id: 'no-srt', srt: null);
      expect(
        () => buildLoader().load('no-srt', targetLanguage: 'zh-CN'),
        throwsStateError,
      );
    });
  });

  group('收藏句标记', () {
    test('索引命中直接标记', () async {
      await insertAudio();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 1,
          sentenceText: 'This is a test.',
          startTime: 3.5,
          endTime: 6.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.isBookmarked).toList(), [false, true, false]);
    });

    test('索引错位时按文本兜底匹配', () async {
      await insertAudio();
      // 索引指向第 0 句，文本却是第 2 句 → 应落到第 2 句
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 0,
          sentenceText: 'Goodbye now.',
          startTime: 0,
          endTime: 3.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.map((s) => s.isBookmarked).toList(), [false, false, true]);
    });

    test('索引越界且文本不匹配时丢弃', () async {
      await insertAudio();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion.insert(
          audioItemId: 'audio-1',
          sentenceIndex: 99,
          sentenceText: 'Not in transcript.',
          startTime: 0,
          endTime: 1.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      expect(all.every((s) => !s.isBookmarked), true);
    });
  });

  group('翻译与解析缓存', () {
    test('缓存命中填充翻译与解析三字段', () async {
      await insertAudio();
      final hash = hashText('This is a test.');
      // 翻译键 = 上下文相关哈希（前句 Hello world. + 本句 + 后句 Goodbye now.）
      final translationHash = translationContextHash(
        'This is a test.',
        previous: 'Hello world.',
        next: 'Goodbye now.',
      );
      await db.sentenceAiCacheDao.upsert(
        translationHash,
        'translation_v2:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );
      await db.sentenceAiCacheDao.upsert(
        hash,
        'analysis_v2:zh-CN',
        jsonEncode({
          'grammar': [
            {'point': '主系表结构', 'note': ''},
          ],
          'vocabulary': [
            {'term': 'test', 'note': '测试'},
          ],
          'listening': [
            {'phrase': 'this is', 'note': '连读'},
          ],
        }),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, '这是一个测试。');
      expect(s.grammar, '主系表结构');
      expect(s.vocabulary, 'test: 测试');
      expect(s.listening, 'this is: 连读');
    });

    test('targetLanguage 隔离：zh-CN 缓存不命中 en 查询', () async {
      await insertAudio();
      await db.sentenceAiCacheDao.upsert(
        translationContextHash(
          'This is a test.',
          previous: 'Hello world.',
          next: 'Goodbye now.',
        ),
        'translation_v2:zh-CN',
        jsonEncode({'translation': '这是一个测试。'}),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'en');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, isNull);
    });

    test('坏 JSON 视作未命中不抛异常', () async {
      await insertAudio();
      final hash = hashText('This is a test.');
      final translationHash = translationContextHash(
        'This is a test.',
        previous: 'Hello world.',
        next: 'Goodbye now.',
      );
      await db.sentenceAiCacheDao.upsert(
        translationHash,
        'translation_v2:zh-CN',
        '{broken',
      );
      await db.sentenceAiCacheDao.upsert(hash, 'analysis_v2:zh-CN', '[]');

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.translation, isNull);
      expect(s.grammar, isNull);
    });
  });

  group('词汇笔记', () {
    test('AI 词典缓存命中：义项转 bullet、us 音标优先', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('test|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'headword': 'test',
          'pronunciation': {'uk': 'test-uk', 'us': 'test-us'},
          'meanings': [
            {
              'partOfSpeech': 'n.',
              'translation': ['测试', '考验'],
            },
            {
              'partOfSpeech': 'v.',
              'translation': ['检测'],
            },
          ],
        }),
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final s = doc.paragraphs.expand((p) => p).toList()[1];
      expect(s.vocabNotes.length, 1);
      final note = s.vocabNotes.first;
      expect(note.term, 'test');
      expect(note.phonetic, 'test-us');
      expect(note.glosses.map((g) => (g.pos, g.text)).toList(), [
        ('n.', '测试；考验'),
        ('v.', '检测'),
      ]);
    });

    test('AI 未命中时本地词典兜底（词性剥入 pos），两者皆无时不显示词条', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.savedWordDao.saveWord(
        word: 'unknown',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      // 本地词典只认识 test
      final doc2 = await buildLoader(
        localDictLookup: (word) => word == 'test'
            ? const DictEntry(
                word: 'test',
                phonetic: 'test',
                translation: 'n. 测试\nvt. 检测',
              )
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');

      // 无任何词典结果时词条不出现在右栏
      for (final s in doc.paragraphs.expand((p) => p)) {
        expect(s.vocabNotes, isEmpty);
      }
      final all2 = doc2.paragraphs.expand((p) => p).toList();
      final testNote = all2[1].vocabNotes.single;
      expect(testNote.glosses.map((g) => (g.pos, g.text)).toList(), [
        ('n.', '测试'),
        ('vt.', '检测'),
      ]);
      expect(testNote.phonetic, 'test');
      // unknown 两路皆无 → 被过滤
      expect(all2[0].vocabNotes, isEmpty);
    });

    test('AI 与本地词典同时命中时只用 AI 结果，不混入本地词典', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('test|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'pronunciation': {'us': 'ai-us'},
          'meanings': [
            {
              'partOfSpeech': 'n.',
              'translation': ['AI 释义'],
            },
          ],
        }),
      );

      final doc = await buildLoader(
        localDictLookup: (word) => word == 'test'
            ? const DictEntry(
                word: 'test',
                phonetic: 'local',
                translation: 'n. 本地释义',
              )
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');
      final note = doc.paragraphs
          .expand((p) => p)
          .toList()[1]
          .vocabNotes
          .single;
      expect(note.phonetic, 'ai-us');
      expect(note.glosses.single.text, 'AI 释义');
    });

    test('收藏词按表面词形直查 AI 缓存命中（收藏即字幕中的词形）', () async {
      // 新设计：收藏词存的就是字幕中的表面词形；AI 查词也按表面词形缓存，
      // 故直接用收藏词本身查 AI 缓存即可命中，无需扫全句找变形。
      await insertAudio(
        id: 'audio-m',
        srt: '''
1
00:00:00,000 --> 00:00:03,000
He sends messages.
''',
      );
      await db.savedWordDao.saveWord(
        word: 'messages',
        audioItemId: 'audio-m',
        sentenceIndex: 0,
        sentenceText: 'He sends messages.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('messages|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'meanings': [
            {
              'partOfSpeech': 'n.',
              'translation': ['消息'],
            },
          ],
        }),
      );

      // 本地词典也有释义，但 AI 命中后不应使用本地释义
      final doc = await buildLoader(
        localDictLookup: (word) => word == 'messages'
            ? const DictEntry(
                word: 'messages',
                phonetic: 'local',
                translation: 'n. 本地释义',
              )
            : null,
      ).load('audio-m', targetLanguage: 'zh-CN');
      final note = doc.paragraphs.expand((p) => p).first.vocabNotes.single;
      expect(note.glosses.single.text, '消息');
    });

    test('右栏词条按句中首次出现位置排序', () async {
      await insertAudio(
        id: 'audio-o',
        srt: '''
1
00:00:00,000 --> 00:00:05,000
Thank you for the birthday card and message. I received it.
''',
      );
      // 按与出现顺序无关的顺序收藏
      const sentence =
          'Thank you for the birthday card and message. I received it.';
      for (final w in ['i', 'message', 'you', 'birthday']) {
        await db.savedWordDao.saveWord(
          word: w,
          audioItemId: 'audio-o',
          sentenceIndex: 0,
          sentenceText: sentence,
        );
      }

      final doc = await buildLoader(
        localDictLookup: (word) =>
            DictEntry(word: word, phonetic: '', translation: '释义'),
      ).load('audio-o', targetLanguage: 'zh-CN');
      final notes = doc.paragraphs.expand((p) => p).first.vocabNotes;
      expect(notes.map((n) => n.term).toList(), [
        'you',
        'birthday',
        'message',
        'i',
      ]);
    });

    test('词条按全文档首现句归位/编号，不随收藏来源句', () async {
      // 'to' 在末句收藏（sentenceIndex=2），但更早出现在第 2 句（index=1）；
      // 'now' 也在末句收藏、末句才首现。期望：'to' 编号/归句都靠前（第 2 句
      // 右栏），'now' 在末句右栏、编号在后。
      await insertAudio(
        id: 'audio-fo',
        srt: '''
1
00:00:00,000 --> 00:00:03,000
Hello world.

2
00:00:03,500 --> 00:00:06,000
I want to go.

3
00:00:06,500 --> 00:00:09,000
Come to me now.
''',
      );
      await db.savedWordDao.saveWord(
        word: 'to',
        audioItemId: 'audio-fo',
        sentenceIndex: 2,
        sentenceText: 'Come to me now.',
      );
      await db.savedWordDao.saveWord(
        word: 'now',
        audioItemId: 'audio-fo',
        sentenceIndex: 2,
        sentenceText: 'Come to me now.',
      );

      final doc = await buildLoader(
        localDictLookup: (word) =>
            DictEntry(word: word, phonetic: '', translation: '释义'),
      ).load('audio-fo', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      // 'to' 首现于第 2 句 → 归第 2 句右栏、编号 1
      expect(all[1].vocabNotes.single.term, 'to');
      expect(all[1].vocabNotes.single.number, 1);
      // 'now' 首现于末句 → 归末句右栏、编号 2
      expect(all[2].vocabNotes.single.term, 'now');
      expect(all[2].vocabNotes.single.number, 2);
    });

    test('词条标号全局生效：同一收藏词在其他句子出现也有标记位', () async {
      await insertAudio(
        id: 'audio-g',
        srt: '''
1
00:00:00,000 --> 00:00:03,000
Thank you for the message.

2
00:00:03,500 --> 00:00:06,000
That's so nice of you.
''',
      );
      await db.savedWordDao.saveWord(
        word: 'you',
        audioItemId: 'audio-g',
        sentenceIndex: 0,
        sentenceText: 'Thank you for the message.',
      );

      final doc = await buildLoader(
        localDictLookup: (word) => word == 'you'
            ? const DictEntry(word: 'you', phonetic: '', translation: '你')
            : null,
      ).load('audio-g', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      // 来源句：词条标号 1，标记位在 'you' 末尾（6,9）
      expect(all[0].vocabNotes.single.number, 1);
      expect(all[0].vocabMarkers, [(9, 1)]);
      // 非来源句：无词条（右栏空），但同词出现处也有同号标记位
      expect(all[1].vocabNotes, isEmpty);
      expect(all[1].vocabMarkers, [(21, 1)]);
    });

    test('词条 ranges 记录其在句中的命中区间', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );

      final doc = await buildLoader(
        localDictLookup: (word) => word == 'test'
            ? const DictEntry(word: 'test', phonetic: '', translation: '测试')
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');
      final note = doc.paragraphs
          .expand((p) => p)
          .toList()[1]
          .vocabNotes
          .single;
      // 'This is a test.' 中 test 位于 [10, 14)
      expect(note.ranges, [(10, 14)]);
    });

    test('收藏意群用 displayText 展示、phraseText 查询，按出现位置排序', () async {
      await insertAudio();
      await db.savedWordDao.saveWord(
        word: 'world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'hello world',
        displayText: 'Hello world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );
      await db.sentenceAiCacheDao.upsert(
        hashText('hello world|zh-CN'),
        'ai_dictionary',
        jsonEncode({
          'meanings': [
            {
              'partOfSpeech': '',
              'translation': ['你好世界'],
            },
          ],
        }),
      );

      // world 走本地词典（无本地结果会被过滤，见上一用例）
      final doc = await buildLoader(
        localDictLookup: (word) => word == 'world'
            ? const DictEntry(word: 'world', phonetic: '', translation: '世界')
            : null,
      ).load('audio-1', targetLanguage: 'zh-CN');
      final notes = doc.paragraphs.expand((p) => p).toList()[0].vocabNotes;
      expect(notes.length, 2);
      // 意群 'Hello world' 起点 0 早于词 'world' 起点 6 → 意群在前
      expect(notes[0].term, 'Hello world');
      expect(notes[1].term, 'world');
      expect(notes[0].glosses.single.pos, '');
      expect(notes[0].glosses.single.text, '你好世界');
    });

    test('收藏词/意群命中区间：全音频索引逐句匹配，与词典结果无关', () async {
      await insertAudio();
      // 无任何词典结果（词条会被右栏过滤），但下划线区间仍应计算
      await db.savedWordDao.saveWord(
        word: 'test',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'This is a test.',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'hello world',
        displayText: 'Hello world',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      final all = doc.paragraphs.expand((p) => p).toList();
      // 'Hello world.' 命中意群（修边去句号）
      expect(all[0].savedRanges, [(0, 11)]);
      // 'This is a test.' 命中收藏词 test
      expect(all[1].savedRanges, [(10, 14)]);
      expect(all[2].savedRanges, isEmpty);
      // 右栏词条因无词典结果被过滤
      expect(all.every((s) => s.vocabNotes.isEmpty), true);
    });

    test('其他音频的收藏词不出现', () async {
      await insertAudio();
      await insertAudio(id: 'audio-2');
      await db.savedWordDao.saveWord(
        word: 'other',
        audioItemId: 'audio-2',
        sentenceIndex: 0,
        sentenceText: 'Hello world.',
      );

      final doc = await buildLoader().load('audio-1', targetLanguage: 'zh-CN');
      expect(
        doc.paragraphs.expand((p) => p).every((s) => s.vocabNotes.isEmpty),
        true,
      );
    });
  });
}

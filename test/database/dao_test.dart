import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/models/sentence.dart';

/// 创建内存数据库用于测试（启用外键约束）
AppDatabase createTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('AudioItemDao', () {
    test('插入并查询音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Test Audio'),
          audioPath: Value('audios/test.mp3'),
          transcriptPath: Value('transcripts/test.srt'),
          addedDate: Value(now),
          totalDuration: Value(120),
          updatedAt: Value(now),
        ),
      );

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 1);
      expect(items.first.id, 'audio-1');
      expect(items.first.name, 'Test Audio');
      expect(items.first.audioPath, 'audios/test.mp3');
      expect(items.first.totalDuration, 120);
    });

    test('getById 返回正确的音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final item = await db.audioItemDao.getById('audio-1');
      expect(item, isNotNull);
      expect(item!.name, 'Audio 1');

      final missing = await db.audioItemDao.getById('nonexistent');
      expect(missing, isNull);
    });

    test('getAllReferencedRelPaths 含软删行、忽略空路径', () async {
      final now = DateTime.now();
      // 活跃行：音频 + 字幕路径
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('a'),
          name: Value('A'),
          audioPath: Value('audios/imported/a.mp3'),
          transcriptPath: Value('transcripts/a.srt'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      // 软删行：文件仍应被视为「被引用」，不能当孤儿删
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('b'),
          name: Value('B'),
          audioPath: Value('audios/official/b.m4a'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.softDelete('b');
      // 无路径行：应被忽略
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('c'),
          name: Value('C'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final paths = await db.audioItemDao.getAllReferencedRelPaths();

      expect(paths, {
        'audios/imported/a.mp3',
        'transcripts/a.srt',
        'audios/official/b.m4a',
      });
    });

    test('upsert 更新已存在的音频项', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Original'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Updated'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 1);
      expect(items.first.name, 'Updated');
    });

    test('softDelete 设置 deletedAt，从 getAllActive 中排除', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('To Delete'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.softDelete('audio-1');

      final active = await db.audioItemDao.getAllActive();
      expect(active, isEmpty);

      // 但仍然可以通过 getById 找到
      final item = await db.audioItemDao.getById('audio-1');
      expect(item, isNotNull);
      expect(item!.deletedAt, isNotNull);
    });

    test('batchInsert 批量插入', () async {
      final now = DateTime.now();
      final entries = List.generate(
        5,
        (i) => AudioItemsCompanion(
          id: Value('audio-$i'),
          name: Value('Audio $i'),
          audioPath: Value('audios/$i.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.batchInsert(entries);

      final items = await db.audioItemDao.getAllActive();
      expect(items.length, 5);
    });

    test('batchInsert 更新已有行时保留 transcript_srt / word_timestamps 大字段', () async {
      final now = DateTime.now();
      // 1) 先写入一行并填入字幕大字段（模拟下载/AI 转录落库）
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Original'),
          audioPath: Value('audios/1.mp3'),
          sentenceCount: Value(10),
          wordCount: Value(100),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.saveTranscriptContent(
        'audio-1',
        srt: 'srt-content',
        wordTimestampsJson: '[{"word":"hi"}]',
      );

      // 2) 走 batchInsert 做一次"只带模型列"的回写（模拟 updateAudioItem/togglePin，
      //    companion 不含 transcript_srt / word_timestamps_json）
      await db.audioItemDao.batchInsert([
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Renamed'),
          audioPath: Value('audios/1.mp3'),
          sentenceCount: Value(10),
          wordCount: Value(100),
          isPinned: Value(true),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      ]);

      // 3) 模型列已更新，但大字段必须原样保留（不被整行 replace 清空）
      final item = await db.audioItemDao.getById('audio-1');
      expect(item!.name, 'Renamed');
      expect(item.isPinned, isTrue);
      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), 'srt-content');
      expect(
        await db.audioItemDao.getWordTimestamps('audio-1'),
        '[{"word":"hi"}]',
      );
    });

    test('batchInsert 更新已有行不会级联删除合集 junction / 书签等子表', () async {
      final now = DateTime.now();
      // 音频 + 合集 + junction + 书签（模拟社区合集中已下载并加书签的音频）
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: const Value('col-1'),
          name: const Value('Official'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/official/x.m4a'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.addAudio('col-1', 'audio-1');
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceText: Value('hi'),
          startTime: Value(0.0),
          endTime: Value(1.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 元数据回写（togglePin/rename/checkAudioContent 等都走此路径）
      await db.audioItemDao.batchInsert([
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/official/x.m4a'),
          isPinned: Value(true),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      ]);

      // 整行替换会触发 onDelete cascade 删空子表；DO UPDATE 不会
      expect(await db.collectionDao.getAudioIds('col-1'), ['audio-1']);
      expect(await db.bookmarkDao.getByAudioId('audio-1'), hasLength(1));
      final item = await db.audioItemDao.getById('audio-1');
      expect(item!.isPinned, isTrue);
    });

    test('hardDeleteMany 批量删除并触发 junction cascade', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: const Value('col-1'),
          name: const Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      final entries = List.generate(
        3,
        (i) => AudioItemsCompanion(
          id: Value('audio-$i'),
          name: Value('Audio $i'),
          audioPath: Value('audios/$i.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.batchInsert(entries);
      await db.collectionDao.addAudios('col-1', [
        'audio-0',
        'audio-1',
        'audio-2',
      ]);

      await db.audioItemDao.hardDeleteMany({'audio-0', 'audio-1'});

      final items = await db.audioItemDao.getAllActive();
      expect(items.map((e) => e.id), ['audio-2']);
      expect(await db.collectionDao.getAudioIds('col-1'), ['audio-2']);
    });

    test('watchAllActive 响应数据变化', () async {
      final now = DateTime.now();
      final stream = db.audioItemDao.watchAllActive();

      // 初始为空
      expect(await stream.first, isEmpty);

      // 添加一个
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final items = await stream.first;
      expect(items.length, 1);
    });

    test('transcriptSrt get/update 往返', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 初始为空
      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), isNull);

      const srt = '1\n00:00:00,000 --> 00:00:01,000\nHello\n';
      await db.audioItemDao.updateTranscriptSrt('audio-1', srt);
      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), srt);

      // 置空
      await db.audioItemDao.updateTranscriptSrt('audio-1', null);
      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), isNull);
    });

    test('saveTranscriptContent 原子写入 SRT + 词级时间戳', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.saveTranscriptContent(
        'audio-1',
        srt: 'srt-content',
        wordTimestampsJson: '[{"word":"hi"}]',
      );

      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), 'srt-content');
      expect(
        await db.audioItemDao.getWordTimestamps('audio-1'),
        '[{"word":"hi"}]',
      );

      // wordTimestampsJson 传 null 同时清空词级时间戳
      await db.audioItemDao.saveTranscriptContent(
        'audio-1',
        srt: 'srt-2',
        wordTimestampsJson: null,
      );
      expect(await db.audioItemDao.getTranscriptSrt('audio-1'), 'srt-2');
      expect(await db.audioItemDao.getWordTimestamps('audio-1'), isNull);
    });

    test('getRowsNeedingSrtBackfill 只返回有 path 且 srt 为空的行', () async {
      final now = DateTime.now();
      // 行1：有 path、无 srt → 需要 backfill
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('need'),
          name: Value('need'),
          transcriptPath: Value('transcripts/need.srt'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      // 行2：有 path 且已有 srt → 不需要
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('done'),
          name: Value('done'),
          transcriptPath: Value('transcripts/done.srt'),
          transcriptSrt: Value('already'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      // 行3：无 path → 不需要
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('nopath'),
          name: Value('nopath'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final rows = await db.audioItemDao.getRowsNeedingSrtBackfill();
      expect(rows.map((r) => r.id), ['need']);
    });
  });

  group('CollectionDao', () {
    test('插入并查询合集', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Test Collection'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      final collections = await db.collectionDao.getAllActive();
      expect(collections.length, 1);
      expect(collections.first.name, 'Test Collection');
    });

    test('addAudio 和 getAudioIds', () async {
      final now = DateTime.now();
      // 先插入音频项和合集
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-2'),
          name: Value('Audio 2'),
          audioPath: Value('audios/2.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.collectionDao.addAudio('col-1', 'audio-1');
      await db.collectionDao.addAudio('col-1', 'audio-2');

      final audioIds = await db.collectionDao.getAudioIds('col-1');
      expect(audioIds.length, 2);
      expect(audioIds, contains('audio-1'));
      expect(audioIds, contains('audio-2'));
    });

    test('addAudios 批量追加并保持顺序', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: const Value('col-1'),
          name: const Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.batchInsert(
        List.generate(
          4,
          (i) => AudioItemsCompanion(
            id: Value('audio-$i'),
            name: Value('Audio $i'),
            audioPath: Value('audios/$i.mp3'),
            addedDate: Value(now),
            updatedAt: Value(now),
          ),
        ),
      );

      await db.collectionDao.addAudio('col-1', 'audio-0');
      await db.collectionDao.addAudios('col-1', [
        'audio-1',
        'audio-2',
        'audio-3',
      ]);

      expect(await db.collectionDao.getAudioIds('col-1'), [
        'audio-0',
        'audio-1',
        'audio-2',
        'audio-3',
      ]);
    });

    test('removeAudio 从合集移除音频', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.collectionDao.addAudio('col-1', 'audio-1');
      await db.collectionDao.removeAudio('col-1', 'audio-1');

      final audioIds = await db.collectionDao.getAudioIds('col-1');
      expect(audioIds, isEmpty);
    });

    test('removeAudioFromAll 从所有合集移除', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      for (int i = 1; i <= 3; i++) {
        await db.collectionDao.upsert(
          CollectionsCompanion(
            id: Value('col-$i'),
            name: Value('Collection $i'),
            createdDate: Value(now),
            updatedAt: Value(now),
          ),
        );
        await db.collectionDao.addAudio('col-$i', 'audio-1');
      }

      await db.collectionDao.removeAudioFromAll('audio-1');

      for (int i = 1; i <= 3; i++) {
        final ids = await db.collectionDao.getAudioIds('col-$i');
        expect(ids, isEmpty, reason: 'col-$i should be empty');
      }
    });

    test('getAudioCount 返回正确数量', () async {
      final now = DateTime.now();
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      for (int i = 0; i < 3; i++) {
        await db.audioItemDao.upsert(
          AudioItemsCompanion(
            id: Value('audio-$i'),
            name: Value('Audio $i'),
            audioPath: Value('audios/$i.mp3'),
            addedDate: Value(now),
            updatedAt: Value(now),
          ),
        );
        await db.collectionDao.addAudio('col-1', 'audio-$i');
      }

      final count = await db.collectionDao.getAudioCount('col-1');
      expect(count, 3);
    });

    test('CASCADE 删除：音频删除后 junction 自动清理', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.upsert(
        CollectionsCompanion(
          id: Value('col-1'),
          name: Value('Collection 1'),
          createdDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.collectionDao.addAudio('col-1', 'audio-1');

      // 硬删除音频
      await db.audioItemDao.hardDelete('audio-1');

      final ids = await db.collectionDao.getAudioIds('col-1');
      expect(ids, isEmpty);
    });
  });

  group('BookmarkDao', () {
    final now = DateTime(2026, 11, 17);

    /// 当前字幕：第 i 句占 [i, i+1) 秒，文本 Sentence i。
    String srtOf(List<(double, double, String)> cues) {
      String ts(double seconds) {
        final ms = (seconds * 1000).round();
        final h = ms ~/ 3600000;
        final m = ms ~/ 60000 % 60;
        final sec = ms ~/ 1000 % 60;
        final rest = ms % 1000;
        String two(int v) => v.toString().padLeft(2, '0');
        return '${two(h)}:${two(m)}:${two(sec)},${rest.toString().padLeft(3, '0')}';
      }

      final buffer = StringBuffer();
      for (final (i, cue) in cues.indexed) {
        buffer
          ..writeln(i + 1)
          ..writeln('${ts(cue.$1)} --> ${ts(cue.$2)}')
          ..writeln(cue.$3)
          ..writeln();
      }
      return buffer.toString();
    }

    List<(double, double, String)> evenCues(int count) => [
      for (var i = 0; i < count; i++) (i * 1.0, i + 1.0, 'Sentence $i'),
    ];

    Future<void> setTranscript(List<(double, double, String)> cues) =>
        db.audioItemDao.updateTranscriptSrt('audio-1', srtOf(cues));

    Future<void> addAt(
      int storedIndex,
      double start,
      double end, {
      String? text,
      String? subjectId,
    }) {
      return db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          memorySubjectId: Value(subjectId),
          sentenceText: Value(text ?? 'Sentence $storedIndex'),
          startTime: Value(start),
          endTime: Value(end),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    /// 测试里第 n 条收藏的起点就是 n 秒。
    Future<int> idOf(int label) async {
      final rows = await (db.select(
        db.bookmarks,
      )..where((t) => t.startTime.equals(label.toDouble()))).get();
      return rows.single.id;
    }

    setUp(() async {
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await setTranscript(evenCues(10));
    });

    test('添加并查询书签', () async {
      await addAt(5, 5.0, 6.0, text: 'Hello world');

      final bookmarks = await db.bookmarkDao.getByAudioId('audio-1');
      expect(bookmarks.length, 1);
      expect(bookmarks.first.sentenceText, 'Hello world');
      expect(bookmarks.first.startTime, closeTo(5.0, 0.01));
    });

    test('getBookmarkedIndices 按收藏时间区间定位到当前字幕', () async {
      for (final i in [2, 5, 8]) {
        await addAt(i, i * 1.0, i + 1.0);
      }

      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {2, 5, 8});
    });

    test('只按时间定位，不看收藏时的文字', () async {
      // 收藏时的文字与当前字幕不同（字幕被改过字），仍按区间落在第 2 句。
      await addAt(9, 2.0, 3.0, text: 'Old text');

      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {2});
    });

    test('合并后两条收藏指向同一句，同一句可存多条收藏', () async {
      await addAt(2, 2.0, 3.0);
      await addAt(3, 3.0, 4.0);
      // 第 2、3 句合并为一句：[2, 4)。
      await setTranscript([
        (0.0, 1.0, 'Sentence 0'),
        (1.0, 2.0, 'Sentence 1'),
        (2.0, 4.0, 'Sentence 2 Sentence 3'),
        (4.0, 5.0, 'Sentence 4'),
      ]);

      expect(await db.bookmarkDao.getByAudioId('audio-1'), hasLength(2));
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {2});
      final located = await db.bookmarkDao.getForSentence(
        'audio-1',
        Sentence(
          index: 2,
          text: 'Sentence 2 Sentence 3',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 4),
        ),
      );
      expect(located.index, 2);
      expect(located.bookmarks, hasLength(2));
    });

    test('来源句被删除的收藏不计入收藏句子', () async {
      await addAt(1, 1.0, 2.0);
      await addAt(3, 3.0, 4.0);
      // 删除第 1 句（留下空隙），后面的句子索引前移。
      await setTranscript([
        (0.0, 1.0, 'Sentence 0'),
        (2.0, 3.0, 'Sentence 2'),
        (3.0, 4.0, 'Sentence 3'),
      ]);

      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {2});
    });

    test('无字幕时没有可定位的收藏句子', () async {
      await addAt(0, 0.0, 1.0);
      await db.audioItemDao.updateTranscriptSrt('audio-1', null);

      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), isEmpty);
      expect(await db.bookmarkDao.getByAudioId('audio-1'), hasLength(1));
    });

    test('getForSentence 按调用方句子的时间定位，不信任其 index；包含回收站', () async {
      await addAt(4, 4.0, 5.0);
      await db.bookmarkDao.softDeleteByIds([await idOf(4)]);
      // 调用方持有字幕编辑前的旧列表：该句 index 写着 9，时间仍是 [4,5)。
      final stale = Sentence(
        index: 9,
        text: 'Sentence 4',
        startTime: const Duration(seconds: 4),
        endTime: const Duration(seconds: 5),
      );

      final located = await db.bookmarkDao.getForSentence('audio-1', stale);

      expect(located.index, 4);
      expect(located.bookmarks.single.deletedAt, isNotNull);
    });

    test('getForSentence：句子已不在当前字幕中时不匹配任何书签', () async {
      await addAt(4, 4.0, 5.0);
      final gone = Sentence(
        index: 4,
        text: 'Removed',
        startTime: const Duration(seconds: 20),
        endTime: const Duration(seconds: 21),
      );

      final located = await db.bookmarkDao.getForSentence('audio-1', gone);

      expect(located.index, isNull);
      expect(located.bookmarks, isEmpty);
    });

    test('softDeleteByIds 只软删除指定书签', () async {
      for (var i = 0; i < 5; i++) {
        await addAt(i, i * 1.0, i + 1.0);
      }

      await db.bookmarkDao.softDeleteByIds([await idOf(1), await idOf(3)]);

      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {0, 2, 4});
    });

    test('watchBookmarkedIndices 随书签变化推送定位后的索引', () async {
      final emissions = <Set<int>>[];
      final subscription = db.bookmarkDao
          .watchBookmarkedIndices('audio-1')
          .listen(emissions.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      await addAt(9, 6.0, 7.0);
      await pumpEventQueue();

      expect(emissions.first, isEmpty);
      expect(emissions.last, {6});

      // 只改字幕（书签行不变）也要重新定位：前面插入一句后该收藏变为第 7 句。
      await setTranscript([(0.0, 0.5, 'Intro'), ...evenCues(10).skip(1)]);
      await pumpEventQueue();
      expect(emissions.last, {6});
      await setTranscript([
        (0.0, 0.5, 'Intro'),
        (0.5, 1.0, 'Sentence 0'),
        ...evenCues(10).skip(1),
      ]);
      await pumpEventQueue();
      expect(emissions.last, {7});
    });

    test('reviveWithSentence 移出回收站并改写为本次收藏的区间', () async {
      await addAt(3, 3.0, 4.0, text: 'Old');
      final id = await idOf(3);
      await db.bookmarkDao.softDeleteByIds([id]);

      await db.bookmarkDao.reviveWithSentence(
        id,
        Sentence(
          index: 7,
          text: 'New',
          startTime: const Duration(milliseconds: 2900),
          endTime: const Duration(milliseconds: 4000),
        ),
      );

      final row = await db.bookmarkDao.getById(id);
      expect(row!.deletedAt, isNull);
      expect(row.sentenceText, 'New');
      expect(row.startTime, closeTo(2.9, 0.001));
    });

    test('getDeletedBookmarks 返回已软删除的书签', () async {
      for (var i = 0; i < 3; i++) {
        await addAt(i, i * 1.0, i + 1.0);
      }

      await db.bookmarkDao.softDeleteByIds([await idOf(0), await idOf(2)]);

      final deleted = await db.bookmarkDao.getDeletedBookmarks(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted.length, 2);
      expect(deleted.map((d) => d.bookmark.startTime).toSet(), {0.0, 2.0});
      expect(deleted.first.audioName, 'Audio 1');
    });

    test('restoreById 恢复已软删除的书签', () async {
      await addAt(0, 0.0, 1.0);
      final id = await idOf(0);

      await db.bookmarkDao.softDeleteByIds([id]);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), isEmpty);

      await db.bookmarkDao.restoreById(id);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {0});
    });

    test('permanentlyDeleteById 只物理删除回收站中的书签', () async {
      await addAt(0, 0.0, 1.0);
      await addAt(1, 1.0, 2.0);
      final deletedId = await idOf(0);
      final activeId = await idOf(1);
      await db.bookmarkDao.softDeleteByIds([deletedId]);

      await db.bookmarkDao.permanentlyDeleteById(deletedId);
      await db.bookmarkDao.permanentlyDeleteById(activeId);

      expect(await db.bookmarkDao.getById(deletedId), isNull);
      expect(await db.bookmarkDao.getById(activeId), isNotNull);
    });

    test('permanentlyDeleteAllDeleted 清空回收站', () async {
      for (var i = 0; i < 3; i++) {
        await addAt(i, i * 1.0, i + 1.0);
      }

      await db.bookmarkDao.softDeleteByIds([await idOf(0), await idOf(2)]);
      await db.bookmarkDao.permanentlyDeleteAllDeleted();

      final deleted = await db.bookmarkDao.getDeletedBookmarks(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted, isEmpty);
      expect(await db.bookmarkDao.getBookmarkedIndices('audio-1'), {1});
    });

    test('CASCADE 删除：音频删除后书签自动清理', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: Value('audio-1'),
          sentenceText: Value('Test'),
          startTime: Value(0.0),
          endTime: Value(1.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.hardDelete('audio-1');

      final bookmarks = await db.bookmarkDao.getByAudioId('audio-1');
      expect(bookmarks, isEmpty);
    });
  });

  group('PlaybackStateDao', () {
    setUp(() async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: Value('audio-1'),
          name: Value('Audio 1'),
          audioPath: Value('audios/1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
    });

    test('保存并查询播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNotNull);
      expect(state!.positionMs, 5000);
      expect(state.playlistMode, 0);
    });

    test('saveState 更新已存在的播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(1000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(9000),
          playlistMode: Value(1),
          savedAt: Value(DateTime.now()),
        ),
      );

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state!.positionMs, 9000);
      expect(state.playlistMode, 1);
    });

    test('clearState 清除播放状态', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.playbackStateDao.clearState('audio-1');

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNull);
    });

    test('CASCADE 删除：音频删除后播放状态自动清理', () async {
      await db.playbackStateDao.saveState(
        PlaybackStatesCompanion(
          audioItemId: Value('audio-1'),
          positionMs: Value(5000),
          playlistMode: Value(0),
          savedAt: Value(DateTime.now()),
        ),
      );

      await db.audioItemDao.hardDelete('audio-1');

      final state = await db.playbackStateDao.getByAudioId('audio-1');
      expect(state, isNull);
    });
  });
}

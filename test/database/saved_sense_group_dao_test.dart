import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/daos/bookmark_dao.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('SavedSenseGroupDao', () {
    test('saveSenseGroup 插入新意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in the morning',
        displayText: 'in the morning',
      );

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.length, 1);
      expect(all.first.phraseText, 'in the morning');
      expect(all.first.displayText, 'in the morning');
    });

    test('saveSenseGroup 含完整来源信息', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Test Audio'),
          audioPath: const Value('test.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'on the other hand',
        displayText: 'On the other hand,',
        audioItemId: 'audio-1',
        sentenceIndex: 3,
        sentenceText: 'On the other hand, it might rain.',
        sentenceStartMs: 5000,
        sentenceEndMs: 8000,
        groupStartMs: 5000,
        groupEndMs: 6500,
      );

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.length, 1);
      final item = all.first;
      expect(item.phraseText, 'on the other hand');
      expect(item.displayText, 'On the other hand,');
      expect(item.audioItemId, 'audio-1');
      expect(item.sentenceIndex, 3);
      expect(item.sentenceText, 'On the other hand, it might rain.');
      expect(item.sentenceStartMs, 5000);
      expect(item.sentenceEndMs, 8000);
      expect(item.groupStartMs, 5000);
      expect(item.groupEndMs, 6500);
    });

    test('saveSenseGroup 重复收藏不覆盖来源（先到先得）', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-2'),
          name: const Value('Audio 2'),
          audioPath: const Value('2.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 首次收藏来自 audio-1
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'for example',
        displayText: 'For example,',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
        sentenceText: 'For example, we could go.',
      );

      // 再次收藏同一意群，来自 audio-2
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'for example',
        displayText: 'for example',
        audioItemId: 'audio-2',
        sentenceIndex: 5,
        sentenceText: 'Take, for example, the case of...',
      );

      // 应只有一条记录，来源信息保持 audio-1（先到先得）
      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.length, 1);
      expect(all.first.audioItemId, 'audio-1');
      expect(all.first.sentenceIndex, 1);
      expect(all.first.displayText, 'For example,');
    });

    test('removeSenseGroup 软删除', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'as a result',
        displayText: 'As a result',
      );

      expect(
        await db.savedSenseGroupDao.isSenseGroupSaved('as a result'),
        true,
      );

      await db.savedSenseGroupDao.removeSenseGroup('as a result');

      expect(
        await db.savedSenseGroupDao.isSenseGroupSaved('as a result'),
        false,
      );

      // 数据仍在表中（软删除）
      final all = await db.select(db.savedSenseGroups).get();
      expect(all.length, 1);
      expect(all.first.deletedAt, isNotNull);
    });

    test('saveSenseGroup 恢复软删除的意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in fact',
        displayText: 'In fact',
      );
      await db.savedSenseGroupDao.removeSenseGroup('in fact');
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('in fact'), false);

      // 重新收藏 → 恢复
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in fact',
        displayText: 'in fact,',
      );
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('in fact'), true);

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.length, 1);
      expect(all.first.deletedAt, isNull);
    });

    test('isSenseGroupSaved 区分已删除和未删除', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'by the way',
        displayText: 'By the way',
      );
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('by the way'), true);
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('not saved'), false);
    });

    test('clearContextForAudio 清除所有非 FK 上下文字段', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio'),
          audioPath: const Value('a.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'at the end of the day',
        displayText: 'At the end of the day',
        audioItemId: 'audio-1',
        sentenceIndex: 2,
        sentenceText: 'At the end of the day, we succeeded.',
        sentenceStartMs: 1000,
        sentenceEndMs: 4000,
        groupStartMs: 1000,
        groupEndMs: 2500,
      );

      await db.savedSenseGroupDao.clearContextForAudio('audio-1');

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.length, 1);
      final item = all.first;
      // phraseText 和 displayText 保留
      expect(item.phraseText, 'at the end of the day');
      expect(item.displayText, 'At the end of the day');
      // 所有上下文字段被清除
      expect(item.sentenceIndex, isNull);
      expect(item.sentenceText, isNull);
      expect(item.sentenceStartMs, isNull);
      expect(item.sentenceEndMs, isNull);
      expect(item.groupStartMs, isNull);
      expect(item.groupEndMs, isNull);
      // audioItemId 不在此方法清除（由 FK SET NULL 处理）
      expect(item.audioItemId, 'audio-1');
    });

    test('clearContextForAudios 批量清除多个音频上下文', () async {
      final now = DateTime.now();
      await db.audioItemDao.batchInsert(
        List.generate(
          3,
          (i) => AudioItemsCompanion(
            id: Value('audio-$i'),
            name: Value('Audio $i'),
            audioPath: Value('$i.mp3'),
            addedDate: Value(now),
            updatedAt: Value(now),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await db.savedSenseGroupDao.saveSenseGroup(
          phraseText: 'phrase-$i',
          displayText: 'Phrase $i',
          audioItemId: 'audio-$i',
          sentenceIndex: i,
          sentenceText: 'Sentence $i',
          sentenceStartMs: i * 1000,
          sentenceEndMs: i * 1000 + 500,
          groupStartMs: i * 1000,
          groupEndMs: i * 1000 + 250,
        );
      }

      await db.savedSenseGroupDao.clearContextForAudios({'audio-0', 'audio-1'});

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      final cleared = all
          .where(
            (g) => g.phraseText == 'phrase-0' || g.phraseText == 'phrase-1',
          )
          .toList();
      expect(cleared.every((g) => g.sentenceIndex == null), isTrue);
      expect(cleared.every((g) => g.sentenceText == null), isTrue);
      expect(cleared.every((g) => g.groupStartMs == null), isTrue);
      final untouched = all.firstWhere((g) => g.phraseText == 'phrase-2');
      expect(untouched.sentenceIndex, 2);
      expect(untouched.sentenceText, 'Sentence 2');
      expect(untouched.groupStartMs, 2000);
    });

    test('getDeletedSenseGroups 返回已软删除的意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'first of all',
        displayText: 'First of all',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in conclusion',
        displayText: 'In conclusion',
      );

      await db.savedSenseGroupDao.removeSenseGroup('first of all');

      final deleted = await db.savedSenseGroupDao.getDeletedSenseGroups(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted.length, 1);
      expect(deleted.first.phraseText, 'first of all');
    });

    test('restoreSenseGroup 恢复已软删除的意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'by the way',
        displayText: 'By the way',
      );
      await db.savedSenseGroupDao.removeSenseGroup('by the way');
      expect(
        await db.savedSenseGroupDao.isSenseGroupSaved('by the way'),
        false,
      );

      await db.savedSenseGroupDao.restoreSenseGroup('by the way');
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('by the way'), true);
    });

    test('permanentlyDeleteSenseGroup 物理删除意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in fact',
        displayText: 'In fact',
      );
      await db.savedSenseGroupDao.removeSenseGroup('in fact');
      await db.savedSenseGroupDao.permanentlyDeleteSenseGroup('in fact');

      await db.savedSenseGroupDao.restoreSenseGroup('in fact');
      expect(await db.savedSenseGroupDao.isSenseGroupSaved('in fact'), false);
    });

    test('permanentlyDeleteAllDeleted 清空回收站但不影响活跃意群', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'on the other hand',
        displayText: 'On the other hand',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'as a result',
        displayText: 'As a result',
      );

      await db.savedSenseGroupDao.removeSenseGroup('on the other hand');
      await db.savedSenseGroupDao.permanentlyDeleteAllDeleted();

      final deleted = await db.savedSenseGroupDao.getDeletedSenseGroups(
        sortMode: RecycleBinSortMode.timeDesc,
      );
      expect(deleted, isEmpty);

      expect(
        await db.savedSenseGroupDao.isSenseGroupSaved('as a result'),
        true,
      );
    });

    test('watchSavedPhraseTexts 返回归一化文本集合', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'first of all',
        displayText: 'First of all',
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in conclusion',
        displayText: 'In conclusion',
      );

      final texts = await db.savedSenseGroupDao.watchSavedPhraseTexts().first;
      expect(texts, {'first of all', 'in conclusion'});
    });

    test('getByAudioId 只返回指定音频的未删除意群，按句子索引升序', () async {
      final now = DateTime.now();
      await db.audioItemDao.upsert(
        AudioItemsCompanion(
          id: const Value('audio-1'),
          name: const Value('Audio 1'),
          audioPath: const Value('1.mp3'),
          addedDate: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'as a result',
        displayText: 'As a result',
        audioItemId: 'audio-1',
        sentenceIndex: 4,
      );
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'first of all',
        displayText: 'First of all',
        audioItemId: 'audio-1',
        sentenceIndex: 1,
      );
      // 无来源音频的意群不应出现
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in conclusion',
        displayText: 'In conclusion',
      );
      // 软删除的意群不应出现
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'to be deleted',
        displayText: 'To be deleted',
        audioItemId: 'audio-1',
        sentenceIndex: 0,
      );
      await db.savedSenseGroupDao.removeSenseGroup('to be deleted');

      final groups = await db.savedSenseGroupDao.getByAudioId('audio-1');
      expect(groups.map((g) => g.phraseText).toList(), [
        'first of all',
        'as a result',
      ]);
    });
  });

  // ========== 练习统计更新 ==========

  group('updatePracticeStats', () {
    test('更新 practiceCount、totalStudyMs、viewedBack、lastPracticedAt', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'in the morning',
        displayText: 'In the morning',
      );

      // 初始值
      var all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.first.practiceCount, 0);
      expect(all.first.totalStudyMs, 0);
      expect(all.first.viewedBack, false);
      expect(all.first.lastPracticedAt, isNull);

      // 练习一次
      await db.savedSenseGroupDao.updatePracticeStats(
        phraseText: 'in the morning',
        studyMs: 3000,
      );

      all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.first.practiceCount, 1);
      expect(all.first.totalStudyMs, 3000);
      expect(all.first.viewedBack, true);
      expect(all.first.lastPracticedAt, isNotNull);
    });

    test('多次调用累加正确', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'as a result',
        displayText: 'As a result',
      );

      await db.savedSenseGroupDao.updatePracticeStats(
        phraseText: 'as a result',
        studyMs: 2000,
      );
      await db.savedSenseGroupDao.updatePracticeStats(
        phraseText: 'as a result',
        studyMs: 4000,
      );

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.first.practiceCount, 2);
      expect(all.first.totalStudyMs, 6000);
    });

    test('studyMs 超过 60000 被 clamp', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'on the other hand',
        displayText: 'On the other hand',
      );

      await db.savedSenseGroupDao.updatePracticeStats(
        phraseText: 'on the other hand',
        studyMs: 120000,
      );

      final all = await (db.select(
        db.savedSenseGroups,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(all.first.totalStudyMs, 60000);
    });

    test('更新后 watchAll stream 收到新数据', () async {
      await db.savedSenseGroupDao.saveSenseGroup(
        phraseText: 'for instance',
        displayText: 'For instance',
      );

      // 监听 stream，跳过初始值
      final stream = db.savedSenseGroupDao.watchAll().skip(1);
      final future = stream.first;

      // 更新统计
      await db.savedSenseGroupDao.updatePracticeStats(
        phraseText: 'for instance',
        studyMs: 5000,
      );

      // stream 应发射更新后的数据
      final updated = await future.timeout(const Duration(seconds: 3));
      expect(updated.first.practiceCount, 1);
      expect(updated.first.lastPracticedAt, isNotNull);
    });
  });
}

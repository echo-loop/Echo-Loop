// 书签持久化测试。
// 验证精听模式中标记难句后，书签能正确持久化到数据库，且下次进入时能正确恢复。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/favorite_sentence_lifecycle_provider.dart';
import 'package:echo_loop/providers/listening_practice/bookmark_manager.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

/// 创建测试用句子列表
///
/// [bookmarkedPositions] 指定哪些位置的句子标记为已收藏
List<Sentence> _createTestSentences({
  int count = 5,
  Set<int> bookmarkedPositions = const {},
}) {
  return List.generate(count, (i) {
    return Sentence(
      index: i,
      text: 'Sentence $i',
      startTime: Duration(seconds: i * 3),
      endTime: Duration(seconds: i * 3 + 3),
      isBookmarked: bookmarkedPositions.contains(i),
    );
  });
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FavoriteSentenceLifecycle sentenceLifecycle;
  const audioId = 'audio-test';

  setUp(() async {
    db = _createTestDb();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    sentenceLifecycle = container.read(favoriteSentenceLifecycleProvider);
    final now = DateTime.now();
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-test'),
        name: const Value('Test Audio'),
        audioPath: const Value('test.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('收藏句生命周期持久化', () {
    test('保存收藏句后可读取收藏索引', () async {
      final sentences = _createTestSentences();
      await sentenceLifecycle.save(audioId, sentences[2]);

      final indices = await BookmarkManager.loadBookmarks(
        audioId,
        dao: db.bookmarkDao,
      );
      expect(indices, {2});
    });

    test('删除收藏句后只移除指定索引', () async {
      final sentences = _createTestSentences();
      // 先添加 3 个书签
      for (final i in [0, 2, 4]) {
        await sentenceLifecycle.save(audioId, sentences[i]);
      }

      // 移除 index 0 和 4
      await sentenceLifecycle.remove(audioId, {0, 4});

      final indices = await BookmarkManager.loadBookmarks(
        audioId,
        dao: db.bookmarkDao,
      );
      expect(indices, {2});
    });
  });

  group('难句标记增量同步逻辑', () {
    test('新增难句正确保存、取消难句正确移除', () async {
      final sentences = _createTestSentences(bookmarkedPositions: {1, 3});

      // 模拟初始状态：句子 1、3 已有书签
      for (final i in [1, 3]) {
        await sentenceLifecycle.save(audioId, sentences[i]);
      }

      // 模拟用户操作后的 difficultSentences = {1, 2, 4}
      //   - 句子 1: 保留（无变化）
      //   - 句子 2: 新增
      //   - 句子 3: 移除
      //   - 句子 4: 新增
      final difficultSentences = <int>{1, 2, 4};

      // 构建初始书签集合（使用位置索引，与 difficultSentences 一致）
      final initialBookmarks = <int>{
        for (final (i, s) in sentences.indexed)
          if (s.isBookmarked) i,
      };
      expect(initialBookmarks, {1, 3});

      // 计算新增和移除
      final added = difficultSentences.difference(initialBookmarks);
      expect(added, {2, 4});

      for (final index in added) {
        await sentenceLifecycle.save(audioId, sentences[index]);
      }

      final removedPositions = initialBookmarks.difference(difficultSentences);
      expect(removedPositions, {3});

      if (removedPositions.isNotEmpty) {
        final removedSentenceIndices = <int>{
          for (final pos in removedPositions)
            if (pos < sentences.length) sentences[pos].index,
        };
        await sentenceLifecycle.remove(audioId, removedSentenceIndices);
      }

      // 验证最终数据库状态
      final finalIndices = await BookmarkManager.loadBookmarks(
        audioId,
        dao: db.bookmarkDao,
      );
      expect(finalIndices, {1, 2, 4});
    });

    test('position 索引与 sentence.index 不同时增量同步正确', () async {
      // 模拟 position != sentence.index 的情况
      // 例如：句子列表只包含部分句子，index 不连续
      final sentences = [
        Sentence(
          index: 5,
          text: 'Sentence at index 5',
          startTime: const Duration(seconds: 0),
          endTime: const Duration(seconds: 3),
          isBookmarked: true,
        ),
        Sentence(
          index: 10,
          text: 'Sentence at index 10',
          startTime: const Duration(seconds: 3),
          endTime: const Duration(seconds: 6),
          isBookmarked: false,
        ),
        Sentence(
          index: 15,
          text: 'Sentence at index 15',
          startTime: const Duration(seconds: 6),
          endTime: const Duration(seconds: 9),
          isBookmarked: true,
        ),
      ];

      // 预存已有书签（sentence.index 5 和 15）
      for (final s in sentences.where((s) => s.isBookmarked)) {
        await sentenceLifecycle.save(audioId, s);
      }

      // 初始书签用位置索引: position 0 (index=5), position 2 (index=15)
      final initialBookmarks = <int>{
        for (final (i, s) in sentences.indexed)
          if (s.isBookmarked) i,
      };
      expect(initialBookmarks, {0, 2});

      // 用户操作：取消 position 0, 新增 position 1
      // difficultSentences = {1, 2}
      final difficultSentences = <int>{1, 2};

      // 新增: position 1
      final added = difficultSentences.difference(initialBookmarks);
      for (final index in added) {
        await sentenceLifecycle.save(audioId, sentences[index]);
      }

      // 移除: position 0 → sentence.index = 5
      final removedPositions = initialBookmarks.difference(difficultSentences);
      expect(removedPositions, {0});

      final removedSentenceIndices = <int>{
        for (final pos in removedPositions)
          if (pos < sentences.length) sentences[pos].index,
      };
      expect(removedSentenceIndices, {5});

      await sentenceLifecycle.remove(audioId, removedSentenceIndices);

      // 验证：应保留 index 10 和 15（position 1 和 2）
      final finalIndices = await BookmarkManager.loadBookmarks(
        audioId,
        dao: db.bookmarkDao,
      );
      expect(finalIndices, {10, 15});
    });
  });

  group('syncBookmarks 书签同步', () {
    test('updateSentenceBookmarkStatus 正确更新句子状态', () {
      final sentences = _createTestSentences();
      // 所有句子初始 isBookmarked = false
      for (final s in sentences) {
        expect(s.isBookmarked, false);
      }

      // 同步书签状态
      BookmarkManager.updateSentenceBookmarkStatus(sentences, {1, 3});

      expect(sentences[0].isBookmarked, false);
      expect(sentences[1].isBookmarked, true);
      expect(sentences[2].isBookmarked, false);
      expect(sentences[3].isBookmarked, true);
      expect(sentences[4].isBookmarked, false);
    });

    test('完整流程：标记→保存→加载→恢复', () async {
      final sentences = _createTestSentences();

      // 1. 模拟精听中标记 position 1 和 3 为难句
      final difficultSentences = <int>{1, 3};
      for (final pos in difficultSentences) {
        await sentenceLifecycle.save(audioId, sentences[pos]);
      }

      // 2. 模拟退出后重新加载书签
      final loadedIndices = await BookmarkManager.loadBookmarks(
        audioId,
        dao: db.bookmarkDao,
      );
      expect(loadedIndices, {1, 3});

      // 3. 模拟重新进入时恢复句子书签状态
      final freshSentences = _createTestSentences();
      BookmarkManager.updateSentenceBookmarkStatus(
        freshSentences,
        loadedIndices,
      );

      // 4. 验证书签状态正确恢复
      expect(freshSentences[1].isBookmarked, true);
      expect(freshSentences[3].isBookmarked, true);
      expect(freshSentences[0].isBookmarked, false);
      expect(freshSentences[2].isBookmarked, false);
      expect(freshSentences[4].isBookmarked, false);

      // 5. 模拟 IntensiveListenPlayer 初始化时从 isBookmarked 预填 difficultSentences
      final preBookmarked = <int>{
        for (final (i, s) in freshSentences.indexed)
          if (s.isBookmarked) i,
      };
      expect(preBookmarked, {1, 3});
    });
  });
}

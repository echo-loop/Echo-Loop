import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
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
    db = _createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('SentenceAiCacheDao', () {
    test('upsert 后 getByHash 返回缓存结果', () async {
      await db.sentenceAiCacheDao.upsert(
        'abc123',
        'translation',
        '{"translation":"你好世界"}',
      );

      final result = await db.sentenceAiCacheDao.getByHash(
        'abc123',
        'translation',
      );
      expect(result, '{"translation":"你好世界"}');
    });

    test('getByHash 未命中返回 null', () async {
      final result = await db.sentenceAiCacheDao.getByHash(
        'nonexistent',
        'translation',
      );
      expect(result, isNull);
    });

    test('同 hash 不同 type 互不干扰', () async {
      await db.sentenceAiCacheDao.upsert(
        'abc123',
        'translation',
        '{"translation":"翻译"}',
      );
      await db.sentenceAiCacheDao.upsert(
        'abc123',
        'analysis',
        '{"analysis":{"grammar":"g","vocabulary":"v","listening":"u"}}',
      );

      final translation = await db.sentenceAiCacheDao.getByHash(
        'abc123',
        'translation',
      );
      final analysis = await db.sentenceAiCacheDao.getByHash(
        'abc123',
        'analysis',
      );
      expect(translation, contains('翻译'));
      expect(analysis, contains('grammar'));
    });

    test('upsert 相同 hash+type 会更新 result', () async {
      await db.sentenceAiCacheDao.upsert(
        'abc123',
        'translation',
        '{"translation":"旧翻译"}',
      );
      await db.sentenceAiCacheDao.upsert(
        'abc123',
        'translation',
        '{"translation":"新翻译"}',
      );

      final result = await db.sentenceAiCacheDao.getByHash(
        'abc123',
        'translation',
      );
      expect(result, '{"translation":"新翻译"}');
    });

    test('deleteOlderThan 删除过期缓存', () async {
      // 先插入两条缓存
      await db.sentenceAiCacheDao.upsert(
        'old',
        'translation',
        '{"translation":"旧"}',
      );
      await db.sentenceAiCacheDao.upsert(
        'new',
        'translation',
        '{"translation":"新"}',
      );

      // 手动将第一条的 lastAccessedAt 设为 31 天前（Drift 用 epoch 秒存储）
      final oldEpoch =
          DateTime.now()
              .subtract(const Duration(days: 31))
              .millisecondsSinceEpoch ~/
          1000;
      await db.customStatement(
        "UPDATE sentence_ai_cache SET last_accessed_at = $oldEpoch WHERE text_hash = 'old'",
      );

      // 删除 30 天未访问的缓存
      final deleted = await db.sentenceAiCacheDao.deleteOlderThan(
        const Duration(days: 30),
      );
      expect(deleted, 1);

      // 旧的被删除，新的保留
      final oldResult = await db.sentenceAiCacheDao.getByHash(
        'old',
        'translation',
      );
      final newResult = await db.sentenceAiCacheDao.getByHash(
        'new',
        'translation',
      );
      expect(oldResult, isNull);
      expect(newResult, isNotNull);
    });

    test('getManyByHash 批量返回命中项，未命中不在结果中', () async {
      await db.sentenceAiCacheDao.upsert('h1', 'translation:zh-CN', '{"t":1}');
      await db.sentenceAiCacheDao.upsert('h2', 'translation:zh-CN', '{"t":2}');
      await db.sentenceAiCacheDao.upsert('h3', 'analysis:zh-CN', '{"a":3}');

      final result = await db.sentenceAiCacheDao.getManyByHash([
        'h1',
        'h2',
        'h3',
        'missing',
      ], 'translation:zh-CN');

      expect(result, {'h1': '{"t":1}', 'h2': '{"t":2}'});
      expect(result.containsKey('h3'), isFalse); // 类型不符
      expect(result.containsKey('missing'), isFalse);
    });

    test('getManyByHash 空哈希列表返回空 map', () async {
      final result = await db.sentenceAiCacheDao.getManyByHash(
        const [],
        'translation:zh-CN',
      );
      expect(result, isEmpty);
    });

    test('getManyByHash 不刷新 lastAccessedAt（只读，避免写放大）', () async {
      await db.sentenceAiCacheDao.upsert('r1', 'translation:zh-CN', '{"t":1}');
      final pastEpoch =
          DateTime.now()
              .subtract(const Duration(days: 10))
              .millisecondsSinceEpoch ~/
          1000;
      await db.customStatement(
        "UPDATE sentence_ai_cache SET last_accessed_at = $pastEpoch WHERE text_hash = 'r1'",
      );

      await db.sentenceAiCacheDao.getManyByHash(['r1'], 'translation:zh-CN');

      // 批量读取不应刷新访问时间：5 天阈值仍会删除这条 10 天前的记录
      final deleted = await db.sentenceAiCacheDao.deleteOlderThan(
        const Duration(days: 5),
      );
      expect(deleted, 1);
    });

    test('getByHash 更新 lastAccessedAt', () async {
      await db.sentenceAiCacheDao.upsert(
        'abc',
        'translation',
        '{"translation":"test"}',
      );

      // 将 lastAccessedAt 设为 10 天前（Drift 用 epoch 秒存储）
      final pastEpoch =
          DateTime.now()
              .subtract(const Duration(days: 10))
              .millisecondsSinceEpoch ~/
          1000;
      await db.customStatement(
        "UPDATE sentence_ai_cache SET last_accessed_at = $pastEpoch WHERE text_hash = 'abc'",
      );

      // 读取一次，应更新 lastAccessedAt
      await db.sentenceAiCacheDao.getByHash('abc', 'translation');

      // 删除 5 天未访问的，读取过的不应被删除
      final deleted = await db.sentenceAiCacheDao.deleteOlderThan(
        const Duration(days: 5),
      );
      expect(deleted, 0);
    });
  });
}

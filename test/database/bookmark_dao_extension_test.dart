import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

/// 创建内存数据库用于测试
AppDatabase _createTestDb() {
  return AppDatabase(
    NativeDatabase.memory(setup: configureAppDatabaseConnection),
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = _createTestDb();
    // 插入测试音频
    final now = DateTime.now();
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('English Podcast'),
        audioPath: const Value('podcast.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-2'),
        name: const Value('TED Talk'),
        audioPath: const Value('ted.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('BookmarkDao.watchAllWithAudioName', () {
    test('返回空列表当无书签时', () async {
      final results = await db.bookmarkDao.watchAllWithAudioName().first;
      expect(results, isEmpty);
    });

    test('返回书签含音频名称', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          sentenceIndex: const Value(0),
          sentenceText: const Value('Hello world'),
          startTime: const Value(0.0),
          endTime: const Value(3.5),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final results = await db.bookmarkDao.watchAllWithAudioName().first;
      expect(results.length, 1);
      expect(results.first.audioName, 'English Podcast');
      expect(results.first.bookmark.sentenceText, 'Hello world');
    });

    test('按音频名称和句子索引排序', () async {
      final now = DateTime.now();
      // audio-2 (TED Talk) 的书签
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-2'),
          sentenceIndex: const Value(0),
          sentenceText: const Value('TED sentence 1'),
          startTime: const Value(0.0),
          endTime: const Value(2.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      // audio-1 (English Podcast) 的书签
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          sentenceIndex: const Value(2),
          sentenceText: const Value('Podcast sentence 3'),
          startTime: const Value(5.0),
          endTime: const Value(8.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          sentenceIndex: const Value(0),
          sentenceText: const Value('Podcast sentence 1'),
          startTime: const Value(0.0),
          endTime: const Value(3.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final results = await db.bookmarkDao.watchAllWithAudioName().first;
      expect(results.length, 3);
      // English Podcast 先于 TED Talk（按名称排序）
      expect(results[0].audioName, 'English Podcast');
      expect(results[0].bookmark.sentenceIndex, 0);
      expect(results[1].audioName, 'English Podcast');
      expect(results[1].bookmark.sentenceIndex, 2);
      expect(results[2].audioName, 'TED Talk');
    });

    test('不包含已软删除的书签', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          sentenceIndex: const Value(0),
          sentenceText: const Value('Active bookmark'),
          startTime: const Value(0.0),
          endTime: const Value(3.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // 直接插入一个带 deletedAt 的书签
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion(
              audioItemId: const Value('audio-1'),
              sentenceIndex: const Value(1),
              sentenceText: const Value('Deleted bookmark'),
              startTime: const Value(3.0),
              endTime: const Value(6.0),
              createdAt: Value(now),
              updatedAt: Value(now),
              deletedAt: Value(now),
            ),
          );

      final results = await db.bookmarkDao.watchAllWithAudioName().first;
      expect(results.length, 1);
      expect(results.first.bookmark.sentenceText, 'Active bookmark');
    });

    test('删除音频后书签消失（CASCADE）', () async {
      final now = DateTime.now();
      await db.bookmarkDao.addBookmark(
        BookmarksCompanion(
          audioItemId: const Value('audio-1'),
          sentenceIndex: const Value(0),
          sentenceText: const Value('Will be cascaded'),
          startTime: const Value(0.0),
          endTime: const Value(3.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.audioItemDao.hardDelete('audio-1');

      final results = await db.bookmarkDao.watchAllWithAudioName().first;
      expect(results, isEmpty);
    });
  });
}

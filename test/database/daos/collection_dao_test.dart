import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

/// 创建内存数据库（启用外键约束，junction 插入需要合集/音频行先存在）。
AppDatabase _createTestDatabase() {
  return AppDatabase(
    NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  /// 预置一个合集。
  Future<void> seedCollection(String id) async {
    final now = DateTime(2026, 1, 1);
    await db.collectionDao.upsert(
      CollectionsCompanion(
        id: Value(id),
        name: Value(id),
        createdDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// 预置一个音频条目。
  Future<void> seedAudio(String id) async {
    final now = DateTime(2026, 1, 1);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: Value(id),
        audioPath: Value('audios/$id.m4a'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  group('CollectionDao.removeAudios', () {
    test('从指定合集批量移除多个音频，仅剩未选中项', () async {
      await seedCollection('c1');
      await seedAudio('a1');
      await seedAudio('a2');
      await seedAudio('a3');
      await db.collectionDao.addAudios('c1', ['a1', 'a2', 'a3']);

      await db.collectionDao.removeAudios('c1', {'a1', 'a3'});

      expect(await db.collectionDao.getAudioIds('c1'), ['a2']);
    });

    test('不影响其它合集对同一音频的引用', () async {
      await seedCollection('c1');
      await seedCollection('c2');
      await seedAudio('a1');
      await seedAudio('a2');
      await db.collectionDao.addAudios('c1', ['a1', 'a2']);
      await db.collectionDao.addAudios('c2', ['a1', 'a2']);

      await db.collectionDao.removeAudios('c1', {'a1', 'a2'});

      expect(await db.collectionDao.getAudioIds('c1'), isEmpty);
      expect(await db.collectionDao.getAudioIds('c2'), ['a1', 'a2']);
    });

    test('空集合为 no-op', () async {
      await seedCollection('c1');
      await seedAudio('a1');
      await db.collectionDao.addAudios('c1', ['a1']);

      await db.collectionDao.removeAudios('c1', {});

      expect(await db.collectionDao.getAudioIds('c1'), ['a1']);
    });
  });
}

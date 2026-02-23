import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/database/app_database.dart';
import 'package:fluency/database/daos/tag_dao.dart';

void main() {
  late AppDatabase db;
  late TagDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: (db) {
      db.execute('PRAGMA foreign_keys = ON');
    }));
    dao = db.tagDao;
  });

  tearDown(() async {
    await db.close();
  });

  /// 辅助：创建标签
  Future<void> insertTag(String id, String name, int color) async {
    await dao.upsert(TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdDate: Value(DateTime(2026, 1, 1)),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 辅助：创建音频
  Future<void> insertAudio(String id) async {
    await db.audioItemDao.upsert(AudioItemsCompanion(
      id: Value(id),
      name: Value('Audio $id'),
      audioPath: Value('audios/$id.mp3'),
      addedDate: Value(DateTime(2026, 1, 1)),
      updatedAt: Value(DateTime.now()),
    ));
  }

  group('CRUD 操作', () {
    test('getAllActive 返回未删除的标签', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertTag('t2', 'Tag 2', 0xFF4CAF50);
      // 软删除 t2
      await dao.softDelete('t2');

      final results = await dao.getAllActive();
      expect(results.length, 1);
      expect(results.first.name, 'Tag 1');
    });

    test('getById 返回正确的标签', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);

      final result = await dao.getById('t1');
      expect(result, isNotNull);
      expect(result!.name, 'Tag 1');
      expect(result.color, 0xFFF44336);
    });

    test('getById 不存在时返回 null', () async {
      final result = await dao.getById('nonexistent');
      expect(result, isNull);
    });

    test('upsert 更新已有标签', () async {
      await insertTag('t1', 'Original', 0xFFF44336);
      await dao.upsert(TagsCompanion(
        id: const Value('t1'),
        name: const Value('Updated'),
        color: const Value(0xFF4CAF50),
        createdDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime.now()),
      ));

      final result = await dao.getById('t1');
      expect(result!.name, 'Updated');
      expect(result.color, 0xFF4CAF50);
    });

    test('hardDelete 物理删除标签', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await dao.hardDelete('t1');

      final result = await dao.getById('t1');
      expect(result, isNull);
    });
  });

  group('Junction 表操作', () {
    test('addAudio 和 getAudioIds', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertAudio('a1');
      await insertAudio('a2');

      await dao.addAudio('t1', 'a1');
      await dao.addAudio('t1', 'a2');

      final ids = await dao.getAudioIds('t1');
      expect(ids, containsAll(['a1', 'a2']));
    });

    test('removeAudio 移除关联', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertAudio('a1');
      await insertAudio('a2');

      await dao.addAudio('t1', 'a1');
      await dao.addAudio('t1', 'a2');
      await dao.removeAudio('t1', 'a1');

      final ids = await dao.getAudioIds('t1');
      expect(ids, ['a2']);
    });

    test('removeAudioFromAll 从所有标签移除', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertTag('t2', 'Tag 2', 0xFF4CAF50);
      await insertAudio('a1');

      await dao.addAudio('t1', 'a1');
      await dao.addAudio('t2', 'a1');
      await dao.removeAudioFromAll('a1');

      expect(await dao.getAudioIds('t1'), isEmpty);
      expect(await dao.getAudioIds('t2'), isEmpty);
    });

    test('CASCADE 删除标签时自动清理 junction', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertAudio('a1');
      await dao.addAudio('t1', 'a1');

      await dao.hardDelete('t1');

      // 通过直接查 junction 表验证
      final rows = await db.select(db.audioItemTags).get();
      expect(rows, isEmpty);
    });

    test('CASCADE 删除音频时自动清理 junction', () async {
      await insertTag('t1', 'Tag 1', 0xFFF44336);
      await insertAudio('a1');
      await dao.addAudio('t1', 'a1');

      await db.audioItemDao.hardDelete('a1');

      final ids = await dao.getAudioIds('t1');
      expect(ids, isEmpty);
    });
  });
}

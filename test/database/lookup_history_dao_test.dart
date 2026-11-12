import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/tables/lookup_histories.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DateTime at(int second) => DateTime(2026, 1, 1, 0, 0, second);

  group('LookupHistoryDao', () {
    test('最近查询排在前面', () async {
      final dao = db.lookupHistoryDao;
      await dao.record('apple', at(1));
      await dao.record('banana', at(2));

      final rows = await dao.watchRecent().first;

      expect(rows.map((row) => row.word), ['banana', 'apple']);
    });

    test('同一词只保留一条并刷新查询时间', () async {
      final dao = db.lookupHistoryDao;
      await dao.record('apple', at(1));
      await dao.record('banana', at(2));
      await dao.record('apple', at(3));

      final rows = await dao.watchRecent().first;

      expect(rows.map((row) => row.word), ['apple', 'banana']);
      expect(rows.first.lookedUpAt, at(3));
    });

    test('超过上限时裁剪为最近的 20 条', () async {
      final dao = db.lookupHistoryDao;
      for (var i = 0; i < kLookupHistoryLimit + 5; i++) {
        await dao.record('word$i', at(i));
      }

      final rows = await dao.watchRecent().first;

      expect(rows, hasLength(kLookupHistoryLimit));
      expect(rows.first.word, 'word${kLookupHistoryLimit + 4}');
      expect(rows.last.word, 'word5');
    });

    test('清空后没有历史', () async {
      final dao = db.lookupHistoryDao;
      await dao.record('apple', at(1));

      await dao.clear();

      expect(await dao.watchRecent().first, isEmpty);
    });
  });
}

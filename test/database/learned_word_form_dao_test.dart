import 'package:echo_loop/database/daos/learned_word_form_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

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

  group('LearnedWordFormDao', () {
    test('insertIfAbsentAll 只保留唯一词形', () async {
      await db.learnedWordFormDao.insertIfAbsentAll({
        'child': DateTime(2026, 3, 12, 10),
        'children': DateTime(2026, 3, 12, 10),
      });
      await db.learnedWordFormDao.insertIfAbsentAll({
        'child': DateTime(2026, 3, 12, 11),
      });

      expect(await db.learnedWordFormDao.countAll(), 2);
    });

    test('countFirstLearnedBetween 只统计指定时间范围内的首次学习', () async {
      final today = DateTime(2026, 3, 12, 10);
      final yesterday = DateTime(2026, 3, 11, 20);
      await db.learnedWordFormDao.insertIfAbsentAll({
        'child': today,
        'children': today,
        'run': yesterday,
      });

      final start = DateTime(2026, 3, 12);
      final end = DateTime(2026, 3, 13);
      expect(
        await db.learnedWordFormDao.countFirstLearnedBetween(start, end),
        2,
      );
    });

    test('fetchPage 默认时间倒序分页', () async {
      await db.learnedWordFormDao.insertIfAbsentAll({
        'alpha': DateTime(2026, 3, 12, 8),
        'beta': DateTime(2026, 3, 12, 10),
        'gamma': DateTime(2026, 3, 12, 9),
      });

      final page = await db.learnedWordFormDao.fetchPage(
        limit: 2,
        offset: 0,
        sortMode: LearnedWordSortMode.timeDesc,
      );

      expect(page.map((e) => e.wordForm).toList(), ['beta', 'gamma']);
    });

    test('fetchPage 支持字母倒序', () async {
      await db.learnedWordFormDao.insertIfAbsentAll({
        'alpha': DateTime(2026, 3, 12, 8),
        'beta': DateTime(2026, 3, 12, 10),
        'gamma': DateTime(2026, 3, 12, 9),
      });

      final page = await db.learnedWordFormDao.fetchPage(
        limit: 3,
        offset: 0,
        sortMode: LearnedWordSortMode.alphabeticalDesc,
      );

      expect(page.map((e) => e.wordForm).toList(), ['gamma', 'beta', 'alpha']);
    });
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'migration_fixture_helper.dart';

void main() {
  test(
    'v55 to v57 adds nullable community metadata without losing collections',
    () async {
      final directory = Directory.systemTemp.createTempSync('fluency_v55_v56_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });

      final file = File('${directory.path}/echo_loop.db');
      await seedCurrentSchema(file);

      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute(
          '''
        INSERT INTO collections (id, name, created_date, updated_at)
        VALUES (?, ?, ?, ?)
        ''',
          [
            'community-local-1',
            'Community English',
            DateTime(2026, 9, 22).millisecondsSinceEpoch,
            DateTime(2026, 9, 22).millisecondsSinceEpoch,
          ],
        );
        raw
          ..execute('ALTER TABLE collections DROP COLUMN author_nickname')
          ..execute('ALTER TABLE collections DROP COLUMN published_at')
          ..execute('PRAGMA user_version = 55');
      } finally {
        raw.close();
      }

      final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(collections)')
          .get();
      final columnNames = columns
          .map((row) => row.data['name'])
          .whereType<String>()
          .toSet();
      expect(columnNames, containsAll(['author_nickname', 'published_at']));

      final collection = await database.collectionDao.getById(
        'community-local-1',
      );
      expect(collection?.name, 'Community English');
      expect(collection?.authorNickname, isNull);
      expect(collection?.publishedAt, isNull);
    },
  );
}

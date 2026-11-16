import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v68→v69 为合集添加本地封面列，已有合集默认无封面', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v68_v69_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    var database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    await database.collectionDao.upsert(
      CollectionsCompanion(
        id: const Value('local-1'),
        name: const Value('My Collection'),
        createdDate: Value(DateTime.utc(2026, 11, 1)),
        updatedAt: Value(DateTime.utc(2026, 11, 1)),
      ),
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('ALTER TABLE collections DROP COLUMN local_cover_path');
      raw.execute('PRAGMA user_version = 68');
    } finally {
      raw.close();
    }

    database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    final collection = await database.collectionDao.getById('local-1');

    expect(collection?.name, 'My Collection');
    expect(collection?.localCoverPath, isNull);
    await database.close();
  });
}

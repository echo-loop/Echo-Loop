import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v58→v59 为合集添加中国封面列并保留已有全球封面', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v58_v59_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    var database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    await database.collectionDao.upsert(
      CollectionsCompanion(
        id: const Value('community-1'),
        name: const Value('Community English'),
        createdDate: Value(DateTime.utc(2026, 10, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
        source: const Value('community'),
        remoteId: const Value('remote-1'),
        coverUrl: const Value('https://global.example/cover.jpg'),
        coverUrlChina: const Value('https://china.example/cover.jpg'),
      ),
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('ALTER TABLE collections DROP COLUMN cover_url_china');
      raw.execute('PRAGMA user_version = 58');
    } finally {
      raw.close();
    }

    database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    final collection = await database.collectionDao.getById('community-1');

    expect(collection?.coverUrl, 'https://global.example/cover.jpg');
    expect(collection?.coverUrlChina, isNull);
    await database.close();
  });
}

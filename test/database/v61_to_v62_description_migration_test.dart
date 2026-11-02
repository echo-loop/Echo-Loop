import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v61→v62 为音频添加可空文件描述字段并保留旧音频', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v61_v62_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    var database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('Existing lesson'),
        addedDate: Value(DateTime.utc(2026, 10, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
        remoteAudioId: const Value('remote-audio-1'),
      ),
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('ALTER TABLE audio_items DROP COLUMN description');
      raw.execute('PRAGMA user_version = 61');
    } finally {
      raw.close();
    }

    database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    final audio = await database.audioItemDao.getById('audio-1');

    expect(audio?.name, 'Existing lesson');
    expect(audio?.description, isNull);
    await database.close();
  });
}

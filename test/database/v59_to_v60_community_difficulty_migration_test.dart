import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v59→v60 为社区媒体添加可空难度字段并保留旧音频', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v59_v60_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    var database = AppDatabase(NativeDatabase(file));
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
      raw.execute('ALTER TABLE audio_items DROP COLUMN community_difficulty');
      raw.execute('PRAGMA user_version = 59');
    } finally {
      raw.dispose();
    }

    database = AppDatabase(NativeDatabase(file));
    final audio = await database.audioItemDao.getById('audio-1');

    expect(audio?.name, 'Existing lesson');
    expect(audio?.communityDifficulty, isNull);
    await database.close();
  });
}

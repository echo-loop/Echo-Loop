import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v63_v64_');
    file = File('${directory.path}/echo_loop.db');
    final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('Community lesson'),
        addedDate: Value(DateTime.utc(2026, 10, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
        remoteAudioId: const Value('remote-audio-1'),
        difficulty: const Value('B1'),
      ),
    );
    await database.close();
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('v63→v64 把 community_difficulty 列重命名为 difficulty 并保留值', () async {
    // 还原 v63 结构：列名回退为 community_difficulty，版本号回退。
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute(
        'ALTER TABLE audio_items RENAME COLUMN difficulty TO community_difficulty',
      );
      raw.execute('PRAGMA user_version = 63');
    } finally {
      raw.close();
    }

    final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    final audio = await database.audioItemDao.getById('audio-1');
    await database.close();

    expect(audio?.name, 'Community lesson');
    expect(audio?.difficulty, 'B1');

    final check = sqlite.sqlite3.open(file.path);
    try {
      final columns = check
          .select('PRAGMA table_info(audio_items)')
          .map((row) => row['name'] as String);
      expect(columns, isNot(contains('community_difficulty')));
      expect(columns, contains('difficulty'));
    } finally {
      check.close();
    }
  });
}

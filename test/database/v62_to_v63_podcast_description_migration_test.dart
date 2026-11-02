import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// 在已关闭的数据库文件上还原 v62 结构：补回 podcast_description 列并回退版本号。
void _rollbackToV62(
  File file, {
  required String audioId,
  String? podcastDescription,
  String? description,
}) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw.execute('ALTER TABLE audio_items ADD COLUMN podcast_description TEXT');
    raw.execute(
      'UPDATE audio_items SET podcast_description = ?, description = ? '
      'WHERE id = ?',
      [podcastDescription, description, audioId],
    );
    raw.execute('PRAGMA user_version = 62');
  } finally {
    raw.close();
  }
}

bool _hasColumn(File file, String column) {
  final raw = sqlite.sqlite3.open(file.path);
  try {
    final rows = raw.select('PRAGMA table_info(audio_items)');
    return rows.any((row) => row['name'] == column);
  } finally {
    raw.close();
  }
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v62_v63_');
    file = File('${directory.path}/echo_loop.db');
    final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('audio-1'),
        name: const Value('Episode'),
        addedDate: Value(DateTime.utc(2026, 10, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
        podcastEpisodeGuid: const Value('guid-1'),
      ),
    );
    await database.close();
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('v62→v63 把播客简介迁入 description 并删除 podcast_description 列', () async {
    _rollbackToV62(file, audioId: 'audio-1', podcastDescription: 'RSS summary');

    final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    final audio = await database.audioItemDao.getById('audio-1');
    await database.close();

    expect(audio?.description, 'RSS summary');
    expect(_hasColumn(file, 'podcast_description'), isFalse);
  });

  test('v62→v63 迁移不覆盖已有的 description', () async {
    _rollbackToV62(
      file,
      audioId: 'audio-1',
      podcastDescription: 'RSS summary',
      description: 'Already set',
    );

    final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
    final audio = await database.audioItemDao.getById('audio-1');
    await database.close();

    expect(audio?.description, 'Already set');
  });

  test('删除列后再次启动不会把 podcast_description 补回来', () async {
    _rollbackToV62(file, audioId: 'audio-1', podcastDescription: 'RSS summary');

    // NativeDatabase 惰性打开：每次启动都要执行一次查询，迁移才会真正运行。
    for (var launch = 0; launch < 2; launch++) {
      final database = AppDatabase(NativeDatabase(file, setup: configureAppDatabaseConnection));
      await database.audioItemDao.getById('audio-1');
      await database.close();
    }

    expect(_hasColumn(file, 'podcast_description'), isFalse);
  });
}

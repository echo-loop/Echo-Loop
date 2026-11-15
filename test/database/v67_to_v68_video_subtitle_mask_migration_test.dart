import 'dart:io';

import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('fluency_v67_v68_');
    file = File('${directory.path}/echo_loop.db');
    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    await database.customSelect('SELECT 1').get();
    await database.close();
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('v67→v68 新增空的 video_subtitle_masks 表，且保留既有素材', () async {
    // 还原 v67 结构：删除遮罩表、写入一条已有素材并回退版本号
    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('DROP TABLE video_subtitle_masks');
      raw.execute(
        "INSERT INTO audio_items (id, name, added_date, updated_at) "
        "VALUES ('video-1', 'Video', 1767225600, 1767225600)",
      );
      raw.execute('PRAGMA user_version = 67');
    } finally {
      raw.close();
    }

    final database = AppDatabase(
      NativeDatabase(file, setup: configureAppDatabaseConnection),
    );
    final audio = await database.audioItemDao.getById('video-1');
    final mask = await database.videoSubtitleMaskDao.getByAudioId('video-1');
    await database.close();

    expect(audio, isNotNull);
    expect(mask, isNull);

    final check = sqlite.sqlite3.open(file.path);
    try {
      final version = check.select('PRAGMA user_version').first.values.first;
      expect(version, greaterThanOrEqualTo(68));
    } finally {
      check.close();
    }
  });
}

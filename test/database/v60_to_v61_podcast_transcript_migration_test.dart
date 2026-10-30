import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('v60→v61 为播客单集添加可空字幕字段并保留旧音频', () async {
    final directory = Directory.systemTemp.createTempSync('fluency_v60_v61_');
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    final file = File('${directory.path}/echo_loop.db');
    var database = AppDatabase(NativeDatabase(file));
    await database.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('podcast-audio-1'),
        name: const Value('Existing episode'),
        addedDate: Value(DateTime.utc(2026, 10, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
        podcastEpisodeGuid: const Value('ep-1'),
        podcastEnclosureUrl: const Value('https://example.com/ep1.mp3'),
      ),
    );
    await database.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('ALTER TABLE audio_items DROP COLUMN podcast_transcript_url');
      raw.execute(
        'ALTER TABLE audio_items DROP COLUMN podcast_transcript_format',
      );
      raw.execute('PRAGMA user_version = 60');
    } finally {
      raw.dispose();
    }

    database = AppDatabase(NativeDatabase(file));
    final audio = await database.audioItemDao.getById('podcast-audio-1');

    expect(audio?.name, 'Existing episode');
    expect(audio?.podcastEnclosureUrl, 'https://example.com/ep1.mp3');
    expect(audio?.podcastTranscriptUrl, isNull);
    expect(audio?.podcastTranscriptFormat, isNull);
    await database.close();
  });
}

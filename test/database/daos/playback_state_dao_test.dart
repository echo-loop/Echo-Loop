import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
  });

  tearDown(() async {
    await db.close();
  });

  test('watchLastSavedAtByAudio emits saved playback times', () async {
    final now = DateTime(2026, 10, 11, 12);
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: const Value('a1'),
        name: const Value('Audio One'),
        audioPath: const Value('audios/a1.mp3'),
        addedDate: Value(now),
        updatedAt: Value(now),
      ),
    );

    final events = StreamIterator(
      db.playbackStateDao.watchLastSavedAtByAudio(),
    );
    addTearDown(() async => events.cancel());
    expect(await events.moveNext(), isTrue);
    expect(events.current, isEmpty);

    await db.playbackStateDao.saveState(
      PlaybackStatesCompanion(
        audioItemId: const Value('a1'),
        positionMs: const Value(1200),
        savedAt: Value(now),
      ),
    );

    expect(await events.moveNext(), isTrue);
    expect(events.current, {'a1': now});
  });
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('AppDatabase.createBackupSnapshot', () {
    late Directory tempDir;
    late File databaseFile;
    late AppDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_snapshot_test_');
      databaseFile = File(p.join(tempDir.path, 'echo_loop.db'));
      database = AppDatabase(NativeDatabase(databaseFile, setup: configureAppDatabaseConnection));
      await database.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('数据库保持打开时生成可重新打开的一致性快照', () async {
      final now = DateTime.utc(2026, 8, 30);
      await database
          .into(database.audioItems)
          .insert(
            AudioItemsCompanion.insert(
              id: 'snapshot-audio',
              name: 'Snapshot Audio',
              addedDate: now,
              updatedAt: now,
              audioPath: const Value('audios/snapshot.m4a'),
            ),
          );

      final snapshot = File(p.join(tempDir.path, 'nested', 'snapshot.sqlite'));
      await database.createBackupSnapshot(snapshot);

      expect(await snapshot.exists(), isTrue);
      expect(
        await database
            .customSelect('SELECT count(*) AS c FROM audio_items')
            .get(),
        isNotEmpty,
      );
      final sqlite = sqlite3.open(snapshot.path, mode: OpenMode.readOnly);
      addTearDown(sqlite.close);
      expect(
        sqlite
            .select("SELECT name FROM audio_items WHERE id = 'snapshot-audio'")
            .single['name'],
        'Snapshot Audio',
      );
      expect(sqlite.select('PRAGMA integrity_check').single.values.first, 'ok');
    });

    test('WAL 中最新已提交数据包含在快照内', () async {
      await database.customStatement('PRAGMA journal_mode = WAL');
      await database.customStatement(
        'CREATE TABLE IF NOT EXISTS snapshot_probe(value TEXT NOT NULL)',
      );
      await database.customStatement(
        'INSERT INTO snapshot_probe(value) VALUES (?)',
        ['latest-committed'],
      );

      final snapshot = File(p.join(tempDir.path, 'wal.sqlite'));
      await database.createBackupSnapshot(snapshot);

      final sqlite = sqlite3.open(snapshot.path, mode: OpenMode.readOnly);
      addTearDown(sqlite.close);
      expect(
        sqlite.select('SELECT value FROM snapshot_probe').single['value'],
        'latest-committed',
      );
    });

    test('事务内执行失败并删除不完整目标', () async {
      final snapshot = File(p.join(tempDir.path, 'transaction.sqlite'));

      await expectLater(
        database.transaction(() => database.createBackupSnapshot(snapshot)),
        throwsA(anything),
      );

      expect(await snapshot.exists(), isFalse);
    });
  });
}

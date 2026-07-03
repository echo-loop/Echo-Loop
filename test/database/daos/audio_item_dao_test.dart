import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// 辅助：插入一条已下载、带完整文件派生元数据与字幕的音频行。
  Future<void> insertDownloaded(String id, {String? remoteAudioId}) async {
    await db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: Value('Audio $id'),
        audioPath: const Value('audios/x.m4a'),
        transcriptSrt: const Value('1\n00:00:00,000 --> 00:00:01,000\nhi\n'),
        transcriptSource: const Value(1),
        sentenceCount: const Value(3),
        wordCount: const Value(20),
        totalDuration: const Value(180),
        audioSha256: const Value('sha-x'),
        originalAudioSha256: const Value('orig-x'),
        audioContentStatus: const Value(0),
        remoteAudioId: Value(remoteAudioId),
        addedDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime(2026, 1, 1)),
      ),
    );
  }

  group('AudioItemDao.clearDownloadState', () {
    test('清空下载态与文件派生元数据，保留字幕/时长', () async {
      await insertDownloaded('a1');

      await db.audioItemDao.clearDownloadState('a1', keepAudioSha256: false);

      final row = await db.audioItemDao.getById('a1');
      // 下载态与文件派生列全部清空
      expect(row!.audioPath, isNull);
      expect(row.audioContentStatus, isNull);
      expect(row.originalAudioSha256, isNull);
      expect(row.audioSha256, isNull);
      // 字幕 / 时长 / 统计保留（字幕单独管理，时长未下载态仍需展示）
      expect(row.transcriptSrt, isNotNull);
      expect(row.transcriptSource, 1);
      expect(row.totalDuration, 180);
      expect(row.sentenceCount, 3);
      expect(row.wordCount, 20);
    });

    test('keepAudioSha256=true 时保留 audioSha256（官方重下定位标识）', () async {
      await insertDownloaded('a1', remoteAudioId: 'remote-1');

      await db.audioItemDao.clearDownloadState('a1', keepAudioSha256: true);

      final row = await db.audioItemDao.getById('a1');
      expect(row!.audioPath, isNull);
      expect(row.audioSha256, 'sha-x');
      // 其余文件派生列仍清空
      expect(row.audioContentStatus, isNull);
      expect(row.originalAudioSha256, isNull);
    });
  });
}

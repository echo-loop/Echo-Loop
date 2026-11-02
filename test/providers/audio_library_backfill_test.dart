import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/utils/app_data_dir.dart';

/// 启动全量 backfill：把旧行的 SRT 文件内容读入 transcript_srt 列。
void main() {
  late AppDatabase db;
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    tempDir = await Directory.systemTemp.createTemp('backfill_srt_test');
    appDataDirectoryOverride = tempDir;
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    appDataDirectoryOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    await db.close();
  });

  Future<void> seed(
    String id, {
    String? transcriptPath,
    String? transcriptSrt,
  }) {
    return db.audioItemDao.upsert(
      AudioItemsCompanion(
        id: Value(id),
        name: Value(id),
        transcriptPath: Value(transcriptPath),
        transcriptSrt: Value(transcriptSrt),
        addedDate: Value(DateTime(2026)),
        updatedAt: Value(DateTime(2026)),
      ),
    );
  }

  test('把存在的 SRT 文件内容回填进 transcript_srt 列', () async {
    const srt = '1\n00:00:00,000 --> 00:00:01,000\nHello\n';
    final file = File(p.join(tempDir.path, 'transcripts', 'a1.srt'));
    await file.parent.create(recursive: true);
    await file.writeAsString(srt);
    await seed('a1', transcriptPath: 'transcripts/a1.srt');

    await container.read(audioLibraryProvider.notifier).backfillTranscriptSrt();

    expect(await db.audioItemDao.getTranscriptSrt('a1'), srt);
  });

  test('文件缺失的行保持 NULL 且不抛异常', () async {
    await seed('missing', transcriptPath: 'transcripts/missing.srt');

    await container.read(audioLibraryProvider.notifier).backfillTranscriptSrt();

    expect(await db.audioItemDao.getTranscriptSrt('missing'), isNull);
  });

  test('已有 srt 或无 path 的行不被改动；重复运行为 no-op', () async {
    await seed(
      'done',
      transcriptPath: 'transcripts/x.srt',
      transcriptSrt: 'kept',
    );
    await seed('nopath');

    final notifier = container.read(audioLibraryProvider.notifier);
    await notifier.backfillTranscriptSrt();
    await notifier.backfillTranscriptSrt(); // 第二次应为 no-op

    expect(await db.audioItemDao.getTranscriptSrt('done'), 'kept');
    expect(await db.audioItemDao.getTranscriptSrt('nopath'), isNull);
  });
}

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/features/media_trim/media_trim_clip.dart';
import 'package:echo_loop/features/media_trim/media_trim_exporter.dart';
import 'package:echo_loop/features/media_trim/media_trim_processor.dart';
import 'package:echo_loop/features/media_trim/media_trim_repository.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只替换 FFmpeg 边界；事务、指纹、文件与清理都走真实实现。
class _FakeProcessor extends MediaTrimProcessor {
  _FakeProcessor({this.failAt, this.cancelAt, this.content});

  final int? failAt;
  final int? cancelAt;

  /// 按片段序号决定输出内容；默认按起点生成不同内容。
  final List<int> Function(Duration start)? content;
  int renders = 0;

  @override
  Future<MediaTrimSourceInfo> probe(String path) async =>
      const MediaTrimSourceInfo(duration: Duration(seconds: 10));

  @override
  Future<void> render({
    required String source,
    required String output,
    required Duration start,
    required Duration end,
    required bool isVideo,
    int? sourceVideoBitrate,
    required MediaTrimCancellation cancellation,
    required void Function(double fraction) onProgress,
  }) async {
    renders++;
    await File(output)
        .writeAsBytes(content?.call(start) ?? [1, 2, 3, start.inSeconds]);
    if (renders == failAt) {
      throw const MediaTrimException(MediaTrimFailure.encodeFailed);
    }
    if (renders == cancelAt) {
      await cancellation.cancel();
      cancellation.throwIfCancelled();
    }
    onProgress(1);
  }
}

void main() {
  late Directory directory;
  late db.AppDatabase database;
  late MediaTrimRepository repository;
  late AudioItem source;
  final sentences = [
    Sentence(
      index: 0,
      text: 'Hello there world',
      startTime: const Duration(milliseconds: 1200),
      endTime: const Duration(milliseconds: 1800),
    ),
  ];
  final boundaries = MediaTrimBoundaries(
    total: const Duration(seconds: 10),
    sentences: sentences,
  );
  const clips = <MediaTrimNamedClip>[
    (
      clip: MediaTrimClip(
        id: 1,
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
      ),
      name: 'First',
    ),
    (
      clip: MediaTrimClip(
        id: 2,
        start: Duration(seconds: 3),
        end: Duration(seconds: 4),
      ),
      name: 'Second',
    ),
  ];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trim-exporter-');
    appDataDirectoryOverride = directory;
    database = db.AppDatabase(
      NativeDatabase.memory(setup: db.configureAppDatabaseConnection),
    );
    repository = MediaTrimRepository(database);
    await File('${directory.path}/source.m4a').writeAsBytes([4, 5, 6]);
    source = AudioItem(
      id: 'source',
      name: 'Source',
      audioPath: 'source.m4a',
      addedDate: DateTime.now(),
      transcriptSource: TranscriptSource.ai,
      transcriptLanguage: 'en',
    );
    await database
        .into(database.audioItems)
        .insert(
          db.AudioItemsCompanion.insert(
            id: source.id,
            name: source.name,
            audioPath: Value(source.audioPath),
            addedDate: source.addedDate,
            updatedAt: source.addedDate,
          ),
        );
  });

  tearDown(() async {
    await database.close();
    appDataDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  Future<MediaTrimExportResult> export(
    MediaTrimProcessor processor, {
    MediaTrimDestination destination = const MediaTrimNewCollection('Clips'),
    MediaTrimCancellation? cancellation,
  }) => MediaTrimExporter(repository: repository, processor: processor).export(
    source: source,
    boundaries: boundaries,
    words: const [],
    clips: clips,
    destination: destination,
    cancellation: cancellation ?? MediaTrimCancellation(),
    onProgress: (_) {},
  );

  Future<void> expectNothingPublished() async {
    expect(await database.audioItemDao.getAllActive(), hasLength(1));
    expect(await database.collectionDao.getAllActive(), isEmpty);
    final root = Directory('${directory.path}/audios/trimmed');
    if (await root.exists()) expect(await root.list().toList(), isEmpty);
    expect(await File('${directory.path}/source.m4a').readAsBytes(), [4, 5, 6]);
  }

  test('整批成功：新材料独立 ID / 指纹，只含片段内字幕，加入新合集', () async {
    final result = await export(_FakeProcessor());
    expect(result.createdCount, 2);
    expect(result.reusedCount, 0);
    final ids = await database.collectionDao.getAudioIds(result.collectionId);
    expect(ids, hasLength(2));
    final first = (await database.audioItemDao.getById(ids.first))!;
    expect(first.name, 'First');
    expect(first.importSourceType, 'trimmed');
    expect(first.audioSha256, first.originalAudioSha256);
    expect(first.sentenceCount, 1);
    expect(first.wordCount, 3);
    expect(first.transcriptLanguage, 'en');
    expect(
      await database.audioItemDao.getTranscriptSrt(ids.first),
      contains('00:00:00,200 --> 00:00:00,800'),
    );
    final second = (await database.audioItemDao.getById(ids.last))!;
    expect(second.transcriptSource, isNull);
    expect(
      await File('${directory.path}/${second.audioPath}').exists(),
      isTrue,
    );
  });

  test('第二段失败：不留材料、合集或产物文件', () async {
    await expectLater(
      export(_FakeProcessor(failAt: 2)),
      throwsA(
        isA<MediaTrimException>().having(
          (e) => e.failure,
          'failure',
          MediaTrimFailure.encodeFailed,
        ),
      ),
    );
    await expectNothingPublished();
  });

  test('取消：不留残留，同一处理器可以重新保存', () async {
    final processor = _FakeProcessor(cancelAt: 2);
    await expectLater(
      export(processor),
      throwsA(
        isA<MediaTrimException>().having(
          (e) => e.failure,
          'failure',
          MediaTrimFailure.cancelled,
        ),
      ),
    );
    await expectNothingPublished();
    final result = await export(processor);
    expect(result.createdCount, 2);
  });

  test('目标合集无效时事务回滚，文件一并删除', () async {
    await expectLater(
      export(
        _FakeProcessor(),
        destination: const MediaTrimExistingCollection('missing'),
      ),
      throwsA(isA<MediaTrimException>()),
    );
    await expectNothingPublished();
  });

  test('内容与已有材料相同时复用已有材料并加入目标合集，不重复入库', () async {
    final firstResult = await export(_FakeProcessor());
    final existingIds = await database.collectionDao.getAudioIds(
      firstResult.collectionId,
    );
    final second = await export(
      _FakeProcessor(),
      destination: const MediaTrimNewCollection('Again'),
    );
    expect(second.createdCount, 0);
    expect(second.reusedCount, 2);
    expect(
      await database.collectionDao.getAudioIds(second.collectionId),
      existingIds,
    );
    expect(await database.audioItemDao.getAllActive(), hasLength(3));
    // 复用后多余的产物目录被删除，只剩第一次保存的目录。
    final tasks = await Directory('${directory.path}/audios/trimmed')
        .list()
        .toList();
    expect(tasks, hasLength(1));
  });

  test('同一批里内容相同的片段只入库一份', () async {
    final result = await export(_FakeProcessor(content: (_) => [9, 9, 9]));
    expect(result.createdCount, 1);
    expect(result.reusedCount, 1);
    expect(
      await database.collectionDao.getAudioIds(result.collectionId),
      hasLength(1),
    );
  });

  test('启动清理删除未发布目录，保留已发布（含软删）文件', () async {
    final result = await export(_FakeProcessor());
    final ids = await database.collectionDao.getAudioIds(result.collectionId);
    await database.audioItemDao.softDelete(ids.first);
    final orphan = Directory('${directory.path}/videos/trimmed/orphan');
    await orphan.create(recursive: true);
    await File('${orphan.path}/partial.mp4').writeAsBytes([0]);

    final removed = await MediaTrimExporter(
      repository: repository,
      processor: _FakeProcessor(),
    ).cleanupUncommitted();

    expect(removed, 1);
    expect(await orphan.exists(), isFalse);
    for (final id in ids) {
      final item = (await database.audioItemDao.getById(id))!;
      expect(
        await File('${directory.path}/${item.audioPath}').exists(),
        isTrue,
      );
    }
  });
}

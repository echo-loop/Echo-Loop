import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/features/community_collections/data/community_file_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/database/app_database.dart' show configureAppDatabaseConnection;

void main() {
  late db.AppDatabase database;
  late Directory dataDirectory;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
    dataDirectory = await Directory.systemTemp.createTemp('community-file-');
  });

  tearDown(() async {
    await database.close();
    if (await dataDirectory.exists()) {
      await dataDirectory.delete(recursive: true);
    }
  });

  test('没有学习记录时删除媒体、合集关联和条目', () async {
    await _seed(database, audioPath: 'audios/community/file.m4a');
    final file = File('${dataDirectory.path}/audios/community/file.m4a')
      ..createSync(recursive: true);

    final result =
        await CommunityFileLifecycleService(
          database: database,
          dataDir: () async => dataDirectory,
        ).markUnavailable(
          audioItemId: 'audio-1',
          localCollectionId: 'collection-1',
        );

    expect(result, CommunityFileRemovalResult.removed);
    expect(await database.audioItemDao.getById('audio-1'), isNull);
    expect(await file.exists(), isFalse);
  });

  test('有学习记录时保留条目和记录，但标记不可用并删除媒体', () async {
    await _seed(database, audioPath: 'audios/community/file.m4a');
    await database
        .into(database.learningProgresses)
        .insert(
          db.LearningProgressesCompanion(
            audioItemId: const Value('audio-1'),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    final file = File('${dataDirectory.path}/audios/community/file.m4a')
      ..createSync(recursive: true);

    final result =
        await CommunityFileLifecycleService(
          database: database,
          dataDir: () async => dataDirectory,
        ).markUnavailable(
          audioItemId: 'audio-1',
          localCollectionId: 'collection-1',
        );

    final row = await database.audioItemDao.getById('audio-1');
    expect(result, CommunityFileRemovalResult.markedUnavailable);
    expect(row?.audioPath, isNull);
    expect(row?.communityUnavailableAt, isNotNull);
    expect(
      await database.learningProgressDao.getByAudioId('audio-1'),
      isNotNull,
    );
    expect(await file.exists(), isFalse);
  });

  test('同一媒体被其它合集引用时移除当前关联但保留媒体', () async {
    await _seed(database, audioPath: 'audios/community/file.m4a');
    await database.collectionDao.upsert(
      db.CollectionsCompanion(
        id: const Value('collection-2'),
        name: const Value('Another Community'),
        createdDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime(2026, 1, 1)),
        source: const Value('community'),
        remoteId: const Value('remote-2'),
      ),
    );
    await database
        .into(database.collectionAudioItems)
        .insert(
          db.CollectionAudioItemsCompanion(
            collectionId: const Value('collection-2'),
            audioItemId: const Value('audio-1'),
            addedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    final file = File('${dataDirectory.path}/audios/community/file.m4a')
      ..createSync(recursive: true);

    final result =
        await CommunityFileLifecycleService(
          database: database,
          dataDir: () async => dataDirectory,
        ).markUnavailable(
          audioItemId: 'audio-1',
          localCollectionId: 'collection-1',
        );

    expect(result, CommunityFileRemovalResult.unchanged);
    expect(await database.audioItemDao.getById('audio-1'), isNotNull);
    expect(
      await (database.select(
        database.collectionAudioItems,
      )..where((row) => row.collectionId.equals('collection-1'))).get(),
      isEmpty,
    );
    expect(
      await (database.select(
        database.collectionAudioItems,
      )..where((row) => row.collectionId.equals('collection-2'))).get(),
      hasLength(1),
    );
    expect(await file.exists(), isTrue);
  });

  test('共享媒体即使有学习记录也只从已下架的合集中解除关联', () async {
    await _seed(database, audioPath: 'audios/community/file.m4a');
    await database.collectionDao.upsert(
      db.CollectionsCompanion(
        id: const Value('collection-2'),
        name: const Value('Another Community'),
        createdDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime(2026, 1, 1)),
        source: const Value('community'),
        remoteId: const Value('remote-2'),
      ),
    );
    await database
        .into(database.collectionAudioItems)
        .insert(
          db.CollectionAudioItemsCompanion(
            collectionId: const Value('collection-2'),
            audioItemId: const Value('audio-1'),
            addedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await database
        .into(database.learningProgresses)
        .insert(
          db.LearningProgressesCompanion(
            audioItemId: const Value('audio-1'),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    final file = File('${dataDirectory.path}/audios/community/file.m4a')
      ..createSync(recursive: true);

    final result =
        await CommunityFileLifecycleService(
          database: database,
          dataDir: () async => dataDirectory,
        ).markUnavailable(
          audioItemId: 'audio-1',
          localCollectionId: 'collection-1',
        );

    final row = await database.audioItemDao.getById('audio-1');
    expect(result, CommunityFileRemovalResult.unchanged);
    expect(row?.audioPath, 'audios/community/file.m4a');
    expect(row?.communityUnavailableAt, isNull);
    expect(
      await database.learningProgressDao.getByAudioId('audio-1'),
      isNotNull,
    );
    expect(
      await (database.select(database.collectionAudioItems)
            ..where((junction) => junction.collectionId.equals('collection-1')))
          .get(),
      isEmpty,
    );
    expect(await file.exists(), isTrue);
  });
}

Future<void> _seed(db.AppDatabase database, {required String audioPath}) async {
  await database.collectionDao.upsert(
    db.CollectionsCompanion(
      id: const Value('collection-1'),
      name: const Value('Community'),
      createdDate: Value(DateTime(2026, 1, 1)),
      updatedAt: Value(DateTime(2026, 1, 1)),
      source: const Value('community'),
      remoteId: const Value('remote-1'),
    ),
  );
  await database.audioItemDao.upsert(
    db.AudioItemsCompanion(
      id: const Value('audio-1'),
      name: const Value('File'),
      addedDate: Value(DateTime(2026, 1, 1)),
      updatedAt: Value(DateTime(2026, 1, 1)),
      audioPath: Value(audioPath),
      remoteAudioId: const Value('file-1'),
    ),
  );
  await database
      .into(database.collectionAudioItems)
      .insert(
        db.CollectionAudioItemsCompanion(
          collectionId: const Value('collection-1'),
          audioItemId: const Value('audio-1'),
          addedAt: Value(DateTime(2026, 1, 1)),
        ),
      );
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/features/community_collections/data/community_collection_api.dart';
import 'package:echo_loop/features/community_collections/data/community_collection_repository.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCommunityApi extends CommunityCollectionApi {
  _FakeCommunityApi() : super.withDio(Dio());

  @override
  Future<PublicCollectionPage> getCollections({
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return PublicCollectionPage(
      items: [
        PublicCollectionCatalogEntry(
          id: 'remote-1',
          name: 'Community English',
          description: 'A community collection.',
          coverUrl: null,
          coverUrlChina: 'https://cn.example/cover.jpg',
          authorNickname: 'Echo Studio',
          fileCount: 0,
          publishedAt: DateTime(2026, 9, 22),
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<CommunityCollectionDetailPage> getCollectionDetail(
    String collectionId, {
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    return CommunityCollectionDetailPage(
      collection: PublicCollectionCatalogEntry(
        id: 'remote-1',
        name: 'Community English',
        description: 'A community collection.',
        coverUrl: 'https://global.example/cover.jpg',
        coverUrlChina: 'https://cn.example/cover.jpg',
        authorNickname: 'Echo Studio',
        fileCount: 1,
        publishedAt: DateTime(2026, 9, 22),
        updatedAt: DateTime(2026, 9, 23),
      ),
      items: [
        CommunityCollectionFile(
          id: 'file-1',
          title: 'Episode 1',
          description: null,
          mediaType: CommunityMediaType.audio,
          durationSec: 45,
          fileSizeBytes: null,
          difficulty: CommunityDifficulty.b1,
          publishedAt: DateTime(2026, 9, 21),
          sortOrder: 3,
          mediaUrl: 'https://example.com/episode-1.m4a',
        ),
      ],
      nextCursor: null,
    );
  }
}

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'enrolling a community collection stores the author nickname locally',
    () async {
      final repository = CommunityCollectionRepository(
        database: database,
        api: _FakeCommunityApi(),
      );

      final localId = await repository.enroll('remote-1');
      final collection = await database.collectionDao.getById(localId);
      final audioId = (await database.collectionDao.getAudioIds(
        localId,
      )).single;
      final audio = await database.audioItemDao.getById(audioId);
      final junction = await (database.select(
        database.collectionAudioItems,
      )..where((row) => row.audioItemId.equals(audioId))).getSingle();

      expect(collection?.authorNickname, 'Echo Studio');
      expect(collection?.description, 'A community collection.');
      expect(collection?.coverUrl, 'https://global.example/cover.jpg');
      expect(collection?.coverUrlChina, 'https://cn.example/cover.jpg');
      expect(collection?.publishedAt, DateTime(2026, 9, 22));
      expect(collection?.updatedAt, DateTime(2026, 9, 23));
      expect(audio?.name, 'Episode 1');
      expect(audio?.totalDuration, 45);
      expect(audio?.originalDate, DateTime(2026, 9, 21));
      expect(audio?.communityDifficulty, 'B1');
      expect(junction.sortOrder, 3);
    },
  );

  test(
    'enrolling reuses a remote audio item already in another collection',
    () async {
      final now = DateTime(2026, 9, 24);
      await database.collectionDao.upsert(
        db.CollectionsCompanion.insert(
          id: 'existing-collection',
          name: 'Existing community collection',
          createdDate: now,
          updatedAt: now,
          source: const Value('community'),
          remoteId: const Value('remote-existing'),
        ),
      );
      await database.audioItemDao.upsert(
        db.AudioItemsCompanion.insert(
          id: 'existing-audio',
          name: 'Episode 1',
          addedDate: now,
          updatedAt: now,
          remoteAudioId: const Value('file-1'),
        ),
      );
      await database.collectionDao.addAudio(
        'existing-collection',
        'existing-audio',
      );

      final repository = CommunityCollectionRepository(
        database: database,
        api: _FakeCommunityApi(),
      );

      final localId = await repository.enroll('remote-1');
      final audioIds = await database.collectionDao.getAudioIds(localId);

      expect(audioIds, ['existing-audio']);
      expect(
        await database.audioItemDao.getByRemoteAudioId('file-1'),
        isNotNull,
      );
      expect(
        (await database.audioItemDao.getByRemoteAudioId(
          'file-1',
        ))?.communityDifficulty,
        'B1',
      );
    },
  );

  test('移除一个合集会保留其它合集共享的音频和学习记录', () async {
    final now = DateTime(2026, 9, 24);
    await database.collectionDao.upsert(
      db.CollectionsCompanion.insert(
        id: 'existing-collection',
        name: 'Existing community collection',
        createdDate: now,
        updatedAt: now,
        source: const Value('community'),
        remoteId: const Value('remote-existing'),
      ),
    );
    await database.audioItemDao.upsert(
      db.AudioItemsCompanion.insert(
        id: 'existing-audio',
        name: 'Episode 1',
        addedDate: now,
        updatedAt: now,
        remoteAudioId: const Value('file-1'),
      ),
    );
    await database.collectionDao.addAudio(
      'existing-collection',
      'existing-audio',
    );
    await database
        .into(database.learningProgresses)
        .insert(
          db.LearningProgressesCompanion(
            audioItemId: const Value('existing-audio'),
            updatedAt: Value(now),
          ),
        );
    final repository = CommunityCollectionRepository(
      database: database,
      api: _FakeCommunityApi(),
      docsDir: () async => Directory.systemTemp,
    );
    final secondCollectionId = await repository.enroll('remote-1');

    await repository.remove(secondCollectionId);

    expect(await database.audioItemDao.getById('existing-audio'), isNotNull);
    expect(await database.collectionDao.getAudioIds('existing-collection'), [
      'existing-audio',
    ]);
    expect(
      await database.learningProgressDao.getByAudioId('existing-audio'),
      isNotNull,
    );
  });

  test('移除最后一个合集时清理不再共享的音频行', () async {
    final repository = CommunityCollectionRepository(
      database: database,
      api: _FakeCommunityApi(),
      docsDir: () async => Directory.systemTemp,
    );
    final localId = await repository.enroll('remote-1');
    final audioId = (await database.collectionDao.getAudioIds(localId)).single;

    await repository.remove(localId);

    expect(await database.collectionDao.getById(localId), isNull);
    expect(await database.audioItemDao.getById(audioId), isNull);
  });
}

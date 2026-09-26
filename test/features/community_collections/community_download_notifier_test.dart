import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echo_loop/database/app_database.dart' as db;
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/features/community_collections/data/community_collection_api.dart';
import 'package:echo_loop/features/community_collections/data/community_file_lifecycle.dart';
import 'package:echo_loop/features/community_collections/download/community_download_notifier.dart';
import 'package:echo_loop/features/community_collections/download/download_progress.dart';
import 'package:echo_loop/features/community_collections/models/community_collection_models.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/download_provider.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

class _MissingFileApi extends CommunityCollectionApi {
  _MissingFileApi() : super.withDio(Dio());

  @override
  Future<CommunityCollectionFileDetail> getFileDetail(
    String collectionId,
    String fileId, {
    CancelToken? cancelToken,
  }) async {
    throw CommunityFileNotFound(fileId);
  }
}

class _AvailableFileApi extends CommunityCollectionApi {
  _AvailableFileApi() : super.withDio(Dio());

  @override
  Future<CommunityCollectionFileDetail> getFileDetail(
    String collectionId,
    String fileId, {
    CancelToken? cancelToken,
  }) async {
    return const CommunityCollectionFileDetail(
      file: CommunityCollectionFile(
        id: 'file-1',
        title: 'Episode',
        description: null,
        mediaType: CommunityMediaType.audio,
        durationSec: 12,
        fileSizeBytes: 999,
        difficulty: null,
        publishedAt: null,
        sortOrder: 0,
        mediaUrl: 'https://example.invalid/episode.mp3',
      ),
      subtitle: CommunitySubtitle(
        sentences: [
          CommunitySubtitleSentence(
            text: 'Hello world',
            startTime: Duration.zero,
            endTime: Duration(seconds: 2),
          ),
        ],
        words: [],
      ),
    );
  }
}

class _FakeBackgroundDownloadRunner implements BackgroundDownloadRunner {
  String? enqueuedDisplayName;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    enqueuedDisplayName = displayName;
    await File(savePath).parent.create(recursive: true);
    await File(savePath).writeAsBytes(const <int>[1, 2, 3]);
    onProgress?.call(3, null);
    return const BackgroundDownloadResult(
      status: BackgroundDownloadStatus.complete,
    );
  }
}

void main() {
  test('远端文件消失时下载不会永久停留在进行中', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final dataDirectory = await Directory.systemTemp.createTemp(
      'community-download-',
    );
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
        name: const Value('Missing file'),
        addedDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime(2026, 1, 1)),
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

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        communityCollectionApiProvider.overrideWithValue(_MissingFileApi()),
        communityFileLifecycleServiceProvider.overrideWithValue(
          CommunityFileLifecycleService(
            database: database,
            dataDir: () async => dataDirectory,
          ),
        ),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
      if (await dataDirectory.exists()) {
        await dataDirectory.delete(recursive: true);
      }
    });

    final notifier = container.read(communityDownloadProvider.notifier);
    expect(
      await notifier.start(audioItemId: 'audio-1', displayName: 'Missing file'),
      StartResult.started,
    );
    expect(await notifier.awaitCompletion(), isFalse);
    expect(container.read(communityDownloadProvider), isA<DownloadFailed>());
    expect(
      container.read(communityDownloadProvider),
      isNot(isA<DownloadInProgress>()),
    );
  });

  test('社区文件大小元数据不准确时仍按后台任务完成状态入库', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final dataDirectory = await Directory.systemTemp.createTemp(
      'community-download-success-',
    );
    appDataDirectoryOverride = dataDirectory;
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
        name: const Value('Episode'),
        addedDate: Value(DateTime(2026, 1, 1)),
        updatedAt: Value(DateTime(2026, 1, 1)),
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

    final runner = _FakeBackgroundDownloadRunner();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        communityCollectionApiProvider.overrideWithValue(_AvailableFileApi()),
        backgroundFileDownloadServiceProvider.overrideWithValue(
          BackgroundFileDownloadService(runner: runner),
        ),
        communityFileLifecycleServiceProvider.overrideWithValue(
          CommunityFileLifecycleService(
            database: database,
            dataDir: () async => dataDirectory,
          ),
        ),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
      appDataDirectoryOverride = null;
      if (await dataDirectory.exists()) {
        await dataDirectory.delete(recursive: true);
      }
    });

    final notifier = container.read(communityDownloadProvider.notifier);
    expect(
      await notifier.start(audioItemId: 'audio-1', displayName: 'Episode'),
      StartResult.started,
    );
    expect(await notifier.awaitCompletion(), isTrue);
    expect(runner.enqueuedDisplayName, 'Episode');
    final item = await database.audioItemDao.getById('audio-1');
    expect(item?.name, 'Episode');
    expect(item?.totalDuration, 12);
    expect(item?.audioPath, 'audios/community/audio-1.mp3');
    expect(await File('${dataDirectory.path}/${item?.audioPath}').length(), 3);
  });
}

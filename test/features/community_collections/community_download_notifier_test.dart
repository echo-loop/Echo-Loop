import 'dart:async';
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
import 'package:echo_loop/features/user_region/user_region_providers.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/download_provider.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/services/resource_download_registry.dart';
import 'package:echo_loop/utils/app_data_dir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'package:echo_loop/database/app_database.dart' show configureAppDatabaseConnection;

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
        mediaUrlChina: 'https://cn.example/episode.mp3',
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
  Uri? enqueuedUri;

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
    enqueuedUri = uri;
    await File(savePath).parent.create(recursive: true);
    await File(savePath).writeAsBytes(const <int>[1, 2, 3]);
    onProgress?.call(3, null);
    return const BackgroundDownloadResult(
      status: BackgroundDownloadStatus.complete,
    );
  }
}

/// 等待某条目的下载结束（状态不再是 [DownloadInProgress]），返回最终状态；成功后条目无状态，返回 null。
Future<DownloadProgress?> waitUntilSettled(
  ProviderContainer container,
  String audioItemId,
) {
  final settled = Completer<DownloadProgress?>();
  final subscription = container.listen(communityDownloadProvider, (_, next) {
    final progress = next[audioItemId];
    if (progress is! DownloadInProgress && !settled.isCompleted) {
      settled.complete(progress);
    }
  });
  return settled.future.whenComplete(subscription.close);
}

/// 记录每次提交并保持挂起，由测试决定何时完成，用于验证并发。
class _HoldingBackgroundDownloadRunner implements BackgroundDownloadRunner {
  final List<String> savePaths = [];
  final List<Completer<BackgroundDownloadResult>> pending = [];

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) {
    savePaths.add(savePath);
    final completer = Completer<BackgroundDownloadResult>();
    pending.add(completer);
    return completer.future;
  }

  /// 写入目标文件后以完成结束，与真实下载的成功顺序一致。
  Future<void> complete(int index) async {
    await File(savePaths[index]).parent.create(recursive: true);
    await File(savePaths[index]).writeAsBytes(const <int>[1, 2, 3]);
    pending[index].complete(
      const BackgroundDownloadResult(status: BackgroundDownloadStatus.complete),
    );
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('远端文件消失时下载不会永久停留在进行中', () async {
    final database = db.AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
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
      overrides: dedupeOverrides([
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
      ]),
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
    expect(await waitUntilSettled(container, 'audio-1'), isA<DownloadFailed>());
    expect(
      container.read(communityDownloadProvider)['audio-1'],
      isA<DownloadFailed>(),
    );
  });

  test('文件大小元数据不准仍完成下载，且详情排序不覆盖合集排序', () async {
    final database = db.AppDatabase(NativeDatabase.memory(setup: configureAppDatabaseConnection));
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
            sortOrder: const Value(220),
          ),
        );

    final runner = _FakeBackgroundDownloadRunner();
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        communityCollectionApiProvider.overrideWithValue(_AvailableFileApi()),
        isChinaUserProvider.overrideWithValue(true),
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
      ]),
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
    expect(await waitUntilSettled(container, 'audio-1'), isNull);
    expect(runner.enqueuedDisplayName, 'Episode');
    expect(runner.enqueuedUri, Uri.parse('https://cn.example/episode.mp3'));
    final item = await database.audioItemDao.getById('audio-1');
    expect(item?.name, 'Episode');
    expect(item?.totalDuration, 12);
    expect(item?.audioPath, 'audios/community/audio-1.mp3');
    expect(await File('${dataDirectory.path}/${item?.audioPath}').length(), 3);
    final collectionAudioItem = await (database.select(
      database.collectionAudioItems,
    )..where((row) => row.collectionId.equals('collection-1'))).getSingle();
    expect(collectionAudioItem.sortOrder, 220);
  });

  test('不同条目可以同时下载，同一条目重复请求不会建第二个任务', () async {
    final database = db.AppDatabase(
      NativeDatabase.memory(setup: configureAppDatabaseConnection),
    );
    final dataDirectory = await Directory.systemTemp.createTemp(
      'community-concurrent-',
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
    for (final id in ['audio-1', 'audio-2']) {
      await database.audioItemDao.upsert(
        db.AudioItemsCompanion(
          id: Value(id),
          name: Value(id),
          addedDate: Value(DateTime(2026, 1, 1)),
          updatedAt: Value(DateTime(2026, 1, 1)),
          remoteAudioId: Value('file-$id'),
        ),
      );
      await database
          .into(database.collectionAudioItems)
          .insert(
            db.CollectionAudioItemsCompanion(
              collectionId: const Value('collection-1'),
              audioItemId: Value(id),
              addedAt: Value(DateTime(2026, 1, 1)),
              sortOrder: Value(id == 'audio-1' ? 1 : 2),
            ),
          );
    }

    final runner = _HoldingBackgroundDownloadRunner();
    final container = ProviderContainer(
      overrides: dedupeOverrides([
        appDatabaseProvider.overrideWithValue(database),
        communityCollectionApiProvider.overrideWithValue(_AvailableFileApi()),
        isChinaUserProvider.overrideWithValue(true),
        backgroundFileDownloadServiceProvider.overrideWithValue(
          BackgroundFileDownloadService(
            runner: runner,
            registry: ResourceDownloadRegistry(),
          ),
        ),
        communityFileLifecycleServiceProvider.overrideWithValue(
          CommunityFileLifecycleService(
            database: database,
            dataDir: () async => dataDirectory,
          ),
        ),
        audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
        collectionListProvider.overrideWith(() => TestCollectionList()),
      ]),
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
      appDataDirectoryOverride = null;
      await dataDirectory.delete(recursive: true);
    });

    final notifier = container.read(communityDownloadProvider.notifier);
    expect(
      await notifier.start(audioItemId: 'audio-1', displayName: 'Episode 1'),
      StartResult.started,
    );
    expect(
      await notifier.start(audioItemId: 'audio-2', displayName: 'Episode 2'),
      StartResult.started,
    );
    expect(
      await notifier.start(audioItemId: 'audio-1', displayName: 'Episode 1'),
      StartResult.alreadyRunning,
    );

    await _until(() => runner.pending.length == 2);
    expect(runner.pending, hasLength(2));
    expect(
      container.read(communityDownloadProvider).keys,
      unorderedEquals(['audio-1', 'audio-2']),
    );

    // 先订阅结束事件，再完成下载，避免错过结束时的状态变化。
    final first = waitUntilSettled(container, 'audio-1');
    final second = waitUntilSettled(container, 'audio-2');
    await runner.complete(0);
    await runner.complete(1);
    expect(await first, isNull);
    expect(await second, isNull);
  });
}

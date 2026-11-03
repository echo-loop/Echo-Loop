import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/audio_import/audio_finalization_service.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_registration_service.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_credential_repository.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_import_service.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_credential_bundle.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session_status.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_account_profile.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../../helpers/mock_providers.dart';

class _FakeCredentialRepository implements BaiduCredentialRepository {
  _FakeCredentialRepository(this.accessToken);

  String? accessToken;

  @override
  Future<void> clearCredential() async {
    accessToken = null;
  }

  @override
  Future<void> consumeForceLoginOnce() async {}

  @override
  Future<void> disconnect() async {
    accessToken = null;
  }

  @override
  Future<BaiduOAuthSession> createSession(BaiduNetdiskPlatform platform) {
    throw UnimplementedError();
  }

  @override
  Future<BaiduOAuthSessionStatus> fetchStatus(BaiduOAuthSession session) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getValidAccessToken() async => accessToken;

  @override
  Future<void> persistCompletedSession({
    required BaiduOAuthSession session,
    required BaiduCredentialBundle credential,
  }) async {}
}

class _FakeBaiduNetdiskApi implements BaiduNetdiskApi {
  @override
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  }) async => const BaiduAccountProfile(uk: 1);

  int fetchDownloadLinkCalls = 0;
  int downloadCalls = 0;
  int downloadBatchCalls = 0;
  final submittedBatchIds = <List<String>>[];
  final submittedBatchDisplayNames = <List<String>>[];
  final fetchLinkCountsAtSubmission = <int>[];
  String? lastAccessToken;
  String? lastSavePath;
  final downloadedDlinks = <String>[];
  List<int> bytes = const [1, 2, 3];
  Map<int, List<int>> bytesByFsId = const <int, List<int>>{};
  Map<int, Object> downloadErrorsByFsId = const <int, Object>{};
  bool cancelBatchAfterFirstDownload = false;

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    String? resourceKey,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    downloadCalls += 1;
    lastAccessToken = accessToken;
    lastSavePath = savePath;
    downloadedDlinks.add(dlink);
    final fsId = int.tryParse(Uri.parse(dlink).pathSegments.last);
    final error = fsId == null ? null : downloadErrorsByFsId[fsId];
    if (error != null) {
      downloadErrorsByFsId = {...downloadErrorsByFsId}..remove(fsId);
      throw error;
    }
    final content = fsId == null ? bytes : bytesByFsId[fsId] ?? bytes;
    onProgress?.call(content.length, null);
    await File(savePath).writeAsBytes(content);
  }

  @override
  Future<List<BaiduNetdiskDownloadItemResult>> downloadFiles({
    required String accessToken,
    required List<BaiduNetdiskDownloadRequest> requests,
    CancelToken? cancelToken,
    void Function(String taskId, int receivedBytes, int? totalBytes)?
    onProgress,
  }) async {
    downloadBatchCalls++;
    submittedBatchIds.add(requests.map((request) => request.id).toList());
    submittedBatchDisplayNames.add(
      requests.map((request) => request.displayName).toList(),
    );
    fetchLinkCountsAtSubmission.add(fetchDownloadLinkCalls);
    final results = <BaiduNetdiskDownloadItemResult>[];
    for (final request in requests) {
      if (cancelToken?.isCancelled ?? false) {
        results.add(
          BaiduNetdiskDownloadItemResult(
            request: request,
            failure: const BaiduNetdiskFileException(
              kind: BaiduNetdiskFileErrorKind.canceled,
              message: 'Download canceled.',
            ),
          ),
        );
        continue;
      }
      await File(request.savePath).parent.create(recursive: true);
      try {
        await downloadToFile(
          accessToken: accessToken,
          dlink: request.dlink,
          savePath: request.savePath,
          cancelToken: cancelToken,
          onProgress: (received, total) =>
              onProgress?.call(request.id, received, total),
        );
        results.add(BaiduNetdiskDownloadItemResult(request: request));
        if (cancelBatchAfterFirstDownload) {
          cancelBatchAfterFirstDownload = false;
          cancelToken?.cancel('test-cancel-after-first-download');
        }
      } on BaiduNetdiskFileException catch (error) {
        results.add(
          BaiduNetdiskDownloadItemResult(request: request, failure: error),
        );
      } on Object catch (error) {
        results.add(
          BaiduNetdiskDownloadItemResult(
            request: request,
            failure: BaiduNetdiskFileException(
              kind: BaiduNetdiskFileErrorKind.unknown,
              message: error.toString(),
              cause: error,
            ),
          ),
        );
      }
    }
    return results;
  }

  @override
  Future<BaiduDownloadLink> fetchDownloadLink({
    required String accessToken,
    required int fsId,
  }) async {
    fetchDownloadLinkCalls += 1;
    lastAccessToken = accessToken;
    return BaiduDownloadLink(
      fsId: fsId,
      dlink: 'https://d.pcs.baidu.com/file/$fsId?v=$fetchDownloadLinkCalls',
      size: 4,
    );
  }

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  }) {
    throw UnimplementedError();
  }
}

class _FakeAudioLibrary extends AudioLibrary {
  _FakeAudioLibrary([this.initialState = const AudioLibraryState()]);

  final AudioLibraryState initialState;

  @override
  AudioLibraryState build() => initialState;

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }
}

void main() {
  group('DefaultBaiduNetdiskImportService', () {
    late Directory tempDir;
    late _FakeCredentialRepository credentialRepository;
    late _FakeBaiduNetdiskApi api;
    late DefaultBaiduNetdiskImportService service;

    const entry = CloudDriveEntry(
      fsId: 42,
      name: 'Lesson 1.mp3',
      path: '/英语/Lesson 1.mp3',
      isDirectory: false,
      size: 4,
    );
    const subtitleEntry = CloudDriveEntry(
      fsId: 43,
      name: 'Lesson 1.srt',
      path: '/英语/Lesson 1.srt',
      isDirectory: false,
      size: 45,
    );
    const videoEntry = CloudDriveEntry(
      fsId: 44,
      name: 'Lesson Video.mp4',
      path: '/英语/Lesson Video.mp4',
      isDirectory: false,
      size: 4,
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('baidu-import-test-');
      credentialRepository = _FakeCredentialRepository('access-token');
      api = _FakeBaiduNetdiskApi();
      service = DefaultBaiduNetdiskImportService(
        credentialRepository: credentialRepository,
        api: api,
        resolveDataDir: () async => tempDir,
        finalizationService: AudioFinalizationService(
          computeSha256: (_) async => 'sha256',
        ),
        registrationService: AudioRegistrationService(
          readDurationSeconds: (_) async => 12,
        ),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('远端大小元数据不准确时仍完成下载并按 cloudDrive 来源入库', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final progresses = <int>[];

      final item = await service.importAudio(
        entry: entry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        onProgress: (_, received, _) => progresses.add(received),
      );

      expect(api.fetchDownloadLinkCalls, 1);
      expect(api.downloadCalls, 1);
      expect(api.lastAccessToken, 'access-token');
      expect(p.basename(api.lastSavePath!), '42.mp3');
      expect(item.name, 'Lesson 1');
      expect(item.totalDuration, 12);
      expect(item.importSourceType, AudioImportSourceType.cloudDrive);
      expect(item.importSourceUrl, contains('baidunetdisk://fs/42'));
      expect(item.audioPath, 'audios/imported/sha256.mp3');
      expect(File('${tempDir.path}/${item.audioPath}').existsSync(), isTrue);
      expect(progresses, [3]);
    });

    test('视频文件从百度网盘导入后落 videos 目录并派生为视频素材', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      final item = await service.importAudio(
        entry: videoEntry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      expect(api.fetchDownloadLinkCalls, 1);
      expect(api.downloadCalls, 1);
      expect(item.name, 'Lesson Video');
      expect(item.audioPath, 'videos/sha256.mp4');
      expect(item.isVideo, isTrue);
      expect(File('${tempDir.path}/${item.audioPath}').existsSync(), isTrue);
    });

    test('dlink 下载失败时刷新一次链接后继续下载', () async {
      api.downloadErrorsByFsId = {
        entry.fsId: const BaiduNetdiskFileException(
          kind: BaiduNetdiskFileErrorKind.notFound,
          message: 'expired dlink',
        ),
      };
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      final item = await service.importAudio(
        entry: entry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      expect(api.fetchDownloadLinkCalls, 2);
      expect(api.downloadCalls, 2);
      expect(api.downloadedDlinks, [
        'https://d.pcs.baidu.com/file/42?v=1',
        'https://d.pcs.baidu.com/file/42?v=2',
      ]);
      expect(item.name, 'Lesson 1');
    });

    test('未授权时要求重新授权且不下载', () async {
      credentialRepository.accessToken = null;
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      expect(
        service.importAudio(
          entry: entry,
          audioLibrary: container.read(audioLibraryProvider.notifier),
          audioLibraryState: container.read(audioLibraryProvider),
        ),
        throwsA(isA<BaiduReauthorizationRequiredException>()),
      );
      expect(api.fetchDownloadLinkCalls, 0);
      expect(api.downloadCalls, 0);
    });

    test('目录和不支持格式在导入前被拒绝', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      await expectLater(
        service.importAudio(
          entry: const CloudDriveEntry(
            fsId: 1,
            name: 'Folder',
            path: '/Folder',
            isDirectory: true,
            size: 0,
          ),
          audioLibrary: container.read(audioLibraryProvider.notifier),
          audioLibraryState: container.read(audioLibraryProvider),
        ),
        throwsA(
          isA<AudioImportException>().having(
            (error) => error.code,
            'code',
            AudioImportFailureCode.unsupportedFormat,
          ),
        ),
      );

      await expectLater(
        service.importAudio(
          entry: const CloudDriveEntry(
            fsId: 2,
            name: 'notes.txt',
            path: '/notes.txt',
            isDirectory: false,
            size: 5,
          ),
          audioLibrary: container.read(audioLibraryProvider.notifier),
          audioLibraryState: container.read(audioLibraryProvider),
        ),
        throwsA(
          isA<AudioImportException>().having(
            (error) => error.code,
            'code',
            AudioImportFailureCode.unsupportedFormat,
          ),
        ),
      );
      expect(api.fetchDownloadLinkCalls, 0);
    });

    test('批量导入区分新增和重复', () async {
      final existing = AudioItem(
        id: 'existing',
        name: 'Existing',
        audioPath: 'audios/imported/sha256.mp3',
        addedDate: DateTime(2026, 1, 1),
        originalAudioSha256: 'sha256',
        audioSha256: 'sha256',
      );
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
        ]),
      );
      addTearDown(container.dispose);
      final itemResults = <CloudDriveImportItemResult>[];

      final outcome = await service.importAudios(
        entries: [entry],
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        onItemResult: itemResults.add,
      );

      expect(outcome.added, isEmpty);
      expect(outcome.duplicateEntries, [entry]);
      expect(outcome.failures, isEmpty);
      expect(itemResults.single.status, CloudDriveImportItemStatus.duplicate);
      expect(itemResults.single.entry, entry);
      expect(itemResults.single.duplicateExistingName, 'Existing');
      expect(File(api.lastSavePath!).existsSync(), isFalse);
    });

    test('批量导入单条普通异常转为失败并继续后续素材', () async {
      const failedEntry = entry;
      const nextEntry = CloudDriveEntry(
        fsId: 45,
        name: 'Lesson 2.mp3',
        path: '/英语/Lesson 2.mp3',
        isDirectory: false,
        size: 4,
      );
      api.downloadErrorsByFsId = {failedEntry.fsId: StateError('TLS failed')};
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final itemResults = <CloudDriveImportItemResult>[];

      final outcome = await service.importAudios(
        entries: [failedEntry, nextEntry],
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        onItemResult: itemResults.add,
      );

      expect(outcome.failures.single.entry, failedEntry);
      expect(outcome.failures.single.message, contains('TLS failed'));
      expect(outcome.added, [nextEntry]);
      expect(outcome.addedItems.single.name, 'Lesson 2');
      expect(itemResults.map((result) => result.status), [
        CloudDriveImportItemStatus.failed,
        CloudDriveImportItemStatus.added,
      ]);
      expect(api.downloadBatchCalls, 1);
      expect(api.fetchLinkCountsAtSubmission, [2]);
      expect(api.submittedBatchIds.single, ['audio-42', 'audio-45']);
    });

    test('批量下载中途取消仍入库已完成的音频并清理未完成文件', () async {
      const nextEntry = CloudDriveEntry(
        fsId: 45,
        name: 'Lesson 2.mp3',
        path: '/英语/Lesson 2.mp3',
        isDirectory: false,
        size: 4,
      );
      api.cancelBatchAfterFirstDownload = true;
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final cancelToken = CancelToken();

      final outcome = await service.importAudios(
        entries: [entry, nextEntry],
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        cancelToken: cancelToken,
      );

      expect(outcome.wasCanceled, isTrue);
      expect(outcome.added, [entry]);
      expect(outcome.addedItems.single.name, 'Lesson 1');
      expect(outcome.failures, isEmpty);
      expect(
        File('${tempDir.path}/audios/imported/sha256.mp3').existsSync(),
        isTrue,
      );
      expect(
        File('${tempDir.path}/tmp/baidu_netdisk/45.mp3').existsSync(),
        isFalse,
      );
    });

    test('批量导入时下载并挂载同名字幕', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      api.bytesByFsId = {
        entry.fsId: const [1, 2, 3, 4],
        subtitleEntry.fsId:
            '1\n00:00:00,000 --> 00:00:01,000\nHello\n'.codeUnits,
      };
      final attached = <String, String>{};
      final itemResults = <CloudDriveImportItemResult>[];
      service = DefaultBaiduNetdiskImportService(
        credentialRepository: credentialRepository,
        api: api,
        resolveDataDir: () async => tempDir,
        finalizationService: AudioFinalizationService(
          computeSha256: (_) async => 'sha256',
        ),
        registrationService: AudioRegistrationService(
          readDurationSeconds: (_) async => 12,
        ),
        subtitleImporter: (item, {required text, required ext}) async {
          attached[item.name] = '$ext:$text';
        },
      );

      final outcome = await service.importAudios(
        entries: [entry],
        subtitleEntries: [subtitleEntry],
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
        onItemResult: itemResults.add,
      );

      expect(outcome.added, [entry]);
      expect(outcome.addedItems.single.name, 'Lesson 1');
      expect(itemResults.single.status, CloudDriveImportItemStatus.added);
      expect(itemResults.single.item?.transcriptSource, TranscriptSource.local);
      expect(api.downloadCalls, 2);
      expect(api.downloadBatchCalls, 1);
      expect(api.submittedBatchIds.single, ['audio-42', 'subtitle-43']);
      expect(api.submittedBatchDisplayNames.single, [
        entry.name,
        subtitleEntry.name,
      ]);
      expect(attached['Lesson 1'], contains('srt:1'));
    });

    test('字幕下载单独取消时仍导入已下载音频并标记取消', () async {
      api.downloadErrorsByFsId = {
        subtitleEntry.fsId: const BaiduNetdiskFileException(
          kind: BaiduNetdiskFileErrorKind.canceled,
          message: 'Subtitle download canceled.',
        ),
      };
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      service = DefaultBaiduNetdiskImportService(
        credentialRepository: credentialRepository,
        api: api,
        resolveDataDir: () async => tempDir,
        finalizationService: AudioFinalizationService(
          computeSha256: (_) async => 'sha256',
        ),
        registrationService: AudioRegistrationService(
          readDurationSeconds: (_) async => 12,
        ),
        subtitleImporter: (_, {required text, required ext}) async {},
      );

      final outcome = await service.importAudios(
        entries: [entry],
        subtitleEntries: [subtitleEntry],
        audioLibrary: container.read(audioLibraryProvider.notifier),
        audioLibraryState: container.read(audioLibraryProvider),
      );

      expect(outcome.wasCanceled, isTrue);
      expect(outcome.added, [entry]);
      expect(outcome.addedItems.single.name, 'Lesson 1');
      expect(api.downloadBatchCalls, 1);
      expect(
        File('${tempDir.path}/audios/imported/sha256.mp3').existsSync(),
        isTrue,
      );
    });
  });
}

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

  /// 每调用一次 [fetchDownloadLinks] 计为一次链接请求（批量请求只计一次）。
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
    required String displayName,
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
          displayName: request.displayName,
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
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  }) async {
    fetchDownloadLinkCalls += 1;
    lastAccessToken = accessToken;
    return {
      for (final fsId in fsIds)
        fsId: BaiduDownloadLink(
          fsId: fsId,
          dlink: 'https://d.pcs.baidu.com/file/$fsId?v=$fetchDownloadLinkCalls',
          size: 4,
        ),
    };
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

    /// 模拟入队时的批量预取（与 provider 调用同一个服务方法）。
    Future<Map<int, BaiduDownloadLink>> prefetchLinks(
      List<CloudDriveEntry> entries,
    ) {
      return service.fetchDownloadLinks(entries: entries);
    }

    test('远端大小元数据不准确时仍完成下载并按 cloudDrive 来源入库', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);
      final progresses = <int>[];

      final item = await service.importAudio(
        entry: entry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([entry]),
        onProgress: (_, received, _) => progresses.add(received),
      );

      // 只有入队时的预取请求一次链接，导入过程中不再取链接。
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
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([videoEntry]),
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
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([entry]),
      );

      // 第 1 次为入队预取，第 2 次为下载失败后的刷新。
      expect(api.fetchDownloadLinkCalls, 2);
      expect(api.downloadCalls, 2);
      expect(api.downloadedDlinks, [
        'https://d.pcs.baidu.com/file/42?v=1',
        'https://d.pcs.baidu.com/file/42?v=2',
      ]);
      expect(item.name, 'Lesson 1');
    });

    test('预取结果中缺少该文件的链接时直接失败，不发起下载', () async {
      final container = ProviderContainer(
        overrides: [audioLibraryProvider.overrideWith(_FakeAudioLibrary.new)],
      );
      addTearDown(container.dispose);

      await expectLater(
        service.importAudio(
          entry: entry,
          audioLibrary: container.read(audioLibraryProvider.notifier),
          readAudioLibraryState: () => container.read(audioLibraryProvider),
          downloadLinks: const {},
        ),
        throwsA(
          isA<BaiduNetdiskFileException>().having(
            (error) => error.kind,
            'kind',
            BaiduNetdiskFileErrorKind.notFound,
          ),
        ),
      );
      expect(api.downloadCalls, 0);
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
          readAudioLibraryState: () => container.read(audioLibraryProvider),
          downloadLinks: const {},
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
          readAudioLibraryState: () => container.read(audioLibraryProvider),
          downloadLinks: const {},
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
          readAudioLibraryState: () => container.read(audioLibraryProvider),
          downloadLinks: const {},
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

    test('导入音频时同批下载并挂载同名字幕，临时字幕文件被清理', () async {
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

      final item = await service.importAudio(
        entry: entry,
        subtitleEntry: subtitleEntry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([entry, subtitleEntry]),
      );

      expect(item.name, 'Lesson 1');
      expect(item.transcriptSource, TranscriptSource.local);
      expect(api.downloadCalls, 2);
      expect(attached['Lesson 1'], contains('srt:1'));
      expect(
        File('${tempDir.path}/tmp/baidu_netdisk/43.srt').existsSync(),
        isFalse,
      );
    });

    test('已导入的音频再次导入时不重复下载音频，只下载并挂载字幕', () async {
      final existing = AudioItem(
        id: 'existing',
        name: 'Lesson 1',
        audioPath: 'audios/imported/sha256.mp3',
        addedDate: DateTime(2026, 1, 1),
        importSourceType: AudioImportSourceType.cloudDrive,
        importSourceUrl: 'baidunetdisk://fs/42?path=%2FLesson%201.mp3',
      );
      final container = ProviderContainer(
        overrides: [
          audioLibraryProvider.overrideWith(
            () => _FakeAudioLibrary(AudioLibraryState(audioItems: [existing])),
          ),
        ],
      );
      addTearDown(container.dispose);
      api.bytesByFsId = {
        subtitleEntry.fsId:
            '1\n00:00:00,000 --> 00:00:01,000\nHello\n'.codeUnits,
      };
      final attached = <String, String>{};
      service = DefaultBaiduNetdiskImportService(
        credentialRepository: credentialRepository,
        api: api,
        resolveDataDir: () async => tempDir,
        subtitleImporter: (item, {required text, required ext}) async {
          attached[item.id] = '$ext:$text';
        },
      );

      final item = await service.importAudio(
        entry: entry,
        subtitleEntry: subtitleEntry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([entry, subtitleEntry]),
      );

      expect(item.id, 'existing');
      expect(api.downloadCalls, 1);
      expect(p.basename(api.lastSavePath!), '43.srt');
      expect(attached['existing'], contains('srt:1'));
    });

    test('字幕下载被取消时音频仍入库且不挂载字幕', () async {
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
      var attachCount = 0;
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
        subtitleImporter: (_, {required text, required ext}) async {
          attachCount++;
        },
      );

      final item = await service.importAudio(
        entry: entry,
        subtitleEntry: subtitleEntry,
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        downloadLinks: await prefetchLinks([entry, subtitleEntry]),
      );

      expect(item.name, 'Lesson 1');
      expect(item.transcriptSource, isNot(TranscriptSource.local));
      expect(attachCount, 0);
      expect(
        File('${tempDir.path}/audios/imported/sha256.mp3').existsSync(),
        isTrue,
      );
    });
  });
}

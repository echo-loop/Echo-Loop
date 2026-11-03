import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_credential_repository.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_import_service.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_credential_bundle.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session_status.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_account_profile.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_import_controller.dart';
import 'package:echo_loop/features/baidu_netdisk/services/baidu_oauth_launcher.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../helpers/mock_providers.dart';

class _FakeCredentialRepository implements BaiduCredentialRepository {
  _FakeCredentialRepository(this.accessToken);

  String? accessToken;
  bool cleared = false;
  int consumedForceLoginCount = 0;
  BaiduOAuthSessionStatus? authorizationStatus;

  @override
  Future<void> clearCredential() async {
    cleared = true;
    accessToken = null;
  }

  @override
  Future<void> consumeForceLoginOnce() async {
    consumedForceLoginCount++;
  }

  @override
  Future<void> disconnect() async {
    cleared = true;
    accessToken = null;
  }

  @override
  Future<BaiduOAuthSession> createSession(BaiduNetdiskPlatform platform) async {
    return BaiduOAuthSession(
      sessionId: 'sid',
      pollToken: 'poll',
      authorizationUri: Uri.parse('https://openapi.baidu.com/oauth'),
      expiresAt: DateTime.utc(2026, 8, 18, 12, 10),
      pollInterval: Duration.zero,
    );
  }

  @override
  Future<BaiduOAuthSessionStatus> fetchStatus(BaiduOAuthSession session) async {
    final status = authorizationStatus;
    if (status == null) throw StateError('未设置 OAuth 授权状态');
    return status;
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
  int profileFetchCount = 0;

  @override
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  }) async {
    profileFetchCount++;
    return const BaiduAccountProfile(uk: 1);
  }

  List<CloudDriveEntry> entries = const <CloudDriveEntry>[];
  String? lastDir;

  @override
  Future<BaiduDownloadLink> fetchDownloadLink({
    required String accessToken,
    required int fsId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    String? resourceKey,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<BaiduNetdiskDownloadItemResult>> downloadFiles({
    required String accessToken,
    required List<BaiduNetdiskDownloadRequest> requests,
    CancelToken? cancelToken,
    void Function(String taskId, int receivedBytes, int? totalBytes)?
    onProgress,
  }) => throw UnimplementedError();

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  }) async {
    lastDir = dir;
    return CloudDriveListPage(
      entries: entries,
      nextStart: entries.length,
      hasMore: false,
    );
  }
}

class _FakeImportService implements BaiduNetdiskImportService {
  List<CloudDriveEntry> importedEntries = const <CloudDriveEntry>[];
  List<CloudDriveEntry> importedSubtitleEntries = const <CloudDriveEntry>[];

  @override
  Future<AudioItem> importAudio({
    required CloudDriveEntry entry,
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    importedEntries = entries;
    importedSubtitleEntries = subtitleEntries;
    for (final entry in entries) {
      onProgress?.call(entry, entry.size, entry.size);
      final item = AudioItem(
        id: 'audio-${entry.fsId}',
        name: entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        audioPath: 'audios/${entry.fsId}.mp3',
        addedDate: DateTime(2026, 1, 1),
      );
      await audioLibrary.addAudioItem(item);
      onItemResult?.call(
        CloudDriveImportItemResult.added(entry: entry, item: item),
      );
    }
    return CloudDriveImportOutcome(
      added: entries,
      addedItems: [
        for (final entry in entries)
          AudioItem(
            id: 'audio-${entry.fsId}',
            name: entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            audioPath: 'audios/${entry.fsId}.mp3',
            addedDate: DateTime(2026, 1, 1),
          ),
      ],
    );
  }
}

class _FailingImportService extends _FakeImportService {
  @override
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    importedEntries = entries;
    importedSubtitleEntries = subtitleEntries;
    final failures = <CloudDriveImportFailure>[];
    for (final entry in entries) {
      onProgress?.call(entry, entry.size, entry.size);
      final failure = CloudDriveImportFailure(
        entry: entry,
        message: 'Connection terminated during handshake',
        errorKind: 'network',
      );
      failures.add(failure);
      onItemResult?.call(
        CloudDriveImportItemResult.failed(entry: entry, failure: failure),
      );
    }
    return CloudDriveImportOutcome(
      added: const <CloudDriveEntry>[],
      failures: failures,
    );
  }
}

class _RetryableImportService extends _FakeImportService {
  _RetryableImportService(this.failOnceFsId);

  final int failOnceFsId;
  final _failedFsIds = <int>{};

  @override
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    importedEntries = entries;
    importedSubtitleEntries = subtitleEntries;
    final added = <CloudDriveEntry>[];
    final addedItems = <AudioItem>[];
    final failures = <CloudDriveImportFailure>[];
    for (final entry in entries) {
      onProgress?.call(entry, entry.size, entry.size);
      if (entry.fsId == failOnceFsId && _failedFsIds.add(entry.fsId)) {
        final failure = CloudDriveImportFailure(
          entry: entry,
          message: 'Connection terminated during handshake',
          errorKind: 'network',
        );
        failures.add(failure);
        onItemResult?.call(
          CloudDriveImportItemResult.failed(entry: entry, failure: failure),
        );
        continue;
      }
      final item = AudioItem(
        id: 'audio-${entry.fsId}',
        name: entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        audioPath: 'audios/${entry.fsId}.mp3',
        addedDate: DateTime(2026, 1, 1),
      );
      await audioLibrary.addAudioItem(item);
      added.add(entry);
      addedItems.add(item);
      onItemResult?.call(
        CloudDriveImportItemResult.added(entry: entry, item: item),
      );
    }
    return CloudDriveImportOutcome(
      added: added,
      addedItems: addedItems,
      failures: failures,
    );
  }
}

class _ProgressImportService extends _FakeImportService {
  _ProgressImportService({
    required this.advanceClock,
    this.receivedFractions = const [0.25, 0.75],
  });

  final VoidCallback advanceClock;
  final List<double> receivedFractions;
  final completer = Completer<CloudDriveImportOutcome>();

  @override
  Future<CloudDriveImportOutcome> importAudios({
    required List<CloudDriveEntry> entries,
    List<CloudDriveEntry> subtitleEntries = const <CloudDriveEntry>[],
    required AudioLibrary audioLibrary,
    required AudioLibraryState audioLibraryState,
    CollectionList? collectionList,
    CollectionState? collectionState,
    String? collectionId,
    CancelToken? cancelToken,
    BaiduNetdiskImportProgressCallback? onProgress,
    BaiduNetdiskImportItemResultCallback? onItemResult,
  }) async {
    importedEntries = entries;
    importedSubtitleEntries = subtitleEntries;
    final entry = entries.single;
    for (var i = 0; i < receivedFractions.length; i++) {
      if (i > 0) advanceClock();
      onProgress?.call(
        entry,
        (entry.size * receivedFractions[i]).round(),
        entry.size,
      );
    }
    return completer.future;
  }
}

class _NoopLauncher implements BaiduOAuthLauncher {
  @override
  Future<void> open(Uri authorizationUri) async {}
}

class _FakeAudioLibrary extends AudioLibrary {
  var contentCheckCalls = 0;

  @override
  AudioLibraryState build() => const AudioLibraryState();

  @override
  Future<void> addAudioItem(AudioItem item) async {
    state = state.copyWith(audioItems: [...state.audioItems, item]);
  }

  @override
  Future<void> checkAudioContent(
    String audioId, {
    int? decodedDurationSeconds,
  }) async {
    contentCheckCalls++;
  }
}

class _FakeCollectionList extends CollectionList {
  @override
  CollectionState build() => const CollectionState();
}

void main() {
  group('BaiduNetdiskImportController', () {
    late _FakeCredentialRepository credentialRepository;
    late _FakeBaiduNetdiskApi api;
    late _FakeImportService importService;
    late ProviderContainer container;
    late BaiduNetdiskImportController controller;

    const folder = CloudDriveEntry(
      fsId: 1,
      name: 'Folder',
      path: '/Folder',
      isDirectory: true,
      size: 0,
    );
    const audio = CloudDriveEntry(
      fsId: 2,
      name: 'lesson.mp3',
      path: '/lesson.mp3',
      isDirectory: false,
      size: 1024,
    );
    const text = CloudDriveEntry(
      fsId: 3,
      name: 'notes.txt',
      path: '/notes.txt',
      isDirectory: false,
      size: 10,
    );
    const subtitle = CloudDriveEntry(
      fsId: 4,
      name: 'lesson.srt',
      path: '/lesson.srt',
      isDirectory: false,
      size: 20,
    );
    const secondAudio = CloudDriveEntry(
      fsId: 5,
      name: 'review.mp3',
      path: '/review.mp3',
      isDirectory: false,
      size: 2048,
    );
    const video = CloudDriveEntry(
      fsId: 6,
      name: 'lesson-video.mp4',
      path: '/lesson-video.mp4',
      isDirectory: false,
      size: 4096,
    );

    setUp(() {
      credentialRepository = _FakeCredentialRepository('access-token');
      api = _FakeBaiduNetdiskApi();
      importService = _FakeImportService();
      container = ProviderContainer(
        overrides: dedupeOverrides([
          audioLibraryProvider.overrideWith(_FakeAudioLibrary.new),
          collectionListProvider.overrideWith(_FakeCollectionList.new),
        ]),
      );
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: importService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
      );
    });

    tearDown(() {
      controller.dispose();
      container.dispose();
    });

    test('无 access token 时进入授权态', () async {
      credentialRepository.accessToken = null;

      await controller.loadInitial();

      expect(
        controller.state.phase,
        BaiduNetdiskImportPhase.authorizationRequired,
      );
    });

    test('授权取消时消费一次性强制登录标志', () async {
      credentialRepository.accessToken = null;
      credentialRepository.authorizationStatus = const BaiduOAuthSessionStatus(
        phase: BaiduOAuthSessionPhase.canceled,
      );

      await controller.authorizeAndLoad();

      expect(credentialRepository.consumedForceLoginCount, 1);
      expect(
        controller.state.phase,
        BaiduNetdiskImportPhase.authorizationRequired,
      );
    });

    test('授权失败时保留一次性强制登录标志', () async {
      credentialRepository.accessToken = null;
      credentialRepository.authorizationStatus = const BaiduOAuthSessionStatus(
        phase: BaiduOAuthSessionPhase.failed,
      );

      await controller.authorizeAndLoad();

      expect(credentialRepository.consumedForceLoginCount, 0);
      expect(
        controller.state.phase,
        BaiduNetdiskImportPhase.authorizationRequired,
      );
    });

    test('加载目录时保留目录、音频和非音频文件', () async {
      api.entries = const [folder, audio, text];

      await controller.loadInitial();

      expect(controller.state.phase, BaiduNetdiskImportPhase.ready);
      expect(controller.state.entries, [folder, audio, text]);
      expect(api.lastDir, '/');
    });

    test('已有凭据进入导入时后台刷新账户资料', () async {
      await controller.loadInitial();
      await Future<void>.delayed(Duration.zero);

      expect(api.profileFetchCount, 1);
    });

    test('只能选择支持的素材和字幕文件', () async {
      api.entries = const [audio, subtitle, secondAudio, video, text];
      await controller.loadInitial();

      controller.toggleEntry(text);
      expect(controller.state.selectedFsIds, isEmpty);

      controller.toggleEntry(audio);
      expect(controller.state.selectedFsIds, {audio.fsId});
      expect(controller.state.selectedAudioEntries, [audio]);
      expect(controller.state.selectedSubtitleEntries, isEmpty);

      controller.toggleEntry(secondAudio);
      expect(controller.state.selectedFsIds, {audio.fsId, secondAudio.fsId});
      expect(controller.state.selectedAudioEntries, [audio, secondAudio]);
      expect(controller.state.selectedSubtitleEntries, isEmpty);

      controller.toggleEntry(video);
      expect(controller.state.selectedFsIds, {
        audio.fsId,
        secondAudio.fsId,
        video.fsId,
      });
      expect(controller.state.selectedAudioEntries, [
        audio,
        secondAudio,
        video,
      ]);
      expect(controller.state.selectedSubtitleEntries, isEmpty);

      controller.toggleEntry(subtitle);
      expect(controller.state.selectedFsIds, {
        audio.fsId,
        secondAudio.fsId,
        video.fsId,
        subtitle.fsId,
      });
      expect(controller.state.selectedAudioEntries, [
        audio,
        secondAudio,
        video,
      ]);
      expect(controller.state.selectedSubtitleEntries, [subtitle]);
    });

    test('全选只切换当前目录内可导入的素材和字幕', () async {
      api.entries = const [folder, audio, video, subtitle, text];
      await controller.loadInitial();

      controller.toggleSelectAll();

      expect(controller.state.selectedFsIds, {
        audio.fsId,
        video.fsId,
        subtitle.fsId,
      });
      expect(controller.state.isAllSelectableSelected, isTrue);

      controller.toggleSelectAll();
      expect(controller.state.selectedFsIds, isEmpty);
    });

    test('选择音频和字幕并导入后进入完成态', () async {
      api.entries = const [audio, subtitle];
      await controller.loadInitial();

      controller.toggleEntry(audio);
      controller.toggleEntry(subtitle);
      await controller.importSelected();

      expect(importService.importedEntries, [audio]);
      expect(importService.importedSubtitleEntries, [subtitle]);
      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(controller.state.selectedFsIds, {audio.fsId, subtitle.fsId});
      expect(controller.state.importOutcome?.added, [audio]);
      expect(controller.state.importOutcome?.addedItems.single.name, 'lesson');
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.added,
      );
      expect(
        container.read(audioLibraryProvider).audioItems.single.name,
        'lesson',
      );
      expect(
        (container.read(audioLibraryProvider.notifier) as _FakeAudioLibrary)
            .contentCheckCalls,
        0,
      );

      controller.returnToReady();

      expect(controller.state.phase, BaiduNetdiskImportPhase.ready);
      expect(controller.state.selectedFsIds, isEmpty);
      expect(controller.state.importOutcome, isNull);
    });

    test('单条导入失败时保留失败状态和错误原因', () async {
      controller.dispose();
      importService = _FailingImportService();
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: importService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
      );
      api.entries = const [audio];
      await controller.loadInitial();

      controller.toggleEntry(audio);
      await controller.importSelected();

      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(controller.state.importOutcome?.failures.single.entry, audio);
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.failed,
      );
      expect(
        controller.state.importFailureMessages[audio.fsId],
        'Connection terminated during handshake',
      );
      expect(controller.state.importDuplicateExistingNames, isEmpty);
    });

    test('导入进度记录当前文件百分比和下载速度', () async {
      controller.dispose();
      var now = DateTime(2026, 7, 22, 12);
      final progressService = _ProgressImportService(
        advanceClock: () => now = now.add(const Duration(seconds: 1)),
      );
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: progressService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
        now: () => now,
      );
      api.entries = const [audio];
      await controller.loadInitial();

      controller.toggleEntry(audio);
      final importFuture = controller.importSelected();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.phase, BaiduNetdiskImportPhase.importing);
      expect(controller.state.importingEntry, audio);
      expect(controller.state.importProgress, 0.75);
      expect(controller.state.importReceivedBytes, 768);
      expect(controller.state.importTotalBytes, 1024);
      expect(controller.state.importSpeedBytesPerSecond, 512);

      progressService.completer.complete(
        const CloudDriveImportOutcome(added: <CloudDriveEntry>[]),
      );
      await importFuture;

      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(controller.state.importSpeedBytesPerSecond, isNull);
    });

    test('导入被取消后未完成文件恢复为待导入状态', () async {
      controller.dispose();
      final progressService = _ProgressImportService(advanceClock: () {});
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: progressService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
      );
      api.entries = const [audio];
      await controller.loadInitial();
      controller.toggleEntry(audio);

      final importFuture = controller.importSelected();
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.importing,
      );

      progressService.completer.complete(
        const CloudDriveImportOutcome(
          added: <CloudDriveEntry>[],
          wasCanceled: true,
        ),
      );
      await importFuture;

      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.pending,
      );
    });

    test('导入速度按最近 5 秒窗口计算并限制显示刷新频率', () async {
      controller.dispose();
      var now = DateTime(2026, 7, 22, 12);
      var step = 0;
      final progressService = _ProgressImportService(
        receivedFractions: const [0.25, 0.5, 0.75, 1.0],
        advanceClock: () {
          step++;
          now = now.add(
            Duration(
              milliseconds: switch (step) {
                1 => 1000,
                2 => 500,
                _ => 800,
              },
            ),
          );
        },
      );
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: progressService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
        now: () => now,
      );
      api.entries = const [video];
      await controller.loadInitial();

      final displayedSpeeds = <double>[];
      final removeListener = controller.addListener((state) {
        final speed = state.importSpeedBytesPerSecond;
        if (speed != null) displayedSpeeds.add(speed);
      }, fireImmediately: false);
      addTearDown(removeListener);

      controller.toggleEntry(video);
      final importFuture = controller.importSelected();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.importProgress, 1.0);
      expect(controller.state.importReceivedBytes, 4096);
      expect(
        controller.state.importSpeedBytesPerSecond,
        closeTo(1335.65, 0.01),
      );
      expect(displayedSpeeds.length, 3);
      expect(displayedSpeeds[0], 1024);
      expect(displayedSpeeds[1], 1024);
      expect(displayedSpeeds[2], closeTo(1335.65, 0.01));

      progressService.completer.complete(
        const CloudDriveImportOutcome(added: <CloudDriveEntry>[]),
      );
      await importFuture;
    });

    test('失败项单独重试后合并到原导入结果', () async {
      controller.dispose();
      importService = _RetryableImportService(audio.fsId);
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        importService: importService,
        launcher: _NoopLauncher(),
        audioLibrary: container.read(audioLibraryProvider.notifier),
        readAudioLibraryState: () => container.read(audioLibraryProvider),
        collectionList: container.read(collectionListProvider.notifier),
        readCollectionState: () => container.read(collectionListProvider),
      );
      api.entries = const [audio, secondAudio];
      await controller.loadInitial();

      controller.toggleEntry(audio);
      controller.toggleEntry(secondAudio);
      await controller.importSelected();

      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(controller.state.importOutcome?.added, [secondAudio]);
      expect(controller.state.importOutcome?.failures.single.entry, audio);
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.failed,
      );

      await controller.retryFailedEntry(audio);

      expect(controller.state.phase, BaiduNetdiskImportPhase.completed);
      expect(controller.state.importOutcome?.failures, isEmpty);
      expect(controller.state.importOutcome?.added, [secondAudio, audio]);
      expect(
        controller.state.importOutcome?.addedItems.map((item) => item.name),
        ['review', 'lesson'],
      );
      expect(
        controller.state.importItemStatuses[audio.fsId],
        AudioImportSelectionStatus.added,
      );
      expect(controller.state.importFailureMessages, isEmpty);
    });
  });
}

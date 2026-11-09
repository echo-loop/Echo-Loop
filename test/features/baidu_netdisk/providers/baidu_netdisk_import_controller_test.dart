import 'package:dio/dio.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_credential_repository.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_credential_bundle.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session_status.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_account_profile.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_import_controller.dart';
import 'package:echo_loop/features/baidu_netdisk/services/baidu_oauth_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final List<int> requestedStarts = <int>[];

  /// 模拟服务端单页最多返回的条数，可能小于请求的 limit。
  int serverMaxPageSize = 1000;

  /// 请求该 start 时抛出失败，用于模拟中途某一页出错。
  int? failingStart;

  @override
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    required String displayName,
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
    int limit = 1000,
  }) async {
    lastDir = dir;
    requestedStarts.add(start);
    if (start == failingStart) {
      throw const BaiduNetdiskFileException(
        kind: BaiduNetdiskFileErrorKind.unknown,
        message: 'page failed',
      );
    }
    final pageSize = limit < serverMaxPageSize ? limit : serverMaxPageSize;
    final pageEntries = entries
        .skip(start)
        .take(pageSize)
        .toList(growable: false);
    return CloudDriveListPage(
      entries: pageEntries,
      nextStart: start + pageEntries.length,
    );
  }
}

class _NoopLauncher implements BaiduOAuthLauncher {
  @override
  Future<void> open(Uri authorizationUri) async {}
}

void main() {
  group('BaiduNetdiskImportController', () {
    late _FakeCredentialRepository credentialRepository;
    late _FakeBaiduNetdiskApi api;
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
      controller = BaiduNetdiskImportController(
        credentialRepository: credentialRepository,
        api: api,
        launcher: _NoopLauncher(),
      );
    });

    tearDown(() {
      controller.dispose();
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

    test('目录超过单页数量时按分页取全所有文件', () async {
      api.entries = [
        for (var index = 0; index < 2500; index++)
          CloudDriveEntry(
            fsId: index + 1,
            name: 'lesson-$index.mp3',
            path: '/lesson-$index.mp3',
            isDirectory: false,
            size: 1,
          ),
      ];

      await controller.loadInitial();

      expect(controller.state.phase, BaiduNetdiskImportPhase.ready);
      expect(controller.state.entries, hasLength(2500));
      expect(controller.state.entries.last.name, 'lesson-2499.mp3');
      expect(api.requestedStarts, [0, 1000, 2000, 2500]);
    });

    test('服务端单页条数小于请求的 limit 时仍取全所有文件', () async {
      api
        ..serverMaxPageSize = 100
        ..entries = [
          for (var index = 0; index < 250; index++)
            CloudDriveEntry(
              fsId: index + 1,
              name: 'lesson-$index.mp3',
              path: '/lesson-$index.mp3',
              isDirectory: false,
              size: 1,
            ),
        ];

      await controller.loadInitial();

      expect(controller.state.phase, BaiduNetdiskImportPhase.ready);
      expect(controller.state.entries, hasLength(250));
      expect(api.requestedStarts, [0, 100, 200, 250]);
    });

    test('中途某一页失败时进入失败态，不保留部分结果', () async {
      api
        ..entries = [
          for (var index = 0; index < 2500; index++)
            CloudDriveEntry(
              fsId: index + 1,
              name: 'lesson-$index.mp3',
              path: '/lesson-$index.mp3',
              isDirectory: false,
              size: 1,
            ),
        ]
        ..failingStart = 1000;

      await controller.loadInitial();

      expect(controller.state.phase, BaiduNetdiskImportPhase.failed);
      expect(controller.state.errorMessage, 'page failed');
      expect(controller.state.entries, isEmpty);
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
      expect(controller.state.isAllSelectableSelected(), isTrue);

      controller.toggleSelectAll();
      expect(controller.state.selectedFsIds, isEmpty);
    });

    test('全选跳过不可选条目，不把已导入或排队中的文件选上', () async {
      api.entries = const [audio, secondAudio, subtitle];
      await controller.loadInitial();

      controller.toggleSelectAll(unavailableFsIds: {audio.fsId});

      expect(controller.state.selectedFsIds, {secondAudio.fsId, subtitle.fsId});
      expect(
        controller.state.isAllSelectableSelected(
          unavailableFsIds: {audio.fsId},
        ),
        isTrue,
      );

      controller.toggleSelectAll(unavailableFsIds: {audio.fsId});
      expect(controller.state.selectedFsIds, isEmpty);
    });

    test('清空选择后不再保留任何选中文件', () async {
      api.entries = const [audio, subtitle, text];
      await controller.loadInitial();
      controller.toggleEntry(audio);
      controller.toggleEntry(subtitle);

      controller.clearSelection();

      expect(controller.state.selectedFsIds, isEmpty);
      expect(controller.state.phase, BaiduNetdiskImportPhase.ready);
    });
  });
}

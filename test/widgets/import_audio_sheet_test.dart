import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_credential_repository.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_import_service.dart';
import 'package:echo_loop/providers/download_clock_provider.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_credential_bundle.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session_status.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_account_profile.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_import_tasks_provider.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/models/collection.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/widgets/import_audio_selection_list.dart';
import 'package:echo_loop/widgets/import_audio_sheet.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/misc.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_app.dart';

class _ImmediateAudioImportController extends AudioImportController {
  _ImmediateAudioImportController({this.fail = false});

  final bool fail;

  @override
  AudioImportState build() => const AudioImportIdle();

  @override
  Future<AudioItem?> importFromUrl(String url, {String? collectionId}) async {
    if (fail) {
      state = const AudioImportFailed(
        AudioImportException(AudioImportFailureCode.invalidUrl, 'invalid'),
      );
      return null;
    }
    final item = AudioItem(
      id: 'url-audio',
      name: 'URL Audio',
      audioPath: 'audios/imported/url.mp3',
      addedDate: DateTime(2026, 1, 1),
    );
    state = AudioImportCompleted(item);
    return item;
  }
}

class _PendingAudioImportController extends AudioImportController {
  final Completer<AudioItem?> _completion = Completer<AudioItem?>();
  bool cancellationRequested = false;

  @override
  AudioImportState build() => const AudioImportIdle();

  @override
  Future<AudioItem?> importFromUrl(String url, {String? collectionId}) {
    state = AudioImportDownloading(displayName: url, progress: 0.4);
    return _completion.future;
  }

  @override
  Future<void> cancel() async {
    cancellationRequested = true;
    state = const AudioImportIdle();
    if (!_completion.isCompleted) _completion.complete(null);
  }
}

class _TokenCredentialRepository implements BaiduCredentialRepository {
  bool cleared = false;

  @override
  Future<void> clearCredential() async {
    cleared = true;
  }

  @override
  Future<void> consumeForceLoginOnce() async {}

  @override
  Future<void> disconnect() async {
    cleared = true;
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
  Future<String?> getValidAccessToken() async => 'access-token';

  @override
  Future<void> persistCompletedSession({
    required BaiduOAuthSession session,
    required BaiduCredentialBundle credential,
  }) async {}
}

class _NoTokenCredentialRepository extends _TokenCredentialRepository {
  @override
  Future<String?> getValidAccessToken() async => null;
}

class _PendingBaiduNetdiskApi implements BaiduNetdiskApi {
  @override
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  }) async => const BaiduAccountProfile(uk: 1);
  final Completer<CloudDriveListPage> _listCompleter =
      Completer<CloudDriveListPage>();

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
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  }) {
    return _listCompleter.future;
  }
}

class _RecordingFilePicker extends FilePicker {
  _RecordingFilePicker({this.result});

  /// 选择器回传的结果；null 表示用户取消。
  final FilePickerResult? result;

  bool? lastAllowMultiple;
  int pickCount = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    @Deprecated(
      'allowCompression is deprecated and has no effect. Use compressionQuality instead.',
    )
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastAllowMultiple = allowMultiple;
    pickCount++;
    return result;
  }
}

class _StaticBaiduNetdiskApi implements BaiduNetdiskApi {
  _StaticBaiduNetdiskApi(
    this.pages, {
    this.profile = const BaiduAccountProfile(uk: 1),
  });

  final BaiduAccountProfile profile;

  @override
  Future<BaiduAccountProfile> fetchAccountProfile({
    required String accessToken,
  }) async => profile;

  final Map<String, List<CloudDriveEntry>> pages;
  final requestedDirs = <String>[];

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
  Future<Map<int, BaiduDownloadLink>> fetchDownloadLinks({
    required String accessToken,
    required List<int> fsIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 1000,
  }) async {
    // 每次进入目录只记录一次（第一页），翻页时的空页请求不计入。
    if (start == 0) requestedDirs.add(dir);
    // 模拟服务端：只有第一页有数据，之后返回空页表示目录末尾。
    final entries = start == 0
        ? pages[dir] ?? const <CloudDriveEntry>[]
        : const <CloudDriveEntry>[];
    return CloudDriveListPage(
      entries: entries,
      nextStart: start + entries.length,
    );
  }
}

/// 挂起的单文件导入执行函数：记录取消令牌，不结束下载。
class _PendingItemRunner {
  _PendingItemRunner({this.succeed = false});

  /// 为 true 时立即成功，用于验证导入完成后的状态。
  final bool succeed;
  final List<CancelToken> tokens = <CancelToken>[];
  BaiduNetdiskImportProgressCallback? _onProgress;

  Future<AudioItem> call({
    required CloudDriveEntry entry,
    CloudDriveEntry? subtitleEntry,
    String? collectionId,
    required Map<int, BaiduDownloadLink> downloadLinks,
    required CancelToken cancelToken,
    required BaiduNetdiskImportProgressCallback onProgress,
  }) {
    tokens.add(cancelToken);
    _onProgress = onProgress;
    if (succeed) {
      return Future.value(
        AudioItem(
          id: 'new-${entry.fsId}',
          name: entry.name,
          audioPath: 'audios/imported/${entry.fsId}.mp3',
          addedDate: DateTime(2026, 1, 1),
        ),
      );
    }
    return Completer<AudioItem>().future;
  }

  /// 模拟底层下载回调上报进度。
  void reportProgress(int received, int total) {
    _onProgress!(_baiduLessonFile, received, total);
  }
}

/// 可手动推进的时钟，用于验证下载速度。
class _FakeClock {
  DateTime now = DateTime(2026, 11, 4, 10);

  void advance(Duration duration) {
    now = now.add(duration);
  }
}

const _baiduLessonFile = CloudDriveEntry(
  fsId: 2,
  name: 'lesson.mp3',
  path: '/lesson.mp3',
  isDirectory: false,
  size: 1536,
);

Future<void> _pumpBaiduDirectory(
  WidgetTester tester, {
  required _PendingItemRunner runner,
  _TokenCredentialRepository? credentialRepository,
  _FakeClock? clock,
  List<CloudDriveEntry> entries = const [_baiduLessonFile],
  List<AudioItem> libraryItems = const [],
  CollectionState? collectionState,
}) async {
  final api = _StaticBaiduNetdiskApi({'/': entries});
  await tester.pumpWidget(
    _buildApp(
      locale: const Locale('zh'),
      overrides: dedupeOverrides([
        baiduCredentialRepositoryProvider.overrideWithValue(
          credentialRepository ?? _TokenCredentialRepository(),
        ),
        baiduNetdiskApiProvider.overrideWithValue(api),
        baiduImportItemRunnerProvider.overrideWithValue(runner.call),
        baiduImportLinkFetcherProvider.overrideWithValue(
          (entries) async => {
            for (final entry in entries)
              entry.fsId: BaiduDownloadLink(
                fsId: entry.fsId,
                dlink: 'https://d.pcs.baidu.com/file/${entry.fsId}',
              ),
          },
        ),
        if (clock != null)
          downloadClockProvider.overrideWithValue(() => clock.now),
        if (libraryItems.isNotEmpty)
          audioLibraryProvider.overrideWith(
            () => TestAudioLibrary(AudioLibraryState(audioItems: libraryItems)),
          ),
        if (collectionState != null)
          collectionListProvider.overrideWith(
            () => TestCollectionList(collectionState),
          ),
      ]),
    ),
  );
  await _reopenBaiduDirectory(tester);
}

/// 从主页打开导入弹窗并进入百度网盘根目录。
Future<void> _reopenBaiduDirectory(WidgetTester tester) async {
  await tester.tap(find.text('Open Import'));
  await _pumpFrames(tester);
  await tester.tap(find.text('从网盘导入'));
  await _pumpFrames(tester);
  await tester.tap(find.text('百度网盘'));
  await _pumpFrames(tester);
}

/// 推进固定时长。下载中的进度圈是无限动画，pumpAndSettle 无法收敛。
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _buildApp({
  bool failImport = false,
  Locale locale = const Locale('en'),
  bool cloudDriveImportEnabled = true,
  List<Override> overrides = const <Override>[],
}) {
  return createTestApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const ImportAudioFlowSheet(),
              );
            },
            child: const Text('Open Import'),
          ),
        ),
      ),
    ),
    overrides: dedupeOverrides([
      analyticsOverride(),
      appSettingsProvider.overrideWith(
        () => TestAppSettings(AppSettingsState(locale: locale)),
      ),
      audioLibraryProvider.overrideWith(() => TestAudioLibrary()),
      collectionListProvider.overrideWith(() => TestCollectionList()),
      audioImportControllerProvider.overrideWith(
        () => _ImmediateAudioImportController(fail: failImport),
      ),
      initialRemoteConfigProvider.overrideWithValue(
        RemoteConfig(
          version: RemoteConfig.currentVersion,
          ttlSeconds: RemoteConfig.defaultTtlSeconds,
          context: const RemoteConfigContext(),
          features: RemoteConfigFeatures(
            cloudDriveImport: RemoteFeatureConfig(
              enabled: cloudDriveImportEnabled,
            ),
          ),
        ),
      ),
      ...overrides,
    ]),
    locale: locale,
  );
}

void main() {
  void mockClipboardText(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return text == null ? null : <String, dynamic>{'text': text};
          }
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('导入列表在固定高度内滚动且不溢出', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: SizedBox(
            height: 260,
            child: ImportAudioSelectionList(
              maxHeight: double.infinity,
              progress: const AudioImportSelectionProgress(
                label: '正在导入 12/30：audio-12.mp3',
                value: 0.8,
              ),
              items: [
                for (var i = 0; i < 30; i++)
                  AudioImportSelectionItem(
                    id: '$i',
                    displayName: 'audio-$i.mp3',
                    fileSize: 1024 * 1024,
                    hasSubtitle: i.isEven,
                    status: i == 12
                        ? AudioImportSelectionStatus.importing
                        : i < 12
                        ? AudioImportSelectionStatus.added
                        : AudioImportSelectionStatus.pending,
                  ),
              ],
            ),
          ),
        ),
        overrides: dedupeOverrides([
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('audio-0.mp3'), findsOneWidget);
    expect(find.text('正在导入 12/30：audio-12.mp3'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('导入列表正在导入行显示下载速度百分比和失败摘要', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: SizedBox(
            width: 360,
            child: ImportAudioSelectionList(
              progress: const AudioImportSelectionProgress(
                label: '正在导入 1/2：002-第一周-002-W1-英国文化拓展-很长很长的文件名.mp4',
                value: 0.5,
                progressPercent: 50,
                speedBytesPerSecond: 512 * 1024,
              ),
              summary: const AudioImportSelectionSummary(
                addedCount: 1,
                subtitleCount: 0,
                skippedCount: 0,
                failedCount: 1,
              ),
              items: const [
                AudioImportSelectionItem(
                  id: 'lesson',
                  displayName: '002-第一周-002-W1-英国文化拓展-很长很长的文件名.mp4',
                  fileSize: 2 * 1024 * 1024,
                  hasSubtitle: false,
                  status: AudioImportSelectionStatus.importing,
                ),
                AudioImportSelectionItem(
                  id: 'failed',
                  displayName: 'failed.mp4',
                  fileSize: 1024,
                  hasSubtitle: false,
                  status: AudioImportSelectionStatus.failed,
                  failureMessage: 'Connection terminated during handshake',
                ),
              ],
            ),
          ),
        ),
        overrides: dedupeOverrides([
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ]),
        locale: const Locale('zh'),
      ),
    );

    expect(find.text('512.0 KB/s · 50%'), findsOneWidget);
    expect(find.textContaining('正在导入 1/2：002-第一周'), findsOneWidget);
    expect(find.textContaining('成功导入 1 个素材'), findsOneWidget);
    expect(find.text('失败 1 个'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsNWidgets(2));
  });

  testWidgets('导入列表速度采样为空时仍保留右侧速度占位', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: SizedBox(
            width: 360,
            child: ImportAudioSelectionList(
              progress: const AudioImportSelectionProgress(
                label: '正在导入 1/3：lesson.mp4',
                value: 0.15,
                progressPercent: 15,
              ),
              items: const [
                AudioImportSelectionItem(
                  id: 'lesson',
                  displayName: 'lesson.mp4',
                  fileSize: 2 * 1024 * 1024,
                  hasSubtitle: false,
                  status: AudioImportSelectionStatus.importing,
                ),
              ],
            ),
          ),
        ),
        overrides: dedupeOverrides([
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ]),
        locale: const Locale('zh'),
      ),
    );

    expect(find.text('0 B/s · 15%'), findsOneWidget);
  });

  testWidgets('导入列表未开始导入时可显示删除入口', (tester) async {
    final removedIds = <String>[];
    await tester.pumpWidget(
      createTestApp(
        Scaffold(
          body: ImportAudioSelectionList(
            onRemove: removedIds.add,
            items: const [
              AudioImportSelectionItem(
                id: 'local-audio',
                displayName: 'local.mp3',
                fileSize: 1024,
                hasSubtitle: true,
              ),
            ],
          ),
        ),
        overrides: dedupeOverrides([
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ]),
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(removedIds, ['local-audio']);
  });

  testWidgets('导入方式 sheet 提供本地文件、链接和网盘入口', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import Audio'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Import from Cloud Storage'), findsOneWidget);
    expect(find.text('Choose a cloud drive provider'), findsNothing);
    expect(find.text('Baidu Netdisk'), findsNothing);

    final localTop = tester
        .getTopLeft(find.byKey(const ValueKey('import-option-local-file')))
        .dy;
    final cloudTop = tester
        .getTopLeft(find.byKey(const ValueKey('import-option-cloud-drive')))
        .dy;
    final linkTop = tester
        .getTopLeft(find.byKey(const ValueKey('import-option-direct-url')))
        .dy;
    expect(localTop, lessThan(cloudTop));
    expect(cloudTop, lessThan(linkTop));
  });

  testWidgets('远程配置关闭时隐藏网盘导入入口', (tester) async {
    await tester.pumpWidget(_buildApp(cloudDriveImportEnabled: false));
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import Audio'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Import from Cloud Storage'), findsNothing);
    expect(
      find.byKey(const ValueKey('import-option-cloud-drive')),
      findsNothing,
    );
  });

  testWidgets('导入方式入口使用独立边框分隔', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    final localOption = find.byKey(const ValueKey('import-option-local-file'));
    final linkOption = find.byKey(const ValueKey('import-option-direct-url'));
    final cloudDriveOption = find.byKey(
      const ValueKey('import-option-cloud-drive'),
    );
    expect(localOption, findsOneWidget);
    expect(linkOption, findsOneWidget);
    expect(cloudDriveOption, findsOneWidget);

    final localMaterial = tester.widget<Material>(
      find.descendant(of: localOption, matching: find.byType(Material)),
    );
    final linkMaterial = tester.widget<Material>(
      find.descendant(of: linkOption, matching: find.byType(Material)),
    );
    final localShape = localMaterial.shape;
    final linkShape = linkMaterial.shape;
    expect(localShape, isA<RoundedRectangleBorder>());
    expect(linkShape, isA<RoundedRectangleBorder>());
    expect(
      (localShape! as RoundedRectangleBorder).side.style,
      BorderStyle.solid,
    );
    expect(
      (linkShape! as RoundedRectangleBorder).side.style,
      BorderStyle.solid,
    );

    final localBottom = tester.getBottomLeft(localOption).dy;
    final cloudDriveTop = tester.getTopLeft(cloudDriveOption).dy;
    expect(cloudDriveTop - localBottom, 8);
    final cloudDriveBottom = tester.getBottomLeft(cloudDriveOption).dy;
    final linkTop = tester.getTopLeft(linkOption).dy;
    expect(linkTop - cloudDriveBottom, 8);
  });

  testWidgets('本地文件入口允许一次选择多个音频和字幕文件', (tester) async {
    final picker = _RecordingFilePicker();
    FilePicker.platform = picker;

    await tester.pumpWidget(_buildApp(locale: const Locale('zh')));
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('从本地文件导入'));
    await tester.pumpAndSettle();

    expect(picker.lastAllowMultiple, isTrue);
  });

  testWidgets('本地文件入口不显示说明提示', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    // 本地文件入口已移除说明文案。
    expect(
      find.text('Choose media files from your phone or cloud drive'),
      findsNothing,
    );
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
  });

  testWidgets('网盘入口进入后展示百度网盘来源且不提前授权', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from Cloud Storage'));
    await tester.pumpAndSettle();

    expect(find.text('Import from Cloud Storage'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cloud-drive-option-baidu-netdisk')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('cloud-drive-option-baidu-netdisk')),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    expect(find.text('Baidu Netdisk'), findsOneWidget);
    expect(
      find.text('Choose media files from your Baidu cloud drive'),
      findsNothing,
    );
    expect(find.text('Connect Baidu Netdisk'), findsNothing);
  });

  testWidgets('百度网盘未授权时不显示退出登录按钮', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _NoTokenCredentialRepository(),
          ),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baidu Netdisk'));
    await tester.pumpAndSettle();

    expect(find.text('Connect Baidu Netdisk'), findsWidgets);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byTooltip('Sign out of Baidu Netdisk'), findsNothing);
  });

  testWidgets('百度网盘文件加载态使用当前语言', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(_PendingBaiduNetdiskApi()),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pump();
    await tester.pump();

    expect(find.text('正在加载百度网盘文件...'), findsOneWidget);
    expect(find.text('Loading Baidu Netdisk files...'), findsNothing);
  });

  testWidgets('百度网盘根目录使用固定文件列表布局并展示所有文件', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        CloudDriveEntry(
          fsId: 1,
          name: '公开英语学习资源',
          path: '/公开英语学习资源',
          isDirectory: true,
          size: 0,
          modifiedAt: DateTime(2026, 7, 17),
        ),
        CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/lesson.mp3',
          isDirectory: false,
          size: 1536,
          modifiedAt: DateTime(2026, 7, 18),
        ),
        CloudDriveEntry(
          fsId: 3,
          name: 'lesson.srt',
          path: '/lesson.srt',
          isDirectory: false,
          size: 256,
          modifiedAt: DateTime(2026, 7, 18),
        ),
        CloudDriveEntry(
          fsId: 5,
          name: 'review.mp3',
          path: '/review.mp3',
          isDirectory: false,
          size: 3072,
          modifiedAt: DateTime(2026, 7, 18),
        ),
        CloudDriveEntry(
          fsId: 6,
          name: 'lesson-video.mp4',
          path: '/lesson-video.mp4',
          isDirectory: false,
          size: 4096,
          modifiedAt: DateTime(2026, 7, 18),
        ),
        CloudDriveEntry(
          fsId: 4,
          name: 'notes.txt',
          path: '/notes.txt',
          isDirectory: false,
          size: 2048,
          modifiedAt: DateTime(2026, 7, 16),
        ),
      ],
    });
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    expect(find.text('全部文件'), findsOneWidget);
    expect(find.text('/'), findsNothing);
    expect(find.text('Up'), findsNothing);
    expect(find.text('网盘'), findsNothing);
    expect(find.text('返回'), findsNothing);
    expect(find.text('此文件夹中没有支持的素材文件。'), findsNothing);
    expect(find.text('公开英语学习资源'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.text('lesson.srt'), findsOneWidget);
    expect(find.text('review.mp3'), findsOneWidget);
    expect(find.text('lesson-video.mp4'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('2026/7/18 · 1.5 KB'), findsOneWidget);
    expect(find.text('2026/7/18 · 256 B'), findsOneWidget);
    expect(find.text('2026/7/18 · 3.0 KB'), findsOneWidget);
    expect(find.text('2026/7/18 · 4.0 KB'), findsOneWidget);
    expect(find.text('2026/7/16 · 2.0 KB'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '全选'), findsNothing);
    expect(find.byKey(const ValueKey('baidu-account-button')), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(4));
    final titleCenterY = tester.getCenter(find.text('全部文件')).dy;
    final avatarCenterY = tester
        .getCenter(find.byKey(const ValueKey('baidu-account-button')))
        .dy;
    expect((avatarCenterY - titleCenterY).abs(), lessThan(24));

    final notesTile = find.ancestor(
      of: find.text('notes.txt'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(notesTile).enabled, isFalse);
    final importButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '导入'),
    );
    expect(importButton.onPressed, isNull);

    await tester.tap(find.text('lesson.srt'));
    await tester.pump();

    expect(find.byKey(const ValueKey('baidu-account-button')), findsNothing);
    expect(find.widgetWithText(TextButton, '全选'), findsOneWidget);

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();

    expect(find.byKey(const ValueKey('baidu-account-button')), findsNothing);
    expect(find.widgetWithText(TextButton, '全选'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pump();

    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(
      checkboxes.where((checkbox) => checkbox.value == true),
      hasLength(4),
    );
    expect(
      find.widgetWithText(FilledButton, '导入（3 个素材，1 个字幕）'),
      findsOneWidget,
    );
  });

  testWidgets('百度网盘选中音频导入后关闭弹窗，再次打开仍显示下载状态', (tester) async {
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(tester, runner: runner);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    expect(runner.tokens, hasLength(1));
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);

    Navigator.of(tester.element(find.byType(ImportAudioFlowSheet))).pop();
    await _pumpFrames(tester);

    expect(runner.tokens.single.isCancelled, isFalse);

    await _reopenBaiduDirectory(tester);

    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('百度网盘任务行取消只取消该文件，文件恢复为可选', (tester) async {
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(tester, runner: runner);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await _pumpFrames(tester);

    expect(runner.tokens.single.isCancelled, isTrue);
    expect(find.widgetWithText(TextButton, '取消'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('百度网盘下载中的行在副标题显示当前速度', (tester) async {
    final runner = _PendingItemRunner();
    final clock = _FakeClock();
    await _pumpBaiduDirectory(tester, runner: runner, clock: clock);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    runner.reportProgress(0, 10240);
    clock.advance(const Duration(seconds: 1));
    runner.reportProgress(2048, 10240);
    await _pumpFrames(tester);

    expect(find.textContaining('2.0 KB/s'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('百度网盘本次导入成功的文件显示对勾，关闭弹窗后对勾消失', (tester) async {
    final runner = _PendingItemRunner(succeed: true);
    await _pumpBaiduDirectory(tester, runner: runner);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // 本次会话已导入的文件不可再选，不显示复选框。
    expect(find.byType(Checkbox), findsNothing);

    Navigator.of(tester.element(find.byType(ImportAudioFlowSheet))).pop();
    await _pumpFrames(tester);
    await _reopenBaiduDirectory(tester);

    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('百度网盘已导入到合集的素材仍可勾选，并以绿色标签列出所在合集', (tester) async {
    final imported = AudioItem(
      id: 'imported-lesson',
      name: 'lesson',
      audioPath: 'audios/imported/lesson.mp3',
      addedDate: DateTime(2026, 1, 1),
      importSourceType: AudioImportSourceType.cloudDrive,
      importSourceUrl: 'baidunetdisk://fs/2?path=%2Flesson.mp3',
    );
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(
      tester,
      runner: runner,
      libraryItems: [imported],
      collectionState: CollectionState(
        rawCollections: [
          Collection(
            id: 'c1',
            name: '英语',
            createdDate: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          Collection(
            id: 'c2',
            name: '口语',
            createdDate: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        audioIdsMap: const {
          'c1': ['imported-lesson'],
          'c2': ['imported-lesson'],
        },
      ),
    );

    expect(find.text('已导入到：英语、口语'), findsOneWidget);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);

    expect(runner.tokens, isEmpty);
    expect(find.textContaining('个素材'), findsOneWidget);
  });

  testWidgets('百度网盘选中的字幕与已导入的同名音频配对，不显示未匹配提示', (tester) async {
    final imported = AudioItem(
      id: 'imported-lesson',
      name: 'lesson',
      audioPath: 'audios/imported/lesson.mp3',
      addedDate: DateTime(2026, 1, 1),
      importSourceType: AudioImportSourceType.cloudDrive,
      importSourceUrl: 'baidunetdisk://fs/2?path=%2Flesson.mp3',
    );
    const srt = CloudDriveEntry(
      fsId: 9,
      name: 'lesson.srt',
      path: '/lesson.srt',
      isDirectory: false,
      size: 10,
    );
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(
      tester,
      runner: runner,
      entries: [_baiduLessonFile, srt],
      libraryItems: [imported],
    );

    await tester.tap(find.text('lesson.srt'));
    await _pumpFrames(tester);

    expect(find.text('没有匹配到同名音频'), findsNothing);
    expect(find.textContaining('1 个字幕'), findsOneWidget);

    await tester.tap(find.textContaining('1 个字幕'));
    await _pumpFrames(tester);

    expect(runner.tokens, hasLength(1));
  });

  testWidgets('百度网盘已导入的素材仍可勾选，并在副标题下方显示已导入', (tester) async {
    final imported = AudioItem(
      id: 'imported-lesson',
      name: 'lesson',
      audioPath: 'audios/imported/lesson.mp3',
      addedDate: DateTime(2026, 1, 1),
      importSourceType: AudioImportSourceType.cloudDrive,
      importSourceUrl: 'baidunetdisk://fs/2?path=%2Flesson.mp3',
    );
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(tester, runner: runner, libraryItems: [imported]);

    expect(find.text('已导入到资源库'), findsOneWidget);

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    expect(runner.tokens, hasLength(1));
  });

  testWidgets('百度网盘已勾选但没有同名音频的字幕显示未匹配提示，配对上的字幕不显示', (tester) async {
    const unmatchedSubtitle = CloudDriveEntry(
      fsId: 7,
      name: 'orphan.srt',
      path: '/orphan.srt',
      isDirectory: false,
      size: 10,
    );
    const matchedSubtitle = CloudDriveEntry(
      fsId: 8,
      name: 'lesson.srt',
      path: '/lesson.srt',
      isDirectory: false,
      size: 10,
    );
    final runner = _PendingItemRunner();
    await _pumpBaiduDirectory(
      tester,
      runner: runner,
      entries: [_baiduLessonFile, matchedSubtitle, unmatchedSubtitle],
    );

    bool hasUnmatchedLabel(String name) {
      return find
          .descendant(
            of: find.ancestor(
              of: find.text(name),
              matching: find.byType(ListTile),
            ),
            matching: find.byKey(const Key('baidu_subtitle_unmatched_label')),
          )
          .evaluate()
          .isNotEmpty;
    }

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.text('lesson.srt'));
    await _pumpFrames(tester);
    await tester.tap(find.text('orphan.srt'));
    await _pumpFrames(tester);

    expect(hasUnmatchedLabel('lesson.srt'), isFalse);
    expect(hasUnmatchedLabel('orphan.srt'), isTrue);
    expect(find.text('没有匹配到同名音频'), findsOneWidget);
  });

  testWidgets('百度网盘有进行中的导入时断开连接需确认，取消则保留下载', (tester) async {
    final runner = _PendingItemRunner();
    final credentialRepository = _TokenCredentialRepository();
    await _pumpBaiduDirectory(
      tester,
      runner: runner,
      credentialRepository: credentialRepository,
    );

    await tester.tap(find.text('lesson.mp3'));
    await _pumpFrames(tester);
    await tester.tap(find.textContaining('个素材'));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const ValueKey('baidu-account-button')));
    await _pumpFrames(tester);
    await tester.tap(find.text('断开百度网盘连接'));
    await _pumpFrames(tester);

    expect(find.text('有文件正在导入'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('取消')),
    );
    await _pumpFrames(tester);

    expect(credentialRepository.cleared, isFalse);
    expect(runner.tokens.single.isCancelled, isFalse);
  });

  testWidgets('百度网盘返回按钮在子目录返回父目录，根目录返回网盘来源', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 1,
          name: '公开英语学习资源',
          path: '/公开英语学习资源',
          isDirectory: true,
          size: 0,
        ),
      ],
      '/公开英语学习资源': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/公开英语学习资源/lesson.mp3',
          isDirectory: false,
          size: 100,
        ),
      ],
    });
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('公开英语学习资源'));
    await tester.pumpAndSettle();
    expect(find.text('公开英语学习资源'), findsOneWidget);
    expect(find.text('全部文件'), findsNothing);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(api.requestedDirs, ['/', '/公开英语学习资源', '/']);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cloud-drive-option-baidu-netdisk')),
      findsOneWidget,
    );
  });

  testWidgets('百度网盘右滑手势返回上一级', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 1,
          name: 'Folder',
          path: '/Folder',
          isDirectory: true,
          size: 0,
        ),
      ],
      '/Folder': const <CloudDriveEntry>[],
    });
    await tester.pumpWidget(
      _buildApp(
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baidu Netdisk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('baidu-netdisk')),
      const Offset(360, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(api.requestedDirs, ['/', '/Folder', '/']);
  });

  testWidgets('百度网盘账户弹窗展示资料并可直接断开连接', (tester) async {
    final credentialRepository = _TokenCredentialRepository();
    await tester.pumpWidget(
      _buildApp(
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            credentialRepository,
          ),
          baiduNetdiskApiProvider.overrideWithValue(
            _StaticBaiduNetdiskApi(
              const {'/': <CloudDriveEntry>[]},
              profile: BaiduAccountProfile(
                uk: 925415873,
                baiduName: 'rgbbook',
                netdiskName: 'Echo User',
                vipType: 0,
                avatarUrl: 'https://example.com/avatar.jpg',
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baidu Netdisk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('baidu-account-button')));
    await tester.pumpAndSettle();
    final headerButtonSize = tester.getSize(
      find.byKey(const ValueKey('baidu-account-button')),
    );
    final headerAvatarSize = tester.getSize(
      find.byKey(const ValueKey('baidu-header-avatar')),
    );
    final dialogAvatarSize = tester.getSize(
      find.byKey(const ValueKey('baidu-dialog-avatar')),
    );
    expect(headerButtonSize, headerAvatarSize);
    expect(headerAvatarSize.width, headerAvatarSize.height);
    expect(dialogAvatarSize.width, dialogAvatarSize.height);
    expect(dialogAvatarSize.width, greaterThan(headerAvatarSize.width));
    expect(find.text('Baidu username'), findsOneWidget);
    expect(find.text('rgbbook'), findsOneWidget);
    expect(find.text('Netdisk nickname'), findsOneWidget);
    expect(find.text('Echo User'), findsOneWidget);
    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('free'), findsOneWidget);
    expect(find.text('User ID'), findsNothing);
    expect(find.text('925415873'), findsNothing);

    await tester.tap(find.text('Disconnect Baidu Netdisk'));
    await tester.pumpAndSettle();

    expect(credentialRepository.cleared, isTrue);
    expect(find.text('Open Import'), findsOneWidget);
    expect(find.text('All Files'), findsNothing);
  });

  testWidgets('百度网盘账户弹窗未提供昵称时隐藏昵称行', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        overrides: dedupeOverrides([
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(
            _StaticBaiduNetdiskApi(
              const {'/': <CloudDriveEntry>[]},
              profile: const BaiduAccountProfile(
                uk: 925415873,
                baiduName: 'rgbbook',
                vipType: 0,
              ),
            ),
          ),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baidu Netdisk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('baidu-account-button')));
    await tester.pumpAndSettle();

    expect(find.text('Netdisk nickname'), findsNothing);
    expect(find.text('Not provided'), findsNothing);
  });

  testWidgets('链接入口显示 URL 表单且空输入禁用提交', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.text('Audio link'), findsOneWidget);
    expect(find.text('Paste Link'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Download and Import'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('链接导入表单弱化输入提示样式', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final fieldContext = tester.element(find.byType(TextField));
    final theme = Theme.of(fieldContext);

    expect(field.style?.fontSize, theme.textTheme.bodyMedium?.fontSize);
    expect(
      field.decoration?.hintStyle?.fontSize,
      theme.textTheme.bodyMedium?.fontSize,
    );
    expect(
      field.decoration?.hintStyle?.color,
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
    );
    expect(
      field.decoration?.labelStyle?.fontSize,
      theme.textTheme.bodySmall?.fontSize,
    );
    expect(
      field.decoration?.floatingLabelStyle?.color,
      theme.colorScheme.primary.withValues(alpha: 0.78),
    );
  });

  testWidgets('本地文件入口进入后不再展示选择按钮与网盘提示', (tester) async {
    // 选择器取消（回传 null）且无已选文件时会退回来源选择页，此处正是该路径。
    FilePicker.platform = _RecordingFilePicker();

    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    // 点入口即自动唤起选择器，面板内不再有独立的手动选择按钮和网盘提示。
    expect(
      find.byKey(const ValueKey('select-audio-file-button')),
      findsNothing,
    );
    expect(
      find.textContaining('Before choosing from a cloud drive'),
      findsNothing,
    );
  });

  testWidgets('本地文件只选中字幕时提示未选择音频且可重新选择', (tester) async {
    // 回归防线：字幕不能单独导入，此前这种情况面板既无提示、底部按钮又是禁用的
    // 「导入」，用户在 embedded 面板里没有任何重新唤起选择器的入口。
    final picker = _RecordingFilePicker(
      result: FilePickerResult([
        PlatformFile(path: '/cache/0/talk.srt', name: 'talk.srt', size: 46),
      ]),
    );
    FilePicker.platform = picker;

    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    expect(find.text('No audio file selected'), findsOneWidget);

    final button = find.widgetWithText(FilledButton, 'Select Audio File');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    // 点击可再次唤起选择器。
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(picker.pickCount, 2);
  });

  testWidgets('本地文件删空已选列表后可重新选择', (tester) async {
    final picker = _RecordingFilePicker(
      result: FilePickerResult([
        PlatformFile(path: '/cache/0/talk.mp3', name: 'talk.mp3', size: 2048),
      ]),
    );
    FilePicker.platform = picker;

    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    expect(find.text('talk.mp3'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Select Audio File'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('talk.mp3'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Select Audio File');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('链接导入页可从剪切板粘贴链接并启用提交', (tester) async {
    mockClipboardText('https://example.com/audio.mp3');
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste Link'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'https://example.com/audio.mp3');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Download and Import'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('链接导入页剪切板没有链接时显示内联提示', (tester) async {
    mockClipboardText('not a link');
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paste Link'));
    await tester.pump();

    expect(find.text('Clipboard does not have a valid link'), findsOneWidget);
  });

  testWidgets('链接导入页可返回导入方式选择页', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.text('Audio link'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Audio link'), findsNothing);
  });

  testWidgets('链接导入页空闲时底部返回按钮回到导入方式选择页', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Import Audio'), findsOneWidget);
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
    expect(find.text('Audio link'), findsNothing);
  });

  testWidgets('链接导入失败时留在表单并显示内联错误', (tester) async {
    await tester.pumpWidget(_buildApp(failImport: true));
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bad-url');
    await tester.pump();
    await tester.tap(find.text('Download and Import'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid audio link'), findsOneWidget);
    expect(find.text('Audio link'), findsOneWidget);
  });

  testWidgets('导入中锁定返回和遮罩关闭，主按钮取消后恢复导航', (tester) async {
    final controller = _PendingAudioImportController();
    await tester.pumpWidget(
      _buildApp(
        overrides: dedupeOverrides([
          audioImportControllerProvider.overrideWith(() => controller),
        ]),
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/a.mp3');
    await tester.pump();
    await tester.tap(find.text('Download and Import'));
    await tester.pump();

    expect(find.text('Cancel Import'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();

    expect(find.text('Audio link'), findsOneWidget);
    expect(controller.cancellationRequested, isFalse);

    await tester.tap(find.text('Cancel Import'));
    await tester.pumpAndSettle();

    expect(controller.cancellationRequested, isTrue);
    expect(find.text('Audio link'), findsOneWidget);
    expect(find.text('Cancel Import'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });

  testWidgets('链接导入成功后仅显示完成确认，不再提示添加字幕', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Link'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'https://example.com/a.mp3');
    await tester.pump();
    await tester.tap(find.text('Download and Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import complete'), findsOneWidget);
    // 完成页展示成功导入计数与其中带字幕数量。
    expect(find.text('1 items imported'), findsOneWidget);
    expect(find.text('0 with subtitles'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    // 字幕已自动匹配，完成页不再提示添加字幕。
    expect(find.text('Add Subtitle'), findsNothing);
    expect(find.text('Add a subtitle now for learning?'), findsNothing);
  });
}

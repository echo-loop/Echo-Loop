import 'dart:async';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_credential_repository.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_api.dart';
import 'package:echo_loop/features/baidu_netdisk/data/baidu_netdisk_import_service.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_credential_bundle.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session.dart';
import 'package:echo_loop/features/baidu_netdisk/models/baidu_oauth_session_status.dart';
import 'package:echo_loop/features/baidu_netdisk/models/cloud_drive_models.dart';
import 'package:echo_loop/features/baidu_netdisk/providers/baidu_netdisk_providers.dart';
import 'package:echo_loop/features/remote_config/remote_config.dart';
import 'package:echo_loop/features/remote_config/remote_config_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/features/audio_import/audio_import_models.dart';
import 'package:echo_loop/features/audio_import/audio_import_provider.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/providers/audio_library_provider.dart';
import 'package:echo_loop/providers/collection_provider.dart';
import 'package:echo_loop/providers/settings_provider.dart';
import 'package:echo_loop/widgets/import_audio_selection_list.dart';
import 'package:echo_loop/widgets/import_audio_sheet.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:file_picker/file_picker.dart';

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

class _TokenCredentialRepository implements BaiduCredentialRepository {
  bool cleared = false;

  @override
  Future<void> clearCredential() async {
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
  final Completer<CloudDriveListPage> _listCompleter =
      Completer<CloudDriveListPage>();

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BaiduDownloadLink> fetchDownloadLink({
    required String accessToken,
    required int fsId,
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
  bool? lastAllowMultiple;

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
    return null;
  }
}

class _StaticBaiduNetdiskApi implements BaiduNetdiskApi {
  _StaticBaiduNetdiskApi(this.pages);

  final Map<String, List<CloudDriveEntry>> pages;
  final requestedDirs = <String>[];

  @override
  Future<void> downloadToFile({
    required String accessToken,
    required String dlink,
    required String savePath,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BaiduDownloadLink> fetchDownloadLink({
    required String accessToken,
    required int fsId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CloudDriveListPage> listDirectory({
    required String accessToken,
    String dir = '/',
    int start = 0,
    int limit = 100,
  }) async {
    requestedDirs.add(dir);
    final entries = pages[dir] ?? const <CloudDriveEntry>[];
    return CloudDriveListPage(
      entries: entries,
      nextStart: entries.length,
      hasMore: false,
    );
  }
}

class _ImmediateBaiduImportService implements BaiduNetdiskImportService {
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
    final items = <AudioItem>[];
    for (final entry in entries) {
      onProgress?.call(entry, entry.size, entry.size);
      final item = AudioItem(
        id: 'baidu-${entry.fsId}',
        name: entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        audioPath: 'audios/imported/${entry.fsId}.mp3',
        addedDate: DateTime(2026, 7, 18),
        transcriptSource:
            subtitleEntries.any(
              (subtitle) =>
                  subtitle.name.replaceFirst(RegExp(r'\.[^.]+$'), '') ==
                  entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            )
            ? TranscriptSource.local
            : null,
      );
      items.add(item);
      await audioLibrary.addAudioItem(item);
      onItemResult?.call(
        CloudDriveImportItemResult.added(entry: entry, item: item),
      );
    }
    return CloudDriveImportOutcome(added: entries, addedItems: items);
  }
}

class _BlockingBaiduImportService extends _ImmediateBaiduImportService {
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
    if (entries.isNotEmpty) {
      onProgress?.call(
        entries.first,
        entries.first.size ~/ 2,
        entries.first.size,
      );
    }
    return completer.future;
  }
}

class _DuplicateBaiduImportService extends _ImmediateBaiduImportService {
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
    if (entries.isNotEmpty) {
      final entry = entries.first;
      onProgress?.call(entry, entry.size, entry.size);
      onItemResult?.call(
        CloudDriveImportItemResult.duplicate(
          entry: entry,
          existingName: '已存在课程',
        ),
      );
      return CloudDriveImportOutcome(
        added: const <CloudDriveEntry>[],
        audioDuplicates: [
          (
            attempted: entry.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            existing: '已存在课程',
          ),
        ],
      );
    }
    return const CloudDriveImportOutcome(added: <CloudDriveEntry>[]);
  }
}

class _MixedDuplicateBaiduImportService extends _ImmediateBaiduImportService {
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
    final duplicate = entries.first;
    final added = entries.last;
    onProgress?.call(duplicate, duplicate.size, duplicate.size);
    onItemResult?.call(
      CloudDriveImportItemResult.duplicate(
        entry: duplicate,
        existingName: '已存在课程',
      ),
    );
    onProgress?.call(added, added.size, added.size);
    final item = AudioItem(
      id: 'baidu-${added.fsId}',
      name: added.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      audioPath: 'audios/imported/${added.fsId}.mp3',
      addedDate: DateTime(2026, 7, 18),
    );
    await audioLibrary.addAudioItem(item);
    onItemResult?.call(
      CloudDriveImportItemResult.added(entry: added, item: item),
    );
    return CloudDriveImportOutcome(
      added: [added],
      addedItems: [item],
      audioDuplicates: [
        (
          attempted: duplicate.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
          existing: '已存在课程',
        ),
      ],
    );
  }
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
    overrides: [
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
    ],
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
        overrides: [
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ],
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
        overrides: [
          analyticsOverride(),
          appSettingsProvider.overrideWith(
            () => TestAppSettings(AppSettingsState(locale: const Locale('zh'))),
          ),
        ],
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
    expect(find.text('Import from Cloud Drive'), findsOneWidget);
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
    expect(find.text('Import from Cloud Drive'), findsNothing);
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
      find.text('Choose audio files from your phone or cloud drive'),
      findsNothing,
    );
    expect(find.text('Import from File'), findsOneWidget);
    expect(find.text('Import from Link'), findsOneWidget);
  });

  testWidgets('网盘入口进入后展示百度网盘来源且不提前授权', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from Cloud Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Import from Cloud Drive'), findsOneWidget);
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
      find.text('Choose audio files from your Baidu cloud drive'),
      findsNothing,
    );
    expect(find.text('Connect Baidu Netdisk'), findsNothing);
  });

  testWidgets('百度网盘未授权时不显示退出登录按钮', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _NoTokenCredentialRepository(),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Drive'));
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
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(_PendingBaiduNetdiskApi()),
        ],
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
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ],
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
    expect(find.text('此文件夹中没有支持的音频文件。'), findsNothing);
    expect(find.text('公开英语学习资源'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.text('lesson.srt'), findsOneWidget);
    expect(find.text('review.mp3'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('2026/7/18 · 1.5 KB'), findsOneWidget);
    expect(find.text('2026/7/18 · 256 B'), findsOneWidget);
    expect(find.text('2026/7/18 · 3.0 KB'), findsOneWidget);
    expect(find.text('2026/7/16 · 2.0 KB'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '全选'), findsNothing);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    final titleCenterY = tester.getCenter(find.text('全部文件')).dy;
    final logoutCenterY = tester.getCenter(find.byIcon(Icons.logout)).dy;
    expect((logoutCenterY - titleCenterY).abs(), lessThan(24));

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

    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.widgetWithText(TextButton, '全选'), findsOneWidget);

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();

    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.widgetWithText(TextButton, '全选'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pump();

    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(
      checkboxes.where((checkbox) => checkbox.value == true),
      hasLength(3),
    );
    expect(
      find.widgetWithText(FilledButton, '导入（2 个音频，1 个字幕）'),
      findsOneWidget,
    );
  });

  testWidgets('百度网盘点击导入先显示导入列表，完成后仍在列表内展示汇总', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/lesson.mp3',
          isDirectory: false,
          size: 1536,
        ),
        const CloudDriveEntry(
          fsId: 3,
          name: 'lesson.srt',
          path: '/lesson.srt',
          isDirectory: false,
          size: 256,
        ),
      ],
    });
    final importService = _ImmediateBaiduImportService();
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
          baiduNetdiskImportServiceProvider.overrideWithValue(importService),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频，1 个字幕）'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 个文件  ·  1.5 KB'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.text('lesson.srt'), findsNothing);
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频，1 个字幕）'));
    await tester.pumpAndSettle();

    expect(importService.importedEntries.single.name, 'lesson.mp3');
    expect(importService.importedSubtitleEntries.single.name, 'lesson.srt');
    expect(find.text('导入列表'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.textContaining('成功导入 1 个音频'), findsOneWidget);
    expect(find.textContaining('其中 1 个包含字幕'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '完成'), findsOneWidget);
  });

  testWidgets('百度网盘导入列表可移除误选音频', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/lesson.mp3',
          isDirectory: false,
          size: 1536,
        ),
        const CloudDriveEntry(
          fsId: 4,
          name: 'review.mp3',
          path: '/review.mp3',
          isDirectory: false,
          size: 2048,
        ),
      ],
    });
    final importService = _ImmediateBaiduImportService();
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
          baiduNetdiskImportServiceProvider.overrideWithValue(importService),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导入（2 个音频）'));
    await tester.pumpAndSettle();

    expect(find.text('导入列表'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.text('review.mp3'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('lesson.mp3'), findsNothing);
    expect(find.text('review.mp3'), findsOneWidget);
    expect(find.text('已选择 1 个文件  ·  2.0 KB'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频）'));
    await tester.pumpAndSettle();

    expect(importService.importedEntries.map((entry) => entry.name), [
      'review.mp3',
    ]);
  });

  testWidgets('百度网盘重复项在导入列表内展示跳过状态和重复文件名', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/lesson.mp3',
          isDirectory: false,
          size: 1536,
        ),
      ],
    });
    final importService = _DuplicateBaiduImportService();
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
          baiduNetdiskImportServiceProvider.overrideWithValue(importService),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频）'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频）'));
    await tester.pumpAndSettle();

    expect(find.text('导入列表'), findsOneWidget);
    expect(find.textContaining('成功导入 0 个音频'), findsOneWidget);
    expect(find.textContaining('跳过 1 个重复项'), findsOneWidget);
    expect(find.text('重复文件名: 已存在课程'), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_outlined), findsNothing);
    expect(find.textContaining('其中 0 个包含字幕'), findsNothing);
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    expect(find.widgetWithText(FilledButton, '完成'), findsOneWidget);
  });

  testWidgets('百度网盘成功项无字幕时摘要不误报包含字幕', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'duplicate.mp3',
          path: '/duplicate.mp3',
          isDirectory: false,
          size: 1536,
        ),
        const CloudDriveEntry(
          fsId: 3,
          name: 'duplicate.lrc',
          path: '/duplicate.lrc',
          isDirectory: false,
          size: 256,
        ),
        const CloudDriveEntry(
          fsId: 4,
          name: 'fresh.mp3',
          path: '/fresh.mp3',
          isDirectory: false,
          size: 2048,
        ),
      ],
    });
    final importService = _MixedDuplicateBaiduImportService();
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
          baiduNetdiskImportServiceProvider.overrideWithValue(importService),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('duplicate.mp3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '全选'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导入（2 个音频，1 个字幕）'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入（2 个音频，1 个字幕）'));
    await tester.pumpAndSettle();

    expect(importService.importedEntries.map((entry) => entry.name), [
      'duplicate.mp3',
      'fresh.mp3',
    ]);
    expect(importService.importedSubtitleEntries.single.name, 'duplicate.lrc');
    expect(find.textContaining('成功导入 1 个音频'), findsOneWidget);
    expect(find.textContaining('其中 1 个包含字幕'), findsNothing);
    expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
  });

  testWidgets('百度网盘导入进度留在待导入列表内展示', (tester) async {
    final api = _StaticBaiduNetdiskApi({
      '/': [
        const CloudDriveEntry(
          fsId: 2,
          name: 'lesson.mp3',
          path: '/lesson.mp3',
          isDirectory: false,
          size: 2048,
        ),
        const CloudDriveEntry(
          fsId: 3,
          name: 'lesson.srt',
          path: '/lesson.srt',
          isDirectory: false,
          size: 256,
        ),
      ],
    });
    final importService = _BlockingBaiduImportService();
    await tester.pumpWidget(
      _buildApp(
        locale: const Locale('zh'),
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
          baiduNetdiskImportServiceProvider.overrideWithValue(importService),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从网盘导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('百度网盘'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('lesson.mp3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频）'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '导入（1 个音频）'));
    await tester.pump();

    expect(find.text('已选择 1 个文件  ·  2.0 KB'), findsOneWidget);
    expect(find.text('lesson.mp3'), findsOneWidget);
    expect(find.text('正在导入 1/1：lesson.mp3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );

    importService.completer.complete(
      const CloudDriveImportOutcome(added: <CloudDriveEntry>[]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
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
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ],
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
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            _TokenCredentialRepository(),
          ),
          baiduNetdiskApiProvider.overrideWithValue(api),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Drive'));
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

  testWidgets('百度网盘退出登录确认后清除授权并关闭弹窗', (tester) async {
    final credentialRepository = _TokenCredentialRepository();
    await tester.pumpWidget(
      _buildApp(
        overrides: [
          baiduCredentialRepositoryProvider.overrideWithValue(
            credentialRepository,
          ),
          baiduNetdiskApiProvider.overrideWithValue(
            _StaticBaiduNetdiskApi(const {'/': <CloudDriveEntry>[]}),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from Cloud Drive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baidu Netdisk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out of Baidu Netdisk'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Baidu Netdisk?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
    await tester.pumpAndSettle();

    expect(credentialRepository.cleared, isTrue);
    expect(find.text('Open Import'), findsOneWidget);
    expect(find.text('All Files'), findsNothing);
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
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.text('Open Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from File'));
    await tester.pumpAndSettle();

    // 点入口即自动唤起选择器，面板内不再有手动选择按钮和网盘提示。
    expect(
      find.byKey(const ValueKey('select-audio-file-button')),
      findsNothing,
    );
    expect(
      find.widgetWithText(FilledButton, 'Select Audio File'),
      findsNothing,
    );
    expect(
      find.textContaining('Before choosing from a cloud drive'),
      findsNothing,
    );
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

    expect(
      find.text('Clipboard does not contain a valid link'),
      findsOneWidget,
    );
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
    expect(find.text('1 audio files imported'), findsOneWidget);
    expect(find.text('0 with subtitles'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    // 字幕已自动匹配，完成页不再提示添加字幕。
    expect(find.text('Add Subtitle'), findsNothing);
    expect(find.text('Add a subtitle now for learning?'), findsNothing);
  });
}

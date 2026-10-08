import 'dart:io';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:echo_loop/config/regional_service_endpoints.dart';
import 'package:echo_loop/services/pronunciation/pronunciation_library_manager.dart';
import 'package:echo_loop/services/pronunciation/pronunciation_catalog.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/runtime_endpoint_router.dart';

class _BytesDownloader implements ReliableHttpDownloader {
  _BytesDownloader(this.bytes);
  final List<int> bytes;
  final calls = <({Uri uri, bool allowResume, String savePath})>[];

  @override
  Future<ReliableDownloadResult> download({
    required Uri uri,
    required String savePath,
    Map<String, String> headers = const {},
    int? expectedSize,
    String? identityKey,
    bool allowResume = true,
    cancelToken,
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    calls.add((uri: uri, allowResume: allowResume, savePath: savePath));
    final part = File('$savePath.part');
    if (part.existsSync()) await part.delete();
    final meta = File('$savePath.part.meta.json');
    if (meta.existsSync()) await meta.delete();
    await File(savePath).writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
    return ReliableDownloadResult(
      savePath: savePath,
      bytesWritten: bytes.length,
      resumed: false,
    );
  }
}

Future<RuntimeEndpointRouter> _routerWithChinaCdn() async {
  final router = RuntimeEndpointRouter(
    endpoints: const RegionalServiceEndpoints(
      globalApiBaseUrl: 'https://global-api.example',
      chinaApiBaseUrl: 'https://china-api.example',
      globalModelCdnBaseUrl: 'https://global-cdn.example',
      chinaModelCdnBaseUrl: 'https://china-cdn.example',
    ),
  );
  return router..updateFromUserRegion(isChinaUser: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog 包含当前发音包下载规格', () {
    expect(pronunciationSpec.resourceId, 'pronunciation-v2');
    expect(pronunciationSpec.estimatedDownloadBytes, 41379389);
  });
  late Directory support;
  late Directory source;

  setUp(() {
    support = Directory.systemTemp.createTempSync('pronunciation_support_');
    source = Directory.systemTemp.createTempSync('pronunciation_source_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => call.method == 'getApplicationSupportDirectory'
              ? support.path
              : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    support.deleteSync(recursive: true);
    source.deleteSync(recursive: true);
  });

  test(
    'valid archive installs database and referenced opus atomically',
    () async {
      final zip = _validArchive(source);
      final digest = sha256.convert(zip).toString();
      final downloader = _BytesDownloader(zip);
      final manager = PronunciationLibraryManager.withDownloader(
        downloader,
        sha256: digest,
        endpointRouter: await _routerWithChinaCdn(),
      );
      Directory(
        p.join(support.path, 'pronunciation', 'v1'),
      ).createSync(recursive: true);

      final paths = await manager.downloadAndInstall();

      expect(File(paths.database).existsSync(), isTrue);
      expect(
        File(p.join(paths.audioDirectory, 'read_us.opus')).existsSync(),
        isTrue,
      );
      expect(await manager.installedPaths(), isNotNull);
      expect(
        Directory(p.join(support.path, 'pronunciation', 'v1')).existsSync(),
        isFalse,
      );
      expect(downloader.calls.single.allowResume, isTrue);
      expect(downloader.calls.single.uri.host, 'china-cdn.example');
      expect(
        downloader.calls.single.uri.path,
        '/dictionary/pronunciation-v2.zip',
      );
      manager.dispose();
    },
  );

  test('install isolate does not capture the installing callback', () async {
    final zip = _validArchive(source);
    final manager = PronunciationLibraryManager.withDownloader(
      _BytesDownloader(zip),
      sha256: sha256.convert(zip).toString(),
    );
    final installingEvents = StreamController<void>();
    var installing = false;
    installingEvents.stream.listen((_) => installing = true);

    final paths = await manager.downloadAndInstall(
      onInstalling: () => installingEvents.add(null),
    );
    await installingEvents.close();

    expect(installing, isTrue);
    expect(File(paths.database).existsSync(), isTrue);
    manager.dispose();
  });

  test(
    'archive path traversal is rejected and leaves no installed version',
    () async {
      final archive = Archive()
        ..addFile(ArchiveFile('../outside.opus', 1, [1]));
      final zip = ZipEncoder().encode(archive);
      final manager = PronunciationLibraryManager.withDownloader(
        _BytesDownloader(zip),
        sha256: sha256.convert(zip).toString(),
      );

      await expectLater(manager.downloadAndInstall(), throwsStateError);
      expect(await manager.installedPaths(), isNull);
      expect(File(p.join(support.path, 'outside.opus')).existsSync(), isFalse);
      manager.dispose();
    },
  );
}

List<int> _validArchive(Directory source) {
  final dbFile = File(p.join(source.path, 'pronunciation.sqlite'));
  final database = sqlite3.open(dbFile.path);
  database.execute('''
    CREATE TABLE pronunciation_audio (
      id INTEGER PRIMARY KEY,
      word TEXT NOT NULL COLLATE NOCASE,
      locale TEXT NOT NULL,
      audio_filename TEXT NOT NULL,
      "order" INTEGER NOT NULL
    )
  ''');
  database.execute(
    "INSERT INTO pronunciation_audio (word, locale, audio_filename, \"order\") "
    "VALUES ('read', 'us', 'read_us.opus', 1)",
  );
  database.dispose();
  final dbBytes = dbFile.readAsBytesSync();
  final archive = Archive()
    ..addFile(ArchiveFile('pronunciation.sqlite', dbBytes.length, dbBytes))
    ..addFile(ArchiveFile.directory('audio/'))
    ..addFile(ArchiveFile('audio/read_us.opus', 3, [1, 2, 3]));
  return ZipEncoder().encode(archive);
}

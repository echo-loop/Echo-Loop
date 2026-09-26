import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFileDownloader extends Mock implements FileDownloader {
  _FakeFileDownloader(this.exception);

  final TaskException exception;
  TaskStatusCallback? _statusCallback;
  String? configuredNotificationGroup;
  TaskNotification? runningNotification;
  TaskNotification? completeNotification;
  TaskNotification? errorNotification;
  TaskNotification? taskRunningNotification;
  TaskNotification? taskCompleteNotification;
  TaskNotification? taskErrorNotification;
  bool notificationProgressBar = false;
  dynamic configuredGlobalConfig;
  final enqueuedFileNames = <String>[];
  final enqueuedDisplayNames = <String?>[];

  @override
  Future<List<(String, String)>> configure({
    dynamic globalConfig,
    dynamic androidConfig,
    dynamic iOSConfig,
    dynamic desktopConfig,
  }) async {
    configuredGlobalConfig = globalConfig;
    return const <(String, String)>[];
  }

  @override
  FileDownloader configureNotificationForGroup(
    String group, {
    TaskNotification? running,
    TaskNotification? complete,
    TaskNotification? error,
    TaskNotification? paused,
    TaskNotification? canceled,
    bool progressBar = false,
    bool tapOpensFile = false,
    String groupNotificationId = '',
  }) {
    configuredNotificationGroup = group;
    runningNotification = running;
    completeNotification = complete;
    errorNotification = error;
    notificationProgressBar = progressBar;
    return this;
  }

  @override
  FileDownloader configureNotificationForTask(
    Task task, {
    TaskNotification? running,
    TaskNotification? complete,
    TaskNotification? error,
    TaskNotification? paused,
    TaskNotification? canceled,
    bool progressBar = false,
    bool tapOpensFile = false,
    String groupNotificationId = '',
  }) {
    taskRunningNotification = running;
    taskCompleteNotification = complete;
    taskErrorNotification = error;
    notificationProgressBar = progressBar;
    return this;
  }

  @override
  FileDownloader registerCallbacks({
    String group = FileDownloader.defaultGroup,
    TaskStatusCallback? taskStatusCallback,
    TaskProgressCallback? taskProgressCallback,
    TaskNotificationTapCallback? taskNotificationTapCallback,
  }) {
    _statusCallback = taskStatusCallback;
    return this;
  }

  @override
  Future<FileDownloader> trackTasksInGroup(
    String group, {
    bool markDownloadedComplete = true,
  }) async => this;

  @override
  Future<void> start({
    bool doTrackTasks = true,
    bool markDownloadedComplete = true,
    bool doRescheduleKilledTasks = true,
    bool autoCleanDatabase = false,
  }) async {}

  @override
  Future<bool> enqueue(Task task) async {
    if (task case final DownloadTask downloadTask) {
      enqueuedFileNames.add(downloadTask.filename);
      enqueuedDisplayNames.add(downloadTask.displayName);
    }
    final callback = _statusCallback;
    if (callback == null) {
      throw StateError('status callback was not registered');
    }
    if (task case final DownloadTask downloadTask) {
      callback(TaskStatusUpdate(downloadTask, TaskStatus.failed, exception));
    } else {
      throw StateError('expected a DownloadTask');
    }
    return true;
  }
}

class _FakeMacOSSystemDownloadClient implements MacOSSystemDownloadClient {
  Uri? uri;
  String? savePath;
  String? displayName;
  String? completeNotificationTitle;
  String? failedNotificationTitle;
  Map<String, String>? headers;

  @override
  Future<BackgroundDownloadResult> download({
    required Uri uri,
    required String savePath,
    required String displayName,
    required String completeNotificationTitle,
    required String failedNotificationTitle,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    this.uri = uri;
    this.savePath = savePath;
    this.displayName = displayName;
    this.completeNotificationTitle = completeNotificationTitle;
    this.failedNotificationTitle = failedNotificationTitle;
    this.headers = headers;
    onProgress?.call(6, 12);
    return const BackgroundDownloadResult(
      status: BackgroundDownloadStatus.complete,
    );
  }
}

class _FakeRunner implements BackgroundDownloadRunner {
  _FakeRunner({
    this.result = const BackgroundDownloadResult(
      status: BackgroundDownloadStatus.complete,
    ),
    this.bytes = const <int>[1, 2],
    this.createFile = true,
    this.totalBytes,
  });

  final BackgroundDownloadResult result;
  final List<int> bytes;
  final bool createFile;
  final int? totalBytes;
  Uri? uri;
  String? savePath;
  Map<String, String>? headers;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    this.uri = uri;
    this.savePath = savePath;
    this.headers = headers;
    onProgress?.call(totalBytes == null ? 0 : bytes.length, totalBytes);
    if (createFile && result.status == BackgroundDownloadStatus.complete) {
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsBytes(bytes);
    }
    return result;
  }
}

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('background-download-');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  test(
    'accepts a completed file without comparing an external expected size',
    () async {
      AppLogger.instance.clear();
      final runner = _FakeRunner(
        result: const BackgroundDownloadResult(
          status: BackgroundDownloadStatus.complete,
          statusCode: 200,
          receivedBytes: 2,
          expectedBytes: 2,
          contentType: 'audio/mpeg',
        ),
        bytes: const <int>[1, 2],
      );
      final service = BackgroundFileDownloadService(runner: runner);
      final target = File('${dataDir.path}/audio.mp3');

      await service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: target.path,
      );

      expect(await target.readAsBytes(), const <int>[1, 2]);
      expect(
        AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'BackgroundFileDownload' &&
              entry.message.contains('download complete host=example.com') &&
              entry.message.contains('statusCode=200') &&
              entry.message.contains('bytes=2') &&
              entry.message.contains('expectedBytes=2') &&
              entry.message.contains('contentType=audio/mpeg'),
        ),
        isTrue,
      );
    },
  );

  test(
    'fails if the platform reports completion but target file is missing',
    () async {
      final service = BackgroundFileDownloadService(
        runner: _FakeRunner(createFile: false),
      );

      await expectLater(
        service.download(
          uri: Uri.parse('https://example.com/audio.mp3'),
          savePath: '${dataDir.path}/missing.mp3',
        ),
        throwsA(isA<BackgroundFileDownloadException>()),
      );
    },
  );

  test(
    'forwards headers and unknown-size progress without inventing a total',
    () async {
      final runner = _FakeRunner(totalBytes: null);
      final service = BackgroundFileDownloadService(runner: runner);
      (int, int?)? progress;

      await service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        headers: const <String, String>{'Authorization': 'Bearer token'},
        onProgress: (received, total) => progress = (received, total),
      );

      expect(runner.headers, const <String, String>{
        'Authorization': 'Bearer token',
      });
      expect(progress, (0, null));
    },
  );

  test(
    'maps not-found, failed, and canceled task results to explicit errors',
    () async {
      Future<void> expectStatus(
        BackgroundDownloadResult result,
        Matcher matcher,
      ) async {
        final service = BackgroundFileDownloadService(
          runner: _FakeRunner(result: result, createFile: false),
        );
        await expectLater(
          service.download(
            uri: Uri.parse('https://example.com/audio.mp3'),
            savePath: '${dataDir.path}/audio.mp3',
          ),
          throwsA(matcher),
        );
      }

      await expectStatus(
        const BackgroundDownloadResult(
          status: BackgroundDownloadStatus.notFound,
        ),
        isA<BackgroundFileDownloadException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      );
      await expectStatus(
        const BackgroundDownloadResult(status: BackgroundDownloadStatus.failed),
        isA<BackgroundFileDownloadException>(),
      );
      await expectStatus(
        const BackgroundDownloadResult(
          status: BackgroundDownloadStatus.canceled,
        ),
        isA<BackgroundFileDownloadException>().having(
          (error) => error.isCanceled,
          'isCanceled',
          isTrue,
        ),
      );
    },
  );

  test(
    'native batch queue submits every file and limits each group to one',
    () async {
      final downloader = _FakeFileDownloader(
        TaskFileSystemException('simulated failure'),
      );
      final service = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: downloader,
        ),
      );

      final outcomes = await service.downloadBatch(
        requests: [
          BackgroundFileDownloadRequest(
            id: 'first',
            uri: Uri.parse('https://example.com/first.mp3'),
            savePath: '${dataDir.path}/first.mp3',
            displayName: 'First episode.mp3',
          ),
          BackgroundFileDownloadRequest(
            id: 'second',
            uri: Uri.parse('https://example.com/second.mp3'),
            savePath: '${dataDir.path}/second.mp3',
          ),
        ],
      );

      expect(downloader.enqueuedFileNames, ['first.mp3', 'second.mp3']);
      expect(downloader.enqueuedDisplayNames, [
        'First episode.mp3',
        'second.mp3',
      ]);
      expect(downloader.configuredGlobalConfig, (
        Config.holdingQueue,
        (null, null, 1),
      ));
      expect(outcomes.map((outcome) => outcome.request.id), [
        'first',
        'second',
      ]);
      expect(outcomes.every((outcome) => outcome.error != null), isTrue);
    },
  );

  test('configures localized notifications on each background task', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('simulated failure'),
    );
    final runner = PluginBackgroundDownloadRunner(
      resolveDataDir: () async => dataDir,
      downloader: downloader,
      resolveNotificationLabels: () async =>
          const BackgroundFileDownloadNotificationLabels(
            running: '正在下载',
            complete: '下载完成',
            failed: '下载失败',
          ),
    );

    await runner.enqueue(
      uri: Uri.parse('https://example.com/audio.mp3'),
      savePath: '${dataDir.path}/audio.mp3',
      displayName: '听力素材',
      headers: const <String, String>{},
      onProgress: null,
      cancelToken: null,
    );

    expect(downloader.taskRunningNotification?.title, '正在下载');
    expect(downloader.taskRunningNotification?.body, '{displayName}');
    expect(downloader.taskCompleteNotification?.title, '下载完成');
    expect(downloader.taskErrorNotification?.title, '下载失败');
    expect(downloader.notificationProgressBar, isTrue);
  });

  test(
    'does not classify a wrapped SocketException as a storage failure',
    () async {
      AppLogger.instance.clear();
      final downloader = _FakeFileDownloader(
        TaskFileSystemException(
          'ClientException with SocketException: Connection refused, uri=https://example.com/file.mp3?token=secret',
        ),
      );
      final service = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: downloader,
        ),
      );

      await expectLater(
        service.download(
          uri: Uri.parse(
            'https://example.com/file.mp3?source=podcast&token=secret',
          ),
          savePath: '${dataDir.path}/audio.mp3',
        ),
        throwsA(
          isA<BackgroundFileDownloadException>()
              .having(
                (error) => error.isStorageFailure,
                'storage failure',
                isFalse,
              )
              .having(
                (error) => error.message,
                'safe message',
                'Background download failed.',
              ),
        ),
      );
      expect(downloader.configuredNotificationGroup, 'echo-loop-user-files');
      expect(downloader.runningNotification?.title, 'Downloading');
      expect(downloader.runningNotification?.body, '{displayName}');
      expect(downloader.notificationProgressBar, isTrue);
      expect(
        AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'BackgroundFileDownload' &&
              entry.message.contains(
                'download queued host=example.com url=https://example.com/file.mp3?source=podcast&token=REDACTED',
              ),
        ),
        isTrue,
      );
      expect(
        AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'BackgroundFileDownload' &&
              entry.message.contains('task status=failed host=example.com') &&
              entry.message.contains('url=https://example.com/file.mp3?') &&
              entry.message.contains('file=audio.mp3 taskId=') &&
              entry.message.contains('durationMs='),
        ),
        isTrue,
      );
      expect(
        AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'BackgroundFileDownload' &&
              entry.message.contains('causeType=TaskFileSystemException') &&
              entry.message.contains('Connection refused'),
        ),
        isTrue,
      );
      expect(
        AppLogger.instance.entries.any(
          (entry) => entry.message.contains('token=secret'),
        ),
        isFalse,
      );
    },
  );

  test('recognizes an explicit no-space filesystem failure', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('No space left on device (errno = 28)'),
    );
    final service = BackgroundFileDownloadService(
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );

    await expectLater(
      service.download(
        uri: Uri.parse('https://example.com/file.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
      ),
      throwsA(
        isA<BackgroundFileDownloadException>().having(
          (error) => error.isStorageFailure,
          'storage failure',
          isTrue,
        ),
      ),
    );
  });

  test(
    'macOS runner delegates downloads without configuring a proxy',
    () async {
      final client = _FakeMacOSSystemDownloadClient();
      final runner = MacOSSystemDownloadRunner(
        resolveDataDir: () async => dataDir,
        client: client,
        resolveNotificationLabels: () async =>
            const BackgroundFileDownloadNotificationLabels(
              running: '正在下载',
              complete: '下载完成',
              failed: '下载失败',
            ),
      );
      final progress = <(int, int?)>[];

      final result = await runner.enqueue(
        uri: Uri.parse('https://cdn.example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        displayName: 'Audio lesson.mp3',
        headers: const <String, String>{'Authorization': 'Bearer test'},
        onProgress: (received, total) => progress.add((received, total)),
        cancelToken: null,
      );

      expect(result.status, BackgroundDownloadStatus.complete);
      expect(client.uri, Uri.parse('https://cdn.example.com/audio.mp3'));
      expect(client.savePath, '${dataDir.path}/audio.mp3');
      expect(client.displayName, 'Audio lesson.mp3');
      expect(client.completeNotificationTitle, '下载完成');
      expect(client.failedNotificationTitle, '下载失败');
      expect(client.headers, const <String, String>{
        'Authorization': 'Bearer test',
      });
      expect(progress, <(int, int?)>[(6, 12)]);
    },
  );
}

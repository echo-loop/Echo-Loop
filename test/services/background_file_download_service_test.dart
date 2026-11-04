import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/services/download_completion_notifier.dart';
import 'package:echo_loop/services/resource_download_registry.dart';
import 'package:echo_loop/services/system_proxy.dart';
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

  /// 系统代理相关的 configure 调用，按调用顺序记录。
  final proxyConfigs = <List<(String, dynamic)>>[];

  /// 代理配置与入队的先后顺序，用于验证代理先于入队生效。
  final events = <String>[];
  final enqueuedFileNames = <String>[];
  final enqueuedDisplayNames = <String?>[];
  final enqueuedTasks = <DownloadTask>[];
  final calls = <String>[];
  bool? startAutoCleanDatabase;
  TaskStatusCallback? get statusCallback => _statusCallback;
  TaskProgressCallback? progressCallback;

  /// 测试可接管入队过程，手动回放进度与状态；为空时按 [exception] 直接失败。
  void Function(DownloadTask task)? onEnqueue;

  /// 启动时清理遗留任务的调用记录。
  final resetGroups = <String>[];

  /// 被取消的插件任务 ID，用于验证取消会直达插件。
  final cancelledTaskIds = <String>[];

  @override
  Future<bool> cancelTaskWithId(String taskId) async {
    cancelledTaskIds.add(taskId);
    return true;
  }

  @override
  Future<int> reset({String group = FileDownloader.defaultGroup}) async {
    resetGroups.add(group);
    return 0;
  }

  @override
  Future<List<(String, String)>> configure({
    dynamic globalConfig,
    dynamic androidConfig,
    dynamic iOSConfig,
    dynamic desktopConfig,
  }) async {
    final entries = (globalConfig as List).cast<(String, dynamic)>();
    if (entries.any((entry) => entry.$1 == Config.proxy)) {
      proxyConfigs.add(entries);
      events.add('proxy');
    } else {
      calls.add('configure');
      configuredGlobalConfig = globalConfig;
    }
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
    calls.add('registerCallbacks');
    _statusCallback = taskStatusCallback;
    progressCallback = taskProgressCallback;
    return this;
  }

  @override
  Future<FileDownloader> trackTasksInGroup(
    String group, {
    bool markDownloadedComplete = true,
  }) async {
    calls.add('trackTasksInGroup');
    return this;
  }

  @override
  Future<void> start({
    bool doTrackTasks = true,
    bool markDownloadedComplete = true,
    bool doRescheduleKilledTasks = true,
    bool autoCleanDatabase = false,
  }) async {
    calls.add('start');
    startAutoCleanDatabase = autoCleanDatabase;
  }

  @override
  Future<bool> enqueue(Task task) async {
    events.add('enqueue');
    if (task case final DownloadTask downloadTask) {
      enqueuedFileNames.add(downloadTask.filename);
      enqueuedDisplayNames.add(downloadTask.displayName);
      enqueuedTasks.add(downloadTask);
    }
    final callback = _statusCallback;
    if (callback == null) {
      throw StateError('status callback was not registered');
    }
    if (task case final DownloadTask downloadTask) {
      final hook = onEnqueue;
      if (hook != null) {
        hook(downloadTask);
        return true;
      }
      callback(TaskStatusUpdate(downloadTask, TaskStatus.failed, exception));
    } else {
      throw StateError('expected a DownloadTask');
    }
    return true;
  }
}

/// 记录应用补发的终态通知。
class _RecordingCompletionNotifier implements DownloadCompletionNotifier {
  final notices = <(String taskId, String title, String body)>[];

  @override
  Future<void> notify({
    required String taskId,
    required String title,
    required String body,
  }) async {
    notices.add((taskId, title, body));
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
    this.progressEvents,
  });

  final BackgroundDownloadResult result;
  final List<int> bytes;
  final bool createFile;
  final int? totalBytes;
  final List<(int, int?)>? progressEvents;
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
    final events = progressEvents;
    if (events == null) {
      onProgress?.call(totalBytes == null ? 0 : bytes.length, totalBytes);
    } else {
      for (final (received, total) in events) {
        onProgress?.call(received, total);
      }
    }
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
    'coalesces progress bursts and publishes the final byte counts',
    () async {
      const finalBytes = 1000;
      final progressEvents = List<(int, int?)>.generate(
        finalBytes,
        (index) => (index + 1, null),
        growable: false,
      );
      final runner = _FakeRunner(
        bytes: List<int>.filled(finalBytes, 0),
        progressEvents: progressEvents,
        result: const BackgroundDownloadResult(
          status: BackgroundDownloadStatus.complete,
          receivedBytes: finalBytes,
          expectedBytes: finalBytes,
        ),
      );
      final service = BackgroundFileDownloadService(runner: runner);
      final progress = <(int, int?)>[];

      await service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(progress.length, lessThan(progressEvents.length));
      expect(progress.first, (0, null));
      expect(progress.last, (finalBytes, finalBytes));
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

  test('native batch queue submits every file and caps concurrent downloads at two', () async {
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
    expect(downloader.configuredGlobalConfig, [
      (Config.holdingQueue, (2, null, null)),
    ]);
    expect(outcomes.map((outcome) => outcome.request.id), ['first', 'second']);
    expect(outcomes.every((outcome) => outcome.error != null), isTrue);
  });

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

  test('通知文案解析失败时回退英文，下载仍可入队（fr_CN 回归）', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('simulated failure'),
    );
    final runner = PluginBackgroundDownloadRunner(
      resolveDataDir: () async => dataDir,
      downloader: downloader,
      resolveNotificationLabels: () async => throw FlutterError(
        'AppLocalizations.delegate failed to load unsupported locale "fr_CN".',
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

    expect(downloader.enqueuedFileNames, ['audio.mp3']);
    expect(downloader.runningNotification?.title, 'Downloading');
    expect(downloader.taskRunningNotification?.title, 'Downloading');
    expect(downloader.taskErrorNotification?.title, 'Download failed');
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

  test('enqueues with resume and retries, and starts the queue with database cleanup', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('simulated failure'),
    );
    final service = BackgroundFileDownloadService(
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );

    await expectLater(
      service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
      ),
      throwsA(isA<BackgroundFileDownloadException>()),
    );

    final task = downloader.enqueuedTasks.single;
    expect(task.allowPause, isTrue);
    expect(task.retries, 2);
    expect(task.group, kUserFilesDownloadGroup);
    expect(downloader.startAutoCleanDatabase, isTrue);
    expect(downloader.resetGroups, [kUserFilesDownloadGroup]);
    expect(downloader.calls, [
      'configure',
      'registerCallbacks',
      'trackTasksInGroup',
      'start',
    ]);
  });

  test(
    'keeps waiting while the plugin retries and completes on success',
    () async {
      final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
      downloader.onEnqueue = (task) {
        final callback = downloader.statusCallback!;
        callback(TaskStatusUpdate(task, TaskStatus.waitingToRetry));
        callback(TaskStatusUpdate(task, TaskStatus.running));
        File('${dataDir.path}/audio.mp3').writeAsBytesSync(const <int>[1, 2]);
        callback(TaskStatusUpdate(task, TaskStatus.complete));
      };
      final service = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: downloader,
        ),
      );

      await service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
      );

      expect(await File('${dataDir.path}/audio.mp3').readAsBytes(), const [
        1,
        2,
      ]);
    },
  );

  test(
    'ignores plugin sentinel progress so already received bytes are kept',
    () async {
      AppLogger.instance.clear();
      final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
      final progress = <(int, int?)>[];
      downloader.onEnqueue = (task) {
        downloader.progressCallback!(TaskProgressUpdate(task, 0.5, 100));
        // 等待重试时插件以负数哨兵上报进度，expectedFileSize 仍为真实总大小。
        downloader.progressCallback!(
          TaskProgressUpdate(task, progressWaitingToRetry, 100),
        );
        downloader.statusCallback!(
          TaskStatusUpdate(
            task,
            TaskStatus.failed,
            TaskFileSystemException('simulated failure'),
          ),
        );
      };
      final service = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: downloader,
        ),
      );

      await expectLater(
        service.download(
          uri: Uri.parse('https://example.com/audio.mp3'),
          savePath: '${dataDir.path}/audio.mp3',
          onProgress: (received, total) => progress.add((received, total)),
        ),
        throwsA(isA<BackgroundFileDownloadException>()),
      );

      // 首个 (0, null) 是服务入队时的初始回报；哨兵进度不应产生新的回报。
      expect(progress, [(0, null), (50, 100)]);
      expect(
        AppLogger.instance.entries.any(
          (entry) =>
              entry.tag == 'BackgroundFileDownload' &&
              entry.message.contains('bytes=50 expectedBytes=100'),
        ),
        isTrue,
      );
    },
  );

  test('把插件状态映射为资源阶段，并随状态变化推送给登记表', () async {
    final registry = ResourceDownloadRegistry();
    final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
    downloader.onEnqueue = (task) {
      final callback = downloader.statusCallback!;
      callback(TaskStatusUpdate(task, TaskStatus.enqueued));
      callback(TaskStatusUpdate(task, TaskStatus.running));
      callback(TaskStatusUpdate(task, TaskStatus.waitingToRetry));
      callback(
        TaskStatusUpdate(
          task,
          TaskStatus.failed,
          TaskFileSystemException('simulated failure'),
        ),
      );
    };
    final service = BackgroundFileDownloadService(
      registry: registry,
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );
    final seen = <ResourceDownloadState>[];
    final subscription = registry.changes.listen(seen.add);

    await expectLater(
      service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
      ),
      throwsA(isA<BackgroundFileDownloadException>()),
    );
    await subscription.cancel();

    // 有空闲名额时提交即进入下载中；平台的 enqueued 回报不会把它降级为排队。
    expect(seen.map((state) => state.runtimeType).toList(), [
      ResourceQueued,
      ResourceRunning,
      ResourceRunning,
      ResourceWaitingToRetry,
      ResourceFailed,
    ]);
  });

  test('插件任务的 metaData 记录资源标识，便于调试页归类', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('simulated failure'),
    );
    final service = BackgroundFileDownloadService(
      registry: ResourceDownloadRegistry(),
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );

    await expectLater(
      service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        resourceKey: 'audio:42',
      ),
      throwsA(isA<BackgroundFileDownloadException>()),
    );

    expect(downloader.enqueuedTasks.single.metaData, 'audio:42');
  });

  test('取消发生在入队返回之前时，会再次取消插件任务', () async {
    final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
    final cancelToken = CancelToken();
    downloader.onEnqueue = (task) {
      // 插件在入队期间收到取消：此时取消回调可能已经找不到任务。
      cancelToken.cancel('user');
      downloader.statusCallback!(TaskStatusUpdate(task, TaskStatus.canceled));
    };
    final service = BackgroundFileDownloadService(
      registry: ResourceDownloadRegistry(),
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );

    await expectLater(
      service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        cancelToken: cancelToken,
      ),
      throwsA(isA<BackgroundFileDownloadException>()),
    );

    final taskId = downloader.enqueuedTasks.single.taskId;
    // 一次来自取消回调，一次来自入队返回后的补救取消。
    expect(downloader.cancelledTaskIds, [taskId, taskId]);
  });

  test('同一个 FileDownloader 只清理一次遗留任务', () async {
    final downloader = _FakeFileDownloader(
      TaskFileSystemException('simulated failure'),
    );
    final first = PluginBackgroundDownloadRunner(
      resolveDataDir: () async => dataDir,
      downloader: downloader,
    );
    final second = PluginBackgroundDownloadRunner(
      resolveDataDir: () async => dataDir,
      downloader: downloader,
    );

    for (final runner in [first, second]) {
      await expectLater(
        runner.enqueue(
          uri: Uri.parse('https://example.com/a.mp3'),
          savePath: '${dataDir.path}/a.mp3',
          headers: const <String, String>{},
          onProgress: null,
          cancelToken: null,
        ),
        completes,
      );
    }

    expect(downloader.resetGroups, [kUserFilesDownloadGroup]);
  });

  test('完成时插件发出的未知大小进度不会覆盖已知的总大小', () async {
    final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
    downloader.onEnqueue = (task) {
      downloader.progressCallback!(TaskProgressUpdate(task, 0.5, 100));
      // 插件在完成时会补发一次 progress=1.0、expectedFileSize=-1 的进度。
      downloader.progressCallback!(TaskProgressUpdate(task, progressComplete));
      File('${dataDir.path}/audio.mp3').writeAsBytesSync(const <int>[1, 2]);
      downloader.statusCallback!(TaskStatusUpdate(task, TaskStatus.complete));
    };
    final service = BackgroundFileDownloadService(
      registry: ResourceDownloadRegistry(),
      runner: PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
      ),
    );
    final progress = <(int, int?)>[];

    await service.download(
      uri: Uri.parse('https://example.com/audio.mp3'),
      savePath: '${dataDir.path}/audio.mp3',
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(progress.last, (100, 100));
  });

  group('桌面端终态通知（插件不发通知时由应用补发）', () {
    const labels = BackgroundFileDownloadNotificationLabels(
      running: '正在下载',
      complete: '下载完成',
      failed: '下载失败',
    );

    test('下载完成后补发完成通知，正文为任务显示名', () async {
      final downloader = _FakeFileDownloader(TaskFileSystemException('unused'));
      final notifier = _RecordingCompletionNotifier();
      downloader.onEnqueue = (task) {
        File('${dataDir.path}/audio.mp3').writeAsBytesSync(const <int>[1, 2]);
        downloader.statusCallback!(TaskStatusUpdate(task, TaskStatus.complete));
      };
      final service = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: downloader,
          resolveNotificationLabels: () async => labels,
          completionNotifier: notifier,
        ),
      );

      await service.download(
        uri: Uri.parse('https://example.com/audio.mp3'),
        savePath: '${dataDir.path}/audio.mp3',
        displayName: '听力素材',
      );

      expect(notifier.notices.single.$2, '下载完成');
      expect(notifier.notices.single.$3, '听力素材');
    });

    test('下载失败补发失败通知；用户取消不提示', () async {
      final failedDownloader = _FakeFileDownloader(
        TaskFileSystemException('unused'),
      );
      final failedNotifier = _RecordingCompletionNotifier();
      failedDownloader.onEnqueue = (task) {
        failedDownloader.statusCallback!(
          TaskStatusUpdate(
            task,
            TaskStatus.failed,
            TaskFileSystemException('simulated failure'),
          ),
        );
      };
      final failedService = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: failedDownloader,
          resolveNotificationLabels: () async => labels,
          completionNotifier: failedNotifier,
        ),
      );

      await expectLater(
        failedService.download(
          uri: Uri.parse('https://example.com/audio.mp3'),
          savePath: '${dataDir.path}/audio.mp3',
        ),
        throwsA(isA<BackgroundFileDownloadException>()),
      );
      expect(failedNotifier.notices.single.$2, '下载失败');

      final canceledDownloader = _FakeFileDownloader(
        TaskFileSystemException('unused'),
      );
      final canceledNotifier = _RecordingCompletionNotifier();
      canceledDownloader.onEnqueue = (task) {
        canceledDownloader.statusCallback!(
          TaskStatusUpdate(task, TaskStatus.canceled),
        );
      };
      final canceledService = BackgroundFileDownloadService(
        runner: PluginBackgroundDownloadRunner(
          resolveDataDir: () async => dataDir,
          downloader: canceledDownloader,
          resolveNotificationLabels: () async => labels,
          completionNotifier: canceledNotifier,
        ),
      );

      await expectLater(
        canceledService.download(
          uri: Uri.parse('https://example.com/audio.mp3'),
          savePath: '${dataDir.path}/audio.mp3',
        ),
        throwsA(isA<BackgroundFileDownloadException>()),
      );
      expect(canceledNotifier.notices, isEmpty);
    });
  });

  group('系统代理', () {
    /// 触发一次下载；假插件固定返回失败，这里只关心入队前的代理配置。
    Future<void> downloadOnce(
      PluginBackgroundDownloadRunner runner,
      Directory dataDir,
      String id,
    ) {
      final service = BackgroundFileDownloadService(runner: runner);
      return expectLater(
        service.download(
          uri: Uri.parse('https://example.com/$id.mp3'),
          savePath: '${dataDir.path}/$id.mp3',
        ),
        throwsA(anything),
      );
    }

    test('开启系统代理时，入队前把代理端点写入插件配置', () async {
      final dataDir = await Directory.systemTemp.createTemp('proxy_on_');
      addTearDown(() => dataDir.delete(recursive: true));
      final downloader = _FakeFileDownloader(
        TaskFileSystemException('simulated failure'),
      );
      final runner = PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
        resolveDownloadProxy: () async =>
            const SystemProxyEndpoint(host: '127.0.0.1', port: 7897),
      );

      await downloadOnce(runner, dataDir, 'episode');

      expect(downloader.proxyConfigs, [
        [(Config.proxy, ('127.0.0.1', 7897))],
      ]);
      // 代理配置必须早于入队，否则本次任务仍会直连。
      expect(downloader.events, ['proxy', 'enqueue']);
    });

    test('关闭系统代理时，明确清除插件中的代理配置', () async {
      final dataDir = await Directory.systemTemp.createTemp('proxy_off_');
      addTearDown(() => dataDir.delete(recursive: true));
      final downloader = _FakeFileDownloader(
        TaskFileSystemException('simulated failure'),
      );
      final runner = PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
        resolveDownloadProxy: () async => null,
      );

      await downloadOnce(runner, dataDir, 'episode');

      expect(downloader.proxyConfigs, [
        [(Config.proxy, false)],
      ]);
    });

    test('代理端点未变化时，连续下载只配置一次', () async {
      final dataDir = await Directory.systemTemp.createTemp('proxy_same_');
      addTearDown(() => dataDir.delete(recursive: true));
      final downloader = _FakeFileDownloader(
        TaskFileSystemException('simulated failure'),
      );
      final runner = PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
        resolveDownloadProxy: () async =>
            const SystemProxyEndpoint(host: '127.0.0.1', port: 7897),
      );

      await downloadOnce(runner, dataDir, 'first');
      await downloadOnce(runner, dataDir, 'second');

      expect(downloader.proxyConfigs, hasLength(1));
    });

    test('用户在两次下载之间切换开关时，下一次下载生效', () async {
      final dataDir = await Directory.systemTemp.createTemp('proxy_switch_');
      addTearDown(() => dataDir.delete(recursive: true));
      final downloader = _FakeFileDownloader(
        TaskFileSystemException('simulated failure'),
      );
      var enabled = false;
      final runner = PluginBackgroundDownloadRunner(
        resolveDataDir: () async => dataDir,
        downloader: downloader,
        resolveDownloadProxy: () async => enabled
            ? const SystemProxyEndpoint(host: '127.0.0.1', port: 7897)
            : null,
      );

      await downloadOnce(runner, dataDir, 'first');
      enabled = true;
      await downloadOnce(runner, dataDir, 'second');

      expect(downloader.proxyConfigs, [
        [(Config.proxy, false)],
        [(Config.proxy, ('127.0.0.1', 7897))],
      ]);
    });
  });
}

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'app_logger.dart';
import '../utils/app_data_dir.dart';

typedef BackgroundFileDownloadProgress =
    void Function(int receivedBytes, int? totalBytes);
typedef BackgroundFileDownloadBatchProgress =
    void Function(String taskId, int receivedBytes, int? totalBytes);

/// 用户文件后台下载通知使用的本地化状态标题。
class BackgroundFileDownloadNotificationLabels {
  const BackgroundFileDownloadNotificationLabels({
    required this.running,
    required this.complete,
    required this.failed,
  });

  final String running;
  final String complete;
  final String failed;
}

typedef BackgroundFileDownloadNotificationLabelResolver =
    Future<BackgroundFileDownloadNotificationLabels> Function();

/// 提交到共享后台下载队列的单个文件请求。
class BackgroundFileDownloadRequest {
  const BackgroundFileDownloadRequest({
    required this.id,
    required this.uri,
    required this.savePath,
    this.displayName,
    this.headers = const <String, String>{},
  });

  /// 用于关联该请求进度和结果的稳定标识。
  final String id;
  final Uri uri;
  final String savePath;

  /// 通知中向用户展示的名称；为空时使用临时文件名。
  final String? displayName;
  final Map<String, String> headers;
}

/// 后台批量下载中单个请求的最终结果。
class BackgroundFileDownloadItemResult {
  const BackgroundFileDownloadItemResult({required this.request, this.error});

  final BackgroundFileDownloadRequest request;
  final BackgroundFileDownloadException? error;

  bool get succeeded => error == null;
}

/// 后台文件任务的最终状态。
enum BackgroundDownloadStatus { complete, notFound, failed, canceled }

/// 下载器返回的最终结果，保留平台错误供业务层映射。
class BackgroundDownloadResult {
  const BackgroundDownloadResult({
    required this.status,
    this.statusCode,
    this.receivedBytes,
    this.expectedBytes,
    this.contentType,
    this.errorDomain,
    this.errorCode,
    this.message,
    this.cause,
    this.isStorageFailure = false,
  });

  final BackgroundDownloadStatus status;
  final int? statusCode;
  final int? receivedBytes;
  final int? expectedBytes;
  final String? contentType;
  final String? errorDomain;
  final int? errorCode;
  final String? message;
  final Object? cause;
  final bool isStorageFailure;
}

/// 适配器可替换接口，供业务测试使用，不暴露插件状态类型。
abstract interface class BackgroundDownloadRunner {
  /// 将任务交给平台下载队列并等待终态。
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  });
}

/// 平台 runner 可选实现此能力，在 Dart 等待任务完成前先将整批任务提交到原生队列。
abstract interface class BackgroundDownloadBatchRunner {
  Future<List<BackgroundDownloadResult>> enqueueBatch({
    required List<BackgroundFileDownloadRequest> requests,
    required BackgroundFileDownloadBatchProgress? onProgress,
    required CancelToken? cancelToken,
  });
}

/// 文件后台下载服务。
///
/// 应用层只依据平台下载任务的终态和目标文件是否存在判断成功，不拿来源
/// 元数据中的文件大小作为失败条件。
class BackgroundFileDownloadService {
  BackgroundFileDownloadService({
    BackgroundDownloadRunner? runner,
    Future<Directory> Function()? resolveDataDir,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
  }) : _runner =
           runner ?? _defaultRunner(resolveDataDir, resolveNotificationLabels);

  static BackgroundDownloadRunner _defaultRunner(
    Future<Directory> Function()? resolveDataDir,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
  ) {
    final directoryResolver = resolveDataDir ?? getAppDataDirectory;
    if (Platform.isMacOS) {
      return MacOSSystemDownloadRunner(
        resolveDataDir: directoryResolver,
        resolveNotificationLabels: resolveNotificationLabels,
      );
    }
    return PluginBackgroundDownloadRunner(
      resolveDataDir: directoryResolver,
      resolveNotificationLabels: resolveNotificationLabels,
    );
  }

  final BackgroundDownloadRunner _runner;

  /// 下载文件到应用数据目录中的 [savePath]。
  Future<void> download({
    required Uri uri,
    required String savePath,
    String? displayName,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
    BackgroundFileDownloadProgress? onProgress,
  }) async {
    final outcomes = await downloadBatch(
      requests: [
        BackgroundFileDownloadRequest(
          id: savePath,
          uri: uri,
          savePath: savePath,
          displayName: displayName,
          headers: headers,
        ),
      ],
      cancelToken: cancelToken,
      onProgress: (_, received, total) => onProgress?.call(received, total),
    );
    final error = outcomes.single.error;
    if (error != null) throw error;
  }

  /// 将一批任务提交到共享队列，并为每个文件返回一个最终结果。
  ///
  /// Mobile platform tasks are all enqueued before this method waits, allowing
  /// the native queue to start the next file while the app is suspended. Runners
  /// without native batch support use the same serial behavior in Dart.
  Future<List<BackgroundFileDownloadItemResult>> downloadBatch({
    required List<BackgroundFileDownloadRequest> requests,
    CancelToken? cancelToken,
    BackgroundFileDownloadBatchProgress? onProgress,
  }) async {
    if (requests.isEmpty) return const <BackgroundFileDownloadItemResult>[];

    for (final request in requests) {
      onProgress?.call(request.id, 0, null);
      AppLogger.log(
        'BackgroundFileDownload',
        'download queued host=${request.uri.host} '
            'url=${_safeDownloadUrl(request.uri)} '
            'file=${p.basename(request.savePath)} task=${request.id}',
      );
    }

    final List<BackgroundDownloadResult> results;
    try {
      final runner = _runner;
      if (runner case final BackgroundDownloadBatchRunner batchRunner) {
        results = await batchRunner.enqueueBatch(
          requests: requests,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      } else {
        results = await _enqueueSerially(
          requests,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      }
    } on Object catch (error) {
      return [
        for (final request in requests)
          BackgroundFileDownloadItemResult(
            request: request,
            error: _exceptionFromError(error),
          ),
      ];
    }

    if (results.length != requests.length) {
      final error = BackgroundFileDownloadException(
        'The download queue returned an incomplete batch result.',
      );
      return [
        for (final request in requests)
          BackgroundFileDownloadItemResult(request: request, error: error),
      ];
    }

    final outcomes = <BackgroundFileDownloadItemResult>[];
    for (var index = 0; index < requests.length; index++) {
      final request = requests[index];
      final result = results[index];
      final error = await _validateResult(request, result);
      if (error != null) _logFailure(request, error);
      outcomes.add(
        BackgroundFileDownloadItemResult(request: request, error: error),
      );
    }
    return outcomes;
  }

  Future<List<BackgroundDownloadResult>> _enqueueSerially(
    List<BackgroundFileDownloadRequest> requests, {
    required CancelToken? cancelToken,
    required BackgroundFileDownloadBatchProgress? onProgress,
  }) async {
    final results = <BackgroundDownloadResult>[];
    for (final request in requests) {
      if (cancelToken?.isCancelled ?? false) {
        results.add(
          const BackgroundDownloadResult(
            status: BackgroundDownloadStatus.canceled,
            message: 'Download canceled before enqueue.',
          ),
        );
        continue;
      }
      try {
        results.add(
          await _runner.enqueue(
            uri: request.uri,
            savePath: request.savePath,
            displayName: request.displayName,
            headers: request.headers,
            cancelToken: cancelToken,
            onProgress: (received, total) =>
                onProgress?.call(request.id, received, total),
          ),
        );
      } on Object catch (error) {
        results.add(_resultFromError(error));
      }
    }
    return results;
  }

  Future<BackgroundFileDownloadException?> _validateResult(
    BackgroundFileDownloadRequest request,
    BackgroundDownloadResult result,
  ) async {
    try {
      switch (result.status) {
        case BackgroundDownloadStatus.complete:
          final file = File(request.savePath);
          if (!await file.exists()) {
            throw BackgroundFileDownloadException(
              'Download completed without creating the target file.',
              cause: result.cause,
            );
          }
          final actualBytes = await file.length();
          AppLogger.log(
            'BackgroundFileDownload',
            'download complete host=${request.uri.host} '
                'url=${_safeDownloadUrl(request.uri)} '
                'file=${p.basename(request.savePath)} '
                'statusCode=${result.statusCode ?? "(null)"} '
                'bytes=$actualBytes '
                'expectedBytes=${result.expectedBytes ?? "(unknown)"}'
                '${result.contentType == null ? '' : ' contentType=${result.contentType}'}',
          );
          return null;
        case BackgroundDownloadStatus.notFound:
          return BackgroundFileDownloadException(
            result.message ?? 'Download URL was not found.',
            statusCode: result.statusCode ?? 404,
            cause: result.cause,
            receivedBytes: result.receivedBytes,
            expectedBytes: result.expectedBytes,
            errorDomain: result.errorDomain,
            errorCode: result.errorCode,
          );
        case BackgroundDownloadStatus.failed:
          return BackgroundFileDownloadException(
            result.message ?? 'Background download failed.',
            statusCode: result.statusCode,
            isStorageFailure: result.isStorageFailure,
            cause: result.cause,
            receivedBytes: result.receivedBytes,
            expectedBytes: result.expectedBytes,
            errorDomain: result.errorDomain,
            errorCode: result.errorCode,
          );
        case BackgroundDownloadStatus.canceled:
          return BackgroundFileDownloadException(
            result.message ?? 'Download canceled.',
            isCanceled: true,
            cause: result.cause,
            receivedBytes: result.receivedBytes,
            expectedBytes: result.expectedBytes,
            errorDomain: result.errorDomain,
            errorCode: result.errorCode,
          );
      }
    } on BackgroundFileDownloadException catch (error) {
      return error;
    } on FileSystemException catch (error) {
      return BackgroundFileDownloadException(
        'Failed to save downloaded file.',
        isStorageFailure: true,
        cause: error,
      );
    } on Object catch (error) {
      return _exceptionFromError(error);
    }
  }

  BackgroundFileDownloadException _exceptionFromError(Object error) {
    if (error case BackgroundFileDownloadException()) return error;
    if (error case FileSystemException()) {
      return BackgroundFileDownloadException(
        'Failed to save downloaded file.',
        isStorageFailure: true,
        cause: error,
      );
    }
    return BackgroundFileDownloadException(
      'Background download failed.',
      cause: error,
    );
  }

  BackgroundDownloadResult _resultFromError(Object error) {
    final exception = _exceptionFromError(error);
    return BackgroundDownloadResult(
      status: exception.isCanceled
          ? BackgroundDownloadStatus.canceled
          : BackgroundDownloadStatus.failed,
      message: exception.message,
      statusCode: exception.statusCode,
      isStorageFailure: exception.isStorageFailure,
      cause: exception.cause,
      receivedBytes: exception.receivedBytes,
      expectedBytes: exception.expectedBytes,
      errorDomain: exception.errorDomain,
      errorCode: exception.errorCode,
    );
  }

  void _logFailure(
    BackgroundFileDownloadRequest request,
    BackgroundFileDownloadException error,
  ) {
    final details =
        ' statusCode=${error.statusCode ?? "(null)"} '
        'storage=${error.isStorageFailure} canceled=${error.isCanceled} '
        'bytes=${error.receivedBytes ?? "(unknown)"} '
        'expectedBytes=${error.expectedBytes ?? "(unknown)"}'
        '${error.errorDomain == null ? '' : ' errorDomain=${error.errorDomain}'}'
        '${error.errorCode == null ? '' : ' errorCode=${error.errorCode}'} '
        'message=${_safeDiagnosticText(error.message)}'
        '${error.cause == null ? '' : ' causeType=${error.cause.runtimeType} cause=${_safeDiagnosticText(error.cause.toString())}'}';
    AppLogger.log(
      'BackgroundFileDownload',
      'download failed host=${request.uri.host} '
          'url=${_safeDownloadUrl(request.uri)} '
          'file=${p.basename(request.savePath)} '
          'errorType=${error.runtimeType}$details',
    );
  }
}

/// 应用层下载错误，带 HTTP 状态及取消语义供现有功能映射。
class BackgroundFileDownloadException implements Exception {
  const BackgroundFileDownloadException(
    this.message, {
    this.statusCode,
    this.isCanceled = false,
    this.isStorageFailure = false,
    this.receivedBytes,
    this.expectedBytes,
    this.errorDomain,
    this.errorCode,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final bool isCanceled;
  final bool isStorageFailure;
  final int? receivedBytes;
  final int? expectedBytes;
  final String? errorDomain;
  final int? errorCode;
  final Object? cause;

  @override
  String toString() => 'BackgroundFileDownloadException($message)';
}

/// `background_downloader` 的平台队列适配器。
class PluginBackgroundDownloadRunner
    implements BackgroundDownloadRunner, BackgroundDownloadBatchRunner {
  PluginBackgroundDownloadRunner({
    required Future<Directory> Function() resolveDataDir,
    FileDownloader? downloader,
    Uuid? uuid,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
  }) : _resolveDataDir = resolveDataDir,
       _downloader = downloader ?? FileDownloader(),
       _uuid = uuid ?? const Uuid(),
       _resolveNotificationLabels =
           resolveNotificationLabels ?? _englishNotificationLabels;

  static const _group = 'echo-loop-user-files';

  final Future<Directory> Function() _resolveDataDir;
  final FileDownloader _downloader;
  final Uuid _uuid;
  final BackgroundFileDownloadNotificationLabelResolver
  _resolveNotificationLabels;
  final Map<String, _PendingDownload> _pending = {};
  Future<void>? _initialization;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: 'Download canceled before enqueue.',
      );
    }

    await _ensureInitialized();
    final dataDir = await _resolveDataDir();
    final rootPath = p.normalize(dataDir.path);
    final targetPath = p.normalize(savePath);
    if (!p.isWithin(rootPath, targetPath)) {
      throw ArgumentError.value(
        savePath,
        'savePath',
        'Download destination must be inside the application data directory.',
      );
    }
    final relativePath = p.relative(targetPath, from: rootPath);
    final directory = p.dirname(relativePath);
    await File(targetPath).parent.create(recursive: true);

    final labels = await _resolveNotificationLabels();
    final taskId = _uuid.v4();
    final completer = Completer<BackgroundDownloadResult>();
    _pending[taskId] = _PendingDownload(
      completer: completer,
      onProgress: onProgress,
      host: uri.host,
      safeUrl: _safeDownloadUrl(uri),
      fileName: p.basename(relativePath),
    );
    final task = DownloadTask(
      taskId: taskId,
      url: uri.toString(),
      filename: p.basename(relativePath),
      directory: directory == '.' ? '' : directory,
      baseDirectory: BaseDirectory.applicationSupport,
      group: _group,
      headers: headers,
      updates: Updates.statusAndProgress,
      allowPause: false,
      displayName: displayName ?? p.basename(relativePath),
    );
    _downloader.configureNotificationForTask(
      task,
      running: TaskNotification(labels.running, '{displayName}'),
      complete: TaskNotification(labels.complete, '{displayName}'),
      error: TaskNotification(labels.failed, '{displayName}'),
      progressBar: true,
    );

    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel
            .then((_) async {
              await _downloader.cancelTaskWithId(taskId);
            })
            .catchError((Object error) {
              AppLogger.log(
                'BackgroundFileDownload',
                'failed to cancel task: $error',
              );
            }),
      );
    }

    try {
      final accepted = await _downloader.enqueue(task);
      AppLogger.log(
        'BackgroundFileDownload',
        'task submitted host=${uri.host} url=${_safeDownloadUrl(uri)} '
            'taskId=$taskId accepted=$accepted',
      );
      if (!accepted && !completer.isCompleted) {
        completer.complete(
          const BackgroundDownloadResult(
            status: BackgroundDownloadStatus.failed,
            message: 'Could not enqueue background download.',
          ),
        );
      }
      return await completer.future;
    } finally {
      _pending.remove(taskId);
    }
  }

  @override
  Future<List<BackgroundDownloadResult>> enqueueBatch({
    required List<BackgroundFileDownloadRequest> requests,
    required BackgroundFileDownloadBatchProgress? onProgress,
    required CancelToken? cancelToken,
  }) {
    return Future.wait(
      requests.map((request) async {
        try {
          return await enqueue(
            uri: request.uri,
            savePath: request.savePath,
            displayName: request.displayName,
            headers: request.headers,
            cancelToken: cancelToken,
            onProgress: (received, total) =>
                onProgress?.call(request.id, received, total),
          );
        } on Object catch (error) {
          final isStorageFailure = error is FileSystemException;
          return BackgroundDownloadResult(
            status: BackgroundDownloadStatus.failed,
            message: isStorageFailure
                ? 'Failed to save downloaded file.'
                : 'Background download failed.',
            isStorageFailure: isStorageFailure,
            cause: error,
          );
        }
      }),
    );
  }

  Future<void> _ensureInitialized() {
    final initialization = _initialization;
    if (initialization != null) return initialization;
    final future = _initialize();
    _initialization = future;
    return future.catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    AppLogger.log(
      'BackgroundFileDownload',
      'initializing plugin group=$_group',
    );
    try {
      await _downloader.configure(
        globalConfig: (Config.holdingQueue, (null, null, 1)),
      );
      final labels = await _resolveNotificationLabels();
      _downloader.configureNotificationForGroup(
        _group,
        running: TaskNotification(labels.running, '{displayName}'),
        complete: TaskNotification(labels.complete, '{displayName}'),
        error: TaskNotification(labels.failed, '{displayName}'),
        progressBar: true,
      );
      _downloader.registerCallbacks(
        group: _group,
        taskStatusCallback: _handleStatus,
        taskProgressCallback: _handleProgress,
      );
      await _downloader.trackTasksInGroup(_group);
      await _downloader.start(
        doTrackTasks: false,
        doRescheduleKilledTasks: false,
      );
      AppLogger.log('BackgroundFileDownload', 'plugin ready group=$_group');
    } on Object catch (error) {
      AppLogger.log(
        'BackgroundFileDownload',
        'plugin initialization failed errorType=${error.runtimeType}',
      );
      rethrow;
    }
  }

  void _handleStatus(TaskStatusUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null || pending.completer.isCompleted) return;
    final exception = update.exception;
    AppLogger.log(
      'BackgroundFileDownload',
      'task status=${update.status.name} host=${pending.host} '
          'url=${pending.safeUrl} '
          'file=${pending.fileName} taskId=${update.task.taskId} '
          'statusCode=${update.responseStatusCode ?? "(null)"} '
          'bytes=${pending.receivedBytes ?? "(unknown)"} '
          'expectedBytes=${pending.expectedBytes ?? "(unknown)"} '
          'durationMs=${pending.stopwatch.elapsedMilliseconds}'
          '${exception == null ? '' : ' error=${_safeTaskException(exception)}'}',
    );

    final result = switch (update.status) {
      TaskStatus.complete => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.complete,
        statusCode: update.responseStatusCode,
        receivedBytes: pending.receivedBytes,
        expectedBytes: pending.expectedBytes,
      ),
      TaskStatus.notFound => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.notFound,
        statusCode: update.responseStatusCode ?? 404,
        message: 'Download URL was not found.',
        cause: update.exception,
        receivedBytes: pending.receivedBytes,
        expectedBytes: pending.expectedBytes,
      ),
      TaskStatus.failed => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.failed,
        statusCode:
            update.responseStatusCode ??
            switch (update.exception) {
              TaskHttpException(:final httpResponseCode) => httpResponseCode,
              _ => null,
            },
        message: 'Background download failed.',
        cause: update.exception,
        isStorageFailure: _isInsufficientStorage(update.exception),
        receivedBytes: pending.receivedBytes,
        expectedBytes: pending.expectedBytes,
      ),
      TaskStatus.canceled => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: 'Download canceled.',
        cause: update.exception,
      ),
      _ => null,
    };
    if (result != null) pending.completer.complete(result);
  }

  /// 插件在部分平台会用文件系统异常包装网络错误，因此只识别明确的空间不足描述。
  bool _isInsufficientStorage(TaskException? exception) {
    final description = exception?.description.toLowerCase();
    if (description == null) return false;
    return const <String>[
      'no space left',
      'enospc',
      'errno = 28',
      'errno 28',
      'insufficient space',
      'not enough space',
      'disk full',
      'storage full',
    ].any(description.contains);
  }

  String _safeTaskException(TaskException exception) {
    final description = exception.description.replaceAll(
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      '<url>',
    );
    return '${exception.exceptionType}: $description';
  }

  void _handleProgress(TaskProgressUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null) return;
    final expectedBytes = update.expectedFileSize > 0
        ? update.expectedFileSize
        : null;
    pending.expectedBytes = expectedBytes;
    pending.receivedBytes = expectedBytes == null
        ? null
        : (update.progress * expectedBytes)
              .round()
              .clamp(0, expectedBytes)
              .toInt();
    final callback = pending.onProgress;
    if (callback == null || update.progress < 0) return;
    final receivedBytes = expectedBytes == null
        ? 0
        : (update.progress * expectedBytes)
              .round()
              .clamp(0, expectedBytes)
              .toInt();
    callback(receivedBytes, expectedBytes);
  }
}

Future<BackgroundFileDownloadNotificationLabels>
_englishNotificationLabels() async {
  return const BackgroundFileDownloadNotificationLabels(
    running: 'Downloading',
    complete: 'Download complete',
    failed: 'Download failed',
  );
}

class _PendingDownload {
  _PendingDownload({
    required this.completer,
    required this.onProgress,
    required this.host,
    required this.safeUrl,
    required this.fileName,
  }) : stopwatch = Stopwatch()..start();

  final Completer<BackgroundDownloadResult> completer;
  final BackgroundFileDownloadProgress? onProgress;
  final String host;
  final String safeUrl;
  final String fileName;
  final Stopwatch stopwatch;
  int? receivedBytes;
  int? expectedBytes;
}

/// macOS 原生下载桥接，可在 Dart 单元测试中替换。
abstract interface class MacOSSystemDownloadClient {
  /// 使用系统网络栈下载文件，并通过 [onProgress] 回报进度。
  Future<BackgroundDownloadResult> download({
    required Uri uri,
    required String savePath,
    required String displayName,
    required String completeNotificationTitle,
    required String failedNotificationTitle,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  });
}

/// macOS 下载适配器。
///
/// macOS 使用 URLSession 默认配置，由系统决定代理和网络路由；其他平台继续
/// 使用 `background_downloader` 自己的原生后台任务实现。
class MacOSSystemDownloadRunner implements BackgroundDownloadRunner {
  MacOSSystemDownloadRunner({
    required Future<Directory> Function() resolveDataDir,
    MacOSSystemDownloadClient? client,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
  }) : _resolveDataDir = resolveDataDir,
       _client = client ?? const _MethodChannelMacOSSystemDownloadClient(),
       _resolveNotificationLabels =
           resolveNotificationLabels ?? _englishNotificationLabels;

  final Future<Directory> Function() _resolveDataDir;
  final MacOSSystemDownloadClient _client;
  final BackgroundFileDownloadNotificationLabelResolver
  _resolveNotificationLabels;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) async {
    final rootPath = p.normalize((await _resolveDataDir()).path);
    final targetPath = p.normalize(savePath);
    if (!p.isWithin(rootPath, targetPath)) {
      throw ArgumentError.value(
        savePath,
        'savePath',
        'Download destination must be inside the application data directory.',
      );
    }
    final labels = await _resolveNotificationLabels();
    return _client.download(
      uri: uri,
      savePath: targetPath,
      displayName: displayName ?? p.basename(targetPath),
      completeNotificationTitle: labels.complete,
      failedNotificationTitle: labels.failed,
      headers: headers,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}

class _MethodChannelMacOSSystemDownloadClient
    implements MacOSSystemDownloadClient {
  const _MethodChannelMacOSSystemDownloadClient();

  static const _methodChannel = MethodChannel('top.echo-loop/system_download');
  static const _eventChannel = EventChannel(
    'top.echo-loop/system_download/events',
  );

  static final _uuid = const Uuid();
  static final Map<String, _MacOSPendingDownload> _pending = {};
  static StreamSubscription<Object?>? _updates;

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
    if (cancelToken?.isCancelled ?? false) {
      return const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: 'Download canceled before enqueue.',
      );
    }
    await _ensureListening();

    final taskId = _uuid.v4();
    final completer = Completer<BackgroundDownloadResult>();
    _pending[taskId] = _MacOSPendingDownload(
      completer: completer,
      onProgress: onProgress,
      host: uri.host,
      safeUrl: _safeDownloadUrl(uri),
      fileName: p.basename(savePath),
    );
    AppLogger.log(
      'BackgroundFileDownload',
      'system download started host=${uri.host} '
          'url=${_safeDownloadUrl(uri)} '
          'file=${p.basename(savePath)} taskId=$taskId',
    );

    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel.then((_) => _requestCancel(taskId)).catchError((
          Object error,
        ) {
          AppLogger.log(
            'BackgroundFileDownload',
            'failed to cancel system download errorType=${error.runtimeType}',
          );
        }),
      );
    }

    try {
      final accepted = await _methodChannel
          .invokeMethod<bool>('startDownload', <String, Object?>{
            'taskId': taskId,
            'url': uri.toString(),
            'savePath': savePath,
            'displayName': displayName,
            'completeNotificationTitle': completeNotificationTitle,
            'failedNotificationTitle': failedNotificationTitle,
            'headers': headers,
          });
      if (accepted != true && !completer.isCompleted) {
        completer.complete(
          const BackgroundDownloadResult(
            status: BackgroundDownloadStatus.failed,
            message: 'Could not enqueue system download.',
          ),
        );
      } else if (accepted == true) {
        final pending = _pending[taskId];
        if (pending != null) {
          pending.started = true;
          if (pending.cancelRequested || (cancelToken?.isCancelled ?? false)) {
            await _requestCancel(taskId);
          }
        }
      }
      return await completer.future;
    } on Object catch (error) {
      if (!completer.isCompleted) {
        completer.complete(
          BackgroundDownloadResult(
            status: BackgroundDownloadStatus.failed,
            message: 'Could not start system download.',
            cause: error,
          ),
        );
      }
      return await completer.future;
    } finally {
      _pending.remove(taskId);
    }
  }

  Future<void> _ensureListening() async {
    if (_updates != null) return;
    _updates = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (Object error) {
        for (final pending in _pending.values) {
          if (!pending.completer.isCompleted) {
            pending.completer.complete(
              BackgroundDownloadResult(
                status: BackgroundDownloadStatus.failed,
                message: 'System download event stream failed.',
                cause: error,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _requestCancel(String taskId) async {
    final pending = _pending[taskId];
    if (pending == null || pending.completer.isCompleted) return;
    pending.cancelRequested = true;
    if (!pending.started) return;
    await _methodChannel.invokeMethod<bool>('cancelDownload', <String, Object?>{
      'taskId': taskId,
    });
  }

  void _handleEvent(Object? event) {
    if (event is! Map<Object?, Object?>) return;
    final update = event;
    final taskId = update['taskId'];
    final status = update['status'];
    if (taskId is! String || status is! String) return;
    final pending = _pending[taskId];
    if (pending == null || pending.completer.isCompleted) return;

    if (status == 'progress') {
      final receivedBytes = _integer(update['receivedBytes']);
      final totalBytes = _integer(update['totalBytes']);
      pending.receivedBytes = receivedBytes ?? pending.receivedBytes;
      pending.expectedBytes = totalBytes ?? pending.expectedBytes;
      if (receivedBytes != null) {
        pending.onProgress?.call(receivedBytes, totalBytes);
      }
      return;
    }

    final statusCode = _integer(update['statusCode']);
    final receivedBytes = _integer(update['receivedBytes']);
    final expectedBytes = _integer(update['expectedBytes']);
    final contentType = update['contentType'] is String
        ? update['contentType'] as String
        : null;
    final errorDomain = update['errorDomain'] is String
        ? update['errorDomain'] as String
        : null;
    final errorCode = _integer(update['errorCode']);
    pending.receivedBytes = receivedBytes ?? pending.receivedBytes;
    pending.expectedBytes = expectedBytes ?? pending.expectedBytes;
    final rawMessage = update['message'];
    final message = rawMessage is String ? rawMessage : null;
    final result = switch (status) {
      'complete' => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.complete,
        statusCode: statusCode,
        receivedBytes: receivedBytes,
        expectedBytes: expectedBytes,
        contentType: contentType,
      ),
      'notFound' => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.notFound,
        statusCode: statusCode ?? 404,
        message: message,
        receivedBytes: receivedBytes,
        expectedBytes: expectedBytes,
        contentType: contentType,
      ),
      'canceled' => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: message,
        receivedBytes: receivedBytes,
        expectedBytes: expectedBytes,
        errorDomain: errorDomain,
        errorCode: errorCode,
      ),
      'failed' => BackgroundDownloadResult(
        status: BackgroundDownloadStatus.failed,
        statusCode: statusCode,
        message: message,
        isStorageFailure: update['isStorageFailure'] == true,
        receivedBytes: receivedBytes,
        expectedBytes: expectedBytes,
        contentType: contentType,
        errorDomain: errorDomain,
        errorCode: errorCode,
      ),
      _ => null,
    };
    if (result == null) return;
    AppLogger.log(
      'BackgroundFileDownload',
      'system task status=$status host=${pending.host} '
          'url=${pending.safeUrl} '
          'file=${pending.fileName} '
          'taskId=$taskId statusCode=${statusCode ?? "(null)"} '
          'bytes=${receivedBytes ?? pending.receivedBytes ?? "(unknown)"} '
          'expectedBytes=${expectedBytes ?? pending.expectedBytes ?? "(unknown)"} '
          'durationMs=${pending.stopwatch.elapsedMilliseconds}'
          '${contentType == null ? '' : ' contentType=$contentType'}'
          '${errorDomain == null ? '' : ' errorDomain=$errorDomain'}'
          '${errorCode == null ? '' : ' errorCode=$errorCode'}'
          '${message == null ? '' : ' message=${_safeDiagnosticText(message)}'}',
    );
    pending.completer.complete(result);
  }

  int? _integer(Object? value) => value is num ? value.toInt() : null;
}

String _safeDiagnosticText(String value) => value.replaceAll(
  RegExp(r'https?://[^\s"<>]+', caseSensitive: false),
  '<url>',
);

String _safeDownloadUrl(Uri uri) {
  final queryParameters = <String>[];
  uri.queryParametersAll.forEach((key, values) {
    final normalizedKey = key.toLowerCase().replaceAll(RegExp(r'[-_.]'), '');
    final isSensitive =
        normalizedKey.contains('token') ||
        normalizedKey.contains('signature') ||
        normalizedKey == 'sig' ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('password') ||
        normalizedKey.contains('passwd') ||
        normalizedKey.startsWith('auth') ||
        normalizedKey.contains('credential') ||
        normalizedKey.contains('apikey') ||
        normalizedKey.endsWith('key') ||
        normalizedKey == 'keypairid' ||
        normalizedKey.contains('policy') ||
        normalizedKey.contains('session');
    for (final value in values) {
      queryParameters.add(
        '${Uri.encodeQueryComponent(key)}='
        '${Uri.encodeQueryComponent(isSensitive ? 'REDACTED' : value)}',
      );
    }
  });
  return uri
      .replace(
        userInfo: '',
        query: uri.hasQuery ? queryParameters.join('&') : null,
      )
      .removeFragment()
      .toString();
}

class _MacOSPendingDownload {
  _MacOSPendingDownload({
    required this.completer,
    required this.onProgress,
    required this.host,
    required this.safeUrl,
    required this.fileName,
  }) : stopwatch = Stopwatch()..start();

  final Completer<BackgroundDownloadResult> completer;
  final BackgroundFileDownloadProgress? onProgress;
  final String host;
  final String safeUrl;
  final String fileName;
  final Stopwatch stopwatch;
  int? receivedBytes;
  int? expectedBytes;
  bool started = false;
  bool cancelRequested = false;
}

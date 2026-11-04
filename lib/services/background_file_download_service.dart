import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'app_logger.dart';
import 'background_file_download_exception.dart';
import 'download_completion_notifier.dart';
import 'resource_download_registry.dart';
import 'system_proxy.dart';
import '../utils/app_data_dir.dart';

export 'background_file_download_exception.dart';

typedef BackgroundFileDownloadProgress = void Function(
  int receivedBytes,
  int? totalBytes,
);
typedef BackgroundFileDownloadBatchProgress = void Function(
  String taskId,
  int receivedBytes,
  int? totalBytes,
);

const _backgroundDownloadProgressUpdateInterval = Duration(milliseconds: 100);

/// 合并后台下载的高频进度通知，限制应用状态最多每 100 毫秒更新一次。
///
/// 每个任务单独限频；任务完成或失败时立即发布最新字节数，避免最终进度被丢弃。
class _BackgroundDownloadProgressThrottler {
  _BackgroundDownloadProgressThrottler(this._callback);

  final BackgroundFileDownloadBatchProgress? _callback;
  final Stopwatch _clock = Stopwatch()..start();
  final Map<String, _DownloadProgressSnapshot> _snapshots = {};

  /// 接收平台进度，并在达到间隔或确定完成时转发给应用层。
  void report(
    String taskId,
    int receivedBytes,
    int? totalBytes, {
    bool force = false,
  }) {
    final callback = _callback;
    if (callback == null) return;

    final snapshot = _snapshots.putIfAbsent(
      taskId,
      _DownloadProgressSnapshot.new,
    );
    snapshot.latestReceivedBytes = receivedBytes;
    snapshot.latestTotalBytes = totalBytes;

    final now = _clock.elapsed;
    final reachedEnd =
        totalBytes != null && totalBytes > 0 && receivedBytes >= totalBytes;
    final lastPublishedAt = snapshot.lastPublishedAt;
    if (!force &&
        !reachedEnd &&
        lastPublishedAt != null &&
        now - lastPublishedAt < _backgroundDownloadProgressUpdateInterval) {
      return;
    }
    _publish(callback, taskId, snapshot, receivedBytes, totalBytes, now);
  }

  /// 发布任务结束时的最终进度；平台未提供最终字节数时使用最后一次事件。
  void finish(String taskId, BackgroundDownloadResult result) {
    final snapshot = _snapshots[taskId];
    final receivedBytes = result.receivedBytes ?? snapshot?.latestReceivedBytes;
    if (receivedBytes == null) {
      flush(taskId);
      return;
    }
    report(
      taskId,
      receivedBytes,
      result.expectedBytes ?? snapshot?.latestTotalBytes,
      force: true,
    );
  }

  /// 异常结束时转发尚未发布的最后进度。
  void flush(String taskId) {
    final snapshot = _snapshots[taskId];
    final receivedBytes = snapshot?.latestReceivedBytes;
    if (receivedBytes == null) return;
    report(taskId, receivedBytes, snapshot?.latestTotalBytes, force: true);
  }

  void _publish(
    BackgroundFileDownloadBatchProgress callback,
    String taskId,
    _DownloadProgressSnapshot snapshot,
    int receivedBytes,
    int? totalBytes,
    Duration now,
  ) {
    if (snapshot.lastPublishedReceivedBytes == receivedBytes &&
        snapshot.lastPublishedTotalBytes == totalBytes) {
      return;
    }
    snapshot
      ..lastPublishedAt = now
      ..lastPublishedReceivedBytes = receivedBytes
      ..lastPublishedTotalBytes = totalBytes;
    callback(taskId, receivedBytes, totalBytes);
  }
}

/// 记录单个任务最新收到的进度和最近一次已通知的进度。
class _DownloadProgressSnapshot {
  int? latestReceivedBytes;
  int? latestTotalBytes;
  Duration? lastPublishedAt;
  int? lastPublishedReceivedBytes;
  int? lastPublishedTotalBytes;
}

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
    String? resourceKey,
    this.displayName,
    this.headers = const <String, String>{},
  }) : resourceKey = resourceKey ?? savePath;

  /// 用于关联该请求进度和结果的稳定标识。
  final String id;
  final Uri uri;
  final String savePath;

  /// 资源标识：同一资源同一时刻只允许一个下载任务，所有入口共享它。
  /// 缺省为 [savePath]，因为同一目标文件本就不能被两个任务同时写。
  final String resourceKey;

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

/// 平台队列中任务所处的阶段，供资源登记表展示排队与重试状态。
enum BackgroundDownloadPhase { queued, running, waitingToRetry }

typedef BackgroundDownloadPhaseCallback = void Function(
  String requestId,
  BackgroundDownloadPhase phase,
);

/// 平台 runner 可选实现此能力，在 Dart 等待任务完成前先将整批任务提交到原生队列。
abstract interface class BackgroundDownloadBatchRunner {
  Future<List<BackgroundDownloadResult>> enqueueBatch({
    required List<BackgroundFileDownloadRequest> requests,
    required BackgroundFileDownloadBatchProgress? onProgress,
    required BackgroundDownloadPhaseCallback? onPhase,
    required CancelToken? cancelToken,
  });
}

/// 用户文件下载在插件中的 group，开发者调试页按此 group 读取持久化记录。
const String kUserFilesDownloadGroup = 'echo-loop-user-files';

/// 进程内共享的资源登记表。所有入口共用同一个实例，才能保证同一资源只有一个下载任务。
/// 进程内共享的资源登记表；界面与下载服务通过它读取同一份资源状态。
final ResourceDownloadRegistry sharedResourceDownloadRegistry =
    ResourceDownloadRegistry();

/// 每个 [FileDownloader] 的遗留任务清理只执行一次（插件是进程级单例）。
final Expando<Future<void>> _leftoverCleanup = Expando<Future<void>>(
  'leftoverCleanup',
);

/// 全局同时运行的下载任务数，在原生队列中限制。
const int maxConcurrentDownloads = 2;

/// 失败后的自动重试次数；首次尝试之外再试 2 次，共 3 次尝试。
/// 插件先尝试续传，无法续传时才从头下载。
const int downloadRetryCount = 2;

/// 文件后台下载服务。
///
/// 应用层只依据平台下载任务的终态和目标文件是否存在判断成功，不拿来源
/// 元数据中的文件大小作为失败条件。
class BackgroundFileDownloadService {
  BackgroundFileDownloadService({
    BackgroundDownloadRunner? runner,
    ResourceDownloadRegistry? registry,
    Future<Directory> Function()? resolveDataDir,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
    DownloadProxyResolver? resolveDownloadProxy,
    DownloadCompletionNotifier? completionNotifier,
  }) : _runner =
           runner ??
           _defaultRunner(
             resolveDataDir,
             resolveNotificationLabels,
             resolveDownloadProxy,
             completionNotifier,
           ),
       _registry = registry ?? sharedResourceDownloadRegistry;

  final ResourceDownloadRegistry _registry;

  static BackgroundDownloadRunner _defaultRunner(
    Future<Directory> Function()? resolveDataDir,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
    DownloadProxyResolver? resolveDownloadProxy,
    DownloadCompletionNotifier? completionNotifier,
  ) {
    return PluginBackgroundDownloadRunner(
      resolveDataDir: resolveDataDir ?? getAppDataDirectory,
      resolveNotificationLabels: resolveNotificationLabels,
      resolveDownloadProxy: resolveDownloadProxy,
      completionNotifier: completionNotifier,
    );
  }

  final BackgroundDownloadRunner _runner;

  /// 下载文件到应用数据目录中的 [savePath]。
  ///
  /// 同一 [resourceKey] 的活动任务会被共享：重复调用只加入已有任务，不会新建第二个任务。
  Future<void> download({
    required Uri uri,
    required String savePath,
    String? displayName,
    String? resourceKey,
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
          resourceKey: resourceKey,
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

  /// 资源状态的只读视图；所有入口读取的是同一份登记表。
  ResourceDownloadReader get downloads => _registry;

  /// 取消某个资源的下载。所有等待该资源的入口都会收到取消结果。
  /// 返回的 Future 在任务结束后完成。
  Future<void> cancelResource(String resourceKey) =>
      _registry.cancelResource(resourceKey);

  /// 将一批请求登记到资源表，并提交新任务到后台队列；为每个请求返回最终结果。
  ///
  /// 同一资源只执行一次：重复请求加入已有任务，并共享同一个结果。
  /// 支持批量的 runner 会先把所有新任务入队再等待，原生队列在 App 挂起时也能推进。
  Future<List<BackgroundFileDownloadItemResult>> downloadBatch({
    required List<BackgroundFileDownloadRequest> requests,
    CancelToken? cancelToken,
    BackgroundFileDownloadBatchProgress? onProgress,
  }) async {
    if (requests.isEmpty) return const <BackgroundFileDownloadItemResult>[];
    if (cancelToken?.isCancelled ?? false) {
      return [
        for (final request in requests)
          BackgroundFileDownloadItemResult(
            request: request,
            error: const BackgroundFileDownloadException(
              'Download canceled before enqueue.',
              isCanceled: true,
            ),
          ),
      ];
    }
    // 先整批校验再登记，避免批内抛错后留下无人执行的任务。
    _registry.validateSavePaths([
      for (final request in requests)
        (key: request.resourceKey, savePath: request.savePath),
    ]);

    final bindings =
        <
          ({BackgroundFileDownloadRequest request, ResourceDownload download})
        >[];
    final newDownloads =
        <
          ({ResourceDownload download, BackgroundFileDownloadRequest request})
        >[];
    final linkedDownloads = <ResourceDownload>{};
    final subscriptions = <StreamSubscription<ResourceDownloadState>>[];
    try {
      for (final request in requests) {
        final acquisition = _registry.acquire(
          key: request.resourceKey,
          savePath: request.savePath,
        );
        final download = acquisition.download;
        bindings.add((request: request, download: download));
        if (acquisition.isNew) {
          newDownloads.add((download: download, request: request));
          // 有空闲并发名额时直接进入下载中，不经过"排队中"，避免闪烁。
          if (_registry.runningCount < maxConcurrentDownloads) {
            _registry.markRunning(download);
          }
          AppLogger.log(
            'BackgroundFileDownload',
            'download queued host=${request.uri.host} '
                'url=${_safeDownloadUrl(request.uri)} '
                'file=${p.basename(request.savePath)} task=${request.id}',
          );
        } else {
          AppLogger.log(
            'BackgroundFileDownload',
            'download joined resource=${request.resourceKey} '
                'file=${p.basename(request.savePath)} task=${request.id}',
          );
        }
        if (linkedDownloads.add(download) && cancelToken != null) {
          // 取消绑定到具体任务：任务结束后取消令牌再次触发不会影响之后的新任务。
          unawaited(
            cancelToken.whenCancel.then((_) => _registry.cancelEntry(download)),
          );
        }
        if (onProgress != null) {
          subscriptions.add(_subscribeProgress(request, download, onProgress));
        }
      }
      for (final pending in newDownloads) {
        unawaited(_execute(pending.download, pending.request));
      }
      final errors = await Future.wait(
        bindings.map((binding) => binding.download.outcome),
      );
      return [
        for (var index = 0; index < bindings.length; index++)
          BackgroundFileDownloadItemResult(
            request: bindings[index].request,
            error: errors[index],
          ),
      ];
    } finally {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }
  }

  /// 将资源的进度转发给单个请求：先报告当前状态，之后只转发该任务自己的进度。
  StreamSubscription<ResourceDownloadState> _subscribeProgress(
    BackgroundFileDownloadRequest request,
    ResourceDownload download,
    BackgroundFileDownloadBatchProgress onProgress,
  ) {
    final current = _registry.stateOf(request.resourceKey);
    if (current is ResourceRunning) {
      onProgress(request.id, current.receivedBytes ?? 0, current.totalBytes);
    } else {
      onProgress(request.id, 0, null);
    }
    late final StreamSubscription<ResourceDownloadState> subscription;
    subscription = _registry.changes.listen((state) {
      // 任务已结束后，同一资源的新任务进度不能再转发给旧请求。
      if (download.isFinished) {
        subscription.cancel();
        return;
      }
      if (state.key != request.resourceKey || state is! ResourceRunning) return;
      onProgress(request.id, state.receivedBytes ?? 0, state.totalBytes);
    });
    return subscription;
  }

  /// 执行一个新登记的任务。不向外抛出异常：所有失败都转为该任务的结果。
  Future<void> _execute(
    ResourceDownload download,
    BackgroundFileDownloadRequest request,
  ) async {
    final throttler = _BackgroundDownloadProgressThrottler(
      (_, received, total) => _registry.markRunning(
        download,
        receivedBytes: received,
        totalBytes: total,
      ),
    );
    BackgroundFileDownloadException? error;
    try {
      // 取消中被替换的任务：等旧任务结束后再提交，避免两个原生任务同时写同一文件。
      final predecessor = download.predecessor;
      if (predecessor != null) await predecessor;
      if (download.cancelToken.isCancelled) {
        error = const BackgroundFileDownloadException(
          'Download canceled before enqueue.',
          isCanceled: true,
        );
      } else {
        final result = await _runRequest(download, request, throttler);
        throttler.finish(request.id, result);
        error = await _validateResult(request, result);
      }
    } on Object catch (caught) {
      error = _exceptionFromError(caught);
    }
    if (error != null) _logFailure(request, error);
    _registry.finish(download, error);
  }

  Future<BackgroundDownloadResult> _runRequest(
    ResourceDownload download,
    BackgroundFileDownloadRequest request,
    _BackgroundDownloadProgressThrottler throttler,
  ) async {
    final runner = _runner;
    if (runner case final BackgroundDownloadBatchRunner batchRunner) {
      final results = await batchRunner.enqueueBatch(
        requests: [request],
        cancelToken: download.cancelToken,
        onProgress: (_, received, total) =>
            throttler.report(request.id, received, total),
        onPhase: (_, phase) => _applyPhase(download, phase),
      );
      return results.single;
    }
    _registry.markRunning(download);
    return runner.enqueue(
      uri: request.uri,
      savePath: request.savePath,
      displayName: request.displayName,
      headers: request.headers,
      cancelToken: download.cancelToken,
      onProgress: (received, total) =>
          throttler.report(request.id, received, total),
    );
  }

  void _applyPhase(ResourceDownload download, BackgroundDownloadPhase phase) {
    switch (phase) {
      case BackgroundDownloadPhase.queued:
        // 平台的 enqueued 回报不代表真的在排队：已经在传输的任务不能被降级为排队。
        if (_registry.stateOf(download.key) is! ResourceRunning) {
          _registry.markQueued(download);
        }
      case BackgroundDownloadPhase.running:
        _registry.markRunning(download);
      case BackgroundDownloadPhase.waitingToRetry:
        _registry.markWaitingToRetry(download);
    }
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

/// `background_downloader` 的平台队列适配器。
/// 返回本次下载应使用的代理；null 表示直连。每次入队前调用，以便开关即时生效。
typedef DownloadProxyResolver = Future<SystemProxyEndpoint?> Function();

class PluginBackgroundDownloadRunner
    implements BackgroundDownloadRunner, BackgroundDownloadBatchRunner {
  PluginBackgroundDownloadRunner({
    required Future<Directory> Function() resolveDataDir,
    FileDownloader? downloader,
    Uuid? uuid,
    BackgroundFileDownloadNotificationLabelResolver? resolveNotificationLabels,
    DownloadProxyResolver? resolveDownloadProxy,
    DownloadCompletionNotifier? completionNotifier,
  }) : _resolveDataDir = resolveDataDir,
       _downloader = downloader ?? FileDownloader(),
       _uuid = uuid ?? const Uuid(),
       _resolveNotificationLabels = _guardNotificationLabels(
         resolveNotificationLabels ?? _englishNotificationLabels,
       ),
       _resolveDownloadProxy = resolveDownloadProxy ?? _noDownloadProxy,
       _completionNotifier = completionNotifier;

  final Future<Directory> Function() _resolveDataDir;
  final FileDownloader _downloader;
  final Uuid _uuid;
  final BackgroundFileDownloadNotificationLabelResolver
  _resolveNotificationLabels;
  final DownloadProxyResolver _resolveDownloadProxy;

  /// 非 null 时，终态（完成 / 失败）由应用补发通知；用于插件不在该平台发通知的情况。
  final DownloadCompletionNotifier? _completionNotifier;
  final Map<String, _PendingDownload> _pending = {};
  Future<void>? _initialization;

  /// 已写入插件的代理端点；尚未写入过时 [_hasAppliedProxy] 为 false。
  SystemProxyEndpoint? _appliedProxy;
  bool _hasAppliedProxy = false;

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) => _enqueueTask(
    uri: uri,
    savePath: savePath,
    displayName: displayName,
    headers: headers,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  Future<BackgroundDownloadResult> _enqueueTask({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
    String? resourceKey,
    void Function(BackgroundDownloadPhase phase)? onPhase,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      return const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.canceled,
        message: 'Download canceled before enqueue.',
      );
    }

    await _ensureInitialized();
    await _applyDownloadProxyIfChanged();
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
      onPhase: onPhase,
      host: uri.host,
      safeUrl: _safeDownloadUrl(uri),
      fileName: p.basename(relativePath),
      labels: labels,
    );
    final task = DownloadTask(
      taskId: taskId,
      url: uri.toString(),
      filename: p.basename(relativePath),
      directory: directory == '.' ? '' : directory,
      baseDirectory: BaseDirectory.applicationSupport,
      group: kUserFilesDownloadGroup,
      headers: headers,
      updates: Updates.statusAndProgress,
      // 允许续传：插件在失败重试时优先从断点恢复，不支持时才从头下载。
      allowPause: true,
      retries: downloadRetryCount,
      displayName: displayName ?? p.basename(relativePath),
      // 持久化在插件记录中，供开发者调试页按资源归类。
      metaData: resourceKey ?? '',
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
      // 取消可能发生在入队返回之前：那时取消回调找不到任务，这里补一次。
      if (cancelToken?.isCancelled ?? false) {
        await _downloader.cancelTaskWithId(taskId);
      }
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
    required BackgroundDownloadPhaseCallback? onPhase,
    required CancelToken? cancelToken,
  }) {
    return Future.wait(
      requests.map((request) async {
        try {
          return await _enqueueTask(
            uri: request.uri,
            savePath: request.savePath,
            displayName: request.displayName,
            headers: request.headers,
            cancelToken: cancelToken,
            resourceKey: request.resourceKey,
            onProgress: (received, total) =>
                onProgress?.call(request.id, received, total),
            onPhase: (phase) => onPhase?.call(request.id, phase),
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

  /// 把当前代理设置写入插件；端点与上次相同时不重复配置。
  ///
  /// 插件的桌面端 HTTP 客户端只使用 [Config.proxy]，不读取系统代理，所以必须显式写入。
  /// 配置在任务启动时被读取：已在传输中的任务保持原代理，只影响之后入队的任务。
  Future<void> _applyDownloadProxyIfChanged() async {
    final proxy = await _resolveDownloadProxy();
    if (_hasAppliedProxy && proxy == _appliedProxy) return;
    final configValue = proxy == null ? false : (proxy.host, proxy.port);
    await _downloader.configure(globalConfig: [(Config.proxy, configValue)]);
    _appliedProxy = proxy;
    _hasAppliedProxy = true;
    AppLogger.log(
      'BackgroundFileDownload',
      proxy == null
          ? 'proxy disabled, downloads connect directly'
          : 'proxy applied host=${proxy.host} port=${proxy.port}',
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
      'initializing plugin group=$kUserFilesDownloadGroup',
    );
    try {
      // 全局队列在原生侧排队，App 挂起时仍会推进；配置须先于首个任务生效。
      final configResults = await _downloader.configure(
        globalConfig: [
          (Config.holdingQueue, (maxConcurrentDownloads, null, null)),
        ],
      );
      // 插件对正常配置返回空字符串，未识别的配置返回非空说明。
      for (final (key, value) in configResults) {
        if (value.isNotEmpty) {
          AppLogger.log(
            'BackgroundFileDownload',
            'plugin config rejected key=$key value=$value',
          );
        }
      }
      final labels = await _resolveNotificationLabels();
      _downloader.configureNotificationForGroup(
        kUserFilesDownloadGroup,
        running: TaskNotification(labels.running, '{displayName}'),
        complete: TaskNotification(labels.complete, '{displayName}'),
        error: TaskNotification(labels.failed, '{displayName}'),
        progressBar: true,
      );
      _downloader.registerCallbacks(
        group: kUserFilesDownloadGroup,
        taskStatusCallback: _handleStatus,
        taskProgressCallback: _handleProgress,
      );
      await _downloader.trackTasksInGroup(kUserFilesDownloadGroup);
      await (_leftoverCleanup[_downloader] ??= _clearLeftoverTasks());
      await _downloader.start(
        doTrackTasks: false,
        doRescheduleKilledTasks: false,
        autoCleanDatabase: true,
      );
      AppLogger.log(
        'BackgroundFileDownload',
        'plugin ready group=$kUserFilesDownloadGroup',
      );
    } on Object catch (error) {
      AppLogger.log(
        'BackgroundFileDownload',
        'plugin initialization failed errorType=${error.runtimeType}',
      );
      rethrow;
    }
  }

  /// 清理上一进程遗留在本 group 中的原生任务。
  ///
  /// 这些任务没有 owner：资源登记表是进程内的，启动后无人认领它们，且 `doRescheduleKilledTasks`
  /// 为 false。不清理的话，同一资源的新任务会与它们同时写同一个临时文件。
  /// 每个 [FileDownloader] 只执行一次，避免多个 runner 互相取消对方的任务。
  Future<void> _clearLeftoverTasks() async {
    final cancelled = await _downloader.reset(group: kUserFilesDownloadGroup);
    AppLogger.log(
      'BackgroundFileDownload',
      'cleared leftover tasks count=$cancelled',
    );
  }

  /// 把插件状态映射为资源阶段；终态由 [_handleStatus] 的结果分支处理，这里不上报。
  void _reportPhase(_PendingDownload pending, TaskStatus status) {
    final phase = switch (status) {
      TaskStatus.enqueued => BackgroundDownloadPhase.queued,
      TaskStatus.running => BackgroundDownloadPhase.running,
      TaskStatus.waitingToRetry => BackgroundDownloadPhase.waitingToRetry,
      _ => null,
    };
    if (phase != null) pending.onPhase?.call(phase);
  }

  void _handleStatus(TaskStatusUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null || pending.completer.isCompleted) return;
    _reportPhase(pending, update.status);
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
          '${exception == null ? '' : ' error=${safeTaskExceptionDescription(exception)}'}',
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
    _notifyFinishedIfPluginSilent(update, pending);
  }

  /// 插件在桌面端不发终态通知，这里按终态补发；取消是用户主动操作，不提示。
  void _notifyFinishedIfPluginSilent(
    TaskStatusUpdate update,
    _PendingDownload pending,
  ) {
    final notifier = _completionNotifier;
    if (notifier == null) return;
    final title = switch (update.status) {
      TaskStatus.complete => pending.labels.complete,
      TaskStatus.failed || TaskStatus.notFound => pending.labels.failed,
      _ => null,
    };
    if (title == null) return;
    unawaited(
      notifier.notify(
        taskId: update.task.taskId,
        title: title,
        body: update.task.displayName,
      ),
    );
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

  void _handleProgress(TaskProgressUpdate update) {
    final pending = _pending[update.task.taskId];
    if (pending == null) return;
    // 负数是插件的状态哨兵（等待重试、暂停、失败等），不是进度值。
    // 重试续传时已收字节仍有效，因此必须原样保留，不能当作 0 回报。
    if (update.progress < 0) return;
    // 插件在完成时会补发一次 expectedFileSize 为 -1 的进度（1.0）。总大小已知时沿用，
    // 不能用 null 覆盖，否则界面会从百分比退回不定态，日志里的总大小也会丢失。
    final expectedBytes = update.expectedFileSize > 0
        ? update.expectedFileSize
        : pending.expectedBytes;
    final receivedBytes = expectedBytes == null
        ? 0
        : (update.progress * expectedBytes)
              .round()
              .clamp(0, expectedBytes)
              .toInt();
    pending.expectedBytes = expectedBytes;
    pending.receivedBytes = expectedBytes == null ? null : receivedBytes;
    pending.onProgress?.call(receivedBytes, expectedBytes);
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

/// 包装通知文案解析：解析失败只记录日志并回退英文。
///
/// 通知文案属于非关键路径，不能让文案解析异常拖垮插件初始化或下载入队。
BackgroundFileDownloadNotificationLabelResolver _guardNotificationLabels(
  BackgroundFileDownloadNotificationLabelResolver resolver,
) {
  return () async {
    try {
      return await resolver();
    } on Object catch (error) {
      AppLogger.log(
        'BackgroundFileDownload',
        'notification labels fallback to english errorType=${error.runtimeType}',
      );
      return _englishNotificationLabels();
    }
  };
}

Future<SystemProxyEndpoint?> _noDownloadProxy() async => null;

class _PendingDownload {
  _PendingDownload({
    required this.completer,
    required this.onProgress,
    required this.onPhase,
    required this.host,
    required this.safeUrl,
    required this.fileName,
    required this.labels,
  }) : stopwatch = Stopwatch()..start();

  final Completer<BackgroundDownloadResult> completer;
  final BackgroundFileDownloadProgress? onProgress;
  final void Function(BackgroundDownloadPhase phase)? onPhase;
  final String host;
  final String safeUrl;
  final String fileName;
  final BackgroundFileDownloadNotificationLabels labels;
  final Stopwatch stopwatch;
  int? receivedBytes;
  int? expectedBytes;
}

String _safeDiagnosticText(String value) => value.replaceAll(
  RegExp(r'https?://[^\s"<>]+', caseSensitive: false),
  '<url>',
);

/// 插件任务异常的脱敏描述；日志与开发者调试页共用，避免展示带 URL 的原文。
String safeTaskExceptionDescription(TaskException exception) =>
    '${exception.exceptionType}: ${_safeDiagnosticText(exception.description)}';

/// URL 资源的身份：去掉敏感参数的值（同一文件换签名不会被当成新资源）。
/// 只用于本地去重，不是安全边界；与日志使用同一脱敏规则。
String resourceKeyForUrl(Uri uri) => _safeDownloadUrl(uri);

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

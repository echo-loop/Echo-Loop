import 'dart:async';

import 'package:dio/dio.dart';

import 'background_file_download_exception.dart';

/// 单个资源的下载状态；所有入口读取的都是同一份状态。
sealed class ResourceDownloadState {
  const ResourceDownloadState(this.key);

  final String key;
}

/// 已登记，等待平台队列启动。
final class ResourceQueued extends ResourceDownloadState {
  const ResourceQueued(super.key);
}

/// 正在下载；字节数未知时为 null。
final class ResourceRunning extends ResourceDownloadState {
  const ResourceRunning(super.key, {this.receivedBytes, this.totalBytes});

  final int? receivedBytes;
  final int? totalBytes;
}

/// 插件正在等待重试（可能续传），尚未结束。
final class ResourceWaitingToRetry extends ResourceDownloadState {
  const ResourceWaitingToRetry(
    super.key, {
    this.receivedBytes,
    this.totalBytes,
  });

  final int? receivedBytes;
  final int? totalBytes;
}

final class ResourceSucceeded extends ResourceDownloadState {
  const ResourceSucceeded(super.key);
}

final class ResourceFailed extends ResourceDownloadState {
  const ResourceFailed(super.key, this.error);

  final BackgroundFileDownloadException error;
}

final class ResourceCanceled extends ResourceDownloadState {
  const ResourceCanceled(super.key);
}

/// 一个资源的下载任务句柄。同一资源同一时刻最多只有一个未结束的句柄。
final class ResourceDownload {
  ResourceDownload._({
    required this.key,
    required this.savePath,
    required this.predecessor,
  });

  final String key;
  final String savePath;

  /// 所有入口共享的取消令牌；任一入口取消都作用于此。
  final CancelToken cancelToken = CancelToken();

  /// 取消中被替换时，新任务必须等待的旧任务；否则为 null。
  final Future<void>? predecessor;

  final Completer<BackgroundFileDownloadException?> _outcome = Completer();
  final Completer<void> _finished = Completer();

  /// 最终结果：成功为 null，否则为错误（取消时 `isCanceled` 为 true）。
  Future<BackgroundFileDownloadException?> get outcome => _outcome.future;

  /// 任务进入终态后完成。
  Future<void> get finished => _finished.future;

  bool get isFinished => _finished.isCompleted;
}

/// [ResourceDownloadRegistry.acquire] 的结果：是新建任务，还是加入已有任务。
typedef ResourceAcquisition = ({ResourceDownload download, bool isNew});

/// 资源级下载任务登记表：同一资源只允许一个活动任务，所有入口共享它。
///
/// 登记与查找之间没有 `await`，因此并发调用不会各自新建任务。
/// 只读接口见 [ResourceDownloadReader]；状态变化只由服务层的回调推动。
class ResourceDownloadRegistry implements ResourceDownloadReader {
  final Map<String, ResourceDownload> _current = {};
  final Map<String, ResourceDownloadState> _states = {};
  final StreamController<ResourceDownloadState> _changes =
      StreamController<ResourceDownloadState>.broadcast(sync: true);

  @override
  ResourceDownloadState? stateOf(String key) => _states[key];

  @override
  Map<String, ResourceDownloadState> get snapshot => Map.unmodifiable(_states);

  /// 正在传输的资源数，用于判断新提交的任务是否有空闲的并发名额。
  int get runningCount => _states.values.whereType<ResourceRunning>().length;

  /// 同步广播：保证进度回调与调用方的时序一致。
  @override
  Stream<ResourceDownloadState> get changes => _changes.stream;

  /// 在登记任何任务之前校验整批请求：同一资源的活动任务必须写同一个 [savePath]。
  void validateSavePaths(Iterable<({String key, String savePath})> requests) {
    final requestedPaths = <String, String>{};
    for (final request in requests) {
      final joinable = _joinable(request.key);
      final expected = joinable?.savePath ?? requestedPaths[request.key];
      if (expected != null && expected != request.savePath) {
        throw StateError(
          'Resource ${request.key} is already downloading to a different path.',
        );
      }
      requestedPaths.putIfAbsent(request.key, () => request.savePath);
    }
  }

  /// 加入可复用的活动任务；没有则新建。取消中的任务不可加入，新任务排在其后。
  ResourceAcquisition acquire({required String key, required String savePath}) {
    final current = _current[key];
    if (current != null && !current.isFinished) {
      if (!current.cancelToken.isCancelled) {
        return (download: current, isNew: false);
      }
      return (
        download: _create(key, savePath, predecessor: current.finished),
        isNew: true,
      );
    }
    return (download: _create(key, savePath, predecessor: null), isNew: true);
  }

  /// 阶段变化不携带字节数时沿用上一次已知的进度，避免进度条回退到不定态。
  void markRunning(
    ResourceDownload download, {
    int? receivedBytes,
    int? totalBytes,
  }) {
    final known = _knownProgress(download.key);
    _publishIfCurrent(
      download,
      ResourceRunning(
        download.key,
        receivedBytes: receivedBytes ?? known.receivedBytes,
        totalBytes: totalBytes ?? known.totalBytes,
      ),
    );
  }

  void markQueued(ResourceDownload download) {
    _publishIfCurrent(download, ResourceQueued(download.key));
  }

  void markWaitingToRetry(
    ResourceDownload download, {
    int? receivedBytes,
    int? totalBytes,
  }) {
    final known = _knownProgress(download.key);
    _publishIfCurrent(
      download,
      ResourceWaitingToRetry(
        download.key,
        receivedBytes: receivedBytes ?? known.receivedBytes,
        totalBytes: totalBytes ?? known.totalBytes,
      ),
    );
  }

  /// 结束任务。幂等；只有仍是当前任务时才更新对外状态。
  void finish(
    ResourceDownload download,
    BackgroundFileDownloadException? error,
  ) {
    if (download.isFinished) return;
    if (identical(_current[download.key], download)) {
      _publish(_terminalState(download.key, error));
    }
    download._outcome.complete(error);
    download._finished.complete();
  }

  /// 取消指定任务；仅当它仍是该资源的当前活动任务时生效。
  void cancelEntry(ResourceDownload download) {
    if (download.isFinished) return;
    if (!identical(_current[download.key], download)) return;
    download.cancelToken.cancel('canceled');
  }

  /// 取消资源的当前任务，返回的 Future 在任务结束后完成。
  Future<void> cancelResource(String key) {
    final current = _current[key];
    if (current == null) return Future<void>.value();
    cancelEntry(current);
    return current.finished;
  }

  ResourceDownload? _joinable(String key) {
    final current = _current[key];
    if (current == null || current.isFinished) return null;
    if (current.cancelToken.isCancelled) return null;
    return current;
  }

  ResourceDownload _create(
    String key,
    String savePath, {
    required Future<void>? predecessor,
  }) {
    final download = ResourceDownload._(
      key: key,
      savePath: savePath,
      predecessor: predecessor,
    );
    _current[key] = download;
    _publish(ResourceQueued(key));
    return download;
  }

  void _publishIfCurrent(
    ResourceDownload download,
    ResourceDownloadState state,
  ) {
    if (download.isFinished) return;
    if (!identical(_current[download.key], download)) return;
    _publish(state);
  }

  ({int? receivedBytes, int? totalBytes}) _knownProgress(String key) {
    return switch (_states[key]) {
      ResourceRunning(:final receivedBytes, :final totalBytes) => (
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
      ),
      ResourceWaitingToRetry(:final receivedBytes, :final totalBytes) => (
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
      ),
      _ => (receivedBytes: null, totalBytes: null),
    };
  }

  void _publish(ResourceDownloadState state) {
    _states[state.key] = state;
    _changes.add(state);
  }

  ResourceDownloadState _terminalState(
    String key,
    BackgroundFileDownloadException? error,
  ) {
    if (error == null) return ResourceSucceeded(key);
    if (error.isCanceled) return ResourceCanceled(key);
    return ResourceFailed(key, error);
  }
}

/// 对外只读视图：UI 与其它服务只能通过它读取状态。
abstract interface class ResourceDownloadReader {
  ResourceDownloadState? stateOf(String key);

  Map<String, ResourceDownloadState> get snapshot;

  Stream<ResourceDownloadState> get changes;
}

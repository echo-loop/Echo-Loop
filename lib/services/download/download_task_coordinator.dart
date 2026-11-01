import 'dart:async';

import 'package:dio/dio.dart';

import '../app_logger.dart';
import 'download_failure.dart';
import 'download_resource.dart';
import 'download_task_store.dart';

class DownloadTaskState {
  const DownloadTaskState({
    required this.resourceId,
    required this.status,
    this.progress = 0,
    this.receivedBytes = 0,
    this.totalBytes,
    this.failure,
  });

  final String resourceId;
  final DownloadTaskStatus status;
  final double progress;
  final int receivedBytes;
  final int? totalBytes;
  final DownloadFailureKind? failure;

  bool get isReady => status == DownloadTaskStatus.downloaded;
  bool get isActive =>
      status == DownloadTaskStatus.queued ||
      status == DownloadTaskStatus.downloading;
}

class DownloadTaskCoordinator {
  DownloadTaskCoordinator({
    required Iterable<DownloadResource> resources,
    required DownloadTaskStore store,
  }) : _resources = {for (final resource in resources) resource.id: resource},
       _store = store;

  final Map<String, DownloadResource> _resources;
  final DownloadTaskStore _store;
  final _controllers = <String, CancelToken>{};
  final _tasks = <String, Future<void>>{};
  final _states = <String, DownloadTaskState>{};
  final _controllersByListener =
      <String, StreamController<DownloadTaskState>>{};

  DownloadResource _resource(String id) =>
      _resources[id] ?? (throw ArgumentError('Unknown download resource: $id'));

  DownloadResource resourceOf(String id) => _resource(id);

  DownloadTaskState stateOf(String id) =>
      _states[id] ??
      DownloadTaskState(resourceId: id, status: DownloadTaskStatus.queued);

  Stream<DownloadTaskState> watch(String id) =>
      (_controllersByListener[id] ??=
              StreamController<DownloadTaskState>.broadcast())
          .stream;

  Future<DownloadTaskState> refresh(String id) async {
    final resource = _resource(id);
    if (await resource.isReady()) {
      return _publish(
        DownloadTaskState(
          resourceId: id,
          status: DownloadTaskStatus.downloaded,
          progress: 1,
        ),
      );
    }
    final record = await _store.read(id);
    if (record?.status == DownloadTaskStatus.failed) {
      return _publish(_fromRecord(record!));
    }
    return _publish(
      DownloadTaskState(
        resourceId: id,
        status: DownloadTaskStatus.notDownloaded,
      ),
    );
  }

  Future<void> start(String id) {
    final existing = _tasks[id];
    if (existing != null) return existing;
    final task = _run(id);
    _tasks[id] = task;
    return task.whenComplete(() {
      if (identical(_tasks[id], task)) _tasks.remove(id);
    });
  }

  /// 启动期静默确保资源可用；调用方不应等待该 Future，以免阻塞首帧。
  Future<void> startSilently(String id) async {
    final state = await refresh(id);
    if (!state.isReady && !state.isActive) {
      unawaited(start(id));
    }
  }

  Future<void> cancel(String id) async {
    _controllers.remove(id)?.cancel('user cancelled');
    final task = _tasks[id];
    _publish(
      DownloadTaskState(
        resourceId: id,
        status: DownloadTaskStatus.notDownloaded,
      ),
    );
    if (task != null) await task;
    await _resource(id).deletePartial();
    await _store.remove(id);
  }

  Future<void> _run(String id) async {
    final resource = _resource(id);
    final token = CancelToken();
    _controllers[id] = token;
    await _store.write(
      DownloadTaskRecord(
        resourceId: id,
        status: DownloadTaskStatus.downloading,
      ),
    );
    _publish(
      DownloadTaskState(resourceId: id, status: DownloadTaskStatus.downloading),
    );
    try {
      await resource.download(
        cancelToken: token,
        onProgress: (received, total) {
          final progress = total == null || total <= 0
              ? 0.0
              : (received / total).clamp(0.0, 1.0);
          _publish(
            DownloadTaskState(
              resourceId: id,
              status: DownloadTaskStatus.downloading,
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
            ),
          );
        },
      );
      if (token.isCancelled) return;
      await _store.write(
        DownloadTaskRecord(
          resourceId: id,
          status: DownloadTaskStatus.downloaded,
        ),
      );
      _publish(
        DownloadTaskState(
          resourceId: id,
          status: DownloadTaskStatus.downloaded,
          progress: 1,
        ),
      );
    } catch (error, stack) {
      if (token.isCancelled || _isCancelled(error)) return;
      final failure = classifyDownloadFailure(error);
      AppLogger.log(
        'Download',
        'resource=$id failed kind=$failure error=$error',
      );
      await _store.write(
        DownloadTaskRecord(
          resourceId: id,
          status: DownloadTaskStatus.failed,
          failure: failure,
        ),
      );
      _publish(
        DownloadTaskState(
          resourceId: id,
          status: DownloadTaskStatus.failed,
          failure: failure,
        ),
      );
      AppLogger.log('Download', '$stack');
    } finally {
      _controllers.remove(id);
    }
  }

  DownloadTaskState _fromRecord(DownloadTaskRecord record) => DownloadTaskState(
    resourceId: record.resourceId,
    status: record.status,
    receivedBytes: record.receivedBytes,
    totalBytes: record.totalBytes,
    failure: record.failure,
    progress: record.totalBytes == null || record.totalBytes == 0
        ? 0
        : (record.receivedBytes / record.totalBytes!).clamp(0.0, 1.0),
  );

  DownloadTaskState _publish(DownloadTaskState next) {
    _states[next.resourceId] = next;
    _controllersByListener[next.resourceId]?.add(next);
    return next;
  }

  bool _isCancelled(Object error) =>
      error is DioException && error.type == DioExceptionType.cancel;

  Future<void> dispose() async {
    for (final token in _controllers.values) {
      token.cancel('coordinator disposed');
    }
    await Future.wait(_controllersByListener.values.map((c) => c.close()));
  }
}

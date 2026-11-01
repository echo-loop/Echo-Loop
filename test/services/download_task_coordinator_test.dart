import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/services/download/download_resource.dart';
import 'package:echo_loop/services/download/download_task_coordinator.dart';
import 'package:echo_loop/services/download/download_task_store.dart';

class _MemoryStore implements DownloadTaskStore {
  final values = <String, DownloadTaskRecord>{};

  @override
  Future<DownloadTaskRecord?> read(String resourceId) async =>
      values[resourceId];

  @override
  Future<void> remove(String resourceId) async => values.remove(resourceId);

  @override
  Future<void> write(DownloadTaskRecord record) async =>
      values[record.resourceId] = record;
}

class _Resource implements DownloadResource {
  _Resource({this.fail = false});

  bool fail;
  bool ready = false;
  int downloadCalls = 0;
  int deleteCalls = 0;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  String get id => 'model';

  @override
  String get displayName => 'Test model';

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> deletePartial() async => deleteCalls++;

  @override
  Future<void> download({
    required void Function(int receivedBytes, int? totalBytes) onProgress,
    required CancelToken cancelToken,
  }) async {
    downloadCalls++;
    if (!started.isCompleted) started.complete();
    onProgress(50, 100);
    if (fail) throw StateError('failed');
    await Future.any([release.future, cancelToken.whenCancel]);
    if (cancelToken.isCancelled) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
      );
    }
    ready = true;
  }
}

void main() {
  test('同一资源重复启动只执行一个任务并发布完成状态', () async {
    final resource = _Resource();
    final coordinator = DownloadTaskCoordinator(
      resources: [resource],
      store: _MemoryStore(),
    );
    final states = <DownloadTaskState>[];
    final subscription = coordinator.watch(resource.id).listen(states.add);
    addTearDown(() async {
      await subscription.cancel();
      await coordinator.dispose();
    });

    final first = coordinator.start(resource.id);
    final second = coordinator.start(resource.id);
    await resource.started.future;
    expect(resource.downloadCalls, 1);
    resource.release.complete();
    await Future.wait([first, second]);
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.stateOf(resource.id).isReady, isTrue);
    expect(
      states.map((state) => state.status),
      contains(DownloadTaskStatus.downloaded),
    );
    expect(states.last.progress, 1);
  });

  test('失败状态可保留结构化错误并再次重试', () async {
    final resource = _Resource(fail: true);
    final store = _MemoryStore();
    final coordinator = DownloadTaskCoordinator(
      resources: [resource],
      store: store,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start(resource.id);

    expect(coordinator.stateOf(resource.id).status, DownloadTaskStatus.failed);
    expect(
      coordinator.stateOf(resource.id).failure,
      DownloadFailureKind.unknown,
    );
    expect(store.values[resource.id]?.status, DownloadTaskStatus.failed);

    resource.fail = false;
    final retry = coordinator.start(resource.id);
    resource.release.complete();
    await retry;
    expect(
      coordinator.stateOf(resource.id).status,
      DownloadTaskStatus.downloaded,
    );
  });

  test('取消会立即清理部分文件且不进入失败状态', () async {
    final resource = _Resource();
    final coordinator = DownloadTaskCoordinator(
      resources: [resource],
      store: _MemoryStore(),
    );
    addTearDown(coordinator.dispose);

    final task = coordinator.start(resource.id);
    await resource.started.future;
    final cancel = coordinator.cancel(resource.id);
    await cancel;
    await task;

    expect(resource.deleteCalls, 1);
    expect(
      coordinator.stateOf(resource.id).status,
      DownloadTaskStatus.notDownloaded,
    );
    expect(coordinator.stateOf(resource.id).failure, isNull);
  });

  test('refresh 优先使用资源完整性而不是过期持久化状态', () async {
    final resource = _Resource()..ready = true;
    final store = _MemoryStore()
      ..values[resource.id] = const DownloadTaskRecord(
        resourceId: 'model',
        status: DownloadTaskStatus.failed,
        failure: DownloadFailureKind.network,
      );
    final coordinator = DownloadTaskCoordinator(
      resources: [resource],
      store: store,
    );
    addTearDown(coordinator.dispose);

    final state = await coordinator.refresh(resource.id);

    expect(state.status, DownloadTaskStatus.downloaded);
    expect(state.progress, 1);
  });
}

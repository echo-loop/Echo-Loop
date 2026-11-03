import 'package:echo_loop/services/background_file_download_exception.dart';
import 'package:echo_loop/services/resource_download_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ResourceDownloadRegistry registry;

  setUp(() {
    registry = ResourceDownloadRegistry();
  });

  test('同一资源在活动期间只登记一个任务，后来者加入同一任务', () {
    final first = registry.acquire(key: 'audio:1', savePath: '/tmp/a.part');
    final second = registry.acquire(key: 'audio:1', savePath: '/tmp/a.part');

    expect(first.isNew, isTrue);
    expect(second.isNew, isFalse);
    expect(identical(first.download, second.download), isTrue);
    expect(registry.stateOf('audio:1'), isA<ResourceQueued>());
  });

  test('同一资源提交不同 savePath 会在登记前被拒绝，且不留下任何任务', () {
    registry.acquire(key: 'audio:1', savePath: '/tmp/a.part');

    expect(
      () => registry.validateSavePaths([
        (key: 'audio:1', savePath: '/tmp/other.part'),
      ]),
      throwsStateError,
    );
    // 批内冲突同样拒绝，而不是只检查已登记的任务。
    expect(
      () => registry.validateSavePaths([
        (key: 'audio:2', savePath: '/tmp/b.part'),
        (key: 'audio:2', savePath: '/tmp/c.part'),
      ]),
      throwsStateError,
    );
  });

  test('取消共享任务会让状态变为 Canceled，并结束结果 Future', () async {
    final acquisition = registry.acquire(key: 'audio:1', savePath: '/tmp/a');
    final download = acquisition.download;

    final cancelled = registry.cancelResource('audio:1');
    expect(download.cancelToken.isCancelled, isTrue);

    registry.finish(
      download,
      const BackgroundFileDownloadException('canceled', isCanceled: true),
    );
    await cancelled;
    expect(await download.outcome, isA<BackgroundFileDownloadException>());
    expect(registry.stateOf('audio:1'), isA<ResourceCanceled>());
  });

  test('加入者取消会取消同一个任务，但不会影响终态之后的新任务', () async {
    final first = registry.acquire(key: 'audio:1', savePath: '/tmp/a').download;
    registry.finish(first, null);
    final second = registry
        .acquire(key: 'audio:1', savePath: '/tmp/a')
        .download;

    // 旧任务的取消回调绑定在旧任务上，不能误取消已经开始的新任务。
    registry.cancelEntry(first);
    expect(second.cancelToken.isCancelled, isFalse);
    expect(registry.stateOf('audio:1'), isA<ResourceQueued>());
  });

  test('取消中再次提交：新任务登记为当前任务，并等待旧任务结束', () async {
    final old = registry.acquire(key: 'audio:1', savePath: '/tmp/a').download;
    registry.cancelResource('audio:1');

    final replacement = registry.acquire(key: 'audio:1', savePath: '/tmp/a');

    expect(replacement.isNew, isTrue);
    expect(identical(replacement.download, old), isFalse);
    expect(replacement.download.predecessor, isNotNull);
    var replacementStarted = false;
    replacement.download.finished.then((_) => replacementStarted = true);

    await Future<void>.delayed(Duration.zero);
    expect(replacementStarted, isFalse);

    registry.finish(
      old,
      const BackgroundFileDownloadException('canceled', isCanceled: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(registry.stateOf('audio:1'), isA<ResourceQueued>());
    // 旧任务的终态不能覆盖新任务的状态。
    expect(
      identical(registry.acquire(key: 'audio:1', savePath: '/tmp/a').download,
          replacement.download),
      isTrue,
    );
  });

  test('成功或失败后再次提交会新建任务并覆盖终态', () {
    final first = registry.acquire(key: 'audio:1', savePath: '/tmp/a').download;
    registry.finish(
      first,
      const BackgroundFileDownloadException('network down'),
    );
    expect(registry.stateOf('audio:1'), isA<ResourceFailed>());

    final retry = registry.acquire(key: 'audio:1', savePath: '/tmp/a');
    expect(retry.isNew, isTrue);
    expect(registry.stateOf('audio:1'), isA<ResourceQueued>());
  });

  test('进度与阶段通过 changes 广播，终态后不再接受中间状态', () {
    final received = <ResourceDownloadState>[];
    final subscription = registry.changes.listen(received.add);
    final download = registry
        .acquire(key: 'audio:1', savePath: '/tmp/a')
        .download;

    registry.markRunning(download, receivedBytes: 10, totalBytes: 100);
    registry.markWaitingToRetry(download, receivedBytes: 10, totalBytes: 100);
    registry.finish(download, null);
    registry.markRunning(download, receivedBytes: 20, totalBytes: 100);

    expect(received[1], isA<ResourceRunning>());
    expect((received[1] as ResourceRunning).receivedBytes, 10);
    expect(received[2], isA<ResourceWaitingToRetry>());
    expect(received[3], isA<ResourceSucceeded>());
    expect(received, hasLength(4));
    expect(registry.stateOf('audio:1'), isA<ResourceSucceeded>());
    subscription.cancel();
  });

  test('snapshot 包含所有资源的当前状态', () {
    registry.acquire(key: 'audio:1', savePath: '/tmp/a');
    registry.acquire(key: 'audio:2', savePath: '/tmp/b');

    expect(registry.snapshot.keys, unorderedEquals(['audio:1', 'audio:2']));
  });
}

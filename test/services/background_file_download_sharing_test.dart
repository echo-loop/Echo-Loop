import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/services/resource_download_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// 可控的批量 runner：每次提交的完成时机由测试决定；取消会让对应提交以取消结束。
class _ControlledRunner
    implements BackgroundDownloadRunner, BackgroundDownloadBatchRunner {
  final List<BackgroundFileDownloadRequest> submitted = [];
  final List<Completer<BackgroundDownloadResult>> _completers = [];
  final List<BackgroundFileDownloadBatchProgress?> _progress = [];
  final List<BackgroundDownloadPhaseCallback?> _phases = [];

  /// 为 false 时取消不会自动结束提交，由测试通过 [completeCanceled] 手动结束。
  bool autoCancel = true;

  @override
  Future<List<BackgroundDownloadResult>> enqueueBatch({
    required List<BackgroundFileDownloadRequest> requests,
    required BackgroundFileDownloadBatchProgress? onProgress,
    required BackgroundDownloadPhaseCallback? onPhase,
    required CancelToken? cancelToken,
  }) {
    return Future.wait(
      requests.map((request) {
        final index = _register(request, onProgress, onPhase, cancelToken);
        return _completers[index].future;
      }),
    );
  }

  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) {
    final request = BackgroundFileDownloadRequest(
      id: savePath,
      uri: uri,
      savePath: savePath,
    );
    final index = _register(request, null, null, cancelToken);
    return _completers[index].future;
  }

  int _register(
    BackgroundFileDownloadRequest request,
    BackgroundFileDownloadBatchProgress? onProgress,
    BackgroundDownloadPhaseCallback? onPhase,
    CancelToken? cancelToken,
  ) {
    final index = submitted.length;
    submitted.add(request);
    _progress.add(onProgress);
    _phases.add(onPhase);
    final completer = Completer<BackgroundDownloadResult>();
    _completers.add(completer);
    if (autoCancel) {
      cancelToken?.whenCancel.then((_) => completeCanceled(index));
    }
    return index;
  }

  void reportProgress(int index, int received, int? total) {
    _progress[index]?.call(submitted[index].id, received, total);
  }

  void reportPhase(int index, BackgroundDownloadPhase phase) {
    _phases[index]?.call(submitted[index].id, phase);
  }

  /// 写入目标文件并以完成结束，与插件成功回调的顺序一致。
  void succeed(int index) {
    File(submitted[index].savePath).writeAsBytesSync(const <int>[1, 2]);
    _completers[index].complete(
      const BackgroundDownloadResult(status: BackgroundDownloadStatus.complete),
    );
  }

  void completeCanceled(int index) {
    if (_completers[index].isCompleted) return;
    _completers[index].complete(
      const BackgroundDownloadResult(status: BackgroundDownloadStatus.canceled),
    );
  }

  void fail(int index) {
    _completers[index].complete(
      const BackgroundDownloadResult(
        status: BackgroundDownloadStatus.failed,
        message: 'network down',
      ),
    );
  }
}

void main() {
  late Directory dataDir;
  late _ControlledRunner runner;
  late BackgroundFileDownloadService service;
  final uri = Uri.parse('https://example.com/audio.mp3');

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('download-sharing-');
    runner = _ControlledRunner();
    // 每个测试使用独立登记表，避免测试之间共享资源状态。
    service = BackgroundFileDownloadService(
      runner: runner,
      registry: ResourceDownloadRegistry(),
    );
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  String pathFor(String name) => '${dataDir.path}/$name';

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('同一资源的重复请求只提交一次，两个调用方共享同一个结果', () async {
    final target = pathFor('audio.mp3');
    final first = service.download(uri: uri, savePath: target);
    final second = service.download(uri: uri, savePath: target);
    await settle();

    expect(runner.submitted, hasLength(1));
    runner.succeed(0);
    await Future.wait([first, second]);
    expect(File(target).existsSync(), isTrue);
  });

  test('任一调用方取消共享任务后，所有等待者都以取消结束', () async {
    final target = pathFor('audio.mp3');
    final first = service.download(uri: uri, savePath: target);
    final second = service.download(uri: uri, savePath: target);
    await settle();

    // 先挂上断言再触发取消，避免结果在无监听时已经报错。
    final firstResult = expectLater(
      first,
      throwsA(
        isA<BackgroundFileDownloadException>().having(
          (error) => error.isCanceled,
          'isCanceled',
          isTrue,
        ),
      ),
    );
    final secondResult = expectLater(
      second,
      throwsA(isA<BackgroundFileDownloadException>()),
    );
    await service.cancelResource(target);

    await firstResult;
    await secondResult;
    expect(service.downloads.stateOf(target), isA<ResourceCanceled>());
  });

  test('加入者的 CancelToken 取消会取消同一个共享任务', () async {
    final target = pathFor('audio.mp3');
    final owner = service.download(uri: uri, savePath: target);
    final joinerToken = CancelToken();
    final joiner = service.download(
      uri: uri,
      savePath: target,
      cancelToken: joinerToken,
    );
    await settle();

    final ownerResult = expectLater(
      owner,
      throwsA(isA<BackgroundFileDownloadException>()),
    );
    final joinerResult = expectLater(
      joiner,
      throwsA(isA<BackgroundFileDownloadException>()),
    );
    joinerToken.cancel('user');

    await ownerResult;
    await joinerResult;
    expect(runner.submitted, hasLength(1));
  });

  test('进度与阶段同时推送给所有共享调用方', () async {
    final target = pathFor('audio.mp3');
    final firstProgress = <(int, int?)>[];
    final secondProgress = <(int, int?)>[];
    final first = service.download(
      uri: uri,
      savePath: target,
      onProgress: (received, total) => firstProgress.add((received, total)),
    );
    final second = service.download(
      uri: uri,
      savePath: target,
      onProgress: (received, total) => secondProgress.add((received, total)),
    );
    await settle();

    runner.reportProgress(0, 50, 100);
    runner.reportPhase(0, BackgroundDownloadPhase.waitingToRetry);
    expect(service.downloads.stateOf(target), isA<ResourceWaitingToRetry>());
    runner.reportPhase(0, BackgroundDownloadPhase.running);
    runner.succeed(0);
    await Future.wait([first, second]);

    expect(firstProgress.last, (50, 100));
    expect(secondProgress.last, (50, 100));
    expect(service.downloads.stateOf(target), isA<ResourceSucceeded>());
  });

  test('同一资源提交不同 savePath 会被拒绝，且不会提交任何任务', () async {
    final target = pathFor('audio.mp3');
    final first = service.download(uri: uri, savePath: target);
    await settle();

    await expectLater(
      service.download(
        uri: uri,
        savePath: pathFor('other.mp3'),
        resourceKey: target,
      ),
      throwsStateError,
    );
    expect(runner.submitted, hasLength(1));

    runner.succeed(0);
    await first;
  });

  test('取消中再次提交：新任务等旧任务结束后才提交给 runner', () async {
    runner.autoCancel = false;
    final target = pathFor('audio.mp3');
    final cancelled = service.download(uri: uri, savePath: target);
    await settle();
    final cancelledResult = expectLater(
      cancelled,
      throwsA(isA<BackgroundFileDownloadException>()),
    );

    // 旧提交尚未结束（取消中），此时再次提交。
    unawaited(service.cancelResource(target));
    final replacement = service.download(uri: uri, savePath: target);
    await settle();
    // 旧的原生提交未结束前，新任务不能提交，否则两个任务会同时写同一文件。
    expect(runner.submitted, hasLength(1));

    runner.completeCanceled(0);
    await cancelledResult;
    await settle();
    expect(runner.submitted, hasLength(2));

    runner.succeed(1);
    await replacement;
  });

  test('失败后再次提交会新建任务，状态被覆盖为新任务的状态', () async {
    final target = pathFor('audio.mp3');
    final failed = service.download(uri: uri, savePath: target);
    await settle();
    runner.fail(0);
    await expectLater(failed, throwsA(isA<BackgroundFileDownloadException>()));
    expect(service.downloads.stateOf(target), isA<ResourceFailed>());

    final retry = service.download(uri: uri, savePath: target);
    await settle();
    expect(runner.submitted, hasLength(2));
    expect(service.downloads.stateOf(target), isA<ResourceRunning>());

    runner.succeed(1);
    await retry;
  });

  test('同一批内的重复资源只提交一次，并返回相同结果', () async {
    final target = pathFor('audio.mp3');
    final batch = service.downloadBatch(
      requests: [
        BackgroundFileDownloadRequest(id: 'first', uri: uri, savePath: target),
        BackgroundFileDownloadRequest(id: 'second', uri: uri, savePath: target),
      ],
    );
    await settle();
    expect(runner.submitted, hasLength(1));

    runner.succeed(0);
    final outcomes = await batch;
    expect(outcomes.map((outcome) => outcome.request.id), ['first', 'second']);
    expect(outcomes.every((outcome) => outcome.succeeded), isTrue);
  });

  test('成功后删除文件再次下载，会重新提交给 runner 而不是复用旧结果', () async {
    final target = pathFor('audio.mp3');
    final first = service.download(uri: uri, savePath: target);
    await settle();
    runner.succeed(0);
    await first;

    // 用户删除音频后重新下载：成功状态只用于展示，不能阻止新的下载。
    File(target).deleteSync();
    final second = service.download(uri: uri, savePath: target);
    await settle();
    expect(runner.submitted, hasLength(2));

    runner.succeed(1);
    await second;
    expect(File(target).existsSync(), isTrue);
  });

  test('URL 资源的身份忽略签名参数的值，但保留资源本身的区分', () {
    final signedA = Uri.parse('https://cdn.example.com/a.m4a?sig=111&id=7');
    final signedB = Uri.parse('https://cdn.example.com/a.m4a?sig=222&id=7');
    final otherFile = Uri.parse('https://cdn.example.com/a.m4a?sig=111&id=8');

    expect(resourceKeyForUrl(signedA), resourceKeyForUrl(signedB));
    expect(resourceKeyForUrl(signedA), isNot(resourceKeyForUrl(otherFile)));
    expect(resourceKeyForUrl(signedA), isNot(contains('111')));
  });

  test('并发名额有空位时直接下载中，名额已满时排队，名额释放后开始', () async {
    final targets = [
      for (final name in ['a', 'b', 'c']) pathFor('$name.mp3'),
    ];
    final futures = [
      for (final target in targets)
        service.download(uri: uri, savePath: target),
    ];
    await settle();

    expect(service.downloads.stateOf(targets[0]), isA<ResourceRunning>());
    expect(service.downloads.stateOf(targets[1]), isA<ResourceRunning>());
    expect(service.downloads.stateOf(targets[2]), isA<ResourceQueued>());

    // 平台仍会回报 enqueued：排队中的任务保持排队，正在下载的任务不能被降级。
    runner.reportPhase(2, BackgroundDownloadPhase.queued);
    runner.reportPhase(0, BackgroundDownloadPhase.queued);
    expect(service.downloads.stateOf(targets[2]), isA<ResourceQueued>());
    expect(service.downloads.stateOf(targets[0]), isA<ResourceRunning>());

    runner.succeed(0);
    await futures[0];
    runner.reportPhase(2, BackgroundDownloadPhase.running);
    expect(service.downloads.stateOf(targets[2]), isA<ResourceRunning>());

    runner.succeed(1);
    runner.succeed(2);
    await Future.wait(futures);
  });
}

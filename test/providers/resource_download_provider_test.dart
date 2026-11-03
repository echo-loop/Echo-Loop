import 'package:dio/dio.dart';
import 'package:echo_loop/providers/download_provider.dart';
import 'package:echo_loop/services/background_file_download_service.dart';
import 'package:echo_loop/services/resource_download_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本测试只通过登记表推动状态，不会真正下载。
class _UnusedRunner implements BackgroundDownloadRunner {
  @override
  Future<BackgroundDownloadResult> enqueue({
    required Uri uri,
    required String savePath,
    String? displayName,
    required Map<String, String> headers,
    required BackgroundFileDownloadProgress? onProgress,
    required CancelToken? cancelToken,
  }) {
    throw UnimplementedError('runner is not used in provider tests');
  }
}

void main() {
  test('resourceDownloadProvider 只反映自己资源的状态变化', () async {
    final registry = ResourceDownloadRegistry();
    final service = BackgroundFileDownloadService(
      runner: _UnusedRunner(),
      registry: registry,
    );
    final container = ProviderContainer(
      overrides: [
        backgroundFileDownloadServiceProvider.overrideWithValue(service),
        resourceDownloadRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);

    final seen = <ResourceDownloadState?>[];
    container.listen(
      resourceDownloadProvider('audio:1'),
      (_, next) => seen.add(next),
      fireImmediately: true,
    );

    final download = registry
        .acquire(key: 'audio:1', savePath: '/tmp/a')
        .download;
    // Riverpod 异步派发监听回调，每步之后让出事件循环再断言。
    await Future<void>.delayed(Duration.zero);
    registry.markRunning(download, receivedBytes: 1, totalBytes: 2);
    await Future<void>.delayed(Duration.zero);
    // 其它资源的变化不应该进入该资源的监听。
    registry.acquire(key: 'audio:2', savePath: '/tmp/b');
    await Future<void>.delayed(Duration.zero);

    expect(seen.map((state) => state.runtimeType).toList(), [
      Null,
      ResourceQueued,
      ResourceRunning,
    ]);
  });
}

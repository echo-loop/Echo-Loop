import 'dart:async';
import 'dart:io' show FileSystemException, OSError;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/providers/tts/kokoro_model_provider.dart';
import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/resource_install_manifest.dart';
import 'package:echo_loop/services/tts/kokoro_model_manager.dart';
import '../../helpers/mock_providers.dart';

const _fp32 = KokoroModelVariant.fp32;

/// 可编排行为的假管理器（不区分变体，按需被 family override 复用）。
class _FakeManager extends KokoroModelManager {
  _FakeManager({
    this.shouldFail = false,
    this.shouldCancel = false,
    this.failError,
    bool downloaded = false,
    this.installMarker = false,
  }) : _downloaded = downloaded,
       super(modelsRootResolver: () async => '/tmp/none');

  bool shouldFail;
  bool shouldCancel;

  /// shouldFail 时抛出的异常（默认 StateError('boom')，供归类测试自定义）。
  Object? failError;
  bool _downloaded;
  bool installMarker;
  int manifestSize = 1024;
  int downloadCount = 0;
  int deleteCount = 0;

  @override
  Future<String> downloadModel({
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCount++;
    onProgress?.call(
      const AsrModelDownloadProgress(
        status: AsrModelDownloadStatus.downloading,
        progress: 0.5,
      ),
    );
    if (shouldCancel) {
      // 迁移到 ReliableHttpDownloader 后，KokoroModelManager 取消时抛的是
      // 结构化 ReliableDownloadException（不再是裸 DioException），fake 需要
      // 如实模拟，否则测不出 provider 对新异常类型的取消判定分支。
      throw const ReliableDownloadException(
        'cancelled',
        kind: ReliableDownloadFailure.cancelled,
      );
    }
    if (shouldFail) {
      throw failError ?? StateError('boom');
    }
    _downloaded = true;
    return '/tmp/none/model';
  }

  @override
  Future<int> modelLocalSize() async =>
      _downloaded ? 1024 : (shouldFail ? 10 : 0);

  @override
  Future<bool> isModelDownloaded() async => _downloaded;

  @override
  Future<bool> hasInstallMarker() async => installMarker;

  @override
  Future<ResourceInstallManifest?> readInstallManifest() async {
    if (!installMarker && !_downloaded) return null;
    return ResourceInstallManifest(
      resourceId: spec.id,
      installAt: DateTime(2026, 8, 26),
      resourceSize: manifestSize,
    );
  }

  @override
  Future<void> deleteModel() async {
    deleteCount++;
    _downloaded = false;
  }
}

class _BlockingCancelManager extends _FakeManager {
  final release = Completer<void>();

  @override
  Future<String> downloadModel({
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    downloadCount++;
    if (cancelToken == null) throw StateError('cancel token is required');
    await cancelToken.whenCancel;
    await release.future;
    throw const ReliableDownloadException(
      'cancelled',
      kind: ReliableDownloadFailure.cancelled,
    );
  }
}

ProviderContainer _container(
  _FakeManager manager, {
  KokoroModelsState? initial,
}) {
  return ProviderContainer(
    overrides: dedupeOverrides([
      kokoroModelManagerProvider.overrideWith((ref, variant) => manager),
      initialKokoroModelStateProvider.overrideWithValue(
        initial ?? KokoroModelsState.initial(),
      ),
    ]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ensureDownloaded 成功 → ready + 进度 1.0 + 体积', () async {
    final c = _container(_FakeManager());
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    final s = c.read(kokoroModelProvider).of(_fp32);
    expect(s.isReady, isTrue);
    expect(s.downloadProgress, 1.0);
    expect(s.localSizeBytes, 1024);
    expect(c.read(kokoroReadyProvider), isTrue);
  });

  test('已有 install.json → 同步 ready 且不重复下载', () async {
    final manager = _FakeManager(downloaded: true, installMarker: true);
    final c = _container(manager);
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    expect(manager.downloadCount, 0);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);
    expect(c.read(kokoroModelProvider).of(_fp32).localSizeBytes, 1024);
    expect(
      c.read(kokoroModelProvider).of(_fp32).installManifest?.resourceSize,
      1024,
    );
  });

  test('refreshInstalledStates 检查全部变体且不下载', () async {
    final manager = _FakeManager(downloaded: true, installMarker: true);
    final c = _container(manager);
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).refreshInstalledStates();

    expect(
      KokoroModelVariant.values.every(
        (variant) => c.read(kokoroModelProvider).of(variant).isReady,
      ),
      isTrue,
    );
    expect(manager.downloadCount, 0);
  });

  test('ensureDownloaded 已就绪 → 不重复下载', () async {
    final manager = _FakeManager();
    final c = _container(
      manager,
      initial: const KokoroModelsState({
        _fp32: KokoroModelState(
          downloadStatus: AsrModelDownloadStatus.downloaded,
          localSizeBytes: 1024,
        ),
      }),
    );
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);
    expect(manager.downloadCount, 0);
  });

  test('并发 ensureDownloaded（同帧重复触发）只下载一次', () async {
    // 复现「进度条来回跳」：状态翻转为下载中须同步先于任何 await，否则两个并发
    // 调用都漏过「未在下载」判定、各起一路下载、回调交错。
    final manager = _FakeManager();
    final c = _container(manager);
    addTearDown(c.dispose);

    final n = c.read(kokoroModelProvider.notifier);
    final f1 = n.ensureDownloaded(_fp32);
    final f2 = n.ensureDownloaded(_fp32);
    await Future.wait([f1, f2]);

    expect(manager.downloadCount, 1);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);
  });

  test('下载失败（未知原因）→ failed + downloadError=unknown', () async {
    final c = _container(_FakeManager(shouldFail: true));
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    final s = c.read(kokoroModelProvider).of(_fp32);
    expect(s.downloadStatus, AsrModelDownloadStatus.failed);
    expect(s.downloadError, DownloadFailureKind.unknown);
    expect(s.isReady, isFalse);
  });

  test('下载失败后 ensureDownloaded 不隐式重试', () async {
    final manager = _FakeManager(shouldFail: true);
    final c = _container(manager);
    addTearDown(c.dispose);
    final notifier = c.read(kokoroModelProvider.notifier);

    await notifier.ensureDownloaded(_fp32);
    await notifier.ensureDownloaded(_fp32);

    expect(manager.downloadCount, 1);
    expect(
      c.read(kokoroModelProvider).of(_fp32).downloadStatus,
      AsrModelDownloadStatus.failed,
    );
  });

  test('存储空间不足（errno 28）→ downloadError=insufficientStorage', () async {
    final c = _container(
      _FakeManager(
        shouldFail: true,
        failError: const FileSystemException(
          'writeFrom failed',
          '/tmp/temp.tar',
          OSError('No space left on device', 28),
        ),
      ),
    );
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    expect(
      c.read(kokoroModelProvider).of(_fp32).downloadError,
      DownloadFailureKind.insufficientStorage,
    );
  });

  test('整包 SHA 不匹配 → downloadError=verification', () async {
    final c = _container(
      _FakeManager(
        shouldFail: true,
        failError: StateError('Kokoro archive SHA-256 mismatch: ...'),
      ),
    );
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    expect(
      c.read(kokoroModelProvider).of(_fp32).downloadError,
      DownloadFailureKind.verification,
    );
  });

  test('网络错误（非取消 DioException）→ downloadError=network', () async {
    final c = _container(
      _FakeManager(
        shouldFail: true,
        failError: DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        ),
      ),
    );
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    expect(
      c.read(kokoroModelProvider).of(_fp32).downloadError,
      DownloadFailureKind.network,
    );
  });

  test('取消 → notDownloaded + 无错误', () async {
    final c = _container(_FakeManager(shouldCancel: true));
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);

    final s = c.read(kokoroModelProvider).of(_fp32);
    expect(s.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(s.downloadError, isNull);
  });

  test('用户取消 → 立即重置 UI，后台清理文件与标记', () async {
    final manager = _BlockingCancelManager();
    final c = _container(manager);
    addTearDown(c.dispose);
    final downloading = c
        .read(kokoroModelProvider.notifier)
        .ensureDownloaded(_fp32);
    await Future<void>.delayed(Duration.zero);

    final cancelling = c
        .read(kokoroModelProvider.notifier)
        .cancelDownload(_fp32);
    await Future<void>.delayed(Duration.zero);

    final immediateState = c.read(kokoroModelProvider).of(_fp32);
    expect(immediateState.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(immediateState.localSizeBytes, 0);
    expect(immediateState.downloadError, isNull);
    expect(manager.deleteCount, 0);

    manager.release.complete();
    await cancelling;
    await downloading;

    expect(manager.deleteCount, 1);
  });

  test('retryDownload 清错误后成功', () async {
    final manager = _FakeManager(shouldFail: true);
    final c = _container(manager);
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);
    expect(
      c.read(kokoroModelProvider).of(_fp32).downloadStatus,
      AsrModelDownloadStatus.failed,
    );

    manager.shouldFail = false;
    await c.read(kokoroModelProvider.notifier).retryDownload(_fp32);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);
    expect(c.read(kokoroModelProvider).of(_fp32).downloadError, isNull);
  });

  test('deleteModel → notDownloaded + 体积 0', () async {
    final c = _container(_FakeManager());
    addTearDown(c.dispose);

    await c.read(kokoroModelProvider.notifier).ensureDownloaded(_fp32);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);

    await c.read(kokoroModelProvider.notifier).deleteModel(_fp32);
    final s = c.read(kokoroModelProvider).of(_fp32);
    expect(s.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(s.localSizeBytes, 0);
  });

  test('两个变体独立：删 int8 不影响 fp32', () async {
    final c = _container(_FakeManager());
    addTearDown(c.dispose);

    final n = c.read(kokoroModelProvider.notifier);
    await n.ensureDownloaded(_fp32);
    await n.ensureDownloaded(KokoroModelVariant.int8);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);
    expect(
      c.read(kokoroModelProvider).of(KokoroModelVariant.int8).isReady,
      isTrue,
    );

    await n.deleteModel(KokoroModelVariant.int8);
    expect(c.read(kokoroModelProvider).of(_fp32).isReady, isTrue);
    expect(
      c.read(kokoroModelProvider).of(KokoroModelVariant.int8).isReady,
      isFalse,
    );
  });
}

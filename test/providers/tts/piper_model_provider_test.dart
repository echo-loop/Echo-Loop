import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/providers/tts/piper_model_provider.dart';
import 'package:echo_loop/providers/tts/tts_settings_provider.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';
import 'package:echo_loop/services/resource_install_manifest.dart';
import 'package:echo_loop/services/tts/piper_model_manager.dart';
import 'package:echo_loop/services/tts/piper_model_catalog.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';
import '../../helpers/mock_providers.dart';

const _us = piperDefaultVoiceUs;
const _uk = piperDefaultVoiceUk;

/// 可编排行为的假管理器（按 voiceId 被 family override 复用）。
class _FakeManager extends PiperModelManager {
  _FakeManager({
    this.shouldFail = false,
    this.shouldCancel = false,
    this.sizeAfterDownload = 1024,
    bool downloaded = false,
    this.installMarker = false,
  }) : _downloaded = downloaded,
       super(
         voice: piperVoices.first,
         modelsRootResolver: () async => '/tmp/none',
       );

  bool shouldFail;
  bool shouldCancel;
  int sizeAfterDownload;
  bool _downloaded;
  bool installMarker;
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
      // 迁移到 ReliableHttpDownloader 后，PiperModelManager 取消时抛的是
      // 结构化 ReliableDownloadException（不再是裸 DioException），fake 需要
      // 如实模拟，否则测不出 provider 对新异常类型的取消判定分支。
      throw const ReliableDownloadException(
        'cancelled',
        kind: ReliableDownloadFailure.cancelled,
      );
    }
    if (shouldFail) throw StateError('boom');
    _downloaded = true;
    return '/tmp/none/model';
  }

  @override
  Future<int> modelLocalSize() async =>
      _downloaded ? sizeAfterDownload : (shouldFail ? 10 : 0);

  @override
  Future<bool> isModelDownloaded() async => _downloaded;

  @override
  Future<bool> hasInstallMarker() async => installMarker;

  @override
  Future<ResourceInstallManifest?> readInstallManifest() async {
    if (!installMarker && !_downloaded) return null;
    return ResourceInstallManifest(
      resourceId: voice.id,
      installAt: DateTime(2026, 8, 26),
      resourceSize: sizeAfterDownload,
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

/// 按 voiceId 返回各自 fake 的容器（默认所有音色共用一个 fake）。
ProviderContainer _container(
  PiperModelManager Function(String voiceId) managerOf, {
  PiperModelsState? initial,
  TtsSettings? settings,
}) {
  return ProviderContainer(
    overrides: dedupeOverrides([
      piperModelManagerProvider.overrideWith((ref, id) => managerOf(id)),
      initialPiperModelStateProvider.overrideWithValue(
        initial ?? PiperModelsState.initial(),
      ),
      if (settings != null)
        initialTtsSettingsProvider.overrideWithValue(settings),
    ]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ensureDownloaded 成功 → ready + 进度 1.0 + 体积', () async {
    final c = _container((_) => _FakeManager());
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);

    final s = c.read(piperModelProvider).of(_us);
    expect(s.isReady, isTrue);
    expect(s.downloadProgress, 1.0);
    expect(s.localSizeBytes, 1024);
  });

  test('已有 install.json → 同步 ready 且不重复下载', () async {
    final manager = _FakeManager(downloaded: true, installMarker: true);
    final c = _container((_) => manager);
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);

    expect(manager.downloadCount, 0);
    expect(c.read(piperModelProvider).of(_us).isReady, isTrue);
    expect(c.read(piperModelProvider).of(_us).localSizeBytes, 1024);
    expect(
      c.read(piperModelProvider).of(_us).installManifest?.resourceSize,
      1024,
    );
  });

  test('refreshInstalledStates 检查全部音色且不下载', () async {
    final managers = <String, _FakeManager>{};
    final c = _container((voiceId) {
      return managers.putIfAbsent(
        voiceId,
        () => _FakeManager(downloaded: true, installMarker: true),
      );
    });
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).refreshInstalledStates();

    expect(
      piperVoices.every(
        (voice) => c.read(piperModelProvider).of(voice.id).isReady,
      ),
      isTrue,
    );
    expect(
      managers.values.every((manager) => manager.downloadCount == 0),
      isTrue,
    );
  });

  test('piperReadyProvider 跟随「当前口音选中音色」就绪态', () async {
    final c = _container(
      (_) => _FakeManager(),
      settings: const TtsSettings(
        engine: TtsEngineKind.piper,
        accent: TtsAccent.us,
      ),
    );
    addTearDown(c.dispose);

    expect(c.read(piperReadyProvider), isFalse);
    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);
    expect(c.read(piperReadyProvider), isTrue);
  });

  test('并发 ensureDownloaded（同帧重复触发）只下载一次', () async {
    final manager = _FakeManager();
    final c = _container((_) => manager);
    addTearDown(c.dispose);

    final n = c.read(piperModelProvider.notifier);
    await Future.wait([n.ensureDownloaded(_us), n.ensureDownloaded(_us)]);

    expect(manager.downloadCount, 1);
    expect(c.read(piperModelProvider).of(_us).isReady, isTrue);
  });

  test('下载失败 → failed', () async {
    final c = _container((_) => _FakeManager(shouldFail: true));
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);
    expect(
      c.read(piperModelProvider).of(_us).downloadStatus,
      AsrModelDownloadStatus.failed,
    );
  });

  test('下载失败后 ensureDownloaded 不隐式重试', () async {
    final manager = _FakeManager(shouldFail: true);
    final c = _container((_) => manager);
    addTearDown(c.dispose);
    final notifier = c.read(piperModelProvider.notifier);

    await notifier.ensureDownloaded(_us);
    await notifier.ensureDownloaded(_us);

    expect(manager.downloadCount, 1);
    expect(
      c.read(piperModelProvider).of(_us).downloadStatus,
      AsrModelDownloadStatus.failed,
    );
  });

  test('取消 → notDownloaded + 无错误', () async {
    final c = _container((_) => _FakeManager(shouldCancel: true));
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);
    final s = c.read(piperModelProvider).of(_us);
    expect(s.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(s.downloadError, isNull);
  });

  test('用户取消 → 立即重置 UI，后台清理文件与标记', () async {
    final manager = _BlockingCancelManager();
    final c = _container((_) => manager);
    addTearDown(c.dispose);
    final downloading = c
        .read(piperModelProvider.notifier)
        .ensureDownloaded(_us);
    await Future<void>.delayed(Duration.zero);

    final cancelling = c.read(piperModelProvider.notifier).cancelDownload(_us);
    await Future<void>.delayed(Duration.zero);

    final immediateState = c.read(piperModelProvider).of(_us);
    expect(immediateState.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(immediateState.localSizeBytes, 0);
    expect(immediateState.downloadError, isNull);
    expect(manager.deleteCount, 0);

    manager.release.complete();
    await cancelling;
    await downloading;

    expect(manager.deleteCount, 1);
  });

  test('音色互相独立：下载美音不影响英音', () async {
    // 每个 voiceId 独立 fake，避免共享 _downloaded 串台。
    final managers = <String, _FakeManager>{};
    final c = _container((id) => managers.putIfAbsent(id, _FakeManager.new));
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);
    expect(c.read(piperModelProvider).of(_us).isReady, isTrue);
    expect(c.read(piperModelProvider).of(_uk).isReady, isFalse);
  });

  test('deleteModel → notDownloaded + 体积 0', () async {
    final c = _container((_) => _FakeManager());
    addTearDown(c.dispose);

    await c.read(piperModelProvider.notifier).ensureDownloaded(_us);
    await c.read(piperModelProvider.notifier).deleteModel(_us);
    final s = c.read(piperModelProvider).of(_us);
    expect(s.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(s.localSizeBytes, 0);
  });
}

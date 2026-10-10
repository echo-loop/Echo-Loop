import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/asr_engine_provider.dart';
import 'package:echo_loop/services/asr/asr_model_manager.dart';
import 'package:echo_loop/services/asr/offline_asr_engine.dart';
import 'package:echo_loop/services/download/download_failure.dart';
import 'package:echo_loop/services/reliable_http_downloader.dart';

class _FakeAsrModelManager extends AsrModelManager {
  _FakeAsrModelManager({
    required this.downloaded,
    required this.localSizeBytes,
  });

  final bool downloaded;
  final int localSizeBytes;
  int deleteModelCallCount = 0;
  int discardPartialDownloadCallCount = 0;

  @override
  Future<bool> isModelDownloaded(String modelId) async => downloaded;

  @override
  Future<int> modelLocalSize(String modelId) async => localSizeBytes;

  @override
  Future<void> deleteModel(String modelId) async {
    deleteModelCallCount += 1;
  }

  @override
  Future<void> cleanupUnknownModels() async {}

  @override
  Future<void> discardPartialDownload(String modelId) async {
    discardPartialDownloadCallCount += 1;
  }
}

class _TestOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  _TestOfflineAsrSettingsNotifier(this._initialState);

  final OfflineAsrSettingsState _initialState;

  @override
  OfflineAsrSettingsState build() => _initialState;
}

class _DelayedAsrModelManager extends _FakeAsrModelManager {
  _DelayedAsrModelManager() : super(downloaded: false, localSizeBytes: 99);

  final downloadCompleter = Completer<String>();
  CancelToken? downloadCancelToken;

  @override
  Future<String> downloadModel(
    String modelId, {
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) {
    downloadCancelToken = cancelToken;
    return downloadCompleter.future;
  }
}

class _BurstProgressAsrModelManager extends _FakeAsrModelManager {
  _BurstProgressAsrModelManager() : super(downloaded: false, localSizeBytes: 0);

  @override
  Future<String> downloadModel(
    String modelId, {
    void Function(AsrModelDownloadProgress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    const callbackCount = 10000;
    for (var i = 1; i <= callbackCount; i++) {
      onProgress?.call(
        AsrModelDownloadProgress(
          status: AsrModelDownloadStatus.downloading,
          progress: i / callbackCount,
        ),
      );
    }
    throw StateError('simulated download failure after progress burst');
  }
}

void main() {
  const recommendedModel = AsrModelInfo(
    id: 'whisper-base-en-int8',
    displayName: 'Whisper Base.en',
    type: AsrModelType.whisper,
  );

  test('推荐模型默认保持 Balanced，不依赖 availableModels 顺序', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final model = container.read(recommendedAsrModelProvider);

    expect(model.id, 'whisper-base-en-int8');
    expect(model.displayName, contains('Balanced'));
  });

  test('旧完成标记不再恢复 downloaded，避免与安装清单漂移', () async {
    SharedPreferences.setMockInitialValues({
      'offline_asr_downloaded_whisper-base-en-int8': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = offlineAsrSettingsStateFromPrefs(
      prefs: prefs,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.enabled, isTrue);
    expect(state.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(state.localSizeBytes, 0);
  });

  test('无完成标记保持 notDownloaded', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = offlineAsrSettingsStateFromPrefs(
      prefs: prefs,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.downloadStatus, AsrModelDownloadStatus.notDownloaded);
  });

  test('高频下载进度只发布有限 UI 状态更新', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final manager = _BurstProgressAsrModelManager();
    final initialState = OfflineAsrSettingsState(
      backend: AsrBackend.offline,
      recommendedModel: recommendedModel,
    );
    final container = ProviderContainer(
      overrides: [
        asrModelManagerProvider.overrideWithValue(manager),
        offlineAsrSettingsProvider.overrideWith(
          () => _TestOfflineAsrSettingsNotifier(initialState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final publishedProgress = <double>[];
    final subscription = container.listen(offlineAsrSettingsProvider, (
      previous,
      next,
    ) {
      if (next.downloadStatus == AsrModelDownloadStatus.downloading &&
          next.downloadProgress > 0) {
        publishedProgress.add(next.downloadProgress);
      }
    });
    addTearDown(subscription.close);

    await container.read(offlineAsrSettingsProvider.notifier).retryDownload();

    expect(publishedProgress, hasLength(lessThan(100)));
    expect(publishedProgress.last, 1);
    expect(
      container.read(offlineAsrSettingsProvider).downloadStatus,
      AsrModelDownloadStatus.failed,
    );
  });

  test('无效持久化模型选择回退到推荐模型', () async {
    SharedPreferences.setMockInitialValues({
      'offline_asr_selected_model_id': 'removed-model',
    });
    final prefs = await SharedPreferences.getInstance();
    final state = offlineAsrSettingsStateFromPrefs(
      prefs: prefs,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.offline,
    );

    expect(state.selectedModel.id, recommendedModel.id);
  });

  test('持久化后端和模型选择同步恢复', () async {
    SharedPreferences.setMockInitialValues({
      'offline_asr_backend': AsrBackend.offline.name,
      'offline_asr_selected_model_id': 'whisper-base-en-int8',
      'offline_asr_downloaded_whisper-base-en-int8': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = offlineAsrSettingsStateFromPrefs(
      prefs: prefs,
      recommendedModel: recommendedModel,
      defaultBackend: AsrBackend.platform,
    );

    expect(state.backend, AsrBackend.offline);
    expect(state.selectedModel.id, recommendedModel.id);
    expect(state.downloadStatus, AsrModelDownloadStatus.notDownloaded);
  });

  test('主动取消下载会清理残留并回到未下载态，不显示失败', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final manager = _FakeAsrModelManager(downloaded: false, localSizeBytes: 99);
    final modelId = recommendedModel.id;
    final initialState = OfflineAsrSettingsState(
      backend: AsrBackend.offline,
      recommendedModel: recommendedModel,
      modelStates: {
        modelId: const AsrModelState(
          downloadStatus: AsrModelDownloadStatus.downloading,
          downloadProgress: 0.4,
          localSizeBytes: 99,
          downloadError: DownloadFailureKind.network,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        asrModelManagerProvider.overrideWithValue(manager),
        offlineAsrSettingsProvider.overrideWith(
          () => _TestOfflineAsrSettingsNotifier(initialState),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(offlineAsrSettingsProvider.notifier).cancelDownload();

    final state = container.read(offlineAsrSettingsProvider);
    expect(manager.deleteModelCallCount, 1);
    expect(manager.discardPartialDownloadCallCount, 1);
    expect(state.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(state.downloadProgress, 0);
    expect(state.localSizeBytes, 0);
    expect(state.downloadError, isNull);
    expect(prefs.getBool('offline_asr_downloaded_$modelId'), isNull);
  });

  test('取消后立即重置 UI，底层写入报存储异常仍不显示重试', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final manager = _DelayedAsrModelManager();
    final initialState = OfflineAsrSettingsState(
      backend: AsrBackend.offline,
      recommendedModel: recommendedModel,
    );
    final container = ProviderContainer(
      overrides: [
        asrModelManagerProvider.overrideWithValue(manager),
        offlineAsrSettingsProvider.overrideWith(
          () => _TestOfflineAsrSettingsNotifier(initialState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final download = container
        .read(offlineAsrSettingsProvider.notifier)
        .retryDownload();
    await Future<void>.delayed(Duration.zero);
    expect(manager.downloadCancelToken, isNotNull);

    final cancel = container
        .read(offlineAsrSettingsProvider.notifier)
        .cancelDownload();
    await Future<void>.delayed(Duration.zero);

    final immediateState = container.read(offlineAsrSettingsProvider);
    expect(immediateState.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(immediateState.downloadProgress, 0);
    expect(immediateState.localSizeBytes, 0);
    expect(immediateState.downloadError, isNull);

    manager.downloadCompleter.completeError(
      const ReliableDownloadException(
        'directory removed during cancellation',
        kind: ReliableDownloadFailure.storage,
      ),
    );
    await cancel;
    await download;

    final state = container.read(offlineAsrSettingsProvider);
    expect(manager.discardPartialDownloadCallCount, 1);
    expect(state.downloadStatus, AsrModelDownloadStatus.notDownloaded);
    expect(state.downloadError, isNull);
    expect(state.localSizeBytes, 0);
  });
}

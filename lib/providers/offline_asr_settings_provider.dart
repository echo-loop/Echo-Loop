/// 离线 ASR 功能设置 Provider。
///
/// 管理本地语音识别的开关状态、模型下载、引擎初始化。
/// 独立于 [AppSettings]，遵循"Provider 按功能域拆分"原则。
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/asr/asr_model_manager.dart';
import '../services/asr/offline_asr_engine.dart';
import 'asr_engine_provider.dart';

const _enabledKey = 'offline_asr_enabled';
const _backendKey = 'offline_asr_backend';
String _downloadCompletedKey(String modelId) =>
    'offline_asr_downloaded_$modelId';

AsrModelDownloadStatus _deriveStoredDownloadStatus({
  required bool fullyDownloaded,
  required int localSizeBytes,
}) {
  if (fullyDownloaded) {
    return AsrModelDownloadStatus.downloaded;
  }
  if (localSizeBytes > 0) {
    return AsrModelDownloadStatus.failed;
  }
  return AsrModelDownloadStatus.notDownloaded;
}
// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// 语音识别后端类型。
enum AsrBackend {
  /// 平台原生 ASR（iOS/macOS 的 SFSpeechRecognizer）。
  platform,

  /// 离线自建模型 ASR（sherpa-onnx）。
  offline,
}

/// 离线 ASR 功能的完整 UI 状态。
class OfflineAsrSettingsState {
  /// 功能开关：true=开启, false=关闭。默认开启。
  final bool enabled;

  /// 当前选择的 ASR 后端。
  ///
  /// iOS/macOS 默认 [AsrBackend.platform]，可切换到 [AsrBackend.offline]。
  /// Android 固定 [AsrBackend.offline]。
  final AsrBackend backend;

  /// 模型下载状态（仅 [AsrBackend.offline] 时有意义）。
  final AsrModelDownloadStatus downloadStatus;

  /// 下载进度 0.0~1.0。
  final double downloadProgress;

  /// 模型本地占用空间（字节）。
  final int localSizeBytes;

  /// 错误信息。
  final String? errorMessage;

  /// 引擎是否已就绪（模型已加载到内存）。
  final bool engineReady;

  /// 推荐的模型信息。
  final AsrModelInfo recommendedModel;

  const OfflineAsrSettingsState({
    this.enabled = true,
    this.backend = AsrBackend.platform,
    this.downloadStatus = AsrModelDownloadStatus.notDownloaded,
    this.downloadProgress = 0,
    this.localSizeBytes = 0,
    this.errorMessage,
    this.engineReady = false,
    required this.recommendedModel,
  });

  /// 是否可以删除模型（关闭 + 已下载）。
  bool get canDelete => !enabled && localSizeBytes > 0;

  /// 是否正在下载。
  bool get isDownloading =>
      downloadStatus == AsrModelDownloadStatus.downloading;

  /// 离线 ASR 是否完全就绪（模型已下载 + 引擎已加载）。
  bool get isOfflineReady =>
      enabled &&
      backend == AsrBackend.offline &&
      downloadStatus == AsrModelDownloadStatus.downloaded &&
      engineReady;

  OfflineAsrSettingsState copyWith({
    bool? enabled,
    AsrBackend? backend,
    AsrModelDownloadStatus? downloadStatus,
    double? downloadProgress,
    int? localSizeBytes,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? engineReady,
  }) {
    return OfflineAsrSettingsState(
      enabled: enabled ?? this.enabled,
      backend: backend ?? this.backend,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localSizeBytes: localSizeBytes ?? this.localSizeBytes,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      engineReady: engineReady ?? this.engineReady,
      recommendedModel: recommendedModel,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// 离线 ASR 功能设置 Provider（keepAlive，全局单例）。
final offlineAsrSettingsProvider =
    NotifierProvider<OfflineAsrSettingsNotifier, OfflineAsrSettingsState>(
      OfflineAsrSettingsNotifier.new,
    );

/// 应用启动时预加载的离线 ASR 初始状态。
///
/// 通过 main() 注入，避免首次点击语音练习时先读到默认值。
/// 启动时只读取“下载完成”持久化标记，不再做文件系统重校验。
final initialOfflineAsrSettingsStateProvider =
    Provider<OfflineAsrSettingsState>((ref) {
      final recommended = ref.read(recommendedAsrModelProvider);
      return OfflineAsrSettingsState(recommendedModel: recommended);
    });

/// 设置页是否显示 AI 语音识别入口。
///
/// 全平台显示（Web 除外）。
final showOfflineAsrSectionProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  return true;
});

/// 推荐的 ASR 模型（main() 中一次性计算并 override 注入）。
final recommendedAsrModelProvider = Provider<AsrModelInfo>(
  (ref) => throw UnimplementedError('Must be overridden in main()'),
);

/// 离线 ASR 设置 Notifier。
class OfflineAsrSettingsNotifier extends Notifier<OfflineAsrSettingsState> {
  CancelToken? _downloadCancelToken;

  @override
  OfflineAsrSettingsState build() {
    ref.onDispose(() {
      _downloadCancelToken?.cancel();
    });

    return ref.read(initialOfflineAsrSettingsStateProvider);
  }

  /// 开启功能。
  ///
  /// platform 后端：直接标记 enabled。
  /// offline 后端：模型已下载 → 直接初始化引擎；未下载 → 自动触发下载。
  Future<void> enable() async {
    // platform 后端无需下载，直接开启。
    if (state.backend == AsrBackend.platform) {
      state = state.copyWith(enabled: true, clearErrorMessage: true);
      await _persistEnabled(true);
      return;
    }

    // 已在下载中，不重复触发。
    if (state.isDownloading) return;

    final modelId = state.recommendedModel.id;
    final modelManager = ref.read(asrModelManagerProvider);

    if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
      final localSize = await modelManager.modelLocalSize(modelId);
      state = state.copyWith(
        enabled: true,
        downloadStatus: AsrModelDownloadStatus.downloaded,
        localSizeBytes: localSize,
        clearErrorMessage: true,
      );
      await _persistEnabled(true);
      await _persistDownloadCompleted(modelId, true);
      // 引擎不在此处加载，进入录音页面时按需加载。
    } else {
      // 先标记 enabled，下载完成后引擎自动初始化。
      state = state.copyWith(enabled: true, clearErrorMessage: true);
      await _persistEnabled(true);
      await _downloadAndInitialize(modelId);
    }
  }

  /// 关闭功能（不删除模型文件）。
  Future<void> disable() async {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    await unloadEngine();
    final modelManager = ref.read(asrModelManagerProvider);
    final localSize = await modelManager.modelLocalSize(
      state.recommendedModel.id,
    );
    final fullyDownloaded =
        state.downloadStatus == AsrModelDownloadStatus.downloaded;
    state = state.copyWith(
      enabled: false,
      engineReady: false,
      downloadStatus: _deriveStoredDownloadStatus(
        fullyDownloaded: fullyDownloaded,
        localSizeBytes: localSize,
      ),
      downloadProgress: 0,
      localSizeBytes: localSize,
      clearErrorMessage: true,
    );
    await _persistEnabled(false);
    await _persistDownloadCompleted(state.recommendedModel.id, fullyDownloaded);
  }

  /// 按需加载引擎（进入录音页面时调用，不阻塞 UI）。
  Future<void> loadEngine() async {
    if (state.engineReady) return;
    if (!state.enabled) return;
    if (state.downloadStatus != AsrModelDownloadStatus.downloaded) return;
    await _initializeEngine(state.recommendedModel.id);
  }

  /// 卸载引擎释放内存（退出录音页面时调用）。
  Future<void> unloadEngine() async {
    if (!state.engineReady) return;
    final engine = ref.read(offlineAsrEngineProvider);
    await engine.dispose();
    state = state.copyWith(engineReady: false);
  }

  /// 关闭功能并删除模型。
  Future<void> disableAndDelete() async {
    await disable();
    await deleteModel();
  }

  /// 删除本地模型（仅关闭时可调用）。
  Future<void> deleteModel() async {
    if (state.enabled) return;
    final modelManager = ref.read(asrModelManagerProvider);
    await modelManager.deleteModel(state.recommendedModel.id);
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.notDownloaded,
      localSizeBytes: 0,
    );
    await _persistDownloadCompleted(state.recommendedModel.id, false);
  }

  /// 重试下载。
  Future<void> retryDownload() async {
    state = state.copyWith(clearErrorMessage: true);
    await _downloadAndInitialize(state.recommendedModel.id);
  }

  /// 取消正在进行的下载。
  Future<void> cancelDownload() async {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    final modelManager = ref.read(asrModelManagerProvider);
    final localSize = await modelManager.modelLocalSize(
      state.recommendedModel.id,
    );
    state = state.copyWith(
      downloadStatus: _deriveStoredDownloadStatus(
        fullyDownloaded: false,
        localSizeBytes: localSize,
      ),
      downloadProgress: 0,
      localSizeBytes: localSize,
    );
    await _persistDownloadCompleted(state.recommendedModel.id, false);
  }

  // ---------------------------------------------------------------------------
  // 内部方法
  // ---------------------------------------------------------------------------

  Future<void> _downloadAndInitialize(String modelId) async {
    await _persistDownloadCompleted(modelId, false);
    state = state.copyWith(
      downloadStatus: AsrModelDownloadStatus.downloading,
      downloadProgress: 0,
    );

    _downloadCancelToken = CancelToken();
    final modelManager = ref.read(asrModelManagerProvider);

    try {
      await modelManager.downloadModel(
        modelId,
        cancelToken: _downloadCancelToken,
        onProgress: (progress) {
          if (_downloadCancelToken?.isCancelled ?? true) return;
          state = state.copyWith(downloadProgress: progress.progress);
        },
      );

      _downloadCancelToken = null;
      final localSize = await modelManager.modelLocalSize(modelId);

      state = state.copyWith(
        downloadStatus: AsrModelDownloadStatus.downloaded,
        downloadProgress: 1.0,
        localSizeBytes: localSize,
      );
      await _persistDownloadCompleted(modelId, true);

      await _initializeEngine(modelId);
    } on DioException catch (e) {
      _downloadCancelToken = null;
      if (e.type == DioExceptionType.cancel) {
        state = state.copyWith(
          downloadStatus: AsrModelDownloadStatus.notDownloaded,
          downloadProgress: 0,
        );
      } else {
        state = state.copyWith(
          downloadStatus: AsrModelDownloadStatus.failed,
          errorMessage: e.message ?? 'Download failed',
        );
      }
      await _persistDownloadCompleted(modelId, false);
    } catch (e) {
      _downloadCancelToken = null;
      state = state.copyWith(
        downloadStatus: AsrModelDownloadStatus.failed,
        errorMessage: '$e',
      );
      await _persistDownloadCompleted(modelId, false);
    }
  }

  Future<void> _initializeEngine(String modelId) async {
    final engine = ref.read(offlineAsrEngineProvider);
    final modelManager = ref.read(asrModelManagerProvider);
    final modelDir = await modelManager.modelDir(modelId);

    try {
      await engine.initialize(
        AsrModelConfig(
          model: state.recommendedModel,
          modelDir: modelDir,
          numThreads: AsrModelConfig.recommendedThreads(),
        ),
      );
      state = state.copyWith(engineReady: true);
    } catch (e) {
      state = state.copyWith(
        engineReady: false,
        downloadStatus: AsrModelDownloadStatus.failed,
        errorMessage: 'Engine initialization failed: $e',
      );
      await _persistDownloadCompleted(modelId, false);
    }
  }

  Future<void> _persistEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> _persistBackend(AsrBackend value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendKey, value.name);
  }

  /// 切换 ASR 后端。
  ///
  /// 切到 offline 且模型未下载时自动触发下载。
  /// 切到 platform 时不影响已下载的模型文件。
  Future<void> setBackend(AsrBackend backend) async {
    if (state.backend == backend) return;

    // 切离 offline 时取消正在进行的下载
    if (state.backend == AsrBackend.offline && state.isDownloading) {
      _downloadCancelToken?.cancel();
      _downloadCancelToken = null;
      state = state.copyWith(
        backend: backend,
        downloadStatus: AsrModelDownloadStatus.notDownloaded,
        downloadProgress: 0,
        clearErrorMessage: true,
      );
    } else {
      state = state.copyWith(backend: backend);
    }
    await _persistBackend(backend);

    final modelId = state.recommendedModel.id;

    // 切到 offline + 已启用 → 确保模型就绪
    if (backend == AsrBackend.offline && state.enabled) {
      if (state.downloadStatus == AsrModelDownloadStatus.downloaded) {
        await _initializeEngine(modelId);
      } else if (state.downloadStatus != AsrModelDownloadStatus.downloading) {
        await _downloadAndInitialize(modelId);
      }
    }
  }

  /// 持久化”模型已完整下载”标记。
  ///
  /// 该标记只作为启动恢复和状态核对的快速索引，最终仍以文件系统校验为准。
  Future<void> _persistDownloadCompleted(String modelId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_downloadCompletedKey(modelId), value);
  }
}

/// 启动期从持久化和模型文件系统中构建离线 ASR 初始状态。
Future<OfflineAsrSettingsState> loadInitialOfflineAsrSettingsState({
  required SharedPreferences prefs,
  required AsrModelManager modelManager,
  required AsrModelInfo recommendedModel,
  required AsrBackend defaultBackend,
}) async {
  final enabled = prefs.getBool(_enabledKey) ?? true;
  final backendName = prefs.getString(_backendKey);
  final backend = backendName == AsrBackend.offline.name
      ? AsrBackend.offline
      : backendName == AsrBackend.platform.name
          ? AsrBackend.platform
          : defaultBackend;
  final persistedDownloaded =
      prefs.getBool(_downloadCompletedKey(recommendedModel.id)) ?? false;
  final localSize = await modelManager.modelLocalSize(recommendedModel.id);

  return OfflineAsrSettingsState(
    enabled: enabled,
    backend: backend,
    downloadStatus: _deriveStoredDownloadStatus(
      fullyDownloaded: persistedDownloaded,
      localSizeBytes: localSize,
    ),
    localSizeBytes: localSize,
    recommendedModel: recommendedModel,
  );
}

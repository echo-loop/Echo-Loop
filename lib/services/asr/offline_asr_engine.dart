/// 离线 ASR 引擎统一接口和数据类。
///
/// 定义 [OfflineAsrEngine] 抽象接口，sherpa-onnx（Moonshine/Whisper ONNX）
/// 和 whisper.cpp（Whisper GGML）都实现此接口，上层不感知具体引擎差异。
library;

import 'dart:io';

/// ASR 模型类型。
enum AsrModelType {
  /// Moonshine 系列（Useful Sensors），ONNX 格式，sherpa-onnx 加载。
  moonshine,

  /// Whisper 系列（OpenAI），ONNX 格式，sherpa-onnx 加载。
  whisper,
}

/// ASR 模型信息。
class AsrModelInfo {
  /// 模型唯一标识，如 "moonshine-tiny-en-int8"。
  final String id;

  /// 显示名称，如 "Moonshine Tiny"。
  final String displayName;

  /// 模型类型。
  final AsrModelType type;

  const AsrModelInfo({
    required this.id,
    required this.displayName,
    required this.type,
  });
}

/// ASR 模型配置（用于初始化引擎）。
class AsrModelConfig {
  /// 模型信息。
  final AsrModelInfo model;

  /// 模型文件本地目录路径。
  final String modelDir;

  /// 推理线程数。
  final int numThreads;

  /// 推理加速 provider（仅 sherpa-onnx 使用）。
  ///
  /// null 时自动选择平台默认值，当前所有平台均为 cpu
  /// （Android NNAPI 在部分机型触发 native abort，已统一改用 cpu，详见
  /// `sherpa_onnx_engine.dart` 的 `_platformProvider`）。
  final String? provider;

  /// Silero VAD 模型文件路径（可选）。
  ///
  /// 提供时，转录前先用 VAD 裁掉静音段以加速 whisper 推理。
  final String? vadModelPath;

  const AsrModelConfig({
    required this.model,
    required this.modelDir,
    this.numThreads = 4,
    this.provider,
    this.vadModelPath,
  });

  /// 根据设备 CPU 核心数推荐线程数。
  ///
  /// cores ≥ 8 → 6 线程，cores ≥ 6 → 4 线程，其他 → 2 线程。
  /// 不占满 CPU，留余量给 UI 和其他任务。
  static int recommendedThreads() {
    final cores = Platform.numberOfProcessors;
    if (cores >= 8) return 6;
    if (cores >= 6) return 4;
    return 2;
  }
}

/// ASR 转录结果。
class AsrResult {
  /// 转录文本。
  final String text;

  /// 推理耗时。
  final Duration inferenceTime;

  const AsrResult({required this.text, required this.inferenceTime});
}

/// 带时间戳的转录片段（用于字幕生成）。
///
/// 时间戳来自 VAD 切出的语音段边界（真实、按静音切分），
/// 每段独立解码得到 [text]。sherpa-onnx Whisper 不产词级时间戳，
/// 故仅提供段级（≈句级）时间，词级时间由上层按字符长度合成。
class AsrSegment {
  /// 段文本。
  final String text;

  /// 段起始时间（相对音频开头）。
  final Duration start;

  /// 段结束时间（相对音频开头）。
  final Duration end;

  const AsrSegment({
    required this.text,
    required this.start,
    required this.end,
  });
}

/// 离线 ASR 引擎抽象接口。
///
/// 统一 Moonshine、Whisper 等模型的转录能力，
/// 由 [SherpaOnnxEngine] 实现。
abstract class OfflineAsrEngine {
  /// 引擎显示名称。
  String get name;

  /// 是否已初始化（模型已加载到内存）。
  bool get isReady;

  /// 当前加载的模型信息，未初始化时为 null。
  AsrModelInfo? get currentModel;

  /// 加载指定模型，初始化推理引擎。
  ///
  /// 如果已加载其他模型，会先释放再重新加载。
  Future<void> initialize(AsrModelConfig config);

  /// 转录 WAV 文件（16kHz/mono/PCM16），返回结果。
  ///
  /// 在后台执行推理，不阻塞 UI 线程。
  /// 引擎未初始化时抛出 [StateError]。
  Future<AsrResult> transcribe(String wavPath);

  /// 转录 WAV 文件（16kHz/mono/PCM16），产出带时间戳的分段列表（用于字幕生成）。
  ///
  /// 与 [transcribe] 的区别：按 VAD 语音段逐段解码、保留每段真实起止时间，
  /// **不合并**为大块，得到句级切分。[onProgress] 在每段解码完成后回调
  /// 进度（0.0~1.0）。全静音/空音频返回空列表。
  /// 在后台执行推理，不阻塞 UI 线程；引擎未初始化时抛出 [StateError]。
  Future<List<AsrSegment>> transcribeSegments(
    String wavPath, {
    void Function(double progress)? onProgress,
  });

  /// 释放模型和引擎资源。
  Future<void> dispose();
}

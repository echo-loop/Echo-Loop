/// 统一 TTS 引擎抽象
///
/// 定义可插拔的文本转语音引擎契约。统一管线为
/// `文本+参数 → cacheKey → 查缓存 → 命中直接播 / 未命中合成产文件并入库 → 播放文件`，
/// 引擎只负责「把文本变成音频」这一步：
/// - [synthesize] 合成到本地文件（可缓存、可复用，长文也走这条）；
/// - [speakLive] 实时朗读兜底（不产文件、不缓存），用于 [synthesize] 失败时降级。
///
/// 本期实现 `PlatformTtsEngine`（flutter_tts）。未来 Kokoro 只需新增一个
/// [TtsEngine] 实现并在工厂里加一个分支，上层（协调器/缓存/播放器）零改动。
library;

/// TTS 引擎种类。
enum TtsEngineKind {
  /// 平台 TTS（flutter_tts，封装系统 TTS）。本期唯一可用。
  platform,

  /// Kokoro TTS（Echo Loop AI Advanced，本地 Kokoro 82M）。质量最佳，CPU 推理偏慢。
  kokoro,

  /// Piper VITS（本地，均衡档）。质量优于系统 TTS、速度远快于 Kokoro；
  /// 每个音色为一个独立单说话人模型，按音色单独下载（见 `piper_model_catalog.dart`）。
  piper,
}

/// 供诊断日志显示的实际 TTS 后端名。
///
/// [TtsEngineKind.kokoro] 是 Echo Loop AI Advanced 的实际 Kokoro 实现；
/// 日志输出实现名以便排障。
extension TtsEngineKindDiagnostics on TtsEngineKind {
  String get diagnosticName => switch (this) {
    TtsEngineKind.platform => 'platform',
    TtsEngineKind.kokoro => 'kokoro',
    TtsEngineKind.piper => 'piper',
  };
}

/// 发音口音。
enum TtsAccent {
  /// 美音。
  us,

  /// 英音。
  uk,
}

/// TTS voice 语言族。Kokoro 多语言 v1.1 同时包含英文与中文发音人。
enum TtsLanguage { english, chinese }

/// Echo Loop（Kokoro）模型精度变体。
///
/// 同一 Kokoro 82M 模型的两种打包：fp32 未量化（推理快、效果好，Apple/ARM 上
/// 显著快于 int8）；int8 量化（体积小、内存占用低，面向低内存设备）。详见
/// CLAUDE.md §7.16 与 ADR-9。
enum KokoroModelVariant {
  /// 未量化全精度（默认推荐）。
  fp32,

  /// int8 量化（低内存设备）。
  int8,
}

/// 引擎无关的发音配置（不可变值对象）。
///
/// 含 [==]/[hashCode] 以便上层判断「配置是否变化」（仅口音变更走
/// `applyConfig` 热更新，不重建引擎）。
class TtsSpeechConfig {
  /// 语言标签（`en-US` / `en-GB`）。
  final String languageTag;

  /// 语速（归一化 0..1，平台层各自映射）。
  final double rate;

  /// 本地神经引擎语速倍率（1.0 = 正常；建议范围 0.5..2.0）。
  ///
  /// 平台 TTS 仍使用 [rate] 做归一化映射；Kokoro/Piper 使用本字段直接传给
  /// sherpa-onnx，避免把 0.45 这类平台参数误当成神经网络倍率。
  final double speed;

  /// 音调。
  final double pitch;

  /// 音量。
  final double volume;

  /// 可选：精确指定 voice 名（预留给未来音色，本期不用）。
  final String? voiceName;

  /// 可选：模型标签，仅参与缓存键分桶（如 Kokoro 的 fp32/int8 变体），
  /// 使不同模型的合成产物互不串音。为 null 时不影响缓存键（平台引擎不用）。
  final String? modelTag;

  const TtsSpeechConfig({
    required this.languageTag,
    this.rate = 0.45,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.voiceName,
    this.modelTag,
  });

  /// 用于缓存键的 voice 标识（精确 voice 优先，否则用语言标签）。
  String get voiceId => voiceName ?? languageTag;

  TtsSpeechConfig copyWith({
    String? languageTag,
    double? rate,
    double? speed,
    double? pitch,
    double? volume,
    String? voiceName,
    String? modelTag,
  }) {
    return TtsSpeechConfig(
      languageTag: languageTag ?? this.languageTag,
      rate: rate ?? this.rate,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      voiceName: voiceName ?? this.voiceName,
      modelTag: modelTag ?? this.modelTag,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsSpeechConfig &&
          runtimeType == other.runtimeType &&
          languageTag == other.languageTag &&
          rate == other.rate &&
          speed == other.speed &&
          pitch == other.pitch &&
          volume == other.volume &&
          voiceName == other.voiceName &&
          modelTag == other.modelTag;

  @override
  int get hashCode =>
      Object.hash(languageTag, rate, speed, pitch, volume, voiceName, modelTag);
}

/// 合成结果（产出的本地音频文件信息）。
class TtsSynthesisResult {
  /// 本地音频文件绝对路径。
  final String filePath;

  /// 音频格式（`wav` / `caf` / 未来 `m4a`）。
  final String format;

  /// 采样率（可选，部分引擎不提供）。
  final int? sampleRate;

  const TtsSynthesisResult({
    required this.filePath,
    required this.format,
    this.sampleRate,
  });
}

/// 可插拔 TTS 引擎。
///
/// 实现须保证：
/// - [initialize] 幂等（重复调用安全）；
/// - [synthesize] 失败（不支持产文件 / 平台异常 / 文件为空）时返回 null，
///   由协调器决定降级到 [speakLive]，**不抛异常打断上层**；
/// - 资源由各引擎自己创建自己释放（[dispose]）。
abstract interface class TtsEngine {
  /// 初始化引擎（幂等）。平台引擎注册回调；未来 Kokoro 加载模型。
  Future<void> initialize();

  /// 应用发音配置（speak/synthesize 前可热更新，如切换口音）。
  Future<void> applyConfig(TtsSpeechConfig config);

  /// 把 [text] 合成为本地音频文件，写入 [outputDir] 下、基名为 [baseName]
  /// 的文件（扩展名由引擎按平台决定，如 Android/macOS `wav` / iOS `caf`）。
  ///
  /// [config] 为本次合成的完整配置（音色/口音/语速）。显式传入而非依赖引擎环境态，
  /// 使同一引擎可在并发下安全地为不同音色合成（试听/预热）——见 [TtsCoordinator]。
  /// 为 null 时回退到 [applyConfig] 设定的配置（向后兼容）。
  ///
  /// 成功返回结果（含实际路径与格式）；本引擎不支持产文件或合成失败时返回 null。
  Future<TtsSynthesisResult?> synthesize(
    String text, {
    required String outputDir,
    required String baseName,
    TtsSpeechConfig? config,
  });

  /// 实时朗读 [text]（无文件兜底）。返回是否成功启动并完成。
  ///
  /// 返回的 Future 在真正朗读完成后才 complete；被新调用抢占时立即
  /// complete（不悬挂调用方）。
  Future<bool> speakLive(String text);

  /// 停止当前朗读/合成（幂等）。
  Future<void> stop();

  /// 释放资源。
  Future<void> dispose();
}

/// 引擎工厂：按种类创建引擎实例。
typedef TtsEngineFactory =
    TtsEngine Function(TtsEngineKind kind, TtsSpeechConfig config);

/// 精听设置模型
///
/// 独立于播放状态的纯配置模型，用于持久化存储。
/// 控制精听播放器的每句循环次数和句间停顿行为。
library;

import '../utils/playback_speed.dart';

/// 跟读控制模式
enum ShadowingControlMode {
  /// 自动模式：自动开始录音、自动停止、自动推进下一句
  auto,

  /// 手动模式：用户手动点击录音/停止/下一句
  manual,
}

/// 跟读参考音频来源。
enum ShadowingReferenceSource {
  /// 播放原媒体中的句子片段。
  original,

  /// 使用本地 Kokoro 朗读句子文本。
  localTts,
}

/// 停顿模式
enum PauseMode {
  /// 智能间隔：2 倍句子时长，最短 2 秒
  smart,

  /// 固定间隔：指定秒数
  fixed,

  /// 句长倍数：句子时长 × 倍数
  multiplier,
}

/// 精听设置（独立于播放状态，持久化存储）
class IntensiveListenSettings {
  /// 每句循环次数（`0`=∞ 无限，`1-10/20/30/40/50`=有限次数，默认 1）
  final int repeatCount;

  /// 讲解页点击播放按钮时是否沿用每句循环次数（默认关闭）。
  final bool annotationReplayUsesRepeatCount;

  /// 停顿模式（默认 smart）
  final PauseMode pauseMode;

  /// 固定间隔秒数（默认 3）
  final int fixedPauseSeconds;

  /// 句长倍数（默认 2.0）
  final double pauseMultiplier;

  /// 控制模式（默认 auto，跟读/精听共用）
  final ShadowingControlMode controlMode;

  /// 播放速度（0.5x-2.0x，默认 1.0x）
  ///
  /// 难句跟读 / 逐句精听 入口弹窗均会写入此字段，会话内每次播音前生效。
  final double playbackSpeed;

  /// 跟读参考音频来源（默认原音）。
  final ShadowingReferenceSource referenceSource;

  /// 入口弹窗使用的离散速度选项
  ///
  /// 与 [BlindListenSettings.briefingPlaybackSpeedOptions] / [RetellSettings.briefingPlaybackSpeedOptions] 保持一致。
  static const List<double> briefingPlaybackSpeedOptions =
      kUnifiedPlaybackSpeeds;

  /// 固定间隔可选值
  static const List<int> fixedPauseOptions = [
    1,
    2,
    3,
    5,
    7,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
    60,
  ];

  /// 倍数可选值
  static const List<double> multiplierOptions = [
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    4.0,
    5.0,
  ];

  const IntensiveListenSettings({
    this.repeatCount = 1,
    this.annotationReplayUsesRepeatCount = false,
    this.pauseMode = PauseMode.smart,
    this.fixedPauseSeconds = 3,
    this.pauseMultiplier = 2.0,
    this.controlMode = ShadowingControlMode.auto,
    this.playbackSpeed = 1.0,
    this.referenceSource = ShadowingReferenceSource.original,
  });

  /// 是否为手动控制模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  IntensiveListenSettings copyWith({
    int? repeatCount,
    bool? annotationReplayUsesRepeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    ShadowingControlMode? controlMode,
    double? playbackSpeed,
    ShadowingReferenceSource? referenceSource,
  }) {
    return IntensiveListenSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      annotationReplayUsesRepeatCount:
          annotationReplayUsesRepeatCount ??
          this.annotationReplayUsesRepeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
      controlMode: controlMode ?? this.controlMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      referenceSource: referenceSource ?? this.referenceSource,
    );
  }

  Map<String, dynamic> toJson() => {
    'repeatCount': repeatCount,
    'annotationReplayUsesRepeatCount': annotationReplayUsesRepeatCount,
    'pauseMode': pauseMode.name,
    'fixedPauseSeconds': fixedPauseSeconds,
    'pauseMultiplier': pauseMultiplier,
    'controlMode': controlMode.name,
    'playbackSpeed': playbackSpeed,
    'referenceSource': referenceSource.name,
  };

  /// 防御性解析：非法值回退默认
  factory IntensiveListenSettings.fromJson(Map<String, dynamic> json) {
    return IntensiveListenSettings(
      repeatCount: _parseRepeatCount(json['repeatCount']),
      annotationReplayUsesRepeatCount: _parseAnnotationReplayUsesRepeatCount(
        json['annotationReplayUsesRepeatCount'],
      ),
      pauseMode: _parsePauseMode(json['pauseMode']),
      fixedPauseSeconds: _parseFixedPauseSeconds(json['fixedPauseSeconds']),
      pauseMultiplier: _parsePauseMultiplier(json['pauseMultiplier']),
      controlMode: _parseControlMode(json['controlMode']),
      playbackSpeed: _parsePlaybackSpeed(json['playbackSpeed']),
      referenceSource: _parseReferenceSource(json['referenceSource']),
    );
  }

  /// 解析播放速度：归一化到统一支持档位，否则回退 1.0
  static double _parsePlaybackSpeed(dynamic raw) {
    if (raw is! num) return 1.0;
    return normalizePlaybackSpeed(raw.toDouble());
  }

  /// 解析循环次数：`0`=∞；有限次数上限为 50；其余非法值回退 1。
  static int _parseRepeatCount(dynamic raw) {
    if (raw is! int) return 1;
    if (raw == 0) return 0;
    if (raw < 1) return 1;
    return raw > 50 ? 50 : raw;
  }

  /// 解析讲解页循环开关：非法值回退关闭。
  static bool _parseAnnotationReplayUsesRepeatCount(dynamic raw) =>
      raw is bool ? raw : false;

  /// 解析停顿模式：非法值回退 smart
  static PauseMode _parsePauseMode(dynamic raw) {
    if (raw is! String) return PauseMode.smart;
    return PauseMode.values.where((e) => e.name == raw).firstOrNull ??
        PauseMode.smart;
  }

  /// 解析固定间隔：必须在可选值列表中，否则回退 3
  static int _parseFixedPauseSeconds(dynamic raw) {
    if (raw is! int) return 3;
    if (!fixedPauseOptions.contains(raw)) return 3;
    return raw;
  }

  /// 解析倍数：必须在可选值列表中，否则回退 2.0
  static double _parsePauseMultiplier(dynamic raw) {
    if (raw is! num) return 2.0;
    final value = raw.toDouble();
    if (!multiplierOptions.contains(value)) return 2.0;
    return value;
  }

  /// 解析控制模式：非法值回退 auto
  static ShadowingControlMode _parseControlMode(dynamic raw) {
    if (raw is! String) return ShadowingControlMode.auto;
    return ShadowingControlMode.values
            .where((e) => e.name == raw)
            .firstOrNull ??
        ShadowingControlMode.auto;
  }

  static ShadowingReferenceSource _parseReferenceSource(dynamic raw) {
    if (raw is! String) return ShadowingReferenceSource.original;
    return ShadowingReferenceSource.values
            .where((e) => e.name == raw)
            .firstOrNull ??
        ShadowingReferenceSource.original;
  }
}

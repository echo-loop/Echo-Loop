/// 精听设置模型
///
/// 独立于播放状态的纯配置模型，用于持久化存储。
/// 控制精听播放器的每句循环次数和句间停顿行为。
library;

/// 跟读控制模式
enum ShadowingControlMode {
  /// 自动模式：自动开始录音、自动停止、自动推进下一句
  auto,

  /// 手动模式：用户手动点击录音/停止/下一句
  manual,
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
  /// 每句循环次数（1-10，默认 1）
  final int repeatCount;

  /// 停顿模式（默认 smart）
  final PauseMode pauseMode;

  /// 固定间隔秒数（默认 5）
  final int fixedPauseSeconds;

  /// 句长倍数（默认 2.0）
  final double pauseMultiplier;

  /// 控制模式（默认 auto，跟读/精听共用）
  final ShadowingControlMode controlMode;

  /// 固定间隔可选值
  static const List<int> fixedPauseOptions = [
    1,
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
    this.pauseMode = PauseMode.smart,
    this.fixedPauseSeconds = 5,
    this.pauseMultiplier = 2.0,
    this.controlMode = ShadowingControlMode.auto,
  });

  /// 是否为手动控制模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  IntensiveListenSettings copyWith({
    int? repeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    ShadowingControlMode? controlMode,
  }) {
    return IntensiveListenSettings(
      repeatCount: repeatCount ?? this.repeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
      controlMode: controlMode ?? this.controlMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'repeatCount': repeatCount,
    'pauseMode': pauseMode.name,
    'fixedPauseSeconds': fixedPauseSeconds,
    'pauseMultiplier': pauseMultiplier,
    'controlMode': controlMode.name,
  };

  /// 防御性解析：非法值回退默认
  factory IntensiveListenSettings.fromJson(Map<String, dynamic> json) {
    return IntensiveListenSettings(
      repeatCount: _parseRepeatCount(json['repeatCount']),
      pauseMode: _parsePauseMode(json['pauseMode']),
      fixedPauseSeconds: _parseFixedPauseSeconds(json['fixedPauseSeconds']),
      pauseMultiplier: _parsePauseMultiplier(json['pauseMultiplier']),
      controlMode: _parseControlMode(json['controlMode']),
    );
  }

  /// 解析循环次数：范围 1-10
  static int _parseRepeatCount(dynamic raw) {
    if (raw is! int) return 1;
    return raw.clamp(1, 10);
  }

  /// 解析停顿模式：非法值回退 smart
  static PauseMode _parsePauseMode(dynamic raw) {
    if (raw is! String) return PauseMode.smart;
    return PauseMode.values.where((e) => e.name == raw).firstOrNull ??
        PauseMode.smart;
  }

  /// 解析固定间隔：必须在可选值列表中，否则回退 5
  static int _parseFixedPauseSeconds(dynamic raw) {
    if (raw is! int) return 5;
    if (!fixedPauseOptions.contains(raw)) return 5;
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
    return ShadowingControlMode.values.where((e) => e.name == raw).firstOrNull ??
        ShadowingControlMode.auto;
  }
}

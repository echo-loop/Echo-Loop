/// 难句补练/收藏复习设置模型
///
/// 独立于播放状态的纯配置模型，控制难句补练和收藏复习的播放参数。
/// 复用 [PauseMode] 枚举和选项列表。
library;

import 'dart:math' as math;

import 'intensive_listen_settings.dart';

/// 难句补练/收藏复习设置
///
/// 包含控制模式、盲听循环次数、跟读循环次数和句间停顿配置。
/// 设置仅对当次练习有效，不持久化。
class DifficultPracticeSettings {
  /// 控制模式（默认 auto），复用跟读页已有枚举
  final ShadowingControlMode controlMode;

  /// 盲听循环次数（1-10，默认 1）
  final int blindListenRepeatCount;

  /// 跟读循环次数（1-10，默认 3）
  final int shadowReadingRepeatCount;

  /// 停顿模式（默认 smart）
  final PauseMode pauseMode;

  /// 固定间隔秒数（默认 5）
  final int fixedPauseSeconds;

  /// 句长倍数（默认 2.0）
  final double pauseMultiplier;

  const DifficultPracticeSettings({
    this.controlMode = ShadowingControlMode.auto,
    this.blindListenRepeatCount = 1,
    this.shadowReadingRepeatCount = 3,
    this.pauseMode = PauseMode.smart,
    this.fixedPauseSeconds = 5,
    this.pauseMultiplier = 2.0,
  });

  /// 是否为手动控制模式
  bool get isManualMode => controlMode == ShadowingControlMode.manual;

  DifficultPracticeSettings copyWith({
    ShadowingControlMode? controlMode,
    int? blindListenRepeatCount,
    int? shadowReadingRepeatCount,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
  }) {
    return DifficultPracticeSettings(
      controlMode: controlMode ?? this.controlMode,
      blindListenRepeatCount:
          blindListenRepeatCount ?? this.blindListenRepeatCount,
      shadowReadingRepeatCount:
          shadowReadingRepeatCount ?? this.shadowReadingRepeatCount,
      pauseMode: pauseMode ?? this.pauseMode,
      fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
      pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
    );
  }

  /// 计算句间停顿时长
  ///
  /// 根据 [pauseMode] 和句子时长计算停顿：
  /// - smart：max(句长, 1000ms)
  /// - fixed：固定秒数
  /// - multiplier：句长 × 倍数，至少 1000ms
  Duration calculateInterSentencePause(Duration sentenceDuration) {
    switch (pauseMode) {
      case PauseMode.smart:
        final ms = sentenceDuration.inMilliseconds;
        return Duration(milliseconds: math.max(ms, 1000));
      case PauseMode.fixed:
        return Duration(seconds: fixedPauseSeconds);
      case PauseMode.multiplier:
        final ms = (sentenceDuration.inMilliseconds * pauseMultiplier).round();
        return Duration(milliseconds: math.max(ms, 1000));
    }
  }

  Map<String, dynamic> toJson() => {
    'controlMode': controlMode.name,
    'blindListenRepeatCount': blindListenRepeatCount,
    'shadowReadingRepeatCount': shadowReadingRepeatCount,
    'pauseMode': pauseMode.name,
    'fixedPauseSeconds': fixedPauseSeconds,
    'pauseMultiplier': pauseMultiplier,
  };

  /// 防御性解析：非法值回退默认
  factory DifficultPracticeSettings.fromJson(Map<String, dynamic> json) {
    return DifficultPracticeSettings(
      controlMode: _parseControlMode(json['controlMode']),
      blindListenRepeatCount: _clampInt(json['blindListenRepeatCount'], 1, 10),
      shadowReadingRepeatCount: _clampInt(
        json['shadowReadingRepeatCount'],
        1,
        10,
        fallback: 3,
      ),
      pauseMode: _parsePauseMode(json['pauseMode']),
      fixedPauseSeconds: _parseFixedPause(json['fixedPauseSeconds']),
      pauseMultiplier: _parseMultiplier(json['pauseMultiplier']),
    );
  }

  static ShadowingControlMode _parseControlMode(dynamic raw) {
    if (raw is! String) return ShadowingControlMode.auto;
    return ShadowingControlMode.values.where((e) => e.name == raw).firstOrNull ??
        ShadowingControlMode.auto;
  }

  static int _clampInt(dynamic raw, int min, int max, {int fallback = 1}) {
    if (raw is! int) return fallback;
    return raw.clamp(min, max);
  }

  static PauseMode _parsePauseMode(dynamic raw) {
    if (raw is! String) return PauseMode.smart;
    return PauseMode.values.where((e) => e.name == raw).firstOrNull ??
        PauseMode.smart;
  }

  static int _parseFixedPause(dynamic raw) {
    if (raw is! int) return 5;
    if (!IntensiveListenSettings.fixedPauseOptions.contains(raw)) return 5;
    return raw;
  }

  static double _parseMultiplier(dynamic raw) {
    if (raw is! num) return 2.0;
    final value = raw.toDouble();
    if (!IntensiveListenSettings.multiplierOptions.contains(value)) return 2.0;
    return value;
  }
}

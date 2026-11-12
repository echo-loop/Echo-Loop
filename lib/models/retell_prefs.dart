/// 段落复述「用户偏好」持久化模型(按槽位)
///
/// 全字段可空的偏好覆盖,`null` = 用默认(含动态智能默认)。与逐句精听同模式,额外多两个
/// 动态默认:可见词比例 [smartRatio]、目标段长 [targetSeconds](后者不是 RetellSettings
/// 字段,作为同槽位旁路键存取)。复述完成后自动播放录音走全局学习设置,不在此偏好内。
library;

import '../utils/playback_speed.dart';
import 'intensive_listen_settings.dart' show PauseMode, ShadowingControlMode;
import 'retell_settings.dart';

/// 段落复述用户偏好覆盖(不可变,全字段可空)。
class RetellPrefs {
  /// 播放速度覆盖(`null`=用智能默认)。
  final double? playbackSpeed;

  /// 停顿模式覆盖(`null`=smart)。
  final PauseMode? pauseMode;

  /// 固定间隔秒数覆盖(`null`=30)。
  final int? fixedPauseSeconds;

  /// 句长倍数覆盖(`null`=0.5)。
  final double? pauseMultiplier;

  /// 关键词挖空方式覆盖(`null`=random)。
  final KeywordMethod? keywordMethod;

  /// 可见词比例覆盖(`null`=用智能默认 smartRatio)。
  final KeywordRatio? keywordRatio;

  /// 控制模式覆盖(`null`=auto)。
  final ShadowingControlMode? controlMode;

  /// 每段循环次数覆盖(`null`=1)。
  final int? repeatCount;

  /// 目标段落时长秒数覆盖(旁路键,`null`=用智能默认 smartSeconds)。
  ///
  /// 非 RetellSettings 字段,合法档位校验在屏幕层(下拉 value 须在 items 内)。
  final int? targetSeconds;

  /// 复述参照文本覆盖(`null`=看英文)。
  final RetellPromptLanguage? promptLanguage;

  const RetellPrefs({
    this.playbackSpeed,
    this.pauseMode,
    this.fixedPauseSeconds,
    this.pauseMultiplier,
    this.keywordMethod,
    this.keywordRatio,
    this.controlMode,
    this.repeatCount,
    this.targetSeconds,
    this.promptLanguage,
  });

  /// 空偏好(用户未改动任何字段)。
  const RetellPrefs.empty()
    : playbackSpeed = null,
      pauseMode = null,
      fixedPauseSeconds = null,
      pauseMultiplier = null,
      keywordMethod = null,
      keywordRatio = null,
      controlMode = null,
      repeatCount = null,
      targetSeconds = null,
      promptLanguage = null;

  /// 把偏好叠加到默认值,得到本次会话生效的完整 [RetellSettings]。
  ///
  /// [smartSpeed]/[smartRatio] 为按当前难度/阶段算出的动态默认;偏好未设时用它们。
  /// 自动播放录音不在此(走全局学习设置),保持 RetellSettings 默认 false。
  RetellSettings resolve({
    required double smartSpeed,
    required KeywordRatio smartRatio,
  }) => RetellSettings(
    playbackSpeed: playbackSpeed ?? smartSpeed,
    pauseMode: pauseMode ?? PauseMode.smart,
    fixedPauseSeconds: fixedPauseSeconds ?? 30,
    pauseMultiplier: pauseMultiplier ?? 0.5,
    keywordMethod: keywordMethod ?? KeywordMethod.random,
    keywordRatio: keywordRatio ?? smartRatio,
    controlMode: controlMode ?? ShadowingControlMode.auto,
    repeatCount: repeatCount ?? 1,
    promptLanguage: promptLanguage ?? RetellPromptLanguage.original,
  );

  /// 返回叠加非空字段后的新偏好(细粒度 setter 用:只改传入的字段)。
  RetellPrefs copyWith({
    double? playbackSpeed,
    PauseMode? pauseMode,
    int? fixedPauseSeconds,
    double? pauseMultiplier,
    KeywordMethod? keywordMethod,
    KeywordRatio? keywordRatio,
    ShadowingControlMode? controlMode,
    int? repeatCount,
    int? targetSeconds,
    RetellPromptLanguage? promptLanguage,
  }) => RetellPrefs(
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    pauseMode: pauseMode ?? this.pauseMode,
    fixedPauseSeconds: fixedPauseSeconds ?? this.fixedPauseSeconds,
    pauseMultiplier: pauseMultiplier ?? this.pauseMultiplier,
    keywordMethod: keywordMethod ?? this.keywordMethod,
    keywordRatio: keywordRatio ?? this.keywordRatio,
    controlMode: controlMode ?? this.controlMode,
    repeatCount: repeatCount ?? this.repeatCount,
    targetSeconds: targetSeconds ?? this.targetSeconds,
    promptLanguage: promptLanguage ?? this.promptLanguage,
  );

  /// 序列化为稀疏 JSON(只写非空字段,枚举存 name)。
  Map<String, dynamic> toJson() => {
    if (playbackSpeed != null) 'playbackSpeed': playbackSpeed,
    if (pauseMode != null) 'pauseMode': pauseMode!.name,
    if (fixedPauseSeconds != null) 'fixedPauseSeconds': fixedPauseSeconds,
    if (pauseMultiplier != null) 'pauseMultiplier': pauseMultiplier,
    if (keywordMethod != null) 'keywordMethod': keywordMethod!.name,
    if (keywordRatio != null) 'keywordRatio': keywordRatio!.name,
    if (controlMode != null) 'controlMode': controlMode!.name,
    if (repeatCount != null) 'repeatCount': repeatCount,
    if (targetSeconds != null) 'targetSeconds': targetSeconds,
    if (promptLanguage != null) 'promptLanguage': promptLanguage!.name,
  };

  /// 防御性解析:缺失/类型错/越档一律视作未设(`null`)。
  factory RetellPrefs.fromJson(Map<String, dynamic> json) => RetellPrefs(
    playbackSpeed: _parseSpeed(json['playbackSpeed']),
    pauseMode: _parsePauseMode(json['pauseMode']),
    fixedPauseSeconds: _parseFixedPauseSeconds(json['fixedPauseSeconds']),
    pauseMultiplier: _parsePauseMultiplier(json['pauseMultiplier']),
    keywordMethod: _parseKeywordMethod(json['keywordMethod']),
    keywordRatio: _parseKeywordRatio(json['keywordRatio']),
    controlMode: _parseControlMode(json['controlMode']),
    repeatCount: _parseRepeatCount(json['repeatCount']),
    targetSeconds: json['targetSeconds'] is int
        ? json['targetSeconds'] as int
        : null,
    promptLanguage: _parsePromptLanguage(json['promptLanguage']),
  );

  static RetellPromptLanguage? _parsePromptLanguage(dynamic raw) =>
      raw is String
      ? RetellPromptLanguage.values.where((e) => e.name == raw).firstOrNull
      : null;

  static double? _parseSpeed(dynamic raw) =>
      raw is num ? normalizePlaybackSpeed(raw.toDouble()) : null;

  static PauseMode? _parsePauseMode(dynamic raw) => raw is String
      ? PauseMode.values.where((e) => e.name == raw).firstOrNull
      : null;

  static int? _parseFixedPauseSeconds(dynamic raw) =>
      (raw is int && RetellSettings.fixedPauseOptions.contains(raw))
      ? raw
      : null;

  static double? _parsePauseMultiplier(dynamic raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    return RetellSettings.multiplierOptions.contains(value) ? value : null;
  }

  static KeywordMethod? _parseKeywordMethod(dynamic raw) => raw is String
      ? KeywordMethod.values.where((e) => e.name == raw).firstOrNull
      : null;

  static KeywordRatio? _parseKeywordRatio(dynamic raw) => raw is String
      ? KeywordRatio.values.where((e) => e.name == raw).firstOrNull
      : null;

  static ShadowingControlMode? _parseControlMode(dynamic raw) => raw is String
      ? ShadowingControlMode.values.where((e) => e.name == raw).firstOrNull
      : null;

  static int? _parseRepeatCount(dynamic raw) {
    if (raw is! int) return null;
    if (raw == 0) return 0;
    if (raw < 1) return null;
    return raw > 50 ? 50 : raw;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetellPrefs &&
          runtimeType == other.runtimeType &&
          playbackSpeed == other.playbackSpeed &&
          pauseMode == other.pauseMode &&
          fixedPauseSeconds == other.fixedPauseSeconds &&
          pauseMultiplier == other.pauseMultiplier &&
          keywordMethod == other.keywordMethod &&
          keywordRatio == other.keywordRatio &&
          controlMode == other.controlMode &&
          repeatCount == other.repeatCount &&
          targetSeconds == other.targetSeconds &&
          promptLanguage == other.promptLanguage;

  @override
  int get hashCode => Object.hash(
    playbackSpeed,
    pauseMode,
    fixedPauseSeconds,
    pauseMultiplier,
    keywordMethod,
    keywordRatio,
    controlMode,
    repeatCount,
    targetSeconds,
    promptLanguage,
  );
}

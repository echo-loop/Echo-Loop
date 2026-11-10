import '../utils/playback_speed.dart';

/// Free Player 支持的离散速度档位。
const List<double> kFreePlayerPlaybackSpeeds = kUnifiedPlaybackSpeeds;

/// 随心听播放栏速度按钮的可选档位，升序排列。
///
/// 比 [kFreePlayerPlaybackSpeeds] 精简，只保留常用速度，避免浮层过长。
const List<double> kFreePlayerSpeedOptions = [
  0.5,
  0.7,
  0.8,
  0.9,
  1.0,
  1.2,
  1.5,
  2.0,
];

double normalizeFreePlayerPlaybackSpeed(double speed) {
  return normalizePlaybackSpeed(speed);
}

/// 自由练习播放器设置模型。
///
/// 循环行为由两组**相互独立、可同时开启**的开关描述：
/// - 整篇循环（[loopWhole]）：整篇播完后回到开头重播，总共播 [wholeLoopCount] 遍
///   （`0`=∞ 无限）；每遍之间停顿 [wholeInterval]。
/// - 单句循环（[loopSentence]）：每句重复 [sentenceLoopCount] 次（`0`=∞ 无限）后进
///   下一句；每次重复之间停顿 [sentenceInterval]。
///
/// 两者可同时开启：每句重复若干次，整篇走到末尾后再整体循环若干遍。
class PlaybackSettings {
  /// 整篇循环开关。
  final bool loopWhole;

  /// 整篇循环的总播放遍数。`1-10/20/30/40/50`：播该遍数后停止；`0`：无限循环（∞）。
  final int wholeLoopCount;

  /// 整篇每遍之间的间隔时间（0-10 秒）。
  final Duration wholeInterval;

  /// 单句循环开关。
  final bool loopSentence;

  /// 单句循环时当前句的重复次数。`1-10/20/30/40/50`：重复该次数后进下一句；`0`：无限重复（∞）。
  final int sentenceLoopCount;

  /// 单句每次重复之间的间隔时间（0-10 秒）。
  final Duration sentenceInterval;

  /// 播放速度。
  final double playbackSpeed;

  /// 单句模式：控制字幕展示方式。
  final bool singleSentenceMode;

  /// 是否显示字幕文本。
  final bool showTranscript;

  const PlaybackSettings({
    this.loopWhole = false,
    this.wholeLoopCount = 3,
    this.wholeInterval = const Duration(seconds: 3),
    this.loopSentence = false,
    this.sentenceLoopCount = 3,
    this.sentenceInterval = const Duration(seconds: 2),
    this.playbackSpeed = 1.0,
    this.singleSentenceMode = false,
    this.showTranscript = true,
  });

  /// 整篇循环是否为无限（开启且次数为 0）。
  bool get isInfiniteWhole => loopWhole && wholeLoopCount == 0;

  /// 单句循环是否为无限（开启且次数为 0）。
  bool get isInfiniteSentence => loopSentence && sentenceLoopCount == 0;

  /// 序列化为 JSON。
  ///
  /// 循环开关、循环参数和其他播放偏好一起落盘；全文与收藏的设置分别保存。
  Map<String, dynamic> toJson() => {
    'loopWhole': loopWhole,
    'wholeLoopCount': wholeLoopCount,
    'wholeInterval': wholeInterval.inMilliseconds,
    'loopSentence': loopSentence,
    'sentenceLoopCount': sentenceLoopCount,
    'sentenceInterval': sentenceInterval.inMilliseconds,
    'playbackSpeed': playbackSpeed,
    'singleSentenceMode': singleSentenceMode,
    'showTranscript': showTranscript,
  };

  /// 从 JSON 还原设置，并兼容旧版持久化数据。
  ///
  /// 缺少循环开关键的旧设置默认关闭循环；旧 `repeatMode`/`loopEnabled`/
  /// `loopAudioEnabled` 字段仍忽略。旧 `loopCount`/`pauseInterval` 继续迁移为单句循环参数。
  factory PlaybackSettings.fromJson(Map<String, dynamic> json) {
    final speed = normalizeFreePlayerPlaybackSpeed(
      (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    );
    final single = json['singleSentenceMode'] == true;
    final transcript = json['showTranscript'] ?? true;

    final hasNewParams =
        json.containsKey('wholeLoopCount') ||
        json.containsKey('sentenceLoopCount') ||
        json.containsKey('wholeInterval') ||
        json.containsKey('sentenceInterval') ||
        json.containsKey('loopWhole') ||
        json.containsKey('loopSentence');
    if (hasNewParams) {
      return PlaybackSettings(
        loopWhole: json['loopWhole'] == true,
        wholeLoopCount: _parseCount(json['wholeLoopCount'], 3),
        wholeInterval: _parseInterval(json['wholeInterval'], 3),
        loopSentence: json['loopSentence'] == true,
        sentenceLoopCount: _parseCount(json['sentenceLoopCount'], 3),
        sentenceInterval: _parseInterval(json['sentenceInterval'], 2),
        playbackSpeed: speed,
        singleSentenceMode: single,
        showTranscript: transcript,
      );
    }

    // 旧 schema：仅迁移参数偏好，开关一律不恢复
    if (_legacyMode(json) == 'one') {
      return PlaybackSettings(
        sentenceLoopCount: _parseCount(json['loopCount'], 3),
        sentenceInterval: _parseInterval(json['pauseInterval'], 2),
        playbackSpeed: speed,
        singleSentenceMode: single,
        showTranscript: transcript,
      );
    }
    return PlaybackSettings(
      playbackSpeed: speed,
      singleSentenceMode: single,
      showTranscript: transcript,
    );
  }

  /// 解析循环次数：`0`=∞；有限次数上限为 50；其余非法值回退 [def]。
  static int _parseCount(dynamic raw, int def) {
    if (raw is! int) return def;
    if (raw == 0) return 0; // ∞
    if (raw < 1) return def;
    return raw > 50 ? 50 : raw;
  }

  /// 解析间隔时间：范围 0-10 秒，越界截断；缺失则用 [defSecs]。
  static Duration _parseInterval(dynamic ms, int defSecs) {
    final raw = ms is int ? ms : defSecs * 1000;
    int secs = (raw / 1000).round();
    if (secs < 0) secs = 0;
    if (secs > 10) secs = 10;
    return Duration(seconds: secs);
  }

  /// 解析旧版循环模式名（`one`/`all`/`off`），兼容更旧的布尔字段。
  static String _legacyMode(Map<String, dynamic> json) {
    final raw = json['repeatMode'];
    if (raw == 'one' || raw == 'all' || raw == 'off') return raw as String;
    if (json['loopEnabled'] == true) return 'one';
    if (json['loopAudioEnabled'] == true) return 'all';
    return 'off';
  }

  PlaybackSettings copyWith({
    bool? loopWhole,
    int? wholeLoopCount,
    Duration? wholeInterval,
    bool? loopSentence,
    int? sentenceLoopCount,
    Duration? sentenceInterval,
    double? playbackSpeed,
    bool? singleSentenceMode,
    bool? showTranscript,
  }) {
    return PlaybackSettings(
      loopWhole: loopWhole ?? this.loopWhole,
      wholeLoopCount: wholeLoopCount ?? this.wholeLoopCount,
      wholeInterval: wholeInterval ?? this.wholeInterval,
      loopSentence: loopSentence ?? this.loopSentence,
      sentenceLoopCount: sentenceLoopCount ?? this.sentenceLoopCount,
      sentenceInterval: sentenceInterval ?? this.sentenceInterval,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      singleSentenceMode: singleSentenceMode ?? this.singleSentenceMode,
      showTranscript: showTranscript ?? this.showTranscript,
    );
  }
}

/// 收藏 tab 的默认循环设置。
///
/// 收藏句通常不是连续上下文；默认开启单句循环并在句间留 1 秒停顿，可避免收藏跳播时
/// 两句无缝硬切，听感更接近“逐句复盘”而不是“连续播放”。
const PlaybackSettings kDefaultBookmarkPlaybackSettings = PlaybackSettings(
  loopSentence: true,
  sentenceLoopCount: 1,
  sentenceInterval: Duration(seconds: 1),
);

/// 将任意设置规范化为收藏 tab 默认循环语义，同时保留其他偏好字段。
PlaybackSettings withBookmarkLoopDefaults(PlaybackSettings settings) {
  return settings.copyWith(
    loopWhole: false,
    loopSentence: true,
    sentenceLoopCount: kDefaultBookmarkPlaybackSettings.sentenceLoopCount,
    sentenceInterval: kDefaultBookmarkPlaybackSettings.sentenceInterval,
  );
}

// 播放设置模型
class PlaybackSettings {
  final bool loopEnabled; // 是否启用句子循环
  final int loopCount; // 句子循环次数，1-20
  final Duration pauseInterval; // 句子循环间隔时间
  final double playbackSpeed; // 播放速度
  final bool singleSentenceMode; // 单句模式：控制字幕展示方式
  final bool showTranscript; // 是否显示字幕文本
  final bool loopAudioEnabled; // 是否启用音频循环
  final int loopAudio; // 音频循环次数：0=无穷，1-10=具体次数
  final bool autoPlayNextSentenceEnabled; // 句子循环完成后是否自动播放下一句

  PlaybackSettings({
    this.loopEnabled = false,
    this.loopCount = 3,
    this.pauseInterval = const Duration(seconds: 3),
    this.playbackSpeed = 1.0,
    this.singleSentenceMode = false,
    this.showTranscript = true,
    this.loopAudioEnabled = false, // 默认不启用音频循环
    this.loopAudio = 1, // 默认循环1次
    this.autoPlayNextSentenceEnabled = true, // 默认自动播放下一句
  });

  Map<String, dynamic> toJson() => {
    'loopEnabled': loopEnabled,
    'loopCount': loopCount,
    'pauseInterval': pauseInterval.inMilliseconds,
    'playbackSpeed': playbackSpeed,
    'singleSentenceMode': singleSentenceMode,
    'showTranscript': showTranscript,
    'loopAudioEnabled': loopAudioEnabled,
    'loopAudio': loopAudio,
    'autoPlayNextSentenceEnabled': autoPlayNextSentenceEnabled,
  };

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) =>
      PlaybackSettings(
        loopEnabled: json['loopEnabled'] ?? false,
        // 句子循环次数：范围 1-20
        loopCount: (() {
          final raw = json['loopCount'];
          final v = raw is int ? raw : 3;
          if (v < 1) return 3;
          if (v > 20) return 20;
          return v;
        })(),
        // 句子循环间隔：范围 0-30秒
        pauseInterval: (() {
          final ms = json['pauseInterval'];
          final rawMs = ms is int ? ms : 1000;
          int secs = (rawMs / 1000).round();
          if (secs < 0) secs = 0;
          if (secs > 30) secs = 30;
          return Duration(seconds: secs);
        })(),
        playbackSpeed: json['playbackSpeed'] ?? 1.0,
        singleSentenceMode: json['singleSentenceMode'] ?? false,
        showTranscript: json['showTranscript'] ?? true,
        loopAudioEnabled: json['loopAudioEnabled'] ?? false,
        // 音频循环：0=无穷，1-10=具体次数
        loopAudio: (() {
          final raw = json['loopAudio'];
          final v = raw is int ? raw : 1;
          if (v < 0) return 1;
          if (v > 10) return 10;
          return v;
        })(),
        autoPlayNextSentenceEnabled:
            json['autoPlayNextSentenceEnabled'] ?? true,
      );

  PlaybackSettings copyWith({
    bool? loopEnabled,
    int? loopCount,
    Duration? pauseInterval,
    double? playbackSpeed,
    bool? singleSentenceMode,
    bool? showTranscript,
    bool? loopAudioEnabled,
    int? loopAudio,
    bool? autoPlayNextSentenceEnabled,
  }) {
    return PlaybackSettings(
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopCount: loopCount ?? this.loopCount,
      pauseInterval: pauseInterval ?? this.pauseInterval,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      singleSentenceMode: singleSentenceMode ?? this.singleSentenceMode,
      showTranscript: showTranscript ?? this.showTranscript,
      loopAudioEnabled: loopAudioEnabled ?? this.loopAudioEnabled,
      loopAudio: loopAudio ?? this.loopAudio,
      autoPlayNextSentenceEnabled:
          autoPlayNextSentenceEnabled ?? this.autoPlayNextSentenceEnabled,
    );
  }
}

/// 与后端 `GET /api/v1/audios/:id/content` 对齐的 DTO。
///
/// 客户端点击某条官方音频开始学习时调用，一次拿齐下载所需：
/// 音频 URL（每次实时）+ SRT 字符串 + 词级时间戳。
library;

import '../../../models/word_timestamp.dart';

/// 下载音频 + 字幕所需内容。
class AudioContent {
  /// R2 永久 URL；客户端用它下载一次即可，不持久化。
  final String audioUrl;

  /// SRT 文本（服务端从 transcripts.sentences 实时生成）。
  /// 直接 [File.writeAsString] 到 `transcripts/official_<audioId>.srt`。
  final String srt;

  /// 词级时间戳。复用现有 [WordTimestamp] 模型（与本地 audio_items.word_timestamps_json 同构）。
  final List<WordTimestamp> wordTimestamps;

  const AudioContent({
    required this.audioUrl,
    required this.srt,
    required this.wordTimestamps,
  });

  factory AudioContent.fromJson(Map<String, dynamic> json) {
    final rawWords = (json['wordTimestamps'] as List? ?? const []);
    return AudioContent(
      audioUrl: json['audioUrl'] as String,
      srt: json['srt'] as String,
      wordTimestamps: rawWords
          .map((e) => WordTimestamp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

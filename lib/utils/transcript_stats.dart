// 字幕统计工具
//
// 解析字幕文件，统计句子数和单词数。
import 'app_data_dir.dart';
import 'package:path/path.dart' as path;

import '../models/sentence.dart';
import '../services/subtitle_parser.dart';

/// 解析字幕文件，返回 (sentenceCount, wordCount)
///
/// [transcriptRelativePath] 为相对于应用数据目录的路径，
/// 如 "transcripts/test.srt"。
/// 解析失败时返回 (0, 0)。
Future<(int, int)> getTranscriptStats(String transcriptRelativePath) async {
  final dataDir = await getAppDataDirectory();
  final fullPath = path.join(dataDir.path, transcriptRelativePath);

  final sentences = await SubtitleParser.parseSubtitle(fullPath);
  return _countStats(sentences);
}

/// 从 SRT 字符串内容统计 (sentenceCount, wordCount)。
///
/// 字幕内容入库后的统计入口：保存时本就持有 SRT 字符串，免再读盘。
/// 解析失败时返回 (0, 0)。
Future<(int, int)> getTranscriptStatsFromSrt(String srt) async {
  final sentences = await SubtitleParser.parseSubtitleString(srt);
  return _countStats(sentences);
}

/// 统计句子列表的 (句数, 词数)。
(int, int) _countStats(List<Sentence> sentences) {
  if (sentences.isEmpty) return (0, 0);

  final sentenceCount = sentences.length;
  int wordCount = 0;
  for (final sentence in sentences) {
    final words = sentence.text.trim().split(RegExp(r'\s+'));
    wordCount += words.where((w) => w.isNotEmpty).length;
  }

  return (sentenceCount, wordCount);
}

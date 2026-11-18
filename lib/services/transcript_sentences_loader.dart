import 'dart:io';

import '../database/daos/audio_item_dao.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import 'subtitle_parser.dart';

/// 读取材料的字幕句子，与任何播放器无关。
///
/// 字幕内容唯一真相源是 DB 的 `transcript_srt` 列；列为空但还有遗留字幕文件时
/// 读文件并回填列（旧版本把字幕存成文件）。材料没有字幕时返回空列表。
/// 读取或解析失败直接抛出，由调用方决定降级还是报错。
Future<List<Sentence>> loadTranscriptSentences(
  AudioItemDao dao,
  AudioItem audioItem,
) async {
  if (!audioItem.hasTranscript) return [];

  final srt = await dao.getTranscriptSrt(audioItem.id);
  if (srt != null && srt.isNotEmpty) {
    return SubtitleParser.parseSubtitleString(srt);
  }

  final fullTranscriptPath = await audioItem.getFullTranscriptPath();
  if (fullTranscriptPath == null) return [];
  final file = File(fullTranscriptPath);
  if (!await file.exists()) return [];
  final content = await file.readAsString();
  if (content.isEmpty) return [];
  await dao.updateTranscriptSrt(audioItem.id, content);
  return SubtitleParser.parseSubtitleString(content);
}

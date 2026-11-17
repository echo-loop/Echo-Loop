/// 字幕句子解析（学习材料与收藏导出共用）
library;

import '../../../models/sentence.dart';
import '../../subtitle_parser.dart';

/// compute 入口：字幕解析（数百 ms 级 CPU，放 isolate 不占主 isolate）
Future<List<Sentence>> parsePdfTranscript(String srt) =>
    SubtitleParser.parseSubtitleString(srt);

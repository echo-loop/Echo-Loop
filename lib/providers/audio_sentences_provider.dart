/// 共享内存字幕 store（按音频只读投影）
///
/// 把一段音频的完整句子列表 `List<Sentence>` 常驻内存，供任意页面按
/// `audioItemId + sentenceIndex` 取相邻句（做 AI 翻译的前后句上下文）。
///
/// 设计要点：
/// - **卸载时机 = 观察者生命周期（autoDispose）**：由 [SentenceExplanationView] 等在
///   build 中 `ref.watch(audioSentencesProvider(id))` 撑起生命周期，视图离屏即自动
///   释放；同 audioItemId 的多个观察者（如 player PageView 相邻页）共享唯一实例。
///   不用 keepAlive，内存不无限累积。
/// - **单一真相源**：唯一真相源是 DB 的 `transcript_srt` 列，本 store 仅其只读投影；
///   仅用于取不可变的 [Sentence.text]，不承载可变的收藏态（`isBookmarked` 真相源在别处）。
///   字幕变更处（`updateTranscriptSrt`）需 `ref.invalidate(audioSentencesProvider(id))`
///   令投影重解析，保证与真相源同步。
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/providers.dart';
import '../models/sentence.dart';
import '../services/subtitle_parser.dart';

part 'audio_sentences_provider.g.dart';

/// 某音频的完整句子列表（index 0..N-1 连续，`list[i-1]/list[i+1]` 即前后句）。
///
/// 无字幕或解析失败返回空列表。直接走 `getTranscriptSrt + SubtitleParser`，
/// 不经 `AudioEngine.loadTranscript`，与播放态解耦。
@riverpod
Future<List<Sentence>> audioSentences(Ref ref, String audioItemId) async {
  if (audioItemId.isEmpty) return const [];
  final srt = await ref
      .read(audioItemDaoProvider)
      .getTranscriptSrt(audioItemId);
  if (srt == null || srt.isEmpty) return const [];
  return SubtitleParser.parseSubtitleString(srt);
}

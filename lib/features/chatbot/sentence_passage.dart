/// 句子聊天上下文构造工具。
library;

import '../../models/sentence.dart';
import '../../services/app_logger.dart';
import '../../services/source_sentence_anchor.dart';

/// 句子聊天的目标及其来源。
///
/// 页面只提供学习目标和原文定位；完整字幕读取与上下文截取由 chatbot 统一完成。
class SentenceChatTarget {
  /// AI 当前需要讲解的句子、单词或短语。
  final String text;

  /// 目标所在材料；没有来源材料时保留单句模式。
  final String? audioItemId;

  /// 目标对应的原文句索引；已知时优先使用。
  final int? sentenceIndex;

  /// 来源句时间区间（毫秒）。收藏不存句子编号，无 [sentenceIndex] 时打开对话
  /// 才按区间在当前字幕里定位，避免页面异步现算编号未完成时丢失上下文。
  final int? sentenceStartMs;
  final int? sentenceEndMs;

  const SentenceChatTarget({
    required this.text,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });
}

/// 打开对话时定位到的上下文：目标句编号（会话身份的一部分）与截取的字幕段落。
typedef SentenceChatContext = ({int? sentenceIndex, String? passage});

/// 取目标句前最多 5 个有效句子、后最多 2 个有效句子，并按原顺序拼接。
///
/// [currentSentenceIndex] 使用字幕模型中的句序号；字幕缺失、索引不匹配或
/// 邻近句均为空时返回 null，让调用方继续使用仅含当前句的兼容请求。
String? buildSentencePassage(
  List<Sentence> sentences, {
  required int currentSentenceIndex,
}) {
  final currentPosition = sentences.indexWhere(
    (sentence) => sentence.index == currentSentenceIndex,
  );
  if (currentPosition < 0 || sentences[currentPosition].text.trim().isEmpty) {
    return null;
  }

  final previousSentences = <String>[];
  for (
    var position = currentPosition - 1;
    position >= 0 && previousSentences.length < 5;
    position--
  ) {
    final text = sentences[position].text.trim();
    if (text.isNotEmpty) previousSentences.add(text);
  }

  final nextSentences = <String>[];
  for (
    var position = currentPosition + 1;
    position < sentences.length && nextSentences.length < 2;
    position++
  ) {
    final text = sentences[position].text.trim();
    if (text.isNotEmpty) nextSentences.add(text);
  }

  final passageSentences = [
    ...previousSentences.reversed,
    sentences[currentPosition].text.trim(),
    ...nextSentences,
  ];

  if (passageSentences.length < 2) return null;
  return passageSentences.join('\n');
}

/// 根据目标来源定位句子编号并解析完整字幕上下文；缺失或读取失败时退回单句模式。
///
/// 无编号时按 [SentenceChatTarget.sentenceStartMs]/[SentenceChatTarget.sentenceEndMs]
/// 在同一份字幕里定位，与收藏复习讲解页的编号算法一致，保证会话身份跨页面一致。
Future<SentenceChatContext> resolveSentenceChatContext({
  required SentenceChatTarget target,
  required Future<List<Sentence>> Function(String audioItemId) loadSentences,
}) async {
  final audioItemId = target.audioItemId;
  final anchor = SourceSentenceAnchor.fromMilliseconds(
    startMs: target.sentenceStartMs,
    endMs: target.sentenceEndMs,
  );
  if (audioItemId == null ||
      audioItemId.isEmpty ||
      (target.sentenceIndex == null && !anchor.hasTimeRange)) {
    return (sentenceIndex: target.sentenceIndex, passage: null);
  }

  final List<Sentence> sentences;
  try {
    sentences = await loadSentences(audioItemId);
  } catch (error, stackTrace) {
    AppLogger.log(
      'SentenceChat',
      'event=context-load-failed audioItemId=$audioItemId '
          'sentenceIndex=${target.sentenceIndex} error=$error\n$stackTrace',
    );
    return (sentenceIndex: target.sentenceIndex, passage: null);
  }
  final sentenceIndex =
      target.sentenceIndex ?? resolveSourceSentenceIndex(anchor, sentences);
  if (sentenceIndex == null) return (sentenceIndex: null, passage: null);
  return (
    sentenceIndex: sentenceIndex,
    passage: buildSentencePassage(
      sentences,
      currentSentenceIndex: sentenceIndex,
    ),
  );
}

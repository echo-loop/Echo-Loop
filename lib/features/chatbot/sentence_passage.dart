/// 句子聊天上下文构造工具。
library;

import '../../models/sentence.dart';
import '../../services/app_logger.dart';

/// 句子聊天的目标及其来源。
///
/// 页面只提供学习目标和原文定位；完整字幕读取与上下文截取由 chatbot 统一完成。
class SentenceChatTarget {
  /// AI 当前需要讲解的句子、单词或短语。
  final String text;

  /// 目标所在材料；没有来源材料时保留单句模式。
  final String? audioItemId;

  /// 目标对应的原文句索引。
  final int? sentenceIndex;

  const SentenceChatTarget({
    required this.text,
    this.audioItemId,
    this.sentenceIndex,
  });
}

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

/// 根据目标来源解析完整字幕上下文；缺失或读取失败时退回单句模式。
Future<String?> resolveSentencePassage({
  required SentenceChatTarget target,
  required Future<List<Sentence>> Function(String audioItemId) loadSentences,
}) async {
  final audioItemId = target.audioItemId;
  final sentenceIndex = target.sentenceIndex;
  if (audioItemId == null || audioItemId.isEmpty || sentenceIndex == null) {
    return null;
  }

  try {
    final sentences = await loadSentences(audioItemId);
    return buildSentencePassage(sentences, currentSentenceIndex: sentenceIndex);
  } catch (error, stackTrace) {
    AppLogger.log(
      'SentenceChat',
      'event=context-load-failed audioItemId=$audioItemId '
          'sentenceIndex=$sentenceIndex error=$error\n$stackTrace',
    );
    return null;
  }
}

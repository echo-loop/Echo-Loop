/// 关键词提取算法
///
/// 纯随机 placeholder 实现，未来替换为 AI 驱动的关键词提取。
/// 从段落句子中随机选取词作为关键词提示。
library;

import 'dart:math';

import '../models/retell_settings.dart';
import '../models/sentence.dart';

/// 分词分隔符正则：空格 + 常见标点
final _wordSplitPattern = RegExp(r'[\s,;:!?."\-—–]+');

/// 从段落句子中提取关键词
///
/// [sentences] 段落内的句子列表
/// [ratio] 关键词比例（默认 1/3）
/// [random] 可选随机数生成器（便于测试）
///
/// 返回 `Map<int, Set<int>>`，键为句子在列表中的索引，值为该句中被选为关键词的词索引集合。
///
/// 算法：
/// 1. 对每个句子按空格+标点分词
/// 2. 收集候选词：长度 > 2 的词（降低门槛使短句也能选出关键词）
/// 3. 目标数量：(totalWords * ratio).round().clamp(1, totalWords)（基于总词数）
/// 4. 每句至少分配 1 个关键词（有候选词的情况下）
/// 5. 加权随机：权重 = 词长（长词概率更高）
/// 6. 返回每句中被选中词的位置索引
Map<int, Set<int>> extractKeywords(
  List<Sentence> sentences, {
  KeywordRatio ratio = KeywordRatio.oneThird,
  Random? random,
}) {
  final rng = random ?? Random();

  if (sentences.isEmpty) return {};

  // 分词并收集所有候选词及其位置
  final allWords = <({int sentenceIdx, int wordIdx, String word})>[];
  final candidatesPerSentence =
      <int, List<({int sentenceIdx, int wordIdx, String word})>>{};

  for (var si = 0; si < sentences.length; si++) {
    final words = _tokenize(sentences[si].text);
    for (var wi = 0; wi < words.length; wi++) {
      allWords.add((sentenceIdx: si, wordIdx: wi, word: words[wi]));
      if (words[wi].length > 2) {
        candidatesPerSentence
            .putIfAbsent(si, () => [])
            .add((sentenceIdx: si, wordIdx: wi, word: words[wi]));
      }
    }
  }

  // 无候选词时返回空映射
  if (candidatesPerSentence.isEmpty) return {};

  // 目标关键词总数（基于总词数）
  final totalWords = allWords.length;
  final targetCount = (totalWords * ratio.value).round().clamp(1, totalWords);

  // 先为每个有候选词的句子分配至少 1 个关键词
  final result = <int, Set<int>>{};
  final usedCandidates = <({int sentenceIdx, int wordIdx, String word})>{};

  for (final entry in candidatesPerSentence.entries) {
    final si = entry.key;
    final candidates = entry.value;
    // 加权随机选 1 个
    final pick = _weightedSample(candidates, 1, rng);
    result.putIfAbsent(si, () => {}).add(pick.first.wordIdx);
    usedCandidates.add(pick.first);
  }

  // 已分配的数量
  var assigned = result.values.fold<int>(0, (sum, s) => sum + s.length);

  // 如果还需要更多关键词，从剩余候选词中加权随机补充
  if (assigned < targetCount) {
    final remaining = <({int sentenceIdx, int wordIdx, String word})>[];
    for (final candidates in candidatesPerSentence.values) {
      for (final c in candidates) {
        if (!usedCandidates.contains(c)) {
          remaining.add(c);
        }
      }
    }

    if (remaining.isNotEmpty) {
      final extraCount = min(targetCount - assigned, remaining.length);
      final extras = _weightedSample(remaining, extraCount, rng);
      for (final item in extras) {
        result.putIfAbsent(item.sentenceIdx, () => {}).add(item.wordIdx);
      }
    }
  }

  return result;
}

/// 将句子文本分词为单词列表
List<String> tokenize(String text) => _tokenize(text);

/// 内部分词实现
List<String> _tokenize(String text) {
  return text.split(_wordSplitPattern).where((w) => w.isNotEmpty).toList();
}

/// 加权随机采样（不重复）
///
/// 权重为词长，长词被选中的概率更高。
List<({int sentenceIdx, int wordIdx, String word})> _weightedSample(
  List<({int sentenceIdx, int wordIdx, String word})> items,
  int count,
  Random rng,
) {
  // 不超过候选数
  final actualCount = min(count, items.length);

  // 构建权重列表
  final weights = items.map((e) => e.word.length.toDouble()).toList();

  final selected = <int>{};
  final result = <({int sentenceIdx, int wordIdx, String word})>[];

  while (result.length < actualCount) {
    // 计算未选中项的总权重
    var totalWeight = 0.0;
    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) totalWeight += weights[i];
    }

    // 随机选择
    var pick = rng.nextDouble() * totalWeight;
    for (var i = 0; i < items.length; i++) {
      if (selected.contains(i)) continue;
      pick -= weights[i];
      if (pick <= 0) {
        selected.add(i);
        result.add(items[i]);
        break;
      }
    }
  }

  return result;
}

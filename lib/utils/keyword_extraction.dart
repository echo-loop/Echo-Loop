/// 关键词提取算法
///
/// 从段落句子中随机选取非停用词作为关键词提示。
library;

import 'dart:math';

import '../models/retell_settings.dart';
import '../models/sentence.dart';
import 'stopwords.dart';

/// 分词分隔符正则：仅按空白字符拆分，保留标点附着在单词上
final _wordSplitPattern = RegExp(r'\s+');

/// 从句子列表中提取关键词
///
/// [sentences] 句子列表
/// [ratio] 关键词比例（默认 medium，40%）
/// [random] 可选随机数生成器（便于测试）
///
/// 返回 `Map<int, Set<int>>`，键为 [Sentence.index]（全局索引），
/// 值为该句中被选为关键词的词索引集合。
///
/// 算法：对每个句子独立计算——按该句**总词数 × ratio** 得出目标数。
/// 先从非停用词候选中随机选取，若仍不足则从停用词中补足，让高比例
/// （如 80%）视觉上确实接近 80% 的词被显示。
///
/// 边界：句子中没有任何非停用词候选时直接跳过（不显示任何"提示"）。
Map<int, Set<int>> extractKeywords(
  List<Sentence> sentences, {
  KeywordRatio ratio = KeywordRatio.medium,
  Random? random,
}) {
  final rng = random ?? Random();

  if (sentences.isEmpty) return {};

  final result = <int, Set<int>>{};

  for (final sentence in sentences) {
    final words = _tokenize(sentence.text);
    if (words.isEmpty) continue;

    // 收集候选词索引（非停用词且长度 > 2）—— 提示价值最高
    final candidateSet = <int>{
      for (var wi = 0; wi < words.length; wi++)
        if (words[wi].length > 2 && !isStopword(words[wi])) wi,
    };

    if (candidateSet.isEmpty) continue;

    // 其余词（停用词 / 短词）—— 高比例时用来补足
    final fillerIndices = <int>[
      for (var wi = 0; wi < words.length; wi++)
        if (!candidateSet.contains(wi)) wi,
    ];

    final candidateIndices = candidateSet.toList();

    // 按该句总词数计算目标数量，上限为总词数
    final targetCount = (words.length * ratio.value).round().clamp(
      1,
      words.length,
    );

    // 优先选内容词，不够则从停用词补足
    candidateIndices.shuffle(rng);
    fillerIndices.shuffle(rng);
    final ordered = [...candidateIndices, ...fillerIndices];
    result[sentence.index] = ordered.take(targetCount).toSet();
  }

  return result;
}

/// 将句子文本分词为单词列表
List<String> tokenize(String text) => _tokenize(text);

/// 内部分词实现
List<String> _tokenize(String text) {
  return text.split(_wordSplitPattern).where((w) => w.isNotEmpty).toList();
}

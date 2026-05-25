/// 语音完成检测器集合。
///
/// 将录音自动停止的各种检测算法拆分为独立函数，方便跟读/复述分别组合使用。
/// 每个检测器接收 [SpeechMatchContext]（LCS 匹配结果），返回 [DetectionResult]。
library;

/// LCS 匹配上下文，由调用方一次性计算后传入各检测器。
class SpeechMatchContext {
  /// 原文 token 列表（小写）
  final List<String> referenceTokens;

  /// 转录 token 列表（小写）
  final List<String> transcriptTokens;

  /// LCS 匹配对（referenceIndex, transcriptIndex）
  final List<(int, int)> lcsPairs;

  /// 匹配到的原文索引集合
  final Set<int> matchedRefIndexes;

  /// 匹配率（0-1）
  final double matchRate;

  SpeechMatchContext({
    required this.referenceTokens,
    required this.transcriptTokens,
    required this.lcsPairs,
  }) : matchedRefIndexes = lcsPairs.map((p) => p.$1).toSet(),
       matchRate = referenceTokens.isEmpty
           ? 0.0
           : lcsPairs.length / referenceTokens.length;

  /// 是否有有效匹配数据
  bool get hasMatch => lcsPairs.isNotEmpty;
}

/// 单个检测器的结果。
class DetectionResult {
  /// 建议的静音阈值（null = 该检测器未触发）
  final Duration? threshold;

  /// 人类可读的原因说明
  final String description;

  const DetectionResult({this.threshold, required this.description});

  /// 检测器是否触发（给出了阈值）
  bool get triggered => threshold != null;
}

/// 从原文和转录文本构建 [SpeechMatchContext]。
///
/// 共享的 tokenize + LCS 计算，避免各检测器重复计算。
SpeechMatchContext buildMatchContext({
  required String referenceText,
  required String partialTranscript,
}) {
  final refTokens = _tokenize(referenceText);
  final transTokens = _tokenize(partialTranscript);
  final pairs = (refTokens.isEmpty || transTokens.isEmpty)
      ? <(int, int)>[]
      : _computeLcsPairs(refTokens, transTokens);
  return SpeechMatchContext(
    referenceTokens: refTokens,
    transcriptTokens: transTokens,
    lcsPairs: pairs,
  );
}

// ========== 检测器 ==========

/// 检测 A：连续尾部匹配。
///
/// 原文末尾有 ≥[minConsecutive] 个连续词被匹配，且该尾部子序列在原文中唯一出现。
/// 触发条件说明：用户说出了原文结尾的独特片段，大概率已读完。
///
/// 默认参数与历史跟读行为一致（[minConsecutive] = 1，阈值 1s）。
/// 复述场景调用方应传 `minConsecutive: 3, triggerDuration: Duration(seconds: 3)` 收紧。
DetectionResult detectTailMatch(
  SpeechMatchContext ctx, {
  int minConsecutive = 1,
  Duration triggerDuration = const Duration(seconds: 1),
}) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'A:无匹配');
  }

  final tokens = ctx.referenceTokens;
  var consecutiveTail = 0;
  for (var i = tokens.length - 1; i >= 0; i--) {
    if (ctx.matchedRefIndexes.contains(i)) {
      consecutiveTail++;
    } else {
      break;
    }
  }

  if (consecutiveTail < minConsecutive) {
    if (consecutiveTail < 1) {
      return const DetectionResult(description: 'A:末尾未匹配');
    }
    return DetectionResult(
      description: 'A:尾部连续${consecutiveTail}词<$minConsecutive,未触发',
    );
  }

  final uniqueStart = tokens.length - consecutiveTail;
  if (!_isSubsequenceUnique(tokens, uniqueStart)) {
    return DetectionResult(description: 'A:尾部连续${consecutiveTail}词但非唯一');
  }

  return DetectionResult(
    threshold: triggerDuration,
    description:
        'A:尾部连续${consecutiveTail}词且唯一→${triggerDuration.inMilliseconds}ms',
  );
}

/// 检测 B：全句匹配率。
///
/// 默认（跟读模式）：100% → 1s, ≥95% → 2s, ≥90% → 3s，低于 90% 不触发。
///
/// 收紧模式：通过 [strictPerfectOnly] = true 启用，仅 100% 匹配才触发，阈值 [perfectDuration]。
/// 复述场景用此模式，避免 90-99% 匹配触发短阈值早停。
DetectionResult detectOverallMatchRate(
  SpeechMatchContext ctx, {
  bool strictPerfectOnly = false,
  Duration perfectDuration = const Duration(seconds: 1),
  Duration nearPerfectDuration = const Duration(seconds: 2),
  Duration highMatchDuration = const Duration(seconds: 3),
}) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'B:无匹配');
  }

  final pct = (ctx.matchRate * 100).toInt();
  if (ctx.matchRate >= 1.0) {
    return DetectionResult(
      threshold: perfectDuration,
      description: 'B:匹配率${pct}%→${perfectDuration.inMilliseconds}ms',
    );
  }
  if (strictPerfectOnly) {
    return DetectionResult(description: 'B:匹配率${pct}%<100%,严格模式不触发');
  }
  if (ctx.matchRate >= 0.95) {
    return DetectionResult(
      threshold: nearPerfectDuration,
      description: 'B:匹配率${pct}%→${nearPerfectDuration.inMilliseconds}ms',
    );
  }
  if (ctx.matchRate >= 0.90) {
    return DetectionResult(
      threshold: highMatchDuration,
      description: 'B:匹配率${pct}%→${highMatchDuration.inMilliseconds}ms',
    );
  }

  return DetectionResult(description: 'B:匹配率${pct}%<90%,未触发');
}

/// 检测 C：末尾 N 词命中数。
///
/// 检查原文最后 [tailSize] 个词中有几个被匹配，命中越多阈值越短。
/// 5命中→1s, 4→2s, 3→3s, 2→4s, ≤1→5s。
DetectionResult detectTailHitCount(SpeechMatchContext ctx, {int tailSize = 5}) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'C:无匹配');
  }

  final tokens = ctx.referenceTokens;
  final effectiveTailSize = tokens.length < tailSize ? tokens.length : tailSize;
  final tailStart = tokens.length - effectiveTailSize;

  var tailMatchCount = 0;
  for (var i = tailStart; i < tokens.length; i++) {
    if (ctx.matchedRefIndexes.contains(i)) {
      tailMatchCount++;
    }
  }

  final threshold = switch (tailMatchCount) {
    <= 1 => const Duration(seconds: 5),
    2 => const Duration(seconds: 4),
    3 => const Duration(seconds: 3),
    4 => const Duration(seconds: 2),
    _ => const Duration(seconds: 1),
  };

  return DetectionResult(
    threshold: threshold,
    description:
        'C:尾部${effectiveTailSize}词命中$tailMatchCount→${threshold.inSeconds}s',
  );
}

/// 检测 E：近完成（全句匹配率高 + 末尾覆盖到位）。
///
/// 复述场景专用：当用户已讲完原文 9 成以上内容，且原文末尾 5 词命中 ≥4 时，
/// 判定为"基本已完成复述"，高置信快速收尾。
///
/// 设计动机：覆盖 B 规则（要求 100% 全句匹配）漏掉的"差 1-2 个词没命中"场景，
/// 又比 A 规则（要求末尾连续匹配）宽容，允许 ASR 漏识别 1 个末尾词。
///
/// 触发条件：
/// - `matchRate >= minMatchRate`（默认 0.90）
/// - 原文末尾 [tailSize] 词中至少 [minTailHits] 词被匹配（默认 5 词中 ≥4 词）
///
/// 默认参数对应复述模式收紧值。函数本身保持参数化，方便其他场景调用。
DetectionResult detectNearCompletion(
  SpeechMatchContext ctx, {
  double minMatchRate = 0.90,
  int tailSize = 5,
  int minTailHits = 4,
  Duration triggerDuration = const Duration(seconds: 1),
}) {
  if (!ctx.hasMatch) {
    return const DetectionResult(description: 'E:无匹配');
  }

  final pct = (ctx.matchRate * 100).toInt();
  if (ctx.matchRate < minMatchRate) {
    final minPct = (minMatchRate * 100).toInt();
    return DetectionResult(description: 'E:匹配率${pct}%<$minPct%,未触发');
  }

  final tokens = ctx.referenceTokens;
  final effectiveTailSize = tokens.length < tailSize ? tokens.length : tailSize;
  final tailStart = tokens.length - effectiveTailSize;
  var tailMatchCount = 0;
  for (var i = tailStart; i < tokens.length; i++) {
    if (ctx.matchedRefIndexes.contains(i)) {
      tailMatchCount++;
    }
  }

  // 短句兜底：末尾词数不足 [minTailHits] 时，要求全部命中。
  final requiredHits = effectiveTailSize < minTailHits
      ? effectiveTailSize
      : minTailHits;
  if (tailMatchCount < requiredHits) {
    return DetectionResult(
      description:
          'E:末尾${effectiveTailSize}词命中$tailMatchCount<$requiredHits,未触发',
    );
  }

  return DetectionResult(
    threshold: triggerDuration,
    description:
        'E:匹配率${pct}% + 末尾$tailMatchCount/${effectiveTailSize}'
        '→${triggerDuration.inMilliseconds}ms',
  );
}

/// 检测 D：剩余词数估算阈值。
///
/// 从 transcript 末尾取 1-[maxSubstringLength] 个词，枚举所有连续子串，
/// 在 reference 中搜索唯一匹配。取最长的唯一匹配定位当前进度，
/// 根据剩余词数计算等待阈值：`baseSeconds + remaining * secondsPerWord`。
///
/// 不触发条件：transcript 为空 / 无唯一匹配 / 剩余 0 词（让规则 A 处理末尾）。
DetectionResult detectRemainingByPosition(
  SpeechMatchContext ctx, {
  int secondsPerWord = 1,
  int baseSeconds = 1,
  int maxSubstringLength = 5,
}) {
  if (ctx.transcriptTokens.isEmpty) {
    return const DetectionResult(description: 'D:transcript为空');
  }
  if (ctx.referenceTokens.isEmpty) {
    return const DetectionResult(description: 'D:reference为空');
  }

  // 从 transcript 末尾枚举长度 1..min(maxSubstringLength, transcriptLen) 的子串，
  // 优先取最长的唯一匹配。
  final transcriptLen = ctx.transcriptTokens.length;
  final maxLen = maxSubstringLength < transcriptLen
      ? maxSubstringLength
      : transcriptLen;

  int? bestMatchEndIndex;
  int bestSubLen = 0;

  for (var subLen = maxLen; subLen >= 1; subLen--) {
    final start = transcriptLen - subLen;
    final substring = ctx.transcriptTokens.sublist(start);
    final endIndex = _findUniqueSubstringEndIndex(
      ctx.referenceTokens,
      substring,
    );
    if (endIndex != null) {
      bestMatchEndIndex = endIndex;
      bestSubLen = subLen;
      break; // 最长优先，找到就停
    }
  }

  if (bestMatchEndIndex == null) {
    return const DetectionResult(description: 'D:无唯一匹配');
  }

  final remaining = ctx.referenceTokens.length - (bestMatchEndIndex + 1);
  if (remaining == 0) {
    return DetectionResult(description: 'D:匹配$bestSubLen词,剩余0词,不触发');
  }

  final seconds = baseSeconds + remaining * secondsPerWord;
  return DetectionResult(
    threshold: Duration(seconds: seconds),
    description: 'D:匹配$bestSubLen词,剩余$remaining词→${seconds}s',
  );
}

/// 在 [reference] 中搜索 [substring] 是否唯一出现。
///
/// 唯一匹配时返回匹配的结束索引（即最后一个词在 reference 中的位置），
/// 否则返回 null（0 次或 >1 次匹配）。
int? _findUniqueSubstringEndIndex(
  List<String> reference,
  List<String> substring,
) {
  final subLen = substring.length;
  if (subLen == 0 || subLen > reference.length) return null;

  int count = 0;
  int? endIndex;

  for (var i = 0; i <= reference.length - subLen; i++) {
    var match = true;
    for (var j = 0; j < subLen; j++) {
      if (reference[i + j] != substring[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      count++;
      if (count > 1) return null; // 多次出现，非唯一
      endIndex = i + subLen - 1;
    }
  }

  return count == 1 ? endIndex : null;
}

/// 组合多个检测结果，取最短阈值。
///
/// 返回 [DetectionResult]，包含最终阈值和所有检测器的汇总说明。
/// 如果没有检测器触发，返回 [fallback] 阈值。
DetectionResult combineDetections(
  List<DetectionResult> results,
  SpeechMatchContext ctx, {
  required Duration fallback,
}) {
  DetectionResult? winner;
  for (final r in results) {
    if (!r.triggered) continue;
    if (winner == null || r.threshold! < winner.threshold!) {
      winner = r;
    }
  }

  final matched = ctx.lcsPairs.length;
  final total = ctx.referenceTokens.length;
  final pct = (ctx.matchRate * 100).toInt();
  final summary = '匹配$matched/${total}词($pct%)';

  if (winner == null) {
    return DetectionResult(
      threshold: fallback,
      description: '$summary, 无规则触发→兜底${fallback.inSeconds}s',
    );
  }

  return DetectionResult(
    threshold: winner.threshold,
    description: '$summary, ${winner.description}',
  );
}

// ========== 动态兜底 ==========

/// 根据有声时长与原句时长的比例计算动态兜底阈值。
///
/// 当文本匹配规则（A/B/C/D）均未触发时，用此函数替代固定 5 秒兜底，
/// 让说得越多的用户越快停止录音。
///
/// - [matchRate]：文本匹配率（0-1），低于 0.8 时不缩短兜底。
///   传 null 表示无转录（ASR 关闭），此时仅凭有声比例计算。
/// - [speedFactor]：语速补偿系数（默认 1.3），学习者通常比原音慢，
///   实际比较基准 = referenceDuration × speedFactor。
Duration computeDynamicFallback({
  required Duration voicedDuration,
  required Duration referenceDuration,
  double? matchRate,
  double speedFactor = 1.1,
  Duration defaultFallback = const Duration(seconds: 5),
}) {
  if (referenceDuration <= Duration.zero) return defaultFallback;
  if (matchRate != null && matchRate < 0.8) return defaultFallback;

  final adjustedMs = referenceDuration.inMilliseconds * speedFactor;
  final ratio = voicedDuration.inMilliseconds / adjustedMs;

  if (ratio >= 0.95) return const Duration(seconds: 1);
  if (ratio >= 0.90) return const Duration(seconds: 2);
  if (ratio >= 0.85) return const Duration(seconds: 3);
  if (ratio >= 0.80) return const Duration(seconds: 4);
  if (ratio >= 0.75) return const Duration(seconds: 5);
  return defaultFallback;
}

// ========== 复述专用动态兜底 ==========

/// 根据有声时长与原句时长的比例计算复述场景的动态兜底阈值。
///
/// 与 [computeDynamicFallback] 类似，但阈值更长，适配复述场景：
/// 用户需要回忆内容，停顿更长属于正常行为。
///
/// 语速补偿系数根据段落时长动态调整：
/// - ≤3s → 1.0（短句无需补偿）
/// - ≤10s → 1.1
/// - ≤20s → 1.2
/// - >20s → 1.3（长段落需要更多回忆时间）
///
/// [matchRate]：文本匹配率（0-1），低于 0.8 时不缩短兜底。
/// 传 null 表示无转录（ASR 关闭），此时仅凭有声比例计算。
///
/// 收紧版（2026-05-18）：上限 20s→30s，各档阈值翻倍，下限 1s→5s。
/// 旧算法以注释保留在函数尾部，方便对比/回滚。
Duration computeRetellDynamicFallback({
  required Duration voicedDuration,
  required Duration referenceDuration,
  double? matchRate,
}) {
  // 动态上限：clamp(referenceDuration, 5s, 30s)
  // [旧算法-2026-05-18] 旧上限：clamp(refDur, 5s, 20s)
  final capMs = referenceDuration.inMilliseconds.clamp(5000, 30000);
  final scale = capMs / 30000; // 缩放因子，各阈值按 cap/30s 等比缩放

  if (referenceDuration <= Duration.zero) return Duration(milliseconds: capMs);
  if (matchRate != null && matchRate < 0.8)
    return Duration(milliseconds: capMs);

  final refSec = referenceDuration.inMilliseconds / 1000.0;
  final speedFactor = refSec <= 3
      ? 1.0
      : refSec <= 10
      ? 1.1
      : refSec <= 20
      ? 1.2
      : 1.3;
  final adjustedMs = referenceDuration.inMilliseconds * speedFactor;
  final ratio = voicedDuration.inMilliseconds / adjustedMs;

  // 基准阈值（scale=1.0 即 ref≥30s 时）：6/12/cap/cap/cap，下限 5s
  final int ms;
  if (ratio >= 0.95) {
    ms = (6000 * scale).round();
  } else if (ratio >= 0.90) {
    ms = (12000 * scale).round();
  } else if (ratio >= 0.85) {
    ms = capMs;
  } else if (ratio >= 0.80) {
    ms = capMs;
  } else if (ratio >= 0.75) {
    ms = capMs;
  } else {
    return Duration(milliseconds: capMs);
  }

  // 收紧后下限：5s
  // [旧算法-2026-05-18] 原下限：1s
  return Duration(milliseconds: ms < 5000 ? 5000 : ms);

  // [旧算法-2026-05-18] 原档位（cap=20s, scale=capMs/20000）：
  // ratio >= 0.95 → 3000 * scale
  // ratio >= 0.90 → 6000 * scale
  // ratio >= 0.85 → 10000 * scale
  // ratio >= 0.80 → 15000 * scale
  // ratio >= 0.75 → cap
  // 其他          → cap
  // 下限 1000ms
}

// ========== 内部工具函数 ==========

final RegExp _englishWordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

List<String> _tokenize(String text) {
  return _englishWordPattern
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0) ?? '')
      .where((token) => token.isNotEmpty)
      .toList();
}

/// 检查 [tokens] 从 [start] 到末尾的连续子序列在 [tokens] 中是否只出现一次。
bool _isSubsequenceUnique(List<String> tokens, int start) {
  final tail = tokens.sublist(start);
  final tailLength = tail.length;
  var count = 0;
  for (var i = 0; i <= tokens.length - tailLength; i++) {
    var match = true;
    for (var j = 0; j < tailLength; j++) {
      if (tokens[i + j] != tail[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      count++;
      if (count > 1) return false;
    }
  }
  return count == 1;
}

List<(int, int)> _computeLcsPairs(
  List<String> referenceTokens,
  List<String> transcriptTokens,
) {
  final rows = referenceTokens.length + 1;
  final cols = transcriptTokens.length + 1;
  final dp = List.generate(rows, (_) => List.filled(cols, 0));

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  final pairs = <(int, int)>[];
  var i = referenceTokens.length;
  var j = transcriptTokens.length;
  while (i > 0 && j > 0) {
    if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
      pairs.add((i - 1, j - 1));
      i -= 1;
      j -= 1;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      i -= 1;
    } else {
      j -= 1;
    }
  }
  return pairs.reversed.toList();
}

/// 段落分组算法
///
/// 两步走：
/// 1. **硬切**：句间静音 ≥ `targetDuration / 2` 处强制断段——尊重原音频的段落结构
///    （考试音频通常用大段静音分隔不同题目段，分组不应跨越这些边界）。
/// 2. **块内 DP**：每个硬切后的 chunk 独立跑 DP，按目标时长分组，
///    最小化各段时长与目标时长偏差的平方和。句子数超过
///    [kWindowedDpSentenceThreshold] 时启用**窗口化**：段长不超过
///    [kWindowMultiplier] × 目标时长的起点才参与枚举，把长音频的 DP 从
///    O(k·n²) 降到 O(k·n·w)（w 为窗口内句子数）。
///
/// 段落"时长"用**墙上时钟**（`last.endTime - first.startTime`），与用户实际听到的
/// 时长一致。硬切剔除超大空白，剩余 chunk 内的小空白计入 DP cost，
/// 避免 DP 因"说话时长之和"看似接近 target 而漏切。
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/sentence.dart';

/// 句子数超过该值时 DP 启用窗口化（小于等于时走全局 DP，结果最精确）
const int kWindowedDpSentenceThreshold = 50;

/// 窗口上限倍数：单段时长上限 = 本倍数 × 目标时长
const int kWindowMultiplier = 3;

/// 将句子列表按目标时长分组为段落
///
/// [sentences] 句子列表（按时间顺序）
/// [targetDuration] 用户选择的目标段落时长（如 30s）
/// [windowedDpThreshold] 句子数超过该值时使用窗口化 DP，默认 [kWindowedDpSentenceThreshold]
///
/// 返回分组后的段落列表，每个段落包含连续的句子。
List<List<Sentence>> groupSentencesIntoParagraphs(
  List<Sentence> sentences,
  Duration targetDuration, {
  int windowedDpThreshold = kWindowedDpSentenceThreshold,
}) {
  // 边界：空列表
  if (sentences.isEmpty) return [];

  // 边界：单句
  if (sentences.length == 1) return [sentences];

  // 句子级别：每句一段（targetDuration == 0）
  if (targetDuration <= Duration.zero) {
    return sentences.map((s) => [s]).toList();
  }

  // Step A：在大空白处硬切，得到若干 chunk
  final chunks = _splitOnLongSilence(sentences, targetDuration);

  // Step B：每个 chunk 独立跑 DP；句子数超过阈值时启用窗口化
  final useWindow = sentences.length > windowedDpThreshold;
  final result = <List<Sentence>>[];
  for (final chunk in chunks) {
    result.addAll(_dpSegment(chunk, targetDuration, useWindow: useWindow));
  }
  return result;
}

/// 在句间静音 ≥ targetDuration/2 处硬切
///
/// 返回若干 chunk，每个 chunk 内的句间空白都 < targetDuration/2。
/// 句子重叠（gap < 0）视为不切，由 DP 处理。
List<List<Sentence>> _splitOnLongSilence(
  List<Sentence> sentences,
  Duration targetDuration,
) {
  final hardCutMs = targetDuration.inMilliseconds ~/ 2;
  final chunks = <List<Sentence>>[];
  var current = <Sentence>[sentences.first];

  for (var i = 1; i < sentences.length; i++) {
    final gapMs =
        sentences[i].startTime.inMilliseconds -
        sentences[i - 1].endTime.inMilliseconds;
    if (gapMs >= hardCutMs) {
      chunks.add(current);
      current = <Sentence>[sentences[i]];
    } else {
      current.add(sentences[i]);
    }
  }
  chunks.add(current);
  return chunks;
}

/// 计算每个句尾位置允许的最小起点（窗口下界）
///
/// 返回 `lower`，`lower[i]` 表示以第 `i-1` 句结尾的段，起点最早只能取到 `lower[i]`。
/// 段长超过 [windowMs] 的起点被排除；单句段始终允许（`lower[i] <= i-1`），
/// 保证超长单句也能独立成段，DP 必有可行解。
@visibleForTesting
List<int> windowLowerBounds(List<Sentence> sentences, int windowMs) {
  final n = sentences.length;
  final lower = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= n; i++) {
    var c = i - 1;
    // 起点左移一句后若段长仍在窗口内，继续左移
    while (c > 0 &&
        sentences[i - 1].endTime.inMilliseconds -
                sentences[c - 1].startTime.inMilliseconds <=
            windowMs) {
      c--;
    }
    lower[i] = c;
  }
  return lower;
}

/// chunk 内 DP 分段
///
/// 全局版复杂度 O(k · n²)；窗口版（[useWindow]）每个句尾只枚举窗口内的起点，
/// 复杂度 O(k · n · w)，w 为窗口内句子数。
/// cost = (rangeMs - targetMs)²，rangeMs 用**墙上时钟**（含句间空白），
/// 让分段贴近用户实际听到的段落时长——硬切已剔除超大空白，剩余 chunk 内
/// 的小空白此处计入 cost，避免 DP 因"说话时长之和"看似接近 target 而漏切。
List<List<Sentence>> _dpSegment(
  List<Sentence> sentences,
  Duration targetDuration, {
  required bool useWindow,
}) {
  // chunk 内边界：单句直接成段
  if (sentences.length == 1) return [sentences];

  final n = sentences.length;
  final targetMs = targetDuration.inMilliseconds;

  // 区间墙上时钟（句子索引 l..r，含两端）= sentences[r].endTime - sentences[l].startTime
  int rangeMs(int l, int r) =>
      sentences[r].endTime.inMilliseconds -
      sentences[l].startTime.inMilliseconds;

  final totalMs = rangeMs(0, n - 1);

  // 边界：总墙上时长 ≤ 目标时长 → 单段
  // （也覆盖 totalMs ≤ 0 的异常数据：句子时间戳重叠/逆序时安全降级）
  if (totalMs <= targetMs) return [sentences];

  // 各句尾的起点下界：全局版为 0（不限制），窗口版按段长上限收紧
  final lower = useWindow
      ? windowLowerBounds(sentences, kWindowMultiplier * targetMs)
      : List<int>.filled(n + 1, 0);

  // 区间代价：偏差平方
  double cost(int l, int r) {
    final diff = rangeMs(l, r) - targetMs;
    return diff.toDouble() * diff.toDouble();
  }

  // 估算最优组数
  final kEstimate = (totalMs / targetMs).round().clamp(1, n);
  final kMin = (kEstimate - 2).clamp(1, n);
  final kMax = (kEstimate + 2).clamp(1, n);

  double bestTotalCost = double.infinity;
  int bestK = kEstimate;
  List<List<int>>? bestCut;

  // 对每个候选 k 值执行 DP
  for (var k = kMin; k <= kMax; k++) {
    // dp[i][j] = 前 i 句分成 j 组的最小代价
    // i: 0..n, j: 0..k
    final dp = List.generate(
      n + 1,
      (_) => List<double>.filled(k + 1, double.infinity),
    );
    final cut = List.generate(n + 1, (_) => List<int>.filled(k + 1, 0));

    dp[0][0] = 0;

    for (var j = 1; j <= k; j++) {
      for (var i = j; i <= n; i++) {
        // 从 c 处切割：前 c 句分成 j-1 组，第 j 组为 [c, i-1]
        // 起点不早于 j-1（前面至少要有 j-1 句），且不早于窗口下界
        final from = lower[i] > j - 1 ? lower[i] : j - 1;
        for (var c = from; c < i; c++) {
          final val = dp[c][j - 1] + cost(c, i - 1);
          if (val < dp[i][j]) {
            dp[i][j] = val;
            cut[i][j] = c;
          }
        }
      }
    }

    if (dp[n][k] < bestTotalCost) {
      bestTotalCost = dp[n][k];
      bestK = k;
      bestCut = cut;
    }
  }

  // 防御：理论上 k=1 必然让 dp[n][1] 有限（cost(0, n-1) 总是有限），
  // 但若 DP 异常未填值，安全降级为单段，避免空指针崩溃。
  if (bestCut == null) return [sentences];

  // 回溯得到分组
  final groups = <List<Sentence>>[];
  var end = n;
  var remaining = bestK;

  while (remaining > 0) {
    final start = bestCut[end][remaining];
    groups.add(sentences.sublist(start, end));
    end = start;
    remaining--;
  }

  // 回溯是逆序的，翻转
  return groups.reversed.toList();
}

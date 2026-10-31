/// 段落分组算法
///
/// 两步走：
/// 1. **硬切**：句间静音 ≥ `targetDuration / 2` 处强制断段——尊重原音频的段落结构
///    （考试音频通常用大段静音分隔不同题目段，分组不应跨越这些边界）。
/// 2. **块内 DP**：每个硬切后的 chunk 独立跑单趟 DP，按目标时长分组，
///    最小化各段时长与目标时长偏差的平方和（段数由 DP 自行决定，不预设）。
///    句子数超过 [kWindowedDpSentenceThreshold] 时启用**窗口化**：段长不超过
///    [kWindowMultiplier] × 目标时长的起点才参与枚举，复杂度降为 O(n·w)
///    （w 为窗口内句子数）；否则为全局 O(n²)。
///
/// 段落"时长"用**墙上时钟**（`last.endTime - first.startTime`），与用户实际听到的
/// 时长一致。硬切剔除超大空白，剩余 chunk 内的小空白计入 DP cost，
/// 避免 DP 因"说话时长之和"看似接近 target 而漏切。
library;

import 'dart:typed_data';

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

/// 按目标时长（秒）切段，统一 -1 / 0 / 正数三种语义
///
/// - `-1`：不分段，整篇作为一段
/// - `0`：逐句一段
/// - `>0`：按 [groupSentencesIntoParagraphs] 分组
List<List<Sentence>> splitIntoParagraphsForTarget(
  List<Sentence> sentences,
  int targetSeconds,
) {
  if (targetSeconds < 0) return [sentences];
  if (targetSeconds == 0) return sentences.map((s) => [s]).toList();
  return groupSentencesIntoParagraphs(
    sentences,
    Duration(seconds: targetSeconds),
  );
}

/// 生成分段结果的诊断摘要，供日志排查使用
///
/// 输出段数、时长明显偏短（小于目标一半）的段数、最小/平均/最大段时长，
/// 以及逐段时长列表（秒，保留 1 位小数）。[targetDuration] 不大于 0 时不统计偏短段。
String summarizeParagraphDurations(
  List<List<Sentence>> paragraphs,
  Duration targetDuration,
) {
  final targetMs = targetDuration.inMilliseconds;
  final durationsMs = [
    for (final p in paragraphs)
      if (p.isNotEmpty)
        p.last.endTime.inMilliseconds - p.first.startTime.inMilliseconds,
  ];
  if (durationsMs.isEmpty) return 'paragraphs=0';

  final shortCount = targetMs > 0
      ? durationsMs.where((d) => d < targetMs / 2).length
      : 0;
  final total = durationsMs.fold<int>(0, (sum, d) => sum + d);
  final minMs = durationsMs.reduce((a, b) => a < b ? a : b);
  final maxMs = durationsMs.reduce((a, b) => a > b ? a : b);
  final seconds = durationsMs.map((d) => (d / 1000).toStringAsFixed(1));

  return 'target=${(targetMs / 1000).toStringAsFixed(1)}s '
      'paragraphs=${durationsMs.length} shortCount=$shortCount '
      'min=${(minMs / 1000).toStringAsFixed(1)}s '
      'avg=${(total / durationsMs.length / 1000).toStringAsFixed(1)}s '
      'max=${(maxMs / 1000).toStringAsFixed(1)}s '
      'durations=[${seconds.join(',')}]';
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

/// chunk 内单趟 DP 分段（段数不预设）
///
/// 设 `best[i]` 为前 i 句的最小代价，则
/// `best[i] = min_c ( best[c] + (rangeMs(c, i-1) - targetMs)² )`，
/// 逐个 i 递推即得全局最优，无需枚举段数 k。
/// 窗口版（[useWindow]）只枚举 `lower[i]` 起的起点，复杂度 O(n · w)；
/// 全局版复杂度 O(n²)，句子数已由调用方限制在阈值以内。
/// cost 用**墙上时钟**（含句间空白），与用户实际听到的段长一致。
List<List<Sentence>> _dpSegment(
  List<Sentence> sentences,
  Duration targetDuration, {
  required bool useWindow,
}) {
  // chunk 内边界：单句直接成段
  if (sentences.length == 1) return [sentences];

  final n = sentences.length;
  final targetMs = targetDuration.inMilliseconds;
  // 预先取出毫秒时间戳，内层循环不反复访问 Duration 的 getter
  final startMs = Int64List.fromList([
    for (final s in sentences) s.startTime.inMilliseconds,
  ]);
  final endMs = Int64List.fromList([
    for (final s in sentences) s.endTime.inMilliseconds,
  ]);

  // 边界：总墙上时长 ≤ 目标时长 → 单段
  // （也覆盖时间戳重叠/逆序的异常数据，安全降级）
  if (endMs[n - 1] - startMs[0] <= targetMs) return [sentences];

  final lower = useWindow
      ? windowLowerBounds(sentences, kWindowMultiplier * targetMs)
      : null;

  // best[i]：前 i 句的最小代价；prev[i]：最后一段的起点
  final best = Float64List(n + 1);
  final prev = Int32List(n + 1);
  for (var i = 1; i <= n; i++) {
    final from = lower == null ? 0 : lower[i];
    var bestCost = double.infinity;
    var bestStart = i - 1;
    for (var c = from; c < i; c++) {
      final diff = (endMs[i - 1] - startMs[c] - targetMs).toDouble();
      final cost = best[c] + diff * diff;
      if (cost < bestCost) {
        bestCost = cost;
        bestStart = c;
      }
    }
    // from ≤ i-1 恒成立，单句段始终可选，因此 bestCost 必为有限值
    best[i] = bestCost;
    prev[i] = bestStart;
  }

  // 从末尾沿 prev 回溯出各段，再翻转为时间顺序
  final groups = <List<Sentence>>[];
  var end = n;
  while (end > 0) {
    final start = prev[end];
    groups.add(sentences.sublist(start, end));
    end = start;
  }
  return groups.reversed.toList();
}

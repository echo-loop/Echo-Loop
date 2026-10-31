/// 段落复述会话总时长估算
///
/// 用于在复述 briefing sheet 上向用户预估"按当前段落时长 + 停顿设置完成一遍练习要花多久"。
/// 公式与 RetellPlayer 实际播放/停顿行为保持一致，避免出现"音频 10 分钟、字幕只占 3 分钟、
/// 预估却显示 30 分钟"这种被音频空白部分污染的结果。
library;

import '../models/intensive_listen_settings.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import 'paragraph_grouping.dart';

/// 估算段落复述会话总时长（基于真实播放+停顿公式）。
///
/// 计算逻辑与 [RetellSettings.calculatePauseDuration] 和 RetellPlayer 实际行为一致：
///
/// 1. 用 [groupSentencesIntoParagraphs] 按 [targetSeconds] 分段：
///    - `-1` → 全文一段（不分段）
///    - `0`  → 逐句一段
///    - `>0` → DP 分段
/// 2. 对每段：
///    - `paragraphDur = last.endTime - first.startTime`（wall-clock，与播放器实际播放时间一致）
///    - `pauseDur = RetellSettings(...).calculatePauseDuration(paragraphDur, score: null)`
///      - smart 模式按"无评分"基线 ×2 + 2s（clamp 3s..60s）
///      - multiplier 模式按 [pauseMultiplier]（clamp ≥ 3s）
/// 3. `total = Σ(paragraphDur + pauseDur) × repeatCount`
///
/// [pauseMultiplier]：`-1.0` = smart 模式；`>0` = multiplier 模式倍数。
/// [repeatCount]：每段重复次数（默认 1）。
///
/// 空字幕返回 [Duration.zero]。
Duration estimateRetellSessionDuration({
  required List<Sentence> sentences,
  required int targetSeconds,
  required double pauseMultiplier,
  int repeatCount = 1,
}) {
  if (sentences.isEmpty) return Duration.zero;
  return estimateRetellParagraphsDuration(
    paragraphs: splitIntoParagraphsForTarget(sentences, targetSeconds),
    pauseMultiplier: pauseMultiplier,
    repeatCount: repeatCount,
  );
}

/// 基于已分段结果估算复述会话总时长（公式同 [estimateRetellSessionDuration]）。
///
/// 调用方已持有分段结果时直接传入，避免重复分组（分组是 O(n·w·k) 的 DP）。
Duration estimateRetellParagraphsDuration({
  required List<List<Sentence>> paragraphs,
  required double pauseMultiplier,
  int repeatCount = 1,
}) {
  final settings = pauseMultiplier < 0
      ? const RetellSettings(pauseMode: PauseMode.smart)
      : RetellSettings(
          pauseMode: PauseMode.multiplier,
          pauseMultiplier: pauseMultiplier,
        );

  var total = Duration.zero;
  for (final p in paragraphs) {
    if (p.isEmpty) continue;
    final paragraphDur = p.last.endTime - p.first.startTime;
    final pause = settings.calculatePauseDuration(paragraphDur);
    total += (paragraphDur + pause) * repeatCount;
  }
  return total;
}

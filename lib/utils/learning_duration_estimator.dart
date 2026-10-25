/// 学习任务入口使用的快速预计时长计算。
library;

/// 估算逐句精听的听句和停顿总时长。
///
/// [repeatCount] 为 0 表示无限循环，此时返回 null 表示无法给出有限估时。
Duration? estimateIntensiveListenDuration({
  required Duration sentenceDuration,
  required int repeatCount,
}) {
  if (sentenceDuration == Duration.zero || repeatCount == 0) return null;
  return sentenceDuration * repeatCount * 2;
}

/// 估算难句补练的盲听和跟读总时长。
///
/// 任一练习阶段设为 0 遍（无限循环）时，返回 null。
Duration? estimateDifficultPracticeDuration({
  required Duration difficultSentenceDuration,
  required int blindListenRepeatCount,
  required int shadowReadingRepeatCount,
}) {
  if (difficultSentenceDuration == Duration.zero ||
      blindListenRepeatCount == 0 ||
      shadowReadingRepeatCount == 0) {
    return null;
  }
  return difficultSentenceDuration *
      (blindListenRepeatCount + shadowReadingRepeatCount);
}

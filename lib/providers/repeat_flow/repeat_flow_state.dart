/// 跟读流程状态（不可变数据类）
///
/// 由 [RepeatFlowEngine] 管理，通过 [onStateChanged] 通知外部。
/// 各页面的 Controller/Provider 可包装此状态或直接暴露给 UI。
library;

import 'repeat_flow_phase.dart';

/// 跟读流程状态
class RepeatFlowState {
  /// 当前阶段
  final RepeatFlowPhase phase;

  /// 当前句子索引（0-based）
  final int sentenceIndex;

  /// 句子总数
  final int totalSentences;

  /// 当前遍次（0-based）
  final int repeatIndex;

  /// 总遍数
  final int totalRepeats;

  /// 遍间倒计时总时长（配置值）
  final Duration intervalDuration;

  /// 录音文件路径
  final String? recordingPath;

  /// 录音评分
  final double? recordingScore;

  /// 流程令牌（异步回调校验用）
  final int flowToken;

  const RepeatFlowState({
    this.phase = const Idle(),
    this.sentenceIndex = 0,
    this.totalSentences = 0,
    this.repeatIndex = 0,
    this.totalRepeats = 1,
    this.intervalDuration = Duration.zero,
    this.recordingPath,
    this.recordingScore,
    this.flowToken = 0,
  });

  RepeatFlowState copyWith({
    RepeatFlowPhase? phase,
    int? sentenceIndex,
    int? totalSentences,
    int? repeatIndex,
    int? totalRepeats,
    Duration? intervalDuration,
    Object? recordingPath = _noChange,
    Object? recordingScore = _noChange,
    int? flowToken,
  }) {
    return RepeatFlowState(
      phase: phase ?? this.phase,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      repeatIndex: repeatIndex ?? this.repeatIndex,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      intervalDuration: intervalDuration ?? this.intervalDuration,
      recordingPath: identical(recordingPath, _noChange)
          ? this.recordingPath
          : recordingPath as String?,
      recordingScore: identical(recordingScore, _noChange)
          ? this.recordingScore
          : recordingScore as double?,
      flowToken: flowToken ?? this.flowToken,
    );
  }

  // ========== 便捷 getter ==========

  /// 是否为最后一句
  bool get isLastSentence => sentenceIndex >= totalSentences - 1;

  /// 是否为第一句
  bool get isFirstSentence => sentenceIndex <= 0;

  /// 是否为最后一遍
  bool get isLastRepeat => repeatIndex >= totalRepeats - 1;

  /// 是否在倒计时中
  bool get isCountingDown => phase is WaitingInterval;

  /// 是否在等待用户操作
  bool get isWaitingForUser => phase is WaitingForUser;

  /// 是否处于停顿状态（包含 Recording：播放已结束，等待用户操作或录音完成）
  bool get isInPause =>
      phase is WaitingInterval || phase is WaitingForUser || phase is Recording;

  /// 是否已完成
  bool get isCompleted =>
      phase is SentenceCompleted || phase is SessionCompleted;
}

const _noChange = Object();

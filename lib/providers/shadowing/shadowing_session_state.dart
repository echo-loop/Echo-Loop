/// 跟读会话状态（不可变）
///
/// UI 只读这一个状态对象，Controller 是唯一写入者。
/// 包含所有 UI 渲染需要的信息，不包含业务逻辑。
library;

import 'shadowing_phase.dart';

/// 跟读会话状态
class ShadowingSessionState {
  /// 当前阶段
  final ShadowingPhase phase;

  /// 当前句子索引（0-based）
  final int sentenceIndex;

  /// 句子总数
  final int totalSentences;

  /// 当前遍数（0-based，"第 repeatIndex+1 遍"）
  final int repeatIndex;

  /// 总遍数
  final int totalRepeats;

  /// 遍间倒计时总时长
  final Duration intervalTotal;

  /// 遍间倒计时剩余时间（仅 WaitingInterval 阶段有意义）
  final Duration intervalRemaining;

  /// 倒计时是否暂停（用户点击倒计时圆环暂停）
  final bool isIntervalPaused;

  /// 最新录音文件路径（null = 本遍未录音）
  final String? recordingPath;

  /// 最新录音评分（null = 未评估）
  final double? recordingScore;

  /// 流程令牌（每次切句/重置递增，异步回调校验用）
  final int flowToken;

  const ShadowingSessionState({
    this.phase = const Idle(),
    this.sentenceIndex = 0,
    this.totalSentences = 0,
    this.repeatIndex = 0,
    this.totalRepeats = 3,
    this.intervalTotal = Duration.zero,
    this.intervalRemaining = Duration.zero,
    this.isIntervalPaused = false,
    this.recordingPath,
    this.recordingScore,
    this.flowToken = 0,
  });

  ShadowingSessionState copyWith({
    ShadowingPhase? phase,
    int? sentenceIndex,
    int? totalSentences,
    int? repeatIndex,
    int? totalRepeats,
    Duration? intervalTotal,
    Duration? intervalRemaining,
    bool? isIntervalPaused,
    Object? recordingPath = _noChange,
    Object? recordingScore = _noChange,
    int? flowToken,
  }) {
    return ShadowingSessionState(
      phase: phase ?? this.phase,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      repeatIndex: repeatIndex ?? this.repeatIndex,
      totalRepeats: totalRepeats ?? this.totalRepeats,
      intervalTotal: intervalTotal ?? this.intervalTotal,
      intervalRemaining: intervalRemaining ?? this.intervalRemaining,
      isIntervalPaused: isIntervalPaused ?? this.isIntervalPaused,
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

  /// 是否已完成
  bool get isCompleted =>
      phase is SentenceCompleted || phase is SessionCompleted;
}

const _noChange = Object();

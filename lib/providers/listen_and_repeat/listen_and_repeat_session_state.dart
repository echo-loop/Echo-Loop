/// 跟读会话状态
///
/// 包装 [RepeatFlowState] 并添加跟读页面专属字段。
library;

import '../repeat_flow/repeat_flow_phase.dart';
import '../repeat_flow/repeat_flow_state.dart';

export '../repeat_flow/repeat_flow_state.dart' show RepeatFlowState;

/// 跟读会话状态
///
/// 继承 [RepeatFlowState] 的所有字段，额外添加 [isFreePlay]。
class ListenAndRepeatSessionState extends RepeatFlowState {
  /// 是否为自由练习模式
  final bool isFreePlay;

  /// 当前句是否仍被标记为难句
  final bool currentSentenceBookmarked;

  /// 当前媒体是否为视频；播放始终由共享 MediaEngine 提供。
  final bool hasVideo;

  const ListenAndRepeatSessionState({
    super.sessionId,
    super.phase,
    super.sentenceIndex,
    super.totalSentences,
    super.repeatIndex,
    super.totalRepeats,
    super.intervalDuration,
    super.recordingPath,
    super.recordingScore,
    super.isReviewPlaybackActive,
    super.flowToken,
    super.controlMode,
    super.postRecordingAction,
    super.isTransitioning,
    this.isFreePlay = false,
    this.currentSentenceBookmarked = false,
    this.hasVideo = false,
  });

  /// 从 [RepeatFlowState] 和 [isFreePlay] 构建
  factory ListenAndRepeatSessionState.fromFlowState(
    RepeatFlowState flow, {
    bool isFreePlay = false,
    bool currentSentenceBookmarked = false,
    bool hasVideo = false,
  }) {
    return ListenAndRepeatSessionState(
      sessionId: flow.sessionId,
      phase: flow.phase,
      sentenceIndex: flow.sentenceIndex,
      totalSentences: flow.totalSentences,
      repeatIndex: flow.repeatIndex,
      totalRepeats: flow.totalRepeats,
      intervalDuration: flow.intervalDuration,
      recordingPath: flow.recordingPath,
      recordingScore: flow.recordingScore,
      isReviewPlaybackActive: flow.isReviewPlaybackActive,
      flowToken: flow.flowToken,
      controlMode: flow.controlMode,
      postRecordingAction: flow.postRecordingAction,
      isTransitioning: flow.isTransitioning,
      isFreePlay: isFreePlay,
      currentSentenceBookmarked: currentSentenceBookmarked,
      hasVideo: hasVideo,
    );
  }

  @override
  ListenAndRepeatSessionState copyWith({
    int? sessionId,
    RepeatFlowPhase? phase,
    int? sentenceIndex,
    int? totalSentences,
    int? repeatIndex,
    int? totalRepeats,
    Duration? intervalDuration,
    Object? recordingPath = _noChange,
    Object? recordingScore = _noChange,
    bool? isReviewPlaybackActive,
    int? flowToken,
    RepeatControlMode? controlMode,
    RepeatPostRecordingAction? postRecordingAction,
    bool? isTransitioning,
    bool? isFreePlay,
    bool? currentSentenceBookmarked,
    bool? hasVideo,
  }) {
    return ListenAndRepeatSessionState(
      sessionId: sessionId ?? this.sessionId,
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
      isReviewPlaybackActive:
          isReviewPlaybackActive ?? this.isReviewPlaybackActive,
      flowToken: flowToken ?? this.flowToken,
      controlMode: controlMode ?? this.controlMode,
      postRecordingAction: postRecordingAction ?? this.postRecordingAction,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      isFreePlay: isFreePlay ?? this.isFreePlay,
      currentSentenceBookmarked:
          currentSentenceBookmarked ?? this.currentSentenceBookmarked,
      hasVideo: hasVideo ?? this.hasVideo,
    );
  }
}

const _noChange = Object();

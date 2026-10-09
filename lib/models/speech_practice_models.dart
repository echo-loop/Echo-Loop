/// 跟读录音练习的数据模型。
library;

/// 权限状态。
enum SpeechPracticePermissionStatus {
  /// 尚未请求。
  notDetermined,

  /// 已授权。
  granted,

  /// 用户拒绝。
  denied,

  /// 系统限制。
  restricted,
}

/// 录音识别结果状态。
enum SpeechPracticeAttemptStatus {
  /// 初始空状态。
  idle,

  /// 正在录音。
  recording,

  /// 已停止录音，正在等待 final transcript。
  awaitingFinal,

  /// 匹配通过。
  passed,

  /// 有英文识别结果，但不足 50%。
  belowThreshold,

  /// 未检测到英语。
  noEnglishDetected,

  /// 权限被拒绝。
  permissionDenied,

  /// 平台能力不可用。
  unavailable,

  /// 其他错误。
  error,
}

extension SpeechPracticeAttemptStatusX on SpeechPracticeAttemptStatus {
  /// 是否属于“识别失败”。
  ///
  /// 识别失败才允许回退到「录音」badge；评估成功但 transcript 为空时，
  /// 仍然应显示评级 badge。
  bool get isRecognitionFailure =>
      this == SpeechPracticeAttemptStatus.noEnglishDetected ||
      this == SpeechPracticeAttemptStatus.permissionDenied ||
      this == SpeechPracticeAttemptStatus.unavailable ||
      this == SpeechPracticeAttemptStatus.error;
}

/// 原生事件类型。
enum SpeechPracticeEventType {
  /// 录音中的中间转录。
  partialTranscriptUpdated,

  /// 检测到用户开始说话。
  speechStarted,

  /// 用户开口后的连续静音时长更新。
  silenceProgress,

  /// 最终转录完成。
  finalTranscriptReady,

  /// 原生录音/识别错误。
  error,
}

/// 权限快照。
class SpeechPracticePermissionState {
  /// 麦克风权限。
  final SpeechPracticePermissionStatus microphone;

  /// 语音识别权限。
  final SpeechPracticePermissionStatus speech;

  const SpeechPracticePermissionState({
    this.microphone = SpeechPracticePermissionStatus.notDetermined,
    this.speech = SpeechPracticePermissionStatus.notDetermined,
  });

  /// 两项权限都已授权。
  bool get isGranted =>
      microphone == SpeechPracticePermissionStatus.granted &&
      speech == SpeechPracticePermissionStatus.granted;

  SpeechPracticePermissionState copyWith({
    SpeechPracticePermissionStatus? microphone,
    SpeechPracticePermissionStatus? speech,
  }) {
    return SpeechPracticePermissionState(
      microphone: microphone ?? this.microphone,
      speech: speech ?? this.speech,
    );
  }
}

/// 转录文本片段。
class SpeechTranscriptSegment {
  /// 原始显示文本。
  final String text;

  /// 当前片段是否命中目标词。
  final bool isMatched;

  const SpeechTranscriptSegment({required this.text, required this.isMatched});
}

/// 原生识别事件。
class SpeechPracticeEvent {
  /// 事件类型。
  final SpeechPracticeEventType type;

  /// 当前句子的业务标识。
  final String promptId;

  /// 事件转录文本。
  final String? transcript;

  /// 错误码。
  final String? errorCode;

  /// 错误消息。
  final String? errorMessage;

  /// 开口后的连续静音时长。
  final Duration? silenceDuration;

  const SpeechPracticeEvent({
    required this.type,
    required this.promptId,
    this.transcript,
    this.errorCode,
    this.errorMessage,
    this.silenceDuration,
  });
}

/// 停止录音后的返回值。
class SpeechPracticeStopResult {
  /// 临时录音文件路径。
  final String? filePath;

  /// 原生录音诊断摘要；不包含录音内容。
  final String? diagnostics;

  const SpeechPracticeStopResult({this.filePath, this.diagnostics});
}

/// 文本比对结果。
class SpeechMatchResult {
  /// 结果状态。
  final SpeechPracticeAttemptStatus status;

  /// 最终识别文本。
  final String finalTranscript;

  /// 匹配分值，范围 0~1。
  final double score;

  /// 命中的目标 token 数。
  final int matchedTokenCount;

  /// 目标 token 总数。
  final int totalTargetTokenCount;

  /// 识别出的英文 token 数。
  final int recognizedEnglishTokenCount;

  /// Transcript 富文本高亮片段。
  final List<SpeechTranscriptSegment> transcriptSegments;

  /// 原文富文本高亮片段。
  final List<SpeechTranscriptSegment> referenceSegments;

  const SpeechMatchResult({
    required this.status,
    required this.finalTranscript,
    required this.score,
    required this.matchedTokenCount,
    required this.totalTargetTokenCount,
    required this.recognizedEnglishTokenCount,
    required this.transcriptSegments,
    required this.referenceSegments,
  });
}

/// 单句录音尝试。
class SpeechPracticeAttempt {
  /// 当前句子的业务标识。
  final String promptId;

  /// 临时录音文件路径。
  final String? filePath;

  /// 当前状态。
  final SpeechPracticeAttemptStatus status;

  /// 录音中的中间转录。
  final String? liveTranscript;

  /// 最终转录。
  final String? finalTranscript;

  /// 最终匹配分值，范围 0~1。
  final double? score;

  /// 命中的目标 token 数。
  final int matchedTokenCount;

  /// 目标 token 总数。
  final int totalTargetTokenCount;

  /// 最终转录高亮片段。
  final List<SpeechTranscriptSegment> transcriptSegments;

  /// 原文高亮片段。
  final List<SpeechTranscriptSegment> referenceSegments;

  /// 当前尝试的错误文案。
  final String? errorMessage;

  /// 是否已检测到用户开口。
  final bool hasDetectedSpeech;

  /// 用户开口后的连续静音时长。
  final Duration silenceDuration;

  const SpeechPracticeAttempt({
    required this.promptId,
    this.filePath,
    this.status = SpeechPracticeAttemptStatus.idle,
    this.liveTranscript,
    this.finalTranscript,
    this.score,
    this.matchedTokenCount = 0,
    this.totalTargetTokenCount = 0,
    this.transcriptSegments = const [],
    this.referenceSegments = const [],
    this.errorMessage,
    this.hasDetectedSpeech = false,
    this.silenceDuration = Duration.zero,
  });

  /// 是否已有录音文件。
  bool get hasRecording {
    final currentFilePath = filePath;
    return currentFilePath != null && currentFilePath.isNotEmpty;
  }

  /// 是否是最终反馈态。
  bool get hasFinalFeedback =>
      status == SpeechPracticeAttemptStatus.passed ||
      status == SpeechPracticeAttemptStatus.belowThreshold ||
      status == SpeechPracticeAttemptStatus.noEnglishDetected ||
      status == SpeechPracticeAttemptStatus.permissionDenied ||
      status == SpeechPracticeAttemptStatus.unavailable ||
      status == SpeechPracticeAttemptStatus.error;

  /// 是否属于“识别失败”。
  bool get isRecognitionFailure => status.isRecognitionFailure;

  SpeechPracticeAttempt copyWith({
    String? filePath,
    bool clearFilePath = false,
    SpeechPracticeAttemptStatus? status,
    String? liveTranscript,
    bool clearLiveTranscript = false,
    String? finalTranscript,
    bool clearFinalTranscript = false,
    double? score,
    bool clearScore = false,
    int? matchedTokenCount,
    int? totalTargetTokenCount,
    List<SpeechTranscriptSegment>? transcriptSegments,
    bool clearTranscriptSegments = false,
    List<SpeechTranscriptSegment>? referenceSegments,
    bool clearReferenceSegments = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? hasDetectedSpeech,
    bool clearDetectedSpeech = false,
    Duration? silenceDuration,
    bool clearSilenceDuration = false,
  }) {
    return SpeechPracticeAttempt(
      promptId: promptId,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      status: status ?? this.status,
      liveTranscript: clearLiveTranscript
          ? null
          : (liveTranscript ?? this.liveTranscript),
      finalTranscript: clearFinalTranscript
          ? null
          : (finalTranscript ?? this.finalTranscript),
      score: clearScore ? null : (score ?? this.score),
      matchedTokenCount: matchedTokenCount ?? this.matchedTokenCount,
      totalTargetTokenCount:
          totalTargetTokenCount ?? this.totalTargetTokenCount,
      transcriptSegments: clearTranscriptSegments
          ? const []
          : (transcriptSegments ?? this.transcriptSegments),
      referenceSegments: clearReferenceSegments
          ? const []
          : (referenceSegments ?? this.referenceSegments),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      hasDetectedSpeech: clearDetectedSpeech
          ? false
          : (hasDetectedSpeech ?? this.hasDetectedSpeech),
      silenceDuration: clearSilenceDuration
          ? Duration.zero
          : (silenceDuration ?? this.silenceDuration),
    );
  }
}

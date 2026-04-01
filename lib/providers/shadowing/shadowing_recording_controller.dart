/// 跟读录音控制器 provider。
///
/// 独立于复述的 [RetellRecordingController]，专为跟读/难句补练/收藏复习设计。
/// 使用 [RecordingService] 管理录音生命周期，录音结束后自动释放麦克风。
/// 评估仅用覆盖率（[SpeechTranscriptMatcher]），不使用 embedding 相似度。
///
/// 状态机：idle → awaitingSpeech → speaking → processing → idle。
///
/// 自动模式录音流程：
/// 1. startRecording → awaitingSpeech，启动 60s 等待开口计时器
/// 2. 检测到语音 → speaking，取消等待计时器，启动最大录音时长计时器
/// 3. 双通道检测结束：
///    - 通道 1：声学静音（silenceDuration）+ [SpeechPracticeCompletionHeuristic]
///    - 通道 2：转录停滞（liveTranscript 停止更新）
///    - 兜底：绝对静音超时（5s）
///    - 兜底：最大录音时长
/// 4. 自动停止 → processing → 评估 → idle
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/speech_practice_models.dart';
import '../../services/app_logger.dart';
import '../../services/recording_service.dart';
import '../../services/speech_completion_detector.dart';
import '../../services/speech_practice_platform.dart';
import '../../services/study_event_recorder.dart';
import '../speech_practice_session_provider.dart';

/// 等待开口最大时长
const _awaitingSpeechTimeout = Duration(seconds: 60);

/// 默认静音兜底阈值（无转录时）
const _defaultSilenceThreshold = Duration(seconds: 5);

/// 默认最大录音时长
const _defaultMaxRecordingDuration = Duration(seconds: 30);

/// 手动模式录音兜底上限（startRecording 时立即启动，检测到语音后按句长/段长重算）
const _manualModeInitialMax = Duration(seconds: 300);

/// 手动模式倍率（检测到语音后：max(300s, 5 × 自动模式时长)）
const _manualModeMultiplier = 5;

/// 跟读回合阶段
enum ShadowingRecordingPhase {
  idle,
  awaitingSpeech,
  speaking,
  processing,
  reviewCountdown,
}

/// 跟读回合状态
class ShadowingRecordingState {
  final ShadowingRecordingPhase phase;
  final String? promptId;
  final String? referenceText;

  /// 当前录音评估结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 实时转录
  final String? liveTranscript;

  /// 是否检测到语音
  final bool hasDetectedSpeech;

  /// 当前静音时长
  final Duration silenceDuration;

  /// 权限状态
  final SpeechPracticePermissionState permissions;

  const ShadowingRecordingState({
    this.phase = ShadowingRecordingPhase.idle,
    this.promptId,
    this.referenceText,
    this.currentAttempt,
    this.liveTranscript,
    this.hasDetectedSpeech = false,
    this.silenceDuration = Duration.zero,
    this.permissions = const SpeechPracticePermissionState(),
  });

  bool get isActive => phase != ShadowingRecordingPhase.idle;

  /// 是否正在录制指定 promptId
  bool isRecordingPrompt(String id) =>
      promptId == id &&
      (phase == ShadowingRecordingPhase.awaitingSpeech ||
          phase == ShadowingRecordingPhase.speaking);

  ShadowingRecordingState copyWith({
    ShadowingRecordingPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    String? referenceText,
    bool clearReferenceText = false,
    SpeechPracticeAttempt? currentAttempt,
    bool clearCurrentAttempt = false,
    String? liveTranscript,
    bool clearLiveTranscript = false,
    bool? hasDetectedSpeech,
    Duration? silenceDuration,
    SpeechPracticePermissionState? permissions,
  }) {
    return ShadowingRecordingState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      referenceText: clearReferenceText
          ? null
          : (referenceText ?? this.referenceText),
      currentAttempt: clearCurrentAttempt
          ? null
          : (currentAttempt ?? this.currentAttempt),
      liveTranscript: clearLiveTranscript
          ? null
          : (liveTranscript ?? this.liveTranscript),
      hasDetectedSpeech: hasDetectedSpeech ?? this.hasDetectedSpeech,
      silenceDuration: silenceDuration ?? this.silenceDuration,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// 句子级静音检测启发式。
///
/// 根据实时转录与参考句的匹配程度，计算所需静音等待时长。
class SpeechPracticeCompletionHeuristic {
  const SpeechPracticeCompletionHeuristic();

  /// 根据实时转录与参考句的匹配程度，计算所需静音等待时长。
  ///
  /// 委托给 [speech_completion_detector.dart] 中的独立检测器：
  /// A. [detectTailMatch] — 连续尾部匹配 + 唯一 → 1s
  /// B. [detectOverallMatchRate] — 全句匹配率 → 1-3s
  /// C. [detectTailHitCount] — 末尾 5 词命中数 → 1-5s
  ///
  /// 三条规则取最小值，无规则触发时返回 [_defaultSilenceThreshold]。
  Duration computeSilenceThreshold({
    required String referenceText,
    required String partialTranscript,
  }) {
    return computeSilenceThresholdDetailed(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
    ).threshold!;
  }

  /// 与 [computeSilenceThreshold] 逻辑一致，额外返回触发原因（用于调试日志）。
  ///
  /// 四条规则取最小值：
  /// D. [detectRemainingByPosition] — 剩余词数估算阈值
  /// A. [detectTailMatch] — 连续尾部匹配 + 唯一 → 1s
  /// B. [detectOverallMatchRate] — 全句匹配率 → 1-3s
  /// C. [detectTailHitCount] — 末尾 5 词命中数 → 1-5s
  DetectionResult computeSilenceThresholdDetailed({
    required String referenceText,
    required String partialTranscript,
  }) {
    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
    );
    if (!ctx.hasMatch) {
      return DetectionResult(
        threshold: _defaultSilenceThreshold,
        description: '无匹配, 默认${_defaultSilenceThreshold.inSeconds}s',
      );
    }

    return combineDetections(
      [
        detectRemainingByPosition(ctx), // D
        detectTailMatch(ctx), // A
        detectOverallMatchRate(ctx), // B
        detectTailHitCount(ctx), // C
      ],
      ctx,
      fallback: _defaultSilenceThreshold,
    );
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

// ============================================================
// ShadowingRecordingController — 跟读专用录音控制器
// ============================================================

/// 跟读录音控制器 provider
final shadowingRecordingControllerProvider =
    NotifierProvider<ShadowingRecordingController, ShadowingRecordingState>(
      ShadowingRecordingController.new,
    );

/// 跟读录音控制器。
///
/// 使用 [RecordingService] 管理录音，[SpeechTranscriptMatcher] 做评估。
/// 录音结束后自动释放麦克风，无需调用方管理引擎生命周期。
///
/// 与 [RetellRecordingController] 的区别：
/// - 状态机含 awaitingSpeech / speaking 两个子阶段
/// - 静音检测用 [SpeechPracticeCompletionHeuristic]（句子级启发式）
/// - 评估仅用覆盖率，不使用 embedding 相似度
class ShadowingRecordingController extends Notifier<ShadowingRecordingState> {
  // ── 服务 ──
  late RecordingService _recordingService;
  StreamSubscription<SpeechPracticeEvent>? _eventSub;

  // ── 计时器 ──
  Timer? _awaitingSpeechTimer;
  Timer? _maxDurationTimer;
  Timer? _transcriptStaleTimer;

  // ── 内部状态 ──
  bool _isStopping = false;
  bool _hasDetectedSpeech = false;
  String? _lastKnownTranscript;
  String? _cachedReferenceText;
  String? _lastSilenceLogDesc;

  // ── 配置 ──
  bool _isManualMode = false;

  /// 自动模式最大录音时长（检测到语音后启动）
  Duration _maxRecordingDuration = _defaultMaxRecordingDuration;

  @override
  ShadowingRecordingState build() {
    final backend = ref.read(speechPracticeBackendProvider);
    _recordingService = RecordingService(backend);

    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _cancelAllTimers();
      _eventSub?.cancel();
      _recordingService.dispose();
    });
    return const ShadowingRecordingState();
  }

  // ========== 配置方法 ==========

  /// 设置学习事件记录器（Provider 进入模式时注入，退出时传 null 清除）
  ///
  /// 录音完成后自动通过 recorder 记录说的时长。
  void setRecorder(StudyEventRecorder? recorder) {
    _recordingService.recorder = recorder;
  }

  /// 设置手动控制模式
  void setManualMode(bool value) {
    _isManualMode = value;
  }

  /// 设置最大录音时长（默认 30s，仅自动模式；手动模式固定 60s）
  void setMaxRecordingDuration(Duration value) {
    _maxRecordingDuration = value;
  }

  // ========== 录音控制 ==========

  /// 开始录音
  ///
  /// 自动模式：启动 60s 等待开口计时器。
  /// 手动模式：不启动等待计时器。
  /// 两种模式均不立即启动最大录音时长计时器（等检测到语音后启动）。
  Future<void> startRecording({
    required String promptId,
    required String referenceText,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      AppLogger.log('ShadowRec', '⏭ startRecording 跳过: 已在录音中 ($promptId)');
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _lastSilenceLogDesc = null;
    _cachedReferenceText = referenceText;

    AppLogger.log('ShadowRec', '┌ startRecording (manual=$_isManualMode)');
    AppLogger.log('ShadowRec', '│ promptId=$promptId');

    state = ShadowingRecordingState(
      phase: ShadowingRecordingPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      permissions: state.permissions,
    );

    try {
      await _recordingService.startRecording(promptId: promptId);
      _eventSub?.cancel();
      _eventSub = _recordingService.events.listen(_handleRecordingEvent);

      state = state.copyWith(permissions: _recordingService.permissions);
    } on SpeechPracticePlatformException catch (error) {
      AppLogger.log('ShadowRec', '└ 录音启动失败: ${error.code} → idle');
      state = state.copyWith(
        phase: ShadowingRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: _statusFromError(error.code),
          errorMessage: error.message,
        ),
        permissions: _recordingService.permissions,
      );
      return;
    }

    if (_isManualMode) {
      // 手动模式：立即启动兜底计时器（用户点击停止前的安全上限）
      AppLogger.log(
        'ShadowRec',
        '│ 手动模式兜底 ${_manualModeInitialMax.inSeconds}s',
      );
      _scheduleMaxDurationTimer(
        promptId: promptId,
        maxDuration: _manualModeInitialMax,
      );
    } else {
      // 自动模式：启动 60s 等待开口计时器
      AppLogger.log(
        'ShadowRec',
        '│ 启动 ${_awaitingSpeechTimeout.inSeconds}s 等待开口计时器',
      );
      _scheduleAwaitingSpeechTimer(promptId);
    }

    AppLogger.log('ShadowRec', '└ 录音已开始，等待用户开口...');
  }

  /// 手动停止录音并评估
  Future<void> stopAndEvaluate({required String referenceText}) async {
    final promptId = state.promptId;
    if (promptId == null) return;

    AppLogger.log('ShadowRec', '● 手动停止录音');
    _isStopping = true;
    _enterProcessing(promptId);
    await _doStopAndEvaluate(promptId: promptId, referenceText: referenceText);
  }

  /// 取消当前录音
  Future<void> cancelActiveRecording() async {
    if (!_recordingService.isRecording) return;

    _cancelAllTimers();
    await _eventSub?.cancel();
    _eventSub = null;
    await _recordingService.cancelRecording();

    state = state.copyWith(
      phase: ShadowingRecordingPhase.idle,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  // ========== 清理方法 ==========

  /// 清除当前回合状态（保留配置），并删除已完成录音的临时文件。
  Future<void> clearRecording() async {
    AppLogger.log('ShadowRec', '● clearRecording → idle');
    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _eventSub?.cancel();
    _eventSub = null;
    // 先读取文件路径，再立即重置状态（避免 await 延迟状态重置导致自动录音触发失败）
    final filePath = state.currentAttempt?.filePath;
    state = ShadowingRecordingState(permissions: state.permissions);
    // 异步删除录音临时文件（fire-and-forget）
    if (filePath != null && filePath.isNotEmpty) {
      unawaited(_recordingService.deleteRecording(filePath));
    }
  }

  /// 完全重置（页面 dispose 时调用）
  Future<void> fullReset() async {
    await cancelActiveRecording();
    await clearRecording();
    _isManualMode = false;
    _cachedReferenceText = null;
    _maxRecordingDuration = _defaultMaxRecordingDuration;
  }

  /// 删除指定录音文件
  Future<void> deleteRecording(String filePath) async {
    await _recordingService.deleteRecording(filePath);
  }

  // ========== 内部方法 ==========

  /// 停止录音 + 评估（仅覆盖率，不使用 embedding）
  Future<void> _doStopAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async {
    _cancelAllTimers();
    await _eventSub?.cancel();
    _eventSub = null;

    final result = await _recordingService.stopRecording(promptId: promptId);
    AppLogger.log(
      'ShadowRec',
      '📋 final: "${result.finalTranscript ?? '(null)'}"',
    );

    if (!result.isSuccess) {
      final attempt = SpeechPracticeAttempt(promptId: promptId).copyWith(
        filePath: result.filePath,
        status: _statusFromError(result.errorCode),
        errorMessage: result.errorMessage,
      );
      AppLogger.log('ShadowRec', '✗ 录音失败: ${result.errorCode}');
      state = state.copyWith(
        phase: ShadowingRecordingPhase.idle,
        currentAttempt: attempt,
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
      return;
    }

    // 评估：仅覆盖率
    final matcher = ref.read(speechTranscriptMatcherProvider);
    final matchResult = matcher.evaluate(
      referenceText: referenceText,
      transcript: result.finalTranscript!,
    );

    final attempt = SpeechPracticeAttempt(promptId: promptId).copyWith(
      filePath: result.filePath,
      status: matchResult.status,
      finalTranscript: matchResult.finalTranscript,
      score: matchResult.score,
      matchedTokenCount: matchResult.matchedTokenCount,
      totalTargetTokenCount: matchResult.totalTargetTokenCount,
      transcriptSegments: matchResult.transcriptSegments,
      referenceSegments: matchResult.referenceSegments,
    );

    AppLogger.log(
      'ShadowRec',
      '✓ 评估完成: '
          'status=${attempt.status.name}, '
          'score=${attempt.score?.toStringAsFixed(2)}, '
          'matched=${attempt.matchedTokenCount}/${attempt.totalTargetTokenCount}',
    );

    state = state.copyWith(
      phase: ShadowingRecordingPhase.idle,
      currentAttempt: attempt,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  void _enterProcessing(String promptId) {
    if (state.promptId != promptId) return;
    _cancelAllTimers();
    state = state.copyWith(phase: ShadowingRecordingPhase.processing);
  }

  // ── 事件处理 ──

  void _handleRecordingEvent(SpeechPracticeEvent event) {
    final promptId = state.promptId;
    if (promptId == null || event.promptId != promptId) return;
    if (_isStopping) return;
    if (state.phase != ShadowingRecordingPhase.awaitingSpeech &&
        state.phase != ShadowingRecordingPhase.speaking) {
      return;
    }

    switch (event.type) {
      case SpeechPracticeEventType.partialTranscriptUpdated:
        _handlePartialTranscript(event);
      case SpeechPracticeEventType.speechStarted:
        _handleSpeechStarted(event);
      case SpeechPracticeEventType.silenceProgress:
        _handleSilenceProgress(event);
      case SpeechPracticeEventType.finalTranscriptReady ||
          SpeechPracticeEventType.error:
        break; // RecordingService 内部处理
    }
  }

  void _handlePartialTranscript(SpeechPracticeEvent event) {
    final text = (event.transcript ?? '').trim();
    final prevText = state.liveTranscript?.trim() ?? '';
    if (text.isNotEmpty && text != prevText) {
      AppLogger.log('ShadowRec', '📝 live: "$text"');
    }
    state = state.copyWith(
      liveTranscript: text,
      silenceDuration: Duration.zero,
    );

    _checkSpeechAndAutoStop(text);
  }

  void _handleSpeechStarted(SpeechPracticeEvent event) {
    state = state.copyWith(
      hasDetectedSpeech: true,
      silenceDuration: Duration.zero,
    );

    if (!_hasDetectedSpeech) {
      _handleSpeechDetected(state.promptId!);
    }
  }

  void _handleSilenceProgress(SpeechPracticeEvent event) {
    final silence = event.silenceDuration ?? Duration.zero;
    state = state.copyWith(silenceDuration: silence);

    _checkAutoStopOnSilence(silence);
  }

  /// 检查语音检测 + 自动停止
  void _checkSpeechAndAutoStop(String liveText) {
    final promptId = state.promptId;
    if (promptId == null) return;

    final hasVoiceInput = state.hasDetectedSpeech || liveText.isNotEmpty;

    // 首次检测到语音
    if (!_hasDetectedSpeech && hasVoiceInput) {
      _handleSpeechDetected(promptId);
    }

    if (_isManualMode || !_hasDetectedSpeech) return;

    // 转录停滞检测（通道 2）
    if (liveText.isNotEmpty && liveText != _lastKnownTranscript) {
      _lastKnownTranscript = liveText;
      _resetTranscriptStaleTimer(
        promptId: promptId,
        referenceText: _cachedReferenceText!,
        transcript: liveText,
      );
    }
  }

  /// 静音时的自动停止检测
  void _checkAutoStopOnSilence(Duration currentSilence) {
    final promptId = state.promptId;
    if (promptId == null || _isManualMode || !_hasDetectedSpeech) return;

    final liveTranscript = state.liveTranscript?.trim() ?? '';
    final referenceText = _cachedReferenceText;
    if (referenceText == null) return;

    // ── 通道 1：声学静音 + 启发式 ──
    if (currentSilence > Duration.zero && liveTranscript.isNotEmpty) {
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      final detailed = heuristic.computeSilenceThresholdDetailed(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      );
      final required = detailed.threshold!;
      if (detailed.description != _lastSilenceLogDesc) {
        _lastSilenceLogDesc = detailed.description;
        AppLogger.log(
          'ShadowRec',
          '静音阈值 ${required.inMilliseconds}ms | '
              '${detailed.description}',
        );
      }
      if (currentSilence >= required) {
        _stopForEvaluation(
          promptId: promptId,
          reason: '用户读完，静音${currentSilence.inMilliseconds}ms',
        );
        return;
      }
    }

    // 静音 5s 兜底（无转录时）
    if (currentSilence >= _defaultSilenceThreshold) {
      _stopForEvaluation(
        promptId: promptId,
        reason: '静音兜底 ${currentSilence.inSeconds}s',
      );
    }
  }

  // ── 等待开口计时器 ──

  /// 60s 内未检测到语音 → 取消录音，回到 idle。
  void _scheduleAwaitingSpeechTimer(String promptId) {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = Timer(_awaitingSpeechTimeout, () async {
      if (state.promptId != promptId ||
          state.phase != ShadowingRecordingPhase.awaitingSpeech) {
        return;
      }
      AppLogger.log(
        'ShadowRec',
        '⏰ ${_awaitingSpeechTimeout.inSeconds}s 未检测到语音 → idle',
      );
      await cancelActiveRecording();
    });
  }

  /// 首次检测到语音的处理
  void _handleSpeechDetected(String promptId) {
    _hasDetectedSpeech = true;
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;

    // awaitingSpeech → speaking
    if (state.phase == ShadowingRecordingPhase.awaitingSpeech) {
      AppLogger.log('ShadowRec', '🎤 检测到语音 → speaking');
      state = state.copyWith(phase: ShadowingRecordingPhase.speaking);
    }

    final effectiveMaxDuration = _isManualMode
        ? _computeManualMaxDuration(_maxRecordingDuration)
        : _maxRecordingDuration;

    AppLogger.log(
      'ShadowRec',
      '│ 启动最大录音时长计时器: ${effectiveMaxDuration.inSeconds}s',
    );
    _scheduleMaxDurationTimer(
      promptId: promptId,
      maxDuration: effectiveMaxDuration,
    );
  }

  /// 转录停滞定时器：使用 [SpeechPracticeCompletionHeuristic] 计算阈值。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();

    final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
    final detailed = heuristic.computeSilenceThresholdDetailed(
      referenceText: referenceText,
      partialTranscript: transcript,
    );
    final threshold = detailed.threshold!;
    AppLogger.log(
      'ShadowRec',
      '转录停滞阈值 ${threshold.inMilliseconds}ms | '
          '${detailed.description}',
    );
    _transcriptStaleTimer = Timer(threshold, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != ShadowingRecordingPhase.speaking) return;
      _stopForEvaluation(
        promptId: promptId,
        reason: '转录停滞 ${threshold.inMilliseconds}ms',
      );
    });
  }

  // ── 最大录音时长 ──

  /// 手动模式最大录音时长：max(300s, 5 × 自动模式时长)
  static Duration _computeManualMaxDuration(Duration autoMaxDuration) {
    final computed = autoMaxDuration * _manualModeMultiplier;
    return computed > _manualModeInitialMax ? computed : _manualModeInitialMax;
  }

  void _scheduleMaxDurationTimer({
    required String promptId,
    required Duration maxDuration,
  }) {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == ShadowingRecordingPhase.awaitingSpeech ||
          state.phase == ShadowingRecordingPhase.speaking) {
        AppLogger.log('ShadowRec', '⏰ 最大录音时长 ${maxDuration.inSeconds}s');
        _stopForEvaluation(promptId: promptId, reason: '最大录音时长');
      }
    });
  }

  // ── 自动停止 ──

  void _stopForEvaluation({required String promptId, String reason = ''}) {
    AppLogger.log('ShadowRec', '⏹ 自动停止录音 ($reason)');
    _isStopping = true;
    _enterProcessing(promptId);

    final referenceText = _cachedReferenceText;
    if (referenceText == null) {
      AppLogger.log('ShadowRec', '⚠ 无法获取 referenceText');
      return;
    }

    unawaited(
      _doStopAndEvaluate(promptId: promptId, referenceText: referenceText),
    );
  }

  // ── 生命周期 ──

  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      AppLogger.log('ShadowRec', 'App 进入后台 → idle');
      _cancelAllTimers();
      _isStopping = false;
      _hasDetectedSpeech = false;
      _lastKnownTranscript = null;
      _lastSilenceLogDesc = null;
      _eventSub?.cancel();
      _eventSub = null;
      unawaited(_recordingService.cancelRecording());
      // 保留 currentAttempt（评级 badge）和 permissions
      state = ShadowingRecordingState(
        phase: ShadowingRecordingPhase.idle,
        permissions: state.permissions,
        currentAttempt: state.currentAttempt,
      );
    }
  }

  void _cancelAllTimers() {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _transcriptStaleTimer?.cancel();
    _transcriptStaleTimer = null;
  }

  /// 判断错误码对应的 attempt 状态。
  SpeechPracticeAttemptStatus _statusFromError(String? code) {
    return switch (code) {
      'permissionDenied' => SpeechPracticeAttemptStatus.permissionDenied,
      'notAvailable' => SpeechPracticeAttemptStatus.unavailable,
      'noSpeech' => SpeechPracticeAttemptStatus.noEnglishDetected,
      _ => SpeechPracticeAttemptStatus.error,
    };
  }
}

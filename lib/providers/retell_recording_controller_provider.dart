/// 复述录音控制器 provider。
///
/// 独立于跟读的 [ListenAndRepeatTurnController]，专为复述场景设计。
/// 使用 [RecordingService] 管理录音生命周期，录音结束后自动释放麦克风。
/// 评估由控制器直接调用 [SpeechTranscriptMatcher]。
///
/// 状态机：idle → recording → processing → idle。
///
/// 自动模式录音流程：
/// 1. startRecording → recording，启动 60s 等待开口计时器
/// 2. 检测到语音 → 取消等待计时器，启动最大录音时长计时器
/// 3. 双通道检测结束：
///    - 通道 1：声学静音（silenceDuration）+ 启发式阈值
///    - 通道 2：转录停滞（liveTranscript 停止更新）
///    - 兜底：绝对静音超时（_silenceTimeout，默认 20s）
///    - 兜底：最大录音时长
/// 4. 自动停止 → processing → 评估 → idle
/// 5. 段间停顿由 RetellPlayer 管理
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../services/app_logger.dart';
import '../services/recording_service.dart';
import '../services/speech_completion_detector.dart';
import '../services/speech_practice_platform.dart';
import 'speech_practice_session_provider.dart';

/// 等待开口最大时长
const _awaitingSpeechTimeout = Duration(seconds: 60);

/// 自动模式默认最大录音时长
const _defaultMaxRecordingDuration = Duration(seconds: 30);

/// 手动模式录音兜底上限
const _manualModeMaxDuration = Duration(seconds: 60);

/// 复述录音阶段
enum RetellRecordingPhase {
  /// 就绪，等用户开始或自动开始
  idle,

  /// 正在录音（含等待开口 + 正在说话）
  recording,

  /// 停止录音，等待 final transcript + 评估
  processing,
}

/// 复述录音状态
class RetellRecordingState {
  /// 当前阶段
  final RetellRecordingPhase phase;

  /// 当前录音对应的 promptId
  final String? promptId;

  /// 等待开口超时后置 true，阻止 screen 层重新自动开始录音
  final bool awaitingSpeechTimedOut;

  /// 当前录音结果（录音完成后保存）
  final SpeechPracticeAttempt? currentAttempt;

  /// 录音中的 live transcript
  final String? liveTranscript;

  /// 是否已检测到用户开口
  final bool hasDetectedSpeech;

  /// 用户开口后的连续静音时长
  final Duration silenceDuration;

  /// 权限状态
  final SpeechPracticePermissionState permissions;

  const RetellRecordingState({
    this.phase = RetellRecordingPhase.idle,
    this.promptId,
    this.awaitingSpeechTimedOut = false,
    this.currentAttempt,
    this.liveTranscript,
    this.hasDetectedSpeech = false,
    this.silenceDuration = Duration.zero,
    this.permissions = const SpeechPracticePermissionState(),
  });

  /// 是否处于活跃状态（非 idle）
  bool get isActive => phase != RetellRecordingPhase.idle;

  /// 是否正在录制指定 promptId
  bool isRecordingPrompt(String id) =>
      promptId == id && phase == RetellRecordingPhase.recording;

  RetellRecordingState copyWith({
    RetellRecordingPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    bool? awaitingSpeechTimedOut,
    SpeechPracticeAttempt? currentAttempt,
    bool clearCurrentAttempt = false,
    String? liveTranscript,
    bool clearLiveTranscript = false,
    bool? hasDetectedSpeech,
    Duration? silenceDuration,
    SpeechPracticePermissionState? permissions,
  }) {
    return RetellRecordingState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      awaitingSpeechTimedOut:
          awaitingSpeechTimedOut ?? this.awaitingSpeechTimedOut,
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

/// 复述录音控制器 provider
final retellRecordingControllerProvider =
    NotifierProvider<RetellRecordingController, RetellRecordingState>(
      RetellRecordingController.new,
    );

/// 复述录音控制器。
///
/// 使用 [RecordingService] 管理录音，[SpeechTranscriptMatcher] 做评估。
/// 录音结束后自动释放麦克风，无需调用方管理引擎生命周期。
class RetellRecordingController extends Notifier<RetellRecordingState> {
  // ── 服务 ──
  late final RecordingService _recordingService;
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

  // ── 配置 ──
  bool _isManualMode = false;

  /// 自动模式最大录音时长（检测到语音后启动）
  Duration _maxRecordingDuration = _defaultMaxRecordingDuration;

  @override
  RetellRecordingState build() {
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
    return const RetellRecordingState();
  }

  // ========== 配置方法 ==========

  /// 设置手动控制模式
  void setManualMode(bool value) {
    _isManualMode = value;
  }

  /// 设置绝对静音兜底阈值（复述场景不使用，保留接口兼容）
  void setSilenceTimeout(Duration value) {
    // 复述场景完全靠 maxDuration 兜底，不使用绝对静音阈值。
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
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _cachedReferenceText = referenceText;

    AppLogger.log('RetellRec', '┌ startRecording (manual=$_isManualMode)');
    AppLogger.log('RetellRec', '│ promptId=$promptId');
    AppLogger.log('RetellRec', '│ referenceText=${referenceText.length}字');

    state = RetellRecordingState(
      phase: RetellRecordingPhase.recording,
      promptId: promptId,
      permissions: state.permissions,
    );

    try {
      await _recordingService.startRecording(promptId: promptId);
      // 订阅事件流
      _eventSub?.cancel();
      _eventSub = _recordingService.events.listen(_handleRecordingEvent);

      state = state.copyWith(
        permissions: _recordingService.permissions,
      );
    } on SpeechPracticePlatformException catch (error) {
      AppLogger.log('RetellRec', '└ 录音启动失败: ${error.code} → idle');
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: _statusFromError(error.code),
          errorMessage: error.message,
        ),
        permissions: _recordingService.permissions,
      );
      return;
    }

    // 自动模式：启动 60s 等待开口计时器
    if (!_isManualMode) {
      AppLogger.log('RetellRec', '│ 启动 ${_awaitingSpeechTimeout.inSeconds}s 等待开口计时器');
      _scheduleAwaitingSpeechTimer(promptId);
    }

    AppLogger.log('RetellRec', '└ 录音已开始，等待用户开口...');
  }

  /// 手动停止录音并评估
  Future<void> stopAndEvaluate({
    required String referenceText,
  }) async {
    final promptId = state.promptId;
    if (promptId == null) return;

    AppLogger.log('RetellRec', '● 手动停止录音');
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
      phase: RetellRecordingPhase.idle,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  // ========== 清理方法 ==========

  /// 清除当前回合状态（保留配置）
  void clearRecording() {
    AppLogger.log('RetellRec', '● clearRecording → idle');
    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _eventSub?.cancel();
    _eventSub = null;
    state = RetellRecordingState(permissions: state.permissions);
  }

  /// 完全重置（页面 dispose 时调用）
  Future<void> fullReset() async {
    await cancelActiveRecording();
    clearRecording();
    _isManualMode = false;
    _cachedReferenceText = null;
    _maxRecordingDuration = _defaultMaxRecordingDuration;
  }

  /// 删除指定录音文件
  Future<void> deleteRecording(String filePath) async {
    await _recordingService.deleteRecording(filePath);
  }

  // ========== 内部方法 ==========

  /// 停止录音 + 评估
  Future<void> _doStopAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async {
    _cancelAllTimers();
    await _eventSub?.cancel();
    _eventSub = null;

    final result = await _recordingService.stopRecording(promptId: promptId);
    AppLogger.log('RetellRec', '📋 final: "${result.finalTranscript ?? '(null)'}"');

    if (!result.isSuccess) {
      final attempt = SpeechPracticeAttempt(promptId: promptId).copyWith(
        filePath: result.filePath,
        status: _statusFromError(result.errorCode),
        errorMessage: result.errorMessage,
      );
      AppLogger.log('RetellRec', '✗ 录音失败: ${result.errorCode}');
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: attempt,
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
      return;
    }

    // 评估
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

    AppLogger.log('RetellRec', '✓ 评估完成: '
        'status=${attempt.status.name}, '
        'score=${attempt.score?.toStringAsFixed(2)}, '
        'matched=${attempt.matchedTokenCount}/${attempt.totalTargetTokenCount}');

    state = state.copyWith(
      phase: RetellRecordingPhase.idle,
      currentAttempt: attempt,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  void _enterProcessing(String promptId) {
    if (state.promptId != promptId) return;
    _cancelAllTimers();
    state = state.copyWith(phase: RetellRecordingPhase.processing);
  }

  // ── 事件处理 ──

  void _handleRecordingEvent(SpeechPracticeEvent event) {
    final promptId = state.promptId;
    if (promptId == null || event.promptId != promptId) return;
    if (state.phase != RetellRecordingPhase.recording || _isStopping) return;

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
      AppLogger.log('RetellRec', '📝 live: "$text"');
    }
    state = state.copyWith(
      liveTranscript: text,
      silenceDuration: Duration.zero,
    );

    // 触发语音检测 + 自动停止逻辑
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

    // 触发自动停止检测
    _checkAutoStopOnSilence(silence);
  }

  /// 检查语音检测 + 自动停止
  void _checkSpeechAndAutoStop(String liveText) {
    final promptId = state.promptId;
    if (promptId == null) return;

    final hasVoiceInput =
        state.hasDetectedSpeech || liveText.isNotEmpty;

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
    if (referenceText == null || liveTranscript.isEmpty) return;
    if (currentSilence <= Duration.zero) return;

    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: liveTranscript,
    );
    if (!ctx.hasMatch) return;

    final ruleA = detectTailMatch(ctx);
    final ruleB = detectOverallMatchRate(ctx);
    for (final rule in [ruleA, ruleB]) {
      if (rule.triggered && currentSilence >= rule.threshold!) {
        final pct = (ctx.matchRate * 100).toInt();
        AppLogger.log('RetellRec', '⏹ 静音停止: '
            '${currentSilence.inMilliseconds}ms ≥ '
            '${rule.threshold!.inMilliseconds}ms | '
            '匹配${ctx.lcsPairs.length}/${ctx.referenceTokens.length}词'
            '($pct%), ${rule.description}');
        _stopForEvaluation(promptId: promptId, reason: rule.description);
        return;
      }
    }
  }

  // ── 等待开口计时器 ──

  /// 60s 内未检测到语音 → 取消录音，标记超时，等待用户手动操作。
  void _scheduleAwaitingSpeechTimer(String promptId) {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = Timer(_awaitingSpeechTimeout, () async {
      if (state.promptId != promptId ||
          state.phase != RetellRecordingPhase.recording) {
        return;
      }
      AppLogger.log('RetellRec', '⏰ ${_awaitingSpeechTimeout.inSeconds}s 未检测到语音 → 退出自动录音');
      await cancelActiveRecording();
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        awaitingSpeechTimedOut: true,
      );
    });
  }

  /// 首次检测到语音的处理
  void _handleSpeechDetected(String promptId) {
    _hasDetectedSpeech = true;
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;

    final effectiveMaxDuration =
        _isManualMode ? _manualModeMaxDuration : _maxRecordingDuration;

    AppLogger.log('RetellRec', '🎤 检测到语音');
    AppLogger.log('RetellRec', '│ 启动最大录音时长计时器: ${effectiveMaxDuration.inSeconds}s');
    _scheduleMaxDurationTimer(
      promptId: promptId,
      maxDuration: effectiveMaxDuration,
    );
  }

  /// 转录停滞定时器：只在规则 A/B 触发时才设置。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();

    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: transcript,
    );
    if (!ctx.hasMatch) return;

    // 取规则 A/B 中最短的触发阈值
    Duration? shortest;
    String? desc;
    for (final rule in [detectTailMatch(ctx), detectOverallMatchRate(ctx)]) {
      if (rule.triggered) {
        if (shortest == null || rule.threshold! < shortest) {
          shortest = rule.threshold;
          desc = rule.description;
        }
      }
    }
    // 无规则触发 → 不设定时器，靠 maxDuration 兜底
    if (shortest == null) return;

    _transcriptStaleTimer = Timer(shortest, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != RetellRecordingPhase.recording) return;
      final pct = (ctx.matchRate * 100).toInt();
      AppLogger.log('RetellRec', '⏹ 转录停滞停止: '
          '${shortest!.inMilliseconds}ms | '
          '匹配${ctx.lcsPairs.length}/${ctx.referenceTokens.length}词'
          '($pct%), $desc');
      _stopForEvaluation(promptId: promptId, reason: '转录停滞($desc)');
    });
  }

  // ── 最大录音时长 ──

  void _scheduleMaxDurationTimer({
    required String promptId,
    required Duration maxDuration,
  }) {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == RetellRecordingPhase.recording) {
        AppLogger.log('RetellRec', '⏰ 最大录音时长 ${maxDuration.inSeconds}s');
        _stopForEvaluation(promptId: promptId, reason: '最大录音时长');
      }
    });
  }

  // ── 自动停止 ──

  void _stopForEvaluation({
    required String promptId,
    String reason = '',
  }) {
    AppLogger.log('RetellRec', '⏹ 自动停止录音 ($reason)');
    _isStopping = true;
    _enterProcessing(promptId);

    final referenceText = _cachedReferenceText;
    if (referenceText == null) {
      AppLogger.log('RetellRec', '⚠ 无法获取 referenceText');
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
      AppLogger.log('RetellRec', 'App 进入后台 → idle');
      _cancelAllTimers();
      _isStopping = false;
      _hasDetectedSpeech = false;
      _lastKnownTranscript = null;
      _eventSub?.cancel();
      _eventSub = null;
      // 取消录音但不 await（后台不可靠）
      unawaited(_recordingService.cancelRecording());
      state = RetellRecordingState(permissions: state.permissions);
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

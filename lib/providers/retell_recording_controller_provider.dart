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
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import '../services/app_logger.dart';
import '../services/embedding_similarity.dart';
import '../services/recording_service.dart';
import '../services/speech_completion_detector.dart';
import '../services/speech_practice_matcher.dart';
import '../services/speech_practice_platform.dart';
import '../services/study_event_recorder.dart';
import 'offline_asr_settings_provider.dart';
import '../services/text_embedding_platform.dart';
import '../widgets/common/speech_rating_badge.dart';

/// 等待开口最大时长
const _awaitingSpeechTimeout = Duration(seconds: 60);

/// 自动模式默认最大录音时长
const _defaultMaxRecordingDuration = Duration(seconds: 30);

/// 手动模式录音兜底上限（startRecording 时立即启动，检测到语音后按段长重算）
const _manualModeInitialMax = Duration(seconds: 300);

/// 手动模式倍率（检测到语音后：max(300s, 5 × 自动模式时长)）
const _manualModeMultiplier = 5;

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
  DateTime? _speechStartTime;
  String? _cachedReferenceText;
  String? _lastSilenceLogDesc;

  /// 原句音频时长（用于有声时长比例兜底）
  Duration? _referenceDuration;

  /// 累计有声时长（silenceMs == 0 区间的加总）
  Duration _voicedDuration = Duration.zero;

  /// 上一次有声事件的时间戳（用于累加有声时长）
  DateTime? _lastVoicedTimestamp;

  /// 上次 log 的兜底阈值（秒），用于去重日志
  int? _lastLoggedFallbackSeconds;

  // ── 配置 ──
  bool _isManualMode = false;

  /// 自动模式最大录音时长（检测到语音后启动）
  Duration _maxRecordingDuration = _defaultMaxRecordingDuration;

  /// 绝对静音兜底阈值（检测到语音后，持续静音超过此时长即停止）
  Duration _silenceTimeout = const Duration(seconds: 20);

  @override
  RetellRecordingState build() {
    final backend = ref.watch(speechPracticeBackendProvider);
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

  /// 设置绝对静音兜底阈值（检测到语音后，持续静音超过此时长即停止）
  void setSilenceTimeout(Duration value) {
    _silenceTimeout = value;
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
    Duration? referenceDuration,
  }) async {
    final backend = ref.read(speechPracticeBackendProvider);
    if (state.promptId == promptId && state.isActive) {
      AppLogger.log('RetellRec', '⏭ startRecording 跳过: 已在录音中 ($promptId)');
      return;
    }

    // 清理上一次录音的临时文件（避免重录时旧文件泄漏）
    final oldFilePath = state.currentAttempt?.filePath;
    if (oldFilePath != null && oldFilePath.isNotEmpty) {
      unawaited(_recordingService.deleteRecording(oldFilePath));
    }

    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _lastSilenceLogDesc = null;
    _speechStartTime = null;
    _cachedReferenceText = referenceText;
    _referenceDuration = referenceDuration;
    _voicedDuration = Duration.zero;
    _lastVoicedTimestamp = null;
    _lastLoggedFallbackSeconds = null;

    AppLogger.log('RetellRec', '┌ startRecording (manual=$_isManualMode)');
    AppLogger.log('RetellRec', '│ promptId=$promptId');
    AppLogger.log('RetellRec', '│ referenceText=${referenceText.length}字');
    AppLogger.log(
      'RetellRec',
      '│ backend=${backend.runtimeType} permissions=${state.permissions.microphone.name}/${state.permissions.speech.name}',
    );

    state = RetellRecordingState(
      phase: RetellRecordingPhase.recording,
      promptId: promptId,
      permissions: state.permissions,
    );

    try {
      final asrSettings = ref.read(offlineAsrSettingsProvider);
      await _recordingService.startRecording(
        promptId: promptId,
        recognitionEnabled:
            asrSettings.enabled && asrSettings.backend == AsrBackend.platform,
      );
      // 订阅事件流
      _eventSub?.cancel();
      _eventSub = _recordingService.events.listen(_handleRecordingEvent);

      state = state.copyWith(permissions: _recordingService.permissions);
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
    } catch (error, stack) {
      AppLogger.log('RetellRec', '└ 录音启动未知异常: $error → idle\n$stack');
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: SpeechPracticeAttemptStatus.error,
          errorMessage: error.toString(),
        ),
      );
      return;
    }

    if (_isManualMode) {
      // 手动模式：立即启动兜底计时器（用户点击停止前的安全上限）
      AppLogger.log(
        'RetellRec',
        '│ 手动模式兜底 ${_manualModeInitialMax.inSeconds}s',
      );
      _scheduleMaxDurationTimer(
        promptId: promptId,
        maxDuration: _manualModeInitialMax,
      );
    } else {
      // 自动模式：启动 60s 等待开口计时器
      AppLogger.log(
        'RetellRec',
        '│ 启动 ${_awaitingSpeechTimeout.inSeconds}s 等待开口计时器',
      );
      _scheduleAwaitingSpeechTimer(promptId);
    }

    AppLogger.log('RetellRec', '└ 录音已开始，等待用户开口...');
  }

  /// 手动停止录音并评估
  Future<void> stopAndEvaluate({required String referenceText}) async {
    final promptId = state.promptId;
    if (promptId == null) return;

    AppLogger.log('RetellRec', '● 手动停止录音');
    _isStopping = true;
    _cancelAllTimers();
    await _doStopAndEvaluate(promptId: promptId, referenceText: referenceText);
  }

  /// 取消当前录音
  Future<void> cancelActiveRecording() async {
    if (!_recordingService.isRecording) return;

    _cancelAllTimers();
    _speechStartTime = null;
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

  /// 清除当前回合状态（保留配置），并删除已完成录音的临时文件。
  Future<void> clearRecording() async {
    AppLogger.log('RetellRec', '● clearRecording → idle');
    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _speechStartTime = null;
    _eventSub?.cancel();
    _eventSub = null;
    // 先读取文件路径，再立即重置状态（避免 await 延迟状态重置导致自动录音触发失败）
    final filePath = state.currentAttempt?.filePath;
    state = RetellRecordingState(permissions: state.permissions);
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

  /// 停止录音 → processing → 等待转录 → 评估 → idle。
  Future<void> _doStopAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async {
    final backend = ref.read(speechPracticeBackendProvider);
    final asrEnabled = ref.read(offlineAsrSettingsProvider).enabled;
    _cancelAllTimers();
    await _eventSub?.cancel();
    _eventSub = null;

    final speechStart = _speechStartTime;
    _speechStartTime = null;
    final effectiveDurationMs = speechStart == null
        ? null
        : math.max(
            0,
            DateTime.now().difference(speechStart).inMilliseconds -
                state.silenceDuration.inMilliseconds,
          );

    // ── 阶段 1：停止录音（立即返回）──
    final stopResult = await _recordingService.stopSession(
      promptId: promptId,
      effectiveDurationMs: effectiveDurationMs,
    );
    final filePath = stopResult.filePath;
    AppLogger.log('RetellRec', '│ backend=${backend.runtimeType}');

    if (stopResult.errorCode != null || filePath == null || filePath.isEmpty) {
      AppLogger.log('RetellRec', '✗ 停止录音失败: ${stopResult.errorCode}');
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: filePath,
          status: SpeechPracticeAttemptStatus.unavailable,
        ),
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
      return;
    }

    // ── ASR 关闭：直接存录音 ──
    if (!asrEnabled) {
      AppLogger.log('RetellRec', '● ASR 关闭，保留录音，跳过转录');
      await _recordingService.shutdown();
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: filePath,
          status: SpeechPracticeAttemptStatus.unavailable,
          score: 0,
        ),
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
      return;
    }

    // ── 阶段 2：进入 processing ──
    _enterProcessing(promptId);

    // ── 阶段 3：等待转录结果 ──
    // whisper-small 推理接近 1:1 实时，加 10s 基础余量。
    final transcriptTimeout = effectiveDurationMs != null
        ? Duration(seconds: 10 + (effectiveDurationMs / 1000).ceil())
        : null;
    final result = await _recordingService.waitForTranscript(
      filePath: filePath,
      timeout: transcriptTimeout,
    );

    // 确定用于评估的 transcript：优先 final，超时时回退到 live
    String? transcript = result.finalTranscript;
    if (transcript == null &&
        result.errorCode == 'timeout' &&
        _lastKnownTranscript != null &&
        _lastKnownTranscript!.trim().isNotEmpty) {
      transcript = _lastKnownTranscript!.trim();
      AppLogger.log(
        'RetellRec',
        '📋 final transcript 超时，回退到 live transcript: "$transcript"',
      );
    }

    AppLogger.log('RetellRec', '📋 final: "${transcript ?? '(null)'}"');

    if (transcript == null || transcript.isEmpty) {
      final status = result.errorCode != null
          ? _statusFromError(result.errorCode)
          : SpeechPracticeAttemptStatus.unavailable;
      AppLogger.log('RetellRec', '✗ 无转录结果，保留录音: status=${status.name}');
      state = state.copyWith(
        phase: RetellRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: filePath,
          status: status,
          score: 0,
          errorMessage: result.errorMessage,
        ),
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
      return;
    }

    // ── 阶段 4：评估 ──
    final matcher = ref.read(speechTranscriptMatcherProvider);
    AppLogger.log(
      'RetellRec',
      '│ evaluate transcriptLen=${transcript.trim().length} '
          'liveLen=${(_lastKnownTranscript ?? '').trim().length}',
    );
    final matchResult = matcher.evaluate(
      referenceText: referenceText,
      transcript: transcript,
    );

    final effectiveScore = await _bestScore(
      coverageScore: matchResult.score,
      referenceText: referenceText,
      transcript: transcript,
    );
    final effectiveStatus = effectiveScore >= 0.2
        ? SpeechPracticeAttemptStatus.passed
        : matchResult.status;

    final attempt = SpeechPracticeAttempt(promptId: promptId).copyWith(
      filePath: filePath,
      status: effectiveStatus,
      finalTranscript: matchResult.finalTranscript,
      score: effectiveScore,
      matchedTokenCount: matchResult.matchedTokenCount,
      totalTargetTokenCount: matchResult.totalTargetTokenCount,
      transcriptSegments: matchResult.transcriptSegments,
      referenceSegments: matchResult.referenceSegments,
    );

    if (attempt.isRecognitionFailure) {
      AppLogger.log(
        'RetellRec',
        '✗ 识别失败: status=${attempt.status.name}, final="${attempt.finalTranscript ?? ''}"',
      );
    }

    AppLogger.log(
      'RetellRec',
      '✓ 评估完成: '
          'status=${attempt.status.name}, '
          'score=${attempt.score?.toStringAsFixed(2)}, '
          'matched=${attempt.matchedTokenCount}/${attempt.totalTargetTokenCount}',
    );

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
    _lastVoicedTimestamp ??= DateTime.now();
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

    // 累加有声时长
    _updateVoicedDuration(silence);

    // 触发自动停止检测
    _checkAutoStopOnSilence(silence);
  }

  /// 根据 silenceProgress 事件累加有声时长。
  ///
  /// 短静音（< [_voicedGapThreshold]）被视为语音的一部分，不结算有声段。
  /// 这是因为 VAD 基于 RMS 阈值，说话中的低音段可能被误判为静音。
  ///
  /// - silenceMs == 0：有声，累加时间差。
  /// - silenceMs > 0 但 < 阈值：不操作，等待恢复。
  /// - silenceMs >= 阈值：真正的静音，结算有声段（结束点 = now - silence）。
  static const _voicedGapThreshold = Duration(milliseconds: 500);

  void _updateVoicedDuration(Duration silence) {
    final now = DateTime.now();
    final lastVoiced = _lastVoicedTimestamp;

    if (silence == Duration.zero) {
      // 有声：累加自上次有声时间戳的差值
      if (lastVoiced != null) {
        _voicedDuration += now.difference(lastVoiced);
      }
      _lastVoicedTimestamp = now;
    } else if (silence >= _voicedGapThreshold && lastVoiced != null) {
      // 静音超过阈值：有声段结束于静音开始时刻
      final voicedEnd = now.subtract(silence);
      final diff = voicedEnd.difference(lastVoiced);
      if (diff > Duration.zero) {
        _voicedDuration += diff;
      }
      _lastVoicedTimestamp = null;
    }
    // silence > 0 但 < 阈值：VAD 抖动，不结算，等恢复
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
    if (currentSilence <= Duration.zero) return;

    final liveTranscript = state.liveTranscript?.trim() ?? '';
    final referenceText = _cachedReferenceText;

    // ── 通道 1：声学静音 + 启发式（需要转录文本） ──
    if (referenceText != null && liveTranscript.isNotEmpty) {
      final ctx = buildMatchContext(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      );
      if (ctx.hasMatch) {
        // [旧算法-2026-05-18] D 规则（剩余词数估算）在复述场景过于激进，
        // 用户说几个词碰巧匹配末尾就被快速停止。已在调用方禁用，函数本身保留。
        // final ruleD = detectRemainingByPosition(
        //   ctx,
        //   secondsPerWord: 3,
        //   baseSeconds: 2,
        // );
        // 复述场景：A 要求尾部连续 ≥3 词唯一匹配，B 仅 100% 匹配时触发，
        // E 覆盖"接近完成但 ASR 漏识别 1-2 词"的场景。三者均高置信，阈值 1s。
        final ruleA = detectTailMatch(
          ctx,
          minConsecutive: 3,
          triggerDuration: const Duration(seconds: 1),
        );
        final ruleB = detectOverallMatchRate(
          ctx,
          strictPerfectOnly: true,
          perfectDuration: const Duration(seconds: 1),
        );
        final ruleE = detectNearCompletion(ctx);
        final rules = [ruleA, ruleB, ruleE];

        // 找最短触发阈值用于日志
        Duration? shortest;
        String? winnerDesc;
        for (final rule in rules) {
          if (rule.triggered) {
            if (shortest == null || rule.threshold! < shortest) {
              shortest = rule.threshold;
              winnerDesc = rule.description;
            }
          }
        }
        final pct = (ctx.matchRate * 100).toInt();
        final summary =
            '匹配${ctx.lcsPairs.length}/${ctx.referenceTokens.length}词'
            '($pct%)';
        if (shortest != null && winnerDesc != _lastSilenceLogDesc) {
          _lastSilenceLogDesc = winnerDesc;
          AppLogger.log(
            'RetellRec',
            '静音阈值 ${shortest.inMilliseconds}ms | '
                '$summary, $winnerDesc',
          );
        }

        for (final rule in rules) {
          if (rule.triggered && currentSilence >= rule.threshold!) {
            AppLogger.log(
              'RetellRec',
              '⏹ 静音停止: '
                  '${currentSilence.inMilliseconds}ms ≥ '
                  '${rule.threshold!.inMilliseconds}ms | '
                  '$summary, ${rule.description}',
            );
            _stopForEvaluation(promptId: promptId, reason: rule.description);
            return;
          }
        }
      }
    }

    // ── 静音兜底（动态阈值，无转录时含无 ASR 场景） ──
    final refDur = _referenceDuration;
    final fallback = (refDur != null)
        ? computeRetellDynamicFallback(
            voicedDuration: _voicedDuration,
            referenceDuration: refDur,
          )
        : _silenceTimeout;

    // 兜底阈值变化时输出日志，方便排查
    final voicedMs = _voicedDuration.inMilliseconds;
    final refMs = refDur?.inMilliseconds ?? 0;
    final fallbackSec = fallback.inSeconds;
    if (fallbackSec != _lastLoggedFallbackSeconds) {
      _lastLoggedFallbackSeconds = fallbackSec;
      AppLogger.log(
        'RetellRec',
        '兜底阈值变更 → ${fallbackSec}s '
            '(有声${voicedMs}ms, ref=${refMs}ms)',
      );
    }

    if (currentSilence >= fallback) {
      AppLogger.log(
        'RetellRec',
        '⏹ 静音兜底停止: '
            '${currentSilence.inMilliseconds}ms ≥ '
            '${fallback.inMilliseconds}ms | '
            '(有声${voicedMs}ms, ref=${refMs}ms)',
      );
      _stopForEvaluation(
        promptId: promptId,
        reason:
            '静音兜底 ${fallback.inSeconds}s '
            '(有声${voicedMs}ms, ref=${refMs}ms)',
      );
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
      AppLogger.log(
        'RetellRec',
        '⏰ ${_awaitingSpeechTimeout.inSeconds}s 未检测到语音 → 退出自动录音',
      );
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
    _speechStartTime ??= DateTime.now();
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = null;

    final effectiveMaxDuration = _isManualMode
        ? _computeManualMaxDuration(_maxRecordingDuration)
        : _maxRecordingDuration;

    AppLogger.log('RetellRec', '🎤 检测到语音');
    AppLogger.log(
      'RetellRec',
      '│ 启动最大录音时长计时器: ${effectiveMaxDuration.inSeconds}s',
    );
    _scheduleMaxDurationTimer(
      promptId: promptId,
      maxDuration: effectiveMaxDuration,
    );
  }

  /// 转录停滞定时器（收紧版）。
  ///
  /// 收紧后只用动态兜底阈值，不再被 A/B/D 内容匹配规则加速。
  /// 语义：长时间没有新转录文字 → 等同于"声学静音兜底"。
  /// A/B 规则的"已说完即停"职责由静音通道（`_checkAutoStopOnSilence`）独立承担。
  ///
  /// 旧逻辑保留在下方注释，方便回滚。
  void _resetTranscriptStaleTimer({
    required String promptId,
    required String referenceText,
    required String transcript,
  }) {
    _transcriptStaleTimer?.cancel();

    final refDur = _referenceDuration;
    final fallback = (refDur != null)
        ? computeRetellDynamicFallback(
            voicedDuration: _voicedDuration,
            referenceDuration: refDur,
          )
        : _silenceTimeout;
    final desc = '转录停滞动态兜底${fallback.inSeconds}s';

    AppLogger.log('RetellRec', '转录停滞阈值 ${fallback.inMilliseconds}ms | $desc');
    _transcriptStaleTimer = Timer(fallback, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != RetellRecordingPhase.recording) return;
      AppLogger.log(
        'RetellRec',
        '⏹ 转录停滞停止: ${fallback.inMilliseconds}ms | $desc',
      );
      _stopForEvaluation(promptId: promptId, reason: '转录停滞($desc)');
    });

    // [旧算法-2026-05-18] 旧逻辑：取规则 D/A/B 最短触发阈值；都未触发再用兜底。
    // 已下线：复述思考时 transcript 不更新，A/B/D 命中后阈值很短（1-5s）会误停。
    // final ctx = buildMatchContext(
    //   referenceText: referenceText,
    //   partialTranscript: transcript,
    // );
    // if (!ctx.hasMatch) return;
    // final ruleD = detectRemainingByPosition(
    //   ctx,
    //   secondsPerWord: 3,
    //   baseSeconds: 2,
    // );
    // Duration? shortest;
    // String? desc;
    // for (final rule in [
    //   ruleD,
    //   detectTailMatch(ctx),
    //   detectOverallMatchRate(ctx),
    // ]) {
    //   if (rule.triggered) {
    //     if (shortest == null || rule.threshold! < shortest) {
    //       shortest = rule.threshold;
    //       desc = rule.description;
    //     }
    //   }
    // }
    // if (shortest == null) { ... 旧兜底分支 ... }
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
      if (state.phase == RetellRecordingPhase.recording) {
        AppLogger.log('RetellRec', '⏰ 最大录音时长 ${maxDuration.inSeconds}s');
        _stopForEvaluation(promptId: promptId, reason: '最大录音时长');
      }
    });
  }

  // ── 自动停止 ──

  void _stopForEvaluation({required String promptId, String reason = ''}) {
    if (_isStopping) return; // 已在停止中，防止重复触发
    AppLogger.log('RetellRec', '⏹ 自动停止录音 ($reason)');
    _isStopping = true;
    _cancelAllTimers();

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
      AppLogger.log('RetellRec', 'App 进入后台 → idle (保留 currentAttempt)');
      _cancelAllTimers();
      _isStopping = false;
      _hasDetectedSpeech = false;
      _lastKnownTranscript = null;
      _lastSilenceLogDesc = null;
      _speechStartTime = null;
      _eventSub?.cancel();
      _eventSub = null;
      // 取消录音但不 await（后台不可靠）
      unawaited(_recordingService.cancelRecording());
      // 保留 currentAttempt（评级 badge）和 permissions
      state = RetellRecordingState(
        permissions: state.permissions,
        currentAttempt: state.currentAttempt,
        awaitingSpeechTimedOut: true, // 阻止回前台后自动开始录音
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

  /// 综合覆盖率和 embedding 相似度，取级别更高的分数。
  ///
  /// 当 embedding 不可用或计算失败时，回退到覆盖率分数。
  Future<double> _bestScore({
    required double coverageScore,
    required String referenceText,
    required String transcript,
  }) async {
    final coverageLevel = _coverageToRatingLevel(coverageScore);
    double? embeddingScore;
    _RatingLevel? embeddingLevel;

    try {
      final similarity = EmbeddingSimilarity(
        backend: TextEmbeddingPlatform.instance,
      );
      if (similarity.isSupported) {
        embeddingScore = await similarity.computeSimilarity(
          referenceText,
          transcript,
        );
        embeddingLevel = _embeddingToRatingLevel(embeddingScore);
      }
    } on Exception catch (e) {
      AppLogger.log('RetellRec', '🧮 Embedding 计算失败: $e');
    }

    final useEmbedding =
        embeddingLevel != null && embeddingLevel.index > coverageLevel.index;
    final effectiveScore = useEmbedding ? embeddingScore! : coverageScore;
    final effectiveLevel = useEmbedding ? embeddingLevel : coverageLevel;

    AppLogger.log(
      'RetellRec',
      '🧮 覆盖率=${coverageScore.toStringAsFixed(2)} (${coverageLevel.name})'
          ', Embedding=${embeddingScore?.toStringAsFixed(2) ?? "N/A"}'
          ' (${embeddingLevel?.name ?? "N/A"})'
          ', 最终=${effectiveScore.toStringAsFixed(2)} (${effectiveLevel.name})',
    );

    return effectiveScore;
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

/// 评分级别，index 越大越好，与 UI 中 _ratingLabel 阈值一致。
enum _RatingLevel {
  keepGoing, // < 0.40
  fair, // >= 0.40
  good, // >= 0.60
  excellent, // >= 0.80
  perfect, // >= 0.95
}

/// 覆盖率 → 评分级别（复述场景阈值）。
///
/// 阈值与 [RatingThresholds.retell] 保持一致。
_RatingLevel _coverageToRatingLevel(double score) {
  const t = RatingThresholds.retell;
  if (score >= t.perfect) return _RatingLevel.perfect;
  if (score >= t.excellent) return _RatingLevel.excellent;
  if (score >= t.good) return _RatingLevel.good;
  if (score >= t.fair) return _RatingLevel.fair;
  return _RatingLevel.keepGoing;
}

/// Embedding cosine similarity → 评分级别。
///
/// cosine similarity 值域偏高，阈值独立于覆盖率。
_RatingLevel _embeddingToRatingLevel(double score) {
  if (score >= 0.90) return _RatingLevel.perfect;
  if (score >= 0.70) return _RatingLevel.excellent;
  if (score >= 0.60) return _RatingLevel.good;
  if (score >= 0.50) return _RatingLevel.fair;
  return _RatingLevel.keepGoing;
}

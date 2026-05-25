/// 跟读录音控制器 provider。
///
/// 独立于复述的 [RetellRecordingController]，专为跟读/难句补练/收藏复习设计。
/// 使用 [RecordingService] 管理录音生命周期，录音结束后自动释放麦克风。
/// 评估仅用覆盖率（[SpeechTranscriptMatcher]），不使用 embedding 相似度。
///
/// 状态机：idle → awaitingSpeech → speaking → [processing →] idle。
/// 有 ASR 时经过 processing（评估转录），无 ASR 时直接 speaking → idle（仅存录音）。
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
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/speech_practice_models.dart';
import '../../services/app_logger.dart';
import '../../services/recording_service.dart';
import '../../services/speech_completion_detector.dart';
import '../../services/speech_practice_matcher.dart';
import '../../services/speech_practice_platform.dart';
import '../../services/study_event_recorder.dart';
import '../offline_asr_settings_provider.dart';

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
enum SpeechRecordingPhase { idle, awaitingSpeech, speaking, processing }

/// 跟读回合状态
class SpeechRecordingState {
  final SpeechRecordingPhase phase;
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

  const SpeechRecordingState({
    this.phase = SpeechRecordingPhase.idle,
    this.promptId,
    this.referenceText,
    this.currentAttempt,
    this.liveTranscript,
    this.hasDetectedSpeech = false,
    this.silenceDuration = Duration.zero,
    this.permissions = const SpeechPracticePermissionState(),
  });

  bool get isActive => phase != SpeechRecordingPhase.idle;

  /// 是否正在录制指定 promptId
  bool isRecordingPrompt(String id) =>
      promptId == id &&
      (phase == SpeechRecordingPhase.awaitingSpeech ||
          phase == SpeechRecordingPhase.speaking);

  SpeechRecordingState copyWith({
    SpeechRecordingPhase? phase,
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
    return SpeechRecordingState(
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
  /// 三条规则取最小值，无规则触发时返回兜底阈值。
  Duration computeSilenceThreshold({
    required String referenceText,
    required String partialTranscript,
    Duration? voicedDuration,
    Duration? referenceDuration,
  }) {
    return computeSilenceThresholdDetailed(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
      voicedDuration: voicedDuration,
      referenceDuration: referenceDuration,
    ).threshold!;
  }

  /// 与 [computeSilenceThreshold] 逻辑一致，额外返回触发原因（用于调试日志）。
  ///
  /// 四条规则取最小值：
  /// D. [detectRemainingByPosition] — 剩余词数估算阈值
  /// A. [detectTailMatch] — 连续尾部匹配 + 唯一 → 1s
  /// B. [detectOverallMatchRate] — 全句匹配率 → 1-3s
  /// C. [detectTailHitCount] — 末尾 5 词命中数 → 1-5s
  ///
  /// 无规则触发时，兜底阈值根据有声时长比例动态计算（需传入
  /// [voicedDuration] 和 [referenceDuration]），否则固定 5s。
  DetectionResult computeSilenceThresholdDetailed({
    required String referenceText,
    required String partialTranscript,
    Duration? voicedDuration,
    Duration? referenceDuration,
  }) {
    final ctx = buildMatchContext(
      referenceText: referenceText,
      partialTranscript: partialTranscript,
    );

    // 计算动态兜底阈值
    final fallback = (voicedDuration != null && referenceDuration != null)
        ? computeDynamicFallback(
            voicedDuration: voicedDuration,
            referenceDuration: referenceDuration,
            matchRate: ctx.matchRate,
          )
        : _defaultSilenceThreshold;

    if (!ctx.hasMatch) {
      return DetectionResult(
        threshold: fallback,
        description: '无匹配, 兜底${fallback.inSeconds}s',
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
      fallback: fallback,
    );
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

// ============================================================
// SpeechRecordingController — 跟读专用录音控制器
// ============================================================

/// 跟读录音控制器 provider
final speechRecordingControllerProvider =
    NotifierProvider<SpeechRecordingController, SpeechRecordingState>(
      SpeechRecordingController.new,
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
class SpeechRecordingController extends Notifier<SpeechRecordingState> {
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

  /// 首次检测到语音的时间（用于计算有效说话时长）
  DateTime? _speechStartTime;
  String? _cachedReferenceText;
  String? _lastSilenceLogDesc;

  /// 原句音频时长（用于有声时长比例兜底）
  Duration? _referenceDuration;

  /// 累计有声时长（silenceMs == 0 区间的加总）
  Duration _voicedDuration = Duration.zero;

  /// 上一次有声事件的时间戳（用于累加有声时长）
  DateTime? _lastVoicedTimestamp;

  // ── 配置 ──
  bool _isManualMode = false;

  /// 自动模式最大录音时长（检测到语音后启动）
  Duration _maxRecordingDuration = _defaultMaxRecordingDuration;

  @override
  SpeechRecordingState build() {
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
    return const SpeechRecordingState();
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
    Duration? referenceDuration,
  }) async {
    final backend = ref.read(speechPracticeBackendProvider);
    if (state.promptId == promptId && state.isActive) {
      AppLogger.log('SpeechRec', '⏭ startRecording 跳过: 已在录音中 ($promptId)');
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

    AppLogger.log('SpeechRec', '┌ startRecording (manual=$_isManualMode)');
    AppLogger.log('SpeechRec', '│ promptId=$promptId');
    AppLogger.log(
      'SpeechRec',
      '│ backend=${backend.runtimeType} permissions=${state.permissions.microphone.name}/${state.permissions.speech.name}',
    );

    state = SpeechRecordingState(
      phase: SpeechRecordingPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      permissions: state.permissions,
    );

    try {
      final asrSettings = ref.read(offlineAsrSettingsProvider);
      await _recordingService.startRecording(
        promptId: promptId,
        recognitionEnabled:
            asrSettings.enabled && asrSettings.backend == AsrBackend.platform,
      );
      _eventSub?.cancel();
      _eventSub = _recordingService.events.listen(_handleRecordingEvent);

      state = state.copyWith(permissions: _recordingService.permissions);
    } on SpeechPracticePlatformException catch (error) {
      AppLogger.log('SpeechRec', '└ 录音启动失败: ${error.code} → idle');
      state = state.copyWith(
        phase: SpeechRecordingPhase.idle,
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
        'SpeechRec',
        '│ 手动模式兜底 ${_manualModeInitialMax.inSeconds}s',
      );
      _scheduleMaxDurationTimer(
        promptId: promptId,
        maxDuration: _manualModeInitialMax,
      );
    } else {
      // 自动模式：启动 60s 等待开口计时器
      AppLogger.log(
        'SpeechRec',
        '│ 启动 ${_awaitingSpeechTimeout.inSeconds}s 等待开口计时器',
      );
      _scheduleAwaitingSpeechTimer(promptId);
    }

    AppLogger.log('SpeechRec', '└ 录音已开始，等待用户开口...');
  }

  /// 手动停止录音并评估
  Future<void> stopAndEvaluate({required String referenceText}) async {
    final promptId = state.promptId;
    if (promptId == null) return;

    AppLogger.log('SpeechRec', '● 手动停止录音');
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
      phase: SpeechRecordingPhase.idle,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  // ========== 清理方法 ==========

  /// 清除当前回合状态（保留配置），并删除已完成录音的临时文件。
  Future<void> clearRecording() async {
    AppLogger.log('SpeechRec', '● clearRecording → idle');
    _cancelAllTimers();
    _isStopping = false;
    _hasDetectedSpeech = false;
    _lastKnownTranscript = null;
    _eventSub?.cancel();
    _eventSub = null;
    // 先读取文件路径，再立即重置状态（避免 await 延迟状态重置导致自动录音触发失败）
    final filePath = state.currentAttempt?.filePath;
    state = SpeechRecordingState(permissions: state.permissions);
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

  /// 停止录音并评估。
  ///
  /// 停止录音 → processing → 等待转录 → 评估 → idle。
  ///
  /// 三个清晰阶段：
  /// 1. stopSession — 立即停止录音
  /// 2. processing — ASR 启用时显示"分析中..."
  /// 3. waitForTranscript + evaluate — 等待转录并评估
  Future<void> _doStopAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async {
    final backend = ref.read(speechPracticeBackendProvider);
    final asrEnabled = ref.read(offlineAsrSettingsProvider).enabled;
    _cancelAllTimers();
    await _eventSub?.cancel();
    _eventSub = null;

    // 记录有效说话时长（开口 → 停止 - 尾部静音）
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
    AppLogger.log('SpeechRec', '│ backend=${backend.runtimeType}');

    if (stopResult.errorCode != null || filePath == null || filePath.isEmpty) {
      AppLogger.log('SpeechRec', '✗ 停止录音失败: ${stopResult.errorCode}');
      state = state.copyWith(
        phase: SpeechRecordingPhase.idle,
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

    // ── ASR 关闭：直接存录音，不等转录 ──
    if (!asrEnabled) {
      AppLogger.log('SpeechRec', '● ASR 关闭，保留录音，跳过转录');
      await _recordingService.shutdown();
      state = state.copyWith(
        phase: SpeechRecordingPhase.idle,
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

    // ── 阶段 2：进入 processing（显示"分析中..."）──
    _enterProcessing(promptId);

    // ── 阶段 3：等待转录结果 ──
    final result = await _recordingService.waitForTranscript(
      filePath: filePath,
    );
    AppLogger.log(
      'SpeechRec',
      '│ transcript filePath=${filePath} '
          'finalLen=${result.finalTranscript?.trim().length ?? 0} '
          'errorCode=${result.errorCode ?? '(null)'}',
    );
    AppLogger.log(
      'SpeechRec',
      '📋 final: "${result.finalTranscript ?? '(null)'}"',
    );

    // 判断是否有可用的转录结果（final 或 live）
    final hasTranscript =
        (result.isSuccess &&
            (result.finalTranscript?.trim().isNotEmpty ?? false)) ||
        (_lastKnownTranscript != null &&
            _lastKnownTranscript!.trim().isNotEmpty);

    if (hasTranscript) {
      _evaluateResult(
        promptId: promptId,
        referenceText: referenceText,
        result: result,
      );
    } else {
      AppLogger.log('SpeechRec', '✗ 无转录结果，保留录音');
      state = state.copyWith(
        phase: SpeechRecordingPhase.idle,
        currentAttempt: SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: filePath,
          status: SpeechPracticeAttemptStatus.unavailable,
          score: 0,
        ),
        clearLiveTranscript: true,
        hasDetectedSpeech: false,
        silenceDuration: Duration.zero,
      );
    }
  }

  /// 同步评估录音结果并更新状态。
  void _evaluateResult({
    required String promptId,
    required String referenceText,
    required RecordingResult result,
  }) {
    if (!result.isSuccess) {
      // Final transcript 失败但有 live transcript → 用 live transcript 做评估
      final fallbackTranscript = _lastKnownTranscript;
      if (fallbackTranscript != null && fallbackTranscript.isNotEmpty) {
        AppLogger.log(
          'SpeechRec',
          '⚠ final transcript 失败 (${result.errorCode})，'
              '用 live transcript 评估: "$fallbackTranscript"',
        );
      } else {
        final attempt = SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: result.filePath,
          status: _statusFromError(result.errorCode),
          errorMessage: result.errorMessage,
        );
        AppLogger.log('SpeechRec', '✗ 识别失败: ${result.errorCode ?? 'unknown'}');
        state = state.copyWith(
          phase: SpeechRecordingPhase.idle,
          currentAttempt: attempt,
          clearLiveTranscript: true,
          hasDetectedSpeech: false,
          silenceDuration: Duration.zero,
        );
        return;
      }
    }

    // 评估：仅覆盖率（优先用 final transcript，fallback 用 live transcript）
    final transcript = result.finalTranscript ?? _lastKnownTranscript ?? '';
    AppLogger.log(
      'SpeechRec',
      '│ evaluate transcriptLen=${transcript.trim().length} '
          'liveLen=${(_lastKnownTranscript ?? '').trim().length}',
    );
    final matcher = ref.read(speechTranscriptMatcherProvider);
    final matchResult = matcher.evaluate(
      referenceText: referenceText,
      transcript: transcript,
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

    if (attempt.isRecognitionFailure) {
      AppLogger.log(
        'SpeechRec',
        '✗ 识别失败: status=${attempt.status.name}, final="${attempt.finalTranscript ?? ''}"',
      );
    }

    AppLogger.log(
      'SpeechRec',
      '✓ 评估完成: '
          'status=${attempt.status.name}, '
          'score=${attempt.score?.toStringAsFixed(2)}, '
          'matched=${attempt.matchedTokenCount}/${attempt.totalTargetTokenCount}',
    );

    state = state.copyWith(
      phase: SpeechRecordingPhase.idle,
      currentAttempt: attempt,
      clearLiveTranscript: true,
      hasDetectedSpeech: false,
      silenceDuration: Duration.zero,
    );
  }

  void _enterProcessing(String promptId) {
    if (state.promptId != promptId) return;
    _cancelAllTimers();
    state = state.copyWith(phase: SpeechRecordingPhase.processing);
  }

  // ── 事件处理 ──

  void _handleRecordingEvent(SpeechPracticeEvent event) {
    final promptId = state.promptId;
    if (promptId == null || event.promptId != promptId) return;
    if (_isStopping) return;
    if (state.phase != SpeechRecordingPhase.awaitingSpeech &&
        state.phase != SpeechRecordingPhase.speaking) {
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
      AppLogger.log('SpeechRec', '📝 live: "$text"');
    }
    state = state.copyWith(
      liveTranscript: text,
      silenceDuration: Duration.zero,
    );

    _checkSpeechAndAutoStop(text);
  }

  void _handleSpeechStarted(SpeechPracticeEvent event) {
    _speechStartTime ??= DateTime.now();
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

    final liveTranscript = state.liveTranscript?.trim() ?? '';
    final referenceText = _cachedReferenceText;
    if (referenceText == null) return;

    // ── 通道 1：声学静音 + 启发式 ──
    if (currentSilence > Duration.zero && liveTranscript.isNotEmpty) {
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      final detailed = heuristic.computeSilenceThresholdDetailed(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
        voicedDuration: _voicedDuration,
        referenceDuration: _referenceDuration,
      );
      final required = detailed.threshold!;
      if (detailed.description != _lastSilenceLogDesc) {
        _lastSilenceLogDesc = detailed.description;
        AppLogger.log(
          'SpeechRec',
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

    // 静音兜底（无转录时，含无 ASR 场景）
    final refDur = _referenceDuration;
    final fallback = (refDur != null)
        ? computeDynamicFallback(
            voicedDuration: _voicedDuration,
            referenceDuration: refDur,
          )
        : _defaultSilenceThreshold;
    if (currentSilence >= fallback) {
      final ratioDesc = (refDur != null && refDur > Duration.zero)
          ? ', ratio=${(_voicedDuration.inMilliseconds / (refDur.inMilliseconds * 1.1) * 100).toStringAsFixed(0)}%'
          : '';
      _stopForEvaluation(
        promptId: promptId,
        reason:
            '静音兜底 ${fallback.inSeconds}s '
            '(有声${_voicedDuration.inMilliseconds}ms, '
            'ref=${refDur?.inMilliseconds ?? 0}ms$ratioDesc)',
      );
    }
  }

  // ── 等待开口计时器 ──

  /// 60s 内未检测到语音 → 取消录音，回到 idle。
  void _scheduleAwaitingSpeechTimer(String promptId) {
    _awaitingSpeechTimer?.cancel();
    _awaitingSpeechTimer = Timer(_awaitingSpeechTimeout, () async {
      if (state.promptId != promptId ||
          state.phase != SpeechRecordingPhase.awaitingSpeech) {
        return;
      }
      AppLogger.log(
        'SpeechRec',
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
    if (state.phase == SpeechRecordingPhase.awaitingSpeech) {
      AppLogger.log('SpeechRec', '🎤 检测到语音 → speaking');
      state = state.copyWith(phase: SpeechRecordingPhase.speaking);
    }

    final effectiveMaxDuration = _isManualMode
        ? _computeManualMaxDuration(_maxRecordingDuration)
        : _maxRecordingDuration;

    AppLogger.log(
      'SpeechRec',
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
      voicedDuration: _voicedDuration,
      referenceDuration: _referenceDuration,
    );
    final threshold = detailed.threshold!;
    AppLogger.log(
      'SpeechRec',
      '转录停滞阈值 ${threshold.inMilliseconds}ms | '
          '${detailed.description}',
    );
    _transcriptStaleTimer = Timer(threshold, () {
      if (state.promptId != promptId || _isStopping) return;
      if (state.phase != SpeechRecordingPhase.speaking) return;
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
      if (state.phase == SpeechRecordingPhase.awaitingSpeech ||
          state.phase == SpeechRecordingPhase.speaking) {
        AppLogger.log('SpeechRec', '⏰ 最大录音时长 ${maxDuration.inSeconds}s');
        _stopForEvaluation(promptId: promptId, reason: '最大录音时长');
      }
    });
  }

  // ── 自动停止 ──

  void _stopForEvaluation({required String promptId, String reason = ''}) {
    AppLogger.log('SpeechRec', '⏹ 自动停止录音 ($reason)');
    _isStopping = true;
    _cancelAllTimers();

    final referenceText = _cachedReferenceText;
    if (referenceText == null) {
      AppLogger.log('SpeechRec', '⚠ 无法获取 referenceText');
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
      AppLogger.log('SpeechRec', 'App 进入后台 → idle');
      _cancelAllTimers();
      _isStopping = false;
      _hasDetectedSpeech = false;
      _lastKnownTranscript = null;
      _lastSilenceLogDesc = null;
      _eventSub?.cancel();
      _eventSub = null;
      unawaited(_recordingService.cancelRecording());
      // 保留 currentAttempt（评级 badge）和 permissions
      state = SpeechRecordingState(
        phase: SpeechRecordingPhase.idle,
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

/// 跟读回合状态机 provider。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/speech_practice_models.dart';
import 'learning_session/listen_and_repeat_player_provider.dart';
import 'speech_practice_session_provider.dart';

const _awaitingSpeechReminderDelay = Duration(seconds: 5);
const _awaitingSpeechFallbackDelay = Duration(seconds: 15);
const _silenceCompletionCheckDelay = Duration(seconds: 1);
const _silenceAutoStopDelay = Duration(seconds: 5);
const _maxRecordingMultiplier = 2.5;
const _maxRecordingBuffer = Duration(seconds: 5);
const _maxRecordingFloor = Duration(seconds: 10);
const _reviewCountdownDuration = Duration(seconds: 5);
const _fairScoreThreshold = 0.45;
const _autoRetryDelay = Duration(seconds: 4);
const _maxConsecutiveFailures = 3;
const _uniqueTailScoreThreshold = 0.40;
const _nonUniqueTailScoreThreshold = 0.60;

enum ListenAndRepeatTurnPhase {
  idle,
  awaitingSpeech,
  speaking,
  processing,
  reviewCountdown,

  /// 评级未达 Fair，短暂展示反馈后自动重新录音。
  retryPending,
  manualFallback,
}

class ListenAndRepeatTurnState {
  final ListenAndRepeatTurnPhase phase;
  final String? promptId;
  final String? referenceText;
  final bool hasShownSpeechReminder;
  final Duration reviewCountdownRemaining;
  final bool isReviewCountdownPaused;

  const ListenAndRepeatTurnState({
    this.phase = ListenAndRepeatTurnPhase.idle,
    this.promptId,
    this.referenceText,
    this.hasShownSpeechReminder = false,
    this.reviewCountdownRemaining = _reviewCountdownDuration,
    this.isReviewCountdownPaused = false,
  });

  bool get isActive =>
      phase != ListenAndRepeatTurnPhase.idle &&
      phase != ListenAndRepeatTurnPhase.manualFallback &&
      phase != ListenAndRepeatTurnPhase.retryPending;

  ListenAndRepeatTurnState copyWith({
    ListenAndRepeatTurnPhase? phase,
    String? promptId,
    bool clearPromptId = false,
    String? referenceText,
    bool clearReferenceText = false,
    bool? hasShownSpeechReminder,
    Duration? reviewCountdownRemaining,
    bool? isReviewCountdownPaused,
  }) {
    return ListenAndRepeatTurnState(
      phase: phase ?? this.phase,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      referenceText: clearReferenceText
          ? null
          : (referenceText ?? this.referenceText),
      hasShownSpeechReminder:
          hasShownSpeechReminder ?? this.hasShownSpeechReminder,
      reviewCountdownRemaining:
          reviewCountdownRemaining ?? this.reviewCountdownRemaining,
      isReviewCountdownPaused:
          isReviewCountdownPaused ?? this.isReviewCountdownPaused,
    );
  }
}

class SpeechPracticeCompletionHeuristic {
  const SpeechPracticeCompletionHeuristic();

  static final RegExp _englishWordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");

  /// 判断用户是否已读完参考句。
  ///
  /// 算法：
  /// 1. LCS 匹配，计算 score = 匹配数 / reference 词数
  /// 2. 从 reference 末尾往前数连续匹配长度 N（N=0 直接返回 false）
  /// 3. 检查尾部 N 个词在 reference 中是否唯一出现
  /// 4. 唯一 → score >= 0.40 判定完成；非唯一 → score >= 0.60
  bool isLikelyComplete({
    required String referenceText,
    required String partialTranscript,
  }) {
    final referenceTokens = _tokenize(referenceText);
    final transcriptTokens = _tokenize(partialTranscript);
    if (referenceTokens.isEmpty || transcriptTokens.isEmpty) {
      return false;
    }

    final lcsPairs = _computeLcsPairs(referenceTokens, transcriptTokens);
    if (lcsPairs.isEmpty) {
      return false;
    }

    final score = lcsPairs.length / referenceTokens.length;

    // 从 reference 末尾往前数，连续多少个词都在 LCS 匹配中
    final matchedRefIndexes = lcsPairs.map((pair) => pair.$1).toSet();
    var tailMatchLength = 0;
    for (var i = referenceTokens.length - 1; i >= 0; i--) {
      if (matchedRefIndexes.contains(i)) {
        tailMatchLength++;
      } else {
        break;
      }
    }

    // 句尾完全没匹配，不可能读完
    if (tailMatchLength == 0) {
      return false;
    }

    // 检查尾部 N 个词组合在 reference 中是否唯一
    final tailStart = referenceTokens.length - tailMatchLength;
    final isTailUnique = _isSubsequenceUnique(referenceTokens, tailStart);

    final threshold = isTailUnique
        ? _uniqueTailScoreThreshold
        : _nonUniqueTailScoreThreshold;
    return score >= threshold;
  }

  /// 检查 [tokens] 从 [start] 到末尾的连续子序列在 [tokens] 中是否只出现一次。
  bool _isSubsequenceUnique(List<String> tokens, int start) {
    final tail = tokens.sublist(start);
    final tailLength = tail.length;
    var count = 0;
    for (var i = 0; i <= tokens.length - tailLength; i++) {
      var match = true;
      for (var j = 0; j < tailLength; j++) {
        if (tokens[i + j] != tail[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        count++;
        if (count > 1) return false;
      }
    }
    return count == 1;
  }

  List<String> _tokenize(String text) {
    return _englishWordPattern
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  List<(int, int)> _computeLcsPairs(
    List<String> referenceTokens,
    List<String> transcriptTokens,
  ) {
    final rows = referenceTokens.length + 1;
    final cols = transcriptTokens.length + 1;
    final dp = List.generate(rows, (_) => List.filled(cols, 0));

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final pairs = <(int, int)>[];
    var i = referenceTokens.length;
    var j = transcriptTokens.length;
    while (i > 0 && j > 0) {
      if (referenceTokens[i - 1] == transcriptTokens[j - 1]) {
        pairs.add((i - 1, j - 1));
        i -= 1;
        j -= 1;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i -= 1;
      } else {
        j -= 1;
      }
    }
    return pairs.reversed.toList();
  }
}

final speechPracticeCompletionHeuristicProvider =
    Provider<SpeechPracticeCompletionHeuristic>((ref) {
      return const SpeechPracticeCompletionHeuristic();
    });

final listenAndRepeatTurnControllerProvider =
    NotifierProvider<ListenAndRepeatTurnController, ListenAndRepeatTurnState>(
      ListenAndRepeatTurnController.new,
    );

class ListenAndRepeatTurnController extends Notifier<ListenAndRepeatTurnState> {
  Timer? _speechReminderTimer;
  Timer? _speechFallbackTimer;
  Timer? _reviewTickTimer;
  Timer? _maxDurationTimer;
  Timer? _autoRetryTimer;
  Duration _sentenceDuration = Duration.zero;
  int _consecutiveFailureCount = 0;
  bool _isStopping = false;

  @override
  ListenAndRepeatTurnState build() {
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _cancelAllTimers();
    });
    ref.listen<SpeechPracticeSessionState>(
      speechPracticeSessionProvider,
      _handleSpeechPracticeStateChanged,
    );
    return const ListenAndRepeatTurnState();
  }

  Future<void> ensureTurn({
    required String promptId,
    required String referenceText,
    bool allowAutoFallback = true,
    Duration sentenceDuration = Duration.zero,
  }) async {
    if (state.promptId == promptId && state.isActive) {
      return;
    }

    _cancelAllTimers();
    _isStopping = false;
    _sentenceDuration = sentenceDuration;
    state = ListenAndRepeatTurnState(
      phase: ListenAndRepeatTurnPhase.awaitingSpeech,
      promptId: promptId,
      referenceText: referenceText,
      reviewCountdownRemaining: _reviewCountdownDuration,
    );

    final session = ref.read(speechPracticeSessionProvider.notifier);
    await session.startRecording(promptId: promptId);
    final currentAttempt = ref
        .read(speechPracticeSessionProvider.notifier)
        .attemptFor(promptId);
    if (currentAttempt?.status != SpeechPracticeAttemptStatus.recording) {
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
      return;
    }

    _scheduleMaxDurationTimer(
      promptId: promptId,
      referenceText: referenceText,
      sentenceDuration: sentenceDuration,
    );

    if (allowAutoFallback) {
      _scheduleAwaitingSpeechTimers(promptId);
    }
  }

  /// 自动跟读回合开始：启动录音并启用提醒与回退。
  Future<void> ensureAutoTurn({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: true,
      sentenceDuration: sentenceDuration,
    );
  }

  /// 手动回退后的重新录音：仍然使用同一状态机，但不再显示 5/15 秒自动提醒。
  Future<void> startManualRecording({
    required String promptId,
    required String referenceText,
    Duration sentenceDuration = Duration.zero,
  }) {
    return ensureTurn(
      promptId: promptId,
      referenceText: referenceText,
      allowAutoFallback: false,
      sentenceDuration: sentenceDuration,
    );
  }

  void enterProcessing(String promptId) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.processing);
  }

  Future<void> handleManualStop() async {
    final promptId = state.promptId;
    final referenceText = state.referenceText;
    if (promptId == null || referenceText == null) {
      return;
    }
    _isStopping = true;
    enterProcessing(promptId);
    await ref
        .read(speechPracticeSessionProvider.notifier)
        .stopRecordingAndEvaluate(
          promptId: promptId,
          referenceText: referenceText,
        );
  }

  Future<void> handleContinue() async {
    _cancelReviewCountdown();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.idle);
    await ref.read(listenAndRepeatPlayerProvider.notifier).completePausedTurn();
  }

  void pauseReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(isReviewCountdownPaused: true);
  }

  void resumeReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (state.reviewCountdownRemaining <= Duration.zero) {
      unawaited(handleContinue());
      return;
    }
    state = state.copyWith(isReviewCountdownPaused: false);
    _startReviewCountdown();
  }

  /// 快进倒计时：立即跳过，进入下一句。
  void fastForwardReviewCountdown() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    unawaited(handleContinue());
  }

  void resetReviewCountdownOnPlayback() {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    _reviewTickTimer?.cancel();
    state = state.copyWith(
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: true,
    );
  }

  void activateReviewCountdown({required String promptId}) {
    if (state.promptId != promptId) {
      return;
    }
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    state = state.copyWith(
      phase: ListenAndRepeatTurnPhase.reviewCountdown,
      reviewCountdownRemaining: _reviewCountdownDuration,
      isReviewCountdownPaused: false,
    );
    _startReviewCountdown();
  }

  /// App 进入后台时清理 turn，停止所有定时器。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      clearTurn();
    }
  }

  void clearTurn() {
    _cancelAllTimers();
    _isStopping = false;
    _consecutiveFailureCount = 0;
    state = const ListenAndRepeatTurnState();
  }

  void _handleSpeechPracticeStateChanged(
    SpeechPracticeSessionState? previous,
    SpeechPracticeSessionState next,
  ) {
    final promptId = state.promptId;
    if (promptId == null) {
      return;
    }
    final previousAttempt = previous?.attempts[promptId];
    final attempt = next.attempts[promptId];
    if (attempt == null) {
      return;
    }

    _handleAttemptPlaybackChanged(
      previousPlayingPromptId: previous?.playingPromptId,
      nextPlayingPromptId: next.playingPromptId,
      promptId: promptId,
    );

    if (attempt.status == SpeechPracticeAttemptStatus.awaitingFinal) {
      enterProcessing(promptId);
      return;
    }

    if (attempt.hasFinalFeedback &&
        !(previousAttempt?.hasFinalFeedback ?? false)) {
      // 权限被拒或平台不可用时回退为手动录音，重试也无法解决
      if (attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable) {
        _cancelAllTimers();
        state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
        return;
      }
      // 检测失败、识别错误或评级未达 Fair 时自动重试
      final isFailed =
          attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          (attempt.score ?? 0) < _fairScoreThreshold;
      if (isFailed) {
        _consecutiveFailureCount++;
        if (_consecutiveFailureCount >= _maxConsecutiveFailures) {
          _consecutiveFailureCount = 0;
          _cancelAllTimers();
          state = state.copyWith(
            phase: ListenAndRepeatTurnPhase.manualFallback,
          );
        } else {
          _scheduleAutoRetry(promptId: promptId);
        }
      } else {
        _consecutiveFailureCount = 0;
        activateReviewCountdown(promptId: promptId);
      }
      return;
    }

    // VAD 检测到语音，或 ASR 已产出文字（用户压低声音时 VAD 可能不触发）
    final hasVoiceInput = attempt.hasDetectedSpeech ||
        (attempt.liveTranscript?.trim().isNotEmpty ?? false);

    if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech &&
        hasVoiceInput) {
      _cancelAwaitingSpeechTimers();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.speaking);
    }

    if (state.phase == ListenAndRepeatTurnPhase.speaking && !_isStopping) {
      _handleSpeakingAttemptUpdate(
        promptId: promptId,
        attempt: attempt,
        previousAttempt: previousAttempt,
      );
    }
  }

  void _scheduleAwaitingSpeechTimers(String promptId) {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = Timer(_awaitingSpeechReminderDelay, () {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      state = state.copyWith(hasShownSpeechReminder: true);
    });
    _speechFallbackTimer = Timer(_awaitingSpeechFallbackDelay, () async {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.awaitingSpeech) {
        return;
      }
      await ref
          .read(speechPracticeSessionProvider.notifier)
          .cancelActiveRecording();
      state = state.copyWith(phase: ListenAndRepeatTurnPhase.manualFallback);
    });
  }

  void _handleSpeakingAttemptUpdate({
    required String promptId,
    required SpeechPracticeAttempt attempt,
    required SpeechPracticeAttempt? previousAttempt,
  }) {
    final prompt = state.promptId;
    final referenceText = state.referenceText;
    if (prompt != promptId || referenceText == null) {
      return;
    }

    final currentSilence = attempt.silenceDuration;
    final previousSilence = previousAttempt?.silenceDuration ?? Duration.zero;
    if (!attempt.hasDetectedSpeech) {
      return;
    }

    if (currentSilence >= _silenceAutoStopDelay &&
        previousSilence < _silenceAutoStopDelay) {
      _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      return;
    }

    if (currentSilence >= _silenceCompletionCheckDelay &&
        previousSilence < _silenceCompletionCheckDelay) {
      final liveTranscript = attempt.liveTranscript?.trim() ?? '';
      if (liveTranscript.isEmpty) {
        return;
      }
      final heuristic = ref.read(speechPracticeCompletionHeuristicProvider);
      if (heuristic.isLikelyComplete(
        referenceText: referenceText,
        partialTranscript: liveTranscript,
      )) {
        _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      }
    }
  }

  void _handleAttemptPlaybackChanged({
    required String? previousPlayingPromptId,
    required String? nextPlayingPromptId,
    required String promptId,
  }) {
    if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown) {
      return;
    }
    if (previousPlayingPromptId != promptId &&
        nextPlayingPromptId == promptId) {
      resetReviewCountdownOnPlayback();
      return;
    }
    if (previousPlayingPromptId == promptId &&
        nextPlayingPromptId != promptId) {
      state = state.copyWith(
        reviewCountdownRemaining: _reviewCountdownDuration,
        isReviewCountdownPaused: false,
      );
      _startReviewCountdown();
    }
  }

  void _startReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (state.phase != ListenAndRepeatTurnPhase.reviewCountdown ||
          state.isReviewCountdownPaused) {
        return;
      }
      final nextRemaining =
          state.reviewCountdownRemaining - const Duration(milliseconds: 100);
      if (nextRemaining <= Duration.zero) {
        timer.cancel();
        state = state.copyWith(reviewCountdownRemaining: Duration.zero);
        await handleContinue();
        return;
      }
      state = state.copyWith(reviewCountdownRemaining: nextRemaining);
    });
  }

  void _stopForEvaluation({
    required String promptId,
    required String referenceText,
  }) {
    _isStopping = true;
    enterProcessing(promptId);
    unawaited(
      ref
          .read(speechPracticeSessionProvider.notifier)
          .stopRecordingAndEvaluate(
            promptId: promptId,
            referenceText: referenceText,
          ),
    );
  }

  void _cancelAwaitingSpeechTimers() {
    _speechReminderTimer?.cancel();
    _speechFallbackTimer?.cancel();
    _speechReminderTimer = null;
    _speechFallbackTimer = null;
  }

  void _cancelReviewCountdown() {
    _reviewTickTimer?.cancel();
    _reviewTickTimer = null;
  }

  /// 评级未达 Fair 时短暂展示反馈，然后自动重新开始录音。
  void _scheduleAutoRetry({required String promptId}) {
    _cancelAllTimers();
    state = state.copyWith(phase: ListenAndRepeatTurnPhase.retryPending);
    _autoRetryTimer = Timer(_autoRetryDelay, () {
      if (state.promptId != promptId ||
          state.phase != ListenAndRepeatTurnPhase.retryPending) {
        return;
      }
      final referenceText = state.referenceText;
      if (referenceText == null) return;
      unawaited(
        ensureTurn(
          promptId: promptId,
          referenceText: referenceText,
          allowAutoFallback: false,
          sentenceDuration: _sentenceDuration,
        ),
      );
    });
  }

  /// 启动录音最大时长兜底计时器。
  ///
  /// 超时后静默停止录音并正常评分，用户无感知。
  void _scheduleMaxDurationTimer({
    required String promptId,
    required String referenceText,
    required Duration sentenceDuration,
  }) {
    _maxDurationTimer?.cancel();
    final maxDuration = _computeMaxRecordingDuration(sentenceDuration);
    _maxDurationTimer = Timer(maxDuration, () {
      if (state.promptId != promptId) return;
      if (state.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
          state.phase == ListenAndRepeatTurnPhase.speaking) {
        _stopForEvaluation(promptId: promptId, referenceText: referenceText);
      }
    });
  }

  /// 计算录音最大时长：`max(2.5 × sentenceDuration + 5s, 10s)`。
  Duration _computeMaxRecordingDuration(Duration sentenceDuration) {
    final computed =
        sentenceDuration * _maxRecordingMultiplier + _maxRecordingBuffer;
    return computed < _maxRecordingFloor ? _maxRecordingFloor : computed;
  }

  void _cancelAllTimers() {
    _cancelAwaitingSpeechTimers();
    _cancelReviewCountdown();
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
  }
}

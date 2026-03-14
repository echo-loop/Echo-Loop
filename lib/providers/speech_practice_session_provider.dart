/// 跟读录音识别会话 Provider。
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/speech_practice_models.dart';
import '../services/speech_practice_matcher.dart';
import '../services/speech_practice_platform.dart';

const _finalTranscriptTimeout = Duration(seconds: 5);

/// 统一后端 provider。
final speechPracticeBackendProvider = Provider<SpeechPracticeBackend>((ref) {
  return SpeechPracticePlatform.instance;
});

/// 文本匹配器 provider。
final speechTranscriptMatcherProvider = Provider<SpeechTranscriptMatcher>((
  ref,
) {
  return SpeechTranscriptMatcher();
});

/// 跟读录音识别会话 provider。
final speechPracticeSessionProvider =
    NotifierProvider<SpeechPracticeSession, SpeechPracticeSessionState>(
      SpeechPracticeSession.new,
    );

/// 管理当前学习阶段内的录音、识别、回放和临时文件清理。
class SpeechPracticeSession extends Notifier<SpeechPracticeSessionState> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<SpeechPracticeEvent>? _eventSub;
  Completer<SpeechPracticeEvent>? _finalEventCompleter;
  String? _finalEventPromptId;

  @override
  SpeechPracticeSessionState build() {
    final backend = ref.read(speechPracticeBackendProvider);
    if (backend.isSupported) {
      _eventSub = backend.events.listen(_handleSpeechEvent);
      unawaited(backend.warmup());
    }

    // App 回前台时刷新权限缓存，覆盖用户在系统设置中撤销权限的场景。
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );

    ref.onDispose(() async {
      lifecycleListener.dispose();
      await _eventSub?.cancel();
      await _disposePlayer();
      if (backend.isSupported) {
        await backend.shutdown();
      }
    });
    return const SpeechPracticeSessionState();
  }

  /// App 生命周期变化回调：回前台时刷新权限，进后台时停止录音。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      unawaited(ensurePermissions());
    } else if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      unawaited(cancelActiveRecording());
    }
  }

  /// 获取当前句子的录音结果。
  SpeechPracticeAttempt? attemptFor(String promptId) =>
      state.attempts[promptId];

  /// 是否正在录当前句子。
  bool isRecordingPrompt(String promptId) =>
      state.recordingPromptId == promptId;

  /// 确保已获取麦克风与语音识别权限。
  Future<bool> ensurePermissions() async {
    final backend = ref.read(speechPracticeBackendProvider);
    if (!backend.isSupported) {
      return false;
    }

    var permissions = await backend.getPermissionStatus();
    if (!permissions.isGranted) {
      permissions = await backend.requestPermissions();
    }
    state = state.copyWith(permissions: permissions);
    return permissions.isGranted;
  }

  /// 开始录音。
  ///
  /// 优化：已缓存 granted 时跳过 MethodChannel 权限查询；
  /// 无活跃回放时跳过 stopAttemptPlayback。
  Future<void> startRecording({required String promptId}) async {
    final backend = ref.read(speechPracticeBackendProvider);

    // 仅在有活跃回放时才 stop，省掉一次空 await。
    if (state.playingPromptId != null) {
      await stopAttemptPlayback();
    }

    if (!backend.isSupported) {
      _setAttemptState(
        promptId,
        SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: SpeechPracticeAttemptStatus.unavailable,
          errorMessage: 'Speech practice is unavailable on this platform.',
        ),
      );
      return;
    }

    // 优化：已缓存 granted → 跳过 MethodChannel 调用。
    bool granted;
    if (state.permissions.isGranted) {
      granted = true;
    } else {
      try {
        granted = await ensurePermissions();
      } on SpeechPracticePlatformException catch (error) {
        _setAttemptState(
          promptId,
          SpeechPracticeAttempt(promptId: promptId).copyWith(
            status: _statusFromError(error.code),
            errorMessage: error.message,
          ),
        );
        return;
      }
    }
    if (!granted) {
      _setAttemptState(
        promptId,
        SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: SpeechPracticeAttemptStatus.permissionDenied,
          errorMessage: 'Microphone or speech recognition permission denied.',
        ),
      );
      return;
    }

    final existing = attemptFor(promptId);
    if (existing?.hasRecording ?? false) {
      final existingPath = existing?.filePath;
      if (existingPath != null) {
        await _deleteRecording(existingPath);
      }
    }

    try {
      final filePath = await backend.startSession(promptId: promptId);
      _setAttemptState(
        promptId,
        SpeechPracticeAttempt(promptId: promptId).copyWith(
          filePath: filePath,
          status: SpeechPracticeAttemptStatus.recording,
          clearLiveTranscript: true,
          clearFinalTranscript: true,
          clearScore: true,
          clearTranscriptSegments: true,
          clearReferenceSegments: true,
          clearErrorMessage: true,
          clearDetectedSpeech: true,
          clearSilenceDuration: true,
          matchedTokenCount: 0,
          totalTargetTokenCount: 0,
        ),
      );
      state = state.copyWith(
        recordingPromptId: promptId,
        clearAwaitingFinalPromptId: true,
      );
    } on SpeechPracticePlatformException catch (error) {
      // startSession 因权限问题失败时，异步刷新缓存。
      if (_isPermissionError(error.code)) {
        unawaited(ensurePermissions());
      }
      _setAttemptState(
        promptId,
        SpeechPracticeAttempt(promptId: promptId).copyWith(
          status: _statusFromError(error.code),
          errorMessage: error.message,
        ),
      );
    }
  }

  /// 停止录音并等待 final transcript 后完成识别、比对。
  Future<SpeechPracticeAttempt?> stopRecordingAndEvaluate({
    required String promptId,
    required String referenceText,
  }) async {
    final backend = ref.read(speechPracticeBackendProvider);
    if (state.recordingPromptId != promptId) {
      return attemptFor(promptId);
    }

    try {
      _finalEventPromptId = promptId;
      _finalEventCompleter = Completer<SpeechPracticeEvent>();
      final stopResult = await backend.stopSession();
      final current =
          (attemptFor(promptId) ?? SpeechPracticeAttempt(promptId: promptId))
              .copyWith(
                filePath: stopResult.filePath,
                status: SpeechPracticeAttemptStatus.awaitingFinal,
                clearErrorMessage: true,
              );
      _setAttemptState(promptId, current);
      state = state.copyWith(
        clearRecordingPromptId: true,
        awaitingFinalPromptId: promptId,
      );

      final stopFilePath = stopResult.filePath;
      if (stopFilePath == null || stopFilePath.isEmpty) {
        final failed = current.copyWith(
          status: SpeechPracticeAttemptStatus.error,
          errorMessage: 'Recording file missing.',
        );
        _setAttemptState(promptId, failed);
        state = state.copyWith(clearAwaitingFinalPromptId: true);
        return failed;
      }

      final finalEventCompleter = _finalEventCompleter;
      if (finalEventCompleter == null) {
        throw const SpeechPracticePlatformException(
          'invalidState',
          'Final transcript listener is missing.',
        );
      }
      final event = await finalEventCompleter.future.timeout(
        _finalTranscriptTimeout,
      );
      _finalEventCompleter = null;
      _finalEventPromptId = null;

      if (event.type == SpeechPracticeEventType.error) {
        final failed = current.copyWith(
          status: _statusFromError(event.errorCode),
          errorMessage: event.errorMessage,
        );
        _setAttemptState(promptId, failed);
        state = state.copyWith(clearAwaitingFinalPromptId: true);
        return failed;
      }

      final finalTranscript = (event.transcript ?? '').trim();
      final matcher = ref.read(speechTranscriptMatcherProvider);
      final matchResult = matcher.evaluate(
        referenceText: referenceText,
        transcript: finalTranscript,
      );
      final updated = current.copyWith(
        status: matchResult.status,
        finalTranscript: matchResult.finalTranscript,
        score: matchResult.score,
        matchedTokenCount: matchResult.matchedTokenCount,
        totalTargetTokenCount: matchResult.totalTargetTokenCount,
        transcriptSegments: matchResult.transcriptSegments,
        referenceSegments: matchResult.referenceSegments,
        clearLiveTranscript: true,
        clearErrorMessage: true,
        clearSilenceDuration: true,
      );
      _setAttemptState(promptId, updated);
      state = state.copyWith(clearAwaitingFinalPromptId: true);
      return updated;
    } on TimeoutException {
      _finalEventCompleter = null;
      _finalEventPromptId = null;
      final current =
          attemptFor(promptId) ?? SpeechPracticeAttempt(promptId: promptId);
      final failed = current.copyWith(
        status: SpeechPracticeAttemptStatus.error,
        errorMessage: 'Final transcript timed out.',
      );
      state = state.copyWith(
        clearRecordingPromptId: true,
        clearAwaitingFinalPromptId: true,
      );
      _setAttemptState(promptId, failed);
      return failed;
    } on SpeechPracticePlatformException catch (error) {
      _finalEventCompleter = null;
      _finalEventPromptId = null;
      final current =
          attemptFor(promptId) ?? SpeechPracticeAttempt(promptId: promptId);
      final failed = current.copyWith(
        status: _statusFromError(error.code),
        errorMessage: error.message,
      );
      state = state.copyWith(
        clearRecordingPromptId: true,
        clearAwaitingFinalPromptId: true,
      );
      _setAttemptState(promptId, failed);
      return failed;
    }
  }

  /// 取消当前录音，不保留本次文件。
  Future<void> cancelActiveRecording() async {
    final promptId = state.recordingPromptId;
    if (promptId == null) {
      return;
    }

    final backend = ref.read(speechPracticeBackendProvider);
    try {
      await backend.cancelSession();
      final current = attemptFor(promptId);
      final filePath = current?.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        await _deleteRecording(filePath);
      }
    } catch (_) {
      // 忽略中断错误，目标只是尽快结束录音态。
    }

    final current = attemptFor(promptId);
    if (current != null) {
      _setAttemptState(
        promptId,
        current.copyWith(
          status: SpeechPracticeAttemptStatus.idle,
          clearFilePath: true,
          clearLiveTranscript: true,
          clearFinalTranscript: true,
          clearScore: true,
          clearTranscriptSegments: true,
          clearReferenceSegments: true,
          clearErrorMessage: true,
          clearDetectedSpeech: true,
          clearSilenceDuration: true,
          matchedTokenCount: 0,
          totalTargetTokenCount: 0,
        ),
      );
    }
    state = state.copyWith(clearRecordingPromptId: true);
  }

  /// 播放指定句子的录音。
  Future<void> playAttempt(String promptId) async {
    final attempt = attemptFor(promptId);
    final filePath = attempt?.filePath;
    if (attempt == null || filePath == null || filePath.isEmpty) {
      return;
    }

    await stopAttemptPlayback();
    final player = await _ensurePlayer();
    await player.setFilePath(filePath);
    state = state.copyWith(playingPromptId: promptId);
    await player.play();
  }

  /// 停止录音回放。
  Future<void> stopAttemptPlayback() async {
    if (_player == null) {
      state = state.copyWith(clearPlayingPromptId: true);
      return;
    }
    await _player!.stop();
    state = state.copyWith(clearPlayingPromptId: true);
  }

  /// 清理当前学习阶段所有临时录音。
  Future<void> disposeSession() async {
    await cancelActiveRecording();
    await stopAttemptPlayback();

    for (final attempt in state.attempts.values) {
      final filePath = attempt.filePath;
      if (filePath != null && filePath.isNotEmpty) {
        await _deleteRecording(filePath);
      }
    }

    // 释放原生引擎（removeTap + engine.stop），彻底归还麦克风。
    final backend = ref.read(speechPracticeBackendProvider);
    if (backend.isSupported) {
      await backend.shutdown();
    }

    state = const SpeechPracticeSessionState();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) {
      return _player!;
    }

    final player = AudioPlayer();
    _player = player;
    _playerStateSub = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed ||
          playerState.processingState == ProcessingState.idle) {
        state = state.copyWith(clearPlayingPromptId: true);
      }
    });
    return player;
  }

  Future<void> _disposePlayer() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }
  }

  void _handleSpeechEvent(SpeechPracticeEvent event) {
    switch (event.type) {
      case SpeechPracticeEventType.partialTranscriptUpdated:
        _handlePartialTranscript(event);
      case SpeechPracticeEventType.speechStarted:
        _handleSpeechStarted(event);
      case SpeechPracticeEventType.silenceProgress:
        _handleSilenceProgress(event);
      case SpeechPracticeEventType.finalTranscriptReady ||
          SpeechPracticeEventType.error:
        final completer = _finalEventCompleter;
        if (_finalEventPromptId == event.promptId &&
            completer != null &&
            !completer.isCompleted) {
          completer.complete(event);
        }
    }
  }

  void _handlePartialTranscript(SpeechPracticeEvent event) {
    final promptId = event.promptId;
    final current = attemptFor(promptId);
    if (promptId.isEmpty || current == null || !isRecordingPrompt(promptId)) {
      return;
    }

    _setAttemptState(
      promptId,
      current.copyWith(
        liveTranscript: (event.transcript ?? '').trim(),
        clearErrorMessage: true,
        clearSilenceDuration: true,
      ),
    );
  }

  void _handleSpeechStarted(SpeechPracticeEvent event) {
    final promptId = event.promptId;
    final current = attemptFor(promptId);
    if (promptId.isEmpty || current == null || !isRecordingPrompt(promptId)) {
      return;
    }

    _setAttemptState(
      promptId,
      current.copyWith(
        hasDetectedSpeech: true,
        clearSilenceDuration: true,
        clearErrorMessage: true,
      ),
    );
  }

  void _handleSilenceProgress(SpeechPracticeEvent event) {
    final promptId = event.promptId;
    final current = attemptFor(promptId);
    if (promptId.isEmpty || current == null || !isRecordingPrompt(promptId)) {
      return;
    }

    _setAttemptState(
      promptId,
      current.copyWith(
        silenceDuration: event.silenceDuration ?? Duration.zero,
        clearErrorMessage: true,
      ),
    );
  }

  void _setAttemptState(String promptId, SpeechPracticeAttempt attempt) {
    final attempts = Map<String, SpeechPracticeAttempt>.from(state.attempts);
    attempts[promptId] = attempt;
    state = state.copyWith(attempts: attempts);
  }

  Future<void> _deleteRecording(String filePath) async {
    final backend = ref.read(speechPracticeBackendProvider);
    if (!backend.isSupported) {
      return;
    }
    try {
      await backend.deleteRecording(filePath);
    } catch (_) {
      // 删除失败不影响学习流程。
    }
  }

  /// 判断错误码是否为权限相关。
  bool _isPermissionError(String? code) =>
      code == 'permissionDenied' || code == 'notAuthorized';

  SpeechPracticeAttemptStatus _statusFromError(String? code) {
    return switch (code) {
      'permissionDenied' => SpeechPracticeAttemptStatus.permissionDenied,
      'notAvailable' => SpeechPracticeAttemptStatus.unavailable,
      'noSpeech' => SpeechPracticeAttemptStatus.noEnglishDetected,
      _ => SpeechPracticeAttemptStatus.error,
    };
  }
}

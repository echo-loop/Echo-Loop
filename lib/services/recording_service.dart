/// 通用录音服务。
///
/// 按需管理录音引擎生命周期：startRecording 自动 warmup + 权限检查 + 开始录音，
/// stopRecording / cancelRecording 完成后自动 shutdown 释放麦克风。
/// 调用方无需关心 warmup/shutdown 时机。
library;

import 'dart:async';

import '../models/speech_practice_models.dart';
import 'app_logger.dart';
import '../services/speech_practice_platform.dart';
import 'study_event_recorder.dart';

/// 录音结果。
class RecordingResult {
  /// 录音文件路径。
  final String? filePath;

  /// 最终识别文本。
  final String? finalTranscript;

  /// 错误码（null 表示成功）。
  final String? errorCode;

  /// 错误消息。
  final String? errorMessage;

  /// 是否成功（有 final transcript 且无错误）。
  bool get isSuccess => errorCode == null && finalTranscript != null;

  const RecordingResult({
    this.filePath,
    this.finalTranscript,
    this.errorCode,
    this.errorMessage,
  });
}

/// 等待 final transcript 的超时时长。
const _finalTranscriptTimeout = Duration(seconds: 5);

/// 通用录音服务。
///
/// 封装 [SpeechPracticeBackend] 的录音流程，提供简洁的
/// startRecording / stopRecording / cancelRecording API。
/// 每次录音结束后自动 shutdown 释放麦克风资源。
class RecordingService {
  final SpeechPracticeBackend _backend;

  StreamSubscription<SpeechPracticeEvent>? _eventSub;
  Completer<SpeechPracticeEvent>? _finalEventCompleter;
  String? _finalEventPromptId;
  final StreamController<SpeechPracticeEvent> _eventController =
      StreamController<SpeechPracticeEvent>.broadcast();

  /// 权限缓存。
  SpeechPracticePermissionState _permissions =
      const SpeechPracticePermissionState();

  /// 当前录音中的 promptId。
  String? _recordingPromptId;

  /// 当前录音文件路径。
  String? _currentFilePath;

  /// 录音开始时间（用于计算录音时长）
  DateTime? _recordingStartedAt;

  /// 防重入标志：startRecording 正在执行中。
  bool _isStarting = false;

  /// 学习事件记录器（外部设置，用于记录说的时长）
  ///
  /// Provider 进入学习模式时注入、退出时置 null。
  StudyEventRecorder? recorder;

  RecordingService(this._backend);

  /// 当前平台是否支持录音。
  bool get isSupported => _backend.isSupported;

  /// 是否正在录音。
  bool get isRecording => _recordingPromptId != null;

  /// 当前录音的 promptId。
  String? get recordingPromptId => _recordingPromptId;

  /// 当前权限状态。
  SpeechPracticePermissionState get permissions => _permissions;

  /// 原生事件流（partial transcript / speechStarted / silenceProgress）。
  Stream<SpeechPracticeEvent> get events => _eventController.stream;

  /// 确保已获取所需录音权限。
  ///
  /// [requirePlatformSpeechRecognition]：是否要求 iOS/macOS 平台原生
  /// `SFSpeechRecognizer` 权限。仅当用户启用 ASR 且 backend 为
  /// `AsrBackend.platform` 时为 true；关闭 ASR / Echo Loop 离线后端时为 false。
  /// 为 false 时只检查麦克风权限，speech recognition 状态被忽略。
  ///
  /// 每次都查询原生层获取实时权限状态，防止用户在系统设置中撤销权限后
  /// 缓存过期导致判断错误。
  Future<bool> ensurePermissions({
    required bool requirePlatformSpeechRecognition,
  }) async {
    if (!_backend.isSupported) return false;

    var perms = await _backend.getPermissionStatus();
    if (!_isCovered(
      perms,
      requirePlatformSpeechRecognition: requirePlatformSpeechRecognition,
    )) {
      // 不需要平台 ASR 时只请求麦克风，避免触发无关的 SFSpeechRecognizer 弹窗
      perms = await _backend.requestPermissions(
        onlyMic: !requirePlatformSpeechRecognition,
      );
    }
    _permissions = perms;
    return _isCovered(
      perms,
      requirePlatformSpeechRecognition: requirePlatformSpeechRecognition,
    );
  }

  /// 判断当前权限快照是否覆盖本次录音所需。
  bool _isCovered(
    SpeechPracticePermissionState perms, {
    required bool requirePlatformSpeechRecognition,
  }) {
    final micOk = perms.microphone == SpeechPracticePermissionStatus.granted;
    final speechOk = !requirePlatformSpeechRecognition ||
        perms.speech == SpeechPracticePermissionStatus.granted;
    return micOk && speechOk;
  }

  /// 开始录音。
  ///
  /// 自动执行 setRecognitionEnabled → 权限检查 → warmup → startSession。
  /// [recognitionEnabled] 控制平台原生 ASR 是否启动（Apple Speech 时为 true）。
  /// 返回录音文件路径，失败时抛出 [SpeechPracticePlatformException]。
  Future<String> startRecording({
    required String promptId,
    bool recognitionEnabled = false,
  }) async {
    if (!_backend.isSupported) {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice is unavailable on this platform.',
      );
    }

    // 防重入：快速连点时避免多次 warmup + startSession
    if (_isStarting) return _currentFilePath!;
    _isStarting = true;

    try {
      // 权限检查（必须在 warmup 之前，否则 iOS/macOS 原生 warmup
      // 会把 notDetermined 当作 denied 直接返回错误）。
      // 仅在启用平台原生 ASR（recognitionEnabled == true）时才要求
      // speech recognition 权限；纯录音 / Echo Loop 离线 ASR 只需 mic。
      final granted = await ensurePermissions(
        requirePlatformSpeechRecognition: recognitionEnabled,
      );
      if (!granted) {
        throw const SpeechPracticePlatformException(
          'permissionDenied',
          'Microphone or speech recognition permission denied.',
        );
      }

      // 设置平台 ASR 模式（必须在 warmup 之前）
      await _backend.setRecognitionEnabled(recognitionEnabled);

      // warmup 引擎
      await _backend.warmup();

      // 订阅事件流
      _eventSub ??= _backend.events.listen(_handleEvent);

      // 开始录音
      final filePath = await _backend.startSession(promptId: promptId);
      _recordingPromptId = promptId;
      _currentFilePath = filePath;
      _recordingStartedAt = DateTime.now();

      return filePath;
    } catch (e) {
      await _backend.shutdown();
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  /// 停止录音，返回文件路径。不等待转录结果。
  ///
  /// 录音时长在此处计算并写入 recorder。
  /// 调用后需调用 [waitForTranscript] 获取转录结果，或直接存录音。
  Future<RecordingResult> stopSession({
    required String promptId,
    int? effectiveDurationMs,
  }) async {
    AppLogger.log(
      'Recording',
      '┌ stopSession promptId=$promptId '
          'recordingPromptId=$_recordingPromptId '
          'durationMs=${effectiveDurationMs ?? -1}',
    );
    if (_recordingPromptId != promptId) {
      AppLogger.log(
        'Recording',
        '└ stopSession skipped: invalidState '
            'recordingPromptId=$_recordingPromptId expected=$promptId',
      );
      return const RecordingResult(
        errorCode: 'invalidState',
        errorMessage: 'Not recording this prompt.',
      );
    }

    final startedAt = _recordingStartedAt;
    final durationMs =
        effectiveDurationMs ??
        (startedAt == null
            ? 0
            : DateTime.now().difference(startedAt).inMilliseconds);
    if (durationMs > 0) {
      recorder?.onRecordingCompleted(durationMs);
    }

    _finalEventPromptId = promptId;
    _finalEventCompleter = Completer<SpeechPracticeEvent>();

    AppLogger.log('Recording', '│ backend.stopSession() ...');
    final stopResult = await _backend.stopSession();
    final filePath = stopResult.filePath ?? _currentFilePath;
    _recordingPromptId = null;
    _recordingStartedAt = null;
    AppLogger.log(
      'Recording',
      '└ stopSession done filePath=${filePath ?? '(null)'}',
    );

    return RecordingResult(filePath: filePath);
  }

  /// 等待转录结果并释放引擎。
  ///
  /// 必须在 [stopSession] 之后调用。等待平台或离线引擎返回 finalTranscript。
  Future<RecordingResult> waitForTranscript({
    required String filePath,
    Duration? timeout,
  }) async {
    try {
      final effectiveTimeout = timeout ?? _finalTranscriptTimeout;
      AppLogger.log(
        'Recording',
        '┌ waitForTranscript timeout=${effectiveTimeout.inSeconds}s ...',
      );
      final event = await _finalEventCompleter!.future.timeout(
        effectiveTimeout,
      );
      _clearFinalCompleter();
      await _shutdown();

      AppLogger.log(
        'Recording',
        '│ final event type=${event.type.name} '
            'transcriptLen=${event.transcript?.trim().length ?? 0} '
            'errorCode=${event.errorCode ?? '(null)'}',
      );

      if (event.type == SpeechPracticeEventType.error) {
        AppLogger.log('Recording', '└ waitForTranscript: ASR error');
        return RecordingResult(
          filePath: filePath,
          errorCode: event.errorCode,
          errorMessage: event.errorMessage,
        );
      }

      AppLogger.log('Recording', '└ waitForTranscript: done');
      return RecordingResult(
        filePath: filePath,
        finalTranscript: (event.transcript ?? '').trim(),
      );
    } on TimeoutException {
      _clearFinalCompleter();
      await _shutdown();
      AppLogger.log('Recording', '└ waitForTranscript: timeout');
      return RecordingResult(
        filePath: filePath,
        errorCode: 'timeout',
        errorMessage: 'Final transcript timed out.',
      );
    } on SpeechPracticePlatformException catch (e) {
      _clearFinalCompleter();
      await _shutdown();
      AppLogger.log(
        'Recording',
        '└ waitForTranscript: platform ${e.code} ${e.message}',
      );
      return RecordingResult(
        filePath: filePath,
        errorCode: e.code,
        errorMessage: e.message,
      );
    }
  }

  /// 停止录音并等待转录（便捷方法，保持向后兼容）。
  Future<RecordingResult> stopRecording({
    required String promptId,
    int? effectiveDurationMs,
  }) async {
    final stopResult = await stopSession(
      promptId: promptId,
      effectiveDurationMs: effectiveDurationMs,
    );
    if (stopResult.errorCode != null) return stopResult;
    final filePath = stopResult.filePath;
    if (filePath == null || filePath.isEmpty) {
      await _shutdown();
      return const RecordingResult(
        errorCode: 'noFile',
        errorMessage: 'Recording file missing.',
      );
    }
    return waitForTranscript(filePath: filePath);
  }

  /// 取消当前录音，删除录音文件，释放麦克风。
  ///
  /// 取消的录音不计入说的时长。
  Future<void> cancelRecording() async {
    final promptId = _recordingPromptId;
    if (promptId == null) return;

    _recordingPromptId = null;
    _recordingStartedAt = null;

    _clearFinalCompleter();

    try {
      await _backend.cancelSession();
      final filePath = _currentFilePath;
      if (filePath != null && filePath.isNotEmpty) {
        await deleteRecording(filePath);
      }
    } catch (e) {
      AppLogger.log('Recording', '⚠ cancelRecording 异常（已忽略）: $e');
    }

    _currentFilePath = null;
    _recordingStartedAt = null;
    await _shutdown();
  }

  /// 删除录音文件。
  Future<void> deleteRecording(String filePath) async {
    if (!_backend.isSupported) return;
    try {
      await _backend.deleteRecording(filePath);
    } catch (e) {
      AppLogger.log('Recording', '⚠ deleteRecording 失败（已忽略）: $e');
    }
  }

  /// 释放资源。
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _clearFinalCompleter();
    await _eventController.close();
    if (_backend.isSupported) {
      await _backend.shutdown();
    }
  }

  /// 关闭引擎并取消事件订阅（公开方法，ASR 关闭时直接释放资源）。
  Future<void> shutdown() async {
    await _shutdown();
  }

  /// 关闭引擎并取消事件订阅。
  Future<void> _shutdown() async {
    await _eventSub?.cancel();
    _eventSub = null;
    if (_backend.isSupported) {
      await _backend.shutdown();
    }
  }

  void _clearFinalCompleter() {
    _finalEventCompleter = null;
    _finalEventPromptId = null;
  }

  void _handleEvent(SpeechPracticeEvent event) {
    AppLogger.log(
      'Recording',
      '│ event type=${event.type.name} promptId=${event.promptId} '
          'transcriptLen=${event.transcript?.trim().length ?? 0} '
          'errorCode=${event.errorCode ?? '(null)'} '
          'silenceMs=${event.silenceDuration?.inMilliseconds ?? -1}',
    );
    switch (event.type) {
      case SpeechPracticeEventType.partialTranscriptUpdated ||
          SpeechPracticeEventType.speechStarted ||
          SpeechPracticeEventType.silenceProgress:
        // 转发给调用方
        _eventController.add(event);
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
}

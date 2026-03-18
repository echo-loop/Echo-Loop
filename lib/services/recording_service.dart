/// 通用录音服务。
///
/// 按需管理录音引擎生命周期：startRecording 自动 warmup + 权限检查 + 开始录音，
/// stopRecording / cancelRecording 完成后自动 shutdown 释放麦克风。
/// 调用方无需关心 warmup/shutdown 时机。
library;

import 'dart:async';

import '../models/speech_practice_models.dart';
import '../services/speech_practice_platform.dart';

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

  /// 确保已获取麦克风与语音识别权限。
  ///
  /// 已缓存 granted 时跳过 MethodChannel 调用。
  Future<bool> ensurePermissions() async {
    if (!_backend.isSupported) return false;

    if (_permissions.isGranted) return true;

    var perms = await _backend.getPermissionStatus();
    if (!perms.isGranted) {
      perms = await _backend.requestPermissions();
    }
    _permissions = perms;
    return perms.isGranted;
  }

  /// 开始录音。
  ///
  /// 自动执行 warmup → 权限检查 → startSession。
  /// 返回录音文件路径，失败时抛出 [SpeechPracticePlatformException]。
  Future<String> startRecording({required String promptId}) async {
    if (!_backend.isSupported) {
      throw const SpeechPracticePlatformException(
        'notAvailable',
        'Speech practice is unavailable on this platform.',
      );
    }

    // warmup 引擎
    await _backend.warmup();

    // 订阅事件流
    _eventSub ??= _backend.events.listen(_handleEvent);

    // 权限检查
    final granted = await ensurePermissions();
    if (!granted) {
      await _backend.shutdown();
      throw const SpeechPracticePlatformException(
        'permissionDenied',
        'Microphone or speech recognition permission denied.',
      );
    }

    // 开始录音
    final filePath = await _backend.startSession(promptId: promptId);
    _recordingPromptId = promptId;
    _currentFilePath = filePath;
    return filePath;
  }

  /// 停止录音并等待 final transcript。
  ///
  /// 内部在拿到 final transcript 后自动 shutdown 释放麦克风。
  Future<RecordingResult> stopRecording({required String promptId}) async {
    if (_recordingPromptId != promptId) {
      return const RecordingResult(
        errorCode: 'invalidState',
        errorMessage: 'Not recording this prompt.',
      );
    }

    try {
      _finalEventPromptId = promptId;
      _finalEventCompleter = Completer<SpeechPracticeEvent>();

      final stopResult = await _backend.stopSession();
      final filePath = stopResult.filePath ?? _currentFilePath;
      _recordingPromptId = null;

      if (filePath == null || filePath.isEmpty) {
        await _shutdown();
        return const RecordingResult(
          errorCode: 'noFile',
          errorMessage: 'Recording file missing.',
        );
      }

      // 等待 final transcript
      final event = await _finalEventCompleter!.future.timeout(
        _finalTranscriptTimeout,
      );
      _clearFinalCompleter();

      await _shutdown();

      if (event.type == SpeechPracticeEventType.error) {
        return RecordingResult(
          filePath: filePath,
          errorCode: event.errorCode,
          errorMessage: event.errorMessage,
        );
      }

      return RecordingResult(
        filePath: filePath,
        finalTranscript: (event.transcript ?? '').trim(),
      );
    } on TimeoutException {
      _clearFinalCompleter();
      _recordingPromptId = null;
      await _shutdown();
      return RecordingResult(
        filePath: _currentFilePath,
        errorCode: 'timeout',
        errorMessage: 'Final transcript timed out.',
      );
    } on SpeechPracticePlatformException catch (e) {
      _clearFinalCompleter();
      _recordingPromptId = null;
      await _shutdown();
      return RecordingResult(
        filePath: _currentFilePath,
        errorCode: e.code,
        errorMessage: e.message,
      );
    }
  }

  /// 取消当前录音，删除录音文件，释放麦克风。
  Future<void> cancelRecording() async {
    final promptId = _recordingPromptId;
    if (promptId == null) return;

    _recordingPromptId = null;
    _clearFinalCompleter();

    try {
      await _backend.cancelSession();
      final filePath = _currentFilePath;
      if (filePath != null && filePath.isNotEmpty) {
        await deleteRecording(filePath);
      }
    } catch (_) {
      // 忽略中断错误，目标只是尽快结束录音态。
    }

    _currentFilePath = null;
    await _shutdown();
  }

  /// 删除录音文件。
  Future<void> deleteRecording(String filePath) async {
    if (!_backend.isSupported) return;
    try {
      await _backend.deleteRecording(filePath);
    } catch (_) {
      // 删除失败不影响流程。
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

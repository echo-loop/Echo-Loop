/// 装饰器 ASR 后端：组合 Native 录音 + 离线 ASR 补充转录。
///
/// 包装 [SpeechPracticePlatform]，当平台 ASR 返回空 transcript 时，
/// 使用 [OfflineAsrEngine] 对录音文件进行离线转录，
/// 将结果以 [finalTranscriptReady] 事件形式注入事件流。
library;

import 'dart:async';

import '../speech_practice_platform.dart';
import '../../models/speech_practice_models.dart';
import '../app_logger.dart';
import 'offline_asr_engine.dart';

/// 离线 ASR 增强的录音后端。
///
/// 装饰器模式：包装 [SpeechPracticePlatform]，
/// 在平台 ASR 返回空 transcript 时，用 [OfflineAsrEngine] 补充。
///
/// 录音、VAD、权限等能力全部委托给 [_platform]（Native 层），
/// 仅在 finalTranscript 环节拦截补充。
class OfflineAsrBackend implements SpeechPracticeBackend {
  final SpeechPracticePlatform _platform;
  final OfflineAsrEngine _engine;

  /// 当前录音文件路径（startSession 时记录，stopSession 后用于转录）。
  String? _currentFilePath;

  /// Generation counter：防止异步转录回调与新 session 冲突。
  int _generation = 0;

  /// 合并后的事件流控制器。
  StreamController<SpeechPracticeEvent>? _mergedController;
  StreamSubscription<SpeechPracticeEvent>? _platformSubscription;

  OfflineAsrBackend({
    required SpeechPracticePlatform platform,
    required OfflineAsrEngine engine,
  }) : _platform = platform,
       _engine = engine;

  @override
  bool get isSupported => _platform.isSupported;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() =>
      _platform.getPermissionStatus();

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) => _platform.requestPermissions(onlyMic: onlyMic);

  @override
  Future<int> getDeviceRamBytes() => _platform.getDeviceRamBytes();

  @override
  Future<void> setRecognitionEnabled(bool enabled) =>
      _platform.setRecognitionEnabled(enabled);

  @override
  Stream<SpeechPracticeEvent> get events {
    if (_mergedController != null) return _mergedController!.stream;

    final controller = StreamController<SpeechPracticeEvent>.broadcast();
    _mergedController = controller;

    _platformSubscription = _platform.events.listen(
      (event) => _handlePlatformEvent(event, controller),
      onError: controller.addError,
    );

    return controller.stream;
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) =>
      _platform.warmup(locale: locale);

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    _generation++;
    AppLogger.log(
      'OfflineASR',
      '┌ startSession promptId=$promptId locale=$locale generation=$_generation',
    );
    final filePath = await _platform.startSession(
      promptId: promptId,
      locale: locale,
    );
    _currentFilePath = filePath;
    AppLogger.log('OfflineASR', '└ startSession filePath=$filePath');
    return filePath;
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    AppLogger.log(
      'OfflineASR',
      '┌ stopSession currentFilePath=${_currentFilePath ?? '(null)'} generation=$_generation',
    );
    final result = await _platform.stopSession();
    AppLogger.log(
      'OfflineASR',
      '└ stopSession filePath=${result.filePath ?? '(null)'}',
    );
    return result;
  }

  @override
  Future<void> cancelSession() {
    _generation++;
    _currentFilePath = null;
    AppLogger.log('OfflineASR', '● cancelSession generation=$_generation');
    return _platform.cancelSession();
  }

  @override
  Future<void> deleteRecording(String filePath) =>
      _platform.deleteRecording(filePath);

  @override
  Future<void> shutdown() async {
    _generation++;
    _currentFilePath = null;
    AppLogger.log('OfflineASR', '● shutdown generation=$_generation');
    await _platformSubscription?.cancel();
    _platformSubscription = null;
    await _mergedController?.close();
    _mergedController = null;
    await _platform.shutdown();
  }

  /// 处理平台事件，拦截空的 finalTranscript 进行离线转录补充。
  void _handlePlatformEvent(
    SpeechPracticeEvent event,
    StreamController<SpeechPracticeEvent> controller,
  ) {
    if (controller.isClosed) return;

    // 非 finalTranscript 事件直接透传。
    if (event.type != SpeechPracticeEventType.finalTranscriptReady) {
      controller.add(event);
      return;
    }

    // 平台已有有效 transcript，直接透传。
    final transcript = event.transcript;
    if (transcript != null && transcript.trim().isNotEmpty) {
      AppLogger.log(
        'OfflineASR',
        '✓ final transcript passthrough promptId=${event.promptId} '
            'len=${transcript.trim().length}',
      );
      controller.add(event);
      return;
    }

    // 平台 transcript 为空 → 尝试离线转录补充。
    if (!_engine.isReady) {
      // 引擎未就绪，原样转发空结果。
      AppLogger.log(
        'OfflineASR',
        '⚠ final transcript empty, engine not ready promptId=${event.promptId}',
      );
      controller.add(event);
      return;
    }

    final filePath = _currentFilePath;
    if (filePath == null) {
      AppLogger.log(
        'OfflineASR',
        '⚠ final transcript empty, no current file path promptId=${event.promptId}',
      );
      controller.add(event);
      return;
    }

    final generation = _generation;
    AppLogger.log(
      'OfflineASR',
      '⏳ transcribe start promptId=${event.promptId} filePath=$filePath generation=$generation',
    );
    _engine
        .transcribe(filePath)
        .then((result) {
          // 校验 generation：如果新 session 已启动，丢弃过期结果。
          if (_generation != generation || controller.isClosed) return;

          AppLogger.log(
            'OfflineASR',
            '✓ transcribe done promptId=${event.promptId} '
                'len=${result.text.trim().length} '
                'elapsed=${result.inferenceTime.inMilliseconds}ms',
          );
          controller.add(
            SpeechPracticeEvent(
              type: SpeechPracticeEventType.finalTranscriptReady,
              promptId: event.promptId,
              transcript: result.text,
            ),
          );
        })
        .catchError((Object error) {
          if (_generation != generation || controller.isClosed) return;

          // 转录失败，发送空结果（与无引擎时行为一致）。
          AppLogger.log(
            'OfflineASR',
            '✗ transcribe failed promptId=${event.promptId} error=$error',
          );
          controller.add(event);
        });
  }
}

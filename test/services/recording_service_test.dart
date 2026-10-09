import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/services/app_logger.dart';
import 'package:echo_loop/services/recording_service.dart';
import 'package:echo_loop/services/speech_practice_platform.dart';

class _Backend implements SpeechPracticeBackend {
  final eventsController = StreamController<SpeechPracticeEvent>.broadcast();
  Completer<void>? warmupGate;
  String? activePromptId;
  int startCalls = 0;
  int cancelCalls = 0;
  int shutdownCalls = 0;
  String? stopDiagnostics;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => eventsController.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async =>
      const SpeechPracticePermissionState(
        microphone: SpeechPracticePermissionStatus.granted,
        speech: SpeechPracticePermissionStatus.granted,
      );

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) => getPermissionStatus();

  @override
  Future<int> getDeviceRamBytes() async => 0;

  @override
  Future<void> setRecognitionEnabled(bool enabled) async {}

  @override
  Future<void> warmup({String locale = 'en-US'}) async {
    await warmupGate?.future;
  }

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    startCalls += 1;
    activePromptId = promptId;
    return '/tmp/$promptId.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async =>
      SpeechPracticeStopResult(
        filePath: '/tmp/${activePromptId ?? 'none'}.caf',
        diagnostics: stopDiagnostics,
      );

  @override
  Future<void> cancelSession() async {
    cancelCalls += 1;
    activePromptId = null;
  }

  @override
  Future<void> deleteRecording(String filePath) async {}

  @override
  Future<void> shutdown() async {
    shutdownCalls += 1;
  }

  Future<void> dispose() => eventsController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('释放期间 warmup 完成后也不会启动麦克风', () async {
    final backend = _Backend()..warmupGate = Completer<void>();
    final service = RecordingService(backend);
    final start = service.startRecording(promptId: 'round:0');

    await Future<void>.value();
    final dispose = service.dispose();
    backend.warmupGate!.complete();

    await expectLater(start, throwsA(isA<SpeechPracticePlatformException>()));
    await dispose;
    await service.dispose();

    expect(backend.startCalls, 0);
    expect(backend.cancelCalls, 0);
    expect(backend.shutdownCalls, greaterThanOrEqualTo(1));
    await backend.dispose();
  });

  test('等待最终转录期间取消会立即结束等待', () async {
    final backend = _Backend();
    final service = RecordingService(backend);
    await service.startRecording(promptId: 'round:1');
    final stopped = await service.stopSession(promptId: 'round:1');
    final filePath = stopped.filePath;
    expect(filePath, isNotEmpty);
    final wait = service.waitForTranscript(
      filePath: filePath ?? '',
      timeout: const Duration(minutes: 1),
    );

    await service.cancelRecording();
    final result = await wait;

    expect(result.errorCode, 'cancelled');
    await service.dispose();
    await backend.dispose();
  });

  test('停止录音时将原生诊断记录到应用日志', () async {
    const promptId = 'diagnostics:round';
    final backend = _Backend()..stopDiagnostics = 'errorReadCount=2';
    final service = RecordingService(backend);

    await service.startRecording(promptId: promptId);
    await service.stopSession(promptId: promptId);

    expect(
      AppLogger.instance.entries.any(
        (entry) =>
            entry.tag == 'RecordingDiag' &&
            entry.message.contains('promptId=$promptId') &&
            entry.message.contains('errorReadCount=2'),
      ),
      isTrue,
    );

    await service.dispose();
    await backend.dispose();
  });
}

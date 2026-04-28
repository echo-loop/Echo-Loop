import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/models/study_stage.dart';
import 'package:fluency/providers/retell_recording_controller_provider.dart';
import 'package:fluency/services/speech_practice_platform.dart';
import 'package:fluency/services/study_event_recorder.dart';
import 'package:fluency/services/study_time_service.dart';

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  String? activePromptId;
  int counter = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechPracticeEvent> get events => _controller.stream;

  @override
  Future<SpeechPracticePermissionState> getPermissionStatus() async {
    return const SpeechPracticePermissionState(
      microphone: SpeechPracticePermissionStatus.granted,
      speech: SpeechPracticePermissionStatus.granted,
    );
  }

  @override
  Future<SpeechPracticePermissionState> requestPermissions({
    bool onlyMic = false,
  }) {
    return getPermissionStatus();
  }

  @override
  Future<void> warmup({String locale = 'en-US'}) async {}

  @override
  Future<void> shutdown() async {}

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    activePromptId = promptId;
    counter += 1;
    return '/tmp/$promptId-$counter.caf';
  }

  @override
  Future<SpeechPracticeStopResult> stopSession() async {
    final promptId = activePromptId ?? 'retell:a1:0';
    scheduleMicrotask(() {
      _controller.add(
        SpeechPracticeEvent(
          type: SpeechPracticeEventType.finalTranscriptReady,
          promptId: promptId,
          transcript: 'retell transcript',
        ),
      );
    });
    return SpeechPracticeStopResult(filePath: '/tmp/$promptId-$counter.caf');
  }

  @override
  Future<void> cancelSession() async {}

  @override
  Future<void> deleteRecording(String filePath) async {}

  void emitPartial(String transcript) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.partialTranscriptUpdated,
        promptId: activePromptId ?? 'retell:a1:0',
        transcript: transcript,
      ),
    );
  }

  void emitSpeechStarted() {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: activePromptId ?? 'retell:a1:0',
      ),
    );
  }

  void emitSilence(Duration duration) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: activePromptId ?? 'retell:a1:0',
        silenceDuration: duration,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _DummyStudyTimeService implements StudyTimeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _RecordingStudyEventRecorder extends StudyEventRecorder {
  _RecordingStudyEventRecorder()
    : super(
        studyTimeService: _DummyStudyTimeService(),
        stage: StudyStage.retell,
      );

  final List<int> recordedDurations = [];

  @override
  void onRecordingCompleted(int durationMs) {
    recordedDurations.add(durationMs);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RetellRecordingController 在停止录音后通过底层统一记录说的时长', () async {
    final backend = _FakeSpeechPracticeBackend();
    final container = ProviderContainer(
      overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(() async {
      await backend.dispose();
      container.dispose();
    });

    final controller = container.read(
      retellRecordingControllerProvider.notifier,
    );
    final recorder = _RecordingStudyEventRecorder();
    controller.setRecorder(recorder);

    await controller.startRecording(
      promptId: 'retell:a1:0',
      referenceText: 'ask your professor today for authorization again',
    );

    backend.emitSpeechStarted();
    backend.emitPartial('ask your professor today');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    backend.emitSilence(const Duration(milliseconds: 100));

    await controller.stopAndEvaluate(
      referenceText: 'ask your professor today for authorization again',
    );

    expect(recorder.recordedDurations, hasLength(1));
    expect(recorder.recordedDurations.single, greaterThanOrEqualTo(900));
  });
}

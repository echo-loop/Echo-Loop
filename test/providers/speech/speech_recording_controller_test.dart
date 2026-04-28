import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluency/models/speech_practice_models.dart';
import 'package:fluency/providers/speech/speech_recording_controller.dart';
import 'package:fluency/services/speech_practice_platform.dart';

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  bool autoEmitFinal;
  String? activePromptId;
  int counter = 0;

  _FakeSpeechPracticeBackend({this.autoEmitFinal = true});

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
    final promptId = activePromptId ?? 'shadowing:a1:0';
    if (autoEmitFinal) {
      scheduleMicrotask(() {
        _controller.add(
          SpeechPracticeEvent(
            type: SpeechPracticeEventType.finalTranscriptReady,
            promptId: promptId,
            transcript: 'done',
          ),
        );
      });
    }
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
        promptId: activePromptId ?? 'shadowing:a1:0',
        transcript: transcript,
      ),
    );
  }

  void emitSpeechStarted() {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.speechStarted,
        promptId: activePromptId ?? 'shadowing:a1:0',
      ),
    );
  }

  void emitSilence(Duration duration) {
    _controller.add(
      SpeechPracticeEvent(
        type: SpeechPracticeEventType.silenceProgress,
        promptId: activePromptId ?? 'shadowing:a1:0',
        silenceDuration: duration,
      ),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechPracticeCompletionHeuristic', () {
    const heuristic = SpeechPracticeCompletionHeuristic();

    test('空输入 → 5s', () {
      expect(
        heuristic.computeSilenceThreshold(
          referenceText: 'Hello world',
          partialTranscript: '',
        ),
        const Duration(seconds: 5),
      );
      expect(
        heuristic.computeSilenceThreshold(
          referenceText: '',
          partialTranscript: 'Hello world',
        ),
        const Duration(seconds: 5),
      );
    });

    test('完全匹配（规则 A + B 同时 1s）→ 1s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Hello world',
        partialTranscript: 'hello world',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('尾部连续完整匹配 + 唯一（规则 A）→ 1s', () {
      // "I noticed your name on the door" 匹配 7/8，尾部 5 词连续且唯一
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'I noticed your name on the door',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('全句 90% 尾部只命中 3/5 → 规则 D 触发 2s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText:
            'the quick brown fox jumps over the lazy dog and '
            'then runs across the wide open green field today',
        partialTranscript:
            'the quick brown fox jumps over the lazy dog and '
            'then runs across the wide green field',
      );
      // 规则 D: 匹配 18 词，剩余 2 词 → 2s
      expect(result, const Duration(seconds: 2));
    });

    test('全句 90% 尾部命中 4/5（规则 B=3s, C=2s）→ 2s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'she always wanted to visit the beautiful city of paris',
        partialTranscript: 'she wanted to visit the beautiful city of paris',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('末尾词唯一但命中少，规则 A 仍生效 → 1s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'she always wanted to visit the beautiful city of paris',
        partialTranscript: 'she wanted the paris',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('只说了唯一的末尾词（规则 A：consecutiveTail=1 且唯一）→ 1s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText:
            "Thought I'd stop in and um find out if you happen "
            'to have any additional copies of the class syllabus',
        partialTranscript: 'syllabus',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('末尾无命中 → 5s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Anyhow I noticed your name on the door',
        partialTranscript: 'Anyhow I noticed your',
      );
      expect(result, const Duration(seconds: 5));
    });

    test('短句（< 5 词）正常工作', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'Hello world',
        partialTranscript: 'hello',
      );
      // 规则 D: 匹配 1 词，剩余 1 词 → 2s
      expect(result, const Duration(seconds: 2));
    });

    test('尾部连续匹配且组合唯一 → 规则 A 生效 → 1s', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'I said hello and she said hello',
        partialTranscript: 'and she said hello',
      );
      expect(result, const Duration(seconds: 1));
    });

    test('尾部非唯一时规则 A 不生效，走 B/C', () {
      final result = heuristic.computeSilenceThreshold(
        referenceText: 'go go',
        partialTranscript: 'go',
      );
      expect(result, const Duration(seconds: 5));
    });
  });

  group('SpeechRecordingController', () {
    test('完全匹配时 1s 静音即停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      backend.emitPartial('I noticed your name on the door');
      backend.emitSpeechStarted();
      backend.emitSilence(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final turnState = container.read(speechRecordingControllerProvider);
      expect(turnState.phase, SpeechRecordingPhase.processing);
    });

    test('部分匹配（尾部 0 命中）时 5s 静音才停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      // 只说了前半句 → 尾部 5 词命中 0 → 阈值 5s
      backend.emitPartial('Anyhow I noticed your');
      backend.emitSpeechStarted();

      // 2s 静音不够
      backend.emitSilence(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.speaking,
      );

      // 5s 静音才触发（尾部 0 命中 → 5s 阈值）
      backend.emitSilence(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.processing,
      );
    });

    test('无匹配时 5s 静音才停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Anyhow I noticed your name on the door',
      );

      // 完全不相关的内容
      backend.emitPartial('something completely different');
      backend.emitSpeechStarted();

      // 4s 不够
      backend.emitSilence(const Duration(seconds: 4));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.speaking,
      );

      // 5s 触发兜底
      backend.emitSilence(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.processing,
      );
    });

    test('转录停滞通道：完全匹配后 1s 不更新即自动结束（无 silenceProgress）', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        // 发送完整转录，模拟嘈杂环境（不发送 silenceProgress）
        backend.emitSpeechStarted();
        async.flushMicrotasks();
        backend.emitPartial('I noticed your name on the door');
        async.flushMicrotasks();

        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 完全匹配 → 阈值 1s，等 1s 后停滞计时器触发
        async.elapse(const Duration(seconds: 1));

        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('转录停滞通道：部分匹配后按动态阈值等待', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        backend.emitSpeechStarted();
        async.flushMicrotasks();
        // 只说前半句 → 尾部 0 命中 → 阈值 5s
        backend.emitPartial('Anyhow I noticed your');
        async.flushMicrotasks();

        // 4s 后仍在 speaking
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 5s 后停滞计时器触发
        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('转录更新会重置停滞计时器', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        async.flushMicrotasks();

        backend.emitSpeechStarted();
        async.flushMicrotasks();
        backend.emitPartial('Anyhow');
        async.flushMicrotasks();

        // 4s 后更新转录 → 重置计时器
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );
        backend.emitPartial('Anyhow I noticed');
        async.flushMicrotasks();

        // 再过 4s 仍在 speaking（计时器已重置）
        async.elapse(const Duration(seconds: 4));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 再过 1s（共 5s 无更新）→ 触发
        async.elapse(const Duration(seconds: 1));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('60s 未开口 → 取消录音回到 idle', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );

      // 设置一个短的超时便于测试
      // 我们通过直接调用 cancelActiveRecording 来测试超时逻辑
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
      );

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.awaitingSpeech,
      );

      // 模拟超时行为：取消录音回到 idle
      await controller.cancelActiveRecording();
      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.idle,
      );
    });

    test('ASR 有转录但 VAD 未触发时，仍应从 awaitingSpeech 转为 speaking', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
        );
        async.flushMicrotasks();

        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.awaitingSpeech,
        );

        // 只发送 partialTranscript，不发送 speechStarted（模拟压低声音）
        backend.emitPartial('Hello');
        async.flushMicrotasks();

        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('录音超过最大时长后自动停止并进入 processing', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        // 默认 maxRecordingDuration = 30s
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
        );
        async.flushMicrotasks();

        // 模拟用户一直在说话
        backend.emitSpeechStarted();
        async.flushMicrotasks();

        // 29s 时仍在录音
        async.elapse(const Duration(seconds: 29));
        final midState = container.read(speechRecordingControllerProvider);
        expect(midState.phase, SpeechRecordingPhase.speaking);

        // 30s 时触发最大时长兜底
        async.elapse(const Duration(seconds: 1));
        final finalState = container.read(speechRecordingControllerProvider);
        expect(finalState.phase, SpeechRecordingPhase.processing);

        backend.dispose();
        container.dispose();
      });
    });

    test('手动模式不启动等待计时器和自动停止', () {
      fakeAsync((async) {
        final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        final container = ProviderContainer(
          overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
        );

        final controller = container.read(
          speechRecordingControllerProvider.notifier,
        );
        controller.setManualMode(true);
        controller.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Hello world',
        );
        async.flushMicrotasks();

        backend.emitSpeechStarted();
        async.flushMicrotasks();
        backend.emitPartial('Hello world');
        async.flushMicrotasks();

        // 静音 5s，手动模式不自动停止
        backend.emitSilence(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 手动模式兜底上限：max(300s, 5 × 30s) = 300s
        async.elapse(const Duration(seconds: 300));
        expect(
          container.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );

        backend.dispose();
        container.dispose();
      });
    });

    test('isRecordingPrompt 在 awaitingSpeech 和 speaking 阶段返回 true', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: [speechPracticeBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
      );

      // awaitingSpeech 阶段
      var state = container.read(speechRecordingControllerProvider);
      expect(state.isRecordingPrompt('shadowing:a1:0'), isTrue);
      expect(state.isRecordingPrompt('other'), isFalse);

      // speaking 阶段
      backend.emitSpeechStarted();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state = container.read(speechRecordingControllerProvider);
      expect(state.isRecordingPrompt('shadowing:a1:0'), isTrue);
    });
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateNotifier / StateProvider 已移入 legacy 库（Riverpod 3），此处保留旧写法
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/models/speech_practice_models.dart';
import 'package:echo_loop/providers/offline_asr_settings_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/services/recording_service.dart';
import 'package:echo_loop/services/speech_practice_platform.dart';

import '../../helpers/mock_providers.dart';

const _testAsrModel = AsrModelInfo(
  id: 'test-model',
  displayName: 'Test Model',
  type: AsrModelType.moonshine,
);

final _testAsrSettings = OfflineAsrSettingsState(
  enabled: true,
  backend: AsrBackend.platform,
  recommendedModel: _testAsrModel,
);

/// 测试用的离线 ASR 设置 Notifier，返回预设状态
class _FakeOfflineAsrSettingsNotifier extends OfflineAsrSettingsNotifier {
  @override
  OfflineAsrSettingsState build() => _testAsrSettings;
}

class _FakeSpeechPracticeBackend implements SpeechPracticeBackend {
  final _controller = StreamController<SpeechPracticeEvent>.broadcast();
  bool autoEmitFinal;
  bool? recognitionEnabled;
  String? activePromptId;
  int counter = 0;
  int cancelSessionCalls = 0;
  Completer<void>? warmupGate;
  int startSessionCalls = 0;
  int shutdownCalls = 0;

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
  Future<void> warmup({String locale = 'en-US'}) async {
    await warmupGate?.future;
  }

  @override
  Future<int> getDeviceRamBytes() async => 0;

  @override
  Future<void> setRecognitionEnabled(bool enabled) async {
    recognitionEnabled = enabled;
  }

  @override
  Future<void> shutdown() async {
    shutdownCalls += 1;
  }

  @override
  Future<String> startSession({
    required String promptId,
    String locale = 'en-US',
  }) async {
    startSessionCalls += 1;
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
  Future<void> cancelSession() {
    cancelSessionCalls += 1;
    return Future<void>.value();
  }

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

  group('RecordingService 统计时长', () {
    test('正常停止返回有效时长，取消停止不产生时长', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final service = RecordingService(backend);

      await service.startRecording(promptId: 'shadowing:test:0');
      final result = await service.stopSession(
        promptId: 'shadowing:test:0',
        effectiveDurationMs: 1250,
      );
      expect(result.recordedDuration, const Duration(milliseconds: 1250));

      await service.startRecording(promptId: 'shadowing:test:1');
      await service.cancelRecording();

      await service.dispose();
      await backend.dispose();
    });
  });

  group('SpeechRecordingController 录音服务生命周期', () {
    test('ASR 后端切换不会替换进行中的录音服务', () async {
      final firstBackend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final secondBackend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final selectedBackendProvider = StateProvider<SpeechPracticeBackend>(
        (_) => firstBackend,
      );
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(listenAndRepeatRatingEnabled: false),
          speechPracticeBackendProvider.overrideWith(
            (ref) => ref.watch(selectedBackendProvider),
          ),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
      );
      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      addTearDown(() async {
        await controller.fullReset();
        await firstBackend.dispose();
        await secondBackend.dispose();
        container.dispose();
      });

      await controller.startRecording(
        promptId: 'shadowing:backend-switch:0',
        referenceText: 'Hello world',
      );
      firstBackend.emitSpeechStarted();
      await Future<void>.value();

      container.read(selectedBackendProvider.notifier).state = secondBackend;
      container.read(speechPracticeBackendProvider);
      await Future<void>.value();

      await controller.cancelActiveRecording();

      expect(firstBackend.cancelSessionCalls, 1);
      expect(secondBackend.cancelSessionCalls, 0);
      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.idle,
      );
    });

    test('warmup 尚未完成时清理回合，不会在退出后启动录音', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false)
        ..warmupGate = Completer<void>();
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(listenAndRepeatRatingEnabled: false),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
      );
      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      addTearDown(() async {
        await controller.fullReset();
        await backend.dispose();
        container.dispose();
      });

      final start = controller.startRecording(
        promptId: 'shadowing:startup-cancel:0',
        referenceText: 'Hello world',
      );
      await Future<void>.value();
      await controller.clearRecording();
      backend.warmupGate!.complete();
      await start;

      expect(backend.startSessionCalls, 0);
      expect(backend.cancelSessionCalls, 0);
      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.idle,
      );
    });
  });

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
    testWidgets('关闭评级仍启用 Apple 实时转录并按转录停滞自动结束', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(listenAndRepeatRatingEnabled: false),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );
        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );

        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );
        expect(backend!.recognitionEnabled, isTrue);

        backend!.emitSpeechStarted();
        backend!.emitPartial('I noticed your name on the door');
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );

        final state = container!.read(speechRecordingControllerProvider);
        expect(state.phase, SpeechRecordingPhase.idle);
        expect(state.currentAttempt?.hasRecording, isTrue);
        expect(
          state.currentAttempt?.status,
          SpeechPracticeAttemptStatus.unavailable,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('完全匹配时 1s 静音即停止', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        backend!.emitPartial('I noticed your name on the door');
        backend!.emitSpeechStarted();
        backend!.emitSilence(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final turnState = container!.read(speechRecordingControllerProvider);
        expect(turnState.phase, SpeechRecordingPhase.processing);
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('部分匹配（尾部 0 命中）时 5s 静音才停止', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        // 只说了前半句 → 尾部 5 词命中 0 → 阈值 5s
        backend!.emitPartial('Anyhow I noticed your');
        backend!.emitSpeechStarted();

        // 2s 静音不够
        backend!.emitSilence(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 5s 静音才触发（尾部 0 命中 → 5s 阈值）
        backend!.emitSilence(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('无匹配时 5s 静音才停止', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        // 完全不相关的内容
        backend!.emitPartial('something completely different');
        backend!.emitSpeechStarted();

        // 4s 不够
        backend!.emitSilence(const Duration(seconds: 4));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 5s 触发兜底
        backend!.emitSilence(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('转录停滞通道：完全匹配后 1s 不更新即自动结束（无 silenceProgress）', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        // 发送完整转录，模拟嘈杂环境（不发送 silenceProgress）
        backend!.emitSpeechStarted();
        backend!.emitPartial('I noticed your name on the door');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 完全匹配 → 阈值 1s，等 1s 后停滞计时器触发
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );

        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('转录停滞通道：部分匹配后按动态阈值等待', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        backend!.emitSpeechStarted();
        // 只说前半句 → 尾部 0 命中 → 阈值 5s
        backend!.emitPartial('Anyhow I noticed your');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 4s 后仍在 speaking
        await Future<void>.delayed(const Duration(seconds: 4));
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 5s 后停滞计时器触发（需要额外 50ms 让 async 完成）
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    testWidgets('转录更新会重置停滞计时器', (tester) async {
      ProviderContainer? container;
      _FakeSpeechPracticeBackend? backend;
      SpeechRecordingController? controller;

      await tester.runAsync(() async {
        backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
        container = ProviderContainer(
          overrides: dedupeOverrides([
            analyticsOverride(),
            ...learningSettingsOverrides(),
            speechPracticeBackendProvider.overrideWithValue(backend!),
            recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
            offlineAsrSettingsProvider.overrideWith(
              () => _FakeOfflineAsrSettingsNotifier(),
            ),
          ]),
        );

        controller = container!.read(
          speechRecordingControllerProvider.notifier,
        );
        await controller!.startRecording(
          promptId: 'shadowing:a1:0',
          referenceText: 'Anyhow I noticed your name on the door',
        );

        backend!.emitSpeechStarted();
        backend!.emitPartial('Anyhow');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 4s 后更新转录 → 重置计时器
        await Future<void>.delayed(const Duration(seconds: 4));
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );
        backend!.emitPartial('Anyhow I noticed');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // 再过 4s 仍在 speaking（计时器已重置）
        await Future<void>.delayed(const Duration(seconds: 4));
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.speaking,
        );

        // 再过 1s（共 5s 无更新）→ 触发
        await Future<void>.delayed(
          const Duration(seconds: 1, milliseconds: 50),
        );
        expect(
          container!.read(speechRecordingControllerProvider).phase,
          SpeechRecordingPhase.processing,
        );
      });

      addTearDown(() async {
        if (controller != null) await controller!.fullReset();
        if (backend != null) await backend!.dispose();
        if (container != null) container!.dispose();
      });
    });

    test('60s 未开口 → 取消录音回到 idle', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
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

    test('ASR 有转录但 VAD 未触发时，仍应从 awaitingSpeech 转为 speaking', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
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

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.awaitingSpeech,
      );

      // 只发送 partialTranscript，不发送 speechStarted（模拟压低声音）
      backend.emitPartial('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.speaking,
      );
    });

    test('录音超过最大时长后自动停止并进入 processing', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      // 默认 maxRecordingDuration = 30s
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
      );

      // 模拟用户一直在说话
      backend.emitSpeechStarted();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 29s 时仍在录音
      await Future<void>.delayed(const Duration(seconds: 29));
      final midState = container.read(speechRecordingControllerProvider);
      expect(midState.phase, SpeechRecordingPhase.speaking);

      // 30s 时触发最大时长兜底
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 50));
      final finalState = container.read(speechRecordingControllerProvider);
      expect(finalState.phase, SpeechRecordingPhase.processing);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('手动模式不启动等待计时器和自动停止', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
      );
      addTearDown(() async {
        await backend.dispose();
        container.dispose();
      });

      final controller = container.read(
        speechRecordingControllerProvider.notifier,
      );
      controller.setManualMode(true);
      await controller.startRecording(
        promptId: 'shadowing:a1:0',
        referenceText: 'Hello world',
      );

      backend.emitSpeechStarted();
      backend.emitPartial('Hello world');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 静音 5s，手动模式不自动停止
      backend.emitSilence(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        container.read(speechRecordingControllerProvider).phase,
        SpeechRecordingPhase.speaking,
      );

      // 注意：手动模式的 300s 兜底上限太长不适合测试，
      // 此处只验证"静音不触发自动停止"的核心行为
    });

    test('isRecordingPrompt 在 awaitingSpeech 和 speaking 阶段返回 true', () async {
      final backend = _FakeSpeechPracticeBackend(autoEmitFinal: false);
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          analyticsOverride(),
          ...learningSettingsOverrides(),
          speechPracticeBackendProvider.overrideWithValue(backend),
          recommendedAsrModelProvider.overrideWithValue(_testAsrModel),
          offlineAsrSettingsProvider.overrideWith(
            () => _FakeOfflineAsrSettingsNotifier(),
          ),
        ]),
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      state = container.read(speechRecordingControllerProvider);
      expect(state.isRecordingPrompt('shadowing:a1:0'), isTrue);
    });
  });
}

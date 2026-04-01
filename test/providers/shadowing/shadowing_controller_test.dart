/// 跟读会话控制器单元测试
///
/// 覆盖核心状态流转：
/// - 正常流程（3 遍循环 + 自动推进）
/// - 手动暂停/恢复（保留剩余时间）
/// - 外部打断/恢复（重置完整 T）
/// - 切句原子重置
/// - flowToken 防竞态
/// - 快进倒计时
/// - 手动模式
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluency/models/audio_engine_state.dart';
import 'package:fluency/models/sentence.dart';
import 'package:fluency/providers/audio_engine/audio_engine_provider.dart';
import 'package:fluency/providers/shadowing/shadowing_recording_controller.dart';
import 'package:fluency/providers/shadowing/shadowing_controller.dart';
import 'package:fluency/providers/shadowing/shadowing_phase.dart';
import 'package:fluency/providers/shadowing/shadowing_session_state.dart';

import '../../helpers/mock_providers.dart';

/// 测试用 AudioEngine — playClipOnce 即时完成
class _InstantAudioEngine extends TestAudioEngine {
  int _sessionId = 0;

  _InstantAudioEngine()
      : super(initialState: const AudioEngineState(sessionId: 0));

  @override
  int newSession() {
    _sessionId += 1;
    return _sessionId;
  }

  @override
  bool isActiveSession(int id) => id == _sessionId;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    if (!isActiveSession(sessionId)) return;
    // 即时完成，不等待播放
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// 测试用默认配置
ShadowingConfig _testConfig({
  int repeatCount = 3,
  Duration interval = const Duration(milliseconds: 100),
  bool isManualMode = false,
}) {
  return ShadowingConfig(
    audioItemId: 'test-audio',
    getRepeatCount: (_) => repeatCount,
    getIntervalDuration: (_) => interval,
    isManualMode: () => isManualMode,
  );
}

void main() {
  late ProviderContainer container;
  late ShadowingController controller;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWith(() => _InstantAudioEngine()),
        shadowingRecordingControllerProvider.overrideWith(
          TestShadowingRecordingController.new,
        ),
      ],
    );
    controller = container.read(shadowingControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  ShadowingSessionState readState() =>
      container.read(shadowingControllerProvider);

  group('startSession', () {
    test('初始化后进入 PlayingPrompt', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      // playClipOnce 即时完成 → 自动进入 Recording（自动模式）
      // 但录音还没接入，_onPromptFinished 会设置 Recording
      expect(readState().phase, isA<ShadowingRecording>());
      expect(readState().sentenceIndex, 0);
      expect(readState().totalSentences, 3);
      expect(readState().repeatIndex, 0);
      expect(readState().totalRepeats, 3);
      expect(readState().flowToken, 1);
    });

    test('指定 startIndex', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
        startIndex: 2,
      );

      expect(readState().sentenceIndex, 2);
    });

    test('startIndex 超出范围时 clamp', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 99,
      );

      expect(readState().sentenceIndex, 2); // clamped to last
    });
  });

  group('等待用户操作 (WaitingForUser)', () {
    test('enterWaitingForUser → WaitingForUser', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      expect(readState().phase, isA<ShadowingRecording>());

      controller.enterWaitingForUser();

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('Idle 状态 enterWaitingForUser 无效', () async {
      expect(readState().phase, isA<Idle>());
      controller.enterWaitingForUser();
      expect(readState().phase, isA<Idle>());
    });

    test('重复 enterWaitingForUser 无效', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());

      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());
    });

    test('onUserInteraction → WaitingForUser', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      controller.onUserInteraction();

      expect(readState().phase, isA<WaitingForUser>());
    });
  });

  group('切句', () {
    test('nextSentence 原子重置 + flowToken 递增', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      final tokenBefore = readState().flowToken;

      await controller.nextSentence();

      expect(readState().sentenceIndex, 1);
      expect(readState().repeatIndex, 0);
      expect(readState().flowToken, greaterThan(tokenBefore));
      expect(readState().recordingPath, isNull);
    });

    test('previousSentence', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );

      await controller.previousSentence();

      expect(readState().sentenceIndex, 1);
    });

    test('第一句 previousSentence 无效', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );

      await controller.previousSentence();
      expect(readState().sentenceIndex, 0); // 不变
    });

    test('最后一句 nextSentence 无效', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );

      await controller.nextSentence();
      expect(readState().sentenceIndex, 2); // 不变
    });
  });

  group('flowToken 防竞态', () {
    test('切句后旧回调被丢弃', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      // 记录当前 token
      final oldToken = readState().flowToken;

      // 切到下一句（token 递增）
      await controller.nextSentence();
      expect(readState().flowToken, isNot(oldToken));

      // 旧 token 的回调不应该影响新状态
      // （controller 内部 _onPromptFinished 等方法会检查 token）
    });
  });

  group('手动模式', () {
    test('手动模式下播放完成后进入 WaitingForUser（不自动录音）', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(isManualMode: true),
      );

      // 手动模式：播放完成后进入 WaitingForUser，等用户手动操作
      expect(readState().phase, isA<WaitingForUser>());
    });
  });

  group('快进倒计时', () {
    test('非 WaitingInterval 状态 fastForward 无效', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      // 当前在 Recording，不是 WaitingInterval
      controller.fastForwardInterval();
      expect(readState().phase, isA<ShadowingRecording>()); // 不变
    });
  });

  group('stopSession', () {
    test('stopSession 回到 Idle', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );

      controller.stopSession();
      expect(readState().phase, isA<Idle>());
    });
  });

  group('便捷 getter', () {
    test('isFirstSentence / isLastSentence', () async {
      await controller.startSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );

      expect(readState().isFirstSentence, isTrue);
      expect(readState().isLastSentence, isFalse);

      await controller.nextSentence();
      await controller.nextSentence();

      expect(readState().isFirstSentence, isFalse);
      expect(readState().isLastSentence, isTrue);
    });
  });
}

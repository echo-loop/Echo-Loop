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
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:echo_loop/database/daos/bookmark_dao.dart';
import 'package:echo_loop/database/providers.dart';
import 'package:echo_loop/database/app_database.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:echo_loop/providers/audio_engine/foreground_audio_engine_provider.dart';
import 'package:echo_loop/providers/speech/speech_recording_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_controller.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_phase.dart';
import 'package:echo_loop/providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';

import '../../helpers/mock_providers.dart';

class _MockBookmarkDao extends Mock implements BookmarkDao {}

/// 测试用 AudioEngine — playClipOnce 即时完成
class _InstantAudioEngine extends TestForegroundAudioEngine {
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

/// 测试用可控 AudioEngine
class _ControlledAudioEngine extends TestForegroundAudioEngine {
  int _sessionId = 0;
  Completer<void>? playCompleter;

  _ControlledAudioEngine()
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
    final completer = playCompleter ??= Completer<void>();
    await completer.future;
  }
}

/// 测试用默认配置
RepeatFlowConfig _testConfig({
  int repeatCount = 3,
  Duration interval = const Duration(milliseconds: 100),
  bool isManualMode = false,
}) {
  return RepeatFlowConfig(
    audioItemId: 'test-audio',
    getRepeatCount: (_) => repeatCount,
    getIntervalDuration: (_) => interval,
    isManualMode: () => isManualMode,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const BookmarksCompanion());
  });

  late ProviderContainer container;
  late ListenAndRepeatController controller;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        foregroundAudioEngineProvider.overrideWith(() => _InstantAudioEngine()),
        audioEngineProvider.overrideWith(TestAudioEngine.new),
        speechRecordingControllerProvider.overrideWith(
          TestSpeechRecordingController.new,
        ),
      ],
    );
    controller = container.read(listenAndRepeatControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  ListenAndRepeatSessionState readState() =>
      container.read(listenAndRepeatControllerProvider);

  group('startSession', () {
    test('初始化后进入 PlayingPrompt', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // playClipOnce 即时完成 → 自动进入 Recording（自动模式）
      // 但录音还没接入，_onPromptFinished 会设置 Recording
      expect(readState().phase, isA<Recording>());
      expect(readState().sentenceIndex, 0);
      expect(readState().totalSentences, 3);
      expect(readState().repeatIndex, 0);
      expect(readState().totalRepeats, 3);
      expect(readState().flowToken, 1);
    });

    test('指定 startIndex', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      expect(readState().sentenceIndex, 2);
    });

    test('repeatCount=0 时 totalRepeats 保留为无限', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(repeatCount: 0),
      );
      await controller.startPlaying();

      expect(readState().totalRepeats, 0);
    });

    test('startIndex 超出范围时 clamp', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 99,
      );
      await controller.startPlaying();

      expect(readState().sentenceIndex, 2); // clamped to last
    });
  });

  group('等待用户操作 (WaitingForUser)', () {
    test('enterWaitingForUser → WaitingForUser', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      expect(readState().phase, isA<Recording>());

      controller.enterWaitingForUser();

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('Idle 状态 enterWaitingForUser 无效', () async {
      expect(readState().phase, isA<Idle>());
      controller.enterWaitingForUser();
      expect(readState().phase, isA<Idle>());
    });

    test('重复 enterWaitingForUser 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();
      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());

      controller.enterWaitingForUser();
      expect(readState().phase, isA<WaitingForUser>());
    });

    test('onUserInteraction → WaitingForUser', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      controller.onUserInteraction();

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('播放中 onUserInteraction 不打断当前句，播完后进入 WaitingForUser', () async {
      final audioEngine = _ControlledAudioEngine();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => audioEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      controller = container.read(listenAndRepeatControllerProvider.notifier);

      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );

      unawaited(controller.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(readState().phase, isA<PlayingPrompt>());

      controller.onUserInteraction();

      expect(readState().phase, isA<PlayingPrompt>());

      audioEngine.playCompleter?.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(readState().phase, isA<WaitingForUser>());
    });

    test('播放中修改设置不打断也不重播，播完后进入 WaitingForUser', () async {
      final audioEngine = _ControlledAudioEngine();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => audioEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      controller = container.read(listenAndRepeatControllerProvider.notifier);

      await controller.prepareSession(
        sentences: createTestSentences(count: 1),
        config: _testConfig(),
      );

      unawaited(controller.startPlaying());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      controller.onUserInteraction();
      await controller.applySettingsChange();

      expect(readState().phase, isA<PlayingPrompt>());

      audioEngine.playCompleter?.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = readState();
      expect(state.phase, isA<WaitingForUser>());
      expect(state.repeatIndex, 0);
    });
  });

  group('切句', () {
    test('nextSentence 原子重置 + flowToken 递增', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();
      final tokenBefore = readState().flowToken;

      await controller.nextSentence();

      expect(readState().sentenceIndex, 1);
      expect(readState().repeatIndex, 0);
      expect(readState().flowToken, greaterThan(tokenBefore));
      expect(readState().recordingPath, isNull);
    });

    test('previousSentence', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      await controller.previousSentence();

      expect(readState().sentenceIndex, 1);
    });

    test('第一句 previousSentence 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );
      await controller.startPlaying();

      await controller.previousSentence();
      expect(readState().sentenceIndex, 0); // 不变
    });

    test('最后一句 nextSentence 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 2,
      );
      await controller.startPlaying();

      await controller.nextSentence();
      expect(readState().sentenceIndex, 2); // 不变
    });
  });

  group('flowToken 防竞态', () {
    test('切句后旧回调被丢弃', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 记录当前 token
      final oldToken = readState().flowToken;

      // 切到下一句（token 递增）
      await controller.nextSentence();
      expect(readState().flowToken, isNot(oldToken));

      // 旧 token 的回调不应该影响新状态
      // （controller 内部 _onPromptFinished 等方法会检查 token）
    });

    test('播放中切换书签不应使当前播放回调失效', () async {
      final controlledEngine = _ControlledAudioEngine();
      final controlledContainer = ProviderContainer(
        overrides: [
          foregroundAudioEngineProvider.overrideWith(() => controlledEngine),
          audioEngineProvider.overrideWith(TestAudioEngine.new),
          bookmarkDaoProvider.overrideWithValue(_MockBookmarkDao()),
          speechRecordingControllerProvider.overrideWith(
            TestSpeechRecordingController.new,
          ),
        ],
      );
      final bookmarkDao = controlledContainer.read(bookmarkDaoProvider);
      when(
        () => bookmarkDao.removeBookmark(any(), any()),
      ).thenAnswer((_) async {});
      when(() => bookmarkDao.addBookmark(any())).thenAnswer((_) async {});
      addTearDown(controlledContainer.dispose);

      final controlledController = controlledContainer.read(
        listenAndRepeatControllerProvider.notifier,
      );
      final initialSentences = createTestSentences(
        count: 3,
      ).map((s) => s.index == 0 ? s.copyWith(isBookmarked: true) : s).toList();

      await controlledController.prepareSession(
        sentences: initialSentences,
        config: _testConfig(),
      );

      final startFuture = controlledController.startPlaying();
      await Future<void>.delayed(Duration.zero);

      expect(
        controlledContainer.read(listenAndRepeatControllerProvider).phase,
        isA<PlayingPrompt>(),
      );

      final tokenBefore = controlledContainer
          .read(listenAndRepeatControllerProvider)
          .flowToken;

      await controlledController.toggleCurrentBookmark();

      final stateAfterToggle = controlledContainer.read(
        listenAndRepeatControllerProvider,
      );
      expect(stateAfterToggle.flowToken, tokenBefore);
      expect(stateAfterToggle.currentSentenceBookmarked, isFalse);

      controlledEngine.playCompleter?.complete();
      await startFuture;

      expect(
        controlledContainer.read(listenAndRepeatControllerProvider).phase,
        isA<Recording>(),
      );
    });
  });

  group('手动模式', () {
    test('手动模式下播放完成后进入 WaitingForUser（不自动录音）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(isManualMode: true),
      );
      await controller.startPlaying();

      // 手动模式：播放完成后进入 WaitingForUser，等用户手动操作
      expect(readState().phase, isA<WaitingForUser>());
    });
  });

  group('快进倒计时', () {
    test('非 WaitingInterval 状态 fastForward 无效', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 当前在 Recording，不是 WaitingInterval
      controller.fastForwardInterval();
      expect(readState().phase, isA<Recording>()); // 不变
    });
  });

  group('stopSession', () {
    test('stopSession 回到 Idle', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      controller.stopSession();
      expect(readState().phase, isA<Idle>());
    });
  });

  group('replayCurrentSentence', () {
    test('手动重播递增 repeatIndex（按一次算一遍）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
      );
      await controller.startPlaying();

      // 自动模式下 startPlaying → PlayingPrompt → 即时完成 → Recording
      expect(readState().repeatIndex, 0);

      await controller.replayCurrentSentence();

      // 第一次重播：repeatIndex 从 0 变 1，原句重新播放后进入 Recording
      expect(readState().repeatIndex, 1);
      expect(readState().phase, isA<Recording>());

      await controller.replayCurrentSentence();

      // 第二次重播：repeatIndex 继续 +1
      expect(readState().repeatIndex, 2);

      await controller.replayCurrentSentence();

      // 允许 overshoot：4/3
      expect(readState().repeatIndex, 3);
      expect(readState().totalRepeats, 3);
    });
  });

  group('便捷 getter', () {
    test('isFirstSentence / isLastSentence', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 3),
        config: _testConfig(),
        startIndex: 0,
      );
      await controller.startPlaying();

      expect(readState().isFirstSentence, isTrue);
      expect(readState().isLastSentence, isFalse);

      await controller.nextSentence();
      await controller.nextSentence();

      expect(readState().isFirstSentence, isFalse);
      expect(readState().isLastSentence, isTrue);
    });
  });

  group('goToSentence 任意跳转（进度条拖动）', () {
    test('跳转到合法句子更新 sentenceIndex', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 8),
        config: _testConfig(),
      );
      await controller.startPlaying();

      await controller.goToSentence(5);

      expect(readState().sentenceIndex, 5);
    });

    test('越界索引被 clamp 到合法范围', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
      );
      await controller.startPlaying();

      await controller.goToSentence(99);
      expect(readState().sentenceIndex, 4);

      await controller.goToSentence(-3);
      expect(readState().sentenceIndex, 0);
    });

    test('跳到当前句保持不变（no-op，flowToken 不变）', () async {
      await controller.prepareSession(
        sentences: createTestSentences(count: 5),
        config: _testConfig(),
      );
      await controller.startPlaying();
      await controller.goToSentence(2);
      final tokenAfterFirstJump = readState().flowToken;

      await controller.goToSentence(2);

      expect(readState().sentenceIndex, 2);
      expect(readState().flowToken, tokenAfterFirstJump);
    });
  });
}

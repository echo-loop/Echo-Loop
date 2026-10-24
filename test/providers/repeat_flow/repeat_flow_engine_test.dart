import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_engine.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_phase.dart';
import 'package:echo_loop/providers/repeat_flow/repeat_flow_state.dart';

void main() {
  test('暂停后的恢复使用精确位置且不增加重复次数或更换 prompt', () async {
    final firstPlayback = Completer<SentencePlaybackResult>();
    final resumeOffsets = <Duration>[];
    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) => firstPlayback.future,
        resumeSentence: (_, _, startAt) async {
          resumeOffsets.add(startAt);
          return SentencePlaybackResult.completed;
        },
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    final sentence = Sentence(
      index: 0,
      text: 'Repeat this sentence.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 1),
    );
    engine.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 3,
        getIntervalDuration: (_) => const Duration(seconds: 30),
        isManualMode: () => false,
      ),
    );
    final promptId = engine.currentPromptId;
    final initialPlayback = engine.startPlaying();
    await Future<void>.delayed(Duration.zero);
    engine.enterWaitingForUser();

    const pausedAt = Duration(milliseconds: 420);
    await engine.resumeCurrentSentence(pausedAt);
    firstPlayback.complete(SentencePlaybackResult.cancelled);
    await initialPlayback;

    expect(resumeOffsets, [pausedAt]);
    expect(engine.state.repeatIndex, 0);
    expect(engine.currentPromptId, promptId);
    expect(engine.state.phase, isA<Recording>());
    engine.dispose();
  });

  test('恢复检查等待期间切句不会把暂停位置用于新句', () async {
    final firstPlayback = Completer<SentencePlaybackResult>();
    final firstPlaybackStarted = Completer<void>();
    final targetPlaybackStarted = Completer<void>();
    final resumeStartReached = Completer<void>();
    final resumeStartGate = Completer<void>();
    final playedIndices = <int>[];
    final resumedOffsets = <({int sentenceIndex, Duration startAt})>[];
    var holdResumeStart = false;
    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (sentence, _) async {
          playedIndices.add(sentence.index);
          if (sentence.index == 0) {
            if (!firstPlaybackStarted.isCompleted) {
              firstPlaybackStarted.complete();
            }
            return firstPlayback.future;
          }
          targetPlaybackStarted.complete();
          return SentencePlaybackResult.completed;
        },
        resumeSentence: (sentence, _, startAt) async {
          resumedOffsets.add((sentenceIndex: sentence.index, startAt: startAt));
          if (sentence.index == 1 && !targetPlaybackStarted.isCompleted) {
            targetPlaybackStarted.complete();
          }
          return SentencePlaybackResult.completed;
        },
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    engine.prepare(
      sentences: List<Sentence>.generate(
        2,
        (index) => Sentence(
          index: index,
          text: 'Sentence $index.',
          startTime: Duration(seconds: index),
          endTime: Duration(seconds: index + 1),
        ),
      ),
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => Duration.zero,
        isManualMode: () => false,
        onBeforeSentenceStart: (_) async {
          if (holdResumeStart) {
            holdResumeStart = false;
            resumeStartReached.complete();
            await resumeStartGate.future;
          }
        },
      ),
    );

    final initialPlay = engine.startPlaying();
    await firstPlaybackStarted.future;
    engine.enterWaitingForUser();

    holdResumeStart = true;
    const pausedAt = Duration(milliseconds: 420);
    final resume = engine.resumeCurrentSentence(pausedAt);
    await resumeStartReached.future;

    await engine.nextSentence();
    await targetPlaybackStarted.future;
    resumeStartGate.complete();
    firstPlayback.complete(SentencePlaybackResult.cancelled);
    await Future.wait([resume, initialPlay]);

    expect(playedIndices, [0, 1]);
    expect(resumedOffsets, isEmpty);
    expect(engine.state.sentenceIndex, 1);
    engine.dispose();
  });

  test('停止后重新准备会话不会继承上一句的用户接管状态', () async {
    RepeatFlowState? latestState;
    final engine = RepeatFlowEngine(
      onStateChanged: (state) => latestState = state,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.completed,
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => true,
      ),
    );
    final sentences = [
      Sentence(
        index: 0,
        text: 'Repeat this sentence.',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 1),
      ),
    ];
    final config = RepeatFlowConfig(
      audioItemId: 'audio-1',
      getRepeatCount: (_) => 2,
      getIntervalDuration: (_) => const Duration(seconds: 30),
      isManualMode: () => false,
    );

    engine.prepare(sentences: sentences, config: config);
    await engine.startPlaying();
    expect(engine.onRecordingFinished('/tmp/first-recording.m4a', 0.9), isTrue);
    expect(latestState?.phase, isA<WaitingInterval>());
    expect(latestState?.controlMode, RepeatControlMode.automatic);
    expect(
      latestState?.postRecordingAction,
      RepeatPostRecordingAction.startInterval,
    );

    engine.enterWaitingForUser();
    expect(latestState?.phase, isA<WaitingForUser>());
    expect(latestState?.controlMode, RepeatControlMode.automatic);
    expect(
      latestState?.postRecordingAction,
      RepeatPostRecordingAction.waitForUser,
    );
    engine.stopSession();

    engine.prepare(sentences: sentences, config: config);
    await engine.startPlaying();
    expect(
      engine.onRecordingFinished('/tmp/second-recording.m4a', 0.9),
      isTrue,
    );

    expect(latestState?.phase, isA<WaitingInterval>());
    expect(latestState?.controlMode, RepeatControlMode.automatic);
    expect(
      latestState?.postRecordingAction,
      RepeatPostRecordingAction.startInterval,
    );
  });

  test('迟到的旧录音结果不会污染当前录音回合', () async {
    RepeatFlowState? latestState;
    final engine = RepeatFlowEngine(
      onStateChanged: (state) => latestState = state,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.completed,
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => true,
      ),
    );
    final sentence = Sentence(
      index: 0,
      text: 'Repeat this sentence.',
      startTime: Duration.zero,
      endTime: const Duration(seconds: 1),
    );
    engine.prepare(
      sentences: [sentence],
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => const Duration(seconds: 30),
        isManualMode: () => false,
      ),
    );
    await engine.startPlaying();

    final currentPromptId = engine.currentPromptId;
    expect(
      engine.onRecordingFinished(
        '/tmp/stale-recording.m4a',
        0.1,
        promptId: 'lar:audio-1:stale',
      ),
      isFalse,
    );
    expect(latestState?.phase, isA<Recording>());
    expect(latestState?.recordingPath, isNull);

    expect(
      engine.onRecordingFinished(
        '/tmp/current-recording.m4a',
        0.9,
        promptId: currentPromptId,
      ),
      isTrue,
    );
    expect(latestState?.phase, isA<WaitingInterval>());
    expect(latestState?.recordingPath, '/tmp/current-recording.m4a');
  });

  test('切句清理进行中会拒绝重复导航请求', () async {
    final clearGate = Completer<void>();
    var clearCalls = 0;
    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.completed,
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {
          clearCalls += 1;
          return clearGate.future;
        },
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => true,
      ),
    );
    final sentences = List<Sentence>.generate(
      3,
      (index) => Sentence(
        index: index,
        text: 'Sentence $index.',
        startTime: Duration(seconds: index),
        endTime: Duration(seconds: index + 1),
      ),
    );
    engine.prepare(
      sentences: sentences,
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => Duration.zero,
        isManualMode: () => false,
      ),
    );
    await engine.startPlaying();

    final firstNavigation = engine.nextSentence();
    final duplicateNavigation = engine.nextSentence();
    await duplicateNavigation;

    expect(engine.state.sentenceIndex, 0);
    expect(engine.state.isTransitioning, isTrue);
    expect(clearCalls, greaterThan(0));

    clearGate.complete();
    await firstNavigation;

    expect(engine.state.sentenceIndex, 1);
    expect(engine.state.isTransitioning, isFalse);
  });

  test('无评分但有录音文件时保留录音并继续流程', () async {
    var clearRecordingCalls = 0;
    RepeatFlowState? latestState;
    final engine = RepeatFlowEngine(
      onStateChanged: (state) => latestState = state,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.completed,
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () => clearRecordingCalls += 1,
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => true,
      ),
    );
    engine.prepare(
      sentences: [
        Sentence(
          index: 0,
          text: 'Practice this sentence.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ],
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => const Duration(seconds: 30),
        isManualMode: () => false,
      ),
    );

    await engine.startPlaying();
    expect(latestState?.phase, isA<Recording>());

    engine.onRecordingFinished('/tmp/recording.m4a', null);

    expect(latestState?.recordingPath, '/tmp/recording.m4a');
    expect(latestState?.recordingScore, isNull);
    expect(latestState?.phase, isA<WaitingInterval>());
    expect(clearRecordingCalls, 0);
  });

  test('播放被取消时不进入录音', () async {
    var recordingStarts = 0;
    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.cancelled,
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) => recordingStarts += 1,
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () {},
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    engine.prepare(
      sentences: [
        Sentence(
          index: 0,
          text: 'Cancelled prompt.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ],
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => Duration.zero,
        isManualMode: () => false,
      ),
    );

    await engine.startPlaying();

    expect(recordingStarts, 0);
    expect(engine.state.phase, isA<WaitingForUser>());
  });

  test('重播会等待录音清理完成后才开始下一次播放', () async {
    final clearGate = Completer<void>();
    var playCalls = 0;
    final engine = RepeatFlowEngine(
      onStateChanged: (_) {},
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async {
          playCalls += 1;
          return SentencePlaybackResult.completed;
        },
        startRecording:
            ({
              required promptId,
              required referenceText,
              required maxDuration,
              referenceDuration,
            }) {},
        cancelRecording: () async {},
        stopAndEvaluate: ({required referenceText}) async {},
        clearRecording: () => clearGate.future,
        setMaxRecordingDuration: (_) {},
        hasDetectedSpeech: () => false,
      ),
    );
    engine.prepare(
      sentences: [
        Sentence(
          index: 0,
          text: 'Practice this sentence.',
          startTime: Duration.zero,
          endTime: const Duration(seconds: 1),
        ),
      ],
      config: RepeatFlowConfig(
        audioItemId: 'audio-1',
        getRepeatCount: (_) => 1,
        getIntervalDuration: (_) => Duration.zero,
        isManualMode: () => false,
      ),
    );

    await engine.startPlaying();
    expect(playCalls, 1);
    final replay = engine.replayCurrentSentence();
    await Future<void>.value();
    expect(playCalls, 1);

    clearGate.complete();
    await replay;
    expect(playCalls, 2);
  });
}

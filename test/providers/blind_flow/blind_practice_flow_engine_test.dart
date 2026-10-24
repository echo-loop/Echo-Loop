import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/models/sentence_playback_result.dart';
import 'package:echo_loop/providers/blind_flow/blind_practice_flow_engine.dart';
import 'package:echo_loop/providers/blind_flow/blind_practice_flow_phase.dart';

void main() {
  test('恢复句子时传递精确位置且保留当前重复轮次', () async {
    final firstPlayback = Completer<SentencePlaybackResult>();
    final resumeOffsets = <Duration>[];
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) => firstPlayback.future,
        resumeSentence: (_, _, startAt) async {
          resumeOffsets.add(startAt);
          return SentencePlaybackResult.completed;
        },
      ),
    );
    engine.prepare(sentences: _sentences(), config: _manualConfig());
    final initialPlayback = engine.startPlaying();
    await Future<void>.delayed(Duration.zero);
    engine.enterWaitingForUser();

    const pausedAt = Duration(milliseconds: 420);
    await engine.resumeCurrentSentence(pausedAt);
    firstPlayback.complete(SentencePlaybackResult.cancelled);
    await initialPlayback;

    expect(resumeOffsets, [pausedAt]);
    expect(engine.state.repeatIndex, 0);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
    engine.dispose();
  });

  test('恢复检查等待期间切句不会把暂停位置用于新句', () async {
    final firstPlayback = Completer<SentencePlaybackResult>();
    final firstPlaybackStarted = Completer<void>();
    final resumeStartReached = Completer<void>();
    final resumeStartGate = Completer<bool>();
    final playedIndices = <int>[];
    final resumedOffsets = <({int sentenceIndex, Duration startAt})>[];
    var holdResumeStart = false;
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (sentence, _) async {
          playedIndices.add(sentence.index);
          if (sentence.index == 0) {
            if (!firstPlaybackStarted.isCompleted) {
              firstPlaybackStarted.complete();
            }
            return firstPlayback.future;
          }
          return SentencePlaybackResult.completed;
        },
        resumeSentence: (sentence, _, startAt) async {
          resumedOffsets.add((sentenceIndex: sentence.index, startAt: startAt));
          return SentencePlaybackResult.completed;
        },
      ),
    );
    engine.prepare(
      sentences: _sentences(),
      config: BlindPracticeFlowConfig(
        getRepeatCount: (_) => 1,
        getRepeatIntervalDuration: (_) => Duration.zero,
        getSentenceIntervalDuration: (_) => Duration.zero,
        onBeforeSentenceStart: (_) async {
          if (holdResumeStart) {
            holdResumeStart = false;
            resumeStartReached.complete();
            return resumeStartGate.future;
          }
          return true;
        },
        isManualMode: () => true,
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
    resumeStartGate.complete(true);
    firstPlayback.complete(SentencePlaybackResult.cancelled);
    await Future.wait([resume, initialPlay]);

    expect(playedIndices, [0, 1]);
    expect(resumedOffsets, isEmpty);
    expect(engine.state.sentenceIndex, 1);
    engine.dispose();
  });

  test('手动模式完成设置的循环后等待用户，重听从第一遍开始', () {
    fakeAsync((async) {
      final playedIndices = <int>[];
      final startedRounds = <int>[];
      BlindPracticeFlowPhase? previousPhase;
      final engine = BlindPracticeFlowEngine(
        onStateChanged: (state) {
          if (state.phase is BlindPlayingPrompt &&
              previousPhase is! BlindPlayingPrompt) {
            startedRounds.add(state.repeatIndex);
          }
          previousPhase = state.phase;
        },
        callbacks: BlindPracticeFlowCallbacks(
          pauseAudio: () {},
          playSentence: (sentence, _) async {
            playedIndices.add(sentence.index);
            return SentencePlaybackResult.completed;
          },
        ),
      );
      engine.prepare(
        sentences: _sentences(),
        config: _manualConfig(repeatCount: 3),
      );

      unawaited(engine.startPlaying());
      async.flushMicrotasks();
      expect(playedIndices, [0]);
      expect(engine.state.phase, isA<BlindWaitingInterval>());
      expect(engine.state.repeatIndex, 1);

      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(playedIndices, [0, 0]);
      expect(engine.state.phase, isA<BlindWaitingInterval>());
      expect(engine.state.repeatIndex, 2);

      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(playedIndices, [0, 0, 0]);
      expect(engine.state.phase, isA<BlindWaitingForUser>());
      expect(engine.state.sentenceIndex, 0);
      expect(engine.state.repeatIndex, 2);

      unawaited(engine.replayCurrentSentence());
      async.flushMicrotasks();
      expect(playedIndices, [0, 0, 0, 0]);
      expect(startedRounds, [0, 1, 2, 0]);
      expect(engine.state.repeatIndex, 1);
      expect(engine.state.phase, isA<BlindWaitingInterval>());

      unawaited(engine.nextSentence());
      async.flushMicrotasks();
      expect(engine.state.sentenceIndex, 1);

      engine.dispose();
    });
  });

  test('手动模式无限循环时等待用户切句', () {
    fakeAsync((async) {
      final playedIndices = <int>[];
      final engine = BlindPracticeFlowEngine(
        onStateChanged: (_) {},
        callbacks: BlindPracticeFlowCallbacks(
          pauseAudio: () {},
          playSentence: (sentence, _) async {
            playedIndices.add(sentence.index);
            return SentencePlaybackResult.completed;
          },
        ),
      );
      engine.prepare(
        sentences: _sentences(),
        config: _manualConfig(repeatCount: 0),
      );

      unawaited(engine.startPlaying());
      async.flushMicrotasks();
      expect(engine.state.isInfiniteRepeat, true);
      expect(engine.state.phase, isA<BlindWaitingInterval>());

      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(playedIndices, [0, 0]);
      expect(engine.state.phase, isA<BlindWaitingInterval>());
      expect(engine.state.sentenceIndex, 0);

      unawaited(engine.nextSentence());
      async.flushMicrotasks();
      expect(engine.state.sentenceIndex, 1);

      engine.dispose();
    });
  });

  test('旧播放取消后不跳过用户切换到的下一句', () async {
    final firstResult = Completer<SentencePlaybackResult>();
    final started = Completer<void>();
    final playedIndices = <int>[];
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (sentence, _) async {
          playedIndices.add(sentence.index);
          if (sentence.index == 0) {
            started.complete();
            return firstResult.future;
          }
          return SentencePlaybackResult.completed;
        },
      ),
    );
    engine.prepare(sentences: _sentences(), config: _manualConfig());

    final initialPlay = engine.startPlaying();
    await started.future;
    await engine.nextSentence();
    firstResult.complete(SentencePlaybackResult.cancelled);
    await initialPlay;

    expect(engine.state.sentenceIndex, 1);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
    expect(playedIndices, [0, 1]);
  });

  test('旧播放取消后不跳过用户切换到的上一句', () async {
    final firstResult = Completer<SentencePlaybackResult>();
    final started = Completer<void>();
    final playedIndices = <int>[];
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (sentence, _) async {
          playedIndices.add(sentence.index);
          if (sentence.index == 1) {
            started.complete();
            return firstResult.future;
          }
          return SentencePlaybackResult.completed;
        },
      ),
    );
    engine.prepare(
      sentences: _sentences(),
      startIndex: 1,
      config: _manualConfig(),
    );

    final initialPlay = engine.startPlaying();
    await started.future;
    await engine.previousSentence();
    firstResult.complete(SentencePlaybackResult.cancelled);
    await initialPlay;

    expect(engine.state.sentenceIndex, 0);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
    expect(playedIndices, [1, 0]);
  });

  test('当前 flow 播放失败时仍跳过不可播放句', () async {
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (sentence, _) async => sentence.index == 0
            ? SentencePlaybackResult.failed
            : SentencePlaybackResult.completed,
      ),
    );
    engine.prepare(sentences: _sentences(), config: _manualConfig());

    await engine.startPlaying();

    expect(engine.state.sentenceIndex, 1);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
  });

  test('当前句播放被取消时停留在该句等待用户，不自动跳过', () async {
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async => SentencePlaybackResult.cancelled,
      ),
    );
    engine.prepare(sentences: _sentences(), config: _manualConfig());

    await engine.startPlaying();

    expect(engine.state.sentenceIndex, 0);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
  });

  test('最后一句播放中暂停后，取消结果不会完成流程', () async {
    final playbackResult = Completer<SentencePlaybackResult>();
    final started = Completer<void>();
    final engine = BlindPracticeFlowEngine(
      onStateChanged: (_) {},
      callbacks: BlindPracticeFlowCallbacks(
        pauseAudio: () {},
        playSentence: (_, _) async {
          started.complete();
          return playbackResult.future;
        },
      ),
    );
    engine.prepare(sentences: [_sentences().last], config: _manualConfig());

    final playing = engine.startPlaying();
    await started.future;
    engine.enterWaitingForUser();
    playbackResult.complete(SentencePlaybackResult.cancelled);
    await playing;

    expect(engine.state.sentenceIndex, 0);
    expect(engine.state.phase, isA<BlindWaitingForUser>());
  });
}

BlindPracticeFlowConfig _manualConfig({int repeatCount = 1}) =>
    BlindPracticeFlowConfig(
      getRepeatCount: (_) => repeatCount,
      getRepeatIntervalDuration: (_) => Duration.zero,
      getSentenceIntervalDuration: (_) => Duration.zero,
      isManualMode: () => true,
    );

List<Sentence> _sentences() => [
  Sentence(
    index: 0,
    text: 'First sentence.',
    startTime: Duration.zero,
    endTime: const Duration(seconds: 1),
  ),
  Sentence(
    index: 1,
    text: 'Second sentence.',
    startTime: const Duration(seconds: 1),
    endTime: const Duration(seconds: 2),
  ),
];

import 'dart:async';

import 'package:echo_loop/features/subtitle_editor/subtitle_editor_controller.dart';
import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/models/audio_item.dart';
import 'package:echo_loop/models/sentence.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../helpers/mock_providers.dart';

/// 回归：句子自然播放结束后，playbackPosition 必须停在句尾，绝不回跳到句首。
///
/// 真实根因（状态机/引擎层）：clip 播放完成时 controller 的 finally 若「先停底层
/// 播放器再冻结状态」，`_audioPlayer.stop()` 会吐出 position=0，经
/// `absolutePositionStream = clipStart + rel` 映射成 clip 起点（句首）后被
/// `_handlePosition` 采纳（此刻 isPlaying 仍为 true），把播放头拉回句首。
/// 修复：finally 中先冻结 isPlaying=false 再停播放器；并在 _handlePosition 丢弃
/// 大幅后退的残留事件。
void main() {
  test('单句播放自然结束后 playbackPosition 停在句尾、不回跳句首', () async {
    final sentences = [
      Sentence(
        index: 0,
        text: 'a',
        startTime: const Duration(seconds: 3),
        endTime: const Duration(seconds: 11),
      ),
      Sentence(
        index: 1,
        text: 'b',
        startTime: const Duration(seconds: 11),
        endTime: const Duration(seconds: 18),
      ),
    ];
    final engine = _StopResetEngine(
      duration: const Duration(seconds: 60),
      sentences: sentences,
    );
    final audioItem = createTestAudioItem();
    final container = ProviderContainer(
      overrides: [audioEngineProvider.overrideWith(() => engine)],
    );
    addTearDown(container.dispose);

    // 订阅以保活 autoDispose provider，并记录每次状态变更（捕获中间帧）。
    final positions = <Duration>[];
    final sub = container.listen(
      subtitleEditorControllerProvider(audioItem),
      (_, next) => positions.add(next.playbackPosition),
    );
    addTearDown(sub.close);

    final ctrl = container.read(
      subtitleEditorControllerProvider(audioItem).notifier,
    );
    await ctrl.load();

    final playFuture = ctrl.playSentence(0);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    // 推进播放位置到接近句尾。
    for (var s = 3; s <= 11; s++) {
      engine.emit(Duration(seconds: s));
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    // 自然结束：完成 playClipOnce → finally 跑完（其间 stopPlayback 会吐出句首残留事件）。
    engine.completePlayback();
    await playFuture;
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final state = container.read(subtitleEditorControllerProvider(audioItem));
    expect(state.isPlaying, isFalse);
    // 必须停在句尾 11s，绝不回跳到句首 3s。
    expect(state.playbackPosition, const Duration(seconds: 11));

    // 关键：任何中间帧都不得在到达 11s 后回退到句首附近（视图会据此渲染跳变）。
    final reachedEnd = positions.indexWhere(
      (p) => p >= const Duration(seconds: 11),
    );
    expect(reachedEnd, greaterThanOrEqualTo(0), reason: '应曾推进到句尾');
    for (final p in positions.sublist(reachedEnd)) {
      expect(
        p,
        greaterThanOrEqualTo(const Duration(seconds: 10)),
        reason: '到达句尾后不得回跳（残留 stop 事件把播放头拉回句首）',
      );
    }
  });
}

/// 模拟真实引擎：stopPlayback() 时吐出「相对位置归 0 → 映射成 clip 起点」的残留事件。
class _StopResetEngine extends AudioEngine {
  _StopResetEngine({required this.duration, required this.sentences});

  final Duration duration;
  final List<Sentence> sentences;
  final _pos = StreamController<Duration>.broadcast();
  final _completers = <Completer<void>>[];
  int _session = 0;
  Duration _clipStart = Duration.zero;

  void emit(Duration p) => _pos.add(p);

  @override
  AudioEngineState build() => AudioEngineState(totalDuration: duration);

  @override
  Stream<Duration> get absolutePositionStream => _pos.stream;

  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  int newSession() => ++_session;

  @override
  bool isActiveSession(int id) => id == _session;

  @override
  Future<Duration?> loadAudio(
    AudioItem item,
    double speed, {
    String? subtitle,
  }) async => duration;

  @override
  Future<List<Sentence>> loadTranscript(AudioItem audioItem) async => sentences;

  @override
  Future<void> playClipOnce(Sentence sentence, int sessionId) async {
    _clipStart = sentence.startTime;
    final c = Completer<void>();
    _completers.add(c);
    await c.future;
  }

  @override
  Future<void> playRangeOnce(
    Duration start,
    Duration end,
    int sessionId, {
    void Function()? onClipReady,
  }) async {
    _clipStart = start;
    final c = Completer<void>();
    _completers.add(c);
    await c.future;
  }

  @override
  Future<void> stopPlayback() async {
    // 真实 just_audio：stop() 把相对位置归 0 → 绝对位置 = clipStart（句首）。
    _pos.add(_clipStart);
  }

  @override
  Future<void> clearClip() async {
    _clipStart = Duration.zero;
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> seekToAbsolute(Duration absolute) async {}

  void completePlayback() {
    for (final c in _completers) {
      if (!c.isCompleted) c.complete();
    }
    _completers.clear();
  }
}

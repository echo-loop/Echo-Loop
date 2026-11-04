import 'dart:async';

import 'package:echo_loop/models/pronunciation/pronunciation_clip.dart';
import 'package:echo_loop/providers/pronunciation/pronunciation_providers.dart';
import 'package:echo_loop/providers/short_audio_player_provider.dart';
import 'package:echo_loop/providers/tts/tts_controller_provider.dart';
import 'package:echo_loop/services/pronunciation/local_audio_clip_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

class _FakeBackend implements AudioClipPlayerBackend {
  _FakeBackend({this.completeOnOpen = true, this.failOnOpen = false});

  final bool completeOnOpen;
  final bool failOnOpen;
  final openedPaths = <String>[];
  final _completed = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> open(String filePath, {Duration start = Duration.zero}) async {
    openedPaths.add(filePath);
    if (failOnOpen) {
      _errors.add('decode failed');
    } else if (completeOnOpen) {
      _completed.add(null);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _errors.close();
    await _positions.close();
  }
}

class _FakeTtsController extends TtsController {
  final spoken = <String>[];
  final promptFlags = <bool>[];
  AudioPlaybackResult result = AudioPlaybackResult.completed;

  @override
  TtsControllerState build() => const TtsControllerState();

  @override
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    spoken.add(text);
    promptFlags.add(promptIfModelMissing);
    return result;
  }

  @override
  Future<void> stop() async {}
}

const _clips = [
  PronunciationClip(
    word: 'read',
    locale: 'us',
    audioFilename: 'read_us_v_past.opus',
    absolutePath: '/audio/read_us_v_past.opus',
    reason: PronunciationReason.pastTense,
  ),
  PronunciationClip(
    word: 'read',
    locale: 'us',
    audioFilename: 'read_us_v_present.opus',
    absolutePath: '/audio/read_us_v_present.opus',
    reason: PronunciationReason.presentTense,
  ),
];

ProviderContainer _container({
  required _FakeBackend backend,
  required _FakeTtsController tts,
  List<PronunciationClip> clips = _clips,
}) {
  final player = LocalAudioClipPlayer(backend: backend);
  return ProviderContainer(
    overrides: dedupeOverrides([
      pronunciationClipsProvider.overrideWith(
        (ref, word) => RegExp(r'\s').hasMatch(word) ? const [] : clips,
      ),
      shortAudioPlayerProvider.overrideWithValue(player),
      ttsControllerProvider.overrideWith(() => tts),
    ]),
  );
}

void main() {
  test(
    'plays all local word pronunciations in order with a 200ms pause',
    () async {
      final backend = _FakeBackend();
      final tts = _FakeTtsController();
      final container = _container(backend: backend, tts: tts);
      addTearDown(container.dispose);

      final stopwatch = Stopwatch()..start();
      await container
          .read(textPlaybackProvider.notifier)
          .speakAllSingleWordPronunciations('read');

      expect(backend.openedPaths, _clips.map((clip) => clip.absolutePath));
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 200)),
      );
      expect(tts.spoken, isEmpty);
    },
  );

  test('does not use the sequence for multi-word text', () async {
    final backend = _FakeBackend();
    final tts = _FakeTtsController();
    final container = _container(backend: backend, tts: tts);
    addTearDown(container.dispose);

    await container
        .read(textPlaybackProvider.notifier)
        .speakAllSingleWordPronunciations('hello world');

    expect(backend.openedPaths, isEmpty);
    expect(tts.spoken, ['hello world']);
  });

  test('falls back to TTS once when every local clip fails', () async {
    final backend = _FakeBackend(failOnOpen: true);
    final tts = _FakeTtsController();
    final container = _container(backend: backend, tts: tts);
    addTearDown(container.dispose);

    await container
        .read(textPlaybackProvider.notifier)
        .speakAllSingleWordPronunciations('read');

    expect(backend.openedPaths, _clips.map((clip) => clip.absolutePath));
    expect(tts.spoken, ['read']);
  });

  test('自动发音无本地音频时把 promptIfModelMissing=false 透传给 TTS 回退', () async {
    final tts = _FakeTtsController();
    final container = _container(
      backend: _FakeBackend(),
      tts: tts,
      clips: const [],
    );
    addTearDown(container.dispose);

    await container
        .read(textPlaybackProvider.notifier)
        .speak('hello', key: 'hello', promptIfModelMissing: false);

    expect(tts.spoken, ['hello']);
    expect(tts.promptFlags, [false]);
  });

  test('本地音频播放失败回退 TTS 时同样透传 promptIfModelMissing=false', () async {
    final backend = _FakeBackend(failOnOpen: true);
    final tts = _FakeTtsController();
    final container = _container(backend: backend, tts: tts);
    addTearDown(container.dispose);

    await container
        .read(textPlaybackProvider.notifier)
        .speak('read', key: 'read', promptIfModelMissing: false);

    expect(backend.openedPaths, [_clips.first.absolutePath]);
    expect(tts.spoken, ['read']);
    expect(tts.promptFlags, [false]);
  });

  test('未指定时 TTS 回退默认允许弹出模型下载提示', () async {
    final tts = _FakeTtsController();
    final container = _container(
      backend: _FakeBackend(),
      tts: tts,
      clips: const [],
    );
    addTearDown(container.dispose);

    await container.read(textPlaybackProvider.notifier).speak('hello');

    expect(tts.promptFlags, [true]);
  });

  test('stopping a sequence prevents later clips from playing', () async {
    final backend = _FakeBackend(completeOnOpen: false);
    final tts = _FakeTtsController();
    final container = _container(backend: backend, tts: tts);
    addTearDown(container.dispose);
    final playback = container.read(textPlaybackProvider.notifier);

    final sequence = playback.speakAllSingleWordPronunciations('read');
    await Future<void>.delayed(Duration.zero);
    await playback.stop();
    await sequence;

    expect(backend.openedPaths, [_clips.first.absolutePath]);
    expect(tts.spoken, isEmpty);
  });
}

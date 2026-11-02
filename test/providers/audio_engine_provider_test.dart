import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:echo_loop/models/audio_engine_state.dart';
import 'package:echo_loop/providers/audio_engine/audio_engine_provider.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('AudioEngine clearClip', () {
    test('未处于 clip 状态时直接返回，不触碰底层播放器', () async {
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioEngineProvider.overrideWith(
            () => _BuildOnlyAudioEngine(
              initialState: const AudioEngineState(
                clipStart: Duration.zero,
                isClipActive: false,
              ),
            ),
          ),
        ]),
      );
      addTearDown(container.dispose);
      final engine = container.read(audioEngineProvider.notifier);

      await engine.clearClip();

      expect(container.read(audioEngineProvider).clipStart, Duration.zero);
      expect(container.read(audioEngineProvider).isClipActive, false);
    });

    test('clip 起点为 0 时仍视为 active，必须清理', () async {
      final container = ProviderContainer(
        overrides: dedupeOverrides([
          audioEngineProvider.overrideWith(
            () => _RecordingClearClipAudioEngine(
              initialState: const AudioEngineState(
                clipStart: Duration.zero,
                isClipActive: true,
              ),
            ),
          ),
        ]),
      );
      addTearDown(container.dispose);
      final engine =
          container.read(audioEngineProvider.notifier)
              as _RecordingClearClipAudioEngine;

      await engine.clearClip();

      expect(engine.clearClipReloadCount, 1);
      expect(container.read(audioEngineProvider).clipStart, Duration.zero);
      expect(container.read(audioEngineProvider).isClipActive, false);
    });
  });
}

class _BuildOnlyAudioEngine extends AudioEngine {
  _BuildOnlyAudioEngine({required this.initialState});

  final AudioEngineState initialState;

  @override
  AudioEngineState build() => initialState;
}

class _RecordingClearClipAudioEngine extends AudioEngine {
  _RecordingClearClipAudioEngine({required this.initialState});

  final AudioEngineState initialState;
  int clearClipReloadCount = 0;

  @override
  AudioEngineState build() => initialState;

  @override
  Future<void> clearClip() async {
    if (!state.isClipActive) return;
    state = state.copyWith(clipStart: Duration.zero, isClipActive: false);
    clearClipReloadCount += 1;
  }
}

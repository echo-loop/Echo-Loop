import '../../models/sense_group_range_playback.dart';
import 'audio_engine_provider.dart';

/// 基于媒体 [AudioEngine] 的按需加载意群播放实现。
class AudioEngineSenseGroupRangePlayback
    implements SenseGroupRangePlayback, ResumableSentenceRangePlayback {
  AudioEngineSenseGroupRangePlayback({
    required AudioEngine engine,
    required double Function() playbackSpeed,
  }) : _engine = engine,
       _playbackSpeed = playbackSpeed;

  final AudioEngine _engine;
  final double Function() _playbackSpeed;
  int _generation = 0;

  @override
  Duration get currentPosition => _engine.absoluteCurrentPosition;

  @override
  Future<void> play(String audioItemId, Duration start, Duration end) =>
      _playRange(audioItemId, start, end);

  @override
  Future<void> playFromPosition(
    String audioItemId,
    Duration start,
    Duration end,
    Duration position,
  ) => _playRange(
    audioItemId,
    position >= start && position < end ? position : start,
    end,
  );

  Future<void> _playRange(
    String audioItemId,
    Duration start,
    Duration end,
  ) async {
    final generation = ++_generation;
    await _engine.playRangeForAudio(
      audioItemId,
      start,
      end,
      speed: _playbackSpeed(),
    );
    if (generation != _generation) return;
  }

  @override
  Future<void> cancel() async {
    _generation++;
    await _engine.pause();
  }
}

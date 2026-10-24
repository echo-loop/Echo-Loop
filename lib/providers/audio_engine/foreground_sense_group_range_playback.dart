import '../../models/sense_group_range_playback.dart';
import '../../services/app_logger.dart';
import 'foreground_audio_engine_provider.dart';

/// 收藏与录音类任务的意群播放实现。
///
/// 区间播放前由 [ForegroundAudioEngine] 自动确认材料已加载；UI 不需要也不能
/// 预先管理播放器状态。generation 让取消/重复点击后的旧异步调用失效；session 所有权
/// 让迟到的取消只暂停本适配器仍在播放的区间，不会中断新句的主播放。
class ForegroundSenseGroupRangePlayback
    implements SenseGroupRangePlayback, ResumableSentenceRangePlayback {
  ForegroundSenseGroupRangePlayback({
    required ForegroundAudioEngine engine,
    required double Function() playbackSpeed,
  }) : _engine = engine,
       _playbackSpeed = playbackSpeed;

  final ForegroundAudioEngine _engine;
  final double Function() _playbackSpeed;
  int _generation = 0;
  int? _activeSessionId;

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
    int? startedSessionId;
    AppLogger.log(
      'ForegroundSenseGroupRangePlayback',
      'event=play-request generation=$generation audioId=$audioItemId '
          'rangeStartMs=${start.inMilliseconds} rangeEndMs=${end.inMilliseconds}',
    );
    try {
      await _engine.playRangeForAudio(
        audioItemId,
        start,
        end,
        speed: _playbackSpeed(),
        isRequestActive: () => generation == _generation,
        onSessionStarted: (sessionId) {
          startedSessionId = sessionId;
          _activeSessionId = sessionId;
          AppLogger.log(
            'ForegroundSenseGroupRangePlayback',
            'event=play-session-start generation=$generation '
                'sessionId=$sessionId',
          );
        },
      );
      if (startedSessionId == null) {
        AppLogger.log(
          'ForegroundSenseGroupRangePlayback',
          'event=play-not-started generation=$generation '
              'currentGeneration=$_generation reason=request-cancelled',
        );
      }
    } finally {
      if (_activeSessionId == startedSessionId) {
        _activeSessionId = null;
      }
    }
  }

  /// 只取消仍由本适配器持有的播放 session，避免旧解释页清理暂停新句播放。
  @override
  Future<void> cancel() async {
    final generation = ++_generation;
    final sessionId = _activeSessionId;
    _activeSessionId = null;
    final ownsActiveSession =
        sessionId != null && _engine.isActiveSession(sessionId);
    AppLogger.log(
      'ForegroundSenseGroupRangePlayback',
      'event=cancel generation=$generation sessionId=$sessionId '
          'sessionActive=$ownsActiveSession '
          'action=${ownsActiveSession ? 'pause-owned-session' : 'no-op'}',
    );
    if (!ownsActiveSession) return;
    await _engine.pause();
  }
}

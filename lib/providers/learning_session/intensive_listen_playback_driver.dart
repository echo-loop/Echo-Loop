import '../../models/sentence.dart';
import '../../models/sentence_playback_result.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../media_engine/media_engine_provider.dart';
import '../../services/app_logger.dart';

/// 句子级学习任务依赖的最小播放契约。
///
/// 学习状态机只描述“播放一句”，不持有具体播放器；精听音频和视频共用
/// [MediaSentencePlaybackDriver]，其他任务可继续使用各自的适配器。
abstract interface class SentencePlaybackDriver {
  Duration get currentPosition;
  int newSession();
  bool isActiveSession(int playbackSessionId);

  /// 立即使当前播放失效并暂停底层引擎，迟到回调不得继续推进业务状态。
  Future<void> invalidateSession();

  Future<void> pause();
  Future<void> setSpeed(double speed);
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  });

  /// 按指定速度完整播放一句；MediaEngine 实现自行管理底层播放请求。
  Future<SentencePlaybackResult> playSentenceWithSpeed(
    Sentence sentence,
    double speed,
  );

  /// 绑定系统媒体控制；不提供系统媒体会话的前台音频适配器实现为空操作。
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  });
  void setSessionActive(bool active);
  void setProgressFrozen(bool frozen);
  void unbindLockScreen();
}

/// 逐句精听在句子播放之外还需要意群区间播放。
abstract interface class IntensiveListenPlaybackDriver
    implements SentencePlaybackDriver {
  Future<SentencePlaybackResult> playRangeOnce(
    Duration start,
    Duration end,
    int playbackSessionId,
  );
}

/// 难句跟读原音频适配器；所有调用仍委托前台 just_audio 引擎。
class ForegroundSentencePlaybackDriver implements SentencePlaybackDriver {
  ForegroundSentencePlaybackDriver(this._foregroundAudioEngine);

  final ForegroundAudioEngine _foregroundAudioEngine;

  @override
  Duration get currentPosition =>
      _foregroundAudioEngine.absoluteCurrentPosition;

  @override
  int newSession() => _foregroundAudioEngine.newSession();

  @override
  bool isActiveSession(int playbackSessionId) =>
      _foregroundAudioEngine.isActiveSession(playbackSessionId);

  @override
  Future<void> invalidateSession() async {
    _foregroundAudioEngine.newSession();
    await _foregroundAudioEngine.pause();
  }

  @override
  Future<void> pause() => _foregroundAudioEngine.pause();

  @override
  Future<void> setSpeed(double speed) => _foregroundAudioEngine.setSpeed(speed);

  @override
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) async {
    final playback = startAt == null
        ? _foregroundAudioEngine.playClipOnce(sentence, playbackSessionId)
        : _foregroundAudioEngine.playClipFromPosition(
            sentence,
            playbackSessionId,
            startAt,
          );
    await playback;
    return _foregroundAudioEngine.isActiveSession(playbackSessionId)
        ? SentencePlaybackResult.completed
        : SentencePlaybackResult.cancelled;
  }

  @override
  Future<SentencePlaybackResult> playSentenceWithSpeed(
    Sentence sentence,
    double speed,
  ) async {
    await setSpeed(speed);
    return playSentence(sentence, newSession());
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {}

  @override
  void setSessionActive(bool active) {}

  @override
  void setProgressFrozen(bool frozen) {}

  @override
  void unbindLockScreen() {}
}

/// 精听与其他媒体学习任务共用的句子播放驱动，统一通过 MediaEngine 播放音频和视频。
class MediaSentencePlaybackDriver implements IntensiveListenPlaybackDriver {
  MediaSentencePlaybackDriver(this._mediaEngine);

  final MediaEngine _mediaEngine;
  double _playbackSpeed = 1.0;

  @override
  Duration get currentPosition => _mediaEngine.currentPosition;

  @override
  int newSession() => _mediaEngine.newSession();

  @override
  bool isActiveSession(int playbackSessionId) =>
      _mediaEngine.isActiveSession(playbackSessionId);

  @override
  Future<void> invalidateSession() =>
      _mediaEngine.cancelActiveRange(reason: 'driver-invalidate');

  @override
  Future<void> pause() =>
      _mediaEngine.cancelActiveRange(reason: 'driver-pause');

  /// 更新当前播放器速度，并保留该值供后续句子和区间播放使用。
  @override
  Future<void> setSpeed(double speed) async {
    _playbackSpeed = speed;
    await _mediaEngine.setSpeed(speed);
  }

  @override
  Future<SentencePlaybackResult> playSentenceWithSpeed(
    Sentence sentence,
    double speed,
  ) => _playSentenceWithDiagnostics(
    sentence,
    speed,
    playbackSessionId: _mediaEngine.currentSessionId,
  );

  @override
  Future<SentencePlaybackResult> playSentence(
    Sentence sentence,
    int playbackSessionId, {
    Duration? startAt,
  }) => _playSentenceWithDiagnostics(
    sentence,
    _playbackSpeed,
    playbackSessionId: playbackSessionId,
    startAt: startAt,
  );

  Future<SentencePlaybackResult> _playSentenceWithDiagnostics(
    Sentence sentence,
    double speed, {
    required int playbackSessionId,
    Duration? startAt,
  }) async {
    AppLogger.log(
      'MediaSentencePlayback',
      'event=sentence-start playbackSessionId=$playbackSessionId '
          'sentenceIndex=${sentence.index} '
          'rangeMs=${sentence.startTime.inMilliseconds}-'
          '${sentence.endTime.inMilliseconds} speed=$speed',
    );
    final timer = Stopwatch()..start();
    try {
      final result = await _mediaEngine.playRange(
        startAt ?? sentence.startTime,
        sentence.endTime,
        speed: speed,
        sessionId: playbackSessionId,
      );
      AppLogger.log(
        'MediaSentencePlayback',
        'event=sentence-result playbackSessionId=$playbackSessionId '
            'sentenceIndex=${sentence.index} '
            'positionMs=${_mediaEngine.currentPosition.inMilliseconds} '
            'elapsedMs=${timer.elapsedMilliseconds} result=$result',
      );
      return result;
    } catch (error) {
      AppLogger.log(
        'MediaSentencePlayback',
        'event=sentence-exception playbackSessionId=$playbackSessionId '
            'sentenceIndex=${sentence.index} error=$error',
      );
      rethrow;
    }
  }

  @override
  Future<SentencePlaybackResult> playRangeOnce(
    Duration start,
    Duration end,
    int playbackSessionId,
  ) async {
    final speed = _playbackSpeed;
    AppLogger.log(
      'MediaSentencePlayback',
      'event=range-once-start playbackSessionId=$playbackSessionId '
          'rangeMs=${start.inMilliseconds}-${end.inMilliseconds} speed=$speed',
    );
    try {
      final result = await _mediaEngine.playRange(
        start,
        end,
        speed: speed,
        sessionId: playbackSessionId,
      );
      AppLogger.log(
        'MediaSentencePlayback',
        'event=range-once-result playbackSessionId=$playbackSessionId result=$result '
            'positionMs=${_mediaEngine.currentPosition.inMilliseconds}',
      );
      return result;
    } catch (error) {
      AppLogger.log(
        'MediaSentencePlayback',
        'event=range-once-exception playbackSessionId=$playbackSessionId error=$error',
      );
      rethrow;
    }
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    _mediaEngine.setTransportHandlers(onPlay: onPlay, onPause: onPause);
    _mediaEngine.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
  }

  @override
  void setSessionActive(bool active) {
    _mediaEngine.setLogicalPlaying(active);
    if (active) {
      _mediaEngine.startKeepAlive();
    } else {
      _mediaEngine.stopKeepAlive();
    }
  }

  @override
  void setProgressFrozen(bool frozen) => _mediaEngine.setProgressFrozen(frozen);

  @override
  void unbindLockScreen() {
    _mediaEngine.setTransportHandlers(onPlay: null, onPause: null);
    _mediaEngine.setSkipHandlers(onPrevious: null, onNext: null);
    _mediaEngine.setLogicalPlaying(null);
    _mediaEngine.setProgressFrozen(false);
    _mediaEngine.stopKeepAlive();
  }
}

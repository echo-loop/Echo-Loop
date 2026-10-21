import 'dart:async';

import '../../models/sentence_playback_result.dart';
import '../media_engine/media_engine_provider.dart';

/// 段落任务的底层播放契约。
///
/// 盲听与复述只依赖此接口，不感知具体播放器实现；音频和视频都通过 MediaEngine
/// 实现该契约。
abstract interface class ParagraphPlaybackDriver {
  int newSession();
  bool isActiveSession(int sessionId);
  Stream<Duration> get positionStream;
  Future<void> pause();
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration position);
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  });
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

/// MediaEngine 段落适配器，供音视频盲听及媒体复述复用。
class MediaParagraphPlaybackDriver implements ParagraphPlaybackDriver {
  MediaParagraphPlaybackDriver(this._engine);
  final MediaEngine _engine;
  @override
  int newSession() => _engine.newSession();
  @override
  bool isActiveSession(int sessionId) => _engine.isActiveSession(sessionId);
  @override
  Stream<Duration> get positionStream => _engine.positionStream;
  @override
  Future<void> pause() => _engine.cancelActiveRange(reason: 'paragraph-pause');
  @override
  Future<void> setSpeed(double speed) => _engine.setSpeed(speed);
  @override
  Future<void> seek(Duration position) => _engine.seek(position);
  @override
  Future<SentencePlaybackResult> playRange(
    Duration start,
    Duration end,
    int sessionId, {
    required double speed,
    required void Function() onRangeReady,
  }) async {
    return _engine.playRange(
      start,
      end,
      speed: speed,
      onRangeReady: onRangeReady,
      sessionId: sessionId,
    );
  }

  @override
  void bindLockScreen({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function() onNext,
    required Future<void> Function() onPrevious,
  }) {
    _engine.setTransportHandlers(onPlay: onPlay, onPause: onPause);
    _engine.setSkipHandlers(onPrevious: onPrevious, onNext: onNext);
  }

  @override
  void setSessionActive(bool active) {
    _engine.setLogicalPlaying(active);
    active
        ? unawaited(_engine.startKeepAlive())
        : unawaited(_engine.stopKeepAlive());
  }

  @override
  void setProgressFrozen(bool frozen) => _engine.setProgressFrozen(frozen);
  @override
  void unbindLockScreen() {
    _engine.setTransportHandlers(onPlay: null, onPause: null);
    _engine.setSkipHandlers(onPrevious: null, onNext: null);
    _engine.setLogicalPlaying(null);
    _engine.setProgressFrozen(false);
    unawaited(_engine.stopKeepAlive());
  }
}

import 'dart:async';

import 'package:echo_loop/services/media_player_backend.dart';
import 'package:flutter/widgets.dart';

/// 测试用 media backend：纯 Dart 状态机，不触达 media_kit 原生层。
class FakeMediaPlayerBackend implements MediaPlayerBackend {
  final positionStreamCancelled = Completer<void>();
  late final StreamController<Duration> positionController =
      StreamController<Duration>.broadcast(
        onCancel: () {
          if (!positionStreamCancelled.isCompleted) {
            positionStreamCancelled.complete();
          }
        },
      );
  final durationController = StreamController<Duration>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();
  final completedController = StreamController<void>.broadcast();
  final landscapeVideoController = StreamController<bool?>.broadcast();
  final videoAspectRatioController = StreamController<double?>.broadcast();

  final openCalls = <String>[];
  final openInitialPositions = <Duration>[];
  final seekCalls = <Duration>[];
  final rateCalls = <double>[];

  /// 依次记录 [setPlaybackEnd] 的参数，`null` 表示撤销终点。
  final playbackEndCalls = <Duration?>[];
  final videoTrackCalls = <bool>[];
  final subtitleTrackDataCalls = <String?>[];
  final videoViewSizes = <Size>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int startKeepAliveCalls = 0;
  int stopKeepAliveCalls = 0;
  bool disposed = false;
  int disposeCalls = 0;
  bool closeStreamsOnDispose = true;
  bool deferSeekPositionUpdate = false;
  Duration disposeDelay = Duration.zero;
  Duration pauseDelay = Duration.zero;
  Object? openError;
  Object? pauseError;
  Object? playError;
  Object? disposeError;
  Completer<void>? playGate;
  Completer<void>? playStarted;

  Duration _position = Duration.zero;
  Duration? _duration = const Duration(seconds: 10);
  bool _playing = false;
  double _rate = 1.0;
  bool? _isLandscapeVideo;
  double? _videoAspectRatio;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get playing => _playing;

  @override
  double get rate => _rate;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration> get durationStream => durationController.stream;

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Stream<bool> get bufferingStream => bufferingController.stream;

  @override
  Stream<void> get completedStream => completedController.stream;

  @override
  bool? get isLandscapeVideo => _isLandscapeVideo;

  @override
  Stream<bool?> get isLandscapeVideoStream => landscapeVideoController.stream;

  @override
  double? get videoAspectRatio => _videoAspectRatio;

  @override
  Stream<double?> get videoAspectRatioStream =>
      videoAspectRatioController.stream;

  @override
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (openError != null) throw openError!;
    openCalls.add(filePath);
    openInitialPositions.add(initialPosition);
    // 与真实后端一致：换媒体时撤销原生终点。
    if (playbackEnd != null) playbackEndCalls.add(null);
    _position = initialPosition;
    final duration = _duration;
    if (duration != null) durationController.add(duration);
  }

  @override
  Future<void> play() async {
    playStarted?.complete();
    final gate = playGate;
    if (gate != null) await gate.future;
    if (playError != null) throw playError!;
    playCalls += 1;
    _playing = true;
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    if (pauseDelay > Duration.zero) await Future<void>.delayed(pauseDelay);
    final error = pauseError;
    if (error != null) throw error;
    _playing = false;
    playingController.add(false);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    _playing = false;
    _position = Duration.zero;
    playingController.add(false);
    positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    if (!deferSeekPositionUpdate) {
      _position = position;
      positionController.add(position);
    }
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    rateCalls.add(rate);
  }

  @override
  Future<void> setPlaybackEnd(Duration? end) async {
    playbackEndCalls.add(end);
  }

  /// 当前生效的原生终点（最后一次设置值）。
  Duration? get playbackEnd =>
      playbackEndCalls.isEmpty ? null : playbackEndCalls.last;

  @override
  Future<void> setVideoTrackEnabled(bool enabled) async {
    videoTrackCalls.add(enabled);
  }

  @override
  Future<void> setSubtitleTrackData(String? srt) async {
    subtitleTrackDataCalls.add(srt);
  }

  @override
  Future<void> startKeepAlive() async {
    startKeepAliveCalls += 1;
  }

  @override
  Future<void> stopKeepAlive() async {
    stopKeepAliveCalls += 1;
  }

  void setDuration(Duration? duration) {
    _duration = duration;
    if (duration != null) durationController.add(duration);
  }

  void emitPosition(Duration position) {
    _position = position;
    positionController.add(position);
  }

  /// 更新 backend 的实时位置但不发送位置流，用于模拟 UI 位置事件尚未到达的瞬间。
  void setPositionWithoutEvent(Duration position) {
    _position = position;
  }

  void emitPlaying(bool playing) {
    _playing = playing;
    playingController.add(playing);
  }

  void emitCompleted() {
    completedController.add(null);
  }

  void emitLandscapeVideo(bool? value) {
    _isLandscapeVideo = value;
    landscapeVideoController.add(value);
  }

  void emitVideoAspectRatio(double? value) {
    _videoAspectRatio = value;
    videoAspectRatioController.add(value);
  }

  @override
  Widget buildVideoView({required Size viewportSize}) {
    videoViewSizes.add(viewportSize);
    return const SizedBox(key: ValueKey('fake-video-view'));
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    if (disposeDelay > Duration.zero) {
      await Future<void>.delayed(disposeDelay);
    }
    final error = disposeError;
    if (error != null) throw error;
    disposed = true;
    if (!closeStreamsOnDispose) return;
    await positionController.close();
    await durationController.close();
    await playingController.close();
    await bufferingController.close();
    await completedController.close();
    await landscapeVideoController.close();
    await videoAspectRatioController.close();
  }
}

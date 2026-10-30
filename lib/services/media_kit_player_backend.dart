import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_subtitle_style.dart';
import 'app_logger.dart';
import 'media_kit_debug_initializer.dart';
import 'media_player_backend.dart';

/// media_kit 播放后端。只负责原生播放器适配，不承载业务播放流程。
///
/// [player] 可注入测试播放器，验证视频组件配置时不加载原生 media_kit 库。
class MediaKitPlayerBackend implements MediaPlayerBackend {
  MediaKitPlayerBackend({Player? player})
    : _player = player ?? _createPlayer() {
    _controller = VideoController(_player);
  }

  static Player _createPlayer() {
    ensureMediaKitInitialized();
    return Player();
  }

  final Player _player;
  Player? _keepAlivePlayer;
  late final VideoController _controller;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  @override
  Duration get position => _player.state.position;

  @override
  Duration? get duration {
    final value = _player.state.duration;
    return value > Duration.zero ? value : null;
  }

  @override
  bool get playing => _player.state.playing;

  @override
  double get rate => _player.state.rate;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<void> get completedStream =>
      _player.stream.completed.where((completed) => completed).map((_) {});

  @override
  bool? get isLandscapeVideo =>
      _isLandscape(_player.state.width, _player.state.height);

  @override
  Stream<bool?> get isLandscapeVideoStream => _player.stream.videoParams.map(
    (_) => _isLandscape(_player.state.width, _player.state.height),
  );

  @override
  double? get videoAspectRatio =>
      _aspectRatio(_player.state.width, _player.state.height);

  @override
  Stream<double?> get videoAspectRatioStream => _player.stream.videoParams.map(
    (_) => _aspectRatio(_player.state.width, _player.state.height),
  );

  @override
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  }) async {
    AppLogger.log(
      'MediaKitBackend',
      'open begin backend=${identityHashCode(this)} '
          'position=${initialPosition.inMilliseconds}ms',
    );
    // mpv 的 end 是全局选项，会延续到下一个文件，换媒体前必须撤销。
    await setPlaybackEnd(null);
    await _player.open(
      Media(
        filePath,
        start: initialPosition > Duration.zero ? initialPosition : null,
      ),
      play: false,
    );
    AppLogger.log(
      'MediaKitBackend',
      'open complete backend=${identityHashCode(this)} '
          'duration=${duration?.inMilliseconds}ms position=${position.inMilliseconds}ms '
          'playing=$playing',
    );
  }

  @override
  Future<void> play() async {
    AppLogger.log(
      'MediaKitBackend',
      'play begin backend=${identityHashCode(this)} '
          'position=${position.inMilliseconds}ms playing=$playing',
    );
    await _player.play();
    AppLogger.log(
      'MediaKitBackend',
      'play complete backend=${identityHashCode(this)} '
          'position=${position.inMilliseconds}ms playing=$playing',
    );
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  /// 通过 mpv `end` 属性在解码层裁切；运行时修改即时生效，`none` 表示不限制。
  @override
  Future<void> setPlaybackEnd(Duration? end) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    final value = end == null
        ? 'none'
        : (end.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(
            3,
          );
    await platform.setProperty('end', value);
    AppLogger.log(
      'MediaKitBackend',
      'set playback end backend=${identityHashCode(this)} end=$value '
          'position=${position.inMilliseconds}ms',
    );
  }

  @override
  Future<void> setVideoTrackEnabled(bool enabled) {
    return _player.setVideoTrack(enabled ? VideoTrack.auto() : VideoTrack.no());
  }

  @override
  Future<void> setSubtitleTrackData(String? srt) {
    return _player.setSubtitleTrack(
      srt == null || srt.isEmpty
          ? SubtitleTrack.no()
          : SubtitleTrack.data(srt, title: 'Echo Loop'),
    );
  }

  /// iOS 停顿期使用 media_kit 自己的静音播放器保活，不借用音频播放链路。
  @override
  Future<void> startKeepAlive() async {
    if (kIsWeb || !Platform.isIOS || _disposed) return;
    final player = _keepAlivePlayer ??= Player();
    if (player.state.playlist.medias.isEmpty) {
      await player.open(
        Media('asset:///assets/audio/silence_2s.m4a'),
        play: false,
      );
      await player.setPlaylistMode(PlaylistMode.single);
      await player.setVolume(100);
    }
    if (!player.state.playing) await player.play();
  }

  @override
  Future<void> stopKeepAlive() async {
    final player = _keepAlivePlayer;
    if (player != null && player.state.playing) await player.pause();
  }

  @override
  Widget buildVideoView({required Size viewportSize}) {
    final subtitleStyle = MediaSubtitleStyle.forViewport(viewportSize);
    return Video(
      controller: _controller,
      controls: NoVideoControls,
      // 视频随心听的音轨需要在锁屏后继续播放；media_kit_video 默认会在后台暂停 Player。
      pauseUponEnteringBackgroundMode: false,
      fit: BoxFit.contain,
      subtitleViewConfiguration: SubtitleViewConfiguration(
        style: TextStyle(
          height: 1.32,
          fontSize: subtitleStyle.fontSize,
          letterSpacing: 0,
          wordSpacing: 0,
          color: const Color(0xffffffff),
          fontWeight: FontWeight.w600,
          backgroundColor: const Color(0xaa000000),
        ),
        textAlign: TextAlign.center,
        textScaler: const TextScaler.linear(1),
        padding: EdgeInsets.fromLTRB(
          subtitleStyle.horizontalPadding,
          0,
          subtitleStyle.horizontalPadding,
          subtitleStyle.bottomPadding,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    final future = _dispose();
    late final Future<void> tracked;
    tracked = future.whenComplete(() {
      // 原生释放失败时保留 backend owner，并允许生命周期管理器重试；成功时
      // [_dispose] 已将 _disposed 置为 true，后续调用自然幂等返回。
      if (!_disposed && identical(_disposeFuture, tracked)) {
        _disposeFuture = null;
      }
    });
    _disposeFuture = tracked;
    return tracked;
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    final startedAt = DateTime.now();
    AppLogger.log(
      'MediaKitBackend',
      'dispose begin backend=${identityHashCode(this)} '
          'position=${position.inMilliseconds}ms playing=$playing',
    );
    try {
      await _player.setVideoTrack(VideoTrack.no());
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
    await _keepAlivePlayer?.dispose();
    _keepAlivePlayer = null;
    _disposed = true;
    AppLogger.log(
      'MediaKitBackend',
      'dispose complete backend=${identityHashCode(this)} '
          'elapsed_ms=${DateTime.now().difference(startedAt).inMilliseconds}',
    );
  }

  /// media_kit 的 width/height 已按视频旋转元数据校正，可直接用于方向判断。
  static bool? _isLandscape(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width > height;
  }

  static double? _aspectRatio(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:path/path.dart' as p;

import 'media_subtitle_style.dart';
import 'app_logger.dart';
import 'media_kit_debug_initializer.dart';
import 'media_player_backend.dart';
import 'video_frame_gate.dart';

/// media_kit 播放后端。只负责原生播放器适配，不承载业务播放流程。
///
/// [player] 可注入测试播放器，验证视频组件配置时不加载原生 media_kit 库。
class MediaKitPlayerBackend implements MediaPlayerBackend {
  MediaKitPlayerBackend({Player? player})
    : _player = player ?? _createPlayer() {
    _controller = VideoController(_player);
    _startVideoFrameGate();
  }

  static Player _createPlayer() {
    ensureMediaKitInitialized();
    return Player();
  }

  final Player _player;
  Player? _keepAlivePlayer;
  late final VideoController _controller;
  StreamSubscription<VideoParams>? _videoParamsSubscription;

  /// 纹理随 [VideoController] 跨 [open] 复用，新媒体出帧前原生纹理仍是上一个
  /// 媒体的最后一帧；门控未放行前视频视图不绘制纹理，避免切换时闪现旧画面。
  final VideoFrameGate _frameGate = VideoFrameGate();

  /// 视频视图是否绘制纹理；仅由 [_frameGate] 驱动。
  final ValueNotifier<bool> _isTextureVisible = ValueNotifier(false);

  /// 当前打开媒体的代次与名称，用于日志区分"正在加载"和"纹理里是谁"。
  int _mediaGeneration = 0;
  String? _currentMediaName;

  /// 纹理中实际画着的媒体；新媒体通过门控后才更新。
  String? _textureMediaName;
  DateTime? _openStartedAt;

  /// 当前打开媒体的起始位置（断点）；暂停中补出帧时必须回到它，不能用播放器当前位置，
  /// 因为 open 完成后 mpv 的 position 可能仍是 0。
  Duration _openPosition = Duration.zero;

  /// 已为哪一代媒体请求过暂停补帧，每次打开只请求一次。
  int? _pausedRedrawGeneration;
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
    // 必须先于 _player.open：新媒体的出帧信号可能在 open 返回前到达。
    _resetVideoFrameGate(filePath);
    _openPosition = initialPosition;
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

  /// 订阅门控所需的三个输入：VO 配置状态、媒体显示尺寸、纹理尺寸。
  ///
  /// 非原生播放器（测试替身）无法观察 mpv 属性，不做门控。
  void _startVideoFrameGate() {
    final platform = _player.platform;
    if (platform is! NativePlayer) {
      _isTextureVisible.value = true;
      return;
    }
    _videoParamsSubscription = _player.stream.videoParams.listen(
      (params) => _applyFrameGateInput(
        'video-size',
        _displaySize(params),
        () => _frameGate.updateVideoSize(_displaySize(params)),
      ),
    );
    _controller.rect.addListener(_onTextureRectChanged);
    unawaited(
      platform
          .observeProperty('vo-configured', (value) async {
            _applyFrameGateInput(
              'vo-configured',
              value,
              () => _frameGate.updateVoConfigured(value == 'yes'),
            );
          })
          .catchError((Object error) {
            // 无法观察时宁可回到旧行为（可能闪旧帧），也不能让视频永远黑屏。
            AppLogger.log('VideoFrame', 'event=gate_unavailable error=$error');
            if (!_disposed) _isTextureVisible.value = true;
          }),
    );
  }

  void _onTextureRectChanged() {
    final rect = _controller.rect.value;
    _applyFrameGateInput(
      'texture-size',
      rect?.size,
      () => _frameGate.updateTextureSize(rect?.size),
    );
  }

  void _resetVideoFrameGate(String filePath) {
    _mediaGeneration += 1;
    _currentMediaName = p.basename(filePath);
    _openStartedAt = DateTime.now();
    _frameGate.resetForNewMedia();
    _isTextureVisible.value = false;
    AppLogger.log(
      'VideoFrame',
      'event=media_open generation=$_mediaGeneration '
          'media=$_currentMediaName textureHolds=${_textureMediaName ?? 'empty'} '
          'texture=${_frameGate.textureSize} visible=false',
    );
  }

  void _applyFrameGateInput(
    String input,
    Object? value,
    bool Function() update,
  ) {
    if (_disposed) return;
    final becameVisible = update();
    AppLogger.log(
      'VideoFrame',
      'event=gate_input input=$input value=$value '
          'generation=$_mediaGeneration media=$_currentMediaName '
          'textureHolds=${_textureMediaName ?? 'empty'} '
          'voConfigured=${_frameGate.isVoConfigured} '
          'video=${_frameGate.videoSize} texture=${_frameGate.textureSize} '
          'visible=${_frameGate.isCurrentMediaVisible}',
    );
    if (!becameVisible) {
      _requestPausedFrameRedrawIfNeeded();
      return;
    }
    _textureMediaName = _currentMediaName;
    _isTextureVisible.value = true;
    final startedAt = _openStartedAt;
    AppLogger.log(
      'VideoFrame',
      'event=current_media_visible generation=$_mediaGeneration '
          'media=$_currentMediaName trigger=$input '
          'texture=${_frameGate.textureSize} elapsedSinceOpenMs='
          '${startedAt == null ? 'n/a' : DateTime.now().difference(startedAt).inMilliseconds}',
    );
  }

  /// 暂停打开时 mpv 不会主动出帧，纹理无法追上新媒体尺寸，门控一直不放行、画面黑屏。
  /// seek 到打开时的起始位置即可让 mpv 重绘当前帧；每次打开只请求一次。
  void _requestPausedFrameRedrawIfNeeded() {
    if (_disposed || playing || !_frameGate.needsFrameRedraw) return;
    if (_pausedRedrawGeneration == _mediaGeneration) return;
    _pausedRedrawGeneration = _mediaGeneration;
    final generation = _mediaGeneration;
    AppLogger.log(
      'VideoFrame',
      'event=paused_redraw_requested generation=$generation '
          'media=$_currentMediaName position=${_openPosition.inMilliseconds}ms',
    );
    unawaited(
      _player.seek(_openPosition).catchError((Object error) {
        AppLogger.log(
          'VideoFrame',
          'event=paused_redraw_failed generation=$generation error=$error',
        );
      }),
    );
  }

  /// 与原生纹理尺寸算法一致：使用显示尺寸，90/270 度旋转时交换宽高。
  static Size? _displaySize(VideoParams params) {
    final dw = params.dw;
    final dh = params.dh;
    if (dw == null || dh == null || dw <= 0 || dh <= 0) return null;
    final rotate = params.rotate ?? 0;
    return rotate == 90 || rotate == 270
        ? Size(dh.toDouble(), dw.toDouble())
        : Size(dw.toDouble(), dh.toDouble());
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

  /// 对应 mpv `audio-buffer` 选项（默认 0.2 秒），在音频输出重新初始化（打开
  /// 媒体）时生效。
  @override
  Future<void> setAudioOutputBuffer(Duration buffer) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    final seconds = (buffer.inMicroseconds / Duration.microsecondsPerSecond)
        .toStringAsFixed(3);
    await platform.setProperty('audio-buffer', seconds);
    AppLogger.log(
      'MediaKitBackend',
      'set audio buffer backend=${identityHashCode(this)} seconds=$seconds',
    );
  }

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
  Future<void> setAudioTrackEnabled(bool enabled) {
    return _player.setAudioTrack(enabled ? AudioTrack.auto() : AudioTrack.no());
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
    // 字幕跟随系统文字缩放：需要 BuildContext 读取 MediaQuery，故包一层 Builder。
    return Builder(
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: _isTextureVisible,
        // 保留 Video 子树，出帧后直接恢复绘制，不重建纹理绑定。
        builder: (context, isVisible, video) =>
            Visibility(visible: isVisible, maintainState: true, child: video!),
        child: _buildVideo(context, subtitleStyle),
      ),
    );
  }

  Widget _buildVideo(BuildContext context, MediaSubtitleStyle subtitleStyle) {
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
        textScaler: MediaQuery.textScalerOf(context),
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
    await _videoParamsSubscription?.cancel();
    _controller.rect.removeListener(_onTextureRectChanged);
    await _player.dispose();
    await _keepAlivePlayer?.dispose();
    _keepAlivePlayer = null;
    _isTextureVisible.dispose();
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

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart' as ja;

import '../utils/app_data_dir.dart';

/// Echo Loop 全局后台播放控制器。
///
/// 设计约束：
/// 1. 系统媒体会话、锁屏/通知栏状态只认这一层；
/// 2. Flutter 业务层通过 facade 调它，不直接持有 `AudioPlayer`；
/// 3. 未来若要加上一句/下一句、循环切换、睡眠定时等锁屏控制，只扩这里。
class EchoLoopAudioHandler extends BaseAudioHandler with SeekHandler {
  EchoLoopAudioHandler({ja.AudioPlayer? player})
    : _player = player ?? ja.AudioPlayer() {
    _playbackEventSub = _player.playbackEventStream.listen(
      (_) => _broadcastState(),
    );
    _durationSub = _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item == null || duration == null) return;
      mediaItem.add(item.copyWith(duration: duration));
      _broadcastState();
    });
  }

  final ja.AudioPlayer _player;
  StreamSubscription<ja.PlaybackEvent>? _playbackEventSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  /// 逻辑播放态覆盖。非 null 时锁屏图标/播放态广播读它而非裸 [_player.playing]。
  ///
  /// 学习/复习任务在「句间/段间停顿倒计时」期间主 player 处于 paused，但锁屏应显示
  /// 「播放中」（配合 [startKeepAlive] 的静音保活）。任务在起播/续播时置 true、
  /// 暂停/停止/完成时置 false；离开页面置 null 恢复读裸值（Free Player 维持原行为）。
  bool? _logicalPlaying;

  /// 锁屏/系统媒体会话采用的有效播放态：有覆盖用覆盖，否则读裸 player。
  bool get _effectivePlaying => _logicalPlaying ?? _player.playing;

  /// 后台静音保活播放器。停顿（静音）期间循环播放打包的静音轨，使 iOS 音频会话
  /// 保持活跃、isolate 不被挂起，让 Dart 倒计时定时器在后台照常推进。
  ///
  /// 不接入 audio_service 媒体会话（锁屏只反映主 [_player]）；仅 iOS 需要，
  /// Android 靠前台服务（androidStopForegroundOnPause:false）保活。
  ja.AudioPlayer? _silencePlayer;

  /// 锁屏/通知栏封面图（app 图标缓存为本地文件后的 file:// URI）。
  /// 由 [prepareArtwork] 启动时填充，[loadFile] 构造 MediaItem 时使用。
  Uri? _artworkUri;

  /// 上一句/下一句回调。仅 Free Player 等支持切句的场景注册（见 [setSkipHandlers]）；
  /// 注册后锁屏才显示上一首/下一首按钮，未注册时为 null 且按钮不出现。
  Future<void> Function()? _onSkipToPrevious;
  Future<void> Function()? _onSkipToNext;
  bool get _canSkip => _onSkipToPrevious != null || _onSkipToNext != null;

  /// 系统播放/暂停命令回调。注册后，锁屏/耳机/中断触发的 [play]/[pause] 会转交给
  /// 业务层（controller），使「播完后从头重播」「保留遍数续播」等逻辑在锁屏操作时
  /// 同样生效；未注册时回退到直接驱动底层播放器（见 [playPlayer]/[pausePlayer]）。
  Future<void> Function()? _onPlayCommand;
  Future<void> Function()? _onPauseCommand;

  /// 后退/前进 N 秒回调。仅无字幕音频注册（见 [setSeekHandlers]）；与切句回调
  /// 互斥，注册后锁屏显示 rewind/fastForward 按钮替代上一首/下一首。
  Future<void> Function()? _onRewind;
  Future<void> Function()? _onFastForward;
  bool get _canSeekRelative => _onRewind != null || _onFastForward != null;

  List<MediaControl> _controls = const [MediaControl.play, MediaControl.stop];
  List<int> _compactActionIndices = const [0];

  ja.AudioPlayer get player => _player;

  /// 把 app 图标 asset 拷到本地文件并缓存其 file:// URI，供锁屏封面图使用。
  ///
  /// audio_service 在 iOS 不直接读 Flutter asset，[MediaItem.artUri] 需要
  /// file:// 或网络 URI。文件已存在则跳过写入。失败仅记日志、不抛出
  /// （封面图缺失不应阻断播放初始化）。
  Future<void> prepareArtwork() async {
    if (kIsWeb) return;
    try {
      final dir = await getAppDataDirectory();
      final file = File('${dir.path}/now_playing_artwork.png');
      if (!file.existsSync()) {
        final bytes = await rootBundle.load('assets/icon/app-icon-1024.png');
        await file.writeAsBytes(bytes.buffer.asUint8List());
      }
      _artworkUri = Uri.file(file.path);
    } catch (_) {
      // 封面图准备失败时保持 _artworkUri 为 null，锁屏不显示封面即可。
    }
  }

  /// 注册/清空上一句、下一句回调。传 null 即清空（锁屏隐藏切句按钮）。
  ///
  /// 由 Free Player controller 在接管播放时注册、释放/挂起时清空，使切句按钮的
  /// 出现范围与「当前可切句」严格对应，避免其他播放场景误触。
  void setSkipHandlers({
    Future<void> Function()? onPrevious,
    Future<void> Function()? onNext,
  }) {
    _onSkipToPrevious = onPrevious;
    _onSkipToNext = onNext;
    _broadcastState();
  }

  /// 注册/清空系统播放、暂停命令回调（传 null 清空，回退到直接驱动播放器）。
  ///
  /// 与 [setSkipHandlers] 同步由 controller 在接管/释放引擎时调用，使锁屏播放/暂停
  /// 与 App 内主播放按钮走同一套业务逻辑。
  void setTransportHandlers({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
  }) {
    _onPlayCommand = onPlay;
    _onPauseCommand = onPause;
  }

  /// 设置/清除逻辑播放态覆盖（见 [_logicalPlaying]）。
  ///
  /// 传 null 恢复读裸 [_player.playing]。赋值后立即广播，使锁屏图标即时同步。
  void setLogicalPlaying(bool? playing) {
    _logicalPlaying = playing;
    _broadcastState();
  }

  /// 启动后台静音保活（仅 iOS / 非 Web）。幂等：已在播则不重复启动。
  ///
  /// 懒加载静音轨并循环播放。**音量必须为 1.0**：资源本身是无声内容，听不到声音，
  /// 但只有「会话持续渲染音频」才能让 iOS 不挂起 app、Dart 倒计时定时器在后台照常
  /// 推进，从而支持「整个会话锁屏后自动跑完」。
  ///
  /// 历史坑：曾用 `setVolume(0)` —— iOS 把「零输出」视作「未在播放」仍会挂起 app，
  /// 停顿期定时器冻结 → 锁屏后不推进（表现为「锁屏后暂停」）。
  Future<void> startKeepAlive() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final player = _silencePlayer ??= ja.AudioPlayer();
      if (player.audioSource == null) {
        await player.setAsset('assets/audio/silence_2s.m4a');
        await player.setLoopMode(ja.LoopMode.one);
        await player.setVolume(1.0);
      }
      if (!player.playing) {
        await player.play();
      }
    } catch (_) {
      // 保活失败：后台连续性退化，但不影响前台与主播放。
    }
  }

  /// 暂停静音保活（不 dispose，便于复用）。
  Future<void> stopKeepAlive() async {
    final player = _silencePlayer;
    if (player == null) return;
    try {
      if (player.playing) await player.pause();
    } catch (_) {}
  }

  /// 注册/清空后退、前进 N 秒回调（传 null 清空）。
  ///
  /// 与 [setSkipHandlers] 互斥：有字幕注册切句、无字幕注册相对 seek，由 controller
  /// 按当前音频是否有字幕分流。注册后锁屏控制列表换成 rewind/fastForward。
  void setSeekHandlers({
    Future<void> Function()? onRewind,
    Future<void> Function()? onFastForward,
  }) {
    _onRewind = onRewind;
    _onFastForward = onFastForward;
    _broadcastState();
  }

  Future<void> configureSession() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    await _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        if (_player.playing) {
          await pause();
        }
        return;
      }
      if (event.type == AudioInterruptionType.pause && event.begin == false) {
        _broadcastState();
      }
    });
    await _becomingNoisySub?.cancel();
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) async {
      if (_player.playing) {
        await pause();
      }
    });
  }

  /// 未来锁屏控制扩展统一改这里，不让页面直接拼系统 controls。
  ///
  /// 注册了切句回调（[_canSkip]）时，控制列表拼成「上一句 / 播放暂停 / 下一句」，
  /// 对齐 iOS 锁屏的 prev/play/next 布局；注册了相对 seek 回调（[_canSeekRelative]，
  /// 无字幕场景）时拼成「后退 / 播放暂停 / 前进」；否则保持「播放暂停 / 停止」。
  void setMediaControls({required bool playing, bool canStop = true}) {
    final List<MediaControl> controls;
    if (_canSkip) {
      controls = <MediaControl>[
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ];
      _compactActionIndices = const [0, 1, 2];
    } else if (_canSeekRelative) {
      controls = <MediaControl>[
        MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.fastForward,
      ];
      _compactActionIndices = const [0, 1, 2];
    } else {
      controls = <MediaControl>[
        playing ? MediaControl.pause : MediaControl.play,
        if (canStop) MediaControl.stop,
      ];
      _compactActionIndices = controls.length >= 2 ? const [0, 1] : const [0];
    }
    _controls = controls;
  }

  Future<Duration?> loadFile({
    required String id,
    required String filePath,
    required String title,
    required double speed,
    String? subtitle,
  }) async {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        // 系统播放控制面板副标题展示所属合集名（subtitle）；不再附加 album「Echo
        // Loop」造成「合集 – Echo Loop」。无合集时回退显示 app 名「Echo Loop」。
        artist: subtitle ?? 'Echo Loop',
        artUri: _artworkUri,
      ),
    );
    final duration = await _player.setFilePath(filePath);
    await _player.setSpeed(speed);
    _broadcastState();
    return duration;
  }

  Future<void> setClip({
    required Duration? start,
    required Duration? end,
  }) async {
    await _player.setClip(start: start, end: end);
    _broadcastState();
  }

  /// 直接驱动底层播放器播放（不经业务回调）。
  ///
  /// 由 [AudioEngine] 内部确定性播放协程调用；[play] 的系统命令入口在未注册
  /// [_onPlayCommand] 时也回退到这里。
  Future<void> playPlayer() async {
    await _player.play();
    setMediaControls(playing: true);
  }

  /// 直接驱动底层播放器暂停（不经业务回调）。
  Future<void> pausePlayer() async {
    await _player.pause();
    setMediaControls(playing: false);
  }

  @override
  Future<void> play() async {
    if (_onPlayCommand != null) {
      await _onPlayCommand!();
      return;
    }
    await playPlayer();
  }

  @override
  Future<void> pause() async {
    if (_onPauseCommand != null) {
      await _onPauseCommand!();
      return;
    }
    await pausePlayer();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    // just_audio stop 后 processingState=idle，但不保证发出 playbackEvent 触发
    // 广播；显式广播一次，确保 audio_service 收到 idle → 调 stopService 清掉
    // 锁屏/通知栏媒体控制（与 seek/setClip/loadFile 末尾显式广播一致）。否则
    // 退出播放页面（精听/盲听 exitLearningMode → stop）后锁屏控制会残留。
    _broadcastState();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    await _onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    await _onSkipToPrevious?.call();
  }

  // 覆盖 SeekHandler 的默认实现（按 config 间隔 seek），改走业务回调，使锁屏
  // 后退/前进与 App 内逻辑一致。未注册时为 no-op。
  @override
  Future<void> rewind() async {
    await _onRewind?.call();
  }

  @override
  Future<void> fastForward() async {
    await _onFastForward?.call();
  }

  Future<void> disposePlayer() async {
    await _playbackEventSub?.cancel();
    await _durationSub?.cancel();
    await _interruptionSub?.cancel();
    await _becomingNoisySub?.cancel();
    await _silencePlayer?.dispose();
    await _player.dispose();
  }

  void _broadcastState() {
    setMediaControls(playing: _effectivePlaying);
    playbackState.add(
      PlaybackState(
        controls: _controls,
        systemActions: {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.seek,
          MediaAction.stop,
          if (_canSkip) ...{MediaAction.skipToNext, MediaAction.skipToPrevious},
          if (_canSeekRelative) ...{
            MediaAction.rewind,
            MediaAction.fastForward,
          },
        },
        androidCompactActionIndices: _compactActionIndices,
        processingState: _mapProcessingState(_player.processingState),
        playing: _effectivePlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ja.ProcessingState state) {
    return switch (state) {
      ja.ProcessingState.idle => AudioProcessingState.idle,
      ja.ProcessingState.loading => AudioProcessingState.loading,
      ja.ProcessingState.buffering => AudioProcessingState.buffering,
      ja.ProcessingState.ready => AudioProcessingState.ready,
      // 循环播放器对系统从不真正「结束」：completed 上报为 ready，避免 iOS 把曲目
      // 当作已播完而把锁屏进度条钉在结尾、忽略整篇回卷后的 seek/position 更新
      // （见 CLAUDE.md §7.7）。app 内部的 completed 判定均读原始 player 状态，不受影响。
      ja.ProcessingState.completed => AudioProcessingState.ready,
    };
  }
}

EchoLoopAudioHandler? _globalAudioHandler;

/// 初始化全局后台播放 handler。
Future<EchoLoopAudioHandler> initEchoLoopAudioHandler() async {
  if (_globalAudioHandler != null) return _globalAudioHandler!;
  final handler = EchoLoopAudioHandler();
  await handler.configureSession();
  await handler.prepareArtwork();
  if (!kIsWeb) {
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'app.echoloop.audio',
        androidNotificationChannelName: 'Echo Loop Playback',
        androidStopForegroundOnPause: false,
        // 通知 small icon：app logo 的白色剪影（Android 强制单色，彩色 logo 见封面图）。
        androidNotificationIcon: 'drawable/ic_stat_logo',
      ),
    );
  }
  _globalAudioHandler = handler;
  return handler;
}

EchoLoopAudioHandler get echoLoopAudioHandler {
  final handler = _globalAudioHandler;
  if (handler == null) {
    throw StateError('EchoLoopAudioHandler has not been initialized');
  }
  return handler;
}

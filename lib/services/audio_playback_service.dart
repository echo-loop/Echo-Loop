/// 通用音频播放服务。
///
/// 封装 just_audio 的 [AudioPlayer]，提供简洁的 play/stop API。
/// 播放完成自动回到 idle 状态。
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// 通用音频播放服务。
///
/// 用于播放本地音频文件（如用户录音 .m4a）。
/// 懒初始化 [AudioPlayer]，首次 play 时创建。
class AudioPlaybackService {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _currentFilePath;
  final StreamController<bool> _isPlayingController =
      StreamController<bool>.broadcast();

  /// 当前是否正在播放。
  bool get isPlaying => _player?.playing ?? false;

  /// 当前播放的文件路径。
  String? get currentFilePath => _currentFilePath;

  /// 播放状态流。
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  /// 播放音频文件。
  ///
  /// 如果当前正在播放，先停止再播放新文件。
  Future<void> play(String filePath) async {
    // 停止当前播放
    if (_player != null) {
      await _player!.stop();
    }

    final player = await _ensurePlayer();
    _currentFilePath = filePath;
    _isPlayingController.add(true);
    await player.setFilePath(filePath);
    await player.play();
  }

  /// 停止播放。
  Future<void> stop() async {
    if (_player == null) {
      _currentFilePath = null;
      _isPlayingController.add(false);
      return;
    }
    await _player!.stop();
    _currentFilePath = null;
    _isPlayingController.add(false);
  }

  /// 释放资源。
  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    _playerStateSub = null;
    if (_player != null) {
      await _player!.dispose();
      _player = null;
    }
    _currentFilePath = null;
    await _isPlayingController.close();
  }

  /// 懒初始化播放器。
  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;

    final player = AudioPlayer();
    _player = player;
    _playerStateSub = player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed ||
          playerState.processingState == ProcessingState.idle) {
        _currentFilePath = null;
        _isPlayingController.add(false);
      }
    });
    return player;
  }
}

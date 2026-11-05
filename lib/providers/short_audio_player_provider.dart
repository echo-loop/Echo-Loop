/// 应用内短音频播放器依赖。
///
/// TTS 缓存 WAV 与 CDN 单词音频 m4a 共用此播放器；它不接入系统媒体会话，
/// 仅负责短片段的播放、完成回调与抢占。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/pronunciation/local_audio_clip_player.dart';

final shortAudioPlayerProvider = Provider<LocalAudioClipPlayer>((ref) {
  final player = LocalAudioClipPlayer();
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

final shortAudioPlaybackStateProvider =
    StreamProvider<LocalAudioClipPlaybackState>((ref) {
      final player = ref.watch(shortAudioPlayerProvider);
      return player.states;
    });

/// 界面音效播放（达成目标等短提示音）。
///
/// 音效是体验增强，不影响业务流程：受全局「音效」开关控制，播放失败只记日志。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/settings_provider.dart';
import 'app_logger.dart';

/// App 内可用的音效。新增音效时在此登记资源路径，并在 pubspec 中声明。
enum SoundEffect {
  /// 今日目标达成。
  achievementBell('assets/sound_effects/achievement_bell.m4a');

  const SoundEffect(this.assetPath);

  final String assetPath;
}

/// 播放 [SoundEffect]，每种音效懒创建并复用一个播放器。
///
/// 播放器不接管音频会话（不激活会话、不响应中断），避免短提示音抢占音频焦点、
/// 打断或暂停正在进行的学习音频播放。
class SoundEffectPlayer {
  SoundEffectPlayer({required this._isEnabled});

  final bool Function() _isEnabled;
  // 存 Future 而不是播放器，避免并发首次播放时重复创建播放器。
  final Map<SoundEffect, Future<AudioPlayer>> _players = {};
  bool _isDisposed = false;

  /// 从头播放 [effect]；音效开关关闭时直接跳过。不等待播放结束。
  Future<void> play(SoundEffect effect) async {
    if (_isDisposed) return;
    if (!_isEnabled()) {
      AppLogger.log('SoundEffect', '音效已关闭，跳过: ${effect.name}');
      return;
    }
    try {
      final player = await (_players[effect] ??= _createPlayer(effect));
      await player.seek(Duration.zero);
      // just_audio 的 play() 在播放结束时才完成，这里只需起播。
      unawaited(
        player.play().catchError((Object error) => _logFailure(effect, error)),
      );
      AppLogger.log('SoundEffect', '播放音效: ${effect.name}');
    } on Object catch (error) {
      // 加载失败的播放器不缓存，下次重新尝试。
      _players.remove(effect);
      _logFailure(effect, error);
    }
  }

  /// 音效属于锦上添花，失败时只记日志，不打断调用方流程。
  void _logFailure(SoundEffect effect, Object error) {
    AppLogger.log('SoundEffect', '音效播放失败: ${effect.name} error=$error');
  }

  Future<AudioPlayer> _createPlayer(SoundEffect effect) async {
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
    );
    try {
      await player.setAsset(effect.assetPath);
    } on Object {
      await player.dispose();
      rethrow;
    }
    return player;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    final players = _players.values.toList();
    _players.clear();
    for (final player in players) {
      try {
        await (await player).dispose();
      } on Object {
        // 创建失败的播放器已在 _createPlayer 中释放。
      }
    }
  }
}

/// 全局音效播放器，读取 [AppSettingsState.soundEffectsEnabled] 决定是否出声。
final soundEffectPlayerProvider = Provider<SoundEffectPlayer>((ref) {
  final player = SoundEffectPlayer(
    isEnabled: () => ref.read(appSettingsProvider).soundEffectsEnabled,
  );
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});

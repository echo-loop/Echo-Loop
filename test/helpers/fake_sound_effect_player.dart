import 'package:echo_loop/services/sound_effect_player.dart';

/// 记录播放请求、不触达 just_audio 平台通道的音效播放器替身。
class FakeSoundEffectPlayer extends SoundEffectPlayer {
  FakeSoundEffectPlayer() : super(isEnabled: () => true);

  final List<SoundEffect> playedEffects = [];

  @override
  Future<void> play(SoundEffect effect) async => playedEffects.add(effect);

  @override
  Future<void> dispose() async {}
}

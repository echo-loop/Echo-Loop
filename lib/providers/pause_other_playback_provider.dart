import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_engine/audio_engine_provider.dart';
import 'media_engine/media_engine_provider.dart';
import 'media_playback/media_playback_provider.dart';

/// 进入独占播放器的编辑页（剪辑、字幕编辑）时，暂停其它正在出声的播放链路，
/// 避免两路声音叠在一起；测试替换为空实现。
final pauseOtherPlaybackProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    if (ref.read(mediaEngineProvider.notifier).isPlaying) {
      await ref.read(mediaPlaybackProvider.notifier).pause();
    }
    final audioEngine = ref.read(audioEngineProvider.notifier);
    if (audioEngine.isPlaying) await audioEngine.pause();
  },
);

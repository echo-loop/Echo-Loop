import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_logger.dart';
import '../../services/pronunciation/local_audio_clip_player.dart';
import '../../services/pronunciation/word_audio_repository.dart';
import '../../services/runtime_endpoint_router.dart';
import '../short_audio_player_provider.dart';
import '../tts/tts_controller_provider.dart';

final wordAudioRepositoryProvider = Provider<WordAudioRepository>((ref) {
  return createWordAudioRepository(runtimeEndpointRouter);
});

class TextPlaybackState {
  const TextPlaybackState({this.playingKey});
  final String? playingKey;
}

final textPlaybackProvider =
    NotifierProvider<TextPlaybackController, TextPlaybackState>(
      TextPlaybackController.new,
    );

/// 统一文本朗读入口：单词优先 CDN 预录音频（本地缓存优先），缺失或失败时回退 TTS。
///
/// 所有通用播放入口都经此分流，预热与点击播放走同一套判定，避免页面各自判断。
class TextPlaybackController extends Notifier<TextPlaybackState> {
  int _sessionId = 0;
  LocalAudioClipPlayer? _player;
  bool _disposed = false;

  @override
  TextPlaybackState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const TextPlaybackState();
  }

  /// 朗读 [text] 并返回真实播放终态。会话被新请求或 [stop] 抢占时返回 [AudioPlaybackResult.cancelled]。
  ///
  /// [promptIfModelMissing] 只影响 TTS 回退时本地模型缺失的行为，见
  /// [TtsController.speakWithResult]。
  Future<AudioPlaybackResult> speakWithResult(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    final sessionId = ++_sessionId;
    final playbackKey = key ?? text;
    state = TextPlaybackState(playingKey: playbackKey);
    try {
      final result = await _speak(
        text,
        playbackKey: playbackKey,
        promptIfModelMissing: promptIfModelMissing,
        sessionId: sessionId,
      );
      return sessionId == _sessionId ? result : AudioPlaybackResult.cancelled;
    } finally {
      if (sessionId == _sessionId) state = const TextPlaybackState();
    }
  }

  /// 保留普通文本播放的 fire-and-forget 入口，实际逻辑只在 [speakWithResult] 实现。
  Future<void> speak(
    String text, {
    String? key,
    bool promptIfModelMissing = true,
  }) async {
    await speakWithResult(
      text,
      key: key,
      promptIfModelMissing: promptIfModelMissing,
    );
  }

  /// 后台预热单词发音：CDN 有音频则落入本地缓存；没有则交给 TTS 预热。
  ///
  /// 已在 CDN 的单词不再消耗 TTS 合成额度。预热仍不播放、不抢占当前播放。
  Future<void> prewarmWord(String word) async {
    final cachedPath = await ref
        .read(wordAudioRepositoryProvider)
        .resolve(word);
    if (cachedPath != null) return;
    await ref.read(ttsControllerProvider.notifier).prewarmTextsIncremental([
      word,
    ]);
  }

  Future<AudioPlaybackResult> _speak(
    String text, {
    required String playbackKey,
    required bool promptIfModelMissing,
    required int sessionId,
  }) async {
    final cachedPath = await ref.read(wordAudioRepositoryProvider).resolve(text);
    if (sessionId != _sessionId) return AudioPlaybackResult.cancelled;
    if (cachedPath != null) {
      final result = await _playCachedFile(
        cachedPath,
        playbackKey: playbackKey,
        sessionId: sessionId,
      );
      if (result != AudioPlaybackResult.failed) return result;
      AppLogger.log('TextPlayback', 'CDN 音频播放失败，回退 TTS');
    }
    if (sessionId != _sessionId) return AudioPlaybackResult.cancelled;
    return ref
        .read(ttsControllerProvider.notifier)
        .speakWithResult(
          text,
          key: playbackKey,
          promptIfModelMissing: promptIfModelMissing,
        );
  }

  Future<AudioPlaybackResult> _playCachedFile(
    String path, {
    required String playbackKey,
    required int sessionId,
  }) async {
    await ref.read(ttsControllerProvider.notifier).stop();
    if (sessionId != _sessionId) return AudioPlaybackResult.cancelled;
    try {
      return await _audioPlayer.playFile(path, playbackKey: playbackKey);
    } catch (error, stackTrace) {
      AppLogger.log(
        'TextPlayback',
        'cached word audio failed error=$error\n$stackTrace',
      );
      return AudioPlaybackResult.failed;
    }
  }

  LocalAudioClipPlayer get _audioPlayer {
    final existing = _player;
    if (existing != null) return existing;
    final created = ref.read(shortAudioPlayerProvider);
    _player = created;
    return created;
  }

  Future<void> stop() async {
    _sessionId++;
    await _player?.stop();
    if (_disposed) return;
    try {
      await ref.read(ttsControllerProvider.notifier).stop();
    } catch (error, stackTrace) {
      // 页面销毁后的迟到清理可能先于 ProviderContainer 释放完成；此时媒体已经
      // 被当前播放器会话作废，不能让二次清理异常反向污染页面收尾。
      AppLogger.log(
        'TextPlayback',
        'TTS stop skipped during provider cleanup error=$error\n$stackTrace',
      );
    }
    if (_disposed) return;
    state = const TextPlaybackState();
  }
}

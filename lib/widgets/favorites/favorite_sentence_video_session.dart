import '../../database/daos/audio_item_dao.dart';
import '../../models/audio_item.dart';
import '../../models/media_playback_state.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/media_engine/media_sense_group_range_playback.dart';
import '../../screens/sentence_detail_screen.dart';
import '../../services/app_logger.dart';
import '../common/media_presentation_controller.dart';

/// [FavoriteSentenceVideoSession.open] 的结果。
enum FavoriteVideoOpenResult {
  /// 视频已加载并停在句首，可以进入讲解页。
  opened,

  /// 加载期间被同一入口的新一次打开取代，调用方不应进入讲解页。
  cancelled,

  /// 视频加载失败，调用方应提示用户并留在收藏页。
  failed,
}

/// 收藏入口打开视频来源句时使用的视频讲解会话。
///
/// 收藏页本身不播放视频，因此由会话把材料加载进 [MediaEngine]：加载时直接
/// 定位到句首，关闭时只解绑页面并保留 backend。生命周期与随心听、盲听、复述
/// 的媒体会话保持一致。
class FavoriteSentenceVideoSession {
  FavoriteSentenceVideoSession({
    required MediaEngine engine,
    required AudioEngine audioEngine,
    required AudioItemDao audioItemDao,
  }) : _engine = engine,
       _audioEngine = audioEngine,
       _audioItemDao = audioItemDao;

  final MediaEngine _engine;
  final AudioEngine _audioEngine;
  final AudioItemDao _audioItemDao;
  int? _mediaSessionId;
  MediaPresentationController? _presentation;
  bool _isClosed = false;

  /// 加载视频并定位到 [sentenceStart]。
  ///
  /// 同一入口连续触发时，后一次 [MediaEngine.newSession] 会让前一次失效。前一次
  /// 返回 [FavoriteVideoOpenResult.cancelled]，由调用方不再进入讲解页，因此
  /// 快速连点不会推入两个讲解页。
  Future<FavoriteVideoOpenResult> open({
    required AudioItem item,
    required Duration sentenceStart,
  }) async {
    // 音频与视频共用系统媒体会话，进入视频讲解前先停掉音频。
    if (_audioEngine.isPlaying) await _audioEngine.pause();
    final sessionId = _engine.newSession();
    _mediaSessionId = sessionId;
    // 讲解页的区间播放自带速度；加载速度只作为首次打开的默认值。
    final duration = await _engine.loadMedia(
      item,
      1.0,
      initialPosition: sentenceStart,
      publishToSystemMediaSession: true,
    );
    if (_isClosed || !_engine.isActiveSession(sessionId)) {
      return FavoriteVideoOpenResult.cancelled;
    }
    if (duration == null) {
      AppLogger.log(
        'FavoriteVideo',
        'open failed audio=${item.id} '
            'error=${_engine.errorMessage ?? 'duration-unavailable'}',
      );
      return FavoriteVideoOpenResult.failed;
    }
    _presentation = MediaPresentationController(
      engine: _engine,
      readTranscriptSrt: _audioItemDao.getTranscriptSrt,
      audioItemId: item.id,
    )..start();
    return FavoriteVideoOpenResult.opened;
  }

  /// 讲解页借用的视频会话；只能在 [open] 成功后、[close] 之前使用。
  SentenceDetailMediaSession get mediaSession {
    final presentation = _requirePresentation();
    return SentenceDetailMediaSession(
      readState: () => MediaPlaybackState(
        visualTrackVisible: presentation.visualTrackVisible,
        visualTrackExpanded: presentation.expanded,
        videoSubtitleVisible: presentation.subtitleVisible,
        videoAspectRatio: _engine.videoAspectRatio,
      ),
      setVisible: presentation.setVisualTrackVisible,
      setSubtitleVisible: presentation.setSubtitleVisible,
      setFullscreen: presentation.setFullscreen,
      previewPosition: _engine.seekForPreview,
      buildVideoView: (size) => _engine.buildVideoView(viewportSize: size),
    );
  }

  /// 句子与意群的区间播放，与随心听共用同一个媒体引擎。
  SenseGroupRangePlayback Function(double Function() playbackSpeed)
  get rangePlaybackBuilder =>
      (playbackSpeed) => MediaSenseGroupRangePlayback(
        engine: _engine,
        playbackSpeed: playbackSpeed,
      );

  /// 逐词高亮跟随媒体引擎时间轴，与随心听的讲解页保持一致。
  WordHighlightSource wordHighlightSource(String audioItemId) {
    return WordHighlightSource(
      audioItemId: audioItemId,
      positionStream: _engine.wordHighlightPositionStream,
      currentPosition: _engine.wordHighlightPosition,
      playbackStatus: _engine.wordHighlightPlaybackStatus,
      playbackStatusStream: _engine.wordHighlightPlaybackStatusStream,
    );
  }

  /// 离开讲解页时调用：退出全屏并解绑页面。只释放仍归本会话所有的引擎会话，
  /// 被后一次打开取代的会话不会误伤新会话。
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    final presentation = _presentation;
    _presentation = null;
    if (presentation != null) {
      await presentation.release();
      presentation.dispose();
    }
    final sessionId = _mediaSessionId;
    if (sessionId != null && _engine.isActiveSession(sessionId)) {
      await _engine.releaseFromScreen();
    }
  }

  MediaPresentationController _requirePresentation() {
    final presentation = _presentation;
    if (presentation == null) {
      throw StateError('收藏视频讲解会话须在 open 成功后、close 之前使用');
    }
    return presentation;
  }
}

import 'package:flutter/foundation.dart';

import '../../database/daos/audio_item_dao.dart';
import '../../models/audio_item.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/sentence_playback_result.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/audio_engine/audio_engine_provider.dart';
import '../../providers/media_engine/media_engine_provider.dart';
import '../../providers/media_engine/media_sense_group_range_playback.dart';
import '../../services/app_logger.dart';
import '../common/media_presentation_controller.dart';
import '../common/practice_media_presentation_host.dart';

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
///
/// 收藏句复习在一次复习内复用同一个会话：逐张卡片调用 [open]，同一材料只
/// 定位不重新加载，画面显示 / 隐藏状态跨卡片保留。
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

  /// 最近一次成功加载的材料；加载失败或被取代时清空。
  String? _loadedAudioItemId;

  /// [audioItemId] 是否已加载在本会话持有的引擎会话中，可直接定位复用。
  bool isLoaded(String audioItemId) {
    final sessionId = _mediaSessionId;
    return !_isClosed &&
        _loadedAudioItemId == audioItemId &&
        sessionId != null &&
        _engine.isActiveSession(sessionId);
  }

  /// 画面显示 / 隐藏等呈现状态变化的通知源；首次 [open] 成功前为 null。
  Listenable? get presentationChanges => _presentation;

  /// 显示或隐藏画面（只影响视频轨，声音照常）；须在 [open] 成功后调用。
  Future<void> setVisualTrackVisible(bool visible) =>
      _requirePresentation().setVisualTrackVisible(visible);

  /// 用户是否选择显示画面；隐藏后仍保留声音。
  bool get visualTrackVisible => _presentation?.visualTrackVisible ?? true;

  /// 已解码视频的宽高比；未知时为 null。
  double? get videoAspectRatio => _engine.videoAspectRatio;

  /// 视频宽高比变化（解码出首帧尺寸后）的通知流。
  Stream<double?> get videoAspectRatioStream => _engine.videoAspectRatioStream;

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
    _loadedAudioItemId = null;
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
    _loadedAudioItemId = item.id;
    final presentation = _presentation;
    if (presentation == null) {
      _presentation = MediaPresentationController(
        engine: _engine,
        readTranscriptSrt: _audioItemDao.getTranscriptSrt,
        audioItemId: item.id,
      )..start();
    } else {
      // 复用时保留画面显示 / 隐藏状态；新引擎会话的视频轨默认开启，需与之对齐。
      presentation.switchAudioItem(item.id);
      if (!presentation.visualTrackVisible) {
        await _engine.setVideoTrackEnabled(false);
      }
    }
    return FavoriteVideoOpenResult.opened;
  }

  /// 暂停中把画面移到 [position]，不触发逐词高亮。
  Future<void> previewPosition(Duration position) =>
      _engine.seekForPreview(position);

  /// 在本会话的引擎会话中播放一个区间；会话已被取代时返回 cancelled。
  Future<SentencePlaybackResult> playRange(Duration start, Duration end) {
    final sessionId = _mediaSessionId;
    if (_isClosed || sessionId == null) {
      return Future.value(SentencePlaybackResult.cancelled);
    }
    return _engine.playRange(start, end, speed: 1.0, sessionId: sessionId);
  }

  /// 取消正在进行的区间播放，画面停在当前帧。
  Future<void> cancelPlayback() =>
      _engine.cancelActiveRange(reason: 'favorite-video-cancel');

  /// 讲解页借用的视频会话；只能在 [open] 成功后、[close] 之前使用。
  PracticeMediaPresentationSession get mediaSession {
    final presentation = _requirePresentation();
    return PracticeMediaPresentationSession(
      readState: () => PracticeMediaPresentationState(
        enabled: true,
        visualTrackVisible: presentation.visualTrackVisible,
        expanded: presentation.expanded,
        subtitleVisible: presentation.subtitleVisible,
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
    _loadedAudioItemId = null;
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

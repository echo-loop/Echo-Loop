import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../database/daos/playback_state_dao.dart';
import '../../models/audio_item.dart';
import '../../models/listening_practice_state.dart';
import '../../models/media_load_result.dart';
import '../../models/media_playback_state.dart';
import '../../models/playback_settings.dart';
import '../../models/sentence.dart';
import '../../models/sentence_focus_reason.dart';
import '../../models/sentence_playback_result.dart';
import '../../models/sense_group_range_playback.dart';
import '../../models/study_stage.dart';
import '../../models/word_highlight_binding.dart';
import '../../services/app_logger.dart';
import '../../services/study_session_timer.dart';
import '../../services/storage_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../favorite_sentence_lifecycle_provider.dart';
import '../listening_practice/playback_reducer.dart';
import '../listening_practice/playback_state_storage.dart';
import '../listening_practice/sentence_tracker.dart';
import '../media_engine/media_engine_provider.dart';
import '../media_engine/media_sense_group_range_playback.dart';

final mediaPlaybackProvider =
    NotifierProvider<MediaPlayback, MediaPlaybackState>(MediaPlayback.new);

/// media_kit 随心听控制器。
///
/// 音频与视频随心听共用此控制器，由 [MediaEngine] 统一驱动播放；其他学习任务继续
/// 使用 ListeningPractice 和 AudioEngine。
class MediaPlayback extends Notifier<MediaPlaybackState> {
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool?>? _landscapeVideoSub;
  StreamSubscription<double?>? _videoAspectRatioSub;
  int _loadGeneration = 0;
  int _playbackGen = 0;
  int _playbackSessionId = -1;
  bool _activeSentenceDrivenPlayback = false;
  Duration? _sentenceResumePosition;
  ({int index, Duration releaseAt})? _pendingFullSentenceFocus;
  bool _isInPlaybackInterval = false;
  int? _playbackIntervalGeneration;

  /// 连续整篇播放的统计游标；它只记录本次播放会话已经跨过的句尾。
  Duration? _lastGaplessStatsPosition;
  bool _awaitingReplayFromStart = false;
  Duration? _pauseAfterPosition;
  bool _autoSaving = false;
  bool _released = false;
  bool _loadReady = false;
  bool _positionUpdatesEnabled = false;
  bool _changingPlaylistMode = false;
  String? _videoSubtitleSrt;
  MediaEngine? _engineCache;
  int? _loadedResourceGeneration;
  SenseGroupRangePlayback? _senseGroupRangePlayback;
  PlaybackStateDao? _playbackStateDaoCache;
  StudySessionTimer? _studySessionTimer;
  int _studyPageGeneration = 0;
  int? _activeStudyPageGeneration;
  Future<void>? _finishStudyPageInFlight;
  int? _finishStudyPageInFlightGeneration;

  MediaEngine get _engine {
    final cached = _engineCache;
    if (cached != null) return cached;
    final engine = ref.read(mediaEngineProvider.notifier);
    _engineCache = engine;
    return engine;
  }

  /// 建立媒体随心听页面级学习会话；页面退出前播放器状态不会结束该会话。
  int beginStudyPage() {
    final generation = ++_studyPageGeneration;
    _activeStudyPageGeneration = generation;
    if (_studySessionTimer == null) {
      final timer = StudySessionTimer(
        studyTimeService: ref.read(studyTimeServiceProvider),
        stage: StudyStage.freePlayer,
        activityGate: ref.read(studyActivityGateProvider),
        allowBackgroundPlayback: true,
        idleTimeout: const Duration(minutes: 2),
        logScope: 'FreePlayerMediaTimer',
      );
      _studySessionTimer = timer;
      timer.start();
    } else {
      _studySessionTimer?.markActivity();
    }
    _studySessionTimer?.setPlaybackActive(state.isPlaying);
    return generation;
  }

  /// 标记媒体随心听页面上的用户活动。
  void markStudyActivity() {
    _studySessionTimer?.markActivity();
  }

  /// 将播放器活动状态同步给页面学习会话。
  void _setStudyPlaybackActive(bool active) {
    _studySessionTimer?.setPlaybackActive(active);
  }

  /// 结束指定页面会话；过期页面的异步清理不会关闭新页面会话。
  Future<bool> endStudyPage(int generation) async {
    if (_activeStudyPageGeneration != generation) return false;
    await _endActiveStudyPage();
    return true;
  }

  /// 完成当前媒体随心听页面的退出收尾。
  ///
  /// 正常路由退出和页面销毁兜底都调用此入口，复用媒体释放流程并等待
  /// 页面计时器的最终 flush。传入页面代际时，过期页面不会释放新会话。
  Future<void> finishStudyPage({int? generation}) {
    final activeGeneration = _activeStudyPageGeneration;
    if (activeGeneration == null ||
        (generation != null && generation != activeGeneration)) {
      if (generation != null && activeGeneration != generation) {
        AppLogger.log(
          'StudyExit',
          'media finish skipped reason=stale-generation '
              'requestedGeneration=$generation activeGeneration=$activeGeneration',
        );
      }
      return Future<void>.value();
    }

    final inFlight = _finishStudyPageInFlight;
    if (inFlight != null &&
        _finishStudyPageInFlightGeneration == activeGeneration) {
      AppLogger.log(
        'StudyExit',
        'media finish joined generation=$activeGeneration',
      );
      return inFlight;
    }

    final targetGeneration = activeGeneration;
    AppLogger.log(
      'StudyExit',
      'media finish start generation=$targetGeneration',
    );
    final operation = _finishStudyPage(targetGeneration);
    late final Future<void> scheduled;
    scheduled = operation.whenComplete(() {
      if (identical(_finishStudyPageInFlight, scheduled)) {
        _finishStudyPageInFlight = null;
        _finishStudyPageInFlightGeneration = null;
      }
    });
    _finishStudyPageInFlight = scheduled;
    _finishStudyPageInFlightGeneration = targetGeneration;
    return scheduled;
  }

  /// 按页面代际执行计时 flush、媒体解绑和断点保存。
  Future<void> _finishStudyPage(int generation) async {
    if (_activeStudyPageGeneration != generation) return;
    try {
      await releaseFromScreen(studyPageGeneration: generation);
      AppLogger.log(
        'StudyExit',
        'media finish complete generation=$generation',
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'StudyExit',
        'media finish failed generation=$generation error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> _endActiveStudyPage() async {
    final generation = _activeStudyPageGeneration;
    final timer = _studySessionTimer;
    try {
      if (timer != null) await timer.dispose();
    } catch (error, stackTrace) {
      // 统计失败不能阻止媒体页面释放；媒体资源的清理由下方退出流程继续完成。
      AppLogger.log(
        'StudyExit',
        'media timer flush failed generation=$generation error=$error\n$stackTrace',
      );
    } finally {
      if (_activeStudyPageGeneration == generation &&
          identical(_studySessionTimer, timer)) {
        _activeStudyPageGeneration = null;
        _studySessionTimer = null;
      }
    }
  }

  void _setPlaying(bool playing) {
    if (!playing) {
      state = state.copyWith(isPlaying: false);
      _setStudyPlaybackActive(false);
      return;
    }
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: playing);
    _setStudyPlaybackActive(true);
  }

  /// 自动续播间隔内维持逻辑播放态，避免 backend 暂停时切成播放按钮。
  void _beginPlaybackInterval(int generation) {
    if (generation != _playbackGen) return;
    _isInPlaybackInterval = true;
    _playbackIntervalGeneration = generation;
    _setPlaying(true);
    _engine.setLogicalPlaying(true);
    _engine.setProgressFrozen(true);
  }

  /// 用户暂停、播放结束或页面释放时清除自动续播覆盖态。
  void _clearPlaybackInterval() {
    if (!_isInPlaybackInterval) return;
    _isInPlaybackInterval = false;
    _playbackIntervalGeneration = null;
    _engineCache?.setProgressFrozen(false);
    _engineCache?.setLogicalPlaying(null);
  }

  /// 新一遍真正起播后交还锁屏状态给 backend。
  void _onPlaybackStarted() {
    if (!_isInPlaybackInterval || _playbackIntervalGeneration != _playbackGen) {
      return;
    }
    _clearPlaybackInterval();
  }

  /// 记录连续播放位置前进期间自然结束的字幕句子。
  ///
  /// 计时器独立负责听力时长；这里仅复用句子统计入口写入听到的词数和唯一词形。
  /// 位置倒退表示 seek 或回卷，重置游标而不把跳过的内容算作听到。
  void _recordGaplessStatsThrough(Duration position) {
    if (_activeSentenceDrivenPlayback || state.sentences.isEmpty) return;

    final previous = _lastGaplessStatsPosition;
    if (previous == null) {
      _lastGaplessStatsPosition = position;
      return;
    }
    if (position <= previous) {
      if (position < previous) _lastGaplessStatsPosition = position;
      return;
    }

    _lastGaplessStatsPosition = position;

    final completed = SentenceTracker.findSentencesCompletedBetween(
      state.sentences,
      previous,
      position,
    );
    for (final sentence in completed) {
      _recordCompletedSentenceStatistics(sentence);
    }
  }

  void _resetGaplessStatsPosition(Duration position) {
    _lastGaplessStatsPosition = position;
  }

  /// 将播放器置为停止态；学习页面会话由页面退出时统一结束。
  Future<void> _stopPlaying() async {
    _clearPlaybackInterval();
    state = state.copyWith(isPlaying: false);
    _setStudyPlaybackActive(false);
  }

  /// 普通暂停只暂停输入计时，保留页面学习会话供用户继续思考。
  Future<void> _pausePlaying() async {
    _clearPlaybackInterval();
    state = state.copyWith(isPlaying: false);
    _setStudyPlaybackActive(false);
  }

  /// 当前媒体会话的意群区间播放器；随心听页面只通过该契约传递播放意图。
  SenseGroupRangePlayback get senseGroupRangePlayback {
    return _senseGroupRangePlayback ??= MediaSenseGroupRangePlayback(
      engine: _engine,
      playbackSpeed: () => state.settings.playbackSpeed,
    );
  }

  @override
  MediaPlaybackState build() {
    ref.onDispose(() {
      _loadGeneration++;
      _playbackGen++;
      _clearPlaybackInterval();
      unawaited(_positionSub?.cancel());
      unawaited(_playingSub?.cancel());
      unawaited(_landscapeVideoSub?.cancel());
      unawaited(_videoAspectRatioSub?.cancel());
      final engine = _engineCache;
      unawaited(_endActiveStudyPage());
      unawaited(_senseGroupRangePlayback?.cancel());
      engine?.setTransportHandlers(onPlay: null, onPause: null);
      engine?.setSkipHandlers();
      engine?.setSeekHandlers();
      unawaited(engine?.releaseForOwnerDispose());
    });
    return const MediaPlaybackState();
  }

  List<Sentence> get _playable => state.playableSentences;

  bool get _usesSentenceDrivenPlayback =>
      state.playlistMode == PlaylistMode.bookmarks ||
      state.settings.loopSentence;

  int? get _currentPos => state.currentPlayablePosition;

  /// 准备随心听媒体及其业务数据。
  ///
  /// 每次调用都会分配独立 generation；退出、取消或后续重试会使旧任务失效，
  /// 防止迟到的字幕、断点和播放器结果重新污染已经释放的页面状态。
  Future<MediaLoadResult> load(AudioItem item) async {
    final pendingRelease = _releaseInFlight;
    if (pendingRelease != null) {
      await pendingRelease;
    }
    final engine = _engine;
    if (state.audioItem?.id == item.id &&
        !_released &&
        _loadReady &&
        _loadedResourceGeneration == engine.resourceGeneration &&
        engine.isReadyFor(item.id)) {
      return MediaLoadResult.ready;
    }
    final generation = ++_loadGeneration;
    bool isCurrentGeneration() => generation == _loadGeneration && !_released;

    _released = false;
    _clearPlaybackInterval();
    _loadReady = false;
    _positionUpdatesEnabled = false;
    _playbackGen++;
    _pauseAfterPosition = null;
    _pendingFullSentenceFocus = null;
    await _positionSub?.cancel();
    await _playingSub?.cancel();
    await _landscapeVideoSub?.cancel();
    await _videoAspectRatioSub?.cancel();

    state = state.copyWith(
      audioItem: item,
      isLoading: true,
      isTranscriptLoading: true,
      clearErrorMessage: true,
      clearDuration: true,
      position: Duration.zero,
      sentences: const [],
      clearCurrentFullIndex: true,
      clearCurrentBookmarkIndex: true,
      isPlaying: false,
      wholeLoopsDone: 0,
      sentenceRepeatsDone: 0,
      visualTrackVisible: true,
      visualTrackExpanded: false,
      videoSubtitleVisible: false,
      clearIsLandscapeVideo: true,
      clearVideoAspectRatio: true,
    );
    _videoSubtitleSrt = null;

    try {
      _engineCache = engine;
      final audioEngine = ref.read(audioEngineProvider.notifier);
      final playbackRestoreFuture = _loadPlaybackState(item);
      if (audioEngine.isPlaying) await audioEngine.pause();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;

      final settingsStore = await StorageService.loadSettings();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      state = state.copyWith(
        fullSettings: settingsStore.full,
        bookmarkSettings: settingsStore.bookmark,
      );

      // 字幕读取与 media_kit 初始化互不依赖，应并行启动。字幕通常更快，完成后
      // 立即更新列表；外挂字幕轨仍在 backend 打开完成后再设置。
      final transcriptFuture = _loadTranscriptData(item, audioEngine);
      // 断点必须在打开视频前就绪：页面先显示正确进度，Media(start) 也能直接
      // 解码目标帧，避免先露出第 0 帧再执行一次可见 seek。
      final playbackRestore = await playbackRestoreFuture;
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      _applyInitialPlaybackState(playbackRestore);
      final mediaFuture = _engine.loadMedia(
        item,
        state.settings.playbackSpeed,
        initialPosition: state.position,
      );

      final transcriptData = await transcriptFuture;
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      _videoSubtitleSrt = transcriptData.subtitleSrt;
      state = state.copyWith(
        sentences: transcriptData.sentences,
        bookmarkedIndices: transcriptData.bookmarkedIndices,
        currentFullIndex: transcriptData.sentences.isEmpty ? null : 0,
        requestSentenceFocus: transcriptData.sentences.isNotEmpty,
        sentenceFocusReason: SentenceFocusReason.immediate,
        isTranscriptLoading: false,
      );
      _syncSentenceFocusToPosition();

      final duration = await mediaFuture;
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      if (duration == null) {
        final errorMessage = ref.read(mediaEngineProvider).errorMessage;
        await _engine.releaseFromScreen();
        if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
        state = state.copyWith(isLoading: false, errorMessage: errorMessage);
        return MediaLoadResult.failure;
      }

      _engine.setTransportHandlers(onPlay: play, onPause: pause);
      if (state.hasSentences) {
        _engine.setSeekHandlers();
        _engine.setSkipHandlers(
          onPrevious: previousSentence,
          onNext: nextSentence,
        );
      } else {
        _engine.setSkipHandlers();
        _engine.setSeekHandlers(
          onRewind: () => seekRelative(const Duration(seconds: -10)),
          onFastForward: () => seekRelative(const Duration(seconds: 10)),
        );
      }
      _positionSub = _engine.positionStream.listen(_onPositionChanged);
      _playingSub = _engine.playingStream.listen((playing) {
        // 底层状态只校准 UI。计时器由 Provider 的显式播放/暂停入口控制，避免
        // 区间起播时 backend 的瞬时 false 让计时器被错误切断。
        if (playing) _onPlaybackStarted();
        if (!playing &&
            _isInPlaybackInterval &&
            _playbackIntervalGeneration == _playbackGen) {
          return;
        }
        if (state.isPlaying != playing) {
          state = state.copyWith(isPlaying: playing);
        }
      });
      state = state.copyWith(isLandscapeVideo: _engine.isLandscapeVideo);
      _landscapeVideoSub = _engine.isLandscapeVideoStream.listen((value) {
        if (!_released && state.isLandscapeVideo != value) {
          state = state.copyWith(
            isLandscapeVideo: value,
            clearIsLandscapeVideo: value == null,
          );
        }
      });
      state = state.copyWith(videoAspectRatio: _engine.videoAspectRatio);
      _videoAspectRatioSub = _engine.videoAspectRatioStream.listen((value) {
        if (!_released && state.videoAspectRatio != value) {
          state = state.copyWith(
            videoAspectRatio: value,
            clearVideoAspectRatio: value == null,
          );
        }
      });

      // 视频进入时默认不显示字幕，同时清空播放器可能保留的外挂字幕轨。
      await _engine.setSubtitleTrackData(
        state.videoSubtitleVisible ? _videoSubtitleSrt : null,
      );
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      state = state.copyWith(duration: duration, isLoading: false);
      _positionUpdatesEnabled = true;
      _applyTransportSpeed();
      _loadReady = true;
      _loadedResourceGeneration = engine.resourceGeneration;
      return MediaLoadResult.ready;
    } catch (e) {
      AppLogger.log('MediaPlayback', '✗ load failed: $e');
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      await _engineCache?.releaseFromScreen();
      if (!isCurrentGeneration()) return MediaLoadResult.cancelled;
      state = state.copyWith(
        isLoading: false,
        isTranscriptLoading: false,
        errorMessage: e.toString(),
      );
      return MediaLoadResult.failure;
    }
  }

  /// 读取页面字幕、外挂字幕原文与收藏状态。
  ///
  /// 此流程不依赖播放器 backend，可与视频打开并行；只有数据完整后才结束字幕加载
  /// 状态，避免列表先显示未同步收藏标记的中间态。
  Future<
    ({
      List<Sentence> sentences,
      Set<int> bookmarkedIndices,
      String? subtitleSrt,
    })
  >
  _loadTranscriptData(AudioItem item, AudioEngine audioEngine) async {
    final sentencesFuture = audioEngine.loadTranscript(item);
    final subtitleSrtFuture = _loadSubtitleTrackData(item);
    final sentences = await sentencesFuture;
    final subtitleSrt = await subtitleSrtFuture;
    var bookmarkedIndices = <int>{};
    if (sentences.isNotEmpty) {
      try {
        final bookmarkDao = ref.read(bookmarkDaoProvider);
        bookmarkedIndices = await BookmarkManager.loadBookmarks(
          item.id,
          dao: bookmarkDao,
        );
      } catch (e) {
        AppLogger.log('MediaPlayback', '⚠ load bookmarks failed: $e');
      }
    }
    BookmarkManager.updateSentenceBookmarkStatus(sentences, bookmarkedIndices);
    return (
      sentences: sentences,
      bookmarkedIndices: bookmarkedIndices,
      subtitleSrt: subtitleSrt,
    );
  }

  void _onPositionChanged(Duration position) {
    // backend 初始化期间可能先补发 0；断点已作为 Media(start) 传入，正式就绪前
    // 保持预读的正确位置，避免进度条从断点闪回 0 再恢复。
    if (!_positionUpdatesEnabled) return;
    final previousFullIndex = state.currentFullIndex;
    state = state.copyWith(position: position);
    if (!_engine.isActiveSession(_playbackSessionId)) return;
    if (_engine.isPlaying) _recordGaplessStatsThrough(position);
    final pauseAfterPosition = _pauseAfterPosition;
    if (_engine.isPlaying &&
        pauseAfterPosition != null &&
        position >= pauseAfterPosition) {
      _pauseAfterPosition = null;
      unawaited(pause());
      return;
    }
    if (!_engine.isPlaying || _activeSentenceDrivenPlayback) return;
    final pendingFocus = _pendingFullSentenceFocus;
    if (pendingFocus != null) {
      if (state.currentFullIndex != pendingFocus.index ||
          position >= pendingFocus.releaseAt) {
        _pendingFullSentenceFocus = null;
      } else {
        // 点句子后的短暂 seek 回退不应把列表焦点切回相邻句。
        return;
      }
    }
    final idx = _nearestSentenceIndex(position);
    if (idx < 0) return;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarkIndex = _nearestBookmarkIndex(position);
      if (bookmarkIndex != null &&
          bookmarkIndex != state.currentBookmarkIndex) {
        state = state.copyWith(
          currentBookmarkIndex: bookmarkIndex,
          requestSentenceFocus: true,
          sentenceFocusReason: SentenceFocusReason.playback,
        );
        _autoSaveProgress();
      }
      return;
    }
    if (idx != state.currentFullIndex) {
      state = state.copyWith(
        currentFullIndex: idx,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.playback,
      );
      AppLogger.log(
        'MediaPlayback',
        'position changed full-list focus from=$previousFullIndex to=$idx '
            'position=${position.inMilliseconds}ms '
            'backendPlaying=${_engine.isPlaying} '
            'session=$_playbackSessionId',
      );
      _autoSaveProgress();
    }
  }

  /// 在播放器打开前读取断点，供进度 state 与 media_kit 的 start 参数共同使用。
  Future<PlaybackStateRestoreResult?> _loadPlaybackState(AudioItem item) async {
    PlaybackStateDao dao;
    try {
      dao = _playbackStateDaoCache ?? ref.read(playbackStateDaoProvider);
      _playbackStateDaoCache = dao;
    } catch (e) {
      AppLogger.log('MediaPlayback', '⚠ restore state unavailable: $e');
      return null;
    }
    return PlaybackStateStorage.loadPlaybackState(item.id, dao: dao);
  }

  void _applyInitialPlaybackState(PlaybackStateRestoreResult? result) {
    if (result == null) return;
    final mode = result.playlistMode;
    final position = result.position;
    state = state.copyWith(playlistMode: mode, position: position);
  }

  /// 字幕可能晚于断点完成；字幕写入后再从已恢复位置推导当前播放列表的焦点。
  ///
  /// 收藏模式的媒体时间不应被列表焦点吸附，但焦点必须选中恢复时间附近的收藏句；
  /// 否则空的 [MediaPlaybackState.currentBookmarkIndex] 会被
  /// [_ensureValidIndex] 回退成第一条收藏，造成列表与进度条指向不同句子。
  void _syncSentenceFocusToPosition() {
    final idx = _nearestSentenceIndex(state.position);
    final bookmarkIndex = state.playlistMode == PlaylistMode.bookmarks
        ? _nearestBookmarkIndex(state.position)
        : null;
    state = state.copyWith(
      currentFullIndex: idx >= 0 ? idx : null,
      currentBookmarkIndex: bookmarkIndex,
      requestSentenceFocus: true,
      sentenceFocusReason: SentenceFocusReason.immediate,
    );
    _ensureValidIndex();
  }

  /// 按当前播放设置开始或恢复播放。
  ///
  /// 用户在播放中拖动进度、点选句子或切换上下句时传
  /// [resetWholeLoops] 为 false：这些都是同一整篇循环会话内的导航，不能把已经
  /// 自然完成的整篇遍数清零。仅明确新起播时才使用默认值重置计数。
  Future<void> play({bool resetWholeLoops = true}) async {
    AppLogger.log(
      'MediaPlayback',
      'play tap: item=${state.audioItem?.id} loading=${state.isLoading} '
          'sentences=${state.sentences.length} isPlaying=${state.isPlaying} '
          'session=$_playbackSessionId engineSession=${_engine.currentSessionId}',
    );
    if (state.audioItem == null || state.isLoading) {
      AppLogger.log('MediaPlayback', 'play ignored: no item or loading');
      return;
    }
    if (state.sentences.isEmpty) {
      AppLogger.log(
        'MediaPlayback',
        'play route: whole playback without subtitles',
      );
      await _startWholeDriven(startAtBeginning: _shouldRestartWhole());
      return;
    }
    _ensureValidIndex();
    if (state.playlistMode == PlaylistMode.bookmarks &&
        state.bookmarkedSentences.isEmpty) {
      AppLogger.log(
        'MediaPlayback',
        'play ignored: bookmark playlist is empty',
      );
      return;
    }
    if (_awaitingReplayFromStart || _isAtEnd()) {
      await _restartFromPlayableBeginning();
      return;
    }
    if (_usesSentenceDrivenPlayback) {
      AppLogger.log('MediaPlayback', 'play route: sentence playback');
      final resumePosition = _sentenceResumePosition;
      _sentenceResumePosition = null;
      _launchSentenceDriven(
        resetWholeLoops: resetWholeLoops,
        resetSentenceRepeats: resumePosition == null,
        startAt: resumePosition,
      );
      return;
    }
    _sentenceResumePosition = null;
    await _startWholeDriven(resetWholeLoops: resetWholeLoops);
  }

  Future<void> pause() async {
    AppLogger.log(
      'MediaPlayback',
      'pause tap: item=${state.audioItem?.id} session=$_playbackSessionId '
          'engineSession=${_engine.currentSessionId}',
    );
    _recordGaplessStatsThrough(_engine.currentPosition);
    _sentenceResumePosition = null;
    if (_activeSentenceDrivenPlayback) {
      final playable = _playable;
      final pos = _currentPos;
      final sentence = pos != null && pos >= 0 && pos < playable.length
          ? playable[pos]
          : null;
      final position = _engine.currentPosition;
      _sentenceResumePosition =
          sentence != null &&
              position >= sentence.startTime &&
              position < sentence.endTime
          ? position
          : null;
    }
    _playbackGen++;
    _clearPlaybackInterval();
    _activeSentenceDrivenPlayback = false;
    _awaitingReplayFromStart = false;
    _pauseAfterPosition = null;
    _pendingFullSentenceFocus = null;
    await _pausePlaying();
    await _engine.pause();
    _playbackSessionId = _engine.currentSessionId;
  }

  /// 请求当前句自然播放结束后暂停；未在播放或当前句无效时立即暂停。
  Future<void> pauseAfterCurrentSentence() async {
    if (!state.isPlaying) {
      await pause();
      return;
    }
    final pos = _currentPos;
    final playable = _playable;
    if (pos == null || pos < 0 || pos >= playable.length) {
      await pause();
      return;
    }
    final sentenceEnd = playable[pos].endTime;
    if (state.position >= sentenceEnd) {
      await pause();
      return;
    }
    _pauseAfterPosition = sentenceEnd;
  }

  Future<void> seekAbsolute(Duration target) async {
    _sentenceResumePosition = null;
    if (target < Duration.zero) target = Duration.zero;
    final duration = state.duration;
    if (duration != null && target > duration) target = duration;
    final wasPlaying = state.isPlaying;
    _playbackGen++;
    _clearPlaybackInterval();
    _activeSentenceDrivenPlayback = false;
    _awaitingReplayFromStart = false;
    _pauseAfterPosition = null;
    _pendingFullSentenceFocus = null;

    if (state.sentences.isNotEmpty) {
      final idx = _nearestSentenceIndex(target);
      if (state.playlistMode == PlaylistMode.bookmarks) {
        final playable = _playable;
        if (playable.isEmpty) return;
        var pos = playable.indexWhere((s) => s.index == idx);
        if (pos < 0) {
          final closest = SentenceTracker.findClosestBookmark(playable, target);
          pos = closest == null
              ? 0
              : playable.indexWhere((s) => s.index == closest);
        }
        final safePos = pos < 0 ? 0 : pos;
        final selected = playable[safePos];
        target = selected.startTime;
        state = state.copyWith(
          currentBookmarkIndex: selected.index,
          lastPlayedBookmarkIndex: selected.index,
          requestSentenceFocus: true,
          sentenceFocusReason: SentenceFocusReason.navigation,
        );
      } else if (idx >= 0) {
        state = state.copyWith(
          currentFullIndex: idx,
          lastPlayedFullIndex: idx,
          requestSentenceFocus: true,
          sentenceFocusReason: SentenceFocusReason.navigation,
        );
      }
    }

    await _engine.seek(target);
    _resetGaplessStatsPosition(_engine.currentPosition);
    await _pausePlaying();
    state = state.copyWith(position: target, sentenceRepeatsDone: 0);
    if (wasPlaying) unawaited(play(resetWholeLoops: false));
  }

  Future<void> seekRelative(Duration delta) async {
    await seekAbsolute(state.position + delta);
  }

  Future<void> previousSentence() async {
    if (state.sentences.isEmpty) {
      await seekRelative(const Duration(seconds: -10));
      return;
    }
    final playable = _playable;
    if (playable.isEmpty) return;
    final current = _currentPos ?? 0;
    if (current <= 0) return;
    await _moveToPosition(current - 1);
  }

  Future<void> nextSentence() async {
    if (state.sentences.isEmpty) {
      await seekRelative(const Duration(seconds: 10));
      return;
    }
    final playable = _playable;
    if (playable.isEmpty) return;
    final current = _currentPos ?? 0;
    if (current >= playable.length - 1) return;
    await _moveToPosition(current + 1);
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= state.sentences.length) return;
    _sentenceResumePosition = null;
    final sentence = state.sentences[index];
    final wasPlaying = state.isPlaying;
    AppLogger.log(
      'MediaPlayback',
      'sentence selection begin source=full from=${state.currentFullIndex} '
          'to=$index range=${sentence.startTime.inMilliseconds}-'
          '${sentence.endTime.inMilliseconds}ms autoPlay=$autoPlay '
          'wasPlaying=$wasPlaying enginePosition='
          '${_engine.currentPosition.inMilliseconds}ms '
          'backendPlaying=${_engine.isPlaying}',
    );
    _pendingFullSentenceFocus = autoPlay && !_usesSentenceDrivenPlayback
        ? (index: index, releaseAt: _focusHoldReleasePosition(sentence))
        : null;
    state = state.copyWith(
      currentFullIndex: index,
      lastPlayedFullIndex: index,
      requestSentenceFocus: true,
      sentenceFocusReason: SentenceFocusReason.navigation,
    );
    await _alignEngineToCurrent();
    AppLogger.log(
      'MediaPlayback',
      'sentence selection aligned source=full index=$index '
          'position=${state.position.inMilliseconds}ms '
          'enginePosition=${_engine.currentPosition.inMilliseconds}ms '
          'backendPlaying=${_engine.isPlaying} autoPlay=$autoPlay',
    );
    if (autoPlay) {
      AppLogger.log(
        'MediaPlayback',
        'sentence selection requests playback source=full index=$index '
            'resetWholeLoops=${!wasPlaying}',
      );
      unawaited(play(resetWholeLoops: !wasPlaying));
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= state.sentences.length) return;
    if (!state.bookmarkedIndices.contains(index)) return;
    _sentenceResumePosition = null;
    _pendingFullSentenceFocus = null;
    final wasPlaying = state.isPlaying;
    AppLogger.log(
      'MediaPlayback',
      'sentence selection begin source=bookmarks '
          'from=${state.currentBookmarkIndex} to=$index '
          'autoPlay=$autoPlay wasPlaying=$wasPlaying',
    );
    state = state.copyWith(
      currentBookmarkIndex: index,
      lastPlayedBookmarkIndex: index,
      requestSentenceFocus: true,
      sentenceFocusReason: SentenceFocusReason.navigation,
    );
    await _alignEngineToCurrent();
    AppLogger.log(
      'MediaPlayback',
      'sentence selection aligned source=bookmarks index=$index '
          'position=${state.position.inMilliseconds}ms autoPlay=$autoPlay',
    );
    if (autoPlay) {
      AppLogger.log(
        'MediaPlayback',
        'sentence selection requests playback source=bookmarks index=$index '
            'resetWholeLoops=${!wasPlaying}',
      );
      unawaited(play(resetWholeLoops: !wasPlaying));
    }
  }

  /// 进入句子讲解前暂停媒体，并记录暂停后的精确位置。
  ///
  /// 讲解页展示点选句子，但导航本身不改变随心听焦点或 seek；否则共享位置流会
  /// 把句首 seek 解析成第一个词的逐词高亮。
  Future<Duration> prepareSentenceDetail() async {
    AppLogger.log(
      'MediaPlayback',
      'sentence detail prepare media=${state.audioItem?.id}',
    );
    await pause();
    final position = _engine.currentPosition;
    state = state.copyWith(position: position);
    AppLogger.log(
      'MediaPlayback',
      'sentence detail paused position=${position.inMilliseconds}ms',
    );
    return position;
  }

  /// 从句子讲解返回后同步收藏，并在讲解播放改变位置时恢复原播放位置。
  ///
  /// 只查看讲解时不 seek；返回也不根据当前句焦点重新对齐媒体位置。
  Future<void> restoreAfterSentenceDetail(Duration returnPosition) async {
    final item = state.audioItem;
    if (item == null) return;
    AppLogger.log(
      'MediaPlayback',
      'sentence detail restore media=${item.id} '
          'position=${returnPosition.inMilliseconds}ms',
    );

    // 讲解页可能使用共享媒体引擎播放句子或意群；先暂停并使其在途回调失效。
    await pause();
    final currentPosition = _engine.currentPosition;
    if (currentPosition != returnPosition) {
      await _engine.seek(returnPosition);
      final restoredPosition = _engine.currentPosition;
      _resetGaplessStatsPosition(restoredPosition);
      state = state.copyWith(position: restoredPosition);
    } else if (state.position != currentPosition) {
      state = state.copyWith(position: currentPosition);
    }

    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      item.id,
      dao: ref.read(bookmarkDaoProvider),
    );
    final sentences = List<Sentence>.from(state.sentences);
    BookmarkManager.updateSentenceBookmarkStatus(sentences, bookmarkedIndices);

    final currentBookmarkIndex = state.currentBookmarkIndex;
    final currentBookmarkRemoved =
        state.playlistMode == PlaylistMode.bookmarks &&
        !bookmarkedIndices.contains(currentBookmarkIndex);
    final bookmarksBecameEmpty =
        state.playlistMode == PlaylistMode.bookmarks &&
        bookmarkedIndices.isEmpty;
    state = state.copyWith(
      sentences: sentences,
      bookmarkedIndices: bookmarkedIndices,
      playlistMode: bookmarksBecameEmpty ? PlaylistMode.full : null,
      currentFullIndex: bookmarksBecameEmpty
          ? currentBookmarkIndex ?? state.currentFullIndex ?? 0
          : null,
      clearCurrentBookmarkIndex: currentBookmarkRemoved,
      requestSentenceFocus: bookmarksBecameEmpty || currentBookmarkRemoved,
      sentenceFocusReason: SentenceFocusReason.immediate,
    );
    _ensureValidIndex();
  }

  Future<void> _moveToPosition(int pos) async {
    _sentenceResumePosition = null;
    final playable = _playable;
    if (pos < 0 || pos >= playable.length) return;
    _pendingFullSentenceFocus = null;
    final wasPlaying = state.isPlaying;
    final selected = playable[pos];
    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: selected.index,
        lastPlayedBookmarkIndex: selected.index,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.navigation,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: selected.index,
        lastPlayedFullIndex: selected.index,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.navigation,
      );
    }
    await _alignEngineToCurrent();
    if (wasPlaying) unawaited(play(resetWholeLoops: false));
  }

  Future<void> toggleBookmark(int index) async {
    final item = state.audioItem;
    if (item == null || index < 0 || index >= state.sentences.length) return;
    final (
      isRemoving,
      indicesToRemove,
      replacementIndex,
    ) = BookmarkManager.toggleBookmark(
      index,
      state.sentences,
      state.bookmarkedIndices,
      state.playlistMode == PlaylistMode.bookmarks,
    );

    final newBookmarks = Set<int>.from(state.bookmarkedIndices);
    final newSentences = List<Sentence>.from(state.sentences);
    if (isRemoving) {
      final toRemove = indicesToRemove.isEmpty ? {index} : indicesToRemove;
      for (final idx in toRemove) {
        newBookmarks.remove(idx);
        if (idx >= 0 && idx < newSentences.length) {
          newSentences[idx] = newSentences[idx].copyWith(isBookmarked: false);
        }
      }
      if (state.playlistMode == PlaylistMode.bookmarks) {
        if (newBookmarks.isEmpty) {
          // 收藏播放列表不保留空死端：取消最后一条后回到
          // 全文，并保持刚操作的句子为当前焦点。
          state = state.copyWith(
            playlistMode: PlaylistMode.full,
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentFullIndex: index,
            clearCurrentBookmarkIndex: true,
            requestSentenceFocus: true,
            sentenceFocusReason: SentenceFocusReason.immediate,
          );
          await pause();
        } else if (replacementIndex != null &&
            newBookmarks.contains(replacementIndex)) {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentBookmarkIndex: replacementIndex,
            requestSentenceFocus: true,
            sentenceFocusReason: SentenceFocusReason.immediate,
          );
        } else {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            clearCurrentBookmarkIndex: true,
          );
          await pause();
        }
      } else {
        state = state.copyWith(
          bookmarkedIndices: newBookmarks,
          sentences: newSentences,
        );
      }
      await ref
          .read(favoriteSentenceLifecycleProvider)
          .remove(item.id, toRemove);
    } else {
      newBookmarks.add(index);
      newSentences[index] = newSentences[index].copyWith(isBookmarked: true);
      state = state.copyWith(
        bookmarkedIndices: newBookmarks,
        sentences: newSentences,
      );
      await ref
          .read(favoriteSentenceLifecycleProvider)
          .save(item.id, state.sentences[index]);
    }
  }

  Future<void> updateSettings(PlaybackSettings next) async {
    final wasSentenceDriven = _usesSentenceDrivenPlayback;
    final willUseSentenceDriven =
        state.playlistMode == PlaylistMode.bookmarks || next.loopSentence;
    state = state.copyWith(settings: next);

    // 单句循环决定底层使用逐句区间播放还是整篇连续播放。播放中切换时必须立刻
    // 失效旧协程并由新模型接管；否则只更新设置会一直等到暂停后再次 play 才生效。
    // 收藏列表始终逐句播放，切换单句循环开关不应打断它。
    // 播放状态流回调可能晚于底层 play；切换循环时以 MediaEngine 的 backend 真值
    // 判断是否需要接管，避免 provider state 尚未回写而丢掉用户的设置变更。
    // provider 状态先于底层 transport 更新；切换发生在 play/区间播放建立期间时，
    // 仅检查 backend 会漏掉这次接管，导致设置变更要等下一次手动播放才生效。
    if ((state.isPlaying || _engine.isPlaying) &&
        wasSentenceDriven != willUseSentenceDriven) {
      if (willUseSentenceDriven) {
        // 用户开启单句循环时明确要求立即从当前句句首重播。
        _launchSentenceDriven(
          resetWholeLoops: false,
          resetSentenceRepeats: true,
        );
      } else {
        // 用户关闭单句循环时从媒体当前真实位置无缝恢复整篇连续播放。旧逐句会话可能
        // 已排队句首 seek，因此新会话需重新对齐当前位置，避免迟到命令将进度回跳。
        // _startWholeDriven 会持续到媒体自然结束；设置更新不能等待该长生命周期会话。
        unawaited(
          _startWholeDriven(
            resumePosition: _engine.currentPosition,
            resetWholeLoops: false,
          ),
        );
      }
    }

    await _applyTransportSpeed();
    await StorageService.saveSettings(
      ListeningPracticeSettingsStore(
        full: state.fullSettings,
        bookmark: state.bookmarkSettings,
      ),
    );
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (state.playlistMode == mode || _changingPlaylistMode) return;
    if (mode == PlaylistMode.bookmarks && state.bookmarkedSentences.isEmpty) {
      return;
    }
    _changingPlaylistMode = true;
    try {
      await pause();
      if (_released) return;
      state = state.copyWith(playlistMode: mode);
      _ensureValidIndex();
      await _applyTransportSpeed();
      await _alignEngineToCurrent();
    } finally {
      _changingPlaylistMode = false;
    }
  }

  Future<void> setVisualTrackVisible(bool visible) async {
    AppLogger.log('MediaPlayback', 'visual track visible=$visible');
    state = state.copyWith(
      visualTrackVisible: visible,
      visualTrackExpanded: visible ? state.visualTrackExpanded : false,
    );
    await _engine.setVideoTrackEnabled(visible);
  }

  Future<void> setVisualTrackExpanded(bool expanded) async {
    AppLogger.log('MediaPlayback', 'visual track expanded=$expanded');
    if (expanded && !state.visualTrackVisible) {
      await setVisualTrackVisible(true);
    }
    state = state.copyWith(visualTrackExpanded: expanded);
  }

  Future<void> setVideoSubtitleVisible(bool visible) async {
    AppLogger.log('MediaPlayback', 'subtitle track visible=$visible');
    state = state.copyWith(videoSubtitleVisible: visible);
    await _engine.setSubtitleTrackData(visible ? _videoSubtitleSrt : null);
  }

  Future<String?> _loadSubtitleTrackData(AudioItem item) async {
    if (!item.hasTranscript) return null;
    try {
      final srt = await ref
          .read(audioItemDaoProvider)
          .getTranscriptSrt(item.id);
      if (srt != null && srt.trim().isNotEmpty) return srt;
    } catch (e) {
      AppLogger.log('MediaPlayback', '⚠ load video subtitle track failed: $e');
    }
    return null;
  }

  Future<void> handleLifecycleHidden() async {
    await _engine.setVideoTrackEnabled(false);
  }

  Future<void> handleLifecycleResumed() async {
    if (state.visualTrackVisible) await _engine.setVideoTrackEnabled(true);
  }

  /// 保存当前播放断点；自然播放完成时可显式写入 0，避免下次恢复到终点。
  Future<void> saveCurrentPlaybackState({
    bool silent = false,
    Duration? position,
  }) async {
    final item = state.audioItem;
    if (item == null) return;
    final dao = _playbackStateDaoCache;
    if (dao == null) return;
    await PlaybackStateStorage.savePlaybackState(
      item,
      position ?? state.position,
      ListeningPracticeState(playlistMode: state.playlistMode),
      dao: dao,
      silent: silent,
    );
  }

  /// 取消尚未完成的加载，不保存尚未开放给用户的临时播放位置。
  Future<void> cancelLoad() async {
    await _releaseMedia(saveProgress: false);
  }

  Future<void>? _releaseInFlight;

  Future<void> releaseFromScreen({int? studyPageGeneration}) async {
    if (studyPageGeneration != null &&
        _activeStudyPageGeneration != studyPageGeneration) {
      return;
    }
    await _releaseMedia(
      saveProgress: _loadReady,
      shouldEndStudyPage: true,
      studyPageGeneration: studyPageGeneration,
    );
  }

  Future<void> _releaseMedia({
    required bool saveProgress,
    bool shouldEndStudyPage = false,
    int? studyPageGeneration,
  }) async {
    final existing = _releaseInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final release = _releaseFromScreen(
      saveProgress: saveProgress,
      shouldEndStudyPage: shouldEndStudyPage,
      studyPageGeneration: studyPageGeneration,
    );
    _releaseInFlight = release;
    try {
      await release;
    } finally {
      if (identical(_releaseInFlight, release)) {
        _releaseInFlight = null;
      }
    }
  }

  /// 统一释放页面拥有的媒体资源；页面退出还会先暂停并结束学习计时。
  Future<void> _releaseFromScreen({
    required bool saveProgress,
    required bool shouldEndStudyPage,
    int? studyPageGeneration,
  }) async {
    if (studyPageGeneration != null &&
        _activeStudyPageGeneration != studyPageGeneration) {
      return;
    }
    final engine = _engineCache;
    final preserveStartCheckpoint = _awaitingReplayFromStart;
    Object? releaseError;
    // 先使待续播协程失效，避免等待 backend 暂停期间旧间隔到期并重新起播。
    _playbackGen++;
    _clearPlaybackInterval();
    engine?.setTransportHandlers(onPlay: null, onPause: null);
    engine?.setSkipHandlers();
    engine?.setSeekHandlers();
    try {
      await engine?.pause();
    } catch (error) {
      releaseError = error;
      AppLogger.log('MediaPlayback', 'release pause failed: $error');
    }
    await _pausePlaying();
    if (studyPageGeneration != null &&
        _activeStudyPageGeneration != studyPageGeneration) {
      // 页面代际已变化时，仅恢复新页面仍在使用的锁屏命令，不执行旧页面解绑。
      if (_loadReady) {
        engine?.setTransportHandlers(onPlay: play, onPause: pause);
        if (state.hasSentences) {
          engine?.setSkipHandlers(
            onPrevious: previousSentence,
            onNext: nextSentence,
          );
        } else {
          engine?.setSeekHandlers(
            onRewind: () => seekRelative(const Duration(seconds: -10)),
            onFastForward: () => seekRelative(const Duration(seconds: 10)),
          );
        }
      }
      return;
    }
    _loadGeneration++;
    _released = true;
    _loadReady = false;
    _loadedResourceGeneration = null;
    _positionUpdatesEnabled = false;
    _activeSentenceDrivenPlayback = false;
    _pauseAfterPosition = null;
    if (engine != null) _recordGaplessStatsThrough(engine.currentPosition);
    // 暂停完成后读取 backend 实时位置，避免 position stream 尚未刷新时使用
    // 落后的界面状态覆盖更精确的断点。
    final checkpointPosition = engine?.currentPosition ?? state.position;
    if (shouldEndStudyPage) {
      if (studyPageGeneration != null) {
        await endStudyPage(studyPageGeneration);
      } else {
        await _endActiveStudyPage();
      }
    }
    try {
      await _senseGroupRangePlayback?.cancel();
      _senseGroupRangePlayback = null;
      await _positionSub?.cancel();
      await _playingSub?.cancel();
      await _landscapeVideoSub?.cancel();
      await _videoAspectRatioSub?.cancel();
    } catch (error) {
      releaseError ??= error;
      AppLogger.log('MediaPlayback', 'release subscriptions failed: $error');
    }
    // 自然完成后 UI 可继续停在终点展示完成态，但持久化断点必须保持为开头；
    // 否则退出页面会用 state.position 的终点值覆盖刚写入的 0:00。持久化失败
    // 不能阻止 engine detach，否则页面 owner 已销毁而 native Player 仍在工作。
    if (saveProgress) {
      try {
        await saveCurrentPlaybackState(
          silent: true,
          position: preserveStartCheckpoint
              ? Duration.zero
              : checkpointPosition,
        );
      } catch (error) {
        releaseError ??= error;
        AppLogger.log('MediaPlayback', 'release progress save failed: $error');
      }
    }
    try {
      await engine?.releaseFromScreen();
    } catch (error) {
      releaseError ??= error;
      AppLogger.log('MediaPlayback', 'release engine detach failed: $error');
    } finally {
      await _stopPlaying();
      state = const MediaPlaybackState();
    }
    final error = releaseError;
    if (error != null) throw error;
  }

  Future<void> _applyTransportSpeed() async {
    await _engine.setSpeed(state.settings.playbackSpeed);
  }

  Future<void> _alignEngineToCurrent() async {
    _playbackGen++;
    _activeSentenceDrivenPlayback = false;
    _awaitingReplayFromStart = false;
    _pauseAfterPosition = null;
    await _pausePlaying();
    state = state.copyWith(sentenceRepeatsDone: 0);
    final pos = _currentPos;
    if (pos != null && pos >= 0 && pos < _playable.length) {
      await _engine.seek(_playable[pos].startTime);
      state = state.copyWith(position: _playable[pos].startTime);
    }
    _resetGaplessStatsPosition(_engine.currentPosition);
    _playbackSessionId = _engine.currentSessionId;
  }

  Duration _focusHoldReleasePosition(Sentence sentence) {
    final toleranceEnd =
        sentence.startTime + wordHighlightSeekRollbackTolerance;
    return toleranceEnd < sentence.endTime ? toleranceEnd : sentence.endTime;
  }

  bool _shouldRestartWhole() => _awaitingReplayFromStart || _isAtEnd();

  bool _isAtEnd() {
    final duration = state.duration;
    if (duration == null || duration <= Duration.zero) return false;
    return state.position >= duration - const Duration(milliseconds: 250);
  }

  Future<void> _restartFromPlayableBeginning() async {
    final playable = _playable;
    if (playable.isEmpty) {
      await _startWholeDriven(startAtBeginning: true, resetWholeLoops: true);
      return;
    }
    final first = playable.first;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: first.index,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.immediate,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: first.index,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.immediate,
      );
    }
    await _alignEngineToCurrent();
    await play();
  }

  Future<void> _startWholeDriven({
    int? startPos,
    Duration? resumePosition,
    bool startAtBeginning = false,
    bool resetWholeLoops = false,
  }) async {
    final gen = ++_playbackGen;
    _clearPlaybackInterval();
    final wasSentenceDriven = _activeSentenceDrivenPlayback;
    _activeSentenceDrivenPlayback = false;
    _awaitingReplayFromStart = false;
    if (resetWholeLoops) {
      state = state.copyWith(wholeLoopsDone: 0, sentenceRepeatsDone: 0);
    }
    _playbackSessionId = _engine.newSession();
    if (wasSentenceDriven) {
      // 区间播放可能仍在等待结束；先取消其迟到的 pause/完成回调，避免切换到整篇
      // 播放后旧协程把新的播放状态改回暂停。
      await _engine.cancelActiveRange(reason: 'switch-to-whole-playback');
    }
    AppLogger.log(
      'MediaPlayback',
      'start whole: gen=$gen session=$_playbackSessionId',
    );
    if (startAtBeginning) {
      await _engine.seek(Duration.zero);
      state = state.copyWith(position: Duration.zero);
    } else if (resumePosition != null) {
      await _engine.seek(resumePosition);
      state = state.copyWith(position: resumePosition);
    } else if (startPos != null && state.sentences.isNotEmpty) {
      final playable = _playable;
      if (startPos >= 0 && startPos < playable.length) {
        final target = playable[startPos];
        await _engine.seek(target.startTime);
        state = state.copyWith(position: target.startTime);
      }
    }
    _resetGaplessStatsPosition(_engine.currentPosition);
    _setPlaying(true);
    AppLogger.log(
      'MediaPlayback',
      'start whole playToEnd active=${_engine.isActiveSession(_playbackSessionId)}',
    );
    while (gen == _playbackGen && _engine.isActiveSession(_playbackSessionId)) {
      await _engine.playToEnd(_playbackSessionId);
      if (gen != _playbackGen || !_engine.isActiveSession(_playbackSessionId)) {
        return;
      }
      _recordGaplessStatsThrough(state.duration ?? _engine.currentPosition);
      final done = state.wholeLoopsDone + 1;
      state = state.copyWith(wholeLoopsDone: done);
      final settings = state.settings;
      if (!shouldLoopWhole(settings.loopWhole, settings.wholeLoopCount, done)) {
        _awaitingReplayFromStart = true;
        await _stopPlaying();
        // 已自然播完时断点应回到开头，不能在退出后恢复为 -0:00 的终点状态。
        await saveCurrentPlaybackState(silent: true, position: Duration.zero);
        await _engine.pauseKeepSession();
        return;
      }
      _autoSaveProgress();
      await _delay(settings.wholeInterval, playbackGeneration: gen);
      await _engine.seek(Duration.zero);
      _resetGaplessStatsPosition(_engine.currentPosition);
      state = state.copyWith(position: Duration.zero);
    }
  }

  /// 按播放位置查找最应该高亮的全文字幕。
  ///
  /// 播放器位置是唯一真实进度：命中字幕区间时高亮该句，落在无字幕空白区时只选择
  /// 距离最近的句子，不反向 seek 播放器，避免普通播放被字幕时间轴吸附。
  int _nearestSentenceIndex(Duration position) {
    final sentences = state.sentences;
    if (sentences.isEmpty) return -1;
    var bestIndex = sentences.first.index;
    var bestDistance = _distanceToSentence(position, sentences.first);
    for (final sentence in sentences.skip(1)) {
      final distance = _distanceToSentence(position, sentence);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = sentence.index;
      }
    }
    return bestIndex;
  }

  /// 书签模式下仅在书签句集合内查找最近焦点，播放进度本身不被吸附。
  int? _nearestBookmarkIndex(Duration position) {
    final bookmarks = state.bookmarkedSentences;
    if (bookmarks.isEmpty) return null;
    var best = bookmarks.first;
    var bestDistance = _distanceToSentence(position, best);
    for (final sentence in bookmarks.skip(1)) {
      final distance = _distanceToSentence(position, sentence);
      if (distance < bestDistance) {
        best = sentence;
        bestDistance = distance;
      }
    }
    return best.index;
  }

  Duration _distanceToSentence(Duration position, Sentence sentence) {
    if (position < sentence.startTime) return sentence.startTime - position;
    if (position > sentence.endTime) return position - sentence.endTime;
    return Duration.zero;
  }

  void _launchSentenceDriven({
    required bool resetWholeLoops,
    required bool resetSentenceRepeats,
    Duration? startAt,
  }) {
    final gen = ++_playbackGen;
    _clearPlaybackInterval();
    _activeSentenceDrivenPlayback = true;
    _awaitingReplayFromStart = false;
    _playbackSessionId = _engine.newSession();
    state = state.copyWith(
      wholeLoopsDone: resetWholeLoops ? 0 : state.wholeLoopsDone,
      sentenceRepeatsDone: resetSentenceRepeats ? 0 : state.sentenceRepeatsDone,
    );
    final position = _currentPos;
    final playable = _playable;
    final currentSentence =
        position != null && position >= 0 && position < playable.length
        ? playable[position]
        : null;
    AppLogger.log(
      'MediaPlayback',
      'sentence playback start item=${state.audioItem?.id} '
          'sentence=${currentSentence?.index} '
          'range=${currentSentence?.startTime.inMilliseconds}-'
          '${currentSentence?.endTime.inMilliseconds}ms '
          'generation=$gen session=$_playbackSessionId',
    );
    _setPlaying(true);
    unawaited(_playSentenceDriven(gen, startAt: startAt));
  }

  Future<void> _playSentenceDriven(int gen, {Duration? startAt}) async {
    var pos = _currentPos ?? 0;
    var startFromPosition = startAt;
    while (gen == _playbackGen) {
      final playable = _playable;
      if (playable.isEmpty || pos < 0 || pos >= playable.length) {
        await _stopPlaying();
        return;
      }
      final sentence = playable[pos];
      _setCurrentFromSentence(sentence);
      AppLogger.log(
        'MediaPlayback',
        'sentence range dispatch begin item=${state.audioItem?.id} '
            'sentence=${sentence.index} '
            'range=${sentence.startTime.inMilliseconds}-'
            '${sentence.endTime.inMilliseconds}ms generation=$gen '
            'session=$_playbackSessionId',
      );
      final result = await _engine.playRange(
        startFromPosition ?? sentence.startTime,
        sentence.endTime,
        speed: state.settings.playbackSpeed,
        onRangeReady: () => AppLogger.log(
          'MediaPlayback',
          'sentence backend play begin item=${state.audioItem?.id} '
              'sentence=${sentence.index} '
              'range=${sentence.startTime.inMilliseconds}-'
              '${sentence.endTime.inMilliseconds}ms generation=$gen '
              'session=$_playbackSessionId',
        ),
        sessionId: _playbackSessionId,
      );
      AppLogger.log(
        'MediaPlayback',
        'sentence range dispatch end item=${state.audioItem?.id} '
            'sentence=${sentence.index} result=$result '
            'generationCurrent=${gen == _playbackGen} '
            'session=$_playbackSessionId',
      );
      if (gen != _playbackGen || result != SentencePlaybackResult.completed) {
        return;
      }
      startFromPosition = null;
      _recordCompletedSentenceStatistics(sentence);
      if (_pauseAfterPosition != null) {
        await pause();
        return;
      }

      final repeats = state.sentenceRepeatsDone + 1;
      state = state.copyWith(sentenceRepeatsDone: repeats);

      final settings = state.settings;
      final action = decideNext(
        loopSentence: settings.loopSentence,
        sentenceLoopCount: settings.sentenceLoopCount,
        sentenceInterval: settings.sentenceInterval,
        loopWhole: settings.loopWhole,
        wholeLoopCount: settings.wholeLoopCount,
        wholeInterval: settings.wholeInterval,
        sentenceRepeatsDone: repeats,
        wholeLoopsDone: state.wholeLoopsDone,
        currentPos: pos,
        playableCount: playable.length,
      );
      switch (action) {
        case StopPlayback():
          _awaitingReplayFromStart = true;
          _activeSentenceDrivenPlayback = false;
          await _stopPlaying();
          // 单句驱动走到播放列表末尾同样属于自然完成，清除终点断点。
          await saveCurrentPlaybackState(silent: true, position: Duration.zero);
          await _engine.pauseKeepSession();
          return;
        case ReplayCurrent(:final pauseBefore):
          _autoSaveProgress();
          await _delay(pauseBefore, playbackGeneration: gen);
        case GoToPosition(:final position, :final pauseBefore):
          final loopedWhole = pos >= playable.length - 1 && position == 0;
          await _delay(pauseBefore, playbackGeneration: gen);
          pos = position;
          state = state.copyWith(
            sentenceRepeatsDone: 0,
            wholeLoopsDone: loopedWhole
                ? state.wholeLoopsDone + 1
                : state.wholeLoopsDone,
          );
          _autoSaveProgress();
      }
    }
  }

  /// 仅在按句区间播放自然完成后写入输入统计；连续整篇播放的总时长由计时器负责。
  ///
  /// 不等待后台数据库写入，避免统计延迟影响媒体播放、循环或切句。
  void _recordCompletedSentenceStatistics(Sentence sentence) {
    ref
        .read(studyTimeServiceProvider)
        .submitSentencePlayback(
          duration: sentence.duration,
          text: sentence.text,
          stage: StudyStage.freePlayer,
          recordInputDuration: false,
        );
  }

  void _setCurrentFromSentence(Sentence sentence) {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final focusChanged = state.currentBookmarkIndex != sentence.index;
      state = state.copyWith(
        currentBookmarkIndex: sentence.index,
        lastPlayedBookmarkIndex: sentence.index,
        position: sentence.startTime,
        requestSentenceFocus: focusChanged,
        sentenceFocusReason: focusChanged ? SentenceFocusReason.playback : null,
      );
      return;
    }
    final focusChanged = state.currentFullIndex != sentence.index;
    state = state.copyWith(
      currentFullIndex: sentence.index,
      lastPlayedFullIndex: sentence.index,
      position: sentence.startTime,
      requestSentenceFocus: focusChanged,
      sentenceFocusReason: focusChanged ? SentenceFocusReason.playback : null,
    );
  }

  void _ensureValidIndex() {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(
          currentBookmarkIndex: bookmarked.first.index,
          requestSentenceFocus: true,
          sentenceFocusReason: SentenceFocusReason.immediate,
        );
      }
      return;
    }
    if (state.sentences.isEmpty) return;
    final current = state.currentFullIndex;
    if (current == null || current < 0 || current >= state.sentences.length) {
      state = state.copyWith(
        currentFullIndex: 0,
        requestSentenceFocus: true,
        sentenceFocusReason: SentenceFocusReason.immediate,
      );
    }
  }

  Future<void> _delay(
    Duration duration, {
    required int playbackGeneration,
  }) async {
    if (duration <= Duration.zero || playbackGeneration != _playbackGen) {
      return;
    }
    _beginPlaybackInterval(playbackGeneration);
    await Future.delayed(duration);
  }

  void _autoSaveProgress() {
    if (_autoSaving || state.audioItem == null) return;
    _autoSaving = true;
    saveCurrentPlaybackState(silent: true)
        .catchError(
          (Object e) =>
              AppLogger.log('MediaPlayback', '⚠ auto-save failed: $e'),
        )
        .whenComplete(() => _autoSaving = false);
  }
}

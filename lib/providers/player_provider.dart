import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/sentence.dart';
import '../models/playback_settings.dart';
import '../services/subtitle_parser.dart';
import '../services/storage_service.dart';

enum PlaylistMode { full, bookmarks }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  AudioItem? _currentAudioItem;
  List<Sentence> _sentences = [];
  int? _currentFullIndex;
  int? _currentBookmarkIndex;
  PlaybackSettings _settings = PlaybackSettings();
  Set<int> _bookmarkedIndices = {};

  bool _isLoading = false;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;
  bool _autoScrollEnabled = true;
  PlaylistMode _playlistMode = PlaylistMode.full;

  // 播放控制 - 简化的状态管理
  int _playbackSessionId = 0; // 用于取消旧的播放会话
  int? _itemPlaybackSentenceIndex; // 标记哪个句子正在通过item按钮播放
  bool _isMainPlaybackPlaying = false; // 标记主播放控制的播放状态

  // 进度条相关 - 用于显示绝对位置
  Duration? _fullDuration; // 完整音频时长
  Duration _clipStart = Duration.zero; // 当前 clip 的起始位置

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  AudioItem? get currentAudioItem => _currentAudioItem;
  List<Sentence> get sentences => _sentences;
  List<Sentence> get bookmarkedSentences =>
      _sentences.where((s) => _bookmarkedIndices.contains(s.index)).toList();
  int? get currentFullIndex => _currentFullIndex;
  int? get currentBookmarkIndex => _currentBookmarkIndex;
  Sentence? get currentSentence =>
      _currentFullIndex != null && _currentFullIndex! < _sentences.length
      ? _sentences[_currentFullIndex!]
      : null;
  PlaybackSettings get settings => _settings;
  Set<int> get bookmarkedIndices => _bookmarkedIndices;
  bool get isLoading => _isLoading;
  bool get isPlaying => _audioPlayer.playing;
  bool get isMainPlaybackPlaying => _isMainPlaybackPlaying; // 主播放控制的播放状态
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _fullDuration; // 返回完整音频时长
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;
  bool get autoScrollEnabled => _autoScrollEnabled;
  int? get itemPlaybackSentenceIndex => _itemPlaybackSentenceIndex;

  // 绝对位置流：将 clip 相对位置映射到完整音频的绝对位置
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((relativePosition) {
        return _clipStart + relativePosition;
      });

  void setPlaylistMode(PlaylistMode mode) {
    _playlistMode = mode;
  }

  PlayerProvider() {
    _loadSettings();
    _setupListeners();
  }

  Future<void> _loadSettings() async {
    _settings = await StorageService.loadSettings();
    notifyListeners();
  }

  void _setupListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen(
      _onPositionChanged,
    );
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      _onPlayerStateChanged,
    );
  }

  void _onPositionChanged(Duration position) {
    final absolute = _clipStart + position;
    _updateCurrentSentence(absolute);
  }

  void _onPlayerStateChanged(PlayerState state) {
    // 处理播放完成（用于Continuous模式的音频循环）
    if (state.processingState == ProcessingState.completed) {
      _handlePlaybackCompleted();
    }
    notifyListeners();
  }

  /// 处理Continuous模式下的播放完成
  void _handlePlaybackCompleted() {
    if (_isDisposed) return;

    // 只在Continuous模式下处理音频循环
    if (!_shouldUseContinuousMode()) return;

    if (_settings.loopAudioEnabled) {
      final shouldLoop = _settings.loopAudio == 0 || true; // 简单处理
      if (shouldLoop && _sentences.isNotEmpty) {
        // 重新从头播放
        Future.microtask(() async {
          if (_playlistMode == PlaylistMode.bookmarks) {
            final bookmarked = bookmarkedSentences;
            if (bookmarked.isNotEmpty) {
              _currentBookmarkIndex = bookmarked.first.index;
            }
          } else {
            _currentFullIndex = 0;
          }
          notifyListeners();
          await _playContinuous();
        });
      } else {
        // 不循环，清除主播放状态
        print("1");
        _isMainPlaybackPlaying = false;
        notifyListeners();
      }
    } else {
      // 不循环，清除主播放状态
      print("2");
      _isMainPlaybackPlaying = false;
      notifyListeners();
    }
  }

  void _updateCurrentSentence(Duration position) {
    if (_sentences.isEmpty) return;

    // 如果正在进行 item 播放，不要自动更新选中状态
    // 这样可以避免点击播放按钮时选中状态跳转
    if (_itemPlaybackSentenceIndex != null) return;

    final index = _sentences.indexWhere(
      (s) => position >= s.startTime && position < s.endTime,
    );

    if (index != -1) {
      if (_playlistMode == PlaylistMode.bookmarks) {
        if (_bookmarkedIndices.contains(index) &&
            index != _currentBookmarkIndex) {
          _currentBookmarkIndex = index;
          notifyListeners();
        }
      } else {
        if (index != _currentFullIndex) {
          _currentFullIndex = index;
          notifyListeners();
        }
      }
    }
  }

  Future<void> loadAudio(AudioItem audioItem) async {
    if (_currentAudioItem?.id == audioItem.id) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Stop current playback
      await stop();

      _currentAudioItem = audioItem;
      _sentences = [];
      _currentFullIndex = null;
      _currentBookmarkIndex = null;

      // Load audio
      try {
        await _audioPlayer.setFilePath(audioItem.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);

        // 获取完整音频时长
        _fullDuration = _audioPlayer.duration;
        // 等待时长加载完成
        if (_fullDuration == null) {
          await _audioPlayer.durationStream.first;
          _fullDuration = _audioPlayer.duration;
        }
        _clipStart = Duration.zero;
      } catch (e) {
        print('Error loading audio file: $e');
        _currentAudioItem = null;
        rethrow;
      }

      // Load transcript if available
      if (audioItem.hasTranscript) {
        try {
          _sentences = await SubtitleParser.parseSubtitle(
            audioItem.transcriptPath!,
          );
        } catch (e) {
          print('Error loading transcript: $e');
        }
      }

      // Load bookmarks
      try {
        _bookmarkedIndices = await StorageService.loadBookmarks(audioItem.id);
      } catch (e) {
        print('Error loading bookmarks: $e');
        _bookmarkedIndices = {};
      }

      //Auto-bookmark sentences wrapped in []
      for (var sentence in _sentences) {
        final text = sentence.text.trim();
        if (text.startsWith('[') && text.endsWith(']')) {
          _bookmarkedIndices.add(sentence.index);
        }
      }

      // Update sentence bookmark status
      for (var sentence in _sentences) {
        sentence.isBookmarked = _bookmarkedIndices.contains(sentence.index);
      }

      // Save auto-bookmarked sentences
      if (_bookmarkedIndices.isNotEmpty) {
        await StorageService.saveBookmarks(audioItem.id, _bookmarkedIndices);
      }

      // Set initial sentence to first sentence if available
      if (_sentences.isNotEmpty) {
        _currentFullIndex = 0;
        await _audioPlayer.seek(_sentences[0].startTime);
      }
    } catch (e) {
      print('Error loading audio: $e');
      _currentAudioItem = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // 播放逻辑：两种模式
  // ============================================================================

  /// 决定使用哪种播放模式
  bool _shouldUseContinuousMode() {
    // 书签模式：永远使用 Subtitle-Driven
    if (_playlistMode == PlaylistMode.bookmarks) return false;

    // 全文模式：autoPlayNextSentence开启 且 sentenceRepeat关闭 => Continuous
    if (_settings.autoPlayNextSentenceEnabled && !_settings.loopEnabled) {
      return true;
    }

    // 其他情况：Subtitle-Driven
    return false;
  }

  bool _is_active_session(int sid) => !_isDisposed && sid == _playbackSessionId;

  /// 主播放方法 - 整体播放模式
  Future<void> mainPlay() async {
    print('mainPlay');
    if (_currentAudioItem == null) return;

    // 停止item播放（如果正在播放）
    if (_itemPlaybackSentenceIndex != null) {
      _audioPlayer.pause();
      _playbackSessionId++; // 取消item播放会话
      _itemPlaybackSentenceIndex = null;
    }

    // 标记为主播放模式
    _isMainPlaybackPlaying = true;

    if (_sentences.isEmpty) {
      // 没有字幕，直接播放
      await _audioPlayer.play();
      return;
    }

    // 确保初始索引存在（只在真正需要时初始化，避免覆盖用户选择）
    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) {
        _isMainPlaybackPlaying = false;
        notifyListeners();
        return;
      }
      // 只有当前索引无效时才初始化
      if (_currentBookmarkIndex == null ||
          !_bookmarkedIndices.contains(_currentBookmarkIndex)) {
        _currentBookmarkIndex = bookmarked.first.index;
        notifyListeners();
      }
    } else {
      // Full Text 模式：只有当前索引无效时才初始化为0
      if (_currentFullIndex == null || _currentFullIndex! >= _sentences.length) {
        _currentFullIndex = 0;
        notifyListeners();
      }
    }

    if (_shouldUseContinuousMode()) {
      await _playContinuous();
    } else {
      // 准备播放列表和起始位置
      List<Sentence> playList;
      int startIndex;

      if (_playlistMode == PlaylistMode.bookmarks) {
        playList = bookmarkedSentences;
        // 找到当前书签的位置
        if (_currentBookmarkIndex != null) {
          startIndex = playList.indexWhere(
            (s) => s.index == _currentBookmarkIndex,
          );
          if (startIndex == -1) startIndex = 0;
        } else {
          startIndex = 0;
        }
      } else {
        playList = _sentences;
        startIndex = _currentFullIndex ?? 0;
      }

      await _playSubtitleDriven(playList, startIndex);
    }
  }

  /// 模式1：全程连续播放
  Future<void> _playContinuous() async {
    ++_playbackSessionId;

    // 确定要 seek 的目标位置
    final startIndex = _currentFullIndex;

    Duration? targetPosition;
    if (startIndex != null && startIndex < _sentences.length) {
      targetPosition = _sentences[startIndex].startTime;
    }

    // 只在有 clip 的情况下才清除，避免不必要的重置
    if (_clipStart != Duration.zero) {
      _clipStart = Duration.zero;
      await _audioPlayer.setClip(start: null, end: null);
    }

    // seek 到目标位置
    if (targetPosition != null) {
      await _audioPlayer.seek(targetPosition);
    }

    await _audioPlayer.play();
  }

  /// 模式2：Subtitle-Driven播放（异步for循环）
  /// [playList] 要播放的句子列表
  /// [startIndex] 起始位置（在playList中的索引）
  Future<void> _playSubtitleDriven(
    List<Sentence> playList,
    int startIndex,
  ) async {
    final sessionId = ++_playbackSessionId;

    if (playList.isEmpty) return;

    // 音频循环计数
    int audioLoopCount = 0;

    while (true) {
      // 检查音频循环条件
      if (audioLoopCount > 0) {
        if (!_settings.loopAudioEnabled) break;
        final shouldLoop =
            _settings.loopAudio == 0 || audioLoopCount < _settings.loopAudio;
        if (!shouldLoop) break;
      }

      // 确定起始位置：第一轮使用传入的startIndex，后续循环从0开始
      final int loopStartIdx = audioLoopCount == 0 ? startIndex : 0;

      // 使用异步for循环逐句播放
      for (int i = loopStartIdx; i < playList.length; i++) {
        // print('playList: ${playList.length}, startIndex: $startIndex, i: $i');
        // 检查会话是否被取消
        if (!_is_active_session(sessionId)) {
          // _isMainPlaybackPlaying = false;
          return;
        }

        final sentence = playList[i];

        // 更新当前索引（使用句子的原始索引）
        // 只在索引真正改变时才更新，避免不必要的 UI 刷新
        bool indexChanged = false;
        if (_playlistMode == PlaylistMode.bookmarks) {
          if (_currentBookmarkIndex != sentence.index) {
            _currentBookmarkIndex = sentence.index;
            indexChanged = true;
          }
        } else {
          if (_currentFullIndex != sentence.index) {
            _currentFullIndex = sentence.index;
            indexChanged = true;
          }
        }
        if (indexChanged) {
          notifyListeners();
        }

        // 播放当前句子
        print(
          "_playSingleSentenceWithLoop begin, _playbackSessionId: $_playbackSessionId",
        );
        await _playSingleSentenceWithLoop(sentence, sessionId);
        print(
          "_playSingleSentenceWithLoop end, _playbackSessionId: $_playbackSessionId",
        );

        // 句子之间间隔。
        if (i < playList.length - 1) {
          if (_playlistMode == PlaylistMode.bookmarks &&
              // 如果播放收藏列表时，并且没有开启循环播放，那么默认间隔为1s
              !_settings.loopEnabled) {
            await Future.delayed(const Duration(seconds: 1));
          } else if (_settings.autoPlayNextSentenceEnabled &&
              // 如果开启循环播放，那么使用设置的间隔
              _settings.loopEnabled &&
              _settings.pauseInterval > Duration.zero) {
            await Future.delayed(_settings.pauseInterval);
          }
        }

        // 检查会话是否被取消
        if (!_is_active_session(sessionId)) {
          // _isMainPlaybackPlaying = false;
          return;
        }

        // 如果不是自动播放下一句，等待当前句子播放完成后退出
        if (!_settings.autoPlayNextSentenceEnabled) {
          print("3");
          // 等待音频播放完成
          if (_audioPlayer.playing) {
            await _audioPlayer.playerStateStream.firstWhere(
              (state) => !state.playing || state.processingState == ProcessingState.completed,
            );
          }
          _isMainPlaybackPlaying = false;
          notifyListeners();
          return;
        }
      }

      // 一轮播放完成
      audioLoopCount++;

      // 如果没有开启音频循环，退出
      if (!_settings.loopAudioEnabled) break;
    }

    // 播放完成，清除主播放状态
    print("4");
    _isMainPlaybackPlaying = false;
    notifyListeners();
  }

  /// 播放单个句子（带循环和间隔）- 用于整体播放中的逐句播放
  Future<void> _playSingleSentenceWithLoop(
    Sentence sentence,
    int sessionId,
  ) async {
    if (_currentAudioItem == null) return;

    final loopCount = _settings.loopEnabled ? _settings.loopCount : 1;
    final pauseInterval = _settings.pauseInterval;

    // 循环播放当前句子
    for (int loop = 0; loop < loopCount; loop++) {
      if (!_is_active_session(sessionId)) {
        print("_playSingleSentenceWithLoop break 1");
        return;
      }

      await _playSingleSentenceOnce(sentence, sessionId);

      if (!_is_active_session(sessionId)) {
        print("_playSingleSentenceWithLoop break 2");
        return;
      }

      // 循环间隔，如果启用了循环播放
      if (loop < loopCount - 1 && pauseInterval > Duration.zero) {
        await Future.delayed(pauseInterval);
      }
    }
  }

  /// 播放单个句子一次（基础方法）
  Future<void> _playSingleSentenceOnce(Sentence sentence, int sessionId) async {
    if (_currentAudioItem == null) return;
    if (!_is_active_session(sessionId)) {
      print("_playSingleSentenceOnce break 3");
      return;
    }

    // 使用 setClip 限定播放范围
    _clipStart = sentence.startTime;
    await _audioPlayer.setClip(
      start: sentence.startTime,
      end: sentence.endTime,
    );
    // 立即通知 UI 更新，让进度条显示正确的位置
    notifyListeners();
    print("_playSingleSentenceOnce play begin");
    await _audioPlayer.play();

    // 等到本次播放结束或被打断
    await _audioPlayer.playerStateStream.firstWhere(
      (s) =>
          !_is_active_session(sessionId) || // 会话被取消
          s.processingState == ProcessingState.completed || // 播放到片段末尾
          (!s.playing && s.processingState == ProcessingState.ready), // 被暂停/停止
    );
    print("_playSingleSentenceOnce play end");
  }

  /// 单次播放句子（用于item按钮点击）
  Future<void> playSingleSentenceOnce(int index, int sessionId) async {
    if (index < 0 || index >= _sentences.length) return;

    final sentence = _sentences[index];

    await _playSingleSentenceOnce(sentence, sessionId);

    // 播放完成，清除item播放状态（只有当前会话仍然有效时才清除）
    if (_is_active_session(sessionId) && _itemPlaybackSentenceIndex == index) {
      _itemPlaybackSentenceIndex = null;
      notifyListeners();
    }
  }

  // ============================================================================
  // 控制方法
  // ============================================================================

  Future<void> pause() async {
    _playbackSessionId++; // 取消当前播放会话
    print("5");
    _isMainPlaybackPlaying = false;
    _itemPlaybackSentenceIndex = null;
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    _playbackSessionId++; // 取消当前播放会话
    print("6");
    _isMainPlaybackPlaying = false;
    _itemPlaybackSentenceIndex = null;
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 绝对位置的 seek（用于进度条拖动）
  Future<void> seekAbsolute(Duration absolutePosition) async {
    // 清除 clip 限制，切换到完整音频模式
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      // 先 seek 到绝对位置，然后再更新 _clipStart
      await _audioPlayer.seek(absolutePosition);
      _clipStart = Duration.zero;
      // 如果正在 item 播放，清除 item 播放状态
      if (_itemPlaybackSentenceIndex != null) {
        _itemPlaybackSentenceIndex = null;
        notifyListeners();
      }
    } else {
      // 直接 seek 到绝对位置
      await _audioPlayer.seek(absolutePosition);
    }
  }

  Future<void> selectFullSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    
    // 如果正在进行 item 播放，停止播放
    if (_itemPlaybackSentenceIndex != null) {
      ++_playbackSessionId; // 取消当前播放会话
      _itemPlaybackSentenceIndex = null;
      await _audioPlayer.pause();
    }
    
    _currentFullIndex = index;
    _autoScrollEnabled = true;

    // 点击item选中，移动进度条到该位置
    if (_currentAudioItem != null) {
      // 清除 clip 限制，切换到完整音频模式
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        _clipStart = Duration.zero;
      }
      await _audioPlayer.seek(_sentences[index].startTime);
    }
    notifyListeners();
  }

  Future<void> selectBookmarkedSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    
    // 如果正在进行 item 播放，停止播放
    if (_itemPlaybackSentenceIndex != null) {
      ++_playbackSessionId; // 取消当前播放会话
      _itemPlaybackSentenceIndex = null;
      await _audioPlayer.pause();
    }
    
    _currentBookmarkIndex = index;
    _autoScrollEnabled = true;

    // 点击item选中，移动进度条到该位置
    if (_currentAudioItem != null) {
      // 清除 clip 限制，切换到完整音频模式
      if (_clipStart != Duration.zero) {
        await _audioPlayer.setClip(start: null, end: null);
        _clipStart = Duration.zero;
      }
      await _audioPlayer.seek(_sentences[index].startTime);
    }
    notifyListeners();
  }

  /// 播放指定句子（用于点击播放按钮）- 单句播放模式
  Future<void> playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    // 如果点击的是正在播放的item，停止播放
    if (_itemPlaybackSentenceIndex == index) {
      ++_playbackSessionId; // 取消当前播放会话
      _itemPlaybackSentenceIndex = null;
      await _audioPlayer.pause();
      notifyListeners();
      return;
    }

    // 停止所有播放
    ++_playbackSessionId; // 取消当前播放会话
    final wasPlaying = _audioPlayer.playing;
    if (wasPlaying) {
      await _audioPlayer.pause();
    }
    
    // 清除所有播放状态
    _isMainPlaybackPlaying = false;
    _itemPlaybackSentenceIndex = null;

    // 根据播放模式设置当前播放索引
    if (_playlistMode == PlaylistMode.bookmarks) {
      if (!_bookmarkedIndices.contains(index)) return;
      _currentBookmarkIndex = index;
    } else {
      _currentFullIndex = index;
    }

    // 标记为item播放
    _itemPlaybackSentenceIndex = index;
    final currentSessionId = ++_playbackSessionId;

    // 先通知 UI 状态变化，然后开始播放（播放内部会再次通知进度条更新）
    notifyListeners();
    await playSingleSentenceOnce(index, currentSessionId);
  }

  Future<void> nextSentence() async {
    if (_sentences.isEmpty) return;
    late int newIndex;
    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      int pos = bookmarked.indexWhere((s) => s.index == _currentBookmarkIndex);
      if (pos == -1)
        pos = 0;
      else if (pos >= bookmarked.length - 1)
        return; // 到达最后一句
      else
        pos++;
      newIndex = bookmarked[pos].index;
      print(
        'next bookmark Sentence: $newIndex , sentence: ${bookmarkedSentences[pos]}',
      );
    } else {
      if (_currentFullIndex == null)
        newIndex = 0;
      else if (_currentFullIndex! >= _sentences.length - 1)
        return; // 到达最后一句
      else
        newIndex = _currentFullIndex! + 1;
    }

    final isPlaying = _audioPlayer.playing;
    // 只有主播放正在播放时才需要暂停
    final shouldResume = _isMainPlaybackPlaying;
    print('isPlaying: $isPlaying, shouldResume: $shouldResume');
    if (isPlaying) await pause();

    if (_playlistMode == PlaylistMode.bookmarks) {
      _currentBookmarkIndex = newIndex;
    } else {
      _currentFullIndex = newIndex;
    }

    // 启用自动滚动，确保选中的 item 可见
    _autoScrollEnabled = true;

    // 清除 clip 限制，确保进度条显示绝对时间
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      _clipStart = Duration.zero;
    }
    await _audioPlayer.seek(_sentences[newIndex].startTime);

    notifyListeners();

    // 如果原本正在播放，则从新的句子重新开始主播放
    if (shouldResume) {
      await mainPlay();
    }
  }

  Future<void> previousSentence() async {
    if (_sentences.isEmpty) return;
    late int newIndex;
    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      int pos = bookmarked.indexWhere((s) => s.index == _currentBookmarkIndex);
      if (pos <= 0) return; // 到达第一句
      pos--;
      newIndex = bookmarked[pos].index;
      print(
        'previous bookmark Sentence: $newIndex, sentence: ${bookmarkedSentences[pos]}',
      );
    } else {
      if (_currentFullIndex == null)
        newIndex = 0;
      else if (_currentFullIndex! <= 0)
        return; // 到达第一句
      else
        newIndex = _currentFullIndex! - 1;
    }

    final isPlaying = _audioPlayer.playing;
    final shouldResume = _isMainPlaybackPlaying;
    if (isPlaying) await pause();

    if (_playlistMode == PlaylistMode.bookmarks) {
      _currentBookmarkIndex = newIndex;
    } else {
      _currentFullIndex = newIndex;
    }

    // 启用自动滚动，确保选中的 item 可见
    _autoScrollEnabled = true;

    // 清除 clip 限制，确保进度条显示绝对时间
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      _clipStart = Duration.zero;
    }
    await _audioPlayer.seek(_sentences[newIndex].startTime);

    notifyListeners();

    // 如果原本正在播放，则从新的句子重新开始主播放
    if (shouldResume) {
      await mainPlay();
    }
  }

  Future<void> toggleBookmark(int index) async {
    final isRemoving = _bookmarkedIndices.contains(index);
    
    if (isRemoving) {
      _bookmarkedIndices.remove(index);
      _sentences[index].isBookmarked = false;
      
      // 如果在 bookmark 模式下取消了当前选中的 bookmark
      if (_playlistMode == PlaylistMode.bookmarks && _currentBookmarkIndex == index) {
        // 清除选中状态
        _currentBookmarkIndex = null;
        // 禁用自动滚动，避免列表跳动
        _autoScrollEnabled = false;
      }
    } else {
      _bookmarkedIndices.add(index);
      _sentences[index].isBookmarked = true;
    }

    if (_currentAudioItem != null) {
      await StorageService.saveBookmarks(
        _currentAudioItem!.id,
        _bookmarkedIndices,
      );
    }

    notifyListeners();
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    _settings = newSettings;
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);
    notifyListeners();
  }

  void setAutoScroll(bool enabled) {
    _autoScrollEnabled = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

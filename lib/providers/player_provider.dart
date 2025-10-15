import 'dart:async';
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
  int? _lastPlayedFullIndex; // 记录上次手动选择播放的句子（全文模式）
  int? _lastPlayedBookmarkIndex; // 记录上次手动选择播放的句子（收藏模式）
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
  bool get isPlaying => _audioPlayer.playing; // 主播放控制的播放状态
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _fullDuration; // 返回完整音频时长
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;
  bool get autoScrollEnabled => _autoScrollEnabled;

  // 绝对位置流：将 clip 相对位置映射到完整音频的绝对位置
  Stream<Duration> get absolutePositionStream =>
      _audioPlayer.positionStream.map((relativePosition) {
        return _clipStart + relativePosition;
      });

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (_playlistMode == mode) return; // 已经是目标模式，无需切换

    // 1. 暂停当前播放
    await pause();

    // 2. 切换模式
    _playlistMode = mode;

    // 3. 清除 clip 限制，确保进度条显示正确
    if (_clipStart != Duration.zero) {
      await _audioPlayer.setClip(start: null, end: null);
      _clipStart = Duration.zero;
    }

    // 4. 根据新模式恢复播放位置
    if (mode == PlaylistMode.full) {
      // 切换到 full text 模式
      if (_currentFullIndex != null && _currentFullIndex! < _sentences.length) {
        await _audioPlayer.seek(_sentences[_currentFullIndex!].startTime);
      } else if (_sentences.isNotEmpty) {
        // 确保有有效的索引
        _currentFullIndex = 0;
        await _audioPlayer.seek(_sentences[0].startTime);
      }
    } else {
      // 切换到 bookmark 模式
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) {
        // 书签为空，保持当前状态但不播放
        notifyListeners();
        return;
      }

      if (_currentBookmarkIndex != null &&
          _currentBookmarkIndex! < _sentences.length &&
          _bookmarkedIndices.contains(_currentBookmarkIndex)) {
        await _audioPlayer.seek(_sentences[_currentBookmarkIndex!].startTime);
      } else {
        // 如果当前没有选中的 bookmark，选择第一个
        _currentBookmarkIndex = bookmarked.first.index;
        await _audioPlayer.seek(bookmarked.first.startTime);
      }
    }

    notifyListeners();
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
        // 不循环
        print("1");
        notifyListeners();
      }
    } else {
      // 不循环
      print("2");
      notifyListeners();
    }
  }

  void _updateCurrentSentence(Duration position) {
    // 只在 Continuous 模式下才根据播放进度自动选中句子
    // 其他模式（Subtitle-Driven）通过播放循环主动更新索引，无需此处处理
    if (!_shouldUseContinuousMode() || !_audioPlayer.playing) return;

    if (_sentences.isEmpty) return;

    // 使用二分查找快速定位当前播放的句子
    int newIndex = _findSentenceIndexByPosition(position);

    // 只在索引真正改变时才更新，避免不必要的UI刷新
    if (newIndex != -1 && newIndex != _currentFullIndex) {
      _currentFullIndex = newIndex;
      notifyListeners();
    }
  }

  /// 二分查找：根据播放位置查找对应的句子索引
  int _findSentenceIndexByPosition(Duration position) {
    if (_sentences.isEmpty) return -1;

    // 特殊情况：位置在第一个句子之前
    if (position < _sentences.first.startTime) return 0;

    // 特殊情况：位置在最后一个句子之后
    if (position >= _sentences.last.endTime) return _sentences.length - 1;

    // 二分查找
    int left = 0;
    int right = _sentences.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final sentence = _sentences[mid];

      if (position >= sentence.startTime && position < sentence.endTime) {
        // 找到目标句子
        return mid;
      } else if (position < sentence.startTime) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    // 如果没有精确匹配（在句子间隙），返回最接近的句子
    // 优先返回即将播放的下一个句子
    if (left < _sentences.length) return left;
    if (right >= 0) return right;

    return -1;
  }

  Future<void> loadAudio(AudioItem audioItem) async {
    print("loadAudio: ${audioItem.name}");
    // 加载新音频时启用自动滚动
    _autoScrollEnabled = true;

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
        // 使用动态获取的完整路径
        final fullAudioPath = await audioItem.getFullAudioPath();
        await _audioPlayer.setFilePath(fullAudioPath);
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
          // 使用动态获取的完整路径
          final fullTranscriptPath = await audioItem.getFullTranscriptPath();
          if (fullTranscriptPath != null) {
            _sentences = await SubtitleParser.parseSubtitle(fullTranscriptPath);
          }
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

      // 恢复之前保存的播放状态，如果没有则初始化为第一个句子
      await _restorePlaybackState(audioItem);

      // 如果没有恢复到有效状态，设置初始句子
      if (_sentences.isNotEmpty && _currentFullIndex == null) {
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

  /// 播放方法
  Future<void> play() async {
    print('play');
    if (_currentAudioItem == null) return;

    if (_sentences.isEmpty) {
      // 没有字幕，直接播放
      await _audioPlayer.play();
      return;
    }

    // 确保初始索引存在（只在真正需要时初始化，避免覆盖用户选择）
    if (_playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = bookmarkedSentences;
      if (bookmarked.isEmpty) {
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
      if (_currentFullIndex == null ||
          _currentFullIndex! >= _sentences.length) {
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
    // 等待音频播放完成
    if (_audioPlayer.playing) {
      await _audioPlayer.playerStateStream.firstWhere(
        (state) =>
            !state.playing ||
            state.processingState == ProcessingState.completed,
      );
    }
    print("_playContinuous end");
    await stop();
    notifyListeners();
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
          return;
        }

        // 如果不是自动播放下一句，等待当前句子播放完成后退出
        if (!_settings.autoPlayNextSentenceEnabled) {
          print("3");
          // 等待音频播放完成
          if (_audioPlayer.playing) {
            await _audioPlayer.playerStateStream.firstWhere(
              (state) =>
                  !state.playing ||
                  state.processingState == ProcessingState.completed,
            );
          }
          notifyListeners();
          return;
        }
      }

      // 一轮播放完成
      audioLoopCount++;

      // 如果没有开启音频循环，退出
      if (!_settings.loopAudioEnabled) break;
    }

    // 播放完成, stop 播放
    await stop();
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

  // ============================================================================
  // 控制方法
  // ============================================================================

  Future<void> pause() async {
    _playbackSessionId++; // 取消当前播放会话
    print("5");
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    _playbackSessionId++; // 取消当前播放会话
    print("6");
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// 绝对位置的 seek（用于进度条拖动）
  Future<void> seekAbsolute(Duration absolutePosition) async {
    final wasPlaying = _audioPlayer.playing;
    if (wasPlaying) {
      await pause();
    }

    // 启用自动滚动，确保选中的句子可见
    _autoScrollEnabled = true;

    // 清除 clip 限制，切换到完整音频模式
    if (_clipStart != Duration.zero) {
      _clipStart = Duration.zero;
      await _audioPlayer.setClip(start: null, end: null);
      // 先 seek 到绝对位置，然后再更新 _clipStart
      await _audioPlayer.seek(absolutePosition);
    } else {
      // 直接 seek 到绝对位置
      await _audioPlayer.seek(absolutePosition);
    }

    // 根据新位置更新当前句子索引
    int? snappedBookmarkIndex;
    if (_sentences.isNotEmpty) {
      final newIndex = _findSentenceIndexByPosition(absolutePosition);
      if (newIndex != -1) {
        if (_playlistMode == PlaylistMode.bookmarks) {
          // 在书签模式下，检查找到的句子是否是书签
          if (_bookmarkedIndices.contains(newIndex)) {
            _currentBookmarkIndex = newIndex;
            snappedBookmarkIndex = newIndex;
          } else {
            // 如果不是书签，找最近的书签
            final bookmarked = bookmarkedSentences;
            if (bookmarked.isNotEmpty) {
              // 找到位置最接近的书签
              int closestIdx = bookmarked.first.index;
              Duration closestDiff =
                  (bookmarked.first.startTime - absolutePosition).abs();
              for (var s in bookmarked) {
                final diff = (s.startTime - absolutePosition).abs();
                if (diff < closestDiff) {
                  closestDiff = diff;
                  closestIdx = s.index;
                }
              }
              _currentBookmarkIndex = closestIdx;
              snappedBookmarkIndex = closestIdx;
            }
          }
        } else {
          // 全文模式直接使用找到的索引
          _currentFullIndex = newIndex;
        }
      }
    }

    // 书签模式下，拖动后将进度条对齐到目标句子的开始时间
    if (snappedBookmarkIndex != null) {
      final s = _sentences[snappedBookmarkIndex];
      await _audioPlayer.seek(s.startTime);
    }

    notifyListeners();

    if (wasPlaying) {
      await play();
    }
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= _sentences.length) return;

    _currentFullIndex = index;
    _lastPlayedFullIndex = index; // 记录上次手动选择的句子

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

    // 点击item时执行与主播放/暂停按钮相同的动作
    if (autoPlay) {
      await play();
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= _sentences.length) return;

    _currentBookmarkIndex = index;
    _lastPlayedBookmarkIndex = index; // 记录上次手动选择的句子

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

    // 点击item时执行与主播放/暂停按钮相同的动作
    if (autoPlay) {
      await play();
    }
  }

  /// 重播上一次手动选择的句子（快捷键 'r'）
  Future<void> replayCurrentSentence() async {
    if (_sentences.isEmpty) return;

    // 获取上一次手动选择的句子索引
    int? lastPlayedIndex;
    if (_playlistMode == PlaylistMode.bookmarks) {
      lastPlayedIndex = _lastPlayedBookmarkIndex;
    } else {
      lastPlayedIndex = _lastPlayedFullIndex;
    }

    if (lastPlayedIndex == null) return;

    // 暂停当前播放
    if (_audioPlayer.playing) {
      await pause();
    }

    // 重新播放该句子
    if (_playlistMode == PlaylistMode.bookmarks) {
      await selectBookmarkedSentence(lastPlayedIndex, autoPlay: true);
    } else {
      await selectFullSentence(lastPlayedIndex, autoPlay: true);
    }
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
    final shouldResume = _audioPlayer.playing;
    print('isPlaying: $isPlaying, shouldResume: $shouldResume');
    if (isPlaying) await pause();

    if (_playlistMode == PlaylistMode.bookmarks) {
      _currentBookmarkIndex = newIndex;
      _lastPlayedBookmarkIndex = newIndex; // 记录手动选择
    } else {
      _currentFullIndex = newIndex;
      _lastPlayedFullIndex = newIndex; // 记录手动选择
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
      await play();
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
    final shouldResume = _audioPlayer.playing;
    if (isPlaying) await pause();

    if (_playlistMode == PlaylistMode.bookmarks) {
      _currentBookmarkIndex = newIndex;
      _lastPlayedBookmarkIndex = newIndex; // 记录手动选择
    } else {
      _currentFullIndex = newIndex;
      _lastPlayedFullIndex = newIndex; // 记录手动选择
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

    // 如果原本正在播放，则从新的句子重新开始播放
    if (shouldResume) {
      await play();
    }
  }

  Future<void> toggleBookmark(int index) async {
    final isRemoving = _bookmarkedIndices.contains(index);

    // 当前是否在书签页
    final inBookmarksMode = _playlistMode == PlaylistMode.bookmarks;

    int? nextIndex;
    Set<int> indicesToRemove = {};
    // 如果是取消收藏：计算所有同文本（不区分大小写）的书签，无论当前处于哪个标签页
    if (isRemoving) {
      final beforeList = bookmarkedSentences;
      final targetTextLower = _sentences[index].text.toLowerCase();
      for (final s in beforeList) {
        if (s.text.toLowerCase() == targetTextLower) {
          indicesToRemove.add(s.index);
        }
      }

      // 仅在书签页时计算“下一个”焦点
      if (inBookmarksMode) {
        final pos = beforeList.indexWhere((s) => s.index == index);
        if (pos != -1) {
          // 找下一个句子（跳过将被移除的条目）
          for (int i = pos + 1; i < beforeList.length; i++) {
            if (!indicesToRemove.contains(beforeList[i].index)) {
              nextIndex = beforeList[i].index;
              break;
            }
          }
          // 没有下一个可用条目，则停止播放
          nextIndex ??= null;
        }
      }
    }

    // 记住播放状态：仅在书签页才需要恢复，并且如果句子列表为空，就停止播放，不需要恢复
    final shouldResume =
        inBookmarksMode && _audioPlayer.playing && nextIndex != null;

    // 仅在书签页执行“取消收藏”时需要立即暂停
    if (inBookmarksMode && isRemoving && _audioPlayer.playing) {
      await pause();
    }

    if (isRemoving) {
      // 移除收藏（包括所有同文本的收藏）
      if (indicesToRemove.isEmpty) {
        indicesToRemove = {index};
      }
      for (final idx in indicesToRemove) {
        _bookmarkedIndices.remove(idx);
        if (idx >= 0 && idx < _sentences.length) {
          _sentences[idx].isBookmarked = false;
        }
      }

      if (inBookmarksMode) {
        // 更新当前选中到"下一个"书签
        _currentBookmarkIndex = nextIndex;

        if (nextIndex != null && nextIndex < _sentences.length) {
          // 定位并设置 clip 至该句子
          final s = _sentences[nextIndex];
          _clipStart = s.startTime;
          await _audioPlayer.setClip(start: s.startTime, end: s.endTime);
        } else {
          // 列表为空：停止播放并重置 clip
          _clipStart = Duration.zero;
          await _audioPlayer.setClip(start: null, end: null);
          _currentBookmarkIndex = null;
          await stop();
        }
      }
    } else {
      // 添加收藏：无论在哪个页面，都不影响播放状态
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

    // 恢复播放：仅在书签页、之前处于播放状态且仍有书签可播时
    if (inBookmarksMode && shouldResume && bookmarkedSentences.isNotEmpty) {
      await play();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    // 保存旧设置，用于检测播放模式是否改变
    final oldSettings = _settings;
    final wasPlaying = _audioPlayer.playing;

    // 检查播放模式是否会改变
    // 影响播放模式的关键设置：autoPlayNextSentenceEnabled, loopEnabled
    final oldContinuousMode =
        _playlistMode == PlaylistMode.full &&
        oldSettings.autoPlayNextSentenceEnabled &&
        !oldSettings.loopEnabled;
    final newContinuousMode =
        _playlistMode == PlaylistMode.full &&
        newSettings.autoPlayNextSentenceEnabled &&
        !newSettings.loopEnabled;
    final modeWillChange = oldContinuousMode != newContinuousMode;

    _settings = newSettings;
    await _audioPlayer.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(newSettings);
    notifyListeners();

    // 如果正在播放且播放模式改变，重新开始播放以应用新模式
    if (wasPlaying && modeWillChange) {
      await pause();
      await play();
    }
  }

  void setAutoScroll(bool enabled) {
    _autoScrollEnabled = enabled;
    notifyListeners();
  }

  /// 保存当前音频的播放状态
  Future<void> saveCurrentPlaybackState() async {
    if (_currentAudioItem == null) return;

    final state = {
      'position': _audioPlayer.position.inMilliseconds,
      'currentFullIndex': _currentFullIndex,
      'currentBookmarkIndex': _currentBookmarkIndex,
      'playlistMode': _playlistMode.index,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await StorageService.savePlaybackState(_currentAudioItem!.id, state);
    print('Saved playback state for ${_currentAudioItem!.name}');
  }

  /// 恢复音频的播放状态
  Future<void> _restorePlaybackState(AudioItem audioItem) async {
    final state = await StorageService.loadPlaybackState(audioItem.id);
    if (state == null) return;

    try {
      // 恢复播放模式
      if (state['playlistMode'] != null) {
        _playlistMode = PlaylistMode.values[state['playlistMode'] as int];
      }

      // 恢复索引
      if (state['currentFullIndex'] != null) {
        _currentFullIndex = state['currentFullIndex'] as int?;
      }
      if (state['currentBookmarkIndex'] != null) {
        _currentBookmarkIndex = state['currentBookmarkIndex'] as int?;
      }

      // 恢复播放位置
      if (state['position'] != null) {
        final position = Duration(milliseconds: state['position'] as int);
        await _audioPlayer.seek(position);
      }

      print('Restored playback state for ${audioItem.name}');
    } catch (e) {
      print('Error restoring playback state: $e');
    }
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

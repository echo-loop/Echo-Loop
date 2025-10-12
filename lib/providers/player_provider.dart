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
  PlaybackSettings _settings = PlaybackSettings();
  Set<int> _bookmarkedIndices = {};

  bool _isLoading = false;
  int _currentAudioLoopCount = 0; // 当前音频的循环次数
  Timer? _pauseTimer;
  Timer? _sentenceEndTimer;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  bool _isDisposed = false;
  bool _autoScrollEnabled = true; // 自动跟随当前句子

  // 基于 processingState=completed 的单句循环控制
  StreamSubscription<ProcessingState>? _sentenceProcSub;
  int _sentenceTicket = 0;
  int _sentenceRemain = 0;
  bool _inSentenceClip = false;
  PlaylistMode _playlistMode = PlaylistMode.full;
  bool _sequentialPlay = false; // 逐句连续播放模式（loop 关闭时由 Play/空格触发）

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
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;
  bool get hasAudio => _currentAudioItem != null;
  bool get hasSentences => _sentences.isNotEmpty;
  bool get autoScrollEnabled => _autoScrollEnabled;

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
    // 在单句裁剪播放模式下，position 是片段内相对时间，
    // 为避免错误匹配句子索引，这里跳过自动更新。
    if (_inSentenceClip) return;
    _updateCurrentSentence(position);
  }

  void _onPlayerStateChanged(PlayerState state) {
    // 当处于单句裁剪播放时，不触发整段音频的完成逻辑
    if (!(_inSentenceClip &&
        state.processingState == ProcessingState.completed)) {
      if (state.processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
    }
    notifyListeners();
  }

  void _updateCurrentSentence(Duration position) {
    if (_sentences.isEmpty) return;

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
      _currentAudioLoopCount = 0;

      // Load audio
      try {
        await _audioPlayer.setFilePath(audioItem.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
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
          // Continue without transcript
        }
      }

      // Load bookmarks
      try {
        _bookmarkedIndices = await StorageService.loadBookmarks(audioItem.id);
      } catch (e) {
        print('Error loading bookmarks: $e');
        _bookmarkedIndices = {};
      }

      // Auto-bookmark sentences wrapped in []
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
      // 重置单句循环状态
      _inSentenceClip = false;
      _sentenceTicket++;
      await _sentenceProcSub?.cancel();
      _sentenceProcSub = null;
    } catch (e) {
      print('Error loading audio: $e');
      _currentAudioItem = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 播放音频：直接播放整个音频
  Future<void> play() async {
    if (_currentAudioItem == null) return;
    // 书签模式
    if (_playlistMode == PlaylistMode.bookmarks) {
      // loop 关闭：根据全局 autoPlayNextSentence 决定是否逐句连续播放
      if (!_settings.loopEnabled) {
        final bookmarked = bookmarkedSentences;
        if (_currentBookmarkIndex == null ||
            !_bookmarkedIndices.contains(_currentBookmarkIndex)) {
          if (bookmarked.isNotEmpty) {
            _currentBookmarkIndex = bookmarked.first.index;
          }
        }
        if (_currentBookmarkIndex != null) {
          _sequentialPlay = _settings.autoPlayNextSentenceEnabled;
          _currentAudioLoopCount = 0; // 新一轮
          await _playBookmarkSentenceInternal(_currentBookmarkIndex!);
          return;
        }
        await _audioPlayer.play();
        return;
      } else {
        // loop 开启：保持原有行为（按设置循环/自动下一句）
        if (_currentBookmarkIndex == null ||
            !_bookmarkedIndices.contains(_currentBookmarkIndex)) {
          final bookmarked = bookmarkedSentences;
          if (bookmarked.isNotEmpty) {
            _currentBookmarkIndex = bookmarked.first.index;
          }
        }
        if (_currentBookmarkIndex != null) {
          _sequentialPlay = false;
          await _playBookmarkSentenceInternal(_currentBookmarkIndex!);
          return;
        }
        await _audioPlayer.play();
        return;
      }
    }

    // 全文模式
    if (!_settings.loopEnabled) {
      if (_currentFullIndex == null && _sentences.isNotEmpty) {
        _currentFullIndex = 0;
      }
      if (_currentFullIndex != null) {
        _sequentialPlay = _settings.autoPlayNextSentenceEnabled;
        _currentAudioLoopCount = 0; // 新一轮
        await _playSentenceInternal(_currentFullIndex!);
        return;
      }
      await _audioPlayer.play();
    } else {
      // loop 开启：按单句设置播放
      if (_currentFullIndex != null) {
        _sequentialPlay = false;
        await _playSentenceInternal(_currentFullIndex!);
        return;
      }
      await _audioPlayer.play();
    }
  }

  Future<void> _playBookmarkSentenceInternal(int index) async {
    print('playBookmarkSentenceInternal: $index');
    if (_isDisposed) return;

    final sentence = _sentences[index];

    _sentenceTicket++;
    await _sentenceProcSub?.cancel();
    _sentenceProcSub = null;
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();

    // 逐句连续播放时，用整段音频并用定时器控制结束，这样进度条显示整段进度
    if (_sequentialPlay && !_settings.loopEnabled) {
      _inSentenceClip = false;
      await _audioPlayer.setLoopMode(LoopMode.off);
      if (_currentAudioItem != null) {
        await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
        await _audioPlayer.seek(sentence.startTime);
        await _audioPlayer.play();
      }

      final myTurn = _sentenceTicket;
      final dur = sentence.endTime - sentence.startTime;
      final effMicros = (dur.inMicroseconds / _settings.playbackSpeed).round();
      _sentenceEndTimer = Timer(Duration(microseconds: effMicros), () async {
        if (myTurn != _sentenceTicket) return;
        // 对齐到句尾并暂停
        final safeEnd = sentence.endTime - const Duration(milliseconds: 1);
        final target = safeEnd >= sentence.startTime
            ? safeEnd
            : sentence.startTime;
        await _audioPlayer.seek(target);
        await _audioPlayer.pause();

        // 顺序前进或处理音频循环
        final bookmarked = bookmarkedSentences;
        final pos = bookmarked.indexWhere(
          (s) => s.index == _currentBookmarkIndex,
        );
        final bool hasNext = pos != -1 && pos < bookmarked.length - 1;
        if (hasNext) {
          final nextIndex = bookmarked[pos + 1].index;
          _currentBookmarkIndex = nextIndex;
          notifyListeners();
          await _playBookmarkSentenceInternal(nextIndex);
        } else {
          if (_settings.loopAudioEnabled) {
            _currentAudioLoopCount++;
            final shouldLoop =
                _settings.loopAudio == 0 ||
                _currentAudioLoopCount < _settings.loopAudio;
            if (shouldLoop && bookmarked.isNotEmpty) {
              _currentBookmarkIndex = bookmarked.first.index;
              notifyListeners();
              await _playBookmarkSentenceInternal(_currentBookmarkIndex!);
            } else {
              _currentAudioLoopCount = 0;
              _sequentialPlay = false;
            }
          } else {
            _sequentialPlay = false;
          }
        }
      });
      return;
    }

    // 非顺序模式：使用裁剪片段，遵循单句循环/间隔/自动下一句
    final Duration clipStart = sentence.startTime;
    final Duration clipEnd = sentence.endTime;

    _inSentenceClip = true;
    // 遵循 repeat 规则：loopEnabled? 重复N次，否则仅播放1次
    final int times = (_settings.loopEnabled ? _settings.loopCount : 1).clamp(
      1,
      999,
    );
    final Duration gap = _settings.pauseInterval;
    _sentenceRemain = times;

    final clip = ClippingAudioSource(
      start: clipStart,
      end: clipEnd,
      child: AudioSource.uri(Uri.file(_currentAudioItem!.audioPath)),
    );

    await _audioPlayer.setLoopMode(LoopMode.off);
    await _audioPlayer.setAudioSource(clip);
    await _audioPlayer.seek(Duration.zero);

    final myTurn = _sentenceTicket;
    _sentenceProcSub = _audioPlayer.processingStateStream.listen((st) async {
      if (myTurn != _sentenceTicket) return;
      if (st != ProcessingState.completed) return;

      _sentenceRemain -= 1;
      if (_sentenceRemain > 0) {
        if (gap > Duration.zero) {
          await Future.delayed(gap);
          if (myTurn != _sentenceTicket) return;
        }
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }

      // 循环完成：恢复整段音源并停在句尾附近
      _inSentenceClip = false;
      await _sentenceProcSub?.cancel();
      _sentenceProcSub = null;

      if (_currentAudioItem != null) {
        await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
        final safeEnd = sentence.endTime - const Duration(milliseconds: 1);
        final target = safeEnd >= sentence.startTime
            ? safeEnd
            : sentence.startTime;
        await _audioPlayer.seek(target);
        await _audioPlayer.pause();
      }

      // 书签模式自动前进
      final bookmarked = bookmarkedSentences;
      final pos = bookmarked.indexWhere(
        (s) => s.index == _currentBookmarkIndex,
      );
      final bool hasNext = pos != -1 && pos < bookmarked.length - 1;
      if (_settings.loopEnabled &&
          _settings.autoPlayNextSentenceEnabled &&
          hasNext) {
        // 仅当启用循环且开启自动下一句时，前进到下一条书签；在前进前等待 interval。
        if (gap > Duration.zero) {
          await Future.delayed(gap);
          if (myTurn != _sentenceTicket) return;
        }
        final nextIndex = bookmarked[pos + 1].index;
        _currentBookmarkIndex = nextIndex;
        notifyListeners();
        await _playBookmarkSentenceInternal(nextIndex);
      }
    });

    await _audioPlayer.play();
  }

  // 暂停播放
  Future<void> pause() async {
    await _audioPlayer.pause();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    // 使待触发的循环/自动下一句失效
    _sentenceTicket++;
    await _sentenceProcSub?.cancel();
    _sentenceProcSub = null;
    _inSentenceClip = false;
    _sequentialPlay = false;
  }

  // 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _currentAudioLoopCount = 0;
    _sentenceTicket++;
    await _sentenceProcSub?.cancel();
    _sentenceProcSub = null;
    _inSentenceClip = false;
    _sequentialPlay = false;
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // 选择句子：设置选中索引，播放中则立即播放；非播放状态仅选中（全文）
  Future<void> selectFullSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentFullIndex = index;
    // 用户点击句子时，恢复自动跟随
    _autoScrollEnabled = true;
    // 只有在播放状态下才立即播放
    if (isPlaying) {
      await playSentence(index);
    } else {
      // 暂停状态下只更新选中索引
      notifyListeners();
    }
  }

  // 选择句子：设置选中索引，播放中则立即播放；非播放状态仅选中（书签）
  Future<void> selectBookmarkedSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentBookmarkIndex = index;
    // 用户点击句子时，恢复自动跟随
    _autoScrollEnabled = true;
    // 只有在播放状态下才立即播放
    if (isPlaying) {
      await playSentence(index);
    } else {
      // 暂停状态下只更新选中索引
      notifyListeners();
    }
  }

  // 播放单个句子（用于逐句精听）
  Future<void> playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;

    if (_playlistMode == PlaylistMode.bookmarks) {
      // 书签模式下，只能播放书签列表中的句子
      if (!_bookmarkedIndices.contains(index)) {
        return;
      }
      _currentBookmarkIndex = index;
      _sequentialPlay = false; // 点击句子只播放当前一句
      await _playBookmarkSentenceInternal(index);
    } else {
      _currentFullIndex = index;
      _sequentialPlay = false; // 点击句子只播放当前一句
      await _playSentenceInternal(index);
    }
  }

  // 内部方法：播放句子的实际逻辑
  Future<void> _playSentenceInternal(int index) async {
    if (_isDisposed) return;

    final sentence = _sentences[index];

    // 结束旧的单句循环任务
    _sentenceTicket++;
    await _sentenceProcSub?.cancel();
    _sentenceProcSub = null;
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    // 顺序模式：整段音频 + 定时器，保证进度条显示整段
    if (_sequentialPlay && !_settings.loopEnabled) {
      _inSentenceClip = false;
      await _audioPlayer.setLoopMode(LoopMode.off);
      if (_currentAudioItem != null) {
        await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
        await _audioPlayer.seek(sentence.startTime);
        await _audioPlayer.play();
      }

      final myTurn = _sentenceTicket;
      final dur = sentence.endTime - sentence.startTime;
      final effMicros = (dur.inMicroseconds / _settings.playbackSpeed).round();
      _sentenceEndTimer = Timer(Duration(microseconds: effMicros), () async {
        if (myTurn != _sentenceTicket) return;
        // 对齐句尾并暂停
        if (_currentAudioItem != null) {
          final safeEnd = sentence.endTime - const Duration(milliseconds: 1);
          final target = safeEnd >= sentence.startTime
              ? safeEnd
              : sentence.startTime;
          await _audioPlayer.seek(target);
          await _audioPlayer.pause();
        }
        // 顺序前进或音频循环
        if (_currentFullIndex != null &&
            _currentFullIndex! < _sentences.length - 1) {
          final nextIndex = _currentFullIndex! + 1;
          _currentFullIndex = nextIndex;
          await _playSentenceInternal(nextIndex);
        } else {
          if (_settings.loopAudioEnabled) {
            _currentAudioLoopCount++;
            final shouldLoop =
                _settings.loopAudio == 0 ||
                _currentAudioLoopCount < _settings.loopAudio;
            if (shouldLoop && _sentences.isNotEmpty) {
              _currentFullIndex = 0;
              await _playSentenceInternal(0);
            } else {
              _currentAudioLoopCount = 0;
              _sequentialPlay = false;
            }
          } else {
            _sequentialPlay = false;
          }
        }
      });
      return;
    }

    // 非顺序模式：使用裁剪片段
    // 计算循环次数与间隔
    final int times = (_settings.loopEnabled ? _settings.loopCount : 1).clamp(
      1,
      999,
    );
    final Duration gap = _settings.pauseInterval;

    // 为了更稳健的切入切出，加少量前后余量
    const headPad = Duration(milliseconds: 40);
    const tailPad = Duration(milliseconds: 60);
    final Duration clipStart = sentence.startTime > headPad
        ? (sentence.startTime - headPad)
        : Duration.zero;
    final Duration clipEnd = sentence.endTime + tailPad;

    // 使用 ClippingAudioSource 播放单句片段
    _inSentenceClip = true;
    _sentenceRemain = times;

    final clip = ClippingAudioSource(
      start: clipStart,
      end: clipEnd,
      child: AudioSource.uri(Uri.file(_currentAudioItem!.audioPath)),
    );

    await _audioPlayer.setLoopMode(LoopMode.off);
    await _audioPlayer.setAudioSource(clip);
    await _audioPlayer.seek(Duration.zero);

    final myTurn = _sentenceTicket;
    _sentenceProcSub = _audioPlayer.processingStateStream.listen((st) async {
      if (myTurn != _sentenceTicket) return; // 任务被新任务取代
      if (st != ProcessingState.completed) return; // 仅关心片段自然结束

      _sentenceRemain -= 1;
      if (_sentenceRemain > 0) {
        if (gap > Duration.zero) {
          await Future.delayed(gap);
          if (myTurn != _sentenceTicket) return;
        }
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
      } else {
        // 循环完成，恢复整段音源，停在句尾附近
        _inSentenceClip = false;
        await _sentenceProcSub?.cancel();
        _sentenceProcSub = null;
        // 恢复整段音频源，保持当前速度设置
        if (_currentAudioItem != null) {
          await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
          await _audioPlayer.setSpeed(_settings.playbackSpeed);
          final safeEnd = sentence.endTime - const Duration(milliseconds: 1);
          final target = safeEnd >= sentence.startTime
              ? safeEnd
              : sentence.startTime;
          await _audioPlayer.seek(target);
          await _audioPlayer.pause();
        }
        // 自动播放下一句（可选）：loop 开启时，等待 interval，再继续；到达最后一句则不前进
        if (_settings.loopEnabled &&
            _settings.autoPlayNextSentenceEnabled &&
            _currentFullIndex != null &&
            _currentFullIndex! < _sentences.length - 1) {
          if (gap > Duration.zero) {
            await Future.delayed(gap);
            if (myTurn != _sentenceTicket) return;
          }
          final nextIndex = _currentFullIndex! + 1;
          _currentFullIndex = nextIndex;
          await _playSentenceInternal(nextIndex);
        }
      }
    });

    await _audioPlayer.play();
  }

  // 处理整个音频播放完成
  void _handlePlaybackCompleted() {
    if (_isDisposed) return;

    // 检查是否启用音频循环
    // loopAudio: 0=无穷循环, 1-10=循环指定次数
    if (_settings.loopAudioEnabled) {
      _currentAudioLoopCount++;

      // 判断是否继续循环
      final shouldLoop =
          _settings.loopAudio == 0 ||
          _currentAudioLoopCount < _settings.loopAudio;

      if (shouldLoop) {
        _pauseTimer?.cancel();
        // 等待间隔时间后重新播放整个音频
        _pauseTimer = Timer(_settings.pauseInterval, () async {
          if (!_isDisposed) {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          }
        });
      } else {
        // 循环完成，重置计数
        _currentAudioLoopCount = 0;
      }
    }
  }

  // 跳转到下一句（根据播放列表模式）
  Future<void> nextSentence() async {
    if (_sentences.isEmpty) return;
    if (_playlistMode == PlaylistMode.bookmarks) {
      final b = bookmarkedSentences;
      if (b.isEmpty) return;
      int pos;
      if (_currentBookmarkIndex == null) {
        pos = 0;
      } else {
        pos = b.indexWhere((s) => s.index == _currentBookmarkIndex);
        if (pos == -1 || pos >= b.length - 1) {
          return; // 到达最后一句，不循环
        } else {
          pos += 1;
        }
      }
      final nextIndex = b[pos].index;
      _currentBookmarkIndex = nextIndex;
      if (_inSentenceClip && _currentAudioItem != null) {
        _inSentenceClip = false;
        _sentenceTicket++;
        await _sentenceProcSub?.cancel();
        _sentenceProcSub = null;
        await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
      }
      await seek(_sentences[nextIndex].startTime);
      notifyListeners();
      return;
    }

    // 全文模式
    if (_currentFullIndex == null) {
      _currentFullIndex = 0;
    } else if (_currentFullIndex! >= _sentences.length - 1) {
      return; // 到达最后一句，不循环
    } else {
      _currentFullIndex = _currentFullIndex! + 1;
    }

    if (_inSentenceClip && _currentAudioItem != null) {
      _inSentenceClip = false;
      _sentenceTicket++;
      await _sentenceProcSub?.cancel();
      _sentenceProcSub = null;
      await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
      await _audioPlayer.setSpeed(_settings.playbackSpeed);
    }
    await seek(_sentences[_currentFullIndex!].startTime);
    notifyListeners();
  }

  // 跳转到上一句（根据播放列表模式）
  Future<void> previousSentence() async {
    if (_sentences.isEmpty) return;
    if (_playlistMode == PlaylistMode.bookmarks) {
      final b = bookmarkedSentences;
      if (b.isEmpty) return;
      int pos;
      if (_currentBookmarkIndex == null) {
        pos = 0;
      } else {
        pos = b.indexWhere((s) => s.index == _currentBookmarkIndex);
        if (pos <= 0) {
          return; // 到达第一句，不循环
        } else {
          pos -= 1;
        }
      }
      final prevIndex = b[pos].index;
      _currentBookmarkIndex = prevIndex;
      if (_inSentenceClip && _currentAudioItem != null) {
        _inSentenceClip = false;
        _sentenceTicket++;
        await _sentenceProcSub?.cancel();
        _sentenceProcSub = null;
        await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
        await _audioPlayer.setSpeed(_settings.playbackSpeed);
      }
      await seek(_sentences[prevIndex].startTime);
      notifyListeners();
      return;
    }

    // 全文模式
    if (_currentFullIndex == null) {
      _currentFullIndex = 0;
    } else if (_currentFullIndex! <= 0) {
      return; // 到达第一句，不循环
    } else {
      _currentFullIndex = _currentFullIndex! - 1;
    }

    if (_inSentenceClip && _currentAudioItem != null) {
      _inSentenceClip = false;
      _sentenceTicket++;
      await _sentenceProcSub?.cancel();
      _sentenceProcSub = null;
      await _audioPlayer.setFilePath(_currentAudioItem!.audioPath);
      await _audioPlayer.setSpeed(_settings.playbackSpeed);
    }
    await seek(_sentences[_currentFullIndex!].startTime);
    notifyListeners();
  }

  Future<void> toggleBookmark(int index) async {
    if (_bookmarkedIndices.contains(index)) {
      _bookmarkedIndices.remove(index);
      _sentences[index].isBookmarked = false;
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
    _pauseTimer?.cancel();
    _sentenceEndTimer?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _sentenceProcSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/audio_item.dart';
import '../../models/sentence.dart';
import '../../models/playback_settings.dart';
import '../../models/listening_practice_state.dart';
import '../../services/app_logger.dart';
import '../../services/storage_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../notification_permission_provider.dart';
import 'bookmark_manager.dart';
import 'playback_reducer.dart';
import 'playback_state_storage.dart';
import 'sentence_tracker.dart';

export '../../models/listening_practice_state.dart'
    show PlaylistMode, ListeningPracticeState;

part 'listening_practice_provider.g.dart';

/// 自由练习播放器的状态与业务编排。
///
/// 播放推进采用统一的「确定性 await-完成循环」模型：无论整篇连续播放
/// （[_playWholeDriven]）还是单句循环/收藏跳播（[_playSentenceDriven]），都在
/// 协程里 `await` 引擎播放一遍（[AudioEngine.playToEnd] / [AudioEngine.playClipOnce]）
/// 后，用纯函数 [decideNext] / [shouldLoopWhole] 决定下一步（重播 / 进下一句 /
/// 回卷 / 停止）。计数与循环不依赖反应式的 `completed` 事件流，从根上避免 just_audio
/// 重复/滞后 `completed` 事件导致的多计数与提前停止。
///
/// 真相源是 [ListeningPracticeState.currentFullIndex] /
/// [ListeningPracticeState.currentBookmarkIndex]，只在以下入口被修改：
/// 用户显式选句/上下句、连播时位置流推进（仅 gapless 模式）、完成事件归约器。
@Riverpod(keepAlive: true)
class ListeningPractice extends _$ListeningPractice {
  StreamSubscription? _positionSub;

  /// 追踪正在进行的音频加载，避免重复调用时跳过未完成的加载
  Completer<void>? _loadingCompleter;

  /// 当前句已完成播放的次数（含刚结束这次）。进新句时归零。
  int _sentenceRepeatsDone = 0;

  /// 整篇已完成的遍数。换音频/重新起播时归零。
  ///
  /// gapless 整段自然播完即 +1；监听句尾模式下走到末尾并回到第 0 句时 +1。
  int _wholeLoopsDone = 0;

  /// 播放任务代际计数器。每次起播/暂停/切句/seek 都递增，所有在途协程跨 await 后
  /// 都必须校验代际，避免旧播放任务在用户操作后继续推进状态。
  int _playbackGen = 0;

  /// 当前是否由 Free Player 的句级 clip 协程驱动。
  ///
  /// 句级模式用于单句循环和收藏跳播；整篇普通连播仍走 gapless。completed 事件在
  /// 句级模式下由协程消费，provider 的全局 playerState 监听必须忽略，避免双推进。
  bool _activeSentenceDrivenPlayback = false;

  /// 播放中切换循环开关后，期望的播放驱动模式与当前实际模式不一致时置为 true。
  ///
  /// 设计要求是“切开关不打断当前播放态”：不立即回句首、不自动播放。因此这里只记
  /// 录“下一次自然句边界/clip 完成后再交接模型”，由位置流或 completed 事件在安
  /// 全时机接管。
  bool _pendingPlaybackModeHandoff = false;

  /// 当前播放列表已自然播完，等待用户再次点击主播放按钮时从列表开头重播。
  ///
  /// 仅在“非整篇循环”的自然结束路径置为 true。它不持久化，也不改变当前高亮/进度；
  /// 作用只是把主播放按钮从“从当前句再播”改为“从当前列表开头再播”。
  bool _awaitingReplayFromStart = false;

  /// LP 自己发起播放时持有的 AudioEngine sessionId。
  ///
  /// engine 的 position/playerState 流是全局共享的：句子讲解页等组件会旁路
  /// 驱动同一个 engine（`playRangeOnce`），并通过 `newSession()` 顶掉当前 session。
  /// 监听回调只处理「属于 LP 当前播放 session」的事件，外来 session 的事件一律
  /// 忽略——否则讲解页试听单句时，位置流会把 `currentFullIndex` 改成被试听的句子，
  /// 返回后主播放按钮就从那一句（常表现为第一句）重新开始。
  int _playbackSessionId = -1;

  /// 跨句自动保存进度的并发护栏：上一次写库未完成时跳过本次，避免堆积写入。
  bool _autoSaving = false;

  @override
  ListeningPracticeState build() {
    _setupListeners();
    ref.onDispose(_disposeListeners);
    _loadSettings();
    return const ListeningPracticeState();
  }

  // --- 获取 AudioEngine ---
  AudioEngine get _engine => ref.read(audioEngineProvider.notifier);

  void _setupListeners() {
    // defer listener setup to after first build
    Future.microtask(() {
      _positionSub = _engine.absolutePositionStream.listen(_onPositionChanged);
    });
  }

  void _disposeListeners() {
    _positionSub?.cancel();
  }

  /// 暂停 stream 监听（学习模式期间调用，避免 LP 接管共享引擎）。
  void suspendListeners() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// 恢复 stream 监听（退出学习模式时调用）
  void resumeListeners() {
    _setupListeners();
  }

  /// 外部标注后同步书签状态（精听退出时调用）
  Future<void> syncBookmarks() async {
    if (state.currentAudioItem == null) return;
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await BookmarkManager.loadBookmarks(
      state.currentAudioItem!.id,
      dao: bookmarkDao,
    );
    BookmarkManager.updateSentenceBookmarkStatus(
      state.sentences,
      bookmarkedIndices,
    );
    state = state.copyWith(bookmarkedIndices: bookmarkedIndices);
  }

  Future<void> _loadSettings() async {
    final settings = await StorageService.loadSettings();
    state = state.copyWith(
      fullSettings: settings.full,
      bookmarkSettings: settings.bookmark,
    );
  }

  // ===========================================================================
  // 播放模型辅助：播放列表 / 当前序号 / clip 形态
  // ===========================================================================

  /// 当前播放列表：全文模式=全部句子；收藏模式=收藏句子。
  List<Sentence> get _playable => state.playlistMode == PlaylistMode.bookmarks
      ? state.bookmarkedSentences
      : state.sentences;

  /// 是否使用句级 clip 驱动。
  ///
  /// 业界常见做法是按播放目标选择模型：整篇连续播放用 gapless；需要准确停在句尾
  /// 的单句循环/收藏跳播用 clip。这样循环不依赖 positionStream 的采样频率和越界
  /// overshoot，避免末句、静音间隙、收藏非连续句的竞态。
  bool get _usesSentenceDrivenPlayback =>
      state.playlistMode == PlaylistMode.bookmarks ||
      state.settings.loopSentence;

  /// 当前句在播放列表中的序号（0-based）。列表为空返回 null。
  int? get _currentPos {
    final playable = _playable;
    if (playable.isEmpty) return null;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final ci = state.currentBookmarkIndex;
      if (ci == null) return 0;
      final p = playable.indexWhere((s) => s.index == ci);
      return p == -1 ? 0 : p;
    } else {
      final ci = state.currentFullIndex;
      if (ci == null || ci < 0 || ci >= playable.length) return 0;
      return ci;
    }
  }

  // ===========================================================================
  // 引擎事件监听
  // ===========================================================================

  void _onPositionChanged(Duration absolutePosition) {
    if (!_engine.isActiveSession(_playbackSessionId)) return;
    if (!_engine.isPlaying) return;
    if (_activeSentenceDrivenPlayback) return;
    final sentenceChanged = _updateHighlight(absolutePosition);
    _maybeHandoffFromGapless(sentenceChanged);
  }

  /// 按实际播放位置刷新当前句高亮（gapless 下连续）。
  ///
  /// 全文模式直接按位置二分查找更新 currentFullIndex。收藏模式只在落点正好是收藏句
  /// 时更新 currentBookmarkIndex；落在非收藏区间（跳播 overshoot）保持当前高亮，
  /// 避免滑过非收藏间隙时高亮闪烁。
  bool _updateHighlight(Duration position) {
    if (state.sentences.isEmpty) return false;
    final idx = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      position,
    );
    if (idx == -1) return false;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      if (state.bookmarkedIndices.contains(idx) &&
          idx != state.currentBookmarkIndex) {
        state = state.copyWith(currentBookmarkIndex: idx);
        _autoSaveProgress();
        return true;
      }
    } else {
      if (idx != state.currentFullIndex) {
        state = state.copyWith(currentFullIndex: idx);
        _autoSaveProgress();
        return true;
      }
    }
    return false;
  }

  /// 设置逻辑播放态——播放/暂停按钮图标的唯一真相源。
  ///
  /// 由 controller 在所有起播/暂停/停止/自然播完入口显式调用，不读 just_audio
  /// 的 `AudioPlayer.playing`（后者在自然播完后仍为 true，会让图标误显「暂停」）。
  void _setLogicalPlaying(bool playing) {
    if (state.isPlaying == playing) return;
    state = state.copyWith(isPlaying: playing);
  }

  /// 启动整篇连续播放的确定性循环（gapless）。
  ///
  /// [startPos] 非空：把真相源对齐到该句并 seek 到句首后起播（全新起播 / 模型交接）；
  /// 为空：从引擎当前精确位置继续（暂停后续播，保留已完成遍数）。
  /// [resetCounters] 为 true 时清零整篇/单句计数（全新起播）。
  Future<void> _startWholeDriven({
    int? startPos,
    required bool resetCounters,
  }) async {
    final playable = _playable;
    if (playable.isEmpty) return;

    final gen = ++_playbackGen;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    if (resetCounters) {
      _wholeLoopsDone = 0;
      _sentenceRepeatsDone = 0;
    }
    _playbackSessionId = _engine.newSession();
    await _engine.clearClip();

    if (startPos != null) {
      if (startPos < 0 || startPos >= playable.length) return;
      final target = playable[startPos];
      if (state.playlistMode == PlaylistMode.bookmarks) {
        state = state.copyWith(
          currentBookmarkIndex: target.index,
          lastPlayedBookmarkIndex: target.index,
        );
      } else {
        state = state.copyWith(
          currentFullIndex: target.index,
          lastPlayedFullIndex: target.index,
        );
      }
      await _engine.seek(target.startTime);
      // seek 后保存，使持久化位置落在新句首而非上一句句尾。
      _autoSaveProgress();
    }

    _setLogicalPlaying(true);
    final s = state.settings;
    AppLogger.log(
      'Player',
      '▶ 整篇起播 gen=$gen sid=$_playbackSessionId '
          'loopWhole=${s.loopWhole} count=${s.wholeLoopCount} '
          'loopsDone=$_wholeLoopsDone '
          'startPos=${startPos ?? '续播(当前位置)'} resetCounters=$resetCounters',
    );
    unawaited(_playWholeDriven(gen, _playbackSessionId));
  }

  /// 整篇连续播放的确定性循环。
  ///
  /// 每遍 `await` [AudioEngine.playToEnd] 播到自然结束，再用 [shouldLoopWhole]
  /// 决定回卷重播还是停止；遍数在协程内自增，因此 just_audio 重复/滞后的
  /// `completed` 事件不会造成多计数或提前停止。`loopWhole == false` 时第一遍后即
  /// 停止，覆盖「非循环播完一次」的情形。高亮仍由 `_onPositionChanged` 跟随位置流。
  Future<void> _playWholeDriven(int gen, int sid) async {
    while (gen == _playbackGen && _engine.isActiveSession(sid)) {
      await _engine.playToEnd(sid);
      if (gen != _playbackGen || !_engine.isActiveSession(sid)) {
        AppLogger.log(
          'Player',
          '⏹ 整篇本遍作废 gen=$gen(cur=$_playbackGen) '
              'sid=$sid(active=${_engine.isActiveSession(sid)}) '
              'loopsDone=$_wholeLoopsDone',
        );
        return;
      }

      _wholeLoopsDone += 1;
      _autoSaveProgress();

      final s = state.settings;
      // 整篇循环计数：「目标 N 遍」时输出 第 done/N 遍；∞ 时输出 第 done 遍。
      final total = s.wholeLoopCount == 0 ? '∞' : '${s.wholeLoopCount}';
      AppLogger.log(
        'Player',
        '✓ 整篇播完第 $_wholeLoopsDone/$total 遍 gen=$gen '
            'loopWhole=${s.loopWhole}',
      );

      if (!shouldLoopWhole(s.loopWhole, s.wholeLoopCount, _wholeLoopsDone)) {
        AppLogger.log(
          'Player',
          '⏹ 整篇循环结束（已播满 $_wholeLoopsDone 遍）→ stop，等待用户重播',
        );
        _awaitingReplayFromStart = true;
        _setLogicalPlaying(false);
        await _engine.stop();
        return;
      }

      await _delayInterval(s.wholeInterval);
      if (gen != _playbackGen || !_engine.isActiveSession(sid)) {
        AppLogger.log(
          'Player',
          '⏹ 整篇间隔停顿后作废 gen=$gen(cur=$_playbackGen) loopsDone=$_wholeLoopsDone',
        );
        return;
      }

      final playable = _playable;
      if (playable.isEmpty) {
        _setLogicalPlaying(false);
        await _engine.stop();
        return;
      }

      // 回卷到列表开头继续下一遍。
      AppLogger.log('Player', '↻ 整篇回卷，准备播第 ${_wholeLoopsDone + 1}/$total 遍');
      final first = playable.first;
      if (state.playlistMode == PlaylistMode.bookmarks) {
        state = state.copyWith(
          currentBookmarkIndex: first.index,
          lastPlayedBookmarkIndex: first.index,
        );
      } else {
        state = state.copyWith(
          currentFullIndex: first.index,
          lastPlayedFullIndex: first.index,
        );
      }
      await _engine.seek(first.startTime);
      _autoSaveProgress();
    }
  }

  /// 句级 clip 播放循环。
  ///
  /// 单句循环和收藏跳播都需要准确停在句尾，用 clip 由 just_audio 产生 completed 事件
  /// 是稳定做法；不要用 positionStream 越界判断句尾。
  Future<void> _playSentenceDriven(int gen, int sid) async {
    var pos = _currentPos ?? 0;

    while (gen == _playbackGen && _engine.isActiveSession(sid)) {
      final playable = _playable;
      if (playable.isEmpty || pos < 0 || pos >= playable.length) {
        await _engine.stop();
        return;
      }

      final sentence = playable[pos];
      _setCurrentFromSentence(sentence);
      await _engine.playClipOnce(sentence, sid);
      if (gen != _playbackGen || !_engine.isActiveSession(sid)) return;

      _sentenceRepeatsDone += 1;
      _autoSaveProgress();

      final s = state.settings;
      final action = decideNext(
        loopSentence: s.loopSentence,
        sentenceLoopCount: s.sentenceLoopCount,
        sentenceInterval: s.sentenceInterval,
        loopWhole: s.loopWhole,
        wholeLoopCount: s.wholeLoopCount,
        wholeInterval: s.wholeInterval,
        sentenceRepeatsDone: _sentenceRepeatsDone,
        wholeLoopsDone: _wholeLoopsDone,
        currentPos: pos,
        playableCount: playable.length,
      );

      if (_pendingPlaybackModeHandoff) {
        _pendingPlaybackModeHandoff = false;

        // 单句循环切回普通全文播放时，当前 clip 先自然播完；随后立刻切回 gapless，
        // 从 reducer 计算出的下一句/回卷位置继续，不再把后续句子也放进 clip 模式。
        if (!_usesSentenceDrivenPlayback) {
          await _handoffFromSentenceDriven(action, gen, sid);
          return;
        }

        // 普通全文播放中途打开单句循环时，当前句先自然播完；在“当前句边界”接管，
        // 直接回到当前句句首进入 clip 循环，不跳到下一句，也不打断当前播放态。
        _sentenceRepeatsDone = 0;
        pos = _currentPos ?? pos;
        continue;
      }

      switch (action) {
        case StopPlayback():
          _awaitingReplayFromStart = true;
          _setLogicalPlaying(false);
          await _engine.stop();
          return;
        case ReplayCurrent(:final pauseBefore):
          await _delayInterval(pauseBefore);
        case GoToPosition(:final position, :final pauseBefore):
          final wasLast = pos >= playable.length - 1;
          if (wasLast && position == 0) {
            _wholeLoopsDone += 1;
          }
          _sentenceRepeatsDone = 0;
          await _delayInterval(pauseBefore);
          pos = position;
      }
    }
  }

  /// gapless 播放中打开单句循环后，等待当前句自然结束，再在“当前句边界”交接到 clip。
  ///
  /// 这里不立刻切 clip，避免播放头突然回到句首；只有位置流确认当前句已经自然播完
  /// 才重启为句级播放模型。这样既不打断当前句，也能从当前句句首开始循环。
  void _maybeHandoffFromGapless(bool sentenceChanged) {
    if (!sentenceChanged) return;
    if (!_pendingPlaybackModeHandoff) return;
    if (_activeSentenceDrivenPlayback) return;
    if (!_usesSentenceDrivenPlayback) return;

    // 位置流已把高亮推进到下一句；把真相源恢复为“刚播完的当前句”，随后从该句句首
    // 切入 clip 循环。收藏模式本来就是句级驱动，不会走到这里。
    final current = state.currentFullIndex;
    if (current != null && current > 0) {
      state = state.copyWith(
        currentFullIndex: current - 1,
        lastPlayedFullIndex: current - 1,
      );
    }

    _pendingPlaybackModeHandoff = false;
    unawaited(_startCurrent());
  }

  /// 从句级 clip 模式自然交接回 gapless。
  ///
  /// 当前 clip 已正常播放完成，随后根据 reducer 给出的结果决定是停止、回卷还是去下
  /// 一句。交接时保留“当前是播放态”的事实，只更换底层驱动模型。
  Future<void> _handoffFromSentenceDriven(
    NextAction action,
    int gen,
    int sid,
  ) async {
    switch (action) {
      case StopPlayback():
        _activeSentenceDrivenPlayback = false;
        _setLogicalPlaying(false);
        await _engine.stop();
        return;
      case ReplayCurrent():
        // 仅在单句循环开启时才可能出现；防御性兜底，保持当前句重播。
        _pendingPlaybackModeHandoff = false;
        return;
      case GoToPosition(:final position, :final pauseBefore):
        await _delayInterval(pauseBefore);
        if (gen != _playbackGen || !_engine.isActiveSession(sid)) return;
        if (_currentPos != null &&
            position == 0 &&
            _currentPos == _playable.length - 1) {
          _wholeLoopsDone += 1;
        }
        // 切回 gapless 整篇循环模型：从目标句句首起播确定性循环，保留已完成遍数。
        await _startWholeDriven(startPos: position, resetCounters: false);
    }
  }

  void _setCurrentFromSentence(Sentence sentence) {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      if (state.currentBookmarkIndex != sentence.index ||
          state.lastPlayedBookmarkIndex != sentence.index) {
        state = state.copyWith(
          currentBookmarkIndex: sentence.index,
          lastPlayedBookmarkIndex: sentence.index,
        );
      }
    } else {
      if (state.currentFullIndex != sentence.index ||
          state.lastPlayedFullIndex != sentence.index) {
        state = state.copyWith(
          currentFullIndex: sentence.index,
          lastPlayedFullIndex: sentence.index,
        );
      }
    }
  }

  /// 按给定间隔停顿（来自 reducer 的决策，区分单句/整篇间隔）。
  Future<void> _delayInterval(Duration interval) async {
    if (interval > Duration.zero) {
      await Future.delayed(interval);
    }
  }

  // ===========================================================================
  // 加载音频
  // ===========================================================================

  Future<void> loadAudio(
    AudioItem audioItem, {
    bool forceTranscriptReload = false,
  }) async {
    // 同一音频且字幕未变化时跳过。
    if (!forceTranscriptReload &&
        state.currentAudioItem?.id == audioItem.id &&
        state.currentAudioItem?.transcriptPath == audioItem.transcriptPath &&
        state.currentAudioItem?.transcriptSource ==
            audioItem.transcriptSource) {
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        return _loadingCompleter!.future;
      }
      return;
    }

    _loadingCompleter = Completer<void>();
    state = state.copyWith(isLoading: true);

    try {
      await stop();
      // 换音频：清空循环计数并作废在途播放任务。
      _sentenceRepeatsDone = 0;
      _wholeLoopsDone = 0;
      _playbackGen++;
      _activeSentenceDrivenPlayback = false;
      _pendingPlaybackModeHandoff = false;

      state = state.copyWith(
        currentAudioItem: audioItem,
        sentences: [],
        clearCurrentFullIndex: true,
        clearCurrentBookmarkIndex: true,
        // 循环开关是「现在想刷这条」的临时意图，加载新音频时一律重置为关
        // （仅改内存，不持久化）；循环参数作为偏好保留。
        fullSettings: state.fullSettings.copyWith(
          loopWhole: false,
          loopSentence: false,
        ),
        bookmarkSettings: withBookmarkLoopDefaults(state.bookmarkSettings),
      );

      try {
        await _engine.loadAudio(audioItem, state.settings.playbackSpeed);
      } catch (e) {
        AppLogger.log('Player', '✗ 音频文件加载失败: $e');
        state = state.copyWith(clearCurrentAudioItem: true);
        rethrow;
      }

      final sentences = await _engine.loadTranscript(audioItem);

      final bookmarkDao = ref.read(bookmarkDaoProvider);
      final storedBookmarks = await BookmarkManager.loadBookmarks(
        audioItem.id,
        dao: bookmarkDao,
      );
      var bookmarkedIndices = Set<int>.from(storedBookmarks);

      final isFirstLoad = storedBookmarks.isEmpty;
      if (isFirstLoad) {
        final autoBookmarks = BookmarkManager.autoAddBracketBookmarks(
          sentences,
        );
        bookmarkedIndices = {...bookmarkedIndices, ...autoBookmarks};

        if (autoBookmarks.isNotEmpty) {
          for (final idx in autoBookmarks) {
            await BookmarkManager.addBookmarkToDb(
              audioItem.id,
              sentences[idx],
              dao: bookmarkDao,
            );
          }
        }
      }

      // 清理 [] 包裹的句子文本
      final cleanedSentences = <Sentence>[];
      for (int i = 0; i < sentences.length; i++) {
        final text = sentences[i].text.trim();
        if (text.startsWith('[') && text.endsWith(']') && text.length > 2) {
          cleanedSentences.add(
            sentences[i].copyWith(
              text: text.substring(1, text.length - 1).trim(),
            ),
          );
        } else {
          cleanedSentences.add(sentences[i]);
        }
      }

      for (var sentence in cleanedSentences) {
        sentence.isBookmarked = bookmarkedIndices.contains(sentence.index);
      }

      state = state.copyWith(
        sentences: cleanedSentences,
        bookmarkedIndices: bookmarkedIndices,
        currentFullIndex: 0,
      );

      await _restorePlaybackState(audioItem);

      if (state.sentences.isNotEmpty && state.currentFullIndex == null) {
        state = state.copyWith(currentFullIndex: 0);
        await _engine.seek(state.sentences[0].startTime);
      }
    } catch (e) {
      AppLogger.log('Player', '✗ loadAudio 失败: $e');
      state = state.copyWith(clearCurrentAudioItem: true);
    } finally {
      state = state.copyWith(isLoading: false);
      if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
        _loadingCompleter!.complete();
      }
    }
  }

  Future<void> _restorePlaybackState(AudioItem audioItem) async {
    final playbackStateDao = ref.read(playbackStateDaoProvider);
    final result = await PlaybackStateStorage.loadPlaybackState(
      audioItem.id,
      dao: playbackStateDao,
    );
    if (result == null) return;

    try {
      if (result.playlistMode != null) {
        state = state.copyWith(playlistMode: result.playlistMode);
      }
      if (result.position != null) {
        await _engine.seek(result.position!);
        // 从恢复位置反推当前句高亮
        final idx = SentenceTracker.findSentenceIndexByPosition(
          state.sentences,
          result.position!,
        );
        if (idx != -1) {
          state = state.copyWith(currentFullIndex: idx);
        }
      }
      AppLogger.log('Player', '✓ 恢复播放状态: ${audioItem.name}');
    } catch (e) {
      AppLogger.log('Player', '⚠ 恢复播放状态失败: $e');
    }
  }

  // ===========================================================================
  // 播放控制
  // ===========================================================================

  /// 主播放按钮：按当前模式起播。
  ///
  /// 普通全文播放走 gapless；单句循环/收藏模式走句级 clip。暂停后仅 gapless 可从精确
  /// position 续播，句级模式始终按当前句重新起播，避免 clip 相对位置造成错位。
  Future<void> play() async {
    if (state.currentAudioItem == null) return;

    if (state.sentences.isEmpty) {
      _setLogicalPlaying(true);
      await _engine.play();
      return;
    }

    _ensureValidIndex();
    if (state.playlistMode == PlaylistMode.bookmarks &&
        state.bookmarkedSentences.isEmpty) {
      return;
    }

    if (_awaitingReplayFromStart) {
      await _restartFromPlayableBeginning();
      return;
    }

    if (!_usesSentenceDrivenPlayback &&
        _engine.isActiveSession(_playbackSessionId)) {
      final ps = _engine.processingState;
      final resumable =
          ps != ja.ProcessingState.completed &&
          ps != ja.ProcessingState.idle &&
          _engine.currentPosition > Duration.zero;
      if (resumable) {
        // 从暂停的精确位置续播：重新拉起整篇确定性循环，保留已完成遍数，
        // 不 seek、不清零，使续播后仍能正确地播满剩余遍数。
        await _startWholeDriven(resetCounters: false);
        return;
      }
    }

    await _startCurrent();
  }

  /// 已播完后再次点击主播放按钮：从当前播放列表开头重新开始。
  ///
  /// 全文 Tab 从第 1 句开始；收藏 Tab 从收藏子集第 1 句开始。当前高亮在结束态下
  /// 保持停在结尾，只有用户显式再次播放时才回到列表开头。
  Future<void> _restartFromPlayableBeginning() async {
    final playable = _playable;
    if (playable.isEmpty) return;

    final first = playable.first.index;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: first,
        lastPlayedBookmarkIndex: first,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: first,
        lastPlayedFullIndex: first,
      );
    }
    await _startCurrent();
  }

  /// 从当前真相源 index 起播（全新 session）。
  Future<void> _startCurrent() async {
    final playable = _playable;
    if (playable.isEmpty) return;

    if (_usesSentenceDrivenPlayback) {
      final gen = ++_playbackGen;
      _awaitingReplayFromStart = false;
      _activeSentenceDrivenPlayback = true;
      _pendingPlaybackModeHandoff = false;
      _sentenceRepeatsDone = 0;
      _wholeLoopsDone = 0;
      _playbackSessionId = _engine.newSession();
      _setLogicalPlaying(true);
      unawaited(_playSentenceDriven(gen, _playbackSessionId));
    } else {
      // 整篇连续播放：从当前句句首起播确定性循环，清零遍数。
      await _startWholeDriven(startPos: _currentPos ?? 0, resetCounters: true);
    }
  }

  void _ensureValidIndex() {
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    } else {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        state = state.copyWith(currentFullIndex: 0);
      }
    }
  }

  Future<void> pause() async {
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    _setLogicalPlaying(false);
    await _engine.pause();
    // 引擎 pause 会自增 session 以失效在途回调；LP 仍是这个「已暂停引擎」的拥有者，
    // 故认领当前 session，使随后的 play() 能从精确暂停位置续播。若期间被讲解页等
    // 外来 session 顶掉，认领失效，play() 会按真相源 index 重新起播。
    _playbackSessionId = _engine.currentSessionId;
  }

  Future<void> stop() async {
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    _setLogicalPlaying(false);
    await _engine.stop();
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
  }

  /// 离开讲解页返回后，把共享引擎显式对齐回当前句起点。
  ///
  /// 讲解页旁路驱动并 stop 了引擎，会改写 clip/position。返回后调用本方法清除
  /// clip、seek 回当前句起点并认领 session，使主播放按钮从「原来的句子」继续，
  /// 而不依赖对引擎残留位置的启发式判断。
  Future<void> restorePosition() async {
    if (state.currentAudioItem == null) return;
    if (_currentPos == null) return;
    await _alignEngineToCurrent();
    _wholeLoopsDone = 0;
  }

  /// 进度条任意位置拖动：seek 到任意时间并从落点继续。
  ///
  /// 普通全文播放可从精确落点续播；句级 clip 模式需要按落点所在句/最近收藏句重新
  /// 起播，确保循环计数和 clip 边界从新句开始。
  Future<void> seekAbsolute(Duration absolutePosition) async {
    if (state.sentences.isEmpty) {
      await _engine.clearClip();
      await _engine.seek(absolutePosition);
      return;
    }

    final wasPlaying = _engine.isPlaying;
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;

    Duration target = absolutePosition;
    final globalIdx = SentenceTracker.findSentenceIndexByPosition(
      state.sentences,
      absolutePosition,
    );

    if (state.playlistMode == PlaylistMode.bookmarks) {
      final playable = _playable;
      if (playable.isEmpty) return;
      var pos = playable.indexWhere((s) => s.index == globalIdx);
      if (pos == -1) {
        final closest = SentenceTracker.findClosestBookmark(
          playable,
          absolutePosition,
        );
        pos = closest == null
            ? 0
            : playable.indexWhere((s) => s.index == closest);
        if (pos < 0) pos = 0;
      }
      final selected = playable[pos];
      state = state.copyWith(
        currentBookmarkIndex: selected.index,
        lastPlayedBookmarkIndex: selected.index,
      );
      target = selected.startTime;
    } else if (globalIdx != -1) {
      state = state.copyWith(
        currentFullIndex: globalIdx,
        lastPlayedFullIndex: globalIdx,
      );
    }

    if (wasPlaying && state.playlistMode == PlaylistMode.bookmarks) {
      _sentenceRepeatsDone = 0;
      _wholeLoopsDone = 0;
      await _startCurrent();
      return;
    }

    if (wasPlaying) await _engine.pauseKeepSession();
    await _engine.clearClip();

    await _engine.seek(target);
    _sentenceRepeatsDone = 0;
    _wholeLoopsDone = 0;

    if (wasPlaying) {
      if (_usesSentenceDrivenPlayback) {
        await _startCurrent();
      } else {
        // 整篇连续播放：从落点起播确定性循环（不再裸 play，否则播完无人接管循环）。
        await _startWholeDriven(resetCounters: false);
      }
    } else {
      _setLogicalPlaying(false);
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  /// 未播放时把引擎对齐到当前真相源句的起点。
  Future<void> _alignEngineToCurrent() async {
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    _setLogicalPlaying(false);
    _sentenceRepeatsDone = 0;
    final pos = _currentPos;
    await _engine.clearClip();
    if (pos != null) {
      await _engine.seek(_playable[pos].startTime);
    }
    _playbackSessionId = _engine.currentSessionId;
  }

  Future<void> selectFullSentence(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(currentFullIndex: index, lastPlayedFullIndex: index);

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> selectBookmarkedSentence(
    int index, {
    bool autoPlay = true,
  }) async {
    if (index < 0 || index >= state.sentences.length) return;

    state = state.copyWith(
      currentBookmarkIndex: index,
      lastPlayedBookmarkIndex: index,
    );

    if (autoPlay) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> replayCurrentSentence() async {
    if (state.sentences.isEmpty) return;

    final int? lastPlayedIndex = state.playlistMode == PlaylistMode.bookmarks
        ? state.lastPlayedBookmarkIndex
        : state.lastPlayedFullIndex;
    if (lastPlayedIndex == null) return;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(currentBookmarkIndex: lastPlayedIndex);
    } else {
      state = state.copyWith(currentFullIndex: lastPlayedIndex);
    }
    await _startCurrent();
  }

  Future<void> nextSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos == -1) {
        pos = 0;
      } else if (pos >= bookmarked.length - 1) {
        return;
      } else {
        pos++;
      }
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! >= state.sentences.length - 1) {
        return;
      } else {
        newIndex = state.currentFullIndex! + 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  Future<void> previousSentence() async {
    if (state.sentences.isEmpty) return;

    late int newIndex;
    if (state.playlistMode == PlaylistMode.bookmarks) {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) return;

      int pos = bookmarked.indexWhere(
        (s) => s.index == state.currentBookmarkIndex,
      );
      if (pos <= 0) return;
      pos--;
      newIndex = bookmarked[pos].index;
    } else {
      if (state.currentFullIndex == null) {
        newIndex = 0;
      } else if (state.currentFullIndex! <= 0) {
        return;
      } else {
        newIndex = state.currentFullIndex! - 1;
      }
    }

    await _moveToIndex(newIndex);
  }

  /// 上/下一句的公共落地：更新真相源 index，播放中则起播该句，否则对齐引擎。
  Future<void> _moveToIndex(int newIndex) async {
    final wasPlaying = _engine.isPlaying;

    if (state.playlistMode == PlaylistMode.bookmarks) {
      state = state.copyWith(
        currentBookmarkIndex: newIndex,
        lastPlayedBookmarkIndex: newIndex,
      );
    } else {
      state = state.copyWith(
        currentFullIndex: newIndex,
        lastPlayedFullIndex: newIndex,
      );
    }

    if (wasPlaying) {
      await _startCurrent();
    } else {
      await _alignEngineToCurrent();
    }
  }

  Future<void> toggleBookmark(int index) async {
    final (
      isRemoving,
      indicesToRemove,
      nextIndex,
    ) = BookmarkManager.toggleBookmark(
      index,
      state.sentences,
      state.bookmarkedIndices,
      state.playlistMode == PlaylistMode.bookmarks,
    );

    // 埋点：收藏/取消收藏句子
    if (state.currentAudioItem != null) {
      final item = state.currentAudioItem!;
      final analyticsParams = {
        EventParams.audioId: item.id,
        EventParams.audioName: item.name,
        EventParams.sentenceIndex: index,
        EventParams.action: isRemoving ? 'remove' : 'add',
      };
      if (!isRemoving) {
        await ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.bookmarkSentenceSaved,
              analyticsParams: analyticsParams,
            );
      } else {
        ref
            .read(analyticsServiceProvider)
            .track(Events.bookmarkToggle, analyticsParams);
      }
    }

    // 价值锚点：只在「添加收藏」时尝试触发通知权限 pre-prompt
    if (!isRemoving) {
      unawaited(
        ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
      );
    }

    final inBookmarksMode = state.playlistMode == PlaylistMode.bookmarks;
    final shouldResume =
        inBookmarksMode && _engine.isPlaying && nextIndex != null;

    if (inBookmarksMode && isRemoving && _engine.isPlaying) {
      await pause();
    }

    var newBookmarks = Set<int>.from(state.bookmarkedIndices);
    var newSentences = List<Sentence>.from(state.sentences);

    if (isRemoving) {
      final toRemove = indicesToRemove.isEmpty ? {index} : indicesToRemove;
      for (final idx in toRemove) {
        newBookmarks.remove(idx);
        if (idx >= 0 && idx < newSentences.length) {
          newSentences[idx] = newSentences[idx].copyWith(isBookmarked: false);
        }
      }

      if (inBookmarksMode) {
        if (nextIndex != null && nextIndex < newSentences.length) {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            currentBookmarkIndex: nextIndex,
          );
        } else {
          state = state.copyWith(
            bookmarkedIndices: newBookmarks,
            sentences: newSentences,
            clearCurrentBookmarkIndex: true,
          );
          await _engine.clearClip();
          await stop();
        }
      } else {
        state = state.copyWith(
          bookmarkedIndices: newBookmarks,
          sentences: newSentences,
        );
      }
    } else {
      newBookmarks.add(index);
      newSentences[index] = newSentences[index].copyWith(isBookmarked: true);
      state = state.copyWith(
        bookmarkedIndices: newBookmarks,
        sentences: newSentences,
      );
    }

    if (state.currentAudioItem != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      if (isRemoving) {
        await BookmarkManager.removeBookmarksFromDb(
          state.currentAudioItem!.id,
          indicesToRemove,
          dao: bookmarkDao,
        );
      } else {
        await BookmarkManager.addBookmarkToDb(
          state.currentAudioItem!.id,
          state.sentences[index],
          dao: bookmarkDao,
        );
      }
    }

    // 收藏模式下移除当前句后，从下一收藏句继续播放
    if (inBookmarksMode &&
        shouldResume &&
        state.bookmarkedSentences.isNotEmpty) {
      await _startCurrent();
    }
  }

  Future<void> updateSettings(PlaybackSettings newSettings) async {
    final wasPlaying = _engine.isPlaying;
    final desiredSentenceDriven =
        state.playlistMode == PlaylistMode.bookmarks ||
        newSettings.loopSentence;

    state = state.copyWith(settings: newSettings);
    await _engine.setSpeed(newSettings.playbackSpeed);
    await StorageService.saveSettings(
      ListeningPracticeSettingsStore(
        full: state.fullSettings,
        bookmark: state.bookmarkSettings,
      ),
    );

    // 单句循环开关切换不应打断当前播放态：播放中只记录“自然句边界后再交接模型”，
    // 暂停时仅更新设置。这样可以避免突然跳句首或在暂停态被意外拉起播放。
    if (wasPlaying && _activeSentenceDrivenPlayback != desiredSentenceDriven) {
      _pendingPlaybackModeHandoff = true;
    }
  }

  Future<void> setPlaylistMode(PlaylistMode mode) async {
    if (state.playlistMode == mode) return;

    await stop();

    state = state.copyWith(playlistMode: mode);
    await _engine.setSpeed(state.settings.playbackSpeed);

    if (mode == PlaylistMode.full) {
      if (state.currentFullIndex == null ||
          state.currentFullIndex! >= state.sentences.length) {
        if (state.sentences.isNotEmpty) {
          state = state.copyWith(currentFullIndex: 0);
        }
      }
    } else {
      final bookmarked = state.bookmarkedSentences;
      if (bookmarked.isEmpty) {
        await _engine.clearClip();
        return;
      }
      if (state.currentBookmarkIndex == null ||
          !state.bookmarkedIndices.contains(state.currentBookmarkIndex)) {
        state = state.copyWith(currentBookmarkIndex: bookmarked.first.index);
      }
    }

    // 切 Tab 的语义是“结束上一个 Tab 的播放上下文”，因此无论切换前是否正在播，
    // 都只对齐新 Tab 的当前位置，不自动续播。
    await _alignEngineToCurrent();
  }

  /// 重置播放位置到开头（供外部学习流程调用）
  void resetToBeginning() {
    if (state.sentences.isNotEmpty) {
      state = state.copyWith(currentFullIndex: 0);
    }
  }

  Future<void> saveCurrentPlaybackState({bool silent = false}) async {
    if (state.currentAudioItem == null) return;

    final playbackStateDao = ref.read(playbackStateDaoProvider);
    await PlaybackStateStorage.savePlaybackState(
      state.currentAudioItem!,
      _engine.absoluteCurrentPosition,
      state,
      dao: playbackStateDao,
      silent: silent,
    );
  }

  /// 跨句时触发的轻量进度保存（fire-and-forget，不阻塞位置流回调）。
  ///
  /// 与 [deactivate] 时的保存共用同一持久化路径，把保存频率从「仅退出页面一次」
  /// 提升到「每跨一句」，使进程被系统强杀/崩溃时最多丢一句的进度。
  /// [_autoSaving] 护栏避免上一次写入未完成时重复写库。
  void _autoSaveProgress() {
    if (_autoSaving) return;
    if (state.currentAudioItem == null) return;
    _autoSaving = true;
    saveCurrentPlaybackState(silent: true)
        .catchError((Object e) => AppLogger.log('Player', '⚠ 跨句自动保存进度失败: $e'))
        .whenComplete(() => _autoSaving = false);
  }
}

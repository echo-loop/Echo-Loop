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
import '../collection_provider.dart';
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
  StreamSubscription<ja.PlayerState>? _playerStateSub;
  bool _listenersAttached = false;
  int _listenerSetupToken = 0;

  /// 追踪正在进行的音频加载，避免重复调用时跳过未完成的加载
  Completer<void>? _loadingCompleter;

  /// 当前句已完成播放的次数（含刚结束这次）。进新句时归零。
  ///
  /// 写入统一经由下面的 setter 镜像到 [ListeningPracticeState.sentenceRepeatsDone]，
  /// 供状态栏展示「当前句第几遍」。
  int _sentenceRepeatsDoneBacking = 0;
  int get _sentenceRepeatsDone => _sentenceRepeatsDoneBacking;
  set _sentenceRepeatsDone(int value) {
    _sentenceRepeatsDoneBacking = value;
    if (state.sentenceRepeatsDone != value) {
      state = state.copyWith(sentenceRepeatsDone: value);
    }
  }

  /// 整篇已完成的遍数。换音频/重新起播时归零。
  ///
  /// gapless 整段自然播完即 +1；监听句尾模式下走到末尾并回到第 0 句时 +1。
  /// 写入统一经由下面的 setter 镜像到 [ListeningPracticeState.wholeLoopsDone]，
  /// 供状态栏展示「当前第几遍」，避免各写入点散落地同步 UI。
  int _wholeLoopsDoneBacking = 0;
  int get _wholeLoopsDone => _wholeLoopsDoneBacking;
  set _wholeLoopsDone(int value) {
    _wholeLoopsDoneBacking = value;
    if (state.wholeLoopsDone != value) {
      state = state.copyWith(wholeLoopsDone: value);
    }
  }

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

  /// 「当前句自然播完后暂停」请求。点击解析/翻译/意群工具栏按钮时置位，避免打断
  /// 当前朗读：句级循环在 clip 边界、整篇 gapless 在句边界消费它，暂停后停在用户
  /// 点击的句子，续播时按记住的遍数/位置继续。任何立即起播/暂停入口都会清零它。
  bool _pauseAfterCurrentSentence = false;

  /// 句级循环被暂停、等待续播时按记住的遍数继续（不回第一遍）。
  ///
  /// 立即暂停（主播放按钮）与延迟暂停（解析工具栏）都会置位；[play] 消费后从当前句
  /// 续播并保留计数。换句/seek/stop 等「全新起播」入口会清零它。
  bool _sentenceLoopResumePending = false;

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

  /// 缓存的 AudioEngine 引用，仅用于 [_disposeListeners] 中清空锁屏切句回调。
  ///
  /// provider 销毁阶段不能再 `ref.read` 其他 provider（会抛 already disposed）；
  /// 而 audioEngineProvider 是 keepAlive，notifier 实例在 LP 销毁后仍有效，故在
  /// setup 时（ref 可读）缓存下来，dispose 时直接用缓存清空回调。
  AudioEngine? _cachedEngineForSkip;

  /// 解析音频所属合集名（取第一个），用作锁屏标题下方副标题。
  ///
  /// 与顶栏副标题同源：按 [collectionListProvider] 的 audioToCollectionsMap
  /// 反查，按已排序的 collections 顺序取首个命中。无所属合集时返回 null。
  String? _resolveCollectionName(String audioId) {
    final cs = ref.read(collectionListProvider);
    final ids = cs.audioToCollectionsMap[audioId];
    if (ids == null || ids.isEmpty) return null;
    final idSet = ids.toSet();
    for (final c in cs.collections) {
      if (idSet.contains(c.id)) return c.name;
    }
    return null;
  }

  void _setupListeners() {
    if (_listenersAttached) return;
    // 在 build/resume 阶段（ref 可读）缓存引擎引用，供 dispose 时清空回调。
    _cachedEngineForSkip = _engine;
    // defer listener setup to after first build；token 用于作废 suspend/dispose 之后尚未执行
    // 的旧 microtask，避免“先 suspend 再 resume”时旧任务回流重复挂订阅。
    final setupToken = ++_listenerSetupToken;
    Future.microtask(() {
      if (setupToken != _listenerSetupToken || _listenersAttached) return;
      _positionSub = _engine.absolutePositionStream.listen(_onPositionChanged);
      _playerStateSub = _engine.playerStateStream.listen(_onPlayerStateChanged);
      _listenersAttached = true;
      // 接管共享引擎时注册锁屏控制回调，使锁屏控件走 controller 同一套业务逻辑。
      _applyLockScreenHandlers();
    });
  }

  /// 按当前音频是否有字幕注册锁屏控制回调。
  ///
  /// 播放/暂停回调始终注册；有字幕注册「上一句/下一句」、清空相对 seek；无字幕注册
  /// 「后退/前进 10 秒」、清空切句。在 [_setupListeners] 与 [loadAudio]（字幕就绪后）
  /// 各调一次，使锁屏按钮形态随当前音频是否有字幕切换。
  void _applyLockScreenHandlers() {
    _engine.setTransportHandlers(onPlay: play, onPause: pause);
    if (state.hasSentences) {
      _engine.setSkipHandlers(
        onPrevious: previousSentence,
        onNext: nextSentence,
      );
      _engine.setSeekHandlers(onRewind: null, onFastForward: null);
    } else {
      _engine.setSkipHandlers(onPrevious: null, onNext: null);
      _engine.setSeekHandlers(
        onRewind: () => seekRelative(const Duration(seconds: -10)),
        onFastForward: () => seekRelative(const Duration(seconds: 10)),
      );
    }
  }

  void _disposeListeners() {
    _listenerSetupToken += 1;
    _positionSub?.cancel();
    _positionSub = null;
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _listenersAttached = false;
    // 用缓存引用清空，避免在 provider 销毁阶段 ref.read 抛 already disposed。
    _cachedEngineForSkip?.setSkipHandlers(onPrevious: null, onNext: null);
    _cachedEngineForSkip?.setSeekHandlers(onRewind: null, onFastForward: null);
    _cachedEngineForSkip?.setTransportHandlers(onPlay: null, onPause: null);
  }

  /// 暂停 stream 监听（学习模式期间调用，避免 LP 接管共享引擎）。
  void suspendListeners() {
    _listenerSetupToken += 1;
    _positionSub?.cancel();
    _positionSub = null;
    _playerStateSub?.cancel();
    _playerStateSub = null;
    _listenersAttached = false;
    // LP 不再驱动引擎时一并撤销锁屏回调，避免学习模式下误触。
    _engine.setSkipHandlers(onPrevious: null, onNext: null);
    _engine.setSeekHandlers(onRewind: null, onFastForward: null);
    _engine.setTransportHandlers(onPlay: null, onPause: null);
  }

  /// 恢复 stream 监听（退出学习模式时调用）
  void resumeListeners() {
    _setupListeners();
  }

  /// Free Player 重新认领锁屏控制（自愈）。
  ///
  /// 学习/复习任务（含 learning_session 之外的收藏句复习、闪卡）会接管全局回调槽并在
  /// 离开时置 null。PlayerScreen 每次进入时调用此方法，使 Free Player 无条件夺回锁屏：
  /// 已挂监听则只重注册回调，未挂则补挂监听并注册。同时清除任何任务残留的逻辑播放态
  /// 覆盖与静音保活，保证 Free Player 回到「读裸 player.playing、不保活」的原始行为。
  void reattachLockScreen() {
    if (_listenersAttached) {
      _applyLockScreenHandlers();
    } else {
      _setupListeners();
    }
    _engine.setLogicalPlaying(null);
    unawaited(_engine.stopKeepAlive());
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
    // 延迟暂停：记下推进前的当前句，跨句边界即「当前句已播完」。
    final indexBeforeAdvance = state.currentFullIndex;
    final sentenceChanged = _updateHighlight(absolutePosition);
    if (sentenceChanged &&
        _pauseAfterCurrentSentence &&
        indexBeforeAdvance != null) {
      _pauseAfterCurrentSentence = false;
      unawaited(_pauseGaplessHoldingSentence(indexBeforeAdvance));
      return;
    }
    _maybeHandoffFromGapless(sentenceChanged);
  }

  /// 系统媒体会话/锁屏/耳机按钮可能绕过页面直接改变底层播放器状态。
  ///
  /// Free Player 的按钮图标和控制器逻辑不能只看“自己是否主动调用了 pause/play”，
  /// 必须把这类被动状态同步回 provider，避免锁屏后音频已停、按钮仍显示暂停图标。
  void _onPlayerStateChanged(ja.PlayerState playerState) {
    if (!_engine.isActiveSession(_playbackSessionId)) return;

    if (!playerState.playing && state.isPlaying) {
      _setLogicalPlaying(false);
      _pendingPlaybackModeHandoff = false;
      if (_activeSentenceDrivenPlayback) {
        _sentenceLoopResumePending = true;
        _activeSentenceDrivenPlayback = false;
      }
      return;
    }

    // completed 时 just_audio 的 `playing` 仍为 true（见 §7.6），但这并非「系统恢复
    // 了播放」。自然播完后保留媒体会话（pauseKeepSession，不再 stop/不 bump session），
    // 这条 completed 事件会到达本监听；若不排除，会把刚置 false 的逻辑播放态又翻回
    // true（图标误显暂停）。故 completed 一律不驱动逻辑播放态为 true。
    if (playerState.playing &&
        !state.isPlaying &&
        playerState.processingState != ja.ProcessingState.completed) {
      _setLogicalPlaying(true);
      if (_sentenceLoopResumePending && _usesSentenceDrivenPlayback) {
        _activeSentenceDrivenPlayback = true;
        _sentenceLoopResumePending = false;
      }
    }
  }

  /// 整篇 gapless 下「当前句播完后暂停」：回到刚播完的句子句首暂停，使解析/翻译面板
  /// 停留在用户点击的句子上（而非随高亮滑到下一句），续播时从本句继续。
  Future<void> _pauseGaplessHoldingSentence(int finishedIndex) async {
    _playbackGen++;
    _pendingPlaybackModeHandoff = false;
    _setLogicalPlaying(false);
    if (finishedIndex >= 0 && finishedIndex < state.sentences.length) {
      state = state.copyWith(
        currentFullIndex: finishedIndex,
        lastPlayedFullIndex: finishedIndex,
      );
      await _engine.pauseKeepSession();
      await _engine.seek(state.sentences[finishedIndex].startTime);
    } else {
      await _engine.pauseKeepSession();
    }
    _playbackSessionId = _engine.currentSessionId;
    _autoSaveProgress();
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
  /// [resetWholeLoops] 清零整篇遍数；[resetSentenceRepeats] 清零单句遍数。两者分开
  /// 控制：全新起播两者都清；播放中切上一句/下一句只清单句遍数、保留整篇遍数（切句是
  /// 「同一遍内换句」而非重新开始整篇循环）。
  Future<void> _startWholeDriven({
    int? startPos,
    bool resetWholeLoops = false,
    bool resetSentenceRepeats = false,
  }) async {
    final playable = _playable;
    if (playable.isEmpty) return;

    final gen = ++_playbackGen;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    if (resetWholeLoops) _wholeLoopsDone = 0;
    if (resetSentenceRepeats) _sentenceRepeatsDone = 0;
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
          'startPos=${startPos ?? '续播(当前位置)'} '
          'resetWhole=$resetWholeLoops resetSentence=$resetSentenceRepeats',
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
          '⏹ 整篇循环结束（已播满 $_wholeLoopsDone 遍）→ 暂停保留会话，等待用户重播',
        );
        _awaitingReplayFromStart = true;
        _setLogicalPlaying(false);
        // 不 stop：保留媒体会话与锁屏 Now Playing（暂停态），用户可在锁屏直接重播。
        // 须 pause 底层播放器使其 playing=false——自然播完后 just_audio 的 playing
        // 仍为 true，不 pause 会让锁屏图标停在「暂停」（误显播放中）。
        await _engine.pauseKeepSession();
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

  /// 引擎当前位置是否已到（或极接近）音频结尾。
  ///
  /// 恢复进入时存档位置可能正好停在结尾，此时 just_audio 的 processingState 仍是
  /// `ready`（非 `completed`，completed 只在本 session 内真正播到尾才触发），不能据
  /// completed 区分「中途暂停续播」与「停在结尾的全新恢复」。用位置接近总时长来识别，
  /// 使后者被当作从头重播而非从结尾续播（否则首次点击会从结尾起播立即结束）。
  bool _isAtAudioEnd() {
    final total = _engine.totalDuration;
    if (total == null || total <= Duration.zero) return false;
    return _engine.currentPosition >= total - const Duration(milliseconds: 200);
  }

  /// 无字幕音频起播：用确定性 await-完成循环驱动，使「自然播完→停在暂停态」和
  /// 「播完后再播→从头开始」都成立。
  ///
  /// 关键在于必须 [AudioEngine.newSession] 并认领 `_playbackSessionId`——否则
  /// `_onPositionChanged`/`_onPlayerStateChanged` 的 session 校验对无字幕永远失败，
  /// 被动状态同步（含锁屏被动暂停回写）全部失效。
  Future<void> _startNoTranscriptPlayback() async {
    final gen = ++_playbackGen;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    _pauseAfterCurrentSentence = false;
    _sentenceLoopResumePending = false;
    _playbackSessionId = _engine.newSession();
    await _engine.clearClip();

    // 区分「续播」与「全新起播 / 播完重播」：续播从精确位置继续并保留整篇遍数；
    // 否则回到开头并清零遍数。just_audio 对已 completed 的播放器 play() 不会自动
    // 回头，全新/重播必须显式 seek(0)。
    final ps = _engine.processingState;
    final resuming =
        !_awaitingReplayFromStart &&
        !_isAtAudioEnd() &&
        ps != ja.ProcessingState.completed &&
        ps != ja.ProcessingState.idle &&
        _engine.currentPosition > Duration.zero;
    if (!resuming) {
      await _engine.seek(Duration.zero);
      _wholeLoopsDone = 0;
    }
    _awaitingReplayFromStart = false;
    _setLogicalPlaying(true);
    unawaited(_playNoTranscriptDriven(gen, _playbackSessionId));
  }

  /// 无字幕整段播放的确定性循环。
  ///
  /// 每遍 `await` [AudioEngine.playToEnd] 播到自然结束后用 [shouldLoopWhole] 决定
  /// 回卷重播还是停止；遍数在协程内自增，对 just_audio 重复/滞后的 `completed`
  /// 事件免疫。`loopWhole == false` 时第一遍后即停止。自然结束（停止）保留媒体会话
  /// 并停在暂停态，`_awaitingReplayFromStart` 使下次 play() 从头重播。
  Future<void> _playNoTranscriptDriven(int gen, int sid) async {
    while (gen == _playbackGen && _engine.isActiveSession(sid)) {
      await _engine.playToEnd(sid);
      if (gen != _playbackGen || !_engine.isActiveSession(sid)) return;

      _wholeLoopsDone += 1;
      _autoSaveProgress();

      final s = state.settings;
      if (!shouldLoopWhole(s.loopWhole, s.wholeLoopCount, _wholeLoopsDone)) {
        _awaitingReplayFromStart = true;
        _setLogicalPlaying(false);
        // 不 stop：保留媒体会话与锁屏 Now Playing（暂停态），用户可在锁屏直接重播。
        await _engine.pauseKeepSession();
        return;
      }

      await _delayInterval(s.wholeInterval);
      if (gen != _playbackGen || !_engine.isActiveSession(sid)) return;

      // 回卷到开头继续下一遍。
      await _engine.seek(Duration.zero);
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

      // 解析/翻译/意群触发的延迟暂停：当前 clip 已自然播完，停在本句暂停，
      // 不再推进循环；遍数与位置保留，续播时从记住的进度继续。
      if (_pauseAfterCurrentSentence) {
        _pauseAfterCurrentSentence = false;
        _activeSentenceDrivenPlayback = false;
        _pendingPlaybackModeHandoff = false;
        _sentenceLoopResumePending = true;
        _setLogicalPlaying(false);
        await _engine.pause();
        _playbackSessionId = _engine.currentSessionId;
        return;
      }

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
          // 同整篇结束：保留媒体会话，锁屏控件停在暂停态供用户重播。
          await _engine.pauseKeepSession();
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
    if (_playable.isEmpty) return;
    // 整篇 gapless 中途开启单句循环：交接到句级循环，保留整篇已播遍数，
    // 只重置当前句的单句遍数——两套循环状态互不影响。
    _launchSentenceDriven(resetWholeLoops: false, resetSentenceRepeats: true);
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
        await _startWholeDriven(startPos: position);
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
        await _engine.loadAudio(
          audioItem,
          state.settings.playbackSpeed,
          subtitle: _resolveCollectionName(audioItem.id),
        );
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
      // 字幕已就绪：按是否有字幕重新注册锁屏控制（无字幕用后退/前进 10 秒替代切句）。
      if (_listenersAttached) _applyLockScreenHandlers();
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
      await _startNoTranscriptPlayback();
      return;
    }

    _ensureValidIndex();
    if (state.playlistMode == PlaylistMode.bookmarks &&
        state.bookmarkedSentences.isEmpty) {
      return;
    }

    // 已播完后重播，或恢复进入时存档位置正好停在结尾（processingState 仍是 ready
    // 而非 completed，区分不出），都从播放列表开头重新开始，而不是从最后一句续播。
    if (_awaitingReplayFromStart || _isAtAudioEnd()) {
      await _restartFromPlayableBeginning();
      return;
    }

    // 句级循环（单句循环 / 收藏跳播）暂停续播：保留已完成的单句/整篇遍数，从当前句
    // 句首重新拉起 clip 循环，从「记住的遍数」继续而非回到第一遍。立即暂停与解析延迟
    // 暂停都置位 _sentenceLoopResumePending；模式已变/会话失效则清零，按常规起播。
    if (_sentenceLoopResumePending) {
      _sentenceLoopResumePending = false;
      if (_usesSentenceDrivenPlayback &&
          _engine.isActiveSession(_playbackSessionId)) {
        await _resumeSentenceDriven();
        return;
      }
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
        await _startWholeDriven();
        return;
      }
    }

    await _startCurrent();
  }

  /// 句级循环的暂停续播：与 [_startCurrent] 的句级分支一致，唯一区别是
  /// 不清零 _sentenceRepeatsDone / _wholeLoopsDone，使续播从记住的遍数继续。
  Future<void> _resumeSentenceDriven() async {
    if (_playable.isEmpty) return;
    // 续播：两套遍数都保留，从记住的进度继续。
    _launchSentenceDriven(resetWholeLoops: false, resetSentenceRepeats: false);
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
  ///
  /// [resetWholeLoops] 默认 true（全新起播清零整篇遍数）；播放中切上一句/下一句传
  /// false——切句是「同一遍内换句」，应保留整篇已播遍数，只重置当前句的单句遍数。
  Future<void> _startCurrent({bool resetWholeLoops = true}) async {
    final playable = _playable;
    if (playable.isEmpty) return;

    // 全新起播：清零任何待定的延迟暂停 / 续播标记（换句、点击列表等都经此）。
    _pauseAfterCurrentSentence = false;
    _sentenceLoopResumePending = false;

    if (_usesSentenceDrivenPlayback) {
      _launchSentenceDriven(
        resetWholeLoops: resetWholeLoops,
        resetSentenceRepeats: true,
      );
    } else {
      // 整篇连续播放：从当前句句首起播确定性循环。单句遍数总清零；整篇遍数按
      // resetWholeLoops 决定（切句保留）。
      await _startWholeDriven(
        startPos: _currentPos ?? 0,
        resetWholeLoops: resetWholeLoops,
        resetSentenceRepeats: true,
      );
    }
  }

  /// 启动句级 clip 循环协程（单句循环 / 收藏跳播）的公共入口。
  ///
  /// [resetWholeLoops]：true 清零整篇遍数（全新起播）；false 保留——暂停续播、
  /// 以及整篇 gapless 播放中途开启单句循环交接进来时，整篇与单句两套循环状态互不
  /// 影响（开单句循环不应把整篇已播遍数清零）。
  /// [resetSentenceRepeats]：是否清零当前句的单句遍数。
  void _launchSentenceDriven({
    required bool resetWholeLoops,
    required bool resetSentenceRepeats,
  }) {
    final gen = ++_playbackGen;
    _awaitingReplayFromStart = false;
    _activeSentenceDrivenPlayback = true;
    _pendingPlaybackModeHandoff = false;
    if (resetSentenceRepeats) _sentenceRepeatsDone = 0;
    if (resetWholeLoops) _wholeLoopsDone = 0;
    _playbackSessionId = _engine.newSession();
    _setLogicalPlaying(true);
    unawaited(_playSentenceDriven(gen, _playbackSessionId));
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
    // 句级循环正在驱动时暂停 → 续播保留遍数；任何待定的延迟暂停被立即暂停取代。
    _sentenceLoopResumePending = _activeSentenceDrivenPlayback;
    _pauseAfterCurrentSentence = false;
    _activeSentenceDrivenPlayback = false;
    _pendingPlaybackModeHandoff = false;
    _setLogicalPlaying(false);
    await _engine.pause();
    // 引擎 pause 会自增 session 以失效在途回调；LP 仍是这个「已暂停引擎」的拥有者，
    // 故认领当前 session，使随后的 play() 能从精确暂停位置续播。若期间被讲解页等
    // 外来 session 顶掉，认领失效，play() 会按真相源 index 重新起播。
    _playbackSessionId = _engine.currentSessionId;
  }

  /// 请求「当前句自然播完后暂停」——点击解析/翻译/意群工具栏按钮时调用，避免打断
  /// 当前朗读。未在播放时退化为立即暂停。
  Future<void> pauseAfterCurrentSentence() async {
    if (!state.isPlaying) {
      await pause();
      return;
    }
    _pauseAfterCurrentSentence = true;
  }

  Future<void> stop() async {
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _sentenceLoopResumePending = false;
    _pauseAfterCurrentSentence = false;
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
    _sentenceLoopResumePending = false;
    _pauseAfterCurrentSentence = false;
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
        // 此处上方已显式清零两套遍数，进度条拖动语义即「重新从落点数」。
        await _startWholeDriven();
      }
    } else {
      _setLogicalPlaying(false);
      _playbackSessionId = _engine.currentSessionId;
    }
  }

  /// 相对当前位置后退/前进（[delta] 负为后退），并钳制到 `[0, total]`。
  ///
  /// 供无字幕场景的 App 内「后退/前进 10 秒」按钮与锁屏 rewind/fastForward 共用。
  /// 复用 [seekAbsolute]：无字幕分支仅 clearClip + seek，不打断在途 `playToEnd`
  /// 循环，播放中 seek 后循环继续从新位置播到结尾。
  Future<void> seekRelative(Duration delta) async {
    final total = ref.read(audioEngineProvider).totalDuration ?? Duration.zero;
    var target = _engine.absoluteCurrentPosition + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total > Duration.zero && target > total) target = total;
    _awaitingReplayFromStart = false;
    await seekAbsolute(target);
  }

  /// 未播放时把引擎对齐到当前真相源句的起点。
  Future<void> _alignEngineToCurrent() async {
    _playbackGen++;
    _awaitingReplayFromStart = false;
    _sentenceLoopResumePending = false;
    _pauseAfterCurrentSentence = false;
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
      // 切上一句/下一句是「同一遍内换句」：保留整篇已播遍数，不重置为第一遍。
      await _startCurrent(resetWholeLoops: false);
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

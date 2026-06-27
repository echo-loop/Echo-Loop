/// 盲听专用播放器 Provider（段落分段播放模式）
///
/// 参考 RetellPlayer 的段落播放模式，去掉复述相关逻辑。
/// 核心功能：
/// - 段落播放（playRangeOnce：首句 startTime → 末句 endTime）
/// - 播放期间句子高亮（监听 absolutePositionStream + 二分查找）
/// - 段间停顿倒计时（段落播放完→倒计时→重复或下一段）
/// - 遍数循环（播完段落→倒计时为一遍，达到遍数后推进下一段）
/// - 文本显示模式切换（全部隐藏/全部显示）
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../services/app_logger.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/silence_skip_detector.dart';
import '../../services/study_event_recorder.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../learning_progress_provider.dart';
import '../blind_listen_prefs_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../notification_permission_provider.dart';
import '../settings_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';
import 'study_background_playback_mixin.dart';

part 'blind_listen_player_provider.g.dart';

/// 盲听文本显示模式
enum BlindListenDisplayMode {
  /// 全部隐藏
  hideAll,

  /// 全部显示
  showAll,
}

/// 盲听播放器状态
class BlindListenPlayerState {
  /// 当前段落索引（0-based）
  final int currentParagraphIndex;

  /// 总段落数
  final int totalParagraphs;

  /// 段内正在播放的句子索引（-1 = 未播放）
  final int playingSentenceIndex;

  /// 当前遍数（1-based）
  final int currentRepeatCount;

  /// 当前段是否已完整播放结束过一次
  final bool hasCompletedCurrentParagraphPlayback;

  /// 是否正在播放
  final bool isPlaying;

  /// 段间停顿倒计时进行中
  final bool isPauseCountdown;

  /// 倒计时剩余时间
  final Duration pauseRemaining;

  /// 倒计时总时长
  final Duration pauseDuration;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中
  final bool isCountdownFastForward;

  /// 文本显示模式
  final BlindListenDisplayMode displayMode;

  /// 是否正在等待用户继续操作
  final bool isWaitingForUser;

  /// 盲听设置
  final BlindListenSettings settings;

  /// 当前步骤是否自然完成（用于 Screen 层检测完成信号）
  final bool stepFinished;

  /// 已收藏句子的全局 index 集合（用于在句子列表上显示只读收藏标记）
  final Set<int> bookmarkedSentenceIndices;

  const BlindListenPlayerState({
    this.currentParagraphIndex = 0,
    this.totalParagraphs = 0,
    this.playingSentenceIndex = -1,
    this.currentRepeatCount = 1,
    this.hasCompletedCurrentParagraphPlayback = false,
    this.isPlaying = false,
    this.isPauseCountdown = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
    this.displayMode = BlindListenDisplayMode.hideAll,
    this.isWaitingForUser = false,
    this.settings = const BlindListenSettings(),
    this.stepFinished = false,
    this.bookmarkedSentenceIndices = const {},
  });

  BlindListenPlayerState copyWith({
    int? currentParagraphIndex,
    int? totalParagraphs,
    int? playingSentenceIndex,
    int? currentRepeatCount,
    bool? hasCompletedCurrentParagraphPlayback,
    bool? isPlaying,
    bool? isPauseCountdown,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
    BlindListenDisplayMode? displayMode,
    bool? isWaitingForUser,
    BlindListenSettings? settings,
    bool? stepFinished,
    Set<int>? bookmarkedSentenceIndices,
  }) {
    return BlindListenPlayerState(
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      totalParagraphs: totalParagraphs ?? this.totalParagraphs,
      playingSentenceIndex: playingSentenceIndex ?? this.playingSentenceIndex,
      currentRepeatCount: currentRepeatCount ?? this.currentRepeatCount,
      hasCompletedCurrentParagraphPlayback:
          hasCompletedCurrentParagraphPlayback ??
          this.hasCompletedCurrentParagraphPlayback,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseCountdown: isPauseCountdown ?? this.isPauseCountdown,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
      displayMode: displayMode ?? this.displayMode,
      isWaitingForUser: isWaitingForUser ?? this.isWaitingForUser,
      settings: settings ?? this.settings,
      stepFinished: stepFinished ?? this.stepFinished,
      bookmarkedSentenceIndices:
          bookmarkedSentenceIndices ?? this.bookmarkedSentenceIndices,
    );
  }
}

/// 段时长 > 该阈值时，断点恢复从段内具体句子开播；否则从段头开播。
const Duration _resumeMinParagraphDuration = Duration(seconds: 10);

/// 盲听专用播放器 Provider
@Riverpod(keepAlive: true)
class BlindListenPlayer extends _$BlindListenPlayer
    with StudyBackgroundPlaybackMixin {
  @override
  Ref get bgRef => ref;

  /// 段落列表
  List<List<Sentence>> _paragraphs = [];

  /// 设置记忆 slot(子阶段×轮次);null 表示本次不记忆。
  String? _settingsSlot;

  /// 断点恢复的段内本地句子 index（仅首次播放该段时生效）。
  ///
  /// `initializeParagraphs` 写入；`_playCurrentParagraph` 消费一次后清零。
  /// 段切换 / 重听等场景下保持为 0，从段头开播。
  int _resumeStartLocalSentenceIndex = 0;

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// position 监听（句子高亮）
  StreamSubscription<Duration>? _positionSub;

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前 AudioEngine sessionId
  int _sessionId = -1;

  /// 倒计时运行版本号
  int _countdownRunId = 0;

  /// 当前段落播完后进入等待态
  bool _waitAfterCurrentParagraph = false;

  /// 上次跳过的静音段去重 key（避免位置流抖动重复触发同一个 gap）
  int? _lastSkippedSilenceKey;

  /// 静音跳过事件流，UI 侧订阅以弹 snackbar
  final StreamController<Duration> _silenceSkipEvents =
      StreamController<Duration>.broadcast();

  /// 静音跳过事件流（gap 时长），UI 侧订阅以弹 snackbar
  Stream<Duration> get silenceSkipEventStream => _silenceSkipEvents.stream;

  @override
  BlindListenPlayerState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.blindListen,
    );

    // 不再在进后台时暂停段间倒计时：后台连续性由静音保活（StudyBackgroundPlaybackMixin
    // 的 setSessionActive）保证，倒计时在后台照常推进，修复「分段只播第一段」。
    ref.onDispose(() {
      _positionSub?.cancel();
      _invalidateCountdown();
      _silenceSkipEvents.close();
    });
    return const BlindListenPlayerState();
  }

  /// 初始化段落播放
  ///
  /// [startParagraphIndex] 断点续学段落索引，自动 clamp 到有效范围。
  /// [startSentenceLocalIndex] 段内本地句子 index，断点位于段中间时使用；
  ///   仅当对应段的时长 > 10s 时生效，且只用于首次播放该段。
  void initializeParagraphs(
    List<List<Sentence>> paragraphs,
    BlindListenSettings settings, {
    int startParagraphIndex = 0,
    int startSentenceLocalIndex = 0,
    String? settingsSlot,
  }) {
    _settingsSlot = settingsSlot;
    _cleanup();
    _paragraphs = paragraphs;

    final safeIndex = paragraphs.isEmpty
        ? 0
        : startParagraphIndex.clamp(0, paragraphs.length - 1);
    final paragraphLen = paragraphs.isEmpty ? 0 : paragraphs[safeIndex].length;
    _resumeStartLocalSentenceIndex = paragraphLen == 0
        ? 0
        : startSentenceLocalIndex.clamp(0, paragraphLen - 1);

    // 从句子的 isBookmarked 字段初始化收藏状态（同步可见 → 避免首帧无标记闪烁）
    final preBookmarked = <int>{
      for (final paragraph in paragraphs)
        for (final s in paragraph)
          if (s.isBookmarked) s.index,
    };

    state = BlindListenPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
      // [settings] 已由调用方从按槽位偏好 resolve 出(默认+记忆),直接 seed。
      settings: settings,
      bookmarkedSentenceIndices: preBookmarked,
    );

    // 锁屏控制：每任务绑定一次（上一段/下一段），整段任务期间始终可用；会话活跃度
    // （保活 + 图标）由 setSessionActive 在播放/停顿/暂停各入口单独维护。
    bindLockScreen(
      onPlay: resume,
      onPause: pause,
      onNext: goToNextParagraph,
      onPrevious: goToPreviousParagraph,
    );

    ref.read(analyticsServiceProvider).track(Events.blindListenStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.passNumber: ref
          .read(learningSessionProvider)
          .blindListenPassCount,
    });
  }

  /// 获取当前段落的句子列表
  List<Sentence> get currentParagraphSentences =>
      _paragraphs.isNotEmpty && state.currentParagraphIndex < _paragraphs.length
      ? _paragraphs[state.currentParagraphIndex]
      : [];

  /// 当前播放句的全局 index（用于断点持久化 / 句子跳转入参）。
  ///
  /// 未开播时退化为当前段首句的全局 index；段落为空时返回 null。
  int? get currentSentenceGlobalIndex {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return null;
    final localIdx = state.playingSentenceIndex >= 0
        ? state.playingSentenceIndex.clamp(0, sentences.length - 1)
        : 0;
    return sentences[localIdx].index;
  }

  /// 全部段落的句子总数（用于以句子粒度展示进度）
  int get totalSentenceCount => _paragraphs.fold(0, (sum, p) => sum + p.length);

  /// 所有段落的累计时长（各段首尾相加）
  Duration get totalDuration {
    var sum = Duration.zero;
    for (final p in _paragraphs) {
      if (p.isEmpty) continue;
      sum += p.last.endTime - p.first.startTime;
    }
    return sum;
  }

  /// 获取当前段落时长
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  /// 开始播放第一段
  Future<void> startPlaying() async {
    if (_paragraphs.isEmpty) return;
    await _playCurrentParagraph();
  }

  /// 暂停播放
  ///
  /// 使旧 session 失效 + 停止音频。
  /// 同时把当前播放句记到 `_resumeStartLocalSentenceIndex`（仅内存），
  /// 这样 resume 时从该句开头开播，而不是段头重播。
  /// 持久化由播放推进时的 async 写 + 退出页 await 写两路负责，pause 本身不写盘。
  Future<void> pause() async {
    // 第一时间快照，避免 stopPlayback 期间的异步事件污染 playingSentenceIndex
    final snapshotIdx = state.playingSentenceIndex;
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    await engine.stopPlayback();
    if (snapshotIdx >= 0) {
      _resumeStartLocalSentenceIndex = snapshotIdx;
    }
    // 暂停：停保活 + 锁屏图标转暂停；保留回调槽，使锁屏播放可续播。
    setSessionActive(false);
    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: false,
      isCountdownPaused: false,
    );
  }

  /// 恢复播放
  ///
  /// 短段（≤10s）也消费 `_resumeStartLocalSentenceIndex` 偏移，
  /// 保证 pause 在短段中后段时 resume 仍从断点句开头开播。
  Future<void> resume() async {
    await _playCurrentParagraph(forceOffset: true);
  }

  /// 跳转到指定全局句索引并开播。
  ///
  /// - 跨段：切段 + 重置 currentRepeatCount / displayMode / 倒计时标志
  /// - 同段：保留 currentRepeatCount / displayMode，只清倒计时 / 等待态
  /// - 复用 `_playCurrentParagraph(startLocalIdxOverride)` 路径，绕开 10s 阈值
  Future<void> seekToSentence(int globalSentenceIndex) async {
    int? targetParaIdx;
    int? targetLocalIdx;
    for (var p = 0; p < _paragraphs.length; p++) {
      for (var s = 0; s < _paragraphs[p].length; s++) {
        if (_paragraphs[p][s].index == globalSentenceIndex) {
          targetParaIdx = p;
          targetLocalIdx = s;
          break;
        }
      }
      if (targetParaIdx != null) break;
    }
    if (targetParaIdx == null || targetLocalIdx == null) return;

    await _cancelAll();
    // _cancelAll 不动 _resumeStartLocalSentenceIndex；这里通过 override 显式传句索引，
    // _playCurrentParagraph 会把字段清零，避免后续路径误用。

    if (targetParaIdx != state.currentParagraphIndex) {
      state = state.copyWith(
        currentParagraphIndex: targetParaIdx,
        currentRepeatCount: 1,
        hasCompletedCurrentParagraphPlayback: false,
        isPauseCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        playingSentenceIndex: -1,
        isWaitingForUser: false,
        displayMode: BlindListenDisplayMode.hideAll,
      );
    } else {
      state = state.copyWith(
        isPauseCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        isWaitingForUser: false,
      );
    }

    // 不 await _playCurrentParagraph：seekToSentence 调用方需要立即解锁 guard 接受
    // 下一次点击。后续 _playCurrentParagraph 内部用 session id 兜底并发竞态。
    unawaited(_playCurrentParagraph(startLocalIdxOverride: targetLocalIdx));
  }

  /// 跳转到指定段落（0-based）：跳到该段首句，行为同 [seekToSentence]。
  ///
  /// 顶部进度条多段模式下按段拖动时调用。
  Future<void> seekToParagraph(int paragraphIndex) {
    if (paragraphIndex < 0 || paragraphIndex >= _paragraphs.length) {
      return Future.value();
    }
    return seekToSentence(_paragraphs[paragraphIndex].first.index);
  }

  /// 跳转到下一段
  Future<void> goToNextParagraph() async {
    // 最后一段 → 停止播放，由 screen 处理完成逻辑
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      await _cancelAll();
      setSessionActive(false);
      state = state.copyWith(isPlaying: false, isPauseCountdown: false);
      return;
    }

    await _cancelAll();
    // 防 pause 残留断点污染下一段起播位置
    _resumeStartLocalSentenceIndex = 0;
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      currentRepeatCount: 1,
      hasCompletedCurrentParagraphPlayback: false,
      playingSentenceIndex: -1,
      isPauseCountdown: false,
      isCountdownPaused: false,
      displayMode: BlindListenDisplayMode.hideAll,
    );

    await _playCurrentParagraph();
  }

  /// 跳转到上一段
  Future<void> goToPreviousParagraph() async {
    if (state.currentParagraphIndex <= 0) return;

    await _cancelAll();
    _resumeStartLocalSentenceIndex = 0;
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex - 1,
      currentRepeatCount: 1,
      hasCompletedCurrentParagraphPlayback: false,
      playingSentenceIndex: -1,
      isPauseCountdown: false,
      isCountdownPaused: false,
      displayMode: BlindListenDisplayMode.hideAll,
    );

    await _playCurrentParagraph();
  }

  /// 重新开始：重置到第一段
  Future<void> restart() async {
    await _cancelAll();
    _resumeStartLocalSentenceIndex = 0;
    state = BlindListenPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: _paragraphs.length,
      settings: state.settings,
      displayMode: BlindListenDisplayMode.hideAll,
    );
    await _playCurrentParagraph();
  }

  /// 设置显示模式
  void setDisplayMode(BlindListenDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  /// 从数据库加载收藏状态。
  ///
  /// 用户在句子详情页可能新增或移除收藏，返回播放页后调用此方法刷新。
  Future<void> initializeBookmarks(String audioItemId) async {
    final dao = ref.read(bookmarkDaoProvider);
    final indices = await BookmarkManager.loadBookmarks(audioItemId, dao: dao);
    // 同步到段落内的句子对象，保持 Sentence.isBookmarked 一致
    final allSentences = _paragraphs.expand((p) => p).toList();
    BookmarkManager.updateSentenceBookmarkStatus(allSentences, indices);
    state = state.copyWith(bookmarkedSentenceIndices: indices);
  }

  /// 切换句子收藏状态。
  ///
  /// 盲听列表右侧收藏按钮直接调用该入口，避免用户必须进入讲解页才能收藏/取消收藏。
  Future<void> toggleBookmark(String audioItemId, Sentence sentence) async {
    final dao = ref.read(bookmarkDaoProvider);
    final isCurrentlyBookmarked = state.bookmarkedSentenceIndices.contains(
      sentence.index,
    );

    if (isCurrentlyBookmarked) {
      await BookmarkManager.removeBookmarksFromDb(audioItemId, {
        sentence.index,
      }, dao: dao);
    } else {
      await BookmarkManager.addBookmarkToDb(audioItemId, sentence, dao: dao);
    }

    final analyticsParams = {
      ...ref.audioEventParams(audioItemId),
      EventParams.sentenceIndex: sentence.index,
      EventParams.action: isCurrentlyBookmarked ? 'remove' : 'add',
    };
    if (!isCurrentlyBookmarked) {
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

    final newSet = Set<int>.from(state.bookmarkedSentenceIndices);
    if (isCurrentlyBookmarked) {
      newSet.remove(sentence.index);
      sentence.isBookmarked = false;
    } else {
      newSet.add(sentence.index);
      sentence.isBookmarked = true;
    }
    state = state.copyWith(bookmarkedSentenceIndices: newSet);

    if (!isCurrentlyBookmarked) {
      unawaited(
        ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
      );
    }
  }

  /// 进入等待用户状态。
  ///
  /// 如果当前段落正在播放且 [afterCurrentParagraph] 为 true，
  /// 则允许当前段自然播完后再停在等待态。
  void enterWaitingForUser({bool afterCurrentParagraph = false}) {
    if (state.isWaitingForUser || state.stepFinished) return;

    if (state.isPlaying && afterCurrentParagraph) {
      _waitAfterCurrentParagraph = true;
      AppLogger.log(
        'BlindListenPlayer',
        '-> WaitingForUser (after current paragraph)',
      );
      return;
    }

    _waitAfterCurrentParagraph = false;
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    unawaited(engine.stopPlayback());
    setSessionActive(false);
    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: false,
      isCountdownPaused: false,
      playingSentenceIndex: -1,
      isWaitingForUser: true,
    );
    AppLogger.log('BlindListenPlayer', '-> WaitingForUser');
  }

  /// 把 🔧 面板改动按槽位写穿到盲听偏好(只记手动改动)。
  void _recordSettingsChange(
    BlindListenSettings oldSettings,
    BlindListenSettings newSettings,
  ) {
    final slot = _settingsSlot;
    if (slot == null) return;
    persistBlindSettingsDiff(
      ref.read(blindListenPrefsProvider.notifier),
      slot,
      oldSettings,
      newSettings,
    );
  }

  void updateSettings(BlindListenSettings newSettings) {
    _recordSettingsChange(state.settings, newSettings);
    final modeChanged = newSettings.isManualMode != state.settings.isManualMode;
    final speedChanged =
        newSettings.playbackSpeed != state.settings.playbackSpeed;
    final shouldKeepWaiting =
        state.isWaitingForUser || _waitAfterCurrentParagraph;

    state = state.copyWith(settings: newSettings);

    if (speedChanged) {
      unawaited(
        ref
            .read(audioEngineProvider.notifier)
            .setSpeed(newSettings.playbackSpeed),
      );
    }

    if (shouldKeepWaiting) {
      return;
    }

    // 自动↔手动切换时，停在当前段落，取消一切异步操作并进入等待态。
    if (modeChanged) {
      final engine = ref.read(audioEngineProvider.notifier);
      _sessionId = engine.newSession();
      _positionSub?.cancel();
      _invalidateCountdown();
      unawaited(engine.stopPlayback());
      setSessionActive(false);
      state = state.copyWith(
        isPlaying: false,
        isPauseCountdown: false,
        isCountdownPaused: false,
        playingSentenceIndex: -1,
        isWaitingForUser: true,
      );
    }
  }

  /// 暂停倒计时
  void pauseCountdown() {
    _countdown.pause();
    state = state.copyWith(isCountdownPaused: true);
  }

  /// 恢复倒计时
  void resumeCountdown() {
    _countdown.resume();
    state = state.copyWith(isCountdownPaused: false);
  }

  /// 取消倒计时
  void cancelCountdown() {
    _invalidateCountdown();
    state = state.copyWith(isPauseCountdown: false, isCountdownPaused: false);
  }

  /// 切换倒计时快进
  ///
  /// 快进时剩余倒计时在 ~1.5 秒内完成。
  /// 如果当前暂停中，快进会同时恢复倒计时。
  void toggleCountdownFastForward() {
    final isFF = !state.isCountdownFastForward;
    if (isFF) {
      _countdown.fastForward();
    } else {
      _countdown.setSpeed(1.0);
    }
    if (state.isCountdownPaused) {
      _countdown.resume();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 释放资源
  void disposePlayer() {
    unbindLockScreen();
    _cleanup();
    _paragraphs = [];
    state = const BlindListenPlayerState();
  }

  // ========== 内部方法 ==========

  /// 异步保存盲听断点（当前播放句子的全局 index），不阻塞播放流程。
  ///
  /// 优先使用 `playingSentenceIndex` 定位的句子；未开播时退化为段首句。
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;
    final localIdx = state.playingSentenceIndex >= 0
        ? state.playingSentenceIndex.clamp(0, sentences.length - 1)
        : 0;
    final globalIdx = sentences[localIdx].index;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveBlindListenSentenceIndex(
            audioItemId,
            globalIdx,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  /// 播放当前段落
  ///
  /// 起播句决策（按优先级）：
  /// 1. [startLocalIdxOverride] 非空：直接使用（来自 `seekToSentence` 等用户主动操作）
  /// 2. [forceOffset] = true：消费 `_resumeStartLocalSentenceIndex`（不看段时长，用于 resume）
  /// 3. 否则按断点续学：段时长 > 10s 时消费字段，否则段头开播
  ///
  /// `_resumeStartLocalSentenceIndex` 用完一次立即清零，避免下次重听 / 下一段误用。
  Future<void> _playCurrentParagraph({
    int? startLocalIdxOverride,
    bool forceOffset = false,
  }) async {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;

    final int startLocalIdx;
    if (startLocalIdxOverride != null) {
      startLocalIdx = startLocalIdxOverride.clamp(0, sentences.length - 1);
      _resumeStartLocalSentenceIndex = 0;
    } else {
      final paragraphDuration =
          sentences.last.endTime - sentences.first.startTime;
      final useOffset =
          _resumeStartLocalSentenceIndex > 0 &&
          _resumeStartLocalSentenceIndex < sentences.length &&
          (forceOffset || paragraphDuration > _resumeMinParagraphDuration);
      startLocalIdx = useOffset ? _resumeStartLocalSentenceIndex : 0;
      _resumeStartLocalSentenceIndex = 0; // 只用一次
    }

    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    final sid = _sessionId;

    state = state.copyWith(
      hasCompletedCurrentParagraphPlayback: false,
      isPlaying: true,
      playingSentenceIndex: startLocalIdx,
      isPauseCountdown: false,
      isWaitingForUser: false,
      stepFinished: false,
    );

    // 进入活跃会话（含随后的段间倒计时，保活全程在跑）。回调槽已在 initializeParagraphs
    // 绑定一次，此处不再重绑。
    setSessionActive(true);

    _persistCurrentSentenceIndexAsync();

    final start = sentences[startLocalIdx].startTime;
    final end = sentences.last.endTime;

    await engine.setSpeed(state.settings.playbackSpeed);
    // 订阅 position stream 实现句子高亮——必须等 clip+seek(0) 落定后才订阅，
    // 否则 setClip/seek 过渡期的陈旧 position 会把高亮跳到错误句、污染断点。
    await engine.playRangeOnce(
      start,
      end,
      sid,
      onClipReady: () => _startPositionTracking(sentences),
    );

    if (!engine.isActiveSession(sid)) return;

    // 通过 recorder 记录听力时长、输入词数、已学词形
    final paragraphWordCount = countWordsInSentences(sentences);
    final durationMs =
        (sentences.last.endTime - sentences.first.startTime).inMilliseconds;
    final paragraphText = sentences.map((s) => s.text).join(' ');
    _recorder.onInputCompleted(
      durationMs: durationMs,
      wordCount: paragraphWordCount,
      text: paragraphText,
    );

    _positionSub?.cancel();

    if (_waitAfterCurrentParagraph) {
      _waitAfterCurrentParagraph = false;
      setSessionActive(false);
      state = state.copyWith(
        hasCompletedCurrentParagraphPlayback: true,
        isPlaying: false,
        isPauseCountdown: false,
        isCountdownPaused: false,
        playingSentenceIndex: -1,
        isWaitingForUser: true,
      );
      return;
    }

    // 手动模式：播放完直接停止，等待用户操作
    if (state.settings.isManualMode) {
      final isLastParagraph =
          state.currentParagraphIndex >= state.totalParagraphs - 1;
      setSessionActive(false);
      state = state.copyWith(
        hasCompletedCurrentParagraphPlayback: true,
        isPlaying: false,
        playingSentenceIndex: -1,
        isWaitingForUser: false,
        stepFinished: isLastParagraph,
      );
      return;
    }

    _startPauseCountdown();
  }

  /// 订阅 position stream，二分查找定位当前句子
  void _startPositionTracking(List<Sentence> sentences) {
    _positionSub?.cancel();
    _lastSkippedSilenceKey = null; // 新段落，清空去重指针
    final engine = ref.read(audioEngineProvider.notifier);

    _positionSub = engine.absolutePositionStream.listen((position) {
      if (!engine.isActiveSession(_sessionId)) return;
      // 防御：clip 切换后仍可能残留一次旧 emission。落在本段范围外的 position
      // 一律丢弃，绝不改高亮、不写断点、不触发静音跳过。
      if (position < sentences.first.startTime ||
          position >= sentences.last.endTime) {
        return;
      }

      final idx = _findSentenceIndex(sentences, position);
      if (idx != state.playingSentenceIndex && idx >= 0) {
        state = state.copyWith(playingSentenceIndex: idx);
        // 句子推进时更新断点（精确到当前句）
        _persistCurrentSentenceIndexAsync();
      }
      _maybeSkipSilence(sentences, position, idx);
    });
  }

  /// 静音跳过判定（开关开启时生效）。
  ///
  /// 段落 clip 范围 = [first.start, last.end]，因此 detector 的末尾分支
  /// 在盲听场景永远不会命中——这里只会在中间 gap 触发。
  void _maybeSkipSilence(List<Sentence> sentences, Duration position, int idx) {
    final settings = ref.read(appSettingsProvider);
    if (!settings.skipSilenceEnabled) return;

    final result = SilenceSkipDetector.detect(
      position: position,
      sentences: sentences,
      currentIdx: idx,
      thresholdSeconds: settings.silenceThresholdSeconds,
      playbackEnd: sentences.last.endTime,
    );
    if (result == null) return;
    if (_lastSkippedSilenceKey == result.dedupKey) return;

    _lastSkippedSilenceKey = result.dedupKey;
    unawaited(
      ref.read(audioEngineProvider.notifier).seekToAbsolute(result.skipTo),
    );

    // 仅在静音段较长（> 5s）时才弹 snackbar，避免短跳过频繁打扰
    if (result.gapDuration.inSeconds > 5) {
      _silenceSkipEvents.add(result.gapDuration);
    }
  }

  /// 二分查找当前播放位置对应的句子索引
  int _findSentenceIndex(List<Sentence> sentences, Duration position) {
    var lo = 0;
    var hi = sentences.length - 1;

    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (position < sentences[mid].startTime) {
        hi = mid - 1;
      } else if (position >= sentences[mid].endTime) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }

    return lo.clamp(0, sentences.length - 1);
  }

  /// 启动段间停顿倒计时
  void _startPauseCountdown() {
    final duration = state.settings.calculatePauseDuration(
      currentParagraphDuration,
    );
    final runId = ++_countdownRunId;

    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: true,
      pauseDuration: duration,
      pauseRemaining: duration,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      playingSentenceIndex: -1,
      hasCompletedCurrentParagraphPlayback: true,
      isWaitingForUser: false,
    );

    _countdown.start(duration).then((_) {
      if (state.isPauseCountdown && runId == _countdownRunId) {
        _onPauseCountdownFinished();
      }
    });
  }

  /// 段间停顿结束
  Future<void> _onPauseCountdownFinished() async {
    if (state.settings.repeatCount == 0 ||
        state.currentRepeatCount < state.settings.repeatCount) {
      // 当前段还有遍数 → 直接继续播放，不经过 isPauseCountdown=false 中间状态
      state = state.copyWith(currentRepeatCount: state.currentRepeatCount + 1);
      await _playCurrentParagraph();
    } else if (state.currentParagraphIndex < state.totalParagraphs - 1) {
      // 还有下一段 → 推进
      state = state.copyWith(isPauseCountdown: false);
      await goToNextParagraph();
    } else {
      // 最后一段最后一遍 → 停止
      setSessionActive(false);
      state = state.copyWith(
        isPauseCountdown: false,
        isPlaying: false,
        isWaitingForUser: false,
        stepFinished: true,
      );
      ref.read(analyticsServiceProvider).track(Events.blindListenComplete, {
        ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
        EventParams.passNumber: state.currentRepeatCount,
      });
    }
  }

  /// 取消所有异步操作并停止音频
  Future<void> _cancelAll() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    _waitAfterCurrentParagraph = false;
    await engine.stopPlayback();
  }

  /// 使当前倒计时失效
  void _invalidateCountdown() {
    _countdownRunId += 1;
    _countdown.cancel();
  }

  /// 清理资源
  void _cleanup() {
    _positionSub?.cancel();
    _invalidateCountdown();
    _waitAfterCurrentParagraph = false;
    _positionSub = null;
  }
}

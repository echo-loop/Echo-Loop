/// 复述专用播放器 Provider
///
/// 段落复述播放器，直接操作 AudioEngine。
/// 核心功能：
/// - 段落播放（playRangeOnce：首句 startTime → 末句 endTime）
/// - 播放期间句子高亮（监听 absolutePositionStream + 二分查找）
/// - 复述倒计时（段落播放完→倒计时→下一段）
/// - 遍数循环（播放→复述为一遍，达到遍数后推进下一段）
/// - 文本遮盖/关键词显示模式切换
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../features/usage/usage_event.dart';
import '../../features/usage/usage_providers.dart';
import '../../database/providers.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/silence_skip_detector.dart';
import '../../services/study_event_recorder.dart';
import '../../utils/keyword_extraction.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/foreground_audio_engine_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../learning_settings_provider.dart';
import '../notification_permission_provider.dart';
import '../retell_recording_controller_provider.dart';
import '../settings_provider.dart';
import '../retell_prefs_provider.dart';
import 'countdown_controller.dart';
import '../learning_progress_provider.dart';
import 'learning_session_provider.dart';

part 'retell_player_provider.g.dart';

/// 段时长 > 该阈值时，断点恢复从段内具体句子开播；否则从段头开播。
const Duration _resumeMinParagraphDuration = Duration(seconds: 10);

/// 复述阶段
enum RetellPhase {
  /// 正在播放段落音频
  listening,

  /// 复述停顿阶段
  retelling,
}

/// 复述播放器状态
class RetellPlayerState {
  /// 当前段落索引（0-based）
  final int currentParagraphIndex;

  /// 总段落数
  final int totalParagraphs;

  /// listening phase: 段内正在播放的句子索引（-1 = 未播放）
  final int playingSentenceIndex;

  /// 当前阶段
  final RetellPhase phase;

  /// 当前遍数（1-based，播放→复述为一遍）
  final int currentRepeatCount;

  /// 文本显示模式
  final RetellDisplayMode displayMode;

  /// 复述设置
  final RetellSettings settings;

  /// listening phase 的播放状态
  final bool isPlaying;

  /// 复述倒计时进行中
  final bool isRetellCountdown;

  /// 倒计时剩余时间
  final Duration pauseRemaining;

  /// 倒计时总时长
  final Duration pauseDuration;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中（10 倍速）
  final bool isCountdownFastForward;

  /// 用户是否在当前段落中手动更改过显示模式
  final bool userOverrodeDisplayMode;

  /// 是否正在等待用户继续操作
  final bool isWaitingForUser;

  /// 已收藏句子索引集合
  final Set<int> bookmarkedSentenceIndices;

  /// 当前步骤是否自然完成（用于 Screen 层检测完成信号）
  final bool stepFinished;

  const RetellPlayerState({
    this.currentParagraphIndex = 0,
    this.totalParagraphs = 0,
    this.playingSentenceIndex = -1,
    this.phase = RetellPhase.listening,
    this.currentRepeatCount = 1,
    this.displayMode = RetellDisplayMode.hideAll,
    this.settings = const RetellSettings(),
    this.isPlaying = false,
    this.isRetellCountdown = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
    this.userOverrodeDisplayMode = false,
    this.bookmarkedSentenceIndices = const {},
    this.isWaitingForUser = false,
    this.stepFinished = false,
  });

  RetellPlayerState copyWith({
    int? currentParagraphIndex,
    int? totalParagraphs,
    int? playingSentenceIndex,
    RetellPhase? phase,
    int? currentRepeatCount,
    RetellDisplayMode? displayMode,
    RetellSettings? settings,
    bool? isPlaying,
    bool? isRetellCountdown,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
    bool? userOverrodeDisplayMode,
    Set<int>? bookmarkedSentenceIndices,
    bool? isWaitingForUser,
    bool? stepFinished,
  }) {
    return RetellPlayerState(
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      totalParagraphs: totalParagraphs ?? this.totalParagraphs,
      playingSentenceIndex: playingSentenceIndex ?? this.playingSentenceIndex,
      phase: phase ?? this.phase,
      currentRepeatCount: currentRepeatCount ?? this.currentRepeatCount,
      displayMode: displayMode ?? this.displayMode,
      settings: settings ?? this.settings,
      isPlaying: isPlaying ?? this.isPlaying,
      isRetellCountdown: isRetellCountdown ?? this.isRetellCountdown,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
      userOverrodeDisplayMode:
          userOverrodeDisplayMode ?? this.userOverrodeDisplayMode,
      bookmarkedSentenceIndices:
          bookmarkedSentenceIndices ?? this.bookmarkedSentenceIndices,
      isWaitingForUser: isWaitingForUser ?? this.isWaitingForUser,
      stepFinished: stepFinished ?? this.stepFinished,
    );
  }
}

/// 复述专用播放器 Provider
@Riverpod(keepAlive: true)
class RetellPlayer extends _$RetellPlayer {
  /// 段落列表
  List<List<Sentence>> _paragraphs = [];

  /// 设置记忆 slot(子阶段×轮次);null 表示本次不记忆。
  String? _settingsSlot;

  /// 断点恢复的段内本地句子 index（仅首次播放该段时生效，用完清零）
  int _resumeStartLocalSentenceIndex = 0;

  /// 所有句子列表（用于重新生成关键词）
  List<Sentence> _allSentences = [];

  /// 关键词映射：段落内句子索引 → 词索引集合
  Map<int, Set<int>> _keywordsMap = {};

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// position 监听（用于句子高亮）
  StreamSubscription<Duration>? _positionSub;

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前 AudioEngine sessionId
  int _sessionId = -1;

  /// 倒计时运行版本号
  ///
  /// 每次启动或取消复述倒计时都递增，用于屏蔽已取消倒计时的过期回调。
  int _retellCountdownRunId = 0;

  /// 当前段落播完后进入等待态
  bool _waitAfterCurrentParagraph = false;

  /// 上次跳过的静音段去重 key
  int? _lastSkippedSilenceKey;

  /// 静音跳过事件流（gap 时长），UI 侧订阅以弹 snackbar
  final StreamController<Duration> _silenceSkipEvents =
      StreamController<Duration>.broadcast();

  /// 静音跳过事件流（gap 时长），UI 侧订阅以弹 snackbar
  Stream<Duration> get silenceSkipEventStream => _silenceSkipEvents.stream;

  @override
  RetellPlayerState build() {
    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } catch (e) {
      AppLogger.log('Player', '⚠ vocabTracker 不可用（测试环境？）: $e');
    }
    _recorder = StudyEventRecorder(
      studyTimeService: ref.read(studyTimeServiceProvider),
      vocabTracker: vocabTracker,
      stage: StudyStage.retell,
    );

    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _positionSub?.cancel();
      _invalidateRetellCountdown();
      _silenceSkipEvents.close();
    });

    // 监听录音评估完成，上报 recording_complete 事件
    ref.listen(retellRecordingControllerProvider, (prev, next) {
      if (prev == null) return;
      if (prev.phase != RetellRecordingPhase.idle &&
          next.phase == RetellRecordingPhase.idle &&
          next.currentAttempt != null) {
        final attempt = next.currentAttempt!;
        ref
            .read(usageTrackerProvider)
            .record(
              UsageEvent.recordingCompleted,
              analyticsParams: {
                ...ref.audioEventParams(
                  ref.read(learningSessionProvider).audioItemId,
                ),
                EventParams.mode: 'retell',
                if (attempt.score != null) EventParams.score: attempt.score!,
              },
            );
      }
    });

    return const RetellPlayerState();
  }

  /// App 进入后台时取消倒计时和播放，回前台后等待用户操作。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      AppLogger.log(
        'RetellPlayer',
        'App 进入后台: '
            'phase=${state.phase.name}, '
            'countdown=${state.isRetellCountdown}',
      );

      // 停止段落音频播放
      final engine = ref.read(foregroundAudioEngineProvider.notifier);
      _sessionId = engine.newSession();
      _positionSub?.cancel();
      engine.stopPlayback();

      // 取消倒计时
      if (state.isRetellCountdown) {
        AppLogger.log('RetellPlayer', '取消倒计时');
        cancelCountdown();
      }

      // 回到 retelling 阶段等待用户操作
      if (state.phase == RetellPhase.listening) {
        AppLogger.log('RetellPlayer', 'listening → retelling (等待用户操作)');
        state = state.copyWith(
          phase: RetellPhase.retelling,
          isPlaying: false,
          isWaitingForUser: true,
        );
      }
    }
  }

  /// 初始化复述播放器
  ///
  /// [paragraphs] DP 分段结果
  /// [startSentenceIndex] 断点续学的全局句子 index。会反查段，并把段内本地
  ///   index 暂存到 `_resumeStartLocalSentenceIndex` 供首次播放该段时使用。
  /// [autoRatio] 按音频难度映射出的可见词比例档位；为 null 时使用 [RetellSettings] 默认值
  ///
  /// 关键词由内部根据 [autoRatio] 或当前 settings 自动生成，无需外部传入。
  void initialize(
    List<List<Sentence>> paragraphs, {
    int? startSentenceIndex,
    RetellSettings settings = const RetellSettings(),
    String? settingsSlot,
  }) {
    _settingsSlot = settingsSlot;
    _cleanup();
    _paragraphs = paragraphs;
    _allSentences = paragraphs.expand((p) => p).toList();

    // 根据全局句子索引反查段 + 段内本地 index
    var safeIndex = 0;
    var localIndex = 0;
    if (startSentenceIndex != null && paragraphs.isNotEmpty) {
      for (var i = 0; i < paragraphs.length; i++) {
        final local = paragraphs[i].indexWhere(
          (s) => s.index == startSentenceIndex,
        );
        if (local >= 0) {
          safeIndex = i;
          localIndex = local;
          break;
        }
      }
    }
    _resumeStartLocalSentenceIndex = localIndex;

    // [settings] 已由调用方从按槽位偏好 resolve 出(默认+记忆);自动播放录音走全局学习设置。
    final learningSettings = ref.read(learningSettingsProvider);
    state = RetellPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
      settings: settings.copyWith(
        autoPlayRecordingAfterCompletion:
            learningSettings.autoPlayRetellRecordingAfterCompletion,
      ),
    );

    // 按 settings.keywordRatio 生成关键词映射
    regenerateKeywords();
    ref.read(analyticsServiceProvider).track(Events.retellStart, {
      ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
      EventParams.totalParagraphs: paragraphs.length,
    });

    // 注入 recorder 到录音控制器
    ref.read(retellRecordingControllerProvider.notifier).setRecorder(_recorder);

    // 从句子的 isBookmarked 字段初始化收藏状态
    final preBookmarked = <int>{
      for (final paragraph in paragraphs)
        for (final s in paragraph)
          if (s.isBookmarked) s.index,
    };
    if (preBookmarked.isNotEmpty) {
      state = state.copyWith(bookmarkedSentenceIndices: preBookmarked);
    }
  }

  /// 从数据库加载收藏状态（初始化后异步调用）
  Future<void> initializeBookmarks(String audioItemId) async {
    final dao = ref.read(bookmarkDaoProvider);
    final indices = await BookmarkManager.loadBookmarks(audioItemId, dao: dao);
    // 同步到句子对象
    BookmarkManager.updateSentenceBookmarkStatus(_allSentences, indices);
    state = state.copyWith(bookmarkedSentenceIndices: indices);
  }

  /// 切换句子收藏状态
  ///
  /// 先写 DB，成功后再更新内存状态，避免 DB 失败导致状态不一致。
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

    // 埋点：收藏/取消收藏句子
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

    // DB 操作完成后更新内存
    final newSet = Set<int>.from(state.bookmarkedSentenceIndices);
    if (isCurrentlyBookmarked) {
      newSet.remove(sentence.index);
      sentence.isBookmarked = false;
    } else {
      newSet.add(sentence.index);
      sentence.isBookmarked = true;
    }
    state = state.copyWith(bookmarkedSentenceIndices: newSet);

    // 价值锚点：只在「添加收藏」时尝试触发通知权限 pre-prompt
    if (!isCurrentlyBookmarked) {
      unawaited(
        ref.read(notificationPermissionServiceProvider).maybeTriggerPrompt(),
      );
    }
  }

  /// 获取当前播放句子的全局句子索引（用于保存断点）。
  ///
  /// 优先用 `playingSentenceIndex` 定位的句子；未开播时退化为段首句。
  /// 段为空时返回 null。
  int? get currentSentenceGlobalIndex {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return null;
    final localIdx = state.playingSentenceIndex >= 0
        ? state.playingSentenceIndex.clamp(0, sentences.length - 1)
        : 0;
    return sentences[localIdx].index;
  }

  /// 获取当前段落的句子列表
  List<Sentence> get currentParagraphSentences =>
      _paragraphs.isNotEmpty && state.currentParagraphIndex < _paragraphs.length
      ? _paragraphs[state.currentParagraphIndex]
      : [];

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

  /// 获取所有段落
  List<List<Sentence>> get paragraphs => List.unmodifiable(_paragraphs);

  /// 获取关键词映射
  Map<int, Set<int>> get keywordsMap => Map.unmodifiable(_keywordsMap);

  /// 获取当前段落时长
  Duration get currentParagraphDuration {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return Duration.zero;
    return sentences.last.endTime - sentences.first.startTime;
  }

  /// 当前段落所有句子文本拼接（空格分隔），用作录音识别的参考文本。
  String get currentParagraphReferenceText {
    return currentParagraphSentences.map((s) => s.text).join(' ');
  }

  /// 录音评估完成后的推进逻辑。
  ///
  /// 记录输出词数并检查遍数推进。
  /// 手动模式下视为单遍（忽略 repeatCount），直接推进下一段。
  Future<void> completeRetellingTurn() async {
    _recordParagraphOutputStats();
    final effectiveRepeatCount = state.settings.isManualMode
        ? 1
        : state.settings.repeatCount;
    if (effectiveRepeatCount == 0 ||
        state.currentRepeatCount < effectiveRepeatCount) {
      state = state.copyWith(currentRepeatCount: state.currentRepeatCount + 1);
      await _playCurrentParagraph();
    } else {
      await goToNextParagraph();
    }
  }

  /// 取消段间停顿倒计时
  void cancelCountdown() {
    _invalidateRetellCountdown();
    state = state.copyWith(
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 记录段落输出词数。
  void _recordParagraphOutputStats() {
    final session = ref.read(learningSessionProvider.notifier);
    final paragraphWordCount = countWordsInSentences(currentParagraphSentences);
    session.addOutputWords(paragraphWordCount);
  }

  /// 异步保存复述断点（当前播放句子的全局 index），不阻塞播放流程。
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
          .saveRetellSentenceIndex(
            audioItemId,
            globalIdx,
            isFreePlay: session.isFreePlay,
          ),
    );
  }

  /// 重新开始：重置到第一段，重新播放
  Future<void> restart() async {
    await _cancelAll();
    _resumeStartLocalSentenceIndex = 0;
    state = RetellPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: _paragraphs.length,
      settings: state.settings,
      displayMode: RetellDisplayMode.hideAll,
    );
    await _playCurrentParagraph();
  }

  /// 开始播放当前段落
  Future<void> startPlaying() async {
    if (_paragraphs.isEmpty) return;
    await _playCurrentParagraph();
  }

  /// 暂停播放
  ///
  /// 使旧 session 失效 + 真正停止底层音频播放。
  /// 同时把当前播放句记到 `_resumeStartLocalSentenceIndex`（仅内存），
  /// 这样 resume 时从该句开头开播，而不是段头重播。
  /// 持久化由播放推进时 async 写 + 退出页 await 写两路负责，pause 本身不写盘。
  Future<void> pause() async {
    // 先快照，避免 stopPlayback 期间异步事件污染 playingSentenceIndex
    final snapshotIdx = state.playingSentenceIndex;
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateRetellCountdown();
    await engine.stopPlayback();
    if (snapshotIdx >= 0) {
      _resumeStartLocalSentenceIndex = snapshotIdx;
    }
    state = state.copyWith(
      isPlaying: false,
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放
  Future<void> resume() async {
    if (state.phase == RetellPhase.listening) {
      // 短段（≤10s）也消费断点偏移，保证 pause 后从当前句开头开播
      await _playCurrentParagraph(forceOffset: true);
    } else {
      // 复述阶段恢复倒计时，从 controller 读取实际剩余时间
      _startRetellCountdown(_countdown.remaining);
    }
  }

  /// 跳转到指定全局句索引并开播。
  ///
  /// - 强制切回 listening phase + 清所有倒计时标志（即使在 retelling phase 也能跳）
  /// - 跨段：重置 currentRepeatCount / displayMode / userOverrodeDisplayMode
  /// - 同段：保留 currentRepeatCount / displayMode（用户已切的 keywordsOnly 不被冲掉）
  /// - 调用方负责取消正在进行的录音
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

    if (targetParaIdx != state.currentParagraphIndex) {
      state = state.copyWith(
        currentParagraphIndex: targetParaIdx,
        phase: RetellPhase.listening,
        currentRepeatCount: 1,
        playingSentenceIndex: -1,
        isRetellCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        isWaitingForUser: false,
        displayMode: RetellDisplayMode.hideAll,
        userOverrodeDisplayMode: false,
      );
    } else {
      // 同段：保留 displayMode / userOverrodeDisplayMode，仅清倒计时和等待态
      state = state.copyWith(
        phase: RetellPhase.listening,
        isRetellCountdown: false,
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
      state = state.copyWith(
        isPlaying: false,
        isRetellCountdown: false,
        stepFinished: true,
      );
      ref.read(analyticsServiceProvider).track(Events.retellComplete, {
        ...ref.audioEventParams(ref.read(learningSessionProvider).audioItemId),
        EventParams.totalParagraphs: state.totalParagraphs,
      });
      return;
    }

    await _cancelAll();
    // 防 pause 残留断点污染下一段起播位置
    _resumeStartLocalSentenceIndex = 0;
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: -1,
      isRetellCountdown: false,
      displayMode: RetellDisplayMode.hideAll,
      userOverrodeDisplayMode: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
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
      phase: RetellPhase.listening,
      currentRepeatCount: 1,
      playingSentenceIndex: -1,
      isRetellCountdown: false,
      displayMode: RetellDisplayMode.hideAll,
      userOverrodeDisplayMode: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    await _playCurrentParagraph();
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

  /// 切换倒计时快进（10 倍速/正常速）
  ///
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

  /// 复述倒计时期间重播当前段落
  ///
  /// 取消倒计时，回到 listening 阶段重新播放。
  Future<void> replayDuringCountdown() async {
    _invalidateRetellCountdown();
    // 重听语义 = 从段头开播，清掉 pause 可能残留的断点
    _resumeStartLocalSentenceIndex = 0;
    state = state.copyWith(
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isWaitingForUser: false,
    );
    await _playCurrentParagraph();
  }

  /// 进入等待用户状态。
  ///
  /// 如果当前段落正在播放且 [afterCurrentParagraph] 为 true，
  /// 则允许当前段自然播完后再停在等待态。
  /// [stopImmediately] 为 true 时，无论当前状态，立即停止播放进入等待态。
  void enterWaitingForUser({
    bool afterCurrentParagraph = false,
    bool stopImmediately = false,
  }) {
    if (state.stepFinished) return;
    // stopImmediately=true 表示调用方要求强制停止；即使当前已在 waiting 态
    // 也要再走一遍 session bump + stopPlayback，避免遗漏底层音频清理。
    if (!stopImmediately && state.isWaitingForUser) return;

    if (!stopImmediately &&
        state.phase == RetellPhase.listening &&
        state.isPlaying &&
        afterCurrentParagraph) {
      _waitAfterCurrentParagraph = true;
      AppLogger.log(
        'RetellPlayer',
        '-> WaitingForUser (after current paragraph)',
      );
      return;
    }

    _waitAfterCurrentParagraph = false;
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateRetellCountdown();
    unawaited(engine.stopPlayback());
    state = state.copyWith(
      phase: RetellPhase.retelling,
      isPlaying: false,
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      playingSentenceIndex: -1,
      isWaitingForUser: true,
    );
    AppLogger.log('RetellPlayer', '-> WaitingForUser');
  }

  /// 退出等待用户状态（用户主动开始复述录音时调用）。
  ///
  /// 手动点击录音从等待态（如刚关闭设置面板）进入录音时，必须清除
  /// [RetellPlayerState.isWaitingForUser]，否则录音评估完成后 screen 层的
  /// 完成处理（自动回放 / 段间倒计时）会被 `!isWaitingForUser` 门控整体跳过。
  void exitWaitingForUser() {
    _waitAfterCurrentParagraph = false;
    if (!state.isWaitingForUser) return;
    state = state.copyWith(isWaitingForUser: false);
    AppLogger.log('RetellPlayer', '<- WaitingForUser (用户开始录音)');
  }

  /// 设置显示模式（用户手动切换）
  void setDisplayMode(RetellDisplayMode mode) {
    state = state.copyWith(displayMode: mode, userOverrodeDisplayMode: true);
  }

  /// 设置显示模式（系统自动切换，不影响用户覆盖标记）
  void setDisplayModeWithoutOverride(RetellDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  /// 记录用户手动改动到按槽位偏好(只写变化字段)。
  ///
  /// `autoPlayRecordingAfterCompletion` 走全局学习设置,不在此偏好内
  /// (persistRetellSettingsDiff 本身已不含该字段)。
  void _recordSettingsChange(
    RetellSettings oldSettings,
    RetellSettings newSettings,
  ) {
    final slot = _settingsSlot;
    if (slot == null) return;
    persistRetellSettingsDiff(
      ref.read(retellPrefsProvider.notifier),
      slot,
      oldSettings,
      newSettings,
    );
  }

  void updateSettings(RetellSettings newSettings) {
    _recordSettingsChange(state.settings, newSettings);
    final modeChanged = newSettings.isManualMode != state.settings.isManualMode;
    final ratioChanged =
        newSettings.keywordRatio != state.settings.keywordRatio;
    final speedChanged =
        newSettings.playbackSpeed != state.settings.playbackSpeed;
    final shouldKeepWaiting =
        state.isWaitingForUser || _waitAfterCurrentParagraph;

    state = state.copyWith(settings: newSettings);

    if (speedChanged) {
      unawaited(
        ref
            .read(foregroundAudioEngineProvider.notifier)
            .setSpeed(newSettings.playbackSpeed),
      );
    }

    if (shouldKeepWaiting) {
      if (ratioChanged) {
        regenerateKeywords();
      }
      return;
    }

    // 自动↔手动切换时，停在当前段落，取消一切异步操作
    if (modeChanged) {
      _invalidateRetellCountdown();
      final engine = ref.read(foregroundAudioEngineProvider.notifier);
      _sessionId = engine.newSession();
      unawaited(engine.stopPlayback());
      state = state.copyWith(
        isPlaying: false,
        isRetellCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        playingSentenceIndex: -1,
        isWaitingForUser: true,
      );
      if (ratioChanged) regenerateKeywords();
      return;
    }

    if (ratioChanged) {
      regenerateKeywords();
    }
  }

  /// 重新生成关键词
  ///
  /// 根据当前设置中的 [KeywordRatio] 重新提取关键词。
  void regenerateKeywords() {
    if (_allSentences.isEmpty) return;
    _keywordsMap = extractKeywords(
      _allSentences,
      ratio: state.settings.keywordRatio,
    );
  }

  /// 释放资源
  void disposePlayer() {
    ref.read(retellRecordingControllerProvider.notifier).setRecorder(null);
    _cleanup();
    _paragraphs = [];
    _allSentences = [];
    _keywordsMap = {};
    state = const RetellPlayerState(); // bookmarkedSentenceIndices 随之清空
  }

  // ========== 内部方法 ==========

  /// 播放当前段落
  ///
  /// 使用局部变量 `sid` 捕获 sessionId，防止 pause/其他操作
  /// 覆写实例变量 `_sessionId` 后导致 guard 失效。
  ///
  /// 起播句决策（按优先级）：
  /// 1. [startLocalIdxOverride] 非空：直接使用（来自 `seekToSentence` 等用户主动操作），
  ///    同时**不重置 displayMode**（保留用户当前的查看模式）
  /// 2. [forceOffset] = true：消费 `_resumeStartLocalSentenceIndex`（不看段时长，用于 resume）
  /// 3. 否则按断点续学：段时长 > 10s 时消费字段，否则段头开播
  ///
  /// `_resumeStartLocalSentenceIndex` 用完一次立即清零。
  Future<void> _playCurrentParagraph({
    int? startLocalIdxOverride,
    bool forceOffset = false,
  }) async {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;

    final int startLocalIdx;
    final bool fromOverride = startLocalIdxOverride != null;
    if (fromOverride) {
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

    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    _sessionId = engine.newSession();
    final sid = _sessionId; // 捕获局部变量

    // override 模式下不重置 displayMode（同段 seek 保留用户视图）；其他模式按既有逻辑
    final RetellDisplayMode? nextDisplayMode = fromOverride
        ? null
        : (state.userOverrodeDisplayMode ? null : RetellDisplayMode.hideAll);
    state = state.copyWith(
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: startLocalIdx,
      isRetellCountdown: false,
      isWaitingForUser: false,
      stepFinished: false,
      displayMode: nextDisplayMode,
    );
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

    // 播放完成后进入复述阶段（用局部变量检查）
    final sessionStillActive = engine.isActiveSession(sid);
    AppLogger.log(
      'RetellPlayer',
      'playRangeOnce 返回: sessionActive=$sessionStillActive, '
          'sid=$sid, paragraph=${state.currentParagraphIndex}',
    );
    if (!sessionStillActive) return;

    // 通过 recorder 记录听力时长、输入词数、已学词形
    final paragraphWordCount = countWordsInSentences(sentences);
    final durationMs = (end - start).inMilliseconds;
    final paragraphText = sentences.map((s) => s.text).join(' ');
    _recorder.onInputCompleted(
      durationMs: durationMs,
      wordCount: paragraphWordCount,
      text: paragraphText,
    );

    _positionSub?.cancel();

    if (_waitAfterCurrentParagraph) {
      _waitAfterCurrentParagraph = false;
      state = state.copyWith(
        phase: RetellPhase.retelling,
        isPlaying: false,
        playingSentenceIndex: -1,
        isRetellCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        isWaitingForUser: true,
        displayMode: state.userOverrodeDisplayMode
            ? null
            : RetellDisplayMode.keywordsOnly,
      );
      return;
    }

    _enterRetellingPhase();
  }

  /// 订阅 position stream，二分查找定位当前句子
  void _startPositionTracking(List<Sentence> sentences) {
    _positionSub?.cancel();
    _lastSkippedSilenceKey = null; // 新段落，清空去重指针
    final engine = ref.read(foregroundAudioEngineProvider.notifier);

    _positionSub = engine.absolutePositionStream.listen((position) {
      if (!engine.isActiveSession(_sessionId)) return;
      if (state.phase != RetellPhase.listening) return;
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
  /// 仅在 listening 阶段触发；段落 clip 范围 = [first.start, last.end]，
  /// 因此 detector 的末尾分支永远不会命中——这里只会在中间 gap 触发。
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
      ref
          .read(foregroundAudioEngineProvider.notifier)
          .seekToAbsolute(result.skipTo),
    );

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

    // 如果没有精确匹配，返回最近的
    return lo.clamp(0, sentences.length - 1);
  }

  /// 进入复述阶段
  ///
  /// 不自动启动倒计时。倒计时由 screen 层在录音评估完成后触发
  /// [startPostEvaluationPause]。
  void _enterRetellingPhase() {
    AppLogger.log(
      'RetellPlayer',
      '→ _enterRetellingPhase: paragraph=${state.currentParagraphIndex}',
    );
    state = state.copyWith(
      phase: RetellPhase.retelling,
      isPlaying: false,
      playingSentenceIndex: -1,
      isWaitingForUser: false,
      displayMode: state.userOverrodeDisplayMode
          ? null
          : RetellDisplayMode.keywordsOnly,
    );
  }

  /// 启动评估后段间停顿倒计时（由 screen 层在评估完成后调用）
  ///
  /// [score] 评估分数（0.0~1.0），Smart 模式下用于缩短倒计时。
  /// 手动模式下直接 return，不启动倒计时，由用户手动推进。
  void startPostEvaluationPause({double? score}) {
    if (state.phase != RetellPhase.retelling) return;
    if (state.isRetellCountdown) return;
    if (state.isWaitingForUser) return;
    if (state.settings.isManualMode) return;

    final pauseDuration = state.settings.calculatePauseDuration(
      currentParagraphDuration,
      score: score,
    );
    _startRetellCountdown(pauseDuration);
  }

  /// 开始复述倒计时
  void _startRetellCountdown(Duration duration) {
    final runId = ++_retellCountdownRunId;
    state = state.copyWith(
      isRetellCountdown: true,
      pauseDuration: duration,
      pauseRemaining: duration,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isWaitingForUser: false,
    );

    _countdown.start(duration).then((_) {
      // 倒计时正常结束（非取消）时推进
      if (state.isRetellCountdown && runId == _retellCountdownRunId) {
        _onRetellCountdownFinished();
      }
    });
  }

  /// 复述倒计时结束
  Future<void> _onRetellCountdownFinished() async {
    // 复述完成 = 输出词数
    final session = ref.read(learningSessionProvider.notifier);
    final paragraphWordCount = countWordsInSentences(currentParagraphSentences);
    session.addOutputWords(paragraphWordCount);

    // 检查遍数（手动模式视为单遍）
    final effectiveRepeatCount = state.settings.isManualMode
        ? 1
        : state.settings.repeatCount;
    if (effectiveRepeatCount == 0 ||
        state.currentRepeatCount < effectiveRepeatCount) {
      // 还有遍数 → 直接回到 listening phase，不经过 isRetellCountdown=false 中间状态
      state = state.copyWith(currentRepeatCount: state.currentRepeatCount + 1);
      await _playCurrentParagraph();
    } else {
      // 推进下一段（goToNextParagraph 内部会设 isRetellCountdown: false）
      await goToNextParagraph();
    }
  }

  /// 取消所有异步操作并停止音频
  ///
  /// 这里必须等待底层 stop 完成，避免在切段时与下一次 setClip
  /// 并发触发 just_audio 的 "Loading interrupted"。
  Future<void> _cancelAll() async {
    final engine = ref.read(foregroundAudioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateRetellCountdown();
    _waitAfterCurrentParagraph = false;
    await engine.stopPlayback();
  }

  /// 使当前复述倒计时失效
  ///
  /// 必须在 await 任何异步中断逻辑前调用，避免取消后的过期倒计时回调继续推进段落。
  void _invalidateRetellCountdown() {
    _retellCountdownRunId += 1;
    _countdown.cancel();
  }

  /// 清理资源
  void _cleanup() {
    _positionSub?.cancel();
    _invalidateRetellCountdown();
    _waitAfterCurrentParagraph = false;
    _positionSub = null;
  }
}

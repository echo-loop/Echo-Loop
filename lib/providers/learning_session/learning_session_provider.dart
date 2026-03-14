/// 学习会话层 Provider
///
/// 管理学习模式状态（盲听等），进入盲听时暂停 ListeningPractice
/// 的 stream 监听，通过 BlindListenPlayer 直接操作 AudioEngine。
/// 负责：进入/退出学习模式、保存/恢复用户播放设置、监听播放完成。
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/playback_settings.dart';
import '../../models/sentence.dart';
import '../../services/study_time_service.dart';
import '../../utils/word_counter.dart';
import '../daily_study_time_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../study_stats_provider.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../listen_and_repeat_turn_controller_provider.dart';
import '../speech_practice_session_provider.dart';
import '../listening_practice/listening_practice_provider.dart';
import 'blind_listen_player_provider.dart';
import 'intensive_listen_player_provider.dart';
import 'listen_and_repeat_player_provider.dart';
import 'retell_player_provider.dart';
import 'review_difficult_practice_provider.dart';
import 'sentence_playback_engine.dart';
import '../../database/providers.dart';

part 'learning_session_provider.g.dart';

/// 学习模式类型
enum LearningMode {
  /// 全文盲听
  blindListen,

  /// 逐句精听
  intensiveListen,

  /// 难句跟读
  listenAndRepeat,

  /// 段级复述
  retell,

  /// 复习难句补练
  reviewDifficultPractice,
}

/// 学习会话状态
class LearningSessionState {
  /// 当前学习模式（null = 自由收听）
  final LearningMode? learningMode;

  /// 本遍盲听是否已播放完成
  final bool blindListenCompleted;

  /// 当前盲听遍数（从 1 开始，表示正在听第几遍）
  final int blindListenPassCount;

  /// 当前学习的音频 ID
  final String? audioItemId;

  /// 进入学习模式前的用户播放设置（退出时恢复）
  final PlaybackSettings? savedSettings;

  /// 是否为自由练习模式（已完成步骤的单独练习，不计入遍数、不弹完成对话框）
  final bool isFreePlay;

  /// 目标盲听遍数（暂时硬编码，后续由 AI 决定）
  final int targetBlindListenPasses;

  const LearningSessionState({
    this.learningMode,
    this.blindListenCompleted = false,
    this.blindListenPassCount = 0,
    this.audioItemId,
    this.savedSettings,
    this.isFreePlay = false,
    this.targetBlindListenPasses = 1,
  });

  /// 是否处于学习模式中
  bool get isInLearningMode => learningMode != null;

  /// 是否还有剩余遍数未完成
  ///
  /// `blindListenPassCount` 表示"正在听第几遍"，完成后才 +1，
  /// 所以用 `<` 比较：正在听的这一遍还没达到目标时返回 true。
  bool get hasRemainingPasses => blindListenPassCount < targetBlindListenPasses;

  LearningSessionState copyWith({
    LearningMode? learningMode,
    bool? blindListenCompleted,
    int? blindListenPassCount,
    String? audioItemId,
    PlaybackSettings? savedSettings,
    bool? isFreePlay,
    int? targetBlindListenPasses,
    bool clearLearningMode = false,
    bool clearSavedSettings = false,
    bool clearAudioItemId = false,
  }) {
    return LearningSessionState(
      learningMode: clearLearningMode
          ? null
          : (learningMode ?? this.learningMode),
      blindListenCompleted: blindListenCompleted ?? this.blindListenCompleted,
      blindListenPassCount: blindListenPassCount ?? this.blindListenPassCount,
      audioItemId: clearAudioItemId ? null : (audioItemId ?? this.audioItemId),
      savedSettings: clearSavedSettings
          ? null
          : (savedSettings ?? this.savedSettings),
      isFreePlay: isFreePlay ?? this.isFreePlay,
      targetBlindListenPasses:
          targetBlindListenPasses ?? this.targetBlindListenPasses,
    );
  }
}

/// 学习会话 Provider
///
/// 作为播放器之上的学习流程控制层。
/// 进入盲听模式时暂停 LP 监听、初始化 BlindListenPlayer，
/// 退出时停止盲听播放、恢复 LP 监听。
@Riverpod(keepAlive: true)
class LearningSession extends _$LearningSession {
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  /// 盲听位置监听（逐句计入输入词数）
  StreamSubscription<Duration>? _blindListenPositionSub;

  /// 盲听已计入词数的最大句子索引（-1 表示尚无句子被计入）
  int _blindListenLastCountedIndex = -1;

  /// 学习计时器，进入学习模式时启动，退出时停止
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 学习计时器是否正在运行（仅用于测试验证）
  @visibleForTesting
  bool get isStudyTimerRunning => _studyStopwatch.isRunning;

  /// App 生命周期监听器，用于在后台暂停计时
  late final AppLifecycleListener _lifecycleListener;

  /// 学习时长存储服务
  final StudyTimeService _studyTimeService = StudyTimeService();

  @override
  LearningSessionState build() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChanged,
    );
    ref.onDispose(() {
      _playerStateSub?.cancel();
      _blindListenPositionSub?.cancel();
      _saveStudyTime();
      _lifecycleListener.dispose();
    });
    return const LearningSessionState();
  }

  /// App 生命周期变化时，根据音频播放状态决定是否暂停计时
  ///
  /// - 进入后台/非活跃：如果音频没在播放，暂停 Stopwatch（避免挂起时间被计入）
  /// - 回到前台：如果当前在学习模式且 Stopwatch 未运行，恢复计时
  void _onAppLifecycleStateChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      // 进入后台：如果音频没在播放，暂停计时
      if (_studyStopwatch.isRunning) {
        final isPlaying = ref.read(audioEngineProvider.notifier).isPlaying;
        if (!isPlaying) {
          _studyStopwatch.stop();
        }
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      // 回到前台：如果在学习模式中，恢复计时
      if (state.isInLearningMode && !_studyStopwatch.isRunning) {
        _studyStopwatch.start();
      }
    }
  }

  /// 停止计时并保存已记录的学习时长
  Future<void> _saveStudyTime() async {
    if (!_studyStopwatch.isRunning &&
        _studyStopwatch.elapsed == Duration.zero) {
      return;
    }
    _studyStopwatch.stop();
    final seconds = _studyStopwatch.elapsed.inSeconds;
    _studyStopwatch.reset();
    if (seconds > 0) {
      await _studyTimeService.addStudyTime(seconds);
    }
  }

  /// 立即持久化输入词数（每播完一句调用，不丢数据）
  ///
  /// 写入后刷新统计 UI，使词数实时可见。
  void addInputWords(int count) {
    if (count > 0) {
      _studyTimeService.addInputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

  /// 立即持久化输出词数（每完成一次跟读/复述调用，不丢数据）
  ///
  /// 写入后刷新统计 UI，使词数实时可见。
  void addOutputWords(int count) {
    if (count > 0) {
      _studyTimeService.addOutputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

  /// 异步记录一句已听到的词形，不阻塞播放流程。
  void recordLearnedSentence(String text) {
    final tracker = _readLearnedVocabularyTracker();
    if (tracker == null) return;
    unawaited(tracker.recordSentence(text));
  }

  /// 异步记录一组已听到的句子词形，适合段落播放完成时调用。
  void recordLearnedSentences(Iterable<Sentence> sentences) {
    final tracker = _readLearnedVocabularyTracker();
    if (tracker == null) return;
    unawaited(tracker.recordSentences(sentences));
  }

  /// 测试环境可能未注入数据库，此时跳过词形统计即可。
  dynamic _readLearnedVocabularyTracker() {
    try {
      return ref.read(learnedVocabularyTrackerProvider);
    } on UnimplementedError {
      return null;
    }
  }

  /// 尽量在退出时落掉待写入的词形统计。
  Future<void> _flushLearnedVocabulary() async {
    final tracker = _readLearnedVocabularyTracker();
    if (tracker == null) return;
    await tracker.flush();
  }

  /// 进入全文盲听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听（避免 LP 干扰盲听播放）
  /// 3. 初始化 BlindListenPlayer，从数据库读取已有遍数
  /// 4. 开始监听播放完成事件
  Future<void> enterBlindListenMode(
    String audioItemId, {
    bool isFreePlay = false,
  }) async {
    _studyStopwatch.start();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取已完成遍数
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[audioItemId];
    final dbPassCount = progress?.blindListenPassCount ?? 0;

    // 保存用户原始设置，遍数从数据库已完成遍数 + 1 开始（当前正在听的这一遍）
    state = state.copyWith(
      learningMode: LearningMode.blindListen,
      blindListenCompleted: false,
      blindListenPassCount: dbPassCount + 1,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听，避免干扰盲听播放
    practice.suspendListeners();

    // 确保音频引擎已加载目标音频
    // （LearningPlanScreen.initState 中的 loadAudio 是异步且未 await 的，
    //   用户快速点击时引擎可能仍在加载中，currentAudioId 还是上一首音频）
    await _ensureAudioLoaded(audioItemId);

    // 初始化盲听播放器，始终从音频开头播放（激励用户一次听完）
    final engineState = ref.read(audioEngineProvider);
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    blindPlayer.initialize(engineState.totalDuration ?? Duration.zero);
    await blindPlayer.seekTo(Duration.zero);

    // 开始逐句追踪输入词数
    _startBlindListenWordTracking();

    // 开始监听播放完成
    _startListeningForCompletion();
  }

  /// 再听一遍
  ///
  /// 重置完成状态，递增遍数，通过 BlindListenPlayer 从头开始播放。
  Future<void> replayBlindListen() async {
    _blindListenLastCountedIndex = -1;
    state = state.copyWith(
      blindListenCompleted: false,
      blindListenPassCount: state.blindListenPassCount + 1,
    );

    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    await blindPlayer.resetAndPlay();
  }

  /// 进入逐句精听模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 IntensiveListenPlayer，从数据库读取断点句子索引
  Future<void> enterIntensiveListenMode(
    String audioItemId,
    List<Sentence> sentences, {
    bool isFreePlay = false,
  }) async {
    _studyStopwatch.start();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;
    final progressNotifier = ref.read(
      learningProgressNotifierProvider.notifier,
    );

    // 进入前统一读取最新持久化断点，避免命中旧内存态。
    final progress = await progressNotifier.getLatestOrEnsureProgress(
      audioItemId,
    );
    final startIndex = progress.intensiveListenSentenceIndex ?? 0;

    state = state.copyWith(
      learningMode: LearningMode.intensiveListen,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化精听播放器
    final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
    await intensivePlayer.initialize(sentences, startIndex: startIndex);
  }

  /// 进入难句跟读模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 从 BookmarkDao 读取难句索引集 → 过滤句子
  /// 4. 从 LearningProgress 读取断点 shadowingSentenceIndex
  /// 5. 根据 difficulty 计算 targetPlayCount
  /// 6. 初始化 ListenAndRepeatPlayer
  Future<void> enterListenAndRepeatMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
  }) async {
    _studyStopwatch.start();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );

    // 过滤出难句列表
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 跟读断点与难度都需要优先使用持久化的最新值，避免只吃到陈旧内存态。
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    final startIndex = progress.shadowingSentenceIndex ?? 0;
    final difficultyValue = progress.difficulty.value;
    final targetPlayCount = targetPlayCountForDifficulty(difficultyValue);

    state = state.copyWith(
      learningMode: LearningMode.listenAndRepeat,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化跟读播放器
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await player.initialize(
      difficultSentences,
      startIndex: startIndex,
      targetPlayCount: targetPlayCount,
    );
  }

  /// 进入段级复述模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 初始化 RetellPlayer（段落分组 + 关键词映射 + 断点索引）
  Future<void> enterRetellMode(
    String audioItemId,
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    bool isFreePlay = false,
  }) async {
    _studyStopwatch.start();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 复述断点保存的是段首句子的全局索引，进入时需要读取最新持久化值。
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    final startSentenceIndex = progress.retellParagraphIndex;

    state = state.copyWith(
      learningMode: LearningMode.retell,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化复述播放器
    final player = ref.read(retellPlayerProvider.notifier);
    player.initialize(
      paragraphs,
      keywordsMap,
      startSentenceIndex: startSentenceIndex,
    );
  }

  /// 进入复习难句补练模式
  ///
  /// 1. 保存当前用户播放设置
  /// 2. 暂停 LP 的 stream 监听
  /// 3. 从 BookmarkDao 读取难句 → 过滤句子
  /// 4. 初始化 ReviewDifficultPractice
  Future<void> enterReviewDifficultPracticeMode(
    String audioItemId,
    List<Sentence> allSentences, {
    bool isFreePlay = false,
  }) async {
    _studyStopwatch.start();
    final practice = ref.read(listeningPracticeProvider.notifier);
    final currentSettings = ref.read(listeningPracticeProvider).settings;

    // 从数据库读取难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );

    // 过滤出难句列表
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 难句补练进入时优先恢复最新持久化断点。
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    final startIndex = progress.difficultPracticeSentenceIndex ?? 0;

    state = state.copyWith(
      learningMode: LearningMode.reviewDifficultPractice,
      blindListenCompleted: false,
      audioItemId: audioItemId,
      savedSettings: currentSettings,
      isFreePlay: isFreePlay,
    );

    // 暂停 LP 的 stream 监听
    practice.suspendListeners();

    // 初始化难句补练播放器（传入断点索引）
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.initialize(difficultSentences, startIndex: startIndex);
  }

  /// 退出学习模式
  ///
  /// 根据当前学习模式分支处理：停止播放、释放资源、恢复 LP 监听。
  Future<void> exitLearningMode() async {
    await _saveStudyTime();
    final mode = state.learningMode;

    _playerStateSub?.cancel();
    _playerStateSub = null;

    if (mode == LearningMode.blindListen) {
      // 补计尚未被位置追踪计入的句子（用户中途退出时）
      _countRemainingBlindListenWords();
      _blindListenPositionSub?.cancel();
      _blindListenPositionSub = null;
      // 停止盲听播放并释放资源
      final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
      await blindPlayer.pause();
      blindPlayer.disposePlayer();
    } else if (mode == LearningMode.intensiveListen) {
      // 释放精听播放器资源
      final intensivePlayer = ref.read(intensiveListenPlayerProvider.notifier);
      intensivePlayer.disposePlayer();
    } else if (mode == LearningMode.listenAndRepeat) {
      // 清理 turn controller 定时器，防止退出后自动重试录音
      ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
      // 释放跟读播放器资源
      final player = ref.read(listenAndRepeatPlayerProvider.notifier);
      player.disposePlayer();
    } else if (mode == LearningMode.retell) {
      // 释放复述播放器资源
      final retellPlayer = ref.read(retellPlayerProvider.notifier);
      retellPlayer.disposePlayer();
    } else if (mode == LearningMode.reviewDifficultPractice) {
      // 释放难句补练播放器资源
      final player = ref.read(reviewDifficultPracticeProvider.notifier);
      player.disposePlayer();
    }

    // 通用：清除 clip 防止残留影响 LP 的 absolutePositionStream
    final engine = ref.read(audioEngineProvider.notifier);
    await engine.clearClip();
    await ref.read(speechPracticeSessionProvider.notifier).disposeSession();

    // 恢复 LP 的 stream 监听
    final practice = ref.read(listeningPracticeProvider.notifier);
    practice.resumeListeners();

    // 同步精听期间新增的书签到 LP 内存状态
    await practice.syncBookmarks();

    // 停止引擎播放（确保干净退出）
    await practice.stop();

    await _flushLearnedVocabulary();

    // 通知 UI 刷新今日学习时长
    ref.read(dailyStudyTimeProvider.notifier).refresh();
    ref.read(studyStatsNotifierProvider.notifier).refresh();

    state = const LearningSessionState();
  }

  /// 标记本遍盲听完成并持久化遍数到数据库
  Future<void> _markBlindListenCompleted() async {
    if (state.learningMode != LearningMode.blindListen) return;
    if (state.blindListenCompleted) return;

    state = state.copyWith(blindListenCompleted: true);

    // 播放完成后暂停并将进度条回到零点，等待用户下一步操作
    final blindPlayer = ref.read(blindListenPlayerProvider.notifier);
    await blindPlayer.pause();
    await blindPlayer.seekTo(Duration.zero);

    // 补计尚未被位置追踪计入的剩余句子词数
    _countRemainingBlindListenWords();

    // 持久化盲听遍数到数据库
    final audioItemId = state.audioItemId;
    if (audioItemId != null) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementBlindListenPassCount(audioItemId);
    }

    // 自由练习模式：递增会话内遍数并重置完成标志，使下一遍完成时能再次触发
    // 正常模式由对话框的 replayBlindListen() 处理递增和重置
    if (state.isFreePlay) {
      _blindListenLastCountedIndex = -1;
      state = state.copyWith(
        blindListenCompleted: false,
        blindListenPassCount: state.blindListenPassCount + 1,
      );
    }
  }

  /// 开始监听盲听播放位置，逐句计入输入词数
  ///
  /// 当播放位置越过某句的 endTime 时，立即将该句词数计入。
  /// 这样即使用户中途退出，已播过的句子词数也不会丢失。
  void _startBlindListenWordTracking() {
    _blindListenLastCountedIndex = -1;
    _blindListenPositionSub?.cancel();

    final sentences = ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty) return;

    final engine = ref.read(audioEngineProvider.notifier);
    _blindListenPositionSub = engine.absolutePositionStream.listen((position) {
      // 找出所有已播放完成（position >= endTime）但尚未计入的句子
      for (
        var i = _blindListenLastCountedIndex + 1;
        i < sentences.length;
        i++
      ) {
        if (position >= sentences[i].endTime) {
          addInputWords(countWords(sentences[i].text));
          recordLearnedSentence(sentences[i].text);
          _blindListenLastCountedIndex = i;
        } else {
          break;
        }
      }
    });
  }

  /// 补计盲听中尚未被位置追踪计入的句子
  ///
  /// 两种场景调用：
  /// 1. 播放完成时 — position stream 可能未触发最后一句的 endTime
  /// 2. 用户中途退出 — 计入正在听的那句（position >= startTime）
  void _countRemainingBlindListenWords() {
    final sentences = ref.read(listeningPracticeProvider).sentences;
    if (sentences.isEmpty) return;

    final position = ref.read(blindListenPlayerProvider).position;
    for (var i = _blindListenLastCountedIndex + 1; i < sentences.length; i++) {
      if (position >= sentences[i].startTime) {
        addInputWords(countWords(sentences[i].text));
        recordLearnedSentence(sentences[i].text);
        _blindListenLastCountedIndex = i;
      } else {
        break;
      }
    }
  }

  /// 等待音频引擎加载目标音频
  ///
  /// LearningPlanScreen.initState 中的 loadAudio 是 fire-and-forget 的异步调用，
  /// 用户快速点击"开始"时引擎可能还在加载中。此方法轮询等待引擎完成加载，
  /// 最多等待 10 秒（200 × 50ms），避免播放错误的音频。
  Future<void> _ensureAudioLoaded(String audioItemId) async {
    if (ref.read(audioEngineProvider).currentAudioId == audioItemId) return;
    for (var i = 0; i < 200; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      final current = ref.read(audioEngineProvider);
      if (current.currentAudioId == audioItemId && !current.isLoading) return;
    }
  }

  /// 监听音频播放完成事件
  void _startListeningForCompletion() {
    _playerStateSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);
    _playerStateSub = engine.playerStateStream.listen((playerState) {
      if (playerState.processingState == ja.ProcessingState.completed) {
        _markBlindListenCompleted();
      }
    });
  }
}

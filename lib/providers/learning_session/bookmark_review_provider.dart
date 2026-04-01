/// 收藏句子复习 Provider
///
/// 加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练（ReviewDifficultPractice）一致：
/// 盲听 N 遍 → 句间停顿 → 自动推进；支持偷看字幕、听不懂进入跟读模式。
/// 支持手动模式（盲听强制 1 遍、跟读强制 1 遍）和自动录音（跟读停顿触发）。
///
/// 与难句补练的关键差异：
/// - 数据来源：全局 bookmarks（跨音频）
/// - 播放句子时需检测是否需要切换音频（loadAudio）
/// - 默认按音频分组乱序
/// - 不关联 LearningProgress / LearningSession
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import '../../services/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/daos/bookmark_dao.dart';
import '../../models/audio_item.dart';
import '../../models/bookmark_sentence.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/sentence.dart';
import '../../database/providers.dart';
import '../../models/study_stage.dart';
import '../../services/learned_vocabulary_tracker.dart';
import '../../services/study_event_recorder.dart';
import '../../services/study_time_service.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../daily_study_time_provider.dart';
import '../learned_vocabulary_tracker_provider.dart';
import '../study_stats_provider.dart';
import 'countdown_controller.dart';
import 'review_difficult_practice_provider.dart';
import 'sentence_playback_engine.dart';
import '../shadowing/shadowing_recording_controller.dart';

part 'bookmark_review_provider.g.dart';

/// 收藏复习 Provider
///
/// 复用 [ReviewDifficultPracticeState] 作为状态类。
/// 内部维护 [List<BookmarkSentence>] 用于跨音频播放。
@Riverpod(keepAlive: true)
class BookmarkReview extends _$BookmarkReview {
  /// 收藏句子列表（乱序后）
  List<BookmarkSentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  /// 学习事件记录器
  late StudyEventRecorder _recorder;

  /// 获取 AudioItemDao 的回调（通过 ref 注入）
  late dynamic Function(String) _getAudioItemById;

  /// 学习时长存储服务
  late StudyTimeService _studyTimeService;

  /// 学习计时器
  final Stopwatch _studyStopwatch = Stopwatch();

  /// 评估后倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 倒计时运行 ID（用于使过期倒计时失效）
  int _countdownRunId = 0;

  /// 周期保存定时器（每 _maxSessionSeconds 自动保存并重置计时器）
  Timer? _periodicSaveTimer;

  /// 是否正在执行保存（防止 timer 回调与 dispose 竞态）
  bool _isSaving = false;

  /// 单次会话最大计入时长（防止用户睡着等异常场景）
  static const _maxSessionSeconds = 5 * 60; // 5 分钟

  /// App 生命周期监听器，用于在后台暂停计时
  late AppLifecycleListener _lifecycleListener;

  @override
  ReviewDifficultPracticeState build() {
    _studyTimeService = ref.read(studyTimeServiceProvider);

    LearnedVocabularyTracker? vocabTracker;
    try {
      vocabTracker = ref.read(learnedVocabularyTrackerProvider);
    } on UnimplementedError {
      // 测试环境可能未注入数据库，忽略词形统计即可。
    }
    _recorder = StudyEventRecorder(
      studyTimeService: _studyTimeService,
      vocabTracker: vocabTracker,
      stage: StudyStage.bookmarkReview,
    );

    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
      recorder: _recorder,
    );
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChanged,
    );
    ref.onDispose(() {
      _engine.cleanup();
      _countdown.cancel();
      _periodicSaveTimer?.cancel();
      _saveAndRefreshStudyTime();
      _lifecycleListener.dispose();
    });
    return const ReviewDifficultPracticeState();
  }

  /// App 生命周期变化时暂停/恢复计时
  ///
  /// - 进入后台：暂停所有计时器 + 取消周期保存
  /// - 回到前台：恢复计时 + 重新调度周期保存
  void _onAppLifecycleStateChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden) {
      _studyStopwatch.stop();
      _stopPeriodicSaveTimer();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (_sentences.isNotEmpty &&
          !state.stepFinished &&
          !_studyStopwatch.isRunning) {
        _studyStopwatch.start();
        _schedulePeriodicSave();
      }
    }
  }

  /// 调度下一次周期保存（one-shot Timer，避免 periodic 的 async 竞态）
  void _schedulePeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer(
      const Duration(seconds: _maxSessionSeconds),
      () async {
        if (_isSaving || _sentences.isEmpty) return;
        await _saveAndRefreshStudyTime();
        // 保存后如果仍在学习中，重新启动计时并调度下一次
        if (_sentences.isNotEmpty && !state.stepFinished) {
          _studyStopwatch.start();
          _schedulePeriodicSave();
        }
      },
    );
  }

  /// 停止周期保存定时器
  void _stopPeriodicSaveTimer() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  /// 初始化收藏复习
  ///
  /// [bookmarks] 来自 BookmarkDao.watchAllWithAudioName() 的快照
  /// [getAudioItemById] 根据 audioItemId 获取 AudioItem 行数据
  void initialize(
    List<BookmarkWithAudio> bookmarks, {
    required Future<dynamic> Function(String) getAudioItemById,
  }) {
    _engine.cleanup();
    _getAudioItemById = getAudioItemById;

    // 过滤掉无效书签（迁移遗留的 startTime==endTime==0 条目）
    final validBookmarks = bookmarks.where((b) {
      final duration = b.bookmark.endTime - b.bookmark.startTime;
      return duration > 0 && b.bookmark.sentenceText.isNotEmpty;
    }).toList();

    // 按音频 ID 分组
    final grouped = <String, List<BookmarkWithAudio>>{};
    for (final b in validBookmarks) {
      (grouped[b.bookmark.audioItemId] ??= []).add(b);
    }

    // 方案 A：音频组间乱序，组内保持 sentenceIndex 顺序
    final audioIds = grouped.keys.toList()..shuffle();

    _sentences = [];
    for (final audioId in audioIds) {
      final items = grouped[audioId]!;
      // 组内已按 sentenceIndex 排序（DAO 查询保证）
      for (final item in items) {
        _sentences.add(
          BookmarkSentence(
            sentence: Sentence(
              index: item.bookmark.sentenceIndex,
              text: item.bookmark.sentenceText,
              startTime: Duration(
                milliseconds: (item.bookmark.startTime * 1000).round(),
              ),
              endTime: Duration(
                milliseconds: (item.bookmark.endTime * 1000).round(),
              ),
              isBookmarked: true,
            ),
            audioItemId: item.bookmark.audioItemId,
            audioName: item.audioName,
            originalSentenceIndex: item.bookmark.sentenceIndex,
          ),
        );
      }
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );

    // 启动学习计时 + 周期保存
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave();

    // 注入 recorder 到录音控制器
    ref
        .read(shadowingRecordingControllerProvider.notifier)
        .setRecorder(_recorder);
  }

  /// 更新练习设置（仅会话内生效）
  ///
  /// 更新后中断当前播放，以新设置重新开始当前句子。
  void updateSettings(DifficultPracticeSettings newSettings) {
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    state = state.copyWith(
      settings: newSettings,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isPostEvalCountdown: false,
    );
  }

  /// 当前句进入手动模式（工具栏点击、手动停止播放等触发）
  ///
  /// 同时暂停盲听倒计时 + 取消评估后倒计时，防止自动推进。
  void enterManualForSentence() {
    if (state.isManualForSentence) return;
    state = state.copyWith(isManualForSentence: true);
    _engine.pauseCountdown();
    // 取消评估后倒计时，防止手动模式下自动推进
    _invalidatePostEvalCountdown();
  }

  /// 获取当前句子索引
  int get currentIndex => state.currentSentenceIndex;

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex].sentence
      : null;

  /// 获取当前收藏句子（含音频信息）
  BookmarkSentence? get currentBookmarkSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 开始播放
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startSentence();
  }

  /// 外部中断播放通知（如意群播放）
  void notifyExternalStop() {
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 暂停播放
  void pause() {
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    _studyStopwatch.stop();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放
  ///
  /// 跟读模式下从当前遍数恢复跟读循环。
  /// 盲听模式下从当前句重新开始。
  Future<void> resume() async {
    _studyStopwatch.start();
    if (state.isAnnotationMode) {
      _startShadowReading(startPlayCount: state.currentPlayCount);
      return;
    }
    await _startSentence(startPlayCount: state.currentPlayCount);
  }

  /// 进入跟读模式（听不懂）
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;
    _engine.invalidateSession();
    _startShadowReading();
  }

  /// 设置偷看字幕状态
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 取消当前句子的收藏
  ///
  /// 返回被移除的 [BookmarkSentence]（供外部调用 BookmarkDao 删除）。
  BookmarkSentence? removeBookmark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();
    _invalidatePostEvalCountdown();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(isPlaying: false, totalSentences: 0);
      return removed;
    }

    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      isPlaying: false,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      currentPlayCount: 1,
    );

    return removed;
  }

  /// 切换当前句子的收藏标记（不从列表移除）
  ///
  /// 仅更新内存中的 isBookmarked 状态并触发 UI 重建，
  /// DB 操作由 Screen 层负责。
  void toggleCurrentBookmark() {
    if (_sentences.isEmpty) return;
    final idx = state.currentSentenceIndex;
    final s = _sentences[idx];
    _sentences[idx] = s.copyWithBookmark(!s.sentence.isBookmarked);
    state = state.copyWith(bookmarkVersion: state.bookmarkVersion + 1);
  }

  /// 跳到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isManualForSentence: false,
    );
    await _startSentence();
  }

  /// 跳到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      isManualForSentence: false,
    );
    await _startSentence();
  }

  /// 暂停倒计时
  void pauseCountdown() {
    _engine.pauseCountdown();
    state = state.copyWith(isCountdownPaused: true);
  }

  /// 恢复倒计时
  void resumeCountdown() {
    _engine.resumeCountdown();
    state = state.copyWith(isCountdownPaused: false);
  }

  /// 倒计时期间重播当前句子
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    if (state.isAnnotationMode) {
      _startShadowReading(startPlayCount: state.currentPlayCount);
    } else {
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
      await _startSentence(startPlayCount: state.currentPlayCount);
    }
  }

  /// 录音评估完成后启动 review 倒计时（5s）。
  ///
  /// 仅在跟读模式（annotationMode）下生效。
  void startPostEvaluationPause() {
    if (!state.isPauseBetweenPlays) return;
    if (!state.isAnnotationMode) return;
    if (state.totalSentences == 0) return;
    if (state.isManualMode) return;

    const pauseDuration = Duration(seconds: 5);
    final runId = ++_countdownRunId;

    state = state.copyWith(
      isPostEvalCountdown: true,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      pauseDuration: pauseDuration,
      pauseRemaining: pauseDuration,
    );

    _countdown
        .start(pauseDuration, (remaining) {
          state = state.copyWith(pauseRemaining: remaining);
        })
        .then((_) {
          if (runId == _countdownRunId &&
              state.isPauseBetweenPlays &&
              state.isAnnotationMode) {
            completePausedTurn();
          }
        });
  }

  /// 暂停评估后倒计时
  void pausePostEvalCountdown() {
    if (!_countdown.isActive || _countdown.isPaused) return;
    _countdown.pause();
    state = state.copyWith(isCountdownPaused: true);
  }

  /// 恢复评估后倒计时
  void resumePostEvalCountdown() {
    if (!_countdown.isActive || !_countdown.isPaused) return;
    _countdown.resume();
    state = state.copyWith(isCountdownPaused: false);
  }

  /// 取消评估后倒计时（不推进到下一句）
  void cancelPostEvalCountdown() {
    _invalidatePostEvalCountdown();
    state = state.copyWith(
      isPostEvalCountdown: false,
      isCountdownPaused: false,
      pauseRemaining: Duration.zero,
    );
  }

  /// 使当前评估后倒计时失效，同时清除 state 中的倒计时标志
  ///
  /// 将 timer 取消和 state 清除合并在一起，避免调用点遗漏 copyWith。
  void _invalidatePostEvalCountdown() {
    _countdownRunId += 1;
    _countdown.cancel();
    if (state.isPostEvalCountdown) {
      state = state.copyWith(
        isPostEvalCountdown: false,
        isCountdownPaused: false,
      );
    }
  }

  /// 强制完成（用户在最后一句主动点击完成按钮）
  void forceComplete() {
    _engine.invalidateSession();
    _invalidatePostEvalCountdown();
    _studyStopwatch.stop();
    _stopPeriodicSaveTimer();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  /// 立即完成当前停顿回合，继续后续播放流程。
  ///
  /// 由录音评估完成后的倒计时或 screen 层直接调用。
  Future<void> completePausedTurn() async {
    _invalidatePostEvalCountdown();
    if (!state.isPauseBetweenPlays || !state.isAnnotationMode) return;

    // 句间停顿 → 走 autoAdvance 逻辑
    if (state.isPauseBetweenSentences) {
      final isLastSentence =
          state.currentSentenceIndex >= state.totalSentences - 1;
      _engine.invalidateSession();
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isPostEvalCountdown: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        pauseRemaining: Duration.zero,
        isAnnotationMode: false,
      );
      if (isLastSentence) {
        // 复习完成，停止计时
        _studyStopwatch.stop();
        _stopPeriodicSaveTimer();
        state = state.copyWith(isPlaying: false, stepFinished: true);
      } else {
        state = state.copyWith(
          currentSentenceIndex: state.currentSentenceIndex + 1,
          currentPlayCount: 1,
          isTextRevealed: false,
        );
        await _startSentence();
      }
      return;
    }

    // 遍间停顿：递增遍数
    _engine.invalidateSession();
    state = state.copyWith(
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isPostEvalCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      pauseRemaining: Duration.zero,
    );

    final nextPlayCount = state.currentPlayCount + 1;
    if (nextPlayCount > state.targetRepeatCount) {
      // 跟读遍数用完 → 退出跟读模式 → autoAdvance
      state = state.copyWith(isAnnotationMode: false, isPlaying: false);
      await _autoAdvance();
      return;
    }

    // 还有遍数 → 继续下一遍
    _startShadowReading(startPlayCount: nextPlayCount);
  }

  /// 重置到第一句并重新乱序播放（"再来一遍"）
  Future<void> resetToStart() async {
    _invalidatePostEvalCountdown();
    // 先保存已累计时间
    _saveAndRefreshStudyTime();
    _engine.cleanup();

    // 重新按音频分组乱序
    final grouped = <String, List<BookmarkSentence>>{};
    for (final s in _sentences) {
      (grouped[s.audioItemId] ??= []).add(s);
    }
    final audioIds = grouped.keys.toList()..shuffle();
    _sentences = [];
    for (final audioId in audioIds) {
      _sentences.addAll(grouped[audioId]!);
    }

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );

    // 重新启动计时 + 周期保存
    _studyStopwatch.reset();
    _studyStopwatch.start();
    _schedulePeriodicSave();

    await startPlaying();
  }

  /// 释放资源
  void disposePlayer() {
    ref.read(shadowingRecordingControllerProvider.notifier).setRecorder(null);
    _stopPeriodicSaveTimer();
    _saveAndRefreshStudyTime();
    _engine.cleanup();
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  // ========== 内部方法 ==========

  /// 确保当前句子的音频已加载
  ///
  /// 如果当前 AudioEngine 加载的不是同一音频，则切换。
  /// 返回 false 表示加载失败（应跳过该句）。
  Future<bool> _ensureAudioLoaded(BookmarkSentence bookmarkSentence) async {
    final engineState = ref.read(audioEngineProvider);
    if (engineState.currentAudioId == bookmarkSentence.audioItemId) {
      return true;
    }

    try {
      final row = await _getAudioItemById(bookmarkSentence.audioItemId);
      if (row == null) return false;

      final audioItem = AudioItem(
        id: row.id,
        name: row.name,
        audioPath: row.audioPath,
        transcriptPath: row.transcriptPath,
        addedDate: row.addedDate,
        totalDuration: row.totalDuration,
        sentenceCount: row.sentenceCount,
        wordCount: row.wordCount,
        isStarred: row.isStarred,
        transcriptSource: TranscriptSource.fromIndex(row.transcriptSource),
        audioSha256: row.audioSha256,
        transcriptLanguage: row.transcriptLanguage,
      );

      final engine = ref.read(audioEngineProvider.notifier);
      await engine.loadAudio(audioItem, 1.0);
      return true;
    } catch (e) {
      AppLogger.log('Player', '✗ 收藏复习加载音频失败: $e');
      return false;
    }
  }

  /// 开始播放当前句子（盲听 N 遍）
  Future<void> _startSentence({int startPlayCount = 1}) async {
    final bookmarkSentence = currentBookmarkSentence;
    if (bookmarkSentence == null) return;

    final sentence = bookmarkSentence.sentence;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    // 确保音频已加载（跨音频切换）
    final loaded = await _ensureAudioLoaded(bookmarkSentence);
    if (!loaded) {
      // 音频加载失败，跳过该句
      AppLogger.log(
        'Player',
        '⚠ 收藏复习跳过句子（音频不可用）: ${bookmarkSentence.audioName}',
      );
      await _autoAdvance();
      return;
    }

    // 手动模式下盲听只播 1 遍
    final repeatCount = state.isManualMode
        ? 1
        : state.settings.blindListenRepeatCount;

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: startPlayCount,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      stepFinished: false,
    );

    // 盲听循环：1 遍时无遍间停顿，多遍时使用跟读停顿策略
    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: repeatCount,
      startPlayCount: startPlayCount,
      pauseCalculator: repeatCount > 1
          ? listenAndRepeatPauseCalculator
          : (_) => Duration.zero,
      onPlayCountChanged: repeatCount > 1
          ? (count) {
              state = state.copyWith(currentPlayCount: count, isPlaying: true);
            }
          : (_) {},
      onPauseStarted: repeatCount > 1
          ? (dur) {
              state = state.copyWith(
                isPauseBetweenPlays: true,
                isPlaying: false,
                isCountdownPaused: false,
                isCountdownFastForward: false,
                pauseDuration: dur,
                pauseRemaining: dur,
              );
            }
          : (_) {},
      onPauseEnded: repeatCount > 1
          ? () {
              state = state.copyWith(isPauseBetweenPlays: false);
            }
          : () {},
      onTick: repeatCount > 1
          ? (remaining) {
              state = state.copyWith(pauseRemaining: remaining);
            }
          : (_) {},
      onAllPlaysCompleted: () async {
        await _autoAdvance();
      },
    );
  }

  /// 开始跟读循环（显示字幕，播放 N 遍 + 跟读留白）
  ///
  /// [startPlayCount] 从第几遍开始（默认第 1 遍）。
  void _startShadowReading({int startPlayCount = 1}) {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    final wordCount = countWords(sentence.text);

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: startPlayCount,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      stepFinished: false,
    );

    _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: state.targetRepeatCount,
      startPlayCount: startPlayCount,
      pauseCalculator: listenAndRepeatPauseCalculator,
      onPlayCountChanged: (count) {
        state = state.copyWith(currentPlayCount: count, isPlaying: true);
      },
      onPauseStarted: (dur) {
        // 停顿开始 = 用户跟读 = 输出
        _addOutputWords(wordCount);
        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onPauseEnded: () {
        state = state.copyWith(isPauseBetweenPlays: false);
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAllPlaysCompleted: () async {
        // 最后一遍只有输入，没有跟读停顿
        // 保持 annotationMode，让句间停顿也触发自动录音（与跟读页一致）
        await _autoAdvance();
      },
    );
  }

  /// 停止计时并保存已记录的学习时长，刷新统计 UI
  ///
  /// 输入/输出时间已由 [StudyEventRecorder] 事件驱动写入，无需周期保存。
  /// 所有时长 clamp 到 [_maxSessionSeconds]，防止用户睡着等异常场景。
  /// 使用 [_isSaving] 标志位防止周期保存定时器与 dispose 竞态 double-save。
  Future<void> _saveAndRefreshStudyTime() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      if (!_studyStopwatch.isRunning &&
          _studyStopwatch.elapsed == Duration.zero) {
        return;
      }
      _studyStopwatch.stop();
      final seconds = _studyStopwatch.elapsed.inSeconds.clamp(
        0,
        _maxSessionSeconds,
      );
      _studyStopwatch.reset();
      if (seconds > 0) {
        await _studyTimeService.addStudyTime(
          seconds,
          stage: StudyStage.bookmarkReview,
        );
      }
      ref.read(dailyStudyTimeProvider.notifier).refresh();
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    } finally {
      _isSaving = false;
    }
  }

  /// 累加输出词数并刷新统计 UI
  Future<void> _addOutputWords(int count) async {
    if (count > 0) {
      await _studyTimeService.addOutputWords(count);
      ref.read(studyStatsNotifierProvider.notifier).refresh();
    }
  }

  /// 自动推进到下一句（含句间停顿）
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 使用设置计算句间停顿时长
    final sentence = currentSentence;
    final pauseDur = sentence != null
        ? state.settings.calculateInterSentencePause(sentence.duration)
        : const Duration(seconds: 1);

    await _engine.autoAdvance(
      pauseDuration: pauseDur,
      onPauseStarted: (dur) {
        state = state.copyWith(
          isPlaying: false,
          isPauseBetweenPlays: true,
          isPauseBetweenSentences: true,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAdvance: () async {
        if (isLastSentence) {
          // 复习完成，停止计时
          _studyStopwatch.stop();
          _stopPeriodicSaveTimer();
          state = state.copyWith(
            isPlaying: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
            stepFinished: true,
          );
        } else {
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            isTextRevealed: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
            isAnnotationMode: false,
            isManualForSentence: false,
          );
          await _startSentence();
        }
      },
    );
  }
}

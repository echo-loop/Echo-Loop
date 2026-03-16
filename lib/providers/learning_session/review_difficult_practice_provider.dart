/// 复习难句补练 Provider
///
/// 复习阶段的核心训练步骤：仅加载已标记为难句（bookmarked）的句子，
/// 每句盲听 1 遍 → 句间停顿 → 自动推进下一句。
/// 用户可随时「偷看」字幕或按「听不懂」进入跟读模式（显示字幕，播放 N 遍 + 跟读留白）。
///
/// 交互对齐逐句精听（IntensiveListenPlayer），使用布尔标志位替代枚举阶段。
/// R1+ 支持取消难句标记（听懂的句子可 unbookmark）。
///
/// 使用 SentencePlaybackEngine 的 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/difficult_practice_settings.dart';
import '../../models/sentence.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import 'learning_session_provider.dart';
import 'sentence_playback_engine.dart';

part 'review_difficult_practice_provider.g.dart';

/// 难句补练状态
///
/// 字段对齐 [IntensiveListenState]，使用布尔标志位描述播放阶段。
class ReviewDifficultPracticeState {
  /// 当前句子索引（在难句列表中的索引）
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based）
  final int currentPlayCount;

  /// 练习设置（盲听/跟读循环次数、句间停顿）
  final DifficultPracticeSettings settings;

  /// 跟读模式目标遍数（手动模式下强制为 1）
  int get targetRepeatCount =>
      settings.isManualMode ? 1 : settings.shadowReadingRepeatCount;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中（盲听句间停顿 / 跟读留白）
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 是否处于跟读模式（听不懂 → 显示字幕 + 播放 N 遍跟读循环）
  final bool isAnnotationMode;

  /// 是否偷看字幕（不暂停、不标记，切句时重置）
  final bool isTextRevealed;

  /// 是否已完成所有句子
  final bool isCompleted;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中（10 倍速）
  final bool isCountdownFastForward;

  const ReviewDifficultPracticeState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.settings = const DifficultPracticeSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isAnnotationMode = false,
    this.isTextRevealed = false,
    this.isCompleted = false,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
  });

  ReviewDifficultPracticeState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    DifficultPracticeSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isAnnotationMode,
    bool? isTextRevealed,
    bool? isCompleted,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
  }) {
    return ReviewDifficultPracticeState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      settings: settings ?? this.settings,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays ?? this.isPauseBetweenPlays,
      isPauseBetweenSentences:
          isPauseBetweenSentences ?? this.isPauseBetweenSentences,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      isCompleted: isCompleted ?? this.isCompleted,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
    );
  }
}

/// 难句补练 Provider
///
/// 组合 SentencePlaybackEngine 实现盲听→自动推进的逐句训练循环。
/// 用户可偷看字幕或进入标注模式（听不懂），交互与精听一致。
@Riverpod(keepAlive: true)
class ReviewDifficultPractice extends _$ReviewDifficultPractice {
  /// 难句列表（可变，取消标记时会移除）
  List<Sentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  @override
  ReviewDifficultPracticeState build() {
    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
    );
    ref.onDispose(() => _engine.cleanup());
    return const ReviewDifficultPracticeState();
  }

  /// 初始化难句补练
  ///
  /// [sentences] 难句列表（已过滤，仅 bookmarked 的句子）
  /// [startIndex] 断点续学句子索引（0-based），默认从头开始
  void initialize(List<Sentence> sentences, {int startIndex = 0}) {
    _engine.cleanup();
    _sentences = sentences.map((s) => s.copyWith()).toList();

    // 确保 startIndex 在有效范围内
    final validIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ReviewDifficultPracticeState(
      currentSentenceIndex: validIndex,
      totalSentences: _sentences.length,
    );
  }

  /// 更新练习设置（仅会话内生效）
  ///
  /// 更新后中断当前播放，以新设置重新开始当前句子。
  void updateSettings(DifficultPracticeSettings newSettings) {
    _engine.invalidateSession();
    state = state.copyWith(settings: newSettings, isPlaying: false);
  }

  /// 获取当前句子索引（用于断点保存）
  int get currentIndex => state.currentSentenceIndex;

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 异步保存难句补练断点，不阻塞当前句开始播放。
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            audioItemId,
            state.currentSentenceIndex,
          ),
    );
  }

  /// 开始播放（从当前句子开始盲听）
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    await _startSentence();
  }

  /// 暂停播放
  ///
  /// 跟读模式下保留 isAnnotationMode 标记，resume 时恢复跟读循环。
  void pause() {
    _engine.invalidateSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放
  ///
  /// 跟读模式下从第 1 遍重新开始跟读循环（与跟读页行为一致）。
  /// 盲听模式下从当前句重新开始。
  Future<void> resume() async {
    if (state.isAnnotationMode) {
      _startShadowReading();
      return;
    }
    await _startSentence();
  }

  /// 进入跟读模式（听不懂）
  ///
  /// 中断当前播放 → 启动跟读循环（显示字幕，播放 N 遍 + 跟读留白）。
  /// fire-and-forget 模式，与 listen_and_repeat 一致。
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;

    _engine.invalidateSession();
    _startShadowReading();
  }

  /// 跳过跟读（跟读模式下点"跳过"）
  ///
  /// 中断跟读循环 → 重置跟读模式 → 自动推进到下一句。
  Future<void> skipShadowReading() async {
    _engine.invalidateSession();
    state = state.copyWith(
      isAnnotationMode: false,
      isPlaying: false,
      isPauseBetweenPlays: false,
    );
    await _autoAdvance();
  }

  /// 设置偷看字幕状态（按住显示，松开隐藏）
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
  }

  /// 取消当前句子的难句标记
  ///
  /// 从播放列表移除当前句子，返回被移除的句子（供外部删除书签）。
  /// 若列表为空→标记完成；否则自动调整索引并重置状态。
  Sentence? removeDifficultMark() {
    if (_sentences.isEmpty) return null;

    _engine.invalidateSession();

    final removedIndex = state.currentSentenceIndex;
    final removed = _sentences[removedIndex];
    _sentences.removeAt(removedIndex);

    if (_sentences.isEmpty) {
      state = state.copyWith(
        isCompleted: true,
        isPlaying: false,
        totalSentences: 0,
      );
      return removed;
    }

    // 调整索引：移除的是最后一句则回退一格
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

  /// 跳到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await _startSentence();
  }

  /// 跳到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;
    _engine.invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
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

  /// 切换倒计时快进（10 倍速/正常速）
  ///
  /// 如果当前暂停中，快进会同时恢复倒计时。
  void toggleCountdownFastForward() {
    final isFF = !state.isCountdownFastForward;
    _engine.setCountdownSpeed(isFF ? 10.0 : 1.0);
    if (state.isCountdownPaused) {
      _engine.resumeCountdown();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 倒计时期间重播当前句子
  ///
  /// 跟读模式下重启跟读循环，盲听模式下重播盲听。
  Future<void> replayDuringCountdown() async {
    _engine.invalidateSession();
    if (state.isAnnotationMode) {
      _startShadowReading();
    } else {
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );
      await _startSentence();
    }
  }

  /// 强制完成（用户在最后一句主动点击完成按钮）
  void forceComplete() {
    _engine.invalidateSession();
    state = state.copyWith(
      isCompleted: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  /// 释放资源
  void disposePlayer() {
    _engine.cleanup();
    _sentences = [];
    state = const ReviewDifficultPracticeState();
  }

  /// 重置到第一句并重新开始播放（自由练习"再来一遍"）
  Future<void> resetToStart() async {
    _engine.cleanup();
    state = ReviewDifficultPracticeState(
      currentSentenceIndex: 0,
      totalSentences: _sentences.length,
    );
    await startPlaying();
  }

  // ========== 内部方法 ==========

  /// 立即完成当前停顿回合，继续后续播放流程。
  ///
  /// 由 TurnController 的 handleContinue 通过回调调用。
  Future<void> completePausedTurn() async {
    if (!state.isPauseBetweenPlays || !state.isAnnotationMode) return;

    // 句间停顿 → 走 autoAdvance 逻辑
    if (state.isPauseBetweenSentences) {
      final isLastSentence =
          state.currentSentenceIndex >= state.totalSentences - 1;
      _engine.invalidateSession();
      state = state.copyWith(
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        pauseRemaining: Duration.zero,
        isAnnotationMode: false,
      );
      if (isLastSentence) {
        state = state.copyWith(isCompleted: true, isPlaying: false);
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

  /// 开始跟读循环（显示字幕，播放 N 遍 + 跟读留白）
  ///
  /// fire-and-forget，与 listen_and_repeat 的 _startSentence 模式一致。
  /// [startPlayCount] 从第几遍开始（默认第 1 遍）。
  void _startShadowReading({int startPlayCount = 1}) {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    final wordCount = countWords(sentence.text);
    final session = ref.read(learningSessionProvider.notifier);

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: true,
      currentPlayCount: startPlayCount,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
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
        // 播放完成 = 输入，停顿开始 = 用户跟读 = 输出
        session.addInputWords(wordCount);
        session.recordLearnedSentence(sentence.text);
        session.addOutputWords(wordCount);
        session.startOutputTimer();
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
        session.stopOutputTimer();
        state = state.copyWith(isPauseBetweenPlays: false);
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAllPlaysCompleted: () async {
        // 最后一遍只有输入，没有跟读停顿
        // 保持 annotationMode，让句间停顿也触发自动录音（与跟读页一致）
        session.addInputWords(wordCount);
        session.recordLearnedSentence(sentence.text);
        await _autoAdvance();
      },
    );
  }

  /// 开始播放当前句子（盲听 N 遍）
  Future<void> _startSentence() async {
    final sentence = currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    // 手动模式下盲听只播 1 遍
    final repeatCount = state.settings.isManualMode
        ? 1
        : state.settings.blindListenRepeatCount;

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
    _persistCurrentSentenceIndexAsync();

    final wordCount = countWords(sentence.text);
    final session = ref.read(learningSessionProvider.notifier);

    // 盲听循环：1 遍时无遍间停顿，多遍时使用跟读停顿策略
    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: repeatCount,
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
              // 每遍播完计入输入词数
              session.addInputWords(wordCount);
              session.recordLearnedSentence(sentence.text);
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
        // 最后一遍（或唯一一遍）播完计入输入词数
        session.addInputWords(wordCount);
        session.recordLearnedSentence(sentence.text);
        // 盲听完成 → 句间停顿 → 自动推进
        await _autoAdvance();
      },
    );
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
          // 最后一句停顿结束 → 标记完成
          state = state.copyWith(
            isCompleted: true,
            isPlaying: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
          );
        } else {
          // 推进到下一句
          state = state.copyWith(
            currentSentenceIndex: state.currentSentenceIndex + 1,
            currentPlayCount: 1,
            isTextRevealed: false,
            isPauseBetweenPlays: false,
            isPauseBetweenSentences: false,
            isAnnotationMode: false,
          );
          await _startSentence();
        }
      },
    );
  }
}

/// 精听专用播放器 Provider
///
/// 逐句精听播放器，与 BlindListenPlayer 同层级，直接操作 AudioEngine。
/// 核心功能：
/// - 逐句播放（可配置遍数，遍间停顿）
/// - 看不懂详情模式（听不懂 → 暂停 → 揭示文本 → 标记难句）
/// - 详情模式退出时在当前页带字幕重播一遍再推进
/// - 偷看字幕（不暂停、不标记、切句时重置）
/// - 手动上一句/下一句
/// - 三种停顿模式（智能/固定/倍数）
/// - 倒计时控制（暂停/快进/重播）
///
/// 使用 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../../utils/word_counter.dart';
import '../learning_progress_provider.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';

part 'intensive_listen_player_provider.g.dart';

/// 计算停顿时长（纯函数）
///
/// 根据句子时长和精听设置计算停顿时间。
/// - smart：max(句子时长 × 1, 1000ms)
/// - fixed：固定秒数
/// - multiplier：句子时长 × 倍数
Duration calculatePauseDuration(
  Duration sentenceDuration,
  IntensiveListenSettings settings,
) {
  switch (settings.pauseMode) {
    case PauseMode.smart:
      final ms = sentenceDuration.inMilliseconds;
      return Duration(milliseconds: math.max(ms, 1000));
    case PauseMode.fixed:
      return Duration(seconds: settings.fixedPauseSeconds);
    case PauseMode.multiplier:
      final ms = (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
          .round();
      return Duration(milliseconds: ms);
  }
}

/// 精听播放器状态
class IntensiveListenState {
  /// 当前句子索引（0-based）
  final int currentSentenceIndex;

  /// 句子总数
  final int totalSentences;

  /// 当前遍数（1-based，"第N遍"）
  final int currentPlayCount;

  /// 精听设置（循环次数、停顿模式等）
  final IntensiveListenSettings settings;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中（用于 UI 区分文案）
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 当前句详情重播剩余时间
  final Duration annotationReplayRemaining;

  /// 当前句详情重播总时长
  final Duration annotationReplayDuration;

  /// 是否处于“听不懂”后的详情模式
  final bool isAnnotationMode;

  /// 是否处于当前页内的详情重播状态（带字幕重播一遍）
  final bool isAnnotationReplay;

  /// 是否偷看字幕
  final bool isTextRevealed;

  /// 本次标记的难句索引集合
  final Set<int> difficultSentences;

  /// 当前句是否由“看不懂”动作自动标记为难句
  ///
  /// 仅用于标注模式下的文案分支：
  /// - true：显示“已自动标记为难句”
  /// - false：显示“已标记为难句”
  final bool isCurrentSentenceAutoMarked;

  /// 倒计时是否暂停中
  final bool isCountdownPaused;

  /// 倒计时是否快进中（10 倍速）
  final bool isCountdownFastForward;

  const IntensiveListenState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.settings = const IntensiveListenSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.annotationReplayRemaining = Duration.zero,
    this.annotationReplayDuration = Duration.zero,
    this.isAnnotationMode = false,
    this.isAnnotationReplay = false,
    this.isTextRevealed = false,
    this.difficultSentences = const {},
    this.isCurrentSentenceAutoMarked = false,
    this.isCountdownPaused = false,
    this.isCountdownFastForward = false,
  });

  IntensiveListenState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    IntensiveListenSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    Duration? annotationReplayRemaining,
    Duration? annotationReplayDuration,
    bool? isAnnotationMode,
    bool? isAnnotationReplay,
    bool? isTextRevealed,
    Set<int>? difficultSentences,
    bool? isCurrentSentenceAutoMarked,
    bool? isCountdownPaused,
    bool? isCountdownFastForward,
  }) {
    return IntensiveListenState(
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
      annotationReplayRemaining:
          annotationReplayRemaining ?? this.annotationReplayRemaining,
      annotationReplayDuration:
          annotationReplayDuration ?? this.annotationReplayDuration,
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay ?? this.isAnnotationReplay,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      difficultSentences: difficultSentences ?? this.difficultSentences,
      isCurrentSentenceAutoMarked:
          isCurrentSentenceAutoMarked ?? this.isCurrentSentenceAutoMarked,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      isCountdownFastForward:
          isCountdownFastForward ?? this.isCountdownFastForward,
    );
  }
}

/// 精听专用播放器 Provider
///
/// 直接操作 AudioEngine 的 playClipOnce 基元，实现逐句播放循环。
/// 使用 engine 的 sessionId 防止异步竞态。
@Riverpod(keepAlive: true)
class IntensiveListenPlayer extends _$IntensiveListenPlayer {
  /// 深拷贝的句子列表（避免与 LP 共享可变状态）
  List<Sentence> _sentences = [];

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前播放循环的 sessionId
  int _currentSessionId = -1;

  @override
  IntensiveListenState build() {
    ref.onDispose(_cleanup);
    return const IntensiveListenState();
  }

  /// 初始化精听播放器
  ///
  /// [sentences] 句子列表（会深拷贝）
  /// [startIndex] 起始句子索引（断点续学）
  /// 设置使用默认值，不从持久化存储加载（设置仅会话内临时生效）
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
  }) async {
    _cleanup();

    // 深拷贝句子列表，避免与 LP 共享可变 isBookmarked 状态
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final safeIndex = startIndex.clamp(0, sentences.length - 1);

    // 从句子的 isBookmarked 字段预填历史难句
    final preBookmarked = <int>{
      for (final (i, s) in _sentences.indexed)
        if (s.isBookmarked) i,
    };

    state = IntensiveListenState(
      currentSentenceIndex: safeIndex,
      totalSentences: sentences.length,
      difficultSentences: preBookmarked,
    );
  }

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
      ? _sentences[state.currentSentenceIndex]
      : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 开始播放当前句子
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _startSentence();
  }

  /// 暂停播放
  Future<void> pause() async {
    final engine = ref.read(audioEngineProvider.notifier);
    engine.pause();
    _countdown.cancel();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 恢复播放（从当前句子重新开始播放循环）
  Future<void> resume() async {
    if (state.isAnnotationReplay) {
      await _startInlineAnnotationReplay();
      return;
    }
    await _startSentence();
  }

  /// 跳转到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;

    _invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    await _startSentence();
  }

  /// 跳转到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;

    _invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    await _startSentence();
  }

  /// 进入详情模式（听不懂）
  ///
  /// 暂停音频 → 揭示文本 → 标记为难句
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;

    _invalidateSession();

    final engine = ref.read(audioEngineProvider.notifier);
    engine.pause();

    // 标记当前句子为难句
    final newDifficult = Set<int>.from(state.difficultSentences);
    final wasAlreadyDifficult = newDifficult.contains(
      state.currentSentenceIndex,
    );
    newDifficult.add(state.currentSentenceIndex);

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isTextRevealed: false,
      pauseRemaining: Duration.zero,
      pauseDuration: Duration.zero,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      difficultSentences: newDifficult,
      isCurrentSentenceAutoMarked: !wasAlreadyDifficult,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 退出详情模式（点击“继续”）
  ///
  /// 保持当前页可见，带字幕重播当前句一遍，播完后按正常流程倒计时推进。
  Future<void> exitAnnotationMode() async {
    await _startInlineAnnotationReplay();
  }

  /// 在当前页内启动详情重播
  Future<void> _startInlineAnnotationReplay() async {
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) {
      await _finishAnnotationReplay();
      return;
    }

    state = state.copyWith(
      isAnnotationMode: true,
      isAnnotationReplay: true,
      isPlaying: true,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isCurrentSentenceAutoMarked: false,
      annotationReplayRemaining: sentence.duration,
      annotationReplayDuration: sentence.duration,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    await engine.playClipOnce(sentence, sessionId);

    if (!engine.isActiveSession(sessionId)) return;

    await _finishAnnotationReplay();
  }

  /// 标注模式下重播当前句子一遍
  ///
  /// 仅在标注模式下可用，播放当前句子一遍后停止，
  /// 不推进、不退出标注模式。
  Future<void> replayInAnnotationMode() async {
    if (!state.isAnnotationMode) return;
    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) return;

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;
    state = state.copyWith(isPlaying: true);

    await engine.playClipOnce(sentence, sessionId);

    if (!engine.isActiveSession(sessionId)) return;
    state = state.copyWith(isPlaying: false);
  }

  /// 切换当前句子的难句标记
  ///
  /// 仅在标注模式下可用，允许用户取消或重新标记难句。
  void toggleDifficultSentence() {
    final idx = state.currentSentenceIndex;
    final newSet = Set<int>.from(state.difficultSentences);
    if (newSet.contains(idx)) {
      newSet.remove(idx);
    } else {
      newSet.add(idx);
    }
    state = state.copyWith(
      difficultSentences: newSet,
      isCurrentSentenceAutoMarked: false,
    );
  }

  /// 设置偷看字幕状态（按住显示，松开隐藏）
  void setTextRevealed(bool revealed) {
    state = state.copyWith(isTextRevealed: revealed);
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
    _countdown.setSpeed(isFF ? 10.0 : 1.0);
    if (state.isCountdownPaused) {
      _countdown.resume();
    }
    state = state.copyWith(
      isCountdownFastForward: isFF,
      isCountdownPaused: false,
    );
  }

  /// 倒计时期间重播当前句子
  ///
  /// 取消倒计时，重新播放当前句子的循环。
  Future<void> replayDuringCountdown() async {
    _invalidateSession();
    state = state.copyWith(
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    /// 详情页里的倒计时重播，需要回到“带字幕重播中”而不是普通模式。
    if (state.isAnnotationMode) {
      await _startInlineAnnotationReplay();
      return;
    }

    await _startSentence();
  }

  /// 更新精听设置（仅会话内生效，不持久化）
  ///
  /// 当 repeatCount 调小时，clamp currentPlayCount 避免越界显示（如"第3/1遍"），
  /// 并中断当前播放循环、以新设置重新开始当前句子。
  void updateSettings(IntensiveListenSettings newSettings) {
    var clampedPlayCount = state.currentPlayCount;
    if (clampedPlayCount > newSettings.repeatCount) {
      clampedPlayCount = newSettings.repeatCount;
    }

    final needRestart = newSettings.repeatCount != state.settings.repeatCount ||
        newSettings.controlMode != state.settings.controlMode;

    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: clampedPlayCount,
    );

    // repeatCount 变化时中断当前循环，以新设置重新开始
    if (needRestart && state.isPlaying) {
      _invalidateSession();
      _startSentence();
    }
  }

  /// 释放资源
  void disposePlayer() {
    _cleanup();
    _sentences = [];
    state = const IntensiveListenState();
  }

  /// 获取当前句子索引（供外部保存断点用）
  int get currentIndex => state.currentSentenceIndex;

  // ========== 内部方法 ==========

  /// 开始播放当前句子的循环
  Future<void> _startSentence() async {
    final sentence = currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      await _autoAdvance();
      return;
    }

    state = state.copyWith(
      isPlaying: true,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    _persistCurrentSentenceIndexAsync();

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    await _playSentenceLoop(sentence, sessionId);
  }

  /// 句子播放循环：播放 repeatCount 遍，遍间停顿
  ///
  /// 手动模式下仅播放一遍后停止，等待用户操作。
  Future<void> _playSentenceLoop(Sentence sentence, int sessionId) async {
    final engine = ref.read(audioEngineProvider.notifier);
    final isManual = state.settings.isManualMode;
    final repeatCount = isManual ? 1 : state.settings.repeatCount;

    for (int playCount = 1; playCount <= repeatCount; playCount++) {
      if (!engine.isActiveSession(sessionId)) return;

      state = state.copyWith(currentPlayCount: playCount, isPlaying: true);

      await engine.playClipOnce(sentence, sessionId);

      if (!engine.isActiveSession(sessionId)) return;

      // 每遍播完计入输入词数
      final wordCount = countWords(sentence.text);
      final session = ref.read(learningSessionProvider.notifier);
      session.addInputWords(wordCount);
      session.recordLearnedSentence(sentence.text);

      // 手动模式：播完一遍即停止，等待用户操作
      if (isManual) {
        state = state.copyWith(isPlaying: false);
        return;
      }

      // 遍间停顿（最后一遍不停顿）
      if (playCount < repeatCount) {
        final pauseDur = calculatePauseDuration(
          sentence.duration,
          state.settings,
        );

        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
          pauseDuration: pauseDur,
          pauseRemaining: pauseDur,
        );

        await _countdown.start(pauseDur, (remaining) {
          state = state.copyWith(pauseRemaining: remaining);
        });

        if (!engine.isActiveSession(sessionId)) return;

        state = state.copyWith(
          isPauseBetweenPlays: false,
          isCountdownPaused: false,
          isCountdownFastForward: false,
        );
      }
    }

    // 所有遍数播完 → 自动推进
    if (engine.isActiveSession(sessionId)) {
      await _autoAdvance();
    }
  }

  /// 自动推进到下一句（最后一句也走停顿流程）
  ///
  /// 推进前先停顿，停顿时长由设置决定。
  Future<void> _autoAdvance() async {
    final isLastSentence =
        state.currentSentenceIndex >= state.totalSentences - 1;

    // 所有句子（包括最后一句）都走停顿
    final sentence = currentSentence;
    final pauseDur = sentence != null
        ? calculatePauseDuration(sentence.duration, state.settings)
        : const Duration(seconds: 1);

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: true,
      isPauseBetweenSentences: true,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCountdownPaused: false,
      isCountdownFastForward: false,
      pauseDuration: pauseDur,
      pauseRemaining: pauseDur,
    );

    await _countdown.start(pauseDur, (remaining) {
      state = state.copyWith(pauseRemaining: remaining);
    });

    // 停顿期间用户可能暂停/切句，检查 session 是否仍有效
    if (!engine.isActiveSession(sessionId)) return;

    if (isLastSentence) {
      // 最后一句停顿结束 → 发出完成信号（screen listener 检测增量触发弹窗）
      state = state.copyWith(
        isPlaying: false,
        isAnnotationMode: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
        isCurrentSentenceAutoMarked: false,
      );
    } else {
      // 非最后一句 → 推进到下一句
      state = state.copyWith(
        currentSentenceIndex: state.currentSentenceIndex + 1,
        currentPlayCount: 1,
        isTextRevealed: false,
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
        isAnnotationMode: false,
        isAnnotationReplay: false,
        annotationReplayRemaining: Duration.zero,
        annotationReplayDuration: Duration.zero,
        isCurrentSentenceAutoMarked: false,
        isCountdownPaused: false,
        isCountdownFastForward: false,
      );

      await _startSentence();
    }
  }

  /// 停止播放（用户在最后一句主动点击完成按钮时调用）
  ///
  /// 仅停止播放，弹窗由 screen 层直接调用。
  void stopPlayback() {
    _invalidateSession();
    try {
      ref.read(learningSessionProvider.notifier).stopOutputTimer();
    } catch (_) {}
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
  }

  /// 重置到第一句并重新开始播放（供"再来一遍"使用）
  Future<void> resetToStart() async {
    _invalidateSession();
    state = state.copyWith(
      currentSentenceIndex: 0,
      currentPlayCount: 1,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCurrentSentenceAutoMarked: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await startPlaying();
  }

  /// 当前页内的详情重播完成后推进
  ///
  /// 手动模式下重播完成后停止等待，不自动推进。
  Future<void> _finishAnnotationReplay() async {
    state = state.copyWith(
      isAnnotationReplay: false,
      isPlaying: false,
      annotationReplayRemaining: Duration.zero,
      annotationReplayDuration: Duration.zero,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );

    // 手动模式：重播完成后退出标注模式，停止等待用户操作
    if (state.settings.isManualMode) {
      state = state.copyWith(isAnnotationMode: false);
      return;
    }

    await _autoAdvance();
  }

  /// 每次开始播放一句时异步保存断点，避免依赖页面退出时机。
  void _persistCurrentSentenceIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    if (audioItemId == null) return;

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            audioItemId,
            state.currentSentenceIndex,
          ),
    );
  }

  /// 使当前 session 失效
  void _invalidateSession() {
    final engine = ref.read(audioEngineProvider.notifier);
    engine.pause();
    _currentSessionId = -1;
    _countdown.cancel();
  }

  /// 清理资源
  void _cleanup() {
    _countdown.cancel();
    _currentSessionId = -1;
  }
}

/// 精听专用播放器 Provider
///
/// 逐句精听播放器，与 BlindListenPlayer 同层级，直接操作 AudioEngine。
/// 核心功能：
/// - 逐句播放（可配置遍数，遍间停顿）
/// - 标注模式（听不懂 → 暂停 → 揭示文本 → 标记难句）
/// - 标注模式退出时带字幕重播一遍再推进
/// - 偷看字幕（不暂停、不标记、切句时重置）
/// - 手动上一句/下一句
/// - 三种停顿模式（智能/固定/倍数）
///
/// 使用 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../audio_engine/audio_engine_provider.dart';

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

  /// 是否处于标注模式（听不懂）
  final bool isAnnotationMode;

  /// 是否处于标注模式重播（带字幕重播一遍）
  final bool isAnnotationReplay;

  /// 是否已完成所有句子
  final bool isCompleted;

  /// 是否偷看字幕
  final bool isTextRevealed;

  /// 本次标记的难句索引集合
  final Set<int> difficultSentences;

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
    this.isAnnotationMode = false,
    this.isAnnotationReplay = false,
    this.isCompleted = false,
    this.isTextRevealed = false,
    this.difficultSentences = const {},
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
    bool? isAnnotationMode,
    bool? isAnnotationReplay,
    bool? isCompleted,
    bool? isTextRevealed,
    Set<int>? difficultSentences,
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
      isAnnotationMode: isAnnotationMode ?? this.isAnnotationMode,
      isAnnotationReplay: isAnnotationReplay ?? this.isAnnotationReplay,
      isCompleted: isCompleted ?? this.isCompleted,
      isTextRevealed: isTextRevealed ?? this.isTextRevealed,
      difficultSentences: difficultSentences ?? this.difficultSentences,
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

  /// 倒计时 Timer（遍间停顿 UI 更新用）
  Timer? _countdownTimer;

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

    state = IntensiveListenState(
      currentSentenceIndex: safeIndex,
      totalSentences: sentences.length,
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
    _cancelCountdown();
    state = state.copyWith(isPlaying: false, isPauseBetweenPlays: false);
  }

  /// 恢复播放（从当前句子重新开始播放循环）
  Future<void> resume() async {
    await _startSentence();
  }

  /// 跳转到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;

    _invalidateSession();
    _cancelCountdown();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
    );

    await _startSentence();
  }

  /// 跳转到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;

    _invalidateSession();
    _cancelCountdown();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isAnnotationMode: false,
      isAnnotationReplay: false,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
    );

    await _startSentence();
  }

  /// 进入标注模式（听不懂）
  ///
  /// 暂停音频 → 揭示文本 → 标记为难句
  void enterAnnotationMode() {
    if (state.isAnnotationMode) return;

    _invalidateSession();
    _cancelCountdown();

    final engine = ref.read(audioEngineProvider.notifier);
    engine.pause();

    // 标记当前句子为难句
    final newDifficult = Set<int>.from(state.difficultSentences);
    newDifficult.add(state.currentSentenceIndex);

    state = state.copyWith(
      isAnnotationMode: true,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isTextRevealed: false,
      difficultSentences: newDifficult,
    );
  }

  /// 退出标注模式（点击"继续"）
  ///
  /// 带字幕重播当前句一遍 → 播完自动推进到下一句
  Future<void> exitAnnotationMode() async {
    state = state.copyWith(
      isAnnotationMode: false,
      isAnnotationReplay: true,
      isPlaying: true,
    );

    final sentence = currentSentence;
    if (sentence == null || sentence.duration <= Duration.zero) {
      await _finishAnnotationReplay();
      return;
    }

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
    state = state.copyWith(difficultSentences: newSet);
  }

  /// 切换偷看字幕
  void toggleTextReveal() {
    state = state.copyWith(isTextRevealed: !state.isTextRevealed);
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

    final needRestart = newSettings.repeatCount != state.settings.repeatCount;

    state = state.copyWith(
      settings: newSettings,
      currentPlayCount: clampedPlayCount,
    );

    // repeatCount 变化时中断当前循环，以新设置重新开始
    if (needRestart && state.isPlaying) {
      _invalidateSession();
      _cancelCountdown();
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
    );

    final engine = ref.read(audioEngineProvider.notifier);
    _currentSessionId = engine.newSession();
    final sessionId = _currentSessionId;

    await _playSentenceLoop(sentence, sessionId);
  }

  /// 句子播放循环：播放 repeatCount 遍，遍间停顿
  Future<void> _playSentenceLoop(Sentence sentence, int sessionId) async {
    final engine = ref.read(audioEngineProvider.notifier);
    final repeatCount = state.settings.repeatCount;

    for (int playCount = 1; playCount <= repeatCount; playCount++) {
      if (!engine.isActiveSession(sessionId)) return;

      state = state.copyWith(currentPlayCount: playCount, isPlaying: true);

      await engine.playClipOnce(sentence, sessionId);

      if (!engine.isActiveSession(sessionId)) return;

      // 遍间停顿（最后一遍不停顿）
      if (playCount < repeatCount) {
        final pauseDur = calculatePauseDuration(
          sentence.duration,
          state.settings,
        );

        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          pauseDuration: pauseDur,
          pauseRemaining: pauseDur,
        );

        // 启动倒计时 Timer 更新 UI
        _startCountdown(pauseDur);

        await Future.delayed(pauseDur);

        _cancelCountdown();

        if (!engine.isActiveSession(sessionId)) return;

        state = state.copyWith(isPauseBetweenPlays: false);
      }
    }

    // 所有遍数播完 → 自动推进
    if (engine.isActiveSession(sessionId)) {
      await _autoAdvance();
    }
  }

  /// 自动推进到下一句
  ///
  /// 推进前先停顿，停顿时长由设置决定，
  /// 复用遍间停顿机制（倒计时 UI + Future.delayed）。
  Future<void> _autoAdvance() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) {
      // 最后一句 → 标记完成
      state = state.copyWith(isCompleted: true, isPlaying: false);
      return;
    }

    // 句间停顿
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
      pauseDuration: pauseDur,
      pauseRemaining: pauseDur,
    );

    _startCountdown(pauseDur);
    await Future.delayed(pauseDur);
    _cancelCountdown();

    // 停顿期间用户可能暂停/切句，检查 session 是否仍有效
    if (!engine.isActiveSession(sessionId)) return;

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isTextRevealed: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
      isAnnotationMode: false,
      isAnnotationReplay: false,
    );

    _startSentence();
  }

  /// 标注重播完成后推进（停顿由 _autoAdvance 统一处理）
  Future<void> _finishAnnotationReplay() async {
    state = state.copyWith(isAnnotationReplay: false, isPlaying: false);
    await _autoAdvance();
  }

  /// 使当前 session 失效
  void _invalidateSession() {
    final engine = ref.read(audioEngineProvider.notifier);
    engine.pause();
    _currentSessionId = -1;
  }

  /// 启动倒计时 Timer（每 100ms 更新 UI）
  void _startCountdown(Duration total) {
    _cancelCountdown();
    final startTime = DateTime.now();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      final elapsed = DateTime.now().difference(startTime);
      final remaining = total - elapsed;
      if (remaining <= Duration.zero) {
        timer.cancel();
        return;
      }
      state = state.copyWith(pauseRemaining: remaining);
    });
  }

  /// 取消倒计时
  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// 清理资源
  void _cleanup() {
    _cancelCountdown();
    _currentSessionId = -1;
  }
}

/// 跟读专用播放器 Provider
///
/// 难句跟读播放器，与 IntensiveListenPlayer 同层级，直接操作 AudioEngine。
/// 核心功能：
/// - 逐句播放（遍数根据难度调整：veryEasy/easy=2, medium=3, hard=4, veryHard=5）
/// - 遍间停顿时间：max(句长×2, 2000ms)，给用户跟读时间
/// - 取消难句收藏（从播放列表移除该句）
/// - 手动上一句/下一句
///
/// 使用 SentencePlaybackEngine 的 sessionId 守护防止异步竞态。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'sentence_playback_engine.dart';

part 'listen_and_repeat_player_provider.g.dart';

/// 跟读播放器状态
class ListenAndRepeatPlayerState {
  /// 当前句子索引（0-based，在过滤后的难句列表中的索引）
  final int currentSentenceIndex;

  /// 难句总数
  final int totalSentences;

  /// 当前遍数（1-based，"第N遍"）
  final int currentPlayCount;

  /// 目标播放遍数（根据难度动态计算，已弃用，由 settings.repeatCount 代替）
  final int targetPlayCount;

  /// 跟读设置（循环次数 + 停顿模式）
  final IntensiveListenSettings settings;

  /// 是否正在播放
  final bool isPlaying;

  /// 是否处于遍间停顿中（跟读时间）
  final bool isPauseBetweenPlays;

  /// 是否处于句间停顿中
  final bool isPauseBetweenSentences;

  /// 停顿剩余时间
  final Duration pauseRemaining;

  /// 停顿总时长
  final Duration pauseDuration;

  /// 是否已完成所有句子
  final bool isCompleted;

  const ListenAndRepeatPlayerState({
    this.currentSentenceIndex = 0,
    this.totalSentences = 0,
    this.currentPlayCount = 1,
    this.targetPlayCount = 3,
    this.settings = const IntensiveListenSettings(),
    this.isPlaying = false,
    this.isPauseBetweenPlays = false,
    this.isPauseBetweenSentences = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCompleted = false,
  });

  ListenAndRepeatPlayerState copyWith({
    int? currentSentenceIndex,
    int? totalSentences,
    int? currentPlayCount,
    int? targetPlayCount,
    IntensiveListenSettings? settings,
    bool? isPlaying,
    bool? isPauseBetweenPlays,
    bool? isPauseBetweenSentences,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCompleted,
  }) {
    return ListenAndRepeatPlayerState(
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentences: totalSentences ?? this.totalSentences,
      currentPlayCount: currentPlayCount ?? this.currentPlayCount,
      targetPlayCount: targetPlayCount ?? this.targetPlayCount,
      settings: settings ?? this.settings,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseBetweenPlays: isPauseBetweenPlays ?? this.isPauseBetweenPlays,
      isPauseBetweenSentences:
          isPauseBetweenSentences ?? this.isPauseBetweenSentences,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 跟读专用播放器 Provider
///
/// 组合 SentencePlaybackEngine 实现逐句跟读播放循环。
/// 句子列表来自精听阶段标记的难句。
@Riverpod(keepAlive: true)
class ListenAndRepeatPlayer extends _$ListenAndRepeatPlayer {
  /// 难句列表（可变，取消收藏时会移除）
  List<Sentence> _sentences = [];

  /// 播放引擎
  late SentencePlaybackEngine _engine;

  @override
  ListenAndRepeatPlayerState build() {
    _engine = SentencePlaybackEngine(
      getEngine: () => ref.read(audioEngineProvider.notifier),
    );
    ref.onDispose(() => _engine.cleanup());
    return const ListenAndRepeatPlayerState();
  }

  /// 初始化跟读播放器
  ///
  /// [sentences] 难句列表（会深拷贝）
  /// [startIndex] 起始句子索引（断点续学）
  /// [targetPlayCount] 目标播放遍数（根据难度计算）
  Future<void> initialize(
    List<Sentence> sentences, {
    int startIndex = 0,
    int targetPlayCount = 3,
  }) async {
    _engine.cleanup();
    _sentences = sentences.map((s) => s.copyWith()).toList();

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);

    state = ListenAndRepeatPlayerState(
      currentSentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      targetPlayCount: targetPlayCount,
      settings: IntensiveListenSettings(repeatCount: targetPlayCount),
    );
  }

  /// 获取当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.currentSentenceIndex < _sentences.length
          ? _sentences[state.currentSentenceIndex]
          : null;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  /// 获取当前句子索引（供外部保存断点用）
  int get currentIndex => state.currentSentenceIndex;

  /// 开始播放当前句子
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) {
      state = state.copyWith(isCompleted: true);
      return;
    }
    await _startSentence();
  }

  /// 暂停播放
  Future<void> pause() async {
    _engine.invalidateSession();
    state = state.copyWith(
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );
  }

  /// 恢复播放（从当前句子重新开始播放循环）
  Future<void> resume() async {
    await _startSentence();
  }

  /// 跳转到下一句
  Future<void> goToNext() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    await _startSentence();
  }

  /// 跳转到上一句
  Future<void> goToPrevious() async {
    if (state.currentSentenceIndex <= 0) return;

    _engine.invalidateSession();

    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      currentPlayCount: 1,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    await _startSentence();
  }

  /// 取消当前句子的难句收藏
  ///
  /// 从播放列表移除当前句子，返回被移除的句子（供外部删除书签）。
  /// 若列表为空→标记完成；否则自动调整索引。
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
        isPauseBetweenPlays: false,
        isPauseBetweenSentences: false,
      );
      return removed;
    }

    // 调整索引：如果移除的是最后一句，回退一格
    final newIndex = removedIndex >= _sentences.length
        ? _sentences.length - 1
        : removedIndex;

    state = state.copyWith(
      currentSentenceIndex: newIndex,
      totalSentences: _sentences.length,
      currentPlayCount: 1,
      isPlaying: false,
      isPauseBetweenPlays: false,
      isPauseBetweenSentences: false,
    );

    return removed;
  }

  /// 更新跟读设置（即时生效，仅本次会话）
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
      _engine.invalidateSession();
      _startSentence();
    }
  }

  /// 释放资源
  void disposePlayer() {
    _engine.cleanup();
    _sentences = [];
    state = const ListenAndRepeatPlayerState();
  }

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
    );

    await _engine.playSentenceLoop(
      sentence: sentence,
      repeatCount: state.settings.repeatCount,
      pauseCalculator: _buildPauseCalculator(),
      onPlayCountChanged: (playCount) {
        state = state.copyWith(currentPlayCount: playCount, isPlaying: true);
      },
      onPauseStarted: (pauseDur) {
        state = state.copyWith(
          isPauseBetweenPlays: true,
          isPlaying: false,
          pauseDuration: pauseDur,
          pauseRemaining: pauseDur,
        );
      },
      onPauseEnded: () {
        state = state.copyWith(isPauseBetweenPlays: false);
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAllPlaysCompleted: () async {
        await _autoAdvance();
      },
    );
  }

  /// 自动推进到下一句
  Future<void> _autoAdvance() async {
    if (state.currentSentenceIndex >= state.totalSentences - 1) {
      // 最后一句 → 标记完成
      state = state.copyWith(isCompleted: true, isPlaying: false);
      return;
    }

    // 句间停顿
    final sentence = currentSentence;
    final calculator = _buildPauseCalculator();
    final pauseDur = sentence != null
        ? calculator(sentence.duration)
        : const Duration(seconds: 2);

    await _engine.autoAdvance(
      pauseDuration: pauseDur,
      onPauseStarted: (dur) {
        state = state.copyWith(
          isPlaying: false,
          isPauseBetweenPlays: true,
          isPauseBetweenSentences: true,
          pauseDuration: dur,
          pauseRemaining: dur,
        );
      },
      onTick: (remaining) {
        state = state.copyWith(pauseRemaining: remaining);
      },
      onAdvance: () async {
        state = state.copyWith(
          currentSentenceIndex: state.currentSentenceIndex + 1,
          currentPlayCount: 1,
          isPauseBetweenPlays: false,
          isPauseBetweenSentences: false,
        );
        _startSentence();
      },
    );
  }

  /// 根据当前设置构建停顿计算器
  ///
  /// 返回的 lambda 在每次调用时读取最新 `state.settings`，
  /// 确保用户在播放中途修改停顿设置后能即时生效。
  /// - smart: max(句长×2, 2000ms)（跟读专用，给用户足够跟读时间）
  /// - fixed / multiplier: 复用精听的 calculatePauseDuration 逻辑
  PauseCalculator _buildPauseCalculator() {
    return (Duration sentenceDuration) {
      final settings = state.settings;
      return switch (settings.pauseMode) {
        PauseMode.smart => listenAndRepeatPauseCalculator(sentenceDuration),
        PauseMode.fixed => Duration(seconds: settings.fixedPauseSeconds),
        PauseMode.multiplier => Duration(
          milliseconds: math.max(
            (sentenceDuration.inMilliseconds * settings.pauseMultiplier)
                .round(),
            1000,
          ),
        ),
      };
    };
  }
}

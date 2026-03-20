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
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/blind_listen_settings.dart';
import '../../models/sentence.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'countdown_controller.dart';
import 'learning_session_provider.dart';

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

  /// 文本显示模式
  final BlindListenDisplayMode displayMode;

  /// 盲听设置
  final BlindListenSettings settings;

  const BlindListenPlayerState({
    this.currentParagraphIndex = 0,
    this.totalParagraphs = 0,
    this.playingSentenceIndex = -1,
    this.currentRepeatCount = 1,
    this.isPlaying = false,
    this.isPauseCountdown = false,
    this.pauseRemaining = Duration.zero,
    this.pauseDuration = Duration.zero,
    this.isCountdownPaused = false,
    this.displayMode = BlindListenDisplayMode.hideAll,
    this.settings = const BlindListenSettings(),
  });

  BlindListenPlayerState copyWith({
    int? currentParagraphIndex,
    int? totalParagraphs,
    int? playingSentenceIndex,
    int? currentRepeatCount,
    bool? isPlaying,
    bool? isPauseCountdown,
    Duration? pauseRemaining,
    Duration? pauseDuration,
    bool? isCountdownPaused,
    BlindListenDisplayMode? displayMode,
    BlindListenSettings? settings,
  }) {
    return BlindListenPlayerState(
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      totalParagraphs: totalParagraphs ?? this.totalParagraphs,
      playingSentenceIndex: playingSentenceIndex ?? this.playingSentenceIndex,
      currentRepeatCount: currentRepeatCount ?? this.currentRepeatCount,
      isPlaying: isPlaying ?? this.isPlaying,
      isPauseCountdown: isPauseCountdown ?? this.isPauseCountdown,
      pauseRemaining: pauseRemaining ?? this.pauseRemaining,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      isCountdownPaused: isCountdownPaused ?? this.isCountdownPaused,
      displayMode: displayMode ?? this.displayMode,
      settings: settings ?? this.settings,
    );
  }
}

/// 盲听专用播放器 Provider
@Riverpod(keepAlive: true)
class BlindListenPlayer extends _$BlindListenPlayer {
  /// 段落列表
  List<List<Sentence>> _paragraphs = [];

  /// position 监听（句子高亮）
  StreamSubscription<Duration>? _positionSub;

  /// 可控倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 当前 AudioEngine sessionId
  int _sessionId = -1;

  /// 倒计时运行版本号
  int _countdownRunId = 0;

  @override
  BlindListenPlayerState build() {
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _positionSub?.cancel();
      _invalidateCountdown();
    });
    return const BlindListenPlayerState();
  }

  /// App 进入后台时暂停倒计时（音频继续播放）
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      if (state.isPauseCountdown) {
        pauseCountdown();
      }
    }
  }

  /// 初始化段落播放
  void initializeParagraphs(
    List<List<Sentence>> paragraphs,
    BlindListenSettings settings,
  ) {
    _cleanup();
    _paragraphs = paragraphs;

    state = BlindListenPlayerState(
      currentParagraphIndex: 0,
      totalParagraphs: paragraphs.length,
      settings: settings,
    );
  }

  /// 获取当前段落的句子列表
  List<Sentence> get currentParagraphSentences =>
      _paragraphs.isNotEmpty &&
              state.currentParagraphIndex < _paragraphs.length
          ? _paragraphs[state.currentParagraphIndex]
          : [];

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
  /// 使旧 session 失效 + 停止音频，resume 时从段落开头重播。
  Future<void> pause() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
    await engine.stopPlayback();
    state = state.copyWith(
      isPlaying: false,
      isPauseCountdown: false,
      isCountdownPaused: false,
    );
  }

  /// 恢复播放
  Future<void> resume() async {
    await _playCurrentParagraph();
  }

  /// 跳转到下一段
  Future<void> goToNextParagraph() async {
    // 最后一段 → 停止播放，由 screen 处理完成逻辑
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      await _cancelAll();
      state = state.copyWith(isPlaying: false, isPauseCountdown: false);
      return;
    }

    await _cancelAll();
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex + 1,
      currentRepeatCount: 1,
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
    state = state.copyWith(
      currentParagraphIndex: state.currentParagraphIndex - 1,
      currentRepeatCount: 1,
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

  /// 更新设置
  ///
  /// 切换到手动模式时，取消正在进行的倒计时。
  void updateSettings(BlindListenSettings newSettings) {
    final switchedToManual = newSettings.isManualMode &&
        !state.settings.isManualMode;

    state = state.copyWith(settings: newSettings);

    if (switchedToManual && state.isPauseCountdown) {
      cancelCountdown();
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
    state = state.copyWith(
      isPauseCountdown: false,
      isCountdownPaused: false,
    );
  }

  /// 释放资源
  void disposePlayer() {
    _cleanup();
    _paragraphs = [];
    state = const BlindListenPlayerState();
  }

  // ========== 内部方法 ==========

  /// 播放当前段落
  Future<void> _playCurrentParagraph() async {
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;

    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    final sid = _sessionId;

    state = state.copyWith(
      isPlaying: true,
      playingSentenceIndex: 0,
      isPauseCountdown: false,
    );

    _startPositionTracking(sentences);

    final start = sentences.first.startTime;
    final end = sentences.last.endTime;

    await engine.playRangeOnce(start, end, sid);

    if (!engine.isActiveSession(sid)) return;

    // 计入输入词数
    final paragraphWordCount = countWordsInSentences(sentences);
    try {
      final session = ref.read(learningSessionProvider.notifier);
      session.addInputWords(paragraphWordCount);
      session.recordLearnedSentences(sentences);
    } catch (_) {}

    _positionSub?.cancel();

    // 手动模式：播放完直接停止，等待用户操作
    if (state.settings.isManualMode) {
      state = state.copyWith(isPlaying: false, playingSentenceIndex: -1);
      return;
    }

    _startPauseCountdown();
  }

  /// 订阅 position stream，二分查找定位当前句子
  void _startPositionTracking(List<Sentence> sentences) {
    _positionSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);

    _positionSub = engine.absolutePositionStream.listen((position) {
      if (!engine.isActiveSession(_sessionId)) return;

      final idx = _findSentenceIndex(sentences, position);
      if (idx != state.playingSentenceIndex && idx >= 0) {
        state = state.copyWith(playingSentenceIndex: idx);
      }
    });
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
      playingSentenceIndex: -1,
    );

    _countdown
        .start(duration, (remaining) {
          state = state.copyWith(pauseRemaining: remaining);
        })
        .then((_) {
          if (state.isPauseCountdown && runId == _countdownRunId) {
            _onPauseCountdownFinished();
          }
        });
  }

  /// 段间停顿结束
  Future<void> _onPauseCountdownFinished() async {
    state = state.copyWith(isPauseCountdown: false);

    if (state.currentRepeatCount < state.settings.repeatCount) {
      // 当前段还有遍数 → 继续播放
      state = state.copyWith(
        currentRepeatCount: state.currentRepeatCount + 1,
      );
      await _playCurrentParagraph();
    } else if (state.currentParagraphIndex < state.totalParagraphs - 1) {
      // 还有下一段 → 推进
      await goToNextParagraph();
    } else {
      // 最后一段最后一遍 → 停止，等用户点完成按钮
      state = state.copyWith(isPlaying: false);
    }
  }

  /// 取消所有异步操作并停止音频
  Future<void> _cancelAll() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateCountdown();
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
    _positionSub = null;
  }
}

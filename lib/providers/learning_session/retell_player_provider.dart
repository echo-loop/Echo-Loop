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
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../services/app_logger.dart';
import '../../utils/keyword_extraction.dart';
import '../../utils/word_counter.dart';
import '../audio_engine/audio_engine_provider.dart';
import 'countdown_controller.dart';
import '../learning_progress_provider.dart';
import 'learning_session_provider.dart';

part 'retell_player_provider.g.dart';

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
    );
  }
}

/// 复述专用播放器 Provider
@Riverpod(keepAlive: true)
class RetellPlayer extends _$RetellPlayer {
  /// 段落列表
  List<List<Sentence>> _paragraphs = [];

  /// 所有句子列表（用于重新生成关键词）
  List<Sentence> _allSentences = [];

  /// 关键词映射：段落内句子索引 → 词索引集合
  Map<int, Set<int>> _keywordsMap = {};

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

  @override
  RetellPlayerState build() {
    final lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleChange,
    );
    ref.onDispose(() {
      lifecycleListener.dispose();
      _positionSub?.cancel();
      _invalidateRetellCountdown();
    });
    return const RetellPlayerState();
  }

  /// App 进入后台时取消倒计时和播放，回前台后等待用户操作。
  void _handleAppLifecycleChange(AppLifecycleState appState) {
    if (appState == AppLifecycleState.paused ||
        appState == AppLifecycleState.hidden) {
      AppLogger.log('RetellPlayer', 'App 进入后台: '
          'phase=${state.phase.name}, '
          'countdown=${state.isRetellCountdown}');

      // 停止段落音频播放
      final engine = ref.read(audioEngineProvider.notifier);
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
        );
      }
    }
  }

  /// 初始化复述播放器
  ///
  /// [paragraphs] DP 分段结果
  /// [keywordsMap] 关键词提取结果
  /// [startSentenceIndex] 断点续学句子索引（段落第一句的全局索引）
  void initialize(
    List<List<Sentence>> paragraphs,
    Map<int, Set<int>> keywordsMap, {
    int? startSentenceIndex,
  }) {
    _cleanup();
    _paragraphs = paragraphs;
    _allSentences = paragraphs.expand((p) => p).toList();
    _keywordsMap = keywordsMap;

    // 根据句子索引查找对应段落
    var safeIndex = 0;
    if (startSentenceIndex != null && paragraphs.isNotEmpty) {
      for (var i = 0; i < paragraphs.length; i++) {
        if (paragraphs[i].any((s) => s.index == startSentenceIndex)) {
          safeIndex = i;
          break;
        }
      }
    }

    state = RetellPlayerState(
      currentParagraphIndex: safeIndex,
      totalParagraphs: paragraphs.length,
    );
  }

  /// 获取当前段落第一句的全局句子索引（用于保存断点）
  int? get currentParagraphFirstSentenceIndex {
    final sentences = currentParagraphSentences;
    return sentences.isNotEmpty ? sentences.first.index : null;
  }

  /// 获取当前段落的句子列表
  List<Sentence> get currentParagraphSentences =>
      _paragraphs.isNotEmpty && state.currentParagraphIndex < _paragraphs.length
      ? _paragraphs[state.currentParagraphIndex]
      : [];

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
    final effectiveRepeatCount =
        state.settings.isManualMode ? 1 : state.settings.repeatCount;
    if (state.currentRepeatCount < effectiveRepeatCount) {
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

  /// 记录段落输出词数并停止输出计时。
  void _recordParagraphOutputStats() {
    final session = ref.read(learningSessionProvider.notifier);
    final paragraphWordCount = countWordsInSentences(currentParagraphSentences);
    session.addOutputWords(paragraphWordCount);
    session.stopOutputTimer();
  }

  /// 异步保存复述断点，记录当前段首句的全局索引。
  void _persistCurrentParagraphIndexAsync() {
    final session = ref.read(learningSessionProvider);
    final audioItemId = session.audioItemId;
    final sentenceIndex = currentParagraphFirstSentenceIndex;
    if (audioItemId == null || sentenceIndex == null) {
      return;
    }

    unawaited(
      ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(audioItemId, sentenceIndex),
    );
  }

  /// 重新开始：重置到第一段，重新播放
  Future<void> restart() async {
    await _cancelAll();
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
  /// resume 时从段落开头重新播放（不是从暂停位置继续），
  /// 因为复述练习需要连贯听完整段。
  Future<void> pause() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateRetellCountdown();
    try { ref.read(learningSessionProvider.notifier).stopOutputTimer(); } catch (_) {}
    await engine.stopPlayback();
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
      await _playCurrentParagraph();
    } else {
      // 复述阶段恢复倒计时
      _startRetellCountdown(state.pauseRemaining);
    }
  }

  /// 跳转到下一段
  Future<void> goToNextParagraph() async {
    // 最后一段 → 停止播放，由 screen 处理完成逻辑
    if (state.currentParagraphIndex >= state.totalParagraphs - 1) {
      await _cancelAll();
      state = state.copyWith(isPlaying: false, isRetellCountdown: false);
      return;
    }

    await _cancelAll();
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
    _countdown.setSpeed(isFF ? 10.0 : 1.0);
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
    state = state.copyWith(
      isRetellCountdown: false,
      isCountdownPaused: false,
      isCountdownFastForward: false,
    );
    await _playCurrentParagraph();
  }

  /// 设置显示模式
  void setDisplayMode(RetellDisplayMode mode) {
    state = state.copyWith(displayMode: mode, userOverrodeDisplayMode: true);
  }

  /// 更新设置
  ///
  /// 当 [keywordRatio] 变化时自动重新生成关键词。
  void updateSettings(RetellSettings newSettings) {
    final ratioChanged =
        newSettings.keywordRatio != state.settings.keywordRatio;
    state = state.copyWith(settings: newSettings);
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
    _cleanup();
    _paragraphs = [];
    _allSentences = [];
    _keywordsMap = {};
    state = const RetellPlayerState();
  }

  // ========== 内部方法 ==========

  /// 播放当前段落
  ///
  /// 使用局部变量 `sid` 捕获 sessionId，防止 pause/其他操作
  /// 覆写实例变量 `_sessionId` 后导致 guard 失效。
  Future<void> _playCurrentParagraph() async {
    try { ref.read(learningSessionProvider.notifier).stopOutputTimer(); } catch (_) {}
    final sentences = currentParagraphSentences;
    if (sentences.isEmpty) return;

    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    final sid = _sessionId; // 捕获局部变量

    state = state.copyWith(
      phase: RetellPhase.listening,
      isPlaying: true,
      playingSentenceIndex: 0,
      isRetellCountdown: false,
    );
    _persistCurrentParagraphIndexAsync();

    // 订阅 position stream 实现句子高亮
    _startPositionTracking(sentences);

    final start = sentences.first.startTime;
    final end = sentences.last.endTime;

    await engine.playRangeOnce(start, end, sid);

    // 播放完成后进入复述阶段（用局部变量检查）
    if (!engine.isActiveSession(sid)) return;

    // 计入输入词数（听完一遍段落）
    final paragraphWordCount = countWordsInSentences(sentences);
    final session = ref.read(learningSessionProvider.notifier);
    session.addInputWords(paragraphWordCount);
    session.recordLearnedSentences(sentences);

    _positionSub?.cancel();
    _enterRetellingPhase();
  }

  /// 订阅 position stream，二分查找定位当前句子
  void _startPositionTracking(List<Sentence> sentences) {
    _positionSub?.cancel();
    final engine = ref.read(audioEngineProvider.notifier);

    _positionSub = engine.absolutePositionStream.listen((position) {
      if (!engine.isActiveSession(_sessionId)) return;
      if (state.phase != RetellPhase.listening) return;

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

    // 如果没有精确匹配，返回最近的
    return lo.clamp(0, sentences.length - 1);
  }

  /// 进入复述阶段
  ///
  /// 不自动启动倒计时。倒计时由 screen 层在录音评估完成后触发
  /// [startPostEvaluationPause]。
  void _enterRetellingPhase() {
    // 复述开始 = 输出时间开始
    try {
      ref.read(learningSessionProvider.notifier).startOutputTimer();
    } catch (_) {}

    state = state.copyWith(
      phase: RetellPhase.retelling,
      isPlaying: false,
      playingSentenceIndex: -1,
      displayMode: state.userOverrodeDisplayMode
          ? null
          : RetellDisplayMode.keywordsOnly,
    );
  }

  /// 启动评估后段间停顿倒计时（由 screen 层在评估完成后调用）
  ///
  /// 手动模式下直接 return，不启动倒计时，由用户手动推进。
  void startPostEvaluationPause() {
    if (state.phase != RetellPhase.retelling) return;
    if (state.isRetellCountdown) return;
    if (state.settings.isManualMode) return;

    final pauseDuration = state.settings.calculatePauseDuration(
      currentParagraphDuration,
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
    );

    _countdown
        .start(duration, (remaining) {
          state = state.copyWith(pauseRemaining: remaining);
        })
        .then((_) {
          // 倒计时正常结束（非取消）时推进
          if (state.isRetellCountdown && runId == _retellCountdownRunId) {
            _onRetellCountdownFinished();
          }
        });
  }

  /// 复述倒计时结束
  Future<void> _onRetellCountdownFinished() async {
    // 复述完成 = 输出词数 + 停止输出计时
    final session = ref.read(learningSessionProvider.notifier);
    final paragraphWordCount = countWordsInSentences(currentParagraphSentences);
    session.addOutputWords(paragraphWordCount);
    session.stopOutputTimer();

    state = state.copyWith(isRetellCountdown: false);

    // 检查遍数（手动模式视为单遍）
    final effectiveRepeatCount =
        state.settings.isManualMode ? 1 : state.settings.repeatCount;
    if (state.currentRepeatCount < effectiveRepeatCount) {
      // 还有遍数 → 回到 listening phase
      state = state.copyWith(currentRepeatCount: state.currentRepeatCount + 1);
      await _playCurrentParagraph();
    } else {
      // 推进下一段
      await goToNextParagraph();
    }
  }

  /// 取消所有异步操作并停止音频
  ///
  /// 这里必须等待底层 stop 完成，避免在切段时与下一次 setClip
  /// 并发触发 just_audio 的 "Loading interrupted"。
  Future<void> _cancelAll() async {
    final engine = ref.read(audioEngineProvider.notifier);
    _sessionId = engine.newSession();
    _positionSub?.cancel();
    _invalidateRetellCountdown();
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
    _positionSub = null;
  }
}

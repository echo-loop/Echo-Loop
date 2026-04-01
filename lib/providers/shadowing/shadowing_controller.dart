/// 跟读会话控制器
///
/// **唯一的状态入口**：所有状态变更都通过此控制器。
/// Screen 只读 state、只调公开方法，不直接操作资源服务。
///
/// 流程：PlayingPrompt → Recording → (ReviewingRecording) → WaitingInterval → 下一遍/句
///
/// 关键设计：
/// - 倒计时只在 WaitingInterval
/// - flowToken 防异步竞态
/// - 切句原子重置
/// - 手动暂停(保留剩余) vs 外部打断(重置T)
library;

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../database/providers.dart';
import '../../models/sentence.dart';
import '../../services/app_logger.dart';
import '../../services/audio_playback_service.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../learning_session/countdown_controller.dart';
import '../learning_session/learning_session_provider.dart';
import '../listen_and_repeat_turn_controller_provider.dart';
import '../listening_practice/bookmark_manager.dart';
import 'shadowing_phase.dart';
import 'shadowing_session_state.dart';

part 'shadowing_controller.g.dart';

/// 跟读差异化配置
///
/// 各页面（跟读/难句补练/收藏复习）通过不同 Config 注入差异行为。
class ShadowingConfig {
  /// 音频项 ID（用于构建 promptId）
  final String audioItemId;

  /// 获取指定句子的目标遍数
  final int Function(Sentence sentence) getRepeatCount;

  /// 获取遍间倒计时时长
  final Duration Function(Sentence sentence) getIntervalDuration;

  /// 是否手动模式（手动模式下不自动录音、不自动倒计时推进）
  final bool Function() isManualMode;

  /// 句子播放前的钩子（如收藏复习需要跨音频加载）
  final Future<void> Function(int sentenceIndex)? onBeforeSentenceStart;

  /// 句子播完一遍的回调（用于学习统计）
  final void Function(Sentence sentence)? onSentencePlayed;

  const ShadowingConfig({
    required this.audioItemId,
    required this.getRepeatCount,
    required this.getIntervalDuration,
    required this.isManualMode,
    this.onBeforeSentenceStart,
    this.onSentencePlayed,
  });
}

/// 跟读会话控制器
@Riverpod(keepAlive: true)
class ShadowingController extends _$ShadowingController {
  /// 句子列表
  List<Sentence> _sentences = [];

  /// 差异化配置
  late ShadowingConfig _config;

  /// 倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 录音回放服务
  final AudioPlaybackService _playbackService = AudioPlaybackService();

  /// 回放结束监听
  StreamSubscription<bool>? _playbackSub;

  @override
  ShadowingSessionState build() {
    // 监听录音控制器状态变化（评估完成时推进流程）
    ref.listen(shadowingRecordingControllerProvider, _onRecordingStateChanged);

    ref.onDispose(() {
      _countdown.cancel();
      _playbackSub?.cancel();
      _playbackService.dispose();
    });
    return const ShadowingSessionState();
  }

  // ========== 公开方法（Screen 调用） ==========

  /// 初始化并开始会话
  Future<void> startSession({
    required List<Sentence> sentences,
    required ShadowingConfig config,
    int startIndex = 0,
  }) async {
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _config = config;

    // 监听回放结束
    _playbackSub?.cancel();
    _playbackSub = _playbackService.isPlayingStream.listen((isPlaying) {
      if (!isPlaying && state.phase is ReviewingRecording) {
        _onReviewPlaybackFinished();
      }
    });

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);
    final sentence = _sentences[safeIndex];

    state = ShadowingSessionState(
      phase: const Idle(),
      sentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      totalRepeats: config.getRepeatCount(sentence),
      intervalTotal: config.getIntervalDuration(sentence),
      flowToken: 1,
    );

    // 同步录音控制器模式
    ref
        .read(shadowingRecordingControllerProvider.notifier)
        .setManualMode(config.isManualMode());

    await _playCurrentSentence();
  }

  /// 进入等待用户操作状态
  ///
  /// 停止所有资源（播放/录音/倒计时），进入 WaitingForUser。
  /// 用户做任何操作（录音/播放/切句）后自动恢复正常流程。
  void enterWaitingForUser() {
    final phase = state.phase;
    if (phase is WaitingForUser || phase is Idle || phase is SessionCompleted) {
      return;
    }

    _stopAllResources();
    state = state.copyWith(phase: const WaitingForUser());
    AppLogger.log('Shadowing', '→ WaitingForUser (从 ${phase.runtimeType})');
  }

  /// 下一句（原子重置）
  Future<void> nextSentence() async {
    if (state.isLastSentence) return;
    await _jumpToSentence(state.sentenceIndex + 1);
  }

  /// 上一句（原子重置）
  Future<void> previousSentence() async {
    if (state.isFirstSentence) return;
    await _jumpToSentence(state.sentenceIndex - 1);
  }

  /// 手动开始录音
  ///
  /// 在 WaitingInterval 或 WaitingForUser 阶段允许开始录音。
  void startManualRecording() {
    final phase = state.phase;
    if (phase is! WaitingInterval && phase is! WaitingForUser) {
      AppLogger.log(
        'Shadowing',
        'startManualRecording 跳过: phase=${phase.runtimeType}',
      );
      return;
    }
    _startRecording();
  }

  /// 手动停止录音
  ///
  /// 如果未检测到语音，取消录音（不评估）回到 WaitingInterval 等用户重试。
  /// 如果已检测到语音，停止并评估。
  Future<void> stopRecording() async {
    if (state.phase is! ShadowingRecording) return;
    final sentence = _currentSentence;
    if (sentence == null) return;

    final recController = ref.read(
      shadowingRecordingControllerProvider.notifier,
    );
    final recState = ref.read(shadowingRecordingControllerProvider);

    if (!recState.hasDetectedSpeech) {
      // 没检测到语音 → 取消录音，回到等待状态
      AppLogger.log('Shadowing', '手动停止录音: 无语音 → 取消');
      await recController.cancelActiveRecording();
      state = state.copyWith(phase: const WaitingForUser());
      return;
    }

    AppLogger.log('Shadowing', '手动停止录音: 有语音 → 评估');
    await recController.stopAndEvaluate(referenceText: sentence.text);
    // 评估完成后 _onRecordingStateChanged 回调推进流程
  }

  /// 播放录音回放
  Future<void> playRecording() async {
    final path = state.recordingPath;
    if (path == null || path.isEmpty) return;

    final phase = state.phase;
    if (phase is! WaitingInterval &&
        phase is! WaitingForUser &&
        phase is! Idle) return;

    // 如果在倒计时中，取消倒计时
    if (phase is WaitingInterval) {
      _countdown.cancel();
    }

    state = state.copyWith(phase: const ReviewingRecording());
    AppLogger.log('Shadowing', '播放录音回放');
    await _playbackService.play(path);
    // 播放结束由 _playbackSub 监听触发 _onReviewPlaybackFinished
  }

  /// 停止录音回放
  Future<void> stopPlayback() async {
    if (state.phase is! ReviewingRecording) return;
    await _playbackService.stop();
    // _playbackSub 会触发 _onReviewPlaybackFinished
  }

  /// 用户打开弹窗（查词典/设置等）→ 进入等待用户状态
  void onUserInteraction() {
    enterWaitingForUser();
  }

  /// 用户关闭设置弹窗 → 同步设置变更
  void onSettingsClosed() {
    ref
        .read(shadowingRecordingControllerProvider.notifier)
        .setManualMode(_config.isManualMode());
  }

  /// 快进倒计时（10 倍速）
  void fastForwardInterval() {
    AppLogger.log(
      'Shadowing',
      'fastForward: phase=${state.phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}, '
          'speed=${_countdown.speed}',
    );
    if (state.phase is! WaitingInterval) return;
    if (!_countdown.isActive) return;
    _countdown.setSpeed(10.0);
    AppLogger.log('Shadowing', '倒计时快进 10x → speed=${_countdown.speed}');
  }

  /// 暂停倒计时（WaitingInterval 中用户点击倒计时圆环）
  void pauseInterval() {
    AppLogger.log(
      'Shadowing',
      'pauseInterval: phase=${state.phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}',
    );
    if (state.phase is! WaitingInterval) return;
    if (_countdown.isPaused) return;
    _countdown.pause();
    state = state.copyWith(isIntervalPaused: true);
    AppLogger.log('Shadowing', '倒计时暂停 ✓');
  }

  /// 恢复倒计时
  void resumeInterval() {
    AppLogger.log(
      'Shadowing',
      'resumeInterval: phase=${state.phase.runtimeType}, '
          'countdownActive=${_countdown.isActive}, '
          'countdownPaused=${_countdown.isPaused}, '
          'isIntervalPaused=${state.isIntervalPaused}',
    );
    if (state.phase is! WaitingInterval) return;
    if (!_countdown.isPaused) return;
    _countdown.resume();
    state = state.copyWith(isIntervalPaused: false);
    AppLogger.log('Shadowing', '倒计时恢复 ✓');
  }

  /// 停止会话
  void stopSession() {
    _atomicReset();
    state = state.copyWith(phase: const Idle());
  }

  /// 释放资源
  void disposeSession() {
    _atomicReset();
    ref.read(shadowingRecordingControllerProvider.notifier).fullReset();
    _sentences = [];
    state = const ShadowingSessionState();
  }

  /// 重播当前句子（倒计时期间用户点击播放按钮时调用）
  ///
  /// 停止所有资源，保持当前遍数，重新播放当前句子。
  Future<void> replayCurrentSentence() async {
    _stopAllResources();
    ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();
    state = state.copyWith(
      recordingPath: null,
      recordingScore: null,
      flowToken: state.flowToken + 1,
    );
    await _playCurrentSentence();
  }

  /// 切换当前句子的收藏标记（内存 + DB）
  Future<void> toggleCurrentBookmark() async {
    if (_sentences.isEmpty) return;
    final idx = state.sentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.isBookmarked;
    _sentences[idx] = s.copyWith(isBookmarked: !wasBookmarked);
    state = state.copyWith(flowToken: state.flowToken + 1);

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (wasBookmarked) {
      await bookmarkDao.removeBookmark(_config.audioItemId, s.index);
    } else {
      await BookmarkManager.addBookmarkToDb(
        _config.audioItemId,
        s,
        dao: bookmarkDao,
      );
    }
  }

  // ========== 进度管理 ==========

  /// 保存跟读断点
  Future<void> saveBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _config.audioItemId,
          state.sentenceIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 清除断点（完成时调用）
  Future<void> clearBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _config.audioItemId,
          null,
          isFreePlay: isFreePlay,
        );
  }

  /// 递增跟读遍数统计
  Future<void> incrementPassCount() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementShadowingPassCount(_config.audioItemId);
  }

  /// 标记当前子步骤完成
  Future<void> completeSubStage() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage(_config.audioItemId);
  }

  /// 退出学习模式（释放资源 + 通知 learningSession）
  Future<void> exitLearningMode() async {
    disposeSession();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
  }

  /// 获取当前句子（供 Screen 读取）
  Sentence? get currentSentence => _currentSentence;

  /// 获取当前句子索引
  int get currentIndex => state.sentenceIndex;

  /// 获取句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  // ========== 录音状态监听 ==========

  /// 录音控制器状态变化回调
  void _onRecordingStateChanged(
    ListenAndRepeatTurnState? prev,
    ListenAndRepeatTurnState next,
  ) {
    if (prev == null) return;

    // 评估完成（processing → idle，有结果）→ 推进流程
    if (prev.phase == ListenAndRepeatTurnPhase.processing &&
        next.phase == ListenAndRepeatTurnPhase.idle &&
        next.currentAttempt != null) {
      final token = state.flowToken;
      final attempt = next.currentAttempt!;
      _onRecordingFinished(token, attempt.filePath, attempt.score);
    }

    // 录音取消/超时（→ idle 无结果）→ 等待用户操作
    if (state.phase is ShadowingRecording &&
        next.phase == ListenAndRepeatTurnPhase.idle &&
        next.currentAttempt == null) {
      AppLogger.log('Shadowing', '录音取消/超时 → WaitingForUser');
      state = state.copyWith(phase: const WaitingForUser());
    }
  }

  // ========== 资源回调（内部方法） ==========

  /// 原句播放完成回调
  void _onPromptFinished(int token) {
    if (token != state.flowToken) return;
    if (state.phase is! PlayingPrompt) return;

    AppLogger.log('Shadowing', '原句播放完成');
    _config.onSentencePlayed?.call(_currentSentence!);

    if (_config.isManualMode()) {
      // 手动模式：不自动录音，等用户手动操作
      state = state.copyWith(phase: const WaitingForUser());
      return;
    }

    // 自动模式：开始录音
    _startRecording();
  }

  /// 录音完成回调（自动/手动统一收口）
  void _onRecordingFinished(int token, String? filePath, double? score) {
    if (token != state.flowToken) return;
    if (state.phase is! ShadowingRecording) return;

    AppLogger.log(
      'Shadowing',
      score != null ? '录音评估完成: score=$score' : '录音评估失败: 无有效识别结果',
    );
    state = state.copyWith(recordingPath: filePath, recordingScore: score);

    // 识别失败（score 为 null）：回到等待状态，清掉失败的 attempt
    if (score == null) {
      AppLogger.log('Shadowing', '→ 识别失败，等待用户重试');
      // 先改 phase，再 clear，避免 clearRecording 触发 _onRecordingStateChanged 时
      // state.phase 还是 ShadowingRecording 导致二次触发
      state = state.copyWith(
        phase: const WaitingForUser(),
        recordingPath: null,
        recordingScore: null,
      );
      ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();
      return;
    }

    // 手动模式：等用户操作
    if (_config.isManualMode()) {
      AppLogger.log('Shadowing', '→ 手动模式，等待用户操作');
      state = state.copyWith(phase: const WaitingForUser());
      return;
    }

    // 自动模式 + 识别成功：进入遍间倒计时
    _startInterval(resetFull: true);
  }

  /// 录音回放完成回调
  void _onReviewPlaybackFinished() {
    if (state.phase is! ReviewingRecording) return;

    AppLogger.log('Shadowing', '回放结束 → WaitingInterval');

    if (_config.isManualMode()) {
      state = state.copyWith(phase: const WaitingForUser());
      return;
    }

    // 自动模式：回放结束后重置完整 T 秒
    _startInterval(resetFull: true);
  }

  /// 倒计时 tick 回调
  void _onIntervalTick(int token, Duration remaining) {
    if (token != state.flowToken) return;
    if (state.phase is! WaitingInterval) return;
    state = state.copyWith(intervalRemaining: remaining);
  }

  /// 倒计时结束回调
  void _onIntervalFinished() {
    if (state.phase is! WaitingInterval) return;
    _advanceToNextRepeatOrSentence();
  }

  // ========== 内部流程方法 ==========

  /// 播放当前句子
  Future<void> _playCurrentSentence() async {
    final sentence = _currentSentence;
    if (sentence == null) return;

    // 跳过零时长句子
    if (sentence.duration <= Duration.zero) {
      _advanceToNextRepeatOrSentence();
      return;
    }

    await _config.onBeforeSentenceStart?.call(state.sentenceIndex);

    state = state.copyWith(phase: const PlayingPrompt());
    final token = state.flowToken;

    AppLogger.log(
      'Shadowing',
      '播放句子 ${state.sentenceIndex + 1}/${state.totalSentences} '
          '第 ${state.repeatIndex + 1}/${state.totalRepeats} 遍',
    );

    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.playClipOnce(sentence, sessionId);

    _onPromptFinished(token);
  }

  /// 启动录音
  void _startRecording() {
    final sentence = _currentSentence;
    if (sentence == null) return;

    state = state.copyWith(phase: const ShadowingRecording());

    final promptId = 'shadowing:${_config.audioItemId}:${sentence.index}';

    // 设置录音阈值：max(2.5 × sentenceDuration + 5s, 10s)
    final computed = sentence.duration * 2.5 + const Duration(seconds: 5);
    final maxDuration = computed < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : computed;

    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    controller.setMaxRecordingDuration(maxDuration);

    AppLogger.log('Shadowing', '开始录音: $promptId');
    unawaited(
      controller.startRecording(
        promptId: promptId,
        referenceText: sentence.text,
      ),
    );
  }

  /// 启动遍间倒计时
  Future<void> _startInterval({required bool resetFull}) async {
    final total = state.intervalTotal;
    final remaining = resetFull ? total : state.intervalRemaining;

    state = state.copyWith(
      phase: const WaitingInterval(),
      intervalRemaining: remaining,
      isIntervalPaused: false,
    );

    if (_config.isManualMode()) return;

    final token = state.flowToken;
    await _countdown.start(remaining, (rem) {
      _onIntervalTick(token, rem);
    });

    // 倒计时自然结束（cancel 也会 complete，用 token 区分）
    if (token == state.flowToken && state.phase is WaitingInterval) {
      _onIntervalFinished();
    }
  }

  /// 推进到下一遍或下一句
  void _advanceToNextRepeatOrSentence() {
    if (state.isLastRepeat) {
      if (state.isLastSentence) {
        AppLogger.log('Shadowing', '全部完成');
        state = state.copyWith(phase: const SessionCompleted());
      } else {
        AppLogger.log('Shadowing', '当前句完成 → 下一句');
        _jumpToSentence(state.sentenceIndex + 1);
      }
    } else {
      final nextRepeat = state.repeatIndex + 1;
      AppLogger.log(
        'Shadowing',
        '下一遍: ${nextRepeat + 1}/${state.totalRepeats}',
      );
      ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();
      state = state.copyWith(
        repeatIndex: nextRepeat,
        recordingPath: null,
        recordingScore: null,
      );
      _playCurrentSentence();
    }
  }

  /// 跳转到指定句子（原子重置）
  Future<void> _jumpToSentence(int index) async {
    _atomicReset();

    final sentence = _sentences[index];
    state = state.copyWith(
      phase: const Idle(),
      sentenceIndex: index,
      repeatIndex: 0,
      totalRepeats: _config.getRepeatCount(sentence),
      intervalTotal: _config.getIntervalDuration(sentence),
      intervalRemaining: Duration.zero,
      recordingPath: null,
      recordingScore: null,
      flowToken: state.flowToken + 1,
    );

    await _playCurrentSentence();
  }

  /// 原子重置：停止所有资源 + 递增 token
  void _atomicReset() {
    _stopAllResources();
    state = state.copyWith(flowToken: state.flowToken + 1);
  }

  /// 停止所有资源服务
  void _stopAllResources() {
    ref.read(audioEngineProvider.notifier).pause();
    _countdown.cancel();
    final recController = ref.read(
      shadowingRecordingControllerProvider.notifier,
    );
    recController.cancelActiveRecording();
    recController.clearRecording();
    _playbackService.stop();
  }


  /// 当前句子
  Sentence? get _currentSentence =>
      _sentences.isNotEmpty && state.sentenceIndex < _sentences.length
      ? _sentences[state.sentenceIndex]
      : null;
}

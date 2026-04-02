/// 跟读流程引擎
///
/// 封装跟读核心流程：play → record → evaluate → interval → next repeat/sentence。
/// 纯 Dart 类，不依赖 Riverpod，通过回调与外部交互。
///
/// 各页面的 Controller/Provider 组合此引擎：
/// - 跟读页面：ListenAndRepeatController
/// - 难句补练：ReviewDifficultPractice（跟读模式时使用）
/// - 收藏复习：BookmarkReview（跟读模式时使用）
library;

import 'dart:async';

import '../../models/sentence.dart';
import '../../services/app_logger.dart';
import '../../services/audio_playback_service.dart';
import '../learning_session/countdown_controller.dart';
import 'repeat_flow_phase.dart';
import 'repeat_flow_state.dart';

/// 智能停顿最小时长（毫秒）
const kSmartPauseMinMs = 2000;

/// 智能停顿最大时长（毫秒）
const kSmartPauseMaxMs = 20000;

/// 倍率停顿最小时长（毫秒）
const kMultiplierPauseMinMs = 1000;

/// 倒计时快进速度倍率
const kFastForwardSpeed = 10.0;

/// 录音最大时长 = sentenceDuration × 此倍率 + kRecordingTimeoutBase
const kRecordingDurationMultiplier = 2.5;

/// 录音超时基础时长
const kRecordingTimeoutBase = Duration(seconds: 5);

/// 录音最小超时时长
const kRecordingMinTimeout = Duration(seconds: 10);

/// 跟读流程配置
class RepeatFlowConfig {
  /// 音频项 ID（用于构建 promptId）
  final String audioItemId;

  /// 获取指定句子的目标遍数
  final int Function(Sentence sentence) getRepeatCount;

  /// 获取遍间倒计时时长
  final Duration Function(Sentence sentence) getIntervalDuration;

  /// 是否手动模式
  final bool Function() isManualMode;

  /// 句子播放前的钩子（如收藏复习需要跨音频加载）
  final Future<void> Function(int sentenceIndex)? onBeforeSentenceStart;

  /// 句子播完一遍的回调（用于学习统计等）
  final void Function(Sentence sentence)? onSentencePlayed;

  /// promptId 前缀（默认 'lar'，各页面可自定义）
  final String promptIdPrefix;

  const RepeatFlowConfig({
    required this.audioItemId,
    required this.getRepeatCount,
    required this.getIntervalDuration,
    required this.isManualMode,
    this.onBeforeSentenceStart,
    this.onSentencePlayed,
    this.promptIdPrefix = 'lar',
  });
}

/// 跟读流程引擎回调
class RepeatFlowCallbacks {
  /// 播放句子音频
  final Future<void> Function(Sentence sentence, int flowToken) playSentence;

  /// 开始录音
  final void Function({
    required String promptId,
    required String referenceText,
    required Duration maxDuration,
  }) startRecording;

  /// 取消录音
  final Future<void> Function() cancelRecording;

  /// 停止录音并评估
  final Future<void> Function({required String referenceText}) stopAndEvaluate;

  /// 清除录音数据（切句/重播时调用）
  final void Function() clearRecording;

  /// 设置录音最大时长
  final void Function(Duration duration) setMaxRecordingDuration;

  /// 查询是否检测到语音
  final bool Function() hasDetectedSpeech;

  const RepeatFlowCallbacks({
    required this.playSentence,
    required this.startRecording,
    required this.cancelRecording,
    required this.stopAndEvaluate,
    required this.clearRecording,
    required this.setMaxRecordingDuration,
    required this.hasDetectedSpeech,
  });
}

/// 跟读流程引擎
///
/// 通过 [prepare] 配置句子和参数，[startPlaying] 开始流程。
/// 状态变化通过 [onStateChanged] 回调通知外部。
class RepeatFlowEngine {
  /// 状态变化回调
  final void Function(RepeatFlowState state) onStateChanged;

  /// 外部交互回调
  final RepeatFlowCallbacks callbacks;

  /// 日志标签
  final String logTag;

  /// 倒计时控制器
  final CountdownController _countdown = CountdownController();

  /// 录音回放服务
  final AudioPlaybackService _playbackService = AudioPlaybackService();

  /// 句子列表
  List<Sentence> _sentences = [];

  /// 配置
  late RepeatFlowConfig _config;

  /// 当前状态
  RepeatFlowState _state = const RepeatFlowState();

  RepeatFlowEngine({
    required this.onStateChanged,
    required this.callbacks,
    this.logTag = 'RepeatFlow',
  });

  /// 当前状态（只读）
  RepeatFlowState get state => _state;

  /// 当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && _state.sentenceIndex < _sentences.length
          ? _sentences[_state.sentenceIndex]
          : null;

  /// 当前 promptId
  String get currentPromptId {
    final sentence = currentSentence;
    final idx = sentence?.index ?? _state.sentenceIndex;
    return '${_config.promptIdPrefix}:${_config.audioItemId}:$idx';
  }

  /// 当前配置
  RepeatFlowConfig get config => _config;

  /// 句子列表（只读）
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  // ========== 公开方法 ==========

  /// 准备会话数据
  void prepare({
    required List<Sentence> sentences,
    required RepeatFlowConfig config,
    int startIndex = 0,
  }) {
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _config = config;

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);
    final sentence = _sentences.isNotEmpty ? _sentences[safeIndex] : null;

    _updateState(RepeatFlowState(
      phase: const Idle(),
      sentenceIndex: safeIndex,
      totalSentences: _sentences.length,
      totalRepeats: sentence != null ? config.getRepeatCount(sentence) : 1,
      intervalDuration:
          sentence != null ? config.getIntervalDuration(sentence) : Duration.zero,
      flowToken: 1,
    ));
  }

  /// 开始播放
  Future<void> startPlaying() async {
    if (_sentences.isEmpty) return;
    await _playCurrentSentence();
  }

  /// 进入等待用户操作状态
  void enterWaitingForUser() {
    final phase = _state.phase;
    if (phase is WaitingForUser || phase is Idle || phase is SessionCompleted) {
      return;
    }

    _stopActiveResources();
    _updateState(_state.copyWith(
      phase: const WaitingForUser(WaitingReason.userInteraction),
    ));
    AppLogger.log(logTag, '→ WaitingForUser (从 ${phase.runtimeType})');
  }

  /// 用户交互（查词/翻译等）
  ///
  /// 仅自动模式生效。手动模式下不打断。
  void onUserInteraction() {
    if (_config.isManualMode()) return;
    enterWaitingForUser();
  }

  /// 下一句
  Future<void> nextSentence() async {
    if (_state.isLastSentence) return;
    await _jumpToSentence(_state.sentenceIndex + 1);
  }

  /// 上一句
  Future<void> previousSentence() async {
    if (_state.isFirstSentence) return;
    await _jumpToSentence(_state.sentenceIndex - 1);
  }

  /// 录音按钮点击
  Future<void> onRecordButtonTapped() async {
    final phase = _state.phase;
    if (phase is Recording) {
      await stopRecording();
      return;
    }
    if (phase is ReviewingRecording) {
      await stopPlayback();
    }
    startManualRecording();
  }

  /// 录音回放按钮点击
  Future<void> togglePlayback() async {
    if (_state.phase is ReviewingRecording) {
      await stopPlayback();
    } else {
      await playRecording();
    }
  }

  /// 手动开始录音
  void startManualRecording() {
    final phase = _state.phase;
    if (phase is! WaitingInterval && phase is! WaitingForUser) {
      AppLogger.log(logTag, 'startManualRecording 跳过: phase=${phase.runtimeType}');
      return;
    }
    _startRecording();
  }

  /// 手动停止录音
  Future<void> stopRecording() async {
    if (_state.phase is! Recording) return;
    final sentence = currentSentence;
    if (sentence == null) return;

    if (!callbacks.hasDetectedSpeech()) {
      AppLogger.log(logTag, '手动停止录音: 无语音 → 取消');
      await callbacks.cancelRecording();
      _updateState(_state.copyWith(
        phase: const WaitingForUser(WaitingReason.recordingFailed),
      ));
      return;
    }

    AppLogger.log(logTag, '手动停止录音: 有语音 → 评估');
    await callbacks.stopAndEvaluate(referenceText: sentence.text);
  }

  /// 播放录音回放
  Future<void> playRecording() async {
    final path = _state.recordingPath;
    if (path == null || path.isEmpty) return;

    final phase = _state.phase;
    if (phase is! WaitingInterval && phase is! WaitingForUser && phase is! Idle) {
      return;
    }

    if (phase is WaitingInterval) {
      _countdown.cancel();
    }

    _updateState(_state.copyWith(
      phase: ReviewingRecording(recordingPath: path),
    ));
    final token = _state.flowToken;
    AppLogger.log(logTag, '播放录音回放: $path');

    await _playbackService.play(path);

    if (token != _state.flowToken) return;
    if (_state.phase is! ReviewingRecording) return;
    _onReviewPlaybackFinished();
  }

  /// 停止录音回放
  Future<void> stopPlayback() async {
    if (_state.phase is! ReviewingRecording) return;
    await _playbackService.stop();
    _onReviewPlaybackFinished();
  }

  /// 快进倒计时
  void fastForwardInterval() {
    if (_state.phase is! WaitingInterval) return;
    if (!_countdown.isActive) return;
    _countdown.setSpeed(kFastForwardSpeed);
    AppLogger.log(logTag, '倒计时快进 ${kFastForwardSpeed}x');
  }

  /// 暂停倒计时
  void pauseInterval() {
    final phase = _state.phase;
    if (phase is! WaitingInterval) return;
    if (_countdown.isPaused) return;
    _countdown.pause();
    _updateState(_state.copyWith(phase: phase.copyWith(isPaused: true)));
  }

  /// 恢复倒计时
  void resumeInterval() {
    final phase = _state.phase;
    if (phase is! WaitingInterval) return;
    if (!_countdown.isPaused) return;
    _countdown.resume();
    _updateState(_state.copyWith(phase: phase.copyWith(isPaused: false)));
  }

  /// 重播当前句子
  Future<void> replayCurrentSentence() async {
    _stopActiveResources();
    callbacks.clearRecording();
    _updateState(_state.copyWith(
      recordingPath: null,
      recordingScore: null,
      flowToken: _state.flowToken + 1,
    ));
    await _playCurrentSentence();
  }

  /// 停止会话
  void stopSession() {
    _atomicReset();
    _updateState(_state.copyWith(phase: const Idle()));
  }

  /// 录音完成回调（由外部 Provider 的 ref.listen 桥接调用）
  void onRecordingFinished(String? filePath, double? score) {
    if (_state.phase is! Recording) return;

    AppLogger.log(
      logTag,
      score != null ? '录音评估完成: score=$score' : '录音评估失败: 无有效识别结果',
    );
    _updateState(_state.copyWith(recordingPath: filePath, recordingScore: score));

    if (score == null) {
      AppLogger.log(logTag, '→ 识别失败，等待用户重试');
      _updateState(_state.copyWith(
        phase: const WaitingForUser(WaitingReason.recordingFailed),
        recordingPath: null,
        recordingScore: null,
      ));
      callbacks.clearRecording();
      return;
    }

    if (_config.isManualMode()) {
      AppLogger.log(logTag, '→ 手动模式，等待用户操作');
      _updateState(_state.copyWith(
        phase: const WaitingForUser(WaitingReason.userInteraction),
      ));
      return;
    }

    _startInterval(resetFull: true);
  }

  /// 录音取消/超时回调（由外部 Provider 的 ref.listen 桥接调用）
  void onRecordingCancelled() {
    if (_state.phase is! Recording) return;
    AppLogger.log(logTag, '录音取消/超时 → WaitingForUser');
    _updateState(_state.copyWith(
      phase: const WaitingForUser(WaitingReason.recordingFailed),
    ));
  }

  /// 释放资源
  void dispose() {
    _countdown.cancel();
    _playbackService.dispose();
    _sentences = [];
  }

  /// 切换句子的收藏标记（仅内存，DB 由调用方处理）
  void updateSentenceBookmark(int index, bool isBookmarked) {
    if (index < 0 || index >= _sentences.length) return;
    _sentences[index] = _sentences[index].copyWith(isBookmarked: isBookmarked);
    _updateState(_state.copyWith(flowToken: _state.flowToken + 1));
  }

  // ========== 内部方法 ==========

  void _updateState(RepeatFlowState newState) {
    _state = newState;
    onStateChanged(newState);
  }

  /// 播放当前句子
  Future<void> _playCurrentSentence() async {
    final sentence = currentSentence;
    if (sentence == null) return;

    if (sentence.duration <= Duration.zero) {
      _advanceToNextRepeatOrSentence();
      return;
    }

    await _config.onBeforeSentenceStart?.call(_state.sentenceIndex);

    _updateState(_state.copyWith(phase: const PlayingPrompt()));
    final token = _state.flowToken;

    AppLogger.log(
      logTag,
      '播放句子 ${_state.sentenceIndex + 1}/${_state.totalSentences} '
          '第 ${_state.repeatIndex + 1}/${_state.totalRepeats} 遍',
    );

    await callbacks.playSentence(sentence, token);

    _onPromptFinished(token);
  }

  /// 原句播放完成
  void _onPromptFinished(int token) {
    if (token != _state.flowToken) return;
    if (_state.phase is! PlayingPrompt) return;

    AppLogger.log(logTag, '原句播放完成');
    _config.onSentencePlayed?.call(currentSentence!);

    if (_config.isManualMode()) {
      _updateState(_state.copyWith(
        phase: const WaitingForUser(WaitingReason.userInteraction),
      ));
      return;
    }

    _startRecording();
  }

  /// 启动录音
  void _startRecording() {
    final sentence = currentSentence;
    if (sentence == null) return;

    final promptId = '${_config.promptIdPrefix}:${_config.audioItemId}:${sentence.index}';
    _updateState(_state.copyWith(phase: Recording(promptId: promptId)));

    final computed = sentence.duration * kRecordingDurationMultiplier + kRecordingTimeoutBase;
    final maxDuration = computed < kRecordingMinTimeout ? kRecordingMinTimeout : computed;

    callbacks.setMaxRecordingDuration(maxDuration);

    AppLogger.log(logTag, '开始录音: $promptId');
    callbacks.startRecording(
      promptId: promptId,
      referenceText: sentence.text,
      maxDuration: maxDuration,
    );
  }

  /// 录音回放完成
  void _onReviewPlaybackFinished() {
    if (_state.phase is! ReviewingRecording) return;
    AppLogger.log(logTag, '回放结束 → WaitingForUser');
    _updateState(_state.copyWith(
      phase: const WaitingForUser(WaitingReason.userInteraction),
    ));
  }

  /// 启动遍间倒计时
  Future<void> _startInterval({required bool resetFull}) async {
    final total = _state.intervalDuration;
    final currentPhase = _state.phase;
    final remaining = resetFull || currentPhase is! WaitingInterval
        ? total
        : currentPhase.remaining;

    _updateState(_state.copyWith(
      phase: WaitingInterval(remaining: remaining, total: total),
    ));

    if (_config.isManualMode()) return;

    final token = _state.flowToken;
    await _countdown.start(remaining, (rem) {
      _onIntervalTick(token, rem);
    });

    if (token == _state.flowToken && _state.phase is WaitingInterval) {
      _onIntervalFinished();
    }
  }

  void _onIntervalTick(int token, Duration remaining) {
    if (token != _state.flowToken) return;
    final phase = _state.phase;
    if (phase is! WaitingInterval) return;
    _updateState(_state.copyWith(phase: phase.copyWith(remaining: remaining)));
  }

  void _onIntervalFinished() {
    if (_state.phase is! WaitingInterval) return;
    _advanceToNextRepeatOrSentence();
  }

  /// 推进到下一遍或下一句
  void _advanceToNextRepeatOrSentence() {
    if (_state.isLastRepeat) {
      if (_state.isLastSentence) {
        AppLogger.log(logTag, '全部完成');
        _updateState(_state.copyWith(phase: const SessionCompleted()));
      } else {
        AppLogger.log(logTag, '当前句完成 → 下一句');
        _jumpToSentence(_state.sentenceIndex + 1);
      }
    } else {
      final nextRepeat = _state.repeatIndex + 1;
      AppLogger.log(logTag, '下一遍: ${nextRepeat + 1}/${_state.totalRepeats}');
      callbacks.clearRecording();
      _updateState(_state.copyWith(
        repeatIndex: nextRepeat,
        recordingPath: null,
        recordingScore: null,
      ));
      _playCurrentSentence();
    }
  }

  /// 跳转到指定句子
  Future<void> _jumpToSentence(int index) async {
    _atomicReset();
    callbacks.clearRecording();

    final sentence = _sentences[index];
    _updateState(_state.copyWith(
      phase: const Idle(),
      sentenceIndex: index,
      repeatIndex: 0,
      totalRepeats: _config.getRepeatCount(sentence),
      intervalDuration: _config.getIntervalDuration(sentence),
      recordingPath: null,
      recordingScore: null,
      flowToken: _state.flowToken + 1,
    ));

    await _playCurrentSentence();
  }

  void _atomicReset() {
    _stopActiveResources();
    _state = _state.copyWith(flowToken: _state.flowToken + 1);
  }

  void _stopActiveResources() {
    _countdown.cancel();
    callbacks.cancelRecording();
    _playbackService.stop();
  }
}

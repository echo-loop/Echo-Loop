/// 盲听练习流程引擎
///
/// 封装盲听模式核心流程：play -> repeat interval -> sentence interval -> next sentence。
library;

import 'dart:async';

import '../../models/sentence.dart';
import '../../models/sentence_playback_result.dart';
import '../../services/app_logger.dart';
import '../learning_session/countdown_controller.dart';
import 'blind_practice_flow_phase.dart';
import 'blind_practice_flow_state.dart';

/// 盲听流程配置
class BlindPracticeFlowConfig {
  /// 获取指定句子的目标遍数
  final int Function(Sentence sentence) getRepeatCount;

  /// 获取遍间停顿时长
  final Duration Function(Sentence sentence) getRepeatIntervalDuration;

  /// 获取句间停顿时长
  final Duration Function(Sentence sentence) getSentenceIntervalDuration;

  /// 句子播放前钩子，例如收藏复习中的跨音频加载
  final Future<bool> Function(int sentenceIndex)? onBeforeSentenceStart;

  /// 每成功播放一遍后的回调
  final void Function(Sentence sentence)? onSentencePlayed;

  /// 是否为手动模式。手动模式完成设置的循环后等待用户切句。
  final bool Function() isManualMode;

  const BlindPracticeFlowConfig({
    required this.getRepeatCount,
    required this.getRepeatIntervalDuration,
    required this.getSentenceIntervalDuration,
    this.onBeforeSentenceStart,
    this.onSentencePlayed,
    required this.isManualMode,
  });
}

/// 盲听流程引擎回调
class BlindPracticeFlowCallbacks {
  /// 暂停音频播放
  final void Function() pauseAudio;

  /// 播放句子音频；只有明确失败才会跳过当前句。
  final Future<SentencePlaybackResult> Function(
    Sentence sentence,
    int flowToken,
  )
  playSentence;

  /// 从暂停位置继续播放当前句；未提供时退回普通起播。
  final Future<SentencePlaybackResult> Function(
    Sentence sentence,
    int flowToken,
    Duration startAt,
  )?
  resumeSentence;

  const BlindPracticeFlowCallbacks({
    required this.pauseAudio,
    required this.playSentence,
    this.resumeSentence,
  });
}

/// 盲听练习流程引擎
class BlindPracticeFlowEngine {
  final void Function(BlindPracticeFlowState state) onStateChanged;
  final BlindPracticeFlowCallbacks callbacks;
  final String logTag;

  final CountdownController _countdown = CountdownController();

  List<Sentence> _sentences = [];
  late BlindPracticeFlowConfig _config;
  BlindPracticeFlowState _state = const BlindPracticeFlowState();
  bool _disposed = false;
  bool _waitAfterCurrentPrompt = false;

  BlindPracticeFlowEngine({
    required this.onStateChanged,
    required this.callbacks,
    this.logTag = 'BlindFlow',
  });

  BlindPracticeFlowState get state => _state;

  /// 当前句播完后是否应转入等待用户状态。
  bool get willEnterWaitingAfterCurrentPrompt => _waitAfterCurrentPrompt;

  Sentence? get currentSentence =>
      _sentences.isNotEmpty && _state.sentenceIndex < _sentences.length
      ? _sentences[_state.sentenceIndex]
      : null;

  void prepare({
    required List<Sentence> sentences,
    required BlindPracticeFlowConfig config,
    int startIndex = 0,
  }) {
    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _config = config;

    final safeIndex = _sentences.isEmpty
        ? 0
        : startIndex.clamp(0, _sentences.length - 1);
    final sentence = _sentences.isNotEmpty ? _sentences[safeIndex] : null;

    _updateState(
      BlindPracticeFlowState(
        phase: const BlindIdle(),
        sentenceIndex: safeIndex,
        totalSentences: _sentences.length,
        totalRepeats: sentence != null ? config.getRepeatCount(sentence) : 1,
        flowToken: _state.flowToken + 1,
      ),
    );
  }

  Future<void> startPlaying() async {
    if (_disposed) return;
    if (_sentences.isEmpty) return;
    await _playCurrentSentence();
  }

  void enterWaitingForUser({bool afterCurrentPrompt = false}) {
    if (_disposed) return;
    final phase = _state.phase;
    if (phase is BlindIdle ||
        phase is BlindWaitingForUser ||
        phase is BlindSessionCompleted) {
      return;
    }

    if (afterCurrentPrompt && phase is BlindPlayingPrompt) {
      _waitAfterCurrentPrompt = true;
      AppLogger.log(logTag, '-> WaitingForUser (after current prompt)');
      return;
    }

    _stopActiveResources();
    _waitAfterCurrentPrompt = false;
    _updateState(
      _state.copyWith(
        phase: const BlindWaitingForUser(BlindWaitingReason.userInteraction),
        // 主动暂停会取消当前播放；递增 token，避免取消结果被误判为不可播放。
        flowToken: _state.flowToken + 1,
      ),
    );
    AppLogger.log(logTag, '-> WaitingForUser (from ${phase.runtimeType})');
  }

  /// 重播当前句；手动模式从本轮第一遍重新开始。
  Future<void> replayCurrentSentence() async {
    if (_disposed) return;
    final sentence = currentSentence;
    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: const BlindIdle(),
        repeatIndex: _config.isManualMode() ? 0 : _state.repeatIndex,
        totalRepeats: sentence == null
            ? _state.totalRepeats
            : _config.getRepeatCount(sentence),
        flowToken: _state.flowToken + 1,
      ),
    );
    await _playCurrentSentence();
  }

  /// 从给定媒体位置继续当前句，保留本轮重复次数和流程状态。
  Future<void> resumeCurrentSentence(Duration startAt) async {
    if (_disposed || currentSentence == null) return;
    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: const BlindIdle(),
        flowToken: _state.flowToken + 1,
      ),
    );
    await _playCurrentSentence(startAt: startAt);
  }

  Future<void> nextSentence() async {
    if (_disposed) return;
    if (_state.isLastSentence) return;
    await _jumpToSentence(_state.sentenceIndex + 1);
  }

  Future<void> previousSentence() async {
    if (_disposed) return;
    if (_state.isFirstSentence) return;
    await _jumpToSentence(_state.sentenceIndex - 1);
  }

  void pauseInterval() {
    if (_disposed) return;
    final phase = _state.phase;
    if (phase is! BlindWaitingInterval || _countdown.isPaused) {
      return;
    }
    _countdown.pause();
    _updateState(_state.copyWith(phase: phase.copyWith(isPaused: true)));
  }

  void resumeInterval() {
    if (_disposed) return;
    final phase = _state.phase;
    if (phase is! BlindWaitingInterval || !_countdown.isPaused) {
      return;
    }
    _countdown.resume();
    _updateState(_state.copyWith(phase: phase.copyWith(isPaused: false)));
  }

  void setIntervalSpeed(double speed) {
    if (_disposed) return;
    if (_state.phase is! BlindWaitingInterval) return;
    _countdown.setSpeed(speed);
  }

  /// 快进倒计时（动态速度，~1.5 秒内结束）
  ///
  /// 返回实际速度倍率，供调用方同步 UI。
  double fastForwardInterval() {
    if (_disposed) return 1.0;
    if (_state.phase is! BlindWaitingInterval) return 1.0;
    return _countdown.fastForward();
  }

  Future<void> restartCurrentSentence({bool autoplay = true}) async {
    if (_disposed) return;
    final sentence = currentSentence;
    if (sentence == null) return;

    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: autoplay
            ? const BlindIdle()
            : const BlindWaitingForUser(BlindWaitingReason.userInteraction),
        repeatIndex: 0,
        totalRepeats: _config.getRepeatCount(sentence),
        flowToken: _state.flowToken + 1,
      ),
    );

    if (autoplay) {
      await _playCurrentSentence();
    }
  }

  void stopSession() {
    if (_disposed) return;
    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    _updateState(
      _state.copyWith(
        phase: const BlindIdle(),
        flowToken: _state.flowToken + 1,
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _waitAfterCurrentPrompt = false;
    _countdown.cancel();
    _state = _state.copyWith(flowToken: _state.flowToken + 1);
    _sentences = [];
  }

  /// 播放当前句，并在异步前置检查后校验本次 flowToken。
  /// [startAt] 仅属于本次启动，避免切句后串用旧的恢复位置。
  Future<void> _playCurrentSentence({Duration? startAt}) async {
    if (_disposed) return;
    final sentence = currentSentence;
    if (sentence == null) return;
    final initialFlowToken = _state.flowToken;

    if (sentence.duration <= Duration.zero) {
      await _advanceToNextSentence();
      return;
    }

    final canStart =
        await _config.onBeforeSentenceStart?.call(_state.sentenceIndex) ?? true;
    if (_disposed || initialFlowToken != _state.flowToken) return;
    if (!canStart) {
      await _skipCurrentSentence(reason: 'before-sentence-start-rejected');
      return;
    }

    _updateState(_state.copyWith(phase: const BlindPlayingPrompt()));
    final token = _state.flowToken;
    AppLogger.log(
      logTag,
      'event=play-start sentenceIndex=${_state.sentenceIndex} '
      'sentence=${_state.sentenceIndex + 1}/${_state.totalSentences} '
      'repeat=${_state.repeatIndex + 1}/${_state.totalRepeats} '
      'flowToken=$token',
    );

    final resumeSentence = callbacks.resumeSentence;
    final result = startAt != null && resumeSentence != null
        ? await resumeSentence(sentence, token, startAt)
        : await callbacks.playSentence(sentence, token);
    if (_disposed) return;
    final currentFlowToken = _state.flowToken;
    AppLogger.log(
      logTag,
      'event=play-result sentenceIndex=${sentence.index} '
      'flowToken=$token currentFlowToken=$currentFlowToken '
      'currentIndex=${_state.sentenceIndex} '
      'phase=${_state.phase.runtimeType} result=$result',
    );
    if (token != currentFlowToken) {
      AppLogger.log(
        logTag,
        'event=play-result-ignored reason=stale-flow-token '
        'flowToken=$token currentFlowToken=$currentFlowToken '
        'result=$result',
      );
      return;
    }
    if (result == SentencePlaybackResult.cancelled) {
      _handlePromptCancelled(token);
      return;
    }
    if (result == SentencePlaybackResult.failed) {
      await _handlePromptNotPlayed(token);
      return;
    }

    _onPromptFinished(token);
  }

  /// 区分当前句真实不可播放和旧播放请求被取消两种结果。
  ///
  /// 当前请求只有明确失败才跳过；旧请求通过 flow token 校验后静默丢弃。
  Future<void> _handlePromptNotPlayed(int token) async {
    if (token != _state.flowToken) return;
    await _skipCurrentSentence(reason: 'playback-failed');
  }

  /// 当前流程的播放被取消时保留句子，等待用户重新播放或切换。
  void _handlePromptCancelled(int token) {
    if (token != _state.flowToken || _state.phase is! BlindPlayingPrompt) {
      return;
    }
    _waitAfterCurrentPrompt = false;
    _updateState(
      _state.copyWith(
        phase: const BlindWaitingForUser(BlindWaitingReason.userInteraction),
        flowToken: _state.flowToken + 1,
      ),
    );
    AppLogger.log(
      logTag,
      'event=play-cancelled action=wait sentenceIndex=${_state.sentenceIndex} '
      'flowToken=$token nextFlowToken=${_state.flowToken}',
    );
  }

  void _onPromptFinished(int token) {
    if (_disposed) return;
    if (token != _state.flowToken) return;
    if (_state.phase is! BlindPlayingPrompt) return;

    final sentence = currentSentence;
    if (sentence == null) return;
    _config.onSentencePlayed?.call(sentence);
    AppLogger.log(
      logTag,
      'event=prompt-finished sentenceIndex=${_state.sentenceIndex} '
      'flowToken=$token',
    );

    if (_waitAfterCurrentPrompt) {
      _waitAfterCurrentPrompt = false;
      _updateState(
        _state.copyWith(
          repeatIndex: 0,
          totalRepeats: _config.getRepeatCount(sentence),
          phase: const BlindWaitingForUser(BlindWaitingReason.userInteraction),
        ),
      );
      return;
    }

    if (_state.isLastRepeat) {
      if (_config.isManualMode()) {
        // 手动模式完成所有循环后停在当前句，不触发句间倒计时或自动推进。
        _updateState(
          _state.copyWith(
            phase: const BlindWaitingForUser(
              BlindWaitingReason.userInteraction,
            ),
          ),
        );
        return;
      }
      unawaited(_startSentenceInterval(sentence));
      return;
    }

    final nextRepeat = _state.repeatIndex + 1;
    _updateState(_state.copyWith(repeatIndex: nextRepeat));
    unawaited(
      _startInterval(
        total: _config.getRepeatIntervalDuration(sentence),
        isBetweenSentences: false,
        onFinished: _playCurrentSentence,
      ),
    );
  }

  Future<void> _startSentenceInterval(Sentence sentence) async {
    if (_disposed) return;
    await _startInterval(
      total: _config.getSentenceIntervalDuration(sentence),
      isBetweenSentences: true,
      onFinished: _advanceToNextSentence,
    );
  }

  Future<void> _startInterval({
    required Duration total,
    required bool isBetweenSentences,
    required Future<void> Function() onFinished,
  }) async {
    if (_disposed) return;
    _updateState(
      _state.copyWith(
        phase: BlindWaitingInterval(
          remaining: total,
          total: total,
          isBetweenSentences: isBetweenSentences,
        ),
      ),
    );

    final token = _state.flowToken;
    await _countdown.start(total);

    if (token != _state.flowToken || _state.phase is! BlindWaitingInterval) {
      return;
    }
    if (_disposed) return;
    await onFinished();
  }

  Future<void> _advanceToNextSentence() async {
    if (_disposed) return;
    if (_state.isLastSentence) {
      AppLogger.log(
        logTag,
        'event=session-completed sentenceIndex=${_state.sentenceIndex} '
        'flowToken=${_state.flowToken}',
      );
      _updateState(_state.copyWith(phase: const BlindSessionCompleted()));
      return;
    }
    AppLogger.log(
      logTag,
      'event=auto-advance reason=interval-completed '
      'fromIndex=${_state.sentenceIndex} toIndex=${_state.sentenceIndex + 1} '
      'flowToken=${_state.flowToken}',
    );
    await _jumpToSentence(_state.sentenceIndex + 1);
  }

  Future<void> _skipCurrentSentence({required String reason}) async {
    if (_disposed) return;
    AppLogger.log(
      logTag,
      'event=skip-current reason=$reason '
      'sentenceIndex=${_state.sentenceIndex} flowToken=${_state.flowToken}',
    );
    await _advanceToNextSentence();
  }

  Future<void> _jumpToSentence(int index) async {
    if (_disposed) return;
    _waitAfterCurrentPrompt = false;
    _stopActiveResources();
    final sentence = _sentences[index];
    _updateState(
      _state.copyWith(
        phase: const BlindIdle(),
        sentenceIndex: index,
        repeatIndex: 0,
        totalRepeats: _config.getRepeatCount(sentence),
        flowToken: _state.flowToken + 1,
      ),
    );
    await _playCurrentSentence();
  }

  void _stopActiveResources() {
    if (!_disposed) {
      callbacks.pauseAudio();
    }
    _countdown.cancel();
  }

  void _updateState(BlindPracticeFlowState newState) {
    if (_disposed) return;
    _state = newState;
    onStateChanged(newState);
  }
}

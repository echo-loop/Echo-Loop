/// 跟读会话控制器
///
/// 组合 [RepeatFlowEngine] 驱动跟读流程，添加跟读页面专属逻辑：
/// - 初始化（读书签/断点/设置）
/// - 学习计时（StudyTaskControllerMixin）
/// - 书签管理、断点保存、进度统计
///
/// Screen 只读 state、只调公开方法，不直接操作资源服务。
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../analytics/analytics_providers.dart';
import '../../analytics/audio_event_params.dart';
import '../../analytics/models/event_names.dart';
import '../../database/providers.dart';
import '../../models/intensive_listen_settings.dart';
import '../../models/sentence.dart';
import '../../models/study_stage.dart';
import '../../services/app_logger.dart';
import '../audio_engine/audio_engine_provider.dart';
import '../learning_progress_provider.dart';
import '../learning_session/sentence_playback_engine.dart';
import '../repeat_flow/repeat_flow_engine.dart';
import '../repeat_flow/repeat_flow_phase.dart';
import '../speech/speech_recording_controller.dart';
import '../listening_practice/bookmark_manager.dart';
import '../study_task_controller_mixin.dart';
import 'listen_and_repeat_session_state.dart';
import 'listen_and_repeat_settings_provider.dart';

part 'listen_and_repeat_controller.g.dart';

/// 跟读会话控制器
@Riverpod(keepAlive: true)
class ListenAndRepeatController extends _$ListenAndRepeatController
    with StudyTaskControllerMixin {
  /// 跟读流程引擎
  late final RepeatFlowEngine _engine;

  /// 是否为自由练习模式
  bool _isFreePlay = false;

  /// 当前会话句子列表（包含页面级业务字段，如 bookmark 状态）
  List<Sentence> _sentences = [];

  @override
  ListenAndRepeatSessionState build() {
    // 创建引擎
    _engine = RepeatFlowEngine(
      onStateChanged: _onEngineStateChanged,
      callbacks: RepeatFlowCallbacks(
        pauseAudio: () => ref.read(audioEngineProvider.notifier).pause(),
        playSentence: _playSentence,
        startRecording: _startRecording,
        cancelRecording: _cancelRecording,
        stopAndEvaluate: _stopAndEvaluate,
        clearRecording: _clearRecording,
        setMaxRecordingDuration: _setMaxRecordingDuration,
        hasDetectedSpeech: _hasDetectedSpeech,
      ),
      logTag: 'L&R',
    );

    // 监听录音控制器状态变化 → 桥接到 engine
    ref.listen(speechRecordingControllerProvider, _onRecordingStateChanged);

    // 打印状态变化日志
    ref.listenSelf((prev, next) {
      if (prev?.phase.runtimeType != next.phase.runtimeType ||
          prev?.sentenceIndex != next.sentenceIndex ||
          prev?.repeatIndex != next.repeatIndex) {
        final recPhase = ref.read(speechRecordingControllerProvider).phase;
        AppLogger.log(
          'L&R State',
          '${next.phase.runtimeType} | '
              '句${next.sentenceIndex + 1}/${next.totalSentences} '
              '遍${next.repeatIndex + 1}/${next.totalRepeats} | '
              '录音=$recPhase | '
              'token=${next.flowToken}',
        );
      }
    });

    ref.onDispose(() => _engine.dispose());
    return const ListenAndRepeatSessionState();
  }

  // ========== 初始化 ==========

  /// 初始化跟读任务（从 DB 读数据 + 启动学习计时 + 准备会话）
  ///
  /// [playbackSpeed] 入口 briefing 中用户选择的初始播放速度，默认 1.0x。
  /// [pauseMultiplier] 入口 briefing 中选择的句间停顿；-1.0 = 自动（smart 模式），
  ///   其余正数走 multiplier 模式。
  Future<void> initialize({
    required String audioItemId,
    required List<Sentence> allSentences,
    required bool isFreePlay,
    double playbackSpeed = 1.0,
    double pauseMultiplier = -1.0,
  }) async {
    _isFreePlay = isFreePlay;

    // 从 DB 读难句索引
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarkedIndices = await bookmarkDao.getBookmarkedIndices(
      audioItemId,
    );
    final difficultSentences = allSentences
        .where((s) => bookmarkedIndices.contains(s.index))
        .toList();

    // 从 DB 读断点
    final progress = await ref
        .read(learningProgressNotifierProvider.notifier)
        .getLatestOrEnsureProgress(audioItemId);
    int startIndex = 0;
    if (isFreePlay) {
      startIndex = progress.freePlayShadowingSentenceIndex ?? 0;
    } else {
      startIndex = progress.shadowingSentenceIndex ?? 0;
    }

    // 根据难度计算目标遍数
    final targetPlayCount = targetPlayCountForDifficulty(
      progress.difficulty.value,
    );

    // 初始化设置（含入口选择的播放速度 + 句间停顿）
    ref
        .read(listenAndRepeatSettingsProvider.notifier)
        .initialize(
          repeatCount: targetPlayCount,
          playbackSpeed: playbackSpeed,
          pauseMultiplier: pauseMultiplier,
        );

    // 学习任务通用初始化（计时、LP、音频、analytics、recorder 注入）
    await initStudyTask(
      ref,
      audioItemId: audioItemId,
      stage: StudyStage.listenAndRepeat,
      isFreePlay: isFreePlay,
    );

    // 构造 config 并准备会话
    final config = RepeatFlowConfig(
      audioItemId: audioItemId,
      promptIdPrefix: 'lar',
      getRepeatCount: (_) =>
          ref.read(listenAndRepeatSettingsProvider).repeatCount,
      getIntervalDuration: (s) {
        final st = ref.read(listenAndRepeatSettingsProvider);
        return switch (st.pauseMode) {
          PauseMode.smart => Duration(
            milliseconds: (1000 + (s.duration.inMilliseconds * 0.6).round())
                .clamp(kSmartPauseMinMs, kSmartPauseMaxMs),
          ),
          PauseMode.fixed => Duration(seconds: st.fixedPauseSeconds),
          PauseMode.multiplier => Duration(
            milliseconds: math.max(
              (s.duration.inMilliseconds * st.pauseMultiplier).round(),
              kMultiplierPauseMinMs,
            ),
          ),
        };
      },
      isManualMode: () =>
          ref.read(listenAndRepeatSettingsProvider).isManualMode,
    );

    await prepareSession(
      sentences: difficultSentences,
      config: config,
      startIndex: startIndex,
      isFreePlay: isFreePlay,
    );
    ref.read(analyticsServiceProvider).track(Events.listenRepeatStart, {
      ...ref.audioEventParams(audioItemId),
      EventParams.totalSentences: difficultSentences.length,
    });
  }

  // ========== 公开方法（Screen 调用） ==========

  /// 准备会话数据
  Future<void> prepareSession({
    required List<Sentence> sentences,
    required RepeatFlowConfig config,
    int startIndex = 0,
    bool isFreePlay = false,
  }) async {
    _isFreePlay = isFreePlay;
    _sentences = sentences.map((s) => s.copyWith()).toList();
    _engine.prepare(
      sentences: _sentences,
      config: config,
      startIndex: startIndex,
    );

    // 同步录音控制器模式
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(config.isManualMode());
  }

  /// 开始播放
  Future<void> startPlaying() async => _engine.startPlaying();

  /// 进入等待用户操作状态
  void enterWaitingForUser() => _engine.enterWaitingForUser();

  /// 当前原句播完后进入等待用户操作状态。
  void enterWaitingForUserAfterCurrentPrompt() =>
      _engine.enterWaitingForUser(afterCurrentPrompt: true);

  /// 用户交互（查词/翻译等）
  void onUserInteraction() => _engine.onUserInteraction();

  /// 下一句
  Future<void> nextSentence() async => _engine.nextSentence();

  /// 上一句
  Future<void> previousSentence() async => _engine.previousSentence();

  /// 录音按钮点击
  Future<void> onRecordButtonTapped() async => _engine.onRecordButtonTapped();

  /// 录音回放按钮点击
  Future<void> togglePlayback() async => _engine.togglePlayback();

  /// 为播放录音回放做准备。
  void prepareForPlayback() => _engine.prepareForPlayback();

  /// 手动开始录音
  void startManualRecording() => _engine.startManualRecording();

  /// 手动停止录音
  Future<void> stopRecording() async => _engine.stopRecording();

  /// 播放录音回放
  Future<void> playRecording() async => _engine.playRecording();

  /// 停止录音回放
  Future<void> stopPlayback() async => _engine.stopPlayback();

  /// 快进倒计时
  void fastForwardInterval() => _engine.fastForwardInterval();

  /// 暂停倒计时
  void pauseInterval() => _engine.pauseInterval();

  /// 恢复倒计时
  void resumeInterval() => _engine.resumeInterval();

  /// 重播当前句子
  Future<void> replayCurrentSentence() async => _engine.replayCurrentSentence();

  /// 停止会话
  void stopSession() => _engine.stopSession();

  /// 释放资源
  void disposeSession() {
    _engine.stopSession();
    ref.read(speechRecordingControllerProvider.notifier).fullReset();
  }

  /// 应用会话内设置变更，并立即按新配置重建当前句流程。
  ///
  /// 设置面板是即时写回 Provider 的，因此这里不能等弹窗关闭后再处理。
  Future<void> applySettingsChange() async {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setManualMode(_engine.config.isManualMode());
    if (_engine.willEnterWaitingAfterCurrentPrompt) {
      return;
    }
    // 等待态只刷新当前句配置，不应立刻自动重播。
    await _engine.restartCurrentSentence(
      autoplay: state.phase is! WaitingForUser,
    );
  }

  /// 暂停学习计时（完成弹窗显示时调用）
  // ignore: use super method directly
  void pauseTimer() => pauseStudyTimer();

  // ========== 书签 & 进度 ==========

  /// 切换当前句子的收藏标记
  Future<void> toggleCurrentBookmark() async {
    if (_sentences.isEmpty) return;
    final idx = state.sentenceIndex;
    final s = _sentences[idx];
    final wasBookmarked = s.isBookmarked;
    _sentences[idx] = s.copyWith(isBookmarked: !wasBookmarked);
    state = state.copyWith(currentSentenceBookmarked: !wasBookmarked);

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (wasBookmarked) {
      await bookmarkDao.removeBookmark(_engine.config.audioItemId, s.index);
    } else {
      await BookmarkManager.addBookmarkToDb(
        _engine.config.audioItemId,
        s,
        dao: bookmarkDao,
      );
    }
  }

  /// 保存断点
  Future<void> saveBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _engine.config.audioItemId,
          state.sentenceIndex,
          isFreePlay: isFreePlay,
        );
  }

  /// 清除断点
  Future<void> clearBreakpoint({required bool isFreePlay}) async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(
          _engine.config.audioItemId,
          null,
          isFreePlay: isFreePlay,
        );
  }

  /// 递增遍数统计
  Future<void> incrementPassCount() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementShadowingPassCount(_engine.config.audioItemId);
  }

  /// 标记当前子步骤完成
  Future<void> completeSubStage() async {
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .completeCurrentSubStage(_engine.config.audioItemId);
  }

  /// 退出学习模式
  Future<void> exitLearningMode() async {
    ref.read(analyticsServiceProvider).track(Events.listenRepeatComplete, {
      ...ref.audioEventParams(_engine.config.audioItemId),
      EventParams.totalSentences: _sentences.length,
    });
    disposeSession();
    await disposeStudyTask(ref);
  }

  // ========== 数据访问 ==========

  /// 当前句子
  Sentence? get currentSentence =>
      _sentences.isNotEmpty && state.sentenceIndex < _sentences.length
      ? _sentences[state.sentenceIndex]
      : null;

  /// 当前 promptId
  String get currentPromptId => _engine.currentPromptId;

  /// 当前配置
  RepeatFlowConfig get config => _engine.config;

  /// 当前句子索引
  int get currentIndex => state.sentenceIndex;

  /// 句子列表
  List<Sentence> get sentences => List.unmodifiable(_sentences);

  // ========== Engine 回调实现 ==========

  /// Engine 状态变化 → 更新 Riverpod state
  void _onEngineStateChanged(RepeatFlowState flowState) {
    final isBookmarked =
        _sentences.isNotEmpty && flowState.sentenceIndex < _sentences.length
        ? _sentences[flowState.sentenceIndex].isBookmarked
        : false;
    state = ListenAndRepeatSessionState.fromFlowState(
      flowState,
      isFreePlay: _isFreePlay,
      currentSentenceBookmarked: isBookmarked,
    );
  }

  /// 播放句子
  Future<void> _playSentence(Sentence sentence, int flowToken) async {
    final engine = ref.read(audioEngineProvider.notifier);
    final sessionId = engine.newSession();
    await engine.setSpeed(
      ref.read(listenAndRepeatSettingsProvider).playbackSpeed,
    );
    await engine.playClipOnce(sentence, sessionId);
  }

  /// 开始录音
  void _startRecording({
    required String promptId,
    required String referenceText,
    required Duration maxDuration,
    Duration? referenceDuration,
  }) {
    final controller = ref.read(speechRecordingControllerProvider.notifier);
    controller.setMaxRecordingDuration(maxDuration);
    unawaited(
      controller.startRecording(
        promptId: promptId,
        referenceText: referenceText,
        referenceDuration: referenceDuration,
      ),
    );
  }

  /// 取消录音
  Future<void> _cancelRecording() async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .cancelActiveRecording();
  }

  /// 停止录音并评估
  Future<void> _stopAndEvaluate({required String referenceText}) async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .stopAndEvaluate(referenceText: referenceText);
  }

  /// 清除录音数据
  void _clearRecording() {
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
  }

  /// 设置录音最大时长
  void _setMaxRecordingDuration(Duration duration) {
    ref
        .read(speechRecordingControllerProvider.notifier)
        .setMaxRecordingDuration(duration);
  }

  /// 是否检测到语音
  bool _hasDetectedSpeech() {
    return ref.read(speechRecordingControllerProvider).hasDetectedSpeech;
  }

  /// 录音状态变化 → 桥接到 engine
  void _onRecordingStateChanged(
    SpeechRecordingState? prev,
    SpeechRecordingState next,
  ) {
    if (prev == null) return;

    if (prev.phase != next.phase) {
      AppLogger.log(
        'L&R Rec',
        '${prev.phase.name} → ${next.phase.name} | '
            'attempt=${next.currentAttempt != null} | '
            'score=${next.currentAttempt?.score}',
      );
    }

    // 评估完成 → 通知 engine（有 ASR: processing→idle，无 ASR: speaking→idle）
    if (prev.phase != SpeechRecordingPhase.idle &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt != null) {
      final attempt = next.currentAttempt!;
      _engine.onRecordingFinished(attempt.filePath, attempt.score);
      ref.read(analyticsServiceProvider).track(Events.recordingComplete, {
        ...ref.audioEventParams(_engine.config.audioItemId),
        EventParams.mode: 'listen_repeat',
        if (attempt.score != null) EventParams.score: attempt.score!,
      });
    }

    // 录音取消/超时 → 通知 engine
    if (state.phase is Recording &&
        next.phase == SpeechRecordingPhase.idle &&
        next.currentAttempt == null) {
      _engine.onRecordingCancelled();
    }
  }
}

/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 流程控制通过 [ListenAndRepeatController] 驱动（统一管理播放、录音、倒计时）。
/// 录音 UI 状态通过 [SpeechRecordingController] 读取（转录文本、评估结果）。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/speech_permission_dialog.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../models/intensive_listen_settings.dart';
import '../utils/wakelock_mixin.dart';
import '../utils/playback_speed.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/speech/speech_recording_controller.dart';
import '../providers/audio_engine/audio_engine_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_controller.dart';
import '../providers/listen_and_repeat/listen_and_repeat_phase.dart';
import '../providers/listen_and_repeat/listen_and_repeat_settings_provider.dart';
import '../providers/listen_and_repeat/listen_and_repeat_session_state.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/common/recording_button.dart' show RecordingButtonMode;
import '../widgets/common/repeat_practice_panel.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_play_count_label.dart';

/// 跟读播放器页面
class ListenAndRepeatPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const ListenAndRepeatPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<ListenAndRepeatPlayerScreen> createState() =>
      _ListenAndRepeatPlayerScreenState();
}

class _ListenAndRepeatPlayerScreenState
    extends ConsumerState<ListenAndRepeatPlayerScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 词典面板宿主（返回/退出时先关面板的 guard 用）
  final GlobalKey<DictionaryPanelHostState> _dictPanelHostKey =
      GlobalKey<DictionaryPanelHostState>();

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  ProviderSubscription<ListenAndRepeatSessionState>? _controllerSubscription;
  ProviderSubscription<IntensiveListenSettings>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await ensureSpeechReadyForSubStage(
        context,
        ref,
        SubStageType.listenAndRepeat,
      );
      if (!mounted) return;
      if (!ok) {
        if (context.canPop()) context.pop();
        return;
      }
      ref.read(listenAndRepeatControllerProvider.notifier).startPlaying();
    });
    _controllerSubscription = ref.listenManual<ListenAndRepeatSessionState>(
      listenAndRepeatControllerProvider,
      _handleControllerStateChanged,
    );
    _settingsSubscription = ref.listenManual<IntensiveListenSettings>(
      listenAndRepeatSettingsProvider,
      _handleSettingsChanged,
    );
  }

  @override
  void dispose() {
    _settingsSubscription?.close();
    _controllerSubscription?.close();
    super.dispose();
  }

  void _handleControllerStateChanged(
    ListenAndRepeatSessionState? prev,
    ListenAndRepeatSessionState next,
  ) {
    if (prev != null && !_isExiting) {
      if (next.phase is SessionCompleted && prev.phase is! SessionCompleted) {
        ref.read(listenAndRepeatControllerProvider.notifier).pauseStudyTimer();
        shortenIdleTimeout(5);
        unawaited(_handleCompleted());
      }
    }
  }

  void _handleSettingsChanged(
    IntensiveListenSettings? prev,
    IntensiveListenSettings next,
  ) {
    if (prev == null || _isExiting) return;
    // 速度变化无需重启当前句：直接把新速度推给 AudioEngine 即可。
    // 其它字段变化仍走 applySettingsChange（会重建当前句配置）。
    // IntensiveListenSettings 无 == 重载，逐字段比对（除 speed 外全相等即"仅速度变了"）。
    final speedOnly =
        next.playbackSpeed != prev.playbackSpeed &&
        next.repeatCount == prev.repeatCount &&
        next.pauseMode == prev.pauseMode &&
        next.fixedPauseSeconds == prev.fixedPauseSeconds &&
        next.pauseMultiplier == prev.pauseMultiplier &&
        next.controlMode == prev.controlMode;
    if (speedOnly) {
      unawaited(
        ref.read(audioEngineProvider.notifier).setSpeed(next.playbackSpeed),
      );
      return;
    }
    unawaited(
      ref
          .read(listenAndRepeatControllerProvider.notifier)
          .applySettingsChange(),
    );
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    // 词典面板开着时本次返回只关面板，不退出页面
    if (_dictPanelHostKey.currentState?.closeIfOpen() ?? false) return;
    _isExiting = true;
    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);
    ctrl.enterWaitingForUser();
    if (!mounted) return;

    final ctrlState = ref.read(listenAndRepeatControllerProvider);
    if (ctrlState.isFreePlay) {
      await ctrl.saveBreakpoint(isFreePlay: true);
      await ctrl.exitLearningMode();
      if (mounted) context.pop();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitListenAndRepeatTitle),
        content: Text(l10n.exitListenAndRepeatMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmExit),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      _isExiting = false;
      return;
    }

    await ctrl.saveBreakpoint(isFreePlay: false);
    await ctrl.exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息
  ({
    int stepIndex,
    int totalSteps,
    String stageName,
    String? nextStepName,
    bool isLastStep,
  })
  _getStepContext() {
    final l10n = AppLocalizations.of(context)!;
    final plan = ref.read(learningPlanForAudioProvider(widget.audioItemId));
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    final stage = progress?.currentStage ?? LearningStage.firstLearn;
    final currentSub =
        progress?.currentSubStage ?? SubStageType.listenAndRepeat;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(currentSub);
    final isLast = currentIdx < 0 || currentIdx >= planned.length - 1;

    final next = plan.nextPlannedAfter(stage, currentSub);
    final nextStepName = (next != null && _hasPlayerScreen(next.subStage))
        ? _getSubStageName(next.subStage, l10n)
        : null;

    return (
      stepIndex: currentIdx >= 0 ? currentIdx : planned.length,
      totalSteps: planned.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理播放完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);
    final ctrlState = ref.read(listenAndRepeatControllerProvider);

    if (!mounted) return;

    // 递增遍数统计
    await ctrl.incrementPassCount();

    if (!mounted) return;

    // 自由练习模式
    if (ctrlState.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      await handleFreePlayComplete(
        context: context,
        title: l10n.listenAndRepeatCompleteTitle,
        stats: [
          (
            value: '${ctrlState.totalSentences}',
            label: l10n.statDifficultSentences,
          ),
        ],
        onStudyAgain: () async {
          // 重新开始（从第一句，复用当前 config）
          await ctrl.prepareSession(
            sentences: ctrl.sentences,
            config: ctrl.config,
            startIndex: 0,
            isFreePlay: true,
          );
          await ctrl.startPlaying();
        },
        onExit: () async {
          await ref
              .read(learningSessionProvider.notifier)
              .recordCatchUpCompletionIfAny(widget.audioItemId);
          await ctrl.clearBreakpoint(isFreePlay: true);
          await ctrl.exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    // 正式学习模式
    final stepCtx = _getStepContext();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.listenAndRepeatCompleteTitle,
      stats: [
        (
          value: '${ctrlState.totalSentences}',
          label: l10n.statDifficultSentences,
        ),
      ],
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
    );

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 清除断点 + 标记完成
    await ctrl.clearBreakpoint(isFreePlay: false);
    await ctrl.completeSubStage();
    await ctrl.exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      await _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
    }
  }

  /// 返回学习计划页并自动启动下一个任务
  ///
  /// 先 go 回学习 Tab 清空导航栈，再 push 新的学习计划页（autoStart=true），
  /// 效果等同于用户在学习列表点击"继续学习"。
  Future<void> _navigateBackToPlanAndAutoStart() async {
    if (!mounted) return;
    final nextSubStage = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId]
        ?.currentSubStage;
    final canAutoStart = nextSubStage == null
        ? true
        : await ensureSpeechReadyForSubStage(context, ref, nextSubStage);
    if (!mounted) return;

    final route = widget.collectionId != null
        ? AppRoutes.learningPlan(
            widget.collectionId!,
            widget.audioItemId,
            autoStart: canAutoStart,
          )
        : AppRoutes.audioLearningPlan(
            widget.audioItemId,
            autoStart: canAutoStart,
          );
    GoRouter.of(context).go(AppRoutes.study);
    GoRouter.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 监听 ListenAndRepeatController 状态变化（避免倒计时 tick 重建整个页面）
    ref.watch(
      listenAndRepeatControllerProvider.select(
        (s) => (
          s.sentenceIndex,
          s.totalSentences,
          s.repeatIndex,
          s.totalRepeats,
          s.phase.runtimeType,
          s.isCountingDown && s.phase is WaitingInterval
              ? (s.phase as WaitingInterval).isPaused
              : false,
          s.recordingScore,
          s.currentSentenceBookmarked,
        ),
      ),
    );
    final isManualMode = ref.watch(
      listenAndRepeatSettingsProvider.select((s) => s.isManualMode),
    );
    final ctrlState = ref.read(listenAndRepeatControllerProvider);
    final ctrl = ref.read(listenAndRepeatControllerProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      speechRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(speechRecordingControllerProvider);

    final currentSentence = ctrl.currentSentence;
    final currentPromptId = ctrl.currentPromptId;
    final currentAttempt = turnState.currentAttempt;
    final isPlaying = ctrlState.phase is PlayingPrompt;
    final isInPause = ctrlState.isInPause;
    final showCountdown = ctrlState.isCountingDown;
    final isRecording = turnState.isRecordingPrompt(currentPromptId);
    final recordingMode = isRecording
        ? RecordingButtonMode.recording
        : RecordingButtonMode.idle;
    final isProcessing =
        turnState.promptId == currentPromptId &&
        turnState.phase == SpeechRecordingPhase.processing;

    // 句子时长（如 "2.8秒"）
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;

    return wakelockBody(
      child: LearningHotkeyScope(
        onPlayPause: () {
          AppLogger.log(
            'L&R Screen',
            '播放按钮: phase=${ctrlState.phase.runtimeType}',
          );

          if (isInPause) {
            ref
                .read(speechRecordingControllerProvider.notifier)
                .clearRecording();
            ctrl.replayCurrentSentence();
          } else if (isPlaying) {
            ctrl.enterWaitingForUserAfterCurrentPrompt();
          } else {
            ctrl.replayCurrentSentence();
          }
        },
        onPrevious: () {
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          unawaited(ctrl.previousSentence());
        },
        onNext: () {
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          unawaited(ctrl.nextSentence());
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleExit();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.listenAndRepeatAppBarTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    ref
                        .read(listenAndRepeatControllerProvider.notifier)
                        .enterWaitingForUserAfterCurrentPrompt();
                    showListenAndRepeatSettingsSheet(context: context);
                  },
                ),
              ],
            ),
            // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）
            body: DictionaryPanelHost(
              key: _dictPanelHostKey,
              child: Column(
                children: [
                  // 进度条
                  PracticeProgressSection(
                    current: ctrlState.sentenceIndex + 1,
                    total: ctrlState.totalSentences,
                    progressText: l10n.listenAndRepeatProgress(
                      ctrlState.sentenceIndex + 1,
                      ctrlState.totalSentences,
                    ),
                    durationText: durationText,
                    showAudioSource: false,
                    onSeek: (i) => ref
                        .read(listenAndRepeatControllerProvider.notifier)
                        .goToSentence(i),
                  ),

                  // 主体内容：书签行 + 标注内容
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                      ),
                      child: currentSentence != null
                          ? Column(
                              children: [
                                const SizedBox(height: AppSpacing.s),
                                BookmarkToggleRow(
                                  isDifficult:
                                      ctrlState.currentSentenceBookmarked,
                                  onTap: () => ref
                                      .read(
                                        listenAndRepeatControllerProvider
                                            .notifier,
                                      )
                                      .toggleCurrentBookmark(),
                                ),
                                const SizedBox(height: AppSpacing.m),
                                Expanded(
                                  child: AnnotationContentView(
                                    text: currentSentence.text,
                                    aiNotifier: ref.read(
                                      sentenceAiNotifierProvider,
                                    ),
                                    audioItemId: widget.audioItemId,
                                    sentenceIndex: ctrlState.sentenceIndex,
                                    sentenceStartMs: currentSentence
                                        .startTime
                                        .inMilliseconds,
                                    sentenceEndMs:
                                        currentSentence.endTime.inMilliseconds,
                                    highlightedSegments:
                                        currentAttempt?.referenceSegments,
                                    onStopMainPlayer: () {
                                      ctrl.enterWaitingForUser();
                                    },
                                    onToolbarButtonTapped: () {
                                      AppLogger.log(
                                        'L&R Screen',
                                        '工具栏点击: 打断流程',
                                      );
                                      ctrl.onUserInteraction();
                                    },
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // 底部区域：评分 + 录音/倒计时 + 播放控制 + 遍数
                  RepeatPracticePanel(
                    l10n: l10n,
                    theme: theme,
                    recordingMode: recordingMode,
                    isProcessing: isProcessing,
                    currentAttempt: currentAttempt,
                    hintText: isPlaying ? l10n.listenAndRepeatListenHint : null,
                    showCountdown: showCountdown,
                    isInPause: isInPause,
                    countdownWidget: showCountdown
                        ? Center(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final phase = ref.watch(
                                  listenAndRepeatControllerProvider.select(
                                    (s) => s.phase,
                                  ),
                                );
                                if (phase is! WaitingInterval) {
                                  return const SizedBox.shrink();
                                }
                                return CountdownChip(
                                  total: phase.total,
                                  isPaused: phase.isPaused,
                                  isFastForward: phase.speed > 1.0,
                                  onPause: ctrl.pauseInterval,
                                  onResume: ctrl.resumeInterval,
                                );
                              },
                            ),
                          )
                        : null,
                    onRecordTap: () => ctrl.onRecordButtonTapped(),
                    showRatingBadge: ref.watch(
                      learningSettingsProvider.select(
                        (s) => s.listenAndRepeatRatingEnabled,
                      ),
                    ),
                    onFastForward:
                        showCountdown &&
                            ctrlState.phase is WaitingInterval &&
                            !(ctrlState.phase as WaitingInterval).isPaused
                        ? ctrl.fastForwardInterval
                        : null,
                    onBeforePlayback: () => ref
                        .read(listenAndRepeatControllerProvider.notifier)
                        .prepareForPlayback(),
                  ),
                  PracticePlaybackFooter(
                    canGoPrev: !ctrlState.isFirstSentence,
                    isLast: ctrlState.isLastSentence,
                    centerIcon: isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPrevious: () {
                      ref
                          .read(speechRecordingControllerProvider.notifier)
                          .clearRecording();
                      unawaited(ctrl.previousSentence());
                    },
                    onNext: () {
                      ref
                          .read(speechRecordingControllerProvider.notifier)
                          .clearRecording();
                      if (ctrlState.isLastSentence) {
                        ctrl.stopSession();
                        _handleCompleted();
                      } else {
                        unawaited(ctrl.nextSentence());
                      }
                    },
                    onCenter: () {
                      if (isInPause) {
                        ref
                            .read(speechRecordingControllerProvider.notifier)
                            .clearRecording();
                        ctrl.replayCurrentSentence();
                      } else if (isPlaying) {
                        ctrl.enterWaitingForUser();
                      } else {
                        ctrl.replayCurrentSentence();
                      }
                    },
                    isManualMode: isManualMode,
                    playCountText: formatPracticePlayCount(
                      l10n,
                      currentCount: ctrlState.repeatIndex + 1,
                      totalCount: ctrlState.totalRepeats,
                    ),
                    statusSuffixText: _formatSpeed(
                      ref.watch(listenAndRepeatSettingsProvider).playbackSpeed,
                    ),
                    l10n: l10n,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

/// 判断子步骤是否有专用播放器页面
bool _hasPlayerScreen(SubStageType type) => switch (type) {
  SubStageType.blindListen => true,
  SubStageType.intensiveListen => true,
  SubStageType.listenAndRepeat => true,
  SubStageType.retell => true,
  SubStageType.reviewDifficultPractice => true,
  SubStageType.reviewRetellParagraph => true,
  SubStageType.reviewRetellSummary => true,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.stepRetelling,
      SubStageType.reviewRetellSummary => l10n.stepRetelling,
    };

/// 复习难句补练页面
///
/// 仅加载已标记为难句的句子，逐句执行：
/// 1. 盲听一遍（不显示字幕）
/// 2. 句间停顿 → 自动推进下一句
/// 3. 用户可随时「偷看」字幕或按「听不懂」进入跟读模式
/// 4. 跟读模式：播放句子（显示字幕）→ 自动录音 → 评分 → 倒计时 → 下一遍
///
/// 录音通过 [SpeechRecordingController] 驱动（跟读专用控制器）。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
///
/// 交互与逐句精听页面（IntensiveListenPlayerScreen）一致。
/// R1+ 可取消难句标记（听懂的句子 unbookmark）。
/// 完成后弹完成对话框，支持"继续下一步"或"返回计划"。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../widgets/speech_permission_dialog.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../utils/playback_speed.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_settings_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/speech/speech_recording_controller.dart';
import '../utils/wakelock_mixin.dart';
import '../providers/sentence_ai_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/practice/selectable_sentence_text.dart';
import '../widgets/player_hotkey_scope.dart';
import '../models/speech_practice_models.dart';
import '../providers/repeat_flow/repeat_flow_phase.dart';
import '../providers/repeat_flow/repeat_flow_state.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/recording_button.dart' show RecordingButtonMode;
import '../widgets/common/repeat_practice_panel.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_play_count_label.dart';

/// 复习难句补练页面
class ReviewDifficultPracticeScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const ReviewDifficultPracticeScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<ReviewDifficultPracticeScreen> createState() =>
      _ReviewDifficultPracticeScreenState();
}

class _ReviewDifficultPracticeScreenState
    extends ConsumerState<ReviewDifficultPracticeScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 词典面板宿主（返回/退出时先关面板的 guard 用）
  final GlobalKey<DictionaryPanelHostState> _dictPanelHostKey =
      GlobalKey<DictionaryPanelHostState>();

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  ProviderSubscription<ReviewDifficultPracticeState>? _playerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await ensureSpeechReadyForSubStage(
        context,
        ref,
        SubStageType.reviewDifficultPractice,
      );
      if (!mounted) return;
      if (!ok) {
        if (context.canPop()) context.pop();
        return;
      }
      ref.read(reviewDifficultPracticeProvider.notifier).syncRecordingMode();
      ref.read(reviewDifficultPracticeProvider.notifier).startPlaying();
    });
    _playerSubscription = ref.listenManual<ReviewDifficultPracticeState>(
      reviewDifficultPracticeProvider,
      _handlePlayerStateChanged,
    );
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    super.dispose();
  }

  /// 取消录音
  Future<void> _cancelRecordingAndPlayback() async {
    await ref
        .read(speechRecordingControllerProvider.notifier)
        .cancelActiveRecording();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    // 词典面板开着时本次返回只关面板，不退出页面
    if (_dictPanelHostKey.currentState?.closeIfOpen() ?? false) return;
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    final l10n = AppLocalizations.of(context)!;

    // 自由练习模式直接退出
    if (session.isFreePlay) {
      await _exit();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitReviewDifficultPracticeTitle),
        content: Text(l10n.exitReviewDifficultPracticeConfirmMessage),
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

    await _exit();
  }

  /// 执行退出（保存断点、释放录音后退出）
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(speechRecordingControllerProvider.notifier).fullReset();

    // 保存当前句子索引作为断点
    final session = ref.read(learningSessionProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultPracticeSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
          isFreePlay: session.isFreePlay,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 切换当前句子的难句标记
  Future<void> _handleToggleDifficult() async {
    await ref
        .read(reviewDifficultPracticeProvider.notifier)
        .toggleCurrentBookmark(widget.audioItemId);
  }

  void _handlePlayerStateChanged(
    ReviewDifficultPracticeState? prev,
    ReviewDifficultPracticeState next,
  ) {
    if (prev != null &&
        prev.currentSentenceIndex != next.currentSentenceIndex) {
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    }

    if (prev != null && !_isExiting) {
      if (!prev.stepFinished && next.stepFinished) {
        ref.read(learningSessionProvider.notifier).pauseStudyTimer();
        shortenIdleTimeout(5);
        unawaited(_handleCompleted());
      }
    }

    if (prev?.isManualMode != next.isManualMode) {
      ref.read(reviewDifficultPracticeProvider.notifier).syncRecordingMode();
    }

    if (next.isPauseBetweenPlays &&
        next.isManualMode &&
        !next.isCountdownPaused) {
      ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
    }
  }

  /// 获取当前步骤上下文
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

    if (progress == null) {
      return (
        stepIndex: 0,
        totalSteps: 1,
        stageName: '',
        nextStepName: null,
        isLastStep: true,
      );
    }

    final stage = progress.currentStage;
    final currentSub = progress.currentSubStage;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(currentSub);
    final isLast = currentIdx < 0 || currentIdx >= planned.length - 1;

    // 用 plan 找下一步：plan 末尾或不在 plan → null（弹窗只显示「完成」按钮，
    // 修复 bug 1：关闭复述时 review0 难句补练完成后不再显示「继续：段落复述」）
    final next = plan.nextPlannedAfter(stage, currentSub);
    final nextStepName = next == null
        ? null
        : _getSubStageName(next.subStage, l10n);

    return (
      stepIndex: currentIdx >= 0 ? currentIdx : planned.length,
      totalSteps: planned.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放录音
    await ref.read(speechRecordingControllerProvider.notifier).fullReset();

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：弹窗询问"完成"或"再练一遍"
    if (session.isFreePlay) {
      if (!mounted) return;
      final playerState = ref.read(reviewDifficultPracticeProvider);
      final l10n = AppLocalizations.of(context)!;

      // 弹窗前清除断点
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: true,
          );

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.reviewDifficultPracticeCompleteTitle,
        stats: [
          (
            value: '${playerState.totalSentences}',
            label: l10n.statDifficultSentences,
          ),
        ],
        onStudyAgain: () async {
          await ref
              .read(reviewDifficultPracticeProvider.notifier)
              .resetToStart();
        },
        onExit: () async {
          _isExiting = true;
          await ref
              .read(learningSessionProvider.notifier)
              .recordCatchUpCompletionIfAny(widget.audioItemId);
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    final playerState = ref.read(reviewDifficultPracticeProvider);
    final stepCtx = _getStepContext();

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.reviewDifficultPracticeCompleteTitle,
      stats: [
        (
          value: '${playerState.totalSentences}',
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

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('难句补练完成处理出错: $e');
    }

    _isExiting = true;
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext &&
        stepCtx.nextStepName != null) {
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

    // select 过滤倒计时 tick（100ms 一次的 remaining 变化），避免整页频繁 rebuild
    // 导致 TapGestureRecognizer 被反复 dispose/重建，点击单词无法触发词典弹窗。
    ref.watch(
      reviewDifficultPracticeProvider.select(
        (s) => (
          s.currentSentenceIndex,
          s.totalSentences,
          s.currentPlayCount,
          s.isPlaying,
          s.isPauseBetweenPlays,
          s.isAnnotationMode,
          s.isTextRevealed,
          s.isCountdownPaused,
          s.stepFinished,
          s.bookmarkVersion,
          s.isManualMode,
          s.settings,
          s.repeatFlowState?.phase.runtimeType,
          // 倒计时暂停状态独立监听，否则点暂停时 phase.runtimeType 不变，
          // 页面不 rebuild，快进按钮等依赖 isPaused 的渲染会停留在旧值。
          s.repeatFlowState?.phase is WaitingInterval
              ? (s.repeatFlowState!.phase as WaitingInterval).isPaused
              : false,
          s.repeatFlowState?.repeatIndex,
          s.repeatFlowState?.isReviewPlaybackActive,
          s.repeatFlowState?.recordingScore,
          s.blindFlowState?.phase.runtimeType,
        ),
      ),
    );
    final playerState = ref.read(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      speechRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(speechRecordingControllerProvider);

    // 跟读模式下录音状态变化由 RepeatFlowEngine 内部处理，无需 Screen 层桥接。
    // 盲听模式下不涉及录音。

    final currentSentence = player.currentSentence;
    final currentAttempt = turnState.currentAttempt;
    // 跟读模式用 engine 的 promptId，盲听模式无录音
    final currentPromptId = playerState.isAnnotationMode
        ? (player.repeatEngine?.currentPromptId ?? '')
        : '';

    // 跟读模式下自动录音由 RepeatFlowEngine 内部驱动，无需 Screen 触发。

    // 句子时长和时间戳
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
          unawaited(_cancelRecordingAndPlayback());
          if (playerState.isPauseBetweenPlays) {
            ref
                .read(speechRecordingControllerProvider.notifier)
                .clearRecording();
            player.replayDuringCountdown();
          } else if (playerState.isPlaying) {
            player.pause();
          } else {
            player.resume();
          }
        },
        onPrevious: () {
          unawaited(_cancelRecordingAndPlayback());
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          player.goToPrevious();
        },
        onNext: () {
          unawaited(_cancelRecordingAndPlayback());
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          player.goToNext();
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleExit();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.reviewDifficultPracticeTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    final player = ref.read(
                      reviewDifficultPracticeProvider.notifier,
                    );
                    if (playerState.isAnnotationMode) {
                      player.repeatEngine?.onUserInteraction();
                    } else {
                      player.enterWaitingForUserInBlindMode();
                    }
                    showDifficultPracticeSettingsSheet(context: context);
                  },
                ),
              ],
            ),
            // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）
            body: DictionaryPanelHost(
              key: _dictPanelHostKey,
              child: Column(
                children: [
                  // 进度区域
                  PracticeProgressSection(
                    current: playerState.currentSentenceIndex + 1,
                    total: playerState.totalSentences,
                    progressText: l10n.reviewDifficultPracticeProgress(
                      playerState.currentSentenceIndex + 1,
                      playerState.totalSentences,
                    ),
                    durationText: durationText,
                    showAudioSource: false,
                    onSeek: (i) => ref
                        .read(reviewDifficultPracticeProvider.notifier)
                        .goToSentence(i),
                  ),

                  // 主体内容：盲听/跟读 双态切换
                  Expanded(
                    child: playerState.isAnnotationMode
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.l,
                            ),
                            child: currentSentence != null
                                ? Column(
                                    children: [
                                      const SizedBox(height: AppSpacing.s),
                                      BookmarkToggleRow(
                                        isDifficult:
                                            currentSentence.isBookmarked,
                                        onTap: _handleToggleDifficult,
                                      ),
                                      const SizedBox(height: AppSpacing.m),
                                      Expanded(
                                        child: AnnotationContentView(
                                          text: currentSentence.text,
                                          aiNotifier: ref.read(
                                            sentenceAiNotifierProvider,
                                          ),
                                          audioItemId: widget.audioItemId,
                                          sentenceIndex: player.currentIndex,
                                          sentenceStartMs: currentSentence
                                              .startTime
                                              .inMilliseconds,
                                          sentenceEndMs: currentSentence
                                              .endTime
                                              .inMilliseconds,
                                          highlightedSegments:
                                              currentAttempt?.referenceSegments,
                                          onStopMainPlayer: () {
                                            player.repeatEngine
                                                ?.enterWaitingForUser();
                                          },
                                          onToolbarButtonTapped: () {
                                            player.repeatEngine
                                                ?.onUserInteraction();
                                          },
                                        ),
                                      ),
                                      _buildAnnotationMiddlePanel(
                                        playerState: playerState,
                                        turnState: turnState,
                                        currentAttempt: currentAttempt,
                                        currentPromptId: currentPromptId,
                                        l10n: l10n,
                                        theme: theme,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          )
                        : PracticeNormalModeView(
                            l10n: l10n,
                            theme: theme,
                            isTextRevealed: playerState.isTextRevealed,
                            countdown: Consumer(
                              builder: (context, ref, _) {
                                final s = ref.watch(
                                  reviewDifficultPracticeProvider.select(
                                    (s) => (
                                      show:
                                          s.isPauseBetweenPlays &&
                                          !s.isManualMode,
                                      total: s.pauseDuration,
                                      paused: s.isCountdownPaused,
                                      fastForward: s.isCountdownFastForward,
                                    ),
                                  ),
                                );
                                if (!s.show) return const SizedBox.shrink();
                                return CountdownChip(
                                  total: s.total,
                                  isPaused: s.paused,
                                  isFastForward: s.fastForward,
                                  onPause: () => player.pauseCountdown(),
                                  onResume: () => player.resumeCountdown(),
                                );
                              },
                            ),
                            onPeekToggle: () {
                              player.enterWaitingForUserInBlindMode();
                              player.setTextRevealed(
                                !playerState.isTextRevealed,
                              );
                            },
                            onCantUnderstand: () =>
                                player.enterAnnotationMode(),
                            onToggleMark: _handleToggleDifficult,
                            isDifficult: currentSentence?.isBookmarked ?? true,
                            sentenceText: currentSentence?.text,
                            lookupOrigin: currentSentence != null
                                ? DictionaryLookupOrigin(
                                    audioItemId: widget.audioItemId,
                                    sentenceIndex: currentSentence.index,
                                    sentenceText: currentSentence.text,
                                    sentenceStartMs: currentSentence
                                        .startTime
                                        .inMilliseconds,
                                    sentenceEndMs:
                                        currentSentence.endTime.inMilliseconds,
                                  )
                                : null,
                            onBeforeLookup: () =>
                                player.enterWaitingForUserInBlindMode(),
                          ),
                  ),

                  PracticePlaybackFooter(
                    canGoPrev: playerState.currentSentenceIndex > 0,
                    isLast:
                        playerState.currentSentenceIndex >=
                        playerState.totalSentences - 1,
                    centerIcon: _buildFooterCenterIcon(playerState),
                    onPrevious: _handlePrevious,
                    onNext: _handleNext,
                    onCenter: _handleCenter,
                    isManualMode: playerState.isManualMode,
                    playCountText: _buildPlayCountText(playerState, l10n),
                    statusSuffixText: _formatSpeed(
                      playerState.settings.playbackSpeed,
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

  /// 跟读模式中间区域（与跟读页面架构一致）
  Widget _buildAnnotationMiddlePanel({
    required ReviewDifficultPracticeState playerState,
    required SpeechRecordingState turnState,
    required SpeechPracticeAttempt? currentAttempt,
    required String currentPromptId,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    final flowState = playerState.repeatFlowState;
    if (flowState == null) return const SizedBox.shrink();
    final engine = ref
        .read(reviewDifficultPracticeProvider.notifier)
        .repeatEngine;
    void noop() {}

    final isPlaying = flowState.phase is PlayingPrompt;
    final isInPause = flowState.isInPause;
    final showCountdown = flowState.isCountingDown;
    final effectivePromptId = engine?.currentPromptId ?? currentPromptId;
    final isRecording = turnState.isRecordingPrompt(effectivePromptId);
    final recordingMode = isRecording
        ? RecordingButtonMode.recording
        : RecordingButtonMode.idle;
    final isProcessing =
        turnState.promptId == effectivePromptId &&
        turnState.phase == SpeechRecordingPhase.processing;

    return RepeatPracticePanel(
      l10n: l10n,
      theme: theme,
      recordingMode: recordingMode,
      isProcessing: isProcessing,
      currentAttempt: currentAttempt,
      hintText: isPlaying ? l10n.listenAndRepeatListenHint : null,
      showRatingBadge: ref.watch(
        learningSettingsProvider.select((s) => s.listenAndRepeatRatingEnabled),
      ),
      showCountdown: showCountdown,
      isInPause: isInPause,
      countdownWidget: showCountdown
          ? Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final phase = ref.watch(
                    reviewDifficultPracticeProvider.select(
                      (s) => s.repeatFlowState?.phase,
                    ),
                  );
                  if (phase is! WaitingInterval) {
                    return const SizedBox.shrink();
                  }
                  return CountdownChip(
                    total: phase.total,
                    isPaused: phase.isPaused,
                    isFastForward: phase.speed > 1.0,
                    onPause: engine?.pauseInterval ?? noop,
                    onResume: engine?.resumeInterval ?? noop,
                  );
                },
              ),
            )
          : null,
      onRecordTap: () {
        if (engine == null) return;
        unawaited(engine.onRecordButtonTapped());
      },
      onFastForward:
          showCountdown &&
              flowState.phase is WaitingInterval &&
              !(flowState.phase as WaitingInterval).isPaused
          ? (engine?.fastForwardInterval ?? noop)
          : null,
      onBeforePlayback: engine != null
          ? () => engine.prepareForPlayback()
          : null,
    );
  }

  IconData _buildFooterCenterIcon(ReviewDifficultPracticeState playerState) {
    final flowState = playerState.repeatFlowState;
    if (playerState.isAnnotationMode && flowState != null) {
      return _isRepeatPromptPlaybackActive(flowState)
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded;
    }
    return _isBlindSentencePlaybackActive(playerState)
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
  }

  bool _isRepeatPromptPlaybackActive(RepeatFlowState flowState) {
    return flowState.phase is PlayingPrompt &&
        !flowState.isWaitingForUser &&
        !flowState.isCountingDown;
  }

  bool _isBlindSentencePlaybackActive(ReviewDifficultPracticeState state) {
    return state.isPlaying &&
        !state.isPauseBetweenPlays &&
        !state.isPauseBetweenSentences &&
        !state.isCountdownPaused;
  }

  String _buildPlayCountText(
    ReviewDifficultPracticeState playerState,
    AppLocalizations l10n,
  ) {
    if (playerState.isAnnotationMode && playerState.repeatFlowState != null) {
      final flowState = playerState.repeatFlowState!;
      return formatPracticePlayCount(
        l10n,
        currentCount: flowState.repeatIndex + 1,
        totalCount: playerState.targetRepeatCount,
      );
    }
    return formatPracticePlayCount(
      l10n,
      currentCount: playerState.currentPlayCount,
      totalCount: playerState.isManualMode
          ? 1
          : playerState.settings.blindListenRepeatCount,
    );
  }

  void _handlePrevious() {
    final playerState = ref.read(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    unawaited(_cancelRecordingAndPlayback());
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    if (playerState.isAnnotationMode) {
      unawaited(player.goToPrevious());
      return;
    }
    unawaited(player.goToPrevious());
  }

  void _handleNext() {
    final playerState = ref.read(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    unawaited(_cancelRecordingAndPlayback());
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    final isLast =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    if (isLast) {
      player.stopPlayback();
      unawaited(_handleCompleted());
      return;
    }
    unawaited(player.goToNext());
  }

  void _handleCenter() {
    final playerState = ref.read(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final engine = player.repeatEngine;
    unawaited(_cancelRecordingAndPlayback());
    if (playerState.isAnnotationMode && engine != null) {
      final flowState = playerState.repeatFlowState;
      if (flowState?.isInPause ?? false) {
        ref.read(speechRecordingControllerProvider.notifier).clearRecording();
        unawaited(engine.replayCurrentSentence());
      } else if (flowState?.phase is PlayingPrompt) {
        engine.enterWaitingForUser();
      } else {
        unawaited(engine.replayCurrentSentence());
      }
      return;
    }
    if (playerState.isPauseBetweenPlays) {
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
      unawaited(player.replayDuringCountdown());
    } else if (playerState.isPlaying) {
      player.pause();
    } else {
      unawaited(player.resume());
    }
  }
}

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

/// 子步骤本地化名称
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

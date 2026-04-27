/// 盲听播放器页面
///
/// 支持两种模式：
/// 1. 段落分段模式（有字幕）：段落信息 + 句子列表 + 上下段导航 + 段间停顿
/// 2. 极简模式（无字幕）：仅播放/暂停按钮 + 进度条
///
/// 段落模式下布局类似复述页面，但无录音、无关键词。
/// 播放完成后根据目标遍数决定行为。
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/blind_listen_settings_sheet.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/paragraph_practice_scaffold.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/player_hotkey_scope.dart';

/// 盲听播放器页面
class BlindListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const BlindListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<BlindListenPlayerScreen> createState() =>
      _BlindListenPlayerScreenState();
}

class _BlindListenPlayerScreenState
    extends ConsumerState<BlindListenPlayerScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;
  ProviderSubscription<BlindListenPlayerState>? _playerSubscription;
  StreamSubscription<Duration>? _silenceSkipSub;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<BlindListenPlayerState>(
      blindListenPlayerProvider,
      (prev, next) {
        if (_isExiting || prev == null) return;
        _logBlindStateTransition(prev, next);
        if (!prev.stepFinished && next.stepFinished) {
          ref.read(learningSessionProvider.notifier).pauseStudyTimer();
          shortenIdleTimeout(5);
          _handleCompleted();
        }
      },
    );
    _silenceSkipSub = ref
        .read(blindListenPlayerProvider.notifier)
        .silenceSkipEventStream
        .listen(_showSilenceSkippedSnackBar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.log('BlindListenScreen', '首帧后启动播放');
      ref.read(blindListenPlayerProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    _silenceSkipSub?.cancel();
    super.dispose();
  }

  /// 弹出"已自动跳过 Xs 静音"提示
  void _showSilenceSkippedSnackBar(Duration gap) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.silenceSkipped(gap.inSeconds)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ========== 完成处理 ==========

  /// 播放完成处理
  void _handleCompleted() {
    if (_isShowingDialog || _isExiting) return;
    _isShowingDialog = true;
    final session = ref.read(learningSessionProvider);

    if (session.isFreePlay) {
      _showFreePlayCompleteDialog();
    } else if (session.hasRemainingPasses) {
      // 未达目标遍数 → 再来一遍
      ref.read(learningSessionProvider.notifier).replayBlindListen();
    } else {
      _showCompleteDialog();
    }
  }

  // ========== 完成逻辑 ==========

  /// 自由练习完成对话框
  Future<void> _showFreePlayCompleteDialog() async {
    final l10n = AppLocalizations.of(context)!;

    await handleFreePlayComplete(
      context: context,
      title: l10n.blindListenComplete,
      onStudyAgain: () async {
        await ref.read(learningSessionProvider.notifier).replayBlindListen();
      },
      onExit: () async {
        if (mounted) context.pop();
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
      },
    );
    _isShowingDialog = false;
  }

  /// 正常模式完成对话框
  Future<void> _showCompleteDialog() async {
    if (!mounted) return;

    final stepCtx = _getStepContext();

    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    final isReview = progress?.isInReviewStage ?? false;

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.blindListenComplete,
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
      showDifficultySelector: !isReview,
    );

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 用户确认后：保存难度 + 标记完成
    try {
      if (!isReview) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .setDifficulty(
              widget.audioItemId,
              result.difficulty ?? DifficultyLevel.medium,
            );
      }
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('盲听完成处理出错: $e');
    }

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      await _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
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
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      return (
        stepIndex: 0,
        totalSteps: LearningStage.firstLearn.subStageCount,
        stageName: reviewStageLabel(l10n, LearningStage.firstLearn),
        nextStepName: _hasPlayerScreen(SubStageType.intensiveListen)
            ? _getSubStageName(SubStageType.intensiveListen, l10n)
            : null,
        isLastStep: false,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    final isLast = currentIdx >= subStages.length - 1;

    String? nextStepName;
    if (!isLast) {
      final nextSubStage = subStages[currentIdx + 1];
      if (_hasPlayerScreen(nextSubStage)) {
        nextStepName = _getSubStageName(nextSubStage, l10n);
      }
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
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

  // ========== 退出处理 ==========

  Future<void> _openSettings() async {
    AppLogger.log('BlindListenScreen', '打开设置 → 请求进入 WaitingForUser');
    ref
        .read(blindListenPlayerProvider.notifier)
        .enterWaitingForUser(afterCurrentParagraph: true);
    await showBlindListenSettingsSheet(context);
  }

  Future<void> _handleExit() async {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);

    if (sessionState.isFreePlay) {
      await _exit();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exitBlindListenTitle),
        content: Text(l10n.exitBlindListenMessage),
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

    if (confirm == true) {
      await _exit();
    }
  }

  Future<void> _exit() async {
    _isExiting = true;
    if (mounted) context.pop();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
  }

  void _logBlindStateTransition(
    BlindListenPlayerState prev,
    BlindListenPlayerState next,
  ) {
    // 排除 pauseRemaining，倒计时期间变化太频繁
    if (prev.currentParagraphIndex == next.currentParagraphIndex &&
        prev.playingSentenceIndex == next.playingSentenceIndex &&
        prev.currentRepeatCount == next.currentRepeatCount &&
        prev.hasCompletedCurrentParagraphPlayback ==
            next.hasCompletedCurrentParagraphPlayback &&
        prev.isPlaying == next.isPlaying &&
        prev.isPauseCountdown == next.isPauseCountdown &&
        prev.isCountdownPaused == next.isCountdownPaused &&
        prev.isWaitingForUser == next.isWaitingForUser &&
        prev.stepFinished == next.stepFinished) {
      return;
    }

    AppLogger.log(
      'BlindListenScreen',
      '状态变化: '
          'paragraph ${prev.currentParagraphIndex}→${next.currentParagraphIndex}, '
          'sentence ${prev.playingSentenceIndex}→${next.playingSentenceIndex}, '
          'repeat ${prev.currentRepeatCount}→${next.currentRepeatCount}, '
          'playing ${prev.isPlaying}→${next.isPlaying}, '
          'countdown ${prev.isPauseCountdown}/${prev.isCountdownPaused}'
          '→${next.isPauseCountdown}/${next.isCountdownPaused}, '
          'waiting ${prev.isWaitingForUser}→${next.isWaitingForUser}, '
          'completedPlayback ${prev.hasCompletedCurrentParagraphPlayback}'
          '→${next.hasCompletedCurrentParagraphPlayback}, '
          'remaining ${prev.pauseRemaining.inMilliseconds}'
          '→${next.pauseRemaining.inMilliseconds}ms, '
          'stepFinished ${prev.stepFinished}→${next.stepFinished}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 只监听非倒计时字段，排除 pauseRemaining，
    // 避免倒计时每 100ms tick 导致整个页面重建
    ref.watch(
      blindListenPlayerProvider.select(
        (s) => (
          s.currentParagraphIndex,
          s.totalParagraphs,
          s.playingSentenceIndex,
          s.currentRepeatCount,
          s.isPlaying,
          s.isPauseCountdown,
          s.pauseDuration,
          s.isCountdownPaused,
          s.displayMode,
          s.settings,
          s.stepFinished,
        ),
      ),
    );
    final playerState = ref.read(blindListenPlayerProvider);

    return wakelockBody(
      child: _buildParagraphMode(context, l10n, theme, playerState),
    );
  }

  Widget? _buildManualHint(
    BlindListenPlayerState state,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (state.isPauseCountdown) {
      return null;
    }

    final (IconData icon, String text) = state.isPlaying
        ? (Icons.headphones, l10n.blindListenListeningHint)
        : state.isWaitingForUser || !state.hasCompletedCurrentParagraphPlayback
        ? (Icons.play_circle_outline, l10n.blindListenPreListenHint)
        : state.settings.isManualMode
        ? (Icons.lightbulb_outline, l10n.blindListenRecallHint)
        : (Icons.headphones, l10n.blindListenListeningHint);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.s),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ========== 段落分段模式 UI ==========

  Widget _buildParagraphMode(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    BlindListenPlayerState playerState,
  ) {
    final player = ref.read(blindListenPlayerProvider.notifier);

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;

    return LearningHotkeyScope(
      onPlayPause: () {
        if (playerState.isPauseCountdown) {
          playerState.isCountdownPaused
              ? player.resumeCountdown()
              : player.pauseCountdown();
        } else {
          playerState.isPlaying ? player.pause() : player.resume();
        }
      },
      onPrevious: () => player.goToPreviousParagraph(),
      onNext: () {
        final ps = ref.read(blindListenPlayerProvider);
        final isLast = ps.currentParagraphIndex >= ps.totalParagraphs - 1;
        if (isLast) {
          ref.read(blindListenPlayerProvider.notifier).pause();
          _handleCompleted();
        } else {
          ref.read(blindListenPlayerProvider.notifier).goToNextParagraph();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await _handleExit();
        },
        child: ParagraphPracticeScaffold(
          title: l10n.blindListenAppBarTitle,
          onClose: _handleExit,
          onOpenSettings: _openSettings,
          current: playerState.currentParagraphIndex + 1,
          total: playerState.totalParagraphs,
          progressText: l10n.retellParagraphProgress(
            playerState.currentParagraphIndex + 1,
            playerState.totalParagraphs,
          ),
          durationText: l10n.retellParagraphDuration(
            '${paragraphDuration.inSeconds}',
          ),
          paragraphContent: ParagraphSentenceListCard(
            sentences: sentences,
            displayMode:
                playerState.displayMode == BlindListenDisplayMode.showAll
                ? RetellDisplayMode.showAll
                : RetellDisplayMode.hideAll,
            keywordMap: const {},
            playingSentenceIndex: playerState.playingSentenceIndex,
          ),
          contentControls: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final next =
                    playerState.displayMode == BlindListenDisplayMode.showAll
                    ? BlindListenDisplayMode.hideAll
                    : BlindListenDisplayMode.showAll;
                player.setDisplayMode(next);
              },
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      playerState.displayMode == BlindListenDisplayMode.showAll
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      playerState.displayMode == BlindListenDisplayMode.showAll
                          ? l10n.blindListenDisplayHideAll
                          : l10n.intensiveListenPeek,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          practiceControls: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Center(
                  child: playerState.isPauseCountdown
                      ? Text(
                          l10n.blindListenRecallHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(
                height: 56,
                child: playerState.isPauseCountdown
                    ? Consumer(
                        builder: (context, ref, _) {
                          final s = ref.watch(
                            blindListenPlayerProvider.select(
                              (s) => (
                                total: s.pauseDuration,
                                paused: s.isCountdownPaused,
                                fastForward: s.isCountdownFastForward,
                              ),
                            ),
                          );
                          final hasFF = !s.paused && !s.fastForward;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 左槽位：占位（与 prev 按钮对齐）
                              const SizedBox(
                                width: PlaybackControls.controlButtonSize,
                              ),
                              const SizedBox(width: 48),
                              // 中间槽位：倒计时（与中心按钮对齐）
                              SizedBox(
                                width: PlaybackControls.controlButtonSize,
                                child: Center(
                                  child: CountdownChip(
                                    total: s.total,
                                    isPaused: s.paused,
                                    isFastForward: s.fastForward,
                                    onPause: () =>
                                        player.pauseCountdown(),
                                    onResume: () =>
                                        player.resumeCountdown(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                              // 右槽位：快进按钮（与 next 按钮对齐）
                              SizedBox(
                                width: PlaybackControls.controlButtonSize,
                                height: 56,
                                child: Center(
                                  child: AnimatedOpacity(
                                    opacity: hasFF ? 1.0 : 0.0,
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    child: IgnorePointer(
                                      ignoring: !hasFF,
                                      child: hasFF
                                          ? GestureDetector(
                                              onTap: player
                                                  .toggleCountdownFastForward,
                                              child: Icon(
                                                Icons
                                                    .fast_forward_rounded,
                                                size: 32,
                                                color: theme.colorScheme
                                                    .onSurface
                                                    .withValues(
                                                      alpha: 0.6,
                                                    ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    : Center(
                        child:
                            _buildManualHint(playerState, l10n, theme),
                      ),
              ),
            ],
          ),
          canGoPrev: playerState.currentParagraphIndex > 0,
          isLast:
              playerState.currentParagraphIndex >=
              playerState.totalParagraphs - 1,
          centerIcon: _isBlindMainPlaybackActive(playerState)
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onPrevious: () => player.goToPreviousParagraph(),
          onNext: () {
            final isLast =
                playerState.currentParagraphIndex >=
                playerState.totalParagraphs - 1;
            if (isLast) {
              player.pause();
              _handleCompleted();
            } else {
              player.goToNextParagraph();
            }
          },
          onCenter: _isBlindMainPlaybackActive(playerState)
              ? player.pause
              : player.resume,
          isManualMode: playerState.settings.isManualMode,
          playCountText: l10n.blindListenRepeatInfo(
            playerState.currentRepeatCount,
            playerState.settings.repeatCount,
          ),
          l10n: l10n,
          theme: theme,
        ),
      ),
    );
  }
}

bool _isBlindMainPlaybackActive(BlindListenPlayerState state) {
  return state.isPlaying &&
      !state.isPauseCountdown &&
      !state.isCountdownPaused &&
      !state.isWaitingForUser;
}

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

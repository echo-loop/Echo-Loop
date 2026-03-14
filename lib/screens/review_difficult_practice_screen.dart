/// 复习难句补练页面
///
/// 仅加载已标记为难句的句子，逐句执行：
/// 1. 盲听一遍（不显示字幕）
/// 2. 句间停顿 → 自动推进下一句
/// 3. 用户可随时「偷看」字幕或按「听不懂」进入跟读模式
/// 4. 跟读模式：播放句子（显示字幕）→ 自动录音 → 评分 → 倒计时 → 下一遍
///
/// 交互与逐句精听页面（IntensiveListenPlayerScreen）一致。
/// R1+ 可取消难句标记（听懂的句子 unbookmark）。
/// 完成后弹完成对话框，支持"继续下一步"或"返回计划"。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/speech_practice_session_provider.dart';
import '../theme/app_theme.dart';
import '../utils/wakelock_mixin.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/listen_and_repeat/speech_practice_turn_panel.dart';
import '../widgets/listen_and_repeat/speech_practice_result_card.dart';
import '../widgets/player_hotkey_scope.dart';

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
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 注册 TurnController 回调
      ref
          .read(listenAndRepeatTurnControllerProvider.notifier)
          .setOnContinue(
            () => ref
                .read(reviewDifficultPracticeProvider.notifier)
                .completePausedTurn(),
          );
      ref.read(reviewDifficultPracticeProvider.notifier).startPlaying();
    });
  }

  /// 当前句子的 promptId
  String _currentPromptId() {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final sentence = player.currentSentence;
    final sentenceIndex = sentence?.index ?? player.currentIndex;
    return 'difficult:${widget.audioItemId}:$sentenceIndex';
  }

  /// 录音相关清理（切句/退出前调用）
  Future<void> _prepareForExternalPlaybackAction() async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    await speech.cancelActiveRecording();
    await speech.stopAttemptPlayback();
    ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
    // 重新注册回调（clearTurn 会清空 _onContinue）
    ref
        .read(listenAndRepeatTurnControllerProvider.notifier)
        .setOnContinue(
          () => ref
              .read(reviewDifficultPracticeProvider.notifier)
              .completePausedTurn(),
        );
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (!playerState.isPauseBetweenPlays || !playerState.isAnnotationMode) {
      return;
    }

    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final turn = ref.read(listenAndRepeatTurnControllerProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId();
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    if (speech.isRecordingPrompt(promptId)) {
      await turn.handleManualStop();
      return;
    }

    if (!playerState.isCountdownPaused) {
      player.pauseCountdown();
    }
    await turn.startManualRecording(
      promptId: promptId,
      referenceText: currentSentence.text,
      sentenceDuration: currentSentence.duration,
    );
  }

  /// 处理录音回放点击
  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    final speechState = ref.read(speechPracticeSessionProvider);
    if (speechState.playingPromptId == promptId) {
      await speech.stopAttemptPlayback();
      return;
    }

    // 暂停原句播放
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (playerState.isPlaying) {
      ref.read(reviewDifficultPracticeProvider.notifier).pause();
    }
    await speech.playAttempt(promptId);
  }

  /// 处理退出
  Future<void> _handleExit() async {
    await _prepareForExternalPlaybackAction();
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.read(reviewDifficultPracticeProvider);

    // 已完成或自由练习模式直接退出
    if (playerState.isCompleted || session.isFreePlay) {
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
      // 取消退出 → 恢复播放（标注模式下不恢复）
      if (mounted) {
        final currentState = ref.read(reviewDifficultPracticeProvider);
        if (!currentState.isAnnotationMode) {
          player.resume();
        }
      }
      return;
    }

    await _exit();
  }

  /// 执行退出（保存断点、释放麦克风后退出）
  Future<void> _exit() async {
    // 释放麦克风
    await ref.read(speechPracticeSessionProvider.notifier).disposeSession();

    // 保存当前句子索引作为断点
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultPracticeSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 取消当前句子的难句标记
  Future<void> _handleRemoveDifficult() async {
    await _prepareForExternalPlaybackAction();
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final removed = player.removeDifficultMark();

    if (removed != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(widget.audioItemId, removed.index);
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (!playerState.isCompleted && playerState.totalSentences > 0) {
      await player.startPlaying();
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
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    final isLast = currentIdx >= subStages.length - 1;

    String? nextStepName;
    if (!isLast) {
      final nextSubStage = subStages[currentIdx + 1];
      nextStepName = nextSubStage.label;
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放麦克风
    await ref.read(speechPracticeSessionProvider.notifier).disposeSession();

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：弹窗询问"完成"或"再练一遍"
    if (session.isFreePlay) {
      final playerState = ref.read(reviewDifficultPracticeProvider);
      final l10n = AppLocalizations.of(context)!;

      final result = await showFreePlayCompleteDialog(
        context: context,
        title: l10n.reviewDifficultPracticeCompleteTitle,
        message: l10n.reviewDifficultPracticeCompleteMessage(
          playerState.totalSentences,
        ),
      );

      _isShowingDialog = false;
      if (!mounted) return;

      // 清除断点（已全部完成）
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);

      if (result == true) {
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      } else {
        // 再练一遍
        await ref.read(reviewDifficultPracticeProvider.notifier).resetToStart();
      }
      return;
    }

    final playerState = ref.read(reviewDifficultPracticeProvider);
    final stepCtx = _getStepContext();

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.reviewDifficultPracticeCompleteTitle,
      contentBody: Text(
        l10n.reviewDifficultPracticeCompleteMessage(playerState.totalSentences),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
      replayLabel: l10n.practiceAgain,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    // 再来一遍（点击 replayLabel 按钮时 result 为 null）
    if (result == null) {
      await ref.read(reviewDifficultPracticeProvider.notifier).resetToStart();
      return;
    }

    // 清除断点（已全部完成）并推进子步骤
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('难句补练完成处理出错: $e');
    }

    if (result.continueToNext && stepCtx.nextStepName != null) {
      // 继续下一步 → 退出当前模式，返回计划页让路由分发
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    } else {
      // 返回计划页
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final speechState = ref.watch(speechPracticeSessionProvider);
    final turnState = ref.watch(listenAndRepeatTurnControllerProvider);

    // 监听完成状态
    ref.listen<ReviewDifficultPracticeState>(reviewDifficultPracticeProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
    });

    final currentSentence = player.currentSentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = speechState.attempts[currentPromptId];
    final isRecordingCurrent = speechState.recordingPromptId == currentPromptId;

    // 跟读模式 + 停顿中 + TurnController idle → 自动开始录音（与跟读页一致）
    if (playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        currentSentence != null &&
        turnState.phase == ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestTurn = ref.read(listenAndRepeatTurnControllerProvider);
        if (latestTurn.phase != ListenAndRepeatTurnPhase.idle) return;
        final latestPlayer = ref.read(reviewDifficultPracticeProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays) {
          return;
        }
        // 暂停 provider 层倒计时（录音由 TurnController 接管）
        if (!latestPlayer.isCountdownPaused) {
          ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
        }
        unawaited(
          ref
              .read(listenAndRepeatTurnControllerProvider.notifier)
              .ensureAutoTurn(
                promptId: currentPromptId,
                referenceText: currentSentence.text,
                sentenceDuration: currentSentence.duration,
              ),
        );
      });
    }

    // 非停顿状态下清理 TurnController
    if (!playerState.isPauseBetweenPlays &&
        turnState.phase != ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
        // 重新注册回调
        ref
            .read(listenAndRepeatTurnControllerProvider.notifier)
            .setOnContinue(
              () => ref
                  .read(reviewDifficultPracticeProvider.notifier)
                  .completePausedTurn(),
            );
      });
    }

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
    return LearningHotkeyScope(
      onPlayPause: () {
        unawaited(_prepareForExternalPlaybackAction());
        if (playerState.isPauseBetweenPlays) {
          player.replayDuringCountdown();
        } else if (playerState.isPlaying) {
          player.pause();
        } else {
          player.resume();
        }
      },
      onPrevious: () {
        unawaited(_prepareForExternalPlaybackAction());
        player.goToPrevious();
      },
      onNext: () {
        unawaited(_prepareForExternalPlaybackAction());
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
                tooltip: l10n.difficultPracticeSettings,
                onPressed: () =>
                    showDifficultPracticeSettingsSheet(context: context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度区域
              _ProgressSection(
                playerState: playerState,
                l10n: l10n,
                durationText: durationText,
              ),

              // 主体内容：盲听/跟读 双态切换
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: playerState.isAnnotationMode
                      ? _ShadowReadingView(
                          key: const ValueKey('shadow'),
                          text: currentSentence?.text ?? '',
                          playerState: playerState,
                          turnState: turnState,
                          speechState: speechState,
                          currentPromptId: currentPromptId,
                          currentAttempt: currentAttempt,
                          isRecordingCurrent: isRecordingCurrent,
                          l10n: l10n,
                          onRemoveDifficult: _handleRemoveDifficult,
                          onRecordTap: _handleRecordTap,
                          onAttemptPlaybackTap: _handleAttemptPlaybackTap,
                          onFastForward: () => ref
                              .read(
                                listenAndRepeatTurnControllerProvider.notifier,
                              )
                              .fastForwardReviewCountdown(),
                          onCountdownTap: turnState.isReviewCountdownPaused
                              ? () => ref
                                    .read(
                                      listenAndRepeatTurnControllerProvider
                                          .notifier,
                                    )
                                    .resumeReviewCountdown()
                              : () => ref
                                    .read(
                                      listenAndRepeatTurnControllerProvider
                                          .notifier,
                                    )
                                    .pauseReviewCountdown(),
                          aiNotifier: ref.read(sentenceAiNotifierProvider),
                          audioItemId: widget.audioItemId,
                          sentenceIndex: player.currentIndex,
                        )
                      : _NormalModeView(
                          key: const ValueKey('normal'),
                          playerState: playerState,
                          l10n: l10n,
                          theme: theme,
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onRemoveDifficult: _handleRemoveDifficult,
                          onPauseCountdown: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                          sentenceText: currentSentence?.text,
                        ),
                ),
              ),

              // 底部播放控制
              _PlaybackControls(
                playerState: playerState,
                onPrevious: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  player.goToPrevious();
                },
                onNext: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  player.goToNext();
                },
                onPlayPause: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  if (playerState.isPauseBetweenPlays) {
                    player.replayDuringCountdown();
                  } else if (playerState.isPlaying) {
                    player.pause();
                  } else {
                    player.resume();
                  }
                },
              ),

              // 遍数
              if (playerState.isAnnotationMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    l10n.listenAndRepeatPlayCount(
                      playerState.currentPlayCount,
                      playerState.targetRepeatCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                )
              else if (playerState.settings.blindListenRepeatCount > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    l10n.listenAndRepeatPlayCount(
                      playerState.currentPlayCount,
                      playerState.settings.blindListenRepeatCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: AppSpacing.m),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final String? durationText;

  const _ProgressSection({
    required this.playerState,
    required this.l10n,
    this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = playerState.totalSentences;
    final current = playerState.currentSentenceIndex + 1;
    final progress = total > 0 ? current / total : 0.0;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                l10n.reviewDifficultPracticeProgress(current, total),
                style: subtitleStyle,
              ),
              const Spacer(),
              if (durationText case final dur?) Text(dur, style: subtitleStyle),
            ],
          ),
        ],
      ),
    );
  }
}

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekToggle;
  final VoidCallback onCantUnderstand;
  final VoidCallback onRemoveDifficult;
  final VoidCallback onPauseCountdown;
  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onRemoveDifficult,
    required this.onPauseCountdown,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句标记行
          GestureDetector(
            onTap: onRemoveDifficult,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.intensiveListenMarkedDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.bookmark, color: Colors.amber, size: 18),
              ],
            ),
          ),

          // 遮盖/偷看区域
          Expanded(
            child: Center(
              child: playerState.isTextRevealed && sentenceText != null
                  ? Text(
                      sentenceText!,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    )
                  : _HiddenTextPlaceholder(),
            ),
          ),

          // 倒计时控制（上） + 盲听状态标签（下）
          SizedBox(
            height: 80,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (playerState.isPauseBetweenPlays)
                  CountdownChip(
                    remaining: playerState.pauseRemaining,
                    total: playerState.pauseDuration,
                    isPaused: playerState.isCountdownPaused,
                    onTap: onPauseCountdown,
                  ),
                if (playerState.isPlaying)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headphones,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        l10n.reviewDifficultPracticeBlindListen,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),

          // 偷看/听不懂按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPeekToggle,
                child: _ActionChip(
                  icon: playerState.isTextRevealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  label: l10n.intensiveListenPeek,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton.tonal(
                onPressed: onCantUnderstand,
                child: Text(l10n.intensiveListenCantUnderstand),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

/// 跟读模式视图（听不懂 → 显示字幕 + 自动录音 + 评分反馈）
class _ShadowReadingView extends StatelessWidget {
  final String text;
  final ReviewDifficultPracticeState playerState;
  final ListenAndRepeatTurnState turnState;
  final SpeechPracticeSessionState speechState;
  final String currentPromptId;
  final SpeechPracticeAttempt? currentAttempt;
  final bool isRecordingCurrent;
  final AppLocalizations l10n;
  final VoidCallback onRemoveDifficult;
  final VoidCallback onRecordTap;
  final void Function(String promptId) onAttemptPlaybackTap;
  final VoidCallback onFastForward;
  final VoidCallback onCountdownTap;
  final SentenceAiNotifier? aiNotifier;
  final String? audioItemId;
  final int? sentenceIndex;

  const _ShadowReadingView({
    super.key,
    required this.text,
    required this.playerState,
    required this.turnState,
    required this.speechState,
    required this.currentPromptId,
    required this.currentAttempt,
    required this.isRecordingCurrent,
    required this.l10n,
    required this.onRemoveDifficult,
    required this.onRecordTap,
    required this.onAttemptPlaybackTap,
    required this.onFastForward,
    required this.onCountdownTap,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ai = aiNotifier;
    final cachedTranslation = ai?.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    // 停顿期间显示录音面板（与跟读页一致，遍间和句间都触发录音）
    final shouldShowTurnPanel = playerState.isPauseBetweenPlays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 句子卡片（含难句标记、可点击查词、AI 翻译/解析、录音反馈）
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                key: ValueKey(text),
                text: text,
                isDifficult: true,
                onToggle: onRemoveDifficult,
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                highlightedSegments: currentAttempt?.referenceSegments,
                inlineFeedback: switch (currentAttempt) {
                  final attempt? when attempt.hasFinalFeedback =>
                    SpeechPracticeResultCard(
                      l10n: l10n,
                      attempt: attempt,
                      isPlayingAttempt:
                          speechState.playingPromptId == currentPromptId,
                      onPlayAttempt: attempt.hasRecording
                          ? () => onAttemptPlaybackTap(currentPromptId)
                          : null,
                    ),
                  _ => null,
                },
                onRequestTranslation: ai != null
                    ? () async {
                        final result = await ai.getTranslation(text);
                        return result.translation;
                      }
                    : null,
                onRequestAnalysis: ai != null
                    ? () async {
                        final result = await ai.getAnalysis(text);
                        return result.toDisplayString();
                      }
                    : null,
                cachedTranslation: cachedTranslation,
                cachedAnalysis: cachedAnalysisText,
              ),
            ),
          ),

          // 底部固定区域：录音面板 / 跟读提示 / 播放状态
          if (shouldShowTurnPanel)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: SpeechPracticeTurnPanel(
                l10n: l10n,
                turnState: turnState,
                isRecordingCurrent: isRecordingCurrent,
                onRecordTap: onRecordTap,
                onFastForward: onFastForward,
                onCountdownTap: onCountdownTap,
              ),
            )
          else
            SizedBox(
              height: 116,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (playerState.isPlaying) ...[
                    // 播放中提示：先听，听完后跟读
                    Text(
                      l10n.listenAndRepeatListenHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.headphones,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.m),
        ],
      ),
    );
  }
}

/// 操作按钮（偷看字幕 / 听不懂）
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部播放控制
///
/// 布局：[上一句] --- [播放/暂停] --- [下一句]
class _PlaybackControls extends StatelessWidget {
  final ReviewDifficultPracticeState playerState;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;

  const _PlaybackControls({
    required this.playerState,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canGoPrev = playerState.currentSentenceIndex > 0;
    final canGoNext =
        playerState.currentSentenceIndex < playerState.totalSentences - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? onPrevious : null,
          ),
          const SizedBox(width: 48),

          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),

          _NavButton(
            icon: Icons.skip_next_rounded,
            enabled: canGoNext,
            onTap: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（上一句/下一句）
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 0.6 : 0.15,
        duration: const Duration(milliseconds: 150),
        child: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

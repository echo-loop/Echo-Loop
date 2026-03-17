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
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/speech_practice_session_provider.dart';
import '../utils/wakelock_mixin.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/practice/practice_playback_controls.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_shadow_reading_view.dart';

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
      final turnController = ref.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      turnController.setOnContinue(
        () => ref
            .read(reviewDifficultPracticeProvider.notifier)
            .completePausedTurn(),
      );
      // 同步初始控制模式
      turnController.setManualMode(
        ref.read(reviewDifficultPracticeProvider).settings.isManualMode,
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

    // 监听完成状态 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(reviewDifficultPracticeProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
      // 控制模式切换时同步到 TurnController，并取消正在进行的自动录音
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final turnController = ref.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        turnController.setManualMode(next.settings.isManualMode);
        if (next.settings.isManualMode) {
          final turnState = ref.read(listenAndRepeatTurnControllerProvider);
          if (turnState.isActive) {
            unawaited(
              ref
                  .read(speechPracticeSessionProvider.notifier)
                  .cancelActiveRecording(),
            );
            turnController.clearTurn();
          }
        }
      }
    });

    final currentSentence = player.currentSentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = speechState.attempts[currentPromptId];
    final isRecordingCurrent = speechState.recordingPromptId == currentPromptId;

    // 手动模式 + 盲听停顿中 → 立即暂停倒计时，等用户手动下一句
    if (!playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        playerState.settings.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(reviewDifficultPracticeProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
      });
    }

    // 跟读模式 + 停顿中 + TurnController idle → 暂停倒计时 + 自动录音
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
        // 手动模式下不自动开始录音，等用户点击录音按钮
        if (latestPlayer.settings.isManualMode) {
          return;
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

    // 句子时长
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
              PracticeProgressSection(
                playerState: playerState,
                l10n: l10n,
                durationText: durationText,
              ),

              // 主体内容：盲听/跟读 双态切换
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: playerState.isAnnotationMode
                      ? PracticeShadowReadingView(
                          key: const ValueKey('shadow'),
                          text: currentSentence?.text ?? '',
                          playerState: playerState,
                          l10n: l10n,
                          onRemoveMark: _handleRemoveDifficult,
                          aiNotifier: ref.read(sentenceAiNotifierProvider),
                          audioItemId: widget.audioItemId,
                          sentenceIndex: player.currentIndex,
                          recording: RecordingConfig(
                            turnState: turnState,
                            speechState: speechState,
                            currentPromptId: currentPromptId,
                            currentAttempt: currentAttempt,
                            isRecordingCurrent: isRecordingCurrent,
                            onRecordTap: _handleRecordTap,
                            onAttemptPlaybackTap: _handleAttemptPlaybackTap,
                            onFastForward: () => ref
                                .read(
                                  listenAndRepeatTurnControllerProvider
                                      .notifier,
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
                          ),
                        )
                      : PracticeNormalModeView(
                          key: const ValueKey('normal'),
                          playerState: playerState,
                          l10n: l10n,
                          theme: theme,
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onRemoveMark: _handleRemoveDifficult,
                          onPauseCountdown: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                          sentenceText: currentSentence?.text,
                        ),
                ),
              ),

              // 底部播放控制
              PracticePlaybackControls(
                playerState: playerState,
                onPrevious: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  player.goToPrevious();
                },
                onNext: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  final isLast =
                      playerState.currentSentenceIndex >=
                      playerState.totalSentences - 1;
                  if (isLast) {
                    player.forceComplete();
                  } else if (playerState.isPauseBetweenPlays &&
                      playerState.isAnnotationMode) {
                    // 跟读停顿中：走 completePausedTurn（递增遍数或推进）
                    unawaited(player.completePausedTurn());
                  } else {
                    unawaited(player.goToNext());
                  }
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
              PracticePlayCountLabel(
                playerState: playerState,
                l10n: l10n,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

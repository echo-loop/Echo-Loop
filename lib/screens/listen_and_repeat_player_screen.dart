/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/listen_and_repeat_player_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../models/retell_settings.dart';
import '../models/speech_practice_models.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/speech_practice_session_provider.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/listen_and_repeat/speech_practice_turn_panel.dart';
import '../widgets/listen_and_repeat/speech_practice_result_card.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/retell/retell_briefing_sheet.dart';
import '../widgets/player_hotkey_scope.dart';

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
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放，注册 TurnController 回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final turnController =
          ref.read(listenAndRepeatTurnControllerProvider.notifier);
      turnController.setOnContinue(
        () => ref
            .read(listenAndRepeatPlayerProvider.notifier)
            .completePausedTurn(),
      );
      // 同步初始控制模式
      turnController.setManualMode(
        ref.read(listenAndRepeatPlayerProvider).settings.isManualMode,
      );
      ref.read(listenAndRepeatPlayerProvider.notifier).startPlaying();
    });
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    await _prepareForExternalPlaybackAction();
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await _saveSentenceProgress();
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
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
      // 用户取消退出 → 恢复播放
      if (mounted) {
        player.resume();
      }
      return;
    }

    // 保存断点
    await _saveSentenceProgress();

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  String _currentPromptId() {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final sentence = player.currentSentence;
    final sentenceIndex = sentence?.index ?? player.currentIndex;
    return _promptIdForSentenceIndex(sentenceIndex);
  }

  String _promptIdForSentenceIndex(int sentenceIndex) {
    return 'shadowing:${widget.audioItemId}:$sentenceIndex';
  }

  Future<void> _prepareForExternalPlaybackAction() async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    await speech.cancelActiveRecording();
    await speech.stopAttemptPlayback();
  }

  Future<void> _handleRecordTap() async {
    final playerState = ref.read(listenAndRepeatPlayerProvider);
    if (!playerState.isPauseBetweenPlays) {
      return;
    }

    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final turn = ref.read(listenAndRepeatTurnControllerProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) {
      return;
    }

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

  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    final speechState = ref.read(speechPracticeSessionProvider);
    if (speechState.playingPromptId == promptId) {
      await speech.stopAttemptPlayback();
      return;
    }

    // 暂停原句播放，确保同时只有一个音频在播放
    final playerState = ref.read(listenAndRepeatPlayerProvider);
    if (playerState.isPlaying) {
      await ref.read(listenAndRepeatPlayerProvider.notifier).pause();
    }
    await speech.playAttempt(promptId);
  }

  /// 保存跟读断点进度
  Future<void> _saveSentenceProgress() async {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(widget.audioItemId, player.currentIndex);
  }

  /// 构建带 AI 翻译/解析回调的句子卡片
  Widget _buildAnnotationCard(
    String text,
    int sentenceIndex, {
    Widget? inlineFeedback,
    List<SpeechTranscriptSegment>? highlightedSegments,
  }) {
    final ai = ref.read(sentenceAiNotifierProvider);
    final cachedTranslation = ai.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return SentenceAnnotationCard(
      key: ValueKey(text),
      text: text,
      isDifficult: true,
      onToggle: _handleRemoveDifficult,
      audioItemId: widget.audioItemId,
      sentenceIndex: sentenceIndex,
      inlineFeedback: inlineFeedback,
      highlightedSegments: highlightedSegments,
      onRequestTranslation: () async {
        final result = await ai.getTranslation(text);
        return result.translation;
      },
      onRequestAnalysis: () async {
        final result = await ai.getAnalysis(text);
        return result.toDisplayString();
      },
      cachedTranslation: cachedTranslation,
      cachedAnalysis: cachedAnalysisText,
    );
  }

  /// 取消当前句子的难句收藏
  Future<void> _handleRemoveDifficult() async {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final removed = player.removeDifficultMark();

    if (removed != null) {
      // 从数据库删除书签
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(widget.audioItemId, removed.index);
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final state = ref.read(listenAndRepeatPlayerProvider);
    if (!state.isCompleted && state.totalSentences > 0) {
      await player.startPlaying();
    }
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
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.listenAndRepeat);
      final isLast = idx >= subStages.length - 1;
      String? nextName;
      if (!isLast) {
        final next = subStages[idx + 1];
        if (_hasPlayerScreen(next)) {
          nextName = _getSubStageName(next, l10n);
        }
      }
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: LearningStage.firstLearn.label,
        nextStepName: nextName,
        isLastStep: isLast,
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
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理播放完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(listenAndRepeatPlayerProvider);

    if (!mounted) {
      _isShowingDialog = false;
      return;
    }

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      final result = await showFreePlayCompleteDialog(
        context: context,
        title: l10n.listenAndRepeatCompleteTitle,
        message: l10n.listenAndRepeatCompleteMessage(
          playerState.totalSentences,
        ),
      );

      _isShowingDialog = false;
      if (!mounted) return;

      // 递增遍数（无论再来一遍还是完成，都算一遍）
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);

      if (result == true) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveShadowingSentenceIndex(widget.audioItemId, null);
        // 完成退出
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      } else {
        // 再来一遍：重置到第一句重新开始
        await ref.read(speechPracticeSessionProvider.notifier).disposeSession();
        ref.read(listenAndRepeatPlayerProvider.notifier).resetToStart();
      }
      return;
    }

    final stepCtx = _getStepContext();

    final l10nStep = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10nStep.listenAndRepeatCompleteTitle,
      contentBody: Text(
        l10nStep.listenAndRepeatCompleteMessage(playerState.totalSentences),
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result != null) {
      try {
        // 递增跟读总遍数
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .incrementShadowingPassCount(widget.audioItemId);

        // 清除断点（已完成）
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveShadowingSentenceIndex(widget.audioItemId, null);

        // 推进子步骤
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        print('跟读完成处理出错: $e');
      }

      if (result.continueToNext) {
        // 继续下一步：段落复述
        await _navigateToRetell();
      } else {
        // 返回计划页
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      }
    }
  }

  /// 导航到段落复述播放器
  ///
  /// 退出跟读模式 → 显示复述简报弹窗 → 分段 + 提取关键词 → 进入复述模式 → pushReplacement
  Future<void> _navigateToRetell() async {
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) {
      if (mounted) context.pop();
      return;
    }

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(LearningStage.firstLearn),
      onStartPractice: (targetDuration) async {
        final paragraphs = groupSentencesIntoParagraphs(
          lpState.sentences,
          targetDuration,
        );
        final keywordsMap = extractKeywords(
          lpState.sentences,
          ratio: KeywordRatio.oneThird,
        );

        await ref
            .read(learningSessionProvider.notifier)
            .enterRetellMode(widget.audioItemId, paragraphs, keywordsMap);
        if (mounted) {
          context.pushReplacement(
            AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(listenAndRepeatPlayerProvider);
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final speechState = ref.watch(speechPracticeSessionProvider);
    final turnState = ref.watch(listenAndRepeatTurnControllerProvider);

    // 监听完成状态 + 控制模式变化
    ref.listen<ListenAndRepeatPlayerState>(listenAndRepeatPlayerProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
      // 控制模式切换时同步到 TurnController，并取消正在进行的自动录音
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final turnController =
            ref.read(listenAndRepeatTurnControllerProvider.notifier);
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

    if (playerState.isPauseBetweenPlays &&
        currentSentence != null &&
        turnState.phase == ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final latestTurn = ref.read(listenAndRepeatTurnControllerProvider);
        if (latestTurn.phase != ListenAndRepeatTurnPhase.idle) {
          return;
        }
        final latestPlayer = ref.read(listenAndRepeatPlayerProvider);
        // 防护：player 可能已推进，不再处于停顿中
        if (!latestPlayer.isPauseBetweenPlays) {
          AppLogger.log('Screen', 'postFrameCallback 跳过：isPauseBetweenPlays=false');
          return;
        }
        if (!latestPlayer.isCountdownPaused) {
          ref.read(listenAndRepeatPlayerProvider.notifier).pauseCountdown();
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

    if (!playerState.isPauseBetweenPlays &&
        turnState.phase != ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
      });
    }

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
        unawaited(player.goToPrevious());
      },
      onNext: () {
        unawaited(_prepareForExternalPlaybackAction());
        unawaited(player.goToNext());
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
                onPressed: () =>
                    showListenAndRepeatSettingsSheet(context: context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度条
              _ProgressSection(
                playerState: playerState,
                l10n: l10n,
                durationText: durationText,
              ),

              // 主体内容：句子卡片
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: SingleChildScrollView(
                    child: currentSentence != null
                        ? _buildAnnotationCard(
                            currentSentence.text,
                            player.currentIndex,
                            highlightedSegments:
                                currentAttempt?.referenceSegments,
                            inlineFeedback: switch (currentAttempt) {
                              final attempt? when attempt.hasFinalFeedback =>
                                SpeechPracticeResultCard(
                                  l10n: l10n,
                                  attempt: attempt,
                                  isPlayingAttempt:
                                      speechState.playingPromptId ==
                                      currentPromptId,
                                  onPlayAttempt: attempt.hasRecording
                                      ? () => _handleAttemptPlaybackTap(
                                          currentPromptId,
                                        )
                                      : null,
                                ),
                              _ => null,
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // 底部区域：录音/提示 + 播放控制 + 遍数
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.l,
                  right: AppSpacing.l,
                  bottom: AppSpacing.m,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 录音面板 / 播放提示
                    // 自动模式 idle 阶段不显示，避免蓝→红闪烁；手动模式需要显示蓝色按钮
                    if (playerState.isPauseBetweenPlays &&
                        (playerState.settings.isManualMode ||
                            turnState.phase !=
                                ListenAndRepeatTurnPhase.idle))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: SpeechPracticeTurnPanel(
                          l10n: l10n,
                          turnState: turnState,
                          isRecordingCurrent: isRecordingCurrent,
                          onRecordTap: _handleRecordTap,
                          onFastForward: () {
                            ref
                                .read(
                                  listenAndRepeatTurnControllerProvider
                                      .notifier,
                                )
                                .fastForwardReviewCountdown();
                          },
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
                      ),
                    // 播放控制
                    _PlaybackControls(
                      playerState: playerState,
                      onPrevious: () {
                        unawaited(_prepareForExternalPlaybackAction());
                        unawaited(player.goToPrevious());
                      },
                      onNext: () {
                        unawaited(_prepareForExternalPlaybackAction());
                        final isLast = playerState.currentSentenceIndex >=
                            playerState.totalSentences - 1;
                        if (isLast) {
                          // 最后一句：直接完成
                          player.forceComplete();
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
                    // 遍数（手动模式下隐藏文字但保留占位）
                    Opacity(
                      opacity: playerState.settings.isManualMode ? 0 : 1,
                      child: Text(
                        l10n.listenAndRepeatPlayCount(
                          playerState.currentPlayCount,
                          playerState.settings.repeatCount,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final ListenAndRepeatPlayerState playerState;
  final AppLocalizations l10n;

  /// 句子时长文本（如 "2.8秒"），为 null 时不显示
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
                l10n.listenAndRepeatProgress(current, total),
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

/// 底部播放控制
///
/// 布局：[上一句] --- [播放/暂停] --- [下一句]
class _PlaybackControls extends StatelessWidget {
  final ListenAndRepeatPlayerState playerState;
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
    final isLastSentence =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    final canGoNext = true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
            icon: isLastSentence
                ? Icons.check_circle_rounded
                : Icons.skip_next_rounded,
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

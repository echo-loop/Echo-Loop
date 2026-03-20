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
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/blind_listen_settings_sheet.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/paragraph_bottom_controls.dart';
import '../widgets/common/paragraph_progress_header.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/retell/retell_briefing_sheet.dart';
import '../widgets/retell/retell_sentence_tile.dart';
import '../database/providers.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';
import '../providers/listening_practice/bookmark_manager.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blindListenPlayerProvider.notifier).startPlaying();
    });
  }


  // ========== 完成处理 ==========

  /// 播放完成处理
  void _handleCompleted() {
    if (_isExiting) return;
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

    if (!mounted || result == null) return;

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

    if (result.action == StepCompleteAction.continueNext) {
      await _navigateToNextStep();
    } else {
      // back：返回计划页
      if (mounted) context.pop();
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
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
        stageName: LearningStage.firstLearn.label,
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
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 导航到下一个子步骤
  Future<void> _navigateToNextStep() async {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null || !mounted) {
      if (mounted) context.pop();
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      return;
    }

    final nextSubStage = progress.currentSubStage;

    if (nextSubStage == SubStageType.intensiveListen) {
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (!mounted) return;

      final lpState = ref.read(listeningPracticeProvider);
      if (lpState.sentences.isEmpty) {
        if (mounted) context.pop();
        return;
      }

      await ref
          .read(learningSessionProvider.notifier)
          .enterIntensiveListenMode(widget.audioItemId, lpState.sentences);
      if (mounted) {
        context.pushReplacement(
          AppRoutes.intensiveListenPlayer(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      }
    } else if (nextSubStage == SubStageType.reviewDifficultPractice) {
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (!mounted) return;

      final lpState = ref.read(listeningPracticeProvider);
      if (lpState.sentences.isEmpty) {
        if (mounted) context.pop();
        return;
      }

      final bookmarkDao = ref.read(bookmarkDaoProvider);
      final bookmarks = await BookmarkManager.loadBookmarks(
        widget.audioItemId,
        dao: bookmarkDao,
      );
      if (!mounted) return;

      if (bookmarks.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reviewDifficultPracticeNone)),
        );
        _navigateToReviewRetell();
        return;
      }

      await ref
          .read(learningSessionProvider.notifier)
          .enterReviewDifficultPracticeMode(
            widget.audioItemId,
            lpState.sentences,
          );
      if (mounted) {
        context.pushReplacement(
          AppRoutes.reviewDifficultPractice(
            widget.collectionId,
            widget.audioItemId,
          ),
        );
      }
    } else {
      if (mounted) context.pop();
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
    }
  }

  /// 导航到复习复述
  void _navigateToReviewRetell() {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];
    if (progress == null || !mounted) {
      if (mounted) context.pop();
      return;
    }

    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) {
      context.pop();
      return;
    }

    final nextSubStage = progress.currentSubStage;
    if (nextSubStage == SubStageType.reviewRetellSummary) {
      final keywordsMap = extractKeywords(
        lpState.sentences,
        ratio: KeywordRatio.oneThird,
      );
      ref
          .read(learningSessionProvider.notifier)
          .enterRetellMode(
            widget.audioItemId,
            [lpState.sentences],
            keywordsMap,
          )
          .then((_) {
        if (mounted) {
          context.pushReplacement(
            AppRoutes.retellPlayer(
              widget.collectionId,
              widget.audioItemId,
            ),
          );
        }
      });
    } else if (nextSubStage == SubStageType.reviewRetellParagraph) {
      final currentStage = progress.currentStage;
      showRetellBriefingSheet(
        context: context,
        sentences: lpState.sentences,
        defaultSeconds: retellDefaultSeconds(currentStage),
        onStartPractice: (targetDuration, _) async {
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
              .enterRetellMode(
                widget.audioItemId,
                paragraphs,
                keywordsMap,
              );
          if (mounted) {
            context.pushReplacement(
              AppRoutes.retellPlayer(
                widget.collectionId,
                widget.audioItemId,
              ),
            );
          }
        },
      );
    } else {
      context.pop();
    }
  }

  // ========== 退出处理 ==========

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = ref.watch(learningSessionProvider);
    final playerState = ref.watch(blindListenPlayerProvider);

    return _buildParagraphMode(context, l10n, theme, session, playerState);
  }

  /// 手动模式下播放完成后的空闲状态（非播放、非倒计时）
  bool _isManualIdleState(BlindListenPlayerState state) {
    return state.settings.isManualMode &&
        !state.isPlaying &&
        !state.isPauseCountdown;
  }

  // ========== 段落分段模式 UI ==========

  Widget _buildParagraphMode(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    LearningSessionState session,
    BlindListenPlayerState playerState,
  ) {
    final player = ref.read(blindListenPlayerProvider.notifier);

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final progress = (playerState.totalParagraphs > 0)
        ? (playerState.currentParagraphIndex + 1) /
            playerState.totalParagraphs
        : 0.0;

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
        final isLast =
            ps.currentParagraphIndex >= ps.totalParagraphs - 1;
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
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.blindListenAppBarTitle),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _handleExit,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => showBlindListenSettingsSheet(context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度条
              LinearProgressIndicator(value: progress),

              // 段落进度文字
              ParagraphProgressHeader(
                currentIndex: playerState.currentParagraphIndex,
                totalParagraphs: playerState.totalParagraphs,
                paragraphDuration: paragraphDuration,
              ),

              // 句子列表
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    itemCount: sentences.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: AppSpacing.m,
                      endIndent: AppSpacing.m,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final sentence = sentences[index];
                      return RetellSentenceTile(
                        sentence: sentence,
                        phase: RetellPhase.listening,
                        displayMode: playerState.displayMode ==
                                BlindListenDisplayMode.showAll
                            ? RetellDisplayMode.showAll
                            : RetellDisplayMode.hideAll,
                        keywordIndices: const {},
                        isPlayingSentence:
                            index == playerState.playingSentenceIndex,
                        onWordTap: playerState.displayMode ==
                                BlindListenDisplayMode.showAll
                            ? (word) => showWordDictionarySheet(
                                  context: context,
                                  word: word,
                                  audioItemId: widget.audioItemId,
                                  sentenceIndex: index,
                                  sentenceText: sentence.text,
                                  sentenceStartMs:
                                      sentence.startTime.inMilliseconds,
                                  sentenceEndMs:
                                      sentence.endTime.inMilliseconds,
                                )
                            : null,
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.s),

              // 字幕显示/隐藏标签（点击切换）
              GestureDetector(
                onTap: () {
                  final next =
                      playerState.displayMode == BlindListenDisplayMode.showAll
                          ? BlindListenDisplayMode.hideAll
                          : BlindListenDisplayMode.showAll;
                  player.setDisplayMode(next);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      playerState.displayMode == BlindListenDisplayMode.showAll
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      playerState.displayMode == BlindListenDisplayMode.showAll
                          ? l10n.blindListenDisplayHideAll
                          : l10n.intensiveListenPeek,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // 回忆提示（仅自动模式倒计时时显示）
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

              // 倒计时/状态提示区域
              SizedBox(
                height: 56,
                child: Center(
                  child: playerState.isPauseCountdown
                      ? CountdownChip(
                          remaining: playerState.pauseRemaining,
                          total: playerState.pauseDuration,
                          isPaused: playerState.isCountdownPaused,
                          onTap: () {
                            playerState.isCountdownPaused
                                ? player.resumeCountdown()
                                : player.pauseCountdown();
                          },
                        )
                      : playerState.isPlaying
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.headphones,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.s),
                                Text(
                                  l10n.blindListenListeningHint,
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : _isManualIdleState(playerState)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Text(
                                      l10n.blindListenRecallHint,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                ),
              ),

              const SizedBox(height: AppSpacing.m),

              // 底部控制栏
              ParagraphBottomControls(
                canGoPrev: playerState.currentParagraphIndex > 0,
                isLastParagraph: playerState.currentParagraphIndex >=
                    playerState.totalParagraphs - 1,
                centerIcon: playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onCenter:
                    playerState.isPlaying ? player.pause : player.resume,
                onPrevious: () => player.goToPreviousParagraph(),
                onNext: () {
                  final isLast = playerState.currentParagraphIndex >=
                      playerState.totalParagraphs - 1;
                  if (isLast) {
                    player.pause();
                    _handleCompleted();
                  } else {
                    player.goToNextParagraph();
                  }
                },
              ),

              // 遍数（手动模式隐藏）
              if (!playerState.settings.isManualMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
                    l10n.blindListenRepeatInfo(
                      playerState.currentRepeatCount,
                      playerState.settings.repeatCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
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


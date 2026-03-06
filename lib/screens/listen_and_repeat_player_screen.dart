/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/listen_and_repeat_player_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../models/retell_settings.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/retell/retell_briefing_sheet.dart';

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
    extends ConsumerState<ListenAndRepeatPlayerScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listenAndRepeatPlayerProvider.notifier).startPlaying();
    });
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
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

  /// 保存跟读断点进度
  Future<void> _saveSentenceProgress() async {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveShadowingSentenceIndex(widget.audioItemId, player.currentIndex);
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
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _FreePlayCompleteDialog(
          title: AppLocalizations.of(ctx)!.listenAndRepeatCompleteTitle,
          message: AppLocalizations.of(
            ctx,
          )!.listenAndRepeatCompleteMessage(playerState.totalSentences),
        ),
      );

      _isShowingDialog = false;
      if (!mounted) return;

      // 递增遍数（无论再来一遍还是完成，都算一遍）
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);

      if (result == true) {
        // 完成退出
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      } else {
        // 再来一遍：重置到第一句重新开始
        ref.read(listenAndRepeatPlayerProvider.notifier).resetToStart();
      }
      return;
    }

    final stepCtx = _getStepContext();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ListenAndRepeatCompleteDialog(
        totalSentences: playerState.totalSentences,
        stepIndex: stepCtx.stepIndex,
        totalSteps: stepCtx.totalSteps,
        stageName: stepCtx.stageName,
        nextStepName: stepCtx.nextStepName,
        isLastStep: stepCtx.isLastStep,
      ),
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
        debugPrint('跟读完成处理出错: $e');
      }

      if (result == true) {
        // 继续下一步：段级复述
        await _navigateToRetell();
      } else {
        // 返回计划页
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      }
    }
  }

  /// 导航到段级复述播放器
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

    // 监听完成状态
    ref.listen<ListenAndRepeatPlayerState>(listenAndRepeatPlayerProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
    });

    final currentSentence = player.currentSentence;

    // 句子时长（如 "3.5s"）和时间戳（如 "00:32.1 - 00:35.6"）分开传递，
    // 由 _ProgressSection 用不同样式渲染以建立视觉层级。
    final hasDuration =
        currentSentence != null && currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0).toStringAsFixed(
              1,
            ),
          )
        : null;
    final timestampText = hasDuration
        ? '${_formatTimestamp(currentSentence.startTime)}'
              ' - ${_formatTimestamp(currentSentence.endTime)}'
        : null;

    return PopScope(
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
              timestampText: timestampText,
            ),

            // 主体内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  children: [
                    // 句子卡片（带★标记）
                    Expanded(
                      child: SingleChildScrollView(
                        child: currentSentence != null
                            ? SentenceAnnotationCard(
                                text: currentSentence.text,
                                isDifficult: true,
                                onToggle: _handleRemoveDifficult,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // 跟读提示 / 倒计时控制（上） + 播放遍数（下）
                    SizedBox(
                      height: 96,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (playerState.isPauseBetweenPlays) ...[
                            // 跟读提示
                            Text(
                              l10n.listenAndRepeatYourTurnHint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _CountdownChip(
                              remaining: playerState.pauseRemaining,
                              total: playerState.pauseDuration,
                              isPaused: playerState.isCountdownPaused,
                              onTap: playerState.isCountdownPaused
                                  ? () => player.resumeCountdown()
                                  : () => player.pauseCountdown(),
                            ),
                          ],
                          // 播放中：先听提示 / 留白期：跟读提示
                          if (!playerState.isPauseBetweenPlays)
                            Text(
                              l10n.listenAndRepeatListenHint,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.listenAndRepeatPlayCount(
                              playerState.currentPlayCount,
                              playerState.settings.repeatCount,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部播放控制
            _PlaybackControls(
              playerState: playerState,
              onPrevious: () => player.goToPrevious(),
              onNext: () => player.goToNext(),
              onPlayPause: () {
                if (playerState.isPauseBetweenPlays) {
                  player.replayDuringCountdown();
                } else if (playerState.isPlaying) {
                  player.pause();
                } else {
                  player.resume();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final ListenAndRepeatPlayerState playerState;
  final AppLocalizations l10n;

  /// 句子时长文本（如 "3.5s"），为 null 时不显示
  final String? durationText;

  /// 句子时间戳文本（如 "00:11.6 - 00:22.5"），为 null 时不显示
  final String? timestampText;

  const _ProgressSection({
    required this.playerState,
    required this.l10n,
    this.durationText,
    this.timestampText,
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
    // 时间戳：更小字号 + 半透明，视觉退后
    final timestampStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              if (timestampText case final ts?) ...[
                const SizedBox(width: 6),
                Text(ts, style: timestampStyle),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 倒计时控制按钮
///
/// 圆形按钮，外围带进度环，内部显示暂停/恢复图标，右侧显示秒数。
class _CountdownChip extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final bool isPaused;
  final VoidCallback onTap;

  const _CountdownChip({
    required this.remaining,
    required this.total,
    required this.isPaused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${seconds}s',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 2.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  valueColor: AlwaysStoppedAnimation(
                    theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
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
    final canGoNext =
        playerState.currentSentenceIndex < playerState.totalSentences - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.xs,
        AppSpacing.l,
        AppSpacing.l,
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

/// 跟读完成对话框 — 双按钮（返回计划 / 继续下一步）
class _ListenAndRepeatCompleteDialog extends StatelessWidget {
  final int totalSentences;
  final int stepIndex;
  final int totalSteps;
  final String stageName;
  final String? nextStepName;
  final bool isLastStep;

  const _ListenAndRepeatCompleteDialog({
    required this.totalSentences,
    required this.stepIndex,
    required this.totalSteps,
    required this.stageName,
    this.nextStepName,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(l10n.listenAndRepeatCompleteTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.stepProgressLabel(stepIndex + 1, totalSteps, stageName),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.listenAndRepeatCompleteMessage(totalSentences),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: _buildActions(context, l10n),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    if (nextStepName != null) {
      return [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.backToPlan),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.continueToStep(nextStepName!)),
              ),
            ),
          ],
        ),
      ];
    } else if (isLastStep) {
      final l10nCtx = AppLocalizations.of(context)!;
      final isFirstStudy =
          stageName == l10nCtx.firstStudy ||
          stageName == LearningStage.firstLearn.label;
      final completeText = isFirstStudy
          ? l10n.completeFirstStudy
          : l10n.completeReview;

      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(completeText),
          ),
        ),
      ];
    } else {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.backToPlan),
          ),
        ),
      ];
    }
  }
}

/// 自由练习完成对话框
///
/// 显示完成标题和消息，提供「完成」和「再来一遍」两个操作按钮。
/// 返回 `true` 表示完成退出，`false` 表示再来一遍。
class _FreePlayCompleteDialog extends StatelessWidget {
  final String title;
  final String message;

  const _FreePlayCompleteDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Flexible(child: Text(title)),
          ],
        ),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.done),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.listenAgain),
                ),
              ),
            ],
          ),
        ],
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

/// 格式化时间戳为 MM:SS.m 格式（如 01:02.3）
///
/// 仅保留十分之一秒精度，减少视觉噪音。
/// 超过 1 小时时显示 H:MM:SS.m（如 1:02:30.5）。
String _formatTimestamp(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final tenths = (d.inMilliseconds % 1000) ~/ 100;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss.$tenths';
  }
  return '$mm:$ss.$tenths';
}

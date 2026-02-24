/// 精听播放器页面
///
/// 逐句精听界面，支持普通模式（文字遮盖）、标注模式（揭示文本）、
/// 标注重播模式（带字幕重播）。
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
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_briefing_sheet.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';

/// 精听播放器页面
class IntensiveListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const IntensiveListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<IntensiveListenPlayerScreen> createState() =>
      _IntensiveListenPlayerScreenState();
}

class _IntensiveListenPlayerScreenState
    extends ConsumerState<IntensiveListenPlayerScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(intensiveListenPlayerProvider.notifier).startPlaying();
    });
  }

  /// 处理退出（close 按钮 / 系统返回）
  ///
  /// 自由练习模式直接退出；正常学习模式弹出确认对话框，
  /// 确认后保存断点和难句，再退出。
  Future<void> _handleExit() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
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
        title: Text(l10n.exitIntensiveListenTitle),
        content: Text(l10n.exitIntensiveListenMessage),
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
      // 用户取消退出 → 恢复播放（标注模式下不恢复，保持暂停状态）
      if (mounted) {
        final currentState = ref.read(intensiveListenPlayerProvider);
        if (!currentState.isAnnotationMode) {
          player.resume();
        }
      }
      return;
    }

    // 保存断点 + 难句 + 难句数快照
    await _saveSentenceProgress();
    await _saveDifficultSentences();

    final playerState = ref.read(intensiveListenPlayerProvider);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultCount(
          widget.audioItemId,
          playerState.difficultSentences.length,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 保存精听断点进度
  Future<void> _saveSentenceProgress() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveIntensiveListenSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
        );
  }

  /// 保存难句书签到数据库
  Future<void> _saveDifficultSentences() async {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final bookmarkDao = ref.read(bookmarkDaoProvider);

    for (final index in playerState.difficultSentences) {
      if (index < player.sentences.length) {
        final sentence = player.sentences[index];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    }
  }

  /// 进入难句跟读模式
  ///
  /// 精听完成后调用，读取难句书签并进入跟读。
  /// 0 个难句时显示 SnackBar 提示并 pop 回计划页。
  void _startListenAndRepeat() {
    final l10n = AppLocalizations.of(context)!;
    final lpState = ref.read(listeningPracticeProvider);

    if (lpState.sentences.isEmpty) {
      context.pop();
      return;
    }

    // 读取难句书签数量（用于 briefing sheet）
    final playerState = ref.read(intensiveListenPlayerProvider);
    final difficultCount = playerState.difficultSentences.length;

    if (difficultCount == 0) {
      // 无难句 → 跳过跟读，回到计划页
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listenAndRepeatNoDifficultSentences)),
      );
      context.pop();
      return;
    }

    showListenAndRepeatBriefingSheet(
      context: context,
      difficultCount: difficultCount,
      playCount: 3, // 默认遍数（实际由难度决定，此处为预览估值）
      onStartPractice: () async {
        await ref
            .read(learningSessionProvider.notifier)
            .enterListenAndRepeatMode(
              widget.audioItemId,
              lpState.sentences,
            );
        if (mounted) {
          context.pushReplacement(
            AppRoutes.listenAndRepeatPlayer(
              widget.collectionId,
              widget.audioItemId,
            ),
          );
        }
      },
    );
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
      final idx = subStages.indexOf(SubStageType.intensiveListen);
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

    // 判断下一步是否有播放器
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
  ///
  /// 弹出完成对话框，支持双按钮："返回计划"和"继续下一步"。
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(intensiveListenPlayerProvider);

    // 保存难句书签
    await _saveDifficultSentences();

    if (!mounted) {
      _isShowingDialog = false;
      return;
    }

    // 自由练习模式：保存难句数 + 递增遍数 → 退出
    if (session.isFreePlay) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(
            widget.audioItemId,
            playerState.difficultSentences.length,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      _isShowingDialog = false;
      if (mounted) context.pop();
      return;
    }

    final stepCtx = _getStepContext();

    // continueToNext: true = 继续, false = 返回计划, null = 对话框未响应
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _IntensiveListenCompleteDialog(
        totalSentences: playerState.totalSentences,
        difficultCount: playerState.difficultSentences.length,
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
        // 保存精听统计（难句数快照 + 递增总遍数）
        final stats = ref.read(intensiveListenPlayerProvider);
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveDifficultCount(
              widget.audioItemId,
              stats.difficultSentences.length,
            );
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .incrementIntensiveListenPassCount(widget.audioItemId);

        // 清除断点（已完成）
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveIntensiveListenSentenceIndex(widget.audioItemId, null);

        // 推进子步骤
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      } catch (e) {
        debugPrint('精听完成处理出错: $e');
      }

      if (result == true) {
        // 继续下一步 → 进入难句跟读
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) {
          _startListenAndRepeat();
        }
      } else {
        // 返回计划页
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

    // 监听完成状态
    ref.listen<IntensiveListenState>(intensiveListenPlayerProvider, (
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
    final hasDuration = currentSentence != null &&
        currentSentence.duration > Duration.zero;
    final durationText = hasDuration
        ? l10n.sentenceDuration(
            (currentSentence.duration.inMilliseconds / 1000.0)
                .toStringAsFixed(1),
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
          title: Text(l10n.intensiveListenAppBarTitle),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.intensiveListenSettings,
              onPressed: () {
                showIntensiveListenSettingsSheet(context: context);
              },
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerState.isAnnotationReplay
                    ? _AnnotationReplayView(
                        key: const ValueKey('replay'),
                        text: currentSentence?.text ?? '',
                        l10n: l10n,
                      )
                    : playerState.isAnnotationMode
                    ? _AnnotationModeView(
                        key: const ValueKey('annotation'),
                        text: currentSentence?.text ?? '',
                        isDifficult: playerState.difficultSentences.contains(
                          playerState.currentSentenceIndex,
                        ),
                        l10n: l10n,
                        onContinue: () => player.exitAnnotationMode(),
                        onToggleDifficult: () =>
                            player.toggleDifficultSentence(),
                      )
                    : _NormalModeView(
                        key: const ValueKey('normal'),
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeek: () => player.toggleTextReveal(),
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        sentenceText: currentSentence?.text,
                      ),
              ),
            ),

            // 底部播放控制
            _PlaybackControls(
              playerState: playerState,
              onPrevious: () => player.goToPrevious(),
              onNext: () => player.goToNext(),
              onPlayPause: () {
                if (playerState.isAnnotationMode) {
                  player.replayInAnnotationMode();
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
  final IntensiveListenState playerState;
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
                l10n.intensiveListenProgress(current, total),
                style: subtitleStyle,
              ),
              const Spacer(),
              if (durationText case final dur?)
                Text(dur, style: subtitleStyle),
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

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeek;
  final VoidCallback onCantUnderstand;
  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeek,
    required this.onCantUnderstand,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

          // 固定高度区域：播放遍数 或 间隔倒计时
          SizedBox(
            height: 64,
            child: Center(
              child: playerState.isPauseBetweenPlays
                  ? _PauseCountdownIndicator(
                      remaining: playerState.pauseRemaining,
                      total: playerState.pauseDuration,
                      isBetweenSentences: playerState.isPauseBetweenSentences,
                      l10n: l10n,
                    )
                  : Text(
                      l10n.intensiveListenPlayCount(
                        playerState.currentPlayCount,
                        playerState.settings.repeatCount,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // 操作按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onPeek,
                icon: Icon(
                  playerState.isTextRevealed
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                label: Text(
                  playerState.isTextRevealed
                      ? l10n.intensiveListenHideSubtitle
                      : l10n.intensiveListenPeek,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              FilledButton.tonal(
                onPressed: onCantUnderstand,
                child: Text(l10n.intensiveListenCantUnderstand),
              ),
            ],
          ),
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
        // 占位灰色线条
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

/// 间隔倒计时指示器
class _PauseCountdownIndicator extends StatelessWidget {
  final Duration remaining;
  final Duration total;

  /// 是否是句间停顿（true=下一句，false=下一遍）
  final bool isBetweenSentences;
  final AppLocalizations l10n;

  const _PauseCountdownIndicator({
    required this.remaining,
    required this.total,
    required this.isBetweenSentences,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = total.inMilliseconds;
    final remainingMs = remaining.inMilliseconds;
    final progress = totalMs > 0 ? 1.0 - (remainingMs / totalMs) : 1.0;
    final seconds = (remainingMs / 1000).ceil();

    final label = isBetweenSentences
        ? l10n.intensiveListenPauseBetweenSentences(seconds)
        : l10n.intensiveListenPauseBetweenPlays(seconds);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// 标注模式视图
class _AnnotationModeView extends StatelessWidget {
  final String text;
  final bool isDifficult;
  final AppLocalizations l10n;
  final VoidCallback onContinue;
  final VoidCallback onToggleDifficult;

  const _AnnotationModeView({
    super.key,
    required this.text,
    required this.isDifficult,
    required this.l10n,
    required this.onContinue,
    required this.onToggleDifficult,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SentenceAnnotationCard(
                text: text,
                isDifficult: isDifficult,
                onToggle: onToggleDifficult,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(l10n.intensiveListenContinue),
            ),
          ),
        ],
      ),
    );
  }
}

/// 标注重播模式视图（带字幕重播中）
class _AnnotationReplayView extends StatelessWidget {
  final String text;
  final AppLocalizations l10n;

  const _AnnotationReplayView({
    super.key,
    required this.text,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 显示句子文本
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.l),

            // 播放中指示器
            CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.intensiveListenReplayingWithSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部播放控制
class _PlaybackControls extends StatelessWidget {
  final IntensiveListenState playerState;
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

    // 标注重播模式下播放按钮禁用（自动播放中，不应干预）
    final isPlayDisabled = playerState.isAnnotationReplay;

    // 上一句/下一句：标注模式和标注重播模式下都禁用
    final isNavDisabled =
        playerState.isAnnotationMode || playerState.isAnnotationReplay;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一句
          IconButton(
            onPressed: isNavDisabled || playerState.currentSentenceIndex <= 0
                ? null
                : onPrevious,
            icon: const Icon(Icons.skip_previous, size: 32),
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: AppSpacing.l),

          // 播放/暂停
          GestureDetector(
            onTap: isPlayDisabled ? null : onPlayPause,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isPlayDisabled
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: isPlayDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: isPlayDisabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),

          // 下一句
          IconButton(
            onPressed:
                isNavDisabled ||
                    playerState.currentSentenceIndex >=
                        playerState.totalSentences - 1
                ? null
                : onNext,
            icon: const Icon(Icons.skip_next, size: 32),
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

/// 精听完成对话框 — 双按钮（返回计划 / 继续下一步）
///
/// 返回 true 表示"继续下一步"，false 表示"返回计划"。
class _IntensiveListenCompleteDialog extends StatelessWidget {
  final int totalSentences;
  final int difficultCount;
  final int stepIndex;
  final int totalSteps;
  final String stageName;
  final String? nextStepName;
  final bool isLastStep;

  const _IntensiveListenCompleteDialog({
    required this.totalSentences,
    required this.difficultCount,
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
            Flexible(child: Text(l10n.intensiveListenCompleteTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步骤进度
            Text(
              l10n.stepProgressLabel(stepIndex + 1, totalSteps, stageName),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            // 完成统计
            Text(
              l10n.intensiveListenCompleteMessage(totalSentences, difficultCount),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        // 底部操作按钮（返回计划 + 继续 同一行）
        actions: _buildActions(context, l10n),
      ),
    );
  }

  /// 构建底部操作按钮
  ///
  /// 三种情况：
  /// 1. 有下一步可继续：[返回计划 Outlined] [继续：X Filled] 同一行
  /// 2. 末步骤：[完成首学/复习 Filled]（全宽）
  /// 3. 非末步骤但下一步不可用：[返回计划 Filled]（全宽）
  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    if (nextStepName != null) {
      // 情况 1：有下一步可继续 — 返回计划（左） + 继续（右）
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
      // 情况 2：末步骤 — 完成按钮全宽
      final l10nCtx = AppLocalizations.of(context)!;
      final isFirstStudy = stageName == l10nCtx.firstStudy ||
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
      // 情况 3：非末步骤但下一步不可用 — 返回计划全宽
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

/// 判断子步骤是否有专用播放器页面
bool _hasPlayerScreen(SubStageType type) => switch (type) {
  SubStageType.blindListen => true,
  SubStageType.intensiveListen => true,
  SubStageType.listenAndRepeat => true,
  SubStageType.retell => false,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
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

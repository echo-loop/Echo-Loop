/// 复述播放器页面
///
/// 段级复述的核心交互页面。
/// 布局: AppBar → 进度条 → 句子列表 → 阶段指示器 → 底部控制。
/// 支持 listening/retelling 双阶段切换、显示模式循环、倒计时跳过。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/retell/retell_sentence_tile.dart';
import '../widgets/retell/retell_settings_sheet.dart';

/// 复述播放器页面
class RetellPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（独立音频路由时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  const RetellPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
  });

  @override
  ConsumerState<RetellPlayerScreen> createState() => _RetellPlayerScreenState();
}

class _RetellPlayerScreenState extends ConsumerState<RetellPlayerScreen> {
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(retellPlayerProvider.notifier).startPlaying();
    });
  }

  /// 格式化时长（纯秒数 + 单位）
  String _formatDuration(Duration d) {
    return '${d.inSeconds}s';
  }

  /// 处理退出
  Future<void> _handleExit() async {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final state = ref.read(retellPlayerProvider);

    // 已完成或自由练习模式直接退出
    if (state.isCompleted || sessionState.isFreePlay) {
      await _exit();
      return;
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.retellExitConfirmTitle),
        content: Text(l10n.retellExitConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 保存断点（存当前段落第一句的全局索引，分段无关）
      final sentenceIndex = ref
          .read(retellPlayerProvider.notifier)
          .currentParagraphFirstSentenceIndex;
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(widget.audioItemId, sentenceIndex);
      await _exit();
    }
  }

  /// 执行退出
  Future<void> _exit() async {
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息（步骤序号、总步骤数、阶段名称）
  ({int stepIndex, int totalSteps, String stageName}) _getStepContext() {
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    if (progress == null) {
      final subStages = LearningStage.firstLearn.subStages;
      final idx = subStages.indexOf(SubStageType.retell);
      return (
        stepIndex: idx,
        totalSteps: subStages.length,
        stageName: LearningStage.firstLearn.label,
      );
    }

    final stage = progress.currentStage;
    final subStages = stage.subStages;
    final currentIdx = subStages.indexOf(progress.currentSubStage);
    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: stage.label,
    );
  }

  /// 处理完成
  ///
  /// 弹出完成对话框，提供"再来一遍"和"完成/返回"两个操作。
  /// 步骤完成标记推迟到用户确认后才执行。
  Future<void> _handleComplete() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final retellState = ref.read(retellPlayerProvider);
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    // 确定完成按钮文案
    final String completeButtonText;
    if (sessionState.isFreePlay) {
      completeButtonText = l10n.retellCompleteFreePlay;
    } else if (progress?.currentStage == LearningStage.firstLearn) {
      completeButtonText = l10n.retellCompleteFirstStudy;
    } else {
      completeButtonText = l10n.retellCompleteReview;
    }

    // 获取步骤上下文
    final stepCtx = sessionState.isFreePlay ? null : _getStepContext();

    // 弹出完成对话框：true = 完成退出, null = 再来一遍
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RetellCompleteDialog(
        completeButtonText: completeButtonText,
        totalParagraphs: retellState.totalParagraphs,
        stepIndex: stepCtx?.stepIndex,
        totalSteps: stepCtx?.totalSteps,
        stageName: stepCtx?.stageName,
      ),
    );

    _isShowingDialog = false;
    if (!mounted) return;

    // 递增复述遍数（无论再来一遍还是完成，都算一遍）
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementRetellPassCount(widget.audioItemId);

    if (result == true) {
      // 完成退出
      if (!sessionState.isFreePlay) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .completeCurrentSubStage(widget.audioItemId);
      }
      await _exit();
    } else {
      // 再来一遍：重置到第一段
      await ref.read(retellPlayerProvider.notifier).restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final player = ref.read(retellPlayerProvider.notifier);

    // 监听完成状态
    ref.listen<RetellPlayerState>(retellPlayerProvider, (prev, next) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleComplete();
      }
    });

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final keywords = player.keywordsMap;
    final progress = (state.totalParagraphs > 0)
        ? (state.currentParagraphIndex + 1) / state.totalParagraphs
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.retellTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleExit,
          ),
          actions: [
            // 设置按钮
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () => showRetellSettingsSheet(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // 进度条
            LinearProgressIndicator(value: progress),

            // 段落进度文字
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.retellParagraphProgress(
                      state.currentParagraphIndex + 1,
                      state.totalParagraphs,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    l10n.retellParagraphDuration(
                      _formatDuration(paragraphDuration),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 显示模式切换（仅当前段落生效，可见词关闭时隐藏）
            if (state.settings.keywordMethod != KeywordMethod.off)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: SegmentedButton<RetellDisplayMode>(
                  segments: [
                    ButtonSegment(
                      value: RetellDisplayMode.keywordsOnly,
                      label: Text(l10n.retellDisplayKeywordsOnly),
                    ),
                    ButtonSegment(
                      value: RetellDisplayMode.showAll,
                      label: Text(l10n.retellDisplayShowAll),
                    ),
                    ButtonSegment(
                      value: RetellDisplayMode.hideAll,
                      label: Text(l10n.retellDisplayHideAll),
                    ),
                  ],
                  selected: {state.displayMode},
                  onSelectionChanged: (selected) =>
                      player.setDisplayMode(selected.first),
                ),
              ),
            const SizedBox(height: AppSpacing.s),

            // 句子列表
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                  itemCount: sentences.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: AppSpacing.m,
                    endIndent: AppSpacing.m,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    // 使用句子的全局索引来查找关键词
                    final sentenceKeywords =
                        keywords[sentence.index] ?? const {};

                    return RetellSentenceTile(
                      sentence: sentence,
                      phase: state.phase,
                      displayMode:
                          state.settings.keywordMethod != KeywordMethod.off
                          ? state.displayMode
                          : RetellDisplayMode.hideAll,
                      keywordIndices: sentenceKeywords,
                      isPlayingSentence:
                          state.phase == RetellPhase.listening &&
                          index == state.playingSentenceIndex,
                      onWordTap: (word) =>
                          showWordDictionarySheet(context: context, word: word),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.s),

            // 阶段指示器 + 倒计时控制
            _PhaseIndicator(
              state: state,
              l10n: l10n,
              onPauseResume: state.isCountdownPaused
                  ? () => player.resumeCountdown()
                  : () => player.pauseCountdown(),
            ),

            const SizedBox(height: AppSpacing.m),

            // 底部控制
            _BottomControls(state: state, player: player, l10n: l10n),

            const SizedBox(height: AppSpacing.l),
          ],
        ),
      ),
    );
  }
}

/// 阶段指示器：listening/retelling 状态
class _PhaseIndicator extends StatelessWidget {
  final RetellPlayerState state;
  final AppLocalizations l10n;
  final VoidCallback onPauseResume;

  const _PhaseIndicator({
    required this.state,
    required this.l10n,
    required this.onPauseResume,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // listening 阶段，固定高度与 retelling 阶段一致，避免切换时跳动
    if (state.phase == RetellPhase.listening) {
      return SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  l10n.retellListeningPhase,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (state.settings.repeatCount > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.retellRepeatInfo(
                  state.currentRepeatCount,
                  state.settings.repeatCount,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // retelling 阶段：倒计时控制（上） + 提示文字（下）
    return SizedBox(
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (state.isRetellCountdown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _CountdownChip(
                remaining: state.pauseRemaining,
                total: state.pauseDuration,
                isPaused: state.isCountdownPaused,
                onTap: onPauseResume,
              ),
            ),
          Text(
            l10n.retellRetellingCountdown(
              (state.pauseRemaining.inMilliseconds / 1000).ceil(),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
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

/// 底部控制栏
///
/// 布局：[上一段] --- [播放/暂停] --- [下一段]
class _BottomControls extends StatelessWidget {
  final RetellPlayerState state;
  final RetellPlayer player;
  final AppLocalizations l10n;

  const _BottomControls({
    required this.state,
    required this.player,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoPrev = state.currentParagraphIndex > 0;
    final canGoNext = state.currentParagraphIndex < state.totalParagraphs - 1;

    // 中间大按钮
    final IconData centerIcon;
    final VoidCallback centerOnPressed;
    if (state.phase == RetellPhase.listening) {
      centerIcon = state.isPlaying
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded;
      centerOnPressed = state.isPlaying ? player.pause : player.resume;
    } else if (state.isRetellCountdown) {
      centerIcon = Icons.play_arrow_rounded;
      centerOnPressed = player.replayDuringCountdown;
    } else {
      centerIcon = Icons.play_arrow_rounded;
      centerOnPressed = player.resume;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            enabled: canGoPrev,
            onTap: canGoPrev ? player.goToPreviousParagraph : null,
          ),
          const SizedBox(width: 48),

          GestureDetector(
            onTap: centerOnPressed,
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
                centerIcon,
                size: 28,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),

          _NavButton(
            icon: Icons.skip_next_rounded,
            enabled: canGoNext,
            onTap: canGoNext ? player.goToNextParagraph : null,
          ),
        ],
      ),
    );
  }
}

/// 导航按钮（上一段/下一段）
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

/// 复述完成对话框
///
/// 布局与精听/跟读完成对话框保持一致：
/// 标题行（Icon + 文本）→ 内容区（步骤进度 + 统计）→ 底部按钮区。
/// 返回 true = 完成退出，返回 null = 再来一遍。
class _RetellCompleteDialog extends StatelessWidget {
  final String completeButtonText;
  final int totalParagraphs;
  final int? stepIndex;
  final int? totalSteps;
  final String? stageName;

  const _RetellCompleteDialog({
    required this.completeButtonText,
    required this.totalParagraphs,
    this.stepIndex,
    this.totalSteps,
    this.stageName,
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
            Flexible(child: Text(l10n.retellCompleteTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步骤进度（非自由练习模式）
            if (stepIndex != null && totalSteps != null && stageName != null)
              Text(
                l10n.stepProgressLabel(stepIndex! + 1, totalSteps!, stageName!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (stepIndex != null) const SizedBox(height: AppSpacing.s),
            // 完成统计
            Text(
              l10n.retellCompleteMessage(totalParagraphs),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.retellPracticeAgain),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(completeButtonText),
            ),
          ),
        ],
      ),
    );
  }
}

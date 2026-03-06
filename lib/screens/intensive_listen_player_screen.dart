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
      if (mounted) context.pop();
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
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

    final totalDifficultCount = await _loadTotalDifficultCount();
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultCount(widget.audioItemId, totalDifficultCount);

    // 先 pop 页面，再 exitLearningMode（dispose 会重置 state，
    // 若先 dispose 再 pop 会导致星标状态闪烁）
    if (mounted) context.pop();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
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

  /// 获取当前音频的难句总数（以数据库书签为准）
  ///
  /// 该值代表“全部已标记难句”，而非“本次会话临时集合”。
  Future<int> _loadTotalDifficultCount() async {
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    final bookmarks = await bookmarkDao.getByAudioId(widget.audioItemId);
    return bookmarks.length;
  }

  /// 切换难句标记并即时持久化到数据库
  ///
  /// 先切换内存状态，再根据新状态决定新增或移除书签，
  /// 最后同步难句数快照到 learning_progress。
  Future<void> _toggleAndSaveDifficult() async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final playerState = ref.read(intensiveListenPlayerProvider);
    final idx = playerState.currentSentenceIndex;

    // 1. 切换内存状态
    player.toggleDifficultSentence();

    // 2. 读取切换后的状态，判断是新增还是移除
    final newState = ref.read(intensiveListenPlayerProvider);
    final isNowDifficult = newState.difficultSentences.contains(idx);

    // 3. 即时持久化到 DB
    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (isNowDifficult) {
      if (idx < player.sentences.length) {
        final sentence = player.sentences[idx];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    } else {
      await bookmarkDao.removeBookmark(
        widget.audioItemId,
        player.sentences[idx].index,
      );
    }

    // 4. 同步难句数快照到 learning_progress（以数据库总量为准）
    final totalDifficultCount = await _loadTotalDifficultCount();
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultCount(widget.audioItemId, totalDifficultCount);
  }

  /// 保存难句书签到数据库（增量同步：新增 + 移除）
  ///
  /// 对比初始书签状态与当前 difficultSentences，
  /// 新标记的添加到数据库，取消标记的从数据库移除。
  Future<void> _saveDifficultSentences() async {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final bookmarkDao = ref.read(bookmarkDaoProvider);

    // 初始书签集合（深拷贝句子保留了原始 isBookmarked）
    final initialBookmarks = <int>{
      for (final s in player.sentences)
        if (s.isBookmarked) s.index,
    };

    // 新增的难句书签
    final added = playerState.difficultSentences.difference(initialBookmarks);
    for (final index in added) {
      if (index < player.sentences.length) {
        final sentence = player.sentences[index];
        await BookmarkManager.addBookmarkToDb(
          widget.audioItemId,
          sentence,
          dao: bookmarkDao,
        );
      }
    }

    // 取消标记的书签
    final removed = initialBookmarks.difference(playerState.difficultSentences);
    if (removed.isNotEmpty) {
      await BookmarkManager.removeBookmarksFromDb(
        widget.audioItemId,
        removed,
        dao: bookmarkDao,
      );
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

    _loadTotalDifficultCount().then((difficultCount) {
      if (!mounted) return;

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
              .enterListenAndRepeatMode(widget.audioItemId, lpState.sentences);
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
    });
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
    final totalDifficultCount = await _loadTotalDifficultCount();

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
          title: AppLocalizations.of(ctx)!.intensiveListenCompleteTitle,
          message: AppLocalizations.of(ctx)!.intensiveListenCompleteMessage(
            playerState.totalSentences,
            totalDifficultCount,
          ),
        ),
      );

      _isShowingDialog = false;
      if (!mounted) return;

      // 无论选择什么，都保存统计并递增遍数
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);

      if (result == true) {
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
        if (mounted) context.pop();
      } else {
        // 再来一遍：resetToStart()，保留已标记难句
        ref.read(intensiveListenPlayerProvider.notifier).resetToStart();
      }
      return;
    }

    final stepCtx = _getStepContext();

    // continueToNext: true = 继续, false = 返回计划, null = 对话框未响应
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _IntensiveListenCompleteDialog(
        totalSentences: playerState.totalSentences,
        difficultCount: totalDifficultCount,
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
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveDifficultCount(widget.audioItemId, totalDifficultCount);
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
          title: Text(l10n.intensiveListenAppBarTitle),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleExit,
          ),
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
                        onToggleDifficult: _toggleAndSaveDifficult,
                      )
                    : _NormalModeView(
                        key: const ValueKey('normal'),
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeekStart: () => player.setTextRevealed(true),
                        onPeekEnd: () => player.setTextRevealed(false),
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        onToggleDifficult: _toggleAndSaveDifficult,
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
              onPrevious: () => player.goToPrevious(),
              onNext: () => player.goToNext(),
              onPlayPause: () {
                if (playerState.isAnnotationMode) {
                  player.replayInAnnotationMode();
                } else if (playerState.isPauseBetweenPlays) {
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

/// 普通模式视图（文字遮盖 / 偷看）
class _NormalModeView extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekStart;
  final VoidCallback onPeekEnd;
  final VoidCallback onCantUnderstand;

  /// 取消难句标记回调
  final VoidCallback onToggleDifficult;

  /// 倒计时暂停/恢复回调
  final VoidCallback onPauseCountdown;

  final String? sentenceText;

  const _NormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekStart,
    required this.onPeekEnd,
    required this.onCantUnderstand,
    required this.onToggleDifficult,
    required this.onPauseCountdown,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    final isDifficult = playerState.difficultSentences.contains(
      playerState.currentSentenceIndex,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句标记行
          GestureDetector(
            onTap: onToggleDifficult,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    isDifficult
                        ? l10n.intensiveListenMarkedDifficult
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.star : Icons.star_border,
                  color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                  size: 18,
                ),
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

          // 倒计时控制（上） + 播放遍数（下），固定高度避免跳动
          SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (playerState.isPauseBetweenPlays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _CountdownChip(
                      remaining: playerState.pauseRemaining,
                      total: playerState.pauseDuration,
                      isPaused: playerState.isCountdownPaused,
                      onTap: onPauseCountdown,
                    ),
                  ),
                Text(
                  l10n.intensiveListenPlayCount(
                    playerState.currentPlayCount,
                    playerState.settings.repeatCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),

          // 偷看/听不懂按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Listener(
                onPointerDown: (_) => onPeekStart(),
                onPointerUp: (_) => onPeekEnd(),
                onPointerCancel: (_) => onPeekEnd(),
                child: _ActionChip(
                  icon: Icons.visibility_outlined,
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

/// 倒计时控制按钮
///
/// 圆形按钮，外围带进度环，内部显示暂停/恢复图标，右侧显示秒数。
/// 点击可暂停/恢复倒计时。
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
          // 秒数文字
          Text(
            '${seconds}s',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          // 带进度环的圆形按钮（居中）
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

/// 操作按钮（偷看字幕 / 听不懂）
///
/// 统一的轻量胶囊样式，浅色背景 + 小图标 + 文字。
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

    final isPlayDisabled = playerState.isAnnotationReplay;
    final isNavDisabled = playerState.isAnnotationReplay;

    final canGoPrev = !isNavDisabled && playerState.currentSentenceIndex > 0;
    final canGoNext =
        !isNavDisabled &&
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

          // 播放/暂停
          GestureDetector(
            onTap: isPlayDisabled ? null : onPlayPause,
            child: Container(
              width: 56,
              height: 56,
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
                            alpha: 0.15,
                          ),
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
                color: isPlayDisabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimary,
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
///
/// 无背景图标，禁用态降低透明度。
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 0.6 : 0.15,
        duration: const Duration(milliseconds: 150),
        child: Icon(icon, size: 32, color: theme.colorScheme.onSurface),
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
              l10n.intensiveListenCompleteMessage(
                totalSentences,
                difficultCount,
              ),
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

/// 精听自由练习完成对话框
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
  SubStageType.reviewDifficultPractice => false,
  SubStageType.reviewRetellParagraph => false,
  SubStageType.reviewRetellSummary => false,
};

/// 获取子步骤的本地化名称
String _getSubStageName(SubStageType type, AppLocalizations l10n) =>
    switch (type) {
      SubStageType.blindListen => l10n.stepBlindListening,
      SubStageType.intensiveListen => l10n.stepIntensiveListening,
      SubStageType.listenAndRepeat => l10n.stepShadowing,
      SubStageType.retell => l10n.stepRetelling,
      SubStageType.reviewDifficultPractice => 'Difficult practice',
      SubStageType.reviewRetellParagraph => 'Paragraph retelling',
      SubStageType.reviewRetellSummary => 'Summary retelling',
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

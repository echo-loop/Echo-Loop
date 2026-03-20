/// 精听播放器页面
///
/// 逐句精听界面，支持普通模式（文字遮盖）和“听不懂”后的详情模式。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
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
import '../providers/sentence_ai_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/retell/retell_briefing_sheet.dart';
import '../models/retell_settings.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';

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
    extends ConsumerState<IntensiveListenPlayerScreen>
    with WakelockMixin {
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

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
    _isExiting = true;
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await _saveSentenceProgress();

      // 保存难句书签 + 难句数快照（与非 freePlay 路径一致）
      await _saveDifficultSentences();
      final totalDifficultCount = await _loadTotalDifficultCount();
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);

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
      _isExiting = false;
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

    // 先 exitLearningMode 同步书签到 LP，再 pop 页面
    // （pop 后 widget 销毁，ref.read 可能失效）
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

    // 初始书签集合 — 使用位置索引，与 difficultSentences 保持一致
    final initialBookmarks = <int>{
      for (final (i, s) in player.sentences.indexed)
        if (s.isBookmarked) i,
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

    // 取消标记的书签 — 位置索引转换为句子索引后传给 DB
    final removedPositions = initialBookmarks.difference(
      playerState.difficultSentences,
    );
    if (removedPositions.isNotEmpty) {
      final removedSentenceIndices = <int>{
        for (final pos in removedPositions)
          if (pos < player.sentences.length) player.sentences[pos].index,
      };
      await BookmarkManager.removeBookmarksFromDb(
        widget.audioItemId,
        removedSentenceIndices,
        dao: bookmarkDao,
      );
    }
  }

  /// 进入难句跟读模式
  ///
  /// 精听完成后调用，读取难句书签并进入跟读。
  /// 0 个难句时显示 SnackBar 提示并 pop 回计划页。
  Future<void> _startListenAndRepeat() async {
    final l10n = AppLocalizations.of(context)!;
    final lpState = ref.read(listeningPracticeProvider);

    if (lpState.sentences.isEmpty) {
      context.pop();
      return;
    }

    final difficultCount = await _loadTotalDifficultCount();
    if (!mounted) return;

    if (difficultCount == 0) {
      // 无难句 → 自动完成跟读，推进到复述
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listenAndRepeatNoDifficultSentences)),
      );
      // 退出精听模式后导航到段落复述
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (!mounted) return;
      _navigateToRetell();
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
  }

  /// 导航到段落复述（跳过跟读后使用）
  void _navigateToRetell() {
    final lpState = ref.read(listeningPracticeProvider);
    if (lpState.sentences.isEmpty) {
      context.pop();
      return;
    }

    showRetellBriefingSheet(
      context: context,
      sentences: lpState.sentences,
      defaultSeconds: retellDefaultSeconds(LearningStage.firstLearn),
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
            .enterRetellMode(widget.audioItemId, paragraphs, keywordsMap);
        if (mounted) {
          context.pushReplacement(
            AppRoutes.retellPlayer(widget.collectionId, widget.audioItemId),
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
    if (_isExiting || !mounted) return;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(intensiveListenPlayerProvider);

    // 保存难句书签
    await _saveDifficultSentences();
    final totalDifficultCount = await _loadTotalDifficultCount();

    if (!mounted) return;

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      // 弹窗前保存统计并递增遍数
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.intensiveListenCompleteTitle,
        message: l10n.intensiveListenCompleteMessage(
          playerState.totalSentences,
          totalDifficultCount,
        ),
        onStudyAgain: () async {
          ref.read(intensiveListenPlayerProvider.notifier).resetToStart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveIntensiveListenSentenceIndex(widget.audioItemId, null);
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
      return;
    }

    final stepCtx = _getStepContext();

    // 弹窗前保存统计（事实记录，不影响步骤进度）
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultCount(widget.audioItemId, totalDifficultCount);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementIntensiveListenPassCount(widget.audioItemId);
    } catch (e) {
      debugPrint('精听保存统计出错: $e');
    }

    if (!mounted) return;

    final l10nDialog = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10nDialog.intensiveListenCompleteTitle,
      contentBody: Text(
        l10nDialog.intensiveListenCompleteMessage(
          playerState.totalSentences,
          totalDifficultCount,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      nextStepName: stepCtx.nextStepName,
      isLastStep: stepCtx.isLastStep,
    );

    if (!mounted || result == null) return;

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(widget.audioItemId, null);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('精听完成处理出错: $e');
    }

    if (result.action == StepCompleteAction.continueNext) {
      // 继续下一步 → 进入难句跟读
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) {
        _startListenAndRepeat();
      }
    } else {
      // 返回计划 → 退出
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

    final currentSentence = player.currentSentence;

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
        if (playerState.isPlaying) {
          player.pause();
        } else if (playerState.isAnnotationReplay) {
          player.resume();
        } else if (playerState.isPauseBetweenPlays) {
          player.replayDuringCountdown();
        } else if (playerState.isAnnotationMode) {
          player.replayInAnnotationMode();
        } else {
          player.resume();
        }
      },
      onPrevious: () => player.goToPrevious(),
      onNext: () => player.goToNext(),
      child: PopScope(
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
              ),

              // 主体内容
              Expanded(
                child:
                    playerState.isAnnotationMode ||
                        playerState.isAnnotationReplay
                    ? _AnnotationWithBookmark(
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onToggleDifficult: _toggleAndSaveDifficult,
                        child: _AnnotationModeView(
                          text: currentSentence?.text ?? '',
                          isDifficult: playerState.difficultSentences.contains(
                            playerState.currentSentenceIndex,
                          ),
                          isAutoMarked:
                              playerState.isCurrentSentenceAutoMarked,
                          aiNotifier: ref.read(sentenceAiNotifierProvider),
                          audioItemId: widget.audioItemId,
                          sentenceIndex: playerState.currentSentenceIndex,
                          sentenceStartMs:
                              currentSentence?.startTime.inMilliseconds,
                          sentenceEndMs:
                              currentSentence?.endTime.inMilliseconds,
                        ),
                      )
                    : _NormalModeView(
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeekToggle: () =>
                            player.setTextRevealed(!playerState.isTextRevealed),
                        onToggleDifficult: _toggleAndSaveDifficult,
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        onPauseCountdown: () => playerState.isCountdownPaused
                            ? player.resumeCountdown()
                            : player.pauseCountdown(),
                        sentenceText: currentSentence?.text,
                      ),
              ),

              // 底部统一 Padding（对齐跟读页布局）
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.l,
                  right: AppSpacing.l,
                  bottom: AppSpacing.m,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // === 标注模式专属 ===
                    if (playerState.isAnnotationMode &&
                        !playerState.isAnnotationReplay &&
                        !playerState.isPauseBetweenSentences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => player.exitAnnotationMode(),
                            child: Text(l10n.intensiveListenContinue),
                          ),
                        ),
                      ),
                    if (playerState.isAnnotationReplay)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: Text(
                          l10n.intensiveListenReplayingWithSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    if ((playerState.isAnnotationMode ||
                            playerState.isAnnotationReplay) &&
                        playerState.isPauseBetweenSentences)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: CountdownChip(
                          remaining: playerState.pauseRemaining,
                          total: playerState.pauseDuration,
                          isPaused: playerState.isCountdownPaused,
                          onTap: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                        ),
                      ),

                    // === 通用：播放控制 ===
                    _PlaybackControls(
                      playerState: playerState,
                      onPrevious: () => player.goToPrevious(),
                      onNext: () {
                        final isLast =
                            playerState.currentSentenceIndex >=
                            playerState.totalSentences - 1;
                        if (isLast) {
                          player.stopPlayback();
                          _handleCompleted();
                        } else {
                          player.goToNext();
                        }
                      },
                      onPlayPause: () {
                        if (playerState.isPlaying) {
                          player.pause();
                        } else if (playerState.isAnnotationReplay) {
                          player.resume();
                        } else if (playerState.isPauseBetweenPlays) {
                          player.replayDuringCountdown();
                        } else if (playerState.isAnnotationMode) {
                          player.replayInAnnotationMode();
                        } else {
                          player.resume();
                        }
                      },
                    ),
                    // 播放遍数
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final IntensiveListenState playerState;
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
                l10n.intensiveListenProgress(current, total),
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

/// 普通模式视图（难句标记行 + 字幕区 + 偷看 + 倒计时 + 按钮行）
///
/// 倒计时使用固定 56px 高度占位，避免字幕区跳动。
/// 布局参考难句补练 PracticeNormalModeView。
/// 标注模式外层包装：在顶部显示和普通模式相同的书签标记行
class _AnnotationWithBookmark extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onToggleDifficult;
  final Widget child;

  const _AnnotationWithBookmark({
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onToggleDifficult,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDifficult = playerState.difficultSentences.contains(
      playerState.currentSentenceIndex,
    );
    final isAutoMarked = playerState.isCurrentSentenceAutoMarked;

    // 标记文案：自动标记 / 手动标记 / 未标记
    final labelText = isDifficult
        ? (isAutoMarked
            ? l10n.intensiveListenAutoMarkedDifficult
            : l10n.intensiveListenMarkedDifficult)
        : l10n.intensiveListenNotDifficult;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),
          // 书签标记行（和普通模式同位置、同样式）
          GestureDetector(
            onTap: onToggleDifficult,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    labelText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          // 标注内容
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NormalModeView extends StatelessWidget {
  final IntensiveListenState playerState;
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onPeekToggle;

  /// 切换难句标记回调（用于难句标记行）
  final VoidCallback onToggleDifficult;

  /// 听不懂（进入标注模式）
  final VoidCallback onCantUnderstand;

  /// 暂停/恢复倒计时
  final VoidCallback onPauseCountdown;

  final String? sentenceText;

  const _NormalModeView({
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onToggleDifficult,
    required this.onCantUnderstand,
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
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber.shade700 : Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),

          // 字幕区（整个区域可点击切换字幕）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPeekToggle,
              child: Stack(
                children: [
                  // 字幕内容偏上（-0.4 ≈ 上方 30% 位置）
                  Align(
                    alignment: const Alignment(0, -0.4),
                    child: playerState.isTextRevealed && sentenceText != null
                        ? GestureDetector(
                            onTap: () {}, // 拦截点击，不冒泡到外层
                            child: Text(
                              sentenceText!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _HiddenTextPlaceholder(),
                  ),
                  // 偷看字幕标签（固定在字幕区中间偏下）
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _PeekLabel(
                      isRevealed: playerState.isTextRevealed,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部固定区：倒计时 + 按钮行
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倒计时（固定 56 高度占位，避免字幕区跳动）
              SizedBox(
                height: 56,
                child: playerState.isPauseBetweenPlays
                    ? CountdownChip(
                        remaining: playerState.pauseRemaining,
                        total: playerState.pauseDuration,
                        isPaused: playerState.isCountdownPaused,
                        onTap: onPauseCountdown,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.m),
              // 取消标记 + 听不懂按钮
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDifficult) ...[
                      TextButton(
                        onPressed: onToggleDifficult,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          l10n.practiceRemoveMark,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    FilledButton.tonal(
                      onPressed: onCantUnderstand,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.intensiveListenCantUnderstand,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.l),
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

/// 标注模式视图（仅卡片，底部控件已移至 build 底部统一 Padding）
class _AnnotationModeView extends StatelessWidget {
  final String text;
  final bool isDifficult;

  /// 是否展示”自动标记为难句”文案
  final bool isAutoMarked;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 来源音频 ID（用于词典弹窗收藏单词）
  final String? audioItemId;

  /// 当前句子索引
  final int? sentenceIndex;

  /// 当前句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 当前句子结束时间（毫秒）
  final int? sentenceEndMs;

  const _AnnotationModeView({
    required this.text,
    required this.isDifficult,
    required this.isAutoMarked,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
  });

  @override
  Widget build(BuildContext context) {
    final ai = aiNotifier;
    final cachedTranslation = ai?.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai?.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: SentenceAnnotationCard(
            key: ValueKey(text),
            text: text,
            isDifficult: isDifficult,
            showAutoMarkedLabel: isAutoMarked,
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
            audioItemId: audioItemId,
            sentenceIndex: sentenceIndex,
            sentenceStartMs: sentenceStartMs,
            sentenceEndMs: sentenceEndMs,
          ),
    );
  }
}

/// 偷看字幕标签（字幕区下方，提示用户可点击）
class _PeekLabel extends StatelessWidget {
  final bool isRevealed;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PeekLabel({
    required this.isRevealed,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRevealed
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          l10n.intensiveListenPeek,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
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
    final canGoPrev = playerState.currentSentenceIndex > 0;
    final isLastSentence =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;

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

          // 播放/暂停
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
            enabled: true,
            onTap: onNext,
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

/// 精听播放器页面
///
/// 逐句精听界面，支持普通模式（文字遮盖）和“听不懂”后的详情模式。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../utils/wakelock_mixin.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_permission_dialog.dart'
    show maybeShowLearningNotificationPrompt;
import '../widgets/speech_permission_dialog.dart';
import '../widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/app_logger.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/guide_flow.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../providers/new_user_guide_provider.dart';

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

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  /// 新手引导：「听不太懂」按钮 Showcase key（随 State 生命周期存在）
  final GlobalKey _guideCantUnderstandKey = GlobalKey();

  ProviderSubscription<IntensiveListenState>? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<IntensiveListenState>(
      intensiveListenPlayerProvider,
      (prev, next) {
        if (_isExiting || prev == null) return;
        if (!prev.stepFinished && next.stepFinished) {
          ref.read(learningSessionProvider.notifier).pauseStudyTimer();
          shortenIdleTimeout(5);
          unawaited(_handleCompleted());
        }
      },
    );
    // 进入后自动开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(intensiveListenPlayerProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    super.dispose();
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
      await _saveSentenceProgress(isFreePlay: true);

      // 保存难句书签
      await _saveDifficultSentences();

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
      return;
    }

    // 保存断点 + 难句 + 难句数快照
    await _saveSentenceProgress(isFreePlay: false);
    await _saveDifficultSentences();

    // 先 exitLearningMode 同步书签到 LP，再 pop 页面
    // （pop 后 widget 销毁，ref.read 可能失效）
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 保存精听断点进度
  Future<void> _saveSentenceProgress({required bool isFreePlay}) async {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveIntensiveListenSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
          isFreePlay: isFreePlay,
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
    final plan = ref.read(learningPlanForAudioProvider(widget.audioItemId));
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    final stage = progress?.currentStage ?? LearningStage.firstLearn;
    final currentSub =
        progress?.currentSubStage ?? SubStageType.intensiveListen;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(currentSub);
    final isLast = currentIdx < 0 || currentIdx >= planned.length - 1;

    // 用 plan 找下一步：plan 末尾 → null（不显示「继续」按钮）
    final next = plan.nextPlannedAfter(stage, currentSub);
    final nextStepName = (next != null && _hasPlayerScreen(next.subStage))
        ? _getSubStageName(next.subStage, l10n)
        : null;

    return (
      stepIndex: currentIdx >= 0 ? currentIdx : planned.length,
      totalSteps: planned.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理播放完成
  ///
  /// 弹出完成对话框，支持双按钮："返回计划"和"继续下一步"。
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(intensiveListenPlayerProvider);

    // 保存难句书签
    await _saveDifficultSentences();
    final totalDifficultCount = await _loadTotalDifficultCount();

    if (!mounted) return;

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      // 弹窗前递增遍数
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
              .saveIntensiveListenSentenceIndex(
                widget.audioItemId,
                null,
                isFreePlay: true,
              );
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    final stepCtx = _getStepContext();

    // 弹窗前保存统计（事实记录，不影响步骤进度）
    try {
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

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('精听完成处理出错: $e');
    }

    await maybeShowLearningNotificationPrompt(context, ref);

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      await _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // 只监听非倒计时字段，排除 pauseRemaining / annotationReplayRemaining，
    // 避免倒计时每 100ms tick 导致整个页面（含 ListView、句子卡片）重建
    ref.watch(
      intensiveListenPlayerProvider.select(
        (s) => (
          s.currentSentenceIndex,
          s.totalSentences,
          s.currentPlayCount,
          s.settings,
          s.isPlaying,
          s.isPauseBetweenPlays,
          s.isPauseBetweenSentences,
          s.pauseDuration,
          s.annotationReplayDuration,
          s.isAnnotationMode,
          s.isAnnotationReplay,
          s.isTextRevealed,
          s.difficultSentences,
          s.isCurrentSentenceAutoMarked,
          s.isCountdownPaused,
          s.isCountdownFastForward,
          s.stepFinished,
          s.playingSenseGroupIndex,
          s.playedSenseGroupIndices,
        ),
      ),
    );
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

    final currentSentence = player.currentSentence;

    // 新手引导：仅在普通练习模式（非标注/重播）下展示，确保按钮在屏上
    final cantUnderstandStep = GuideStep(
      key: _guideCantUnderstandKey,
      description: l10n.guideIntensiveListenCantUnderstandDescription,
    );
    final guideFlows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.intensiveListenCantUnderstand,
        shouldRun:
            !playerState.isAnnotationMode && !playerState.isAnnotationReplay,
        steps: [cantUnderstandStep],
      ),
    ];

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

    return wakelockBody(
      child: LearningHotkeyScope(
        onPlayPause: _handleCenter,
        onPrevious: _handlePrevious,
        onNext: _handleNext,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleExit();
          },
          child: GuideFlowSequenceHost(
            flows: guideFlows,
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
                    onPressed: () {
                      if (playerState.annotationState != null) {
                        player.onAnnotationUserInteraction();
                      } else {
                        player.enterWaitingForUserInBlindMode();
                      }
                      showIntensiveListenSettingsSheet(context: context);
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  PracticeProgressSection(
                    current: playerState.currentSentenceIndex + 1,
                    total: playerState.totalSentences,
                    progressText: l10n.intensiveListenProgress(
                      playerState.currentSentenceIndex + 1,
                      playerState.totalSentences,
                    ),
                    durationText: durationText,
                    showAudioSource: false,
                  ),

                  // 主体内容
                  Expanded(
                    child:
                        playerState.isAnnotationMode ||
                            playerState.isAnnotationReplay
                        ? _AnnotationWithBookmark(
                            playerState: playerState,
                            onToggleDifficult: _toggleAndSaveDifficult,
                            child: AnnotationContentView(
                              text: currentSentence?.text ?? '',
                              aiNotifier: ref.read(sentenceAiNotifierProvider),
                              audioItemId: widget.audioItemId,
                              sentenceIndex:
                                  currentSentence?.index ??
                                  playerState.currentSentenceIndex,
                              sentenceStartMs:
                                  currentSentence?.startTime.inMilliseconds,
                              sentenceEndMs:
                                  currentSentence?.endTime.inMilliseconds,
                              onStopMainPlayer: () {
                                player.onAnnotationUserInteraction();
                              },
                              onToolbarButtonTapped: () {
                                player.onAnnotationUserInteraction();
                              },
                            ),
                          )
                        : PracticeNormalModeView(
                            l10n: l10n,
                            theme: theme,
                            isTextRevealed: playerState.isTextRevealed,
                            countdown: Consumer(
                              builder: (context, ref, _) {
                                final s = ref.watch(
                                  intensiveListenPlayerProvider.select(
                                    (s) => (
                                      show:
                                          s.isPauseBetweenPlays &&
                                          !s.settings.isManualMode,
                                      total: s.pauseDuration,
                                      paused: s.isCountdownPaused,
                                      fastForward: s.isCountdownFastForward,
                                    ),
                                  ),
                                );
                                if (!s.show) return const SizedBox.shrink();
                                return CountdownChip(
                                  key: ValueKey(
                                    'blind-countdown-'
                                    '${playerState.currentSentenceIndex}-'
                                    '${s.total.inMilliseconds}',
                                  ),
                                  total: s.total,
                                  isPaused: s.paused,
                                  isFastForward: s.fastForward,
                                  onPause: () => player.pauseCountdown(),
                                  onResume: () => player.resumeCountdown(),
                                );
                              },
                            ),
                            alwaysShowToggleButton: false,
                            isDifficult: playerState.difficultSentences
                                .contains(playerState.currentSentenceIndex),
                            onPeekToggle: () {
                              player.enterWaitingForUserInBlindMode();
                              player.setTextRevealed(
                                !playerState.isTextRevealed,
                              );
                            },
                            onToggleMark: _toggleAndSaveDifficult,
                            onCantUnderstand: () =>
                                player.enterAnnotationMode(),
                            cantUnderstandStep: cantUnderstandStep,
                            sentenceText: currentSentence?.text,
                            onWordTap: currentSentence != null
                                ? (word) {
                                    player.enterWaitingForUserInBlindMode();
                                    showWordDictionarySheet(
                                      context: context,
                                      word: word,
                                      audioItemId: widget.audioItemId,
                                      sentenceIndex: currentSentence.index,
                                      sentenceText: currentSentence.text,
                                      sentenceStartMs: currentSentence
                                          .startTime
                                          .inMilliseconds,
                                      sentenceEndMs: currentSentence
                                          .endTime
                                          .inMilliseconds,
                                    );
                                  }
                                : null,
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.m),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showContinueButton(playerState))
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.l,
                              right: AppSpacing.l,
                              bottom: AppSpacing.m,
                            ),
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.m,
                            ),
                            child: Text(
                              l10n.intensiveListenReplayingWithSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        if (_showAnnotationCountdown(playerState))
                          Consumer(
                            builder: (context, ref, _) {
                              final countdown = ref.watch(
                                intensiveListenPlayerProvider.select(
                                  (s) => (
                                    show: _showAnnotationCountdown(s),
                                    sentenceIndex: s.currentSentenceIndex,
                                    total: s.pauseDuration,
                                    paused: s.isCountdownPaused,
                                    fastForward: s.isCountdownFastForward,
                                  ),
                                ),
                              );
                              if (!countdown.show) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.l,
                                  right: AppSpacing.l,
                                  bottom: AppSpacing.m,
                                ),
                                child: CountdownChip(
                                  key: ValueKey(
                                    'annotation-countdown-'
                                    '${countdown.sentenceIndex}-'
                                    '${countdown.total.inMilliseconds}',
                                  ),
                                  total: countdown.total,
                                  isPaused: countdown.paused,
                                  isFastForward: countdown.fastForward,
                                  onPause: () => player.pauseCountdown(),
                                  onResume: () => player.resumeCountdown(),
                                ),
                              );
                            },
                          ),
                        PracticePlaybackFooter(
                          canGoPrev: playerState.currentSentenceIndex > 0,
                          isLast:
                              playerState.currentSentenceIndex >=
                              playerState.totalSentences - 1,
                          centerIcon: _buildFooterCenterIcon(playerState),
                          onPrevious: _handlePrevious,
                          onNext: _handleNext,
                          onCenter: _handleCenter,
                          isManualMode: playerState.settings.isManualMode,
                          playCountText: l10n.intensiveListenPlayCount(
                            playerState.currentPlayCount,
                            playerState.settings.isManualMode
                                ? 1
                                : playerState.settings.repeatCount,
                          ),
                          l10n: l10n,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
  final VoidCallback onToggleDifficult;
  final Widget child;

  const _AnnotationWithBookmark({
    required this.playerState,
    required this.onToggleDifficult,
    required this.child,
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
          BookmarkToggleRow(
            isDifficult: isDifficult,
            isAutoMarked: playerState.isCurrentSentenceAutoMarked,
            onTap: onToggleDifficult,
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(child: child),
        ],
      ),
    );
  }
}

bool _showContinueButton(IntensiveListenState playerState) {
  return playerState.isAnnotationMode &&
      !playerState.isAnnotationReplay &&
      !playerState.isPauseBetweenSentences;
}

bool _showAnnotationCountdown(IntensiveListenState playerState) {
  return playerState.isAnnotationMode && playerState.isPauseBetweenSentences;
}

IconData _buildFooterCenterIcon(IntensiveListenState playerState) {
  return _isIntensiveMainPlaybackActive(playerState)
      ? Icons.pause_rounded
      : Icons.play_arrow_rounded;
}

bool _isIntensiveMainPlaybackActive(IntensiveListenState state) {
  return state.isPlaying &&
      !state.isPauseBetweenPlays &&
      !state.isPauseBetweenSentences;
}

extension on _IntensiveListenPlayerScreenState {
  void _handlePrevious() {
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    unawaited(player.goToPrevious());
  }

  void _handleNext() {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final isLast =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    if (isLast) {
      player.stopPlayback();
      unawaited(_handleCompleted());
      return;
    }
    unawaited(player.goToNext());
  }

  void _handleCenter() {
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    AppLogger.log(
      'IntensivePlayPause',
      'isPlaying=${playerState.isPlaying} '
          'isAnnotationReplay=${playerState.isAnnotationReplay} '
          'isPauseBetweenPlays=${playerState.isPauseBetweenPlays} '
          'isAnnotationMode=${playerState.isAnnotationMode}',
    );
    if (playerState.isPlaying) {
      unawaited(player.pause());
      return;
    }
    if (playerState.isAnnotationReplay) {
      unawaited(player.resume());
      return;
    }
    if (playerState.isPauseBetweenPlays) {
      unawaited(player.replayDuringCountdown());
      return;
    }
    if (playerState.isAnnotationMode) {
      unawaited(player.replayInAnnotationMode());
      return;
    }
    unawaited(player.resume());
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
      SubStageType.reviewDifficultPractice => 'Difficult Practice',
      SubStageType.reviewRetellParagraph => 'Paragraph Retelling',
      SubStageType.reviewRetellSummary => 'Full Text Retelling',
    };

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
import '../router/app_router.dart';
import '../database/enums.dart';
import '../utils/playback_speed.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../models/sentence.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/blind_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../providers/new_user_guide_provider.dart';
import 'sentence_detail_screen.dart';
import '../services/app_logger.dart';
import '../theme/app_theme.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/blind_listen_settings_sheet.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/paragraph_practice_scaffold.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/common/paragraph_sentence_list_card.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/guide_flow.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_play_count_label.dart';

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

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  /// 是否正在跳转句子详情页，防止快速点击重复 push
  bool _isNavigatingToDetail = false;

  /// 是否正在 seek 同步阶段（_cancelAll + state.copyWith）。
  /// seekToSentence 内 _playCurrentParagraph 是 unawaited，guard 只 hold
  /// 同步阶段（几十 ms），不阻塞下一次点击。
  bool _isSeeking = false;

  /// 新手引导：编号区 / 主体区 Showcase key（随 State 生命周期存在）
  final GlobalKey _guideNumberKey = GlobalKey(
    debugLabel: 'guideSentenceNumber',
  );
  final GlobalKey _guideBodyKey = GlobalKey(debugLabel: 'guideSentenceBody');
  ProviderSubscription<BlindListenPlayerState>? _playerSubscription;
  StreamSubscription<Duration>? _silenceSkipSub;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<BlindListenPlayerState>(
      blindListenPlayerProvider,
      (prev, next) {
        if (_isExiting || prev == null) return;
        _logBlindStateTransition(prev, next);
        if (!prev.stepFinished && next.stepFinished) {
          ref.read(learningSessionProvider.notifier).pauseStudyTimer();
          shortenIdleTimeout(5);
          _handleCompleted();
        }
      },
    );
    _silenceSkipSub = ref
        .read(blindListenPlayerProvider.notifier)
        .silenceSkipEventStream
        .listen(_showSilenceSkippedSnackBar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.log('BlindListenScreen', '首帧后启动播放');
      ref.read(blindListenPlayerProvider.notifier).startPlaying();
      // 从 DB 拉取最新的收藏状态（覆盖 initializeParagraphs 时的同步快照）
      unawaited(
        ref
            .read(blindListenPlayerProvider.notifier)
            .initializeBookmarks(widget.audioItemId),
      );
    });
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    _silenceSkipSub?.cancel();
    super.dispose();
  }

  /// 弹出"已自动跳过 Xs 静音"提示
  void _showSilenceSkippedSnackBar(Duration gap) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.silenceSkipped(gap.inSeconds)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ========== 句子点击 ==========

  /// 点击句子编号 → 从该句开始播放
  ///
  /// guard 只 hold seekToSentence 的同步阶段（Provider 内 _cancelAll + state.copyWith
  /// 完成立即返回，_playCurrentParagraph 是 unawaited 异步执行）。
  /// 用 guard 隔离与 _handleSentenceDetail 的 pause+navigate 并发：避免 pause 写完
  /// state 后被 _playCurrentParagraph 同步部分覆盖。
  Future<void> _handleSentencePlayFrom(Sentence sentence) async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      await ref
          .read(blindListenPlayerProvider.notifier)
          .seekToSentence(sentence.index);
    } finally {
      _isSeeking = false;
    }
  }

  /// 点击句子主体（文本/书签）→ 暂停播放 → 进入句子详情页
  ///
  /// 与复述任务行为一致：导航前停止音频，返回后由用户手动恢复播放。
  Future<void> _handleSentenceDetail(Sentence sentence) async {
    if (_isNavigatingToDetail) return;
    _isNavigatingToDetail = true;

    await ref.read(blindListenPlayerProvider.notifier).pause();

    if (!mounted) {
      _isNavigatingToDetail = false;
      return;
    }

    final lpState = ref.read(listeningPracticeProvider);
    final audioName = lpState.currentAudioItem?.name ?? '';

    await context.push(
      AppRoutes.sentenceDetail,
      extra: SentenceDetailArgs(
        audioItemId: widget.audioItemId,
        audioName: audioName,
        sentenceText: sentence.text,
        sentenceIndex: sentence.index,
        startTimeMs: sentence.startTime.inMilliseconds,
        endTimeMs: sentence.endTime.inMilliseconds,
      ),
    );

    _isNavigatingToDetail = false;

    // 返回后刷新收藏状态（详情页可能修改了收藏）
    if (!mounted) return;
    await ref
        .read(blindListenPlayerProvider.notifier)
        .initializeBookmarks(widget.audioItemId);
  }

  // ========== 完成处理 ==========

  /// 播放完成处理
  void _handleCompleted() {
    if (_isShowingDialog || _isExiting) return;
    _isShowingDialog = true;
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
        // 在 pop 前置 _isExiting，避免 PopScope 重入 _handleExit 反向回写断点
        _isExiting = true;
        await ref
            .read(learningSessionProvider.notifier)
            .recordCatchUpCompletionIfAny(widget.audioItemId);
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveBlindListenSentenceIndex(
              widget.audioItemId,
              null,
              isFreePlay: true,
            );
        if (mounted) context.pop();
        await ref.read(learningSessionProvider.notifier).exitLearningMode();
      },
    );
    _isShowingDialog = false;
  }

  /// 正常模式完成对话框
  Future<void> _showCompleteDialog() async {
    if (!mounted) return;

    final stepCtx = _getStepContext();

    final l10n = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.blindListenComplete,
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

    // 用户确认后：标记完成（难度已在逐句精听完成时自动判定，盲听不再设难度）
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveBlindListenSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('盲听完成处理出错: $e');
    }

    // 在 exitLearningMode + pop / navigate 之前置 _isExiting，
    // 避免 PopScope 重入 _handleExit 反向回写断点。
    _isExiting = true;
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext) {
      await _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
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
    final plan = ref.read(learningPlanForAudioProvider(widget.audioItemId));
    final progress = ref
        .read(learningProgressNotifierProvider)
        .progressMap[widget.audioItemId];

    final stage = progress?.currentStage ?? LearningStage.firstLearn;
    final currentSub = progress?.currentSubStage ?? SubStageType.blindListen;
    final planned = plan.subStagesFor(stage);
    final currentIdx = planned.indexOf(currentSub);
    final isLast = currentIdx < 0 || currentIdx >= planned.length - 1;

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

  // ========== 退出处理 ==========

  Future<void> _openSettings() async {
    AppLogger.log('BlindListenScreen', '打开设置 → 请求进入 WaitingForUser');
    ref
        .read(blindListenPlayerProvider.notifier)
        .enterWaitingForUser(afterCurrentParagraph: true);
    await showBlindListenSettingsSheet(context);
  }

  Future<void> _handleExit() async {
    // 防重入：完成弹窗 / _exit 内 context.pop() 会被 PopScope 拦截再触发 _handleExit，
    // 导致反向回写断点（覆盖完成弹窗写入的 null）。
    if (_isExiting) return;

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
    // 退出前显式落盘当前句索引（与复述 _handleExit 行为对齐）。
    // 完成 / 自由练习完成走 _showCompleteDialog / _showFreePlayCompleteDialog 显式清空 null，
    // 不走这里。
    try {
      final sessionState = ref.read(learningSessionProvider);
      final globalIdx = ref
          .read(blindListenPlayerProvider.notifier)
          .currentSentenceGlobalIndex;
      if (globalIdx != null) {
        await ref
            .read(learningProgressNotifierProvider.notifier)
            .saveBlindListenSentenceIndex(
              widget.audioItemId,
              globalIdx,
              isFreePlay: sessionState.isFreePlay,
            );
      }
    } catch (e) {
      debugPrint('盲听退出保存断点失败: $e');
    }
    if (mounted) context.pop();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
  }

  void _logBlindStateTransition(
    BlindListenPlayerState prev,
    BlindListenPlayerState next,
  ) {
    // 排除 pauseRemaining，倒计时期间变化太频繁
    if (prev.currentParagraphIndex == next.currentParagraphIndex &&
        prev.playingSentenceIndex == next.playingSentenceIndex &&
        prev.currentRepeatCount == next.currentRepeatCount &&
        prev.hasCompletedCurrentParagraphPlayback ==
            next.hasCompletedCurrentParagraphPlayback &&
        prev.isPlaying == next.isPlaying &&
        prev.isPauseCountdown == next.isPauseCountdown &&
        prev.isCountdownPaused == next.isCountdownPaused &&
        prev.isWaitingForUser == next.isWaitingForUser &&
        prev.stepFinished == next.stepFinished) {
      return;
    }

    AppLogger.log(
      'BlindListenScreen',
      '状态变化: '
          'paragraph ${prev.currentParagraphIndex}→${next.currentParagraphIndex}, '
          'sentence ${prev.playingSentenceIndex}→${next.playingSentenceIndex}, '
          'repeat ${prev.currentRepeatCount}→${next.currentRepeatCount}, '
          'playing ${prev.isPlaying}→${next.isPlaying}, '
          'countdown ${prev.isPauseCountdown}/${prev.isCountdownPaused}'
          '→${next.isPauseCountdown}/${next.isCountdownPaused}, '
          'waiting ${prev.isWaitingForUser}→${next.isWaitingForUser}, '
          'completedPlayback ${prev.hasCompletedCurrentParagraphPlayback}'
          '→${next.hasCompletedCurrentParagraphPlayback}, '
          'remaining ${prev.pauseRemaining.inMilliseconds}'
          '→${next.pauseRemaining.inMilliseconds}ms, '
          'stepFinished ${prev.stepFinished}→${next.stepFinished}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // 只监听非倒计时字段，排除 pauseRemaining，
    // 避免倒计时每 100ms tick 导致整个页面重建
    ref.watch(
      blindListenPlayerProvider.select(
        (s) => (
          s.currentParagraphIndex,
          s.totalParagraphs,
          s.playingSentenceIndex,
          s.currentRepeatCount,
          s.isPlaying,
          s.isPauseCountdown,
          s.pauseDuration,
          s.isCountdownPaused,
          s.displayMode,
          s.settings,
          s.stepFinished,
          s.bookmarkedSentenceIndices,
        ),
      ),
    );
    final playerState = ref.read(blindListenPlayerProvider);

    return wakelockBody(
      child: _buildParagraphMode(context, l10n, theme, playerState),
    );
  }

  Widget? _buildManualHint(
    BlindListenPlayerState state,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (state.isPauseCountdown) {
      return null;
    }

    final (IconData icon, String text) = state.isPlaying
        ? (Icons.headphones, l10n.blindListenListeningHint)
        : state.isWaitingForUser || !state.hasCompletedCurrentParagraphPlayback
        ? (Icons.play_circle_outline, l10n.blindListenPreListenHint)
        : state.settings.isManualMode
        ? (Icons.lightbulb_outline, l10n.blindListenRecallHint)
        : (Icons.headphones, l10n.blindListenListeningHint);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.s),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ========== 段落分段模式 UI ==========

  Widget _buildParagraphMode(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    BlindListenPlayerState playerState,
  ) {
    final player = ref.read(blindListenPlayerProvider.notifier);

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;

    // 顶部进度条：多段按「段落」单调驱动（不随句子/遍数回退），单段无段落
    // 进度可言，保留原逐句行为。
    final isMultiParagraph = playerState.totalParagraphs > 1;
    final sentenceIdx = _globalSentenceIdx(
      sentences,
      playerState.playingSentenceIndex,
    );
    final progressCurrent = isMultiParagraph
        ? playerState.currentParagraphIndex + 1
        : sentenceIdx;
    final progressTotal = isMultiParagraph
        ? playerState.totalParagraphs
        : player.totalSentenceCount;
    final progressText = isMultiParagraph
        ? l10n.retellParagraphProgress(
            playerState.currentParagraphIndex + 1,
            playerState.totalParagraphs,
          )
        : l10n.intensiveListenProgress(sentenceIdx, player.totalSentenceCount);

    // 新手引导：编号→开播、文本→讲解。统一挂在第 1 句（idx=0），首项最显眼。
    const guideTargetLocalIdx = 0;
    final numberStep = GuideStep(
      key: _guideNumberKey,
      description: l10n.guideSentenceTileNumberDescription,
    );
    final bodyStep = GuideStep(
      key: _guideBodyKey,
      description: l10n.guideSentenceTileBodyDescription,
    );
    final guideFlows = <GuideFlow>[
      GuideFlow(
        flowId: GuideFlowIds.sentenceTileTour,
        shouldRun: sentences.isNotEmpty,
        steps: [numberStep, bodyStep],
      ),
    ];

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
        final isLast = ps.currentParagraphIndex >= ps.totalParagraphs - 1;
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
        child: GuideFlowSequenceHost(
          flows: guideFlows,
          child: ParagraphPracticeScaffold(
            title: l10n.blindListenAppBarTitle,
            onClose: _handleExit,
            onOpenSettings: _openSettings,
            current: progressCurrent,
            total: progressTotal,
            progressText: progressText,
            durationText: _formatDurationText(
              l10n,
              paragraphDuration: paragraphDuration,
              totalDuration: player.totalDuration,
              paragraphTotal: playerState.totalParagraphs,
            ),
            onSeekToIndex: isMultiParagraph
                ? (p) => ref
                      .read(blindListenPlayerProvider.notifier)
                      .seekToParagraph(p)
                : (i) => ref
                      .read(blindListenPlayerProvider.notifier)
                      .seekToSentence(i),
            paragraphContent: ParagraphSentenceListCard(
              sentences: sentences,
              displayMode:
                  playerState.displayMode == BlindListenDisplayMode.showAll
                  ? RetellDisplayMode.showAll
                  : RetellDisplayMode.hideAll,
              keywordMap: const {},
              playingSentenceIndex: playerState.playingSentenceIndex,
              autoFocusEnabled: true,
              bookmarkedSentenceIndices: playerState.bookmarkedSentenceIndices,
              onSentenceTap: _handleSentenceDetail,
              onSentencePlayFrom: _handleSentencePlayFrom,
              onSentenceBookmarkToggle: (sentence) => ref
                  .read(blindListenPlayerProvider.notifier)
                  .toggleBookmark(widget.audioItemId, sentence),
              guideTargetLocalIdx: guideTargetLocalIdx,
              numberAreaGuideStep: numberStep,
              bodyAreaGuideStep: bodyStep,
            ),
            contentControls: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final next =
                      playerState.displayMode == BlindListenDisplayMode.showAll
                      ? BlindListenDisplayMode.hideAll
                      : BlindListenDisplayMode.showAll;
                  player.setDisplayMode(next);
                },
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        playerState.displayMode ==
                                BlindListenDisplayMode.showAll
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        playerState.displayMode ==
                                BlindListenDisplayMode.showAll
                            ? l10n.blindListenDisplayHideAll
                            : l10n.intensiveListenPeek,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 常态（非倒计时）只占必要高度，倒计时时才撑开为「回忆提示 + 倒计时行」
            // 两段固定预留会在常态浪费大量垂直空间，故按状态条件渲染。
            practiceControls: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playerState.isPauseCountdown)
                  SizedBox(
                    height: 22,
                    child: Center(
                      child: Text(
                        l10n.blindListenRecallHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  height: playerState.isPauseCountdown ? 48 : 32,
                  child: playerState.isPauseCountdown
                      ? Consumer(
                          builder: (context, ref, _) {
                            final s = ref.watch(
                              blindListenPlayerProvider.select(
                                (s) => (
                                  total: s.pauseDuration,
                                  paused: s.isCountdownPaused,
                                  fastForward: s.isCountdownFastForward,
                                ),
                              ),
                            );
                            final hasFF = !s.paused && !s.fastForward;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 左槽位：占位（与 prev 按钮对齐）
                                const SizedBox(
                                  width: PlaybackControls.controlButtonSize,
                                ),
                                const SizedBox(width: 48),
                                // 中间槽位：倒计时（与中心按钮对齐）
                                SizedBox(
                                  width: PlaybackControls.controlButtonSize,
                                  child: Center(
                                    child: CountdownChip(
                                      total: s.total,
                                      isPaused: s.paused,
                                      isFastForward: s.fastForward,
                                      onPause: () => player.pauseCountdown(),
                                      onResume: () => player.resumeCountdown(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                                // 右槽位：快进按钮（与 next 按钮对齐）
                                SizedBox(
                                  width: PlaybackControls.controlButtonSize,
                                  height: 48,
                                  child: Center(
                                    child: AnimatedOpacity(
                                      opacity: hasFF ? 1.0 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: IgnorePointer(
                                        ignoring: !hasFF,
                                        child: hasFF
                                            ? GestureDetector(
                                                onTap: player
                                                    .toggleCountdownFastForward,
                                                child: Icon(
                                                  Icons.fast_forward_rounded,
                                                  size: 32,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : Center(
                          child: _buildManualHint(playerState, l10n, theme),
                        ),
                ),
              ],
            ),
            canGoPrev: playerState.currentParagraphIndex > 0,
            isLast:
                playerState.currentParagraphIndex >=
                playerState.totalParagraphs - 1,
            centerIcon: _isBlindMainPlaybackActive(playerState)
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onPrevious: () => player.goToPreviousParagraph(),
            onNext: () {
              final isLast =
                  playerState.currentParagraphIndex >=
                  playerState.totalParagraphs - 1;
              if (isLast) {
                player.pause();
                _handleCompleted();
              } else {
                player.goToNextParagraph();
              }
            },
            onCenter: _isBlindMainPlaybackActive(playerState)
                ? player.pause
                : player.resume,
            isManualMode: playerState.settings.isManualMode,
            playCountText: formatPracticePlayCount(
              l10n,
              currentCount: playerState.currentRepeatCount,
              totalCount: playerState.settings.repeatCount,
            ),
            statusSuffixText: _formatSpeed(playerState.settings.playbackSpeed),
            l10n: l10n,
            theme: theme,
          ),
        ),
      ),
    );
  }
}

/// 当前播放句子的全局序号（1-based）。
///
/// [localIdx] 为 -1（未开始/段间停顿）时取当前段落首句的全局序号。
int _globalSentenceIdx(List<Sentence> paragraphSentences, int localIdx) {
  if (paragraphSentences.isEmpty) return 0;
  final pick = (localIdx >= 0 && localIdx < paragraphSentences.length)
      ? paragraphSentences[localIdx]
      : paragraphSentences.first;
  return pick.index + 1;
}

/// 友好的时长展示：不到 1 分钟显示「X秒」，否则显示「X分Y秒」
String _formatHumanDuration(AppLocalizations l10n, Duration duration) {
  final totalSec = duration.inSeconds;
  if (totalSec < 60) return l10n.retellParagraphDuration('$totalSec');
  return l10n.durationMinutesSeconds(totalSec ~/ 60, totalSec % 60);
}

/// 时长文案：单段时只显示总长，多段时显示「段长 / 总长」
String _formatDurationText(
  AppLocalizations l10n, {
  required Duration paragraphDuration,
  required Duration totalDuration,
  required int paragraphTotal,
}) {
  if (paragraphTotal <= 1) return _formatHumanDuration(l10n, totalDuration);
  return '${_formatHumanDuration(l10n, paragraphDuration)} / '
      '${_formatHumanDuration(l10n, totalDuration)}';
}

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

bool _isBlindMainPlaybackActive(BlindListenPlayerState state) {
  return state.isPlaying &&
      !state.isPauseCountdown &&
      !state.isCountdownPaused &&
      !state.isWaitingForUser;
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

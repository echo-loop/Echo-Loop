/// 复习难句补练页面
///
/// 仅加载已标记为难句的句子，逐句执行：
/// 1. 盲听一遍（不显示字幕）
/// 2. 句间停顿 → 自动推进下一句
/// 3. 用户可随时「偷看」字幕或按「听不懂」进入跟读模式
/// 4. 跟读模式：播放句子（显示字幕）→ 自动录音 → 评分 → 倒计时 → 下一遍
///
/// 录音通过 [ShadowingRecordingController] 驱动（跟读专用控制器）。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
///
/// 交互与逐句精听页面（IntensiveListenPlayerScreen）一致。
/// R1+ 可取消难句标记（听懂的句子 unbookmark）。
/// 完成后弹完成对话框，支持"继续下一步"或"返回计划"。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../providers/shadowing/shadowing_recording_controller.dart';
import '../services/app_logger.dart';
import '../services/audio_playback_service.dart';
import '../utils/wakelock_mixin.dart';
import '../providers/sentence_ai_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/practice/annotation_with_recording.dart';
import '../widgets/practice/practice_progress_section.dart';

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
  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  /// 录音回放服务
  final AudioPlaybackService _playbackService = AudioPlaybackService();

  /// 当前正在播放的 promptId（null = 未播放）
  String? _playingPromptId;

  /// 播放状态监听
  StreamSubscription<bool>? _playbackSub;

  @override
  void initState() {
    super.initState();
    _playbackSub = _playbackService.isPlayingStream.listen((isPlaying) {
      if (!isPlaying && mounted) {
        setState(() => _playingPromptId = null);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 同步初始控制模式到录音控制器
      final playerState = ref.read(reviewDifficultPracticeProvider);
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .setManualMode(playerState.isManualMode);
      ref.read(reviewDifficultPracticeProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _playbackService.dispose();
    super.dispose();
  }

  /// 当前句子的 promptId
  String _currentPromptId() {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final sentence = player.currentSentence;
    final sentenceIndex = sentence?.index ?? player.currentIndex;
    return 'difficult:${widget.audioItemId}:$sentenceIndex';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final sentenceDuration = currentSentence.duration;

    // 跟读场景最大录音时长：max(2.5 × sentenceDuration + 5s, 10s)
    final computed = sentenceDuration * 2.5 + const Duration(seconds: 5);
    final maxRecording = computed < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : computed;

    controller.setMaxRecordingDuration(maxRecording);
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
    await _stopPlayback();
  }

  /// 停止录音回放
  Future<void> _stopPlayback() async {
    await _playbackService.stop();
    if (mounted) {
      setState(() => _playingPromptId = null);
    }
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (!playerState.isPauseBetweenPlays || !playerState.isAnnotationMode) {
      return;
    }

    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final recState = ref.read(shadowingRecordingControllerProvider);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('DifficultScreen', '手动停止录音');
      player.enterManualForSentence();
      await controller.stopAndEvaluate(referenceText: currentSentence.text);
      return;
    }

    await _stopPlayback();

    if (!playerState.isCountdownPaused) {
      player.pauseCountdown();
    }
    _updateRecordingThresholds();
    await controller.startRecording(
      promptId: promptId,
      referenceText: currentSentence.text,
    );
  }

  /// 处理录音回放点击
  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    if (_playingPromptId == promptId) {
      await _stopPlayback();
      return;
    }

    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (playerState.isPlaying) {
      ref.read(reviewDifficultPracticeProvider.notifier).pause();
    }

    // 取消评估后倒计时（不推进到下一句）
    ref
        .read(reviewDifficultPracticeProvider.notifier)
        .cancelPostEvalCountdown();

    ref.read(reviewDifficultPracticeProvider.notifier).enterManualForSentence();

    final recState = ref.read(shadowingRecordingControllerProvider);
    final attempt = recState.currentAttempt;
    final filePath = attempt?.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() => _playingPromptId = promptId);
    await _playbackService.play(filePath);
  }

  /// 处理退出
  Future<void> _handleExit() async {
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.read(reviewDifficultPracticeProvider);

    // 自由练习模式直接退出
    if (session.isFreePlay) {
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
      _isExiting = false;
      return;
    }

    await _exit();
  }

  /// 执行退出（保存断点、释放录音后退出）
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();

    // 保存当前句子索引作为断点
    final session = ref.read(learningSessionProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultPracticeSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
          isFreePlay: session.isFreePlay,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 切换当前句子的难句标记
  Future<void> _handleToggleDifficult() async {
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final sentence = player.currentSentence;
    if (sentence == null) return;

    final isCurrentlyBookmarked = sentence.isBookmarked;
    player.toggleCurrentBookmark();

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (isCurrentlyBookmarked) {
      await bookmarkDao.removeBookmark(widget.audioItemId, sentence.index);
    } else {
      await BookmarkManager.addBookmarkToDb(
        widget.audioItemId,
        sentence,
        dao: bookmarkDao,
      );
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
      nextStepName = _getSubStageName(nextSubStage, l10n);
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: reviewStageLabel(l10n, stage),
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放录音
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();

    final session = ref.read(learningSessionProvider);

    // 自由练习模式：弹窗询问"完成"或"再练一遍"
    if (session.isFreePlay) {
      final playerState = ref.read(reviewDifficultPracticeProvider);
      final l10n = AppLocalizations.of(context)!;

      // 弹窗前清除断点
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: true,
          );

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.reviewDifficultPracticeCompleteTitle,
        message: l10n.reviewDifficultPracticeCompleteMessage(
          playerState.totalSentences,
        ),
        onStudyAgain: () async {
          await ref
              .read(reviewDifficultPracticeProvider.notifier)
              .resetToStart();
        },
        onExit: () async {
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
      _isShowingDialog = false;
      return;
    }

    final playerState = ref.read(reviewDifficultPracticeProvider);
    final stepCtx = _getStepContext();

    if (!mounted) return;

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
    );

    if (!mounted || result == null) {
      _isShowingDialog = false;
      return;
    }

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('难句补练完成处理出错: $e');
    }

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (!mounted) return;

    if (result.action == StepCompleteAction.continueNext &&
        stepCtx.nextStepName != null) {
      _navigateBackToPlanAndAutoStart();
    } else {
      context.pop();
    }
  }

  /// 返回学习计划页并自动启动下一个任务
  ///
  /// 先 go 回学习 Tab 清空导航栈，再 push 新的学习计划页（autoStart=true），
  /// 效果等同于用户在学习列表点击"继续学习"。
  void _navigateBackToPlanAndAutoStart() {
    if (!mounted) return;
    final route = widget.collectionId != null
        ? AppRoutes.learningPlan(
            widget.collectionId!,
            widget.audioItemId,
            autoStart: true,
          )
        : AppRoutes.audioLearningPlan(widget.audioItemId, autoStart: true);
    GoRouter.of(context).go(AppRoutes.study);
    GoRouter.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      shadowingRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(shadowingRecordingControllerProvider);

    // 监听句子切换 + 自动播完信号 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(reviewDifficultPracticeProvider, (
      prev,
      next,
    ) {
      // 句子切换时清除上一句的录音结果，为下一句自动录音做准备
      if (prev != null &&
          prev.currentSentenceIndex != next.currentSentenceIndex) {
        ref
            .read(shadowingRecordingControllerProvider.notifier)
            .clearRecording();
      }
      // 监听自然完成信号 → 触发完成弹窗
      if (prev != null && !_isExiting) {
        if (!prev.stepFinished && next.stepFinished) {
          ref.read(learningSessionProvider.notifier).pauseStudyTimer();
          shortenIdleTimeout(5);
          _handleCompleted();
        }
      }
      // 手动模式变化时同步到录音控制器（全局设置切换 或 单句手动模式变化）
      if (prev?.isManualMode != next.isManualMode) {
        final controller = ref.read(
          shadowingRecordingControllerProvider.notifier,
        );
        controller.setManualMode(next.isManualMode);
        if (next.isManualMode) {
          final recState = ref.read(shadowingRecordingControllerProvider);
          if (recState.phase == ShadowingRecordingPhase.awaitingSpeech ||
              recState.phase == ShadowingRecordingPhase.speaking) {
            controller.cancelActiveRecording();
          }
        }
      }
    });

    // 评估完成 → 启动 review countdown（仅跟读模式）
    ref.listen<ShadowingRecordingState>(shadowingRecordingControllerProvider, (
      prev,
      next,
    ) {
      if (prev?.phase == ShadowingRecordingPhase.processing &&
          next.phase == ShadowingRecordingPhase.idle &&
          next.currentAttempt != null) {
        final latestState = ref.read(reviewDifficultPracticeProvider);
        if (latestState.isPauseBetweenPlays &&
            latestState.isAnnotationMode &&
            !latestState.isManualMode) {
          AppLogger.log('DifficultScreen', '评估完成 → 启动 review countdown');
          ref
              .read(reviewDifficultPracticeProvider.notifier)
              .startPostEvaluationPause();
        }
      }
    });

    final currentSentence = player.currentSentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = turnState.currentAttempt;
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);

    // 手动模式 + 停顿中 → 暂停倒计时（盲听和跟读均适用）
    if (playerState.isPauseBetweenPlays &&
        playerState.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(reviewDifficultPracticeProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
      });
    }

    // 自动模式 + 跟读停顿中 + recording idle + 非倒计时中 → 自动录音
    if (playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        currentSentence != null &&
        !playerState.isManualMode &&
        turnState.phase == ShadowingRecordingPhase.idle &&
        !playerState.isPostEvalCountdown) {
      final promptId = currentPromptId;
      final referenceText = currentSentence.text;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestRecState = ref.read(shadowingRecordingControllerProvider);
        if (latestRecState.phase != ShadowingRecordingPhase.idle) return;
        final latestPlayer = ref.read(reviewDifficultPracticeProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays ||
            latestPlayer.isManualMode) {
          return;
        }

        // 暂停 provider 层倒计时（录音由 ShadowingRecordingController 接管）
        if (!latestPlayer.isCountdownPaused) {
          ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
        }

        AppLogger.log('DifficultScreen', '自动开始录音');
        _updateRecordingThresholds();
        unawaited(
          ref
              .read(shadowingRecordingControllerProvider.notifier)
              .startRecording(promptId: promptId, referenceText: referenceText),
        );
      });
    }

    // 句子时长和时间戳
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
        onPlayPause: () {
          unawaited(_cancelRecordingAndPlayback());
          if (playerState.isPauseBetweenPlays) {
            ref
                .read(shadowingRecordingControllerProvider.notifier)
                .clearRecording();
            player.replayDuringCountdown();
          } else if (playerState.isPlaying) {
            player.pause();
          } else {
            player.resume();
          }
        },
        onPrevious: () {
          unawaited(_cancelRecordingAndPlayback());
          ref
              .read(shadowingRecordingControllerProvider.notifier)
              .clearRecording();
          player.goToPrevious();
        },
        onNext: () {
          unawaited(_cancelRecordingAndPlayback());
          ref
              .read(shadowingRecordingControllerProvider.notifier)
              .clearRecording();
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
                  onPressed: () =>
                      showDifficultPracticeSettingsSheet(context: context),
                ),
              ],
            ),
            body: Column(
              children: [
                // 进度区域
                PracticeProgressSection(
                  current: playerState.currentSentenceIndex + 1,
                  total: playerState.totalSentences,
                  progressText: l10n.reviewDifficultPracticeProgress(
                    playerState.currentSentenceIndex + 1,
                    playerState.totalSentences,
                  ),
                  durationText: durationText,
                ),

                // 主体内容：盲听/跟读 双态切换
                Expanded(
                  child: playerState.isAnnotationMode
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                          ),
                          child: AnnotationWithRecording(
                            text: currentSentence?.text ?? '',
                            playerState: playerState,
                            l10n: l10n,
                            isDifficult: currentSentence?.isBookmarked ?? true,
                            onToggleMark: _handleToggleDifficult,
                            aiNotifier: ref.read(sentenceAiNotifierProvider),
                            audioItemId: widget.audioItemId,
                            sentenceIndex: player.currentIndex,
                            sentenceStartMs:
                                currentSentence?.startTime.inMilliseconds,
                            sentenceEndMs:
                                currentSentence?.endTime.inMilliseconds,
                            onStopMainPlayer: () {
                              ref.read(reviewDifficultPracticeProvider.notifier)
                                ..enterManualForSentence()
                                ..notifyExternalStop();
                              ref
                                  .read(
                                    shadowingRecordingControllerProvider
                                        .notifier,
                                  )
                                  .cancelActiveRecording();
                            },
                            turnState: turnState,
                            currentPromptId: currentPromptId,
                            currentAttempt: currentAttempt,
                            isRecordingCurrent: isRecordingCurrent,
                            isPlayingAttempt:
                                _playingPromptId == currentPromptId,
                            onRecordTap: _handleRecordTap,
                            onAttemptPlaybackTap: _handleAttemptPlaybackTap,
                            onFastForward: () => ref
                                .read(reviewDifficultPracticeProvider.notifier)
                                .completePausedTurn(),
                            onCountdownPause: () => ref
                                .read(
                                  reviewDifficultPracticeProvider.notifier,
                                )
                                .pausePostEvalCountdown(),
                            onCountdownResume: () => ref
                                .read(
                                  reviewDifficultPracticeProvider.notifier,
                                )
                                .resumePostEvalCountdown(),
                            onToolbarButtonTapped: () {
                              if (playerState.isManualMode) return;
                              ref
                                  .read(
                                    reviewDifficultPracticeProvider.notifier,
                                  )
                                  .enterManualForSentence();
                              ref
                                  .read(
                                    shadowingRecordingControllerProvider
                                        .notifier,
                                  )
                                  .cancelActiveRecording();
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
                                reviewDifficultPracticeProvider.select(
                                  (s) => (
                                    show:
                                        s.isPauseBetweenPlays &&
                                        !s.isManualMode,
                                    remaining: s.pauseRemaining,
                                    total: s.pauseDuration,
                                    paused: s.isCountdownPaused,
                                  ),
                                ),
                              );
                              if (!s.show) return const SizedBox.shrink();
                              return CountdownChip(
                                remaining: s.remaining,
                                total: s.total,
                                isPaused: s.paused,
                                onPause: () => player.pauseCountdown(),
                                onResume: () => player.resumeCountdown(),
                              );
                            },
                          ),
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onToggleMark: _handleToggleDifficult,
                          isDifficult: currentSentence?.isBookmarked ?? true,
                          sentenceText: currentSentence?.text,
                          onWordTap: currentSentence != null
                              ? (word) => showWordDictionarySheet(
                                  context: context,
                                  word: word,
                                  audioItemId: widget.audioItemId,
                                  sentenceIndex: currentSentence.index,
                                  sentenceText: currentSentence.text,
                                  sentenceStartMs:
                                      currentSentence.startTime.inMilliseconds,
                                  sentenceEndMs:
                                      currentSentence.endTime.inMilliseconds,
                                )
                              : null,
                        ),
                ),

                // 底部播放控制
                PlaybackControls(
                  canGoPrev: playerState.currentSentenceIndex > 0,
                  isLast:
                      playerState.currentSentenceIndex >=
                      playerState.totalSentences - 1,
                  centerIcon: playerState.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPrevious: () {
                    unawaited(_cancelRecordingAndPlayback());
                    ref
                        .read(shadowingRecordingControllerProvider.notifier)
                        .clearRecording();
                    player.goToPrevious();
                  },
                  onNext: () {
                    unawaited(_cancelRecordingAndPlayback());
                    ref
                        .read(shadowingRecordingControllerProvider.notifier)
                        .clearRecording();
                    final isLast =
                        playerState.currentSentenceIndex >=
                        playerState.totalSentences - 1;
                    if (isLast) {
                      player.stopPlayback();
                      _handleCompleted();
                    } else {
                      unawaited(player.goToNext());
                    }
                  },
                  onCenter: () {
                    unawaited(_cancelRecordingAndPlayback());
                    if (playerState.isPauseBetweenPlays) {
                      ref
                          .read(shadowingRecordingControllerProvider.notifier)
                          .clearRecording();
                      player.replayDuringCountdown();
                    } else if (playerState.isPlaying) {
                      player.pause();
                    } else {
                      player.resume();
                    }
                  },
                ),

                // 遍数 + 模式指示器
                PracticePlayCountLabel(
                  isManualMode: playerState.isManualMode,
                  playCountText: l10n.listenAndRepeatPlayCount(
                    playerState.currentPlayCount,
                    playerState.isAnnotationMode
                        ? playerState.targetRepeatCount
                        : (playerState.isManualMode
                              ? 1
                              : playerState
                                    .settings
                                    .blindListenRepeatCount),
                  ),
                  l10n: l10n,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 子步骤本地化名称
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

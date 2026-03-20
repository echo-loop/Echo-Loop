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
import '../database/providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../services/app_logger.dart';
import '../services/audio_playback_service.dart';
import '../utils/wakelock_mixin.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/practice/practice_playback_controls.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_shadow_reading_view.dart';

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

  /// 用户在当前句手动停止过录音 → 本句不再自动录音/倒计时
  bool _manualStoppedThisSentence = false;

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
      final settings = ref.read(reviewDifficultPracticeProvider).settings;
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
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
      _manualStoppedThisSentence = true;
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

    _manualStoppedThisSentence = true;

    final recState = ref.read(shadowingRecordingControllerProvider);
    final attempt = recState.currentAttempt;
    final filePath = attempt?.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() => _playingPromptId = promptId);
    await _playbackService.play(filePath);
  }

  /// 处理退出
  Future<void> _handleExit() async {
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
      // 取消退出 → 恢复播放（标注模式下不恢复）
      if (mounted) {
        final currentState = ref.read(reviewDifficultPracticeProvider);
        if (!currentState.isAnnotationMode) {
          player.resume();
        }
      }
      return;
    }

    await _exit();
  }

  /// 执行退出（保存断点、释放录音后退出）
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();

    // 保存当前句子索引作为断点
    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    await ref
        .read(learningProgressNotifierProvider.notifier)
        .saveDifficultPracticeSentenceIndex(
          widget.audioItemId,
          player.currentIndex,
        );

    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 取消当前句子的难句标记
  Future<void> _handleRemoveDifficult() async {
    await _cancelRecordingAndPlayback();
    ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();
    _manualStoppedThisSentence = false;

    final player = ref.read(reviewDifficultPracticeProvider.notifier);
    final removed = player.removeDifficultMark();

    if (removed != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(widget.audioItemId, removed.index);
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final playerState = ref.read(reviewDifficultPracticeProvider);
    if (playerState.totalSentences > 0) {
      await player.startPlaying();
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
      nextStepName = nextSubStage.label;
    }

    return (
      stepIndex: currentIdx,
      totalSteps: subStages.length,
      stageName: stage.label,
      nextStepName: nextStepName,
      isLastStep: isLast,
    );
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isExiting || !mounted) return;

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
          .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.reviewDifficultPracticeCompleteTitle,
        message: l10n.reviewDifficultPracticeCompleteMessage(
          playerState.totalSentences,
        ),
        onStudyAgain: () async {
          _manualStoppedThisSentence = false;
          await ref
              .read(reviewDifficultPracticeProvider.notifier)
              .resetToStart();
        },
        onExit: () async {
          await ref.read(learningSessionProvider.notifier).exitLearningMode();
          if (mounted) context.pop();
        },
      );
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

    if (!mounted || result == null) return;

    // 用户确认后：清除断点 + 标记完成
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveDifficultPracticeSentenceIndex(widget.audioItemId, null);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('难句补练完成处理出错: $e');
    }

    if (result.action == StepCompleteAction.continueNext && stepCtx.nextStepName != null) {
      // 继续下一步 → 退出当前模式，返回计划页让路由分发
      await ref.read(learningSessionProvider.notifier).exitLearningMode();
      if (mounted) context.pop();
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

    final playerState = ref.watch(reviewDifficultPracticeProvider);
    final player = ref.read(reviewDifficultPracticeProvider.notifier);

    // watch 录音相关状态
    final turnState = ref.watch(shadowingRecordingControllerProvider);

    // 监听句子切换 + 自动播完信号 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(reviewDifficultPracticeProvider, (
      prev,
      next,
    ) {
      // 句子切换时清除上一句的录音结果，为下一句自动录音做准备
      if (prev != null &&
          prev.currentSentenceIndex != next.currentSentenceIndex) {
        _manualStoppedThisSentence = false;
        ref
            .read(shadowingRecordingControllerProvider.notifier)
            .clearRecording();
      }
      // 控制模式切换时同步到录音控制器
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final controller = ref.read(
          shadowingRecordingControllerProvider.notifier,
        );
        controller.setManualMode(next.settings.isManualMode);
        if (next.settings.isManualMode) {
          final recState = ref.read(shadowingRecordingControllerProvider);
          if (recState.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
              recState.phase == ListenAndRepeatTurnPhase.speaking) {
            controller.cancelActiveRecording();
          }
        }
      }
    });

    // 评估完成 → 启动 review countdown（仅跟读模式）
    ref.listen<ListenAndRepeatTurnState>(shadowingRecordingControllerProvider, (
      prev,
      next,
    ) {
      if (prev?.phase == ListenAndRepeatTurnPhase.processing &&
          next.phase == ListenAndRepeatTurnPhase.idle &&
          next.currentAttempt != null) {
        final latestState = ref.read(reviewDifficultPracticeProvider);
        if (latestState.isPauseBetweenPlays &&
            latestState.isAnnotationMode &&
            !latestState.settings.isManualMode &&
            !_manualStoppedThisSentence) {
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

    // 手动模式 + 盲听停顿中 → 立即暂停倒计时，等用户手动下一句
    if (!playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        playerState.settings.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(reviewDifficultPracticeProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
      });
    }

    // 跟读模式 + 停顿中 + recording idle + 非倒计时中 → 暂停倒计时 + 自动录音
    if (playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        currentSentence != null &&
        !playerState.settings.isManualMode &&
        turnState.phase == ListenAndRepeatTurnPhase.idle &&
        !playerState.isPostEvalCountdown &&
        !_manualStoppedThisSentence) {
      final promptId = currentPromptId;
      final referenceText = currentSentence.text;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestRecState = ref.read(shadowingRecordingControllerProvider);
        if (latestRecState.phase != ListenAndRepeatTurnPhase.idle) return;
        final latestPlayer = ref.read(reviewDifficultPracticeProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays) {
          return;
        }
        if (_manualStoppedThisSentence) return;

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

    // 手动模式 + 跟读模式 + 停顿中 → 暂停倒计时，等用户点击录音
    if (playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        playerState.settings.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(reviewDifficultPracticeProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(reviewDifficultPracticeProvider.notifier).pauseCountdown();
      });
    }

    // 句子时长
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
        unawaited(_cancelRecordingAndPlayback());
        if (playerState.isPauseBetweenPlays) {
          _manualStoppedThisSentence = false;
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
        _manualStoppedThisSentence = false;
        unawaited(_cancelRecordingAndPlayback());
        ref
            .read(shadowingRecordingControllerProvider.notifier)
            .clearRecording();
        player.goToPrevious();
      },
      onNext: () {
        _manualStoppedThisSentence = false;
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
                tooltip: l10n.difficultPracticeSettings,
                onPressed: () =>
                    showDifficultPracticeSettingsSheet(context: context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度区域
              PracticeProgressSection(
                playerState: playerState,
                l10n: l10n,
                durationText: durationText,
              ),

              // 主体内容：盲听/跟读 双态切换
              Expanded(
                child: playerState.isAnnotationMode
                    ? PracticeShadowReadingView(
                        text: currentSentence?.text ?? '',
                        playerState: playerState,
                        l10n: l10n,
                        onRemoveMark: _handleRemoveDifficult,
                        aiNotifier: ref.read(sentenceAiNotifierProvider),
                        audioItemId: widget.audioItemId,
                        sentenceIndex: player.currentIndex,
                        recording: RecordingConfig(
                          turnState: turnState,
                          currentPromptId: currentPromptId,
                          currentAttempt: currentAttempt,
                          isRecordingCurrent: isRecordingCurrent,
                          isPlayingAttempt: _playingPromptId == currentPromptId,
                          onRecordTap: _handleRecordTap,
                          onAttemptPlaybackTap: _handleAttemptPlaybackTap,
                          pauseRemaining: playerState.pauseRemaining,
                          pauseDuration: playerState.pauseDuration,
                          isCountdownPaused: playerState.isCountdownPaused,
                          isPostEvalCountdown: playerState.isPostEvalCountdown,
                          onFastForward: () => ref
                              .read(reviewDifficultPracticeProvider.notifier)
                              .completePausedTurn(),
                          onCountdownTap: () {
                            final p = ref.read(
                              reviewDifficultPracticeProvider.notifier,
                            );
                            playerState.isCountdownPaused
                                ? p.resumePostEvalCountdown()
                                : p.pausePostEvalCountdown();
                          },
                        ),
                      )
                    : PracticeNormalModeView(
                        playerState: playerState,
                        l10n: l10n,
                        theme: theme,
                        onPeekToggle: () =>
                            player.setTextRevealed(!playerState.isTextRevealed),
                        onCantUnderstand: () => player.enterAnnotationMode(),
                        onRemoveMark: _handleRemoveDifficult,
                        onPauseCountdown: () => playerState.isCountdownPaused
                            ? player.resumeCountdown()
                            : player.pauseCountdown(),
                        sentenceText: currentSentence?.text,
                      ),
              ),

              // 底部播放控制
              PracticePlaybackControls(
                playerState: playerState,
                onPrevious: () {
                  _manualStoppedThisSentence = false;
                  unawaited(_cancelRecordingAndPlayback());
                  ref
                      .read(shadowingRecordingControllerProvider.notifier)
                      .clearRecording();
                  player.goToPrevious();
                },
                onNext: () {
                  _manualStoppedThisSentence = false;
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
                onPlayPause: () {
                  unawaited(_cancelRecordingAndPlayback());
                  if (playerState.isPauseBetweenPlays) {
                    _manualStoppedThisSentence = false;
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

              // 遍数
              PracticePlayCountLabel(
                playerState: playerState,
                l10n: l10n,
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

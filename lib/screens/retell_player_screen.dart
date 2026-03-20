/// 复述播放器页面
///
/// 段落复述的核心交互页面。
/// 布局: AppBar → 进度条 → 句子列表 → (录音结果卡) → 阶段指示器 → 底部控制。
/// 支持 listening/retelling 双阶段切换、显示模式循环。
/// retelling 阶段通过 [RetellRecordingController] 驱动录音识别流程。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../l10n/app_localizations.dart';
import '../models/retell_settings.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/retell_player_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart'
    show ListenAndRepeatTurnPhase, ListenAndRepeatTurnState;
import '../providers/retell_recording_controller_provider.dart';
import '../services/app_logger.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/listen_and_repeat/speech_record_button.dart';
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/retell/retell_sentence_tile.dart';
import '../widgets/retell/retell_settings_sheet.dart';
import '../widgets/common/paragraph_bottom_controls.dart';
import '../widgets/common/paragraph_progress_header.dart';
import '../widgets/player_hotkey_scope.dart';

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

class _RetellPlayerScreenState extends ConsumerState<RetellPlayerScreen>
    with WakelockMixin {
  bool _isShowingDialog = false;

  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 用户在当前段手动停止过录音 → 本段不再自动录音/倒计时
  bool _manualStoppedThisParagraph = false;

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
      final settings = ref.read(retellPlayerProvider).settings;
      ref
          .read(retellRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
      ref.read(retellPlayerProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _playbackService.dispose();
    super.dispose();
  }

  /// 构造当前段落的 promptId
  String _currentPromptId() {
    final state = ref.read(retellPlayerProvider);
    return 'retell:${widget.audioItemId}:${state.currentParagraphIndex}';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(retellPlayerProvider.notifier);
    final settings = ref.read(retellPlayerProvider).settings;
    final paragraphDuration = player.currentParagraphDuration;
    final controller = ref.read(retellRecordingControllerProvider.notifier);

    final maxRecording = settings.calculateRetellingDuration(paragraphDuration);
    AppLogger.log('RetellScreen', '更新阈值: 静音=20s, '
        '最大录音=${maxRecording.inMilliseconds}ms');
    controller.setSilenceTimeout(const Duration(seconds: 20));
    controller.setMaxRecordingDuration(maxRecording);
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final state = ref.read(retellPlayerProvider);
    if (state.phase != RetellPhase.retelling) return;

    final controller = ref.read(retellRecordingControllerProvider.notifier);
    final player = ref.read(retellPlayerProvider.notifier);
    final recState = ref.read(retellRecordingControllerProvider);

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('RetellScreen', '手动停止录音 → 本段退出自动模式');
      _manualStoppedThisParagraph = true;
      await controller.stopAndEvaluate(
        referenceText: player.currentParagraphReferenceText,
      );
      return;
    }

    // 如果在倒计时中点击录音，取消倒计时
    if (state.isRetellCountdown) {
      player.cancelCountdown();
    }

    // 停止录音回放
    await _stopPlayback();

    AppLogger.log('RetellScreen', '手动开始录音: '
        '段落${ref.read(retellPlayerProvider).currentParagraphIndex + 1}');
    _updateRecordingThresholds();
    await controller.startRecording(
      promptId: promptId,
      referenceText: player.currentParagraphReferenceText,
    );
  }

  /// 处理录音回放按钮点击。
  ///
  /// 点击播放时取消倒计时、标记本段手动操作过，
  /// 让用户听完录音后自行决定是否重录或继续。
  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    if (_playingPromptId == promptId) {
      await _stopPlayback();
      return;
    }

    final playerState = ref.read(retellPlayerProvider);
    if (playerState.isPlaying) {
      await ref.read(retellPlayerProvider.notifier).pause();
    }

    // 取消段间停顿倒计时
    if (playerState.isRetellCountdown) {
      AppLogger.log('RetellScreen', '播放录音 → 取消倒计时');
      ref.read(retellPlayerProvider.notifier).cancelCountdown();
    }

    // 标记本段手动操作过 → 不再自动录音/倒计时
    AppLogger.log('RetellScreen', '播放录音 → 等待用户操作');
    _manualStoppedThisParagraph = true;

    final recState = ref.read(retellRecordingControllerProvider);
    final attempt = recState.currentAttempt;
    final filePath = attempt?.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() => _playingPromptId = promptId);
    await _playbackService.play(filePath);
  }

  /// 停止录音回放
  Future<void> _stopPlayback() async {
    await _playbackService.stop();
    if (mounted) {
      setState(() => _playingPromptId = null);
    }
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    final controller = ref.read(retellRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
    await _stopPlayback();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    await _cancelRecordingAndPlayback();

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final state = ref.read(retellPlayerProvider);

    if (sessionState.isFreePlay) {
      final sentenceIndex = ref
          .read(retellPlayerProvider.notifier)
          .currentParagraphFirstSentenceIndex;
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(widget.audioItemId, sentenceIndex);
      await _exit();
      return;
    }

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
    _isExiting = true;
    await ref.read(retellRecordingControllerProvider.notifier).fullReset();
    await ref.read(learningSessionProvider.notifier).exitLearningMode();
    if (mounted) context.pop();
  }

  /// 获取当前步骤的上下文信息
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
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.read(learningSessionProvider);
    final retellState = ref.read(retellPlayerProvider);

    // 自由练习模式：使用公用弹窗
    if (sessionState.isFreePlay) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementRetellPassCount(widget.audioItemId);

      if (!mounted) { _isShowingDialog = false; return; }

      await handleFreePlayComplete(
        context: context,
        title: l10n.retellCompleteTitle,
        message: l10n.retellCompleteMessage(retellState.totalParagraphs),
        replayLabel: l10n.retellPracticeAgain,
        onStudyAgain: () async {
          await ref
              .read(retellRecordingControllerProvider.notifier)
              .fullReset();
          await ref.read(retellPlayerProvider.notifier).restart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveRetellParagraphIndex(widget.audioItemId, null);
          await _exit();
        },
      );
      _isShowingDialog = false;
      return;
    }

    // 正常学习模式：使用步骤完成弹窗
    final stepCtx = _getStepContext();

    final result = await showStepCompleteDialog(
      context: context,
      title: l10n.retellCompleteTitle,
      contentBody: Text(
        l10n.retellCompleteMessage(retellState.totalParagraphs),
      ),
      stepIndex: stepCtx.stepIndex,
      totalSteps: stepCtx.totalSteps,
      stageName: stepCtx.stageName,
      isLastStep: true,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    await ref
        .read(learningProgressNotifierProvider.notifier)
        .incrementRetellPassCount(widget.audioItemId);

    if (result != null) {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveRetellParagraphIndex(widget.audioItemId, null);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
      await _exit();
    } else {
      // 关闭弹窗 → 留在页面，不做操作
    }
  }

  /// 提示文字行：统一在按钮上方，用颜色区分状态。
  Widget _buildStatusText(
    RetellPlayerState state,
    ListenAndRepeatTurnState turnState,
    SpeechPracticeAttempt? attempt,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    // listening 阶段 / 倒计时阶段：不显示录音提示
    if (state.phase == RetellPhase.listening || state.isRetellCountdown) {
      return const SizedBox.shrink();
    }

    // 评估结果：错误提示放在这里（红色），正常结果由上方结果卡展示
    if (attempt != null && attempt.hasFinalFeedback) {
      final isError =
          attempt.status == SpeechPracticeAttemptStatus.noEnglishDetected ||
          attempt.status == SpeechPracticeAttemptStatus.error ||
          attempt.status == SpeechPracticeAttemptStatus.permissionDenied ||
          attempt.status == SpeechPracticeAttemptStatus.unavailable;
      if (isError) {
        final errorText = switch (attempt.status) {
          SpeechPracticeAttemptStatus.noEnglishDetected =>
            l10n.listenAndRepeatRecognitionNoEnglish,
          SpeechPracticeAttemptStatus.permissionDenied =>
            l10n.listenAndRepeatTapToRecord,
          _ => attempt.errorMessage ?? l10n.listenAndRepeatAnalyzing,
        };
        return Text(
          errorText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      // 正常结果（有分数）且录音空闲：显示"点击录音"引导用户操作
      if (turnState.phase == ListenAndRepeatTurnPhase.idle) {
        return Text(
          l10n.listenAndRepeatTapToRecord,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // 录音状态文字
    return Text(
      switch (turnState.phase) {
        ListenAndRepeatTurnPhase.idle => l10n.listenAndRepeatTapToRecord,
        ListenAndRepeatTurnPhase.speaking =>
          l10n.listenAndRepeatRecordingInProgress,
        ListenAndRepeatTurnPhase.processing => l10n.listenAndRepeatAnalyzing,
        _ => l10n.listenAndRepeatTapToRecord,
      },
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  /// 中间按钮：录音按钮 或 段间停顿倒计时环。
  Widget _buildCenterButton(
    RetellPlayerState state,
    ListenAndRepeatTurnState turnState,
    bool isRecordingCurrent,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    // listening 阶段：耳机图标 + 文字（占据录音按钮位置）
    if (state.phase == RetellPhase.listening) {
      final theme = Theme.of(context);
      return SizedBox(
        height: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones, size: 20, color: theme.colorScheme.primary),
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
      );
    }

    // 段间停顿：倒计时环取代录音按钮
    if (state.isRetellCountdown) {
      return CountdownChip(
        remaining: state.pauseRemaining,
        total: state.pauseDuration,
        isPaused: state.isCountdownPaused,
        onTap: () {
          final p = ref.read(retellPlayerProvider.notifier);
          state.isCountdownPaused ? p.resumeCountdown() : p.pauseCountdown();
        },
      );
    }

    // retelling 阶段：录音按钮
    final isProcessing =
        turnState.phase == ListenAndRepeatTurnPhase.processing;
    return IgnorePointer(
      ignoring: isProcessing,
      child: Opacity(
        opacity: isProcessing ? 0.45 : 1.0,
        child: SpeechRecordButton(
          phase: switch (turnState.phase) {
            ListenAndRepeatTurnPhase.idle ||
            ListenAndRepeatTurnPhase.processing =>
              ListenAndRepeatTurnPhase.waitingForUser,
            final p => p,
          },
          onTap: _handleRecordTap,
        ),
      ),
    );
  }

  /// 重播当前段落
  Future<void> _handleReplay() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '重播当前段落');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).replayDuringCountdown();
  }

  /// 切段：retelling 阶段走 completeRetellingTurn（记录统计 + 遍数逻辑）。
  ///
  /// 最后一段时保留录音结果（badge）和手动标记，避免完成弹窗期间
  /// 触发自动录音或 badge 消失。
  Future<void> _goToNextParagraph() async {
    final retellState = ref.read(retellPlayerProvider);
    final isLastParagraph = retellState.currentParagraphIndex >=
        retellState.totalParagraphs - 1;

    if (!isLastParagraph) {
      _manualStoppedThisParagraph = false;
      ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    }

    AppLogger.log('RetellScreen', '→ 下一段 (last=$isLastParagraph)');
    await _cancelRecordingAndPlayback();

    if (retellState.phase == RetellPhase.retelling) {
      await ref.read(retellPlayerProvider.notifier).completeRetellingTurn();
    } else {
      await ref.read(retellPlayerProvider.notifier).goToNextParagraph();
    }

    // 最后一段 → 直接触发完成处理
    if (isLastParagraph) {
      _handleCompleted();
    }
  }

  Future<void> _goToPreviousParagraph() async {
    _manualStoppedThisParagraph = false;
    AppLogger.log('RetellScreen', '→ 上一段');
    await _cancelRecordingAndPlayback();
    ref.read(retellRecordingControllerProvider.notifier).clearRecording();
    await ref.read(retellPlayerProvider.notifier).goToPreviousParagraph();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = ref.watch(retellPlayerProvider);
    final player = ref.read(retellPlayerProvider.notifier);

    // watch 录音相关状态
    final retellRecState = ref.watch(retellRecordingControllerProvider);

    // 映射为 ListenAndRepeatTurnState 供 SpeechPracticeTurnPanel 复用
    final turnState = _mapToTurnState(retellRecState);

    // 评估完成 → 启动段间停顿倒计时
    ref.listen<RetellRecordingState>(
      retellRecordingControllerProvider,
      (prev, next) {
        if (prev?.phase == RetellRecordingPhase.processing &&
            next.phase == RetellRecordingPhase.idle) {
          final latestState = ref.read(retellPlayerProvider);
          if (latestState.phase == RetellPhase.retelling &&
              !latestState.settings.isManualMode &&
              !_manualStoppedThisParagraph) {
            AppLogger.log('RetellScreen', '评估完成 → 启动段间停顿');
            ref.read(retellPlayerProvider.notifier)
                .startPostEvaluationPause();
          }
        }
      },
    );

    // controlMode 切换 → 同步到录音控制器
    ref.listen<RetellPlayerState>(retellPlayerProvider, (prev, next) {
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final controller =
            ref.read(retellRecordingControllerProvider.notifier);
        controller.setManualMode(next.settings.isManualMode);
        // 切入手动模式时取消正在进行的自动录音和倒计时
        if (next.settings.isManualMode) {
          final recState = ref.read(retellRecordingControllerProvider);
          if (recState.phase == RetellRecordingPhase.recording) {
            controller.cancelActiveRecording();
          }
          if (next.isRetellCountdown) {
            ref.read(retellPlayerProvider.notifier).cancelCountdown();
          }
        }
      }
    });

    // 自动模式录音触发：
    // retelling + 未完成 + 非手动模式 + recording idle + 未超时 + 非倒计时中 + 本段未手动停止过
    if (state.phase == RetellPhase.retelling &&
        !state.settings.isManualMode &&
        retellRecState.phase == RetellRecordingPhase.idle &&
        !retellRecState.awaitingSpeechTimedOut &&
        !state.isRetellCountdown &&
        !_manualStoppedThisParagraph) {
      final promptId = _currentPromptId();
      final referenceText = player.currentParagraphReferenceText;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestRecState = ref.read(retellRecordingControllerProvider);
        if (latestRecState.phase != RetellRecordingPhase.idle) return;
        if (latestRecState.awaitingSpeechTimedOut) return;
        final latestState = ref.read(retellPlayerProvider);
        if (latestState.phase != RetellPhase.retelling) return;
        if (latestState.isRetellCountdown) return;
        if (_manualStoppedThisParagraph) return;

        AppLogger.log('RetellScreen', '自动开始录音: '
            '段落${latestState.currentParagraphIndex + 1}');
        _updateRecordingThresholds();
        unawaited(
          ref
              .read(retellRecordingControllerProvider.notifier)
              .startRecording(
                promptId: promptId,
                referenceText: referenceText,
              ),
        );
      });
    }

    final sentences = player.currentParagraphSentences;
    final paragraphDuration = player.currentParagraphDuration;
    final keywords = player.keywordsMap;
    final progress = (state.totalParagraphs > 0)
        ? (state.currentParagraphIndex + 1) / state.totalParagraphs
        : 0.0;

    // 录音结果（从 controller state 获取）
    final currentPromptId = _currentPromptId();
    final currentAttempt = retellRecState.currentAttempt;
    final isRecordingCurrent = retellRecState.isRecordingPrompt(currentPromptId);

    return LearningHotkeyScope(
      onPlayPause: () {
        if (state.phase == RetellPhase.listening) {
          state.isPlaying ? player.pause() : player.resume();
        } else if (state.isRetellCountdown) {
          _handleReplay();
        } else {
          _handleReplay();
        }
      },
      onPrevious: _goToPreviousParagraph,
      onNext: _goToNextParagraph,
      child: PopScope(
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
              ParagraphProgressHeader(
                currentIndex: state.currentParagraphIndex,
                totalParagraphs: state.totalParagraphs,
                paragraphDuration: paragraphDuration,
              ),

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
                        onWordTap: (word) => showWordDictionarySheet(
                          context: context,
                          word: word,
                          audioItemId: widget.audioItemId,
                          sentenceIndex: index,
                          sentenceText: sentence.text,
                          sentenceStartMs: sentence.startTime.inMilliseconds,
                          sentenceEndMs: sentence.endTime.inMilliseconds,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 评级 badge（点击播放录音）
              if (currentAttempt != null && currentAttempt.score != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Center(
                    child: SpeechRatingBadge(
                      l10n: l10n,
                      attempt: currentAttempt,
                      isPlaying: _playingPromptId == currentPromptId,
                      onTap: () =>
                          _handleAttemptPlaybackTap(currentPromptId),
                      thresholds: RatingThresholds.retell,
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.s),

              // 显示模式切换
              if (state.settings.keywordMethod != KeywordMethod.off)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 360;
                      final keywordsOnlyLabel = _displayModeLabel(
                        context,
                        regularText: l10n.retellDisplayKeywordsOnly,
                        compactEnglishText: 'Visible',
                        isCompact: isCompact,
                      );
                      final showAllLabel = _displayModeLabel(
                        context,
                        regularText: l10n.retellDisplayShowAll,
                        compactEnglishText: 'Show',
                        isCompact: isCompact,
                      );
                      final hideAllLabel = _displayModeLabel(
                        context,
                        regularText: l10n.retellDisplayHideAll,
                        compactEnglishText: 'Hide',
                        isCompact: isCompact,
                      );
                      return SegmentedButton<RetellDisplayMode>(
                        direction: isCompact ? Axis.vertical : Axis.horizontal,
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: RetellDisplayMode.hideAll,
                            label: _DisplayModeSegmentLabel(text: hideAllLabel),
                          ),
                          ButtonSegment(
                            value: RetellDisplayMode.keywordsOnly,
                            label: _DisplayModeSegmentLabel(
                              text: keywordsOnlyLabel,
                            ),
                          ),
                          ButtonSegment(
                            value: RetellDisplayMode.showAll,
                            label: _DisplayModeSegmentLabel(text: showAllLabel),
                          ),
                        ],
                        selected: {state.displayMode},
                        onSelectionChanged: (selected) =>
                            player.setDisplayMode(selected.first),
                      );
                    },
                  ),
                ),

              // 提示文字行（固定高度，颜色区分状态）
              SizedBox(
                height: 32,
                child: Center(
                  child: _buildStatusText(
                    state, turnState, currentAttempt, l10n, theme,
                  ),
                ),
              ),

              // 录音按钮 或 段间停顿倒计时（固定位置）
              _buildCenterButton(state, turnState, isRecordingCurrent, l10n, ref),

              const SizedBox(height: AppSpacing.m),

              // 播放控制栏
              ParagraphBottomControls(
                canGoPrev: state.currentParagraphIndex > 0,
                isLastParagraph: state.currentParagraphIndex >=
                    state.totalParagraphs - 1,
                centerIcon: state.phase == RetellPhase.listening
                    ? (state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded)
                    : Icons.play_arrow_rounded,
                onCenter: state.phase == RetellPhase.listening
                    ? (state.isPlaying ? player.pause : player.resume)
                    : _handleReplay,
                onPrevious: _goToPreviousParagraph,
                onNext: _goToNextParagraph,
              ),

              // 遍数（手动模式下隐藏）
              if (!state.settings.isManualMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: Text(
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

/// 将 [RetellRecordingState] 映射为 [ListenAndRepeatTurnState]，
/// 供 [SpeechPracticeTurnPanel] 复用。
ListenAndRepeatTurnState _mapToTurnState(RetellRecordingState rs) {
  return ListenAndRepeatTurnState(
    phase: switch (rs.phase) {
      RetellRecordingPhase.idle => ListenAndRepeatTurnPhase.idle,
      RetellRecordingPhase.recording => ListenAndRepeatTurnPhase.speaking,
      RetellRecordingPhase.processing => ListenAndRepeatTurnPhase.processing,
    },
  );
}

String _displayModeLabel(
  BuildContext context, {
  required String regularText,
  required String compactEnglishText,
  required bool isCompact,
}) {
  if (!isCompact) return regularText;
  return Localizations.localeOf(context).languageCode == 'en'
      ? compactEnglishText
      : regularText;
}

/// 显示模式标签
class _DisplayModeSegmentLabel extends StatelessWidget {
  final String text;

  const _DisplayModeSegmentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}


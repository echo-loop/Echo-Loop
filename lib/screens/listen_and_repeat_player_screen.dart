/// 跟读播放器页面
///
/// 难句跟读界面，逐句显示难句文本（带★标记），
/// 用户听完后在停顿时间内跟读。
///
/// 录音通过 [ShadowingRecordingController] 驱动（跟读专用控制器）。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
///
/// 完成处理：所有句子播完 → 完成对话框 → completeCurrentSubStage → 退出
/// 退出处理：PopScope → 保存断点 → exitLearningMode → pop
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/enums.dart';
import '../database/providers.dart';
import '../utils/wakelock_mixin.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/learning_session/listen_and_repeat_player_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/listening_practice/listening_practice_provider.dart';
import '../router/app_router.dart';
import '../services/app_logger.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import '../models/retell_settings.dart';
import '../models/speech_practice_models.dart';
import '../utils/keyword_extraction.dart';
import '../utils/paragraph_grouping.dart';
import '../providers/sentence_ai_provider.dart';
import '../widgets/intensive_listen/sentence_annotation_card.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/listen_and_repeat/listen_and_repeat_settings_sheet.dart';
import '../widgets/listen_and_repeat/speech_practice_turn_panel.dart';
import '../widgets/common/speech_rating_badge.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/retell/retell_briefing_sheet.dart';
import '../widgets/player_hotkey_scope.dart';

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
    extends ConsumerState<ListenAndRepeatPlayerScreen>
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
      final settings = ref.read(listenAndRepeatPlayerProvider).settings;
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
      ref.read(listenAndRepeatPlayerProvider.notifier).startPlaying();
    });
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _playbackService.dispose();
    super.dispose();
  }

  /// 构造当前句子的 promptId
  String _currentPromptId() {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final sentence = player.currentSentence;
    final sentenceIndex = sentence?.index ?? player.currentIndex;
    return 'shadowing:${widget.audioItemId}:$sentenceIndex';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final sentenceDuration = currentSentence.duration;

    // 跟读场景最大录音时长：max(2.5 × sentenceDuration + 5s, 10s)
    final computed = sentenceDuration * 2.5 + const Duration(seconds: 5);
    final maxRecording = computed < const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : computed;

    AppLogger.log(
      'ShadowScreen',
      '更新阈值: '
          '最大录音=${maxRecording.inMilliseconds}ms',
    );
    controller.setMaxRecordingDuration(maxRecording);
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final playerState = ref.read(listenAndRepeatPlayerProvider);
    if (!playerState.isPauseBetweenPlays) return;

    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final recState = ref.read(shadowingRecordingControllerProvider);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
      AppLogger.log('ShadowScreen', '手动停止录音 → 本句退出自动模式');
      _manualStoppedThisSentence = true;
      await controller.stopAndEvaluate(referenceText: currentSentence.text);
      return;
    }

    // 停止录音回放
    await _stopPlayback();

    // 暂停倒计时
    if (!playerState.isCountdownPaused) {
      player.pauseCountdown();
    }

    AppLogger.log('ShadowScreen', '手动开始录音: 句子${player.currentIndex + 1}');
    _updateRecordingThresholds();
    await controller.startRecording(
      promptId: promptId,
      referenceText: currentSentence.text,
    );
  }

  /// 处理录音回放按钮点击
  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    if (_playingPromptId == promptId) {
      await _stopPlayback();
      return;
    }

    final playerState = ref.read(listenAndRepeatPlayerProvider);
    if (playerState.isPlaying) {
      await ref.read(listenAndRepeatPlayerProvider.notifier).pause();
    }

    // 取消评估后倒计时（不推进到下一句）
    ref.read(listenAndRepeatPlayerProvider.notifier).cancelPostEvalCountdown();

    // 标记本句手动操作过 → 不再自动录音/倒计时
    AppLogger.log('ShadowScreen', '播放录音 → 等待用户操作');
    _manualStoppedThisSentence = true;

    final recState = ref.read(shadowingRecordingControllerProvider);
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
    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
    await _stopPlayback();
  }

  /// 处理退出（close 按钮 / 系统返回）
  Future<void> _handleExit() async {
    await _cancelRecordingAndPlayback();
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    await player.pause();
    if (!mounted) return;

    final session = ref.read(learningSessionProvider);
    if (session.isFreePlay) {
      await _saveSentenceProgress();
      await _exit();
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
    await _exit();
  }

  /// 执行退出
  Future<void> _exit() async {
    _isExiting = true;
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();
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

  /// 构建带 AI 翻译/解析回调的句子卡片
  Widget _buildAnnotationCard(
    String text,
    int sentenceIndex, {
    Widget? inlineFeedback,
    List<SpeechTranscriptSegment>? highlightedSegments,
  }) {
    final ai = ref.read(sentenceAiNotifierProvider);
    final cachedTranslation = ai.getCachedTranslation(text)?.translation;
    final cachedAnalysis = ai.getCachedAnalysis(text);
    final cachedAnalysisText = cachedAnalysis?.toDisplayString();

    return SentenceAnnotationCard(
      key: ValueKey(text),
      text: text,
      isDifficult: true,
      onToggle: _handleRemoveDifficult,
      audioItemId: widget.audioItemId,
      sentenceIndex: sentenceIndex,
      inlineFeedback: inlineFeedback,
      highlightedSegments: highlightedSegments,
      onRequestTranslation: () async {
        final result = await ai.getTranslation(text);
        return result.translation;
      },
      onRequestAnalysis: () async {
        final result = await ai.getAnalysis(text);
        return result.toDisplayString();
      },
      cachedTranslation: cachedTranslation,
      cachedAnalysis: cachedAnalysisText,
    );
  }

  /// 取消当前句子的难句收藏
  Future<void> _handleRemoveDifficult() async {
    await _cancelRecordingAndPlayback();
    ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();

    final player = ref.read(listenAndRepeatPlayerProvider.notifier);
    final removed = player.removeDifficultMark();

    if (removed != null) {
      // 从数据库删除书签
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(widget.audioItemId, removed.index);
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final state = ref.read(listenAndRepeatPlayerProvider);
    if (state.totalSentences > 0) {
      _manualStoppedThisSentence = false;
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
    if (_isExiting || !mounted) return;

    final session = ref.read(learningSessionProvider);
    final playerState = ref.read(listenAndRepeatPlayerProvider);

    if (!mounted) return;

    // 自由练习模式：弹窗询问"完成"或"再来一遍"
    if (session.isFreePlay) {
      final l10n = AppLocalizations.of(context)!;
      // 弹窗前递增遍数
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);

      if (!mounted) return;

      await handleFreePlayComplete(
        context: context,
        title: l10n.listenAndRepeatCompleteTitle,
        message: l10n.listenAndRepeatCompleteMessage(
          playerState.totalSentences,
        ),
        onStudyAgain: () async {
          await ref
              .read(shadowingRecordingControllerProvider.notifier)
              .fullReset();
          _manualStoppedThisSentence = false;
          ref.read(listenAndRepeatPlayerProvider.notifier).resetToStart();
        },
        onExit: () async {
          await ref
              .read(learningProgressNotifierProvider.notifier)
              .saveShadowingSentenceIndex(widget.audioItemId, null);
          await _exit();
        },
      );
      return;
    }

    final stepCtx = _getStepContext();

    // 弹窗前保存统计（事实记录，不影响步骤进度）
    try {
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .incrementShadowingPassCount(widget.audioItemId);
    } catch (e) {
      debugPrint('跟读保存统计出错: $e');
    }

    if (!mounted) return;

    final l10nStep = AppLocalizations.of(context)!;
    final result = await showStepCompleteDialog(
      context: context,
      title: l10nStep.listenAndRepeatCompleteTitle,
      contentBody: Text(
        l10nStep.listenAndRepeatCompleteMessage(playerState.totalSentences),
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
          .saveShadowingSentenceIndex(widget.audioItemId, null);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeCurrentSubStage(widget.audioItemId);
    } catch (e) {
      debugPrint('跟读完成处理出错: $e');
    }

    if (result.action == StepCompleteAction.continueNext) {
      // 继续下一步：段落复述
      await _navigateToRetell();
    } else {
      // 返回计划 → 退出
      await _exit();
    }
  }

  /// 导航到段落复述播放器
  ///
  /// 退出跟读模式 → 显示复述简报弹窗 → 分段 + 提取关键词 → 进入复述模式 → pushReplacement
  Future<void> _navigateToRetell() async {
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(listenAndRepeatPlayerProvider);
    final player = ref.read(listenAndRepeatPlayerProvider.notifier);

    // watch 录音相关状态
    final turnState = ref.watch(shadowingRecordingControllerProvider);

    // 监听句子切换 + 自动播完信号
    ref.listen<ListenAndRepeatPlayerState>(listenAndRepeatPlayerProvider, (
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
    });

    // 评估完成 → 启动 review countdown
    ref.listen<ListenAndRepeatTurnState>(shadowingRecordingControllerProvider, (
      prev,
      next,
    ) {
      if (prev?.phase == ListenAndRepeatTurnPhase.processing &&
          next.phase == ListenAndRepeatTurnPhase.idle &&
          next.currentAttempt != null) {
        final latestState = ref.read(listenAndRepeatPlayerProvider);
        if (latestState.isPauseBetweenPlays &&
            !latestState.settings.isManualMode &&
            !_manualStoppedThisSentence) {
          AppLogger.log('ShadowScreen', '评估完成 → 启动 review countdown');
          ref
              .read(listenAndRepeatPlayerProvider.notifier)
              .startPostEvaluationPause();
        }
      }
    });

    // controlMode 切换 → 同步到录音控制器
    ref.listen<ListenAndRepeatPlayerState>(listenAndRepeatPlayerProvider, (
      prev,
      next,
    ) {
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final controller = ref.read(
          shadowingRecordingControllerProvider.notifier,
        );
        controller.setManualMode(next.settings.isManualMode);
        // 切入手动模式时取消正在进行的自动录音
        if (next.settings.isManualMode) {
          final recState = ref.read(shadowingRecordingControllerProvider);
          if (recState.phase == ListenAndRepeatTurnPhase.awaitingSpeech ||
              recState.phase == ListenAndRepeatTurnPhase.speaking) {
            controller.cancelActiveRecording();
          }
        }
      }
    });

    // 自动模式录音触发（对应复述页面的 !state.isRetellCountdown）：
    // 停顿中 + 未完成 + 非手动模式 + recording idle + 非倒计时中 + 本句未手动停止过
    if (playerState.isPauseBetweenPlays &&
        !playerState.settings.isManualMode &&
        turnState.phase == ListenAndRepeatTurnPhase.idle &&
        !playerState.isPostEvalCountdown &&
        !_manualStoppedThisSentence) {
      final currentSentence = player.currentSentence;
      if (currentSentence != null) {
        final promptId = _currentPromptId();
        final referenceText = currentSentence.text;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latestRecState = ref.read(shadowingRecordingControllerProvider);
          if (latestRecState.phase != ListenAndRepeatTurnPhase.idle) return;
          final latestState = ref.read(listenAndRepeatPlayerProvider);
          if (!latestState.isPauseBetweenPlays) return;
          if (_manualStoppedThisSentence) return;

          // 暂停 player 层倒计时（录音由 ShadowingRecordingController 接管）
          if (!latestState.isCountdownPaused) {
            ref.read(listenAndRepeatPlayerProvider.notifier).pauseCountdown();
          }

          AppLogger.log(
            'ShadowScreen',
            '自动开始录音: '
                '句子${latestState.currentSentenceIndex + 1}',
          );
          _updateRecordingThresholds();
          unawaited(
            ref
                .read(shadowingRecordingControllerProvider.notifier)
                .startRecording(
                  promptId: promptId,
                  referenceText: referenceText,
                ),
          );
        });
      }
    }

    final currentSentence = player.currentSentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = turnState.currentAttempt;
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);

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
        unawaited(player.goToPrevious());
      },
      onNext: () {
        _manualStoppedThisSentence = false;
        unawaited(_cancelRecordingAndPlayback());
        ref
            .read(shadowingRecordingControllerProvider.notifier)
            .clearRecording();
        unawaited(player.goToNext());
      },
      child: PopScope(
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
              ),

              // 主体内容：句子卡片
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: SingleChildScrollView(
                    child: currentSentence != null
                        ? _buildAnnotationCard(
                            currentSentence.text,
                            player.currentIndex,
                            highlightedSegments:
                                currentAttempt?.referenceSegments,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // 底部区域：录音/提示 + 播放控制 + 遍数
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.l,
                  right: AppSpacing.l,
                  bottom: AppSpacing.m,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 评级 badge（点击播放录音），和复述页面同位置
                    if (currentAttempt != null && currentAttempt.score != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Center(
                          child: SpeechRatingBadge(
                            l10n: l10n,
                            attempt: currentAttempt,
                            isPlaying: _playingPromptId == currentPromptId,
                            onTap: currentAttempt.hasRecording
                                ? () =>
                                      _handleAttemptPlaybackTap(currentPromptId)
                                : null,
                          ),
                        ),
                      ),
                    // 评估后倒计时 / 录音面板（和复述页面同构）
                    if (_isPostEvalCountdown(playerState))
                      _PostEvalCountdown(
                        playerState: playerState,
                        onFastForward: () => ref
                            .read(listenAndRepeatPlayerProvider.notifier)
                            .completePausedTurn(),
                        onCountdownTap: () {
                          final p = ref.read(
                            listenAndRepeatPlayerProvider.notifier,
                          );
                          playerState.isCountdownPaused
                              ? p.resumePostEvalCountdown()
                              : p.pausePostEvalCountdown();
                        },
                      )
                    else if (playerState.isPauseBetweenPlays)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: SpeechPracticeTurnPanel(
                          l10n: l10n,
                          turnState: turnState,
                          isRecordingCurrent: isRecordingCurrent,
                          onRecordTap: _handleRecordTap,
                          currentAttempt: currentAttempt,
                        ),
                      ),
                    // 播放控制
                    _PlaybackControls(
                      playerState: playerState,
                      onPrevious: () {
                        _manualStoppedThisSentence = false;
                        unawaited(_cancelRecordingAndPlayback());
                        ref
                            .read(shadowingRecordingControllerProvider.notifier)
                            .clearRecording();
                        unawaited(player.goToPrevious());
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
                          // 最后一句：停止播放，直接弹窗
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
                              .read(
                                shadowingRecordingControllerProvider.notifier,
                              )
                              .clearRecording();
                          player.replayDuringCountdown();
                        } else if (playerState.isPlaying) {
                          player.pause();
                        } else {
                          player.resume();
                        }
                      },
                    ),
                    // 遍数（手动模式下隐藏文字但保留占位）
                    Opacity(
                      opacity: playerState.settings.isManualMode ? 0 : 1,
                      child: Text(
                        l10n.listenAndRepeatPlayCount(
                          playerState.currentPlayCount,
                          playerState.settings.repeatCount,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
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

/// 是否处于评估后倒计时状态（对应复述页面的 isRetellCountdown）
bool _isPostEvalCountdown(ListenAndRepeatPlayerState playerState) {
  return playerState.isPostEvalCountdown;
}

/// 评估后倒计时组件：CountdownChip + 快进按钮
class _PostEvalCountdown extends StatelessWidget {
  final ListenAndRepeatPlayerState playerState;
  final VoidCallback onFastForward;
  final VoidCallback onCountdownTap;

  const _PostEvalCountdown({
    required this.playerState,
    required this.onFastForward,
    required this.onCountdownTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24 + AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 32),
              const SizedBox(width: 48),
              CountdownChip(
                remaining: playerState.pauseRemaining,
                total: playerState.pauseDuration,
                isPaused: playerState.isCountdownPaused,
                onTap: onCountdownTap,
              ),
              const SizedBox(width: 48),
              GestureDetector(
                onTap: onFastForward,
                child: Icon(
                  Icons.fast_forward_rounded,
                  size: 32,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶部进度条区域
class _ProgressSection extends StatelessWidget {
  final ListenAndRepeatPlayerState playerState;
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
                l10n.listenAndRepeatProgress(current, total),
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
    final isLastSentence =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    final canGoNext = true;

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
            enabled: canGoNext,
            onTap: onNext,
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

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
import '../models/media_learning_startup.dart';
import '../utils/playback_speed.dart';
import '../utils/wakelock_mixin.dart';
import '../utils/difficulty_from_ratio.dart';
import '../database/providers.dart';
import '../features/chatbot/widgets/sentence_chat_button.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_plan_provider.dart';
import '../providers/learning_progress_provider.dart';
import '../providers/learning_session/intensive_listen_player_provider.dart';
import '../providers/learning_session/learning_session_provider.dart';
import '../providers/intensive_annotation/intensive_annotation_phase.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/favorite_sentence_lifecycle_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_permission_dialog.dart'
    show maybeShowLearningNotificationPrompt;
import '../widgets/speech_permission_dialog.dart';
import '../widgets/intensive_listen/intensive_listen_settings_sheet.dart';
import '../services/app_logger.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/dialogs/step_complete_dialog.dart';
import '../widgets/review/review_briefing_sheet.dart';
import '../widgets/practice/selectable_sentence_text.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/dictionary/dictionary_panel_host.dart';
import '../widgets/practice/sentence_explanation_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/common/managed_media_visual_surface.dart';
import '../widgets/common/practice_media_presentation_host.dart';
import '../widgets/practice/practice_sentence_pager.dart';
import '../widgets/study/study_activity_detector.dart';

/// 精听播放器页面
class IntensiveListenPlayerScreen extends ConsumerStatefulWidget {
  /// 合集 ID（用于返回导航，从独立音频路由进入时为 null）
  final String? collectionId;

  /// 音频项 ID
  final String audioItemId;

  /// 视频入口的延迟启动命令；音频或已初始化路由为 null。
  final MediaLearningStartup? mediaStartup;

  const IntensiveListenPlayerScreen({
    super.key,
    this.collectionId,
    required this.audioItemId,
    this.mediaStartup,
  });

  @override
  ConsumerState<IntensiveListenPlayerScreen> createState() =>
      _IntensiveListenPlayerScreenState();
}

class _IntensiveListenPlayerScreenState
    extends ConsumerState<IntensiveListenPlayerScreen>
    with WakelockMixin {
  /// 逐句精听的横向分页控制器。
  ///
  /// 由页面持有并在 dispose 释放；用户滑动和播放器自动切句都通过它呈现同一套过渡。
  final PracticeSentencePagerController _sentencePager =
      PracticeSentencePagerController();

  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  /// 词典面板宿主（返回/退出时先关面板的 guard 用）
  final GlobalKey<DictionaryPanelHostState> _dictPanelHostKey =
      GlobalKey<DictionaryPanelHostState>();

  /// 是否正在显示完成弹窗，防止重复弹窗
  bool _isShowingDialog = false;

  ProviderSubscription<IntensiveListenState>? _playerSubscription;
  bool _mediaStartupReady = false;
  bool _autoPlayScheduled = false;
  bool _isAutoAdvancingAnnotationPage = false;

  @override
  void initState() {
    super.initState();
    _playerSubscription = ref.listenManual<IntensiveListenState>(
      intensiveListenPlayerProvider,
      (prev, next) {
        if (_isExiting || prev == null) return;
        final nextPhase = next.annotationState?.phase;
        final previousPhase = prev.annotationState?.phase;
        if (nextPhase is WaitingAnnotationPageTransition &&
            (previousPhase is! WaitingAnnotationPageTransition ||
                previousPhase.targetSentenceIndex !=
                    nextPhase.targetSentenceIndex)) {
          unawaited(
            _animatePendingAnnotationAdvance(nextPhase.targetSentenceIndex),
          );
        }
        // 切句即结束查词会话。横滑、自动推进、进度条跳句、底部切句最终都汇入
        // provider 的 goToSentence，所以这里是覆盖全部路径的单一入口。面板与
        // 选区绑在同一个句子上，而 PageView 每页是独立实例，跨句存活会让已经
        // 离屏的旧 owner 继续把焦点和操作条投影到离屏页的几何上。
        if (next.currentSentenceIndex != prev.currentSentenceIndex) {
          _dictPanelHostKey.currentState?.closeIfOpen();
        }
        if (!prev.stepFinished && next.stepFinished) {
          shortenIdleTimeout(5);
          unawaited(_handleCompleted());
        }
        // 设置面板拖动播放速度时即时生效：把新速度推给 AudioEngine，
        // 不必等下一次播放前的 setSpeed。
        if (next.settings.playbackSpeed != prev.settings.playbackSpeed) {
          unawaited(
            ref
                .read(intensiveListenPlayerProvider.notifier)
                .applyPlaybackSpeed(next.settings.playbackSpeed),
          );
        }
      },
    );
    if (widget.mediaStartup == null) {
      final playerState = ref.read(intensiveListenPlayerProvider);
      if (playerState.totalSentences == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppLogger.log(
            'Intensive Screen',
            '恢复路由缺少已初始化会话，返回入口页: audioId=${widget.audioItemId}',
          );
          if (context.canPop()) context.pop();
        });
      } else {
        _scheduleAutoPlay();
      }
    }
  }

  /// 先完成讲解页到下一句的分页动画，再提交 provider 的切句状态。
  Future<void> _animatePendingAnnotationAdvance(int targetSentenceIndex) async {
    if (_isAutoAdvancingAnnotationPage || !mounted) return;
    _isAutoAdvancingAnnotationPage = true;
    try {
      await _sentencePager.animateAndCommit(
        targetSentenceIndex,
        commit: () {
          final commit = ref
              .read(intensiveListenPlayerProvider.notifier)
              .commitPendingAnnotationAdvance(targetSentenceIndex);
          // Provider 已同步切换句索引；新句播放在后台继续时即可开始下一次导航。
          _isAutoAdvancingAnnotationPage = false;
          return commit;
        },
      );
    } finally {
      _isAutoAdvancingAnnotationPage = false;
    }
  }

  /// 当前页面生命周期内只安排一次自动播放。
  void _scheduleAutoPlay() {
    if (_autoPlayScheduled) return;
    _autoPlayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(intensiveListenPlayerProvider.notifier).startPlaying();
    });
  }

  /// 托管组件确认视频与学习会话均 ready 后开放业务 UI。
  void _handleMediaStartupReady() {
    if (!mounted || _mediaStartupReady) return;
    setState(() => _mediaStartupReady = true);
    _scheduleAutoPlay();
  }

  /// 加载或失败阶段直接取消并返回，不保存尚未开始的断点。
  Future<void> _handleMediaStartupExit() async {
    await widget.mediaStartup?.cancel();
    if (mounted) context.pop();
  }

  Widget _wrapMediaStartup(Widget child) {
    final startup = widget.mediaStartup;
    if (startup == null) return child;
    return ManagedMediaVisualSurface(
      loadKey: startup.loadKey,
      load: startup.load,
      cancel: startup.cancel,
      onReady: _handleMediaStartupReady,
      child: child,
    );
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
    // 词典面板开着时本次返回只关面板，不退出页面
    if (_dictPanelHostKey.currentState?.closeIfOpen() ?? false) return;
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
    if (isNowDifficult) {
      if (idx < player.sentences.length) {
        final sentence = player.sentences[idx];
        await ref
            .read(favoriteSentenceLifecycleProvider)
            .save(widget.audioItemId, sentence);
      }
    } else {
      await ref.read(favoriteSentenceLifecycleProvider).remove(
        widget.audioItemId,
        {player.sentences[idx].index},
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
        await ref
            .read(favoriteSentenceLifecycleProvider)
            .save(widget.audioItemId, sentence);
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
      await ref
          .read(favoriteSentenceLifecycleProvider)
          .remove(widget.audioItemId, removedSentenceIndices);
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
        stats: [
          (value: '${playerState.totalSentences}', label: l10n.statSentences),
          (value: '$totalDifficultCount', label: l10n.statDifficultSentences),
        ],
        message: l10n.intensiveListenCompleteHint,
        onStudyAgain: () async {
          ref.read(intensiveListenPlayerProvider.notifier).resetToStart();
        },
        onExit: () async {
          _isExiting = true;
          await ref
              .read(learningSessionProvider.notifier)
              .recordCatchUpCompletionIfAny(widget.audioItemId);
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
      stats: [
        (
          value: '${playerState.totalSentences}',
          label: l10nDialog.statSentences,
        ),
        (
          value: '$totalDifficultCount',
          label: l10nDialog.statDifficultSentences,
        ),
      ],
      contentBody: Text(l10nDialog.intensiveListenCompleteHint),
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

    // 用户确认后：按难句比例自动判定难度 + 清除断点 + 标记完成
    try {
      final autoDifficulty = difficultyFromDifficultRatio(
        playerState.totalSentences,
        totalDifficultCount,
      );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .setDifficulty(widget.audioItemId, autoDifficulty);
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .saveIntensiveListenSentenceIndex(
            widget.audioItemId,
            null,
            isFreePlay: false,
          );
      await ref
          .read(learningProgressNotifierProvider.notifier)
          .completeIntensiveListenAndAutoCompleteShadowingIfNoDifficult(
            widget.audioItemId,
          );
    } catch (e) {
      debugPrint('精听完成处理出错: $e');
    }

    if (!mounted) return;

    // 学习版通知提示只挂在首次学习当前第一任务的完成点。
    // 现行任务顺序下，该任务就是逐句精听。
    await maybeShowLearningNotificationPrompt(context, ref);

    _isExiting = true;
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
    final mediaReady = widget.mediaStartup == null || _mediaStartupReady;

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
          s.usesMediaEngine,
        ),
      ),
    );
    final playerState = ref.read(intensiveListenPlayerProvider);
    final player = ref.read(intensiveListenPlayerProvider.notifier);

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

    return StudyActivityDetector(
      onActivity: player.markStudyActivity,
      child: wakelockBody(
        child: LearningHotkeyScope(
          onPlayPause: mediaReady ? _handleCenter : () {},
          onPrevious: mediaReady ? _handlePrevious : () {},
          onNext: mediaReady ? _handleNext : () {},
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (mediaReady) {
                _handleExit();
              } else {
                _handleMediaStartupExit();
              }
            },
            child: PracticeMediaPresentationHost(
              enabled: playerState.usesMediaEngine,
              audioItemId: widget.audioItemId,
              isPlaying: playerState.isPlaying,
              onPlayPause: _handleCenter,
              builder: (context, presentation, mediaSurface) => Scaffold(
                appBar: presentation.expanded
                    ? null
                    : AppBar(
                        actionsPadding: const EdgeInsets.only(
                          right: AppSpacing.s,
                        ),
                        title: Text(l10n.intensiveListenAppBarTitle),
                        centerTitle: true,
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: mediaReady
                              ? _handleExit
                              : _handleMediaStartupExit,
                        ),
                        actions: [
                          if (mediaReady) ...[
                            // AI 助手入口：打开前暂停自动推进（同设置按钮的处理）。
                            SentenceChatButton(
                              sentenceText: currentSentence?.text ?? '',
                              onBeforeOpen: () {
                                if (playerState.annotationState != null) {
                                  player.onAnnotationUserInteraction();
                                } else {
                                  player.enterWaitingForUserInBlindMode();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune),
                              onPressed: () {
                                if (playerState.annotationState != null) {
                                  player.onAnnotationUserInteraction();
                                } else {
                                  player.enterWaitingForUserInBlindMode();
                                }
                                showIntensiveListenSettingsSheet(
                                  context: context,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                // 词典面板宿主：面板内嵌 body、非 modal（显示期间正文可继续点词）
                body: _wrapMediaStartup(
                  presentation.expanded
                      ? mediaSurface
                      : DictionaryPanelHost(
                          key: _dictPanelHostKey,
                          child: Column(
                            children: [
                              if (playerState.usesMediaEngine) mediaSurface,
                              PracticeProgressBar(
                                current: playerState.currentSentenceIndex + 1,
                                total: playerState.totalSentences,
                                elapsed: currentSentence?.startTime,
                                remaining:
                                    currentSentence == null ||
                                        player.sentences.isEmpty
                                    ? null
                                    : player.sentences.last.endTime -
                                          currentSentence.startTime,
                                onSeek: (i) => ref
                                    .read(
                                      intensiveListenPlayerProvider.notifier,
                                    )
                                    .goToSentence(i),
                              ),
                              PracticeSentenceInfoRow(
                                progressText: l10n.intensiveListenProgress(
                                  playerState.currentSentenceIndex + 1,
                                  playerState.totalSentences,
                                ),
                                durationText: durationText,
                                trailing: BookmarkToggleRow(
                                  isDifficult: playerState.difficultSentences
                                      .contains(
                                        playerState.currentSentenceIndex,
                                      ),
                                  isAutoMarked:
                                      playerState.isCurrentSentenceAutoMarked,
                                  onTap: _toggleAndSaveDifficult,
                                ),
                              ),

                              // 主体内容
                              Expanded(
                                child: PracticeSentencePager(
                                  controller: _sentencePager,
                                  pageViewKey: const ValueKey(
                                    'intensive-sentence-page-view',
                                  ),
                                  currentIndex:
                                      playerState.currentSentenceIndex,
                                  itemCount: player.sentences.length,
                                  isTransitionLocked:
                                      playerState.annotationState?.phase
                                          is WaitingAnnotationPageTransition,
                                  onSentenceSettled: player.goToSentence,
                                  itemBuilder: (context, sentenceIndex) {
                                    final sentence =
                                        player.sentences[sentenceIndex];
                                    final isActivePage =
                                        sentenceIndex ==
                                        playerState.currentSentenceIndex;
                                    // PageView 会同时预建相邻页。讲解态只能属于 provider
                                    // 当前的源句，目标页在横滑期间始终显示盲听内容。
                                    final showAnnotationContent =
                                        isActivePage &&
                                        (playerState.isAnnotationMode ||
                                            playerState.isAnnotationReplay);
                                    final content = showAnnotationContent
                                        ? _AnnotationContent(
                                            child: SentenceExplanationView(
                                              text: sentence.text,
                                              aiNotifier: ref.read(
                                                sentenceAiNotifierProvider,
                                              ),
                                              audioItemId: widget.audioItemId,
                                              sentenceIndex: sentence.index,
                                              sentenceStartMs: sentence
                                                  .startTime
                                                  .inMilliseconds,
                                              sentenceEndMs: sentence
                                                  .endTime
                                                  .inMilliseconds,
                                              onStopMainPlayer: () {
                                                player
                                                    .onAnnotationUserInteraction();
                                              },
                                              onToolbarButtonTapped: () {
                                                player
                                                    .onAnnotationUserInteraction();
                                              },
                                              enableGuide: false,
                                            ),
                                          )
                                        : PracticeNormalModeView(
                                            l10n: l10n,
                                            theme: theme,
                                            isTextRevealed:
                                                isActivePage &&
                                                playerState.isTextRevealed,
                                            showHiddenTextPlaceholderLines:
                                                !playerState.usesMediaEngine ||
                                                !presentation
                                                    .visualTrackVisible,
                                            // 仅当句子初始就是难句时才展示「取消标记 / 重新标记」按钮；
                                            // 否则（任务开始时未标记）只显示「听不太懂」。
                                            alwaysShowToggleButton:
                                                sentence.isBookmarked,
                                            showBookmarkRow: false,
                                            countdown: Consumer(
                                              builder: (context, ref, _) {
                                                final s = ref.watch(
                                                  intensiveListenPlayerProvider.select(
                                                    (s) => (
                                                      show:
                                                          s.isPauseBetweenPlays &&
                                                          !s
                                                              .settings
                                                              .isManualMode,
                                                      total: s.pauseDuration,
                                                      paused:
                                                          s.isCountdownPaused,
                                                      fastForward: s
                                                          .isCountdownFastForward,
                                                    ),
                                                  ),
                                                );
                                                if (!isActivePage || !s.show) {
                                                  return const SizedBox.shrink();
                                                }
                                                return CountdownChip(
                                                  key: ValueKey(
                                                    'blind-countdown-'
                                                    '${playerState.currentSentenceIndex}-'
                                                    '${s.total.inMilliseconds}',
                                                  ),
                                                  total: s.total,
                                                  isPaused: s.paused,
                                                  isFastForward: s.fastForward,
                                                  onTap: player
                                                      .enterWaitingForUserInBlindMode,
                                                  onPause: () =>
                                                      player.pauseCountdown(),
                                                  onResume: () =>
                                                      player.resumeCountdown(),
                                                );
                                              },
                                            ),
                                            isDifficult: playerState
                                                .difficultSentences
                                                .contains(sentenceIndex),
                                            onPeekToggle: () {
                                              player
                                                  .enterWaitingForUserInBlindMode();
                                              player.setTextRevealed(
                                                !playerState.isTextRevealed,
                                              );
                                            },
                                            onToggleMark:
                                                _toggleAndSaveDifficult,
                                            onCantUnderstand: () =>
                                                player.enterAnnotationMode(),
                                            sentenceText: sentence.text,
                                            lookupOrigin:
                                                DictionaryLookupOrigin(
                                                  audioItemId:
                                                      widget.audioItemId,
                                                  sentenceIndex: sentence.index,
                                                  sentenceText: sentence.text,
                                                  sentenceStartMs: sentence
                                                      .startTime
                                                      .inMilliseconds,
                                                  sentenceEndMs: sentence
                                                      .endTime
                                                      .inMilliseconds,
                                                ),
                                            onBeforeLookup: () => player
                                                .enterWaitingForUserInBlindMode(),
                                          );
                                    return KeyedSubtree(
                                      key: ValueKey(
                                        'intensive-sentence-mode-$sentenceIndex-'
                                        '${showAnnotationContent ? 'annotation' : 'blind'}',
                                      ),
                                      child: Column(
                                        children: [Expanded(child: content)],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.m,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (playerState.isAnnotationReplay)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.m,
                                        ),
                                        child: Text(
                                          l10n.intensiveListenReplayingWithSubtitle,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant
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
                                                show: _showAnnotationCountdown(
                                                  s,
                                                ),
                                                sentenceIndex:
                                                    s.currentSentenceIndex,
                                                total: s.pauseDuration,
                                                paused: s.isCountdownPaused,
                                                fastForward:
                                                    s.isCountdownFastForward,
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
                                              isFastForward:
                                                  countdown.fastForward,
                                              onTap: player
                                                  .onAnnotationUserInteraction,
                                              onPause: () =>
                                                  player.pauseCountdown(),
                                              onResume: () =>
                                                  player.resumeCountdown(),
                                            ),
                                          );
                                        },
                                      ),
                                    PracticePlaybackFooter(
                                      canGoPrev:
                                          playerState.currentSentenceIndex > 0,
                                      isLast:
                                          playerState.currentSentenceIndex >=
                                          playerState.totalSentences - 1,
                                      centerIcon: _buildFooterCenterIcon(
                                        playerState,
                                      ),
                                      onPrevious: _handlePrevious,
                                      onNext: _handleNext,
                                      onCenter: _handleCenter,
                                      nextControl:
                                          _showContinueButton(playerState)
                                          ? SizedBox(
                                              width: 128,
                                              height: 48,
                                              child: FilledButton.icon(
                                                key: const ValueKey(
                                                  'intensive-annotation-continue-button',
                                                ),
                                                onPressed: () =>
                                                    player.exitAnnotationMode(),
                                                icon: const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                ),
                                                iconAlignment:
                                                    IconAlignment.end,
                                                label: Text(
                                                  l10n.intensiveListenContinue,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow: TextOverflow.clip,
                                                ),
                                                style: FilledButton.styleFrom(
                                                  shape: const StadiumBorder(),
                                                  fixedSize: const Size(
                                                    128,
                                                    48,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  textStyle: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            )
                                          : null,
                                      nextControlWidth: 128,
                                      isManualMode:
                                          playerState.settings.isManualMode,
                                      playCountText: formatPracticePlayCount(
                                        l10n,
                                        currentCount:
                                            playerState.currentPlayCount,
                                        totalCount:
                                            playerState.settings.isManualMode
                                            ? 1
                                            : playerState.settings.repeatCount,
                                      ),
                                      statusSuffixText: _formatSpeed(
                                        playerState.settings.playbackSpeed,
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
/// 标注模式内容容器，与进度区共享左右边界。
class _AnnotationContent extends StatelessWidget {
  final Widget child;

  const _AnnotationContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 与顶部进度区使用相同边距，保持句次、收藏和讲解内容左右对齐。
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Column(children: [Expanded(child: child)]),
    );
  }
}

bool _showContinueButton(IntensiveListenState playerState) {
  return playerState.isAnnotationMode &&
      !playerState.isAnnotationReplay &&
      !playerState.isPauseBetweenSentences &&
      playerState.annotationState?.phase is! WaitingAnnotationPageTransition;
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
    final playerState = ref.read(intensiveListenPlayerProvider);
    if (playerState.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }
    if (playerState.currentSentenceIndex <= 0) {
      return;
    }
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    // 盲听句间停顿的“上一句”语义是重播当前句，不产生分页切换。
    if (playerState.isPauseBetweenSentences &&
        playerState.annotationState == null) {
      unawaited(player.goToPrevious());
      return;
    }
    unawaited(
      _sentencePager.animateAndCommit(
        playerState.currentSentenceIndex - 1,
        commit: player.goToPrevious,
      ),
    );
  }

  void _handleNext() {
    final playerState = ref.read(intensiveListenPlayerProvider);
    if (playerState.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }
    final player = ref.read(intensiveListenPlayerProvider.notifier);
    final isLast =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    if (isLast) {
      player.stopPlayback();
      unawaited(_handleCompleted());
      return;
    }
    unawaited(
      _sentencePager.animateAndCommit(
        playerState.currentSentenceIndex + 1,
        commit: player.goToNext,
      ),
    );
  }

  void _handleCenter() {
    final playerState = ref.read(intensiveListenPlayerProvider);
    if (playerState.annotationState?.phase is WaitingAnnotationPageTransition) {
      return;
    }
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

/// 统一显示速度标签：始终保留一位小数。
String _formatSpeed(double speed) => formatPlaybackSpeedLabel(speed);

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
      SubStageType.reviewDifficultPractice => l10n.reviewDifficultPracticeTitle,
      SubStageType.reviewRetellParagraph => l10n.stepRetelling,
      SubStageType.reviewRetellSummary => l10n.stepRetelling,
    };

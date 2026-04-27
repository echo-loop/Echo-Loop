/// 收藏句子复习页面
///
/// 从 Favorites Tab 进入，加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练页面（ReviewDifficultPracticeScreen）完全一致：
/// 盲听 N 遍 → 句间停顿 → 自动推进；偷看字幕、听不懂进入跟读模式。
/// 支持手动/自动控制模式切换、跟读自动录音。
///
/// 录音通过 [SpeechRecordingController] 驱动（跟读专用控制器）。
/// 录音回放通过 [AudioPlaybackService] 播放本地 .m4a 文件。
///
/// 额外功能：
/// - 显示当前句子来源音频名称
/// - 跨音频自动切换（loadAudio）
/// - 取消收藏当前句子
/// - 完成后支持"再来一遍"（重新乱序）
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/speech_practice_models.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/repeat_flow/repeat_flow_state.dart';
import '../providers/speech/speech_recording_controller.dart';
import '../providers/sentence_ai_provider.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/speech_permission_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/annotation_content_view.dart';
import '../widgets/common/bookmark_toggle_row.dart';
import '../widgets/common/practice_playback_footer.dart';
import '../widgets/common/recording_button.dart' show RecordingButtonMode;
import '../widgets/common/repeat_practice_panel.dart';
import '../providers/repeat_flow/repeat_flow_phase.dart';

/// 收藏句子复习页面
class BookmarkReviewScreen extends ConsumerStatefulWidget {
  const BookmarkReviewScreen({super.key});

  @override
  ConsumerState<BookmarkReviewScreen> createState() =>
      _BookmarkReviewScreenState();
}

class _BookmarkReviewScreenState extends ConsumerState<BookmarkReviewScreen>
    with WakelockMixin {
  bool _isShowingDialog = false;

  /// 是否正在退出页面，防止退出过程中 listener 触发弹窗
  bool _isExiting = false;

  ProviderSubscription<ReviewDifficultPracticeState>? _playerSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ok = await ensureSpeechReadyForRecording(context, ref);
      if (!mounted) return;
      if (!ok) {
        if (context.canPop()) context.pop();
        return;
      }
      ref.read(bookmarkReviewProvider.notifier).syncRecordingMode();
      ref.read(bookmarkReviewProvider.notifier).startPlaying();
    });
    _playerSubscription = ref.listenManual<ReviewDifficultPracticeState>(
      bookmarkReviewProvider,
      _handlePlayerStateChanged,
    );
  }

  @override
  void dispose() {
    _playerSubscription?.close();
    super.dispose();
  }

  /// 取消录音和回放
  Future<void> _cancelRecordingAndPlayback() async {
    final controller = ref.read(speechRecordingControllerProvider.notifier);
    await controller.cancelActiveRecording();
  }

  /// 处理退出
  Future<void> _handleExit() async {
    _isExiting = true;
    await _cancelRecordingAndPlayback();
    final player = ref.read(bookmarkReviewProvider.notifier);
    player.pause();
    if (!mounted) return;

    // 释放录音
    await ref.read(speechRecordingControllerProvider.notifier).fullReset();

    // 收藏复习无需保存断点，直接退出
    player.disposePlayer();
    if (mounted) context.pop();
  }

  /// 取消当前句子的收藏
  /// 切换当前句子的收藏标记
  Future<void> _handleToggleBookmark() async {
    await ref.read(bookmarkReviewProvider.notifier).toggleCurrentBookmark();
  }

  void _handlePlayerStateChanged(
    ReviewDifficultPracticeState? prev,
    ReviewDifficultPracticeState next,
  ) {
    if (prev != null &&
        prev.currentSentenceIndex != next.currentSentenceIndex) {
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    }

    if (prev != null && !_isExiting) {
      if (!prev.stepFinished && next.stepFinished) {
        shortenIdleTimeout(5);
        unawaited(_handleCompleted());
      }
    }

    if (prev?.isManualMode != next.isManualMode) {
      ref.read(bookmarkReviewProvider.notifier).syncRecordingMode();
    }

    if (next.isPauseBetweenPlays &&
        next.isManualMode &&
        !next.isCountdownPaused) {
      ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
    }
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放录音
    await ref.read(speechRecordingControllerProvider.notifier).fullReset();

    if (!mounted) return;
    final playerState = ref.read(bookmarkReviewProvider);
    final l10n = AppLocalizations.of(context)!;

    await handleFreePlayComplete(
      context: context,
      title: l10n.bookmarkReviewComplete,
      message: l10n.bookmarkReviewCompleteMessage(playerState.totalSentences),
      replayLabel: l10n.bookmarkReviewAgain,
      onStudyAgain: () async {
        await ref.read(bookmarkReviewProvider.notifier).resetToStart();
      },
      onExit: () async {
        ref.read(bookmarkReviewProvider.notifier).disposePlayer();
        if (mounted) context.pop();
      },
    );
    _isShowingDialog = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // select 过滤倒计时 tick（100ms 一次的 remaining 变化），避免整页频繁 rebuild
    // 导致 TapGestureRecognizer 被反复 dispose/重建，点击单词无法触发词典弹窗。
    ref.watch(
      bookmarkReviewProvider.select(
        (s) => (
          s.currentSentenceIndex,
          s.totalSentences,
          s.currentPlayCount,
          s.isPlaying,
          s.isPauseBetweenPlays,
          s.isAnnotationMode,
          s.isTextRevealed,
          s.isCountdownPaused,
          s.stepFinished,
          s.bookmarkVersion,
          s.isManualMode,
          s.settings,
          s.repeatFlowState?.phase.runtimeType,
          s.repeatFlowState?.repeatIndex,
          s.repeatFlowState?.isReviewPlaybackActive,
          s.repeatFlowState?.recordingScore,
          s.blindFlowState?.phase.runtimeType,
        ),
      ),
    );
    final playerState = ref.read(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      speechRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(speechRecordingControllerProvider);

    final currentBookmark = player.currentBookmarkSentence;
    final currentSentence = currentBookmark?.sentence;
    final currentPromptId = player.repeatEngine?.currentPromptId ?? '';
    final currentAttempt = turnState.currentAttempt;

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
                .read(speechRecordingControllerProvider.notifier)
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
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
          player.goToPrevious();
        },
        onNext: () {
          unawaited(_cancelRecordingAndPlayback());
          ref.read(speechRecordingControllerProvider.notifier).clearRecording();
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
              title: Text(l10n.bookmarkReviewTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () {
                    final player = ref.read(bookmarkReviewProvider.notifier);
                    if (playerState.isAnnotationMode) {
                      player.repeatEngine?.onUserInteraction();
                    } else {
                      player.enterWaitingForUserInBlindMode();
                    }
                    showBookmarkReviewSettingsSheet(context: context);
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // 进度区域（含音频来源名称）
                PracticeProgressSection(
                  current: playerState.currentSentenceIndex + 1,
                  total: playerState.totalSentences,
                  progressText: l10n.bookmarkReviewProgress(
                    playerState.currentSentenceIndex + 1,
                    playerState.totalSentences,
                  ),
                  durationText: durationText,
                  audioName: currentBookmark?.audioName,
                  showAudioSource: true,
                  l10n: l10n,
                ),

                // 主体内容：盲听/跟读 双态切换
                Expanded(
                  child: playerState.isAnnotationMode
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                          ),
                          child: currentSentence == null
                              ? const SizedBox.shrink()
                              : Column(
                                  children: [
                                    const SizedBox(height: AppSpacing.s),
                                    BookmarkToggleRow(
                                      isDifficult: currentSentence.isBookmarked,
                                      onTap: _handleToggleBookmark,
                                    ),
                                    const SizedBox(height: AppSpacing.m),
                                    Expanded(
                                      child: AnnotationContentView(
                                        text: currentSentence.text,
                                        aiNotifier: ref.read(
                                          sentenceAiNotifierProvider,
                                        ),
                                        audioItemId:
                                            currentBookmark?.audioItemId,
                                        sentenceIndex: currentBookmark
                                            ?.originalSentenceIndex,
                                        sentenceStartMs: currentSentence
                                            .startTime
                                            .inMilliseconds,
                                        sentenceEndMs: currentSentence
                                            .endTime
                                            .inMilliseconds,
                                        highlightedSegments:
                                            currentAttempt?.referenceSegments,
                                        onStopMainPlayer: () {
                                          player.repeatEngine
                                              ?.enterWaitingForUser();
                                        },
                                        onToolbarButtonTapped: () {
                                          player.repeatEngine
                                              ?.onUserInteraction();
                                        },
                                      ),
                                    ),
                                    _buildAnnotationMiddlePanel(
                                      playerState: playerState,
                                      turnState: turnState,
                                      currentAttempt: currentAttempt,
                                      currentPromptId: currentPromptId,
                                      l10n: l10n,
                                      theme: theme,
                                    ),
                                  ],
                                ),
                        )
                      : PracticeNormalModeView(
                          l10n: l10n,
                          theme: theme,
                          isTextRevealed: playerState.isTextRevealed,
                          countdown: Consumer(
                            builder: (context, ref, _) {
                              final s = ref.watch(
                                bookmarkReviewProvider.select(
                                  (s) => (
                                    show:
                                        s.isPauseBetweenPlays &&
                                        !s.isManualMode,
                                    total: s.pauseDuration,
                                    paused: s.isCountdownPaused,
                                    fastForward: s.isCountdownFastForward,
                                  ),
                                ),
                              );
                              if (!s.show) return const SizedBox.shrink();
                              return CountdownChip(
                                total: s.total,
                                isPaused: s.paused,
                                isFastForward: s.fastForward,
                                onPause: () => player.pauseCountdown(),
                                onResume: () => player.resumeCountdown(),
                              );
                            },
                          ),
                          onPeekToggle: () {
                            player.enterWaitingForUserInBlindMode();
                            player.setTextRevealed(!playerState.isTextRevealed);
                          },
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onToggleMark: _handleToggleBookmark,
                          isDifficult: currentSentence?.isBookmarked ?? true,
                          sentenceText: currentSentence?.text,
                          onWordTap: currentSentence != null
                              ? (word) {
                                  player.enterWaitingForUserInBlindMode();
                                  showWordDictionarySheet(
                                    context: context,
                                    word: word,
                                    audioItemId: currentBookmark?.audioItemId,
                                    sentenceIndex: currentSentence.index,
                                    sentenceText: currentSentence.text,
                                    sentenceStartMs: currentSentence
                                        .startTime
                                        .inMilliseconds,
                                    sentenceEndMs:
                                        currentSentence.endTime.inMilliseconds,
                                  );
                                }
                              : null,
                        ),
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
                  isManualMode: playerState.isManualMode,
                  playCountText: _buildPlayCountText(playerState, l10n),
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

  Widget _buildAnnotationMiddlePanel({
    required ReviewDifficultPracticeState playerState,
    required SpeechRecordingState turnState,
    required SpeechPracticeAttempt? currentAttempt,
    required String currentPromptId,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    final flowState = playerState.repeatFlowState;
    if (flowState == null) return const SizedBox.shrink();
    final engine = ref.read(bookmarkReviewProvider.notifier).repeatEngine;
    void noop() {}

    final isPlaying = flowState.phase is PlayingPrompt;
    final isInPause = flowState.isInPause;
    final showCountdown = flowState.isCountingDown;

    final isRecording = turnState.isRecordingPrompt(currentPromptId);
    final recordingMode = isRecording
        ? RecordingButtonMode.recording
        : RecordingButtonMode.idle;
    final isProcessingState =
        turnState.promptId == currentPromptId &&
        turnState.phase == SpeechRecordingPhase.processing;

    return RepeatPracticePanel(
      l10n: l10n,
      theme: theme,
      recordingMode: recordingMode,
      isProcessing: isProcessingState,
      currentAttempt: currentAttempt,
      hintText: isPlaying ? l10n.listenAndRepeatListenHint : null,
      showCountdown: showCountdown,
      isInPause: isInPause,
      countdownWidget: showCountdown
          ? Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final phase = ref.watch(
                    bookmarkReviewProvider.select(
                      (s) => s.repeatFlowState?.phase,
                    ),
                  );
                  if (phase is! WaitingInterval) {
                    return const SizedBox.shrink();
                  }
                  return CountdownChip(
                    total: phase.total,
                    isPaused: phase.isPaused,
                    isFastForward: phase.speed > 1.0,
                    onPause: engine?.pauseInterval ?? noop,
                    onResume: engine?.resumeInterval ?? noop,
                  );
                },
              ),
            )
          : null,
      onRecordTap: () {
        if (engine == null) return;
        unawaited(engine.onRecordButtonTapped());
      },
      onFastForward:
          showCountdown &&
              flowState.phase is WaitingInterval &&
              !(flowState.phase as WaitingInterval).isPaused
          ? (engine?.fastForwardInterval ?? noop)
          : null,
      onBeforePlayback: engine != null
          ? () => engine.prepareForPlayback()
          : null,
    );
  }

  IconData _buildFooterCenterIcon(ReviewDifficultPracticeState playerState) {
    final flowState = playerState.repeatFlowState;
    if (playerState.isAnnotationMode && flowState != null) {
      return _isRepeatPromptPlaybackActive(flowState)
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded;
    }
    return _isBlindSentencePlaybackActive(playerState)
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
  }

  bool _isRepeatPromptPlaybackActive(RepeatFlowState flowState) {
    return flowState.phase is PlayingPrompt &&
        !flowState.isWaitingForUser &&
        !flowState.isCountingDown;
  }

  bool _isBlindSentencePlaybackActive(ReviewDifficultPracticeState state) {
    return state.isPlaying &&
        !state.isPauseBetweenPlays &&
        !state.isPauseBetweenSentences &&
        !state.isCountdownPaused;
  }

  String _buildPlayCountText(
    ReviewDifficultPracticeState playerState,
    AppLocalizations l10n,
  ) {
    if (playerState.isAnnotationMode && playerState.repeatFlowState != null) {
      final flowState = playerState.repeatFlowState!;
      return l10n.listenAndRepeatPlayCount(
        flowState.repeatIndex + 1,
        playerState.targetRepeatCount,
      );
    }
    return l10n.listenAndRepeatPlayCount(
      playerState.currentPlayCount,
      playerState.isManualMode
          ? 1
          : playerState.settings.blindListenRepeatCount,
    );
  }

  void _handlePrevious() {
    final player = ref.read(bookmarkReviewProvider.notifier);
    unawaited(_cancelRecordingAndPlayback());
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    unawaited(player.goToPrevious());
  }

  void _handleNext() {
    final playerState = ref.read(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);
    unawaited(_cancelRecordingAndPlayback());
    ref.read(speechRecordingControllerProvider.notifier).clearRecording();
    final isLast =
        playerState.currentSentenceIndex >= playerState.totalSentences - 1;
    if (isLast) {
      player.forceComplete();
      unawaited(_handleCompleted());
      return;
    }
    unawaited(player.goToNext());
  }

  void _handleCenter() {
    final playerState = ref.read(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);
    final engine = player.repeatEngine;
    unawaited(_cancelRecordingAndPlayback());
    if (playerState.isAnnotationMode && engine != null) {
      final flowState = playerState.repeatFlowState;
      if (flowState?.isInPause ?? false) {
        ref.read(speechRecordingControllerProvider.notifier).clearRecording();
        unawaited(engine.replayCurrentSentence());
      } else if (flowState?.phase is PlayingPrompt) {
        engine.enterWaitingForUser();
      } else {
        unawaited(engine.replayCurrentSentence());
      }
      return;
    }
    if (playerState.isPauseBetweenPlays) {
      ref.read(speechRecordingControllerProvider.notifier).clearRecording();
      unawaited(player.replayDuringCountdown());
    } else if (playerState.isPlaying) {
      player.pause();
    } else {
      unawaited(player.resume());
    }
  }
}

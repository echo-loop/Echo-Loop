/// 收藏句子复习页面
///
/// 从 Favorites Tab 进入，加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练页面（ReviewDifficultPracticeScreen）完全一致：
/// 盲听 N 遍 → 句间停顿 → 自动推进；偷看字幕、听不懂进入跟读模式。
/// 支持手动/自动控制模式切换、跟读自动录音。
///
/// 录音通过 [ShadowingRecordingController] 驱动（跟读专用控制器）。
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

import '../database/providers.dart';
import '../providers/listening_practice/bookmark_manager.dart';
import '../l10n/app_localizations.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/shadowing/shadowing_recording_controller.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/audio_playback_service.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/intensive_listen/word_dictionary_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/common/countdown_chip.dart';
import '../widgets/practice/annotation_with_recording.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/common/playback_controls.dart';
import '../widgets/practice/practice_progress_section.dart';

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
      final playerState = ref.read(bookmarkReviewProvider);
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .setManualMode(playerState.isManualMode);
      ref.read(bookmarkReviewProvider.notifier).startPlaying();
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
    final player = ref.read(bookmarkReviewProvider.notifier);
    final bookmark = player.currentBookmarkSentence;
    final sentenceIndex =
        bookmark?.originalSentenceIndex ?? player.currentIndex;
    final audioItemId = bookmark?.audioItemId ?? '';
    return 'bookmark:$audioItemId:$sentenceIndex';
  }

  /// 更新录音相关阈值
  void _updateRecordingThresholds() {
    final player = ref.read(bookmarkReviewProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final sentenceDuration = currentSentence.duration;

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
    final playerState = ref.read(bookmarkReviewProvider);
    if (!playerState.isPauseBetweenPlays || !playerState.isAnnotationMode) {
      return;
    }

    final player = ref.read(bookmarkReviewProvider.notifier);
    final controller = ref.read(shadowingRecordingControllerProvider.notifier);
    final recState = ref.read(shadowingRecordingControllerProvider);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId();
    if (recState.isRecordingPrompt(promptId)) {
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

    final playerState = ref.read(bookmarkReviewProvider);
    if (playerState.isPlaying) {
      ref.read(bookmarkReviewProvider.notifier).pause();
    }

    // 取消评估后倒计时（不推进到下一句）
    ref.read(bookmarkReviewProvider.notifier).cancelPostEvalCountdown();

    ref.read(bookmarkReviewProvider.notifier).enterManualForSentence();

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
    final player = ref.read(bookmarkReviewProvider.notifier);
    player.pause();
    if (!mounted) return;

    // 释放录音
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();

    // 收藏复习无需保存断点，直接退出
    player.disposePlayer();
    if (mounted) context.pop();
  }

  /// 取消当前句子的收藏
  /// 切换当前句子的收藏标记
  Future<void> _handleToggleBookmark() async {
    final player = ref.read(bookmarkReviewProvider.notifier);
    final sentence = player.currentBookmarkSentence;
    if (sentence == null) return;

    final isCurrentlyBookmarked = sentence.sentence.isBookmarked;
    player.toggleCurrentBookmark();

    final bookmarkDao = ref.read(bookmarkDaoProvider);
    if (isCurrentlyBookmarked) {
      await bookmarkDao.removeBookmark(
        sentence.audioItemId,
        sentence.originalSentenceIndex,
      );
    } else {
      await BookmarkManager.addBookmarkToDb(
        sentence.audioItemId,
        sentence.sentence,
        dao: bookmarkDao,
      );
    }
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || _isExiting || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放录音
    await ref.read(shadowingRecordingControllerProvider.notifier).fullReset();

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

    final playerState = ref.watch(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);

    // watch 录音相关状态（仅监听 build 中实际使用的字段，避免转录更新触发重建）
    ref.watch(
      shadowingRecordingControllerProvider.select(
        (s) => (s.phase, s.currentAttempt, s.promptId),
      ),
    );
    final turnState = ref.read(shadowingRecordingControllerProvider);

    // 监听句子切换 + 自动播完信号 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(bookmarkReviewProvider, (
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
        final latestState = ref.read(bookmarkReviewProvider);
        if (latestState.isPauseBetweenPlays &&
            latestState.isAnnotationMode &&
            !latestState.isManualMode) {
          ref.read(bookmarkReviewProvider.notifier).startPostEvaluationPause();
        }
      }
    });

    final currentBookmark = player.currentBookmarkSentence;
    final currentSentence = currentBookmark?.sentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = turnState.currentAttempt;
    final isRecordingCurrent = turnState.isRecordingPrompt(currentPromptId);

    // 手动模式 + 停顿中 → 暂停倒计时（盲听和跟读均适用）
    if (playerState.isPauseBetweenPlays &&
        playerState.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(bookmarkReviewProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
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
        final latestPlayer = ref.read(bookmarkReviewProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays ||
            latestPlayer.isManualMode) {
          return;
        }

        if (!latestPlayer.isCountdownPaused) {
          ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
        }

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
              title: Text(l10n.bookmarkReviewTitle),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _handleExit,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () =>
                      showBookmarkReviewSettingsSheet(context: context),
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
                  l10n: l10n,
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
                            onToggleMark: _handleToggleBookmark,
                            aiNotifier: ref.read(sentenceAiNotifierProvider),
                            audioItemId: currentBookmark?.audioItemId,
                            sentenceIndex:
                                currentBookmark?.originalSentenceIndex,
                            sentenceStartMs:
                                currentSentence?.startTime.inMilliseconds,
                            sentenceEndMs:
                                currentSentence?.endTime.inMilliseconds,
                            onStopMainPlayer: () {
                              ref.read(bookmarkReviewProvider.notifier)
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
                                .read(bookmarkReviewProvider.notifier)
                                .completePausedTurn(),
                            onCountdownPause: () => ref
                                .read(bookmarkReviewProvider.notifier)
                                .pausePostEvalCountdown(),
                            onCountdownResume: () => ref
                                .read(bookmarkReviewProvider.notifier)
                                .resumePostEvalCountdown(),
                            onToolbarButtonTapped: () {
                              if (playerState.isManualMode) return;
                              ref
                                  .read(bookmarkReviewProvider.notifier)
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
                                bookmarkReviewProvider.select(
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
                          onToggleMark: _handleToggleBookmark,
                          isDifficult: currentSentence?.isBookmarked ?? true,
                          sentenceText: currentSentence?.text,
                          onWordTap: currentSentence != null
                              ? (word) => showWordDictionarySheet(
                                  context: context,
                                  word: word,
                                  audioItemId: currentBookmark?.audioItemId,
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
                      player.forceComplete();
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

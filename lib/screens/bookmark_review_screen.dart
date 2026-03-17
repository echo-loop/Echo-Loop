/// 收藏句子复习页面
///
/// 从 Favorites Tab 进入，加载所有收藏句子，按音频分组乱序后逐句复习。
/// 交互模式与难句补练页面（ReviewDifficultPracticeScreen）完全一致：
/// 盲听 N 遍 → 句间停顿 → 自动推进；偷看字幕、听不懂进入跟读模式。
/// 支持手动/自动控制模式切换、跟读自动录音。
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
import '../l10n/app_localizations.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../providers/speech_practice_session_provider.dart';
import '../utils/wakelock_mixin.dart';
import '../widgets/dialogs/free_play_complete_dialog.dart';
import '../widgets/difficult_practice/difficult_practice_settings_sheet.dart';
import '../widgets/player_hotkey_scope.dart';
import '../widgets/practice/practice_normal_mode_view.dart';
import '../widgets/practice/practice_play_count_label.dart';
import '../widgets/practice/practice_playback_controls.dart';
import '../widgets/practice/practice_progress_section.dart';
import '../widgets/practice/practice_shadow_reading_view.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 注册 TurnController 回调
      final turnController = ref.read(
        listenAndRepeatTurnControllerProvider.notifier,
      );
      turnController.setOnContinue(
        () => ref.read(bookmarkReviewProvider.notifier).completePausedTurn(),
      );
      // 同步初始控制模式
      turnController.setManualMode(
        ref.read(bookmarkReviewProvider).settings.isManualMode,
      );
      ref.read(bookmarkReviewProvider.notifier).startPlaying();
    });
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

  /// 录音相关清理（切句/退出前调用）
  Future<void> _prepareForExternalPlaybackAction() async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    await speech.cancelActiveRecording();
    await speech.stopAttemptPlayback();
    ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
    // 重新注册回调（clearTurn 会清空 _onContinue）
    ref
        .read(listenAndRepeatTurnControllerProvider.notifier)
        .setOnContinue(
          () => ref.read(bookmarkReviewProvider.notifier).completePausedTurn(),
        );
  }

  /// 处理录音按钮点击
  Future<void> _handleRecordTap() async {
    final playerState = ref.read(bookmarkReviewProvider);
    if (!playerState.isPauseBetweenPlays || !playerState.isAnnotationMode) {
      return;
    }

    final player = ref.read(bookmarkReviewProvider.notifier);
    final turn = ref.read(listenAndRepeatTurnControllerProvider.notifier);
    final currentSentence = player.currentSentence;
    if (currentSentence == null) return;

    final promptId = _currentPromptId();
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    if (speech.isRecordingPrompt(promptId)) {
      await turn.handleManualStop();
      return;
    }

    if (!playerState.isCountdownPaused) {
      player.pauseCountdown();
    }
    await turn.startManualRecording(
      promptId: promptId,
      referenceText: currentSentence.text,
      sentenceDuration: currentSentence.duration,
    );
  }

  /// 处理录音回放点击
  Future<void> _handleAttemptPlaybackTap(String promptId) async {
    final speech = ref.read(speechPracticeSessionProvider.notifier);
    final speechState = ref.read(speechPracticeSessionProvider);
    if (speechState.playingPromptId == promptId) {
      await speech.stopAttemptPlayback();
      return;
    }

    // 暂停原句播放
    final playerState = ref.read(bookmarkReviewProvider);
    if (playerState.isPlaying) {
      ref.read(bookmarkReviewProvider.notifier).pause();
    }
    await speech.playAttempt(promptId);
  }

  /// 处理退出
  Future<void> _handleExit() async {
    await _prepareForExternalPlaybackAction();
    final player = ref.read(bookmarkReviewProvider.notifier);
    player.pause();
    if (!mounted) return;

    // 释放麦克风
    await ref.read(speechPracticeSessionProvider.notifier).disposeSession();

    // 收藏复习无需保存断点，直接退出
    player.disposePlayer();
    if (mounted) context.pop();
  }

  /// 取消当前句子的收藏
  Future<void> _handleRemoveBookmark() async {
    await _prepareForExternalPlaybackAction();
    final player = ref.read(bookmarkReviewProvider.notifier);
    final removed = player.removeBookmark();

    if (removed != null) {
      final bookmarkDao = ref.read(bookmarkDaoProvider);
      await bookmarkDao.removeBookmark(
        removed.audioItemId,
        removed.originalSentenceIndex,
      );
    }

    // 如果还有句子且未完成，自动开始播放下一句
    final playerState = ref.read(bookmarkReviewProvider);
    if (!playerState.isCompleted && playerState.totalSentences > 0) {
      await player.startPlaying();
    }
  }

  /// 处理完成
  Future<void> _handleCompleted() async {
    if (_isShowingDialog || !mounted) return;
    _isShowingDialog = true;

    // 完成时释放麦克风
    await ref.read(speechPracticeSessionProvider.notifier).disposeSession();

    final playerState = ref.read(bookmarkReviewProvider);
    final l10n = AppLocalizations.of(context)!;

    final result = await showFreePlayCompleteDialog(
      context: context,
      title: l10n.bookmarkReviewComplete,
      message: l10n.bookmarkReviewCompleteMessage(playerState.totalSentences),
      replayLabel: l10n.bookmarkReviewAgain,
    );

    _isShowingDialog = false;
    if (!mounted) return;

    if (result == true) {
      // 完成退出
      ref.read(bookmarkReviewProvider.notifier).disposePlayer();
      if (mounted) context.pop();
    } else {
      // 再来一遍
      await ref.read(bookmarkReviewProvider.notifier).resetToStart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final playerState = ref.watch(bookmarkReviewProvider);
    final player = ref.read(bookmarkReviewProvider.notifier);
    final speechState = ref.watch(speechPracticeSessionProvider);
    final turnState = ref.watch(listenAndRepeatTurnControllerProvider);

    // 监听完成状态 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(bookmarkReviewProvider, (
      prev,
      next,
    ) {
      if (next.isCompleted && !(prev?.isCompleted ?? false)) {
        _handleCompleted();
      }
      // 控制模式切换时同步到 TurnController，并取消正在进行的自动录音
      if (prev?.settings.controlMode != next.settings.controlMode) {
        final turnController = ref.read(
          listenAndRepeatTurnControllerProvider.notifier,
        );
        turnController.setManualMode(next.settings.isManualMode);
        if (next.settings.isManualMode) {
          final turnState = ref.read(listenAndRepeatTurnControllerProvider);
          if (turnState.isActive) {
            unawaited(
              ref
                  .read(speechPracticeSessionProvider.notifier)
                  .cancelActiveRecording(),
            );
            turnController.clearTurn();
          }
        }
      }
    });

    final currentBookmark = player.currentBookmarkSentence;
    final currentSentence = currentBookmark?.sentence;
    final currentPromptId = _currentPromptId();
    final currentAttempt = speechState.attempts[currentPromptId];
    final isRecordingCurrent = speechState.recordingPromptId == currentPromptId;

    // 手动模式 + 盲听停顿中 → 立即暂停倒计时，等用户手动下一句
    if (!playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        playerState.settings.isManualMode &&
        !playerState.isCountdownPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(bookmarkReviewProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
      });
    }

    // 跟读模式 + 停顿中 + TurnController idle → 暂停倒计时 + 自动录音
    if (playerState.isAnnotationMode &&
        playerState.isPauseBetweenPlays &&
        currentSentence != null &&
        turnState.phase == ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latestTurn = ref.read(listenAndRepeatTurnControllerProvider);
        if (latestTurn.phase != ListenAndRepeatTurnPhase.idle) return;
        final latestPlayer = ref.read(bookmarkReviewProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays) {
          return;
        }
        // 暂停 provider 层倒计时（录音由 TurnController 接管）
        if (!latestPlayer.isCountdownPaused) {
          ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
        }
        // 手动模式下不自动开始录音，等用户点击录音按钮
        if (latestPlayer.settings.isManualMode) {
          return;
        }
        unawaited(
          ref
              .read(listenAndRepeatTurnControllerProvider.notifier)
              .ensureAutoTurn(
                promptId: currentPromptId,
                referenceText: currentSentence.text,
                sentenceDuration: currentSentence.duration,
              ),
        );
      });
    }

    // 非停顿状态下清理 TurnController
    if (!playerState.isPauseBetweenPlays &&
        turnState.phase != ListenAndRepeatTurnPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(listenAndRepeatTurnControllerProvider.notifier).clearTurn();
        // 重新注册回调
        ref
            .read(listenAndRepeatTurnControllerProvider.notifier)
            .setOnContinue(
              () => ref
                  .read(bookmarkReviewProvider.notifier)
                  .completePausedTurn(),
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
    final timestampText = hasDuration
        ? '${_formatTimestamp(currentSentence.startTime)}'
              ' - ${_formatTimestamp(currentSentence.endTime)}'
        : null;

    return LearningHotkeyScope(
      onPlayPause: () {
        unawaited(_prepareForExternalPlaybackAction());
        if (playerState.isPauseBetweenPlays) {
          player.replayDuringCountdown();
        } else if (playerState.isPlaying) {
          player.pause();
        } else {
          player.resume();
        }
      },
      onPrevious: () {
        unawaited(_prepareForExternalPlaybackAction());
        player.goToPrevious();
      },
      onNext: () {
        unawaited(_prepareForExternalPlaybackAction());
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
                tooltip: l10n.difficultPracticeSettings,
                onPressed: () =>
                    showBookmarkReviewSettingsSheet(context: context),
              ),
            ],
          ),
          body: Column(
            children: [
              // 进度区域（含音频来源名称）
              PracticeProgressSection(
                playerState: playerState,
                l10n: l10n,
                durationText: durationText,
                audioName: currentBookmark?.audioName,
                timestampText: timestampText,
              ),

              // 主体内容：盲听/跟读 双态切换
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: playerState.isAnnotationMode
                      ? PracticeShadowReadingView(
                          key: const ValueKey('shadow'),
                          text: currentSentence?.text ?? '',
                          playerState: playerState,
                          l10n: l10n,
                          onRemoveMark: _handleRemoveBookmark,
                          aiNotifier: ref.read(sentenceAiNotifierProvider),
                          audioItemId: currentBookmark?.audioItemId,
                          sentenceIndex: currentBookmark?.originalSentenceIndex,
                          recording: RecordingConfig(
                            turnState: turnState,
                            speechState: speechState,
                            currentPromptId: currentPromptId,
                            currentAttempt: currentAttempt,
                            isRecordingCurrent: isRecordingCurrent,
                            onRecordTap: _handleRecordTap,
                            onAttemptPlaybackTap: _handleAttemptPlaybackTap,
                            onFastForward: () => ref
                                .read(
                                  listenAndRepeatTurnControllerProvider
                                      .notifier,
                                )
                                .fastForwardReviewCountdown(),
                            onCountdownTap: turnState.isReviewCountdownPaused
                                ? () => ref
                                      .read(
                                        listenAndRepeatTurnControllerProvider
                                            .notifier,
                                      )
                                      .resumeReviewCountdown()
                                : () => ref
                                      .read(
                                        listenAndRepeatTurnControllerProvider
                                            .notifier,
                                      )
                                      .pauseReviewCountdown(),
                          ),
                        )
                      : PracticeNormalModeView(
                          key: const ValueKey('normal'),
                          playerState: playerState,
                          l10n: l10n,
                          theme: theme,
                          onPeekToggle: () => player.setTextRevealed(
                            !playerState.isTextRevealed,
                          ),
                          onCantUnderstand: () => player.enterAnnotationMode(),
                          onRemoveMark: _handleRemoveBookmark,
                          onPauseCountdown: () => playerState.isCountdownPaused
                              ? player.resumeCountdown()
                              : player.pauseCountdown(),
                          sentenceText: currentSentence?.text,
                        ),
                ),
              ),

              // 底部播放控制
              PracticePlaybackControls(
                playerState: playerState,
                onPrevious: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  player.goToPrevious();
                },
                onNext: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  final isLast =
                      playerState.currentSentenceIndex >=
                      playerState.totalSentences - 1;
                  if (isLast) {
                    player.forceComplete();
                  } else if (playerState.isPauseBetweenPlays &&
                      playerState.isAnnotationMode) {
                    // 跟读停顿中：走 completePausedTurn（递增遍数或推进）
                    unawaited(player.completePausedTurn());
                  } else {
                    unawaited(player.goToNext());
                  }
                },
                onPlayPause: () {
                  unawaited(_prepareForExternalPlaybackAction());
                  if (playerState.isPauseBetweenPlays) {
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

/// 格式化时间戳为 MM:SS.m 格式
String _formatTimestamp(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final tenths = (d.inMilliseconds % 1000) ~/ 100;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss.$tenths';
  }
  return '$mm:$ss.$tenths';
}

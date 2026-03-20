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
import '../l10n/app_localizations.dart';
import '../providers/learning_session/bookmark_review_provider.dart';
import '../providers/learning_session/review_difficult_practice_provider.dart';
import '../providers/listen_and_repeat_turn_controller_provider.dart';
import '../providers/sentence_ai_provider.dart';
import '../services/audio_playback_service.dart';
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
      final settings = ref.read(bookmarkReviewProvider).settings;
      ref
          .read(shadowingRecordingControllerProvider.notifier)
          .setManualMode(settings.isManualMode);
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

    final playerState = ref.read(bookmarkReviewProvider);
    if (playerState.isPlaying) {
      ref.read(bookmarkReviewProvider.notifier).pause();
    }

    // 取消评估后倒计时（不推进到下一句）
    ref.read(bookmarkReviewProvider.notifier).cancelPostEvalCountdown();

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
  Future<void> _handleRemoveBookmark() async {
    await _cancelRecordingAndPlayback();
    ref.read(shadowingRecordingControllerProvider.notifier).clearRecording();
    _manualStoppedThisSentence = false;

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
    if (playerState.totalSentences > 0) {
      await player.startPlaying();
    } else {
      // 所有收藏已删除 → 直接触发完成
      _handleCompleted();
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
        _manualStoppedThisSentence = false;
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

    // watch 录音相关状态
    final turnState = ref.watch(shadowingRecordingControllerProvider);

    // 监听句子切换 + 自动播完信号 + 控制模式变化
    ref.listen<ReviewDifficultPracticeState>(bookmarkReviewProvider, (
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
        final latestState = ref.read(bookmarkReviewProvider);
        if (latestState.isPauseBetweenPlays &&
            latestState.isAnnotationMode &&
            !latestState.settings.isManualMode &&
            !_manualStoppedThisSentence) {
          ref.read(bookmarkReviewProvider.notifier).startPostEvaluationPause();
        }
      }
    });

    final currentBookmark = player.currentBookmarkSentence;
    final currentSentence = currentBookmark?.sentence;
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
        final latest = ref.read(bookmarkReviewProvider);
        if (!latest.isPauseBetweenPlays || latest.isCountdownPaused) return;
        ref.read(bookmarkReviewProvider.notifier).pauseCountdown();
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
        final latestPlayer = ref.read(bookmarkReviewProvider);
        if (!latestPlayer.isAnnotationMode ||
            !latestPlayer.isPauseBetweenPlays) {
          return;
        }
        if (_manualStoppedThisSentence) return;

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

    // 手动模式 + 跟读模式 + 停顿中 → 暂停倒计时
    if (playerState.isAnnotationMode &&
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
                child: playerState.isAnnotationMode
                    ? PracticeShadowReadingView(
                        text: currentSentence?.text ?? '',
                        playerState: playerState,
                        l10n: l10n,
                        onRemoveMark: _handleRemoveBookmark,
                        aiNotifier: ref.read(sentenceAiNotifierProvider),
                        audioItemId: currentBookmark?.audioItemId,
                        sentenceIndex: currentBookmark?.originalSentenceIndex,
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
                              .read(bookmarkReviewProvider.notifier)
                              .completePausedTurn(),
                          onCountdownTap: () {
                            final p = ref.read(bookmarkReviewProvider.notifier);
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
                        onRemoveMark: _handleRemoveBookmark,
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
                    player.forceComplete();
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

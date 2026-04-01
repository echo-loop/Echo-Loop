/// 标注模式 + 录音 UI 组合视图
///
/// 布局：BookmarkToggleRow + AnnotationContentView + 录音区域。
/// 用于难句补练和收藏复习页面。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../providers/listen_and_repeat_turn_controller_provider.dart'
    show ListenAndRepeatTurnPhase, ListenAndRepeatTurnState;
import '../../providers/sentence_ai_provider.dart';
import '../../theme/app_theme.dart';
import '../common/bookmark_toggle_row.dart';
import '../common/countdown_chip.dart';
import '../common/speech_rating_badge.dart';
import '../common/recording_button.dart'
    show RecordingButton, RecordingButtonMode;
import '../common/status_label.dart';
import 'annotation_content_view.dart';

/// 标注模式 + 录音 UI 组合
///
/// 布局：BookmarkToggleRow + AnnotationContentView + 录音区域。
class AnnotationWithRecording extends StatelessWidget {
  /// 当前句子文本
  final String text;

  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 是否已标记为难句/收藏
  final bool isDifficult;

  /// 切换标记回调
  final VoidCallback onToggleMark;

  /// AI 翻译/解析服务
  final SentenceAiNotifier? aiNotifier;

  /// 音频项 ID
  final String? audioItemId;

  /// 句子索引
  final int? sentenceIndex;

  /// 句子起始时间（毫秒）
  final int? sentenceStartMs;

  /// 句子结束时间（毫秒）
  final int? sentenceEndMs;

  /// 播放意群前停止主播放
  final VoidCallback? onStopMainPlayer;

  /// 录音控制器状态
  final ListenAndRepeatTurnState turnState;

  /// 当前句子的 promptId
  final String currentPromptId;

  /// 当前录音结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 是否正在录制当前句子
  final bool isRecordingCurrent;

  /// 是否正在播放录音回放
  final bool isPlayingAttempt;

  /// 录音按钮点击
  final VoidCallback onRecordTap;

  /// 录音回放点击
  final void Function(String) onAttemptPlaybackTap;

  /// 快进倒计时（可选，传入后在倒计时旁显示快进按钮）
  final VoidCallback? onFastForward;

  /// 暂停倒计时
  final VoidCallback onCountdownPause;

  /// 恢复倒计时
  final VoidCallback onCountdownResume;

  /// 用户点击工具栏按钮（意群/翻译/解析）时触发，通知外部切换到手动模式
  final VoidCallback? onToolbarButtonTapped;

  const AnnotationWithRecording({
    super.key,
    required this.text,
    required this.playerState,
    required this.l10n,
    required this.isDifficult,
    required this.onToggleMark,
    this.aiNotifier,
    this.audioItemId,
    this.sentenceIndex,
    this.sentenceStartMs,
    this.sentenceEndMs,
    this.onStopMainPlayer,
    required this.turnState,
    required this.currentPromptId,
    this.currentAttempt,
    required this.isRecordingCurrent,
    required this.isPlayingAttempt,
    required this.onRecordTap,
    required this.onAttemptPlaybackTap,
    this.onFastForward,
    required this.onCountdownPause,
    required this.onCountdownResume,
    this.onToolbarButtonTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isCountdown = playerState.isPostEvalCountdown;
    final shouldShowTurnPanel = !isCountdown && playerState.isPauseBetweenPlays;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.s),
        BookmarkToggleRow(isDifficult: isDifficult, onTap: onToggleMark),
        const SizedBox(height: AppSpacing.m),

        // 固定工具栏 + 可滚动句子卡片
        Expanded(
          child: AnnotationContentView(
            text: text,
            aiNotifier: aiNotifier,
            audioItemId: audioItemId,
            sentenceIndex: sentenceIndex,
            sentenceStartMs: sentenceStartMs,
            sentenceEndMs: sentenceEndMs,
            highlightedSegments: currentAttempt?.referenceSegments,
            onStopMainPlayer: onStopMainPlayer,
            onToolbarButtonTapped: onToolbarButtonTapped,
          ),
        ),

        // 评级 badge
        if (currentAttempt != null && currentAttempt!.score != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s,
              bottom: AppSpacing.xs,
            ),
            child: Center(
              child: SpeechRatingBadge(
                l10n: l10n,
                attempt: currentAttempt!,
                isPlaying: isPlayingAttempt,
                onTap: currentAttempt!.hasRecording
                    ? () => onAttemptPlaybackTap(currentPromptId)
                    : null,
              ),
            ),
          ),

        // 底部固定区域
        if (isCountdown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24 + AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CountdownChip(
                      remaining: playerState.pauseRemaining,
                      total: playerState.pauseDuration,
                      isPaused: playerState.isCountdownPaused,
                      onPause: onCountdownPause,
                      onResume: onCountdownResume,
                    ),
                    if (onFastForward != null &&
                        !playerState.isCountdownPaused) ...[
                      const SizedBox(width: 48),
                      GestureDetector(
                        onTap: onFastForward,
                        child: Icon(
                          Icons.fast_forward_rounded,
                          size: 32,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          )
        else if (shouldShowTurnPanel)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Builder(
              builder: (context) {
                final mode = isRecordingCurrent
                    ? switch (turnState.phase) {
                        ListenAndRepeatTurnPhase.idle =>
                          RecordingButtonMode.idle,
                        ListenAndRepeatTurnPhase.awaitingSpeech ||
                        ListenAndRepeatTurnPhase.speaking =>
                          RecordingButtonMode.recording,
                        ListenAndRepeatTurnPhase.processing =>
                          RecordingButtonMode.disabled,
                        _ => RecordingButtonMode.idle,
                      }
                    : RecordingButtonMode.idle;

                final hasError = currentAttempt?.errorMessage != null;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusLabel(
                      text: hasError
                          ? currentAttempt!.errorMessage
                          : switch (mode) {
                              RecordingButtonMode.idle =>
                                l10n.listenAndRepeatTapToRecord,
                              RecordingButtonMode.recording =>
                                l10n.listenAndRepeatRecordingInProgress,
                              RecordingButtonMode.disabled =>
                                l10n.listenAndRepeatAnalyzing,
                            },
                      color: hasError
                          ? Theme.of(context).colorScheme.error
                          : null,
                      bold: hasError,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RecordingButton(mode: mode, onTap: onRecordTap),
                  ],
                );
              },
            ),
          )
        else if (playerState.isPauseBetweenPlays)
          // 无录音 + 停顿中：简单倒计时
          SizedBox(
            height: 124,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n.listenAndRepeatYourTurnHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                CountdownChip(
                  remaining: playerState.pauseRemaining,
                  total: playerState.pauseDuration,
                  isPaused: playerState.isCountdownPaused,
                  onPause: () {},
                  onResume: () {},
                ),
              ],
            ),
          )
        else
          // 播放中 / 其他状态
          SizedBox(
            height: 116,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (playerState.isPlaying)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headphones,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.listenAndRepeatListenHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.m),
      ],
    );
  }
}

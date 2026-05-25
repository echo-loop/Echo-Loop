/// 练习页面共享的中间操作区
///
/// 固定槽位布局，避免状态切换时布局跳动：
/// 1. 状态文字槽位（居中，20px）
/// 2. 间距（8px）
/// 3. 按钮行（56px）：badge(左) + 中间内容(居中) + 快进(右)
///    与 PlaybackControls 同 Row 结构，badge 对齐 prev，快进对齐 next。
/// 4. 底部间距（16px）
///
/// 中间内容、状态文字、评分 badge 均由内部根据状态自动构建。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/speech_practice_models.dart';
import '../../theme/app_theme.dart';
import 'playback_controls.dart' show PlaybackControls;
import 'processing_indicator.dart';
import 'recording_button.dart' show RecordingButton, RecordingButtonMode;
import 'speech_rating_badge.dart';
import 'status_label.dart';

/// 正常状态文字槽位高度
const double _kStatusSlotHeight = 20;

/// 槽位间距
const double _kSlotGap = 8;

/// 按钮行高度
const double _kButtonRowHeight = 56;

/// 按钮行到底部 footer 的间距
const double _kBottomGap = 16;

/// 固定总高度：状态文字(20) + 间距(8) + 按钮行(56) + 底部间距(16) = 100
const double kTurnAreaHeight =
    _kStatusSlotHeight + _kSlotGap + _kButtonRowHeight + _kBottomGap;

/// 错误文案允许双行，避免英文提示在窄屏被截断。
const double _kErrorStatusSlotHeight = 40;

/// 错误模式总高度：错误文案(40) + 间距(8) + 按钮行(56) + 底部间距(16) = 120
const double _kErrorTurnAreaHeight =
    _kErrorStatusSlotHeight + _kSlotGap + _kButtonRowHeight + _kBottomGap;

/// 练习页面共享的中间操作区
class RepeatPracticePanel extends StatelessWidget {
  // ========== 数据 ==========

  /// 录音按钮模式（由调用方根据录音状态计算）
  final RecordingButtonMode recordingMode;

  /// 是否处于评估加载中
  final bool isProcessing;

  /// 当前评估结果
  final SpeechPracticeAttempt? currentAttempt;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  // ========== 状态标志 ==========

  /// 提示文本（如"先听再跟读"，播放中显示）
  final String? hintText;

  /// 是否显示倒计时
  final bool showCountdown;

  /// 是否处于停顿状态（录音/等待/倒计时）
  final bool isInPause;

  // ========== 外部 widget ==========

  /// 倒计时 widget（由调用方通过 Consumer 构建，监听各自的 provider）
  final Widget? countdownWidget;

  // ========== 回调 ==========

  /// 录音按钮点击回调
  final VoidCallback onRecordTap;

  /// 快进回调（非 null 时显示快进按钮）
  final VoidCallback? onFastForward;

  /// badge 播放录音前的准备回调
  final FutureOr<void> Function()? onBeforePlayback;

  // ========== 配置 ==========

  /// 评分阈值
  final RatingThresholds thresholds;

  const RepeatPracticePanel({
    super.key,
    this.recordingMode = RecordingButtonMode.idle,
    this.isProcessing = false,
    this.currentAttempt,
    required this.l10n,
    required this.theme,
    this.hintText,
    required this.showCountdown,
    required this.isInPause,
    this.countdownWidget,
    required this.onRecordTap,
    this.onFastForward,
    this.onBeforePlayback,
    this.thresholds = RatingThresholds.listenAndRepeat,
  });

  @override
  Widget build(BuildContext context) {
    // processing 状态：加载动画独占整个区域（自然高度 > 56px，不适合按钮行）
    if (isProcessing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: SizedBox(
          height: kTurnAreaHeight,
          child: Center(
            child: ProcessingIndicator(text: l10n.listenAndRepeatAnalyzing),
          ),
        ),
      );
    }

    final statusText = _buildStatusText(context);
    final hasStatus = statusText != null;
    final hasBadge = currentAttempt?.hasFinalFeedback ?? false;
    final hasFF = onFastForward != null;
    final statusSlotHeight = _usesExpandedStatusSlot
        ? _kErrorStatusSlotHeight
        : _kStatusSlotHeight;
    final panelHeight = _usesExpandedStatusSlot
        ? _kErrorTurnAreaHeight
        : kTurnAreaHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: SizedBox(
        height: panelHeight,
        child: Column(
          children: [
            // 状态文字槽位（固定高度，AnimatedOpacity 控制显隐）
            SizedBox(
              height: statusSlotHeight,
              child: Center(
                child: AnimatedOpacity(
                  opacity: hasStatus ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: statusText ?? const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: _kSlotGap),
            // 按钮行：badge(左) + 中间内容(居中) + 快进(右)
            // 使用 Stack 让 hintText 可以占满整行宽度，不被左右槽位挤压
            // 固定宽度结构与 PlaybackControls 一致，保证左右槽位对齐 prev/next
            SizedBox(
              height: _kButtonRowHeight,
              child: Stack(
                children: [
                  // 底层：三栏布局（badge + 中间内容 + 快进）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 左槽位：badge（与 prev 按钮同宽同位）
                      SizedBox(
                        width: PlaybackControls.controlButtonSize,
                        height: _kButtonRowHeight,
                        child: OverflowBox(
                          maxWidth: 160,
                          minHeight: 0,
                          alignment: Alignment.center,
                          child: AnimatedOpacity(
                            opacity: hasBadge ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !hasBadge,
                              child: hasBadge
                                  ? SpeechRatingBadge(
                                      l10n: l10n,
                                      attempt: currentAttempt!,
                                      onBeforePlayback:
                                          currentAttempt!.hasRecording
                                          ? onBeforePlayback
                                          : null,
                                      thresholds: thresholds,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                      // 中间槽位：固定宽度与 PlaybackControls 中心按钮一致
                      SizedBox(
                        width: PlaybackControls.controlButtonSize,
                        height: _kButtonRowHeight,
                        child: Center(
                          child: hintText != null
                              ? const SizedBox.shrink()
                              : _buildCenterContent(),
                        ),
                      ),
                      const SizedBox(width: 48),
                      // 右槽位：快进按钮（与 next 按钮同宽同位）
                      SizedBox(
                        width: PlaybackControls.controlButtonSize,
                        height: _kButtonRowHeight,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: hasFF ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !hasFF,
                              child: hasFF
                                  ? GestureDetector(
                                      onTap: onFastForward,
                                      child: Icon(
                                        Icons.fast_forward_rounded,
                                        size: 32,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 顶层：hintText 占满整行居中显示
                  if (hintText != null) Center(child: _buildCenterContent()),
                ],
              ),
            ),
            // 底部间距（与 footer 之间的间距）
            const SizedBox(height: _kBottomGap),
          ],
        ),
      ),
    );
  }

  /// 中间内容（优先级：hintText > countdown > recording > empty）
  Widget _buildCenterContent() {
    // 播放中：显示提示文本
    if (hintText != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            hintText!,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // 倒计时中
    if (showCountdown && countdownWidget != null) {
      return countdownWidget!;
    }

    // 停顿中：录音按钮
    if (isInPause) {
      return RecordingButton(mode: recordingMode, onTap: onRecordTap);
    }

    return const SizedBox.shrink();
  }

  /// 错误文案允许更高的状态槽位（避免英文提示在窄屏截断）。
  bool get _usesExpandedStatusSlot => currentAttempt?.errorMessage != null;

  /// 状态文字（录音提示 / 错误信息）
  Widget? _buildStatusText(BuildContext context) {
    if (!isInPause || isProcessing) return null;

    final errorMessage = currentAttempt?.errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          errorMessage,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (recordingMode == RecordingButtonMode.recording) {
      return StatusLabel(text: l10n.listenAndRepeatRecordingInProgress);
    }

    return null;
  }
}

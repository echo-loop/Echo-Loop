/// 练习页面共享的普通模式视图（盲听 — 文字遮盖/偷看）
///
/// 布局：
/// - 上方：难句/收藏标记行
/// - 中间（Expanded）：隐藏占位 / 偷看文本，整个区域可点击切换字幕显示
/// - 中间下方：偷看字幕标签（提示用户可点击）
/// - 底部固定区：听不懂按钮（居中，与跟读录音按钮同位置） + 倒计时
///
/// 手动模式下隐藏倒计时。
/// 用于难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/learning_session/review_difficult_practice_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/countdown_chip.dart';

/// 普通模式视图（文字遮盖 / 偷看）
class PracticeNormalModeView extends StatelessWidget {
  /// 播放状态
  final ReviewDifficultPracticeState playerState;

  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  /// 切换偷看字幕
  final VoidCallback onPeekToggle;

  /// 听不懂（进入跟读模式）
  final VoidCallback onCantUnderstand;

  /// 取消标记（难句/收藏）
  final VoidCallback onRemoveMark;

  /// 暂停/恢复倒计时
  final VoidCallback onPauseCountdown;

  /// 当前句子文本
  final String? sentenceText;

  const PracticeNormalModeView({
    super.key,
    required this.playerState,
    required this.l10n,
    required this.theme,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onRemoveMark,
    required this.onPauseCountdown,
    this.sentenceText,
  });

  @override
  Widget build(BuildContext context) {
    final isRevealed = playerState.isTextRevealed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句/收藏标记行
          GestureDetector(
            onTap: onRemoveMark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.intensiveListenMarkedDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.bookmark, color: Colors.amber, size: 18),
              ],
            ),
          ),

          // 字幕区域（整个区域可点击切换字幕）
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPeekToggle,
              child: Stack(
                children: [
                  // 字幕内容偏上（-0.4 ≈ 上方 30% 位置）
                  Align(
                    alignment: const Alignment(0, -0.4),
                    child: isRevealed && sentenceText != null
                        ? GestureDetector(
                            onTap: () {}, // 拦截点击，不冒泡到外层
                            child: Text(
                              sentenceText!,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(height: 1.6),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const _HiddenTextPlaceholder(),
                  ),
                  // 偷看字幕标签（固定在字幕区中间偏下）
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _PeekLabel(
                      isRevealed: isRevealed,
                      l10n: l10n,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部固定区：倒计时 + 按钮行
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倒计时（固定 56 高度占位，避免字幕区跳动）
              SizedBox(
                height: 56,
                child: (playerState.isPauseBetweenPlays &&
                        !playerState.settings.isManualMode)
                    ? CountdownChip(
                        remaining: playerState.pauseRemaining,
                        total: playerState.pauseDuration,
                        isPaused: playerState.isCountdownPaused,
                        onTap: onPauseCountdown,
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.m),
              // 取消标记 + 听不懂按钮（并排，统一 tonal 风格）
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: onRemoveMark,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.practiceRemoveMark,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    FilledButton.tonal(
                      onPressed: onCantUnderstand,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        l10n.intensiveListenCantUnderstand,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    ],
                  ),
                ),
              ],
            ),

          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }
}

/// 偷看字幕标签（字幕区下方，提示可点击）
class _PeekLabel extends StatelessWidget {
  final bool isRevealed;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _PeekLabel({
    required this.isRevealed,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRevealed
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          isRevealed
              ? l10n.intensiveListenPeek
              : l10n.intensiveListenPeek,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  const _HiddenTextPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.hearing,
          size: 48,
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: AppSpacing.l),
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 200 - i * 40,
            height: 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}

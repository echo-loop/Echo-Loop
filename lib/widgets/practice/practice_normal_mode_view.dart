/// 练习页面共享的普通模式视图（盲听 — 文字遮盖/偷看）
///
/// 布局：
/// - 上方：难句/收藏标记行
/// - 中间（Expanded）：隐藏占位 / 偷看文本，整个区域可点击切换字幕显示
/// - 中间下方：偷看字幕标签（提示用户可点击）
/// - 底部固定区：听不懂按钮（居中，与跟读录音按钮同位置） + 倒计时
///
/// 用于精听、难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/tappable_wrapper.dart';
import '../../widgets/common/text_context_menu.dart';
import '../../widgets/guide_flow.dart';

/// 普通模式视图（文字遮盖 / 偷看）
class PracticeNormalModeView extends StatelessWidget {
  /// 本地化
  final AppLocalizations l10n;

  /// 主题
  final ThemeData theme;

  /// 当前句子文本是否已显示
  final bool isTextRevealed;

  /// 独立倒计时组件（由调用方通过 Consumer 隔离 tick rebuild）
  ///
  /// 放在固定 56 高度的 SizedBox 内，null 时不显示。
  final Widget? countdown;

  /// 底部标记按钮是否始终显示（false 时仅 isDifficult 为 true 才显示）
  final bool alwaysShowToggleButton;

  /// 切换偷看字幕
  final VoidCallback onPeekToggle;

  /// 听不懂（进入跟读/标注模式）
  final VoidCallback onCantUnderstand;

  /// 切换标记（难句/收藏）
  final VoidCallback onToggleMark;

  /// 当前句子是否已标记为难句/收藏
  final bool isDifficult;

  /// 当前句子文本
  final String? sentenceText;

  /// 点击单词查词回调（null 时不启用逐词点击）
  final void Function(String word)? onWordTap;

  /// 可选：新手引导步骤，用于给「听不太懂」按钮挂 Showcase
  final GuideStep? cantUnderstandStep;

  const PracticeNormalModeView({
    super.key,
    required this.l10n,
    required this.theme,
    required this.isTextRevealed,
    this.countdown,
    this.alwaysShowToggleButton = true,
    required this.onPeekToggle,
    required this.onCantUnderstand,
    required this.onToggleMark,
    this.isDifficult = true,
    this.sentenceText,
    this.onWordTap,
    this.cantUnderstandStep,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句/收藏标记行
          TappableWrapper(
            onTap: onToggleMark,
            feedbackType: TapFeedback.opacity,
            pressedOpacity: 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    isDifficult
                        ? l10n.intensiveListenMarkedDifficult
                        : l10n.intensiveListenNotDifficult,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  isDifficult ? Icons.bookmark : Icons.bookmark_border,
                  color: isDifficult ? Colors.amber : Colors.grey,
                  size: 18,
                ),
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
                    child: isTextRevealed && sentenceText != null
                        ? GestureDetector(
                            onTap: () {}, // 拦截文字区域点击，不冒泡到偷看切换
                            onLongPressStart: (details) => TextContextMenu.show(
                              context,
                              details.globalPosition,
                              sentenceText!,
                            ),
                            onSecondaryTapDown: (details) =>
                                TextContextMenu.show(
                                  context,
                                  details.globalPosition,
                                  sentenceText!,
                                ),
                            child: onWordTap != null
                                ? _TappableText(
                                    text: sentenceText!,
                                    style:
                                        theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.6,
                                        ) ??
                                        const TextStyle(),
                                    onWordTap: onWordTap!,
                                  )
                                : Text(
                                    sentenceText!,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                    ),
                                  ),
                          )
                        : const _HiddenTextPlaceholder(),
                  ),
                  // 偷看字幕标签（固定在字幕区中间偏下）
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _PeekLabel(
                      isRevealed: isTextRevealed,
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
              SizedBox(height: 56, child: countdown),
              const SizedBox(height: AppSpacing.m),
              // 取消标记 + 听不懂按钮（并排）
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (alwaysShowToggleButton || isDifficult) ...[
                      TextButton(
                        onPressed: onToggleMark,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          isDifficult
                              ? l10n.practiceRemoveMark
                              : l10n.practiceAddMark,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    _buildCantUnderstandButton(),
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

  Widget _buildCantUnderstandButton() {
    final button = FilledButton.tonal(
      onPressed: onCantUnderstand,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      ),
      child: Text(
        l10n.intensiveListenCantUnderstand,
        style: theme.textTheme.titleSmall,
      ),
    );
    final step = cantUnderstandStep;
    return step != null ? GuideTarget(step: step, child: button) : button;
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
              ? l10n.intensiveListenHideSubtitle
              : l10n.intensiveListenPeek,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// 去除单词两端的标点符号
String _cleanWord(String word) => word.replaceAll(
  RegExp(
    r'[.,!?;:\-—…、，。！？；："""'
    '()]',
  ),
  '',
);

/// 逐词可点击的文本（Wrap 布局，点击单词触发查词，带按压高亮反馈）
class _TappableText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final void Function(String word) onWordTap;

  const _TappableText({
    required this.text,
    required this.style,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = text.split(RegExp(r'\s+'));
    return Wrap(
      alignment: WrapAlignment.start,
      children: tokens.map((token) {
        final clean = _cleanWord(token);
        if (clean.isEmpty) return Text('$token ', style: style);
        return _TappableWord(
          token: '$token ',
          style: style,
          onTap: () => onWordTap(clean),
        );
      }).toList(),
    );
  }
}

/// 单个可点击单词（按压时显示浅色背景高亮）
class _TappableWord extends StatefulWidget {
  final String token;
  final TextStyle style;
  final VoidCallback onTap;

  const _TappableWord({
    required this.token,
    required this.style,
    required this.onTap,
  });

  @override
  State<_TappableWord> createState() => _TappableWordState();
}

class _TappableWordState extends State<_TappableWord> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final highlightColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.1);
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: _isPressed ? highlightColor : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(widget.token, style: widget.style),
      ),
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

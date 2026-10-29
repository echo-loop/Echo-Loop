/// 练习页面共享的普通模式视图（盲听 — 文字遮盖/偷看）
///
/// 布局：
/// - 上方：难句/收藏标记行
/// - 中间（Expanded）：字幕内容与显隐入口整体居中，整个区域可点击切换
/// - 底部固定区：听不懂按钮（居中，与跟读录音按钮同位置） + 倒计时
///
/// 用于精听、难句补练和收藏复习。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/word_highlight_binding.dart';
import '../../utils/text_normalize.dart';
import '../../widgets/common/tappable_wrapper.dart';
import '../../widgets/common/word_highlight_builder.dart';
import 'selectable_sentence_text.dart';

final _sentenceWordPattern = RegExp(r'\S+');

/// 普通模式视图（文字遮盖 / 偷看）
class PracticeNormalModeView extends StatelessWidget {
  /// 字幕交互区，用于布局回归测试验证提示与占位内容不会重叠。
  static const subtitleRegionKey = ValueKey('practice-subtitle-region');

  /// 耳朵/灰线或字幕正文所在的主要内容区。
  static const subtitleMainRegionKey = ValueKey(
    'practice-subtitle-main-region',
  );

  /// 偷看/隐藏字幕所在的辅助操作区。
  static const subtitleLabelRegionKey = ValueKey(
    'practice-subtitle-label-region',
  );

  /// 标签区下方、操作按钮上方的倒计时预留点击区。
  static const subtitleTrailingTapRegionKey = ValueKey(
    'practice-subtitle-trailing-tap-region',
  );

  /// 主要字幕内容的定位锚点。
  static const subtitleContentGroupKey = ValueKey(
    'practice-subtitle-content-group',
  );

  /// 隐藏字幕骨架的定位锚点。
  static const hiddenPlaceholderKey = ValueKey('practice-hidden-placeholder');

  /// 隐藏字幕骨架中的三条灰线锚点。
  static const hiddenPlaceholderLinesKey = ValueKey(
    'practice-hidden-placeholder-lines',
  );

  /// 偷看/隐藏字幕提示的定位锚点。
  static const peekLabelKey = ValueKey('practice-peek-label');

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
  final VoidCallback onUnclear;

  /// 切换标记（难句/收藏）
  final VoidCallback onToggleMark;

  /// 当前句子是否已标记为难句/收藏
  final bool isDifficult;

  /// 当前句子文本
  final String? sentenceText;

  /// 是否显示隐藏字幕占位中的三条灰线。
  ///
  /// 视频画面可见时可隐藏灰线以减少视觉干扰；隐藏画面后重新显示灰线。
  /// 耳朵图标与字幕显隐入口不受此配置影响。
  final bool showHiddenTextPlaceholderLines;

  /// 是否在内容区顶部显示难句/收藏标记行。
  ///
  /// 精听页会将入口放到顶部进度信息行，此时设为 false，避免重复显示。
  final bool showBookmarkRow;

  /// 普通模式内容区的水平留白。
  ///
  /// 默认保留通用页面的 24 dp；逐句精听由外层分页器负责手势留白。
  final EdgeInsets horizontalPadding;

  /// 查词来源上下文（null 时不启用点词/词组选择，渲染纯文本）
  final DictionaryLookupOrigin? lookupOrigin;

  /// 查词前副作用钩子（如进入等待用户态），点词与词组松手时触发
  final VoidCallback? onBeforeLookup;

  /// 当前句子在原音播放时间轴中的位置；为空时保持原有显示。
  final WordHighlightBinding? wordHighlightBinding;

  const PracticeNormalModeView({
    super.key,
    required this.l10n,
    required this.theme,
    required this.isTextRevealed,
    this.countdown,
    this.alwaysShowToggleButton = true,
    required this.onPeekToggle,
    required this.onUnclear,
    required this.onToggleMark,
    this.isDifficult = true,
    this.sentenceText,
    this.showHiddenTextPlaceholderLines = true,
    this.showBookmarkRow = true,
    this.horizontalPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.l,
    ),
    this.lookupOrigin,
    this.onBeforeLookup,
    this.wordHighlightBinding,
  });

  @override
  Widget build(BuildContext context) {
    final text = sentenceText;
    Widget buildRevealedText(int? activeWordIndex) {
      if (text == null) return const SizedBox.shrink();
      final origin = lookupOrigin;
      return GestureDetector(
        onTap: () {}, // 拦截文字区域点击，不冒泡到偷看切换
        child: origin != null
            ? SelectableSentenceText(
                text: text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                origin: origin,
                onBeforeLookup: onBeforeLookup,
                activeWordIndex: activeWordIndex,
              )
            : _buildStaticSentenceText(
                text,
                theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                theme,
                activeWordIndex,
              ),
      );
    }

    final binding = wordHighlightBinding;
    final subtitleContent = isTextRevealed && text != null
        ? binding == null
              ? buildRevealedText(null)
              : WordHighlightBuilder(
                  text: text,
                  binding: binding,
                  builder: (context, activeWordIndex) =>
                      buildRevealedText(activeWordIndex),
                )
        : KeyedSubtree(
            key: hiddenPlaceholderKey,
            child: _HiddenTextPlaceholder(
              showLines: showHiddenTextPlaceholderLines,
            ),
          );
    final peekLabel = KeyedSubtree(
      key: peekLabelKey,
      child: _PeekLabel(isRevealed: isTextRevealed, l10n: l10n, theme: theme),
    );

    return Padding(
      padding: horizontalPadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.s),

          // 难句/收藏标记行
          if (showBookmarkRow)
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
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    isDifficult ? Icons.bookmark : Icons.bookmark_border,
                    color: isDifficult ? AppTheme.bookmarkColor : Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),

          // 字幕交互区分为互不影响的两个语义区域：主要内容占上方 2/3，
          // 显隐入口占下方 1/3。正文高度和标签位置不再互相牵动。
          Expanded(
            child: SizedBox(
              key: subtitleRegionKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPeekToggle,
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        key: subtitleMainRegionKey,
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: KeyedSubtree(
                                      key: subtitleContentGroupKey,
                                      child: subtitleContent,
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        key: subtitleLabelRegionKey,
                        child: Center(child: peekLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部固定区：倒计时 + 按钮行
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 倒计时预留区与其下方间距在空白状态下也属于字幕显隐入口，
              // 避免视觉上连续的大块空白无法点击。
              GestureDetector(
                key: subtitleTrailingTapRegionKey,
                behavior: HitTestBehavior.opaque,
                onTap: onPeekToggle,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 固定 56 高度占位，避免字幕区随倒计时显隐跳动。
                      SizedBox(height: 56, child: countdown),
                      const SizedBox(height: AppSpacing.m),
                    ],
                  ),
                ),
              ),
              // 取消标记 + 听不懂按钮（并排，主次随 isDifficult 翻转）
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (alwaysShowToggleButton || isDifficult) ...[
                      _buildToggleMarkButton(),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    _buildUnclearButton(),
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

  /// 标记切换按钮与「听不太懂」按钮的稳定 key。
  ///
  /// 两者会在同一个 Row 中按出现与否前后移位，必须用 key 绑定 element；
  /// 否则位置复用会把一个按钮的文字样式插值到另一个按钮，触发 TextStyle 插值异常。
  static const _toggleMarkButtonKey = ValueKey('practice-toggle-mark-button');
  static const _unclearButtonKey = ValueKey('practice-cant-understand-button');

  /// 标记切换按钮
  ///
  /// 主次随 [isDifficult] 翻转：
  /// - 未标记（状态 A）：次操作，OutlinedButton 描边样式
  /// - 已标记（状态 B）：主操作，errorContainer 暖色填充 + 移除 icon，
  ///   明显提醒用户「这句子还在难句池里」
  Widget _buildToggleMarkButton() {
    final cs = theme.colorScheme;
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

    if (isDifficult) {
      return FilledButton.tonal(
        key: _toggleMarkButtonKey,
        onPressed: onToggleMark,
        style: FilledButton.styleFrom(
          backgroundColor: cs.errorContainer,
          foregroundColor: cs.onErrorContainer,
          shape: const StadiumBorder(),
          padding: padding,
          minimumSize: const Size(0, 48),
          textStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_remove_outlined, size: 18),
            const SizedBox(width: 6),
            Text(l10n.practiceRemoveMark),
          ],
        ),
      );
    }

    return OutlinedButton(
      key: _toggleMarkButtonKey,
      onPressed: onToggleMark,
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurfaceVariant,
        side: BorderSide(color: cs.outlineVariant),
        shape: const StadiumBorder(),
        padding: padding,
        minimumSize: const Size(0, 48),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_add_outlined, size: 18),
          const SizedBox(width: 6),
          Text(l10n.practiceAddMark),
        ],
      ),
    );
  }

  /// 听不太懂按钮（始终为 FilledTonal 蓝色填充）
  Widget _buildUnclearButton() {
    final button = FilledButton.tonal(
      key: _unclearButtonKey,
      onPressed: onUnclear,
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        minimumSize: const Size(0, 48),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.question_mark, size: 16),
          const SizedBox(width: 6),
          Text(l10n.intensiveListenUnclear, style: theme.textTheme.titleSmall),
        ],
      ),
    );
    return button;
  }
}

Widget _buildStaticSentenceText(
  String text,
  TextStyle? style,
  ThemeData theme,
  int? activeWordIndex,
) {
  final spans = <InlineSpan>[];
  var lastOffset = 0;
  var wordIndex = 0;
  for (final match in _sentenceWordPattern.allMatches(text)) {
    if (match.start > lastOffset) {
      spans.add(TextSpan(text: text.substring(lastOffset, match.start)));
    }
    final token = match.group(0) ?? '';
    final isWord = normalizeWord(token).isNotEmpty;
    spans.add(
      TextSpan(
        text: token,
        style: isWord && wordIndex == activeWordIndex
            ? TextStyle(
                backgroundColor: AppTheme.wordHighlightBackgroundColor(
                  theme.colorScheme,
                ),
              )
            : null,
      ),
    );
    if (isWord) wordIndex++;
    lastOffset = match.end;
  }
  if (lastOffset < text.length) {
    spans.add(TextSpan(text: text.substring(lastOffset)));
  }
  return Text.rich(TextSpan(style: style, children: spans));
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

/// 隐藏文本占位（灰色线条）
class _HiddenTextPlaceholder extends StatelessWidget {
  final bool showLines;

  const _HiddenTextPlaceholder({this.showLines = true});

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
        if (showLines) ...[
          const SizedBox(height: AppSpacing.l),
          KeyedSubtree(
            key: PracticeNormalModeView.hiddenPlaceholderLinesKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
            ),
          ),
        ],
      ],
    );
  }
}

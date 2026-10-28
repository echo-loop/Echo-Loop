/// 遮盖句子 Tile
///
/// 段落内单个句子的显示组件，支持多种渲染模式：
/// - 按 displayMode 显示关键词/全部显示/全部隐藏（listening 和 retelling 通用）
/// - listening 阶段当前播放句高亮
///
/// 每个词独立渲染（Wrap 子元素数量恒定，切换模式时布局不跳动），
/// 连续遮盖词通过溢出绘制桥接色块实现视觉连续。
///
/// 已收藏的单词/词组/意群在**可见**词上渲染橙色点状下划线（与
/// [SelectableSentenceText] 同一套匹配逻辑与视觉语言）；遮盖词不渲染
/// 下划线，避免给遮盖块泄漏词长之外的额外信息。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../models/word_highlight_binding.dart';
import '../../providers/reading_text_prefs_provider.dart';
import '../../providers/saved_word_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyword_extraction.dart';
import '../../utils/text_normalize.dart';
import '../guide_flow.dart';
import '../practice/sentence_word_selection.dart';
import 'word_highlight_builder.dart';

/// 句子讲解按钮 key 前缀（供 widget test 精准点击，避免点到文本本身）。
@visibleForTesting
const String kMaskedSentenceExplanationHitAreaKeyPrefix =
    'masked-sentence-explanation-hit-area';

/// 句子主体点击区 key 前缀（供 widget test 精准点击，避免受内部文本布局影响）。
@visibleForTesting
const String kMaskedSentenceBodyHitAreaKeyPrefix =
    'masked-sentence-body-hit-area';

/// 句子收藏按钮 key 前缀（供 widget test 精准点击右侧收藏热区）。
@visibleForTesting
const String kMaskedSentenceBookmarkHitAreaKeyPrefix =
    'masked-sentence-bookmark-hit-area';

/// Wrap 子元素间距（px）— 模拟自然空格宽度
const _wordSpacing = 4.0;

/// 遮盖句子 Tile
///
/// 三个独立点击区：
/// - **讲解区**（左侧 32dp 宽，撑满 tile 全高）：`onDetailTap`，点击进入句子讲解页。
/// - **主体区**（中间 Expanded）：`onPlayFromTap`，点击从该句开始播放。
/// - **收藏区**（右侧独立按钮）：`onBookmarkTap`，直接收藏/取消收藏。
class MaskedSentenceTile extends ConsumerWidget {
  /// 句子数据
  final Sentence sentence;

  /// 文本显示模式
  final RetellDisplayMode displayMode;

  /// 该句的关键词词索引集合
  final Set<int> keywordIndices;

  /// 是否为当前播放中的句子
  final bool isPlayingSentence;

  /// 当前句子的原音时间轴；遮盖模式仍不会透露被遮住的词。
  final WordHighlightBinding? wordHighlightBinding;

  /// 是否已收藏
  final bool isBookmarked;

  /// 点击句子主体回调：从该句开始播放
  final VoidCallback? onPlayFromTap;

  /// 点击左侧讲解按钮回调：进入句子讲解页
  final VoidCallback? onDetailTap;

  /// 点击右侧收藏按钮回调：直接切换收藏状态
  final VoidCallback? onBookmarkTap;

  /// 新手引导：讲解按钮 GuideStep（非空时包 GuideTarget 高亮左侧讲解按钮）
  final GuideStep? explanationAreaGuideStep;

  /// 新手引导：主体区 GuideStep（非空时包 GuideTarget 高亮可播放文本区）
  final GuideStep? bodyAreaGuideStep;

  const MaskedSentenceTile({
    super.key,
    required this.sentence,
    required this.displayMode,
    required this.keywordIndices,
    required this.isPlayingSentence,
    this.wordHighlightBinding,
    this.isBookmarked = false,
    this.onPlayFromTap,
    this.onDetailTap,
    this.onBookmarkTap,
    this.explanationAreaGuideStep,
    this.bodyAreaGuideStep,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 收藏索引流式监听：加载中/降级（测试环境无 DB）时为空索引 = 无标记
    final savedSegments = savedWordSegments(
      sentence.text,
      ref.watch(savedTextIndexProvider),
    );
    // 字幕正文样式：主题正文 + 用户的学习内容字号/字体偏好（每句只算一次）
    final textStyle = ref
        .watch(readingTextPrefsNotifierProvider)
        .applyTo(theme.textTheme.bodyMedium ?? const TextStyle());
    final words = tokenize(sentence.text);
    final binding = wordHighlightBinding;
    final Widget sentenceText = binding == null
        ? _buildMaskedText(theme, textStyle, words, savedSegments, null)
        : WordHighlightBuilder(
            text: sentence.text,
            binding: binding,
            builder: (context, activeWordIndex) => _buildMaskedText(
              theme,
              textStyle,
              words,
              savedSegments,
              activeWordIndex,
            ),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isPlayingSentence
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        border: Border(
          left: BorderSide(
            color: isPlayingSentence
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _wrapWithGuide(
              explanationAreaGuideStep,
              _SentenceExplanationHitArea(
                key: ValueKey(
                  '$kMaskedSentenceExplanationHitAreaKeyPrefix-${sentence.index}',
                ),
                theme: theme,
                label:
                    AppLocalizations.of(context)?.viewSentenceExplanation ??
                    'View sentence explanation',
                onTap: onDetailTap,
              ),
            ),
            Expanded(
              child: _wrapWithGuide(
                bodyAreaGuideStep,
                _SentenceBodyHitArea(
                  key: ValueKey(
                    '$kMaskedSentenceBodyHitAreaKeyPrefix-${sentence.index}',
                  ),
                  theme: theme,
                  onTap: onPlayFromTap,
                  child: sentenceText,
                ),
              ),
            ),
            _SentenceBookmarkHitArea(
              key: ValueKey(
                '$kMaskedSentenceBookmarkHitAreaKeyPrefix-${sentence.index}',
              ),
              theme: theme,
              isBookmarked: isBookmarked,
              onTap: onBookmarkTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapWithGuide(GuideStep? step, Widget child) =>
      step == null ? child : GuideTarget(step: step, child: child);

  /// 构建遮盖文本
  Widget _buildMaskedText(
    ThemeData theme,
    TextStyle textStyle,
    List<String> words,
    Map<int, List<(int, int, bool)>> savedSegments,
    int? activeWordIndex,
  ) {
    if (words.isEmpty) return const SizedBox.shrink();

    // 按显示模式渲染（listening 和 retelling 阶段统一逻辑）
    final shouldMask = switch (displayMode) {
      RetellDisplayMode.keywordsOnly => (int idx) => !keywordIndices.contains(
        idx,
      ),
      RetellDisplayMode.showAll => (int idx) => false,
      RetellDisplayMode.hideAll => (int idx) => true,
    };

    return Wrap(
      spacing: _wordSpacing,
      runSpacing: 2,
      children: _buildWordWidgets(
        words,
        shouldMask,
        theme,
        textStyle,
        savedSegments,
        activeWordIndex,
      ),
    );
  }

  /// 构建独立词组件列表
  ///
  /// 每个词独立渲染，保证所有模式下 Wrap children 数量一致。
  /// 连续遮盖词通过溢出绘制桥接色块实现视觉连续。
  List<Widget> _buildWordWidgets(
    List<String> words,
    bool Function(int index) shouldMask,
    ThemeData theme,
    TextStyle textStyle,
    Map<int, List<(int, int, bool)>> savedSegments,
    int? activeWordIndex,
  ) {
    var playbackWordIndex = 0;
    final blocks = <Widget>[];
    for (var i = 0; i < words.length; i++) {
      final isWord = normalizeWord(words[i]).isNotEmpty;
      blocks.add(
        _WordBlock(
          text: words[i],
          isMasked: shouldMask(i),
          isActiveWord: isWord && playbackWordIndex == activeWordIndex,
          isPrevMasked: i > 0 && shouldMask(i) && shouldMask(i - 1),
          isNextMasked:
              i < words.length - 1 && shouldMask(i) && shouldMask(i + 1),
          savedSegments: savedSegments[i],
          theme: theme,
          textStyle: textStyle,
        ),
      );
      if (isWord) playbackWordIndex++;
    }
    return blocks;
  }
}

/// 左侧讲解按钮。
///
/// 固定 32dp 宽，给正文释放更多横向空间；热区随 tile 全高撑开。
class _SentenceExplanationHitArea extends StatelessWidget {
  final VoidCallback? onTap;
  final ThemeData theme;
  final String label;

  const _SentenceExplanationHitArea({
    super.key,
    required this.theme,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      width: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Center(
          child: Icon(
            Icons.auto_awesome,
            size: 18,
            color: Colors.purple.shade400,
          ),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: label,
      child: Tooltip(
        message: label,
        child: onTap == null
            ? inner
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  // 背景在外层 AnimatedContainer 上，splash 会被遮挡，仅用 highlight 反馈
                  splashColor: Colors.transparent,
                  highlightColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: inner,
                ),
              ),
      ),
    );
  }
}

/// 主体点击区（文本）
///
/// 撑满剩余宽度，撑满 tile 全高。点击从该句开始播放。
class _SentenceBodyHitArea extends StatelessWidget {
  final ThemeData theme;
  final VoidCallback? onTap;
  final Widget child;

  const _SentenceBodyHitArea({
    super.key,
    required this.theme,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.s,
        top: AppSpacing.s,
        bottom: AppSpacing.s,
      ),
      child: child,
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: inner,
      ),
    );
  }
}

/// 收藏按钮点击区
///
/// 视觉上收窄为句子右侧的轻量标记，不与句子文本竞争注意力；
/// 交互上仍保持独立热区，避免和中间文本进讲解混在一起。
class _SentenceBookmarkHitArea extends StatelessWidget {
  final ThemeData theme;
  final bool isBookmarked;
  final VoidCallback? onTap;

  const _SentenceBookmarkHitArea({
    super.key,
    required this.theme,
    required this.isBookmarked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semanticLabel = isBookmarked
        ? (l10n?.intensiveListenMarkedDifficult ?? 'Marked difficult')
        : (l10n?.intensiveListenNotDifficult ?? 'Not marked difficult');
    final iconColor = isBookmarked
        ? AppTheme.bookmarkColor
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.28);

    final inner = SizedBox(
      width: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Center(
          child: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            size: 14,
            color: iconColor,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );

    if (onTap == null) return inner;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.03),
            child: inner,
          ),
        ),
      ),
    );
  }
}

/// 统一词块：可见或遮盖，统一 padding 保证等高
///
/// 遮盖模式下，通过 [isPrevMasked]/[isNextMasked] 控制：
/// - 连接侧圆角置零
/// - 向后溢出绘制桥接色块，填充 Wrap spacing 间隙
///
/// [savedSegments] 非空且词可见时，按收藏命中子段渲染橙色点状下划线
/// （如 "dog." 只给 "dog" 加下划线、句号不加）；遮盖时忽略。
class _WordBlock extends StatelessWidget {
  final String text;
  final bool isMasked;
  final bool isActiveWord;
  final bool isPrevMasked;
  final bool isNextMasked;

  /// 词内收藏命中子段（相对词首的 (起, 止, 是否命中) 列表；null = 无命中）
  final List<(int, int, bool)>? savedSegments;

  final ThemeData theme;

  /// 正文样式（已叠加学习内容字号/字体偏好）；遮盖词仅改颜色，尺寸不变。
  final TextStyle textStyle;

  const _WordBlock({
    required this.text,
    required this.isMasked,
    required this.isActiveWord,
    required this.theme,
    required this.textStyle,
    this.isPrevMasked = false,
    this.isNextMasked = false,
    this.savedSegments,
  });

  @override
  Widget build(BuildContext context) {
    final maskColor = theme.colorScheme.surfaceContainerHighest;

    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      decoration: isMasked
          ? BoxDecoration(
              color: maskColor,
              borderRadius: BorderRadius.horizontal(
                left: isPrevMasked ? Radius.zero : const Radius.circular(3),
                right: isNextMasked ? Radius.zero : const Radius.circular(3),
              ),
            )
          : isActiveWord
          ? BoxDecoration(
              color: AppTheme.wordHighlightBackgroundColor(theme.colorScheme),
              borderRadius: BorderRadius.circular(3),
            )
          : null,
      child: _buildText(),
    );

    // 连续遮盖词：向右溢出绘制桥接色块填充 Wrap spacing
    if (isMasked && isNextMasked) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -_wordSpacing,
            top: 0,
            bottom: 0,
            width: _wordSpacing,
            child: ColoredBox(color: maskColor),
          ),
        ],
      );
    }

    return child;
  }

  /// 词文本：无收藏命中或被遮盖时普通 [Text]；否则按子段渲染点状下划线。
  ///
  /// 下划线必须显式设 decorationColor（默认会跟随文字色）。
  Widget _buildText() {
    final baseStyle = textStyle.copyWith(
      color: isMasked ? Colors.transparent : null,
    );
    final segments = savedSegments;
    if (isMasked || segments == null) {
      return Text(text, style: baseStyle);
    }
    final savedColor = AppTheme.savedTextMarkColor(theme.brightness);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final (start, end, saved) in segments)
            TextSpan(
              text: text.substring(start, end),
              style: saved
                  ? TextStyle(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: savedColor,
                      decorationThickness: 2,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

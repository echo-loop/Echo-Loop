/// 遮盖句子 Tile
///
/// 段落内单个句子的显示组件，支持多种渲染模式：
/// - 按 displayMode 显示关键词/全部显示/全部隐藏（listening 和 retelling 通用）
/// - listening 阶段当前播放句高亮
///
/// 每个词独立渲染（Wrap 子元素数量恒定，切换模式时布局不跳动），
/// 连续遮盖词通过溢出绘制桥接色块实现视觉连续。
library;

import 'package:flutter/material.dart';
import '../../models/retell_settings.dart';
import '../../models/sentence.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyword_extraction.dart';

/// Wrap 子元素间距（px）— 模拟自然空格宽度
const _wordSpacing = 4.0;

/// 遮盖句子 Tile
class MaskedSentenceTile extends StatelessWidget {
  /// 句子数据
  final Sentence sentence;

  /// 文本显示模式
  final RetellDisplayMode displayMode;

  /// 该句的关键词词索引集合
  final Set<int> keywordIndices;

  /// 是否为当前播放中的句子
  final bool isPlayingSentence;

  /// 是否已收藏（只读标记）
  final bool isBookmarked;

  /// 点击整行回调
  final VoidCallback? onTap;

  const MaskedSentenceTile({
    super.key,
    required this.sentence,
    required this.displayMode,
    required this.keywordIndices,
    required this.isPlayingSentence,
    this.isBookmarked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 句子序号 + 内容 + 收藏标记
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${sentence.index + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: _buildMaskedText(theme, tokenize(sentence.text))),
              if (isBookmarked)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.bookmark, size: 14, color: Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        // 背景色在 AnimatedContainer 上，涟漪会被遮挡，改用高亮反馈
        splashColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: content,
      );
    }
    return content;
  }

  /// 构建遮盖文本
  Widget _buildMaskedText(ThemeData theme, List<String> words) {
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
      children: _buildWordWidgets(words, shouldMask, theme),
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
  ) {
    return [
      for (var i = 0; i < words.length; i++)
        _WordBlock(
          text: words[i],
          isMasked: shouldMask(i),
          isPrevMasked: i > 0 && shouldMask(i) && shouldMask(i - 1),
          isNextMasked:
              i < words.length - 1 && shouldMask(i) && shouldMask(i + 1),
          theme: theme,
        ),
    ];
  }
}

/// 统一词块：可见或遮盖，统一 padding 保证等高
///
/// 遮盖模式下，通过 [isPrevMasked]/[isNextMasked] 控制：
/// - 连接侧圆角置零
/// - 向后溢出绘制桥接色块，填充 Wrap spacing 间隙
class _WordBlock extends StatelessWidget {
  final String text;
  final bool isMasked;
  final bool isPrevMasked;
  final bool isNextMasked;
  final ThemeData theme;

  const _WordBlock({
    required this.text,
    required this.isMasked,
    required this.theme,
    this.isPrevMasked = false,
    this.isNextMasked = false,
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
          : null,
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isMasked ? Colors.transparent : null,
        ),
      ),
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
}

/// 句子列表与操作菜单共用的图标，统一收藏状态和 AI 讲解的视觉含义。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 已收藏使用黄色实心书签，未收藏使用轮廓书签。
class SentenceBookmarkIcon extends StatelessWidget {
  final bool isBookmarked;
  final double size;
  final Color? unsavedColor;
  final String? semanticLabel;

  const SentenceBookmarkIcon({
    super.key,
    required this.isBookmarked,
    this.size = 18,
    this.unsavedColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => Icon(
    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
    size: size,
    color: isBookmarked
        ? AppTheme.bookmarkColor
        : unsavedColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
    semanticLabel: semanticLabel,
  );
}

/// AI 讲解统一使用紫色星芒图标。
class SentenceExplanationIcon extends StatelessWidget {
  const SentenceExplanationIcon({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.auto_awesome, size: 18, color: Colors.purple.shade400);
}

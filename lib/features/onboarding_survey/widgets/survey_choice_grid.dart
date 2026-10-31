/// 问卷双列选项网格与竖向卡片。
///
/// 适用于选项较多、标签较短的题目（如 Q3 来源渠道），让用户一屏内看完全部选项。
/// 选中态与 [SurveyChoiceTile] 保持一致：主题容器色 + 2px primary 边框 + ✓ 标记。
library;

import 'package:flutter/material.dart';

/// 两列网格：子项按顺序两两一行，同一行的卡片等高。
///
/// 奇数个子项时最后一行右侧留空，不拉伸单个卡片。
class SurveyChoiceGrid extends StatelessWidget {
  const SurveyChoiceGrid({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  final List<Widget> children;

  /// 行间距与列间距（逻辑像素）。
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final hasRight = i + 1 < children.length;
      if (i > 0) rows.add(SizedBox(height: spacing));
      // IntrinsicHeight 让同一行的两张卡片等高；Column 不给子项有限高度，不能直接 stretch。
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: spacing),
              Expanded(
                child: hasRight ? children[i + 1] : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// 网格中的竖向选项卡片：图标在上，标签居中在下，最多两行。
class SurveyChoiceGridTile extends StatelessWidget {
  const SurveyChoiceGridTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 顶部的可选装饰 Widget（品牌图标等）。为 null 时不渲染该 slot。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = selected
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final textColor = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          // StackFit.expand 让内部 Column 撑满卡片宽度，图标与标签才能居中对齐。
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(child: leading),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: textColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // ✓ 绝对定位在右上角，选中前后卡片高度保持一致，避免布局跳动。
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI 查词折叠入口卡片，收藏复习背面与查词详情页共用。
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// AI 查词主入口：以整行卡片表达可展开内容，而不是普通次级按钮。
class AiLookupToggle extends StatelessWidget {
  const AiLookupToggle({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      toggled: expanded,
      label: expanded ? '收起 AI 查词' : '显示 AI 查词',
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: 9,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 查词',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.chevron_right_rounded,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

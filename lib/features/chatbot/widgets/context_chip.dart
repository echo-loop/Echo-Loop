/// 输入框上方「正在讨论：<摘要>」chip。
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// config.contextSummary 为空则由上层不渲染本组件。
/// 摘要可能是整句长文本：maxLines: 1 + TextOverflow.ellipsis。
class ChatContextChip extends StatelessWidget {
  const ChatContextChip({super.key, required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.chatContextLabel(summary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(context),
            ),
          ),
        ],
      ),
    );
  }
}

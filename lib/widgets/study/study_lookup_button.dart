/// 学习页顶部的手动查词入口，与连续学习天数胶囊同款样式，位于其左侧。
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../common/svg_action_icon.dart';

class StudyLookupButton extends StatelessWidget {
  const StudyLookupButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final foreground = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: l10n.studyLookupEntry,
      child: ConstrainedBox(
        // 视觉胶囊与连续天数同高，但触控区域不低于 44pt。
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('study-lookup-entry'),
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgActionIcon(
                      assetName: 'assets/icon/book-search.svg',
                      size: 16,
                      color: foreground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.studyLookupEntry,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 展示连续学习天数；传入 [onTap] 时 badge 可点击。
class StudyStreakBadge extends StatelessWidget {
  const StudyStreakBadge({required this.streak, this.onTap, super.key});

  final int streak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = streak > 0;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.orange.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: isActive
                ? Colors.orange
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.streakDays(streak),
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? Colors.orange.shade800
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}

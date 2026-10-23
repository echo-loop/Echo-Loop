import 'package:flutter/material.dart';

import '../models/community_collection_models.dart';
import '../../../l10n/app_localizations.dart';

/// 显示社区材料服务端提供的 CEFR 难度等级。
class CommunityDifficultyBadge extends StatelessWidget {
  final CommunityDifficulty difficulty;

  const CommunityDifficultyBadge({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = difficulty.code;
    final colors = _colorsForDifficulty(difficulty, theme.brightness);
    return Semantics(
      label: AppLocalizations.of(context)!.difficultyLabel(label),
      child: Container(
        key: const Key('community_difficulty_badge'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 为各 CEFR 等级使用不同色相，并在浅色和深色主题中保持文字对比度。
({Color background, Color foreground}) _colorsForDifficulty(
  CommunityDifficulty difficulty,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  return switch (difficulty) {
    CommunityDifficulty.a1 => (
      background: Color(isDark ? 0xFF2E3B1C : 0xFFF0F7D4),
      foreground: Color(isDark ? 0xFFDCEFB0 : 0xFF355500),
    ),
    CommunityDifficulty.a2 => (
      background: Color(isDark ? 0xFF123C32 : 0xFFD9F0E7),
      foreground: Color(isDark ? 0xFFA7E6CE : 0xFF005A45),
    ),
    CommunityDifficulty.b1 => (
      background: Color(isDark ? 0xFF143A5C : 0xFFDCEBFA),
      foreground: Color(isDark ? 0xFFAFD5FF : 0xFF0D47A1),
    ),
    CommunityDifficulty.b2 => (
      background: Color(isDark ? 0xFF272E5C : 0xFFE1E5FA),
      foreground: Color(isDark ? 0xFFC5CAFF : 0xFF303F9F),
    ),
    CommunityDifficulty.c1 => (
      background: Color(isDark ? 0xFF442456 : 0xFFEFE0F5),
      foreground: Color(isDark ? 0xFFEAD0F4 : 0xFF6A1B9A),
    ),
    CommunityDifficulty.c2 => (
      background: Color(isDark ? 0xFF4A3514 : 0xFFF8E9C8),
      foreground: Color(isDark ? 0xFFFFE0A3 : 0xFF6A4B00),
    ),
  };
}

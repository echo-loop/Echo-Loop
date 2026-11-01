import 'package:flutter/material.dart';

import '../features/community_collections/models/community_collection_models.dart';
import '../features/community_collections/widgets/community_difficulty_badge.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../services/subtitle_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_info_chip.dart';

/// 音频详情页：展示单个音频的完整描述、难度与基础元信息。
///
/// 从学习计划页的进度卡片进入（嵌套子路由 `audio-detail`）。
/// 后续会追加关键点等内容，因此按分区组织 ListView。
class AudioDetailScreen extends StatelessWidget {
  /// 要展示的音频条目。
  final AudioItem audioItem;

  const AudioDetailScreen({super.key, required this.audioItem});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final difficulty = CommunityDifficulty.fromCode(audioItem.difficulty);
    final description = audioItem.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final metaChips = _buildMetaChips(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.audioDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          Text(
            audioItem.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (metaChips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.xs,
              children: metaChips,
            ),
          ],
          if (difficulty != null) ...[
            const SizedBox(height: AppSpacing.l),
            Row(
              key: const Key('audio_detail_difficulty'),
              children: [
                Text(
                  l10n.audioDetailDifficulty,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                CommunityDifficultyBadge(difficulty: difficulty),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          Text(
            l10n.audioDetailDescription,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            hasDescription ? description : l10n.audioDetailNoDescription,
            key: const Key('audio_detail_description'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: hasDescription
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 时长 / 句数 / 词数标签，与学习计划页卡片的图标样式一致；没有数据时返回空列表。
  List<Widget> _buildMetaChips(AppLocalizations l10n) {
    return [
      if (audioItem.totalDuration > 0)
        AudioInfoChip(
          icon: Icons.timer_outlined,
          label: SubtitleParser.formatDuration(
            Duration(seconds: audioItem.totalDuration),
          ),
        ),
      if (audioItem.sentenceCount > 0)
        AudioInfoChip(
          icon: Icons.format_list_numbered,
          label: l10n.sentenceCountLabel(audioItem.sentenceCount),
        ),
      if (audioItem.wordCount > 0)
        AudioInfoChip(
          icon: Icons.text_fields,
          label: l10n.wordCountLabel(audioItem.wordCount),
        ),
    ];
  }
}

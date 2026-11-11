// 素材元信息：CC 徽章、难度徽章、时长与日期。
//
// 合集列表项与学习页「为你推荐」卡共用，保证两处展示的元信息规则一致。
// 下载状态等列表项专属信息不在这里处理。
import 'package:flutter/material.dart';

import '../features/community_collections/models/community_collection_models.dart';
import '../features/community_collections/widgets/community_difficulty_badge.dart';
import '../l10n/app_localizations.dart';
import '../models/audio_item.dart';
import '../utils/time_format.dart';
import 'common/transcript_cc_badge.dart';

/// 元信息文案：可见的图标与文本段，以及供屏幕阅读器读出的完整文案。
class AudioMetaParts {
  final List<InlineSpan> spans;
  final List<String> accessibleLabels;

  const AudioMetaParts({required this.spans, required this.accessibleLabels});
}

/// 构建时长与日期两段元信息（段与段之间已插入分隔符）。
///
/// 日期规则：用户自建音频显示「添加于」；社区合集 / 播客单集显示「发布于」，
/// 原始发布日期未录入时跳过。
AudioMetaParts buildAudioMetaParts(BuildContext context, AudioItem audio) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final iconColor = theme.colorScheme.onSurfaceVariant;
  final spans = <InlineSpan>[];
  final accessibleLabels = <String>[];
  void addSeparator() {
    if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · '));
  }

  if (audio.totalDuration > 0) {
    final duration = formatAudioDuration(audio.totalDuration);
    addSeparator();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.schedule_outlined, size: 14, color: iconColor),
      ),
    );
    spans.add(TextSpan(text: ' $duration'));
    accessibleLabels.add(l10n.audioDuration(duration));
  }

  final isPublishedSource =
      audio.remoteAudioId != null || audio.podcastEpisodeGuid != null;
  if (!isPublishedSource) {
    final addedDate = formatTimeAgo(context, audio.addedDate);
    addSeparator();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.calendar_today_outlined, size: 14, color: iconColor),
      ),
    );
    spans.add(TextSpan(text: ' $addedDate'));
    accessibleLabels.add(l10n.addedOn(addedDate));
  } else if (audio.originalDate case final originalDate?) {
    final publishedDate = formatAbsoluteDate(originalDate);
    addSeparator();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.calendar_today_outlined, size: 14, color: iconColor),
      ),
    );
    spans.add(TextSpan(text: ' $publishedDate'));
    accessibleLabels.add(l10n.publishedOn(publishedDate));
  }

  return AudioMetaParts(spans: spans, accessibleLabels: accessibleLabels);
}

/// 社区音频原始发布日期：绝对日期 `yyyy/M/d`（历史日期相对时间没意义）。
String formatAbsoluteDate(DateTime date) {
  return '${date.year}/${date.month}/${date.day}';
}

/// 格式化音频时长（秒 → mm:ss 或 h:mm:ss）。
String formatAudioDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 元信息行：左侧 CC 徽章与难度徽章，右侧时长与日期（单行省略）。
class AudioMetaLine extends StatelessWidget {
  final AudioItem audio;

  const AudioMetaLine({super.key, required this.audio});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final difficulty = audio.isCommunity
        ? CommunityDifficulty.fromCode(audio.difficulty)
        : null;
    final meta = buildAudioMetaParts(context, audio);
    final metaText = Text.rich(
      TextSpan(children: meta.spans),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    return Row(
      children: [
        if (audio.hasTranscript) ...[
          TranscriptCcBadge(
            containerKey: const Key('audio_meta_line_transcript_badge'),
            label: l10n.transcript,
          ),
          const SizedBox(width: 8),
        ],
        if (difficulty != null) ...[
          CommunityDifficultyBadge(difficulty: difficulty),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: meta.accessibleLabels.isEmpty
              ? metaText
              : Semantics(
                  label: meta.accessibleLabels.join(' · '),
                  excludeSemantics: true,
                  child: metaText,
                ),
        ),
      ],
    );
  }
}

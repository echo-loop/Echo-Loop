import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/audio_item.dart';
import '../../../models/sentence.dart';
import '../media_trim_editor_controller.dart';
import 'media_trim_clip_colors.dart';
import 'media_trim_format.dart';

/// 只读字幕列表的 sliver 组：点句试听并定位；左侧色条标出句子所属片段。
class MediaTrimTranscriptSlivers extends ConsumerWidget {
  const MediaTrimTranscriptSlivers({
    super.key,
    required this.source,
    this.showHeader = true,
  });

  final AudioItem source;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mediaTrimEditorProvider(source);
    final sentences = ref.watch(
      provider.select((s) => s.boundaries?.sentences ?? const <Sentence>[]),
    );
    final (clips, selectedId) = ref.watch(
      provider.select((s) => (s.clips, s.selectedClipId)),
    );
    final playingIndex = ref.watch(
      provider.select((s) {
        if (!s.isPlaying) return -1;
        final preview = s.preview;
        if (preview is MediaTrimSentencePreview) return preview.sentenceIndex;
        return -1;
      }),
    );
    final currentIndex = ref.watch(
      provider.select((s) {
        final position = s.position;
        return sentences.indexWhere(
          (sentence) =>
              position >= sentence.startTime && position < sentence.endTime,
        );
      }),
    );
    final controller = ref.read(provider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SliverMainAxisGroup(
      slivers: [
        if (showHeader)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
              child: Text(
                '${l10n.mediaTrimTranscript} · ${sentences.length}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              l10n.mediaTrimTranscriptHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        SliverList.builder(
          key: const ValueKey('trim-sentences'),
          itemCount: sentences.length,
          itemBuilder: (context, index) {
            final sentence = sentences[index];
            var membership = _Membership.none;
            var clipIndex = -1;
            for (var i = 0; i < clips.length; i++) {
              final clip = clips[i];
              if (sentence.startTime >= clip.start &&
                  sentence.endTime <= clip.end) {
                clipIndex = i;
                if (clip.id == selectedId) {
                  membership = _Membership.selected;
                  break;
                }
                membership = _Membership.other;
              }
            }
            return _SentenceRow(
              index: index,
              sentence: sentence,
              membership: membership,
              clipColor: clipIndex < 0
                  ? null
                  : MediaTrimClipColor.of(clipIndex, theme.brightness).base,
              isCurrent: index == currentIndex,
              isPlaying: index == playingIndex,
              onTap: () => controller.toggleSentencePreview(index),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

enum _Membership { none, other, selected }

class _SentenceRow extends StatelessWidget {
  const _SentenceRow({
    required this.index,
    required this.sentence,
    required this.membership,
    required this.clipColor,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final int index;
  final Sentence sentence;
  final _Membership membership;

  /// 句子所属片段的颜色，与时间轴区间一致；不属于任何片段时为 null。
  final Color? clipColor;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = switch (membership) {
      _Membership.selected => clipColor!,
      _Membership.other => clipColor!.withValues(alpha: 0.45),
      _Membership.none => Colors.transparent,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: membership == _Membership.selected
            ? clipColor!.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('trim-sentence-$index'),
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.fromLTRB(6, 10, 0, 10),
                  decoration: BoxDecoration(
                    color: band,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sentence.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrent
                                ? scheme.primary
                                : scheme.onSurface,
                            fontWeight: isCurrent ? FontWeight.w600 : null,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (isPlaying)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.volume_up_rounded,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                              ),
                            Text(
                              '${formatTrimTime(sentence.startTime)} – '
                              '${formatTrimTime(sentence.endTime)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

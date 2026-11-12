/// 收藏词汇/句子共用的来源句卡片与来源材料入口。
///
/// 收藏复习背面与查词详情页共用：可点词的来源句 + 跳转来源材料的链接。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../practice/selectable_sentence_text.dart';
import 'source_sentence_detail_navigation.dart';

/// 来源句卡片：把可播放句子与学习语境标签组合成一个明确的内容入口。
class SourceSentenceCard extends StatelessWidget {
  const SourceSentenceCard({
    required this.sentenceText,
    required this.audioItemId,
    required this.sentenceIndex,
    required this.sentenceStartMs,
    required this.sentenceEndMs,
  });

  final String sentenceText;
  final String? audioItemId;
  final int? sentenceIndex;
  final int? sentenceStartMs;
  final int? sentenceEndMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const Key('favorite-vocabulary-review-source'),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s, 8, AppSpacing.s, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableSentenceText(
              text: sentenceText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
              origin: DictionaryLookupOrigin(
                audioItemId: audioItemId,
                sentenceIndex: sentenceIndex,
                sentenceText: sentenceText,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
              ),
            ),
            if (audioItemId != null) ...[
              const SizedBox(height: AppSpacing.xs),
              SourceMaterialLink(
                audioItemId: audioItemId!,
                sentenceText: sentenceText,
                sentenceIndex: sentenceIndex,
                sentenceStartMs: sentenceStartMs,
                sentenceEndMs: sentenceEndMs,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 来源材料入口只读取标题；点击进入来源句讲解页，与收藏详情页的来源句箭头一致。
class SourceMaterialLink extends ConsumerWidget {
  const SourceMaterialLink({
    required this.audioItemId,
    required this.sentenceText,
    required this.sentenceIndex,
    required this.sentenceStartMs,
    required this.sentenceEndMs,
  });

  final String audioItemId;
  final String sentenceText;
  final int? sentenceIndex;
  final int? sentenceStartMs;
  final int? sentenceEndMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
    future: ref.read(audioItemDaoProvider).getById(audioItemId),
    builder: (context, snapshot) {
      final title = snapshot.data?.name ?? '来源材料';
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Semantics(
        button: true,
        label: '打开来源句讲解 $title',
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('favorite-vocabulary-review-source-material'),
              onTap: () => unawaited(
                openFavoriteSourceSentenceDetail(
                  context: context,
                  ref: ref,
                  audioItemId: audioItemId,
                  sentenceText: sentenceText,
                  sentenceIndex: sentenceIndex,
                  sentenceStartMs: sentenceStartMs,
                  sentenceEndMs: sentenceEndMs,
                ),
              ),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        l10n.bookmarkReviewFromAudio(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

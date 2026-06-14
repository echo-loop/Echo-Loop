/// Podcast 信息只读展示弹窗
///
/// - [showPodcastFeedInfoSheet]：合集级详情（标题/简介/图片/Apple 链接/link/RSS）
/// - [showPodcastEpisodeInfoSheet]：音频级详情（标题/简介/网页 link/音频下载链接）
library;

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/audio_item.dart';
import '../../models/collection.dart';
import '../../theme/app_theme.dart';
import 'podcast_models.dart';

/// 展示 podcast 合集的详情（只读）。
void showPodcastFeedInfoSheet(BuildContext context, Collection collection) {
  final l10n = AppLocalizations.of(context)!;
  final meta = _decodeMeta(collection.podcastMetaJson);
  final title = meta?.title ?? collection.name;
  final description = meta?.description ?? collection.description;
  final imageUrl = meta?.imageUrl ?? collection.coverUrl;
  final lastRefreshed = collection.podcastLastRefreshedAt;

  showPodcastInfoSheet(
    context,
    title: l10n.podcastDetails,
    heroTitle: title,
    heroAuthor: meta?.author,
    heroDescription: description,
    imageUrl: imageUrl,
    dateText: lastRefreshed == null
        ? null
        : l10n.podcastLastRefreshed(_formatDateTime(lastRefreshed)),
    links: [
      if (_hasText(collection.podcastInputUrl))
        PodcastInfoLink(
          _isApplePodcastUrl(collection.podcastInputUrl!)
              ? l10n.podcastAppleLink
              : l10n.podcastOriginalLink,
          collection.podcastInputUrl!,
        ),
      if (_hasText(meta?.feedUrl) && meta!.feedUrl != collection.podcastFeedUrl)
        PodcastInfoLink(l10n.podcastOriginalLink, meta.feedUrl),
      if (_hasText(collection.podcastFeedUrl))
        PodcastInfoLink(l10n.podcastFeedUrl, collection.podcastFeedUrl!),
    ],
  );
}

/// 展示通用 Podcast 信息弹窗。
///
/// 发现页精选播客预览和本地已订阅 Podcast 合集共用同一套详情布局，
/// 避免同一类内容在不同入口呈现不一致。
void showPodcastInfoSheet(
  BuildContext context, {
  required String title,
  required String heroTitle,
  required List<PodcastInfoLink> links,
  String? heroAuthor,
  String? heroDescription,
  String? imageUrl,
  String? dateText,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: title,
      heroTitle: heroTitle,
      heroAuthor: heroAuthor,
      heroDescription: heroDescription,
      imageUrl: imageUrl,
      dateText: dateText,
      links: links,
    ),
  );
}

/// 展示 podcast episode 的详情（只读）。
void showPodcastEpisodeInfoSheet(BuildContext context, AudioItem item) {
  final l10n = AppLocalizations.of(context)!;
  final episodeLink = _episodeLink(item);
  // meta 行：发布日期 · 时长，二者都可能缺省。
  final metaParts = <String>[
    if (item.originalDate != null)
      l10n.publishedOn(_formatDate(item.originalDate!)),
    if (item.totalDuration > 0)
      l10n.audioDuration(_formatDuration(item.totalDuration)),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _InfoSheet(
      title: l10n.podcastEpisodeMeta,
      heroTitle: item.name,
      heroDescription: item.podcastDescription,
      dateText: metaParts.isEmpty ? null : metaParts.join(' · '),
      // 单集封面优先用 episode 自带图，缺省时 _PodcastArtwork 会显示占位图标。
      imageUrl: item.podcastImageUrl,
      links: [
        if (_hasText(episodeLink))
          PodcastInfoLink(l10n.podcastOriginalLink, episodeLink!),
        if (_hasText(item.podcastEnclosureUrl))
          PodcastInfoLink(l10n.podcastEnclosureUrl, item.podcastEnclosureUrl!),
      ],
    ),
  );
}

PodcastFeedMeta? _decodeMeta(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return PodcastFeedMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _episodeLink(AudioItem item) {
  if (_hasText(item.podcastLink)) return item.podcastLink;
  final guid = item.podcastEpisodeGuid;
  if (!_hasText(guid)) return null;
  final uri = Uri.tryParse(guid!);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
  return switch (uri.scheme) {
    'http' || 'https' => guid,
    _ => null,
  };
}

bool _isApplePodcastUrl(String value) {
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase();
  return host == 'podcasts.apple.com' || host == 'itunes.apple.com';
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

/// 日期 + 时分（yyyy-MM-dd HH:mm），用于「上次刷新」展示。
String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// 时长（秒 → mm:ss 或 h:mm:ss）。
String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

class PodcastInfoLink {
  final String label;
  final String url;

  const PodcastInfoLink(this.label, this.url);
}

class _InfoSheet extends StatelessWidget {
  final String title;
  final String heroTitle;
  final String? heroAuthor;
  final String? heroDescription;
  final String? imageUrl;
  final String? dateText;
  final List<PodcastInfoLink> links;

  const _InfoSheet({
    required this.title,
    required this.heroTitle,
    required this.links,
    this.heroAuthor,
    this.heroDescription,
    this.imageUrl,
    this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xl + bottom,
            ),
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.l),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.l),
              _InfoHero(
                title: heroTitle,
                author: heroAuthor,
                description: heroDescription,
                imageUrl: imageUrl,
                dateText: dateText,
              ),
              if (links.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.l),
                for (final link in links) _LinkRow(link: link),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoHero extends StatelessWidget {
  final String title;
  final String? author;
  final String? description;
  final String? imageUrl;
  final String? dateText;

  const _InfoHero({
    required this.title,
    this.author,
    this.description,
    this.imageUrl,
    this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 封面只与标题/作者/日期并排；简介移到整行下方占满宽度，
    // 避免文字比封面高时封面下方左侧出现大片空白。
    final headColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(title, style: theme.textTheme.titleLarge),
        if (_hasText(author)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            author!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasText(dateText)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            dateText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PodcastArtwork(imageUrl: imageUrl, size: 88),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: headColumn),
          ],
        ),
        if (_hasText(description)) ...[
          const SizedBox(height: AppSpacing.m),
          SelectableText(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _PodcastArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _PodcastArtwork({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: !_hasText(imageUrl)
            ? placeholder
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final PodcastInfoLink link;

  const _LinkRow({required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openLink(context, link.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.link_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String value) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(value);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.podcastOpenLinkFailed)));
    }
  }
}

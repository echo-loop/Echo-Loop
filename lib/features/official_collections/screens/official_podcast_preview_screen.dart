import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../podcast/podcast_info_sheet.dart';
import '../../podcast/podcast_models.dart';
import '../../podcast/podcast_repository.dart';
import '../models/catalog.dart';
import '../providers/discover_podcasts_provider.dart';
import '../providers/podcast_preview_provider.dart';

/// 精选 Podcast 内容预览页。
///
/// 本页不写入 audio_items；只有用户明确添加到我的合集后，才进入现有
/// Podcast 订阅流程并创建本地合集。
class OfficialPodcastPreviewScreen extends ConsumerStatefulWidget {
  final String podcastId;

  const OfficialPodcastPreviewScreen({super.key, required this.podcastId});

  @override
  ConsumerState<OfficialPodcastPreviewScreen> createState() =>
      _OfficialPodcastPreviewScreenState();
}

class _OfficialPodcastPreviewScreenState
    extends ConsumerState<OfficialPodcastPreviewScreen> {
  bool _subscribing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final podcast = ref.watch(podcastCatalogDetailProvider(widget.podcastId));
    final preview = ref.watch(podcastPreviewProvider(widget.podcastId));
    final subscribedCollection = podcast == null
        ? null
        : _findSubscribedCollection(podcast);

    return Scaffold(
      appBar: AppBar(title: Text(podcast?.title ?? l10n.discoverPodcastTitle)),
      body: podcast == null
          ? _MissingPodcastState(message: l10n.officialCollectionDeprecated)
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(podcastPreviewProvider(widget.podcastId));
                      try {
                        await ref.read(
                          podcastPreviewProvider(widget.podcastId).future,
                        );
                      } catch (_) {
                        // 错误由 AsyncValue 渲染为页面内错误卡；刷新手势本身不抛出。
                      }
                    },
                    child: _buildContent(
                      podcast,
                      preview,
                      subscribedCollection,
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildCta(podcast, subscribedCollection, l10n),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContent(
    CatalogPodcast podcast,
    AsyncValue<PodcastPreviewData> preview,
    Collection? subscribedCollection,
  ) {
    return preview.when(
      loading: () => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _PodcastPreviewHeader(podcast: podcast),
          const LinearProgressIndicator(),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _PodcastPreviewHeader(podcast: podcast),
          _PodcastPreviewErrorCard(
            message: _formatPreviewError(error),
            onRetry: () =>
                ref.invalidate(podcastPreviewProvider(widget.podcastId)),
          ),
        ],
      ),
      data: (data) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: data.episodes.length + 1,
        separatorBuilder: (context, index) =>
            index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _PodcastPreviewHeader(podcast: podcast, meta: data.meta);
          }
          final episode = data.episodes[index - 1];
          return _EpisodePreviewTile(
            episode: episode,
            subscribed: subscribedCollection != null,
            onTap: () => subscribedCollection == null
                ? _showSubscribeRequiredDialog(podcast)
                : context.go(
                    AppRoutes.collectionDetail(subscribedCollection.id),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCta(
    CatalogPodcast podcast,
    Collection? subscribedCollection,
    AppLocalizations l10n,
  ) {
    if (_subscribing) {
      return FilledButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.podcastSubscribing),
          ],
        ),
      );
    }
    if (subscribedCollection != null) {
      return FilledButton(
        onPressed: () =>
            context.go(AppRoutes.collectionDetail(subscribedCollection.id)),
        child: Text(l10n.goLearn),
      );
    }
    return FilledButton(
      onPressed: () => _subscribe(podcast),
      child: Text(l10n.addToMyCollections),
    );
  }

  Collection? _findSubscribedCollection(CatalogPodcast podcast) {
    final state = ref.watch(collectionListProvider);
    for (final c in state.collections) {
      if (c.isPodcast && c.podcastFeedUrl == podcast.rssUrl) return c;
    }
    return null;
  }

  Future<void> _showSubscribeRequiredDialog(CatalogPodcast podcast) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.podcastEnrollNeededTitle),
        content: Text(l10n.podcastEnrollNeededMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'subscribe'),
            child: Text(l10n.addToMyCollections),
          ),
        ],
      ),
    );
    if (result == 'subscribe' && mounted) {
      await _subscribe(podcast);
    }
  }

  Future<void> _subscribe(CatalogPodcast podcast) async {
    final l10n = AppLocalizations.of(context)!;
    final canEnroll = await ensureSignedInForAction(
      context: context,
      ref: ref,
      title: l10n.officialCollectionSignInRequiredTitle,
      message: l10n.podcastCatalogSignInRequiredMessage,
    );
    if (!mounted || !canEnroll) return;

    setState(() => _subscribing = true);
    try {
      final collection = await ref
          .read(podcastRepositoryProvider)
          .createAndFetch(_subscriptionUrl(podcast));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enrollSucceeded)));
      context.go(AppRoutes.collectionDetail(collection.id));
    } on PodcastAlreadySubscribedException catch (e) {
      if (!mounted) return;
      final existing = ref
          .read(collectionListProvider)
          .collections
          .where((c) => c.isPodcast && c.name == e.collectionName)
          .firstOrNull;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.podcastAlreadySubscribed(e.collectionName)),
        ),
      );
      if (existing != null) {
        context.go(AppRoutes.collectionDetail(existing.id));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastCatalogSubscribeFailed)),
      );
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  String _subscriptionUrl(CatalogPodcast podcast) {
    final rssUrl = podcast.rssUrl.trim();
    if (rssUrl.isNotEmpty) return rssUrl;
    return podcast.applePodcastUrl;
  }

  String _formatPreviewError(Object error) {
    final l10n = AppLocalizations.of(context)!;
    if (error is PodcastPreviewException) {
      return switch (error.kind) {
        PodcastPreviewErrorKind.timeout ||
        PodcastPreviewErrorKind.network => l10n.podcastPreviewNetworkFailed,
        PodcastPreviewErrorKind.appleLookup => l10n.podcastPreviewAppleFailed,
        PodcastPreviewErrorKind.parseFailed => l10n.podcastPreviewParseFailed,
        PodcastPreviewErrorKind.emptyFeed => l10n.podcastPreviewEmpty,
        PodcastPreviewErrorKind.rssUnavailable =>
          l10n.podcastPreviewNetworkFailed,
      };
    }
    return l10n.podcastPreviewNetworkFailed;
  }
}

class _PodcastPreviewHeader extends StatelessWidget {
  final CatalogPodcast podcast;
  final PodcastFeedMeta? meta;

  const _PodcastPreviewHeader({required this.podcast, this.meta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title = meta?.title.isNotEmpty == true ? meta!.title : podcast.title;
    final description = meta?.description ?? podcast.description;
    final imageUrl = meta?.imageUrl ?? podcast.imageUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPodcastInfo(context, podcast, meta),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.m,
            AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PodcastCover(imageUrl: imageUrl, size: 72),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((description ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.podcastShowMore,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPodcastInfo(
    BuildContext context,
    CatalogPodcast podcast,
    PodcastFeedMeta? meta,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showPodcastInfoSheet(
      context,
      title: l10n.podcastDetails,
      heroTitle: meta?.title.isNotEmpty == true ? meta!.title : podcast.title,
      heroAuthor: meta?.author,
      heroDescription: meta?.description ?? podcast.description,
      imageUrl: meta?.imageUrl ?? podcast.imageUrl,
      links: [
        if (podcast.applePodcastUrl.isNotEmpty)
          PodcastInfoLink(l10n.podcastAppleLink, podcast.applePodcastUrl),
        if (podcast.rssUrl.isNotEmpty)
          PodcastInfoLink(l10n.podcastFeedUrl, podcast.rssUrl),
      ],
    );
  }
}

class _EpisodePreviewTile extends StatelessWidget {
  final PodcastEpisode episode;
  final bool subscribed;
  final VoidCallback onTap;

  const _EpisodePreviewTile({
    required this.episode,
    required this.subscribed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final meta = <String>[
      if (episode.pubDate != null) _formatDate(episode.pubDate!),
      if (episode.durationSeconds != null && episode.durationSeconds! > 0)
        _formatDuration(episode.durationSeconds!),
    ].join(' · ');
    return ListTile(
      leading: Icon(Icons.graphic_eq, color: theme.colorScheme.outline),
      title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if ((episode.description ?? '').isNotEmpty)
            Text(
              episode.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Tooltip(
        message: subscribed ? l10n.goLearn : l10n.addToMyCollections,
        child: Icon(subscribed ? Icons.chevron_right : Icons.lock_outline),
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }
}

class _PodcastPreviewErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PodcastPreviewErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text(l10n.discoverRetry)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodcastCover extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _PodcastCover({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.podcasts_rounded,
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: imageUrl == null || imageUrl!.isEmpty
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

class _MissingPodcastState extends StatelessWidget {
  final String message;

  const _MissingPodcastState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

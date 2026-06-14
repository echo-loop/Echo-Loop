import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/collection.dart';
import '../../../providers/collection_provider.dart';
import '../../../router/app_router.dart';
import '../../auth/sign_in_required_dialog.dart';
import '../../podcast/podcast_repository.dart';
import '../models/catalog.dart';
import '../providers/discover_podcasts_provider.dart';

/// 发现页精选 Podcast 二级列表。
class OfficialPodcastListScreen extends ConsumerStatefulWidget {
  const OfficialPodcastListScreen({super.key});

  @override
  ConsumerState<OfficialPodcastListScreen> createState() =>
      _OfficialPodcastListScreenState();
}

class _OfficialPodcastListScreenState
    extends ConsumerState<OfficialPodcastListScreen> {
  final Set<String> _subscribing = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final podcasts = ref.watch(discoverPodcastsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.discoverPodcastTitle)),
      body: switch (podcasts) {
        null => const Center(child: CircularProgressIndicator()),
        final items when items.isEmpty => _EmptyPodcastList(
          message: l10n.discoverPodcastEmpty,
        ),
        final items => _buildList(items),
      },
    );
  }

  Widget _buildList(List<CatalogPodcast> podcasts) {
    final collectionState = ref.watch(collectionListProvider);
    final feedToCollection = _podcastCollectionsByFeed(collectionState);
    return ListView.builder(
      itemCount: podcasts.length,
      itemBuilder: (context, index) {
        final podcast = podcasts[index];
        final localCollection = feedToCollection[podcast.rssUrl];
        return _CatalogPodcastCard(
          podcast: podcast,
          subscribed: localCollection != null,
          subscribing: _subscribing.contains(podcast.id),
          onOpen: () =>
              context.push(AppRoutes.discoverPodcastPreview(podcast.id)),
          onSubscribe: () => _subscribe(podcast),
          onGoLearn: () {
            if (localCollection != null) {
              context.go(AppRoutes.collectionDetail(localCollection.id));
            }
          },
        );
      },
    );
  }

  Map<String, Collection> _podcastCollectionsByFeed(CollectionState state) {
    return {
      for (final c in state.collections)
        if (c.isPodcast && c.podcastFeedUrl != null) c.podcastFeedUrl!: c,
    };
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

    setState(() => _subscribing.add(podcast.id));
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastCatalogSubscribeFailed)),
      );
    } finally {
      if (mounted) setState(() => _subscribing.remove(podcast.id));
    }
  }

  String _subscriptionUrl(CatalogPodcast podcast) {
    final rssUrl = podcast.rssUrl.trim();
    if (rssUrl.isNotEmpty) return rssUrl;
    return podcast.applePodcastUrl;
  }
}

class _CatalogPodcastCard extends StatelessWidget {
  final CatalogPodcast podcast;
  final bool subscribed;
  final bool subscribing;
  final VoidCallback onOpen;
  final VoidCallback onSubscribe;
  final VoidCallback onGoLearn;

  const _CatalogPodcastCard({
    required this.podcast,
    required this.subscribed,
    required this.subscribing,
    required this.onOpen,
    required this.onSubscribe,
    required this.onGoLearn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Row(
                  children: [
                    _PodcastCover(imageUrl: podcast.imageUrl, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            podcast.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((podcast.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              podcast.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildTrailing(context, l10n, theme),
        ],
      ),
    );
  }

  Widget _buildTrailing(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (subscribing) {
      return const SizedBox(
        width: 72,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (subscribed) {
      return SizedBox(
        width: 72,
        child: InkWell(
          onTap: onGoLearn,
          child: Center(
            child: Text(
              l10n.goLearn,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: onSubscribe,
        child: Tooltip(
          message: l10n.addToMyCollections,
          child: Center(
            child: Icon(
              Icons.add_circle_outline,
              color: theme.colorScheme.primary,
            ),
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

class _EmptyPodcastList extends StatelessWidget {
  final String message;

  const _EmptyPodcastList({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.podcasts_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
